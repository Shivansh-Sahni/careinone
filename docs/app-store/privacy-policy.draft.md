# CareInOne Privacy Policy — publication draft

**Publication status:** This draft is based on the source tree inspected October 4, 2026. Complete the fields below, confirm the final deployed providers and retention, and remove this notice before publication. Do not publish unresolved bracketed fields.

- Operator's verified legal name: [NutriAssist's exact legal entity name]
- Privacy contact: [monitored privacy email or contact route]
- Prepared public support page: https://careinone-api.onrender.com/support (live source match verified October 4)
- Prepared public privacy page: https://careinone-api.onrender.com/privacy (live source match verified October 4)
- Effective date: [date this policy actually becomes effective]
- Deployment-specific provider/hosting details requiring confirmation: [Render service operator, infrastructure log retention, OpenAI organization/project retention controls, any fallback provider]. The current gateway region is Ohio (US East), verified by the root task in Render settings October 4; this does not establish all provider processing locations.

## Your information and your choices

CareInOne helps you organize information you choose to save about care. You can use local capture, text recognition, review, search, appointment preparation, and follow-through without enabling cloud analysis. No app account is required in the current build.

The app is free. It contains no advertising, tracking SDK, subscription, or in-app purchase. We do not sell your care information or use it for advertising.

## Information saved on your device

CareInOne saves your optional profile, captured source text and original files, recordings you retain, reviewed care details, questions, notes, appointment companions, follow-through plans, selected handoff copies, and a limited local history of app operations. The local operation history contains operation names, times, and counts rather than clinical text.

These records are stored in the app's protected local storage. iOS Data Protection protects files using the device's security features. An optional app lock requires device authentication. CareInOne covers its contents when the app becomes inactive.

The current build does not synchronize care records through iCloud or CloudKit. Care records and original evidence files are excluded from device backup. App preferences, including opaque Calendar export receipts, may be included in device backup. You should create and keep an encrypted backup if you want a recoverable copy of your care after reinstalling or moving devices. Device protection is not a promise that a compromised or unlocked device cannot be accessed.

## Photos, documents, audio, and permissions

You choose the photos and files to import. The app uses Apple's selected-item photo picker rather than requiring access to your entire photo library. Camera access is used only when you choose to capture a document or image.

Microphone access is used when you choose to record. Visit recording requires confirmation that people present have agreed. Recording remains visible and pauses outside the foreground. Speech transcription requires permission and is requested on device; availability depends on device and language. CareInOne does not use a cloud transcription service in this build.

You can choose whether to keep audio after successful transcription. A recording may remain locally available for recovery if transcription fails. You can delete audio separately from its source.

Notifications are local and display a generic reminder without clinical labels or patient names. Calendar write access is requested only when you choose to add a reviewed appointment; CareInOne cannot read existing events. Your calendar service may synchronize the new event separately. The app keeps opaque hashed export receipts in local preferences to prevent repeated additions after a relaunch. These preferences contain no patient names, quotations, medical dates, or calendar event identifiers. Another copy requires explicit confirmation. Edits or deletion in CareInOne do not update or remove external Calendar copies. Fictional practice does not write to your personal calendar.

## Optional cloud analysis

Cloud analysis is off until you enable it for the provider configuration displayed in the app. When you request cloud analysis, CareInOne sends the source's working text, source type, and event date, if provided, over HTTPS to the configured gateway. The gateway sends that text to its displayed primary model provider and may use a displayed fallback provider if configured. The app's cloud-analysis request does not upload the original photo, PDF, other binary attachment, or recording.

Working text can itself contain health information, names, or other personal details. Review what you are sending. The model proposes structured information, and the app validates supporting quotations and asks you to review proposals before they become reviewed care.

The supplied gateway processes patient text for the request and has no patient-content database or saved file repository. Application request-access logging is disabled. Its application errors are designed not to contain source text, model output, or secrets. The gateway does not intentionally retain source text or output after processing completes. Cancelling a request may not stop a provider request already transmitted. The hosting and model services can have separate operational logs and retention. Changing the displayed providers requires renewed permission before more patient content is sent.

For the intended OpenAI deployment, requests use Chat Completions with `store: false`. OpenAI's standard API abuse monitoring can retain content for up to 30 days, with exceptions described in its current data-control terms. Disabling stored completions does not, by itself, mean Zero Data Retention. This draft does not claim the CareInOne operator has obtained Zero Data Retention. [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data)

The current included Render gateway is configured in Ohio (US East), as inspected October 4, 2026. Its infrastructure-log retention has not been established by this audit. **Before publication, confirm the operator, infrastructure-log handling, and final provider-specific controls.** If other gateways or fallback providers are offered, name their operators, explain their retention, and link their applicable policies here. An arbitrary host/model identifier is not a complete legal privacy disclosure.

A synthetic connection test sends a fixed invented sentence rather than your saved patient information. Network services necessarily receive connection information to process a request; confirm whether your deployment retains that information and for how long before publishing this policy.

Gateway credentials are kept in the device Keychain. Model-provider API keys belong only on the server. Do not submit provider keys as patient text or include them in screenshots.

## Sharing, exports, and backups

You decide what to share through the system share sheet. A text or PDF care brief, selected visit packet, or graph export can contain health information. A graph JSON export includes saved source text but not original binary files or audio. Recipients and storage services you select control their own copies.

Encrypted backup includes the saved care data and original files within the supported size limits, with optional inclusion of retained audio. Encryption and decryption occur on the device. The passphrase is not included in the backup, cannot be recovered by the operator, and should be kept separately. Gateway credentials are not included.

Restore previews a backup and replaces the active local records after confirmation; it does not silently merge patient histories. Back up existing records before replacement. Restored records require renewed cloud permission. The fictional demo uses a separate local database and evidence directory. Demo changes do not merge into personal care; use its top control to return to your care.

## Deletion and withdrawal

You can disable cloud analysis in Settings and save the preference to stop future patient-content analysis requests. A request already sent may complete under the provider's processing and retention rules; disabling analysis or deleting local information does not recall previously transmitted content.

Deleting a source removes its linked care information and rebuilds derived views. Copied handoffs that included the source are invalidated so their outgoing quoted copy is not retained. You can also delete individual audio files or use **Delete all local data** to remove local records and gateway credentials.

These actions do not remove copies you previously shared, saved to Files, exported as backups, or added to a calendar. Remove those copies in their destinations. Provider-retained content and support correspondence follow their separately disclosed retention and deletion processes.

For privacy questions, withdrawal questions, or deletion requests concerning information held by the operator, contact [monitored privacy contact]. The operator cannot recover local care files or a forgotten backup passphrase.

The verified public NutriAssist general inquiry address is [shivika@nutriassist.org](mailto:shivika@nutriassist.org), also listed on [NutriAssist's contact page](https://nutriassist.org/contact/). Confirm CareInOne-specific monitoring and privacy responsibility before turning this draft into the final policy. No response time is promised. Do not email health records, recordings, credentials, or backup passphrases.

## Support correspondence

If you contact support, we receive the message and information you choose to include. Send a brief technical description and redact patient details and credentials. Support is not a care service or an emergency channel.

**Before publication, specify the support-mail provider, authorized recipients, retention period, and deletion-request handling.** Do not promise a response time or deletion deadline that has not been established.

## Children and people whose care you help manage

CareInOne is not marketed as a Kids Category app. Only save or share another person's information when you are authorized to do so. The final operator must confirm the intended age audience, consent arrangements, and child-data practices before release; a store age rating is not a substitute for those decisions.

## Policy updates and contact

The policy and its effective date will be updated when the app's data handling changes. [Verified legal operator] is responsible for this policy. Contact [monitored privacy contact] for questions.
