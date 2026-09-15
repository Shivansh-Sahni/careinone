#!/usr/bin/env python3
"""Capability ledger: IDs mirror the exact supplied specification (1–215)."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GROUPS=[
('A. Onboarding',1,10,'Views/OnboardingView.swift; Views/SettingsView.swift','UI onboarding/demo; device app-lock checklist'),
('B. Capture',11,36,'Views/CaptureView.swift; Services/CaptureServices.swift; App/AppStore.swift','UI capture/review; device capture checklist'),
('C. Source processing',37,60,'Core/Extraction.swift; Core/FHIRImporter.swift; Services/CloudAnalysis.swift; App/AppStore.swift','Core quote/chunk/date/cache tests; backend schema tests'),
('D. Review',61,80,'Views/ReviewEditor.swift; Views/SourceViews.swift; Core/Reconciliation.swift','Core proposal/atomicity/subject tests; UI capture-review test'),
('E. Care memory / graph',81,105,'Core/Domain.swift; Core/Reconciliation.swift; Services/Persistence.swift','Core roundtrip/rebuild/deletion tests; simulator persistence test'),
('F. Entity resolution',106,115,'Core/Reconciliation.swift; Views/ReviewEditor.swift','Core code/alias/weak-match tests'),
('G. Reconciliation',116,139,'Core/Reconciliation.swift; Views/FollowThroughViews.swift; App/AppStore.swift','Core discrepancy/supersession/rebuild/deletion tests'),
('H. Open loops',140,161,'Core/LoopEngine.swift; Views/FollowThroughViews.swift; Services/ReminderService.swift','Core state-machine/date/uncertainty/completion tests'),
('I. Today',162,175,'Core/LoopEngine.swift; Views/TodayView.swift; Views/SettingsView.swift','Core priority test; UI demo navigation'),
('J. My Care',176,195,'Views/CareViews.swift; Core/Domain.swift','UI demo category/detail; core projections'),
('K. Changes',196,209,'Core/Reconciliation.swift; Views/CareViews.swift','Core reconciliation/rebuild tests; simulator Changes checklist'),
('L. Discrepancies',210,215,'Views/FollowThroughViews.swift; Core/Reconciliation.swift','Core persistent resolution/new-evidence tests; simulator discrepancy checklist')]
NAMES='''Progressive onboarding|Local profile|Optional display name|Optional DOB|Optional local emergency/primary contact|Local/cloud processing explanation|Cloud-analysis consent|Recording-consent education|Optional app lock|Synthetic CAC demo mode
Quick voice update|Editable voice transcript|Explicitly permission-gated in-person visit recording|Persistent recording indicator|Pause/resume/stop|Optional local audio retention|Audio playback|Independent audio deletion|Typed recap|Paste text|Camera capture|Photo/screenshot picker|Local OCR|PDF import|Native PDF text extraction|OCR fallback for scanned pages|Text file import|FHIR JSON import|Manual structured entry|Share/open-in architecture|Duplicate-source detection|Same-encounter association|Source-title editing|Event-date editing|Capture cancellation|Recoverable interrupted processing
Source metadata creation|Capture date separate from event date|Effective date separate where appropriate|Source-type classification|Preserve original evidence|Normalized working text|Long-document chunking|Chunk overlap|Chunk claim deduplication|Exact quote validation|Confidence handling|Conditional-language detection|Negation detection|Subject attribution|Speaker attribution when feasible|Speaker uncertainty|Clarification-question generation|Maximum clarification count|Processing progress|Processing cancellation|Pending-analysis state|Retry analysis|Re-analyze source|Hash/version extraction cache
Review claims before commit|Accept individual claim|Reject individual claim|Edit claim label|Edit action|Edit value|Edit numeric value|Edit unit|Edit date|Edit entity association|Mark not about me|Mark historical|Mark uncertain|Show exact supporting quote|Show source location|Stronger review for medication/allergy/instruction|Save source even when analysis fails|Rejected claims remain noncanonical analysis history|Review-all-safe claims workflow|Explain confirmation is reported, not medical correctness
Persistent EvidenceSource|Persistent Encounter|Persistent CareEntity|Persistent CareClaim|Persistent ClaimRelation|Persistent ConflictRecord|Persistent OpenLoop|Persistent ChangeRecord|Persistent SavedQuestion|Persistent PatientNote|Persistent PatientProfile|Non-PHI AuditEvent|Version history|Source history|Current-state projection|Historical-state projection|Conflicting-state projection|Possible-current projection|Unknown-state representation|Patient-vs-document provenance distinction|Entity aliases|Optional code-system/code|Encounter grouping|Cross-encounter entity continuity|Rebuildable derived graph
Normalized-key exact matching|Code matching|Alias matching|Conservative fuzzy matching|Candidate match score|Candidate match reason|Patient review for weak match|Never silently merge weak provider matches|Never silently merge weak medication matches|Terminology adapter boundary
New-vs-existing comparison|ChangeSet creation|New item detection|Updated item detection|Explicit supersession|Duplicate detection|Potential conflict detection|Medication dose discrepancy|Medication start/stop/status discrepancy|Medication route discrepancy|Medication frequency discrepancy|Medication form discrepancy|Allergy discrepancy|Instruction discrepancy|Appointment/date discrepancy|Follow-up interval discrepancy|Patient report vs document discrepancy|Persistent unresolved conflicts|User resolution note|Conflict dismissal|Conflict reopening where justified|Rebuild after source edit|Rebuild after deletion|Local deterministic canonical reconciliation
Test loop|Referral loop|Follow-up loop|Procedure loop|Result-follow-up loop|Administrative loop|Exact due date|Approximate due date|Due-date confidence|No false overdue language|Duplicate loop suppression|Open status|Completed status|Uncertain status|Dismissed status|User-reported completion|Evidence-based completion|Reopen where contradictory evidence justifies|Notification integration|Loop notes|Loop date edits|Encounter linkage
What Changed|Needs Follow-through|Records to Clarify|What’s Next|Deterministic priority score|Why-this-is-shown explanation|Supporting-source deep link|Dismiss/resolve where appropriate|Honest empty state|Upcoming appointment summary|Recent meaningful change summary|Open discrepancy summary|Due-soon explicit tasks|User-configurable notification relevance
Medications|Conditions|Allergies|Tests/results|Referrals|Procedures|Appointments|Care team|Instructions|Follow-through|Per-entity history|Per-entity sources|Current/possible/conflicting/historical/unknown badges|Patient-reported badge|Search within category|Entity detail|Related encounters|Related conflicts|Related loops|Related questions
Chronological ChangeSet feed|Added|Changed|Superseded|Conflict introduced|Conflict resolved|Loop opened|Loop closed|Before/after comparison|Source evidence|Filter by category|Filter by provider|Filter by date|Encounter grouping
Persistent inbox|Side-by-side claims|Source snippets|Source metadata|Clarification-question generation|Mark clarified'''
names=[name.strip() for line in NAMES.splitlines() for name in line.split('|')]
assert len(names)==215,len(names)
LIMITS={
9:'Device passcode/biometric policy requires physical validation.',
11:'On-device Speech support varies by device/language; saved audio and typed fallback remain usable.',
13:'Per-session permission gate implemented; consent and audio routing require physical validation.',
14:'Visible throughout recording; recording pauses outside the foreground, no hidden background recording.',
16:'Failed/interrupted transcription retains local recovery audio until explicit deletion.',
17:'Local playback implemented; physical audio route validation pending.',
21:'Camera is explicitly unavailable on simulator; photo picker remains available.',
23:'OCR is fallible; original image is preserved and review required. Device/explicit language selection prevents automatic script confusion; auto detection remains optional.',
26:'PDF OCR fallback; maximum 200 pages/30 MB. Long or locked files can be preserved without analysis.',
28:'Conservative FHIR R4 subset; unsupported resources preserved in original. No live EHR connection.',
30:'Native Files/Open In document handling implemented. A separate share extension is not shipped.',
43:'Cloud text cap 200,000 characters, bounded chunks; evidence import cap one million characters/30 MB.',
51:'Only explicit speaker text labels; no diarization or inferred speaker identity.',
55:'Stage progress and activity indicators, not fabricated percent estimates.',
75:'Exact quote/page where available; transcript timestamps are derived from verified Speech segments and omitted after text editing.',
93:'Source working-text versions and claim revisions preserved; no automatic clinical truth overwrite.',
105:'Accepted claims plus patient conflict/loop decisions rebuild projections. User-approved entity aliases remain persistent inputs.',
115:'Protocol and no-op adapter provided; no live RxNorm integration claimed.',
140:'Exact code/system or explicitly reviewed result relationships can link result entities to test loops; fuzzy panel/component interpretation is not inferred.',
158:'Local generic notifications; permission/timing/locked-device delivery require device validation.',
175:'Tasks and appointments configurable separately. No clinical-risk or emergency alerts.'}
head='''# CareContinuity implementation status

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
'''
lines=[head]
for heading,start,end,location,tests in GROUPS:
    lines += [f'\n### {heading}\n', '| # | Capability | Status | Code location | Verification / limitation |','|---|---|---|---|---|']
    for number in range(start,end+1):
        status='Implemented; device validation pending' if number in (9,11,13,14,15,16,17,21,158) else 'Implemented'
        detail=tests + ('. '+LIMITS[number] if number in LIMITS else '')
        lines.append(f'| {number} | {names[number-1]} | {status} | {location} | {detail} |')
lines.append('''
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
''')
(ROOT/'IMPLEMENTATION_STATUS.md').write_text('\n'.join(lines))
print('Updated all 215 capability rows.')
