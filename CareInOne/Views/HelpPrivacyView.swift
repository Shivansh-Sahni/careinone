import SwiftUI

struct HelpPrivacyView: View {
    var body: some View {
        List {
            Section("Start with one small update") {
                Text("Tap Add and choose the easiest input: speak, type, take a photo, or import a file. You do not need to enter your complete medical history.")
                Text("The original becomes a source. Review proposed claims, especially medications, allergies, and instructions. Accepting a claim confirms what was reported; it does not verify medical correctness.")
            }
            Section("Understand your saved care") {
                Text("Today brings together recent changes, open follow-through, conflicting reports, and upcoming appointments. My Care groups reviewed claims while keeping their source history.")
                Text("Conflicting reports stay side by side. You can save a clarification question or record what your care team clarified. The app does not choose which clinical instruction is correct.")
                Text("No completion has been added here means this app has no completion record. It does not mean the care never happened.")
            }
            Section("Prepare and share") {
                Text("Use Visits to group an encounter’s sources and questions. Prepare and Care Brief bring saved context together for an appointment. Review the brief before sharing it.")
                Text("Ask finds matching reviewed claims from your saved care. Search also finds original source text, questions, notes, and providers. Neither provides diagnosis or treatment advice.")
            }
            Section("What stays on this device") {
                Text("Care connections traces saved evidence and separates medical dates from when records were added. Leaving sources out is a temporary information preview; nothing is deleted and no treatment is simulated.")
                Text("Tracked handoffs preserve an exact selected copy and flag later changes in reviewed information. Sharing and finishing are recorded only by your report. Reply drafts stay local until you save them as evidence; extracted claims still need review.")
                Text("Your profile, sources, recordings, reviewed claims, notes, questions, and care graph are stored locally with iOS Data Protection. An optional app lock uses device authentication. The app covers its screen when inactive.")
                Text("There is no account, advertising SDK, tracking SDK, or iCloud synchronization in this build. Care records and original evidence files are excluded from device cloud backup. App preferences, including opaque calendar export receipts, may be included in a device backup. Create an encrypted backup if you want a recoverable copy of your care.")
                NavigationLink { BackupView() } label: { Label("Encrypted backup & restore", systemImage: "lock.doc") }
            }
            Section("Optional cloud processing") {
                Text("Cloud analysis is off until you allow it. When enabled, source working text, source type, and its event date are sent through your HTTPS gateway to a disclosed model provider. The app does not upload original photos, PDFs, or audio.")
                Text("The included gateway does not persist patient content. Hosting infrastructure and model providers have their own retention practices. Review those practices before enabling analysis. The connection screen identifies both primary and fallback model recipients.")
                Text("A synthetic connection test sends only a fixed invented sentence. Changing the model configuration requires renewed consent for patient-content processing.")
                NavigationLink { CloudConnectionView() } label: { Label("Review cloud connection", systemImage: "network") }
            }
            Section("Recording and permissions") {
                Text("Record a visit only after everyone present agrees. Recording has a visible indicator, pause and stop controls, and pauses outside the foreground. On-device transcription depends on device and language support.")
                Text("Photos and files are selected by you. Calendar additions and local reminders require your explicit action and system permission. Notification text excludes clinical details.")
            }
            Section("Delete or move your data") {
                Text("Delete a source to remove its linked claims and rebuild derived care. Delete audio independently to keep its transcript. Delete all local data in Settings removes local records and gateway credentials.")
                Text("Source deletion also removes copied checkpoint evidence and invalidates any handoff copy that included that source. The whole outgoing copy is removed to avoid retaining its quotes. Comparison coverage is then incomplete. Locally prepared export files are cleared; copies you shared elsewhere are not recalled.")
                Text("Files you already shared or saved outside the app are separate copies. Delete those copies in their destination if you no longer want them. Backup passphrases cannot be recovered by this app.")
            }
            Section("If something does not work") {
                Text("A failed analysis keeps the source. Open it in Sources to retry, use local analysis, or enter a structured claim manually. Compare OCR and transcript text with the original before accepting consequential information.")
                Text("This build organizes your saved reports. It is not an emergency service, a diagnosis engine, or a medication advisor. Bring conflicting or unclear instructions to your treating care team.")
            }
            Section("Privacy policy & support") {
                Link("Read the privacy policy", destination: URL(string: "https://careinone-api.onrender.com/privacy")!)
                    .accessibilityIdentifier("privacy-policy-link")
                Link("CareInOne support", destination: URL(string: "https://careinone-api.onrender.com/support")!)
                    .accessibilityIdentifier("support-link")
                Text("These public pages explain local storage, optional model processing, deletion, and how to contact the project. No patient information is included in these links.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Help & privacy").navigationBarTitleDisplayMode(.inline)
    }
}
