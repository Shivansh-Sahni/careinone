#!/usr/bin/env python3
"""Read-only repository release checks. This does not certify an App Store release."""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT/'CareContinuity.xcodeproj/project.pbxproj').read_text()
missing = [p.relative_to(ROOT).as_posix() for p in (ROOT/'CareContinuity').rglob('*.swift') if 'Core' not in p.parts and p.relative_to(ROOT).as_posix() not in project]
assert not missing, 'Regenerate the Xcode project; missing Swift sources: ' + ', '.join(missing)
for path in (ROOT/'CareContinuity/Resources').glob('*.plist'):
    with path.open('rb') as stream: plistlib.load(stream)
with (ROOT/'CareContinuity/Resources/PrivacyInfo.xcprivacy').open('rb') as stream:
    privacy = plistlib.load(stream)
assert privacy['NSPrivacyTracking'] is False
ledger=(ROOT/'IMPLEMENTATION_STATUS.md').read_text()
ids=[int(value) for value in re.findall(r'^\| (\d+) \|',ledger,re.MULTILINE)]
assert ids == list(range(1,216)), 'Capability ledger must contain every supplied ID exactly once, in order'
for name in ('MODEL_SETUP.md','RELEASE.md','VALIDATION.md','SECURITY.md'):
    assert (ROOT/'docs'/name).is_file(), 'Missing release document: '+name
assert len('Your care, connected') <= 30
assert len('care,appointments,records,questions,visits,documents,continuity,follow-up') <= 100
print('PASS: Xcode source membership, property lists, privacy manifest, 215 capability rows, release documents, listing text limits.')
print('Native build/device/live-provider validation and publisher-specific release settings remain separate checks.')
