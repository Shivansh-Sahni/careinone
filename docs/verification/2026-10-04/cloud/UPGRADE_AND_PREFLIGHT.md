# Normal-install preservation and final source preflight

Prepared for the parent to run against the existing main simulator. This subtask did not inspect that simulator or operate a device. `simulator_fingerprint.py` reads only the selected application's CareContinuity SQLite payloads and original Evidence directory. It does not read Keychain, credentials, `.env`, app preference files or another app's container. It emits record counts and SHA-256 values; original filenames and patient text are not printed.

The default remains the personal workspace and the original `records`/`evidence` JSON layout. `--workspace demo` selects only `Library/Application Support/CareContinuity/FictionalDemo`. Both include the entire decoded Preferences record, including profile, loop overrides, continuity, handoffs, appointment companions and follow-through drafts. Binary originals are streamed into hashes. SQLite physical bytes are not compared, because storage housekeeping and equivalent JSON formatting can change bytes without losing records.

The utility now rejects missing/unrecognized model tables, invalid columns, duplicate keys, malformed/ambiguous JSON, symlinked originals and report outputs inside the app's data container. It allows the known Core Data/SwiftData metadata tables without reading their contents. A schema-name-only check authorized by the parent on the main simulator confirmed ACHANGE, ATRANSACTION and ATRANSACTIONSTRING as additional persistent-history bookkeeping; these exact names were added to the allowlist, with no row values read. A new model must be explicitly added to the known table list and tested before a new comparison can pass. It never treats a partial table inventory as preserved data.

## Parent-run preservation sequence

Use the actual main simulator UDID and the reviewed final `.app` path. These assignments are examples with explicit placeholders; do not use a test simulator or change the app bundle ID. The main simulator's isolated demo was not initialized when the parent checked. `--workspace demo --allow-absent` records an explicit absent baseline without creating/resetting anything; a partially present or invalid store still fails. Continued absence is not evidence that demo records were preserved.

```sh
CARE_UPGRADE_DEVICE_ID='MAIN_SIMULATOR_UDID'
CARE_UPGRADE_APP_PATH='/absolute/path/to/final/CareInOne.app'
```

After saving any intentional drafts, terminate the app normally and wait for termination. This prevents concurrent app edits between SQLite and evidence reads. Do not clear data, uninstall, reset Keychain, launch with UI-test/reset arguments, remove the demo or change consent while collecting these checks.

```sh
xcrun simctl terminate "$CARE_UPGRADE_DEVICE_ID" org.carecontinuity.app
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --output docs/verification/2026-10-04/cloud/upgrade-personal-before.json
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --workspace demo --allow-absent --output docs/verification/2026-10-04/cloud/upgrade-demo-before.json
```

The fingerprint commands are read-only apart from their report files. The next commands are the explicitly authorized install/launch operations and must be performed by the parent. Normal install replaces the binary without uninstalling the app. Preserve the compatibility bundle identifier `org.carecontinuity.app` and module/model identity `CareContinuity`.

```sh
xcrun simctl install "$CARE_UPGRADE_DEVICE_ID" "$CARE_UPGRADE_APP_PATH"
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --output docs/verification/2026-10-04/cloud/upgrade-personal-after-install.json
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --workspace demo --allow-absent --output docs/verification/2026-10-04/cloud/upgrade-demo-after-install.json
xcrun simctl launch "$CARE_UPGRADE_DEVICE_ID" org.carecontinuity.app
```

Inspect the normally launched personal view without editing content. If the demo baseline was present, switch to it using the existing controls and confirm its drafts/originals load and remain isolated. If the demo baseline was absent, do not open or initialize it until the preservation comparison is finished. Then terminate and collect another pair. The parent should retain any failure instead of replacing it with a new baseline.

```sh
xcrun simctl terminate "$CARE_UPGRADE_DEVICE_ID" org.carecontinuity.app
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --output docs/verification/2026-10-04/cloud/upgrade-personal-after-launch.json
python3 scripts/simulator_fingerprint.py --device "$CARE_UPGRADE_DEVICE_ID" --workspace demo --allow-absent --output docs/verification/2026-10-04/cloud/upgrade-demo-after-launch.json
```

Compare the complete hash objects without dumping individual records or original names:

```sh
python3 - <<'PY'
from pathlib import Path
import json
root = Path('docs/verification/2026-10-04/cloud')
summary = {'verification': 'normal_install_and_launch', 'workspaces': {}}
for workspace in ('personal', 'demo'):
    before = json.loads((root / f'upgrade-{workspace}-before.json').read_text())
    installed = json.loads((root / f'upgrade-{workspace}-after-install.json').read_text())
    launched = json.loads((root / f'upgrade-{workspace}-after-launch.json').read_text())
    summary['workspaces'][workspace] = {
        'baseline_state': before.get('workspace_state', 'present'),
        'decoded_records_and_originals_preserved_after_install': before == installed,
        'decoded_records_and_originals_preserved_after_launch': before == launched,
        'record_types': len(before['records']),
        'record_count': sum(value['count'] for value in before['records'].values()),
        'original_count': len(before['evidence']),
    }
(root / 'upgrade-preservation-result.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary))
PY
```

If a legitimate migration or documented launch operation changes a digest, record the actual changed table/category and independently prove preservation; do not automatically declare data loss or silently allowlist a difference. This fingerprint cannot verify Keychain, Calendar receipts, delivered reminders, external shared copies, archive encryption or clinical correctness. Those have separate integration/hardware checks.

After the final comparison, normally launch the app and leave the isolated fictional demo visible as requested. If the parent initializes a previously absent demo at this point, record that as a separate intentional action after preservation verification. Do not re-seed personal records.

## Final dependency/privacy/source checklist

The read-only inventory is in `source-dependency-privacy-check.json`. At inspection, native dependencies were the local CareCore package and Apple frameworks, with zero remote Swift packages. The generated resource phase included PrivacyInfo.xcprivacy. Backend runtime requirements were exactly locked for click, h11 and uvicorn; Docker's Python minor-version tag was not digest-pinned, so the lock is not proof of an identical base image. Final build/runtime evidence must identify what actually ran.

1. **Freeze final source and regenerate target membership.** The first read-only `release_preflight.py` invocation found three newly added integration files missing from the source phase. The parent regenerated the project; the next invocation passed with 35 app, 14 integration and five UI source files, including audio/alias/stale-edit regressions. Current evidence is `source-preflight.log`. Preserve the intended signing team separately across any later regeneration, and rerun after subsequent changes.
2. **Execute final candidate tests.** Run the shared core, backend, native integration and relevant UI suites against the final source snapshot. Include the new audio, alias and stale-edit regressions. Fixture validation for the fingerprint itself is `python3 -m unittest discover -s scripts/tests -v`: 14 fictional-fixture tests passed here, with no simulator row or credential access.
3. **Check the built app, not only source references.** Verify compiled Info.plist branding CareInOne, version/build, stable bundle identifier, iOS 18 deployment target, iPhone/iPad orientations, selected device families, and actual PrivacyInfo.xcprivacy in the final app/archive. Validate the actual icon and required assets. An unsigned simulator app is not an App Store archive.
4. **Reconcile privacy declarations and behavior.** Current source declares tracking false/no domains and linked Health plus Other User Content for App Functionality, matching optional health-text processing. Required-reason entries are FileTimestamp/C617.1 and app-only UserDefaults/CA92.1. Check the compiled privacy report, public policy, provider retention evidence and App Store Connect questionnaire together. `store:false` is not Zero Data Retention. Do not claim remote photo/audio upload: this pipeline sends working text/date and keeps originals local.
5. **Validate permissions and entitlements.** Purpose strings cover chosen microphone capture, on-device speech, camera, Face ID and Calendar write-only access. The only source entitlement is complete default data protection. No push/iCloud/HealthKit/background-audio/IAP entitlement is implemented. Physical microphone interruption, speech-language availability, notification denial/recovery/delivery, Calendar permission and biometric behavior need actual hardware evidence where claimed.
6. **Preserve free-release and spending decisions.** No purchase, subscription, ad or operating-limit increase was introduced. Do not provision a new paid service, automatically raise quotas or embed a shared provider/gateway credential in the public client. A verified private developer connection is separate from public-user cloud enrollment.
7. **Repeat production endpoint checks after final deployment.** Compare public privacy/support bytes and headers with the reviewed local pages, verify authenticated configuration rejects credential-like metadata and use only the parent's bounded fictional cloud procedure. Record real/mock identity precisely and keep credentials/raw bodies out of reports.
8. **Complete publisher-specific signing and submission.** Confirm the NutriAssist organization approval, team/App ID ownership, actual distribution certificate/profile, archive validation and upload identity. The active individual membership does not authorize publishing under NutriAssist or substitute for that release dependency. Check free pricing, app rights, age rating, accessibility/review notes, privacy/support URLs and final iPhone/iPad screenshots against actual App Store Connect.

These are concrete final checks, not certification that the app is submission-ready. The parent owns the final candidate result and remaining publication actions.

## Archive and validation commands

These commands are prepared for the parent; this subtask has not run an archive, signed app, export or upload. Signing was previously checked by the parent: no installed usable signing certificate and NutriAssist conversion not yet approved. Do not use the active individual identity as a workaround. A simulator build, unsigned archive and source-preflight pass cannot be uploaded as a signed NutriAssist App Store release.

An unsigned device archive can verify optimized device compilation and packaging now:

```sh
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne -configuration Release -destination 'generic/platform=iOS' -archivePath artifacts/CareInOne-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO archive > docs/verification/2026-10-04/cloud/unsigned-archive.log 2>&1
```

Read only the compiled public metadata/resources after a successful archive. This verifies actual packaging without reading a provisioning credential or patient container:

```sh
python3 - <<'PY'
from pathlib import Path
import json, plistlib
app = Path('artifacts/CareInOne-unsigned.xcarchive/Products/Applications/CareInOne.app')
info = plistlib.loads((app / 'Info.plist').read_bytes())
manifest = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
result = {
    'bundle_identifier': info['CFBundleIdentifier'],
    'name': info['CFBundleDisplayName'],
    'version': info['CFBundleShortVersionString'],
    'build': info['CFBundleVersion'],
    'minimum_os': info.get('MinimumOSVersion'),
    'device_families': info.get('UIDeviceFamily'),
    'non_exempt_encryption': info.get('ITSAppUsesNonExemptEncryption'),
    'privacy_manifest_packaged': True,
    'tracking': manifest['NSPrivacyTracking'],
    'required_reason_apis': manifest['NSPrivacyAccessedAPITypes'],
    'collected_data_types': manifest['NSPrivacyCollectedDataTypes'],
}
assert result['bundle_identifier'] == 'org.carecontinuity.app'
assert result['name'] == 'CareInOne'
assert result['non_exempt_encryption'] is False
assert result['tracking'] is False
Path('docs/verification/2026-10-04/cloud/unsigned-archive-packaging.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
PY
```

Only after the NutriAssist team, App ID and signing material are verified, produce the signed archive with that actual team ID. This command does not authorize new certificates, a substituted identity or automatic publication:

```sh
export CARE_NUTRIASSIST_TEAM_ID='VERIFIED_NUTRIASSIST_TEAM_ID'
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne -configuration Release -destination 'generic/platform=iOS' -archivePath artifacts/CareInOne-NutriAssist.xcarchive DEVELOPMENT_TEAM="$CARE_NUTRIASSIST_TEAM_ID" archive > docs/verification/2026-10-04/cloud/signed-archive.log 2>&1
codesign --verify --strict --deep artifacts/CareInOne-NutriAssist.xcarchive/Products/Applications/CareInOne.app
```

Create export options locally using the verified team. `method=app-store-connect` and `destination=export` are supported by the installed Xcode's own `xcodebuild -help`; the latter prepares files and does not request an upload. The help also distinguishes a `validation` distribution method. Do not replace `destination` with `upload` or run upload commands until the publisher dependency and final release decision are resolved.

```sh
python3 - <<'PY'
from pathlib import Path
import os, plistlib
team = os.environ.get('CARE_NUTRIASSIST_TEAM_ID', '')
assert team and team != 'VERIFIED_NUTRIASSIST_TEAM_ID', 'Use the actual approved NutriAssist team; do not substitute the individual team'
options = {'method': 'app-store-connect', 'destination': 'export', 'signingStyle': 'automatic', 'teamID': team}
Path('artifacts/CareInOne-export-options.plist').write_bytes(plistlib.dumps(options))
PY
xcodebuild -exportArchive -archivePath artifacts/CareInOne-NutriAssist.xcarchive -exportPath artifacts/CareInOne-AppStore-export -exportOptionsPlist artifacts/CareInOne-export-options.plist > docs/verification/2026-10-04/cloud/archive-export.log 2>&1
```

No secret key is required in this options file. Installed signing certificates/profiles and an approved team remain requirements. Local codesign/export success does not prove App Store review acceptance or privacy-label accuracy. Use Xcode Organizer's **Validate App** on the signed NutriAssist archive and record Apple's actual validation result; upload and release remain separate publication actions owned by the parent/publisher.
