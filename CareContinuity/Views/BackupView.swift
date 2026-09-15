import SwiftUI
import UniformTypeIdentifiers
import CareCore

struct BackupView: View {
    @Environment(AppStore.self) private var store
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var includeAudio = true
    @State private var output: URL?
    @State private var importing = false
    @State private var input: Data?
    @State private var filename = ""
    @State private var preview: CareArchive?
    @State private var replace = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Label("Keep a recoverable copy", systemImage: "lock.doc").font(.headline)
                Text("Your care records do not sync to iCloud. An encrypted backup lets you restore them on another iPhone or after reinstalling. Save the backup somewhere you control.")
                Text("Keep the passphrase separately. There is no password reset or recovery key.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Passphrase") {
                SecureField("At least 12 characters", text: $passphrase).textContentType(.newPassword).autocorrectionDisabled().textInputAutocapitalization(.never)
                Text("Use a long, unique phrase. Encryption and decryption happen on this iPhone.").font(.caption).foregroundStyle(.secondary)
            }.disabled(busy)
            Section("Create a backup") {
                SecureField("Repeat passphrase", text: $confirmation).textContentType(.newPassword).autocorrectionDisabled().textInputAutocapitalization(.never).disabled(busy)
                Toggle("Include retained audio", isOn: $includeAudio).disabled(busy)
                Text("Includes sources, original files, reviewed care, history, questions, and notes. Attached files must total at most 40 MB. API keys and gateway credentials are never included.").font(.caption).foregroundStyle(.secondary)
                Button("Create encrypted backup") { create() }.disabled(busy || passphrase.count < 12 || confirmation != passphrase)
                if let output { ShareLink("Save or share encrypted backup", item: output) }
            }
            Section("Restore a backup") {
                Button("Choose backup file", systemImage: "folder") { importing = true }.disabled(busy)
                if input != nil {
                    Text(filename).font(.caption)
                    Button("Unlock and preview") { unlock() }.disabled(busy || passphrase.count < 12)
                }
                if let preview {
                    Text("Backup created \(preview.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.subheadline)
                    Text("\(preview.state.sources.count) sources · \(preview.state.claims.filter(\.canonical).count) reviewed claims · \(preview.files.count) attached files")
                    Text("Restoring replaces the \(store.state.sources.count) sources currently on this iPhone. Cloud consent and notifications will be off. Existing app-lock settings stay in place.").font(.caption).foregroundStyle(.secondary)
                    Button("Replace local records with this backup", role: .destructive) { replace = true }.disabled(busy)
                }
            }
            if busy { Section { ProgressView("Protecting your care information…") } }
            if let message { Section { Text(message).accessibilityIdentifier("backup-message") } }
        }.navigationTitle("Backup & restore").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(busy)
            .onChange(of: passphrase) { preview = nil; output = nil; message = nil }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= ArchiveCodec.maxArchiveBytes else { throw CareError.invalid("This file exceeds the backup size limit.") }
                    input = try ArchiveCodec.readFile(url); filename = url.lastPathComponent; preview = nil; message = nil
                } catch { message = error.localizedDescription }
            }
            .confirmationDialog("Replace this iPhone’s saved care?", isPresented: $replace, titleVisibility: .visible) {
                Button("Restore and replace records", role: .destructive) {
                    guard let preview else { return }
                    do { try store.restore(preview); self.preview = nil; input = nil; passphrase = ""; confirmation = ""; store.notice = "Backup restored. Review your care and preferences before continuing." }
                    catch { message = "Restore did not finish. Your current records remain saved. " + error.localizedDescription }
                }
            } message: { Text("Make a backup of current records first if you want to keep them. This does not merge two patient histories.") }
    }
    private func create() {
        do {
            let snapshot = try store.archive(includeAudio: includeAudio); let secret = passphrase
            busy = true; message = nil; output = nil
            Task {
                defer { busy = false }
                do {
                    let data = try await Task.detached(priority: .userInitiated) { try ArchiveCodec.encrypt(snapshot, passphrase: secret) }.value
                    output = try ExportService.encryptedBackup(data); message = "Encrypted backup ready. Use Save or share to keep a copy outside this app."
                } catch { message = error.localizedDescription }
            }
        } catch { message = error.localizedDescription }
    }
    private func unlock() {
        guard let input else { return }; let secret = passphrase
        busy = true; message = nil; preview = nil
        Task {
            defer { busy = false }
            do { preview = try await Task.detached(priority: .userInitiated) { try ArchiveCodec.decrypt(input, passphrase: secret) }.value }
            catch { message = error.localizedDescription }
        }
    }
}
