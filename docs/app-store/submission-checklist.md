# Submission checklist

This checklist separates software work from decisions that cannot be inferred from source code. No App Store upload, review submission, or public release is claimed.

## Publisher and ownership

- [ ] Confirm Apple has approved conversion to NutriAssist's organization membership and App Store Connect reflects the verified entity. Do not substitute the current individual identity.
- [ ] Confirm the actual signing team, app identifier registration, and rights holder. Preserve `org.carecontinuity.app` and existing data/Keychain identifiers unless a deliberate migration is required.
- [ ] Select or create the CareInOne app record under that publisher. Verify name availability in App Store Connect; a local filename does not reserve the name.
- [ ] Confirm current Apple agreements and access for the person uploading/submitting.
- [ ] Set price to free, with no IAP products/subscriptions or advertising claims.

## Release binary

- [ ] Record final commit/worktree state, build number, Xcode version, SDK, and actual archive path.
- [ ] Archive the Release scheme for generic iOS devices with the correct signing identity/provisioning.
- [ ] Inspect the archived entitlements, Info.plist, privacy manifest, icon, and privacy report; validate in Xcode Organizer.
- [ ] Increment the build number before a new upload if the prior build number has been uploaded.
- [ ] Complete the [encryption export worksheet](encryption-export-worksheet.md). Source uses Apple OS CryptoKit/CommonCrypto/URLSession only, supporting the OS-only no-documentation branch. Set `ITSAppUsesNonExemptEncryption` to actual Boolean `false` for this audited implementation before archive, then confirm the compiled plist and linked libraries. If the implementation/determination changes to require documentation, use `true` plus Apple’s actual returned code. It must not be described as using no encryption.
- [ ] Confirm production endpoints, secret isolation, review access, and bounded service availability.
- [ ] Run release-candidate automated and simulator tests; save results. Physical camera/microphone, notifications, Data Protection, biometric/passcode fallback, VoiceOver, and restore after reinstall still require device evidence.

Current upload requirements are documented in [Apple upload-build guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds). Encryption disclosure should follow [Apple export-compliance guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).

The [October 4 requirements check](../verification/2026-10-04/release/APPLE_UPLOAD_REQUIREMENTS.md) records the current Xcode 26+/iOS 26 SDK+ and iOS 13+ target thresholds, and the announced April 2027 SDK 27+/iOS 15+ thresholds. The [read-only App Store Connect check](../verification/2026-10-04/release/APP_STORE_CONNECT_READINESS.md) confirms an active individual Free Apps Agreement and Account Holder/Admin access, with no visible NutriAssist team or CareInOne app record. Neither observation closes the organization publisher or signed-archive gate.

## Cloud rollout

- [ ] Choose the actual user path: managed enrollment with private per-installation credentials, or explicitly operator-configured optional cloud. The inspected build has no self-service public cloud enrollment.
- [ ] Do not embed a shared production gateway token in an app binary or public page.
- [ ] Verify live synthetic inference and source → validated proposal → review → persistence with fictional data.
- [ ] Confirm exposed provider credentials have been revoked and replacement model names are identifiers, not secrets.
- [ ] Keep spending limits and recurring costs unchanged; define what users see when quota is exhausted.
- [ ] Provide reviewer-specific access privately if cloud is in the submitted feature set.
- [ ] Complete [the privacy-label worksheet](privacy-label-worksheet.md) using actual deployment evidence.

## Public pages and privacy

- [ ] Verify NutriAssist's exact legal operator name and a monitored support/privacy contact.
- [ ] Complete the privacy/support drafts, host them at live HTTPS URLs, and verify those URLs require no login.
- [ ] Add an easily accessible in-app policy link and support contact/link in the final build. In-app explanatory text alone does not supply the required policy URL.
- [ ] Confirm provider/hosting retention, consent withdrawal, support retention, and deletion practices.
- [ ] Save accurate App Privacy answers, including retained third-party processing.

## Listing and review

- [ ] Reconcile listing and review paths with the actual final build; remove claims of unavailable cloud enrollment or unverified features.
- [ ] Capture screenshots from the release candidate using fictional data only. Do not submit macOS Simulator-window screenshots or screenshots with secrets.
- [ ] Upload an accepted large-iPhone set (6.9-inch, or the documented 6.5-inch alternative) and a 13-inch iPad set because the target supports iPad. PNG/JPEG files must have no alpha channel. A practical capture plan is six screens: Today, source review, care history, appointment companion, selected visit packet, and follow-through assistance.
- [ ] Verify screenshot layout/readability and crop to native device pixels. Accepted current 6.9-inch portrait sizes include 1260×2736, 1290×2796, and 1320×2868; current 13-inch iPad portrait sizes include 2064×2752 and 2048×2732. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [ ] Complete the current age-rating questionnaire. Review the medical/treatment-information item rather than presuming the app qualifies for 4+.
- [ ] Complete the applicable regulated-medical-device declaration truthfully. Medical/Health & Fitness category selection or frequent medical/treatment content can trigger the declaration in listed territories. No regulatory status is claimed here. [Apple declaration instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status)
- [ ] Select territories intentionally; complete applicable trader/contact/compliance details instead of inferring them from nonprofit or free-app status.
- [ ] Set accessibility claims only from final manual evaluation.
- [ ] Opt out of automatic availability on Apple-silicon Mac/Apple Vision Pro unless those platforms have been validated for the selected release. iPhone/iPad target support is separate from these compatibility-store options.
- [ ] Fill the private review contact fields and confirm the reviewer path works on a clean installation.
- [ ] Use a manual release option so approved review does not accidentally publish before publisher/operational readiness is confirmed.
- [ ] After all remaining facts are resolved, authorized owner reviews the concrete archive, metadata, screenshots, and disclosures before submission/release.

## Unsigned engineering artifact

The [unsigned generic iOS Release archive audit](../verification/2026-10-04/release/UNSIGNED_RELEASE_ARCHIVE.md) records an actual successful arm64 archive with compiled version/manifest/encryption checks. It is not uploadable: identity/team/profile/signature are absent and no valid local signing identity is available. Rebuild and validate the final signed artifact only after the intended NutriAssist team and bundle registration are available.
