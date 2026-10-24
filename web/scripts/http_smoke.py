"""Actual HTTP checks shared by local ASGI and production-container smoke tests.

All inference is mock-only. Credentials are ephemeral and never printed.
"""
from __future__ import annotations
import argparse
import datetime as dt
import http.cookiejar
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

ASSETS = ('/notices', '/app.js', '/imports.js', '/recorder.js', '/insights.js',
          '/vendor/pdf-5.5.207/pdf.mjs', '/vendor/ocr-7.0.0/worker.min.js',
          '/vendor/ocr-7.0.0/lang/eng.traineddata.gz')

def mock_environment(origin):
    env = {k: v for k, v in os.environ.items() if not k.startswith('CARE_')}
    token, code = secrets.token_urlsafe(40), secrets.token_urlsafe(40)
    env.update(CARE_PROVIDER='mock', CARE_ALLOW_MOCK='true', CARE_BACKEND_TOKENS=token,
               CARE_WEB_COMBINED='true', CARE_WEB_ORIGIN=origin,
               CARE_WEB_SESSION_SECRET=secrets.token_urlsafe(40), CARE_WEB_ACCESS_CODES=code)
    return env, token, code

def free_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]

def verify_http(origin, token, code, *, transport, cloud=True, process_alive=lambda: True):
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def request(path, body=None, authorization=False):
        headers = {'Origin': origin, 'X-CareInOne-Request': '1', 'Content-Type': 'application/json'}
        if authorization:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(origin + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        with opener.open(req, timeout=15) as response:
            return response.status, response.headers, response.read()
    for attempt in range(120):
        try:
            request('/health')
            break
        except (OSError, urllib.error.URLError):
            if not process_alive():
                raise RuntimeError('Smoke server failed to start.') from None
            if attempt == 119:
                raise RuntimeError('Smoke server readiness timeout.') from None
            time.sleep(.1)
    status, headers, body = request('/')
    assert status == 200 and b'CareInOne' in body and headers['Cache-Control'] == 'no-store'
    for asset in ASSETS:
        status, headers, body = request(asset)
        assert status == 200 and body
        assert token.encode() not in body and code.encode() not in body
    assert json.loads(request('/health')[2]) == {'status': 'ok', 'schemaVersion': 'care-schema-1.0'}
    root = Path(__file__).resolve().parents[2]
    for route in ('/privacy', '/support'):
        assert request(route)[2] == (root / 'backend/public' / (route[1:] + '.html')).read_bytes()
    for route in (('/api/config', '/v1/config') if cloud else ('/v1/config',)):
        try:
            request(route)
            raise AssertionError('Unauthenticated configuration was accepted.')
        except urllib.error.HTTPError as error:
            assert error.code == 401
    native = json.loads(request('/v1/config', authorization=True)[2])
    assert native['patientContentStored'] is False and native['providers']['primary']['adapter'] == 'mock'
    if not cloud:
        assert json.loads(request('/api/status')[2]) == {'enabled': False, 'storage': 'browser-only'}
        for route, body in (('/api/config', None), ('/api/login', {'code': code})):
            try:
                request(route, body)
                raise AssertionError('Disabled web cloud route was accepted.')
            except urllib.error.HTTPError as error:
                assert error.code == 503
        return {'passed': True, 'checkedAtUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
                'transport': transport, 'paidRequests': 0, 'assetsVerified': len(ASSETS),
                'legacyAPIHealthPreserved': True, 'legacyAPIAuthenticationPreserved': True,
                'legacyPublicDocumentBytesPreserved': True, 'webCloudEnabled': False,
                'webLocalFallbackVerified': True, 'patientRecordsStoredByServer': False}
    assert request('/api/login', {'code': code})[0] == 200
    config = json.loads(request('/api/config')[2])
    assert config['providers']['primary']['adapter'] == 'mock'
    assert config['configurationID'] == native['configurationID']
    text = 'Fictional follow-up appointment requested.'
    result = json.loads(request('/api/extract', {'schemaVersion': 'care-schema-1.0', 'text': text,
                  'sourceKind': 'typed', 'consent': True, 'providerConfigurationID': config['configurationID']})[2])
    assert result['claims'] and all(c['quote'] in text for c in result['claims'])
    assert request('/api/logout', {})[0] == 200
    return {'passed': True, 'checkedAtUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
            'transport': transport, 'inference': 'synthetic mock only', 'paidRequests': 0,
            'assetsVerified': len(ASSETS), 'legacyAPIHealthPreserved': True,
            'legacyAPIAuthenticationPreserved': True, 'legacyPublicDocumentBytesPreserved': True,
            'cloudBridgeVerified': True, 'patientRecordsStoredByServer': False}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--local-only', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    env, token, code = mock_environment(origin)
    if args.local_only:
        env['CARE_WEB_CLOUD_ENABLED']='false'
        env.pop('CARE_WEB_SESSION_SECRET'); env.pop('CARE_WEB_ACCESS_CODES')
    process = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'web.combined:create_app', '--factory',
               '--host', '127.0.0.1', '--port', str(port), '--no-access-log'], cwd=root, env=env,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        print(json.dumps(verify_http(origin, token, code, transport='actual localhost HTTP',
                                    cloud=not args.local_only, process_alive=lambda: process.poll() is None), indent=2))
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

if __name__ == '__main__':
    main()
