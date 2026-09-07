import Foundation
import CryptoKit

public enum ContentHasher {
    public static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func hash(_ text: String) -> String { hash(Data(text.utf8)) }
    public static func cacheKey(_ source: Source, version: String) -> String {
        hash(source.contentHash + "|" + source.workingText + "|" + (source.eventAt?.ISO8601Format() ?? "unknown") + "|" + version)
    }
}
public struct TextChunk: Sendable, Equatable { public var index: Int; public var text: String; public var start: Int }
public enum Chunker {
    public static func split(_ text: String, size: Int = 10000, overlap: Int = 500) -> [TextChunk] {
        guard size > 0, overlap >= 0, overlap < size else { return [] }
        let chars = Array(text); var start = 0; var result: [TextChunk] = []
        while start < chars.count {
            let end = min(start + size, chars.count)
            result.append(TextChunk(index: result.count, text: String(chars[start..<end]), start: start))
            if end == chars.count { break }; start = end - overlap
        }
        return result
    }
}
public enum ProposalValidator {
    public static let maximumClarifications = 3
    public static let version = "care-schema-1.0"
    public static func validate(_ claim: Claim, source: Source) throws {
        guard claim.sourceID == source.id else { throw CareError.invalid("Source identity does not match.") }
        guard !claim.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, claim.label.count <= 200 else { throw CareError.invalid("A claim must have a label of 1–200 characters.") }
        guard !claim.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, claim.quote.count <= 6000, source.workingText.contains(claim.quote) else { throw CareError.invalid("The exact supporting quote could not be found. Edit the proposal or preserve it as a note.") }
        if let page = claim.page { guard source.pages.contains(where: { $0.number == page && $0.text.contains(claim.quote) }) else { throw CareError.invalid("The quote does not match the proposed page.") } }
        guard claim.confidence.isFinite, (0...1).contains(claim.confidence) else { throw CareError.invalid("Invalid extraction confidence.") }
        if let number = claim.numericValue { guard number.isFinite else { throw CareError.invalid("Numeric values must be finite.") } }
        guard claim.value.count <= 4000, claim.unit.count <= 80, claim.route.count <= 200, claim.frequency.count <= 200, claim.form.count <= 200 else { throw CareError.invalid("Proposal fields exceed allowed length.") }
        if let days = claim.intervalDays { guard (0...36500).contains(days) else { throw CareError.invalid("Follow-up interval is outside supported bounds.") } }
        if let seconds = claim.transcriptSeconds {
            guard seconds.isFinite && seconds >= 0, let verified = LocalExtractor.transcriptLocation(claim.quote, source: source), abs(verified - seconds) < 0.01 else { throw CareError.invalid("Transcript location was not verified against the original recording transcript.") }
        }
        if claim.duePrecision != .unknown && claim.dueAt == nil && claim.intervalDays == nil { throw CareError.invalid("Due-date confidence requires a date or interval.") }
    }
    public static func deduplicate(_ claims: [Claim]) -> [Claim] {
        var result: [Claim] = []
        for claim in claims where !result.contains(where: { $0.sourceID == claim.sourceID && $0.page == claim.page && Normalizer.equivalent($0, claim) && $0.quote == claim.quote }) { result.append(claim) }
        return result
    }
    public static func clarifications(_ claims: [Claim]) -> [String] {
        var result: [String] = []
        for claim in claims {
            let question: String?
            if claim.subject != .patient { question = "Is ‘\(claim.label)’ about you or someone else?" }
            else if claim.conditional { question = "Was ‘\(claim.label)’ a definite plan or only something to consider?" }
            else if claim.eventAt == nil { question = "When did ‘\(claim.label)’ happen? It is okay to leave this unknown." }
            else if claim.confidence < 0.7 { question = "Does ‘\(claim.label)’ accurately reflect what was reported?" }
            else { question = claim.clarification }
            if let question, !result.contains(question) { result.append(question) }
            if result.count == maximumClarifications { break }
        }
        return result
    }
}
public protocol ExtractionProvider: Sendable {
    var version: String { get }
    func extract(source: Source) async throws -> [Claim]
}
public struct LocalExtractor: ExtractionProvider {
    public let version = "local-conservative-1.0"
    public init() {}
    public func extract(source: Source) async throws -> [Claim] { try Self.proposals(source) }
    public static func proposals(_ source: Source) throws -> [Claim] {
        var claims: [Claim] = []
        let sections = source.pages.isEmpty ? [EvidencePage(number: 0, text: source.workingText)] : source.pages
        for section in sections {
            let lines = section.text.components(separatedBy: .newlines).flatMap { Chunker.split($0, size: 5500, overlap: 300).map(\.text) }
            for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try Task.checkCancellation()
                let quote = String(line.prefix(6000)); let lower = quote.lowercased()
                var kind: EntityKind = .other; var action: ClaimAction = .mentioned
                var label = String(quote.prefix(100)); var numeric: Double?; var unit = ""
                let dosePattern = #"(?i)\b([a-z][a-z-]{2,}(?:\s+(?:succinate|tartrate|hydrochloride))?)\s+(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml)\b"#
                if let match = match(dosePattern, quote), match.count >= 4, !["take", "dose", "increase", "decrease", "given"].contains(match[1].lowercased()) {
                    kind = .medication; label = match[1]; numeric = Double(match[2]); unit = match[3]
                    action = contains(lower, ["stop", "discontinue"]) ? .stopped : contains(lower, ["start", "begin"]) ? .started : contains(lower, ["increase", "decrease", "change"]) ? .changed : .taking
                } else if lower.hasPrefix("allergy:") || lower.hasPrefix("allergies:") { kind = .allergy; label = afterColon(quote) }
                else if lower.hasPrefix("condition:") { kind = .condition; label = afterColon(quote) }
                else if lower.hasPrefix("provider:") { kind = .provider; label = afterColon(quote) }
                else if contains(lower, ["referral", "referred"]) { kind = .referral; action = contains(lower, ["placed", "referred"]) ? .referralPlaced : .requested }
                else if contains(lower, ["follow up", "follow-up", "return in"]) { kind = .followUp; action = .requested }
                else if contains(lower, ["appointment", "scheduled visit"]) { kind = .appointment; action = .scheduled }
                else if contains(lower, ["blood test", "lab test", "mri", "ct scan", "echocardiogram", "cbc", "a1c"]) {
                    kind = .labTest
                    for name in ["echocardiogram", "ct scan", "MRI", "CBC", "A1c", "blood test", "lab test"] where lower.contains(name.lowercased()) { label = name; break }
                    action = contains(lower, ["result available", "result:"]) ? .resultAvailable : contains(lower, ["completed", "performed"]) ? .completed : contains(lower, ["scheduled"]) ? .scheduled : contains(lower, ["ordered", "requested", "obtain"]) ? .ordered : .mentioned
                } else if lower.hasPrefix("procedure:") { kind = .procedure; label = afterColon(quote); action = contains(lower, ["scheduled"]) ? .scheduled : contains(lower, ["planned", "ordered"]) ? .planned : .mentioned }
                else if lower.hasPrefix("task:") { kind = .administrativeTask; label = afterColon(quote); action = .requested }
                else if lower.hasPrefix("instruction:") { kind = .instruction; label = afterColon(quote) }
                var claim = Claim(sourceID: source.id, kind: kind, label: label, quote: quote)
                claim.action = action; claim.numericValue = numeric; claim.unit = unit; claim.eventAt = source.eventAt
                claim.page = section.number == 0 ? nil : section.number
                claim.transcriptSeconds = transcriptLocation(quote, source: source)
                claim.provenance = [.pdf, .photo, .fhir].contains(source.kind) ? .documentDerived : .patientReported
                claim.certainty = claim.provenance == .documentDerived ? .documented : .reported
                claim.confidence = kind == .other ? 0.5 : 0.7
                claim.conditional = contains(lower, ["consider", "if needed", "might", "may need", "possibly", "could", "if "])
                if claim.conditional { claim.certainty = .conditional }
                claim.negated = contains(lower, ["no ", "not ", "denies", "without ", "never "])
                if contains(lower, ["mother", "father", "sister", "brother", "family history"]) { claim.subject = .family }
                else if contains(lower, ["my wife", "my husband", "my child", "my partner"]) { claim.subject = .other }
                if contains(lower, ["previously", "historical", "used to"]) { claim.certainty = .historical }
                if contains(lower, ["unsure", "not sure", "uncertain"]) { claim.certainty = .uncertain }
                if let speaker = match(#"^(Doctor|Dr\.[^:]{1,60}|Nurse|Patient|Me):"#, quote)?.dropFirst().first { claim.speaker = speaker; claim.speakerUncertain = true }
                for f in ["twice daily", "once daily", "three times daily", "daily", "weekly", "as needed"] where lower.contains(f) { claim.frequency = f; break }
                for r in ["oral", "topical", "intravenous", "subcutaneous"] where lower.contains(r) { claim.route = r; break }
                for f in ["extended release", "tablet", "capsule", "liquid"] where lower.contains(f) { claim.form = f; break }
                if let interval = match(#"(?i)\bin\s+(\d+)\s+(day|week|month)s?\b"#, quote), let number = Int(interval[1]) {
                    if interval[2].lowercased() != "month" { claim.intervalDays = number * (interval[2].lowercased() == "week" ? 7 : 1) }
                    if let event = source.eventAt {
                        let component: Calendar.Component = interval[2].lowercased() == "month" ? .month : .day
                        claim.dueAt = Calendar(identifier: .gregorian).date(byAdding: component, value: component == .month ? number : claim.intervalDays!, to: event)
                        claim.duePrecision = .approximate
                    }
                }
                if let date = match(#"\b(\d{4}-\d{2}-\d{2})\b"#, quote)?.dropFirst().first.flatMap(DateParser.parse) { claim.dueAt = date; claim.duePrecision = .exact }
                claim.extractionVersion = "local-conservative-1.0"
                try ProposalValidator.validate(claim, source: source); claims.append(claim)
                if claims.count >= 200 { return claims }
            }
        }
        return ProposalValidator.deduplicate(claims)
    }
    private static func afterColon(_ s: String) -> String { String(s.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces) }
    private static func contains(_ s: String, _ terms: [String]) -> Bool { terms.contains { s.contains($0) } }
    static func match(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
    }
    public static func transcriptLocation(_ quote: String, source: Source) -> Double? {
        guard source.originalText == source.workingText, let range = source.workingText.range(of: quote) else { return nil }
        let start = NSRange(range, in: source.workingText).location
        return source.transcriptSegments.first { $0.startUTF16 <= start && start < $0.startUTF16 + $0.lengthUTF16 }?.seconds
    }
}
public enum DateParser {
    public static func parse(_ string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard string.count == 10 else { return nil }; return formatter.date(from: string)
    }
}
public struct WireProposal: Codable, Sendable {
    public var kind: EntityKind; public var label: String; public var quote: String
    public var action: ClaimAction?; public var value: String?; public var numericValue: Double?; public var unit: String?
    public var route: String?; public var frequency: String?; public var form: String?; public var eventDate: String?; public var effectiveDate: String?; public var dueDate: String?
    public var duePrecision: DuePrecision?; public var intervalDays: Int?; public var page: Int?; public var transcriptSeconds: Double?
    public var subject: Subject?; public var speaker: String?; public var speakerUncertain: Bool?; public var certainty: Certainty?
    public var negated: Bool?; public var conditional: Bool?; public var confidence: Double?; public var clarification: String?
    public var code: String?; public var codeSystem: String?
    public func claim(source: Source, version: String) throws -> Claim {
        var c = Claim(sourceID: source.id, kind: kind, label: label, quote: quote)
        c.action = action ?? .mentioned; c.value = value ?? ""; c.numericValue = numericValue; c.unit = unit ?? ""
        c.route = route ?? ""; c.frequency = frequency ?? ""; c.form = form ?? ""
        for date in [eventDate, effectiveDate, dueDate].compactMap({ $0 }) { guard DateParser.parse(date) != nil else { throw CareError.invalid("Analysis returned an invalid date.") } }
        c.eventAt = eventDate.flatMap(DateParser.parse) ?? source.eventAt; c.effectiveAt = effectiveDate.flatMap(DateParser.parse)
        c.dueAt = dueDate.flatMap(DateParser.parse); c.duePrecision = duePrecision ?? .unknown; c.intervalDays = intervalDays
        if kind == .appointment, dueDate == nil, let explicitDate = eventDate.flatMap(DateParser.parse) { c.dueAt = explicitDate; c.duePrecision = duePrecision ?? .exact }
        c.dueTimeKnown = (dueDate ?? (kind == .appointment ? eventDate : nil))?.contains("T") == true
        c.page = page; c.transcriptSeconds = LocalExtractor.transcriptLocation(quote, source: source); c.subject = subject ?? .unknown; c.speaker = speaker; c.speakerUncertain = speakerUncertain ?? true
        c.certainty = certainty ?? .uncertain; c.negated = negated ?? false; c.conditional = conditional ?? false; c.confidence = confidence ?? 0
        c.provenance = [.pdf, .photo, .fhir].contains(source.kind) ? .documentDerived : .patientReported
        c.clarification = clarification; c.code = code; c.codeSystem = codeSystem; c.extractionVersion = version
        let lower = quote.lowercased()
        if ["family history", "my mother", "my father", "my sister", "my brother"].contains(where: lower.contains) { c.subject = .family }
        if ["consider ", "if needed", "might ", "may need", "possibly "].contains(where: lower.contains) { c.conditional = true; c.certainty = .conditional }
        if ["denies ", "no history of", "not taking", "without "].contains(where: lower.contains) { c.negated = true }
        // Deliberately no entity IDs, review state, or supersession from the model.
        try ProposalValidator.validate(c, source: source); return c
    }
}
public struct ExtractionEnvelope: Codable, Sendable { public var schemaVersion: String; public var claims: [WireProposal] }
