# Encryption export worksheet

Prepared October 4, 2026 from the current source and official Apple guidance. This is an implementation inventory and submission decision worksheet. No encryption declaration, territory choice, or classification has been submitted.

## What the app actually uses

| Use | Implementation | Source evidence |
|---|---|---|
| Optional gateway connection | HTTPS through Foundation `URLSession`, ephemeral configuration, no redirect forwarding | `CareInOne/Services/CloudAnalysis.swift` |
| Encrypted backup | Apple CryptoKit `AES.GCM.seal/open`, 256-bit derived key, random 32-byte salt, authenticated version marker | `CareInOne/Core/CareArchive.swift` |
| Backup passphrase derivation | Apple CommonCrypto `CCKeyDerivationPBKDF`, PBKDF2-HMAC-SHA256, 600,000 iterations, 32-byte output | `CareInOne/Core/CareArchive.swift` |
| Secure randomness | Apple Security `SecRandomCopyBytes` | `CareInOne/Core/CareArchive.swift` |
| Device storage / gateway credential | iOS Complete Data Protection and Apple Keychain APIs | `CareInOne/Resources/CareInOne.entitlements`; local vault/Keychain services |
| Linked cryptographic dependencies | Inspected package contains local CareCore only; no vendored encryption library or custom cipher implementation was found | `Package.swift`; generated Xcode project |

The backup file format and additional authenticated version marker are application formats, not a new encryption algorithm. Do not describe the app as using no encryption, and do not treat a 256-bit key by itself as proof that a CCATS is required.

## Current Apple guidance and our inference

Apple’s documentation table distinguishes OS-provided encryption from standard algorithms implemented outside the Apple OS and proprietary algorithms. OS-only encryption needs no App Store Connect documentation. Non-OS industry-standard encryption requires a French declaration when distributing in France; proprietary algorithms require CCATS and the applicable French declaration. [Apple documentation table](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption)

The inspected CareInOne implementation uses only the audited Apple operating-system APIs: CryptoKit, CommonCrypto, Security, Data Protection, and URLSession. With no vendored/custom cipher or additional cryptographic dependency found, the current source supports the OS-only branch. **Engineering recommendation: set `ITSAppUsesNonExemptEncryption` to Boolean `false` now, then confirm the final archive matches this inventory.** No separate owner clarification is necessary to prepare that truthful source declaration. This records the app’s implementation against Apple’s documentation rule; it is not a government classification, a claim of Apple clearance, or a statement that the app is unencrypted.

Apple’s plist guidance says Boolean `false` is appropriate for no encryption **or exempt encryption**, while `true` denotes non-exempt encryption. Leaving the key absent invokes the questionnaire. OS HTTPS is typically exempt; exemptions can still involve separate government reporting. [Apple plist key](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption), [Apple encryption guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)

## Exact submission actions

1. Retain this inventory with the final build number and archive. Confirm no additional linked dependency implements encryption outside Apple’s OS.
2. Under the approved NutriAssist publisher, retain this inventory with the actual territory choices. If App Store Connect requests encryption answers, open **Apps → CareInOne → App Information → App Encryption Documentation (+)**, or **Manage** next to a build missing encryption information. Describe the implemented OS APIs accurately and answer the displayed questions. Upload documentation only if the actual app/distribution determination requires it. [Apple workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)
3. For the currently audited OS-only implementation, add the following actual Boolean to the app’s source `Info.plist` before the final archive, then verify the value and linked dependencies in that archive:

   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <false/>
   ```

   This does **not** say the encrypted backup is unencrypted. Do not add `ITSEncryptionExportComplianceCode` for a no-documentation branch.
4. If the final determination requires documentation, use `ITSAppUsesNonExemptEncryption = true`. Upload required documentation and use **only the actual code Apple returns** as `ITSEncryptionExportComplianceCode`. Do not invent a code or copy another app’s.
5. Review any government self-classification/reporting obligations for the selected exemption and distribution. App Store documentation exemption is not a blanket statement of exemption from every export rule. Apple assigns the developer responsibility for accurate interpretation. [Apple overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)

## Current source status

The parent has now added actual Boolean `false` to source `Info.plist`; this release audit parsed the plist and confirmed the type/value. No compliance code is set. This is justified by the OS-only source inventory and does not require inventing a code or waiting for the NutriAssist conversion. Inspect the compiled final `.app` plist and linked frameworks/libraries before upload. Revisit the declaration if future dependencies supply their own encryption or custom algorithms. No purchase, signing mutation, upload, or territory change was performed by this task.

| Final record | Status |
|---|---|
| Archive/build inspected | [Unsigned arm64 iOS Release archive](../verification/2026-10-04/release/UNSIGNED_RELEASE_ARCHIVE.md), CareInOne 1.0 (1), Xcode 27 / SDK 27; final signed artifact remains separate |
| Linked encryption dependencies match inventory | Unsigned archive loads only Apple system/Swift libraries, no embedded frameworks; CryptoKit AES-GCM, CommonCrypto PBKDF2 and Security symbols confirmed |
| App Store Connect determination | Not completed |
| Intended territories | Owner/publisher decision not recorded here |
| Required documentation / government reporting conclusion | Not assumed |
| Final plist Boolean / compliance code | Actual Boolean false parsed in source and unsigned compiled Info.plist; no compliance code. Recheck the signed upload artifact |
