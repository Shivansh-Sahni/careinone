# CareInOne implementation status

The supplied specification ends at **215: Mark clarified**. Every supplied numbered capability is listed below. `Implemented` means code is present; test/device evidence is stated separately. No claim of medical validation, App Store approval, or production certification is made.

## Patient companions (2026-09-21, verified)

[Acceptance criteria P1–P10](docs/PATIENT_COMPANIONS.md) and [verification evidence](docs/verification/2026-09-21/patient-companions/README.md). These additions help patients prepare what to say, keep appointment answers, arrange care and remember replies. All original capabilities and earlier verification records remain below.

The complete suite passes **156 core tests (150 Swift Testing + 6 XCTest), 44 native integration tests and 17 unique UI workflows**. The final native run passes all 44 integration + four new UI tests; all 13 pre-existing UI workflows passed the broader run. Two affected UI workflows also pass after the final presentation adjustments; they are repeats, not additional unique tests. The unsigned iPhone Release build passes without warnings or errors. Normal reinstall/launch preserves the hashes of all 12 existing record types and the original evidence file; six synthetic screenshots were visually inspected. The broad run's one UI test-locator failure and subsequent passing reruns are recorded in the evidence rather than counted as a wholly passing run. Signing, physical-device behavior, funded providers and patient studies remain separate gates.

Core test references below resolve to [VisitCompanionTests](Tests/CareCoreTests/VisitCompanionTests.swift), [FollowThroughAssistTests](Tests/CareCoreTests/FollowThroughAssistTests.swift) and [PatientHomeTests](Tests/CareCoreTests/PatientHomeTests.swift). Native persistence/transaction tests are in [PatientCompanionIntegrationTests](IntegrationTests/PatientCompanionIntegrationTests.swift); the four new workflows are in [PatientCompanionUITests](UITests/PatientCompanionUITests.swift).

| ID | Status | Code location | Tests / genuine limitation |
|---|---|---|---|
| P1 | Implemented and verified | `CareInOne/Core/PatientHome.swift`, `CareInOne/Views/TodayView.swift`, `CareInOne/Views/PatientWorkflowViews.swift`, `CareInOne/Views/VisitCompanionViews.swift` | `freshPatientCanStartWithOneThoughtAndUnknownVisitDate`, `testEmptyPatientCanPrepareWithoutAnInventedAppointment` and native empty-patient UI pass. An upcoming appointment keeps its own date and does not inherit the earlier reporting encounter; missing dates remain unknown. |
| P2 | Implemented and verified within stated device limits | `CareInOne/Core/VisitCompanion.swift` (`openingBrief`), `CareInOne/Views/VisitCompanionViews.swift`, `CareInOne/Services/ExportService.swift` | `briefContainsOnlyTheChosenFirstThreeAndNotAnswersOrLaterQuestionText` and native brief/PDF/accessibility workflows pass. Extra agenda items remain separate. Read aloud is explicit system speech; audible output, installed offline voices, interruptions and received copies at real share destinations require physical validation. |
| P3 | Implemented and verified | `CareInOne/Core/VisitCompanion.swift` (`suggestions`, `reorder`, question editing), `CareInOne/Views/VisitCompanionViews.swift` | `copiedQuestionsAreSeparateEditableSnapshotsWithSources`, `orderedAgendaAndDraftsSurviveCodableRoundTrip`, deletion tests and source-navigation UI pass. Editing an agenda snapshot never rewrites its original source or saved question. Supporting sources remain accessible within the live visit. |
| P4 | Implemented and verified within stated persistence limits | `CareInOne/Views/VisitCompanionViews.swift` (live editor), `CareInOne/App/VisitCompanionStore.swift`, `CareInOne/Services/Persistence.swift` | `testPatientCompanionDraftsAndVisitPositionSurviveSQLiteRelaunch`, `testEmptyPatientAppointmentBriefAnswersResumeAndReview` and `testVisitSourceContextOpensInsideTheConversationAndRetainsAnswer` pass. Successfully saved answers/order/position survive relaunch. Failed writes keep the answer in the current editor and guard navigation; unsaved session memory cannot survive process termination. |
| P5 | Implemented and verified | `CareInOne/Core/VisitCompanion.swift` (`captureAnswers`), `CareInOne/App/VisitCompanionStore.swift` | Answer-only extraction, contextual original evidence, idempotent capture, edited-source recapture, synthetic separation, native rollback and `testSavedCompanionAnswersAndRepliesRequireNormalReviewBeforeChangingCare` pass. Own/generic question context may be preserved in original evidence; generated prompts never enter working text. Mixed real/synthetic answers are rejected without discarding drafts. Local extraction remains limited to explicit supported patterns. |
| P6 | Implemented and verified within stated sharing limits | `CareInOne/Core/FollowThroughAssist.swift`, `CareInOne/Views/FollowThroughAssistView.swift`, `CareInOne/App/FollowThroughAssistStore.swift` | `firstPlanIsUsefulWithoutDatesProviderOrCompleteChart`, `existingScheduledAndCompletedStagesUseRelevantWordsWithoutMedicalAdvice` and native message/outreach/reply UI pass. Editable source-grounded messages and call scripts do not invent contact details, send automatically or confirm delivery. Real recipient/share-sheet behavior remains a device check. |
| P7 | Implemented and verified within stated notification limits | `CareInOne/Core/PatientHome.swift`, `CareInOne/Core/LoopEngine.swift` (`ReminderPlanner`), `CareInOne/Core/FollowThroughAssist.swift` (`checkBackAt`) | `checkBackRequiresBothConsentSettingsAndAnOpenTask`, `testPersonalCheckBackAppearsLocallyWithNotificationsOffAndNeverChangesClinicalDate`, and `testPersonalNotificationRespectsTaskConsentAndFutureDates` pass. Personal check-backs never change clinical due dates; paused/completed/dismissed tasks do not schedule active-task reminders. Actual lock-screen delivery requires physical validation. |
| P8 | Implemented and verified | `CareInOne/Core/FollowThroughAssist.swift` (`recordAttempt`, `captureReply`), `CareInOne/App/FollowThroughAssistStore.swift`, `CareInOne/Views/FollowThroughAssistView.swift` | Outreach/state-separation, exact-reply/idempotency, native reply-draft relaunch, failed-capture rollback and review-gate tests pass. Outreach remains patient reported; saving replies or finishing organizational work does not advance clinical stages or resolve discrepancies. Source corrections preserve a paused helper; reconnection is explicit. |
| P9 | Implemented and verified | `CareInOne/Core/PatientHome.swift`, `CareInOne/Views/TodayView.swift`, `CareInOne/Views/FollowThroughViews.swift` | All six `PatientHomeTests` pass, including active-visit priority, unknown appointment timing, separate reporting encounters and personal check-backs. Native workflows exercise direct start/resume/help navigation and accessibility text size. Physical VoiceOver and patient usability studies remain outstanding. |
| P10 | Implemented and verified within stated storage limits | `CareInOne/Services/Persistence.swift` (optional memories in `Preferences`), `CareInOne/Core/CareArchive.swift`, `CareInOne/Core/Reconciliation.swift`, both companion engines/stores | Core bounds/reference validation plus native SQLite, encrypted restore, legacy preferences, save rollback, source deletion, reply preservation and paused-helper recovery tests pass. Source deletion scrubs copied questions/answers/messages and session recovery; independent evidence remains. Draft durability requires successful persistence. Already shared copies and earlier backups cannot be recalled. |

## Evidence intelligence and tracked handoffs (2026-09-21, verified)

[Acceptance criteria N1–N10](docs/EVIDENCE_INTELLIGENCE_PLAN.md) and [verification evidence](docs/verification/2026-09-21/evidence-intelligence/README.md). These are local product additions; no world-first or competitive superiority claim is made. All original 215 capabilities and invariants remain below.

| ID | Status | Code location | Tests / genuine limitation |
|---|---|---|---|
| N1 | Implemented and verified | `Core/EvidenceGraph.swift`, `Views/EvidenceIntelligenceViews.swift` | Reviewed-patient-only graph, exact quotes, typed IDs, explicit relations; pending/rejected/family exclusion. Arrows describe saved information, not medical causality. |
| N2 | Implemented and verified | `EvidenceGraph.trace`, `EvidenceTraceView` | Cycle safety, deterministic order, bounded traversal/truncation, source links. One shortest path per node; default 200 nodes/six steps, with drill-down to continue. |
| N3 | Implemented and verified | `SourceOmissionEngine`, `SourceOmissionView` | Joint omission, invalid selection, original-state equality, no false completion; simulator multi-source selection/preview passes. Up to 30 sources; cancellation/stale-result handling; no clinical treatment simulation. |
| N4 | Implemented and verified | `Core/EvidenceTimeline.swift`, `EvidenceTimelineView` | Unknown date retention, late arrival, event/effective/capture/review distinction and sorting pass; simulator axis switching passes. Current reviewed versions only; not a complete event-sourced edit history. |
| N5 | Implemented and verified | `Core/CareHandoff.swift`, `Core/VisitPacket.swift`, `Views/HandoffViews.swift` | Selection/privacy, immutable text, SHA-256 digest, exact PDF and new-patient question-only handoff pass. Digest identifies content; it is not an authenticity or delivery guarantee. |
| N6 | Implemented and verified | `HandoffEngine.context/changes`, `HandoffDetailView` | Reviewed report/source/metadata/context changes, unrelated/pending exclusion, re-analysis with new IDs, selected profile fields and stable rebuild tests pass. Comparisons watch selected care items and supporting source content; they do not infer unlinked outside care. |
| N7 | Implemented and verified | `HandoffEngine.recordShared/finish/reopen`, `HandoffDetailView` | Finished context and reopening tests pass, including simulator reviewed-reply changes after finishing. Clinical tasks/discrepancies retain their status. Sharing is user reported only. |
| N8 | Implemented and verified | `HandoffEngine.saveReplyDraft/captureReply`, `AppStore.captureHandoffReply`, `HandoffReplyView` | Exact text, draft relaunch, duplicate suppression, failed-save rollback, real local extraction and review gate pass. Drafts save explicitly; photo/PDF/recording replies use ordinary capture. |
| N9 | Implemented and verified | Optional `CareState.handoffs`, existing SwiftData profile payload, archive/erase/source/demo/encounter cascades | Legacy payload, encrypted restore, digest tampering, missing references, source-copy invalidation, export cleanup only after successful deletion, independent reply preservation pass. Outgoing text/drafts share a 2M-character bound; 100 handoffs / 50K comparison fingerprints. Already shared copies cannot be recalled. |
| N10 | Scoped verification complete | `EvidenceIntelligenceTests.swift`, integration/UI suites, `scripts/simulator_fingerprint.py`, walkthrough/plan | **113 core, 50 gateway, 33 integration and 13 UI tests pass** with no native skips/runtime warnings; final deletion-copy UI regression also passes. Unsigned iPhone Release, preflight, visual inspection and all 12 installed record types plus original-file preservation pass. Physical iPhone/live-provider/patient studies remain separate. |

## Connected visit continuity (2026-09-20, verified)

The scoped requirements are in [CONTINUITY_IMPROVEMENT_PLAN.md](docs/CONTINUITY_IMPROVEMENT_PLAN.md). All new functionality is local and uses the existing review gate. The 215 original capabilities and invariants remain listed below. [Verification evidence and synthetic screenshots](docs/verification/2026-09-20/continuity/README.md).

| ID | Status | Implementation | Verification / remaining limitation |
|---|---|---|---|
| C1 | Implemented and verified | `Core/ContinuityComparison.swift`, `Views/EvidenceImpactView.swift`, `Views/ReviewEditor.swift` | Preview purity, invalid-preview atomicity, medication disagreement and simulator review/preview/accept flow pass. Acceptance recomputes from the latest saved state. |
| C2 | Implemented and verified | `ContinuityEngine.removeSource`, `Reconciler.deleteSource`, `SourceDetailView` | Cached quote deletion and surviving-loop identity regressions pass; native failed deletion preserves records/files; simulator deletion preview passes. Disappearance is not completion. |
| C3 | Implemented and verified | `Core/ContinuityMemory.swift`, `ContinuityComparator`, `CheckpointDetailView` | Pending excluded; older medical events remain new saved knowledge; edits and retired reports compared. Core regressions and visible accepted-report comparison pass. |
| C4 | Implemented and verified | `CheckpointsView`, `CheckpointEditor`, `Core/CareArchive.swift`, `Services/Persistence.swift` | Create/rename/delete, linked-reference detachment, encrypted metadata round-trip, missing-reference rejection, legacy JSON/SQLite and native relaunch checks pass. Snapshot storage is bounded. |
| C5 | Implemented and verified | `VisitWorkspaceView`, `WorkspaceEditor`, `ContinuityHubView` | Encounter, priorities, chosen checkpoint, packet, follow-through, questions and recollection linked. Native round-trip and simulator empty-patient workspace flow pass. Progress is patient-controlled organizational status. |
| C6 | Implemented and verified | `VisitDebriefDraft`, `ContinuityEngine.saveDebrief`, `AppStore.saveDebrief`, `VisitDebriefView` | Exact patient text, questions-only entry, duplicate suppression and rollback pass. Generated headings are excluded from extraction. Native test requires the actual latex allergy proposal; simulator save-draft/relaunch/review passes. |
| C7 | Implemented and verified | `Core/VisitReadiness.swift`, `ReadinessSections` | Earlier unfinished work and unknown timing included, unrelated encounter questions excluded; no health score or inferred completion. Core checks pass. |
| C8 | Implemented and verified | Today, Visits, Prepare, source detail and review navigation | Shared local state updates comparisons without module-specific entry. Native UI paths through workspace, debrief, source review, comparison and export pass; screenshots visually inspected. |
| C9 | Implemented and verified | Optional `CareState.continuity` in existing profile payload; archive/erase/demo/source cascades | Native metadata/legacy-store/erase/restore tests pass. Pre-work source/claim/entity/loop/conflict payloads remain unchanged. Normal reinstall preserves all 12 decoded record types and the protected evidence file. Existing storage/model/archive identities remain stable. |
| C10 | Scoped verification complete | `ContinuityTests.swift`, native integration/UI suites, plan and walkthrough | **95 core, 50 gateway, 28 integration and 9 UI tests pass**; unsigned iPhone Release succeeds; release preflight and whitespace checks pass. Physical-device/live-provider and comparative patient trials remain required. |

The final combined native run passed all 37 tests with no skipped tests or runtime warnings. Regression work caught and corrected a false new-task comparison after source deletion, extraction of generated recollection headings, and nested navigation/re-presentation issues. Evidence distinguishes intermediate failures from the final passing build.

The new workspace is a local organizational tool, not a shared caregiver account or evidence of medical attendance. Saved draft recovery requires choosing Save draft. Checkpoints are capped at 100 / 25,000 combined copied reports, workspaces at 100; encrypted archives retain their existing attachment/total-size bounds. Deleting source evidence redacts cached checkpoint content and explicitly reduces comparison coverage. Shared exports remain independently held static copies. Physical-device/live-provider usability and clinical validation remain outside automated verification.

## Competitive review and CareInOne update (2026-09-20)

- Reviewed 14 competitors and adjacent services using primary sources: [competitive review](docs/COMPETITIVE_REVIEW_2026-09-20.md). Closest broad overlaps include Guava, My Medical Records.ai and PicnicHealth. No head-to-head usability/accuracy trial or superiority claim is made.
- Added selected visit packets, source quotes and locations, optional profile fields/personal notes, exact text/PDF preview, and an editable outgoing care-team draft. Medication/allergy selections retain differing accepted reports and flags. `Core/VisitPacket.swift`, `Views/VisitPacketView.swift`, `Services/ExportService.swift`.
- Preparation now carries earlier unfinished work into new encounters. Questions can be added as visit priorities; changing the recent-change date range never hides unresolved work. `Views/PatientWorkflowViews.swift`, `Core/VisitPacket.swift`. Supports provenance/review (39, 74–80), related questions/encounters (192, 195), persistent conflicts (133, 210–215), and secondary Prepare/Care Brief acceptance criteria.
- Renamed the source folder, package, Xcode project, app/test targets, scheme, setup/deployment text, exports and current product copy to **CareInOne**. Existing bundle, SwiftData module/store, Keychain and archive protocol keys stay stable to preserve data. [Exact compatibility exceptions](docs/BRAND_COMPATIBILITY.md).
- Verification: **78 core tests, 50 gateway tests, 22 integration tests and 7 UI tests pass**; unsigned iPhone Release build succeeds. The full native run passed 21 integration + 7 UI tests, followed by all 22 integration tests after the pre-rename export-cleanup regression was added. New tests: `Tests/CareCoreTests/VisitPacketTests.swift`, `IntegrationTests/CareInOneIntegrationTests.swift`, `UITests/CareInOneUITests.swift`. Evidence: [competition verification](docs/verification/2026-09-20/competition/README.md).
- Installed and opened CareInOne on iPhone 16 Pro / iOS 18.4 without reset or demo reload. Compared saved source/claim/entity/loop/conflict payloads before installation and after launch: all unchanged. The existing synthetic demo and additional saved source remain available. The selected-packet screenshot was visually checked; test artifacts contain synthetic examples only.
- Limits: shared packets are static copies, not revocable access; selected quotes can contain identity details even when profile fields are off. Outgoing draft edits last for that preview only. No live EHR, collaborative caregiver account, new cloud service or clinical recommendation was added. Physical-device/live-model and release validation remain required.

## Offline pipeline usability update (2026-09-20)

- Public display name is now **CareInOne**. Stable bundle and storage identifiers preserve compatibility; the subsequent update above also renames the Xcode targets and project.
- Capture (19–36), source preservation/review (41, 61–80): manual medication route/frequency/form/effective dates, draft-discard protection, locked capture mode during staged imports, finite numeric validation, and save-failure draft retention. `Views/CaptureView.swift`, `Views/OnboardingView.swift`, `Views/ReviewEditor.swift`.
- Demo (10), imports (23–28), and onboarding (1): broader source-linked synthetic graph, future encounter, completed test, all care categories, and real TXT/PDF/PNG/FHIR practice imports. `Core/SyntheticDemo.swift`, `Views/SampleEvidenceView.swift`, `Services/ExportService.swift`. Samples always pass through review; direct practice imports are flagged synthetic.
- Notes/questions (89–90): note edit/delete and question save failure handling. `Views/CareViews.swift`, `Views/PatientEditors.swift`, `App/AppStore.swift`. Synthetic removal cleans original files and cancels in-flight analysis while preserving patient sources.
- Import/export acceptance: source original-file/text/audio share actions, existing graph JSON, care brief text/PDF, and encrypted full backup/restore are available. Graph JSON is not a restore format. `Views/SourceViews.swift`, `Services/ExportService.swift`, `Views/BackupView.swift`.
- Walkthrough: `docs/SIMULATOR_WALKTHROUGH.md` covers the loaded demo, real imports, fresh-patient onboarding, export/restore, and genuine device/cloud limits.
- Verification: 60 Swift core tests and 50 backend tests pass. First native run: 19 integration + 3 UI tests pass, including generated practice-file processing through real importers. Unsigned iPhone Release build succeeds. Final native run: **20 integration + 4 UI tests pass**, including the in-app practice importer, synthetic-file cleanup, and patient-data preservation. Evidence: `docs/verification/2026-09-20/`.

- Deeper pipeline audit: claim identity now preserves effective dates, intervals, date precision, codes, attribution, and explicit relationships; known conflicting terminology codes require patient review. Duplicate analysis links survive rebuilding. Rejected source-edit history remains backup-compatible, and notes/questions detach from removed entities without losing their text. Appointment discrepancies respect date-only precision and never substitute event dates for missing appointment dates. Source reads are bounded and image OCR decodes at a bounded resolution. Regression tests: `Tests/CareCoreTests/WorkflowHardeningTests.swift`; native personal-notes UI test added. FHIR medication instructions, route/coded timing, as-needed flags, and allergy reactions are now retained. Multiple explicit patient references are rejected even without Patient resources; complex dosages are not flattened. Final verification: **73 core tests, 20 native integration tests, and 5 UI tests pass**; the unsigned iPhone Release build succeeds. The verified app is installed and launched on iPhone 16 Pro / iOS 18.4 with the expanded synthetic patient. Screenshot and test evidence are saved in `docs/verification/2026-09-20/`.

## Release hardening verification (2026-09-15)

- Implemented OpenAI/Kimi/generic adapters, independent fallback parameters, owner-only interactive server configuration, authenticated model diagnostics, fixed synthetic connectivity checks, per-source cost bounds, and bounded streaming iPhone responses. Code: `backend/providers.py`, `backend/configure.py`, `backend/app.py`, `Services/CloudAnalysis.swift`, `Views/CloudConnectionView.swift`.
- Gateway: **50 tests passing** including configuration security, provider wire parameters, refused/truncated output, synthetic-only checks, recipient-bound consent, and fallback reporting (`backend/tests/test_providers.py`). Real localhost HTTP extraction/configuration/consent/check smoke test passes.
- Swift core: **59 tests passing** across four suites, including authenticated encrypted backup round trips, wrong-passphrase/tamper rejection, duplicate/missing archive records, relevant-claim retrieval, and overflow-safe intervals. The installed Command Line Tools run these tests with their optional missing Foundation cross-import overlay disabled; exact command/evidence is in `docs/verification/2026-09-15/`.
- Added encrypted backup/restore (`Core/CareArchive.swift`, `Views/BackupView.swift`, `App/AppStore.swift`), explicit question and encounter editors (`Views/PatientEditors.swift`), readable enum labels (`Core/DisplayLabels.swift`), and in-app help/privacy (`Views/HelpPrivacyView.swift`). Backup attachment limit: 40 MB, with explicit audio exclusion. Restore replaces data only after confirmation; no passphrase recovery exists.
- The cloud transport passes independent macOS Foundation type-checking. All native Swift files pass syntax parsing. These checks do not replace an iOS build. Three additional native integration tests cover restore, failed persistence/deletion, and gateway credential validation; all now pass.
- Xcode **27.0** license accepted: **17 integration + 3 UI tests passed** on iPhone 16 Pro / iOS 18.4. The updated unsigned iPhone **Release build succeeds**. Native results include restore/rollback and gateway credential validation. Evidence: `docs/verification/2026-09-15/native-final.json`.
- Added cost planning, Cloud Run and Render deployment templates, a Decimal-based cost calculator, and an eight-case synthetic primary-model evaluation runner. `docs/LOW_COST_LAUNCH.md`, `deploy/`, `scripts/estimate_cost.py`, and `backend/evaluate.py` describe exact scope and remaining public enrollment work. No cloud resources were provisioned or paid model evaluation run.
- Live provider credentials, signing, physical-iPhone validation, and publication destination remain external release requirements.
- `docs/MODEL_SETUP.md` provides ready-to-use setup steps; `docs/RELEASE.md` contains listing copy, review notes, and concrete remaining release checks. No external publication has occurred.

## Previous verified baseline (2026-09-07)

- Swift 6 core: **50 tests passing**, including medication dimensions, loop families, reminders, provenance, deletion scope, FHIR statuses and coded result linkage.
- Python gateway: **30 tests passing** (authentication, consent, validation, fallback, disconnect, privacy, limits).
- Xcode 26.6 / iOS 26.5: **simulator build succeeds**. Matching runtime installed and iPhone 17 Pro simulator booted.
- Native integration: **14 tests passing**, including real SwiftData persistence, OCR/scanned PDF, export, interrupted processing, cancellation races, transcript recovery, and Keychain update/deletion.
- UI automation: **3 tests passing** on iOS 26.5: capture/review/persistence after relaunch, discrepancy clarification/reopening, and demo navigation/provenance.
- Unsigned iPhone **Release build succeeds**. The final iOS 18.4 combined run passes **17/17** native tests. iOS 26.5 passed the core patient workflows and native integration suite; a separate dark/accessibility-text run also passes. Exact run summaries and synthetic screenshots are in `docs/verification/`.
- No physical iPhone, signing identity, or live provider credentials have been supplied. Device/cloud validation remains explicit in `docs/VALIDATION.md`.

## Numbered capability ledger

Paths below are relative to `CareInOne/` unless marked otherwise. Automated test references resolve to `Tests/CareCoreTests/CareCoreTests.swift`, `Tests/CareCoreTests/EdgeCaseTests.swift`, `IntegrationTests/CareInOneIntegrationTests.swift`, `UITests/CareInOneUITests.swift`, or `backend/tests/test_gateway.py`. Group-level tests exercise the shared boundary; they do not imply independent automated coverage of every individual row.


### A. Onboarding

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 1 | Progressive onboarding | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 2 | Local profile | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 3 | Optional display name | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 4 | Optional DOB | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 5 | Optional local emergency/primary contact | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 6 | Local/cloud processing explanation | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 7 | Cloud-analysis consent | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 8 | Recording-consent education | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |
| 9 | Optional app lock | Implemented; device validation pending | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist. Device passcode/biometric policy requires physical validation. |
| 10 | Synthetic CAC demo mode | Implemented | Views/OnboardingView.swift; Views/SettingsView.swift | UI onboarding/demo; device app-lock checklist |

### B. Capture

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 11 | Quick voice update | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. On-device Speech support varies by device/language; saved audio and typed fallback remain usable. |
| 12 | Editable voice transcript | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 13 | Explicitly permission-gated in-person visit recording | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Per-session permission gate implemented; consent and audio routing require physical validation. |
| 14 | Persistent recording indicator | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Visible throughout recording; recording pauses outside the foreground, no hidden background recording. |
| 15 | Pause/resume/stop | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 16 | Optional local audio retention | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Failed/interrupted transcription retains local recovery audio until explicit deletion. |
| 17 | Audio playback | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Local playback implemented; physical audio route validation pending. |
| 18 | Independent audio deletion | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 19 | Typed recap | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 20 | Paste text | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 21 | Camera capture | Implemented; device validation pending | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Camera is explicitly unavailable on simulator; photo picker remains available. |
| 22 | Photo/screenshot picker | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 23 | Local OCR | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. OCR is fallible; original image is preserved and review required. Device/explicit language selection prevents automatic script confusion; auto detection remains optional. |
| 24 | PDF import | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 25 | Native PDF text extraction | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 26 | OCR fallback for scanned pages | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. PDF OCR fallback; maximum 200 pages/30 MB. Long or locked files can be preserved without analysis. |
| 27 | Text file import | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 28 | FHIR JSON import | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Conservative FHIR R4 subset; unsupported resources preserved in original. No live EHR connection. |
| 29 | Manual structured entry | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 30 | Share/open-in architecture | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist. Native Files/Open In document handling implemented. A separate share extension is not shipped. |
| 31 | Duplicate-source detection | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 32 | Same-encounter association | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 33 | Source-title editing | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 34 | Event-date editing | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 35 | Capture cancellation | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |
| 36 | Recoverable interrupted processing | Implemented | Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift | UI capture/review; device capture checklist |

### C. Source processing

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 37 | Source metadata creation | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 38 | Capture date separate from event date | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 39 | Effective date separate where appropriate | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 40 | Source-type classification | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 41 | Preserve original evidence | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 42 | Normalized working text | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 43 | Long-document chunking | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests. Cloud text cap 200,000 characters, bounded chunks; evidence import cap one million characters/30 MB. |
| 44 | Chunk overlap | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 45 | Chunk claim deduplication | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 46 | Exact quote validation | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 47 | Confidence handling | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 48 | Conditional-language detection | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 49 | Negation detection | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 50 | Subject attribution | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 51 | Speaker attribution when feasible | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests. Only explicit speaker text labels; no diarization or inferred speaker identity. |
| 52 | Speaker uncertainty | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 53 | Clarification-question generation | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 54 | Maximum clarification count | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 55 | Processing progress | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests. Stage progress and activity indicators, not fabricated percent estimates. |
| 56 | Processing cancellation | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 57 | Pending-analysis state | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 58 | Retry analysis | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 59 | Re-analyze source | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |
| 60 | Hash/version extraction cache | Implemented | Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift | Core quote/chunk/date/cache tests; backend schema tests |

### D. Review

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 61 | Review claims before commit | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 62 | Accept individual claim | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 63 | Reject individual claim | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 64 | Edit claim label | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 65 | Edit action | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 66 | Edit value | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 67 | Edit numeric value | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 68 | Edit unit | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 69 | Edit date | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 70 | Edit entity association | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 71 | Mark not about me | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 72 | Mark historical | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 73 | Mark uncertain | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 74 | Show exact supporting quote | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 75 | Show source location | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test. Exact quote/page where available; transcript timestamps are derived from verified Speech segments and omitted after text editing. |
| 76 | Stronger review for medication/allergy/instruction | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 77 | Save source even when analysis fails | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 78 | Rejected claims remain noncanonical analysis history | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 79 | Review-all-safe claims workflow | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |
| 80 | Explain confirmation is reported, not medical correctness | Implemented | Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift | Core proposal/atomicity/subject tests; UI capture-review test |

### E. Care memory / graph

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 81 | Persistent EvidenceSource | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 82 | Persistent Encounter | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 83 | Persistent CareEntity | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 84 | Persistent CareClaim | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 85 | Persistent ClaimRelation | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 86 | Persistent ConflictRecord | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 87 | Persistent OpenLoop | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 88 | Persistent ChangeRecord | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 89 | Persistent SavedQuestion | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 90 | Persistent PatientNote | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 91 | Persistent PatientProfile | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 92 | Non-PHI AuditEvent | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 93 | Version history | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test. Source working-text versions and claim revisions preserved; no automatic clinical truth overwrite. |
| 94 | Source history | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 95 | Current-state projection | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 96 | Historical-state projection | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 97 | Conflicting-state projection | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 98 | Possible-current projection | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 99 | Unknown-state representation | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 100 | Patient-vs-document provenance distinction | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 101 | Entity aliases | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 102 | Optional code-system/code | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 103 | Encounter grouping | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 104 | Cross-encounter entity continuity | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test |
| 105 | Rebuildable derived graph | Implemented | Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift | Core roundtrip/rebuild/deletion tests; simulator persistence test. Accepted claims plus patient conflict/loop decisions rebuild projections. User-approved entity aliases remain persistent inputs. |

### F. Entity resolution

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 106 | Normalized-key exact matching | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 107 | Code matching | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 108 | Alias matching | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 109 | Conservative fuzzy matching | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 110 | Candidate match score | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 111 | Candidate match reason | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 112 | Patient review for weak match | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 113 | Never silently merge weak provider matches | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 114 | Never silently merge weak medication matches | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests |
| 115 | Terminology adapter boundary | Implemented | Core/Reconciliation.swift; Views/ReviewEditor.swift | Core code/alias/weak-match tests. Protocol and no-op adapter provided; no live RxNorm integration claimed. |

### G. Reconciliation

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 116 | New-vs-existing comparison | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 117 | ChangeSet creation | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 118 | New item detection | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 119 | Updated item detection | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 120 | Explicit supersession | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 121 | Duplicate detection | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 122 | Potential conflict detection | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 123 | Medication dose discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 124 | Medication start/stop/status discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 125 | Medication route discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 126 | Medication frequency discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 127 | Medication form discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 128 | Allergy discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 129 | Instruction discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 130 | Appointment/date discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 131 | Follow-up interval discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 132 | Patient report vs document discrepancy | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 133 | Persistent unresolved conflicts | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 134 | User resolution note | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 135 | Conflict dismissal | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 136 | Conflict reopening where justified | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 137 | Rebuild after source edit | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 138 | Rebuild after deletion | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |
| 139 | Local deterministic canonical reconciliation | Implemented | Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift | Core discrepancy/supersession/rebuild/deletion tests |

### H. Open loops

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 140 | Test loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests. Exact code/system or explicitly reviewed result relationships can link result entities to test loops; fuzzy panel/component interpretation is not inferred. |
| 141 | Referral loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 142 | Follow-up loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 143 | Procedure loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 144 | Result-follow-up loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 145 | Administrative loop | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 146 | Exact due date | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 147 | Approximate due date | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 148 | Due-date confidence | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 149 | No false overdue language | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 150 | Duplicate loop suppression | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 151 | Open status | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 152 | Completed status | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 153 | Uncertain status | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 154 | Dismissed status | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 155 | User-reported completion | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 156 | Evidence-based completion | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 157 | Reopen where contradictory evidence justifies | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 158 | Notification integration | Implemented; device validation pending | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests. Local generic notifications; permission/timing/locked-device delivery require device validation. |
| 159 | Loop notes | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 160 | Loop date edits | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |
| 161 | Encounter linkage | Implemented | Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift | Core state-machine/date/uncertainty/completion tests |

### I. Today

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 162 | What Changed | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 163 | Needs Follow-through | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 164 | Records to Clarify | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 165 | What’s Next | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 166 | Deterministic priority score | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 167 | Why-this-is-shown explanation | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 168 | Supporting-source deep link | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 169 | Dismiss/resolve where appropriate | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 170 | Honest empty state | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 171 | Upcoming appointment summary | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 172 | Recent meaningful change summary | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 173 | Open discrepancy summary | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 174 | Due-soon explicit tasks | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation |
| 175 | User-configurable notification relevance | Implemented | Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift | Core priority test; UI demo navigation. Tasks and appointments configurable separately. No clinical-risk or emergency alerts. |

### J. My Care

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 176 | Medications | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 177 | Conditions | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 178 | Allergies | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 179 | Tests/results | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 180 | Referrals | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 181 | Procedures | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 182 | Appointments | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 183 | Care team | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 184 | Instructions | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 185 | Follow-through | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 186 | Per-entity history | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 187 | Per-entity sources | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 188 | Current/possible/conflicting/historical/unknown badges | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 189 | Patient-reported badge | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 190 | Search within category | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 191 | Entity detail | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 192 | Related encounters | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 193 | Related conflicts | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 194 | Related loops | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |
| 195 | Related questions | Implemented | Views/CareViews.swift; Core/Domain.swift | UI demo category/detail; core projections |

### K. Changes

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 196 | Chronological ChangeSet feed | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 197 | Added | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 198 | Changed | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 199 | Superseded | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 200 | Conflict introduced | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 201 | Conflict resolved | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 202 | Loop opened | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 203 | Loop closed | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 204 | Before/after comparison | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 205 | Source evidence | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 206 | Filter by category | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 207 | Filter by provider | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 208 | Filter by date | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |
| 209 | Encounter grouping | Implemented | Core/Reconciliation.swift; Views/CareViews.swift | Core reconciliation/rebuild tests; simulator Changes checklist |

### L. Discrepancies

| # | Capability | Status | Code location | Verification / limitation |
|---|---|---|---|---|
| 210 | Persistent inbox | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |
| 211 | Side-by-side claims | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |
| 212 | Source snippets | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |
| 213 | Source metadata | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |
| 214 | Clarification-question generation | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |
| 215 | Mark clarified | Implemented | Views/FollowThroughViews.swift; Core/Reconciliation.swift | Core persistent resolution/new-evidence tests; simulator discrepancy checklist |

## Architectural and workflow acceptance criteria

| Criterion | Implementation / evidence | Remaining validation |
|---|---|---|
| 1. Capture-first, value from one small input | Short onboarding; typed/voice/manual entry; no chart questionnaire | Simulator one-input UI test passes |
| 2. One input updates the whole product | AppStore review transaction + Reconciler.rebuild drive all destinations | Native capture/persistence and UI care-history tests pass |
| 3. Claims, not mutable scalar truths | Separate source-linked Claim records; discrepancy pairs preserve both sides | Core dosage/omission tests pass |
| 4. Provenance everywhere | Source/capture/event/effective/quote/page/subject/speaker/uncertainty/review/edit/provenance fields | Timestamps only where evidence provides them |
| 5. Model never mutates canonical state | Wire DTO excludes state/IDs; exact validation; review; local Swift reconciliation | Forged quote/unknown field/atomicity tests pass |
| 6. Deterministic software | Hashes, chunks, entity matching, reconciliation, due dates, priorities, cascades, search | No LLM clinical winner or sole priority calculation |
| 7. Incomplete stays incomplete | Explicit certainty states; unknown event dates; no omission-as-stop; conditional/subject gates | Core adversarial tests pass |
| 8. Local-first | SwiftData 12 persistent record types, no CloudKit, protected local evidence | Device protection/backup checks |
| 9. Optional cloud | Local OCR, on-device Speech when available, local extractor, manual review, all care workflows | Network-off device check |
| 10. Provider independent | ExtractionProvider/SynthesisProvider/TerminologyAdapter; generic compatible + mock + primary/fallback gateway | Live provider credentials required for external end-to-end test |
| 11. Low patient effort | Capture → proposals → targeted review; exact matching automatic; high-risk individual gate | Usability/patient accessibility study not performed |
| 12. No dead UI | Actions use store/services; camera unavailable label on simulator; file/open-in/export pathways | UI smoke tests pass; physical device checklist remains |
| Platform | Native SwiftUI, SwiftData, Observation, async/await, iOS 18, Swift 6, native frameworks | Simulator and unsigned iPhone Release builds pass |
| Navigation | Today, My Care, Visits, Sources, Settings + global Add + every named secondary destination | UI navigation tests pass; all destinations have real model/service actions |
| Recording | Explicit per-visit consent, microphone authorization, indicator, pause/resume/stop, local retention/deletion | No hidden recording; pauses outside foreground |
| Review | Individual accept/reject/edit, quote and source, safe bulk action, consequential confirmation | UI review test passes; uncertain/historical/disputed claims never bulk-accept |
| Entities | All 13 kinds; all 12 relation kinds in model, deterministic relation production where supported | Semantic relation inference is conservative; no invented provider links |
| Loop state machines | Tests, referrals, follow-ups, procedures, explicit result follow-up, admin; honest absence wording | No inference that a missing result means test never occurred |
| Today prioritization | Consequential conflicts, explicit approaching dates, upcoming visits, recent changes, old loops, information | Scores are organizational, not clinical triage |
| Product boundaries | No diagnosis, symptom triage, dose calculation, treatment recommendation, silent clinical edits | README, in-app explanations, deterministic Ask excerpts |
| Useful secondary workflows | Prepare with prior-encounter open work; selected VisitPacketBuilder, quote-linked text/PDF preview, optional profile/notes, editable outgoing copy; Questions, grounded local Ask, Search, complete Care Brief, unit-separated Trends, Care Network | Core packet-selection/provenance tests, native selected-PDF test, UI packet/draft tests; device share checklist remains. Static exports have no remote revocation. |
| Connected visit continuity (C1–C10) | Named local checkpoints, source-linked comparisons, visit workspaces, saved recollection drafts, separate unanswered questions, readiness checklist and acceptance/deletion impact | ContinuityTests and native persistence/rollback/UI workflows; exact results above. A checkpoint compares saved knowledge, never clinical correctness. Source deletion purges cached checkpoint evidence. |
| Stateless backend/security | No PHI DB/cache/request logs; HTTPS configured provider, tokens, limits, no redirects, exact quote checks | Deploy behind TLS; verify provider retention and infrastructure logging |
