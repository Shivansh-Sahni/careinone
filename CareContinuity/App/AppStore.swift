import Foundation
import Observation
import CareCore
import OSLog

@MainActor @Observable final class AppStore {
    private(set) var state: CareState
    var error: String?
    var notice: String?
    var showAdd = false
    var captureMode: CaptureMode = .text
    var selectedTab = 0
    var importedURL: URL?
    let vault: EvidenceVault
    private let repository: any CareRepository
    private let extractionProvider: (any ExtractionProvider)?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var runs: [UUID: UUID] = [:]
    private let logger = Logger(subsystem: "org.carecontinuity.app", category: "storage")
    let lock = AppLock()
    init(repository: any CareRepository, vault: EvidenceVault, extractionProvider: (any ExtractionProvider)? = nil) throws {
        self.repository = repository; self.vault = vault; self.extractionProvider = extractionProvider; state = try repository.load()
        for i in state.sources.indices where state.sources[i].state == .processing {
            state.sources[i].state = .pending; state.sources[i].processingMessage = "Processing was interrupted. Your evidence is saved; retry when ready."
        }
        Reconciler.rebuild(&state); try repository.save(state)
        do { try vault.removeOrphans(state: state) } catch { self.error = "Your records are available. Protected file cleanup could not finish; it will retry next launch." }
        lock.unlocked = !state.profile.appLock
    }
    @discardableResult func mutate(_ operation: (inout CareState) throws -> Void) -> Bool {
        var next = state
        do { try operation(&next); try repository.save(next); state = next; return true }
        catch { logger.error("Local save failed; previous committed state retained"); self.error = "Could not save this change. \(error.localizedDescription)"; return false }
    }
    @discardableResult func saveProfile(_ profile: Profile) -> Bool {
        if !profile.cloudConsent { cancelAllAnalysis() }
        let saved = mutate({ $0.profile = profile; $0.audit.append(Audit(action: "preferences_updated")) })
        if saved { refreshNotifications() }; return saved
    }
    func source(_ id: UUID) -> Source? { state.source(id) }
    func openAdd(_ mode: CaptureMode = .text) { captureMode = mode; showAdd = true }
    @discardableResult func capture(title: String, kind: SourceKind, text: String, data: Data? = nil, extension ext: String = "txt", event: Date? = nil, encounterID: UUID? = nil, provider: String = "", pages: [EvidencePage] = [], analyze: Bool = true) throws -> UUID {
        guard text.count <= 1_000_000, (data?.count ?? 0) <= 30_000_000 else { throw CareError.invalid("Please import a file under 30 MB and one million text characters.") }
        let hash = ContentHasher.hash(data ?? Data(text.utf8))
        if let duplicate = state.sources.first(where: { $0.contentHash == hash }) { notice = "This evidence is already saved as ‘\(duplicate.title)’."; return duplicate.id }
        var source = Source(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled source" : title, kind: kind, text: text, contentHash: hash, eventAt: event)
        source.pages = pages; source.encounterID = encounterID; source.provider = provider
        if let data { source.originalFile = try vault.write(data, extension: ext) }
        source.state = analyze && !text.isEmpty ? .pending : .saved
        var next = state; next.sources.append(source); next.audit.append(Audit(action: "source_saved"))
        do { try repository.save(next); state = next }
        catch { try? vault.remove(source.originalFile); throw error }
        if analyze && !text.isEmpty { self.analyze(source.id) }
        return source.id
    }
    func importFHIR(title: String, data: Data, event: Date?, encounter: UUID?) throws -> UUID {
        let id = try capture(title: title, kind: .fhir, text: String(data: data, encoding: .utf8) ?? "", data: data, extension: "json", event: event, encounterID: encounter, analyze: false)
        guard let source = source(id), !state.claims.contains(where: { $0.sourceID == id }) else { return id }
        do {
            let imported = try FHIRImporter.parse(data, sourceID: id, eventAt: event)
            _ = mutate { state in
                guard let i = state.sources.firstIndex(where: { $0.id == id }) else { return }
                state.sources[i].workingText = imported.text; state.sources[i].state = .needsReview
                state.sources[i].processingMessage = "\(imported.claims.count) supported items. \(imported.skipped) unsupported resources preserved only in the original file. Confirm subject and extraction."
                state.sources[i].analysisVersion = "fhir-r4-subset-1.0"; state.claims.append(contentsOf: imported.claims)
            }
        } catch {
            _ = mutate { state in if let i = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[i].state = .failed; state.sources[i].processingMessage = error.localizedDescription } }
        }
        return id
    }
    func analyze(_ id: UUID, force: Bool = false, localOnly: Bool = false) {
        guard let source = source(id) else { return }
        if source.kind == .fhir { reanalyzeFHIR(id); return }
        guard !source.workingText.isEmpty else { return }
        tasks[id]?.cancel()
        runs[id] = nil
        let useCloud = state.profile.cloudConsent && !localOnly
        let credentials = KeychainStore.backend; let backend = credentials.endpoint
        let provider: any ExtractionProvider
        if let extractionProvider { provider = extractionProvider }
        else if useCloud, let url = URL(string: backend), !backend.isEmpty { provider = CloudExtractor(baseURL: url, token: credentials.token, configurationID: state.profile.cloudProviderConfigurationID) }
        else { provider = LocalExtractor() }
        let key = ContentHasher.cacheKey(source, version: provider.version)
        if !force && source.analysisVersion == key {
            _ = mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = state.claims.contains(where: { $0.sourceID == id && $0.review == .pending }) ? .needsReview : .complete } }; return
        }
        guard mutate({ if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].state = .processing; $0.sources[i].processingMessage = useCloud && !backend.isEmpty ? "Analyzing with your configured cloud provider…" : "Preparing conservative local proposals…" } }) else { return }
        let run = UUID(); runs[id] = run
        tasks[id] = Task { [weak self] in
            do {
                let claims = try await provider.extract(source: source)
                try Task.checkCancellation()
                guard let self, self.runs[id] == run, let current = self.source(id), current.version == source.version else { return }
                _ = self.mutate { state in
                    for i in state.claims.indices where state.claims[i].sourceID == id && state.claims[i].review == .pending { state.claims[i].review = .rejected }
                    let fresh = claims.filter { proposed in !state.claims.contains { $0.sourceID == id && $0.canonical && Normalizer.equivalent($0, proposed) && $0.quote == proposed.quote } }
                    state.claims.append(contentsOf: fresh)
                    if let i = state.sources.firstIndex(where: { $0.id == id }) {
                        state.sources[i].state = fresh.isEmpty ? .complete : .needsReview; state.sources[i].analysisVersion = key
                        state.sources[i].processingMessage = fresh.isEmpty ? "No new proposals. Your original evidence is saved." : "\(fresh.count) proposals ready. Nothing enters My Care until you review it." + (claims.count == 200 ? " This source reached the 200-item analysis limit. Split the source or review the remaining original text manually." : "")
                    }
                    state.audit.append(Audit(action: "analysis_proposed", count: fresh.count))
                }
                self.tasks[id] = nil; self.runs[id] = nil
            } catch is CancellationError { }
            catch {
                guard let self, self.runs[id] == run, self.source(id)?.version == source.version, !Task.isCancelled else { return }
                _ = self.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .failed; state.sources[i].processingMessage = "Analysis did not finish. Your source is safe. \(error.localizedDescription)" } }
                self.tasks[id] = nil; self.runs[id] = nil
            }
        }
    }
    private func reanalyzeFHIR(_ id: UUID) {
        guard let source = source(id), let filename = source.originalFile else { return }
        tasks[id]?.cancel()
        guard mutate({ if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].state = .processing; $0.sources[i].processingMessage = "Reading supported FHIR resources locally…" } }) else { return }
        let run = UUID(); runs[id] = run
        tasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try Data(contentsOf: self.vault.url(filename))
                let result = try await Task.detached { try FHIRImporter.parse(data, sourceID: id, eventAt: source.eventAt) }.value
                try Task.checkCancellation(); guard self.runs[id] == run, self.source(id)?.version == source.version else { return }
                _ = self.mutate { state in
                    for i in state.claims.indices where state.claims[i].sourceID == id && state.claims[i].review == .pending { state.claims[i].review = .rejected }
                    let fresh = result.claims.filter { claim in !state.claims.contains { $0.sourceID == id && $0.canonical && Normalizer.equivalent($0, claim) } }
                    state.claims.append(contentsOf: fresh)
                    if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].workingText = result.text; state.sources[i].state = fresh.isEmpty ? .complete : .needsReview; state.sources[i].processingMessage = "\(fresh.count) new proposals. \(result.skipped) unsupported resources remain in the original file." }
                }
            } catch is CancellationError { } catch { if self.runs[id] == run && !Task.isCancelled { _ = self.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .failed; state.sources[i].processingMessage = error.localizedDescription } } } }
            if self.runs[id] == run { self.tasks[id] = nil; self.runs[id] = nil }
        }
    }
    func cancelAnalysis(_ id: UUID) { tasks[id]?.cancel(); tasks[id] = nil; runs[id] = nil; _ = mutate { if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].state = .cancelled; $0.sources[i].processingMessage = "Analysis cancelled. Original evidence remains saved." } } }
    func cancelAllAnalysis() { for id in Array(tasks.keys) { cancelAnalysis(id) } }
    func extractOriginal(_ id: UUID) {
        guard let source = source(id), let filename = source.originalFile else { return }
        tasks[id]?.cancel()
        guard mutate({ if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].state = .processing; $0.sources[i].processingMessage = "Extracting text from the preserved original…" } }) else { return }
        let run = UUID(); runs[id] = run
        tasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await DocumentProcessor.importFile(self.vault.url(filename), language:self.state.profile.ocrLanguage); try Task.checkCancellation()
                guard self.runs[id] == run, self.source(id)?.version == source.version else { return }
                _ = self.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].originalText = result.text; state.sources[i].workingText = result.text; state.sources[i].pages = result.pages; state.sources[i].state = result.text.isEmpty ? .saved : .pending; state.sources[i].processingMessage = result.message.isEmpty ? "Text extracted locally. Analyze when ready." : result.message } }
            } catch is CancellationError { } catch { if self.runs[id] == run && !Task.isCancelled { _ = self.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .failed; state.sources[i].processingMessage = "Text extraction failed. The original remains saved." } } } }
            if self.runs[id] == run { self.tasks[id] = nil; self.runs[id] = nil }
        }
    }
    func accept(_ claims: [Claim]) -> Bool {
        let success = mutate { state in
            try Reconciler.accept(claims, into: &state)
            for sourceID in Set(claims.map(\.sourceID)) where !state.claims.contains(where: { $0.sourceID == sourceID && $0.review == .pending }) {
                if let i = state.sources.firstIndex(where: { $0.id == sourceID }) { state.sources[i].state = .complete }
            }
        }
        if success { refreshNotifications() }; return success
    }
    @discardableResult func reject(_ claim: Claim) -> Bool {
        mutate { state in
            var rejected = claim; rejected.review = .rejected
            if let i = state.claims.firstIndex(where: { $0.id == claim.id }) { state.claims[i] = rejected } else { state.claims.append(rejected) }
            if !state.claims.contains(where: { $0.sourceID == claim.sourceID && $0.review == .pending }), let i = state.sources.firstIndex(where: { $0.id == claim.sourceID }) { state.sources[i].state = .complete }
        }
    }
    @discardableResult func saveRecoveredTranscript(_ id: UUID, text: String, segments: [TranscriptSegment]) -> Bool {
        guard let source = source(id), source.workingText.isEmpty else { return false }
        return mutate { state in
            guard let i = state.sources.firstIndex(where: { $0.id == id }) else { return }
            state.sources[i].originalText = text; state.sources[i].workingText = text; state.sources[i].transcriptSegments = segments
            state.sources[i].version += 1; state.sources[i].analysisVersion = ""; state.sources[i].state = text.isEmpty ? .saved : .pending
            state.sources[i].processingMessage = "Transcript recovered locally. Review the text before analysis."
        }
    }
    @discardableResult func editSource(_ id: UUID, title: String, text: String, event: Date?, encounter: UUID?, provider: String) -> Bool {
        tasks[id]?.cancel(); tasks[id] = nil; runs[id] = nil
        let succeeded = mutate { state in
            guard let i = state.sources.firstIndex(where: { $0.id == id }) else { return }
            let changedEvidence = state.sources[i].workingText != text || state.sources[i].eventAt != event
            if state.sources[i].state == .processing { state.sources[i].state = .pending; state.sources[i].processingMessage = "Source context changed. Retry analysis when ready." }
            if changedEvidence {
                state.sources[i].previousText.append(state.sources[i].workingText)
                if state.sources[i].workingText != text { state.sources[i].pages = [] }
                state.sources[i].version += 1; state.sources[i].analysisVersion = ""; state.sources[i].state = .pending
                for j in state.claims.indices where state.claims[j].sourceID == id { state.claims[j].review = .rejected }
            }
            state.sources[i].title = title; state.sources[i].workingText = text; state.sources[i].eventAt = event; state.sources[i].encounterID = encounter; state.sources[i].provider = provider
            Reconciler.rebuild(&state); state.audit.append(Audit(action: "source_edited"))
        }
        if succeeded { refreshNotifications() }
        return succeeded
    }
    @discardableResult func deleteSource(_ id: UUID) -> Bool {
        guard let source = source(id) else { return false }; tasks[id]?.cancel(); tasks[id] = nil; runs[id] = nil
        if mutate({ Reconciler.deleteSource(id, from: &$0) }) {
            do { try vault.remove(source.originalFile); try vault.remove(source.audioFile) } catch { self.error = "Record removed. File cleanup will retry at next launch." }
            refreshNotifications()
            return true
        }
        return false
    }
    func deleteAudio(_ id: UUID) {
        guard let source = source(id), let name = source.audioFile else { return }
        if mutate({ if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].audioFile = nil }; $0.audit.append(Audit(action: "audio_deleted")) }) {
            do { try vault.remove(name) } catch { self.error = "Audio link removed. Protected file cleanup will retry at next launch." }
        }
    }
    @discardableResult func setLoop(_ loop: CareLoop, status: LoopStatus?, note: String, due: Date?, precision: DuePrecision, dateEdited: Bool) -> Bool {
        let saved = mutate { state in
            var value = LoopOverride(); value.status = status; value.note = note; value.dueAt = due; value.precision = precision; value.dateEdited = dateEdited; value.evidenceIDs = loop.claimIDs
            state.loopOverrides[loop.id] = value; Reconciler.rebuild(&state); state.audit.append(Audit(action: "loop_reviewed"))
        }; if saved { refreshNotifications() }; return saved
    }
    @discardableResult func resolve(_ conflict: Conflict, status: ConflictStatus, note: String) -> Bool {
        mutate { state in
            if let i = state.conflicts.firstIndex(where: { $0.id == conflict.id }) { state.conflicts[i].status = status; state.conflicts[i].note = note; state.conflicts[i].resolvedAt = status == .unresolved ? nil : Date() }
            Reconciler.rebuild(&state); state.audit.append(Audit(action: "conflict_reviewed"))
        }
    }
    func addQuestion(_ text: String, entity: UUID? = nil, source: UUID? = nil, encounter: UUID? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if state.questions.contains(where: { !$0.answered && Normalizer.key($0.text) == Normalizer.key(text) && $0.entityID == entity && $0.encounterID == encounter }) { notice = "This question is already saved."; return }
        if mutate({ $0.questions.append(Question(text: text, entityID: entity, sourceID: source, encounterID: encounter)) }) { notice = "Question saved." }
    }
    func refreshNotifications() { let snapshot = state; Task { await ReminderService.reconcile(snapshot) } }
    func archive(includeAudio: Bool) throws -> CareArchive {
        var snapshot = state
        if !includeAudio { for i in snapshot.sources.indices { snapshot.sources[i].audioFile = nil } }
        var files: [String: Data] = [:]; var total = 0
        for name in Set(snapshot.sources.flatMap { [$0.originalFile, $0.audioFile].compactMap { $0 } }) {
            let url = try vault.url(name)
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= ArchiveCodec.maxFileBytes - total else { throw CareError.invalid("Attached files exceed the 40 MB backup limit. Try excluding retained audio.") }
            let data = try ArchiveCodec.readFile(url, limit: ArchiveCodec.maxFileBytes - total); total += data.count
            guard total <= ArchiveCodec.maxFileBytes else { throw CareError.invalid("Attached files exceed the 40 MB backup limit.") }
            files[name] = data
        }
        return CareArchive(state: snapshot, files: files)
    }
    /// Stage new files first, commit the complete state once, then remove old files.
    /// A failed repository save leaves the existing graph and evidence intact.
    func restore(_ archive: CareArchive) throws {
        try archive.validate()
        var restored = archive.state
        var created: [String] = []
        do {
            var names: [String: String] = [:]
            for (name, data) in archive.files {
                let newName = try vault.write(data, extension: (name as NSString).pathExtension)
                created.append(newName); names[name] = newName
            }
            for i in restored.sources.indices {
                restored.sources[i].originalFile = restored.sources[i].originalFile.flatMap { names[$0] }
                restored.sources[i].audioFile = restored.sources[i].audioFile.flatMap { names[$0] }
                if restored.sources[i].state == .processing { restored.sources[i].state = .pending; restored.sources[i].processingMessage = "Restored source. Retry analysis when ready." }
            }
            // Consent and device permissions do not transfer with a backup.
            restored.profile.cloudConsent = false; restored.profile.cloudConsentAt = nil
            restored.profile.cloudProviderConfigurationID = nil
            restored.profile.notifications = false; restored.profile.appLock = state.profile.appLock
            restored.profile.onboarded = true
            Reconciler.rebuild(&restored); restored.audit.append(Audit(action: "backup_restored", count: restored.sources.count))
            try repository.save(restored)
        } catch {
            for name in created { try? vault.remove(name) }
            throw error
        }
        for task in tasks.values { task.cancel() }; tasks.removeAll(); runs.removeAll()
        state = restored; ExportService.clean(); refreshNotifications()
        do { try vault.removeOrphans(state: restored) } catch { self.error = "Backup restored. Old-file cleanup will retry when the app next opens." }
    }
    func loadDemo() { if mutate({ try SyntheticDemo.load(into: &$0) }) { notice = "Synthetic demo loaded. Every demo source is labeled." } }
    func removeDemo() {
        _ = mutate { state in for id in state.sources.filter(\.synthetic).map(\.id) { Reconciler.deleteSource(id, from: &state) }; state.profile.demoLoaded = false }; refreshNotifications()
    }
    func eraseAll() {
        cancelAllAnalysis()
        if mutate({ $0 = CareState() }) {
            do { try vault.removeOrphans(state: state) } catch { self.error = "Records removed. Some protected files could not yet be deleted; cleanup will retry at next launch." }
            ExportService.clean()
            do { try KeychainStore.eraseBackend() } catch { self.error = "Records were removed, but saved backend credentials could not be cleared. Retry Delete all local data while this iPhone is unlocked." }
            lock.unlocked = true; refreshNotifications()
        }
    }
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case voice = "Voice Update", recording = "Record Visit", text = "Type/Paste", camera = "Camera", photo = "Photo", file = "PDF/File", fhir = "FHIR", manual = "Manual"
    var id: String { rawValue }
    var symbol: String { switch self { case .voice: "waveform"; case .recording: "mic.badge.plus"; case .text: "square.and.pencil"; case .camera: "camera"; case .photo: "photo"; case .file: "doc"; case .fhir: "curlybraces"; case .manual: "list.bullet.clipboard" } }
}
