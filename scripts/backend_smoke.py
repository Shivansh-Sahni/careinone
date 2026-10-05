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
import urllib.error
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
    for path in ('/privacy','/support'):
        with urllib.request.urlopen(base+path,timeout=10) as response:
            document=response.read()
            assert response.status==200 and b'CareInOne' in document
            assert response.headers['Content-Type']=='text/html; charset=utf-8'
            assert response.headers['Cache-Control']=='no-store'
            assert response.headers['X-Content-Type-Options']=='nosniff'
            assert "default-src 'none'" in response.headers['Content-Security-Policy']
            assert int(response.headers['Content-Length'])==len(document)
        with urllib.request.urlopen(urllib.request.Request(base+path,method='HEAD'),timeout=10) as response:
            assert response.status==200 and response.read()==b''
            assert int(response.headers['Content-Length'])==len(document)
        try: urllib.request.urlopen(urllib.request.Request(base+path,data=b'fictional content',method='POST'),timeout=10)
        except urllib.error.HTTPError as error:
            assert error.code==405 and error.headers['Allow']=='GET, HEAD'
            assert json.load(error)=={'error':'Method not allowed'}
        else: raise AssertionError('Public page mutation unexpectedly allowed')
    try: urllib.request.urlopen(base+'/privacy/../providers.py',timeout=10)
    except urllib.error.HTTPError as error:
        assert error.code==404 and json.load(error)=={'error':'Not found'}
    else: raise AssertionError('Public page traversal unexpectedly allowed')
    config=urllib.request.Request(base+'/v1/config',headers={'Authorization':'Bearer '+token})
    with urllib.request.urlopen(config,timeout=10) as response: configuration=json.load(response)
    payload={'schemaVersion':'care-schema-1.0','text':'Synthetic note: CBC ordered.','sourceKind':'typed','consent':True,'providerConfigurationID':configuration['configurationID']}
    request=urllib.request.Request(base+'/v1/extract',data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
    with urllib.request.urlopen(request,timeout=10) as response:
        assert response.headers['Cache-Control']=='no-store'; result=json.load(response)
    assert result['claims'][0]['quote']==payload['text']; assert result['claims'][0]['subject']=='unknown'
    config=urllib.request.Request(base+'/v1/config',headers={'Authorization':'Bearer '+token})
    with urllib.request.urlopen(config,timeout=10) as response:
        assert response.headers['Cache-Control']=='no-store'
        configuration=json.load(response)
        assert configuration['providers']['primary']['adapter']=='mock'
        assert configuration['patientContentStored'] is False
    check=urllib.request.Request(base+'/v1/check',data=json.dumps({'schemaVersion':'care-schema-1.0'}).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
    with urllib.request.urlopen(check,timeout=10) as response:
        checked=json.load(response)
        assert checked['syntheticOnly'] is True and checked['route']=='primary'
    fixtures=ROOT/'Tests/Fixtures'; fixtures.mkdir(exist_ok=True)
    (fixtures/'gateway-mock-envelope.json').write_text(json.dumps(result,indent=2))
    print('PASS: real HTTP public privacy/support GET/HEAD/mutation/traversal/security headers plus health/auth/extraction/config/synthetic-check/no-store; Swift contract fixture saved (synthetic only).')
finally:
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired: process.kill(); process.wait()
