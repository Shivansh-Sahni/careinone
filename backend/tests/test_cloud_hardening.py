import asyncio
import contextlib
import io
import json
import os
import threading
import unittest
import urllib.error
from unittest.mock import patch

from backend.app import Gateway, create_app
from backend.providers import CompatibleProvider, MockProvider, NoRedirect, ProviderError, Router
from backend.schema import VERSION, ValidationError, loads, validate_envelope, validate_request
from backend.tests import test_gateway
from backend.tests.test_gateway import TOKEN, envelope
from backend.verify_gateway import FICTIONAL_SOURCE, main as verify_main, safe_provider, verify


class ConfigurationHardeningTests(unittest.TestCase):
    def provider(self, model="gpt-4.1-mini-2025-04-14", **kwargs):
        return CompatibleProvider("https://api.example/v1", "unit-test-private-key", model, **kwargs)

    def test_api_keys_and_credential_prefixes_cannot_be_model_ids(self):
        for model in ("sk-proj-fictional-test-only", "SK-PROJ-fictional-test-only", "sk-ant-fictional-test-only", "ghp_fictional", "github_pat_fictional", "Bearer fictional", "AKIAFICTIONAL", "ASIAFICTIONAL", "AIza-fictional", "xoxb-fictional", "eyJhbGciOiJub25lIn0.payload.signature", "unit-test-private-key", "model/unit-test-private-key"):
            with self.subTest(case=model.split('-')[0]), self.assertRaises(ProviderError) as caught:
                self.provider(model)
            self.assertNotIn(model, str(caught.exception))

    def test_valid_namespaced_and_pinned_models_remain_supported(self):
        for model in ("gpt-4.1-mini-2025-04-14", "kimi-k2.6", "Qwen/Qwen3-235B-A22B", "ft:gpt-4.1-mini:organization:label:id", "us.anthropic.claude-model-v1:0"):
            with self.subTest(model=model): self.assertEqual(self.provider(model).model, model)

    def test_malformed_or_unbounded_model_ids_fail_before_network(self):
        for model in ("", " model", "model ", "model\n", '"model"', "`model`", "https://api.example/model?key=value", "a"*201, "model😀", "../model", None):
            with self.subTest(case=repr(model)[:20]), self.assertRaises(ProviderError): self.provider(model)

    def test_invalid_urls_fail_without_echoing_the_url(self):
        values = ("http://api.example/v1", " https://api.example/v1", "https://api.example/v1 ", "https://api.example/\n", '"https://api.example/v1"', "https://user:fictional@api.example/v1", "https://api.example/v1?key=fictional", "https://api.example/v1#fictional", "https://api.example:bad/v1", "https://api.example:0/v1", "https://api.example:99999/v1", "https://sk-proj-fictional.example/v1", "https://api.example/unit-test-private-key", "https://api.example/v1/chat/completions")
        for url in values:
            with self.subTest(case=url[:20]), self.assertRaises(ProviderError) as caught:
                CompatibleProvider(url, "unit-test-private-key", "model")
            self.assertNotIn(url, str(caught.exception))

    def test_repr_excludes_operator_controlled_sensitive_fields(self):
        provider=self.provider()
        rendered=repr(provider)
        for value in (provider.base_url, provider.api_key, provider.model): self.assertNotIn(value, rendered)

    def test_disclosed_configuration_is_revalidated(self):
        provider=self.provider()
        object.__setattr__(provider, "model", "sk-proj-fictional-test-only")
        with self.assertRaises(ProviderError): Router(provider).configuration()

    def test_gateway_token_cannot_be_provider_api_key(self):
        for token in ("sk-proj-"+"fictional"*10, "Bearer-"+"fictional"*10):
            with self.subTest(prefix=token[:7]), self.assertRaises(ValueError): Gateway([token], Router(MockProvider()))

    def test_gateway_tokens_cannot_be_used_as_primary_or_fallback_model_identifiers(self):
        for model in (TOKEN, 'model/'+TOKEN+'/pinned'):
            for fallback in (False, True):
                provider=self.provider(model)
                router=Router(self.provider(),provider) if fallback else Router(provider)
                with self.subTest(embedded=model != TOKEN,fallback=fallback),self.assertRaises(ProviderError) as caught:
                    Gateway([TOKEN],router)
                self.assertEqual(caught.exception.code,'provider_configuration')
                self.assertNotIn(TOKEN,str(caught.exception))

    def test_gateway_tokens_cannot_be_embedded_in_provider_url_paths_or_hosts(self):
        for url in ('https://api.example/'+TOKEN+'/v1','https://'+TOKEN+'.example/v1'):
            provider=CompatibleProvider(url,'unit-test-private-key','model')
            with self.subTest(host=TOKEN+'.example' in url),self.assertRaises(ProviderError) as caught:
                Gateway([TOKEN],Router(provider))
            self.assertNotIn(TOKEN,str(caught.exception)); self.assertNotIn(url,str(caught.exception))

    def test_gateway_credential_cannot_be_reused_as_a_provider_api_key(self):
        for api_key in (TOKEN,'provider-'+TOKEN+'-key'):
            provider=CompatibleProvider('https://api.example/v1',api_key,'model')
            with self.assertRaises(ProviderError) as caught: Gateway([TOKEN],Router(provider))
            self.assertEqual(caught.exception.code,'provider_configuration')
            self.assertNotIn(TOKEN,str(caught.exception))

    def test_token_fingerprints_do_not_retain_plaintext_gateway_credentials(self):
        app=Gateway([TOKEN],Router(self.provider()))
        self.assertNotIn(TOKEN,repr(vars(app)))
        self.assertTrue(app.contains_gateway_token('model/'+TOKEN+'/pinned'))
        self.assertFalse(app.contains_gateway_token('model/'+TOKEN[:-1]+'X/pinned'))

    def test_startup_integer_error_does_not_echo_accidental_secret(self):
        secret="sk-proj-fictional-misplaced-configuration-value"
        with patch.dict(os.environ, {"CARE_MAX_SOURCE_CHARACTERS":secret}, clear=True), self.assertRaises(ProviderError) as caught:
            create_app()
        self.assertNotIn(secret, str(caught.exception)); self.assertIsNone(caught.exception.__cause__)
        self.assertTrue(caught.exception.__suppress_context__)

    def test_invalid_runtime_bounds_cannot_disable_limits(self):
        for kwargs in ({"rate":0}, {"rate":True}, {"max_inflight":0}, {"max_inflight":17}, {"max_source_characters":True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError): Gateway([TOKEN],Router(MockProvider()),**kwargs)
        for kwargs in ({"timeout":float('inf')}, {"timeout":0}, {"max_output_tokens":True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ProviderError): self.provider(**kwargs)


class ProviderFailureTests(unittest.IsolatedAsyncioTestCase):
    async def failure(self, status, error_body):
        error=urllib.error.HTTPError("https://api.example/v1/chat/completions",status,"fictional patient secret must never be shown",{},io.BytesIO(json.dumps(error_body).encode()))
        provider=CompatibleProvider("https://api.example/v1", "unit-test-private-key", "model")
        with patch("urllib.request.build_opener") as opener:
            opener.return_value.open.side_effect=error
            try: await provider.extract("fictional evidence", "typed", None)
            except ProviderError as caught: return caught
        self.fail("Expected a safe provider error")

    async def test_known_provider_failures_are_sanitized_and_actionable(self):
        for status, body, code in ((401,{},"provider_authentication"),(403,{},"provider_permission"),(404,{},"provider_model"),(429,{"error":{"code":"insufficient_quota","message":"fictional patient secret"}},"provider_quota"),(429,{"error":{"code":"rate_limit_exceeded"}},"provider_rate_limit"),(500,{"error":{"message":"fictional patient secret"}},"provider_unavailable")):
            with self.subTest(status=status, code=code):
                error=await self.failure(status,body)
                self.assertEqual(error.code,code)
                self.assertNotIn("fictional",str(error)+error.public_message)
                self.assertNotIn("private-key",str(error)+error.public_message)
                self.assertTrue(error.__suppress_context__)

    async def test_router_preserves_safe_failure_code_but_not_exception_message(self):
        class Broken:
            async def extract(self,*args): raise ProviderError("fictional patient sensitive details",code="provider_quota")
        with self.assertRaises(ProviderError) as caught: await Router(Broken()).extract("source","typed",None)
        self.assertEqual(caught.exception.code,"provider_quota")
        self.assertNotIn("sensitive",str(caught.exception)+caught.exception.public_message)

    async def test_untrusted_error_code_is_not_disclosed(self):
        error=await self.failure(429,{"error":{"code":"sk-proj-fictional"}})
        self.assertEqual(error.code,"provider_rate_limit")

    def test_redirects_never_forward_authorization(self):
        with self.assertRaises(ProviderError): NoRedirect().redirect_request(None,None,302,"",{},"https://other.example")


class ProviderConcurrencyTests(unittest.IsolatedAsyncioTestCase):
    async def test_cancelled_sockets_keep_capacity_and_cancelled_waiters_never_dispatch(self):
        opened=threading.Event(); release=threading.Event(); queued=threading.Event()
        calls=0
        class TrackedSlots:
            def __init__(self): self.slots=threading.BoundedSemaphore(1); self.attempts=0; self.lock=threading.Lock()
            def acquire(self,timeout):
                with self.lock:
                    self.attempts+=1
                    if self.attempts>=2: queued.set()
                return self.slots.acquire(timeout=timeout)
            def release(self): self.slots.release()
        class Response:
            def __init__(self,text): self.raw=json.dumps({'choices':[{'finish_reason':'stop','message':{'content':json.dumps(envelope(text))}}]}).encode()
            def __enter__(self): return self
            def __exit__(self,*args): pass
            def read(self,limit): return self.raw[:limit]
        def open_request(request,timeout):
            nonlocal calls
            calls+=1
            if calls==1:
                opened.set()
                if not release.wait(timeout=3): raise AssertionError('Test transport was not released')
            text=json.loads(json.loads(request.data)['messages'][-1]['content'])['untrustedEvidence']
            return Response(text)
        primary=CompatibleProvider('https://api.example/v1','unit-test-private-key','model',timeout=5)
        independent=CompatibleProvider('https://other.example/v1','unit-test-private-key','other-model',timeout=5)
        first=second=None
        with patch('backend.providers._PROVIDER_TRANSPORT_SLOTS',TrackedSlots()),patch('urllib.request.build_opener') as opener:
            opener.return_value.open.side_effect=open_request
            try:
                first=asyncio.create_task(primary.extract('fictional first','typed',None))
                self.assertTrue(await asyncio.to_thread(opened.wait,1))
                first.cancel(); await asyncio.gather(first,return_exceptions=True)
                second=asyncio.create_task(independent.extract('fictional cancelled waiter','typed',None))
                self.assertTrue(await asyncio.to_thread(queued.wait,1))
                self.assertEqual(calls,1,'A cancelled active socket must retain its shared capacity')
                second.cancel(); await asyncio.gather(second,return_exceptions=True)
                release.set()
                result=await asyncio.wait_for(independent.extract('fictional recovery','typed',None),timeout=2)
                self.assertEqual(result['claims'][0]['quote'],'fictional recovery')
                self.assertEqual(calls,2,'The cancelled waiter must never dispatch later')
            finally:
                release.set()
                for task in (first,second):
                    if task: task.cancel()
                await asyncio.gather(*(task for task in (first,second) if task),return_exceptions=True)

    async def test_worker_failures_release_capacity(self):
        from backend.providers import _run_bounded_transport
        slots=threading.BoundedSemaphore(1)
        cancelled=threading.Event()
        def fail(): raise RuntimeError('fictional transport failure')
        with patch('backend.providers._PROVIDER_TRANSPORT_SLOTS',slots):
            with self.assertRaises(RuntimeError): await asyncio.to_thread(_run_bounded_transport,fail,cancelled,1)
            self.assertEqual(await asyncio.to_thread(_run_bounded_transport,lambda:'recovered',cancelled,1),'recovered')

    async def test_waiting_for_transport_capacity_is_bounded_without_dispatch(self):
        from backend.providers import _run_bounded_transport
        slots=threading.BoundedSemaphore(1); slots.acquire()
        def never(): self.fail('Waiting requests must not dispatch after their capacity timeout')
        try:
            with patch('backend.providers._PROVIDER_TRANSPORT_SLOTS',slots),self.assertRaises(ProviderError):
                await asyncio.to_thread(_run_bounded_transport,never,threading.Event(),0.02)
        finally: slots.release()


class GatewayDisclosureTests(unittest.IsolatedAsyncioTestCase):
    call=test_gateway.GatewayTests.call

    async def test_mutated_metadata_is_rejected_without_disclosure(self):
        provider=CompatibleProvider("https://api.example/v1","unit-test-private-key","model")
        app=Gateway([TOKEN],Router(provider))
        object.__setattr__(provider,"model","sk-proj-fictional-test-only")
        status,body,_=await self.call(app=app,path="/v1/config",method="GET")
        self.assertEqual(status,503); self.assertEqual(body["errorCode"],"provider_configuration")
        self.assertNotIn("sk-proj",json.dumps(body)); self.assertNotIn("private-key",json.dumps(body))

    async def test_gateway_token_mutated_into_metadata_is_rejected_without_disclosure(self):
        for field,value in (('model','model/'+TOKEN),('base_url','https://api.example/'+TOKEN+'/v1')):
            provider=CompatibleProvider('https://api.example/v1','unit-test-private-key','model')
            app=Gateway([TOKEN],Router(provider))
            object.__setattr__(provider,field,value)
            status,body,_=await self.call(app=app,path='/v1/config',method='GET')
            self.assertEqual(status,503); self.assertEqual(body['errorCode'],'provider_configuration')
            self.assertNotIn(TOKEN,json.dumps(body))

    async def test_safe_failure_code_reaches_client_without_provider_content(self):
        class Broken:
            async def extract(self,*args): raise ProviderError("private provider response",code="provider_authentication")
        app=Gateway([TOKEN],Router(Broken()))
        status,body,_=await self.call(app=app,path="/v1/check",value={"schemaVersion":VERSION})
        self.assertEqual(status,503); self.assertEqual(body["errorCode"],"provider_authentication")
        self.assertNotIn("private provider response",json.dumps(body))

    async def test_malformed_source_kind_is_a_validation_error_before_forwarding(self):
        class Never:
            async def extract(self,*args): raise AssertionError("Malformed inputs cannot reach the model")
        app=Gateway([TOKEN],Router(Never()))
        for kind in ([], {}, True):
            status,_,_=await self.call(app=app,value={"schemaVersion":VERSION,"text":"fictional evidence","sourceKind":kind,"consent":True})
            self.assertEqual(status,422)

    async def test_disconnected_queued_request_never_starts_provider_work(self):
        calls=0
        class Counted:
            async def extract(self,text,*args):
                nonlocal calls
                calls+=1
                return envelope(text)
        app=Gateway([TOKEN],Router(Counted()),max_inflight=1)
        await app.semaphore.acquire()
        queue=asyncio.Queue(); output=[]
        await queue.put({'type':'http.request','body':json.dumps({'schemaVersion':VERSION,'text':'fictional evidence','sourceKind':'typed','consent':True,'providerConfigurationID':app.configuration_id}).encode(),'more_body':False})
        async def send(event): output.append(event)
        task=asyncio.create_task(app({'type':'http','path':'/v1/extract','method':'POST','headers':[(b'authorization',('Bearer '+TOKEN).encode()),(b'content-type',b'application/json')]},queue.get,send))
        # Yield until the full body has been consumed and the request is queued.
        while not queue.empty(): await asyncio.sleep(0)
        await queue.put({'type':'http.disconnect'})
        try:
            # Completion must not depend on the unavailable provider slot.
            await asyncio.wait_for(task,timeout=1)
            self.assertEqual(calls,0); self.assertEqual(output,[])
        finally:
            app.semaphore.release()
            task.cancel(); await asyncio.gather(task,return_exceptions=True)

    async def test_already_disconnected_request_is_not_forwarded(self):
        class Never:
            async def extract(self,*args): raise AssertionError('Disconnected evidence must not be forwarded')
        app=Gateway([TOKEN],Router(Never()))
        queue=asyncio.Queue(); output=[]
        await queue.put({'type':'http.request','body':json.dumps({'schemaVersion':VERSION,'text':'fictional evidence','sourceKind':'typed','consent':True,'providerConfigurationID':app.configuration_id}).encode(),'more_body':False})
        await queue.put({'type':'http.disconnect'})
        async def send(event): output.append(event)
        await app({'type':'http','path':'/v1/extract','method':'POST','headers':[(b'authorization',('Bearer '+TOKEN).encode()),(b'content-type',b'application/json')]},queue.get,send)
        self.assertEqual(output,[])


class SchemaHardeningTests(unittest.TestCase):
    def test_escaped_lone_surrogates_cannot_reach_provider_or_response_encoding(self):
        source=loads('{"schemaVersion":"'+VERSION+'","text":"fictional \\ud800","sourceKind":"typed","consent":true}')
        with self.assertRaises(ValidationError): validate_request(source)
        for key in ('label','quote','value','speaker','clarification','code'):
            with self.subTest(key=key),self.assertRaises(ValidationError):
                validate_envelope(envelope(**{key:'fictional \udfff'}),'fictional evidence')

    def test_complete_unicode_and_multiline_evidence_remain_supported(self):
        text=loads('"First line\\n\\ud83d\\ude00 Café Ελληνικά 中文"')
        validate_request({'schemaVersion':VERSION,'text':text,'sourceKind':'typed','consent':True})
        result=validate_envelope(envelope(text,label='Café 😀'),'First line\n😀 Café Ελληνικά 中文')
        self.assertIn('😀',result['claims'][0]['quote'])

    def test_null_attribution_becomes_explicit_uncertainty(self):
        claim=validate_envelope(envelope(subject=None,confidence=None,certainty=None,speakerUncertain=None),"A patient-owned note")["claims"][0]
        self.assertEqual(claim["subject"],"unknown"); self.assertEqual(claim["confidence"],0)
        self.assertEqual(claim["certainty"],"uncertain"); self.assertTrue(claim["speakerUncertain"])

    def test_collection_values_in_enums_are_rejected_consistently(self):
        for key in ("kind","action","certainty","subject","duePrecision"):
            for value in ([],{}):
                with self.subTest(key=key,type=type(value).__name__), self.assertRaises(ValidationError):
                    validate_envelope(envelope(**{key:value}),"A patient-owned note")

    def test_extremely_large_integer_is_not_a_supported_numeric_value(self):
        with self.assertRaises(ValidationError): validate_envelope(envelope(numericValue=10**400),"A patient-owned note")

    def test_deeply_nested_json_is_rejected_as_invalid_input(self):
        with self.assertRaises(ValidationError): loads('['*3000+'0'+']'*3000)

    def test_nested_punctuation_in_evidence_is_not_json_nesting(self):
        text='["quoted"]\\'+'{'*1000+'\\\\"closing"'
        self.assertEqual(loads(json.dumps({'text':text}))['text'],text)


class VerificationToolTests(unittest.TestCase):
    def config(self,provider=None):
        return {"schemaVersion":VERSION,"configurationID":"a"*64,"providers":{"primary":provider or Router(MockProvider()).configuration()["primary"],"fallback":None},"maxSourceCharacters":40000,"patientContentStored":False}

    def test_verification_never_echoes_secretlike_old_gateway_metadata(self):
        config=self.config({"adapter":"openai","model":"sk-proj-fictional-visible-mistake","host":"api.openai.com","maxOutputTokens":6000})
        with patch("backend.verify_gateway.fetch",side_effect=[({"passed":True},{"status":"ok","schemaVersion":VERSION}),({"passed":True},config)]):
            report=verify("https://gateway.example",TOKEN)
        self.assertEqual(report["configuration"]["error"],"unsafe_or_invalid_configuration")
        self.assertNotIn("sk-proj",json.dumps(report)); self.assertEqual(report["paidRequestsAttempted"],0)

    def test_verification_never_echoes_its_gateway_token_in_old_model_or_host_metadata(self):
        for model,host in ((TOKEN,'api.example'),('model/'+TOKEN+'/pinned','api.example'),('model',TOKEN+'.example')):
            config=self.config({'adapter':'openai','model':model,'host':host,'maxOutputTokens':6000})
            with patch('backend.verify_gateway.fetch',side_effect=[({'passed':True},{'status':'ok','schemaVersion':VERSION}),({'passed':True},config)]) as fetch:
                report=verify('https://gateway.example',TOKEN,synthetic=True,extract=True)
            self.assertEqual(fetch.call_count,2); self.assertEqual(report['paidRequestsAttempted'],0)
            self.assertEqual(report['configuration']['error'],'unsafe_or_invalid_configuration')
            self.assertNotIn(TOKEN,json.dumps(report))

    def test_gateway_token_in_verification_origin_is_rejected_before_network(self):
        with patch('backend.verify_gateway.fetch') as fetch,self.assertRaises(ValueError) as caught:
            verify('https://'+TOKEN+'.example',TOKEN)
        fetch.assert_not_called(); self.assertNotIn(TOKEN,str(caught.exception))

    def test_no_credentials_means_only_public_health_is_requested(self):
        with patch("backend.verify_gateway.fetch",return_value=({"passed":True},{"status":"ok","schemaVersion":VERSION})) as fetch:
            report=verify("https://gateway.example","")
        self.assertEqual(fetch.call_count,1); self.assertFalse(report["liveInferenceVerified"])

    def test_mock_success_is_not_reported_as_real_model_verification(self):
        config=self.config()
        check={"schemaVersion":VERSION,"status":"ok","route":"primary","providers":config["providers"],"syntheticOnly":True}
        with patch("backend.verify_gateway.fetch",side_effect=[({"passed":True},{"status":"ok","schemaVersion":VERSION}),({"passed":True},config),({"passed":True},check)]):
            report=verify("https://gateway.example",TOKEN,synthetic=True)
        self.assertTrue(report["connectionCheck"]["passed"]); self.assertFalse(report["liveInferenceVerified"])

    def test_fictional_extraction_report_contains_counts_not_evidence(self):
        with patch("backend.verify_gateway.fetch",side_effect=[({"passed":True},{"status":"ok","schemaVersion":VERSION}),({"passed":True},self.config()),({"passed":True},envelope(FICTIONAL_SOURCE))]):
            report=verify("https://gateway.example",TOKEN,extract=True)
        self.assertEqual(report["fictionalExtraction"]["claimCount"],1)
        self.assertNotIn("Alex",json.dumps(report)); self.assertNotIn(TOKEN,json.dumps(report))

    def test_compatible_host_ports_and_explicit_mock_are_valid(self):
        safe_provider({"adapter":"compatible","model":"Qwen/model","host":"api.example:8443","maxOutputTokens":6000})
        safe_provider(Router(MockProvider()).configuration()["primary"])

    def test_server_environment_requires_opt_in_and_never_makes_paid_calls_by_default(self):
        second_token='second-unit-test-token-'+('x'*40)
        output=io.StringIO()
        with patch.dict(os.environ,{'CARE_BACKEND_TOKENS':TOKEN+','+second_token},clear=True),patch('sys.argv',['verify_gateway','--server-environment']),patch('sys.stdin.read',side_effect=AssertionError('Server verification must not copy credentials through stdin')),patch('backend.verify_gateway.fetch',side_effect=[({'passed':True},{'status':'ok','schemaVersion':VERSION}),({'passed':True},self.config())]) as fetch,contextlib.redirect_stdout(output):
            verify_main()
        self.assertEqual(fetch.call_count,2)
        self.assertEqual(fetch.call_args_list[1].args,('https://careinone-api.onrender.com','/v1/config',TOKEN))
        report=json.loads(output.getvalue()); self.assertEqual(report['paidRequestsAttempted'],0)
        self.assertNotIn(TOKEN,output.getvalue()); self.assertNotIn(second_token,output.getvalue())

    def test_server_tokens_are_not_implicitly_used_without_server_environment_flag(self):
        output=io.StringIO()
        with patch.dict(os.environ,{'CARE_BACKEND_TOKENS':TOKEN},clear=True),patch('sys.argv',['verify_gateway']),patch('backend.verify_gateway.fetch',return_value=({'passed':True},{'status':'ok','schemaVersion':VERSION})) as fetch,contextlib.redirect_stdout(output),self.assertRaises(SystemExit) as caught:
            verify_main()
        self.assertEqual(caught.exception.code,1); self.assertEqual(fetch.call_count,1)
        report=json.loads(output.getvalue()); self.assertEqual(report['paidRequestsAttempted'],0)
        self.assertEqual(report['configuration']['error'],'gateway_token_unavailable')
        self.assertNotIn(TOKEN,output.getvalue())
