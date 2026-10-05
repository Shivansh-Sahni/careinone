import SwiftUI
import CareCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var profile = Profile()
    @State private var erase = false
    @State private var removeDemo = false
    @State private var export: URL?
    @State private var authenticating = false
    @State private var saving = false
    @State private var resetDemo = false
    var body: some View {
        Form {
            Section("Local profile · all optional") {
                Text(store.isDemoWorkspace ? "This is an isolated fictional practice profile." : "This care memory is for one person. Changing the display name does not start a new patient history. Keep other people’s records separate.").font(.caption).foregroundStyle(.secondary)
                TextField("Display name", text: $profile.displayName).textContentType(.givenName)
                OptionalDateField(title: "Date of birth", date: $profile.birthDate)
                TextField("Emergency / primary contact", text: $profile.contactName)
                TextField("Contact phone", text: $profile.contactPhone).keyboardType(.phonePad)
            }
            Section("Processing & consent") {
                Toggle("Allow cloud analysis", isOn: $profile.cloudConsent).disabled(store.isDemoWorkspace)
                Text("With cloud analysis off, capture, OCR, transcription when available on this device, conservative extraction, review, care memory, and workflows stay local. With it on, source text is sent to your configured backend and its model provider. Audio, photos, and original files are not sent by this app.").font(.caption).foregroundStyle(.secondary)
                Text("Review your model provider’s privacy and retention terms before enabling. The included backend does not store patient content. Provider behavior depends on your deployment.").font(.caption).foregroundStyle(.secondary)
                NavigationLink { CloudConnectionView() } label: { Label("Set up or test cloud connection", systemImage: "network") }
                Text("Model API keys belong only in the backend environment. This device stores its backend access token in Keychain.").font(.caption).foregroundStyle(.secondary)
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
                if let status = store.reminderStatus {
                    Label(status.statusMessage, systemImage: status.warningMessage == nil ? "bell" : "exclamationmark.bell")
                        .font(.caption).foregroundStyle(status.warningMessage == nil ? Color.secondary : Theme.warning)
                        .accessibilityIdentifier("reminder-status")
                    if profile.notifications && !store.isDemoWorkspace {
                        Button("Retry reminder setup") { save() }.accessibilityIdentifier("retry-reminders")
                    }
                }
            }
            Section {
                Button("Save preferences", systemImage: "checkmark") { save() }.buttonStyle(.borderedProminent).disabled(authenticating || saving).accessibilityIdentifier("save-settings")
                if saving { ProgressView("Saving your preferences…") }
            }
            Section("Fictional practice") {
                NavigationLink("Practice text, PDF, photo & FHIR imports") { SampleEvidenceView() }.accessibilityIdentifier("practice-imports")
                if store.isDemoWorkspace {
                    Button("Reset fictional demo", role: .destructive) { resetDemo = true }
                    Text("All practice changes stay in this demo workspace. Use Return to my care at the top to open your personal records.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Explore the fictional demo") { store.openDemo() }.accessibilityIdentifier("open-demo")
                    if store.state.profile.demoLoaded || store.state.sources.contains(where: \.synthetic) { Button("Remove older synthetic examples from my care", role: .destructive) { removeDemo = true } }
                    Text("The demo has its own database and files. It shows a medication discrepancy, follow-through, an upcoming appointment, and result trends without mixing them into your care.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Your data") {
                NavigationLink { BackupView() } label: { Label("Encrypted backup & restore", systemImage: "externaldrive.badge.checkmark") }
                Button("Export care graph as JSON") {
                    export = nil; store.error = nil
                    do { export = try ExportService.graph(store.state) } catch { store.error = error.localizedDescription }
                }
                if let export, FileManager.default.isReadableFile(atPath: export.path) { ShareLink("Share exported graph", item: export) }
                Text("The graph export contains your saved health information and source text. Original binary files and audio are not included. Share it only with recipients you choose.").font(.caption).foregroundStyle(.secondary)
                Button("Rebuild derived care graph") { if store.mutate({ Reconciler.rebuild(&$0) }) { store.refreshNotifications(); store.notice = "Derived views rebuilt from accepted claims." } }
                Button("Delete all local data", role: .destructive) { erase = true }
            }
            Section("About this build") {
                NavigationLink { HelpPrivacyView() } label: { Label("How it works & privacy", systemImage: "questionmark.circle") }
                Text("CareInOne 1.0 · iOS 18+")
                Text("A capture-first continuity tool. It organizes reported information, preserves evidence, and helps you prepare questions. It does not diagnose or determine which conflicting instruction is correct.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Local audit activity · no health content") {
                    ForEach(store.state.audit.sorted { $0.timestamp > $1.timestamp }.prefix(20)) { event in HStack { Text(event.action); Spacer(); Text(event.timestamp.formatted(date: .abbreviated, time: .shortened)) }.font(.caption) }
                }
            }
        }.disabled(saving).navigationTitle("Settings").onAppear { profile = store.state.profile; store.refreshNotifications() }
            .onChange(of: store.state) { _, _ in export = nil }
            .confirmationDialog("Erase every local record?", isPresented: $erase, titleVisibility: .visible) { Button("Permanently delete all local data", role: .destructive) { ExportService.clean(); store.eraseAll(); profile = store.state.profile } } message: { Text("Sources, audio, claims, profile, questions, and local credentials will be removed. This cannot be undone.") }
            .confirmationDialog("Remove demo sources?", isPresented: $removeDemo, titleVisibility: .visible) { Button("Remove synthetic data", role: .destructive) { store.removeDemo(); profile = store.state.profile } }
            .confirmationDialog("Reset the fictional demo?", isPresented: $resetDemo, titleVisibility: .visible) { Button("Reset demo", role: .destructive) { store.resetDemoWorkspace(); profile = store.state.profile } } message: { Text("This removes practice changes and restores the fictional examples. Personal records and saved gateway credentials remain unchanged.") }
    }
    private func save() {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false; authenticating = false }
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
                if profile.notifications && !store.isDemoWorkspace {
                    guard try await ReminderService.requestPermission() else { profile.notifications = false; throw CareError.invalid("Notifications were not allowed. You can enable them in iOS Settings later.") }
                }
                if profile.cloudConsent && !store.state.profile.cloudConsent { profile.cloudConsentAt = Date() }
                if !profile.cloudConsent { profile.cloudConsentAt = nil }
                profile.demoLoaded = store.state.profile.demoLoaded
                if store.saveProfile(profile) { store.notice = "Preferences saved on this device. Reminder status is shown in Settings." }
            } catch { store.error = error.localizedDescription }
        }
    }
}
struct CareBriefView: View {
    @Environment(AppStore.self) private var store
    @State private var pdf: PreparedTextExport?
    private var text: String { BriefBuilder.text(store.state) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CareCard {
                    Label("Your context, ready to carry", systemImage: "doc.richtext").font(.title2.bold())
                    Text("Review before sharing. This brief includes saved health information, unresolved differences, open steps, and questions.").font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink { VisitPacketView() } label: { Label("Choose what to include", systemImage: "checklist") }
                    ShareLink("Share complete text brief", item: text)
                    Button("Create PDF for sharing") {
                        pdf?.discard(); pdf = nil
                        do { pdf = try ExportService.preparedPDF(text, name: "CareInOne-care-brief.pdf") }
                        catch { store.error = error.localizedDescription }
                    }.accessibilityIdentifier("care-brief-pdf")
                    if let pdf, pdf.isAvailable(for: text) { ShareLink("Share Care Brief PDF", item: pdf.url).accessibilityIdentifier("care-brief-share-pdf") }
                }
                Text(text).font(.subheadline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20)
        }.background(Theme.background).navigationTitle("Care Brief").navigationBarTitleDisplayMode(.inline)
            .onChange(of: text) { _, _ in pdf?.discard(); pdf = nil }
    }
}
