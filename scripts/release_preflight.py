#!/usr/bin/env python3
"""Read-only repository release checks. This does not certify an App Store release."""
from pathlib import Path
import json
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT/'CareInOne.xcodeproj/project.pbxproj').read_text()
scheme_path = ROOT/'CareInOne.xcodeproj/xcshareddata/xcschemes/CareInOne.xcscheme'
assert scheme_path.is_file()
with (ROOT/'CareInOne/Resources/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleDisplayName'] == 'CareInOne'
assert info.get('ITSAppUsesNonExemptEncryption') is False, 'Audited Apple OS-only encryption requires actual Boolean false, not a string/missing key; revisit this check if the crypto implementation changes'
assert not info.get('ITSEncryptionExportComplianceCode'), 'Do not invent a compliance code for the audited OS-only no-documentation branch'
assert 'PRODUCT_MODULE_NAME = "CareContinuity";' in project, 'Keep the persisted SwiftData module identity until a tested migration replaces it'
# Parse target source phases, not just filename presence: an orphan PBXFileReference
# would otherwise look included while its tests never execute.
parsed = json.loads(subprocess.run(
    ['plutil', '-convert', 'json', '-o', '-', str(ROOT/'CareInOne.xcodeproj/project.pbxproj')],
    check=True, capture_output=True, text=True).stdout)['objects']
source_counts = {}
for target_name, directory in [('CareInOne', 'CareInOne'), ('CareInOneIntegrationTests', 'IntegrationTests'), ('CareInOneUITests', 'UITests')]:
    target = next((item for item in parsed.values() if item.get('isa') == 'PBXNativeTarget' and item.get('name') == target_name), None)
    assert target is not None, 'Missing native target: '+target_name
    references = set()
    for phase_id in target.get('buildPhases', []):
        phase = parsed[phase_id]
        if phase.get('isa') == 'PBXSourcesBuildPhase':
            for build_id in phase.get('files', []):
                reference = parsed[parsed[build_id]['fileRef']]
                references.add(reference.get('path'))
    expected = {p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*.swift')
                if directory != 'CareInOne' or 'Core' not in p.relative_to(ROOT/'CareInOne').parts}
    missing = sorted(expected - references)
    assert not missing, 'Regenerate the Xcode project; missing '+target_name+' source phase members: '+', '.join(missing)
    source_counts[target_name] = len(expected)
scheme = ET.parse(scheme_path)
testables = {reference.get('BlueprintName') for item in scheme.findall('.//TestableReference')
             if item.get('skipped') == 'NO' for reference in item.findall('BuildableReference')}
assert {'CareInOneIntegrationTests', 'CareInOneUITests'} <= testables, 'Shared scheme must include both native test targets'
for path in (ROOT/'CareInOne/Resources').glob('*.plist'):
    with path.open('rb') as stream: plistlib.load(stream)
with (ROOT/'CareInOne/Resources/PrivacyInfo.xcprivacy').open('rb') as stream:
    privacy = plistlib.load(stream)
assert privacy['NSPrivacyTracking'] is False
assert not privacy.get('NSPrivacyTrackingDomains', []), 'The audited no-tracking release has no tracking domains'
ledger=(ROOT/'IMPLEMENTATION_STATUS.md').read_text()
ids=[int(value) for value in re.findall(r'^\| (\d+) \|',ledger,re.MULTILINE)]
assert ids == list(range(1,216)), 'Capability ledger must contain every supplied ID exactly once, in order'
for name in ('MODEL_SETUP.md','RELEASE.md','VALIDATION.md','SECURITY.md'):
    assert (ROOT/'docs'/name).is_file(), 'Missing release document: '+name
listing = (ROOT/'docs/app-store/listing.en-US.md').read_text()
listing_lengths = {}
for heading, limit in [('App name', 30), ('Subtitle', 30), ('Promotional text', 170), ('Description', 4000), ('Keywords', 100), ('First-version release notes', 4000)]:
    match = re.search(r'^## '+re.escape(heading)+r'\s*\n(.*?)(?=^## |\Z)', listing, re.MULTILINE | re.DOTALL)
    assert match is not None, 'Listing section missing: '+heading
    content = match.group(1).strip()
    assert content and len(content) <= limit, f'Actual {heading} length {len(content)} exceeds {limit} or is empty'
    listing_lengths[heading] = {'characters': len(content), 'limit': limit}
assert re.search(r'^## App name\s*\n\s*CareInOne\s*(?=^## )', listing, re.MULTILINE), 'Actual listing name must be CareInOne'
print('PASS: CareInOne branding and compatible model identity, target source membership, Boolean OS-only encryption declaration, property lists, privacy manifest, 215 capability rows, release documents, actual listing field limits.')
print('Native source membership: '+json.dumps(source_counts, sort_keys=True))
print('Actual listing fields: '+json.dumps(listing_lengths, sort_keys=True))
print('Native build/device/live-provider validation and publisher-specific release settings remain separate checks.')
