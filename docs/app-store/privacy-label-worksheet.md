# App Privacy worksheet

Prepared October 4–5, 2026. This worksheet is a deployment decision aid, not a submitted App Privacy label. It must match the final release, hosting configuration, support practices, and all configured model providers.

Apple distinguishes device-only processing from data transmitted and retained beyond servicing a request. Optional cloud collection still matters. The privacy manifest and the App Store Connect questionnaire are separate disclosures. [Apple App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)

## Actual current flows

| Flow | Data | Device / recipient | Current code behavior | Label consequence to assess |
|---|---|---|---|---|
| Local profile | Display name, birth date, primary/emergency contact | Device | Saved locally; optional fields | Not off-device solely from filling these fields |
| Capture and OCR | Source text, photos, PDFs, files | Device | Original preserved locally; Vision/PDF extraction local | Device-only capture is not itself collected |
| Audio and transcription | Voice recording and transcript | Device | Speech request requires on-device recognition | Do not declare remote audio collection unless the final implementation adds it |
| Optional model extraction | Working source text, source type, event date | Gateway → primary/fallback model provider | Explicit configuration-bound consent; JSON schema/quote validation | Health and Other User Content are likely applicable for normal retained provider processing |
| Gateway authorization | Operator-issued gateway access token; not necessarily unique per installation | Gateway | Bearer token checked against hashed configured values; separate installation tokens require operator provisioning | Review persistence, linkage, and any operational record of the credential; do not treat an identity-linked credential as automatically anonymous |
| Connection metadata | IP address and HTTP connection details | Hosting/model infrastructure | App access logs disabled; infrastructure handling unverified | Declare retained types according to actual use; do not infer region/device tracking solely from a transient network request |
| Local reminders | Generic reminder content | Device notifications | No clinical labels or names in notification body | No app-operated remote notification collection in current code |
| Calendar addition | Appointment title and selected date | User-selected calendar | Write-only permission and explicit action | Explain user's calendar provider may synchronize separately |
| Calendar export receipts | Opaque SHA256 claim/snapshot hashes | Local preferences | Prevent accidental repeat additions after relaunch; no names, medical dates, quotations or event identifiers | Device-only preference storage is not itself off-device collection; acknowledge that Calendar copies require separate editing/deletion |
| Share / backup | User-selected care text/PDF/JSON, encrypted backup | User-selected share destination | Explicit share; no automatic operator upload | User destination receives a copy; do not promise recall |
| Support email | User message, email address, voluntarily attached data | NutriAssist general-contact mailbox | Public address `shivika@nutriassist.org` verified; app-specific handling/retention not established | Review optional-disclosure criteria and actual retention; document support separately |

## Cloud-enabled release: recommended starting answers to verify

- **Tracking:** No, for the inspected source tree. No advertising identifier, cross-app tracking, advertising SDK, or data-broker sharing is implemented.
- **Purpose:** App Functionality for extraction and returning structured proposals. Do not add advertising/analytics purposes that are not used.
- **Health:** Include when cloud analysis processes health-containing care sources and a provider retains them.
- **Other User Content:** Include for retained working source text.
- **Linked to the user:** Conservatively treat retained identifiable care text as linked; absence of an app login does not de-identify names, dates, or patient details in a source.
- **Contact Info / Sensitive Info:** Assess what the actual cloud feature solicits/transmits. Local profile fields are not automatically transmitted. Apple's guidance for generic free-form fields does not require enumerating every conceivable manually entered data type, but a health-focused feature must not be described as generic content to conceal its core data.
- **Identifiers / Diagnostics / Usage Data:** Determine actual gateway enrollment, persistent credentials, hosting access/security logs, model request logs, and support records. No analytics SDK was found, but that does not answer infrastructure retention.
- **Photos or Videos / Audio Data:** The inspected cloud request sends text, not originals or audio. These are stored locally. Revisit answers if remote upload/transcription is added.

OpenAI's standard abuse monitoring can retain prompts/responses for up to 30 days. The code's `store: false` does not establish Zero Data Retention. Therefore the default cloud deployment cannot be assumed eligible for **Data Not Collected**. Confirm any approved controls in the actual organization/project, including fallback behavior. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)

## A Data Not Collected answer requires evidence

This may be supportable for a release whose relevant content remains entirely local, or an off-device request-processing deployment in which every recipient truly discards readable content within the request-service exemption. It requires verifying infrastructure and model behavior, not just the gateway's lack of a database. Do not answer No Collection based only on cloud being optional or currently switched off on one simulator.

## Manifest audit

The initial baseline had an empty collected-data array and no direct UserDefaults use. The current October 4 candidate declares linked Health and Other User Content for App Functionality, Tracking false, no tracking domains, FileTimestamp reason C617.1, and UserDefaults reason CA92.1. The latter now covers app-only local preferences for opaque Calendar export receipts. This source declaration does not save the App Store Connect label. Deeper scanning found fileSizeKey reads for user-selected file import/backup preview; that key is not in Apple's explicit required FileTimestamp API list. Do not add 3B52.1 based solely on those size reads. Inspect the final archive's API/privacy report for actual listed API use, and reconcile the resulting declarations with the final cloud deployment. [Deeper audit](../verification/2026-10-04/release/PRIVACY_MANIFEST_AUDIT.md)

## Operator sign-off worksheet

| Question | Required evidence | Final answer |
|---|---|---|
| Which public cloud path is offered? | Final build and enrollment/support path | Current implementation is operator-configured with no self-service enrollment; final public rollout/reviewer access decision remains unresolved |
| Which hosts and legal operators receive text? | Authenticated gateway config plus legal provider accounts | Unresolved |
| Is a fallback enabled? | Final provider configuration | Unresolved |
| How long does Render retain network/security logs? | Actual plan/region/settings/contracts | Unresolved |
| Is OpenAI Zero Data Retention actually approved and enabled? | Actual organization/project data-control evidence | Unresolved; not assumed |
| What support data is retained and for how long? | Monitored mailbox and written policy | Unresolved |
| Which label answers were saved? | App Store Connect review of final answers | Not submitted |
| Does the in-app policy link match the live public policy? | Final build + HTTPS page check | C8 compiled/source policy links match the reviewed implementation; unchanged deployed HTML bytes verified at 4ec91e3. Reconcile the final signed release and any later deployment. |

## Exact App Store Connect actions

Under the approved publisher, open **Apps → CareInOne → App Privacy**. Set the verified live `/privacy` URL and review data types. For the intended standard-retained OpenAI path, use the following implementation-grounded starting answers; they are not saved declarations:

| Data type | Purpose | Linked | Tracking | Why this implementation needs that answer |
|---|---|---|---|---|
| Health | App Functionality | Yes | No | The cloud feature processes care information; identifiable content is not removed before transmission |
| Other User Content | App Functionality | Yes | No | Working text, including extracted/transcribed text, is submitted for structured proposals |
| Customer Support / Email Address | Confirm actual collection and handling first | Confirm | No if current practices remain | Public general-contact email is verified, but retention and operator handling are not |
| Retained operational connection data | Identify the actual type and use first | Confirm | No if current practices remain | Gateway has no app access logs; infrastructure handling still requires evidence |

Do not mark remote Audio Data or Photos or Videos merely because the device retains originals: current model requests contain working text only. Do not mark Health data as unlinked based on lack of login. Optional cloud permission does not remove a core-function collection disclosure. Save and publish answers only when deployment facts match the final build; preview the resulting label and record the date/build. Apple permits updating labels separately from a binary and requires relevant third-party practices. [Apple privacy management](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

Root observed the current gateway's **Ohio (US East)** region in Render Settings on October 4, 2026. That closes the gateway-region fact only; it does not establish all provider processing locations or hosting-log retention. The general-contact address is supported by [NutriAssist’s contact page](https://nutriassist.org/contact/).
