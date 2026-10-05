# CareInOne connected continuity verification

Verified September 20, 2026 with Xcode 27, macOS 26.6.2, and iPhone 16 Pro / iOS 18.4 simulator. This records the scoped C1–C10 implementation in [the continuity plan](../../../CONTINUITY_IMPROVEMENT_PLAN.md), following [the competitive review](../../../COMPETITIVE_REVIEW_2026-09-20.md).

## Results

| Check | Result | Evidence |
|---|---|---|
| Swift core | 95 tests pass in 11 suites | [Core log](core-tests.log) |
| Stateless gateway | 50 tests pass | [Gateway log](gateway-tests.log) |
| Final combined native run | 28 integration + 9 UI tests pass; no skipped tests or runtime warnings | [Native summary](native-summary.json) |
| Focused workspace navigation regressions | Both new UI flows pass | [Navigation summary](navigation-regression-summary.json) |
| Physical-iPhone target | Unsigned Release build succeeds | [Release summary](release-summary.json) |
| Release preflight | Branding, compatible model identity, project membership, property lists, privacy manifest, 215 capability rows and release documents pass | [Preflight](preflight.log) |
| Existing installation | 20 sources, 19 claims, 14 entities, 7 loops and 2 conflicts preserve their pre-work payload bytes | [Upgrade check](upgrade-preservation.json) |
| Normal reinstall | All 12 decoded record types, including profile/settings, and one protected original file remain unchanged | [Reinstall check](reinstall-preservation.json) |

The profile's raw JSON bytes differ from the earlier baseline, so the upgrade check does not assert byte identity for that row. The later reinstall check compares decoded JSON with sorted keys and verifies semantic equality for all record types, as well as exact original-file bytes. Native legacy-payload tests independently verify recovery of profile fields and the absence of new optional metadata. No normal patient reset, demo refresh or reload was used.

## What was exercised

- Copy-only acceptance preview with the actual local reconciler; no canonical mutation or reminders until the existing review transaction commits.
- Side-by-side saved-information comparisons, including older medical events added later, pending/rejected exclusions, changes in uncertainty, patient-reported completion and removed evidence.
- Named checkpoints and visit workspaces through SQLite relaunch and encrypted backup/restore; legacy data without continuity metadata still opens.
- Checkpoint evidence deletion, surviving loop identities, failed-deletion rollback, protected-file preservation, demo removal and complete erasure.
- A completely empty patient creates a visit workspace, saves an empty starting checkpoint, enters `Allergy: latex` and a separate unanswered question, saves evidence, reviews the actual allergy proposal, previews its impact, accepts it, and exports the checkpoint comparison as text/PDF.
- A patient with synthetic demo data saves a recollection draft, relaunches the app, recovers that draft, and inspects a source deletion preview without deleting the source.
- Existing capture/review, discrepancy reopening, personal notes, practice imports, demo source navigation, selected visit packet and editable outgoing message workflows remain passing.

## Failures found and corrected

Intermediate results are not counted as passing verification:

1. Deleting the earliest source could change a surviving loop's identifier and make it look like new work against a redacted checkpoint. Surviving claim references now prevent that false comparison; removed source text is still purged.
2. Generated recollection headings were offered as extracted claims. Original evidence retains those headings, but extraction receives only exact patient-entered recollections and next steps. The native regression now requires the actual latex allergy proposal; unanswered questions remain separate.
3. Nested item and value navigation could reopen the workspace over its comparison. Replacing them with one explicit route path exposed an environment-propagation crash in the next run. Route state now belongs to the entire navigation stack, and both focused UI flows plus the final full 37-test run pass.

## Visual inspection

These images contain synthetic test examples only. Inspected for legible text, correct destination, working action placement, honest comparison context and the actual reviewed allergy rather than a generated heading.

- [Reviewed recollection in its checkpoint comparison](checkpoint-comparison.png)
- [Review impact before acceptance](review-impact.png)
- [Deletion impact with synthetic evidence](deletion-impact.png)

The three screenshots come from the passing focused run. The final combined run used the same app code. A separate normal-launch screen was inspected locally and was not copied into this verification folder.

## Reproduce

Run from the repository root. Use your own simulator identifier if necessary.

```sh
swift test
python3 -m unittest discover -s backend/tests -v
python3 scripts/release_preflight.py
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=653F56D1-0FC8-4449-A486-118013DBECAC' \
  -derivedDataPath /private/tmp/CareInOneLaunch \
  -resultBundlePath /private/tmp/CareInOneContinuityVerified.xcresult \
  -parallel-testing-enabled NO test
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/CareInOneRelease CODE_SIGNING_ALLOWED=NO build
```

Choose a new result-bundle path when repeating the native run; Xcode does not overwrite an existing bundle. UI tests use their isolated `CareInOneUITests` vault. Normal launch uses the stable installed database and no test/reset flags.

## Boundaries

This is automated and simulator evidence, not a comparative usability trial, clinical validation, signing/distribution approval or a funded model evaluation. The app has no live portal connection, automatic cross-device sync or collaborative caregiver account. Draft recovery requires choosing Save draft. Checkpoints are bounded to 100 and 25,000 combined copied reports; workspaces to 100. Static shared copies cannot be remotely revoked. See the specific remaining [physical-iPhone/live-provider checks](../../../VALIDATION.md).
