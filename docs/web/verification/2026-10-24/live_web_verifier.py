"""Run inside the existing Render shell after owner credential setup.

Reads credentials only in that server process; prints a bounded non-PHI report.
Performs one fictional extraction using existing model/caps. No secrets are
written or printed, and redirects are rejected.
"""
import datetime as dt
import http.cookiejar
import json
import os
import urllib.error
import urllib.request
from backend.schema import validate_envelope
from backend.verify_gateway import FICTIONAL_SOURCE, safe_providers
from web.server import NoRedirect

origin = os.environ['CARE_WEB_ORIGIN'].rstrip('/')
assert origin == 'https://careinone-api.onrender.com'
code = os.environ['CARE_WEB_ACCESS_CODES'].split(',')[0].strip()
token = os.environ['CARE_BACKEND_TOKENS'].split(',')[0].strip()
secret = os.environ['CARE_WEB_SESSION_SECRET']
assert len(code) >= 32 and len(secret) >= 32
report = {'checkedAtUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
          'origin': origin, 'releaseSHA': os.getenv('RENDER_GIT_COMMIT'),
          'runtimeUID': os.getuid(), 'paidRequestsAttempted': 0,
          'syntheticOnly': True, 'patientDataUsed': False}
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPCookieProcessor(jar))

def request(path, body=None, *, native=False):
    headers = {'Origin': origin, 'X-CareInOne-Request': '1', 'Content-Type': 'application/json'}
    if native:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(origin + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with opener.open(req, timeout=60) as response:
            raw = response.read(1200001)
            assert len(raw) <= 1200000 and response.headers.get('Cache-Control') == 'no-store'
            assert not any(value.encode() in raw for value in (code, token, secret))
            return response.status, response.headers, json.loads(raw)
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        return status, {}, None

try:
    assert request('/api/status')[2] == {'enabled': True, 'storage': 'browser-only'}
    assert request('/api/config')[0] == 401
    report['unauthenticatedConfigRejected'] = True
    status, headers, value = request('/api/login', {'code': code})
    assert status == 200 and value == {'connected': True}
    cookie = headers.get('Set-Cookie', '')
    assert all(flag in cookie for flag in ('HttpOnly', 'Secure', 'SameSite=Strict', 'Path=/api'))
    report['codeLoginAndSecureCookiePassed'] = True
    assert request('/api/session')[2] == {'authenticated': True}
    status, _, config = request('/api/config')
    assert status == 200
    native_status, _, native_config = request('/v1/config', native=True)
    assert native_status == 200 and config['configurationID'] == native_config['configurationID']
    providers = safe_providers(config['providers'], (code, token, secret))
    assert providers['primary']['adapter'] == 'openai'
    assert providers['primary']['model'] == 'gpt-4.1-mini-2025-04-14'
    report.update(providers=providers, nativeConfigurationMatches=True,
                  maxSourceCharacters=config['maxSourceCharacters'])
    payload = {'schemaVersion': 'care-schema-1.0', 'text': FICTIONAL_SOURCE,
               'sourceKind': 'typed', 'consent': False,
               'providerConfigurationID': config['configurationID']}
    assert request('/api/extract', payload)[0] == 422
    report['missingConsentRejected'] = True
    payload['consent'] = True
    report['paidRequestsAttempted'] = 1
    status, _, result = request('/api/extract', payload)
    report['fictionalExtractionHTTPStatus'] = status
    assert status == 200
    envelope = validate_envelope(result, FICTIONAL_SOURCE)
    assert envelope['claims']
    report.update(claimCount=len(envelope['claims']), exactQuotesValidated=True,
                  liveWebInferenceVerified=True)
    assert request('/api/logout', {})[0] == 200
    assert request('/api/session')[2] == {'authenticated': False}
    assert request('/api/config')[0] == 401
    report['logoutPassed'] = True
    report['passed'] = True
except Exception as error:
    report['passed'] = False
    report['failureClass'] = type(error).__name__
finally:
    print(json.dumps(report, indent=2))
