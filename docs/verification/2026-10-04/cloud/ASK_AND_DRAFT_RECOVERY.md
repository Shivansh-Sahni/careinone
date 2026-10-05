# Ask results and draft recovery verification

## Confirmed defects and repairs

Ask previously retained source excerpts in `@State` after its query or saved care changed. Results now render only when the exact query and complete care snapshot match the answered snapshot. Changing either cancels the pending local request, clears excerpts and answer state, and prevents an earlier task from publishing. Source deletion therefore cannot leave its cached quote, summary, or Save-as-question action displayed on return. Duplicate Find submissions are blocked during a search, and a failed search gets a fixed recovery message.

Changing a source's working text or event date already withdrew its claims but left the old processing message. The status now accurately requires reanalysis for nonempty evidence or says working text was cleared and must be added before analysis. It explicitly distinguishes preserved originals/versions from withdrawn proposals/reports. Title-only changes preserve the existing version and status.

Conflict and follow-through draft screens now compare their note/date/precision fields with the original snapshot. Dirty Done actions offer Keep editing or explicit Discard changes; dirty sheet swipes are blocked. State is initialized once in the view initializer, so inspecting supporting evidence and returning cannot silently reset the note. Existing transactional conflict/loop identity checks are unchanged. Note keyboard controls explicitly finish editing while keeping the draft.

## Completed focused runtime verification

The fresh disposable iPhone 18 Pro, iOS 27 simulator `BEFFC231-C67F-4FFC-9F41-53789BF05F78` used only fictional data with `--uitesting --reset --demo`. No primary or screenshot device, patient data, credential store, provider quota, external calendar, or pending notifications were used.

- Ask exact demo quote -> query modification -> prior result disappears -> restored query -> source link -> deletion preview -> explicit source deletion -> return to Ask -> deleted exact quote absent -> fresh search excludes deleted quote and retains other fictional sources: **passed**.
- Nonempty source edit withdraws accepted/pending reports, removes care entities, preserves original binary evidence and prior text versions, and persists the truthful status after reopening. Clearing text produces saved/needs-text status and persists it: **passed**.
- Date-only edit requires reanalysis without claiming nonexistent reports were withdrawn; subsequent title-only change preserves version/status: **passed**.

The focused run intentionally disabled simulator code signing because it does not exercise Keychain. The final candidate must use normal simulator signing and root-owned real connection verification. See `ask-source-status-results.json` and `ask-and-source-status-native.log`; the runner completion status is recorded separately from individual test results.

## Completed draft UI verification

`FollowThroughDraftRecoveryUITests` verified both journeys with normal simulator signing. The clarification-note case passed in 138.803 seconds: Done/swipe/source navigation preserved the unsaved note, explicit discard left the saved note empty and the discrepancy unresolved, and unchanged Done closed directly. The loop case passed in 220.188 seconds: note/date/precision Keep editing and dirty swipe protection, discard restoring saved fields, explicit save, and relaunch persistence all passed.

The initial loop harness tapped the center of the SwiftUI labelled switch row, leaving the actual switch unchanged. The first retry corrected that interaction and then exposed a test assertion that ignored the picker label when a numeric accessibility value existed. Targeting the actual right-hand switch and checking combined label/value/child labels resolved both test-only issues; no production code changed between these runs. Failed initial results and the passing final result are retained separately. The final runner exited 0 with TEST SUCCEEDED. See `follow-through-initial-xcresult-summary.json`, `follow-through-loop-final-xcresult-summary.json`, and the associated native logs. Runtime warnings include AVAudioSession main-thread activation/deactivation and invalid frame dimensions during keyboard transitions; these were not test failures and are not proof of physical-device behavior.

Production edit scope for this batch: AskView only in PatientWorkflowViews.swift, changedEvidence status only in AppStore.editSource, ConflictDetailView and LoopDetailView only in FollowThroughViews.swift. Added tests are isolated native integration/UI fixtures. No new clinical interpretation, feature, paid request, account setting, or public deployment was introduced.
