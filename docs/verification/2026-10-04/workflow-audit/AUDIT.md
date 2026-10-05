# CareInOne publication workflow audit — October 4–5, 2026

This subtask reviewed medication/FHIR import, care editing, calendar export, visits, search, caregiver handoffs, source deletion and reminder scheduling. It did not launch a simulator, read private patient records, use personal Calendar/notification APIs, commit code, or change accounts or spending. The parent owns hands-on candidate verification and deployment. Code inspection and an SDK typecheck are distinguished from executed tests below.

## Repaired clinical interpretation

FHIR R4 MedicationRequest intent is now preserved in its generated evidence quotation and interpreted before status. Plan, proposal and option are conditional mentions, not medication orders. Missing or unsupported intent remains uncertain with an explicit review question; a cancelled plan no longer implies stopping an actual medicine. Explicit order-family requests retain ordered/stopped status as supported by their evidence. Unknown/family subject and pending review remain intact. ServiceRequest uses the same distinction. The subset importer version is `fhir-r4-subset-1.2`.

The required FHIR intent modifier distinguishes a proposed plan from an executable order. [HL7 R4 MedicationRequest intent definition](https://hl7.org/fhir/R4/medicationrequest-definitions.html#MedicationRequest.intent)

## Repaired Calendar export

Calendar export now requires a current, patient-reviewed appointment with an explicitly scheduled action, exact date, reported/documented certainty, no negation/condition and no unresolved discrepancy. Superseded, stale, unreviewed, other-subject, vague-date and past-date snapshots cannot be exported. A just-granted permission is followed by a current-state eligibility check before writing. Fictional demo export never requests Calendar access or writes an event.

The exporter suppresses repeated taps while permission is pending and saves an opaque local receipt only after EventKit succeeds. Ordinary retries/relaunches do not write a duplicate, including when the saved appointment date changes. The care screen explains that a prior calendar copy exists and offers a confirmed **Add another calendar copy** recovery action if the external event was removed or the patient deliberately needs another copy. This is explicit opt-in because write-only Calendar access cannot inspect an existing event. Permission denial and write errors explain recovery without exposing underlying error contents.

Receipts contain only hashes of claim/snapshot identifiers; no calendar event identifier, label, evidence text, patient name or plain appointment date is stored in preferences. `CalendarService.clearExportReceipts()` removes only that preference and invalidates in-flight permission requests. The parent integrated this call after a successful personal erase with system services enabled; demo/test erasure cannot clear personal receipts. Previously exported external events remain user-managed and are not silently edited or removed. Required-reason UserDefaults API use is declared as `CA92.1` in the privacy manifest.

## Repaired numeric trend evidence

The pure `NumericTrendPolicy` now uses the same eligibility predicate for chart series and empty states. It includes only finite numeric/date evidence with an existing source and entity, exact supporting quotation, current patient review, reported/documented certainty and explicit result-available status. Superseded, negated, conditional, preliminary/ordered, unknown, unreviewed and detached values cannot appear as available results. Older dated available results remain useful historical measurements; their age does not retire them.

Different unit strings remain separate without conversion. Missing-unit values stay readable with source links, but are never connected as comparable measurements. An unresolved discrepancy suppresses the whole series line and is labeled beside the source values. Multiple different values within the same day also suppress the line and ask the user to compare reports; this is deliberately not classified as a clinical contradiction because both may be valid repeat measurements. Exact values, certainty and source buttons form an accessible textual alternative to the visual chart. The screen states that no diagnosis, normal range or clinical interpretation is inferred.

## Automated evidence

| Check | Result | What it establishes |
|---|---|---|
| Full SwiftPM core run | 173 tests in 19 suites passed | Current shared core checkout, including reconciliation, safety, archive/workflow logic and new medication-intent, calendar-eligibility and numeric-trend regressions |
| New core regressions | 9 test methods in 2 suites passed, including parameterized plan/order families | Intent/status combinations, missing intent, conditional/family review, calendar conflict/supersession/stale checks and opaque snapshot hash behavior |
| Numeric trend regressions | 8 tests in 1 suite passed | Current/unsafe evidence filtering, unit separation, repeated-date source comparison, disputed values, historical measurements, missing units and malformed/detached evidence |
| Reminder service SDK check | Swift 6 arm64 iOS 27 simulator SDK passed | Service and injected test code compile; no personal notification state was touched |
| Calendar service SDK check | Swift 6 arm64 iOS 27 simulator SDK passed | Service and all 10 injected integration methods compile; XCTest execution is owned by the parent candidate run |
| Calendar view parser | Passed | Syntax only, not rendering or interaction correctness |
| Privacy manifest lint | Passed | Plist format and added declaration parse correctly |
| Whitespace check | `git diff --check` passed | Patch formatting only |

`core-tests.log` contains the full executed core run. SDK checks emitted isolated CareCore and service modules in `/private/tmp/careinone-calendar-typecheck` with the Xcode iOS 27 SDK, then typechecked CalendarExportIntegrationTests and ReminderServiceIntegrationTests. The tests inject fakes; their permission/save counters make actual Calendar or notification requests unnecessary.

Ten Calendar integration methods cover successful export and shared-receipt relaunch, concurrent taps, denied permission/recovery, failed write/retry, demo and unsafe eligibility, cancellation, a changed appointment while permission is pending, changed-date duplicate recovery, erase during a pending request, and isolated UserDefaults cleanup preserving unrelated preferences. The parent's release candidate must execute these tests; a typecheck is not a recorded test pass.

## Code-reviewed strengths and limits

- Reconciliation validates exact source quotations before atomic acceptance, keeps family/unknown/conditional facts explicit, and exposes unresolved dose/date discrepancies rather than selecting an automatic clinical winner.
- Source text edits preserve original and prior text while retiring derived claims and rebuilding care. Source deletion has an impact preview, removes or redacts internally saved derivatives and schedules protected-file cleanup. It cannot retract a copy already shared outside the app.
- Caregiver handoffs create a selected, labeled snapshot. Reply text becomes a source proposal requiring review; it does not silently become accepted care. Sharing is an explicit system action. This is not a live shared-care account service.
- Visit companions preserve copied question provenance and answers independently, validate evidence references, and save before navigation/capture transitions. Existing source deletion redacts dependent snapshots. They organize patient notes rather than verifying clinician instructions.
- Local grounded search uses saved reviewed evidence and quotations, labels uncertainty and unresolved disputes, and caps returned excerpts. It supplies no diagnosis, treatment recommendation or claimed model inference.
- Numeric trends now share a tested eligibility policy and show disputed/repeated-date values as labeled points with source access rather than an apparently settled trend line.
- Native permission delivery, real photo/camera/microphone input, external Calendar behavior, VoiceOver interaction and physical-device notification delivery require parent/device checks. No claim of full hands-on verification is made by this audit.

## Remaining ranked findings at handoff

These are code observations at handoff, not necessarily unresolved in the final candidate. The parent owns final reconciliation of the list.

1. **P2 — Numeric trend display repaired; runtime still pending.** The issue identified at handoff is repaired by NumericTrendPolicy and eight executed core regressions above. The parent must compile and inspect the final view in Candidate 4; this subtask's view parser check alone does not establish runtime accessibility or rendering.
2. **P2 — Stale loop/conflict edits can report a save without changing current care.** `AppStore.setLoop` stores an override for a passed snapshot, then rebuild can discard it; `resolve` records an audit entry even if the passed conflict no longer exists. Current-state/evidence guards should reject stale forms and keep their input visible for recovery. Parent must cover removed/changed evidence after the form opens.
3. **P3 — Patient-approved aliases have limited error recovery.** CareViews checks the raw alias before appending its trimmed form, permitting whitespace/case duplicates. There is no removal control for a mistaken alias without retiring the care entity. Prefer normalized duplicate detection and a deliberate remove action; changing an alias must not rewrite historical claims.
4. **P3 — Global search omits original and prior source text.** The broad “Search everything saved” entry indexes only the working source text. Original-only words disappear from global results after a correction, though original evidence remains saved and visible in Sources. If history is included, clearly label original/earlier versions and avoid promoting them into current clinical state.
5. **P3 — Some small unsaved/delete actions still lack recovery.** Questions can be immediately deleted from their list, and handoff composer cancellation loses its unsaved selection/title draft. Lower priority than correct clinical evidence and cloud processing; add an undo/confirmation or draft guard where it helps without unfinished feature growth.

The parent's accepted-claim correction controls and source rejection rebuild were reviewed separately and are being integrated/tested by the parent. Their earlier absence is not listed as an outstanding finding here.

## Publication dependency

Parent-observed account evidence is an active individual Apple membership through October 4, 2027, with NutriAssist organization conversion unconfirmed and no installed local signing certificates. These repairs do not authorize publication under the individual identity. The parent must produce the final build/test evidence, signing/archive artifacts where available, public policy/support route verification and exact remaining NutriAssist release actions.
