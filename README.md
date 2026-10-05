# CareInOne

CareInOne connects the evidence patients capture with the decisions and unfinished work they need to carry forward. Conversations, documents, photos and personal updates become reviewed, source-linked claims in a longitudinal care memory on the iPhone. Patients can see what changed, where saved sources disagree, and what to bring into their next appointment.

For hands-on testing, follow [the offline simulator walkthrough](docs/SIMULATOR_WALKTHROUGH.md). Practice TXT, PDF, image/OCR, and FHIR imports are available in Settings; no model key is required.
Open the **CareInOne** project and scheme. Stable storage and app identifiers preserve existing installations; see [compatibility notes](docs/BRAND_COMPATIBILITY.md). The [September 20 competitive review](docs/COMPETITIVE_REVIEW_2026-09-20.md) compares 14 products and distinguishes implemented behavior from remaining gaps.

**The supplied specification ends at capability 215.** [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) tracks all 215 supplied capabilities, the architectural invariants, verification results, and genuine limitations. The app is implemented; physical-device, live-provider, and release validation are explicitly separated from automated verification.

## Open and run

1. Open **CareInOne.xcodeproj** in current Xcode. The checked-in project does not require XcodeGen, CocoaPods, or third-party iOS packages.
2. Select the **CareInOne** scheme and an iPhone simulator, or your connected iPhone. Minimum OS: **iOS 18**. Swift language mode: **6**.
3. For an iPhone, set your development team under Signing & Capabilities and change the bundle identifier if needed. The target uses the Data Protection capability. Build and run.
4. Start with one note or load the clearly labeled synthetic demo. No backend configuration is required for the local application.
5. Optional: open Settings → Set up or test cloud connection. Check the gateway and disclosed models, then explicitly allow cloud analysis. **Never place a model-provider API key in the iOS app.**

If Xcode reports an unavailable platform despite showing an SDK, install the matching runtime from Xcode → Settings → Components. The `xcodebuild -downloadPlatform iOS` command can also install the runtime. This workspace initially had an SDK/runtime mismatch; the verification ledger records its resolution.

## What works locally

- **Appointment companion:** a personal opening and ranked top-three agenda, a short clinician-facing text/PDF brief with optional read-aloud, and a focused one-question-at-a-time visit screen. Answers and your place persist; finish by saving answers straight into the evidence/review pipeline.
- **Help me get this done:** choose what is blocking a saved care task, use a ready-to-edit clinic message or call script, keep outreach history, and save replies for review. Personal check-back dates appear on Today and support optional private reminders. Source corrections pause a helper without deleting its drafts.
- **Pick up where you left off:** Today resumes an active appointment, surfaces your personal check-backs, and opens follow-through help directly. These tools work with the synthetic patient or a new, empty patient; no model key is needed. See [patient companion scope](docs/PATIENT_COMPANIONS.md).
- Short progressive onboarding, local profile, optional device authentication, and removable synthetic examples.
- Typed/pasted recaps, permission-gated voice and visit recordings, editable on-device transcripts when supported, independent audio playback/deletion, camera/photo OCR, PDFs with native text and scanned-page OCR fallback, text files, supported FHIR JSON, and structured entry.
- Original source preservation, duplicate detection, separate capture/event/effective dates, encounter associations, recoverable processing, review history, exact quotes, page/transcript locations where verified, and hash/version analysis reuse.
- Individually reviewed medication/allergy/instruction claims, editable attributes and associations, safe bulk review, rejection, historical/uncertain/not-about-me states.
- Persistent SwiftData graph, conservative entity resolution, deterministic reconciliation, unresolved source discrepancies, explicit supersession, and rebuilds after edits/deletion.
- Explicit test/referral/follow-up/procedure/result-follow-up/admin state machines, user-reported completion, date/notes editing, privacy-preserving local notifications, and calendar export.
- Today, My Care, Visits, Sources, Settings, Changes, Records to Clarify, Follow-through, Prepare, Questions, Search, grounded local Ask, Care Brief PDF/text, numeric Trends, and Care Network.
- A selectable visit packet with source quotes, optional personal context and profile fields, exact preview, text/PDF export, and an editable care-team message draft. Older unfinished work remains available when preparing a new encounter.
- Connected visit workspaces with personal priorities, evidence checklists, saved care checkpoints and before/after comparisons. Recollection drafts survive relaunch when saved; finalized recaps create patient-reported sources and separate questions, then follow the normal review pipeline.
- Local impact previews before accepting a claim or deleting source evidence. Source deletion also purges copied checkpoint evidence; removed tasks and discrepancies are never mislabeled medical completion or resolution. Comparisons can be previewed and shared as text/PDF.
- **Care connections:** a typed evidence dependency map, bounded upstream/downstream traces, and a two-date timeline that separates medical-event/effective dates from capture/review dates. Multi-source omission previews run real reconciliation on a temporary copy without changing saved care.
- **Tracked handoffs:** immutable selected text/PDF copies, content digests, relevant-evidence change detection, patient-reported sharing/finishing/reopening, and recoverable reply drafts. Replies pass through the normal evidence/review pipeline. Deleting an included source invalidates the copied outgoing text and clears locally prepared exports. See the [acceptance criteria](docs/EVIDENCE_INTELLIGENCE_PLAN.md) and [walkthrough](docs/SIMULATOR_WALKTHROUGH.md).

Local extraction is deliberately conservative and is not a replacement for the optional semantic model. It recognizes a bounded set of explicit patterns and preserves the remaining text as reviewable notes. It never guesses a clinical winner. A date-only appointment remains date-only; unsupported Speech languages/devices retain audio and offer typed/retry paths.

## Optional stateless backend

Python 3.11+ is required. From the repository root:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.lock
```

For guided setup, run `.venv/bin/python -m backend.configure`, then `.venv/bin/python -m backend.run`. The first command creates an owner-only `.env` without printing keys; the second explicitly loads it without shell evaluation. OpenAI, Kimi, and generic compatible adapters have independent primary/fallback settings. Deployment platforms can supply the variables in [backend/.env.example](backend/.env.example) directly. See [docs/MODEL_SETUP.md](docs/MODEL_SETUP.md) for model selection, limits, consent, and a synthetic-only connectivity check. The direct Uvicorn command below uses environment variables and does not load `.env`.

```sh
.venv/bin/uvicorn backend.app:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log --limit-concurrency 16
```

Deploy behind an HTTPS reverse proxy; the iPhone rejects plain HTTP and redirects. `GET /health` is content-free. `POST /v1/extract` requires bearer authentication, JSON, schema version, explicit consent bound to the disclosed provider configuration, source kind, and bounded text. Authenticated `/v1/config` and `/v1/check` support setup without sending patient records. Responses contain proposals only. Both server and client validate them; canonical reconciliation runs only in Swift after review.

The gateway has no patient database, content cache, uploads directory, or request-body logging. Provider requests use bounded timeouts, no redirects, no tool calls, and no evidence-specified URLs. **Provider and infrastructure retention must be assessed for your deployment.** See [docs/SECURITY.md](docs/SECURITY.md).

## Verify

```sh
swift test
python3 -m unittest discover -s backend/tests -v
.venv/bin/python scripts/backend_smoke.py
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne \
  -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR' test
```

The Swift package tests the pure care engine. Xcode runs SwiftData/capture/export integration tests and UI tests that use an isolated synthetic test store. `scripts/backend_smoke.py` runs an actual localhost ASGI server using an ephemeral token and synthetic data, then writes the Swift wire-contract fixture. See [docs/VALIDATION.md](docs/VALIDATION.md) for physical validation steps and remaining release work.

**September 21 verification:** **156 Swift core tests (150 Swift Testing + 6 XCTest), 44 native integration tests and 17 unique UI workflows pass**, along with the unsigned iPhone Release build. The final native run passes all 44 integration + four new companion UI tests; the broader run passed all 13 pre-existing UI workflows. Two affected UI tests also pass after the final layout changes and are not counted twice. Coverage includes empty-patient preparation, brief PDF generation, answer/reply recovery and review, source navigation/deletion, separate appointment and check-back dates, encrypted restore and failed-save rollback. Normal reinstall/launch preserves all 12 existing record types and the original evidence file. The unchanged gateway retains its earlier 50-test baseline. See [current verification evidence and synthetic screenshots](docs/verification/2026-09-21/patient-companions/README.md), [implementation status](IMPLEMENTATION_STATUS.md), and the [remaining signing, physical-device and live-provider checks](docs/VALIDATION.md).

Screenshots from the running app: [Today](docs/verification/today.png), [source discrepancies](docs/verification/discrepancy.png), [medication history](docs/verification/medication-history.png), and [explicit review](docs/verification/review.png). All displayed records are synthetic.

`python3 scripts/generate_project.py` regenerates the project and simple app icon after adding Swift files. `python3 scripts/update_status.py` maintains the numbered capability table. Update its verification snapshot alongside the Markdown ledger.

## Repository map

| Location | Responsibility |
|---|---|
| `CareInOne/Core` | Portable domain types, validation, FHIR subset, entity resolution, reconciliation, loops, priority, search, brief, synthetic data |
| `CareInOne/App` | Application bootstrap, transaction boundary, processing orchestration, root navigation |
| `CareInOne/Services` | SwiftData, protected evidence vault, Keychain/lock, native capture, cloud adapter, reminders/calendar, PDF export |
| `CareInOne/Views` | Real patient workflows and review interfaces |
| `backend` | Stateless ASGI gateway, strict wire validation, provider adapters, routing, deployment files |
| `Tests`, `IntegrationTests`, `UITests` | Core, native integration, and user-flow validation |
| `docs` | Architecture, security, FHIR contract, validation checklist |

Encrypted backup/restore includes the care graph and original files, with optional audio, protected by a patient-held passphrase. The bounded archive supports 40 MB of attachments; restore replaces local records only after explicit confirmation and a successful transaction.

Local graph JSON export includes health information and source text, but not original binary attachments or audio. Native Files/Open In import is supported; a separate share extension is not included. There is no HealthKit, live EHR, on-device foundation-model, or RxNorm service dependency. Adapter boundaries allow those to be added later without changing canonical state ownership.

## Cost-conscious launch

[Detailed low-cost launch guide](docs/LOW_COST_LAUNCH.md) explains local storage, model comparisons, concrete Cloud Run/Render setup, realistic monthly scenarios, and public enrollment requirements. Deployment templates are in `deploy/`; `python3 scripts/estimate_cost.py` calculates editable cost scenarios. `python3 -m backend.evaluate --list` lists synthetic model checks without sending any network request.
