"""Run only inside the existing Render shell after the canonical-domain change.
Credentials stay in that server process. No paid inference requests are made.
"""
import datetime as dt
import http.cookiejar
import json
import os
import urllib.error
import urllib.request
from backend.verify_gateway import safe_providers
from web.server import NoRedirect

origin = os.environ['CARE_WEB_ORIGIN'].rstrip('/')
assert origin == 'https://careinone.org'
legacy = 'https://careinone-api.onrender.com'
tokens = [value.strip() for value in os.environ['CARE_BACKEND_TOKENS'].split(',') if value.strip()]
secret = os.environ['CARE_WEB_SESSION_SECRET']
report = {'checkedAtUTC': dt.datetime.now(dt.timezone.utc).isoformat(),
          'origin': origin, 'legacyAPIOrigin': legacy,
          'releaseSHA': os.getenv('RENDER_GIT_COMMIT'), 'runtimeUID': os.getuid(),
          'paidRequestsAttempted': 0, 'patientDataUsed': False}
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPCookieProcessor(jar))

def request(base, path, body=None, token=None, request_origin=None):
    headers = {'Origin': request_origin or origin, 'X-CareInOne-Request': '1',
               'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with opener.open(req, timeout=30) as response:
            raw = response.read(1200001)
            assert len(raw) <= 1200000
            assert response.headers.get('Cache-Control') == 'no-store'
            assert not any(value.encode() in raw for value in [secret, *tokens])
            return response.status, response.headers, json.loads(raw)
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        return status, {}, None

try:
    assert request(legacy, '/health')[2] == {'status': 'ok', 'schemaVersion': 'care-schema-1.0'}
    assert request(legacy, '/v1/config')[0] == 401
    native = None
    for token in tokens:
        status, _, value = request(legacy, '/v1/config', token=token)
        assert status == 200
        native = value
    report['allConfiguredNativeTokensAuthenticateOnOldHost'] = True
    report['legacyHealthAndAuthenticationPassed'] = True
    assert request(origin, '/api/status')[2] == {'enabled': True, 'storage': 'browser-only', 'publicAccess': True}
    assert request(origin, '/api/config')[0] == 401
    assert request(origin, '/api/connect', {}, request_origin=legacy)[0] == 403
    report['noncanonicalOriginPostRejected'] = True
    status, headers, value = request(origin, '/api/connect', {})
    assert status == 200 and value == {'connected': True}
    cookie = headers.get('Set-Cookie', '')
    assert all(flag in cookie for flag in ('HttpOnly', 'Secure', 'SameSite=Strict', 'Path=/api'))
    report['canonicalCodeFreeSessionAndSecureCookiePassed'] = True
    assert request(origin, '/api/session')[2] == {'authenticated': True}
    status, _, config = request(origin, '/api/config')
    assert status == 200 and config['configurationID'] == native['configurationID']
    providers = safe_providers(config['providers'], (secret, *tokens))
    assert providers['primary']['adapter'] == 'openai'
    assert providers['primary']['model'] == 'gpt-4.1-mini-2025-04-14'
    assert providers['primary']['maxOutputTokens'] == 6000
    assert config['maxSourceCharacters'] == 40000 and providers['fallback'] is None
    assert native['patientContentStored'] is False
    report.update(providers=providers, nativeConfigurationMatches=True,
                  maxSourceCharacters=config['maxSourceCharacters'])
    # Invalid consent is rejected before any provider request or paid quota use.
    payload = {'schemaVersion': 'care-schema-1.0', 'text': 'Fictional domain verification only.',
               'sourceKind': 'typed', 'consent': False,
               'providerConfigurationID': config['configurationID']}
    assert request(origin, '/api/extract', payload)[0] == 422
    report['missingConsentRejectedWithoutInference'] = True
    assert request(origin, '/api/logout', {})[0] == 200
    assert request(origin, '/api/session')[2] == {'authenticated': False}
    assert request(origin, '/api/config')[0] == 401
    report['logoutPassed'] = True
    report['passed'] = True
except Exception as error:
    report['passed'] = False
    report['failureClass'] = type(error).__name__
finally:
    print(json.dumps(report, indent=2))
