# Reviewer notes draft

Re-run this path on the exact signed build intended for submission before pasting it into App Store Connect. No patient content or private credential belongs in this file. This is the detailed preparation guide, not a single paste field. Use the separately prepared [Notes text](review-notes-for-paste.en-US.txt) after final verification; it is checked against Apple’s 4,000-byte Notes limit. Private contact and gateway access must be entered separately. [Apple field specification](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

## Current engineering verification — not part of the paste field

[Candidate8](../verification/2026-10-05/continuation/release/CANDIDATE8_RELEASE_VERIFICATION.md) completed145 native passes/one gated paid-cloud skip, minimum-OS24 passes and an unsigned archive audit. Its final whole UI action is29 total/26 passes/two failures/one intended screenshot skip, exit65,16 frame warnings and zero audio-session warnings. The backup keyboard and Loop failures remain explicit; focused recoveries are separate. Source-status/accessibility passed. Six fresh ordinary Release phone pictures passed format/visual/OCR review. Current ordinary Release leaves the fictional Demo on Today and preserves all12 personal record-type payloads and one original fingerprint. These facts do not close valid signing, NutriAssist approval, physical-device checks, operator privacy/support facts or public cloud enrollment. Fresh account inspection still sees Individual only and zero local identities/profiles.

## Notes for Review

CareInOne organizes information a patient or caregiver chooses to capture. There is no required app account or login. Model-generated details are proposals until the user reviews them. The app does not diagnose, prescribe, rank treatment options, verify clinical correctness, or replace a care team.

The app's local capture, review, search, visit preparation, follow-through, and export functions work without cloud analysis. On-device speech transcription may be unavailable for the review device or language; typed notes remain available.

### Start with the fictional demonstration

1. On first launch choose **Explore the fictional demo**. After onboarding, it is available in **Settings → Explore the fictional demo**. A banner identifies the isolated practice workspace; **Return to my care** exits without merging fictional information into personal care. **Settings → Reset fictional demo** resets practice changes only.
2. **Today** identifies recent changes, open follow-through, and reports needing clarification. Demo information is explicitly synthetic.
3. Open **My Care** to inspect reviewed information and supporting sources. Open conflicting reports to see that both reports are preserved rather than silently resolved.
4. On **Today**, open the appointment companion. Save an opening and questions, enter an answer, leave the screen, and return to see the saved conversation context.
5. Open a follow-through item and **Help me get this done**. Edit the prepared message and record outreach or a reply. The app does not automatically send messages or equate outreach with clinical completion.
6. Open **Care Brief → Choose what to include** to prepare a selected visit packet. Use the system share sheet to export the selected text or PDF.
7. In **Settings**, open **Practice text, PDF, photo & FHIR imports** for fictional practice sources. Keep practice changes within the isolated demonstration; its database and original files are separate from personal care.

### Add your own fictional evidence

1. Tap **Add an update**, choose the text input, and paste:
   ```text
   Fictional review example.
   Allergy: penicillin.
   Follow-up: call the clinic tomorrow to arrange an appointment.
   ```
2. Save the source. Open the source and review its proposed details. If you repeat the identical example in the same context, the app reports that it is already saved and closes the capture sheet. Open **Sources → the original evidence → Review & edit** to resume; it preserves the original rather than creating a second copy.
3. Confirm consequential details individually before accepting them into reviewed care.
4. Inspect the original text and accepted detail in Sources/My Care. A reported allergy is not independently medically verified.

### Permissions and privacy

The app requests camera, microphone, speech recognition, notifications, or calendar-write permission only for their corresponding user actions. Selected photo import uses the system picker. Visit recording requires agreement confirmation, shows a recording indicator, and pauses when the app leaves the foreground. Calendar additions and external shares occur only after user action.

The local data is protected by iOS Data Protection. Optional app lock uses Face ID, Touch ID, or device passcode. Encrypted backup is in Settings; its passphrase cannot be recovered. Deletion controls remove local records, while copies a user previously exported remain in their chosen destinations.

### Optional cloud access — finalize one accurate variant

**If cloud is available in the submitted release:** provide a reviewer-specific gateway address and token only in App Store Connect's private review information. Keep that credential active throughout review, with enough bounded quota for verification. Explain the same enrollment/support path available to ordinary users. Reviewer access must not be a substitute for a working public user path.

Reviewer path: first use **Return to my care** if the isolated demonstration is open; cloud setup is intentionally unavailable in fictional practice and does not alter personal credentials or consent. Then open **Settings → Set up or test cloud connection → Check gateway configuration → Test with synthetic text → Allow cloud analysis with these models**. Test extraction using a newly typed fictional source, without real patient information. Source working text, source type, and event date are sent through the disclosed gateway to its displayed model providers; original photos, PDFs, and audio are not uploaded. Provider changes require renewed permission.

**If the release offers local functionality with operator-configured cloud only:** state that limitation plainly in the listing and review notes. Do not market universally available managed AI or instruct reviewers to supply their own OpenAI key. Configure any provided reviewer gateway through private review information.

## Private App Store Connect fields — not populated here

- Review contact name: [verified person authorized to represent NutriAssist]
- Review contact email: [monitored address]
- Review contact phone: [reachable number required by review workflow]
- Reviewer gateway credential, if applicable: [entered privately; never committed]
- Final tested build number and date: [from final verification]

## Submission operator note

The owner intends NutriAssist as publisher and has asked not to substitute the active individual membership. Wait for confirmed organization conversion before submitting under the intended legal entity. This packet does not claim that conversion has completed.
