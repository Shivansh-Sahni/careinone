# CareInOne reminder audit — October 4, 2026

The notification service previously ignored every scheduling error with `try?`, did not check authorization during automatic refresh, and could clear personal pending notifications while opening the fictional demo. Settings checked permission only when its stored toggle changed from off to on, allowing externally revoked permission to remain visually stale.

## Service changes

- Return a structured `ReminderReconciliation` with planned, scheduled and failed counts, current authorization, superseded state, and fixed recovery/status messages. Notification-center exception text is never shown.
- Refresh system authorization before scheduling; denied or undetermined permission schedules no reminders and explains recovery. Automatic refresh does not prompt for permission.
- Explicit permission requests check current status and prompt only if undetermined, then verify the actual grant. Existing authorized, provisional and ephemeral permission remains supported. Quiet authorization is explained without guaranteeing delivery through Focus.
- Keep generation-based stale-completion cleanup and add cancellation checks. A late scheduling completion from a superseded or cancelled batch is removed and does not produce a success message.
- Add an explicit `isDemoWorkspace` argument. Demo refresh does not read, remove, add, or interrupt personal notification requests. The AppStore caller must pass its workspace flag; Settings must also skip system permission prompts in demo.
- Preserve generic lock-screen content without names, clinical labels, medication details or supporting quotations.

## Deterministic test coverage

`IntegrationTests/ReminderServiceIntegrationTests.swift` uses an injected actor fake, never the real notification center. Ten cases cover denied/undetermined permission, actual authorization rechecks, externally revoked permission, partial and complete scheduling failures, app-only removal, zero-operation demo isolation, a late older batch after disabling, demo entry during personal scheduling, and cancelled late completion cleanup.

The service and complete test file typecheck under Swift 6 against the arm64 iOS simulator SDK. Core and service modules were emitted in an isolated temporary directory; no app was launched and no simulator permission or pending request was changed by this subtask.

Test execution and hands-on Settings recovery remain pending the parent's simulator release and integration of the result/status API. Typechecking is not recorded as a passed XCTest run. Physical-device notification delivery remains a separate check.

## Caller contract

```swift
ReminderService.reconcile(state, isDemoWorkspace: isDemoWorkspace) // async -> ReminderReconciliation
ReminderService.authorizationStatus() // async -> ReminderAuthorization
ReminderService.requestPermission() // async throws -> Bool
```

Observe `warningMessage` and `statusMessage`; do not equate a persisted preference with successful reminder scheduling. Ignore superseded results. Refresh permission/status on return from iOS Settings. All other local records remain saved when notification permission or scheduling fails.
