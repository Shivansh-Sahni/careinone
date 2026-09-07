import Foundation

public struct SearchHit: Identifiable, Sendable {
    public var id: String; public var title: String; public var excerpt: String; public var type: String; public var sourceID: UUID?; public var entityID: UUID?; public var score: Int
}
public enum SearchEngine {
    public static func search(_ query: String, state: CareState) -> [SearchHit] {
        let tokens = Set(Normalizer.key(query).split(separator: " ").map(String.init)).subtracting(["what", "when", "the", "my", "did", "do", "is", "was", "about", "i", "a", "to", "of", "and", "am"])
        guard !tokens.isEmpty else { return [] }
        func score(_ text: String) -> Int { let key = Normalizer.key(text); return tokens.filter { key.contains($0) }.count }
        var hits: [SearchHit] = []
        for source in state.sources {
            let s = score(source.title + " " + source.workingText + " " + source.provider)
            if s > 0 {
                let line = source.workingText.components(separatedBy: .newlines).max { score($0) < score($1) } ?? ""
                hits.append(SearchHit(id: source.id.uuidString, title: source.title, excerpt: String(line.prefix(700)), type: "Source", sourceID: source.id, score: s))
            }
        }
        for entity in state.entities {
            let s = score(entity.label + " " + entity.aliases.joined(separator: " "))
            if s > 0 { hits.append(SearchHit(id: entity.id.uuidString, title: entity.label, excerpt: state.projection(for: entity.id).rawValue, type: "My Care", entityID: entity.id, score: s + 1)) }
        }
        for question in state.questions where score(question.text + " " + question.answer) > 0 { hits.append(SearchHit(id: question.id.uuidString, title: question.text, excerpt: question.answer, type: "Question", sourceID: question.sourceID, entityID: question.entityID, score: score(question.text))) }
        for note in state.notes where score(note.text) > 0 { hits.append(SearchHit(id: note.id.uuidString, title: "Patient note", excerpt: note.text, type: "Note", entityID: note.entityID, score: score(note.text))) }
        return hits.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
    }
}
public struct GroundedExcerpt: Identifiable, Sendable { public var id: UUID; public var summary: String; public var quote: String; public var sourceID: UUID; public var eventAt: Date?; public var disputed: Bool }
public protocol SynthesisProvider: Sendable { func answer(_ query: String, state: CareState) async throws -> [GroundedExcerpt] }
public struct LocalGroundedSynthesis: SynthesisProvider {
    public init() {}
    public func answer(_ query: String, state: CareState) async throws -> [GroundedExcerpt] {
        let hits = SearchEngine.search(query, state: state)
        let sourceIDs = Set(hits.compactMap(\.sourceID)), entityIDs = Set(hits.compactMap(\.entityID))
        return state.claims.filter { $0.canonical && (sourceIDs.contains($0.sourceID) || $0.entityID.map(entityIDs.contains) == true) }.sorted { ($0.eventAt ?? .distantPast) > ($1.eventAt ?? .distantPast) }.prefix(12).map { c in
            GroundedExcerpt(id: c.id, summary: c.summary, quote: c.quote, sourceID: c.sourceID, eventAt: c.eventAt, disputed: state.conflicts.contains { $0.status == .unresolved && $0.claimIDs.contains(c.id) })
        }
    }
}
public enum BriefBuilder {
    public static func text(_ state: CareState, now: Date = Date()) -> String {
        var lines = ["CARECONTINUITY · PATIENT CARE BRIEF", "Prepared \(now.formatted(date: .abbreviated, time: .shortened))", state.profile.displayName.isEmpty ? "Patient name not provided" : state.profile.displayName,
                     "Based only on saved, patient-reviewed reports. Incomplete information remains unknown. This brief does not verify clinical correctness."]
        if state.profile.demoLoaded { lines.append("INCLUDES SYNTHETIC DEMO DATA — not a real patient's clinical record.") }
        if let birth = state.profile.birthDate { lines.append("DOB: \(birth.formatted(date: .abbreviated, time: .omitted))") }
        if !state.profile.contactName.isEmpty { lines.append("Local contact: \(state.profile.contactName) \(state.profile.contactPhone)") }
        let superseded = Set(state.relations.filter { $0.kind == .supersedes }.map(\.to))
        for kind in EntityKind.allCases {
            let claims = state.claims.filter { $0.canonical && $0.kind == kind && !superseded.contains($0.id) && $0.certainty != .historical }
            guard !claims.isEmpty else { continue }; lines.append("\n\(kind.title.uppercased())")
            for claim in claims {
                let source = state.source(claim.sourceID)
                lines.append("• \(claim.summary) | \(claim.action.rawValue) | \(claim.certainty.rawValue) | \(claim.provenance.rawValue)" + (claim.conditional ? " | CONDITIONAL" : "") + (claim.negated ? " | NEGATED" : ""))
                lines.append("  Event: \(claim.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "unknown"). Source: \(source?.title ?? "unknown") [\(claim.sourceID.uuidString.prefix(8))]" + (claim.page.map { ", page \($0)" } ?? ""))
            }
        }
        lines.append("\nRECORDS TO CLARIFY")
        let conflicts = state.conflicts.filter { $0.status == .unresolved }
        if conflicts.isEmpty { lines.append("No unresolved discrepancies identified in the information saved here.") }
        for c in conflicts { lines.append("• \(c.reason)"); lines.append("  \(c.question)") }
        lines.append("\nFOLLOW-THROUGH")
        for loop in state.loops where [.open, .uncertain].contains(loop.status) { lines.append("• \(loop.title): \(loop.stage.rawValue). \(loop.timing(now: now))"); if !loop.note.isEmpty { lines.append("  Patient note: \(loop.note)") } }
        lines.append("\nQUESTIONS TO BRING")
        for question in state.questions where !question.answered { lines.append("• " + question.text) }
        lines.append("\nSources are preserved on the patient's iPhone. Confirm care decisions with the treating team.")
        return lines.joined(separator: "\n")
    }
}
