# Evidence intelligence and tracked handoffs

Scope: 2026-09-21. These are working local features, not claims of invention or clinical validation. The competitive desk review cannot establish that a feature has never existed elsewhere.

| ID | Acceptance criterion |
|---|---|
| N1 | Traverse a typed, deterministic source → reviewed report → care item → discrepancy/follow-through graph, with exact evidence and explicit relation labels. Pending/rejected reports never enter this graph. |
| N2 | Inspect bounded upstream/downstream paths with cycle protection, visible truncation and source deep links. Source counts are not medical confidence scores. |
| N3 | Temporarily omit multiple sources and reconcile a copy. Show joint effects without saving, deleting, closing work or choosing a clinical winner. |
| N4 | Explore medical-event/effective dates separately from capture/review dates, including unknown dates and late-added evidence. Never substitute upload time for medical time. |
| N5 | Create a persistent handoff from selected packet items, with exact immutable outgoing text, explicit provenance and a content digest. Unselected context is never added to the outgoing copy. |
| N6 | Detect relevant newly reviewed reports, changed evidence, discrepancies and workflow changes after a handoff. Pending analysis does not count as accepted care. |
| N7 | Record patient-reported sharing and completion, reopen the organizational handoff, and expose changes since finishing. Never claim delivery, clinician acknowledgement or medical completion. |
| N8 | Save/recover a reply draft and capture it as patient-reported evidence through extraction → review → local reconciliation. Preserve original text; do not automatically resolve clinical disagreements. |
| N9 | Include handoffs in protected persistence/encrypted backup; decode older stores; invalidate copied outgoing text when supporting sources are deleted. Erase/demo/encounter cleanup and failed-save rollback must remain correct. |
| N10 | Provide reachable native screens, accessible controls, meaningful core/native/UI regressions, visual inspection, release build and preserved installed patient data. |

Safety boundaries: evidence relationships describe saved information, not biological causality. An omission rehearsal is not a treatment simulation. A handoff digest identifies a local copy, not authorship, authenticity or a read receipt. Shared copies cannot be remotely revoked. Medical timelines show current reviewed versions and are not a complete historical audit of every prior edit.

All N1–N10 criteria have implementation and scoped verification evidence in [IMPLEMENTATION_STATUS.md](../IMPLEMENTATION_STATUS.md) and the [September 21 verification record](verification/2026-09-21/evidence-intelligence/README.md). Limits: 100 handoffs, 2M combined outgoing/draft characters, 200K per outgoing copy, 30K per reply draft, 500 selected items, and 50K combined comparison fingerprints (10K per context). Graph tracing defaults to six steps/200 nodes with explicit truncation; omission previews accept up to 30 sources.
