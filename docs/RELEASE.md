# Release preparation

This packet prepares a TestFlight beta first, followed by public distribution after device and deployment validation. No upload or publication has occurred. Current test results and build evidence are recorded in [IMPLEMENTATION_STATUS.md](../IMPLEMENTATION_STATUS.md).

## Store listing copy

**Name:** CareInOne

**Subtitle:** Your care, connected

**Promotional text:** Save the details of care, see what changed, keep track of open next steps, and bring source-linked context into your next appointment.

**Description:**

Care arrives in conversations, documents, photos, portal messages, and your own notes. CareInOne helps you carry that information forward.

Start with one small update. Speak a recap, type a note, photograph a document, or import a PDF. Keep the original source, review proposed details, and build a personal care memory on your iPhone.

• See what changed across your saved information.
• Track explicit follow-through and upcoming appointments.
• Compare conflicting reports side by side, with their sources.
• Save questions, choose a source-linked visit packet, and share the selected text or PDF for your next appointment.
• Walk into appointments with a short personal opening and your top questions. Follow one question at a time and keep your answers, even when you pause and return later.
• Get a ready-to-edit message when you need to arrange care or ask for an update. Save replies, outreach history, and your own dates to check back.
• Search reviewed claims and original source text.
• Keep an encrypted, passphrase-protected backup under your control.

No complete medical history or EHR connection is required. Local capture, text recognition, review, and care workflows work without a cloud model. Optional cloud extraction uses a separately configured gateway and requires permission for its disclosed providers.

CareInOne organizes reported information. It does not diagnose, recommend treatment, choose between conflicting clinical instructions, or monitor emergencies. Review saved details and clarify care decisions with your treating team.

**Keywords:** care,appointments,records,questions,visits,documents,continuity,follow-up

## App Review notes

The app is a patient-owned evidence and continuity tool. No login is required. Onboarding offers a clearly labeled synthetic demo that reviewers can load and remove. The home screen is Today, not a chatbot. A useful offline review path is Add → Type/Paste → enter “Allergy: penicillin” → save → review → confirm reported information → accept → My Care → Allergies.

The synthetic demo shows conflicting medication reports, source history, explicit follow-through, and numeric results. Clarifying a discrepancy preserves both reports. Model proposals never directly update the care graph.

Today → Get ready for my visit opens the appointment companion. Its opening brief can be read aloud or shared as text/PDF; the visit screen preserves answers and question position. Saving answers creates patient-reported evidence that still requires review. Follow-through → Help me get this done opens an editable clinic message, personal check-back date, outreach history and reply draft. No message is sent automatically, and recording outreach does not mark care complete. These workflows are local and need no API key.

Cloud extraction is optional and off until explicit permission. Configure a reviewer-specific gateway token through App Store Connect’s private review information if cloud functionality is included in the release. Do not put that token in this file or public metadata. The connection screen shows primary/fallback hosts and models and offers a synthetic connectivity test. The gateway has no patient-content database.

Visit recording requires a per-recording agreement confirmation and system microphone permission. A visible indicator remains present while recording. Recordings pause outside the foreground. Speech transcription uses the on-device requirement and may be unavailable for a device/language.

## Evidence required before uploading

- [x] Xcode 27 license accepted; native integration/UI tests and unsigned device Release builds verified. See the dated summaries in [IMPLEMENTATION_STATUS.md](../IMPLEMENTATION_STATUS.md).
- [ ] Configure signing team and final unique bundle identifier; archive the Release target and validate it in Xcode Organizer.
- [ ] Complete the physical-iPhone checklist in `VALIDATION.md`, including real microphone/camera, VoiceOver, lock/app-switcher, notifications, deletion, and backup restore after reinstall.
- [ ] Validate the chosen live primary/fallback models with synthetic cases, cancellation, quota exhaustion, consent changes, and unavailable network. Record model IDs and dates.
- [ ] Provide real publisher identity, support contact, public privacy/support URLs, countries, age-rating answers, and actual deployment-specific privacy disclosures. The in-app privacy explanation is already implemented; a public policy must describe the actual operator and providers.
- [ ] Decide whether custom gateway setup is appropriate for this beta audience. Public consumer cloud service needs installation-specific credential enrollment and operational support; the current model is operator-configured tokens, not self-service account enrollment.
- [ ] Capture screenshots of the final build on the actual submission device sizes, using only synthetic data. Dated verification screenshots document their specific builds; use only the matching current build for the store listing.
- [ ] Verify external policy/support URLs and all text in the App Store Connect preview. Supply a live reviewer gateway only if cloud analysis is advertised as available for that release.

Apple requires accurate metadata, functional review access, and disclosure/permission for third-party data sharing, including AI. This checklist and code are preparation, not a guarantee of App Review approval. Reference: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), checked September 15, 2026.

## Backup validation

Settings → Encrypted backup & restore creates an authenticated AES-256-GCM archive with a random salt and nonce. PBKDF2-HMAC-SHA256 uses 600,000 iterations. All metadata and attached file contents are inside the encrypted payload. Provider keys and Keychain credentials are absent. A long unique passphrase is essential and cannot be recovered.

The current bounded implementation supports 40 MB of original/audio attachments and at most 80 MB of encoded plaintext. Audio can be explicitly excluded; original documents are never silently omitted. Restore previews source/claim/file counts, requires replacement confirmation, stages new files, and commits the graph only after staging succeeds. A failed save preserves the prior state and files. Cloud consent and reminders are disabled on restore; the current device’s app-lock setting is retained.
