import Foundation

public enum ReadinessKind: String, CaseIterable, Sendable {
    case disagreement = "Records to clarify", unreviewed = "Evidence awaiting review"
    case question = "Questions to bring", followThrough = "Unfinished work", uncertain = "Meaning or timing to clarify"
}
public struct ReadinessItem: Identifiable, Sendable {
    public var id: String
    public var kind: ReadinessKind
    public var title: String
    public var explanation: String
    public var sourceIDs: [UUID]
    public var entityID: UUID?
    public var questionID: UUID?
}
/// An evidence checklist, never a medical readiness score or proof that outside care is complete.
public enum VisitReadiness {
    public static func items(_ state: CareState, encounterID: UUID? = nil, now: Date = Date()) -> [ReadinessItem] {
        var result: [ReadinessItem] = []
        let claims = Dictionary(uniqueKeysWithValues: state.claims.filter(\.canonical).map { ($0.id, $0) })
        func sources(_ ids: [UUID]) -> [UUID] { Array(Set(ids.compactMap { claims[$0]?.sourceID })).sorted { $0.uuidString < $1.uuidString } }
        for conflict in state.conflicts where conflict.status == .unresolved {
            result.append(ReadinessItem(id: "conflict:" + conflict.id, kind: .disagreement, title: conflict.reason,
                explanation: "Different saved reports remain unresolved. Bring both sources; this app does not choose which instruction is correct.",
                sourceIDs: sources(conflict.claimIDs), entityID: conflict.entityID))
        }
        let pendingSources = Set(state.claims.filter { $0.review == .pending }.map(\.sourceID))
        for source in state.sources where source.state != .complete || pendingSources.contains(source.id) {
            result.append(ReadinessItem(id: "source:" + source.id.uuidString, kind: .unreviewed, title: source.title,
                explanation: source.state.displayLabel + ". Original evidence is saved. Unaccepted proposals do not enter your care comparison.", sourceIDs: [source.id]))
        }
        for question in state.questions where !question.answered && (encounterID == nil || question.encounterID == nil || question.encounterID == encounterID) {
            result.append(ReadinessItem(id: "question:" + question.id.uuidString, kind: .question, title: question.text,
                explanation: "A saved question has no answer marked here. Writing an answer does not independently verify clinical instructions.",
                sourceIDs: question.sourceID.map { [$0] } ?? [], entityID: question.entityID, questionID: question.id))
        }
        for loop in state.loops where [.open, .uncertain].contains(loop.status) {
            result.append(ReadinessItem(id: "loop:" + loop.id, kind: .followThrough, title: loop.title,
                explanation: loop.timing(now: now) + " Earlier unfinished work remains visible for this visit.", sourceIDs: sources(loop.claimIDs), entityID: loop.entityID))
        }
        for claim in state.unsupersededClaims where claim.certainty != .historical {
            var reasons: [String] = []
            if claim.conditional || claim.certainty == .conditional { reasons.append("Conditional wording has been preserved; it does not establish an order.") }
            if [.unknown, .uncertain, .notProvided, .disputed].contains(claim.certainty) { reasons.append("The accepted report retains an uncertain or incomplete state.") }
            if claim.kind == .appointment && claim.dueAt == nil { reasons.append("No appointment date is provided here.") }
            guard !reasons.isEmpty else { continue }
            result.append(ReadinessItem(id: "claim:" + claim.id.uuidString, kind: .uncertain, title: claim.summary,
                explanation: reasons.joined(separator: " "), sourceIDs: [claim.sourceID], entityID: claim.entityID))
        }
        let order = Dictionary(uniqueKeysWithValues: ReadinessKind.allCases.enumerated().map { ($0.element, $0.offset) })
        return result.sorted { order[$0.kind] == order[$1.kind] ? $0.id < $1.id : order[$0.kind]! < order[$1.kind]! }
    }
}
