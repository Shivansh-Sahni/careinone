"""Optional single-service deployment: keep legacy mobile API + add the website.

Uses the unchanged Gateway ASGI application through an in-process transport,
including its authentication, consent validation, and rate/concurrency controls.
No loopback network request or public shared credential is needed.
"""
import asyncio
import json
import os
from backend.app import create_app as gateway_factory
from .server import Web, cloud_enabled

class Combined:
    def __init__(self,gateway,web_token,web_cloud_enabled=True,**web_options):
        self.gateway=gateway;self.web_token=web_token
        if not gateway.authorized({b'authorization':('Bearer '+web_token).encode()}):raise ValueError('Web bridge token must be present in CARE_BACKEND_TOKENS.')
        self.web=Web(gateway_url='https://careinone-api.onrender.com' if web_cloud_enabled else '',gateway_token=web_token,transport=self.transport,**web_options)
    async def transport(self,path,payload=None):
        if path not in {'/v1/config','/v1/extract'}:raise ValueError('Unsupported gateway path')
        sent=[];received=False
        async def receive():
            nonlocal received
            if not received:
                received=True
                return {'type':'http.request','body':json.dumps(payload).encode() if payload else b'','more_body':False}
            await asyncio.Future()
        async def send(event):sent.append(event)
        scope={'type':'http','method':'GET' if payload is None else 'POST','path':path,'headers':[(b'authorization',('Bearer '+self.web_token).encode()),(b'content-type',b'application/json')]}
        await self.gateway(scope,receive,send)
        return sent[0]['status'],json.loads(b''.join(e.get('body',b'') for e in sent[1:]))
    async def __call__(self,scope,receive,send):
        # Existing native paths preserve the exact original behavior.
        path=scope.get('path','')
        if scope['type']=='http' and (path.startswith('/v1/') or path in {'/health','/privacy','/support'}):
            return await self.gateway(scope,receive,send)
        return await self.web(scope,receive,send)

def create_app():
    if os.getenv('CARE_WEB_COMBINED','').lower()!='true':
        from .server import create_app as web_factory
        return web_factory()
    gateway=gateway_factory()
    tokens=[t.strip() for t in os.getenv('CARE_BACKEND_TOKENS','').split(',') if t.strip()]
    token=os.getenv('CARE_WEB_GATEWAY_TOKEN','') or tokens[0]
    return Combined(gateway,token,web_cloud_enabled=cloud_enabled(),origin=os.environ['CARE_WEB_ORIGIN'],secret=os.getenv('CARE_WEB_SESSION_SECRET',''),codes=tuple(c.strip() for c in os.getenv('CARE_WEB_ACCESS_CODES','').split(',') if c.strip()),daily_limit=os.getenv('CARE_WEB_DAILY_LIMIT','10'),global_limit=os.getenv('CARE_WEB_GLOBAL_DAILY_LIMIT','100'))
