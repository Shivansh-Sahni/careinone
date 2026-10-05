# Read-only action and failure-path audit

Scope: current SwiftUI capture/source, backup, appointment companion, workspace, questions/notes, follow-through, care-item, evidence-map/timeline, temporary omission, settings, and tracked-handoff controls; service error/cancellation paths inspected with repository searches. This is source coverage, not a claim that every device interaction was exercised.

Concrete findings and disposition:

| Finding | Evidence | Disposition |
| --- | --- | --- |
| Native system PasteButton payload callback inherited main-actor isolation while iOS 18 delivered on a cooperative thread | Captured iOS 18.2 SIGTRAP executor assertion; `ios18-paste-crash-signature.json` | Repaired shared callback with Sendable payload + main-actor mutation. Exact 80-line native paste/save/relaunch passed. |
| Source working-text edit retained an old “proposals ready” processing message after retiring proposals | Source edit state transition and actual cleared-source screenshot | Parent assigned cloud agent truthful message repair and persistence regression. |
| Ask saved-information screen retained cached quotation results after source/patient state or query changed | Cached `excerpts` lacked state/query invalidation | Parent assigned cloud agent invalidation, cancellation and native privacy regression. |
| Review editor Cancel/swipe could lose an edited supporting quote or claim before acceptance | Local editable `draft`/numeric/interval state; unconditional dismissal | Added dirty comparison, swipe protection and explicit Keep editing/Discard changes. Focused UI verification records separately. Existing acceptance/evidence transaction remains unchanged. |
| Visit workspace Cancel/swipe could lose unsaved title, priorities or encounter grouping | Local editable state; existing transactional save | Same explicit recovery pattern applied only to WorkspaceEditor. Focused UI verification records separately. |
| Conflict resolution and loop notes/date/precision could be lost by Done/swipe before explicit save | `FollowThroughViews.swift` resolution/loop editors | Reported to parent; parent assigned cloud agent narrowly scoped dirty dismissal protection and verification. |

No additional dead advertised action was found in the inspected controls. Empty confirmation-cancel closures are intentional system alert dismissal actions. Export preparation clears previous output before generation and displays real errors; unique protected export files and stale-preview checks are handled by the export audit. Temporary source omission cancels work and invalidates results when selection or saved state changes. Native appointment answer navigation, pause and completion save before progressing and retain failed drafts. Ordinary save operations use AppStore transactions with visible failure state rather than treating closure completion as successful persistence.

Remaining verification boundaries: hardware microphone/camera/speech and Calendar permissions, actual VoiceOver execution, operating-system file/share destination choices and production signing are outside these isolated simulator checks. Naming-only checkpoint/handoff creation Cancel still explicitly abandons its unsubmitted creation fields; it is not a completed saved action. Profile preferences require the visible Save preferences action. These boundaries should be represented honestly in the release checklist.
