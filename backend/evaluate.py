"""Evaluate only bundled synthetic cases against the configured primary model.

This consumes provider API quota. It never reads patient sources or changes the app.
Passing these small regression checks is not a clinical-quality certification.
"""
import argparse
import asyncio
from dataclasses import replace
import json
import os
from pathlib import Path
import time
from .configure import load_configuration
from .providers import CompatibleProvider, router_from_environment
from .schema import validate_envelope

CASES = [
    {'id':'medication-dose', 'text':'I am taking metoprolol 25 mg orally once daily.', 'required':[{'kind':'medication','labelContains':'metoprolol','numericValue':25,'unit':'mg','action':'taking','subject':'patient'}]},
    {'id':'family-subject', 'text':'My mother has diabetes. I do not have a diagnosis of diabetes.', 'required':[{'kind':'condition','labelContains':'diabetes','subject':'family'}], 'forbidden':[{'kind':'condition','subject':'patient','negated':False}]},
    {'id':'conditional-plan', 'text':'The clinician said to consider MRI if the pain persists. No MRI was ordered.', 'required':[{'labelContains':'mri','conditional':True}], 'forbidden':[{'labelContains':'mri','action':'ordered','negated':False}]},
    {'id':'explicit-order', 'text':'My clinician ordered a CBC blood test today.', 'required':[{'kind':'labTest','labelContains':'cbc','action':'ordered','subject':'patient'}]},
    {'id':'conflicting-reports', 'text':'The PCP medication list says metoprolol 25 mg daily. The cardiology medication list says metoprolol 50 mg daily.', 'required':[{'kind':'medication','labelContains':'metoprolol','numericValue':25},{'kind':'medication','labelContains':'metoprolol','numericValue':50}]},
    {'id':'omission-not-stop', 'text':'My visit concerned a cough. No medications were discussed.', 'forbidden':[{'kind':'medication','action':'stopped'}]},
    {'id':'allergy-negation', 'text':'I am not allergic to penicillin.', 'required':[{'kind':'allergy','labelContains':'penicillin','negated':True,'subject':'patient'}], 'forbidden':[{'kind':'allergy','labelContains':'penicillin','negated':False}]},
    {'id':'appointment-date', 'text':'My follow-up appointment is scheduled for October 12, 2026 at 10:30 AM. The time zone was not specified.', 'required':[{'kind':'appointment','action':'scheduled','dueDatePrefix':'2026-10-12','subject':'patient'}]},
]

def matches(claim, expected):
    for key, value in expected.items():
        if key == 'labelContains':
            if value not in claim.get('label','').lower(): return False
        elif key == 'dueDatePrefix':
            if not (claim.get('dueDate') or '').startswith(value): return False
        elif key == 'negated':
            if claim.get(key,False) != value: return False
        elif claim.get(key) != value: return False
    return True

def assess(case, claims):
    missing=sum(not any(matches(c,expected) for c in claims) for expected in case.get('required',[]))
    prohibited=sum(any(matches(c,expected) for c in claims) for expected in case.get('forbidden',[]))
    return {'passed':missing == 0 and prohibited == 0,'missingExpectations':missing,'prohibitedClaims':prohibited}

async def evaluate(provider):
    results=[]
    for case in CASES:
        start=time.monotonic()
        try:
            response=validate_envelope(await provider.extract(case['text'],'typed',None),case['text'])
            outcome=assess(case,response['claims'])
        except Exception:
            outcome={'passed':False,'error':'Provider request or schema validation failed'}
        results.append({'case':case['id'],'seconds':round(time.monotonic()-start,2),**outcome})
    return {'model':provider.model,'adapter':provider.adapter,'syntheticOnly':True,'passed':sum(r['passed'] for r in results),'total':len(results),'cases':results,'limitation':'Small synthetic regression screen; not a clinical-quality evaluation or exact cost measurement.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list',action='store_true',help='List cases without network or credentials')
    parser.add_argument('--env-file',type=Path,default=Path('.env'))
    parser.add_argument('--model',help='Override only the primary model ID for comparison')
    parser.add_argument('--output',type=Path,help='Optional non-PHI report path')
    args=parser.parse_args()
    if args.list:
        for case in CASES: print(case['id'])
        return
    if args.env_file.exists():
        for key,value in load_configuration(args.env_file).items(): os.environ.setdefault(key,value)
    provider=router_from_environment().primary
    if not isinstance(provider,CompatibleProvider): parser.error('Select a live compatible provider; mock output is not a model quality result')
    if args.model: provider=replace(provider,model=args.model)
    report=asyncio.run(evaluate(provider)); rendered=json.dumps(report,indent=2)
    if args.output: args.output.write_text(rendered+'\n')
    print(rendered)
    if report['passed'] != report['total']: raise SystemExit(1)

if __name__ == '__main__': main()
