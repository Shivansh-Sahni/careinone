import json
import unittest
from unittest.mock import patch
from web.server import Web, public_ai_enabled
from web.tests import test_server as helpers
TOKEN, CODE, SECRET, CONFIG = helpers.TOKEN, helpers.CODE, helpers.SECRET, helpers.CONFIG


class PublicAccessTests(unittest.IsolatedAsyncioTestCase):
    request = helpers.WebTests.request

    def setUp(self):
        helpers.WebTests.setUp(self)
        self.app = Web(gateway_url='https://api.example.test', gateway_token=TOKEN,
                       secret=SECRET, public_access=True, transport=self.app.transport,
                       daily_limit=2, global_limit=4)
        self.payload = {'schemaVersion': 'care-schema-1.0', 'text': 'Fictional source only',
                        'sourceKind': 'typed', 'consent': True,
                        'providerConfigurationID': CONFIG['configurationID']}

    async def connect(self, **kwargs):
        status, headers, body = await self.request('/api/connect', 'POST', {}, **kwargs)
        self.assertEqual(status, 200)
        for value in (TOKEN, SECRET, CODE):
            self.assertNotIn(value.encode(), body)
        return headers[b'set-cookie'].split(b';')[0]

    async def test_public_connect_config_cookie_and_logout_without_code(self):
        status = json.loads((await self.request('/api/status'))[2])
        self.assertTrue(status['publicAccess'])
        self.assertEqual((await self.request('/api/config'))[0], 401)
        cookie = await self.connect()
        self.assertTrue(json.loads((await self.request('/api/session', cookie=cookie))[2])['authenticated'])
        self.assertEqual((await self.request('/api/config', cookie=cookie))[0], 200)
        _, headers, _ = await self.request('/api/connect', 'POST', {})
        self.assertIn(b'HttpOnly', headers[b'set-cookie'])
        self.assertIn(b'SameSite=Strict', headers[b'set-cookie'])
        _, headers, _ = await self.request('/api/logout', 'POST', {}, cookie)
        self.assertIn(b'Max-Age=0', headers[b'set-cookie'])

    async def test_public_mode_is_opt_in_and_requires_private_server_credentials(self):
        private = Web(gateway_url='https://api.example.test', gateway_token=TOKEN,
                      secret=SECRET, codes=[CODE])
        self.assertEqual((await self.request('/api/connect', 'POST', {}, app=private))[0], 403)
        with self.assertRaises(ValueError):
            Web(gateway_url='https://api.example.test', gateway_token=TOKEN, public_access=True)
        with self.assertRaises(ValueError):
            Web(public_access='true')
        with patch.dict('os.environ', {'CARE_WEB_PUBLIC_AI': 'true'}):
            self.assertTrue(public_ai_enabled())
        with patch.dict('os.environ', {'CARE_WEB_PUBLIC_AI': 'false'}):
            self.assertFalse(public_ai_enabled())
        with patch.dict('os.environ', {'CARE_WEB_PUBLIC_AI': 'yes'}):
            with self.assertRaises(ValueError): public_ai_enabled()

    async def test_public_connection_rejects_cross_origin_and_unexpected_data(self):
        self.assertEqual((await self.request('/api/connect', 'POST', {}, origin='https://evil.test'))[0], 403)
        self.assertEqual((await self.request('/api/connect', 'POST', {'text': 'not accepted here'}))[0], 422)
        self.assertEqual(self.calls, [])

    async def test_cookie_tampering_proxy_hop_continuity_expiry_and_disabled_mode(self):
        cookie = await self.connect()
        self.assertEqual((await self.request('/api/config', cookie=cookie+b'forged'))[0], 401)
        self.assertEqual((await self.request('/api/config', cookie=cookie, client=('203.0.113.2', 123)))[0], 200)
        with patch('web.server.time.time', return_value=10**12):
            self.assertEqual((await self.request('/api/config', cookie=cookie))[0], 401)
        self.app.public_access = False
        self.assertEqual((await self.request('/api/config', cookie=cookie))[0], 401)

    async def test_daily_allowance_survives_reconnect_proxy_hop_and_forwarded_header_spoof(self):
        cookie = await self.connect()
        for _ in range(2):
            self.assertEqual((await self.request('/api/extract', 'POST', self.payload, cookie))[0], 200)
        result = await self.request('/api/connect', 'POST', {}, cookie=cookie)
        self.assertEqual(result[0], 200)
        self.assertNotIn(b'set-cookie', result[1])
        result = await self.request('/api/extract', 'POST', self.payload, cookie,
                                    extra=[(b'x-forwarded-for', b'203.0.113.200')], client=('203.0.113.2', 123))
        self.assertEqual(result[0], 429)
        self.assertIn(b'Local review', result[2])
        self.assertEqual(len(self.calls), 2)

    async def test_global_allowance_applies_across_different_network_sessions(self):
        self.app.global_limit = 2
        for index in range(3):
            client = (f'203.0.113.{index+1}', 123)
            cookie = await self.connect(client=client)
            result = await self.request('/api/extract', 'POST', self.payload, cookie, client=client)
            self.assertEqual(result[0], 200 if index < 2 else 429)
        self.assertEqual(len(self.calls), 2)

    async def test_consent_and_quotes_remain_validated_before_local_records_change(self):
        cookie = await self.connect()
        self.assertEqual((await self.request('/api/extract', 'POST', {**self.payload, 'consent': False}, cookie))[0], 422)
        self.assertEqual(self.calls, [])
        self.app.transport = lambda *_: (200, {'schemaVersion': 'care-schema-1.0',
            'claims': [{'kind': 'other', 'label': 'Test', 'quote': 'invented quote'}]})
        self.assertEqual((await self.request('/api/extract', 'POST', self.payload, cookie))[0], 422)

    async def test_connection_attempts_are_bounded(self):
        for _ in range(100): await self.connect()
        self.assertEqual((await self.request('/api/connect', 'POST', {}))[0], 429)

    async def test_public_https_cookie_keeps_secure_flag(self):
        self.app.origin = 'https://127.0.0.1:8080'
        self.app.secure = True
        _, headers, _ = await self.request('/api/connect', 'POST', {}, origin=self.app.origin)
        self.assertIn(b'Secure', headers[b'set-cookie'])
