# CareInOne Web

A separately runnable browser version of CareInOne. The native SwiftUI app remains in `CareInOne/` and its Xcode project; this web version does not replace its code, storage or app identifiers.

## Run locally

From the repository root, use the existing `.venv`. For a fresh checkout only, first create it with `python3 -m venv .venv`. Then:

```sh
.venv/bin/python -m pip install -r backend/requirements.lock
npm --prefix web ci --omit=optional --ignore-scripts
npm --prefix web run build
.venv/bin/python -m web.run
```

Open **http://127.0.0.1:8080**. The Python server serves the website and fixed, self-hosted document assets. It stores no patient records. Modern browser JavaScript, IndexedDB, Web Crypto and WebAssembly are required. Node 20.19+ is needed to build the document assets. No Node runtime is needed after they are built. The local default makes no provider/model requests.

Use the clearly labeled fictional example or start an empty workspace. Sources, reviews, tasks, visits, questions, profile and originals persist in that browser profile. The website does not encrypt IndexedDB at rest; use a locked personal device/profile. Export encrypted backups regularly. Switching domains or browsers does not move data; export and restore explicitly.

## Available workflows

- Notes, manual text, text-file import, native-text PDF parsing, English OCR for images/scanned PDFs and a conservative FHIR JSON subset. Original files are preserved separately from text; page references are retained only when exact extracted text remains unchanged.
- Capture → pending proposals → individual accept/edit/reject → deterministic source-linked care. Conditional, negated, historical, uncertain and non-patient statements remain evidence and are excluded from the current-care projection. Different reported medication details remain unresolved together.
- Local audio notes with explicit recording permission, pause/resume/stop, playback/download and optional typed transcript. Leaving the visible tab stops recording. No automatic speech service is contacted.
- Follow-through with personal dates, reported status, outreach drafts/history and calendar export. Visits with agendas, questions, recap recovery and recap-to-source review.
- Questions, search, exact-quote record lookup, evidence map, unit-separated reported-result trends, activity trail and care brief text/print-to-PDF.
- Password-encrypted web backup/restore (AES-256-GCM, PBKDF2-SHA-256 with 600,000 iterations), original attachment inclusion, transactional saves and stale-tab conflict protection.
- Optional same-origin authenticated cloud analysis through the existing gateway, recipient disclosure and per-source consent. Model credentials never enter the browser.

Document limits: 5 MB per uploaded original, 50 PDF pages, at most 10 scanned/OCR pages per import, 200,000 source-text characters. Local audio: maximum 10 minutes or approximately 15 MB. Workspace JSON: 40 MB; encrypted restore file: 60 MB. English OCR and the supported FHIR subset are bounded features, not complete EHR interoperability. OCR needs careful review of names, numbers and units.

## Verify

```sh
npm --prefix web run check
npm --prefix web test
.venv/bin/python -m unittest discover -s web/tests -p 'test_*.py' -v
.venv/bin/python -m unittest discover -s backend/tests -v
.venv/bin/python web/scripts/http_smoke.py
```

The HTTP smoke test launches a temporary localhost combined server with ephemeral secrets and mock inference only. It never uses real provider credentials or paid calls. The checked-in web workflow also builds the dedicated production Docker image. Browser acceptance and limitations are recorded in [the web ledger](IMPLEMENTATION_STATUS.md).

## Production

See [the ordered Render/domain launch plan](../docs/web/LAUNCH_PLAN.md). Recommended: reuse the existing Render web service with `CARE_WEB_COMBINED=true` and `web/Dockerfile`, keeping all current gateway/provider settings and native routes. No new patient database is required. `deploy/web-render.yaml` is the optional second-service alternative and may add compute cost.

Configuration names are listed in `.env.example`. Neither `web.run` nor the production entry point auto-loads `.env`; supply environment variables in the process or Render settings. Never put server credentials into HTML, JavaScript, Git, screenshots or shell command arguments. Public mode requires an exact HTTPS `CARE_WEB_ORIGIN`; one web hostname is canonical, while existing mobile `/v1/*` routes remain available through the legacy API origin.

Cloud access codes enable optional analysis, not patient accounts or storage. Public visitor access is enabled with `CARE_WEB_PUBLIC_AI=true`, using the existing server secret and gateway credentials; no access code or account is requested. Signed anonymous sessions last24hours and allow10 extraction attempts per rolling day, with100 total attempts per server process/day and100 new sessions per15minutes. Existing valid-session reconnects retain their identity. Cookie clearing can create a new identity but cannot bypass the shared process cap. Private-code mode remains available when that flag is false. In-memory limits reset on process restart and are not a financial hard cap; keep provider billing controls. Automatic accounts, email recovery, cross-device sync, encrypted browser locking, native push notifications and automatic speech transcription are not included. Native iOS backups use a different format.

For the October 24 launch, see [the exact existing-service/domain cutover](../docs/web/DOMAIN_CUTOVER.md) and [judge access/demo steps](../docs/web/JUDGE_DEMO.md). Explicit `CARE_WEB_CLOUD_ENABLED=false` preserves local web workflows plus the native API without opening public paid analysis; it does not simulate live cloud inference.

## October25 public visitor release1.1.0

The deployed1.1.0 release adds code-free signed anonymous sessions while retaining provider disclosure, explicit source consent, exact-quote validation, local review, secure cookies and the unchanged native API. Sessions are independent of reverse-proxy peer IPs; no forwarding-header trust was widened. All35 unique web/server tests,38 browser logic tests,108 gateway regressions and actualHTTP public/private/local modes pass. A real local browser walkthrough (mock only) passes anonymous connection→source consent→pending proposals and a clear exhausted-allowance message. Live at **https://careinone.org/**, runtime `cfc9475de3d8701d81ce0e6321b29bee4bfe4072`. Actual Render build/start, HTTPS/www redirects, all native tokens, guest authentication/consent/logout and one real fictional guest-browser analysis passed; see Oct25 domain status/evidence.

## October25 privacy copy release1.1.1

Concise personal-use and no-HIPAA-compliance-claim notes appear on onboarding, Settings and the web Privacy page. Existing per-source consent identifies the dynamic recipient and selected text/type/event date, hosting through Render and retention limits. OpenAI `store:false` is not a Zero Data Retention guarantee; the linked [official data controls](https://developers.openai.com/api/docs/guides/your-data) describe standard abuse-monitoring retention and exceptions. Web help asks users not to send health records or credentials in support requests. Native public documents, APIs, secrets, provider configuration, access scope and spending controls are unchanged. This copy update is not a compliance certification.

Local syntax,38 JavaScript tests and public HTTP mock smoke passed with zero paid inference. Exact production deployment and browser acceptance evidence will be recorded under `docs/web/verification/2026-10-25/privacy/` and in the domain status ledger.
