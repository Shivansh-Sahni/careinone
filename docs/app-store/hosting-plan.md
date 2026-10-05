# Public CareInOne pages — prepared hosting path

Prepared October 4, 2026. Both pages are now hosted on the existing Render service. A read-only production check at 20:24 EDT on October 4 returned HTTP 200 for both pages and matched each response byte for byte to the reviewed source. This is hosting evidence, not App Store approval or completed publisher conversion.

Later source wording now describes opaque Calendar export receipts, duplicate-copy confirmation and external edit/deletion limits. The existing production record proves the prior page revisions; deploy and recheck the changed files before claiming the latest reviewed bytes are live.

## Exact paths

| Destination | Source | Status |
|---|---|---|
| `https://careinone-api.onrender.com/privacy` | `backend/public/privacy.html` | Live HTTPS 200; reviewed source match verified October 4 |
| `https://careinone-api.onrender.com/support` | `backend/public/support.html` | Live HTTPS 200; reviewed source match verified October 4 |
| `https://nutriassist.org/` | Existing NutriAssist website | HTTPS HTTP 200 verified October 4 |
| `https://nutriassist.org/contact/` | Existing NutriAssist contact page | HTTPS HTTP 200; explicit general-contact email verified |
| `mailto:shivika@nutriassist.org` | Contact page email link | Public general inquiry address verified; CareInOne-specific monitoring is not independently established |
| `https://nutriassist.org/about/` | Existing NutriAssist About page | HTTPS HTTP 200; site describes NutriAssist as a nonprofit providing free protein supplements |

The About page's self-description is not independent verification of a registered legal name, tax status, Apple organizational account, or application-publisher approval. No EIN, physical address, support hours, or legal title is invented. Neither the home nor contact page linked a CareInOne privacy policy at inspection.

The web reading service could not retrieve the NutriAssist site and its indexed search returned no useful results. An approved read-only HTTPS request from the host did retrieve these pages. The contact page visibly includes `mailto:shivika@nutriassist.org`; the footer also assembles that address in ordinary public JavaScript. No message was sent and no mailbox access was attempted.

## No extra hosting purchase

The existing Render web service already exposes an HTTPS `onrender.com` address. Two small public HTML responses can be served by that same process; no additional static-site service, custom domain, database, paid plan, or recurring-charge increase is required. This is an inference from the existing ASGI deployment and Render's documented public web-service behavior, not a guarantee of unlimited bandwidth or availability. Existing spending controls remain unchanged. [Render web services](https://render.com/docs/web-services)

`cloud_hardening` owns fixed ASGI routes, headers, Docker context, and tests. The release-material task owns the two HTML files. Exact GET/HEAD routes are public; API routes retain their existing authentication. The pages contain no scripts, forms, tracking resources, remote fonts, images, or query-dependent text. The only external actions are user-selected policy/contact links; the mailbox link does not send a message automatically.

Both pages were visually inspected in the Codex in-app browser at desktop width and 390 CSS pixels. Neither had horizontal overflow at phone width. Semantic headings/landmarks, a skip link, visible focus treatment, and the support disclosure's keyboard Enter behavior were checked. Structure checks and scope are recorded in [public-pages-check.json](../verification/2026-10-04/release/public-pages-check.json). Backend route/header verification belongs to the [cloud evidence](../verification/2026-10-04/cloud/README.md).

The live responses include `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, and a restrictive Content Security Policy. Response hashes, sizes, check time, and exact URLs are recorded in [public-pages-live-check.json](../verification/2026-10-04/release/public-pages-live-check.json). The root task reports deployment commit `9d1283d`; the content check independently proves the reviewed HTML is being served without exposing deployment secrets.

## Publication gates

1. Root reviewed and deployed the public copy through the existing authorized Render service. Recheck after any later policy change.
2. Production content and headers have been verified without credentials. Preserve the check record and recheck before submission.
3. Add the public links to the app and App Store Connect fields. Recheck them in the final release build.
4. Confirm CareInOne's responsible legal entity after NutriAssist account approval, monitored support/privacy handling, support-mail retention, Render log handling, actual primary/fallback providers, and any OpenAI retention controls. Root inspected Render Settings on October 4 and observed Ohio (US East), 0.5 CPU/512 MB on the existing plan. The public policy now states that verified gateway region while qualifying that it does not establish model-provider processing locations or infrastructure-log retention.
5. Update candid pre-release statements with verified release facts before publication. The current pages explicitly identify pending publisher approval and unknown deployment details; those disclosures avoid a false representation but do not finish the release's legal/privacy sign-off.
6. Reconcile the final App Privacy questionnaire and privacy manifest. Standard retained OpenAI health content cannot be labeled Data Not Collected merely because cloud use is optional.

The HTML pages have no unresolved bracket placeholders. The Markdown policy/support drafts remain editable decision documents with explicit unresolved fields; do not publish those draft files directly.
