# CareInOne patient companion verification

This pass implements [P1–P10](../../../PATIENT_COMPANIONS.md): preparing what to say, keeping appointment answers, arranging care, remembering outreach, and saving actual replies for review. Verification uses Xcode 27 and an iPhone 16 Pro / iOS 18.4 simulator. No comparative patient study or first-in-market claim is made.

## Results

| Check | Result | Evidence |
|---|---|---|
| Complete Swift core suite | 156 tests pass: 150 Swift Testing and six XCTest cases | [Core log](core-tests.log) |
| Broad native regression run | 43 integration and 15 UI tests pass; one UI automation tap failed | [Full intermediate result](broad-run-summary.json) |
| Final native regression | 44 integration + four patient companion UI tests pass; zero failures, skips or runtime warnings | [Final result](final-native-summary.json) |
| Final layout verification | Both affected UI workflows pass after brief content order and accessibility progress layout adjustment; zero failures, skips or runtime warnings | [Final layout result](layout-summary.json) |
| iPhone Release | Final app code builds successfully, unsigned; no compiler warnings | [Release summary](release-summary.json) |
| Release preflight | Branding, compatible model identity, project membership, privacy/property lists, 215 original capability rows and listing bounds pass | [Preflight](preflight.log) |
| Normal installation preservation | All 12 decoded record types and the original evidence file are identical after reinstall and normal launch; existing demo preserved | [Counts and hashes](upgrade-preservation.json) |

The broad run passed all 13 pre-existing UI workflows. The remaining new workflow failure was an automation tap on the partially clipped deletion-preview footer: XCTest reported it as hittable, but its center was below the sheet. The test now scrolls the actual action fully into view and requires the confirmation before deleting. An earlier targeted test had a scroll-direction error when returning to a reply editor; that was corrected. The first targeted Xcode driver stalled collecting failure diagnostics after its tests ended and was terminated; subsequent runs use `-collect-test-diagnostics never`. Those intermediate runs are not presented as passing evidence.

Final app corrections made during verification include preserving drafts while source corrections retire derived tasks, invalidating deleted helper copies, protecting unsaved live answers when opening their source, rejecting captures that mix real answers with synthetic-question answers, and separating a future appointment's date from the older encounter where it was mentioned. The final native run includes the new appointment-date and source-navigation regressions. The final visual pass puts the patient's opening text before export controls and stacks the question progress at accessibility text sizes; affected UI tests and the unsigned Release build are rerun for that presentation-only change.

The gateway was unchanged in this pass. Its last verified 50-test result is recorded in the [preceding verification](../evidence-intelligence/README.md); it was not rerun merely to increase the count.

## Patient workflows exercised

- Start from an empty patient with no medical history or known appointment date. Edit a personal opening, create the exact short brief PDF, enter live visit mode, write an answer, advance, quit and reopen, return to that answer, and save it as evidence. The actual local allergy proposal requires explicit review before it appears in My Care.
- Copy and reorder saved questions and source-grounded suggestions as editable agenda snapshots. Keeping a question for later, discussing it, or finishing the companion does not finish care tasks or resolve discrepancies.
- A future cardiology appointment mentioned in a prior PCP recap uses the cardiology date. Its companion and captured answers do not silently attach to the PCP encounter. Explicitly chosen encounters remain supported.
- Choose an obstacle, generate an editable clinic message, record actual outreach, save a reply draft, quit/reopen, and preserve the reply as evidence. Saving and outreach do not advance a clinical state machine.
- Personal check-back dates appear locally even when notifications are off. Scheduling requires consent, task relevance and a future date; completed, dismissed and paused tasks do not produce active-task check-back reminders. Clinical due dates remain unchanged.
- Source corrections preserve paused helper drafts and history through SQLite reload and encrypted archive validation. Explicit reconnection after review preserves the patient's outgoing edits; it does not automatically replace the message or merge helper plans.
- Supporting-source deletion removes copied helper messages/history/drafts and linked appointment questions. Captured-answer deletion clears retained answer copies. Independent evidence remains unless separately deleted. Failed transactions preserve the prior committed graph and files.
- Legacy payloads without companion metadata open normally. New metadata and drafts round-trip through the existing protected local store and encrypted backup. Restore resets cloud and notification consent; it does not import provider keys.
- Failed helper saves retain session drafts, pause automatic retries, and support Retry/Discard. Successful deletion/restore clears session recovery copies. Session-only recovery is not promised after force-quit or device power loss.
- Synthetic and real answers remain distinct, including unused demo prompts, answer edits, duplicate capture and source corrections. Invalid dates/references, duplicate IDs and storage limits are rejected.

## Visual inspection

Six synthetic screenshots were inspected after the passing runs. The opening brief now presents the patient's priorities and questions before sharing controls. The live appointment shows one question, its answer and saved state. Follow-through separates the next step from replies and outreach, and the reply can be preserved as evidence for review. At the largest accessibility text size, progress stacks vertically and actions wrap in the scrollable content; the tested controls remain reachable. Large-text navigation exercises `UICTContentSizeCategoryAccessibilityXXXL`; this is not a complete VoiceOver or physical-device accessibility audit.

| Surface | Inspected screenshot |
|---|---|
| Opening brief | [Patient's opening and questions](screenshots/opening-brief.png) |
| Live appointment | [Saved answer](screenshots/appointment-answer.png) |
| Follow-through | [Obstacle and next step](screenshots/follow-through-next-step.png) |
| Actual reply | [Reply saved for review](screenshots/follow-through-reply.png) |
| Appointment, largest accessibility size | [Stacked progress and question](screenshots/appointment-accessibility.png) |
| Follow-through, largest accessibility size | [Reachable outreach actions](screenshots/follow-through-accessibility.png) |

[Screenshot provenance](screenshots.json) records the test and result bundle for every image. The normal user's saved data is not copied into verification screenshots. The normally launched Today screen was also inspected locally: it displays the existing synthetic-data label, saved care counts and appointment companion entry. Xcode and the simulator are open with that unchanged installation.

## Reproduce

From the repository root, use an available simulator ID and an unused result-bundle path:

```sh
swift test
python3 scripts/release_preflight.py
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -destination 'platform=iOS Simulator,id=653F56D1-0FC8-4449-A486-118013DBECAC' \
  -derivedDataPath /private/tmp/CareInOneLaunch \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath /private/tmp/CareInOnePatientCompanionsRecheck.xcresult test
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/CareInOneRelease CODE_SIGNING_ALLOWED=NO build
```

The final targeted run uses `-only-testing:CareInOneIntegrationTests -only-testing:CareInOneUITests/PatientCompanionUITests` after the broad regression run. Compare `scripts/simulator_fingerprint.py` output before and after normal reinstall/launch to verify all 12 decoded record types and original-file bytes. Do not use reset/demo/test flags for the normal installation.

## Limits and remaining validation

Everything added in this pass functions locally without a model subscription. The local extractor supports bounded explicit patterns; arbitrary prose may need manual entry or optional cloud extraction. The system never chooses which clinical instruction is correct.

Companions are limited to 50 sessions, 40 questions each, 2,000 characters per question, 10,000 per answer, 5,000 per opening, and 500,000 aggregate text characters. Follow-through helpers allow 200 plans, 20,000 characters per message/reply, 2,000 per outreach note, 200 history entries per plan, and two million combined stored text characters. These are explicit validation limits, not silent truncation of the patient's entered answer.

Read aloud uses explicit system speech synthesis. Audible output, offline voice availability, interruptions, Bluetooth/headphones, lock/background behavior, real sharing destinations, local notification delivery, VoiceOver and patient usability studies remain physical validation tasks. See [VALIDATION.md items 19–22](../../../VALIDATION.md). Successful draft persistence is durable; failed disk writes retain only the prior saved state plus the documented current-session recovery. Externally shared copies and old backups cannot be recalled. No live collaborative caregiver account, portal integration, automatic message delivery or clinical advice is implied.
