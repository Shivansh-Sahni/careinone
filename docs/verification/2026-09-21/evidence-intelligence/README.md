# CareInOne evidence intelligence verification

Verified September 21, 2026 with Xcode 27, macOS 26.6.2 and iPhone 16 Pro / iOS 18.4 simulator. This records N1–N10 in [the acceptance plan](../../../EVIDENCE_INTELLIGENCE_PLAN.md). These are implemented local workflows; this record does not establish world-first originality, clinical validity or superiority to other products.

## Results

| Check | Result | Evidence |
|---|---|---|
| Swift core | 113 tests in 12 suites pass | [Core log](core-tests.log) |
| Stateless gateway | 50 tests pass | [Gateway log](gateway-tests.log) |
| Combined native run | 33 integration + 13 UI tests pass; zero failures, skips or runtime warnings | [Native summary](native-summary.json) |
| Final deletion disclosure | Saved visit draft/relaunch/source-deletion preview workflow passes after the wording update | [Follow-up summary](deletion-disclosure-summary.json) |
| iPhone Release | Unsigned build succeeds with the final disclosure; no compiler warnings | [Release summary](release-summary.json) |
| Release preflight | Branding, stable model identity, Xcode membership, property lists/privacy, all 215 capability rows and listing bounds pass | [Preflight](preflight.log) |
| Normal installation | All 12 decoded record types and one original evidence file preserve their pre-update hashes | [Upgrade preservation](upgrade-preservation.json) |

The combined native run exercised the final feature logic and accessible layouts. The only subsequent app-code edit clarified source deletion's effect on copied handoffs and locally prepared exports. The relevant UI workflow and unsigned Release build were rerun afterward. Core and gateway code were unchanged by that disclosure edit.

The normal simulator still contains 20 sources, 19 claims, 14 entities, seven loops and two discrepancies. No patient reset or demo reload was used. The fingerprint check compares canonicalized decoded JSON for every record type, including profile/settings and audit rows, plus exact original-file bytes. The saved report contains only counts/hashes, never patient text. Both UI test suites and native persistence tests use isolated test data.

## What was exercised

- Typed evidence nodes and deterministic upstream/downstream traversal across preserved sources, reviewed reports, care items, discrepancies and follow-through. Pending, rejected and nonpatient claims stay outside the accepted graph. Cycles, depth/node bounds and explicit truncation are tested.
- Joint omission of multiple sources using the actual local reconciler on a copy. Tests assert that the original state is unchanged and disappearing records are not labeled medical completion. The UI supports cancellation and discards results when the selected sources or saved state change.
- Medical event/effective dates remain distinct from capture/review timestamps. Unknown report dates are never filled from the source or upload date. Late-arriving evidence sorts on the selected time axis without inventing medical chronology.
- Selected handoff text is immutable, includes only the chosen packet items/profile fields, and retains a SHA-256 content identifier. Native PDF text is checked against the saved copy. A fresh patient can begin with one question and no medical history.
- Handoff context comparison includes relevant reviewed claims, supporting-source content/metadata, discrepancies, workflows, selected questions/notes and explicitly included profile fields. Pending or unrelated claims are excluded. Re-analysis with new report/entity IDs still changes the source fingerprint, without silently merging those identities. A deterministic rebuild does not itself create a change.
- Sharing and finishing are patient-reported organizational actions. Finishing does not resolve a discrepancy or complete a care task. New reviewed evidence is visible against both the outgoing-copy baseline and the baseline captured at finishing; the handoff can reopen.
- Reply text/date/synthetic choice survive explicit draft saving and SQLite relaunch. Capturing a reply preserves exact text and runs real local extraction. The allergy proposal affects care only after explicit review. Duplicate reply capture, failed saves and stale packet selections are covered.
- Handoffs and drafts round-trip through encrypted backup. Legacy profile/archive data without the new optional metadata still opens. Invalid references, digest tampering and bounds are rejected.
- Deleting a supporting source removes its copied outgoing handoff text and comparison references. Export cleanup occurs only after successful persistence; a failed transaction preserves records/files. Independently captured replies survive handoff deletion and real replies survive synthetic-data removal. Encounter removal detaches handoffs safely.

## Visual inspection

All checked-in images contain synthetic test examples. They were inspected for readable text, source links, truthful date/change labels and usable actions:

- [Care connections](care-connections.png)
- [Medication evidence trace](evidence-trace.png)
- [Medical and capture timeline](two-date-timeline.png)
- [Combined source omission](combined-omission.png)
- [Exact selected handoff copy](exact-handoff-copy.png)
- [Reviewed information added after finishing a handoff](handoff-changes.png)
- [Care connections at maximum accessibility text](care-connections-accessibility.png)
- [Timeline introductory text at maximum accessibility text](timeline-accessibility.png)
- [Final source-deletion disclosure](deletion-disclosure.png)

The accessibility run verifies scrolling/navigation into the timeline at `UICTContentSizeCategoryAccessibilityXXXL`; it is not a complete VoiceOver or device accessibility audit. [Screenshot provenance](screenshots.json) identifies the result bundles. A normal-launch screenshot was inspected locally but not copied here.

## Reproduce

Run from the repository root, substituting an available simulator ID and unused result-bundle path:

```sh
swift test
python3 -m unittest discover -s backend/tests -v
python3 scripts/release_preflight.py
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=653F56D1-0FC8-4449-A486-118013DBECAC' \
  -derivedDataPath /private/tmp/CareInOneLaunch \
  -resultBundlePath /private/tmp/CareInOneIntelligenceVerified.xcresult \
  -parallel-testing-enabled NO test
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/CareInOneRelease CODE_SIGNING_ALLOWED=NO build
```

For an upgrade comparison, run `scripts/simulator_fingerprint.py --device DEVICE_ID --output OUTPUT_PATH` before and after installation. Compare the two JSON values. Do not pass UI-test/reset/demo flags when launching the normal patient. The verification script reads the database and evidence without modifying them.

## Remaining boundaries

All new tools function locally without a model key. Local reply extraction remains deliberately conservative; arbitrary prose may need manual structured entry or optional cloud analysis. A graph edge describes an information relationship, not medical causality. Source omission never simulates a treatment choice. A content digest is not a signature or delivery receipt. Timeline entries show current reviewed versions, not every prior edit.

Handoff limits are 100 records, 2M combined outgoing/draft characters, 200K per outgoing copy, 30K per reply draft, 500 selected items and 50K combined comparison fingerprints (10K per context). Graph traces default to 200 nodes/six steps with drill-down; omission previews accept up to 30 sources. Draft recovery requires choosing Save draft. External shared copies cannot be recalled.

There is no collaborative caregiver account, live portal sync or automatic delivery acknowledgement. Signing, physical-iPhone validation, funded-provider evaluation and patient usability studies remain separate. Specific remaining steps are in [VALIDATION.md](../../../VALIDATION.md), including new handoff, omission, sharing and deletion checks.
