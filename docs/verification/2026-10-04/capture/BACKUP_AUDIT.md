# Backup, restore, and source exports — 2026-10-04

## Repairs

- Backup file reads (bounded to 110 MB), protected evidence snapshot reads (40 MB combined), encryption/decryption, and encrypted output writes run outside the main actor. The screen immediately reports the actual operation and blocks duplicate submissions.
- An operation can be cancelled. Its run identifier prevents late crypto/file results from becoming a preview or shared backup after cancellation/navigation. A completed cancelled output is removed.
- A failed replacement file import clears the earlier input and unlocked preview. A wrong passphrase leaves the chosen encrypted file available for retry and never modifies saved records.
- Changing passphrase, confirmation, retained-audio choice, or saved care invalidates an earlier share preparation. Care changing during backup creation cancels that preparation rather than presenting an out-of-date snapshot as current.
- Restore previews show the patient label, counts, and fictional-demo label where applicable. Restore explicitly replaces the current care memory and does not merge patient histories.
- Restore stages protected files in the background, validates archive integrity, checks cancellation and concurrent changes to care, and commits once on the main actor. Failed commits remove staged files and preserve existing records/evidence. Consent and notifications do not transfer; the current app-lock preference stays in place. Personal backups cannot be restored into the fictional demo workspace.
- Both passphrase fields have a keyboard Done control. Sensitive values clear on leaving the screen.
- Original-text source exports invalidate when saved care changes, check file readability, and do not retain stale QuickLook references after original-file changes or source removal.

## Verification

`backup-build.log`: independent generic Simulator build-for-testing succeeded, compiling the async backup implementation and new test sources.

`backup-capture-tests.log`: all 10 CapturePipelineIntegrationTests, 9 BackupWorkflowIntegrationTests, and both CapturePipelineUITests passed. The first backup UI assertion failed because it queried an offscreen lazy Form label before revealing it; the test interaction was repaired.

`backup-retest.log`: all 9 backup integration tests passed again. The backup UI generated a real encrypted file and read the success message, then failed because tapping the switch row center did not change the native switch value. The test now taps its right-side toggle and asserts the value changes.

`backup-final.log`: native iPhone 18 Pro / iOS 27.0 Simulator run completed with **TEST SUCCEEDED, exit 0**. Finalized result bundle: `/private/tmp/CareInOneBackupCombinedFinal.xcresult`. `xcresulttool get test-results summary` reports **10 passed, 0 failed, 0 skipped**. Those are the backup UI flow plus all 9 backup integration tests. Integration fixtures disable system services and use unique local data roots; no backend credentials are modified.

The UI test verifies keyboard dismissal, local encrypted backup creation, a visible success message, actual retained-audio switch change, removal of the stale ShareLink, and a clear recreate message. `backup-created.png` is its captured success screen.

The integration tests verify wrong passphrase/retry without changing care, failed replacement input clearing, late cancellation suppression, stale output invalidation, 8 MB original bytes and optional audio exclusion, patient replacement rather than merging, persistence after reopening, consent reset, original-file restoration, repository failure rollback, demo isolation, and pre-commit cancellation.

## Runner note and limits

Some xcodebuild runs delayed finalization while a child `simctl diagnose --timeout=600` collected simulator diagnostics. The final run preserved the functional runner and stopped only that stalled diagnostic child, allowing a successful finalized result bundle. Earlier terminated runners establish individual logged test outcomes but do not have finalized result summaries.

The final result includes one transient negative/non-finite frame warning during keyboard interaction. All asserted interactions passed; screenshots show a usable layout. This does not establish minimum-iOS-version or physical-device keyboard behavior.

The native Files document chooser and destination share-sheet saving were not automated in this focused UI test. Their bounded file loading and encrypted output bytes are covered by integration tests. Physical device storage/locked-device behavior remains a device verification item. PBKDF computation cannot be interrupted mid-call, but cancelled runs discard its eventual result; care remains intact.
