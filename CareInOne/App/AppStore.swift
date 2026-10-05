import Foundation
import Observation
import CareCore
import OSLog

@MainActor @Observable final class AppStore {
    private(set) var state: CareState
    /// Recover a failed helper draft while the app remains open; never substitutes for a disk save.
    var followThroughRecoveryDrafts: [UUID: FollowThroughPlan] = [:]
    var error: String?
    var notice: String?
    var reminderStatus: ReminderReconciliation?
    private var notificationRefresh: Task<Void, Never>?
    var showAdd = false
    var captureMode: CaptureMode = .text
    var captureEncounterID: UUID?
    var selectedTab = 0
    var showDemo = false
    var importedURL: URL?
    var importedSynthetic = false
    let vault: EvidenceVault
    let isDemoWorkspace: Bool
    private let repository: any CareRepository
    private let extractionProvider: (any ExtractionProvider)?
    private let clearBackendOnErase: Bool
    private let systemServicesEnabled: Bool
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var runs: [UUID: UUID] = [:]
    private let logger = Logger(subsystem: "org.carecontinuity.app", category: "storage")
    let lock = AppLock()
    init(repository: any CareRepository, vault: EvidenceVault, extractionProvider: (any ExtractionProvider)? = nil, isDemoWorkspace: Bool = false, clearBackendOnErase: Bool = true, systemServicesEnabled: Bool = true) throws {
        self.repository = repository; self.vault = vault; self.extractionProvider = extractionProvider; self.isDemoWorkspace = isDemoWorkspace; self.clearBackendOnErase = clearBackendOnErase; self.systemServicesEnabled = systemServicesEnabled; state = try repository.load()
        try ContinuityEngine.validate(state)
        try HandoffEngine.validate(state)
        try VisitCompanionEngine.validate(state)
        try FollowThroughAssistEngine.validate(state)
        for i in state.sources.indices where state.sources[i].state == .processing {
            state.sources[i].state = .pending; state.sources[i].processingMessage = "Processing was interrupted. Your evidence is saved; retry when ready."
        }
        Reconciler.rebuild(&state); try repository.save(state)
        do { try vault.removeOrphans(state: state) } catch { self.error = "Your records are available. Protected file cleanup could not finish; it will retry next launch." }
        lock.unlocked = !state.profile.appLock
    }
    @discardableResult func mutate(_ operation: (inout CareState) throws -> Void) -> Bool {
        var next = state
        do {
            try operation(&next)
            if isDemoWorkspace {
                let existing = Set(state.sources.map(\.id))
                for i in next.sources.indices where !existing.contains(next.sources[i].id) { next.sources[i].synthetic = true }
            }
            try repository.save(next); state = next
            let plans = Set(next.followThroughPlans?.plans.map(\.id) ?? [])
            followThroughRecoveryDrafts = followThroughRecoveryDrafts.filter { plans.contains($0.key) }
            return true
        }
        catch { logger.error("Local save failed; previous committed state retained"); self.error = "Could not save this change. \(error.localizedDescription)"; return false }
    }
    @discardableResult func saveProfile(_ profile: Profile) -> Bool {
        if !profile.cloudConsent { cancelAllAnalysis() }
        let saved = mutate({ $0.profile = profile; $0.audit.append(Audit(action: "preferences_updated")) })
        if saved { refreshNotifications() }; return saved
    }
    func source(_ id: UUID) -> Source? { state.source(id) }
    func analysisInProgress(_ id: UUID) -> Bool { tasks[id] != nil }
    @discardableResult func createWorkspace(title: String, encounterID: UUID? = nil) -> UUID? {
        var id: UUID?
        return mutate { id = try ContinuityEngine.createWorkspace(title: title, encounterID: encounterID, in: &$0) } ? id : nil
    }
    @discardableResult func saveWorkspace(_ workspace: VisitWorkspace) -> Bool {
        mutate { try ContinuityEngine.saveWorkspace(workspace, in: &$0) }
    }
    @discardableResult func saveCheckpoint(title: String, encounterID: UUID? = nil, workspaceID: UUID? = nil) -> UUID? {
        var id: UUID?
        let saved = mutate { state in
            let created = try ContinuityEngine.saveCheckpoint(title: title, encounterID: encounterID, in: &state)
            if let workspaceID {
                guard var workspace = state.continuity?.workspaces.first(where: { $0.id == workspaceID }) else { throw CareError.invalid("The workspace was removed.") }
                workspace.checkpointID = created; try ContinuityEngine.saveWorkspace(workspace, in: &state)
            }
            id = created
        }
        return saved ? id : nil
    }
    func saveDebrief(_ draft: VisitDebriefDraft, workspaceID: UUID) -> (saved: Bool, sourceID: UUID?) {
        var id: UUID?
        let saved = mutate { id = try ContinuityEngine.saveDebrief(draft, workspaceID: workspaceID, in: &$0) }
        if saved, let id, source(id)?.state == .pending { analyze(id) }
        return (saved, saved ? id : nil)
    }
    func openAdd(_ mode: CaptureMode = .text, encounterID: UUID? = nil) { captureMode = mode; captureEncounterID = encounterID; showAdd = true }
    @discardableResult func createHandoff(title: String, recipient: String, options: PacketOptions) -> UUID? {
        var id: UUID?
        return mutate { id = try HandoffEngine.create(title: title, recipient: recipient, options: options, in: &$0) } ? id : nil
    }
    @discardableResult func captureHandoffReply(_ text: String, eventAt: Date?, handoffID: UUID, synthetic: Bool) -> UUID? {
        var id: UUID?
        let saved = mutate { id = try HandoffEngine.captureReply(text, eventAt: eventAt, handoffID: handoffID, synthetic: synthetic, in: &$0) }
        if saved, let id, source(id)?.state == .pending { analyze(id) }
        return saved ? id : nil
    }
    @discardableResult func capture(title: String, kind: SourceKind, text: String, data: Data? = nil, extension ext: String = "txt", event: Date? = nil, encounterID: UUID? = nil, provider: String = "", pages: [EvidencePage] = [], analyze: Bool = true) throws -> UUID {
        guard text.count <= 1_000_000, (data?.count ?? 0) <= 30_000_000 else { throw CareError.invalid("Please import a file under 30 MB and one million text characters.") }
        let hash = ContentHasher.hash(data ?? Data(text.utf8))
        // Repeated instructions can belong to a later visit. Only suppress a
        // repeated submission when both the bytes and care context match.
        let providerName = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        if let duplicate = state.sources.first(where: {
            $0.contentHash == hash && $0.kind == kind && $0.eventAt == event &&
            $0.encounterID == encounterID && $0.provider.trimmingCharacters(in: .whitespacesAndNewlines) == providerName
        }) { notice = "This evidence is already saved as ‘\(duplicate.title)’."; return duplicate.id }
        var source = Source(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled source" : title, kind: kind, text: text, contentHash: hash, eventAt: event)
        source.synthetic = isDemoWorkspace
        source.pages = pages; source.encounterID = encounterID; source.provider = providerName
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
        let imported: FHIRImport
        do { imported = try FHIRImporter.parse(data, sourceID: id, eventAt: event) }
        catch {
            let message = error.localizedDescription
            guard mutate({ state in
                guard let i = state.sources.firstIndex(where: { $0.id == source.id }) else { throw CareError.invalid("The saved source could not be found.") }
                state.sources[i].state = .failed; state.sources[i].processingMessage = "FHIR import could not finish. The original file remains saved. " + message
            }) else { throw CareError.invalid("The original FHIR file was saved, but its import status could not be saved. Retry from Sources.") }
            return id
        }
        guard mutate({ state in
                guard let i = state.sources.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("The saved source could not be found.") }
                state.sources[i].workingText = imported.text; state.sources[i].state = .needsReview
                state.sources[i].processingMessage = "\(imported.claims.count) supported items. \(imported.skipped) unsupported resources preserved only in the original file. Confirm subject and extraction."
                state.sources[i].analysisVersion = FHIRImporter.version; state.claims.append(contentsOf: imported.claims)
            }) else { throw CareError.invalid("The original FHIR file was saved, but imported proposals could not be saved. Retry from Sources.") }
        return id
    }
    func analyze(_ id: UUID, force: Bool = false, localOnly: Bool = false) {
        guard let source = source(id) else { error = "This source has been removed. No analysis was started."; return }
        if source.kind == .fhir { reanalyzeFHIR(id); return }
        guard !source.workingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Add or extract source text before analyzing. Your original file remains saved."; return }
        tasks[id]?.cancel()
        runs[id] = nil
        let useCloud = state.profile.cloudConsent && !localOnly
        let credentials = KeychainStore.backend; let backend = credentials.endpoint
        let provider: any ExtractionProvider
        if let extractionProvider { provider = extractionProvider }
        else if useCloud {
            do {
                let url = try GatewayClient.validate(endpoint: backend, token: credentials.token)
                guard state.profile.cloudProviderConfigurationID != nil else { throw CareError.invalid("Review and allow the configured models in Settings → Cloud connection before using cloud analysis.") }
                provider = CloudExtractor(baseURL: url, token: credentials.token, configurationID: state.profile.cloudProviderConfigurationID)
            } catch { self.error = error.localizedDescription; return }
        }
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
        guard source.workingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "This source already has working text. Edit it directly to preserve reviewed care and earlier versions."; return }
        tasks[id]?.cancel()
        guard mutate({ if let i = $0.sources.firstIndex(where: { $0.id == id }) { $0.sources[i].state = .processing; $0.sources[i].processingMessage = "Extracting text from the preserved original…" } }) else { return }
        let run = UUID(); runs[id] = run
        tasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await DocumentProcessor.importFile(self.vault.url(filename), language:self.state.profile.ocrLanguage); try Task.checkCancellation()
                guard self.runs[id] == run, self.source(id)?.version == source.version else { return }
                guard result.text.count <= 1_000_000 else { throw CareError.invalid("The extracted text exceeds one million characters. Split the original into smaller files.") }
                _ = self.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) {
                    if !state.sources[i].originalText.isEmpty && state.sources[i].originalText != result.text { state.sources[i].previousText.append(state.sources[i].originalText) }
                    state.sources[i].originalText = result.text; state.sources[i].workingText = result.text; state.sources[i].pages = result.pages
                    state.sources[i].state = result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed : .pending
                    state.sources[i].processingMessage = result.message.isEmpty ? (result.text.isEmpty ? "No text could be extracted. The original is saved. Add working text manually or try another file." : "Text extracted locally. Analyze when ready.") : result.message
                } }
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
        let saved = mutate { state in
            guard state.source(claim.sourceID) != nil else { throw CareError.invalid("The supporting source has been removed. No report was changed.") }
            var rejected = claim; rejected.review = .rejected
            if let i = state.claims.firstIndex(where: { $0.id == claim.id }) {
                guard state.claims[i].sourceID == claim.sourceID, state.claims[i].revision == claim.revision else {
                    throw CareError.invalid("This report changed while it was open. Review the current version before withdrawing it.")
                }
                if state.claims[i].canonical {
                    var previous = state.claims[i]; previous.id = UUID(); previous.review = .rejected
                    state.claims.append(previous)
                    rejected.revision = state.claims[i].revision + 1
                }
                state.claims[i] = rejected
            } else { state.claims.append(rejected) }
            if !state.claims.contains(where: { $0.sourceID == claim.sourceID && $0.review == .pending }), let i = state.sources.firstIndex(where: { $0.id == claim.sourceID }) { state.sources[i].state = .complete }
            Reconciler.rebuild(&state)
            state.audit.append(Audit(action: "claim_withdrawn"))
        }
        if saved { refreshNotifications() }; return saved
    }
    @discardableResult func correctReviewedClaim(_ original: Claim, with correction: Claim) -> Bool {
        let saved = mutate { state in
            guard let current = state.claims.first(where: { $0.id == original.id }), current == original, current.canonical,
                  correction.id == original.id, correction.sourceID == original.sourceID else {
                throw CareError.invalid("This saved report changed while you were editing. Open it again to review the current version. Your draft remains here.")
            }
            var previous = current; previous.id = UUID(); previous.review = .rejected
            var revised = correction; revised.userEdited = true; revised.revision = current.revision + 1
            try Reconciler.accept([revised], into: &state)
            state.claims.append(previous)
            state.audit.append(Audit(action: "reviewed_claim_corrected"))
        }
        if saved { refreshNotifications() }; return saved
    }
    @discardableResult func saveRecoveredTranscript(_ id: UUID, text: String, segments: [TranscriptSegment]) -> Bool {
        guard text.count <= 1_000_000 else { error = "This transcript exceeds one million characters. The saved recording is still available."; return false }
        guard let source = source(id), source.workingText.isEmpty else { error = "This source already has text or has been removed. Your current saved version was preserved."; return false }
        return mutate { state in
            guard let i = state.sources.firstIndex(where: { $0.id == id }) else { return }
            state.sources[i].originalText = text; state.sources[i].workingText = text; state.sources[i].transcriptSegments = segments
            state.sources[i].version += 1; state.sources[i].analysisVersion = ""; state.sources[i].state = text.isEmpty ? .saved : .pending
            state.sources[i].processingMessage = "Transcript recovered locally. Review the text before analysis."
        }
    }
    @discardableResult func editSource(_ id: UUID, title: String, text: String, event: Date?, encounter: UUID?, provider: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { error = "Give this source a title before saving."; return false }
        guard text.count <= 1_000_000 else { error = "Keep source text under one million characters. Your previous version is still saved."; return false }
        guard source(id) != nil else { error = "This source has been removed. Your changes could not be saved."; return false }
        tasks[id]?.cancel(); tasks[id] = nil; runs[id] = nil
        let succeeded = mutate { state in
            guard let i = state.sources.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("This source has been removed.") }
            let changedEvidence = state.sources[i].workingText != text || state.sources[i].eventAt != event
            if state.sources[i].state == .processing { state.sources[i].state = .pending; state.sources[i].processingMessage = "Source context changed. Retry analysis when ready." }
            if changedEvidence {
                let hadReports = state.claims.contains { $0.sourceID == id }
                state.sources[i].previousText.append(state.sources[i].workingText)
                if state.sources[i].workingText != text { state.sources[i].pages = [] }
                state.sources[i].version += 1; state.sources[i].analysisVersion = ""; state.sources[i].state = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .saved : .pending
                for j in state.claims.indices where state.claims[j].sourceID == id { state.claims[j].review = .rejected }
                let retirement = hadReports ? " Earlier proposals and reports from this source are withdrawn from My Care." : ""
                state.sources[i].processingMessage = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Working text cleared." + retirement + " Original evidence and earlier working versions remain saved. Add working text before analysis."
                    : "Working text or event date changed." + retirement + " Analyze the updated source, then review new proposals. Original evidence and earlier working versions remain saved."
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
            ExportService.clean()
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
            guard state.loops.first(where: { $0.id == loop.id }) == loop else {
                throw CareError.invalid("This next step changed while you were editing. Your changes were not saved. Reopen it to review the latest evidence.")
            }
            var value = LoopOverride(); value.status = status; value.note = note; value.dueAt = due; value.precision = precision; value.dateEdited = dateEdited; value.evidenceIDs = loop.claimIDs
            state.loopOverrides[loop.id] = value; Reconciler.rebuild(&state); state.audit.append(Audit(action: "loop_reviewed"))
        }; if saved { refreshNotifications() }; return saved
    }
    @discardableResult func resolve(_ conflict: Conflict, status: ConflictStatus, note: String) -> Bool {
        mutate { state in
            guard let i = state.conflicts.firstIndex(where: { $0.id == conflict.id }), state.conflicts[i] == conflict else {
                throw CareError.invalid("These reports changed while you were editing. Your clarification was not saved. Reopen the discrepancy to review the latest evidence.")
            }
            state.conflicts[i].status = status; state.conflicts[i].note = note; state.conflicts[i].resolvedAt = status == .unresolved ? nil : Date()
            Reconciler.rebuild(&state); state.audit.append(Audit(action: "conflict_reviewed"))
        }
    }
    @discardableResult func addQuestion(_ text: String, entity: UUID? = nil, source: UUID? = nil, encounter: UUID? = nil) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if state.questions.contains(where: { !$0.answered && Normalizer.key($0.text) == Normalizer.key(text) && $0.entityID == entity && $0.encounterID == encounter }) { notice = "This question is already saved."; return true }
        if mutate({ $0.questions.append(Question(text: text, entityID: entity, sourceID: source, encounterID: encounter)) }) { notice = "Question saved."; return true }; return false
    }
    func refreshNotifications() {
        guard systemServicesEnabled else { return }
        notificationRefresh?.cancel()
        let snapshot = state
        notificationRefresh = Task {
            let result = await ReminderService.reconcile(snapshot, isDemoWorkspace: isDemoWorkspace)
            guard !Task.isCancelled, !result.superseded else { return }
            reminderStatus = result
        }
    }
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
        guard !isDemoWorkspace || (archive.state.profile.demoLoaded && archive.state.sources.allSatisfy(\.synthetic)) else {
            throw CareError.invalid("Restore personal records in My Care, outside the fictional demo. Your current demo and personal records have not been changed.")
        }
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
        state = restored; followThroughRecoveryDrafts = [:]; ExportService.clean(); refreshNotifications()
        do { try vault.removeOrphans(state: restored) } catch { self.error = "Backup restored. Old-file cleanup will retry when the app next opens." }
    }
    func loadDemo() { if mutate({ try SyntheticDemo.load(into: &$0) }) { notice = "Synthetic demo loaded. Every demo source is labeled." } }
    func openDemo() {
        guard !isDemoWorkspace else { notice = "You are already in the fictional demo workspace."; return }
        showDemo = true
    }
    func resetDemoWorkspace() {
        guard isDemoWorkspace else { return }
        cancelAllAnalysis()
        if mutate({ state in state = CareState(); try SyntheticDemo.load(into: &state); state.profile.onboarded = true }) {
            followThroughRecoveryDrafts = [:]; ExportService.clean(); refreshNotifications()
            do { try vault.removeOrphans(state: state) } catch { self.error = "The fictional demo was reset. Old demo-file cleanup will retry next launch." }
            notice = "Fictional demo reset. Your personal care records were preserved."
        }
    }
    func removeDemo() {
        let ids = state.sources.filter(\.synthetic).map(\.id)
        for id in ids { tasks[id]?.cancel(); tasks[id] = nil; runs[id] = nil }
        if mutate({ state in for id in ids { Reconciler.deleteSource(id, from: &state) }; state.profile.demoLoaded = false }) {
            ExportService.clean()
            do { try vault.removeOrphans(state: state) } catch { self.error = "Synthetic records removed. File cleanup will retry at next launch." }
            refreshNotifications()
        }
    }
    func eraseAll() {
        cancelAllAnalysis()
        if mutate({ $0 = CareState(); if isDemoWorkspace { $0.profile.onboarded = true } }) {
            do { try vault.removeOrphans(state: state) } catch { self.error = "Records removed. Some protected files could not yet be deleted; cleanup will retry at next launch." }
            ExportService.clean()
            if !isDemoWorkspace && systemServicesEnabled { CalendarService.clearExportReceipts() }
            if !isDemoWorkspace && clearBackendOnErase && systemServicesEnabled { do { try KeychainStore.eraseBackend() } catch { self.error = "Records were removed, but saved backend credentials could not be cleared. Retry Delete all local data while this device is unlocked." } }
            lock.unlocked = true; refreshNotifications()
        }
    }
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case voice = "Voice Update", recording = "Record Visit", text = "Type/Paste", camera = "Camera", photo = "Photo", file = "PDF/File", fhir = "FHIR", manual = "Manual"
    var id: String { rawValue }
    var symbol: String { switch self { case .voice: "waveform"; case .recording: "mic.badge.plus"; case .text: "square.and.pencil"; case .camera: "camera"; case .photo: "photo"; case .file: "doc"; case .fhir: "curlybraces"; case .manual: "list.bullet.clipboard" } }
}


// UI backup operations keep bounded evidence I/O off the main actor. The final
// repository transaction stays on the main actor, with no suspension during commit.
extension AppStore {
    func archiveInBackground(includeAudio: Bool) async throws -> CareArchive {
        var snapshot = state
        if !includeAudio { for i in snapshot.sources.indices { snapshot.sources[i].audioFile = nil } }
        let names = Set(snapshot.sources.flatMap { [$0.originalFile, $0.audioFile].compactMap { $0 } })
        let urls = try names.map { name in (name, try vault.url(name)) }
        let immutableSnapshot = snapshot
        let worker = Task.detached(priority: .userInitiated) {
            var files: [String: Data] = [:]; var total = 0
            for (name, url) in urls {
                try Task.checkCancellation()
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= ArchiveCodec.maxFileBytes - total else { throw CareError.invalid("Attached files exceed the 40 MB backup limit. Try excluding retained audio.") }
                let data = try ArchiveCodec.readFile(url, limit: ArchiveCodec.maxFileBytes - total)
                total += data.count; files[name] = data
            }
            try Task.checkCancellation()
            let archive = CareArchive(state: immutableSnapshot, files: files)
            try archive.validate()
            return archive
        }
        return try await withTaskCancellationHandler {
            let archive = try await worker.value
            try Task.checkCancellation()
            return archive
        } onCancel: { worker.cancel() }
    }

    func restoreInBackground(_ archive: CareArchive) async throws {
        try Task.checkCancellation()
        guard !isDemoWorkspace || (archive.state.profile.demoLoaded && archive.state.sources.allSatisfy(\.synthetic)) else {
            throw CareError.invalid("Restore personal records in My Care, outside the fictional demo. Your current demo and personal records have not been changed.")
        }
        let prior = state
        let directory = vault.files
        let worker = Task.detached(priority: .userInitiated) { () throws -> [String: String] in
            var names: [String: String] = [:]
            do {
                try archive.validate()
                for (name, data) in archive.files {
                    try Task.checkCancellation()
                    let ext = (name as NSString).pathExtension.filter { $0.isLetter || $0.isNumber }.prefix(12)
                    let staged = UUID().uuidString + "." + ext
                    // Track before writing so an interrupted failed write is also cleaned.
                    names[name] = staged
                    try data.write(to: directory.appendingPathComponent(staged), options: [.atomic, .completeFileProtection])
                }
                try Task.checkCancellation()
                return names
            } catch {
                for staged in names.values { try? FileManager.default.removeItem(at: directory.appendingPathComponent(staged)) }
                throw error
            }
        }
        let names = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: { worker.cancel() }
        var restored = archive.state
        do {
            try Task.checkCancellation()
            guard state == prior else { throw CareError.invalid("Your saved care changed while the backup was being prepared. Nothing was replaced. Review the current records and restore again when ready.") }
            for i in restored.sources.indices {
                restored.sources[i].originalFile = restored.sources[i].originalFile.flatMap { names[$0] }
                restored.sources[i].audioFile = restored.sources[i].audioFile.flatMap { names[$0] }
                if restored.sources[i].state == .processing { restored.sources[i].state = .pending; restored.sources[i].processingMessage = "Restored source. Retry analysis when ready." }
            }
            restored.profile.cloudConsent = false; restored.profile.cloudConsentAt = nil
            restored.profile.cloudProviderConfigurationID = nil
            restored.profile.notifications = false; restored.profile.appLock = state.profile.appLock
            restored.profile.onboarded = true
            Reconciler.rebuild(&restored); restored.audit.append(Audit(action: "backup_restored", count: restored.sources.count))
            try repository.save(restored)
        } catch {
            for name in names.values { try? vault.remove(name) }
            throw error
        }
        for task in tasks.values { task.cancel() }; tasks.removeAll(); runs.removeAll()
        state = restored; followThroughRecoveryDrafts = [:]; ExportService.clean(); refreshNotifications()
        do { try vault.removeOrphans(state: restored) }
        catch { self.error = "Backup restored. Old-file cleanup will retry when the app next opens." }
    }
}
