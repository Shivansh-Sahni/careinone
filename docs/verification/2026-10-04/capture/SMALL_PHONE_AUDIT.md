# iPhone SE / minimum iOS verification

Device: temporary iPhone SE (3rd generation), iOS 18.2 build 22C150. This simulator is separate from the primary iOS 27 candidate runner. Every case uses the isolated `--uitesting` workspace with fictional data; no real patient data, gateway credentials, or system reminders are modified.

## Initial result

`/private/tmp/CareInOneSmallPhone.xcresult` finalized with xcodebuild exit 65: 5 UI cases, 2 passed and 3 failed. Care connections at accessibility size and the empty-patient appointment brief / answer / review / persistence workflow passed. This result is a diagnostic baseline, not readiness evidence.

1. Native PasteButton transferred long Unicode multiline text on a background executor, but its closure inherited MainActor isolation. The app trapped with EXC_BREAKPOINT / SIGTRAP. The sanitized signature is in `ios18-paste-crash-signature.json`: `_dispatch_assert_queue_fail` → `dispatch_assert_queue` → `swift_task_isCurrentExecutorImpl` → `EvidenceTextEditor.body` → SwiftUI PasteHelper.
2. iOS 18 did not expose the expected Select All menu after long press. The diagnostic keyboard fallback was intermittent; the final test uses ordinary native Delete keystrokes in the real focused editor. It still asserts exact empty working text, a successful save, and preservation of original evidence. OS Select All menu behavior was not verified.
3. The companion accessibility test retained an index-bound lazy ScrollView, which was replaced during scrolling. The gesture now measures the visible content bounds and anchors to the stable application coordinate, remaining confined above the keyboard and tab bar and below the navigation bar / demo banner.

## Repair

The one shared EvidenceTextEditor PasteButton callback is explicitly `@Sendable`; immutable transferred strings enter `Task { @MainActor in ... }` before any binding/error update. Character limits and whole-paste rejection remain unchanged. Every application PasteButton uses this callback: source capture, working-text edits, exact supporting quotations, personal notes, question answers, outreach messages, and replies. Generic simulator test compilation succeeded (`paste-isolation-build.log`). Native retest is required before claiming the repair verified.

## Visual inspection

Screenshots from the initial passing cases are saved here. At the largest accessibility size, the persistent fictional-demo banner dominates the small phone and breaks “Fictional” across lines. The parent agent was notified to consider a compact visual label with full VoiceOver semantics. The opening brief has readable paragraphs and reachable native Done / share controls.

## Retest

Pending: `/private/tmp/CareInOneSmallPhoneRetest.xcresult`; log `small-phone-retest.log`. Initial observation: keyboard clearing passed, and native PasteButton now returns the exact 80-line Unicode payload without crashing. The long-paste test then hit a scrolling/keyboard navigation problem locating Save; the source persistence/relaunch portion still needs a successful native run.

### Subsequent results

`CareInOneSmallPhoneRetest.xcresult`: 4 passed / 1 failed, xcodebuild exit 65. The repaired PasteButton returned exact Unicode text; that test then needed explicit keyboard dismissal and an outer-form gesture to reach Save. The keyboard clearing case passed once using native Command-A, but this proved intermittent in later runs.

`CareInOneSmallPhoneFinal.xcresult` and `CareInOneSmallPhoneVerified.xcresult`: 4 passed / 1 failed each, finalized exit 65. The actual 80-line Unicode native PasteButton → source save → ordinary relaunch → exact working-text readback passed in both. Accessibility care connections, appointment companion, and empty-patient brief/answer/relaunch/reviewed latex passed. The latter bundle includes the compact visual Demo/Exit banner with full VoiceOver wording; the screenshot is `small-phone-compact-demo-accessibility.png`.

The clear-text fixture no longer claims Select All menu verification. The iOS 18 simulator's edit-menu and Command-A automation was intermittent, including a focused editor snapshot with keyboard below the visible screen. The authorized test now uses the public Done action, refocuses the visible blank end of the short editor, and sends ordinary native Delete keystrokes. Exact-empty, successful-save, and original-preservation assertions remain. No production shortcut was added for this test.

## Final native verification

`/private/tmp/CareInOneSmallPhoneReleaseChecks.xcresult` finalized with **TEST SUCCEEDED, xcodebuild exit 0: 6 passed, 0 failed, 0 skipped**. Machine-readable result: `small-phone-release-summary.json`. Source and test patches are frozen; no primary simulator, personal data, or credentials were changed.

| Actual native journey | Result |
| --- | --- |
| System PasteButton transfers all 80 Unicode multiline lines, source save, ordinary relaunch, exact working-text readback | Passed, 72.964 seconds |
| Done dismisses keyboard, native Delete clears editable working text, save succeeds, original evidence remains exact | Passed, 33.147 seconds |
| Care connections and timeline at accessibility text size | Passed, 30.736 seconds |
| Appointment companion and getting-unstuck controls at accessibility text size | Passed, 93.185 seconds |
| Empty patient opens appointment brief, saves answers, relaunches, resumes, reviews and saves reported latex allergy | Passed |
| Fictional caregiver outreach/reply survives relaunch and explicit demo reopening, remains pending review, deleted evidence removes cached reply/history | Passed, 159.469 seconds |

The six native cases took 496.662 seconds. Xcode's optional post-test simulator diagnostic collection timed out after 600 seconds, then finalized the successful result. This does not conceal a failed assertion or app crash. Three SwiftUI invalid-frame runtime warnings remain in the result; no negative/nonfinite frame was observed in the retained screenshots. Parent notified for source review. The simulator establishes UI and persistence coverage, not real-device microphone, camera, Calendar or VoiceOver validation.

All earlier failed bundles remain diagnostic evidence. Retained final screenshots use fictional data only; lossless-paste readback, empty working/original separation, appointment answer, reply/history, timeline and accessibility layout are included.
