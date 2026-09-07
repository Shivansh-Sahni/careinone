# Architecture and operational boundaries

## Data flow

`capture → protected original source → local/cloud proposal → schema + exact quote validation → patient review → atomic SwiftData save → Swift reconciliation → all patient workflows`

The iPhone owns `CareState`. Codable domain values in `CareCore` are independent of SwiftUI and SwiftData, allowing deterministic tests on macOS. Twelve concrete SwiftData model types persist sources, encounters, entities, claims, relations, conflicts, loops, changes, questions, notes, profile/loop decisions, and non-PHI audit events. Each row has a stable unique ID and versionable Codable payload. Graph references use explicit IDs; `Reconciler` owns relationship reconstruction and cascade semantics. There is no CloudKit container.

`AppStore.mutate` copies the current state, applies a bounded operation, saves every affected record in one SwiftData context save, and publishes only after success. Failure rolls back the context and retains the previous in-memory state. Evidence is written atomically before its database record; failed record insertion cleans its file. Source deletion saves the cascade before unlinking files; startup cleanup removes orphaned files. Original text and binaries remain separate from editable working text.

Analysis is asynchronous and cancellable. Source records persist before analysis starts. Interrupted processing becomes pending on next launch. Retained recording drafts can be played, transcribed again, edited, or deleted. Re-analysis retains accepted claims, retires older pending proposals into noncanonical history, and proposes only new evidence. Editing source text/date invalidates prior claims from that source until review; metadata-only edits preserve claims.

Every processing run has a generation token. Cancellation, deletion, edits, and new runs invalidate it, so a late provider response cannot overwrite newer work or clear a newer task handle. Local PDF/OCR workers receive cancellation and discard any late page output. Verified Speech segments survive transcription recovery; edited transcript text no longer claims original audio timestamps.

## Claims and projections

A claim records source, subject, attribution, exact quote, optional page/timestamp, event/effective/due dates, precision, action, values, medication dimensions, uncertainty, conditionality, negation, confidence, code metadata, revision, and review status. Only accepted/edited claims **about the patient** enter reconciliation. Family/other/unknown subjects and rejected/pending proposals never enter My Care.

Entity resolution uses exact normalized names, complete code-system/code pairs, approved aliases, and scored conservative string candidates. Weak and ambiguous exact matches require review. No terminology network call is made by the no-op terminology adapter. Multiple reports remain separate even when they share an entity. A confirmed patient medication report does not erase an unresolved provider-record discrepancy.

Supersession requires an explicit patient-edited selection of an accepted claim for the same entity. It changes the projection and preserves both claims. Conflicts are stable source-linked pairs; clarification/dismissal notes persist. New disagreeing evidence creates new unresolved pairs. Source deletion removes derived claims, relations, loops, conflicts, changes, and source-bound questions, then rebuilds from remaining accepted evidence.

The graph derives added/changed/superseded/conflict/loop Change records with source-based ChangeSet IDs and encounter grouping. Every change points to its supporting claim/source. Organization priority uses deterministic factors, never clinical risk prediction.

Results and tests remain distinct entity kinds. A unique exact code/system match or explicitly reviewed result relationship allows a result to contribute evidence to the test state machine. The canonical result is never rewritten as an order. Upcoming appointments share one deterministic selection function across Visits, Today, and reminders: superseded, cancelled, historical, conditional, and undated reports cannot become upcoming appointment reminders. Capture/event context never substitutes for an absent appointment date.

## State-machine semantics

- Test: mentioned creates no action; explicit ordered/requested/scheduled creates a loop; completed means awaiting saved result; resultAvailable/followUpKnown closes the evidence loop.
- Referral: requested → referralPlaced → appointmentScheduled → visitCompleted.
- Follow-up: requested → scheduled → completed.
- Procedure: ordered/planned → scheduled → explicit prepNeeded → completed; an explicit follow-up can be recorded separately.
- Result follow-up: created only from an explicit request, never from an abnormal value alone.
- Admin: requested → inProgress → completed/dismissed.

Undated completion from an unassociated source does not silently close a dated request. It creates uncertainty. Explicit evidence associations and known event chronology support progression. A later order after completion opens a new cycle. User completion is an independent override labeled “Completed by your report”; new explicitly later contradictory evidence can reopen it. Notification dates require explicit exact dates; approximate dates never produce overdue wording.

## Source and model boundaries

Local OCR uses Vision; PDFs use PDFKit native text followed by Vision for sparse/scanned pages. Speech is requested with `requiresOnDeviceRecognition`; no hidden cloud speech fallback is permitted. Permission and language/device failures preserve audio and expose manual alternatives. Original files, images, and audio are never sent by the cloud adapter; only consented working text, source kind, and optional event date are sent.

Cloud analysis uses `ExtractionProvider` and a generic compatible gateway. No model API key is bundled with the client. Server validation rejects unknown fields, fabricated quotes, invalid dates/enums/numbers, oversized content, and canonical IDs or review flags. The client rebuilds claims with local source identity and independently validates them. Quote validation proves textual support, not medical correctness; review remains necessary.

`SynthesisProvider` currently implements local grounded retrieval of accepted claim excerpts, with visible source links and discrepancy flags. It does not issue medical recommendations. Trends keep units separate and omit undated/non-numeric evidence. Brief export explicitly includes uncertainty and contradictions.

## Engineering references

- Apple [SwiftData ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext) documents explicit save/rollback and persistent-model management.
- HL7 [FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html) defines the source envelope and resource reference structure used by the conservative importer.
- vLLM [compatible server documentation](https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server/) describes the chat/completions and JSON-object interface used by the provider adapter.
- Uvicorn [settings](https://www.uvicorn.org/settings/) documents the ASGI process and request concurrency/access-log controls used in deployment.
