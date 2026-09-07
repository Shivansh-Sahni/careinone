#!/usr/bin/env python3
"""Exercise the real ASGI HTTP stack using synthetic content and an ephemeral token."""
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
token=secrets.token_urlsafe(40)
with socket.socket() as sock: sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
env={**os.environ,'CARE_BACKEND_TOKENS':token,'CARE_PROVIDER':'mock','CARE_ALLOW_MOCK':'true'}
process=subprocess.Popen([sys.executable,'-m','uvicorn','backend.app:create_app','--factory','--host','127.0.0.1','--port',str(port),'--no-access-log'],cwd=ROOT,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
    base=f'http://127.0.0.1:{port}'
    for _ in range(100):
        try:
            with urllib.request.urlopen(base+'/health',timeout=1) as response: assert json.load(response)['status']=='ok'
            break
        except OSError: time.sleep(.05)
    else: raise RuntimeError('Gateway failed to start')
    payload={'schemaVersion':'care-schema-1.0','text':'Synthetic note: CBC ordered.','sourceKind':'typed','consent':True}
    request=urllib.request.Request(base+'/v1/extract',data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
    with urllib.request.urlopen(request,timeout=10) as response:
        assert response.headers['Cache-Control']=='no-store'; result=json.load(response)
    assert result['claims'][0]['quote']==payload['text']; assert result['claims'][0]['subject']=='unknown'
    fixtures=ROOT/'Tests/Fixtures'; fixtures.mkdir(exist_ok=True)
    (fixtures/'gateway-mock-envelope.json').write_text(json.dumps(result,indent=2))
    print('PASS: real HTTP health/auth/extraction/no-store; Swift contract fixture saved (synthetic only).')
finally:
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired: process.kill(); process.wait()
