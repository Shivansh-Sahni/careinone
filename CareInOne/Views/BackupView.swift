import SwiftUI
import UniformTypeIdentifiers
import CareCore

struct BackupView: View {
    @Environment(AppStore.self) private var store
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var includeAudio = true
    @State private var importing = false
    @State private var replace = false
    @State private var workflow = BackupWorkflow()
    private enum Entry: Hashable { case passphrase, confirmation }
    @FocusState private var focused: Entry?

    var body: some View {
        Form {
            Section {
                Label("Keep a recoverable copy", systemImage: "lock.doc").font(.headline)
                Text("Your care records do not sync to iCloud. An encrypted backup lets you restore them on another iPhone or after reinstalling. Save the backup somewhere you control.")
                Text("Keep the passphrase separately. There is no password reset or recovery key.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Passphrase") {
                SecureField("At least 12 characters", text: $passphrase)
                    .textContentType(.newPassword).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .focused($focused, equals: .passphrase).accessibilityIdentifier("backup-passphrase")
                Text("Use a long, unique phrase. Encryption and decryption happen on this device.").font(.caption).foregroundStyle(.secondary)
            }.disabled(workflow.busy)
            Section("Create a backup") {
                SecureField("Repeat passphrase", text: $confirmation)
                    .textContentType(.newPassword).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .focused($focused, equals: .confirmation).accessibilityIdentifier("backup-confirmation").disabled(workflow.busy)
                Toggle("Include retained audio", isOn: $includeAudio).disabled(workflow.busy).accessibilityIdentifier("backup-include-audio")
                Text("Includes sources, original files, reviewed care, history, questions, and notes. Attached files must total at most 40 MB. API keys and gateway credentials are never included.").font(.caption).foregroundStyle(.secondary)
                Button("Create encrypted backup") { workflow.create(store: store, passphrase: passphrase, includeAudio: includeAudio) }
                    .disabled(workflow.busy || passphrase.count < 12 || confirmation != passphrase)
                    .accessibilityIdentifier("backup-create")
                if let output = workflow.output {
                    ShareLink("Save or share encrypted backup", item: output).disabled(workflow.busy).accessibilityIdentifier("backup-share")
                }
            }
            Section("Restore a backup") {
                Button("Choose backup file", systemImage: "folder") { importing = true }.disabled(workflow.busy).accessibilityIdentifier("backup-choose")
                if workflow.input != nil {
                    Text(workflow.filename).font(.caption)
                    Button("Unlock and preview") { workflow.unlock(passphrase: passphrase) }
                        .disabled(workflow.busy || passphrase.count < 12).accessibilityIdentifier("backup-unlock")
                }
                if let preview = workflow.preview {
                    Text("Backup created \(preview.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.subheadline)
                    Text("Patient label: \(preview.state.profile.displayName.isEmpty ? "Not provided" : preview.state.profile.displayName)").accessibilityIdentifier("backup-patient")
                    if preview.state.profile.demoLoaded && preview.state.sources.allSatisfy(\.synthetic) { Label("Fictional demo backup", systemImage: "person.crop.circle.badge.questionmark") }
                    Text("\(preview.state.sources.count) sources · \(preview.state.claims.filter(\.canonical).count) reviewed claims · \(preview.files.count) attached files")
                    Text("Restoring replaces the \(store.state.sources.count) sources currently in this care memory. Cloud consent and notifications will be off. Existing app-lock settings stay in place.").font(.caption).foregroundStyle(.secondary)
                    Button("Replace local records with this backup", role: .destructive) { replace = true }.disabled(workflow.busy).accessibilityIdentifier("backup-replace")
                }
            }
            if workflow.busy {
                Section {
                    ProgressView(workflow.activity).accessibilityIdentifier("backup-progress")
                    Button("Cancel operation", role: .cancel) { workflow.cancel() }.accessibilityIdentifier("backup-cancel")
                }
            }
            if let message = workflow.message { Section { Text(message).accessibilityIdentifier("backup-message") } }
        }.navigationTitle("Backup & restore").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar { if focused != nil { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil }.accessibilityIdentifier("backup-keyboard-done") } } }
            .interactiveDismissDisabled(workflow.busy)
            .onChange(of: passphrase) { workflow.invalidateForPassphraseChange() }
            .onChange(of: confirmation) { workflow.invalidateOutput() }
            .onChange(of: includeAudio) { workflow.invalidateOutput() }
            .onChange(of: store.state) { workflow.careChanged() }
            .onDisappear { workflow.cancel(); passphrase = ""; confirmation = "" }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { workflow.load(url) }
                case .failure(let error):
                    let value = error as NSError
                    if value.domain != NSCocoaErrorDomain || value.code != NSUserCancelledError { workflow.message = error.localizedDescription }
                }
            }
            .confirmationDialog("Replace this care memory’s saved records?", isPresented: $replace, titleVisibility: .visible) {
                Button("Restore and replace records", role: .destructive) {
                    workflow.restore(store: store) { passphrase = ""; confirmation = ""; store.notice = "Backup restored. Review your care and preferences before continuing." }
                }
            } message: { Text("Make a backup of current records first if you want to keep them. This does not merge two patient histories.") }
    }
}
