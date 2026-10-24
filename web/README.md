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

Cloud access codes enable optional analysis, not patient accounts or storage. Each code is operator-issued. In-memory per-code/global quotas reset on restart; provider billing controls remain necessary. Automatic accounts, email recovery, cross-device sync, encrypted browser locking, native push notifications and automatic speech transcription are not included. Native iOS backups use a different format.

For the October 24 launch, see [the exact existing-service/domain cutover](../docs/web/DOMAIN_CUTOVER.md) and [judge access/demo steps](../docs/web/JUDGE_DEMO.md). Explicit `CARE_WEB_CLOUD_ENABLED=false` preserves local web workflows plus the native API without opening public paid analysis; it does not simulate live cloud inference.
