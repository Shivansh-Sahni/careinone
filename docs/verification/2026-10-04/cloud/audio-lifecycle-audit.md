# Audio lifecycle and permission audit

Scope: narrow audio lifecycle repairs in `CareInOne/Services/CaptureServices.swift`, preserving the capture agent's text limits, file retention, OCR/PDF cancellation and transcription implementation. No microphone capture, permission prompt, simulator operation, patient-record access or service request was performed by this subtask.

## Repaired findings

- A native recorder `record()` failure during Resume previously left the app appearing paused with no explanation. Resume now checks the result, preserves the captured recording, explains retry/Stop recovery and clears that warning only after a successful resume.
- Audio-session interruption can require reactivation before recording resumes. Resume now reactivates the session and returns fixed, actionable feedback if that fails; underlying platform error text is not displayed.
- A recording that finishes or fails unexpectedly could leave `recording` true, keeping the capture screen's Save action disabled. Completion/error callbacks now finish the active capture and explain whether audio may be incomplete. Recorder identity checks prevent an old callback from stopping a newer recording.
- Failed playback initialization/start could leave the shared audio session active. Failure now calls the existing Stop/deactivation path and throws fixed recovery guidance while preserving the source.
- Inactive Pause no longer creates a paused-recording state, and only interruption-began notifications pause an active recording.

The implementation retains local originals and does not claim that failed native audio is necessarily complete or playable. No background microphone entitlement was added.

## Validation

Seven deterministic `AudioLifecycleIntegrationTests` use a fake recorder and injected permission/session closures. They cover denied microphone permission, initial recording failure/session cleanup, failed-resume retry, failed session reactivation without underlying-error disclosure, unexpected finish/elapsed preservation, stale completion/error callbacks and duration-limit/inactive-pause behavior. They create no audio file and make no native recording or permission request.

The repaired service module and all seven test methods passed Swift 6 typechecking against the iOS 18 simulator target using the installed iOS 27 SDK. `git diff --check` also passed. The initial sandboxed compiler attempt could not run Apple's Observation macro plugin; the same authorized compiler invocation then passed outside the sandbox. These results are compilation checks, not executed XCTest results.

The parent must run these regressions in the final candidate. Physical-device microphone permission changes, real audio interruptions, Bluetooth input, playback and on-device speech availability remain hardware checks. No claim of full hardware verification is made here.
