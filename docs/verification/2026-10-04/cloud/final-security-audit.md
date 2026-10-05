# CareInOne final read-only security audit

Audited the current shared checkout on October 4–5, 2026. No production source was changed for this final audit. No ignored `.env`, credential store, Keychain, private Render settings or personal patient record was read. No model inference or paid request was made. This is a bounded engineering audit, not a penetration test or assurance that all possible credentials can be recognized.

## Credential scan

The scan covered git-tracked and nonignored untracked UTF-8 files: 455 text files, approximately 110 MB, including source, drafts and plain-text verification logs. Seven matches were found, all obvious fictional provider-key strings used by credential-rejection tests. There were no real credential-pattern matches in the scanned text. The report contains only file path, line number, candidate length, category and fictional classification; it never includes a matched value.

The scanner checked common OpenAI, GitHub, AWS, Google and Slack key prefixes, private-key markers, long bearer values, quoted assigned secrets and credential-like query values. It skipped 1,140 binary/unreadable artifacts, principally `.xcresult` and simulator diagnostic contents. It did not scan Git history or arbitrary binary serializations. Therefore the result must not be represented as proving that all repository artifacts or historical revisions contain no secrets.

The parent authorized a narrow `.gitignore` repair after this scan. Raw `.xcresult` bundles and simulator diagnostics/log archives are now ignored, preserved locally and excluded from Git publication. No artifacts were deleted. The check found no already tracked raw diagnostic files and no remaining nonignored raw diagnostic files; 115 reviewed summary/image/log artifacts remained available. Diagnostic bundles have a broader information scope than app source, and their binary contents were not secret-scanned here. Publish reviewed summaries and safe evidence images outside the ignored bundles.

Evidence: `final-secret-scan.json`.

## App and backend boundaries reviewed

- Provider API keys remain server-side; app gateway credentials are separate and kept in Keychain, excluded from source/backup state. Client input rejects provider-key prefixes and provider API endpoints. Authentication headers are sent only to the configured HTTPS gateway with redirects disabled.
- Backend model/host metadata is revalidated before disclosure, including actual provider-key and configured gateway-token substring checks. Provider secrets/endpoints/model identifiers are excluded from dataclass representations. Token authentication uses constant-time digest comparison and retains hashes/lengths for reflection checks.
- Public health and the two static policy pages are unauthenticated by design. Configuration/check/extraction require bearer authentication. Duplicate auth/content headers, compressed input, excessive input, invalid consent/configuration and malformed JSON are rejected before provider work.
- Provider and gateway failures return fixed allowlisted error text/codes. Provider body, underlying error message, source text, request URL and credentials are not inserted into production logs or public error responses. The app maps fixed error codes instead of displaying response bodies.
- Docker runtime disables access logging and has a deny-all build context with exact runtime/document/verifier exceptions. App sources, verification artifacts, tests, general docs and `.env` are not copied into the runtime. The application contains only a static storage-failure OSLog statement; no patient/request content logger was found.
- Requests and responses are bounded, exact supporting quotations are checked independently of strict JSON Schema, and real compatible-provider sockets share a four-operation process bound. Cancellation cannot guarantee cancellation of an already transmitted model request; this operational limit is documented.
- Per-process rate/concurrency controls are not a monthly spending cap. The parent retains the existing provider billing controls. No automatic key/token provisioning or shared production secret is embedded in the public app.
- Backup restore resets cloud consent and notifications, preserves the current local lock choice, and requires a reviewed patient preview before replacement. Demo workspace uses separate records/evidence and cannot operate the personal Calendar or notification center.

## Public endpoint evidence

The unauthenticated public `/privacy` and `/support` routes both returned HTTP 200 with the expected UTF-8 content type, no-store, nosniff, no-referrer, frame denial and restrictive CSP. Their deployed bytes differed from the newer local HTML, so a final HTML deploy remains required; a successful previous backend deploy alone does not establish that the latest policy text is online.

| Route | Local bytes | Deployed bytes | Matches local |
|---|---:|---:|---|
| `/privacy` | 14,270 | 13,810 | No |
| `/support` | 11,162 | 10,903 | No |

Exact SHA-256 values and security headers are recorded in `final-public-page-byte-check.json`. The separate authentication boundary report contains only public health and rejected unauthenticated/fictional-invalid requests. It contains no actual credentials or patient body.

## Current release blockers and scope

No new definite P1 application/backend defect was established by this read-only code audit. The previously reported numeric-trend, stale loop/conflict save, alias recovery and original-history search findings have repairs in the shared checkout and require the parent's final candidate verification.

Remaining concrete release actions are:

1. Deploy the latest reviewed public HTML and repeat the byte/header check before using these URLs in App Store metadata.
2. Restore the native private gateway connection and verify source → real analysis → review → saved care. The parent server report proves two real synthetic requests and exact quotation validation, while the initial native attempt stopped with missing configuration before any paid request.
3. Confirm revocation/rotation of any still-active credential exposed in earlier user screenshots. No such exposed value was used, copied or printed by this subtask; this final source scan cannot establish the state of an external provider key.
4. Complete signing/archive and App Store declarations, physical-device permission/delivery checks and NutriAssist organization approval. Active individual membership is not evidence that NutriAssist publishing is approved.

The parent owns the final ranked release decision, reconciles later test results and must not report submission readiness from this audit alone.
