import SwiftUI
import CareCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var profile = Profile()
    @State private var erase = false
    @State private var removeDemo = false
    @State private var export: URL?
    @State private var authenticating = false
    var body: some View {
        Form {
            Section("Local profile · all optional") {
                TextField("Display name", text: $profile.displayName).textContentType(.givenName)
                OptionalDateField(title: "Date of birth", date: $profile.birthDate)
                TextField("Emergency / primary contact", text: $profile.contactName)
                TextField("Contact phone", text: $profile.contactPhone).keyboardType(.phonePad)
            }
            Section("Processing & consent") {
                Toggle("Allow cloud analysis", isOn: $profile.cloudConsent)
                Text("With cloud analysis off, capture, OCR, transcription when available on this device, conservative extraction, review, care memory, and workflows stay local. With it on, source text is sent to your configured backend and its model provider. Audio, photos, and original files are not sent by this app.").font(.caption).foregroundStyle(.secondary)
                Text("Review your model provider’s privacy and retention terms before enabling. The included backend does not store patient content. Provider behavior depends on your deployment.").font(.caption).foregroundStyle(.secondary)
                NavigationLink { CloudConnectionView() } label: { Label("Set up or test cloud connection", systemImage: "network") }
                Text("Model API keys belong only in the backend environment. This iPhone stores its backend access token in Keychain.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy & recording") {
                Picker("Text recognition language", selection:Binding(get:{ profile.ocrLanguage ?? "" },set:{ profile.ocrLanguage = $0.isEmpty ? nil : $0 })) {
                    Text("Device language").tag(""); Text("Detect automatically").tag("auto")
                    Text("English").tag("en-US"); Text("Español").tag("es-ES"); Text("Français").tag("fr-FR"); Text("Deutsch").tag("de-DE"); Text("Italiano").tag("it-IT"); Text("Português").tag("pt-BR"); Text("中文").tag("zh-Hans")
                }
                Text("Choose the document’s language if scanned abbreviations look wrong. Originals remain available to compare with recognized text.").font(.caption).foregroundStyle(.secondary)
                Toggle("App lock", isOn: $profile.appLock).disabled(authenticating)
                Toggle("Keep audio after successful transcription", isOn: $profile.retainAudio)
                Text("Record only after everyone present agrees. The recording indicator remains visible and recording pauses outside the foreground. Audio is retained temporarily for recovery if transcription fails. Delete it independently from its source.").font(.caption).foregroundStyle(.secondary)
                Text("Local records and evidence use iOS Data Protection and are excluded from device cloud backup. This app does not use iCloud synchronization. An optional app lock adds Face ID, Touch ID, or device passcode access.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Relevant reminders") {
                Toggle("Enable local reminders", isOn: $profile.notifications)
                if profile.notifications { Toggle("Explicit dated follow-through", isOn: $profile.notifyTasks); Toggle("Upcoming appointments", isOn: $profile.notifyAppointments) }
                Text("Only explicit dates generate reminders. Lock-screen notifications contain no clinical details. This is not emergency monitoring.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Save preferences", systemImage: "checkmark") { save() }.buttonStyle(.borderedProminent).disabled(authenticating).accessibilityIdentifier("save-settings")
            }
            Section("Synthetic CAC demo") {
                if store.state.profile.demoLoaded { Button("Remove synthetic demo data", role: .destructive) { removeDemo = true } }
                else { Button("Load synthetic demo") { store.loadDemo(); profile = store.state.profile } }
                Text("Synthetic examples show a medication discrepancy, follow-through, an upcoming appointment, and numeric result trends. Demo sources are visibly labeled.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Your data") {
                NavigationLink { BackupView() } label: { Label("Encrypted backup & restore", systemImage: "externaldrive.badge.checkmark") }
                Button("Export care graph as JSON") { do { export = try ExportService.graph(store.state) } catch { store.error = error.localizedDescription } }
                if let export { ShareLink("Share exported graph", item: export) }
                Text("The graph export contains your saved health information and source text. Original binary files and audio are not included. Share it only with recipients you choose.").font(.caption).foregroundStyle(.secondary)
                Button("Rebuild derived care graph") { if store.mutate({ Reconciler.rebuild(&$0) }) { store.refreshNotifications(); store.notice = "Derived views rebuilt from accepted claims." } }
                Button("Delete all local data", role: .destructive) { erase = true }
            }
            Section("About this build") {
                NavigationLink { HelpPrivacyView() } label: { Label("How it works & privacy", systemImage: "questionmark.circle") }
                Text("CareContinuity 1.0 · iOS 18+")
                Text("A capture-first continuity tool. It organizes reported information, preserves evidence, and helps you prepare questions. It does not diagnose or determine which conflicting instruction is correct.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Local audit activity · no health content") {
                    ForEach(store.state.audit.sorted { $0.timestamp > $1.timestamp }.prefix(20)) { event in HStack { Text(event.action); Spacer(); Text(event.timestamp.formatted(date: .abbreviated, time: .shortened)) }.font(.caption) }
                }
            }
        }.navigationTitle("Settings").onAppear { profile = store.state.profile }
            .confirmationDialog("Erase every local record?", isPresented: $erase, titleVisibility: .visible) { Button("Permanently delete all local data", role: .destructive) { ExportService.clean(); store.eraseAll(); profile = store.state.profile } } message: { Text("Sources, audio, claims, profile, questions, and local credentials will be removed. This cannot be undone.") }
            .confirmationDialog("Remove demo sources?", isPresented: $removeDemo, titleVisibility: .visible) { Button("Remove synthetic data", role: .destructive) { store.removeDemo(); profile = store.state.profile } }
    }
    private func save() {
        Task {
            do {
                if profile.cloudConsent {
                    let credentials = KeychainStore.backend
                    _ = try GatewayClient.validate(endpoint: credentials.endpoint, token: credentials.token)
                    guard profile.cloudProviderConfigurationID != nil else { throw CareError.invalid("Open Cloud connection, check the configured models, and explicitly allow them before enabling cloud analysis.") }
                }
                if profile.appLock && !store.state.profile.appLock {
                    authenticating = true; let allowed = await store.lock.authenticate(); authenticating = false
                    guard allowed else { profile.appLock = false; throw CareError.invalid("App lock requires successful device authentication. Set a device passcode first.") }
                }
                if profile.notifications && !store.state.profile.notifications {
                    guard try await ReminderService.requestPermission() else { profile.notifications = false; throw CareError.invalid("Notifications were not allowed. You can enable them in iOS Settings later.") }
                }
                if profile.cloudConsent && !store.state.profile.cloudConsent { profile.cloudConsentAt = Date() }
                if !profile.cloudConsent { profile.cloudConsentAt = nil }
                profile.demoLoaded = store.state.profile.demoLoaded
                if store.saveProfile(profile) { store.notice = "Preferences saved on this iPhone." }
            } catch { store.error = error.localizedDescription }
        }
    }
}
struct CareBriefView: View {
    @Environment(AppStore.self) private var store
    @State private var pdf: URL?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CareCard {
                    Label("Your context, ready to carry", systemImage: "doc.richtext").font(.title2.bold())
                    Text("Review before sharing. This brief includes saved health information, unresolved differences, open steps, and questions.").font(.subheadline).foregroundStyle(.secondary)
                    ShareLink("Share text brief", item: BriefBuilder.text(store.state))
                    Button("Create PDF for sharing") { do { pdf = try ExportService.briefPDF(store.state) } catch { store.error = error.localizedDescription } }
                    if let pdf { ShareLink("Share Care Brief PDF", item: pdf) }
                }
                Text(BriefBuilder.text(store.state)).font(.subheadline).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20)
        }.background(Theme.background).navigationTitle("Care Brief").navigationBarTitleDisplayMode(.inline)
    }
}
