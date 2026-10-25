# CareInOne Web implementation and launch ledger

Separate web product for the October 19, 2026 pivot. Browser-only records and CareInOne branding were confirmed by the owner. The iOS application and its 215-capability native ledger are independent; this ledger does not claim complete native feature parity.

## Requirements and evidence

| # | Requirement | Implementation | Verification / limit |
|---|---|---|---|
| W01 | Preserve the mobile product | Separate `web/`, `codex/careinone-web`, dedicated Dockerfile/context | Native source, project and identifiers are not changed by this web implementation. Concurrent native edits in this shared checkout are excluded from web staging. |
| W02 | Working local website | `web.run`, `server.py`, `public/` | Local server at `http://127.0.0.1:8080`; actual browser walkthrough and HTTP smoke. |
| W03 | Persist browser-only records | `storage.js` IndexedDB transaction | Reload persistence verified in browser. No server patient store or new database. |
| W04 | Protect stale-tab writes | `storage.js` revision compare inside read/write transaction | Atomic comparison; failed saves leave old records and caller revision unchanged. Actual two-tab browser test passed: a second-tab question was saved, and the older tab rejected its stale save without overwriting it. |
| W05 | Capture notes / text files | `core.js:addSource`, `app.js:captureForm` | Exact source text, capture/event dates, duplicate control; notes verified through review to care. |
| W06 | Preserve PDF/image originals | Source attachments in IndexedDB | 5 MB upload bound, originals downloadable; backup includes attachments. |
| W07 | Read native PDF text | `imports.js`, pinned self-hosted PDF.js 5.5.207 | Synthetic PDF text extraction verified in browser. 50-page bound; no embedded PDF JavaScript execution. |
| W08 | Read image/scanned-PDF text locally | `imports.js`, self-hosted Tesseract.js 7.0.0 + English data | Image OCR verified through pending proposals and accepted result. Scanned-PDF OCR and original/claim persistence also passed in the browser. English only, 10 scanned pages per import; names/numbers/units require review. |
| W09 | Preserve page provenance | Exact unchanged imported pages, `makeClaim` | Unit test verifies valid page linkage and discards wrong/unverified page references. Editing extracted text drops automatic page attribution. |
| W10 | Import supported FHIR JSON | `imports.js:importFHIR` | Unit tests: supported subset, numeric units, single-patient matching, ambiguous attribution, unsupported resources, no external fetch. Original JSON retained; no live EHR connection. |
| W11 | Voice notes | `recorder.js`, recording dialog, local audio player/download | Explicit permission, pause/resume, foreground stop, bounded size/duration, microphone tracks released. Physical microphone capture remains a manual device check; no automatic speech transcription. |
| W12 | Review before current care changes | `core.js:review`, `eligible`, `project` | Accept/edit/reject/reopen tests and browser acceptance. Source quotes remain immutable. |
| W13 | Preserve uncertain/non-patient statements | `eligible`, claim attribution/flags | Family, other, negated, conditional, historical and uncertain statements remain evidence; tests exclude them from current care. |
| W14 | Keep conflicting records together | Deterministic projection and clarification question | Two reported doses remain unresolved with both quotations/source links. Browser verification passed; no clinical winner chosen. |
| W15 | Follow-through | Derived/personal tasks, status/dates/notes/outreach, ICS | Browser date/status update verified. Completion is patient-reported. Rejected supporting statements pause helpers while keeping drafts. |
| W16 | Visit continuity | Derived appointments, personal visit agenda/recap, recap-to-source | Browser agenda/recap save and recap-to-pending-review verified. Appointment source corrections pause linked work. No EHR scheduling integration. |
| W17 | Questions and record search | `app.js` questions/search | Local exact saved-text search; questions can be discussed/reopened. |
| W18 | Grounded record lookup | `insights.js:ask` | Returns matching original claims and review/attribution, no generated clinical answer. Empty search means insufficient matching captured evidence. |
| W19 | Numeric result trends | `insights.js:trends`, source-linked table/chart | Tests separate units, retain missing dates, exclude missing values and update corrected numbers. Browser accepted OCR value verified with exact unit/date/source. |
| W20 | Evidence map and history | `evidenceMap`, activity audit | Source-to-claim map and deletion tests. History is bounded; it is an activity trail, not a clinical correctness audit. |
| W21 | Care brief | `core.js:brief`, text download, print stylesheet | Source quotes/current care/tasks/questions. PDF uses browser Print → Save as PDF. No hidden share/send. |
| W22 | Encrypted backup/restore | AES-256-GCM / PBKDF2-SHA256 600,000 | Automated round trip/wrong-passphrase/tamper tests; actual browser download and restore verified. Web format is separate from iOS backup. |
| W23 | Delete with impact | Source/linked-claim/task/visit cascade; clear confirmation | Core cascade tests. Missing source never becomes medical completion. Clear/restore explain replacement first. |
| W24 | Keep the same model API | `combined.py` wraps unchanged gateway, optional external bridge | Real localhost HTTP mock extraction and native API compatibility pass. No live paid inference was attempted for this web release. |
| W25 | Keep credentials off the browser | Operator codes, HMAC HttpOnly sessions, server-only token | Auth, CSRF, host validation, HTTPS cookies, quota and unsafe-metadata tests. No shared production bearer token in JS or HTML. |
| W26 | Ready deployment source | Dedicated multi-stage `web/Dockerfile`, `.dockerignore`, CI | Explicit runtime allowlist tests pass. Docker is unavailable locally, so local container execution is not claimed; CI includes container build. |
| W27 | Domain / Render operation | `docs/web/LAUNCH_PLAN.md`, optional second-service YAML | Single-service path can reuse existing compute. No domain purchase, DNS change, public deployment or billing change performed. |
| W28 | Honest privacy / costs | In-product privacy/help and launch guide | Browser vault is not encrypted at rest. Encrypted exports are. No new database purchase is needed for the confirmed browser-only release. |

## Historical October 19 verification snapshot

- JavaScript care/import/insight/encryption suite: **38 tests passed**, including IndexedDB transaction/concurrent-writer/rollback coverage.
- Web server/in-process gateway/packaging suite: **23 tests passed**.
- Existing gateway regression suite: **108 tests passed** on Python 3.13.7 (the deployment family) and the current Python 3.14.3 local interpreter.
- Actual localhost HTTP smoke: passed, including fixed document assets, auth, recipient metadata, mock extraction and unchanged legacy routes; **zero paid requests**.
- Dependency audit after replacing the flagged PDF version: **zero reported vulnerabilities**. This is a point-in-time dependency check, not a penetration test.
- Browser verification: fictional example, capture → review → My care, unresolved two-dose conflict, task date/status, visit recap/review, encrypted download/restore, PDF text extraction, local image OCR, reviewed result table and desktop layout. Remaining browser checks are recorded in `docs/web/verification/README.md`.

## Historical October 19 limits and public launch gates

1. No public deployment or domain is configured by this local build. Select the domain, run the documented Render cutover, and verify that exact deployed revision and both web/mobile API flows.
2. Real provider credentials/retention, deployed configuration and live fictional model extraction remain operator checks. Existing Render route reads are recorded separately; an unverified health request must not be described as a successful live API check.
3. No automatic cross-device sync, account recovery, native push notifications, HealthKit, full FHIR/EHR connectivity, speech transcription, graph checkpoint comparisons, or native-style tracked sharing/handoff revocation. The current release supplies working browser workflows described above, not all 215 native capabilities.
4. Browser records are accessible to the unlocked browser profile. Use device/profile access controls and regular encrypted exports; clearing browser data can erase the workspace.
5. English OCR, source parsing and deterministic matching are conservative. They are not clinical validation. Per-code/process rate limits reset on restart; keep provider billing controls.
6. Physical microphone behavior and wider browser/device coverage require manual checks. The exact tested browser/viewport evidence belongs in the verification report.

## October 24 release candidate 1.0.1

Fresh local verification: 38 JavaScript + 26 web/server/compatibility + 108 unchanged backend tests. Both full-cloud and explicit local-only modes pass actual localhost HTTP smoke with zero paid calls. Added multi-mobile-token/old-host compatibility after canonical-origin change, explicit `CARE_WEB_CLOUD_ENABLED=false` fallback, PDF byte-preserving Git attributes, and production image boot/HTTP smoke in CI. Current live API health/configuration and public routes are recorded under `docs/web/verification/2026-10-24/`; the existing live model/budgets are unchanged. See Website management status for the actual release SHA, CI/image outcome and public deployment; the October 19 staging/health blockers are historical, not current evidence.

## October 24 public release

- **Live:** https://careinone-api.onrender.com at runtime SHA `b5aeb69b8da5e1fe1acb31f7ab00974618201d5b` (web1.0.1), Render deployment `dep-dbegcno473hc73d7kbeg`, live19:27:02UTC. Same existing service/compute; no patient database added.
- Actual Render Docker build and startup passed in39.1seconds. Public19-route/asset byte comparisons/security headers passed; native unauthenticated config401 and authenticated config200 preserve the existing model/bounds.
- Public browser acceptance passed fictional onboarding, unresolved source comparison, acceptpending, newcapture→review→task, personal date/notes plus reload, visitrecap→pending source and carebrief. Browser warning/error log empty. Public390×844 responsive viewport passed with no horizontal page overflow and override reset.
- Encrypted backup downloaded in the browser (13,963bytes); offline decryption verifies5sources/10claims/1visit and saved changes. The browser tool's download event timed out despite the successful download. Fresh deployed restore/PDF/OCR automation remains limited by Chrome extension file-upload permission; it has not been expanded. Historical local browser PDF/OCR/restore evidence remains separate.
- Web cloud enabled after owner private credential setup. Same-SHA redeploy Live19:46:38UTC; real web verification19:48:35UTC passed login/cookie, matching native config, missing-consent rejection, one fictional extraction200/3exact-quote-validated claims, logout. RuntimeUID10001. Model/caps unchanged; domain deferred.
- GitHub CI40125147913 could not start due account payment/spending-limit state; zero steps ran, no budget change. Docker read-only-container CI smoke was not executed. Render's actual production build/boot and HTTP checks are the available production evidence.
- See `docs/web/verification/2026-10-24/` and Website management status for the latest mode and verification. The historical unconfigured/public-health/staging limitations above no longer describe the current release.

## October25 public visitor candidate1.1.0

Human requested that all visitors use existing AI features without a private code. `CARE_WEB_PUBLIC_AI=true` adds automatic signed24-hour anonymous sessions using the existing server secret. No provider credential enters browser code. The public flow proceeds straight to recipient disclosure and per-source consent. Private-code mode and local-only rollback remain available.

Public allowances:10 extraction attempts per anonymous session/rolling24hours,100 total per process/rolling24hours,100 new sessions per15minutes, plus unchanged gateway limits and provider financial controls. Session identity is stable across proxy hops and valid reconnects; it is not based on a potentially shared/unstable load-balancer address. Cookie clearing may create another identity; it does not bypass the shared process cap. All counters reset on process restart and are not a global financial hard cap. No database or new service is added.

Verification:35 unique web/server tests (including opt-in, secret requirements, forged/expired cookies, proxy-hop continuity, reconnect quota preservation, shared global cap, enrollment limit, CSRF, consent and quote rejection),38 JavaScript tests,108 unchanged backend tests and actualHTTP public/private/local smoke pass. Browser mock flow reaches consent without a code, returns pending proposals, and shows exhausted allowance while retaining local records. Production-domain/TLS/guest verification and actual deployment are recorded separately in `docs/management/2026-10-25/DOMAIN_STATUS.md`; do not infer deployment from these local checks.

## October25 public deployment verified

**https://careinone.org/** is live at **cfc9475de3d8701d81ce0e6321b29bee4bfe4072**, Render `dep-dbf8485g1s2s73eqvpfg`,22:27:13UTC, actual Docker build/start33seconds. Both domains Verified/CertificateIssued; www redirects to apex; old native API hostname remains enabled. Canonical public26route/assets checks and2redirects pass. Server zero-paid verification confirms all configured old-host native tokens, secure code-free guest session/configuration/consent rejection/logout and unchanged model/caps. One real fictional public-browser analysis returned2pending claims with displayed quotes matching the synthetic source; no auto-accept and no browser errors. This is functional evidence, not clinical validation. Full evidence/limits/rollback are in Oct25 DOMAIN_STATUS. GitHub CI was blocked before steps; actual Render production image and live verification passed.
