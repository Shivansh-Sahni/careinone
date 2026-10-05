# CareInOne competitive improvements and naming verification

Run on September 20, 2026 with Xcode 27. Simulator: iPhone 16 Pro, iOS 18.4, arm64. This validates implementation behavior, not clinical effectiveness or superiority over competitors.

| Check | Result | Evidence |
|---|---|---|
| Swift package core | 78 tests / 10 suites pass | `swift-core.txt` |
| Python gateway | 50 tests pass | `gateway-tests.txt` |
| Full native run | 21 integration + 7 UI tests pass; no failures/skips/runtime warnings | `native-summary.json` |
| Final integration run | All 22 integration tests pass after adding the pre-rename export-cleanup regression | `integration-final.json` |
| Unsigned iPhone Release | Build succeeds after the final service change | `device-release.txt` |
| Release preflight | Branding, stable model module, membership, manifests and all 215 capability rows pass | `preflight.txt` |
| Installed-record preservation | Source/claim/entity/loop/conflict payloads unchanged across install and normal launch | `upgrade-preservation.json`; only counts and comparison results retained |
| Visual check | Selected-packet preview is readable, retains both conflict evidence and a synthetic label | `visit-packet.png`, exported from the synthetic UI test |

There are **29 distinct native tests** across the latest runs: 22 integration and 7 UI. The 22-test follow-up repeats the integration tests; it must not be added to the 28-test full run as though all 50 were distinct tests. The only production change after the full UI run was cleanup of old temporary exports; all integration tests and the Release build were rerun afterward.

New core regressions cover profile/note selection, both differing medication reports, earlier unfinished work at a new visit, filtering by save date without hiding unresolved work, pending-claim exclusion, and honest empty output. Native regressions check selected PDF content and cleanup of exports from both product names while preserving unrelated files. UI regressions exercise packet preview/PDF/clear selection and ensure outgoing draft edits invalidate the previously generated PDF without changing future generated packets.

Commands:

```sh
swift test
python3 -m unittest discover -s backend/tests -v
python3 scripts/release_preflight.py
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -destination 'platform=iOS Simulator,id=653F56D1-0FC8-4449-A486-118013DBECAC' \
  -derivedDataPath /private/tmp/CareInOneLaunch -parallel-testing-enabled NO -jobs 2 test
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -destination 'platform=iOS Simulator,id=653F56D1-0FC8-4449-A486-118013DBECAC' \
  -derivedDataPath /private/tmp/CareInOneLaunch -parallel-testing-enabled NO -jobs 2 \
  -only-testing:CareInOneIntegrationTests test
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/CareInOneRelease \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Full result bundles were generated under `/private/tmp/CareInOneLaunch/Logs/Test/`:

- `Test-CareInOne-2026.09.20_20-31-34--0400.xcresult`
- `Test-CareInOne-2026.09.20_20-35-28--0400.xcresult`

The app was then installed from `Debug-iphonesimulator/CareInOne.app` and launched without test/reset/demo flags. Its original database was reopened successfully. Existing records were not replaced or seeded again. A normal-launch screenshot was inspected locally but is not included in these synthetic test artifacts.

Remaining limits: real-device audio/permissions, delivery/share destinations, accessibility with patients, signing/publication, live model accuracy/cost, and the head-to-head competitive trial. No paid service was provisioned and no external message or app release was sent.
