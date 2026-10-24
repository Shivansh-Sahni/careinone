# CareInOne Web launch plan

Owner decisions on October 19, 2026: retain CareInOne branding; browser-only records initially; no domain purchased; run locally now; prepare for public deployment; retain the native iOS app and existing Render/model API.

## October 24 launch update

The website is now the priority for the competition, with completion of the working HTTPS web release targeted within the next few hours on October 24, before domain purchase; Apple/model migration and competition-registration details are deferred outside the website critical path. Domain purchase remains with the owner. Read [the exact service/DNS/backup cutover](DOMAIN_CUTOVER.md) and [judge demo path](JUDGE_DEMO.md); the October 19 local result is not a public deployment.

## Architecture and preservation

- `web/` is the separately runnable browser product. `CareInOne/`, its Xcode project, Swift data model, and app identifiers remain independent.
- Work is on `codex/careinone-web`, created from `codex/carecontinuity` at `b831c98`. Do not deploy or merge unrelated native changes found in the shared working directory.
- Browser records use IndexedDB. Every source, proposal, task, visit, question and profile stays in that browser profile. Encrypted backups move records between devices/domains; there is no patient database, account or automatic sync.
- The existing gateway remains the model adapter. The website's same-origin `/api/` bridge keeps its bearer token server-side, uses HttpOnly sessions and explicit per-source recipient consent, and returns validated proposals only.
- Recommended production layout: one existing Render service runs `web.combined:create_app`. It preserves `/v1/*`, `/health`, `/privacy`, and `/support` through the unchanged original gateway. The website occupies `/`, with its web privacy/help screens at `/#privacy` and `/#support`.
- Alternative isolation: a second Render service runs the web entry point with `CARE_WEB_COMBINED` unset, forwarding to the existing HTTPS API. The supplied `deploy/web-render.yaml` creates this separate service. It is optional and can incur additional service charges.

## Ordered operation

1. **Build and verify locally.** Capture → pending proposals → review → source-linked care; exercise conflicts, tasks, visits, questions, search, briefs, deletion and encrypted backup/restore. Run the JavaScript and Python suites and the actual HTTP smoke test. Keep clinical statements and synthetic examples visibly distinguished.
2. **Save the separate web release.** Commit only `web/`, web documentation, the web workflow and deployment template. Preserve any concurrent native work without staging it. Retain the previous deployed Render revision for rollback.
3. **Operator preflight.** Confirm current Render service settings and model billing controls. Preserve all existing provider/model variables and `CARE_BACKEND_TOKENS`; do not replace them with browser access codes. Choose a cloud enrollment policy (this release supports individually issued codes). No database purchase is required.
4. **Deploy on the existing Render service when ready to go public.** Select the tested web branch/revision; change Dockerfile path to `./web/Dockerfile`, context `.`. Keep the health path `/health`. Set `CARE_WEB_COMBINED=true`, `CARE_WEB_ORIGIN` to the exact initial HTTPS origin, `CARE_WEB_SESSION_SECRET` to a generated 32+ character secret and `CARE_WEB_ACCESS_CODES` to one or more generated 32+ character codes. `CARE_WEB_GATEWAY_TOKEN` is optional in combined mode: omission uses the first existing gateway token only inside the server. A dedicated gateway token is preferred; if used, add it to the existing token list without deleting mobile installation tokens. Keep one process/instance for this beta's in-memory counters.
5. **Verify the deployed revision.** Verify website assets, native health schema, existing native privacy/support pages, authenticated mobile configuration, web connection/recipient disclosure and the synthetic cloud flow. Real model verification should use fictional content only and a bounded number of operator-approved calls. Local mock results do not establish production inference quality.
6. **Purchase and attach a domain.** Check availability at purchase time (the user mentioned `careinone.org` as an idea, not a registered domain). Add the purchased hostname to the existing Render service; use exactly the DNS values Render displays, wait for verification/TLS, then set `CARE_WEB_ORIGIN=https://<canonical-hostname>` and redeploy. Keep the API's existing `onrender.com` URL available for installed mobile clients. Do not disable it. The web server accepts one canonical Host; noncanonical web requests fail closed. Use the canonical domain for all web links.
7. **Move any testing records deliberately.** Export an encrypted backup at localhost/onrender before switching to the domain. Restore it on the chosen domain. Browser storage is origin-isolated; DNS changes never migrate browser data.
8. **Public launch check.** Confirm the web privacy/help text matches the actual host/provider configuration, test current desktop and mobile browsers, test a fresh empty workspace, back up/restore once, and confirm accessibility and source deletion. Invite the initial users with separate cloud access codes if cloud analysis is enabled.
9. **Rollback if needed.** Revert the Render branch/revision and Dockerfile to the previously working native gateway. Browser data remains in the user's local origin; no server patient database needs migration. Export browser backups before changing the user-facing origin or doing storage-schema changes.

## Cost and capacity

Browser-only records need **no new paid database**. Hosting the web shell and gateway on the existing Render service is intended to reuse its current compute plan; this is an architecture estimate, not a verification of the account's actual bill or capacity. Model usage, domain registration, bandwidth and build overages remain separate. Avoid a second service unless isolation is worth that additional bill.

Render documents custom domains and automatic TLS on existing web services: [custom domains](https://render.com/docs/custom-domains). Its [pricing page](https://render.com/pricing) lists service/storage prices and usage allowances. A separate static site can be free, but cannot safely hold the gateway secret or replace the server bridge. Render's default filesystem is ephemeral; do not later add server records without durable storage. [Persistent disks](https://render.com/docs/disks). Free Render Postgres expires after 30 days and is unsuitable as an indefinite production database. [Free service limits](https://render.com/docs/free).

Cloud allowance defaults: 10 extraction attempts per access code per rolling 24 hours, 100 total per server process, existing gateway's rate/concurrency controls, and bounded source size. Failed attempts count. These counters reset on restart and do not provide a global financial cap. Keep the model provider's own billing controls. Adding/removing a code needs an environment update/redeploy; removing it invalidates sessions derived from that code.

## Public launch dependencies still requiring live verification

No public deploy, domain purchase, DNS change, account billing change, or real model call is implied by local verification. A deployed synthetic analysis plus the existing mobile API compatibility check is required before claiming production cloud readiness. The browser vault is not encrypted at rest by this website; exported backup files are encrypted. Use the device/browser profile's access controls.
