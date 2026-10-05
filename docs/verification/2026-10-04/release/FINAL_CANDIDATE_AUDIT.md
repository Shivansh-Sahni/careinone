# Final candidate source and Git audit

Read-only audit after the frozen Candidate5 production archive, while final UI/assets/deployment work remains pending. This audit did not build, run native tests, operate a simulator, stage files, commit, sign, upload or deploy. The only authorized tooling repair moved the macOS-dependent release preflight to the macOS CI job.

## Compatibility and release membership

- Public product/source folder/project/target/scheme/listing names are CareInOne. Bundle `org.carecontinuity.app`, Swift module `CareContinuity`, Application Support folder, `CareContinuity.store`, Keychain service and encrypted archive format/AAD identifiers retain their original bytes. Existing SwiftData model names and preference schema remain compatible; this is not a fresh patient sandbox or a destructive migration. [Compatibility record](../../../BRAND_COMPATIBILITY.md)
- All **66 app/Core/resource/Package fingerprint paths**, including ignored macOS .DS_Store metadata, compared with the frozen Candidate5 archive source fingerprint still match in the working tree. The final staged comparison below covers the 65 actual production inputs. The project/tooling additions for a UI-only Release screenshot scheme are outside that production-file comparison; they do not establish a new runtime result.
- Static project membership includes all **35 app source files, 14 integration sources and nine UI sources**, with no missing source-phase members. Core sources are included through the local `CareCore` package. The ordinary scheme retains both test targets; the separate screenshot plan selects only its Release UI capture case to avoid building `@testable` native integration against a non-testable Release app.
- Debug reset/UI-test/demo launch handling remains guarded by `#if DEBUG`; the prior compiled archive audit found those switches absent from Release. Public fictional practice remains an ordinary user route, not a Debug-only advertised feature. Unvalidated automatic Mac/Vision compatibility is disabled in current project settings. No app signing team is invented.

The compiled archive, immutable source fingerprints and exact compatibility identifiers are recorded in [the unsigned audit](UNSIGNED_RELEASE_ARCHIVE.md) and [machine-readable source/Git screen](final-candidate-readonly-audit.json). Compilation/reachability is never substituted for screen-level runtime evidence.

## Data and public descriptions

Current source and listing describe local saved care/evidence, explicit sharing, isolated fictional practice and optional operator-configured cloud. Working source text/type/event date can be transmitted after consent; original photos/PDFs/audio remain local. OpenAI store:false is qualified separately from standard abuse-monitoring retention. Care/evidence backup exclusion is distinguished from preferences, including opaque Calendar export receipts, that may enter device backups. External Calendar/share copies are user-managed.

The manifest contains no tracking/domains, linked Health/Other User Content for app functionality, FileTimestamp C617.1 and own-app UserDefaults CA92.1. Actual App Privacy answers/operator retention remain owner gates. The listing does not claim autonomous clinic delivery, universal public cloud enrollment, live hospital integration, complete medical correctness, comparative superiority or clinical validation. Private reviewer/contact placeholders stay in drafts and must be resolved outside public commits where credentials are involved.

## Git and artifact scope

At the recorded audit, Git HEAD was `9f5e88bf9e6bc7c8b743a6c69249e48c23bc13b9`; the index was empty. Root owns final staging. Old tracked CareContinuity paths are deleted while their CareInOne replacements, tests and migration documentation are untracked: **stage the replacement tree and old deletions together**, not just one side of the rename. The recorded candidate path list is a point-in-time review aid, not a command to stage every file blindly.

The Git-eligible inventory contained 414 existing files and 346 untracked paths. No filename candidate for a certificate/private key/provisioning profile/database/IPA/environment credential file or raw archive/result bundle was found. The bounded text screen found seven intentionally marked test-fixture credential patterns in two security-test sources, and none outside test sources; it does not prove the absence of every possible unknown credential. No matching values are recorded.

Picture/binary scope at that snapshot: one app icon, four provisional App Store screenshots and 41 historical/focused evidence images. Final screenshot count/provenance/visual approval remains root-owned and pending. Image pixels were not interpreted by this Git screen. Historical diagnostic pictures are evidence, not final store assets. Raw `.xcresult`, diagnostic/logarchive directories and the durable `artifacts/` archive are ignored by Git. The [durable archive comparison](unsigned-candidate5-durable-copy-check.json) verifies the local copy, which remains unsigned and not uploadable.

`git diff --check` and cached whitespace checks passed at inspection. These are formatting/index checks, not application tests or remote CI execution.

## CI portability repair

The gateway job runs Ubuntu, whereas release_preflight parses the Xcode project with Apple's `plutil -convert json`. Running that step in Ubuntu would fail due to a macOS tool dependency. The preflight step now runs once in the `core` job on `macos-latest`; Ubuntu backend tests/HTTP smoke and macOS native tests remain intact. The workflow was parsed with Ruby Psych and job/step assertions passed; [static result](ci-workflow-static-check.json). Current read-only release_preflight passed source membership, compatible identity, Boolean encryption declaration, manifest and all six actual listing field limits. No GitHub Actions run is claimed until the parent pushes and observes it.

## Gates unchanged

Final whole-device Candidate6 UI, authentic final phone/iPad captures, exact deployed revision/current public-page bytes and actual upgrade fingerprints require direct final evidence. Native real-cloud verification remains blocked at a missing private Keychain gateway pair; real server extraction is a separate success. Public self-service cloud enrollment is absent and must not be marketed as available. Physical camera/audio/Speech, Calendar/notifications, authentication/Data Protection, accessibility and external sharing remain device checks.

NutriAssist organization/team approval, correct app record/rights holder, signing/provisioning/Organizer validation, operator/privacy/support handling and App Store answers remain publication actions. The [release handoff](RELEASE_HANDOFF.md) maps the concrete artifacts and remaining steps. No submission-ready or App Review approval claim is made.


## Final staged snapshot, October 5 at 04:56 UTC

The later [staged audit](final-staged-candidate-audit.json) inspected 385 staged change entries /374 nondeleted staged files, totaling 25,743,552 bytes, without changing the index. The CareInOne replacement tree and old CareContinuity deletions are present together, with no old app paths remaining in the index. All 65 actual app/Core/resource/Package production inputs match the frozen Candidate5 archive in both staged and working content; screenshot project/scheme tooling and ignored macOS .DS_Store metadata are excluded from this production comparison. The original 68-file archive fingerprint is retained separately. Current public HTML staged bytes also match reviewed source.

No credential/environment, private certificate/profile, patient database, IPA, raw archive/result bundle or durable artifacts path is staged. The bounded staged-text pattern screen found one deliberately marked credential fixture in the cloud-safety test and no matches outside fixtures. It did not parse binary images. The earlier separate Vision OCR screen processed all 47 Git-eligible images with zero recognized credential-pattern flags and zero request failures at its recorded snapshot; final replacement/additional images still need a later screen after root finishes capture. Neither screen is a universal absence proof.

At this snapshot, seven already-staged files differed from their working content: two UI test sources, two phone screenshots, the still-running SE action log, the control inventory and the image audit JSON. Subsequent release-document updates and final test summaries must also be included in root’s final deliberate restage. A changing live log is not a finalized result. Root owns that final batch and all commits.

All 24 release/App Store Markdown files had valid local links. The final cached whitespace check exited 2, with 1,018 diagnostics: captured diagnostic/build/test logs contained trailing whitespace and EOF blank lines; the only non-log diagnostic was a trailing blank line in the control inventory. Source/tooling code had no reported whitespace diagnostic. The earlier passing empty-index check remains historical and is not applied to this staged batch. Log evidence has not been rewritten or stripped.

Current main-device Candidate6 and final SE UI results, exact full-workflow reruns, final authentic phone/iPad captures, root deployment/public-byte verification and upgrade fingerprints remain pending direct final artifacts. The handoff and feature ledger retain the native-cloud, physical-device, signing and NutriAssist approval gates.


## Later final-source correction pending separate proof

**Final-source exceptions, October 5:** root authorized two narrow production repairs after minimum-OS runtime failures: full rectangular hit-area behavior in ConflictsView (FollowThroughViews.swift), and native keyboard Done/focus dismissal in VisitDebrief (VisitWorkspaceView.swift). Candidate5 archive/native and the running Candidate6 UI action compiled the earlier app snapshot. The preserved Candidate5 archive remains evidence for that snapshot, but is no longer the final exact app candidate. Candidate7 unsigned archive/source inspection and ordinary native execution are completed separately (129 total, 128 passed, one explicit live-cloud skip, zero failures); scoped whole-workflow UI reruns remain separate, with no pending runtime result inferred in advance. The staged/source matches above are timestamped before this authorized exception and are not applied to later content. Root owns the exact later source hashes and final-stage audit. Current Candidate6 working-text-clear cursor fixture failure and historical full actions remain visible until exact finalized summaries/reruns are attached.


## Latest compiled Candidate7 artifact verified

The parent confirmed actual generic unsigned archive exit 0. Independent [C7 inspection](unsigned-candidate7-archive-inspection.json) and [durable copy](unsigned-candidate7-durable-copy-check.json) now cover the actual two-repair app snapshot: 64 before/after app source/resource hashes unchanged, Package baseline unchanged, compatible identity/version/manifest/OS-only crypto/dependencies/dSYM inspected, no archive-log warning/error lines and zero recognized compiled credential-prefix flags. All 11 regular archive files /24,457,543 bytes match the ignored durable artifact. The archive remains unsigned and not uploadable; native/UI/cloud/device/legal gates stay separate. No source, signing, simulator or service mutation was performed by this archive audit; only the authorized durable artifact copy and evidence files were written.
