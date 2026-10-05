import Foundation

public struct CheckpointFact: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { claim.id }
    public var claim: Claim
    public var sourceTitle: String
    public var sourceVersion: Int
    public var synthetic: Bool
}

public struct CareCheckpoint: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var title: String
    public var createdAt: Date
    public var encounterID: UUID?
    public var facts: [CheckpointFact]
    public var loops: [CareLoop]
    public var conflicts: [Conflict]
    public var removedSourceCount = 0
    public var redactedDerivedIDs: [String] = []
    public var includesSynthetic: Bool { facts.contains(where: \.synthetic) }
}

public enum VisitProgress: String, Codable, CaseIterable, Sendable {
    case preparing = "Preparing", ready = "Packet ready", remembering = "Remembering the visit"
    case followingThrough = "Following through", archived = "Archived"
}

public struct VisitDebriefDraft: Codable, Equatable, Sendable {
    public var heard = ""
    public var nextSteps = ""
    public var questions = ""
    public var eventAt: Date?
    public init() {}
    public var isEmpty: Bool { [heard, nextSteps, questions].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    public var analysisText: String {
        // Only patient-entered passages are extraction candidates. The original
        // source retains our explanatory headings, but headings are not claims.
        [heard, nextSteps].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n\n")
    }
    public var evidenceText: String {
        var parts = ["My after-visit recollection — patient reported, not clinician verified."]
        if !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts += ["What I heard:", heard] }
        if !nextSteps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts += ["Next steps as I remember them:", nextSteps] }
        // Unanswered questions are stored separately; extraction must not mistake them for instructions.
        return parts.joined(separator: "\n")
    }
}

public struct VisitWorkspace: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var title: String
    public var encounterID: UUID?
    public var createdAt: Date
    public var progress: VisitProgress = .preparing
    public var checkpointID: UUID?
    public var debrief = VisitDebriefDraft()
    public var debriefSourceIDs: [UUID] = []
    public var priorities: String = ""
}

public struct ContinuityMemory: Codable, Equatable, Sendable {
    public var version = 1
    public var checkpoints: [CareCheckpoint] = []
    public var workspaces: [VisitWorkspace] = []
    public init() {}
}

public enum ContinuityEngine {
    public static let maximumCheckpoints = 100
    public static let maximumStoredFacts = 25_000
    public static let maximumWorkspaces = 100

    public static func snapshot(_ state: CareState, title: String, encounterID: UUID? = nil, now: Date = Date()) -> CareCheckpoint {
        let sources = Dictionary(uniqueKeysWithValues: state.sources.map { ($0.id, $0) })
        let facts = state.claims.filter(\.canonical).compactMap { claim -> CheckpointFact? in
            guard let source = sources[claim.sourceID] else { return nil }
            return CheckpointFact(claim: claim, sourceTitle: source.title, sourceVersion: source.version, synthetic: source.synthetic)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        return CareCheckpoint(title: title, createdAt: now, encounterID: encounterID, facts: facts, loops: state.loops, conflicts: state.conflicts)
    }

    @discardableResult public static func saveCheckpoint(title: String, encounterID: UUID? = nil, in state: inout CareState, now: Date = Date()) throws -> UUID {
        let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= 200 else { throw CareError.invalid("Name this checkpoint using 1–200 characters.") }
        if let encounterID, !state.encounters.contains(where: { $0.id == encounterID }) { throw CareError.invalid("The encounter was removed.") }
        var memory = state.continuity ?? ContinuityMemory()
        let checkpoint = snapshot(state, title: label, encounterID: encounterID, now: now)
        guard memory.checkpoints.count < maximumCheckpoints,
              memory.checkpoints.reduce(0, { $0 + $1.facts.count }) + checkpoint.facts.count <= maximumStoredFacts else {
            throw CareError.invalid("Checkpoint storage is full. Export or remove an older checkpoint before saving another.")
        }
        memory.checkpoints.append(checkpoint); state.continuity = memory
        state.audit.append(Audit(action: "checkpoint_saved", count: checkpoint.facts.count))
        return checkpoint.id
    }

    public static func removeCheckpoint(_ id: UUID, from state: inout CareState) {
        guard var memory = state.continuity else { return }
        memory.checkpoints.removeAll { $0.id == id }
        for i in memory.workspaces.indices where memory.workspaces[i].checkpointID == id { memory.workspaces[i].checkpointID = nil }
        state.continuity = memory; state.audit.append(Audit(action: "checkpoint_deleted"))
    }

    public static func renameCheckpoint(_ id: UUID, title: String, in state: inout CareState) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 200, let i = state.continuity?.checkpoints.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("Enter a checkpoint name of 1–200 characters.") }
        state.continuity?.checkpoints[i].title = title
    }

    public static func removeWorkspace(_ id: UUID, from state: inout CareState) {
        state.continuity?.workspaces.removeAll { $0.id == id }
        state.audit.append(Audit(action: "visit_workspace_deleted"))
    }

    /// A source must not survive deletion inside a historical snapshot.
    public static func removeSource(_ id: UUID, from state: inout CareState) {
        guard var memory = state.continuity else { return }
        for i in memory.checkpoints.indices {
            let removed = Set(memory.checkpoints[i].facts.filter { $0.claim.sourceID == id }.map(\.id))
            guard !removed.isEmpty else { continue }
            memory.checkpoints[i].facts.removeAll { removed.contains($0.id) }
            // Whole derived rows can contain that source's text, even if another claim also supports them.
            memory.checkpoints[i].redactedDerivedIDs += memory.checkpoints[i].loops.filter { !removed.isDisjoint(with: $0.claimIDs) }.map { "loop:" + $0.id }
            // A loop's identifier can change when its earliest evidence is deleted.
            // Remember only surviving claim IDs so it is not mistaken for new work.
            memory.checkpoints[i].redactedDerivedIDs += memory.checkpoints[i].loops.filter { !removed.isDisjoint(with: $0.claimIDs) }.flatMap { $0.claimIDs.filter { !removed.contains($0) }.map { "loop-claim:" + $0.uuidString } }
            memory.checkpoints[i].redactedDerivedIDs = Array(Set(memory.checkpoints[i].redactedDerivedIDs)).sorted()
            memory.checkpoints[i].redactedDerivedIDs += memory.checkpoints[i].conflicts.filter { !removed.isDisjoint(with: $0.claimIDs) }.map { "conflict:" + $0.id }
            memory.checkpoints[i].loops.removeAll { !removed.isDisjoint(with: $0.claimIDs) }
            memory.checkpoints[i].conflicts.removeAll { !removed.isDisjoint(with: $0.claimIDs) }
            memory.checkpoints[i].removedSourceCount += 1
        }
        for i in memory.workspaces.indices { memory.workspaces[i].debriefSourceIDs.removeAll { $0 == id } }
        state.continuity = memory
    }

    public static func detachEncounter(_ id: UUID, in state: inout CareState) {
        guard var memory = state.continuity else { return }
        for i in memory.checkpoints.indices where memory.checkpoints[i].encounterID == id { memory.checkpoints[i].encounterID = nil }
        for i in memory.workspaces.indices where memory.workspaces[i].encounterID == id { memory.workspaces[i].encounterID = nil }
        state.continuity = memory
    }

    @discardableResult public static func createWorkspace(title: String, encounterID: UUID? = nil, in state: inout CareState, now: Date = Date()) throws -> UUID {
        var memory = state.continuity ?? ContinuityMemory()
        if let encounterID, let existing = memory.workspaces.first(where: { $0.encounterID == encounterID && $0.progress != .archived }) { return existing.id }
        let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= 200, memory.workspaces.count < maximumWorkspaces else { throw CareError.invalid("Enter a workspace title of 1–200 characters. Up to 100 workspaces can be saved.") }
        if let encounterID, !state.encounters.contains(where: { $0.id == encounterID }) { throw CareError.invalid("The encounter was removed.") }
        let workspace = VisitWorkspace(title: label, encounterID: encounterID, createdAt: now)
        memory.workspaces.append(workspace); state.continuity = memory
        state.audit.append(Audit(action: "visit_workspace_saved")); return workspace.id
    }

    public static func saveWorkspace(_ workspace: VisitWorkspace, in state: inout CareState) throws {
        guard var memory = state.continuity, let i = memory.workspaces.firstIndex(where: { $0.id == workspace.id }) else { throw CareError.invalid("This workspace was removed.") }
        guard !workspace.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, workspace.title.count <= 200,
              workspace.createdAt.timeIntervalSinceReferenceDate.isFinite, workspace.debrief.eventAt?.timeIntervalSinceReferenceDate.isFinite != false,
              workspace.priorities.count <= 10_000, [workspace.debrief.heard, workspace.debrief.nextSteps, workspace.debrief.questions].allSatisfy({ $0.count <= 20_000 }) else { throw CareError.invalid("This draft is too long. Use a source document for longer notes.") }
        guard Set(workspace.debriefSourceIDs).isSubset(of: Set(state.sources.map(\.id))),
              workspace.checkpointID == nil || memory.checkpoints.contains(where: { $0.id == workspace.checkpointID }),
              workspace.encounterID == nil || state.encounters.contains(where: { $0.id == workspace.encounterID }) else { throw CareError.invalid("Some linked information was removed. Reopen this workspace before saving.") }
        memory.workspaces[i] = workspace; state.continuity = memory
    }

    /// Save the user's exact recollection and questions atomically. Extraction/review happens later.
    @discardableResult public static func saveDebrief(_ draft: VisitDebriefDraft, workspaceID: UUID, in state: inout CareState, now: Date = Date()) throws -> UUID? {
        var next = state
        guard var workspace = next.continuity?.workspaces.first(where: { $0.id == workspaceID }), !draft.isEmpty else { throw CareError.invalid("Add something you heard, a next step, or a question.") }
        workspace.debrief = draft; try saveWorkspace(workspace, in: &next)
        var sourceID: UUID?
        if !draft.heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.nextSteps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let text = draft.evidenceText
            let hash = ContentHasher.hash(text)
            if let duplicate = next.sources.first(where: { workspace.debriefSourceIDs.contains($0.id) && $0.contentHash == hash && $0.eventAt == draft.eventAt }) {
                sourceID = duplicate.id
            } else {
                var source = Source(title: String(("My recollection · " + workspace.title).prefix(200)), kind: .typed, text: text, contentHash: hash, eventAt: draft.eventAt)
                source.workingText = draft.analysisText
                source.capturedAt = now; source.encounterID = workspace.encounterID; source.state = .pending
                next.sources.append(source); sourceID = source.id
                workspace.debriefSourceIDs.append(source.id)
            }
        }
        for line in draft.questions.components(separatedBy: .newlines) {
            let question = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard question.count <= 2000 else { throw CareError.invalid("Keep each question under 2,000 characters. Your draft is still saved.") }
            guard !question.isEmpty, !next.questions.contains(where: { !$0.answered && Normalizer.key($0.text) == Normalizer.key(question) && $0.encounterID == workspace.encounterID }) else { continue }
            next.questions.append(Question(text: question, sourceID: sourceID, encounterID: workspace.encounterID))
        }
        workspace.debrief = VisitDebriefDraft(); workspace.progress = .remembering
        try saveWorkspace(workspace, in: &next)
        next.audit.append(Audit(action: "visit_recollection_saved")); state = next
        return sourceID
    }

    public static func validate(_ state: CareState) throws {
        guard let memory = state.continuity else { return }
        guard memory.version == 1, memory.checkpoints.count <= maximumCheckpoints, memory.workspaces.count <= maximumWorkspaces,
              memory.checkpoints.reduce(0, { $0 + $1.facts.count }) <= maximumStoredFacts,
              Set(memory.checkpoints.map(\.id)).count == memory.checkpoints.count,
              Set(memory.workspaces.map(\.id)).count == memory.workspaces.count else { throw CareError.invalid("The continuity workspace data is unsupported or exceeds storage limits.") }
        let sourceIDs = Set(state.sources.map(\.id)), encounterIDs = Set(state.encounters.map(\.id)), checkpointIDs = Set(memory.checkpoints.map(\.id))
        for checkpoint in memory.checkpoints {
            let claims = Set(checkpoint.facts.map(\.id))
            guard claims.count == checkpoint.facts.count, !checkpoint.title.isEmpty, checkpoint.title.count <= 200, checkpoint.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  checkpoint.removedSourceCount >= 0, checkpoint.removedSourceCount <= 10_000,
                  checkpoint.redactedDerivedIDs.count <= 100_000, checkpoint.redactedDerivedIDs.allSatisfy({ $0.count <= 1000 }),
                  Set(checkpoint.loops.map(\.id)).count == checkpoint.loops.count,
                  Set(checkpoint.conflicts.map(\.id)).count == checkpoint.conflicts.count else { throw CareError.invalid("A checkpoint contains invalid or duplicate records.") }
            if let id = checkpoint.encounterID, !encounterIDs.contains(id) { throw CareError.invalid("A checkpoint references a missing encounter.") }
            for fact in checkpoint.facts {
                guard fact.claim.canonical, fact.claim.entityID != nil, let source = state.source(fact.claim.sourceID), fact.sourceVersion > 0, fact.sourceVersion <= source.version,
                      fact.claim.label.count <= 200, !fact.claim.label.isEmpty, !fact.claim.quote.isEmpty, fact.claim.quote.count <= 6000,
                      fact.claim.confidence.isFinite, (0...1).contains(fact.claim.confidence), fact.claim.numericValue?.isFinite != false,
                      [fact.claim.eventAt, fact.claim.effectiveAt, fact.claim.dueAt, fact.claim.acceptedAt].compactMap({ $0 }).allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }),
                      fact.sourceTitle.count <= 10_000, fact.claim.createdAt.timeIntervalSinceReferenceDate.isFinite,
                      ([source.originalText, source.workingText] + source.previousText).contains(where: { $0.contains(fact.claim.quote) }) else { throw CareError.invalid("A checkpoint report is missing valid preserved source evidence.") }
            }
            for loop in checkpoint.loops where !Set(loop.claimIDs).isSubset(of: claims) { throw CareError.invalid("A checkpoint workflow references missing evidence.") }
            for conflict in checkpoint.conflicts where !Set(conflict.claimIDs).isSubset(of: claims) { throw CareError.invalid("A checkpoint discrepancy references missing evidence.") }
        }
        for workspace in memory.workspaces {
            guard !workspace.title.isEmpty, workspace.title.count <= 200, workspace.priorities.count <= 10_000,
                  workspace.createdAt.timeIntervalSinceReferenceDate.isFinite, workspace.debrief.eventAt?.timeIntervalSinceReferenceDate.isFinite != false,
                  [workspace.debrief.heard, workspace.debrief.nextSteps, workspace.debrief.questions].allSatisfy({ $0.count <= 20_000 }),
                  Set(workspace.debriefSourceIDs).isSubset(of: sourceIDs), Set(workspace.debriefSourceIDs).count == workspace.debriefSourceIDs.count else { throw CareError.invalid("A visit workspace contains invalid content or missing evidence.") }
            if let id = workspace.encounterID, !encounterIDs.contains(id) { throw CareError.invalid("A visit workspace references a missing encounter.") }
            if let id = workspace.checkpointID, !checkpointIDs.contains(id) { throw CareError.invalid("A visit workspace references a missing checkpoint.") }
        }
    }
}
