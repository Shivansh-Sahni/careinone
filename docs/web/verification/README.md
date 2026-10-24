# CareInOne Web verification — October 19, 2026

This evidence uses fictional records only. The web implementation is separate from the native app; native UI/release claims are not inferred from these checks.

## Automated checks

- 38 JavaScript tests pass: review/provenance, uncertainty gates, duplicate handling, source deletion, appointment/task dependency pauses, FHIR, numeric units, exact-quote record lookup, encrypted backup integrity, IndexedDB persistence, two concurrent writers, stale retry, restore revisions, failed-save preservation and clearing.
- 23 web ASGI/gateway/packaging tests pass on Python 3.13.7 and Python 3.14.3.
- All 108 unchanged gateway regression tests pass on both Python families.
- The actual localhost HTTP smoke passes with the pinned Python 3.13 runtime, including seven document/application assets, legacy public routes and authenticated consent-bound mock extraction. [HTTP summary](http-smoke-py313.json). No provider key is used and **zero paid calls** are made.
- Production npm dependencies report zero known vulnerabilities after PDF.js was pinned to the unaffected stable 5.5.207. The initially supplied 5.6.205 was rejected by audit and is not the delivered version. OCR is Tesseract.js 7.0.0; the selected English model is self-hosted. Dependency audit is point-in-time evidence, not a penetration test.
- JavaScript syntax checks cover every application module. The browser assets build deterministically from the lockfile. Dedicated Docker context/runtime file checks pass; a Docker daemon is unavailable locally, so container execution has not been verified. CI includes the image build.

## Actual browser acceptance

Verified in the Codex in-app browser against localhost:

1. Fictional example loaded; every screen retained the synthetic-example banner.
2. Typed capture persisted across reload, created pending proposals, and appeared in My care only after explicit acceptance. The two-dose example retained both source quotes and showed an unresolved discrepancy.
3. Follow-through date/precision/status/notes editing saved. Completion remained a patient report.
4. A visit agenda/recap persisted and the recap entered the normal pending-review pipeline.
5. An encrypted backup was downloaded and restored with the matching passphrase. Wrong-passphrase and tamper handling are covered separately by automated crypto tests.
6. A synthetic native-text PDF was parsed entirely in the browser. Image OCR recognized the synthetic glucose value and clinic task; those proposals were saved with page provenance and the original image. A synthetic scanned PDF was rasterized/OCR'd locally and its original/three pending statements were also saved.
7. The reviewed glucose result displayed 95 mg/dL, its October 1 event date and its original-source link. It did not fabricate a chart from one observation.
8. A two-tab test left an edit dialog open in the first tab, saved a new fictional question in the second, then attempted the first tab's save. The application rejected it with “Records changed in another tab. Reload before saving.” The second-tab question remained. [Rejection screenshot](stale-tab-rejected.jpg).
9. Desktop 1440×960 and phone 390×844 layouts were inspected. On the phone, document width and viewport width both measured 390 pixels, with no page-wide horizontal overflow. Navigation is horizontally scrollable on small screens. [Desktop](today-desktop.jpg), [phone](today-phone.jpg).
10. Browser console error/warning checks were empty after successful PDF and OCR processing.

The browser tool intermittently encountered automatic permission-review timeouts; allowed retries succeeded. These were tool interruptions, not application test failures. The OCR integration's initial ESM-export mistake and an initial duplicate-content handling issue were repaired before the successful acceptance results above.

## Live service checks and remaining gates

Public existing Render privacy and support routes returned HTTPS 200/no-store. Two public health reads could not be completed from this environment (`URLError`); this is not a diagnosis that the deployed service is unhealthy. [Exact route-attempt report](existing-render-routes.json).

No public site deployment, DNS mutation, domain purchase, Render billing change, production gateway credential retrieval or paid inference occurred. The real deployed cloud flow, container boot, wider browser matrix and physical microphone behavior remain explicit release checks. The default local server leaves cloud analysis unconfigured; local care workflows work independently. Follow [the launch plan](../LAUNCH_PLAN.md) to configure the same existing gateway and deploy the tested revision.
