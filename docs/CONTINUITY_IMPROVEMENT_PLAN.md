# CareInOne connected continuity improvements

Goal: make captured evidence useful before, during and after a visit, with explicit patient review and durable local memory. This is an implementation plan for several connected improvements, not a claim that no other product has ever implemented any component or combination. The September 20 competitive review remains the evidence for external comparisons.

## Requirements and acceptance

| ID | Deliverable | Acceptance evidence required |
|---|---|---|
| C1 | Deterministic evidence impact preview | Preview the actual locally reconciled result of reviewed claims, with added/updated care, new/cleared discrepancies and opened/advanced/removed loops. Preview cannot mutate state or schedule reminders. Commit recomputes with the latest saved state. A disappearance after deletion is not labeled clinical completion or resolution. |
| C2 | Source deletion impact | Explain which saved care depends on a source before deletion. Actual deletion must purge that source's cached checkpoint content and linked workspace evidence; keep unrelated patient records. Transaction failure preserves the previous state and files. |
| C3 | Saved care checkpoints | Save a named reference point, optionally linked to an encounter, containing accepted evidence and organizational state. Compare later accepted additions/edits/retirements, discrepancies and follow-through to that reference point. Compare knowledge saved in the app, not purported medical event order. Pending/rejected claims do not become state. |
| C4 | Durable checkpoint lifecycle | Create, browse, rename and delete checkpoints; restore them through encrypted backup. Older stores and archives without the new optional metadata still open. Deletion cascades remove cached evidence, with an honest indication that the comparison's coverage changed. Bound stored snapshot counts and validate backup references. |
| C5 | Persistent visit workspace | Link an encounter, personal priorities/questions, a baseline checkpoint, selected visit packet, follow-through and captured debrief. Patient-controlled progress labels describe preparation/workflow, never inferred attendance or medical completion. Workspace is useful for a new encounter with no linked sources. |
| C6 | Structured after-visit recollection | Save what the patient heard, next steps and remaining questions as original patient-reported source text; create extraction proposals through the same pipeline. Questions stay questions. Saving a debrief must not silently accept claims, verify a clinician, close tasks or resolve discrepancies. Drafts can be saved locally and recovered. |
| C7 | Evidence readiness and uncertainty | In the workspace, explain unresolved discrepancies, unreviewed sources, unanswered questions and unfinished work with source links and honest unknown-date states. No health score, emergency triage, false overdue claim or “all clear” on an empty record. |
| C8 | Discoverability and connected updates | Today/Visits expose the workspace/checkpoints; review exposes impact preview; source detail exposes deletion impact. New reviewed information updates comparisons/readiness without manual module entry. Source links, question editing, packet export and debrief navigation work. |
| C9 | Persistence, privacy and recovery | New local metadata is saved transactionally, participates in erase/demo-removal/restore, contains no provider secrets, and never enters backend requests automatically. Existing installed records and original attachments survive upgrade. |
| C10 | Verification and documentation | Independent core regressions for comparison, preview purity, deletions, certainty, legacy decoding and corrupt references; native persistence/rollback/backup tests; simulator UI flows from workspace through debrief/review/comparison; unsigned iPhone Release; synthetic screenshots and updated implementation ledger/walkthrough. |

## Design constraints

- One reviewed local state drives all views. Model output remains a proposal.
- A checkpoint is a snapshot of what was saved at a time, not proof of what a clinician knew or what was medically true then.
- Patient recollection remains patient-reported. Completion/resolution still uses the existing explicit review workflows.
- Historical snapshots may preserve source versions while the source exists. Deleting a source also removes its clinical text from checkpoints; a snapshot is not an undeletable shadow record.
- New optional metadata preserves decoding of existing databases/archives and avoids changing SwiftData model identities without a tested migration.
- Keep product wording plain; offer a useful empty path and working controls. No paid service or medical recommendation is introduced.

Implementation status and exact verification results are maintained in `IMPLEMENTATION_STATUS.md`. Outstanding requirements remain open until their scoped evidence is inspected.
