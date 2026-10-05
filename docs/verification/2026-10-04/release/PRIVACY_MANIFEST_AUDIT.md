# Privacy manifest and dependency audit

Inspected October 4, 2026, with later candidate updates identified below. This source audit now includes an actual [unsigned arm64 Release archive inspection](UNSIGNED_RELEASE_ARCHIVE.md); final signed-artifact inspection and App Store Connect declarations remain required. The root task owns application-resource changes.

## Required-reason API findings

The initial baseline manifest declared `NSPrivacyAccessedAPICategoryFileTimestamp` with `C617.1`. At that point, repo-wide Swift searches found no direct uses of Apple's listed timestamp, boot-time, disk-capacity, active-keyboard or UserDefaults required-reason APIs. Later Calendar duplicate-prevention work introduced `UserDefaults.standard` for app-only opaque export-receipt preferences. The current candidate now declares `NSPrivacyAccessedAPICategoryUserDefaults` with `CA92.1` for that use. No patient names, medical dates, quotations or event identifiers are stored in those preferences; external Calendar copies still require separate editing/deletion.

Apple's `CA92.1` reason covers reading/writing preferences belonging only to the app and excludes accessing other apps' or system-written settings. The audited receipt uses the current app's own key; no app-group/global preference access is implemented. Preference databases may be included in an operating-system device backup, separately from the excluded care-storage directory. Do not describe UserDefaults as encrypted or excluded from all system backups. [Apple required-reason values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons), [Apple UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)

File-size reads appear in `CaptureServices.swift`, `BackupView.swift`, and `AppStore.swift` as `url.resourceValues(forKeys: [.fileSizeKey])`. Security-scoped file access is explicitly requested for imports. Apple's current FileTimestamp API list does **not** list `fileSizeKey` itself. Therefore those reads alone do not demonstrate a missing required-reason declaration. The approved reason `3B52.1` applies when listed required APIs are used to inspect user-granted file metadata; do not add it just because a source mentions size. Preserve the existing declared reason unless an archive/API report establishes different actual usage. [Apple required-reason categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

The initial release audit's suggestion to add `3B52.1` was provisional. This deeper audit supersedes that suggestion. Foundation/framework internals are not proven safe or unsafe solely by a text search; inspect the final build's report and Apple validation output, including compiled dependencies.

## Collected-data declarations

The baseline manifest has `NSPrivacyCollectedDataTypes: []`, Tracking false, and no tracking domains. No analytics, advertising, cross-app tracking, or crash-reporting SDK was found. Local-only storage, selected-item PhotosPicker, local Vision/PDF processing, local notifications, and on-device speech do not by themselves establish off-device collection.

Optional cloud analysis sends health-containing working source text to the configured gateway and model provider. OpenAI standard abuse-monitoring retention is separate from request-only gateway memory; `store: false` does not establish Zero Data Retention. An empty collected-data array should be reconciled with the intended cloud-enabled release and App Privacy questionnaire rather than treated as proof of No Collection. [Apple collected-data categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype), [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data)

A conservative starting point for a retained OpenAI deployment is:

| Manifest value | Intended value to confirm | Reason |
|---|---|---|
| `NSPrivacyCollectedDataTypeHealth` | Included | Main cloud input is user-provided health/care information |
| `NSPrivacyCollectedDataTypeOtherUserContent` | Included | Retained source text is user-generated content |
| `NSPrivacyCollectedDataTypeLinked` | `true` | Source text can contain identifying care details even without login |
| `NSPrivacyCollectedDataTypeTracking` | `false` | No implemented cross-app tracking purpose |
| `NSPrivacyCollectedDataTypePurposes` | `NSPrivacyCollectedDataTypePurposeAppFunctionality` | Model analysis returns structured proposals for app functionality |

The root task has applied linked Health and Other User Content / App Functionality declarations to the current source manifest. The final label may require additional types for actual enrollment, support correspondence, or retained infrastructure logs. Do not blindly enumerate every possible free-form datum, declare remote photos/audio that are not uploaded, or claim optional cloud is exempt without retention evidence. See the [deployment worksheet](../../../app-store/privacy-label-worksheet.md).

The following illustrates the now-applied Health/Other User Content declaration. Keep the accessed-API array separately, including the current app-only UserDefaults reason. Apple’s dictionary structure has exactly the data type, linked status, tracking status and purposes keys. [Apple TN3184](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest)

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeHealth</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeOtherUserContent</string>
    <key>NSPrivacyCollectedDataTypeLinked</key><true/>
    <key>NSPrivacyCollectedDataTypeTracking</key><false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
  </dict>
</array>
```

Use actual booleans, not strings. Tracking remains false/no tracking domains for the inspected app. Adding these entries does not submit App Store Connect answers or prove provider retention; final manifest, public disclosure, consent and saved label must agree.

## Native dependencies and resources

| Item | Inspected result | Remaining check |
|---|---|---|
| Swift Package | Local CareCore target only; no third-party remote package | Unsigned Release archive loads only Apple system/Swift libraries and embeds no third-party framework; final signed artifact recheck separate |
| Apple frameworks | SwiftUI, SwiftData, Vision, PDFKit, AVFoundation, Speech, EventKit, LocalAuthentication, Security, CryptoKit | Availability/permission behavior on supported hardware |
| App icon | 1024×1024, 8-bit RGB, no alpha in source PNG | Final asset compilation and App Store validation |
| Privacy manifest packaging | File referenced as an app resource in generated project | Inspect final `.app` and generated privacy report |
| Backend packages | Locked click/h11/uvicorn runtime; non-root Docker user; no app analytics SDK | Deployed image/version verification owned by cloud task |

## Release configuration findings

- iOS deployment target is 18.0. The project targets both iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`); iPad validation/screenshots are required for that release target.
- Stable bundle identifier `org.carecontinuity.app` and SwiftData module `CareContinuity` remain compatibility identifiers. Public branding is CareInOne. Renaming internal identity casually can create a different container or break persisted model compatibility.
- Automatic signing is configured, but no `DEVELOPMENT_TEAM` is committed in the baseline project. Actual NutriAssist team approval, App ID registration, distribution signing, archive validation, and upload are unresolved by this source audit.
- Version 1.0/build 1 must be checked against actual App Store Connect before upload. Increase build number when a duplicate build has already been accepted there.
- The project generator recreates signing settings; editing a team only in a generated project may be lost on regeneration. Root should preserve the selected team/configuration intentionally once verified.
- The app uses OS data protection and explicit encrypted backups. The baseline had no encryption answer; the parent has now applied and this audit parsed actual Boolean `ITSAppUsesNonExemptEncryption=false` in source Info.plist. Apple CryptoKit AES-GCM, CommonCrypto PBKDF2, Security and URLSession constitute the inspected crypto inventory; no vendored/custom cipher was found. Apple’s OS-only branch requires no App Store Connect documentation, supporting a Boolean `false` engineering declaration now for the audited implementation, with final archive linked-library and compiled-plist verification before upload. Separate export/reporting responsibilities remain with the publisher; false does not mean no encryption. Do not state that encryption is absent. [Exact export actions](../../../app-store/encryption-export-worksheet.md)
- No iCloud, HealthKit, push, background-audio, StoreKit/IAP, or ad entitlement/integration was found. Do not advertise those as present.
- Current purpose strings cover camera, chosen microphone recording, on-device speech, device authentication, and calendar write-only access. Capture's candidate wording uses “this device” for on-device speech, which also covers the supported iPad target. Selected-item photo picker does not require whole-library access.
- The app supports portrait/landscape on iPhone and all four orientations on iPad. Test landscape, sheet/popover sharing, file pickers, and largest text on iPad; simulator iPhone success alone is insufficient.
- App Store availability can make iOS apps available on Apple-silicon Macs and Apple Vision Pro by default. Opt out of untested platforms or verify relevant behavior before release. [Apple submission guidance](https://developer.apple.com/app-store/submitting/)

Current Xcode 27 meets the documented current SDK direction. The newly announced iOS/iPadOS 27 SDK minimum begins April 2027, not October 2026. Use actual current upload validation as the final authority; do not invent a future requirement as a present blocker. [Apple submission guidance](https://developer.apple.com/app-store/submitting/)


The actual unsigned Release archive includes the exact reviewed privacy manifest and Boolean encryption false, default ATS without exceptions, complete permission strings, matching executable/dSYM UUID and Apple-only library paths. Unsigned entitlements cannot establish physical-device enforcement. Its no-team/no-signature status is documented in the linked audit; no uploadability is claimed.
