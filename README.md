# CareContinuity

A native, local-first iOS care continuity application. Capture evidence, review structured proposals, and carry source-linked changes, discrepancies, follow-through, and questions into the next appointment.

**The supplied specification ends at capability 215.** [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) tracks all 215 supplied capabilities, the architectural invariants, verification results, and genuine limitations. The app is implemented; physical-device, live-provider, and release validation are explicitly separated from automated verification.

## Open and run

1. Open **CareContinuity.xcodeproj** in current Xcode. The checked-in project does not require XcodeGen, CocoaPods, or third-party iOS packages.
2. Select the **CareContinuity** scheme and an iPhone simulator, or your connected iPhone. Minimum OS: **iOS 18**. Swift language mode: **6**.
3. For an iPhone, set your development team under Signing & Capabilities and change the bundle identifier if needed. The target uses the Data Protection capability. Build and run.
4. Start with one note or load the clearly labeled synthetic demo. No backend configuration is required for the local application.
5. Optional: configure the HTTPS gateway URL and a per-installation backend access token in Settings, enable cloud analysis, and save preferences. **Never place a model-provider API key in the iOS app.**

If Xcode reports an unavailable platform despite showing an SDK, install the matching runtime from Xcode → Settings → Components. The `xcodebuild -downloadPlatform iOS` command can also install the runtime. This workspace initially had an SDK/runtime mismatch; the verification ledger records its resolution.

## What works locally

- Short progressive onboarding, local profile, optional device authentication, and removable synthetic examples.
- Typed/pasted recaps, permission-gated voice and visit recordings, editable on-device transcripts when supported, independent audio playback/deletion, camera/photo OCR, PDFs with native text and scanned-page OCR fallback, text files, supported FHIR JSON, and structured entry.
- Original source preservation, duplicate detection, separate capture/event/effective dates, encounter associations, recoverable processing, review history, exact quotes, page/transcript locations where verified, and hash/version analysis reuse.
- Individually reviewed medication/allergy/instruction claims, editable attributes and associations, safe bulk review, rejection, historical/uncertain/not-about-me states.
- Persistent SwiftData graph, conservative entity resolution, deterministic reconciliation, unresolved source discrepancies, explicit supersession, and rebuilds after edits/deletion.
- Explicit test/referral/follow-up/procedure/result-follow-up/admin state machines, user-reported completion, date/notes editing, privacy-preserving local notifications, and calendar export.
- Today, My Care, Visits, Sources, Settings, Changes, Records to Clarify, Follow-through, Prepare, Questions, Search, grounded local Ask, Care Brief PDF/text, numeric Trends, and Care Network.

Local extraction is deliberately conservative and is not a replacement for the optional semantic model. It recognizes a bounded set of explicit patterns and preserves the remaining text as reviewable notes. It never guesses a clinical winner. A date-only appointment remains date-only; unsupported Speech languages/devices retain audio and offer typed/retry paths.

## Optional stateless backend

Python 3.11+ is required. From the repository root:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.lock
```

Configure environment variables described in [backend/.env.example](backend/.env.example). The server intentionally does **not** load `.env` files automatically; use your deployment platform’s secret manager or set environment variables in your shell. Set `CARE_BACKEND_TOKENS` to comma-separated random tokens of at least 32 characters. Set the compatible provider’s base URL (normally ending in `/v1`), model name, and server-side API key. Optional fallback settings select a second provider. Mock mode requires both `CARE_PROVIDER=mock` and `CARE_ALLOW_MOCK=true`.

```sh
.venv/bin/uvicorn backend.app:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log --limit-concurrency 16
```

Deploy behind an HTTPS reverse proxy; the iPhone rejects plain HTTP and redirects. `GET /health` is content-free. `POST /v1/extract` requires bearer authentication, JSON, schema version, explicit consent, source kind, and bounded text. Responses contain proposals only. Both server and client validate them; canonical reconciliation runs only in Swift after review.

The gateway has no patient database, content cache, uploads directory, or request-body logging. Provider requests use bounded timeouts, no redirects, no tool calls, and no evidence-specified URLs. **Provider and infrastructure retention must be assessed for your deployment.** See [docs/SECURITY.md](docs/SECURITY.md).

## Verify

```sh
swift test
python3 -m unittest discover -s backend/tests -v
.venv/bin/python scripts/backend_smoke.py
xcodebuild -project CareContinuity.xcodeproj -scheme CareContinuity \
  -destination 'platform=iOS Simulator,name=YOUR_SIMULATOR' test
```

The Swift package tests the pure care engine. Xcode runs SwiftData/capture/export integration tests and UI tests that use an isolated synthetic test store. `scripts/backend_smoke.py` runs an actual localhost ASGI server using an ephemeral token and synthetic data, then writes the Swift wire-contract fixture. See [docs/VALIDATION.md](docs/VALIDATION.md) for physical validation steps and remaining release work.

Verified in this workspace: **50 Swift core tests, 30 gateway tests, 14 native integration tests, and 3 UI workflows**. Simulator and unsigned iPhone Release builds pass. Native tests cover both iOS 26.5 and iOS 18.4; the validation record identifies the exact runs and physical checks still required.

Screenshots from the running app: [Today](docs/verification/today.png), [source discrepancies](docs/verification/discrepancy.png), [medication history](docs/verification/medication-history.png), and [explicit review](docs/verification/review.png). All displayed records are synthetic.

`python3 scripts/generate_project.py` regenerates the project and simple app icon after adding Swift files. `python3 scripts/update_status.py` maintains the numbered capability table. Update its verification snapshot alongside the Markdown ledger.

## Repository map

| Location | Responsibility |
|---|---|
| `CareContinuity/Core` | Portable domain types, validation, FHIR subset, entity resolution, reconciliation, loops, priority, search, brief, synthetic data |
| `CareContinuity/App` | Application bootstrap, transaction boundary, processing orchestration, root navigation |
| `CareContinuity/Services` | SwiftData, protected evidence vault, Keychain/lock, native capture, cloud adapter, reminders/calendar, PDF export |
| `CareContinuity/Views` | Real patient workflows and review interfaces |
| `backend` | Stateless ASGI gateway, strict wire validation, provider adapters, routing, deployment files |
| `Tests`, `IntegrationTests`, `UITests` | Core, native integration, and user-flow validation |
| `docs` | Architecture, security, FHIR contract, validation checklist |

Local graph JSON export includes health information and source text, but not original binary attachments or audio. Native Files/Open In import is supported; a separate share extension is not included. There is no HealthKit, live EHR, on-device foundation-model, or RxNorm service dependency. Adapter boundaries allow those to be added later without changing canonical state ownership.
