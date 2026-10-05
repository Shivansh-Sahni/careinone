import json
from pathlib import Path
import shlex
import unittest
from unittest.mock import patch

from backend.app import Gateway
from backend.providers import MockProvider, Router
from backend.tests.test_gateway import TOKEN


class PublicPageTests(unittest.IsolatedAsyncioTestCase):
    async def call(self, path='/privacy', method='GET', query=b'', headers=()):
        app=Gateway([TOKEN],Router(MockProvider()),rate=1)
        output=[]
        async def receive():
            self.fail('Public documents must not consume submitted content')
        async def send(event): output.append(event)
        await app({'type':'http','path':path,'method':method,'query_string':query,'headers':headers},receive,send)
        self.assertEqual(len(app.limits),0)
        return output[0]['status'],output[-1]['body'],dict(output[0]['headers'])

    async def test_both_reviewed_pages_are_available_without_authentication(self):
        for path,title in (('/privacy',b'Privacy'),('/support',b'Support')):
            with self.subTest(path=path):
                status,body,headers=await self.call(path)
                self.assertEqual(status,200)
                self.assertIn(title,body); self.assertIn(b'CareInOne',body)
                self.assertEqual(headers[b'content-type'],b'text/html; charset=utf-8')
                self.assertEqual(int(headers[b'content-length']),len(body))
                self.assertNotIn(b'<script',body.lower())
                self.assertNotIn(b'sk-proj-',body); self.assertNotIn(TOKEN.encode(),body)

    async def test_documents_are_isolated_from_query_and_headers(self):
        status,normal,_=await self.call()
        malicious=b'secret_marker=fictional-secret&file=../providers.py&content=%3Cscript%3E'
        status,body,_=await self.call(query=malicious,headers=[(b'authorization',b'Bearer fictional-secret'),(b'cookie',b'secret_marker=fictional-secret')])
        self.assertEqual(status,200); self.assertEqual(body,normal)
        self.assertNotIn(b'fictional-secret',body); self.assertNotIn(b'secret_marker',body)

    async def test_static_documents_have_restrictive_security_headers(self):
        for path in ('/privacy','/support'):
            _,_,headers=await self.call(path)
            self.assertEqual(headers[b'cache-control'],b'no-store')
            self.assertEqual(headers[b'x-content-type-options'],b'nosniff')
            self.assertEqual(headers[b'referrer-policy'],b'no-referrer')
            self.assertEqual(headers[b'x-frame-options'],b'DENY')
            policy=headers[b'content-security-policy']
            for directive in (b"default-src 'none'",b"base-uri 'none'",b"form-action 'none'",b"frame-ancestors 'none'"):
                self.assertIn(directive,policy)

    async def test_head_preserves_headers_without_document_body(self):
        _,body,get_headers=await self.call('/support')
        status,head,headers=await self.call('/support',method='HEAD')
        self.assertEqual(status,200); self.assertEqual(head,b'')
        self.assertEqual(headers,get_headers); self.assertEqual(int(headers[b'content-length']),len(body))

    async def test_document_mutations_are_not_allowed(self):
        for method in ('POST','PUT','DELETE','PATCH','OPTIONS'):
            with self.subTest(method=method):
                status,body,headers=await self.call(method=method)
                self.assertEqual(status,405); self.assertEqual(headers[b'allow'],b'GET, HEAD')
                self.assertEqual(json.loads(body),{'error':'Method not allowed'})

    async def test_traversal_and_non_allowlisted_files_cannot_be_read(self):
        for path in ('/privacy/../providers.py','/privacy%2f..%2fproviders.py','/public/privacy.html','/backend/.env','/support/','//privacy','/../backend/providers.py','/privacy.html'):
            with self.subTest(path=path), patch('pathlib.Path.read_bytes',side_effect=AssertionError('Unknown paths must not read a file')):
                status,body,_=await self.call(path)
                self.assertEqual(status,404); self.assertEqual(json.loads(body),{'error':'Not found'})

    async def test_missing_oversized_or_non_utf8_document_fails_without_file_details(self):
        for value in (FileNotFoundError('fictional private filesystem path'),b'x'*200_001,b'\xff'):
            with self.subTest(case=type(value).__name__):
                kwargs={'side_effect':value} if isinstance(value,Exception) else {'return_value':value}
                with patch('pathlib.Path.read_bytes',**kwargs): status,body,_=await self.call()
                self.assertEqual(status,503)
                self.assertEqual(json.loads(body),{'error':'Public information is temporarily unavailable'})


class RuntimePackagingTests(unittest.TestCase):
    def test_docker_runtime_includes_public_pages_and_excludes_credentials(self):
        root=Path(__file__).resolve().parents[1]
        docker=(root/'Dockerfile').read_text()
        copied=set()
        for line in docker.splitlines():
            words=shlex.split(line)
            if words and words[0]=='COPY': copied.update(words[1:-1])
        allowed={'backend/requirements.lock','backend/app.py','backend/schema.py','backend/providers.py','backend/__init__.py','backend/public/privacy.html','backend/public/support.html'}
        self.assertEqual(copied,allowed)
        context=root.parent
        ignore=(context/'.dockerignore').read_text().splitlines()
        self.assertIn('**',ignore)
        for source in copied:
            with self.subTest(source=source):
                self.assertTrue((context/source).is_file()); self.assertIn('!'+source,ignore)
        self.assertIn('!backend/public/',ignore)
        self.assertFalse(any('env' in source or 'test' in source for source in copied))
