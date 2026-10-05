"""ASGI application: bounded requests, explicit consent, auth, no patient persistence.

Run with: uvicorn backend.app:create_app --factory --no-access-log
"""
from __future__ import annotations
import asyncio
import hashlib
import hmac
import json
import os
from pathlib import Path
import time
from .providers import CompatibleProvider, Router, router_from_environment, ProviderError, looks_like_credential
from .schema import VERSION, ValidationError, loads, validate_request, validate_envelope, chunks

PUBLIC_PAGES = {'/privacy': 'privacy.html', '/support': 'support.html'}
PUBLIC_DIRECTORY = Path(__file__).with_name('public')

class Gateway:
    def __init__(self, tokens: list[str], router: Router, rate=30, max_inflight=4, max_source_characters=40000):
        if not tokens or any(not isinstance(token, str) or len(token) < 32 or len(token) > 4000 or any(ord(c) <= 32 or ord(c) >= 127 for c in token) or token.startswith('replace-with-') or looks_like_credential(token) for token in tokens):
            raise ValueError("Each backend token must be a generated secret of 32..4000 printable non-space ASCII characters")
        if type(rate) is not int or not 1 <= rate <= 1000: raise ValueError("Rate must be 1..1000 requests per minute")
        if type(max_inflight) is not int or not 1 <= max_inflight <= 16: raise ValueError("Concurrency must be 1..16 requests")
        self.token_hashes = [hashlib.sha256(t.encode()).digest() for t in tokens]
        # Retain hashes and lengths only. These also detect a gateway credential
        # accidentally pasted into a model label or provider URL, including a
        # substring, without retaining another plaintext copy of the token.
        self.token_fingerprints = tuple((len(token), digest) for token, digest in zip(tokens, self.token_hashes))
        self.router = router; self.rate = rate; self.limits = {}; self.semaphore = asyncio.Semaphore(max_inflight)
        if type(max_source_characters) is not int or not 1000 <= max_source_characters <= 200000: raise ValueError("Source limit must be 1000..200000 characters")
        self.max_source_characters = max_source_characters
        self.configuration_id = hashlib.sha256(json.dumps(self.configuration(), sort_keys=True).encode()).hexdigest()
    def contains_gateway_token(self, value):
        for length, expected in self.token_fingerprints:
            for start in range(len(value)-length+1):
                digest=hashlib.sha256(value[start:start+length].encode()).digest()
                if hmac.compare_digest(digest, expected): return True
        return False
    def configuration(self):
        providers=self.router.configuration()
        for provider in (self.router.primary, self.router.fallback):
            if isinstance(provider, CompatibleProvider) and any(self.contains_gateway_token(value) for value in (provider.model, provider.base_url, provider.api_key)):
                raise ProviderError("A gateway token cannot be used in provider configuration", code='provider_configuration')
        return providers
    def authorized(self, headers):
        raw = headers.get(b'authorization', b'')
        if not raw.startswith(b'Bearer ') or len(raw) > 4096: return None
        digest = hashlib.sha256(raw[7:]).digest()
        valid = False
        for expected in self.token_hashes: valid |= hmac.compare_digest(digest, expected)
        return digest if valid else None
    def allow(self, token):
        now = time.monotonic(); start, count = self.limits.get(token,(now,0))
        if now-start >= 60: start,count = now,0
        if count >= self.rate: return False
        self.limits[token]=(start,count+1); return True
    async def __call__(self, scope, receive, send):
        if scope['type'] == 'lifespan':
            while True:
                event=await receive()
                if event['type']=='lifespan.startup': await send({'type':'lifespan.startup.complete'})
                elif event['type']=='lifespan.shutdown': await send({'type':'lifespan.shutdown.complete'}); return
        if scope['type'] != 'http': return
        path=scope.get('path',''); method=scope.get('method','')
        if path in PUBLIC_PAGES:
            if method not in {'GET', 'HEAD'}:
                return await self.respond(send,405,{'error':'Method not allowed'},extra_headers=[(b'allow',b'GET, HEAD')])
            # Only fixed, reviewed public documents can be read. Request paths,
            # query strings, headers and body content never choose a file or
            # interpolate into the document.
            try:
                content=(PUBLIC_DIRECTORY / PUBLIC_PAGES[path]).read_bytes()
                if len(content)>200_000: raise ValueError()
                content.decode('utf-8')
            except (OSError, ValueError):
                return await self.respond(send,503,{'error':'Public information is temporarily unavailable'})
            await send({'type':'http.response.start','status':200,'headers':[
                (b'content-type',b'text/html; charset=utf-8'),
                (b'cache-control',b'no-store'),
                (b'x-content-type-options',b'nosniff'),
                (b'referrer-policy',b'no-referrer'),
                (b'x-frame-options',b'DENY'),
                (b'content-security-policy',b"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"),
                (b'content-length',str(len(content)).encode())]})
            return await send({'type':'http.response.body','body':b'' if method=='HEAD' else content})
        if path == '/health' and method == 'GET': return await self.respond(send,200,{'status':'ok','schemaVersion':VERSION})
        if (path, method) not in {('/v1/extract', 'POST'), ('/v1/config', 'GET'), ('/v1/check', 'POST')}: return await self.respond(send,404,{'error':'Not found'})
        # Reject duplicate auth/content headers instead of accepting ambiguous proxy parsing.
        pairs=scope.get('headers',[]); headers=dict(pairs)
        if sum(k==b'authorization' for k,v in pairs)!=1: return await self.respond(send,401,{'error':'Authentication required'})
        token=self.authorized(headers)
        if token is None: return await self.respond(send,401,{'error':'Authentication required'})
        if not self.allow(token): return await self.respond(send,429,{'error':'Rate limit reached. Retry later.'})
        if path == '/v1/config':
            try: providers=self.configuration()
            except Exception:
                failure=ProviderError(code='provider_configuration')
                return await self.respond(send,503,{'error':failure.public_message,'errorCode':failure.code})
            return await self.respond(send,200,{'schemaVersion':VERSION, 'configurationID':self.configuration_id, 'providers':providers, 'maxSourceCharacters':self.max_source_characters, 'patientContentStored':False})
        if any(sum(k == name for k,v in pairs) > 1 for name in (b'content-type', b'content-length', b'content-encoding')): return await self.respond(send,400,{'error':'Ambiguous request headers'})
        if headers.get(b'content-type',b'').split(b';')[0] != b'application/json': return await self.respond(send,415,{'error':'Use application/json'})
        if headers.get(b'content-encoding',b'identity') != b'identity': return await self.respond(send,415,{'error':'Compressed request bodies are not accepted'})
        body=bytearray()
        try:
            async with asyncio.timeout(15):
                while True:
                    event=await receive()
                    if event['type']=='http.disconnect': return
                    body.extend(event.get('body',b''))
                    if len(body)>1_200_000: return await self.respond(send,413,{'error':'Request too large'})
                    if not event.get('more_body',False): break
            value=loads(body); body.clear()
            if path == '/v1/check':
                if value != {'schemaVersion': VERSION}: raise ValidationError('Use the fixed synthetic connection check')
                request={}
            else:
                request=validate_request(value)
                if request.get('providerConfigurationID') != self.configuration_id:
                    return await self.respond(send,409,{'error':'Review the configured model recipients and renew cloud consent before analysis.'})
                if len(request['text']) > self.max_source_characters: return await self.respond(send,413,{'error':'Source exceeds the configured analysis limit. Split it into smaller sources or use local analysis.'})
            async with asyncio.timeout(180):
                # Monitor disconnection while waiting for capacity, rather than
                # starting a billed model request for an already-cancelled upload.
                disconnect=asyncio.create_task(self.wait_disconnect(receive))
                async def process():
                    async with self.semaphore:
                        if disconnect.done(): return None
                        return await (self.check() if path == '/v1/check' else self.analyze(request))
                work=asyncio.create_task(process())
                try:
                    done,_=await asyncio.wait([work,disconnect],return_when=asyncio.FIRST_COMPLETED)
                    if disconnect in done: work.cancel(); await asyncio.gather(work,return_exceptions=True); return
                    result=await work
                finally:
                    work.cancel(); disconnect.cancel(); await asyncio.gather(work,disconnect,return_exceptions=True)
            return await self.respond(send,200,result)
        except ValidationError: return await self.respond(send,422,{'error':'Invalid request or unsupported extraction schema'})
        except TimeoutError: return await self.respond(send,504,{'error':'Analysis timed out. Evidence remains on your device.'})
        except ProviderError as exc: return await self.respond(send,503,{'error':exc.public_message,'errorCode':exc.code})
        except asyncio.CancelledError: raise
        except Exception: return await self.respond(send,503,{'error':'Analysis unavailable. Use local analysis or retry.'})
        finally: body.clear()
    async def wait_disconnect(self,receive):
        while True:
            event=await receive()
            if event['type']=='http.disconnect': return
    async def check(self):
        text='Synthetic connection check: a follow-up appointment was requested.'
        result, route = await self.router.extract_with_route(text, 'typed', None)
        if not result['claims']: raise ProviderError('The synthetic check did not return a supported proposal')
        return {'schemaVersion':VERSION, 'status':'ok', 'route':route, 'providers':self.configuration(), 'syntheticOnly':True}
    async def analyze(self,request):
        claims=[]; seen=set(); clarification_count=0
        for chunk in chunks(request['text']):
            envelope=await self.router.extract(chunk,request['sourceKind'],request.get('eventDate'))
            for claim in envelope['claims']:
                # Same quote and semantic payload across overlapping chunks deduplicate deterministically.
                identity={k:v for k,v in claim.items() if k not in {'confidence','clarification'}}
                key=json.dumps(identity,sort_keys=True,ensure_ascii=False)
                if key in seen: continue
                seen.add(key)
                if claim.get('clarification'):
                    clarification_count+=1
                    if clarification_count>3: claim.pop('clarification',None)
                claims.append(claim)
                if len(claims)>200: raise ValidationError('Too many claims; split the source')
        return validate_envelope({'schemaVersion':VERSION,'claims':claims},request['text'])
    @staticmethod
    async def respond(send,status,value,extra_headers=()):
        data=json.dumps(value,ensure_ascii=False,allow_nan=False,separators=(',',':')).encode()
        await send({'type':'http.response.start','status':status,'headers':[(b'content-type',b'application/json'),(b'cache-control',b'no-store'),(b'pragma',b'no-cache'),(b'x-content-type-options',b'nosniff'),(b'content-length',str(len(data)).encode()),*extra_headers]})
        await send({'type':'http.response.body','body':data})

def create_app():
    tokens=[token.strip() for token in os.getenv('CARE_BACKEND_TOKENS','').split(',') if token.strip()]
    try:
        max_source_characters=int(os.getenv('CARE_MAX_SOURCE_CHARACTERS','40000'))
    except (ValueError, TypeError):
        raise ProviderError("CARE_MAX_SOURCE_CHARACTERS must be an integer from 1000 to 200000") from None
    return Gateway(tokens,router_from_environment(), max_source_characters=max_source_characters)
