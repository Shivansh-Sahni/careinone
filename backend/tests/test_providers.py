import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from backend.configure import load_configuration, write_configuration
from backend.providers import CompatibleProvider, ProviderError, Router, router_from_environment
from backend.schema import VERSION
from backend.tests import test_gateway
from backend.tests.test_gateway import TOKEN, request
from backend.app import Gateway


class ProviderTests(unittest.IsolatedAsyncioTestCase):
    def provider(self, **kwargs): return CompatibleProvider('https://api.example/v1', 'private-key', 'selected-model', **kwargs)

    def test_openai_uses_current_token_parameter_and_does_not_request_storage(self):
        body = self.provider(adapter='openai').request_body('Evidence', 'typed', None)
        self.assertEqual(body['max_completion_tokens'], 6000)
        self.assertFalse(body['store']); self.assertNotIn('max_tokens', body)
        self.assertNotIn('temperature', body); self.assertNotIn('tools', body)

    def test_kimi_environment_omits_incompatible_temperature(self):
        with patch.dict(os.environ, {'CARE_PROVIDER':'kimi', 'CARE_MODEL_API_KEY':'private-key', 'CARE_MODEL_NAME':'kimi-k2.6'}, clear=True):
            primary = router_from_environment().primary
        body = primary.request_body('Evidence', 'typed', None)
        self.assertEqual(primary.base_url, 'https://api.moonshot.ai/v1')
        self.assertEqual(body['thinking'], {'type':'disabled'})
        self.assertNotIn('temperature', body); self.assertEqual(body['max_tokens'], 6000)

    def test_fallback_adapter_has_independent_parameters(self):
        values = {'CARE_PROVIDER':'kimi', 'CARE_MODEL_API_KEY':'a', 'CARE_MODEL_NAME':'kimi-k2.6', 'CARE_FALLBACK_PROVIDER':'openai', 'CARE_FALLBACK_API_KEY':'b', 'CARE_FALLBACK_MODEL':'selected-model', 'CARE_FALLBACK_MAX_OUTPUT_TOKENS':'1000'}
        with patch.dict(os.environ, values, clear=True): router = router_from_environment()
        body = router.fallback.request_body('Evidence', 'typed', None)
        self.assertEqual(body['max_completion_tokens'], 1000); self.assertNotIn('thinking', body)

    def test_partial_fallback_fails_at_startup(self):
        with patch.dict(os.environ, {'CARE_PROVIDER':'openai', 'CARE_MODEL_API_KEY':'a', 'CARE_MODEL_NAME':'chosen', 'CARE_FALLBACK_API_KEY':'b'}, clear=True):
            with self.assertRaises(ProviderError): router_from_environment()

    def test_secret_not_in_repr_or_configuration(self):
        primary = self.provider()
        self.assertNotIn('private-key', repr(primary) + json.dumps(Router(primary).configuration()))

    async def model_response(self, choice):
        raw = io.BytesIO(json.dumps({'choices':[choice]}).encode())
        with patch('urllib.request.build_opener') as opener:
            opener.return_value.open.return_value.__enter__.return_value = raw
            return await self.provider().extract('Evidence', 'typed', None)

    async def test_rejects_truncated_refused_and_tool_responses(self):
        content = json.dumps({'schemaVersion':VERSION, 'claims':[]})
        for choice in [
            {'finish_reason':'length','message':{'content':content}},
            {'finish_reason':'stop','message':{'content':content,'refusal':'Declined'}},
            {'finish_reason':'stop','message':{'content':content,'tool_calls':[{}]}},
            {'finish_reason':'stop','message':{'content':None}}]:
            with self.subTest(choice=choice), self.assertRaises(ProviderError): await self.model_response(choice)

    async def test_complete_valid_response_is_validated(self):
        result = await self.model_response({'finish_reason':'stop', 'message':{'content':json.dumps({'schemaVersion':VERSION, 'claims':[{'kind':'other','label':'Evidence','quote':'Evidence'}]})}})
        self.assertEqual(result['claims'][0]['quote'], 'Evidence')

    def test_configuration_bounds(self):
        for values in ({'max_output_tokens':20}, {'temperature':float('nan')}, {'thinking':'whatever'}, {'reasoning_effort':'unlimited'}):
            with self.subTest(values=values), self.assertRaises(ProviderError): self.provider(**values)


class ConnectionTests(unittest.IsolatedAsyncioTestCase):
    call = test_gateway.GatewayTests.call
    async def test_missing_or_changed_recipient_consent_prevents_provider_call(self):
        class Never:
            async def extract(self,*args): raise AssertionError('Patient content must not reach a changed recipient')
        app=Gateway([TOKEN],Router(Never()))
        for value in (request(), {**request(),'providerConfigurationID':'0'*64}):
            status, _, _ = await self.call(app=app, raw=json.dumps(value).encode())
            self.assertEqual(status,409)
    async def test_configuration_requires_auth_and_never_calls_model(self):
        class Never:
            async def extract(self, *args): raise AssertionError('No model calls on config GET')
        app = Gateway([TOKEN], Router(Never()))
        status, body, headers = await self.call(app=app, path='/v1/config', method='GET')
        self.assertEqual(status, 200); self.assertFalse(body['patientContentStored'])
        self.assertEqual(headers[b'cache-control'], b'no-store'); self.assertNotIn(TOKEN, json.dumps(body))
        self.assertEqual((await self.call(app=app,path='/v1/config',method='GET',headers=[]))[0],401)

    async def test_check_accepts_only_fixed_synthetic_request(self):
        status, body, _ = await self.call(path='/v1/check', value={'schemaVersion':VERSION})
        self.assertEqual(status,200); self.assertTrue(body['syntheticOnly']); self.assertEqual(body['route'],'primary')
        self.assertEqual((await self.call(path='/v1/check',value=request('Patient data')))[0],422)

    async def test_check_reports_fallback(self):
        from backend.providers import MockProvider
        class Broken:
            async def extract(self,*args): raise ProviderError('No connection')
        app = Gateway([TOKEN],Router(Broken(),MockProvider()))
        status, body, _ = await self.call(app=app,path='/v1/check',value={'schemaVersion':VERSION})
        self.assertEqual(status,200); self.assertEqual(body['route'],'fallback')

    async def test_source_limit_rejects_before_model_call(self):
        app = Gateway([TOKEN], Router(None), max_source_characters=1000)
        self.assertEqual((await self.call(app=app,value=request('x'*1001)))[0],413)

    async def test_duplicate_content_headers_rejected(self):
        headers=[(b'authorization',('Bearer '+TOKEN).encode()),(b'content-type',b'application/json'),(b'content-type',b'text/plain')]
        self.assertEqual((await self.call(headers=headers))[0],400)


class ConfigurationTests(unittest.TestCase):
    def test_example_and_control_character_tokens_are_rejected(self):
        for token in ('replace-with-a-random-token-at-least-32-characters', 'x'*40+'\n', 'x'*4001):
            with self.subTest(token_length=len(token)), self.assertRaises(ValueError): Gateway([token],Router(None))
    def test_secret_file_exclusive_private_round_trip(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'.env'; values={'CARE_MODEL_API_KEY':'literal $(echo bad) `command` "quoted"', 'CARE_PROVIDER':'compatible'}
            write_configuration(path,values)
            self.assertEqual(load_configuration(path),values)
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            with self.assertRaises(FileExistsError): write_configuration(path,{'CARE_PROVIDER':'mock'})
            self.assertEqual(load_configuration(path),values)

    def test_duplicate_or_malformed_config_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'.env'
            for content in ('CARE_PROVIDER=a\nCARE_PROVIDER=b','export CARE_PROVIDER=a','CARE_A="broken','HOME=x'):
                path.write_text(content)
                with self.subTest(content=content), self.assertRaises(ValueError): load_configuration(path)
