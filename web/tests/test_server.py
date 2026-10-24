import asyncio
import hashlib
import json
import unittest
from web.server import Web, NoRedirect
TOKEN='gateway_'+('x'*40)
CODE='invite_'+('y'*40)
SECRET='session_'+('z'*40)
CONFIG={'schemaVersion':'care-schema-1.0','configurationID':'a'*64,'providers':{'primary':{'adapter':'mock','model':'synthetic-development','host':'local development','maxOutputTokens':0},'fallback':None},'maxSourceCharacters':40000}
class WebTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.calls=[]
        def transport(path,body):
            self.calls.append((path,body))
            return (200,CONFIG) if path=='/v1/config' else (200,{'schemaVersion':'care-schema-1.0','claims':[{'kind':'other','label':'Test','quote':body['text'],'subject':'patient','certainty':'reported'}]})
        self.app=Web(gateway_url='https://api.example.test',gateway_token=TOKEN,secret=SECRET,codes=[CODE],transport=transport,daily_limit=2,global_limit=4)
    async def request(self,path='/',method='GET',body=None,cookie=None,origin='http://127.0.0.1:8080',extra=(),app=None):
        sent=[];received=False
        headers=[(b'host',b'127.0.0.1:8080')]
        if method=='POST':headers.extend([(b'content-type',b'application/json'),(b'x-careinone-request',b'1'),(b'origin',origin.encode())])
        if cookie:headers.append((b'cookie',cookie))
        headers.extend(extra)
        async def receive():
            nonlocal received
            if not received:received=True;return {'type':'http.request','body':json.dumps(body or {}).encode(),'more_body':False}
            await asyncio.sleep(100)
        async def send(event):sent.append(event)
        await (app or self.app)({'type':'http','path':path,'method':method,'headers':headers,'client':('127.0.0.1',123)},receive,send)
        start=sent[0];data=sent[1]['body'];return start['status'],dict(start['headers']),data
    async def login(self):
        status,headers,body=await self.request('/api/login','POST',{'code':CODE})
        self.assertEqual(status,200);self.assertNotIn(TOKEN.encode(),body)
        return headers[b'set-cookie'].split(b';')[0]
    async def test_static_assets_and_security_headers(self):
        for path in ['/','/app.js','/core.js','/storage.js','/style.css','/icon.svg']:
            status,headers,data=await self.request(path)
            self.assertEqual(status,200);self.assertTrue(data);self.assertEqual(headers[b'cache-control'],b'no-store');self.assertEqual(headers[b'x-frame-options'],b'DENY');self.assertIn(b"frame-ancestors 'none'",headers[b'content-security-policy']);self.assertNotIn(TOKEN.encode(),data)
    async def test_fixed_file_allowlist_blocks_secrets_and_traversal(self):
        for path in ['/.env','/../server.py','/public/../server.py','/server.py','/api/anything']:
            self.assertEqual((await self.request(path))[0],404)
    async def test_head_and_methods(self):
        self.assertEqual((await self.request('/','HEAD'))[2],b'')
        self.assertEqual((await self.request('/','POST'))[0],405)
    async def test_host_header_validation(self):
        self.assertEqual((await self.request('/',extra=[(b'host',b'evil.test')]))[0],400)
    async def test_health_and_local_only_mode(self):
        local=Web();self.assertEqual((await self.request('/health',app=local))[0],200)
        result=await self.request('/api/status',app=local);self.assertFalse(json.loads(result[2])['enabled'])
        self.assertEqual((await self.request('/api/login','POST',{'code':CODE},app=local))[0],503)
        self.assertEqual(self.calls,[])
    async def test_csrf_cross_origin_and_missing_request_header_rejected(self):
        self.assertEqual((await self.request('/api/login','POST',{'code':CODE},origin='https://evil.test'))[0],403)
        self.assertEqual((await self.request('/api/login','POST',{'code':CODE},extra=[(b'origin',b'http://127.0.0.1:8080')]))[0],403)
    async def test_unauthenticated_config_and_extract_never_call_gateway(self):
        for path,method in [('/api/config','GET'),('/api/extract','POST')]:self.assertEqual((await self.request(path,method))[0],401)
        self.assertEqual(self.calls,[])
    async def test_session_login_cookie_and_config_do_not_disclose_credentials(self):
        cookie=await self.login();status,headers,body=await self.request('/api/config',cookie=cookie)
        self.assertEqual(status,200);self.assertEqual(json.loads(body)['configurationID'],'a'*64)
        for secret in [TOKEN,CODE,SECRET]:self.assertNotIn(secret.encode(),body)
        _,headers,_=await self.request('/api/login','POST',{'code':CODE});self.assertIn(b'HttpOnly',headers[b'set-cookie']);self.assertIn(b'SameSite=Strict',headers[b'set-cookie'])
    async def test_forged_cookie_rejected(self):
        cookie=await self.login();self.assertEqual((await self.request('/api/config',cookie=cookie+b'forged'))[0],401)
    async def test_invalid_login_is_limited(self):
        for i in range(10):self.assertEqual((await self.request('/api/login','POST',{'code':'wrong'}))[0],401)
        self.assertEqual((await self.request('/api/login','POST',{'code':CODE}))[0],429)
    async def test_validated_extract_and_daily_allowance_shared_across_sessions(self):
        cookie=await self.login();payload={'schemaVersion':'care-schema-1.0','text':'Fictional test source','sourceKind':'typed','consent':True,'providerConfigurationID':'a'*64}
        for i in range(2):self.assertEqual((await self.request('/api/extract','POST',payload,cookie))[0],200)
        cookie2=await self.login();self.assertEqual((await self.request('/api/extract','POST',payload,cookie2))[0],429)
        self.assertEqual(len(self.calls),2)
    async def test_no_consent_never_dispatches(self):
        cookie=await self.login();payload={'schemaVersion':'care-schema-1.0','text':'Test','sourceKind':'typed','consent':False}
        self.assertEqual((await self.request('/api/extract','POST',payload,cookie))[0],422);self.assertEqual(self.calls,[])
    async def test_forged_quote_response_is_rejected(self):
        cookie=await self.login();self.app.transport=lambda *_:(200,{'schemaVersion':'care-schema-1.0','claims':[{'kind':'other','label':'Test','quote':'invented'}]})
        payload={'schemaVersion':'care-schema-1.0','text':'Test source','sourceKind':'typed','consent':True}
        self.assertEqual((await self.request('/api/extract','POST',payload,cookie))[0],422)
    async def test_unsafe_model_metadata_never_reaches_browser(self):
        cookie=await self.login();bad=json.loads(json.dumps(CONFIG));bad['providers']['primary']['model']=TOKEN
        self.app.transport=lambda *_:(200,bad);status,_,body=await self.request('/api/config',cookie=cookie)
        self.assertEqual(status,422);self.assertNotIn(TOKEN.encode(),body)
    async def test_secure_cookie_and_hsts_in_public_mode(self):
        app=Web(origin='https://127.0.0.1:8080',gateway_url='https://api.example.test',gateway_token=TOKEN,secret=SECRET,codes=[CODE])
        status,headers,_=await self.request('/api/login','POST',{'code':CODE},origin='https://127.0.0.1:8080',app=app)
        self.assertEqual(status,200);self.assertIn(b'Secure',headers[b'set-cookie']);self.assertIn(b'strict-transport-security',headers)
    def test_unsafe_production_configuration_fails_closed(self):
        for kwargs in [{'origin':'http://public.test'},{'origin':'https://public.test/path'},{'gateway_url':'http://api.test'},{'gateway_url':'https://api.test'},{'codes':['short']}]:
            with self.assertRaises(ValueError):Web(**kwargs)
    def test_gateway_redirects_are_not_followed(self):self.assertIsNone(NoRedirect().redirect_request(None,None,302,'',{},'https://evil.test'))
if __name__=='__main__':unittest.main()
