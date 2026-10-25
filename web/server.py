"""Same-origin web server; patient records remain in the browser.

Optional cloud access uses capped public sessions or operator-issued codes.
No upstream credential is returned to the browser. No patient content is logged.
"""
from __future__ import annotations
import asyncio
import base64
import hashlib
import hmac
import json
import inspect
import os
from pathlib import Path
import secrets
import threading
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler

PUBLIC = Path(__file__).parent / 'public'
ASSETS = {'/':'index.html','/app.js':'app.js','/core.js':'core.js','/storage.js':'storage.js','/style.css':'style.css','/icon.svg':'icon.svg','/imports.js':'imports.js','/recorder.js':'recorder.js','/insights.js':'insights.js','/notices':'vendor-notices.txt'}
TYPES = {'.html':'text/html; charset=utf-8','.txt':'text/plain; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.gz':'application/gzip','.bcmap':'application/octet-stream','.pfb':'application/octet-stream','.ttf':'font/ttf','.otf':'font/otf','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'}
CSP = "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; media-src 'self' blob: data:; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; object-src 'none'"

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

class Web:
    def __init__(self, origin='http://127.0.0.1:8080', gateway_url='', gateway_token='', secret='', codes=(), transport=None, daily_limit=10, global_limit=100, public_access=False):
        if type(public_access) is not bool:raise ValueError('Public AI access must be explicitly enabled.')
        self.public_access=public_access
        parsed=urlsplit(origin)
        if parsed.scheme not in {'http','https'} or not parsed.hostname or parsed.path not in {'','/'} or parsed.query or parsed.fragment or parsed.username:
            raise ValueError('Set CARE_WEB_ORIGIN to the exact site origin, without a path.')
        self.assets=dict(ASSETS)
        manifest=PUBLIC/'vendor-manifest.json'
        if manifest.is_file():
            for route,file in json.loads(manifest.read_text()).items():
                candidate=PUBLIC/file
                if route.startswith('/vendor/') and file.startswith('vendor/') and '..' not in file.split('/') and candidate.is_file() and candidate.resolve().is_relative_to((PUBLIC/'vendor').resolve()):self.assets[route]=file
        self.origin=origin.rstrip('/'); self.secure=parsed.scheme=='https'
        if not self.secure and parsed.hostname not in {'127.0.0.1','localhost','::1'}: raise ValueError('Public websites require HTTPS.')
        self.host=parsed.netloc.lower()
        if gateway_url:
            upstream=urlsplit(gateway_url)
            if upstream.scheme!='https' or not upstream.hostname or upstream.path not in {'','/'} or upstream.query or upstream.fragment or upstream.username or upstream.password:
                raise ValueError('CARE_WEB_GATEWAY_URL must be an HTTPS origin.')
            if len(gateway_token)<32 or len(secret)<32 or (not codes and not public_access): raise ValueError('Cloud access requires server credentials and either access codes or explicitly enabled public sessions.')
        if any(len(code)<32 or len(code)>200 or any(ord(c)<=32 or ord(c)>126 for c in code) for code in codes): raise ValueError('Each web access code must have 32..200 printable characters.')
        self.gateway_url=gateway_url.rstrip('/'); self.gateway_token=gateway_token
        self.secret=(secret or secrets.token_urlsafe(48)).encode()
        self.code_hashes=tuple(hashlib.sha256(c.encode()).hexdigest() for c in codes)
        self.enabled=bool(gateway_url); self.limits={}; self.transport=transport or self.forward
        self.daily_limit=int(daily_limit); self.global_limit=int(global_limit)
        if not 1<=self.daily_limit<=100 or not 1<=self.global_limit<=1000: raise ValueError('Cloud limits must be bounded positive integers.')
        self.transport_slots=threading.BoundedSemaphore(4)
    def limited(self,key,limit,seconds):
        now=time.time(); expired=[k for k,v in self.limits.items() if v[0]<=now]
        for k in expired: del self.limits[k]
        end,count=self.limits.get(key,(now+seconds,0))
        if count>=limit:return True
        if len(self.limits)>=10000 and key not in self.limits:return True
        self.limits[key]=(end,count+1);return False
    def cookie(self,value='',age=0):
        return ('care_web='+value+f'; Path=/api; HttpOnly; SameSite=Strict; Max-Age={age}'+('; Secure' if self.secure else '')).encode()
    def signed_cookie(self,identifier,age=28800):
        expires=int(time.time()+age);signed=f'{identifier}.{expires}'
        signature=hmac.new(self.secret,signed.encode(),hashlib.sha256).hexdigest()
        return self.cookie(signed+'.'+signature,age)
    def session(self,headers):
        try:
            cookies=headers.get(b'cookie',b'').decode().split(';')
            raw=next(x.strip().split('=',1)[1] for x in cookies if x.strip().startswith('care_web='))
            identifier,expires,signature=raw.split('.')
            expected=hmac.new(self.secret,f'{identifier}.{expires}'.encode(),hashlib.sha256).hexdigest()
            if not hmac.compare_digest(signature,expected) or int(expires)<time.time():return None
            public_id=self.public_access and len(identifier)==65 and identifier.startswith('p') and all(c in '0123456789abcdef' for c in identifier[1:])
            if identifier not in self.code_hashes and not public_id:return None
            return identifier
        except (ValueError,StopIteration,UnicodeError):return None
    async def respond(self,send,status,value,content_type='application/json',extra=(),head=False):
        body=value if isinstance(value,bytes) else json.dumps(value,separators=(',',':')).encode()
        headers=[(b'content-type',content_type.encode()),(b'content-length',str(len(body)).encode()),(b'cache-control',b'no-store'),(b'x-content-type-options',b'nosniff'),(b'x-frame-options',b'DENY'),(b'referrer-policy',b'no-referrer'),(b'content-security-policy',CSP.encode()),(b'permissions-policy',b'camera=(), microphone=(self), geolocation=()'),*extra]
        if self.secure:headers.append((b'strict-transport-security',b'max-age=31536000'))
        await send({'type':'http.response.start','status':status,'headers':headers})
        await send({'type':'http.response.body','body':b'' if head else body})
    async def body(self,scope,receive):
        pairs=scope.get('headers',[]);headers=dict(pairs)
        for name in (b'content-type',b'content-length',b'content-encoding'):
            if sum(k==name for k,v in pairs)>1:raise ValueError('Ambiguous headers')
        if headers.get(b'content-type',b'').split(b';')[0]!=b'application/json' or headers.get(b'content-encoding',b'identity')!=b'identity':raise ValueError('Use uncompressed JSON')
        data=bytearray()
        async with asyncio.timeout(15):
            while True:
                message=await receive()
                if message['type']=='http.disconnect':raise ValueError('Disconnected')
                data.extend(message.get('body',b''))
                if len(data)>1200000:raise ValueError('Request too large')
                if not message.get('more_body',False):break
        # Reuse the existing strict parser if repository runtime is available.
        from backend.schema import loads
        value=loads(data)
        if not isinstance(value,dict):raise ValueError('Expected object')
        return value
    def forward(self,path,payload=None):
        # Paths are fixed by server code; visitors never choose upstream URLs.
        if path not in {'/v1/config','/v1/extract'}:raise ValueError('Unsupported upstream route')
        if not self.transport_slots.acquire(blocking=False):return 429,{'error':'Cloud analysis is busy. Try again shortly.'}
        try:
            request=Request(self.gateway_url+path,data=None if payload is None else json.dumps(payload).encode(),headers={'Authorization':'Bearer '+self.gateway_token,'Content-Type':'application/json'},method='GET' if payload is None else 'POST')
            try:
                with build_opener(NoRedirect()).open(request,timeout=175) as response:
                    raw=response.read(1200001)
                    if len(raw)>1200000:raise ValueError('Oversized response')
                    return response.status,json.loads(raw)
            except HTTPError as error:
                # Never reflect arbitrary reverse-proxy HTML or upstream messages.
                status=error.code
                messages={401:'Cloud access needs operator attention.',409:'Analysis recipients changed. Open the connection again and renew consent.',413:'This source exceeds the configured analysis limit.',422:'The source or analysis format was not accepted.',429:'Cloud analysis limit reached. Try again later.',503:'Cloud analysis is unavailable. Your local records are safe.',504:'Analysis timed out. Your local records are safe.'}
                return status if status in messages else 503,{'error':messages.get(status,'Cloud analysis is unavailable. Your local records are safe.')}
        except Exception:
            return 503,{'error':'Cloud analysis is unavailable. Your local records are safe.'}
        finally:self.transport_slots.release()
    async def upstream(self,path,payload=None):
        if inspect.iscoroutinefunction(self.transport):return await self.transport(path,payload)
        return await asyncio.to_thread(self.transport,path,payload)
    async def analysis(self,payload,receive):
        async def wait_disconnect():
            while True:
                event=await receive()
                if event['type']=='http.disconnect':return
        disconnect=asyncio.create_task(wait_disconnect())
        async def process():
            if disconnect.done():return None
            return await self.upstream('/v1/extract',payload)
        work=asyncio.create_task(process())
        try:
            async with asyncio.timeout(180):
                done,_=await asyncio.wait([disconnect,work],return_when=asyncio.FIRST_COMPLETED)
                if disconnect in done:return None
                return await work
        finally:
            work.cancel();disconnect.cancel()
            await asyncio.gather(work,disconnect,return_exceptions=True)
    async def __call__(self,scope,receive,send):
        if scope['type']=='lifespan':
            while True:
                message=await receive()
                if message['type']=='lifespan.startup':await send({'type':'lifespan.startup.complete'})
                elif message['type']=='lifespan.shutdown':await send({'type':'lifespan.shutdown.complete'});return
        if scope['type']!='http':return
        pairs=scope.get('headers',[]);headers=dict(pairs);path=scope.get('path','');method=scope.get('method','')
        if path=='/health' and method in {'GET','HEAD'}:return await self.respond(send,200,{'status':'ok','version':'careinone-web-1'},head=method=='HEAD')
        if sum(k==b'host' for k,v in pairs)!=1 or headers.get(b'host',b'').decode(errors='replace').lower()!=self.host:
            return await self.respond(send,400,{'error':'Unrecognized website host.'})
        if path in self.assets:
            if method not in {'GET','HEAD'}:return await self.respond(send,405,{'error':'Method not allowed'},extra=[(b'allow',b'GET, HEAD')])
            file=PUBLIC/self.assets[path]
            return await self.respond(send,200,file.read_bytes(),TYPES.get(file.suffix,'application/octet-stream'),head=method=='HEAD')
        if path=='/api/status' and method=='GET':return await self.respond(send,200,{'enabled':self.enabled,'storage':'browser-only','publicAccess':self.enabled and self.public_access})
        if path=='/api/session' and method=='GET':return await self.respond(send,200,{'authenticated':self.enabled and bool(self.session(headers))})
        routes={('/api/connect','POST'),('/api/login','POST'),('/api/logout','POST'),('/api/config','GET'),('/api/extract','POST')}
        if (path,method) not in routes:return await self.respond(send,404,{'error':'Not found'})
        if method=='POST':
            if headers.get(b'origin',b'').decode(errors='replace')!=self.origin or headers.get(b'x-careinone-request')!=b'1' or sum(k==b'origin' for k,v in pairs)!=1:
                return await self.respond(send,403,{'error':'Use this website to make this request.'})
        if path=='/api/logout':return await self.respond(send,200,{'disconnected':True},extra=[(b'set-cookie',self.cookie())])
        if not self.enabled:return await self.respond(send,503,{'error':'Optional cloud analysis is not configured. Local care workflows are available.'})
        try:
            if path=='/api/connect':
                if not self.public_access:return await self.respond(send,403,{'error':'Public analysis access is not enabled.'})
                if await self.body(scope,receive):raise ValueError('Public connection does not accept source text or credentials.')
                identifier=self.session(headers)
                if identifier:return await self.respond(send,200,{'connected':True})
                # Do not bind visitors to unstable reverse-proxy peer addresses.
                # New identities still share the extraction-wide process cap.
                if self.limited('public-connect',100,900):return await self.respond(send,429,{'error':'New analysis connections are busy. Try again in 15 minutes. Local records are available.'})
                identifier='p'+secrets.token_hex(32)
                return await self.respond(send,200,{'connected':True},extra=[(b'set-cookie',self.signed_cookie(identifier,86400))])
            if path=='/api/login':
                ip=str(scope.get('client',('unknown',))[0]);fingerprint=hashlib.sha256(ip.encode()).hexdigest()
                # Do not trust client-supplied forwarding headers for this limiter.
                if self.limited('login:'+fingerprint,10,900):return await self.respond(send,429,{'error':'Too many connection attempts. Try again in 15 minutes.'})
                value=await self.body(scope,receive);code=value.get('code','')
                if not isinstance(code,str) or len(code)>200:return await self.respond(send,401,{'error':'Invalid access code.'})
                digest=hashlib.sha256(code.encode()).hexdigest();valid=False
                for expected in self.code_hashes:valid |= hmac.compare_digest(digest,expected)
                if not valid:return await self.respond(send,401,{'error':'Invalid access code.'})
                return await self.respond(send,200,{'connected':True},extra=[(b'set-cookie',self.signed_cookie(digest))])
            identifier=self.session(headers)
            if not identifier:return await self.respond(send,401,{'error':'Your analysis session expired. Close this dialog and try again. Local records are safe.' if self.public_access else 'Connect with an operator-issued access code first.'})
            if path=='/api/config':
                if self.limited('config:'+identifier,30,60):return await self.respond(send,429,{'error':'Too many requests. Try again shortly.'})
                status,result=await self.upstream('/v1/config',None)
                if status==200:
                    from backend.schema import VERSION
                    from backend.verify_gateway import safe_providers
                    if not isinstance(result,dict) or result.get('schemaVersion')!=VERSION or not isinstance(result.get('configurationID'),str) or len(result['configurationID'])!=64 or not isinstance(result.get('providers'),dict) or type(result.get('maxSourceCharacters')) is not int:raise ValueError('Invalid configuration')
                    # Metadata must never contain the bridge credential or access codes.
                    encoded=json.dumps(result)
                    if self.gateway_token in encoded or any(c not in '0123456789abcdef' for c in result['configurationID']) or not 1000<=result['maxSourceCharacters']<=200000:raise ValueError('Unsafe metadata')
                    result={k:result[k] for k in ('schemaVersion','configurationID','providers','maxSourceCharacters')}
                    result['providers']=safe_providers(result['providers'],(self.gateway_token,self.secret.decode()))
                return await self.respond(send,status,result)
            from backend.schema import validate_request,validate_envelope
            value=validate_request(await self.body(scope,receive))
            if self.limited('extract:'+identifier,self.daily_limit,86400) or self.limited('global',self.global_limit,86400):return await self.respond(send,429,{'error':'The daily analysis allowance has been used. Local review is still available.'})
            outcome=await self.analysis(value,receive)
            if outcome is None:return
            status,result=outcome
            if status==200:result=validate_envelope(result,value['text'])
            return await self.respond(send,status,result)
        except (ValueError,TypeError,KeyError,RecursionError,TimeoutError):return await self.respond(send,422,{'error':'The request or analysis response could not be validated. Your records remain local.'})
        except Exception:return await self.respond(send,503,{'error':'Cloud connection unavailable. Your local records are safe.'})

def cloud_enabled():
    value=os.getenv('CARE_WEB_CLOUD_ENABLED','true').lower()
    if value not in {'true','false'}:raise ValueError('CARE_WEB_CLOUD_ENABLED must be true or false.')
    return value=='true'

def public_ai_enabled():
    value=os.getenv('CARE_WEB_PUBLIC_AI','false').lower()
    if value not in {'true','false'}:raise ValueError('CARE_WEB_PUBLIC_AI must be true or false.')
    return value=='true'

def create_app():
    return Web(origin=os.getenv('CARE_WEB_ORIGIN','http://127.0.0.1:8080'),gateway_url=os.getenv('CARE_WEB_GATEWAY_URL','') if cloud_enabled() else '',gateway_token=os.getenv('CARE_WEB_GATEWAY_TOKEN',''),secret=os.getenv('CARE_WEB_SESSION_SECRET',''),codes=tuple(c.strip() for c in os.getenv('CARE_WEB_ACCESS_CODES','').split(',') if c.strip()),daily_limit=os.getenv('CARE_WEB_DAILY_LIMIT','10'),global_limit=os.getenv('CARE_WEB_GLOBAL_DAILY_LIMIT','100'),public_access=public_ai_enabled())
