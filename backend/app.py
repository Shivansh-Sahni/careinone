"""ASGI application: bounded requests, explicit consent, auth, no patient persistence.

Run with: uvicorn backend.app:create_app --factory --no-access-log
"""
from __future__ import annotations
import asyncio
import hashlib
import hmac
import json
import os
import time
from .providers import Router, router_from_environment, ProviderError
from .schema import VERSION, ValidationError, loads, validate_request, validate_envelope, chunks

class Gateway:
    def __init__(self, tokens: list[str], router: Router, rate=30, max_inflight=4):
        if not tokens or any(len(token) < 32 for token in tokens): raise ValueError("Each backend token must contain at least 32 characters")
        self.token_hashes = [hashlib.sha256(t.encode()).digest() for t in tokens]
        self.router = router; self.rate = rate; self.limits = {}; self.semaphore = asyncio.Semaphore(max_inflight)
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
        if path == '/health' and method == 'GET': return await self.respond(send,200,{'status':'ok','schemaVersion':VERSION})
        if path != '/v1/extract' or method != 'POST': return await self.respond(send,404,{'error':'Not found'})
        # Reject duplicate auth/content headers instead of accepting ambiguous proxy parsing.
        pairs=scope.get('headers',[]); headers=dict(pairs)
        if sum(k==b'authorization' for k,v in pairs)!=1: return await self.respond(send,401,{'error':'Authentication required'})
        token=self.authorized(headers)
        if token is None: return await self.respond(send,401,{'error':'Authentication required'})
        if not self.allow(token): return await self.respond(send,429,{'error':'Rate limit reached. Retry later.'})
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
            request=validate_request(loads(body)); body.clear()
            async with asyncio.timeout(180):
                async with self.semaphore:
                    work=asyncio.create_task(self.analyze(request))
                    disconnect=asyncio.create_task(self.wait_disconnect(receive))
                    try:
                        done,_=await asyncio.wait([work,disconnect],return_when=asyncio.FIRST_COMPLETED)
                        if disconnect in done: work.cancel(); await asyncio.gather(work,return_exceptions=True); return
                        result=await work
                    finally:
                        work.cancel(); disconnect.cancel(); await asyncio.gather(work,disconnect,return_exceptions=True)
            return await self.respond(send,200,result)
        except ValidationError: return await self.respond(send,422,{'error':'Invalid request or unsupported extraction schema'})
        except TimeoutError: return await self.respond(send,504,{'error':'Analysis timed out. Evidence remains on your device.'})
        except asyncio.CancelledError: raise
        except Exception: return await self.respond(send,503,{'error':'Analysis unavailable. Use local analysis or retry.'})
        finally: body.clear()
    async def wait_disconnect(self,receive):
        while True:
            event=await receive()
            if event['type']=='http.disconnect': return
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
    async def respond(send,status,value):
        data=json.dumps(value,ensure_ascii=False,allow_nan=False,separators=(',',':')).encode()
        await send({'type':'http.response.start','status':status,'headers':[(b'content-type',b'application/json'),(b'cache-control',b'no-store'),(b'pragma',b'no-cache'),(b'x-content-type-options',b'nosniff'),(b'content-length',str(len(data)).encode())]})
        await send({'type':'http.response.body','body':data})

def create_app():
    tokens=[token.strip() for token in os.getenv('CARE_BACKEND_TOKENS','').split(',') if token.strip()]
    return Gateway(tokens,router_from_environment())
