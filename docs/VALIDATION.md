# Validation record and release checklist

**September 15 update:** 59 core tests and 50 gateway tests pass. Xcode 27 now passes all 17 integration and 3 UI tests on iOS 18.4, including backup restore and consent/credential boundaries, plus an unsigned iPhone Release build. Current evidence is in [verification/2026-09-15](verification/2026-09-15/README.md); the older native results below apply to the September 7 baseline. See [RELEASE.md](RELEASE.md) for the current submission packet and remaining checks.

All clinical examples used by automated tests and the demo are synthetic.

## Automated checks

| Check | Evidence / command | Current result |
|---|---|---|
| Swift core | `swift test` | 50 tests passing; medication dimensions, source/proposal validation, FHIR statuses and result links, all loop families, chronology, supersession, deletion, priorities/reminders, grounded workflows |
| Backend schema/security | `python3 -m unittest discover -s backend/tests -v` | 30 tests passing |
| Actual HTTP gateway | `.venv/bin/python scripts/backend_smoke.py` | Passing: health, authenticated extraction, no-store, Swift wire fixture |
| Xcode simulator build | Xcode 26.6 / iOS 26.5 SDK | Passing. Matching runtime installed after resolving initial missing-component issue |
| iPhone Release build | `xcodebuild ... -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | Passing unsigned device build; signing/install require your team/device |
| Native integration | `CareContinuityIntegrationTests` | 14 passing: SwiftData roundtrip, offline review/deletion, duplicates, audio deletion, source versions, failed transactions, interruption recovery, cancellation races, consent revocation, transcript recovery, Keychain update/deletion, vault traversal, PDF export, image/PDF OCR |
| UI workflows | `CareContinuityUITests` | 3 passing: demo navigation/provenance, one-input capture/review/persistence after relaunch, discrepancy clarification/reopening |
| iOS 18.4 | iPhone 16 Pro simulator | Final combined run: **17/17 pass**. Initial Vision Latin/Cyrillic lookalike failure corrected with independent Latin recognition fallback |
| Dark mode / Dynamic Type | iPhone 17 Pro, accessibility-extra-large | **14/14 pass** (navigation plus native integration suite before the added Keychain test). Summary cards and claim badges adapt vertically; visual evidence saved in `verification/` |

Durable test outputs, machine-readable native summaries, and synthetic screenshots are in [verification](verification/). Full build logs and `.xcresult` bundles were also retained under `/private/tmp` during development. CI configuration is checked in; no remote CI run or deployment is claimed.

## Failures found and corrected

- Xcode’s installed SDK initially lacked its matching simulator runtime; installed and booted iOS 26.5.
- Simulator architecture mismatch in the generated project; Debug now builds the active architecture consistently with its local Swift package.
- Allergy category pluralization; fixed the real category label.
- UI automation originally tapped the confirmation label, leaving the native switch off; it now targets the actual switch and asserts that acceptance becomes enabled and completes before relaunch.
- Cancelled extraction could race a replacement run; per-source generation checks and regression tests now prevent stale writes.
- Appointment reminders could include superseded evidence or substitute source event dates; shared appointment selection and a deterministic reminder planner now exclude those cases.
- Source deletion could remove unrelated empty encounters; deletion is now scoped to the affected encounter.
- FHIR nonactive statuses and generic service categories could be overinterpreted; conservative status/category review and fixture tests now cover them.
- iOS 18 Vision returned Cyrillic lookalikes for Latin “CBC” even with English hints. The independent fast Latin recognizer handles that observed case. A language preference is available; automatic detection remains optional. OCR remains fallible and originals/review remain essential.
- Dark accessibility text exposed cramped horizontal cards; summaries/badges now adapt to vertical layouts.

## Physical iPhone validation still required

1. Open the Xcode project, choose a unique bundle ID/development team, select a connected iPhone on iOS 18+, enable Developer Mode, build/install/launch. Confirm the native app opens without cloud settings.
2. Deny microphone permission and verify typed capture remains usable. Then grant access. For Record Visit, verify recording is disabled until the everyone-agreed toggle is enabled. Start, pause, resume, stop, and confirm the fixed recording banner and elapsed indicator.
3. Trigger a phone/audio interruption, lock the device, background the app, connect/disconnect Bluetooth/headphones, and confirm recording pauses and never continues silently. Force-quit during recording; reopen the saved audio draft and retry transcription or add a typed recap.
4. Test on-device Speech in supported and unsupported device/language combinations. Disable the network. Verify no remote Speech fallback occurs. Verify editable transcripts, supported transcript timestamps, default audio deletion after successful transcript persistence, optional retention, playback, and independent deletion.
5. Capture a photo of a synthetic medication label. Import a screenshot, native-text PDF, scanned PDF, UTF-8 and UTF-16 file, and the synthetic FHIR fixture. Check exact quotes/pages against the original. Import the same bytes again and verify only one source/file exists.
6. From Files/another app’s Open In flow, open supported evidence in CareContinuity. Check security-scoped access and preservation when extraction fails. A separate share extension is not part of this build.
7. Turn on device authentication, background/reopen, cancel authentication, and use device-passcode fallback. Inspect app-switcher snapshots. Verify evidence/database files have complete protection and are excluded from backup; confirm locked-device file reads are unavailable.
8. Review each medication/allergy/instruction individually. Reject, edit numeric values/units/action/date, mark historical/uncertain/not-about-me, and choose a weak association. Verify related views update together and no provider discrepancy disappears merely because a patient reports what they take.
9. Create exact/approximate/unknown follow-through dates. Allow notifications and inspect generic lock-screen content. Edit/dismiss/complete/delete source and ensure pending reminders reconcile. Verify approximate dates never schedule exact reminders or claim overdue status.
10. Add a date-only appointment and a timed appointment to Calendar using explicit user actions. Confirm date-only events are all-day and the app requests write-only access. Check time zones/DST and the displayed duration before relying on an exported event.
11. Generate/share a Care Brief PDF and text. Inspect long multi-page content, synthetic labels, both conflicting doses, open loops, and source references. Export graph JSON and confirm the UI accurately states that attachments are excluded.
12. Delete one source with claims, a conflict, and a loop; verify every derived view rebuilds. Independently delete audio. Remove synthetic demo data while preserving real sources. Delete all local data and confirm protected originals, credentials, notifications, and exports are removed.
13. Test VoiceOver, maximum accessibility text size, bold text, increased contrast, reduced motion, dark mode, landscape, small iPhones, and iPad. Confirm all review fields and actions remain reachable and quotes are readable.

## Live backend validation still required

Deploy the stateless gateway behind TLS with production logging disabled and chosen provider retention settings. Issue a separate random backend token to the installation. Enter the HTTPS endpoint/token and explicitly enable cloud analysis. Use a synthetic source first. Verify primary extraction, invalid-output rejection, fallback provider, timeout, offline retry/local fallback, cloud-consent revocation, and deletion during processing. Confirm no patient text appears in gateway/proxy/provider traces beyond the agreed processing/retention configuration.

No provider credentials, signing identity, or physical iPhone were supplied in this task. Those are configuration/validation steps, not reasons to substitute fake success states in the application.
