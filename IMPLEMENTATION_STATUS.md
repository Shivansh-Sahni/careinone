# CareContinuity implementation status

The supplied specification ends at **215: Mark clarified**. Every supplied numbered capability is listed below. `Implemented` means code is present; test/device evidence is stated separately. No claim of medical validation, App Store approval, or production certification is made.

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

Paths below are relative to `CareContinuity/` unless marked otherwise. Automated test references resolve to `Tests/CareCoreTests/CareCoreTests.swift`, `Tests/CareCoreTests/EdgeCaseTests.swift`, `IntegrationTests/CareContinuityIntegrationTests.swift`, `UITests/CareContinuityUITests.swift`, or `backend/tests/test_gateway.py`. Group-level tests exercise the shared boundary; they do not imply independent automated coverage of every individual row.


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
| Useful secondary workflows | Prepare, Questions, grounded local Ask, Search, Care Brief text/PDF, unit-separated Trends, Care Network | Multipage PDF test passes; device share checklist remains |
| Stateless backend/security | No PHI DB/cache/request logs; HTTPS configured provider, tokens, limits, no redirects, exact quote checks | Deploy behind TLS; verify provider retention and infrastructure logging |
