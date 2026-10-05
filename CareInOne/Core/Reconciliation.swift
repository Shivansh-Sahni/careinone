import Foundation

public enum Normalizer {
    public static func key(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    public static func quantity(_ value: Double, unit: String) -> (Double, String) {
        switch key(unit) {
        case "g", "gram", "grams": (value * 1000, "mg")
        case "mcg", "μg", "microgram", "micrograms": (value / 1000, "mg")
        case "mg", "milligram", "milligrams": (value, "mg")
        case "l", "liter", "litre": (value * 1000, "ml")
        default: (value, key(unit))
        }
    }
    public static func equivalent(_ a: Claim, _ b: Claim) -> Bool {
        let sameNumber: Bool
        if let av = a.numericValue, let bv = b.numericValue {
            let aq = quantity(av, unit: a.unit), bq = quantity(bv, unit: b.unit)
            sameNumber = aq.1 == bq.1 && abs(aq.0 - bq.0) < 0.000001
        } else { sameNumber = a.numericValue == b.numericValue && key(a.unit) == key(b.unit) }
        return a.kind == b.kind && key(a.label) == key(b.label) && a.action == b.action && sameNumber && key(a.value) == key(b.value) && key(a.route) == key(b.route) && key(a.frequency) == key(b.frequency) && key(a.form) == key(b.form) && a.negated == b.negated && a.conditional == b.conditional && a.subject == b.subject && a.dueAt == b.dueAt && a.eventAt == b.eventAt && a.certainty == b.certainty
            && a.effectiveAt == b.effectiveAt && a.intervalDays == b.intervalDays
            && a.duePrecision == b.duePrecision && a.dueTimeKnown == b.dueTimeKnown
            && a.codeSystem == b.codeSystem && a.code == b.code
            && a.provenance == b.provenance && a.speaker == b.speaker && a.speakerUncertain == b.speakerUncertain
            && a.supersedesID == b.supersedesID && a.relatedEntityID == b.relatedEntityID && a.relation == b.relation
    }
}
public struct EntityCandidate: Identifiable, Sendable {
    public var id: UUID; public var label: String; public var score: Double; public var reason: String
    public var automatic: Bool { score == 1 }
}
public protocol TerminologyAdapter: Sendable { func candidates(label: String, kind: EntityKind) async throws -> [EntityCandidate] }
public struct NoTerminologyAdapter: TerminologyAdapter {
    public init() {}
    public func candidates(label: String, kind: EntityKind) async throws -> [EntityCandidate] { [] }
}
public enum EntityResolver {
    public static func candidates(for claim: Claim, in entities: [Entity]) -> [EntityCandidate] {
        let key = Normalizer.key(claim.label)
        guard !key.isEmpty, !["unknown", "not provided", "name not provided", "unspecified"].contains(where: { key.contains($0) }) else { return [] }
        var candidates = entities.filter { $0.kind == claim.kind }.compactMap { entity -> EntityCandidate? in
            if let code = claim.code, !code.isEmpty, let system = claim.codeSystem, !system.isEmpty, entity.code == code, entity.codeSystem == system {
                return EntityCandidate(id: entity.id, label: entity.label, score: 1, reason: "Exact code and code system")
            }
            if let code = claim.code, !code.isEmpty, let system = claim.codeSystem, !system.isEmpty,
               system == entity.codeSystem, let entityCode = entity.code, !entityCode.isEmpty, code != entityCode {
                guard entity.normalizedKey == key || entity.aliases.contains(where: { Normalizer.key($0) == key }) else { return nil }
                return EntityCandidate(id: entity.id, label: entity.label, score: 0.89, reason: "Name matches but terminology codes differ; patient review required.")
            }
            if entity.normalizedKey == key { return EntityCandidate(id: entity.id, label: entity.label, score: 1, reason: "Exact normalized name") }
            if entity.aliases.contains(where: { Normalizer.key($0) == key }) { return EntityCandidate(id: entity.id, label: entity.label, score: 1, reason: "Patient-approved alias") }
            let a = Set(key.split(separator: " ")), b = Set(entity.normalizedKey.split(separator: " "))
            let similarity = Double(a.intersection(b).count) / Double(max(1, a.union(b).count))
            let edit = editSimilarity(key, entity.normalizedKey)
            let score = min(0.89, max(similarity, edit))
            guard score >= 0.65 else { return nil }
            return EntityCandidate(id: entity.id, label: entity.label, score: score, reason: "Similar name; review required. No automatic merge.")
        }.sorted { $0.score == $1.score ? $0.id.uuidString < $1.id.uuidString : $0.score > $1.score }
        if candidates.filter(\.automatic).count > 1 {
            for i in candidates.indices where candidates[i].automatic { candidates[i].score = 0.9; candidates[i].reason = "Multiple exact candidates; choose the correct item during review." }
        }
        return candidates
    }
    private static func editSimilarity(_ a: String, _ b: String) -> Double {
        let a = Array(a.prefix(120)), b = Array(b.prefix(120))
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var row = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var next = [i + 1]
            for (j, cb) in b.enumerated() { next.append(min(next[j] + 1, row[j + 1] + 1, row[j] + (ca == cb ? 0 : 1))) }
            row = next
        }
        return 1 - Double(row[b.count]) / Double(max(a.count, b.count))
    }
}
public enum CareError: LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { message } else { nil } }
}
public enum Reconciler {
    public static func accept(_ approved: [Claim], into state: inout CareState, now: Date = Date()) throws {
        var next = state
        for var claim in approved {
            guard let source = next.source(claim.sourceID) else { throw CareError.invalid("The supporting source is missing.") }
            try ProposalValidator.validate(claim, source: source)
            guard claim.subject == .patient else { throw CareError.invalid("Only claims about you can enter My Care.") }
            if let id = claim.entityID {
                guard let entity = next.entity(id), entity.kind == claim.kind else { throw CareError.invalid("Choose a matching entity category.") }
            } else if let exact = EntityResolver.candidates(for: claim, in: next.entities).first, exact.automatic {
                claim.entityID = exact.id
            } else {
                var entity = Entity(kind: claim.kind, label: claim.label)
                entity.code = claim.code; entity.codeSystem = claim.codeSystem
                next.entities.append(entity); claim.entityID = entity.id
            }
            if let predecessor = claim.supersedesID {
                guard let old = next.claims.first(where: { $0.id == predecessor && $0.canonical }), old.entityID == claim.entityID, old.id != claim.id else { throw CareError.invalid("Supersession must reference an accepted claim for the same item.") }
                // Only the patient may explicitly select supersession during review.
                guard claim.userEdited else { throw CareError.invalid("Replacing an earlier claim requires explicit patient review.") }
            }
            if let duplicate = next.claims.first(where: { $0.id != claim.id && $0.sourceID == claim.sourceID && $0.entityID == claim.entityID && $0.canonical && Normalizer.equivalent($0, claim) }) {
                next.relations.append(Relation(from: claim.id, to: duplicate.id, kind: .duplicateOf))
                claim.review = .rejected
            } else { claim.review = claim.userEdited ? .edited : .accepted; claim.acceptedAt = now }
            if let index = next.claims.firstIndex(where: { $0.id == claim.id }) { next.claims[index] = claim } else { next.claims.append(claim) }
        }
        next.audit.append(Audit(action: "claims_reviewed", count: approved.count))
        rebuild(&next, now: now)
        state = next
    }

    public static func rebuild(_ state: inout CareState, now: Date = Date()) {
        let sourceIDs = Set(state.sources.map(\.id))
        let canonical = state.claims.filter { $0.canonical && sourceIDs.contains($0.sourceID) }
            .sorted { a, b in
                let ad = a.acceptedAt ?? a.createdAt, bd = b.acceptedAt ?? b.createdAt
                return ad == bd ? a.id.uuidString < b.id.uuidString : ad < bd
            }
        let superseded = Set(canonical.compactMap(\.supersedesID))
        let oldConflicts = Dictionary(uniqueKeysWithValues: state.conflicts.map { ($0.id, $0) })
        // Duplicate proposals remain noncanonical analysis history, but their
        // explicit duplicate links must survive deterministic state rebuilding.
        let duplicateRelations = state.relations.filter { relation in
            guard relation.kind == .duplicateOf,
                  let rejected = state.claims.first(where: { $0.id == relation.from && $0.review == .rejected }),
                  let accepted = canonical.first(where: { $0.id == relation.to }),
                  rejected.sourceID == accepted.sourceID, rejected.entityID == accepted.entityID else { return false }
            return Normalizer.equivalent(rejected, accepted)
        }
        var relations: [Relation] = duplicateRelations, conflicts: [Conflict] = [], changes: [Change] = []
        var seen: [UUID: [Claim]] = [:]
        for claim in canonical {
            guard let eid = claim.entityID, let source = state.source(claim.sourceID) else { continue }
            let previous = seen[eid, default: []]
            relations.append(Relation(from: claim.id, to: eid, kind: .sameEntity))
            let duplicate = previous.first { Normalizer.equivalent($0, claim) }
            let kind: ChangeKind = claim.supersedesID != nil ? .superseded : previous.isEmpty ? .added : .changed
            if let duplicate { relations.append(Relation(from: claim.id, to: duplicate.id, kind: .supports)) }
            else { changes.append(change(claim, kind: kind, source: source, before: previous.last?.summary)) }
            if let old = claim.supersedesID { relations.append(Relation(from: claim.id, to: old, kind: .supersedes)) }
            if let related = claim.relatedEntityID, let relation = claim.relation, state.entity(related) != nil {
                relations.append(Relation(from: eid, to: related, kind: relation))
            }
            for old in previous where old.id != claim.supersedesID {
                guard let reason = conflictReason(old, claim) else { continue }
                let ids = [old.id, claim.id].sorted { $0.uuidString < $1.uuidString }
                let id = ids.map(\.uuidString).joined(separator: "|")
                var conflict = Conflict(id: id, entityID: eid, claimIDs: ids, reason: "\(claim.label): \(reason)", createdAt: claim.acceptedAt ?? now)
                if let saved = oldConflicts[id], saved.reason == conflict.reason { conflict.status = saved.status; conflict.note = saved.note; conflict.resolvedAt = saved.resolvedAt; conflict.createdAt = saved.createdAt }
                if superseded.contains(old.id) || superseded.contains(claim.id) {
                    conflict.status = .clarified
                    if conflict.note.isEmpty { conflict.note = "An earlier claim was explicitly superseded during patient review. Both reports remain in history." }
                    conflict.resolvedAt = canonical.first { $0.supersedesID == old.id || $0.supersedesID == claim.id }?.acceptedAt ?? conflict.createdAt
                }
                conflicts.append(conflict)
                relations.append(Relation(from: old.id, to: claim.id, kind: .conflictsWith))
                changes.append(change(claim, kind: .conflictIntroduced, source: source, before: old.summary, suffix: id))
                if conflict.status == .clarified {
                    var resolved = change(claim, kind: .conflictResolved, source: source, before: old.summary, suffix: id)
                    resolved.date = conflict.resolvedAt ?? now; changes.append(resolved)
                }
            }
            seen[eid, default: []].append(claim)
        }
        state.relations = Array(SetByID(relations))
        state.conflicts = conflicts
        let active = canonical.filter { !superseded.contains($0.id) }
        var loopEvidence = active
        // A result remains its own entity. Only an approved relation or a unique exact
        // terminology match can also contribute evidence to a test's state machine.
        for result in active where result.kind == .resultType && result.action == .resultAvailable && !result.negated && !result.conditional {
            let matchingTests = active.filter { test in
                guard test.kind == .labTest, !test.negated, !test.conditional else { return false }
                if result.relatedEntityID == test.entityID && [.resultOf, .completes].contains(result.relation) { return true }
                return result.code?.isEmpty == false && result.codeSystem?.isEmpty == false && result.code == test.code && result.codeSystem == test.codeSystem
            }
            let entities = Set(matchingTests.compactMap(\.entityID))
            guard entities.count == 1, let target = entities.first else { continue }
            var linked = result; linked.kind = .labTest; linked.entityID = target
            loopEvidence.append(linked); relations.append(Relation(from: result.id, to: target, kind: .resultOf))
        }
        let loops = LoopEngine.build(claims: loopEvidence, state: state)
        for loop in loops {
            if let first = canonical.first(where: { $0.id == loop.claimIDs.first }), let source = state.source(first.sourceID) {
                changes.append(change(first, kind: .loopOpened, source: source, before: nil, suffix: loop.id))
            }
            if loop.status == .completed, let last = canonical.first(where: { $0.id == loop.claimIDs.last }), let source = state.source(last.sourceID) {
                var c = change(last, kind: .loopClosed, source: source, before: nil, suffix: loop.id)
                c.date = state.loopOverrides[loop.id]?.updatedAt ?? last.acceptedAt ?? last.createdAt; changes.append(c)
            }
            if loop.claimIDs.count > 1, let first = loop.claimIDs.first, let last = loop.claimIDs.last, loop.status == .completed && !loop.userCompleted { relations.append(Relation(from: last, to: first, kind: .completes)) }
        }
        state.relations = Array(SetByID(relations)); state.loops = loops
        state.changes = changes.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
        state.entities.removeAll { e in !canonical.contains { $0.entityID == e.id } && !state.claims.contains { $0.entityID == e.id && $0.review == .pending } }
        let entityIDs = Set(state.entities.map(\.id))
        for i in state.questions.indices { if let id = state.questions[i].entityID, !entityIDs.contains(id) { state.questions[i].entityID = nil } }
        for i in state.notes.indices { if let id = state.notes[i].entityID, !entityIDs.contains(id) { state.notes[i].entityID = nil } }
        let validLoops = Set(loops.map(\.id)); state.loopOverrides = state.loopOverrides.filter { validLoops.contains($0.key) }
        FollowThroughAssistEngine.pruneUnavailableLoops(in: &state)
    }
    private static func SetByID(_ relations: [Relation]) -> [Relation] {
        var ids = Set<String>(); return relations.filter { ids.insert($0.id).inserted }
    }
    private static func change(_ claim: Claim, kind: ChangeKind, source: Source, before: String?, suffix: String = "") -> Change {
        Change(id: "\(claim.id)|\(kind.rawValue)|\(suffix)", setID: source.id, kind: kind, entityID: claim.entityID!, sourceID: source.id, claimID: claim.id, before: before, after: claim.summary, date: claim.acceptedAt ?? claim.createdAt, category: claim.kind, encounterID: source.encounterID)
    }
    public static func conflictReason(_ a: Claim, _ b: Claim) -> String? {
        guard a.entityID == b.entityID, a.kind == b.kind, a.subject == .patient, b.subject == .patient,
              !a.conditional, !b.conditional, ![.historical, .superseded].contains(a.certainty), ![.historical, .superseded].contains(b.certainty) else { return nil }
        if a.negated != b.negated { return "presence or absence differs" }
        if a.negated && b.negated { return nil }
        if a.kind == .medication {
            let active: Set<ClaimAction> = [.taking, .started, .changed]
            if (a.action == .stopped && active.contains(b.action)) || (b.action == .stopped && active.contains(a.action)) { return "start/stop status differs" }
            if let av = a.numericValue, let bv = b.numericValue {
                let x = Normalizer.quantity(av, unit: a.unit), y = Normalizer.quantity(bv, unit: b.unit)
                if x.1 != y.1 || abs(x.0 - y.0) > 0.000001 { return "dose differs" }
            }
            for (x, y, name) in [(a.route, b.route, "route"), (a.frequency, b.frequency, "frequency"), (a.form, b.form, "form")] {
                if !x.isEmpty && !y.isEmpty && Normalizer.key(x) != Normalizer.key(y) { return "\(name) differs" }
            }
        }
        if [.medication, .allergy, .instruction].contains(a.kind), !a.value.isEmpty, !b.value.isEmpty, Normalizer.key(a.value) != Normalizer.key(b.value) { return "saved instructions differ" }
        if a.kind == .appointment, let x = a.dueAt, let y = b.dueAt {
            let differs = a.dueTimeKnown && b.dueTimeKnown
                ? abs(x.timeIntervalSince(y)) > 60
                : !Calendar.current.isDate(x, inSameDayAs: y)
            if differs { return "appointment date/time differs" }
        }
        if a.kind == .followUp {
            if let x = a.intervalDays, let y = b.intervalDays, x != y { return "follow-up interval differs" }
            if let x = a.dueAt, let y = b.dueAt, !Calendar.current.isDate(x, inSameDayAs: y) { return "follow-up date differs" }
        }
        return nil
    }
    public static func deleteSource(_ id: UUID, from state: inout CareState) {
        let linkedEncounter = state.source(id)?.encounterID
        ContinuityEngine.removeSource(id, from: &state)
        HandoffEngine.removeSource(id, from: &state)
        VisitCompanionEngine.removeSource(id, from: &state)
        FollowThroughAssistEngine.removeSource(id, from: &state)
        let removedIDs = Set(state.claims.filter { $0.sourceID == id }.map(\.id))
        state.sources.removeAll { $0.id == id }; state.claims.removeAll { $0.sourceID == id }
        for index in state.claims.indices where state.claims[index].supersedesID.map(removedIDs.contains) == true { state.claims[index].supersedesID = nil }
        state.questions.removeAll { $0.sourceID == id }
        state.encounters.removeAll { encounter in encounter.id == linkedEncounter && !state.sources.contains { $0.encounterID == encounter.id }
            && !(state.continuity?.workspaces.contains { $0.encounterID == encounter.id } ?? false)
            && !(state.continuity?.checkpoints.contains { $0.encounterID == encounter.id } ?? false)
            && !(state.handoffs?.handoffs.contains { $0.encounterID == encounter.id } ?? false)
            && !(state.visitCompanions?.sessions.contains { $0.encounterID == encounter.id } ?? false) }
        state.audit.append(Audit(action: "source_deleted")); rebuild(&state)
        let entityIDs = Set(state.entities.map(\.id)), encounterIDs = Set(state.encounters.map(\.id))
        for i in state.questions.indices {
            if let entity = state.questions[i].entityID, !entityIDs.contains(entity) { state.questions[i].entityID = nil }
            if let encounter = state.questions[i].encounterID, !encounterIDs.contains(encounter) { state.questions[i].encounterID = nil }
        }
        for i in state.notes.indices { if let entity = state.notes[i].entityID, !entityIDs.contains(entity) { state.notes[i].entityID = nil } }
    }
}
