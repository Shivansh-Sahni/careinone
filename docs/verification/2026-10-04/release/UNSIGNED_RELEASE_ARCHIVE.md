# Unsigned iOS Release archive

## Latest actual Candidate7 archive

The generic iOS Release Candidate7 archive completed with actual runner exit 0 and ARCHIVE SUCCEEDED. It includes the two final production repairs (conflict row hit area and visit debrief keyboard Done), and is durably preserved at [artifacts/release/CareInOneUnsignedCandidate7.xcarchive](../../../../artifacts/release/CareInOneUnsignedCandidate7.xcarchive). The earlier Candidate5 archive is preserved separately.

[Compiled inspection](unsigned-candidate7-archive-inspection.json) confirms CareInOne, compatible bundle org.carecontinuity.app, version 1.0/build 1, iOS18+, arm64 iPhone/iPad, SDK27/Xcode27, actual Boolean OS-only encryption declaration false, exact source privacy manifest, no ATS exception, no embedded frameworks/non-Apple linked libraries, expected Apple system cryptography, matching arm64 dSYM and no Debug reset/UI/demo arguments in the Release binary. The archive log contained zero warning/error diagnostic lines; this is not a runtime-warning claim. The bounded seven-file compiled-prefix scan found zero recognized credential patterns; no matching values were serialized, and no universal secret-absence claim is made.

All 64 app source/resource inputs from root's Candidate7 before snapshot remained unchanged at inspection. Package.swift separately matches the earlier archived fingerprint; current UI helper/tooling edits in the broad 119-path snapshot are outside the production-file comparison. [Production comparison](candidate7-archive-production-after.json), [known-prefix screen](unsigned-candidate7-file-screen.json), [libraries](unsigned-candidate7-dylibs.log) and [actual log](unsigned-candidate7-archive.log) retain exact evidence. The [durable-copy check](unsigned-candidate7-durable-copy-check.json) verifies all 11 regular archive files /24,457,543 bytes byte-for-byte; the artifacts directory is ignored by Git.

**Not uploadable:** zero valid local signing identities; no archive team, signing identity, profile or signature. Source Data Protection entitlement is not enforced proof for unsigned hardware. No certificate/profile was created/downloaded, no agreement accepted, and no App Store upload/submission/release occurred. The corrected native action, scoped full UI recoveries, final visual screenshots, native cloud request and NutriAssist/physical-device/legal publication gates remain separate until their own direct evidence is attached.


**Final-source exceptions, October 5:** root authorized two narrow production repairs after minimum-OS runtime failures: full rectangular hit-area behavior in ConflictsView (FollowThroughViews.swift), and native keyboard Done/focus dismissal in VisitDebrief (VisitWorkspaceView.swift). Candidate5 archive/native and the running Candidate6 UI action compiled the earlier app snapshot. The preserved Candidate5 archive remains evidence for that snapshot, but is no longer the final exact app candidate. Candidate7 unsigned archive/source inspection and ordinary native execution (128 passed, one live-gated skip) are completed separately; scoped UI/native real-cloud/hardware evidence remains distinct.

**Preserved earlier Candidate5 artifact:** `/private/tmp/CareInOneUnsignedReleaseCandidate5.xcarchive` completed **ARCHIVE SUCCEEDED**, exit 0. Its [new inspection](unsigned-candidate5-archive-inspection.json), [log](unsigned-candidate5-archive.log), [library inventory](unsigned-candidate5-dylibs.log) and [bounded credential screen](unsigned-candidate5-file-screen.json) are independent of the earlier artifact below. All 68 app/Core/resource/package/project/scheme hashes match [before](candidate5-archive-source-before.json) and [after](candidate5-archive-source-after.json). This closes the frozen-source unsigned build/audit only, not uploadability or runtime readiness.

**Durable workspace copy:** [artifacts/release/CareInOneUnsignedCandidate5.xcarchive](../../../../artifacts/release/CareInOneUnsignedCandidate5.xcarchive). Root preserved it with `ditto`; the [full regular-file comparison](unsigned-candidate5-durable-copy-check.json) confirms identical file bytes to the audited temporary archive. This artifact is intentionally ignored by Git. The original temporary archive and earlier archive remain preserved. Copying does not sign it or make it uploadable.

Candidate5's compiled name/compatible bundle/version/build/OS/device families match the earlier values below. It has the actual Boolean encryption declaration, exact reviewed privacy manifest, zero non-Apple library paths, Apple crypto symbols, matching executable/dSYM UUIDs, no Debug launch switches, zero known credential-pattern matches and zero archive-log warnings/errors. It has no code signature/profile/team; local signing identity count remains zero.

## Preserved earlier engineering artifact

`xcodebuild archive` completed **ARCHIVE SUCCEEDED**, exit 0, with Release optimization for generic iOS device `arm64`. The build used Xcode 27 / iOS 27 SDK and preserves the compatible internal bundle identity `org.carecontinuity.app`; public name is CareInOne, version 1.0, build 1, minimum iOS 18.0. iPhone and iPad are supported.

Artifact: `/private/tmp/CareInOneUnsignedRelease20261004.xcarchive`.

This artifact is **not uploadable**. Code signing was explicitly disabled, its archive identity/team are empty, no profile or code signature is embedded, and the read-only local audit found zero valid signing identities. No certificate/profile was created or downloaded, no App Store validation/upload was attempted, and the individual publisher identity must not substitute for the intended NutriAssist organization.

## Actual artifact checks

The [machine-readable inspection](unsigned-release-archive-inspection.json), [build log](unsigned-release-archive.log), [library inventory](unsigned-archive-dylibs.log) and [bounded credential screen](unsigned-archive-file-screen.json) record the evidence:

- Compiled `Info.plist` resolves the display name, bundle identity, version and iPhone/iPad families as expected, and contains Boolean `ITSAppUsesNonExemptEncryption=false`.
- The archived privacy manifest exactly matches reviewed source: no tracking/domains; health and other user content for app functionality; file timestamp `C617.1` and own-app preferences `CA92.1` reasons.
- The source entitlement requests Complete file protection. An unsigned archive cannot establish that signed entitlements are applied or enforced on a physical device.
- All loaded libraries are Apple system/Swift libraries; no third-party frameworks are embedded. Imported cryptography symbols are Apple's CryptoKit AES-GCM, CommonCrypto PBKDF2 and Security random generation. This supports the documented OS-only encryption declaration; it does not classify every government reporting obligation.
- No App Transport Security exception is embedded. Production privacy/support links remain HTTPS; API access is opt-in and privately configured in the app's Keychain.
- Debug `--uitesting`, `--reset` and `--demo` arguments are absent from the Release binary. Public fictional demo remains accessible through ordinary app settings.
- OpenAI-key, Render-secret and private-key-block pattern screens found zero matches in all seven app bundle files. This bounded static screen is not proof of the absence of every possible unknown credential.
- `arm64` executable and dSYM UUIDs match. The archive log contains no `warning:` or `error:` lines.

Final signed archive validation, Apple team/bundle registration, organization approval, public privacy answers, native cloud pipeline, final device/runtime checks and App Review remain separate release gates. A successful archive is build evidence, not submission readiness.

## Final-source rebuild command — Candidate5 executed

The earlier artifact predates the later Workspace/Review recovery guards and subsequent root fixes. Root froze Candidate5 source and authorized the following generic-device archive. It completed successfully at the exact new path and preserved the earlier artifact. Runtime Candidate5 tests remain a separate result; never reuse a prior binary hash/audit as evidence for a changed source.

```sh
CARE_RELEASE_TAG=CareInOneUnsignedReleaseCandidate5
xcodebuild -project CareInOne.xcodeproj -scheme CareInOne -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "/private/tmp/$CARE_RELEASE_TAG" \
  -archivePath "/private/tmp/$CARE_RELEASE_TAG.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive \
  > docs/verification/2026-10-04/release/unsigned-candidate5-archive.log 2>&1
```

The source fingerprint, read-only preflight and independent compiled inspection above are complete. If source changes afterward, explicitly mark Candidate5 as a prior snapshot and repeat those checks at another fresh path.

This remains an unsigned engineering build. When NutriAssist's actual signing team/registered identifier and local identity become available, archive separately with proper signing, inspect signed entitlements/profile, and validate in Organizer. Do not invent a team ID, create a certificate/profile, enable an individual substitute publisher, or infer successful App Store validation from the unsigned command.
