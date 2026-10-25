import unittest
from backend.app import Gateway
from backend.providers import MockProvider,Router
from web.combined import Combined
from web.tests import test_server as helpers
CODE,TOKEN,SECRET=helpers.CODE,helpers.TOKEN,helpers.SECRET

class CombinedTests(unittest.IsolatedAsyncioTestCase):
    request=helpers.WebTests.request
    login=helpers.WebTests.login
    def setUp(self):
        self.calls=[]
        self.gateway=Gateway([TOKEN],Router(MockProvider()))
        self.combined=Combined(self.gateway,TOKEN,secret=SECRET,codes=[CODE])
        self.app=self.combined.web
    async def test_real_gateway_configuration_and_extract(self):
        cookie=await self.login();status,_,body=await self.request('/api/config',cookie=cookie)
        import json
        self.assertEqual(status,200);config=json.loads(body)
        self.assertEqual(config['providers']['primary']['adapter'],'mock')
        payload={'schemaVersion':'care-schema-1.0','text':'Fictional follow-up appointment requested.','sourceKind':'typed','consent':True,'providerConfigurationID':config['configurationID']}
        status,_,body=await self.request('/api/extract','POST',payload,cookie)
        self.assertEqual(status,200);claims=json.loads(body)['claims'];self.assertTrue(claims)
        for c in claims:self.assertIn(c['quote'],payload['text'])
    async def test_legacy_mobile_health_and_auth_routes_preserved(self):
        status,_,body=await self.request('/health',app=self.combined)
        import json
        self.assertEqual(json.loads(body),{'status':'ok','schemaVersion':'care-schema-1.0'})
        self.assertEqual((await self.request('/v1/config',app=self.combined))[0],401)
        self.assertEqual((await self.request('/v1/config',extra=[(b'authorization',('Bearer '+TOKEN).encode())],app=self.combined))[0],200)
    async def test_native_public_documents_still_serve(self):
        for path in ['/privacy','/support']:self.assertEqual((await self.request(path,app=self.combined))[0],200)
    def test_bad_internal_token_fails_startup(self):
        with self.assertRaises(ValueError):Combined(self.gateway,'wrong-token'+('a'*32),secret=SECRET,codes=[CODE])

    async def test_native_host_and_multiple_mobile_tokens_survive_domain_cutover(self):
        import asyncio,json
        mobile_a='mobile-a-'+('a'*40); mobile_b='mobile-b-'+('b'*40); bridge='web-bridge-'+('c'*40)
        gateway=Gateway([mobile_a,mobile_b,bridge],Router(MockProvider()))
        app=Combined(gateway,bridge,origin='https://care.example.org',secret=SECRET,codes=[CODE])
        async def native_request(path,token=None):
            events=[]
            async def receive():return {'type':'http.request','body':b'','more_body':False}
            async def send(event):events.append(event)
            headers=[(b'host',b'careinone-api.onrender.com')]
            if token:headers.append((b'authorization',('Bearer '+token).encode()))
            await app({'type':'http','method':'GET','path':path,'headers':headers},receive,send)
            return events[0]['status'],json.loads(events[1]['body'])
        for token in (mobile_a,mobile_b):
            status,body=await native_request('/v1/config',token)
            self.assertEqual(status,200);self.assertFalse(body['patientContentStored'])
        self.assertEqual((await native_request('/health'))[1],{'status':'ok','schemaVersion':'care-schema-1.0'})
        self.assertEqual((await native_request('/v1/config'))[0],401)
        self.assertEqual((await native_request('/'))[0],400)

    async def test_explicit_local_only_web_fallback_preserves_native_api(self):
        app=Combined(self.gateway,TOKEN,web_cloud_enabled=False)
        self.assertEqual((await self.request('/',app=app))[0],200)
        import json
        self.assertFalse(json.loads((await self.request('/api/status',app=app))[2])['enabled'])
        self.assertEqual((await self.request('/api/login','POST',{'code':CODE},app=app))[0],503)
        self.assertEqual((await self.request('/v1/config',extra=[(b'authorization',('Bearer '+TOKEN).encode())],app=app))[0],200)

    def test_cloud_flag_rejects_ambiguous_values(self):
        from unittest.mock import patch
        from web.server import cloud_enabled
        with patch.dict('os.environ',{'CARE_WEB_CLOUD_ENABLED':'false'}):self.assertFalse(cloud_enabled())
        with patch.dict('os.environ',{'CARE_WEB_CLOUD_ENABLED':'true'}):self.assertTrue(cloud_enabled())
        with patch.dict('os.environ',{'CARE_WEB_CLOUD_ENABLED':'maybe'}):
            with self.assertRaises(ValueError):cloud_enabled()
