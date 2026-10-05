import io
import json
import unittest
import urllib.error
from unittest.mock import patch

from backend.app import Gateway
from backend.providers import CompatibleProvider, ProviderError, Router
from backend.schema import FIELDS, VALIDATION_CODES, VERSION, ValidationError, openai_output_schema, validate_envelope
from backend.tests import test_gateway
from backend.tests.test_gateway import TOKEN, request
from backend.verify_gateway import FICTIONAL_SOURCE, fetch


class StructuredOutputTests(unittest.IsolatedAsyncioTestCase):
    call = test_gateway.GatewayTests.call

    def provider(self, adapter='openai'):
        return CompatibleProvider('https://api.example/v1', 'unit-private-key', 'gpt-4.1-mini-2025-04-14', adapter=adapter)

    def test_openai_requests_strict_typed_schema_with_nullable_optional_fields(self):
        body = self.provider().request_body(FICTIONAL_SOURCE, 'typed', None)
        format = body['response_format']
        self.assertEqual(format['type'], 'json_schema'); self.assertTrue(format['json_schema']['strict'])
        schema = format['json_schema']['schema']; claim = schema['properties']['claims']['items']
        self.assertFalse(schema['additionalProperties']); self.assertFalse(claim['additionalProperties'])
        self.assertEqual(set(schema['required']), {'schemaVersion', 'claims'})
        self.assertEqual(set(claim['required']), FIELDS); self.assertEqual(set(claim['properties']), FIELDS)
        self.assertEqual(claim['properties']['numericValue']['type'], ['number', 'null'])
        self.assertEqual(claim['properties']['intervalDays']['type'], ['integer', 'null'])
        self.assertEqual(claim['properties']['negated']['type'], ['boolean', 'null'])
        self.assertEqual(claim['properties']['clarification']['type'], ['string', 'null'])
        self.assertEqual(claim['properties']['quote']['type'], 'string')
        self.assertIn(None, claim['properties']['action']['enum'])
        self.assertEqual(schema['properties']['claims']['maxItems'], 30)
        self.assertFalse(body['store']); self.assertEqual(body['max_completion_tokens'], 6000)

    def test_compatible_and_kimi_keep_their_supported_json_mode(self):
        for adapter in ('compatible', 'kimi'):
            with self.subTest(adapter=adapter):
                body = self.provider(adapter).request_body('Fictional evidence', 'typed', None)
                self.assertEqual(body['response_format'], {'type': 'json_object'})
                self.assertNotIn('store', body)

    async def response(self, result, text=FICTIONAL_SOURCE):
        raw = io.BytesIO(json.dumps({'choices': [{'finish_reason': 'stop', 'message': {'content': json.dumps(result)}}]}).encode())
        with patch('urllib.request.build_opener') as opener:
            opener.return_value.open.return_value.__enter__.return_value = raw
            return await self.provider().extract(text, 'typed', None)

    def fixture(self):
        def claim(**values): return {**dict.fromkeys(FIELDS), **values}
        return {'schemaVersion': VERSION, 'claims': [
            claim(kind='labTest', label='CBC blood test', quote='My clinician ordered a CBC blood test today.', action='ordered', subject='patient', certainty='reported', confidence=0.95, speakerUncertain=True, negated=False, conditional=False),
            claim(kind='condition', label='diabetes', quote='My mother has diabetes.', action='mentioned', subject='family', certainty='reported', confidence=0.95, speakerUncertain=True, negated=False, conditional=False),
            claim(kind='labTest', label='MRI', quote='The clinician said to consider MRI if pain persists; no MRI was ordered.', action='mentioned', subject='patient', certainty='conditional', confidence=0.9, speakerUncertain=True, negated=True, conditional=True),
        ]}

    async def test_multiple_typed_claims_and_null_optional_values_are_accepted_without_promoting_family_or_conditional_data(self):
        result = await self.response(self.fixture())
        self.assertEqual(len(result['claims']), 3)
        self.assertEqual(result['claims'][1]['subject'], 'family')
        self.assertTrue(result['claims'][2]['negated']); self.assertTrue(result['claims'][2]['conditional'])
        self.assertIsNone(result['claims'][0]['dueDate']); self.assertIsNone(result['claims'][0]['numericValue'])
        self.assertTrue(all(claim['quote'] in FICTIONAL_SOURCE for claim in result['claims']))

    async def test_structured_shape_does_not_bypass_exact_quote_validation(self):
        value = self.fixture(); value['claims'][0]['quote'] = 'Fictional unsupported quote'
        with self.assertRaises(ProviderError) as caught: await self.response(value)
        self.assertEqual(caught.exception.code, 'provider_response_invalid')
        self.assertEqual(caught.exception.validation_code, 'quote_not_exact')
        self.assertNotIn('unsupported quote', str(caught.exception))

    async def test_safe_diagnostics_identify_categories_without_echoing_content(self):
        cases = [('clarification', ['private fictional content'], 'text_field_invalid'),
                 ('action', 'private-invalid-action', 'enumeration_invalid'),
                 ('confidence', 'private-string', 'numeric_invalid'),
                 ('dueDate', 'private-invalid-date', 'date_invalid')]
        for key, bad, expected in cases:
            value = self.fixture(); value['claims'][0][key] = bad
            with self.subTest(field=key), self.assertRaises(ProviderError) as caught: await self.response(value)
            self.assertEqual(caught.exception.validation_code, expected)
            self.assertNotIn('private', str(caught.exception) + caught.exception.public_message)

    async def test_gateway_preserves_only_allowlisted_validation_category(self):
        class Invalid:
            async def extract(self, *args): raise ProviderError('private fictional content', code='provider_response_invalid', validation_code='quote_not_exact')
        status, body, _ = await self.call(app=Gateway([TOKEN], Router(Invalid())), value=request())
        self.assertEqual(status, 503); self.assertEqual(body['validationCode'], 'quote_not_exact')
        self.assertNotIn('private', json.dumps(body))
        class Untrusted:
            async def extract(self, *args): raise ProviderError('private', code='provider_response_invalid', validation_code='private-content-as-code')
        _, body, _ = await self.call(app=Gateway([TOKEN], Router(Untrusted())), value=request())
        self.assertNotIn('validationCode', body)

    def test_verifier_only_prints_allowlisted_failure_diagnostics(self):
        for code in ('quote_not_exact', 'private-content-as-code'):
            error = urllib.error.HTTPError('https://api.example', 503, 'private', {}, io.BytesIO(json.dumps({'error': 'private evidence', 'errorCode': 'provider_response_invalid', 'validationCode': code}).encode()))
            with patch('urllib.request.build_opener') as opener:
                opener.return_value.open.side_effect = error
                summary, _ = fetch('https://api.example', '/v1/extract', TOKEN, {})
            self.assertNotIn('private', json.dumps(summary))
            if code in VALIDATION_CODES: self.assertEqual(summary['validationCode'], code)
            else: self.assertNotIn('validationCode', summary)

    def test_unknown_validation_exception_messages_never_become_diagnostics(self):
        self.assertEqual(ValidationError('private raw value').validation_code, 'validation_unknown')
        self.assertEqual(set(openai_output_schema()['properties']['claims']['items']['properties']), FIELDS)
