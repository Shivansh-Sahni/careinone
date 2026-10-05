# CareInOne release audit — October 4, 2026

Initial scope was source/resource inspection and official Apple/OpenAI requirements. Later work added drafts, public HTML, read-only App Store Connect inspection, export/editor/alias repairs, and focused tests, documented below and in their evidence files. This task did not read private API keys, alter developer-account terms, sign/upload an archive, or submit the app. The root owns live service operations, final builds/simulator tests and final status.

## Owner decisions

CareInOne is intended to be published by NutriAssist after organization conversion. Individual membership is active according to the owner; conversion is pending, not independently verified here. First release is free, with no ads, subscriptions, or IAP. The developer pays operating costs. No new purchase or spending-limit increase is authorized.

## Inspected baseline

| Area | Source evidence | Observation |
|---|---|---|
| Public brand | Info.plist, onboarding, views | CareInOne throughout inspected public app copy; some internal names intentionally preserve compatibility |
| Minimum OS | project.pbxproj | iOS 18.0 |
| Devices | TARGETED_DEVICE_FAMILY | iPhone and iPad (1,2) |
| Version | Info.plist | Version 1.0, build 1 |
| Signing | project.pbxproj | Automatic signing; no DEVELOPMENT_TEAM committed |
| Identifier | project.pbxproj | org.carecontinuity.app; do not rename casually |
| Entitlements | CareInOne.entitlements | Default Data Protection Complete; no iCloud/CloudKit, HealthKit, push, or background-audio capability |
| Purpose strings | Info.plist | Camera, microphone, on-device speech, Face ID, calendar write only |
| Local records | Persistence.swift | SwiftData local payloads, no CloudKit; protected Application Support/evidence directory excluded from backup |
| Credentials | SecurityServices.swift | Atomic gateway endpoint/token Keychain item, WhenUnlockedThisDeviceOnly |
| App lock | SecurityServices.swift | DeviceOwnerAuthentication with passcode fallback; inactive-screen shield |
| Exports | ExportService.swift | Explicit text/PDF/JSON share and passphrase-encrypted backup; no automatic operator upload |
| Reminders | ReminderService.swift | Local, generic clinical-detail-free body; explicit calendar write |
| Speech | CaptureServices.swift | requiresOnDeviceRecognition true; unavailable recognition reports failure rather than remote fallback |
| Network | CloudAnalysis.swift | Ephemeral session, HTTPS, no redirects/cookies/cache; working text/type/date forwarded, not originals |
| Gateway | backend/app.py | Stateless content processing; no-store responses, hashed credential checks, bounded inputs/concurrency/rate, explicit configuration-bound consent |
| OpenAI | backend/providers.py | Chat Completions, store false; this does not establish provider Zero Data Retention |
| SDKs | Package.swift/project source search | No advertising, analytics, tracking, crash-reporting SDK, HealthKit, live EHR, or StoreKit integration found |
| Public links | HelpPrivacyView.swift, SettingsView.swift | Help/privacy explanatory text exists; no live privacy-policy URL or support contact/link found at initial audit |
| Manifest | PrivacyInfo.xcprivacy | No tracking; empty collected-data types; FileTimestamp C617.1 only at initial audit |

## Blockers and recommendations for the root task

| Priority | Finding | Concrete next step | Evidence needed to close |
|---|---|---|---|
| P0 | Organization publisher pending | Prepare archive/materials but do not substitute individual publication | Actual organization approval/App Store Connect identity |
| P0 | No signed submission artifact established | Select actual team and registered identifier, archive/validate | Signed archive and Organizer validation |
| P0 | Public privacy/support identity and URLs unknown | Finish drafts, verify monitored contact and legal operator, host approved pages, add app links | Live URLs + final build links |
| P0 | Cloud privacy label is not settled | Confirm provider/infrastructure retention and reconcile manifest/questionnaire | Actual deployment evidence and saved App Privacy answers |
| P1 | Public cloud enrollment absent | Implement a safe bounded user path or accurately describe operator-configured optional cloud | Fresh-install ordinary-user path, not just reviewer credentials |
| P1 | A provider key was displayed as model name in supplied screenshots | Reject/redact credential-shaped model identifiers at provider/config/client boundaries; rotate exposed credential | Regression tests and corrected deployed model configuration |
| P1 | Required-reason declarations need final archive verification | Deeper Swift scan found only fileSizeKey, which is not in Apple's explicit FileTimestamp required list; do not add 3B52.1 based solely on size reads | Built manifest/privacy report; see deeper audit |
| P1 | iPad target requires suitable release assets/validation | Test iPad layouts and capture accepted screenshots | Final native-pixel iPad captures |
| P1 | Export-compliance answer absent | Assess Apple-system crypto exemption for actual final archive; do not claim no encryption | Final declaration or documentation |
| P1 | Device validation not established by this audit | Run camera/audio/lock/notifications/VoiceOver/restore checks on actual supported hardware | Dated device results |
| P2 | Settings labels sample section Synthetic CAC demo | Prefer consumer wording such as Sample patient / Practice imports | Final public UI copy |

## Official-source findings

Apple expects a complete working submission, accurate metadata/review access, accessible policy links and support contact, consent for third-party AI sharing, and appropriate legal-entity submission for sensitive healthcare services. It also scrutinizes medical accuracy claims. These requirements support waiting for NutriAssist conversion and avoiding unverified clinical claims. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

On-device-only data does not require collection disclosure solely because it is stored locally. The off-device exemption depends on discarding readable data within request servicing; optional retained provider processing still needs assessment. [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)

OpenAI standard API abuse monitoring may retain prompt/response content for up to 30 days. `store: false` does not itself turn on Zero Data Retention. No approved retention control was verified in this audit. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)

Additional primary references fetched October 4, 2026:

- [Apple platform metadata fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Apple upload-build requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Apple required-reason API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Apple export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Apple regulated-medical-device declaration](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status)
- [Apple age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

## Draft artifacts and validation

The [App Store packet](../../../app-store/README.md) contains listing, review instructions, policy/support drafts, privacy worksheet, and submission checklist. Metadata-length validation is recorded separately. Missing legal/privacy facts are deliberately explicit so the operator can approve a concrete draft instead of an invented representation. The reviewed HTML has since been deployed; hosting evidence does not make the final policy or publisher identity approved.

The [deeper privacy/release audit](PRIVACY_MANIFEST_AUDIT.md) supersedes the provisional imported-file reason recommendation. [Public pages](../../../app-store/hosting-plan.md) use the verified NutriAssist general contact and candid pending-release disclosures. Local HTML/browser checks passed. The [October 4 production check](public-pages-live-check.json) establishes both exact HTTPS URLs return 200, restrictive headers, and the reviewed source bytes. Final legal/privacy completion remains separate.

## Later candidate observations

Root inspected the Apple Developer account and observed Individual enrollment with renewal October 4, 2027; no organizational identity was shown. Local inventory contained zero valid Apple signing certificates. These concrete observations keep the NutriAssist account/signing gate open without preventing development. No account or certificate mutation was performed by this audit.

The subsequent [read-only App Store Connect inspection](APP_STORE_CONNECT_READINESS.md) independently found only the Vaibhav Sahni team, an Active Free Apps Agreement through October 4, 2027, Account Holder/Admin access, and no visible CareInOne app record. No terms, account, role or app-record changes were made. [Current upload/asset requirements](APPLE_UPLOAD_REQUIREMENTS.md) and [screen/control reachability](NAVIGATION_AND_CONTROL_AUDIT.md) are separately recorded.

The current source privacy manifest declares linked Health and Other User Content for app functionality, tracking false. Its required-reason API declarations retain FileTimestamp C617.1 and add app-only UserDefaults CA92.1 for opaque Calendar export-receipt preferences. This addresses the initial empty-manifest finding and the later direct preference use, but the final archive privacy report and App Store Connect questionnaire still require agreement with actual cloud retention and support handling.

Calendar policy/support wording has been updated in source to explain repeat-addition prevention, write-only permission and external-copy limits. The existing live byte-match record verifies the preceding published HTML revision; root must deploy and recheck the updated files before it establishes those latest disclosures in production.

Source exports now use unique protected file preparations and content-bound PDF sharing; the [export audit](EXPORT_AUDIT.md) distinguishes completed implementation from pending final native/UI validation. Scope of these later source edits is separate from the initial read-only release inspection above.


The [bounded real gateway record](../cloud/strict-output-live-result.json) now confirms successful actual connection and three-claim extraction on strict-schema deployment `9f5e88b`, with exact supporting quotations and four paid server-verifier requests total. The native app pipeline remains blocked before inference because the earlier baseline fixture cleared the simulator Keychain gateway pair. Fixture isolation is repaired, but the endpoint/token must be restored privately before native source → review → saved-care/relaunch can be claimed. Zero paid native requests were attempted.

The [export worksheet](../../../app-store/encryption-export-worksheet.md) now supports setting Boolean `ITSAppUsesNonExemptEncryption=false` for the audited OS-only encryption, followed by compiled-plist/link inspection. This is not a claim of absent encryption or government classification. Final signed validation remains blocked by zero local signing identities and the missing NutriAssist account identity. Final large-iPhone/iPad asset paths and a PNG verifier are prepared; no capture is claimed by the release audit.

## Current publication packet reconciliation

The [frozen Candidate5 unsigned Release archive](UNSIGNED_RELEASE_ARCHIVE.md) succeeded and confirms unchanged pre/post app/Core/resource/project hashes, the compiled Boolean encryption declaration, reviewed privacy manifest and Apple-only library inventory. It preserves the earlier artifact. It cannot be uploaded; the final signed archive and Organizer validation remain open.

Current Help/privacy source contains the actual HTTPS privacy/support links. Prior deployed page revisions returned HTTP 200 with reviewed bytes; latest Calendar receipt wording still requires a new deployment/content check. The Markdown privacy draft now distinguishes care/evidence exclusion from backup from preferences that may enter device backup.

The review draft uses the actual **Explore the fictional demo** label and explicitly exits practice before optional cloud setup. Practice never changes personal credentials/consent. Managed public cloud enrollment, remote caregiver accounts, live hospital integration, automatic clinic delivery, diagnosis and clinical correctness are not claimed. Ordinary users have local functionality without required sign-in; optional cloud remains privately operator-configured.

Complete note recovery passed in finalized [focused8](editor-recovery8-summary.json), while focused6 separately passed complete question/encounter recovery. Historical failures, runtime warnings and diagnostic interventions remain recorded. Candidate4's full result was 150 executed/146 passed/three failed/one skipped; focused repairs are not combined into a new passing full candidate. Frozen Candidate5 native finalized129 executed/128 passed/zero failures/one explicitly gated live-cloud skip, with zero xcresult runtime warnings. Current core173 Swift Testing and backend108 cases passed. The [feature ledger](FEATURE_VERIFICATION.md) additionally records minimum-OS SE6, repeated companion4, review/workspace2, Ask one UI plus two native checks, and separate ordinary-editor focused outcomes without adding repeated cases. The final full Candidate5 UI action, native live-cloud and physical-device boundary checks remain separate.

The listing reflects CareInOne, free price, no ads/subscriptions/IAP, developer-funded operation, and intended NutriAssist publishing. Exact legal operator/rights holder, monitored support/privacy handling and retention, App Privacy answers, age/medical declarations, selected territories, private review contact, cloud access, final native screenshots and NutriAssist approval are still owner-dependent. No submission-ready or App Review approval claim is made.
