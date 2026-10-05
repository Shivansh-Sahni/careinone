import Foundation

public struct SearchHit: Identifiable, Sendable {
    public var id: String; public var title: String; public var excerpt: String; public var type: String; public var sourceID: UUID?; public var entityID: UUID?; public var score: Int
}
public enum SearchEngine {
    static func tokens(_ query: String) -> Set<String> {
        Set(Normalizer.key(query).split(separator: " ").map(String.init)).subtracting(["what", "when", "the", "my", "did", "do", "is", "was", "about", "i", "a", "to", "of", "and", "am", "saved", "show", "me", "information", "care"])
    }
    static func score(_ text: String, tokens: Set<String>) -> Int {
        let words = Set(Normalizer.key(text).split(separator: " ").map(String.init))
        return tokens.filter { token in words.contains(token) || (token.count >= 3 && words.contains { $0.hasPrefix(token) }) }.count
    }
    public static func search(_ query: String, state: CareState) -> [SearchHit] {
        let tokens = tokens(query)
        guard !tokens.isEmpty else { return [] }
        func score(_ text: String) -> Int { Self.score(text, tokens: tokens) }
        var hits: [SearchHit] = []
        for source in state.sources {
            let versions = [("Working text", source.workingText), ("Original text", source.originalText)] + source.previousText.enumerated().map { ("Earlier text \($0.offset + 1)", $0.element) }
            let matches = versions.map { (type: $0.0, text: $0.1, relevance: score($0.1)) }
            guard let match = matches.max(by: { $0.relevance < $1.relevance }) else { continue }
            let s = score(source.title + " " + source.provider) + match.relevance
            if s > 0 {
                let line = match.text.components(separatedBy: .newlines).map { (text: $0, relevance: score($0)) }.max(by: { $0.relevance < $1.relevance })?.text ?? ""
                hits.append(SearchHit(id: source.id.uuidString, title: source.title, excerpt: String(line.prefix(700)), type: "Source · " + match.type.lowercased(), sourceID: source.id, score: s))
            }
        }
        for entity in state.entities {
            let s = score(entity.label + " " + entity.aliases.joined(separator: " "))
            if s > 0 { hits.append(SearchHit(id: entity.id.uuidString, title: entity.label, excerpt: state.projection(for: entity.id).rawValue, type: "My Care", entityID: entity.id, score: s + 1)) }
        }
        for claim in state.claims where claim.canonical {
            let s = score(claim.summary + " " + claim.quote)
            if s > 0 { hits.append(SearchHit(id: claim.id.uuidString, title: claim.summary, excerpt: claim.quote, type: "Reviewed claim", sourceID: claim.sourceID, entityID: claim.entityID, score: s + 2)) }
        }
        for question in state.questions where score(question.text + " " + question.answer) > 0 { hits.append(SearchHit(id: question.id.uuidString, title: question.text, excerpt: question.answer, type: "Question", sourceID: question.sourceID, entityID: question.entityID, score: score(question.text))) }
        for note in state.notes where score(note.text) > 0 { hits.append(SearchHit(id: note.id.uuidString, title: "Patient note", excerpt: note.text, type: "Note", entityID: note.entityID, score: score(note.text))) }
        return hits.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
    }
}
public struct GroundedExcerpt: Identifiable, Sendable { public var id: UUID; public var summary: String; public var quote: String; public var sourceID: UUID; public var eventAt: Date?; public var disputed: Bool; public var context: String }
public protocol SynthesisProvider: Sendable { func answer(_ query: String, state: CareState) async throws -> [GroundedExcerpt] }
public struct LocalGroundedSynthesis: SynthesisProvider {
    public init() {}
    public func answer(_ query: String, state: CareState) async throws -> [GroundedExcerpt] {
        let tokens = SearchEngine.tokens(query)
        guard !tokens.isEmpty else { return [] }
        var ranked: [(Claim, Int)] = []
        for claim in state.claims where claim.canonical {
            let entity = state.entity(claim.entityID)
            let parts = [claim.summary, claim.quote, entity?.aliases.joined(separator: " ") ?? "", state.source(claim.sourceID)?.provider ?? ""]
            let score = SearchEngine.score(parts.joined(separator: " "), tokens: tokens)
            if score > 0 { ranked.append((claim, score)) }
        }
        ranked.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            if lhs.0.eventAt != rhs.0.eventAt { return (lhs.0.eventAt ?? .distantPast) > (rhs.0.eventAt ?? .distantPast) }
            return lhs.0.id.uuidString < rhs.0.id.uuidString
        }
        let superseded = Set(state.claims.filter(\.canonical).compactMap(\.supersedesID))
        return ranked.prefix(12).map { c, _ in
            let context = (superseded.contains(c.id) ? "Superseded" : c.certainty.displayLabel) + " · " + c.action.displayLabel + " · " + c.provenance.displayLabel
            return GroundedExcerpt(id: c.id, summary: c.summary, quote: c.quote, sourceID: c.sourceID, eventAt: c.eventAt, disputed: state.conflicts.contains { $0.status == .unresolved && $0.claimIDs.contains(c.id) }, context: context)
        }
    }
}
public enum BriefBuilder {
    public static func text(_ state: CareState, now: Date = Date()) -> String {
        var lines = ["CAREINONE · PATIENT CARE BRIEF", "Prepared \(now.formatted(date: .abbreviated, time: .shortened))", state.profile.displayName.isEmpty ? "Patient name not provided" : state.profile.displayName,
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
