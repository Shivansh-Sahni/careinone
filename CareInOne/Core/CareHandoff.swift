import Foundation

public enum HandoffProfileField: String, Codable, Sendable { case name, birthDate, contact }

public struct EvidenceStamp: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var digest: String
    public var sourceIDs: [UUID]
}
public struct CareHandoff: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var title: String
    public var recipient: String
    public var encounterID: UUID?
    public var createdAt: Date
    public var selectedItemIDs: [String]
    public var entityIDs: [UUID]
    public var claimIDs: [UUID]
    public var includedSourceIDs: [UUID]
    public var profileFields: [HandoffProfileField]?
    /// Immutable exact outgoing copy, removed in full if a supporting source is deleted.
    public var snapshotText: String?
    public var snapshotDigest: String
    public var baseline: [EvidenceStamp]
    public var sharedAt: Date?
    public var finishedAt: Date?
    public var finishBaseline: [EvidenceStamp]?
    public var redactedAt: Date?
    public var replyDraft = ""
    public var replyEventAt: Date?
    public var replySynthetic: Bool?
    public var replySourceIDs: [UUID] = []
    public var synthetic: Bool
    public var statusLabel: String { finishedAt != nil ? "Finished by you" : sharedAt != nil ? "Shared by your report" : "Prepared" }
}
public struct HandoffMemory: Codable, Equatable, Sendable {
    public var version = 1
    public var handoffs: [CareHandoff] = []
    public init() {}
}
public enum HandoffChangeKind: String, Sendable { case added = "Added since this copy", changed = "Changed since this copy", removed = "No longer represented here" }
public struct HandoffChange: Identifiable, Sendable {
    public var id: String
    public var kind: HandoffChangeKind
    public var title: String
    public var sourceIDs: [UUID]
    public var categoryLabel: String {
        switch id.prefix(while: { $0 != ":" }) {
        case "report": "Reviewed report"
        case "source": "Source and its reviewed content"
        case "conflict": "Discrepancy"
        case "loop": "Follow-through"
        case "question": "Saved question"
        case "profile": "Included profile field"
        default: "Personal context"
        }
    }
}

public enum HandoffEngine {
    public static let maximumHandoffs = 100
    public static let maximumTextCharacters = 2_000_000
    public static let maximumStamps = 50_000
    private static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return ContentHasher.hash(try encoder.encode(value))
    }
    private struct SourceFingerprint: Encodable {
        var title: String; var kind: SourceKind; var capturedAt: Date; var eventAt: Date?
        var provider: String; var version: Int; var originalHash: String; var workingHash: String
        var reviewedReportsHash: String
    }
    /// Watch the selected items and reviewed context for their explicitly linked care items.
    /// These hashes are local comparison metadata; the outgoing text contains only the selection.
    public static func context(for handoff: CareHandoff, in state: CareState) throws -> [EvidenceStamp] {
        let entities = Set(handoff.entityIDs), selected = Set(handoff.selectedItemIDs), reportIDs = Set(handoff.claimIDs)
        let claims = state.claims.filter { $0.canonical && (reportIDs.contains($0.id) || $0.entityID.map(entities.contains) == true) }
        var stamps: [EvidenceStamp] = []
        func add<T: Encodable>(_ id: String, _ value: T, _ sources: [UUID]) throws {
            stamps.append(EvidenceStamp(id: id, digest: try digest(value), sourceIDs: Array(Set(sources)).sorted { $0.uuidString < $1.uuidString }))
        }
        for claim in claims { try add("report:" + claim.id.uuidString, claim, [claim.sourceID]) }
        let byID = Dictionary(uniqueKeysWithValues: state.claims.filter(\.canonical).map { ($0.id, $0) })
        for var conflict in state.conflicts where entities.contains(conflict.entityID) || selected.contains("conflict:" + conflict.id) {
            conflict.claimIDs.sort { $0.uuidString < $1.uuidString }
            try add("conflict:" + conflict.id, conflict, conflict.claimIDs.compactMap { byID[$0]?.sourceID })
        }
        for var loop in state.loops where entities.contains(loop.entityID) || selected.contains("loop:" + loop.id) {
            loop.claimIDs.sort { $0.uuidString < $1.uuidString }
            try add("loop:" + loop.id, loop, loop.claimIDs.compactMap { byID[$0]?.sourceID })
        }
        for question in state.questions where selected.contains("question:" + question.id.uuidString) {
            try add("question:" + question.id.uuidString, question, [question.sourceID].compactMap { $0 })
        }
        for note in state.notes where selected.contains("note:" + note.id.uuidString) { try add("note:" + note.id.uuidString, note, []) }
        for field in handoff.profileFields ?? [] {
            switch field {
            case .name: try add("profile:name", state.profile.displayName, [])
            case .birthDate: try add("profile:birthDate", state.profile.birthDate, [])
            case .contact: try add("profile:contact", [state.profile.contactName, state.profile.contactPhone], [])
            }
        }
        let sourceIDs = Set(handoff.includedSourceIDs + stamps.flatMap(\.sourceIDs))
        let reportsBySource = Dictionary(grouping: state.claims.filter { $0.canonical && sourceIDs.contains($0.sourceID) }, by: \.sourceID)
        for source in state.sources where sourceIDs.contains(source.id) {
            // If a source is edited, re-analysis may create new report/entity IDs.
            // Watch reviewed content in the source as well, without silently merging the new entities.
            let sourceReports = (reportsBySource[source.id] ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
            let value = SourceFingerprint(title: source.title, kind: source.kind, capturedAt: source.capturedAt, eventAt: source.eventAt,
                provider: source.provider, version: source.version, originalHash: source.contentHash, workingHash: ContentHasher.hash(source.workingText), reviewedReportsHash: try digest(sourceReports))
            try add("source:" + source.id.uuidString, value, [source.id])
        }
        guard stamps.count <= 10_000 else { throw CareError.invalid("This handoff has too much linked context. Select fewer care items.") }
        return stamps.sorted { $0.id < $1.id }
    }

    public static func changes(for handoff: CareHandoff, in state: CareState, sinceFinished: Bool = false) throws -> [HandoffChange] {
        let baseline = sinceFinished ? (handoff.finishBaseline ?? handoff.baseline) : handoff.baseline
        let before = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, $0) })
        let after = Dictionary(uniqueKeysWithValues: try context(for: handoff, in: state).map { ($0.id, $0) })
        var titles: [String: String] = [:]
        for source in state.sources { titles["source:" + source.id.uuidString] = source.title }
        for claim in state.claims where claim.canonical { titles["report:" + claim.id.uuidString] = claim.summary }
        for conflict in state.conflicts { titles["conflict:" + conflict.id] = conflict.reason }
        for loop in state.loops { titles["loop:" + loop.id] = loop.title }
        for question in state.questions { titles["question:" + question.id.uuidString] = question.text }
        for note in state.notes { titles["note:" + note.id.uuidString] = "Personal context" }
        titles["profile:name"] = "Included patient name"; titles["profile:birthDate"] = "Included date of birth"; titles["profile:contact"] = "Included local contact"
        return Set(before.keys).union(after.keys).sorted().compactMap { id in
            guard before[id]?.digest != after[id]?.digest else { return nil }
            let kind: HandoffChangeKind = before[id] == nil ? .added : after[id] == nil ? .removed : .changed
            return HandoffChange(id: id, kind: kind, title: titles[id] ?? "Previously included " + String(id.prefix { $0 != ":" }),
                sourceIDs: (after[id]?.sourceIDs ?? before[id]?.sourceIDs ?? []).filter { state.source($0) != nil })
        }
    }

    @discardableResult public static func create(title: String, recipient: String, options: PacketOptions, in state: inout CareState, now: Date = Date()) throws -> UUID {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines), recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 200, recipient.count <= 200 else { throw CareError.invalid("Use a title and recipient of up to 200 characters.") }
        if let id = options.encounterID, !state.encounters.contains(where: { $0.id == id }) { throw CareError.invalid("This encounter was removed.") }
        let items = VisitPacketBuilder.items(state, encounterID: options.encounterID, now: now).filter { options.selectedIDs.contains($0.id) }
        guard !items.isEmpty, items.count <= 500, Set(items.map(\.id)) == options.selectedIDs else { throw CareError.invalid("Some selected items changed. Refresh the packet and select 1–500 available items.") }
        let text = VisitPacketBuilder.text(state, items: items, options: options, now: now)
        guard text.count <= 200_000 else { throw CareError.invalid("This outgoing copy is too long. Select fewer packet items.") }
        func sortedIDs(_ ids: [UUID]) -> [UUID] { Array(Set(ids)).sorted { $0.uuidString < $1.uuidString } }
        var handoff = CareHandoff(title: title, recipient: recipient, encounterID: options.encounterID, createdAt: now,
            selectedItemIDs: items.map(\.id).sorted(), entityIDs: sortedIDs(items.flatMap(\.entityIDs)), claimIDs: sortedIDs(items.flatMap(\.claimIDs)),
            includedSourceIDs: sortedIDs(items.flatMap(\.sourceIDs)), snapshotText: text, snapshotDigest: ContentHasher.hash(text), baseline: [], synthetic: items.contains(where: \.synthetic))
        handoff.profileFields = []
        if options.includeName { handoff.profileFields?.append(.name) }
        if options.includeBirthDate { handoff.profileFields?.append(.birthDate) }
        if options.includeContact { handoff.profileFields?.append(.contact) }
        handoff.baseline = try context(for: handoff, in: state)
        var next = state; if next.handoffs == nil { next.handoffs = HandoffMemory() }
        next.handoffs?.handoffs.append(handoff)
        try validate(next)
        next.audit.append(Audit(action: "handoff_prepared", count: items.count)); state = next
        return handoff.id
    }

    public static func recordShared(_ id: UUID, in state: inout CareState, now: Date = Date()) throws {
        let i = try index(id, state)
        guard now.timeIntervalSinceReferenceDate.isFinite, state.handoffs?.handoffs[i].snapshotText != nil else { throw CareError.invalid("The outgoing copy was removed with its evidence. Create a new packet.") }
        state.handoffs?.handoffs[i].sharedAt = now
        state.audit.append(Audit(action: "handoff_sharing_reported"))
    }
    public static func finish(_ id: UUID, in state: inout CareState, now: Date = Date()) throws {
        let i = try index(id, state)
        let baseline = try context(for: state.handoffs!.handoffs[i], in: state)
        var next = state
        next.handoffs?.handoffs[i].finishBaseline = baseline; next.handoffs?.handoffs[i].finishedAt = now
        try validate(next); next.audit.append(Audit(action: "handoff_finished_by_user")); state = next
    }
    public static func reopen(_ id: UUID, in state: inout CareState) throws {
        let i = try index(id, state); state.handoffs?.handoffs[i].finishedAt = nil; state.handoffs?.handoffs[i].finishBaseline = nil
        state.audit.append(Audit(action: "handoff_reopened"))
    }
    public static func saveReplyDraft(_ text: String, eventAt: Date?, handoffID: UUID, synthetic: Bool? = nil, in state: inout CareState) throws {
        let i = try index(handoffID, state)
        guard text.count <= 30_000, eventAt?.timeIntervalSinceReferenceDate.isFinite != false else { throw CareError.invalid("Keep the reply under 30,000 characters and use a valid date.") }
        var next = state; next.handoffs?.handoffs[i].replyDraft = text; next.handoffs?.handoffs[i].replyEventAt = eventAt
        if let synthetic { next.handoffs?.handoffs[i].replySynthetic = synthetic }
        try validate(next); state = next
    }
    /// A reply is the patient's saved account. It must pass the usual review gate.
    @discardableResult public static func captureReply(_ text: String, eventAt: Date?, handoffID: UUID, synthetic: Bool = false, in state: inout CareState, now: Date = Date()) throws -> UUID {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CareError.invalid("Add what you want to preserve from the reply.") }
        var next = state; try saveReplyDraft(text, eventAt: eventAt, handoffID: handoffID, synthetic: synthetic, in: &next)
        let i = try index(handoffID, next), handoff = next.handoffs!.handoffs[i]
        let hash = ContentHasher.hash(text)
        let id: UUID
        if let existing = next.sources.first(where: { handoff.replySourceIDs.contains($0.id) && $0.contentHash == hash && $0.eventAt == eventAt && $0.synthetic == synthetic }) {
            id = existing.id
        } else {
            var source = Source(title: String(("Reply I saved · " + handoff.title).prefix(200)), kind: .typed, text: text, contentHash: hash, eventAt: eventAt)
            source.capturedAt = now; source.encounterID = handoff.encounterID; source.state = .pending; source.synthetic = synthetic
            source.processingMessage = "Patient-saved reply. Review extracted reports before they enter care memory; this does not verify the speaker or medical correctness."
            next.sources.append(source); next.handoffs?.handoffs[i].replySourceIDs.append(source.id); id = source.id
        }
        next.handoffs?.handoffs[i].replyDraft = ""; next.handoffs?.handoffs[i].replyEventAt = nil
        next.handoffs?.handoffs[i].replySynthetic = nil
        try validate(next); next.audit.append(Audit(action: "handoff_reply_captured")); state = next
        return id
    }
    public static func remove(_ id: UUID, from state: inout CareState) {
        state.handoffs?.handoffs.removeAll { $0.id == id }; state.audit.append(Audit(action: "handoff_deleted"))
    }
    public static func removeSource(_ id: UUID, from state: inout CareState, now: Date = Date()) {
        guard var memory = state.handoffs else { return }
        for i in memory.handoffs.indices {
            if memory.handoffs[i].includedSourceIDs.contains(id) {
                memory.handoffs[i].snapshotText = nil; memory.handoffs[i].redactedAt = now
            }
            memory.handoffs[i].includedSourceIDs.removeAll { $0 == id }
            memory.handoffs[i].replySourceIDs.removeAll { $0 == id }
            memory.handoffs[i].baseline.removeAll { $0.sourceIDs.contains(id) }
            memory.handoffs[i].finishBaseline?.removeAll { $0.sourceIDs.contains(id) }
        }
        state.handoffs = memory
    }
    public static func detachEncounter(_ id: UUID, in state: inout CareState) {
        guard var memory = state.handoffs else { return }
        for i in memory.handoffs.indices where memory.handoffs[i].encounterID == id { memory.handoffs[i].encounterID = nil }
        state.handoffs = memory
    }
    private static func index(_ id: UUID, _ state: CareState) throws -> Int {
        guard let i = state.handoffs?.handoffs.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("This handoff was removed.") }
        return i
    }
    public static func validate(_ state: CareState) throws {
        guard let memory = state.handoffs else { return }
        guard memory.version == 1, memory.handoffs.count <= maximumHandoffs, Set(memory.handoffs.map(\.id)).count == memory.handoffs.count,
              memory.handoffs.reduce(0, { $0 + ($1.snapshotText?.count ?? 0) + $1.replyDraft.count }) <= maximumTextCharacters,
              memory.handoffs.reduce(0, { $0 + $1.baseline.count + ($1.finishBaseline?.count ?? 0) }) <= maximumStamps else {
            throw CareError.invalid("Handoff storage is full or unsupported. Remove an older handoff before saving another.")
        }
        let sourceIDs = Set(state.sources.map(\.id)), encounterIDs = Set(state.encounters.map(\.id))
        func validHash(_ text: String) -> Bool { text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
        for handoff in memory.handoffs {
            let dates = [handoff.createdAt, handoff.sharedAt, handoff.finishedAt, handoff.redactedAt, handoff.replyEventAt].compactMap { $0 }
            guard !handoff.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, handoff.title.count <= 200, handoff.recipient.count <= 200,
                  !handoff.selectedItemIDs.isEmpty, handoff.selectedItemIDs.count <= 500,
                  Set(handoff.selectedItemIDs).count == handoff.selectedItemIDs.count, handoff.selectedItemIDs.allSatisfy({ $0.count <= 500 }),
                  handoff.entityIDs.count <= 10_000, handoff.claimIDs.count <= 100_000, handoff.includedSourceIDs.count <= 10_000,
                  Set(handoff.profileFields ?? []).count == (handoff.profileFields?.count ?? 0),
                  handoff.replyDraft.count <= 30_000, handoff.replySourceIDs.count <= 1_000, (handoff.snapshotText?.count ?? 0) <= 200_000,
                  validHash(handoff.snapshotDigest), dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }),
                  Set(handoff.includedSourceIDs + handoff.replySourceIDs).isSubset(of: sourceIDs),
                  handoff.encounterID == nil || encounterIDs.contains(handoff.encounterID!),
                  (handoff.finishedAt == nil) == (handoff.finishBaseline == nil),
                  (handoff.redactedAt == nil) == (handoff.snapshotText != nil) else { throw CareError.invalid("This handoff contains invalid or missing information.") }
            if let text = handoff.snapshotText, ContentHasher.hash(text) != handoff.snapshotDigest { throw CareError.invalid("The saved outgoing copy does not match its content digest.") }
            for stamps in [handoff.baseline, handoff.finishBaseline ?? []] {
                guard stamps.count <= 10_000, Set(stamps.map(\.id)).count == stamps.count,
                      stamps.allSatisfy({ $0.id.count <= 500 && validHash($0.digest) && Set($0.sourceIDs).isSubset(of: sourceIDs) }) else { throw CareError.invalid("This handoff has invalid comparison references.") }
            }
        }
    }
}
