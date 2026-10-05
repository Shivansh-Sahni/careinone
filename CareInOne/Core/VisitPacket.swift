import Foundation

public enum PacketSection: String, CaseIterable, Sendable {
    case questions = "Questions to bring"
    case conflicts = "Records to clarify"
    case loops = "Follow-through across my care"
    case changes = "Changes saved recently"
    case care = "Medications and allergies"
    case notes = "Personal context"
}
public struct PacketItem: Identifiable, Sendable {
    public var id: String
    public var section: PacketSection
    public var title: String
    public var detail: String
    public var sourceIDs: [UUID]
    public var synthetic: Bool
    public var claimIDs: [UUID] = []
    public var entityIDs: [UUID] = []
}
public struct PacketOptions: Sendable {
    public var selectedIDs: Set<String> = []
    public var encounterID: UUID?
    public var includeName = false
    public var includeBirthDate = false
    public var includeContact = false
    public var asMessage = false
    public init() {}
}
/// Creates a selection of evidence to carry, never a new clinical state or medical recommendation.
public enum VisitPacketBuilder {
    public static func items(_ state: CareState, encounterID: UUID? = nil, since: Date? = nil, now: Date = Date()) -> [PacketItem] {
        var result: [PacketItem] = []
        func append(_ id: String, _ section: PacketSection, _ title: String, _ detail: String, _ sourceIDs: [UUID], claims: [Claim] = [], entities: [UUID] = []) {
            let ids = Array(Set(sourceIDs)).sorted { $0.uuidString < $1.uuidString }
            result.append(PacketItem(id: id, section: section, title: title, detail: detail, sourceIDs: ids, synthetic: ids.contains { state.source($0)?.synthetic == true }, claimIDs: claims.map(\.id), entityIDs: Array(Set(entities + claims.compactMap(\.entityID))).sorted { $0.uuidString < $1.uuidString }))
        }
        func evidence(_ claim: Claim) -> String {
            let source = state.source(claim.sourceID)
            var location = source?.title ?? "Source unavailable"
            if let page = claim.page { location += ", page \(page)" }
            if let seconds = claim.transcriptSeconds { location += ", audio \(seconds.formatted(.number.precision(.fractionLength(0)))) seconds" }
            let dates = "Event: \(claim.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "unknown"). Effective: \(claim.effectiveAt?.formatted(date: .abbreviated, time: .omitted) ?? "not provided")."
            return "\(claim.summary) — \(claim.action.displayLabel); \(claim.certainty.displayLabel); \(claim.provenance.displayLabel)" + (claim.conditional ? "; CONDITIONAL" : "") + (claim.negated ? "; NEGATED" : "") + (claim.userEdited ? "; patient edited extraction" : "") + "\n\(dates) Source: \(location) [\(claim.sourceID.uuidString.prefix(8))]\n“\(claim.quote)”"
        }
        let canonical = state.claims.filter(\.canonical)
        for question in state.questions where !question.answered && (encounterID == nil || question.encounterID == nil || question.encounterID == encounterID) {
            append("question:" + question.id.uuidString, .questions, question.text, "Patient's saved question; not a clinical instruction.", [question.sourceID].compactMap { $0 }, entities: [question.entityID].compactMap { $0 })
        }
        for conflict in state.conflicts where conflict.status == .unresolved {
            let claims = canonical.filter { conflict.claimIDs.contains($0.id) }
            guard !claims.isEmpty else { continue }
            append("conflict:" + conflict.id, .conflicts, conflict.reason, conflict.question + "\n" + claims.map(evidence).joined(separator: "\n\n"), claims.map(\.sourceID), claims: claims)
        }
        // An upcoming encounter often has no sources yet: older open work still matters.
        for loop in state.loops where [.open, .uncertain].contains(loop.status) {
            let claims = canonical.filter { loop.claimIDs.contains($0.id) }
            append("loop:" + loop.id, .loops, loop.title, "\(loop.stage.displayLabel) · \(loop.status.rawValue)\n\(loop.timing(now: now))" + (loop.note.isEmpty ? "" : "\nPatient note: " + loop.note) + "\n" + claims.map(evidence).joined(separator: "\n\n"), claims.map(\.sourceID), claims: claims)
        }
        for change in state.changes.sorted(by: { $0.date > $1.date }) where since == nil || change.date >= since! {
            guard let claim = canonical.first(where: { $0.id == change.claimID }) else { continue }
            let detail = "Saved \(change.date.formatted(date: .abbreviated, time: .omitted)); this is not necessarily the medical event date.\nBefore: \(change.before ?? "Not previously saved")\nAfter: \(change.after)\n" + evidence(claim)
            append("change:" + change.id, .changes, change.kind.displayLabel + ": " + claim.label, detail, [claim.sourceID], claims: [claim])
        }
        let superseded = Set(canonical.compactMap(\.supersedesID))
        for entity in state.entities where [.medication, .allergy].contains(entity.kind) {
            let claims = canonical.filter { $0.entityID == entity.id && $0.certainty != .historical && !superseded.contains($0.id) }
            guard !claims.isEmpty else { continue }
            append("care:" + entity.id.uuidString, .care, entity.label, "Saved state: \(state.projection(for: entity.id).rawValue). All included reports are shown; this is not a verified current regimen.\n" + claims.map(evidence).joined(separator: "\n\n"), claims.map(\.sourceID), claims: claims)
        }
        for note in state.notes {
            append("note:" + note.id.uuidString, .notes, "Personal note", note.text + "\nPatient's personal context; not a verified clinical claim.", [], entities: [note.entityID].compactMap { $0 })
        }
        return result
    }
    public static func suggestedSelection(_ items: [PacketItem]) -> Set<String> {
        Set(items.filter { $0.section != .notes }.map(\.id))
    }
    public static func text(_ state: CareState, items: [PacketItem], options: PacketOptions, now: Date = Date()) -> String {
        let selected = items.filter { options.selectedIDs.contains($0.id) }
        var lines = [options.asMessage ? "CAREINONE · DRAFT FOR MY CARE TEAM" : "CAREINONE · SELECTED VISIT PACKET", "Prepared \(now.formatted(date: .abbreviated, time: .shortened))", "Selected saved reports only. Omitted items are not evidence of absence. Review this document before sharing; confirming extraction does not verify medical correctness."]
        if options.asMessage { lines.append("Hello, I would like to discuss the selected information below. Please help clarify the open questions and any differences between my saved sources.") }
        if let encounter = state.encounters.first(where: { $0.id == options.encounterID }) { lines.append("For: \(encounter.title) · \(encounter.date?.formatted(date: .abbreviated, time: .omitted) ?? "date not provided")") }
        if options.includeName && !state.profile.displayName.isEmpty { lines.append("Patient: " + state.profile.displayName) }
        if options.includeBirthDate, let birth = state.profile.birthDate { lines.append("DOB: " + birth.formatted(date: .abbreviated, time: .omitted)) }
        if options.includeContact { lines.append("Patient-provided contact: \(state.profile.contactName) \(state.profile.contactPhone)") }
        if selected.contains(where: \.synthetic) { lines.append("INCLUDES SYNTHETIC DEMO DATA — not a real patient's clinical record.") }
        if selected.isEmpty { lines.append("No items selected. This does not mean care is complete or records agree.") }
        for section in PacketSection.allCases {
            let group = selected.filter { $0.section == section }
            guard !group.isEmpty else { continue }
            lines.append("\n" + section.rawValue.uppercased())
            for item in group { lines.append("\n• " + item.title + "\n" + item.detail) }
        }
        lines.append("\nOriginal evidence remains on the patient's iPhone. This export is a copy; it does not provide ongoing access or allow remote revocation.")
        return lines.joined(separator: "\n")
    }
}
