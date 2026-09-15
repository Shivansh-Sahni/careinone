import unittest
from backend.evaluate import CASES, assess

class EvaluationTests(unittest.TestCase):
    def test_schema_valid_family_misattribution_fails_quality_gate(self):
        case=next(c for c in CASES if c['id']=='family-subject')
        result=assess(case,[{'kind':'condition','label':'diabetes','subject':'patient','negated':False}])
        self.assertFalse(result['passed']); self.assertEqual(result['prohibitedClaims'],1)
    def test_conflicting_doses_must_both_survive(self):
        case=next(c for c in CASES if c['id']=='conflicting-reports')
        claims=[{'kind':'medication','label':'Metoprolol','numericValue':25}]
        self.assertFalse(assess(case,claims)['passed'])
        claims.append({'kind':'medication','label':'Metoprolol','numericValue':50})
        self.assertTrue(assess(case,claims)['passed'])
    def test_omission_cannot_become_a_stop(self):
        case=next(c for c in CASES if c['id']=='omission-not-stop')
        self.assertTrue(assess(case,[])['passed'])
        self.assertFalse(assess(case,[{'kind':'medication','action':'stopped'}])['passed'])
