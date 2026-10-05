# Native packet and draft-recovery follow-up

All records were fictional and all actions used the disposable iPhone SE (3rd generation), iOS 18.2 build 22C150. The primary simulator, personal data roots, credentials and real notifications/calendar were untouched.

## Outgoing message and PDF

The existing `testOutgoingMessageEditingInvalidatesPreviousPDF` finalized with **TEST SUCCEEDED, exit 0**, one passed case, zero failures/skips, in 71.824 seconds:

- Result: `/private/tmp/CareInOneSEOutgoingMessageVerified.xcresult`.
- Durable log: `se-outgoing-message-verified.log`.
- Machine summary: `se-outgoing-message-summary.json`.
- Real native sharing switch reached on-state before the editable snapshot opened.
- The actual preview button was asserted fully below the navigation header and above the tab bar.
- A real selected PDF was generated and offered for sharing.
- An exact edit in the outgoing message removed the obsolete prepared PDF.
- Reopening a new snapshot omitted that outgoing-copy edit, preserving saved care.

Earlier focused attempts failed native activation or attempted `preview.frame` when that row was absent from an offscreen accessibility snapshot. Two temporary comparisons passed native Format and Include-name taps in both ordinary empty personal care (20.344 seconds) and the isolated demo (18.876 seconds). They did not establish a production binding defect and were removed from test source after diagnosis. The final existing regression waits for consecutive stable native switch rectangles, checks row existence before reading its frame, and confines scroll gestures between visible navigation, keyboard and tab boundaries. Assertions were preserved; no production binding override was introduced.

One SwiftUI invalid-frame runtime warning occurred during the keyboard transition. The exact text, PDF invalidation and new-copy assertions all passed. This warning is retained rather than hidden. Only the action's optional post-test simulator diagnostic collector was stopped after its assertions completed; xcodebuild itself finalized successfully.

## Workspace draft recovery

The complete workspace creation, dirty Cancel/Keep editing, prevented sheet swipe, explicit discard, saved-priority recovery and ordinary relaunch case passed again in 104.421 seconds. The refined native swipe starts inside the measured sheet navigation header and explicitly asserts the app remains `runningForeground`, keeping the gesture away from the system status edge. `workspace-draft-kept.png` shows the actual editable fictional priorities.

That action's result is `/private/tmp/CareInOnePersonalPacketNativeDiagnosis.xcresult`; its workspace case passed, while a separate temporary packet diagnosis failed before activation because a leftover keyboard obscured the row. The aggregate action therefore exited 65 and is not represented as a successful whole-suite result. The earlier two editor recovery cases already finalized together with exit 0 in `/private/tmp/CareInOneEditorDraftRecoveryFinal.xcresult`.
