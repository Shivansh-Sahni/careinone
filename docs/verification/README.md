# Verification evidence · 2026-09-07

All test inputs and screenshot records are synthetic. No live model provider, physical iPhone, signing identity, deployment, or external CI run is claimed.

| Check | Result | Durable evidence |
|---|---|---|
| Swift 6 care engine | 50 tests pass | [Swift output](swift-core.txt) |
| Stateless Python gateway | 30 tests pass | [Gateway output](gateway-tests.txt) |
| Real HTTP gateway smoke | Health, auth, extraction, no-store pass | [Wire fixture](../../Tests/Fixtures/gateway-mock-envelope.json), `scripts/backend_smoke.py` |
| iOS 26.5, iPhone 17 Pro | 16 native tests pass before added Keychain test | [Run summary](native-ios26.json) |
| iOS 18.4, iPhone 16 Pro | Final combined run: 17 native tests pass | [Run summary](native-ios18.json) |
| Dark / accessibility-extra-large, iOS 26.5 | 14 tests pass: navigation plus native services | [Run summary](accessibility-ios26.json) |
| iPhone Release, iOS 18 deployment target | Unsigned device build succeeds | [Build record](device-release.txt) |

The 17 final native tests comprise 14 integration tests and 3 UI workflows. Repeated platform runs are not additional unique tests. Automated coverage validates shared service boundaries and critical workflows; it does not substitute for every physical/accessibility check in [VALIDATION.md](../VALIDATION.md).

## Captured running screens

- [Today](today.png)
- [Two conflicting source reports](discrepancy.png)
- [Medication history](medication-history.png)
- [Explicit patient review](review.png)
- [Today in dark mode with accessibility text](today-dark-large-text.png)
- [Medication in dark mode with accessibility text](medication-dark-large-text.png)

## Reproduce

```sh
swift test
python3 -m unittest discover -s backend/tests -v
.venv/bin/python scripts/backend_smoke.py
xcodebuild -project CareContinuity.xcodeproj -scheme CareContinuity \
  -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR' \
  -parallel-testing-enabled NO -jobs 2 test
xcodebuild -project CareContinuity.xcodeproj -scheme CareContinuity \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Local validation used Xcode 26.6, Swift 6.3.3, iOS SDK 26.5, and Python 3.14.3. Test result bundles were retained during development under `/private/tmp/CareContinuity*.xcresult`; the summaries here remain portable after temporary files are removed.
