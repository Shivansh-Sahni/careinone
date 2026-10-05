import Foundation
import Observation
import CareCore

/// Each operation owns a run identifier. A cancelled or superseded worker cannot
/// publish a preview or share URL after the user leaves this screen.
@MainActor @Observable final class BackupWorkflow {
    private(set) var output: URL?
    private(set) var input: Data?
    private(set) var filename = ""
    private(set) var preview: CareArchive?
    private(set) var busy = false
    private(set) var activity = ""
    var message: String?
    private enum Phase {
        case create, load, unlock, restore
        var title: String {
            switch self {
            case .create: "Creating your encrypted backup…"
            case .load: "Opening your backup file…"
            case .unlock: "Unlocking and checking your backup…"
            case .restore: "Restoring your saved care…"
            }
        }
    }
    private var phase: Phase?
    private var run: UUID?
    private var task: Task<Void, Never>?

    func create(store: AppStore, passphrase: String, includeAudio: Bool) {
        guard !busy else { return }
        output = nil
        perform(.create) { [weak self] id in
            let snapshot = try await store.archiveInBackground(includeAudio: includeAudio)
            try Task.checkCancellation()
            let url = try await Self.background {
                try Task.checkCancellation()
                let data = try ArchiveCodec.encrypt(snapshot, passphrase: passphrase)
                try Task.checkCancellation()
                let url = try ExportService.encryptedBackup(data)
                do { try Task.checkCancellation() }
                catch { try? FileManager.default.removeItem(at: url); throw error }
                return url
            }
            guard let self, self.run == id, !Task.isCancelled else {
                try? FileManager.default.removeItem(at: url); return
            }
            self.output = url
            self.message = "Encrypted backup ready. Use Save or share to keep a copy outside this app."
        }
    }

    func load(_ url: URL) {
        guard !busy else { return }
        // A failed replacement import must never leave the earlier file unlocked.
        input = nil; filename = ""; preview = nil
        perform(.load) { [weak self] id in
            let data = try await Self.background {
                try Task.checkCancellation()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= ArchiveCodec.maxArchiveBytes else { throw CareError.invalid("This file exceeds the backup size limit.") }
                let data = try ArchiveCodec.readFile(url)
                try Task.checkCancellation()
                return data
            }
            guard let self, self.run == id, !Task.isCancelled else { return }
            self.input = data; self.filename = url.lastPathComponent
        }
    }

    func unlock(passphrase: String) {
        guard !busy, let input else { return }
        preview = nil
        perform(.unlock) { [weak self] id in
            let archive = try await Self.background {
                try Task.checkCancellation()
                let archive = try ArchiveCodec.decrypt(input, passphrase: passphrase)
                try Task.checkCancellation()
                return archive
            }
            guard let self, self.run == id, !Task.isCancelled else { return }
            self.preview = archive
            self.message = "Backup unlocked. Check the patient and record counts before replacing local care."
        }
    }

    func restore(store: AppStore, onSuccess: @escaping @MainActor () -> Void) {
        guard !busy, let preview else { return }
        perform(.restore) { [weak self] id in
            try await store.restoreInBackground(preview)
            guard let self, self.run == id, !Task.isCancelled else { return }
            self.preview = nil; self.input = nil; self.filename = ""; self.output = nil
            self.message = "Backup restored. Review your care and preferences before continuing."
            onSuccess()
        }
    }

    func invalidateForPassphraseChange() {
        preview = nil; output = nil; message = nil
    }

    func invalidateOutput() {
        let hadOutput = output != nil
        output = nil
        if hadOutput { message = "Your backup choices or saved care changed. Create a new backup to share the current version." }
    }

    func careChanged() {
        // Restore itself changes care; let that run finish and report its result.
        if busy && phase == .create {
            cancel()
            message = "Your saved care changed while the backup was being made. Create it again to include the latest version."
        }
        invalidateOutput()
    }

    func cancel() {
        guard busy else { return }
        run = nil; task?.cancel(); task = nil; busy = false; activity = ""; phase = nil
        message = "Stopped. Your current care records remain saved."
    }

    private func perform(_ phase: Phase, operation: @escaping @MainActor (UUID) async throws -> Void) {
        guard !busy else { return }
        let id = UUID(); run = id; busy = true; self.phase = phase; self.activity = phase.title; message = nil
        task = Task { [weak self] in
            defer { if let self, self.run == id { self.busy = false; self.activity = ""; self.phase = nil; self.task = nil; self.run = nil } }
            do { try await operation(id) }
            catch is CancellationError { }
            catch {
                guard let self, self.run == id, !Task.isCancelled else { return }
                self.message = phase == .restore ? "Restore did not finish. Your current care records remain saved. " + error.localizedDescription : error.localizedDescription
            }
        }
    }

    private nonisolated static func background<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        let worker = Task.detached(priority: .userInitiated, operation: work)
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: { worker.cancel() }
    }
}
