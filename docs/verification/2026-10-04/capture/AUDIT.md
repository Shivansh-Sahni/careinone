# Capture pipeline verification — 2026-10-04

All fixtures below are fictional. The simulator tests use only the isolated `--uitesting` store.

## Repairs

- New capture and source editing have an explicit system Paste control, lossless Unicode/multiline paste, a character counter, and a keyboard Done control. Save is blocked with a clear error for more than one million characters.
- Capture preserves a staged original after interrupted extraction. Import cancellation invalidates the task run before it can change text. Save cannot run during import, recording preparation, or transcription. Repeated transcription starts are guarded.
- Choosing replacement files/photos requires confirmation when working text exists. An older staged original remains available in Sources instead of being silently deleted. Empty photo-transfer results and persistence failures have actionable errors.
- PDF processing preserves short valid embedded text if OCR returns nothing, identifies blank/unreadable PDFs, bounds page count, and retains malformed original bytes for recovery.
- Source edits preserve explicitly cleared working text and immutable original evidence. Cancel prompts before losing edits. Source search includes original text and provider.
- A source showing Processing without a live analysis task offers recovery instead of an indefinite spinner.
- Audio permission/setup cannot create multiple simultaneous recordings. Transcription times out after five minutes and preserves retained audio when unsuccessful. On-device recognition remains the supported mode.
- Saving a blank, locked, or unreadable staged original does not attempt analysis with empty text. The saved original remains available for extraction retry or a typed recap. A canceled native file picker leaves the capture unchanged.
- Staged files in the isolated demo workspace keep their synthetic flag. Recording preparation, missing-source saves, failed transcript persistence, and empty recognition now have explicit recovery messages; failed cleanup keeps its draft association available for retry.
- Deduplication retains separate sources for identical instructions from a different event, encounter, provider, or source kind. Repeated submissions with the same bytes and care context still reuse the original source and file.
- Speech permission wording applies to this device, including iPad.

## Evidence

`focused-tests.log` records all 10 CapturePipelineIntegrationTests and 4 CloudSafetyIntegrationTests passing. These cover persistence/relaunch, duplicate capture, Unicode/long paste, bounded files, blank/malformed PDFs and photos, cancellation, original preservation, save rollback, and FHIR review gating.

The same log records `testSystemPasteLongMultilineTextSavesAndSurvivesRelaunch` passing (56.94 seconds). It uses UIPasteboard and the native PasteButton with 80 multiline Unicode lines, saves, relaunches, and verifies exact text in the editing screen.

`keyboard-retest.log` records `testKeyboardDoneAndClearedWorkingTextKeepOriginalEvidence` passing (37.608 seconds). It types a multiline source, dismisses the keyboard, saves, clears text through native Select All, saves, and verifies empty working text plus preserved original text.

The first clearing-text UI attempt failed because its deletion sequence started from an arbitrary caret position. The repaired test selects all text before deletion and confirms the editor is empty; the application behavior passes.

## Expanded candidate checks

`CapturePipelineIntegrationTests` now contains 20 cases. The additional cases cover exact per-field paste limits with Unicode and multiple items; preservation of an editable draft after oversized paste; encrypted PDF recovery without decrypted content or lost original bytes; canceled PDF processing; extraction cancel/retry; interrupted file extraction after relaunch; blank extraction status; storage failure ending live progress and allowing retry; deletion preventing late resurrection; and care-context-aware duplicate handling.

`expanded-build.log` records a successful generic simulator build-for-testing of the first eight added capture tests. The final two deduplication cases and narrow final capture fixes are included in `expanded-build-latest.log` / the parent's subsequent candidate verification. Native runtime results for the new cases must be taken from that candidate run, not from compilation.

The parent's `/private/tmp/CareInOneCandidate4.xcresult` and log establish **20/20 capture integration cases and 9/9 backup integration cases passed** on iOS 27.0. Candidate4 as a whole still had three UI failures and one conditional real-cloud skip, so it must not be described as an entirely passing release check.

The existing personal-note and visit-draft UI persistence tests now reflect demo isolation: ordinary relaunch first verifies each practice record is absent from the personal history, then explicitly opens Settings → Explore the fictional demo before checking saved practice content and the original deletion/impact assertions. This is a navigation correction for the separate demo workspace; no production state was changed by the tests.

The follow-through message/outreach/reply UI test now also explicitly reopens the isolated demo after relaunch. Its Candidate2 failure was attempting to find the fictional follow-through helper in the personal workspace. PatientCompanion UI scrolling now drags within visible table/collection/scroll content, avoiding the fixed demo banner, navigation bars, tab bar, and keyboard. Existing reply persistence, review gating, source deletion, and cached-reply absence assertions remain. `ui-isolation-build.log` confirms the complete test build succeeds; final runtime results belong to the subsequent candidate run.

Minimum-iOS native verification is recorded in `SMALL_PHONE_AUDIT.md`: final iPhone SE 3 / iOS 18.2 action passed **6/6 UI cases with exit 0**, including both capture journeys and complete caregiver outreach/reply/relaunch/review/deletion. This exposed and repaired a real iOS 18 PasteButton executor crash; lossless native paste now passes. The final clearing test uses ordinary native Delete keystrokes and does not claim OS Select All menu coverage.

## Runner limitation

The earlier focused xcodebuild invocations completed their test cases but did not finalize; only those two scoped xcodebuild processes were terminated. Logs establish individual test outcomes, not a zero-exit overall test action. A later combined backup run established a simulator diagnostic child (`simctl diagnose --timeout=600`) as its specific finalization delay. Stopping that diagnostic child allowed the later action to finalize successfully (see `BACKUP_AUDIT.md`). The earlier focused delays were not independently diagnosed; repeated package-graph messages did not establish their cause.

## Remaining physical-device verification

Camera capture and actual microphone/on-device transcription require device testing. Simulator tests do not establish those behaviors on hardware. Existing imported audio is not a supported file-import capability; audio capture is through recording. A force-terminated unsaved typed draft is not automatically recovered (the UI warns before ordinary dismissal).
