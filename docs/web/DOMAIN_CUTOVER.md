# Existing Render service: web launch, DNS and browser-data cutover

Updated October 24, 2026. No service, database or domain is purchased by these steps. Keep current model/provider settings and spending caps. The user buys the domain. The current human priority is the working HTTPS website within the next few hours on October 24; domain follows later. Apple, model migration and competition registration do not gate this web work.

## October25 cutover completed

**https://careinone.org/** is canonical and verified, runtime `cfc9475de3d8701d81ce0e6321b29bee4bfe4072`, live22:27:13UTC. Both domains Verified/CertificateIssued; www redirects to apex. Actual Namecheap A@216.24.57.1 / CNAMEwww careinone-api.onrender.com were saved, preserving email. Owner confirmed disposable demo data; no browser storage cleared. `CARE_WEB_ORIGIN=https://careinone.org` and `CARE_WEB_PUBLIC_AI=true` were saved after final owner confirmation. Public guest sessions and one fictional AI analysis pass; all native tokens on the old API host pass. Full current status is `docs/management/2026-10-25/DOMAIN_STATUS.md`. Prior steps below remain operational history/rollback guidance.

## Historical October24 verified live release (19:27 UTC)

The existing service now serves web1.0.1 at **https://careinone-api.onrender.com**, deployed SHA **b5aeb69b8da5e1fe1acb31f7ab00974618201d5b**. Actual Render Docker build/start succeeded in39.1seconds. Public19-route/assets checks and post-deploy authenticated native health/configuration passed. Web cloud is enabled after owner private credential setup and a successful bounded fictional real extraction; same-SHA redeploy went Live19:46:38UTC. See Website status for its exact evidence/limits. No database or service was added.

## Verified pre-launch starting point

- Existing service: `careinone-api`, service ID `srv-db18qghsrm7s73ajqq8g`, Ohio, current compute label `0.5c-512mb`.
- Existing URL: `https://careinone-api.onrender.com`.
- Current live revision: `4ec91e3be0c45470743208e2fb337d30445c2234`, branch `codex/carecontinuity`, Dockerfile `backend/Dockerfile`, context `.`, root directory empty, Docker command override empty, health path `/health`.
- Auto-deploy **Off**, PR previews **Off**, edge cache profile **None**. Preserve these settings.
- Fresh public reads: `/` 404 and `/api/status` 404, so a website is **not yet live**. `/health`, `/privacy`, `/support` are HTTPS 200. The server-side authenticated verifier also passed configuration without a model call.
- Current primary: OpenAI `gpt-4.1-mini-2025-04-14`, 6,000 output tokens, 40,000 source characters, no fallback. Keep it unchanged for this deadline; backend/model migration is separate.

## Candidate release gate

1. Read `docs/management/2026-10-24/WEBSITE_STATUS.md` for the exact release SHA and latest image result. A source commit or local unit pass alone is not a production-image boot.
2. Stage/commit/push only web-owned files to `codex/careinone-web`; preserve dirty native source/test changes. Do not merge them into this web release.
3. Prefer a production Docker image boot tested with `web/scripts/container_smoke.py`, including both cloud and explicit local-only web modes. CI is bounded to 20 minutes. If GitHub quota blocks execution, do not increase budget; record the blocker. No local Docker runtime is currently installed.
4. Keep changes within the owner-authorized existing-service launch. Any new credential entry/submission belongs to the owner under browser credential rules; never put provider keys, gateway tokens, web access codes, cookies or deploy-hook values in chat, screenshots, Git or video. Route owner questions through Manager.

## First HTTPS website, before the domain is ready

Use the existing hosting hostname as the stable fallback; it becomes a tested web fallback **only after deployment and the checks below**, not merely because the API currently answers.

On that same Render service, set:

| Setting | Value |
|---|---|
| Branch | `codex/careinone-web` at the frozen tested release |
| Dockerfile Path | `web/Dockerfile` |
| Docker Build Context Directory | `.` |
| Root Directory | empty |
| Docker Command | empty (use image CMD) |
| Health Check Path | `/health` |
| Auto-deploy / PR previews | keep Off |
| Compute / region | preserve existing plan / Ohio |
| `CARE_WEB_COMBINED` | `true` |
| `CARE_WEB_ORIGIN` | `https://careinone-api.onrender.com` |

Keep **all existing gateway/provider environment values**, including every current `CARE_BACKEND_TOKENS` entry. Do not change the model, fallback, source/output bounds or billing caps.

Choose one explicit web-analysis mode:

- **Deadline fallback without web cloud enrollment:** `CARE_WEB_CLOUD_ENABLED=false`. No new web session secret or access code is required. The website openly reports cloud analysis unavailable; its local capture/review/care/demo/backup features work, while the existing authenticated native API remains unchanged. Do not narrate local proposals as real model inference.
- **Optional web cloud enabled:** `CARE_WEB_CLOUD_ENABLED=true` (also the default). The owner supplies a private random 32+ character `CARE_WEB_SESSION_SECRET` and one or more separate random 32+ character `CARE_WEB_ACCESS_CODES`. Prefer a dedicated `CARE_WEB_GATEWAY_TOKEN` appended to the existing backend token list, preserving mobile tokens. Omission uses the first existing backend token internally, with shared rate limits. The browser never receives that token. Configure codes only through the private operator surface. The default 10 extraction attempts/code and 100/process per rolling day remain; these are not a global financial cap and reset on process restart.

Use one worker/instance. Do not provision the optional second-service Blueprint (`deploy/web-render.yaml`) for this launch: it can add a separate recurring service charge.

After the operator-approved manual deploy, verify this **exact deployed revision**:

- `/` and application/document assets return 200 with expected content and security headers; the onboarding and fictional demo actually open in a clean browser.
- `/health` retains `{"status":"ok","schemaVersion":"care-schema-1.0"}`; `/privacy` and `/support` preserve native public content. A healthy native endpoint alone does not prove the website works.
- Unauthenticated `/v1/config` is 401. Run `python -m backend.verify_gateway --server-environment` in the existing Render Web Shell: health and authenticated configuration should pass with **zero paid requests** and unchanged model/bounds. Never print environment variables.
- `/api/status` reports the selected web mode. In local-only mode `/api/config` and login return 503; this is intentional. In cloud mode, an operator-issued code creates an HttpOnly Secure SameSite session, metadata identifies recipients, and source text is sent only after explicit consent.
- After private credential setup, verify a small bounded fictional live extraction within existing model/billing limits if live cloud is part of the judge demonstration. Mock success does not establish real provider inference.
- Complete the judge walkthrough, backup/restore and a mobile-browser pass. Record the URL/revision and screenshots before using the link in submission.

## Domain purchase and DNS

The purchased hostname and registrar are still owner dependencies. `careinone.org` was an idea, not a confirmed registration. Once provided:

1. Choose one lowercase canonical hostname, usually the purchased apex, before collecting real browser records. Add it under this existing service's **Settings → Custom Domains**.
2. Render automatically creates the paired apex/`www` entry and redirects the counterpart. Adding the apex first makes the apex canonical; adding `www` first makes `www` canonical. Confirm the actual UI behavior and choose deliberately. [Render custom domains](https://render.com/docs/custom-domains).
3. Use the exact DNS targets shown by Render. A `www` CNAME target is `careinone-api.onrender.com`. For the apex, use a supported ALIAS/ANAME/flattened CNAME to that target, or the exact A record supplied by Render if the registrar requires it. Do not invent an A-record address. Remove only conflicting records for the new website; preserve mail MX/TXT and other existing services. [DNS-provider instructions](https://render.com/docs/configure-other-dns).
4. Wait for domain verification and the TLS certificate to become valid. Do not bypass browser certificate warnings or put a pending-TLS address in the submission.
5. **Keep the Render Subdomain enabled.** Installed native clients must continue to reach `https://careinone-api.onrender.com/v1/*` directly. Do not rename the service or globally redirect this API hostname. Do not use a catch-all redirect for native API paths.
6. Before changing the canonical origin, complete the backup procedure below. Then set `CARE_WEB_ORIGIN=https://<chosen-canonical-hostname>` with no path and redeploy the same frozen code revision. Do not change any provider/token/billing setting.
7. Verify the root page, assets, web cookies/consent, native API old-host authentication, paired-domain redirect and TLS. The web app accepts one canonical Host/Origin; noncanonical web requests fail closed, while legacy native paths are intentionally preserved. Do not submit two different web origins as though they share records.

## Encrypted record migration — before changing origin

A browser treats localhost, the Render hostname, apex and `www` as distinct storage origins. DNS never transfers IndexedDB, and the website has no server patient database.

1. On the old working origin, open **Settings → Encrypted backup**, choose and repeat a 12+ character passphrase, download the `.carebackup` file, and keep the passphrase separately. Confirm the download before changing any origin.
2. Preserve the old browser/profile and its data. **Do not clear it, automatically redirect it, or change the canonical-host setting before exporting.** Once its Host is rejected, that old web origin may not open to export.
3. Open the new canonical HTTPS origin, start an empty workspace (or use Restore from onboarding), then **Settings → Restore a backup**. Select the file, enter the passphrase, and explicitly confirm replacement of the destination workspace. Restoring replaces destination data, so back that up first if it already contains records.
4. Compare source/review/task/visit/question counts and original attachments. Download another encrypted backup from the destination and verify a non-destructive copy before retiring the old testing profile.
5. A passphrase cannot be recovered by the operator. Web backups are separate from native iOS backups. Cookie sessions do not migrate; reconnect optional cloud and renew recipient consent on the new origin.

If DNS/TLS is late, use the **already tested HTTPS Render web URL** for the deadline and keep it canonical through judging. Do not switch origins during the last hours. A later domain move can follow the same export/restore procedure.

## Rollback

Retain the verified previous deployment `4ec91e3be0c45470743208e2fb337d30445c2234`, branch `codex/carecontinuity`, Dockerfile `backend/Dockerfile`, context `.`, health `/health`, and the unchanged provider/token environment. If the web candidate fails, use Render's prior-deployment rollback or restore those source settings and manually deploy that prior known-good release. Confirm the actual live SHA after rollback.

No patient database migration is needed. Browser records remain at their local origin, but API-only rollback does not serve the web UI; retain encrypted exports first. A custom domain alone is not a fallback if the underlying web image is not running. Never claim a successful rollback until public/API checks pass again.
