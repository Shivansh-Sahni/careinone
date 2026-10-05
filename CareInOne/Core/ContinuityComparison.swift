import Foundation

public enum ContinuityChangeKind: String, CaseIterable, Sendable {
    case reportAdded = "New reviewed report", reportEdited = "Reviewed report changed", reportRetired = "Report no longer active"
    case conflictOpened = "Discrepancy added", conflictUpdated = "Discrepancy status changed", conflictRemoved = "Discrepancy no longer derived"
    case loopOpened = "Follow-through added", loopUpdated = "Follow-through changed", loopCompleted = "Completion saved", loopReopened = "Follow-through reopened", loopRemoved = "Follow-through no longer derived"
}
public struct ContinuityDifference: Identifiable, Sendable {
    public var id: String
    public var kind: ContinuityChangeKind
    public var title: String
    public var before: String?
    public var after: String?
    public var explanation: String
    public var sourceIDs: [UUID]
    public var entityID: UUID?
}
public struct ContinuityComparison: Sendable {
    public var differences: [ContinuityDifference]
    public var beforeClaimCount: Int
    public var afterClaimCount: Int
    public var omittedDeletedSourceCount: Int
    public var includesSynthetic: Bool
}

public enum ContinuityComparator {
    public static func describe(_ claim: Claim, sourceTitle: String? = nil) -> String {
        let qualifiers = [claim.action.displayLabel, claim.certainty.displayLabel, claim.provenance.displayLabel,
                          claim.conditional ? "Conditional" : nil, claim.negated ? "Negated" : nil,
                          claim.userEdited ? "Patient edited extraction" : nil].compactMap { $0 }.joined(separator: " · ")
        let event = claim.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "unknown"
        let effective = claim.effectiveAt?.formatted(date: .abbreviated, time: .omitted) ?? "not provided"
        let location = (sourceTitle ?? "Source") + " [" + claim.sourceID.uuidString.prefix(8) + "]" + (claim.page.map { ", page \($0)" } ?? "") + (claim.transcriptSeconds.map { ", audio \($0.formatted()) seconds" } ?? "")
        let due = claim.dueAt?.formatted(date: .abbreviated, time: claim.dueTimeKnown ? .shortened : .omitted) ?? "not provided"
        let interval = claim.intervalDays.map { "\($0) days" } ?? "not provided"
        let speaker = claim.speaker.map { "Speaker: " + $0 + (claim.speakerUncertain ? " (uncertain)" : " (as attributed in source)") } ?? "Speaker not provided"
        let replacement = claim.supersedesID.map { "\nPatient selected explicit replacement of report [\($0.uuidString.prefix(8))]." } ?? ""
        return "\(claim.summary)\n\(qualifiers)\nEvent: \(event). Effective: \(effective).\nDue/appointment: \(due) (\(claim.duePrecision.rawValue)). Interval: \(interval).\n\(speaker)\(replacement)\n\(location)\n“\(claim.quote)”"
    }
    private static func describe(_ loop: CareLoop) -> String {
        let due = loop.dueAt?.formatted(date: .abbreviated, time: .omitted) ?? "not provided"
        return "\(loop.stage.displayLabel) · \(loop.status.rawValue)\nDue: \(due) · \(loop.precision.rawValue)" + (loop.userCompleted ? "\nCompleted by patient report" : "") + (loop.note.isEmpty ? "" : "\nPatient note: " + loop.note)
    }
    public static func compare(_ checkpoint: CareCheckpoint, to state: CareState) -> ContinuityComparison {
        let old = Dictionary(uniqueKeysWithValues: checkpoint.facts.map { ($0.id, $0) })
        let current = Dictionary(uniqueKeysWithValues: state.claims.filter { $0.canonical && state.source($0.sourceID) != nil }.map { ($0.id, $0) })
        var differences: [ContinuityDifference] = []
        func append(_ id: String, _ kind: ContinuityChangeKind, _ title: String, _ before: String?, _ after: String?, _ explanation: String, _ claims: [UUID], _ entity: UUID?) {
            let sources = Set(claims.compactMap { current[$0]?.sourceID ?? old[$0]?.claim.sourceID })
            differences.append(ContinuityDifference(id: id, kind: kind, title: title, before: before, after: after, explanation: explanation,
                sourceIDs: sources.sorted { $0.uuidString < $1.uuidString }, entityID: entity))
        }
        for claim in current.values {
            if let fact = old[claim.id] {
                if !Normalizer.equivalent(fact.claim, claim) || fact.claim.quote != claim.quote || fact.claim.entityID != claim.entityID || fact.claim.userEdited != claim.userEdited || fact.claim.page != claim.page || fact.claim.transcriptSeconds != claim.transcriptSeconds {
                    append("report:" + claim.id.uuidString, .reportEdited, claim.label, describe(fact.claim, sourceTitle: fact.sourceTitle), describe(claim, sourceTitle: state.source(claim.sourceID)?.title), "An accepted report was edited in this app. Compare the source evidence; this is not a medical recommendation.", [claim.id], claim.entityID)
                }
            } else {
                append("report:" + claim.id.uuidString, .reportAdded, claim.label, nil, describe(claim, sourceTitle: state.source(claim.sourceID)?.title), "This report was accepted after the checkpoint. Its medical event may have happened earlier.", [claim.id], claim.entityID)
            }
        }
        for fact in old.values where current[fact.id] == nil {
            append("report:" + fact.id.uuidString, .reportRetired, fact.claim.label, describe(fact.claim, sourceTitle: fact.sourceTitle), nil, "This report is no longer accepted in the current saved state. This does not mean a medicine stopped or an event did not happen.", [fact.id], state.entity(fact.claim.entityID)?.id)
        }
        let oldConflicts = Dictionary(uniqueKeysWithValues: checkpoint.conflicts.map { ($0.id, $0) })
        let conflicts = Dictionary(uniqueKeysWithValues: state.conflicts.map { ($0.id, $0) })
        for conflict in conflicts.values where !checkpoint.redactedDerivedIDs.contains("conflict:" + conflict.id) {
            if let previous = oldConflicts[conflict.id] {
                if previous.status != conflict.status || previous.note != conflict.note {
                    append("conflict:" + conflict.id, .conflictUpdated, conflict.reason, previous.status.rawValue + "\n" + previous.note, conflict.status.rawValue + "\n" + conflict.note, "A saved clarification status or note changed. It is not independent clinician verification.", conflict.claimIDs, conflict.entityID)
                }
            } else {
                append("conflict:" + conflict.id, .conflictOpened, conflict.reason, nil, conflict.status.rawValue + "\n" + conflict.question, "Saved sources introduced another comparison. No clinical winner was selected.", conflict.claimIDs, conflict.entityID)
            }
        }
        for previous in oldConflicts.values where conflicts[previous.id] == nil {
            append("conflict:" + previous.id, .conflictRemoved, previous.reason, previous.status.rawValue, nil, "The supporting active evidence changed or was removed. Disappearance does not prove the instructions agree.", previous.claimIDs, state.entity(previous.entityID)?.id)
        }
        let oldLoops = Dictionary(uniqueKeysWithValues: checkpoint.loops.map { ($0.id, $0) })
        let loops = Dictionary(uniqueKeysWithValues: state.loops.map { ($0.id, $0) })
        for loop in loops.values where !checkpoint.redactedDerivedIDs.contains("loop:" + loop.id) && !loop.claimIDs.contains(where: { checkpoint.redactedDerivedIDs.contains("loop-claim:" + $0.uuidString) }) {
            if let previous = oldLoops[loop.id] {
                if previous.stage != loop.stage || previous.status != loop.status || previous.dueAt != loop.dueAt || previous.precision != loop.precision || previous.note != loop.note || previous.userCompleted != loop.userCompleted {
                    let kind: ContinuityChangeKind = loop.status == .completed && previous.status != .completed ? .loopCompleted : previous.status == .completed && [.open, .uncertain].contains(loop.status) ? .loopReopened : .loopUpdated
                    append("loop:" + loop.id, kind, loop.title, describe(previous), describe(loop), loop.status == .completed ? (loop.userCompleted ? "Completion was reported by the patient; no independent verification is implied." : "Saved evidence advanced this workflow to completion. Review its source.") : "A saved workflow state, date, or patient note changed.", loop.claimIDs + previous.claimIDs, loop.entityID)
                }
            } else {
                append("loop:" + loop.id, .loopOpened, loop.title, nil, describe(loop), "This work is now represented in the app. Missing outside records remain unknown.", loop.claimIDs, loop.entityID)
            }
        }
        for previous in oldLoops.values where loops[previous.id] == nil {
            append("loop:" + previous.id, .loopRemoved, previous.title, describe(previous), nil, "This workflow is no longer derived from the remaining evidence. It has not been marked medically completed.", previous.claimIDs, state.entity(previous.entityID)?.id)
        }
        let order = Dictionary(uniqueKeysWithValues: ContinuityChangeKind.allCases.enumerated().map { ($0.element, $0.offset) })
        differences.sort { order[$0.kind] == order[$1.kind] ? $0.id < $1.id : order[$0.kind]! < order[$1.kind]! }
        let synthetic = checkpoint.includesSynthetic || current.values.contains { state.source($0.sourceID)?.synthetic == true }
        return ContinuityComparison(differences: differences, beforeClaimCount: checkpoint.facts.count, afterClaimCount: current.count, omittedDeletedSourceCount: checkpoint.removedSourceCount, includesSynthetic: synthetic)
    }

    public static func text(_ comparison: ContinuityComparison, title: String) -> String {
        var lines = ["CAREINONE · SAVED CARE COMPARISON", title,
            "This compares information saved in the app, not medical truth or the chronological order of medical events. Omitted evidence does not mean an event never happened."]
        if comparison.includesSynthetic { lines.append("INCLUDES SYNTHETIC DEMO EVIDENCE — not a real clinical record.") }
        if comparison.omittedDeletedSourceCount > 0 { lines.append("Some checkpoint evidence was removed when \(comparison.omittedDeletedSourceCount) source(s) were deleted. Comparison coverage is incomplete.") }
        if comparison.differences.isEmpty { lines.append("No differences found in reviewed reports, discrepancy status and follow-through since this checkpoint. Outside events and unreviewed sources remain unknown.") }
        for item in comparison.differences {
            lines.append("\n\(item.kind.rawValue.uppercased()) · \(item.title)\nBefore: \(item.before ?? "Not represented here")\nAfter: \(item.after ?? "No longer represented here")\n\(item.explanation)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum EvidenceImpact {
    public static func accepting(_ claims: [Claim], in state: CareState, now: Date = Date()) throws -> ContinuityComparison {
        let checkpoint = ContinuityEngine.snapshot(state, title: "Before review", now: now)
        var preview = state
        try Reconciler.accept(claims, into: &preview, now: now)
        return ContinuityComparator.compare(checkpoint, to: preview)
    }
    public static func deleting(_ sourceID: UUID, in state: CareState) throws -> ContinuityComparison {
        guard state.source(sourceID) != nil else { throw CareError.invalid("This source was already removed.") }
        // Keep this ephemeral before-image only long enough to explain the deletion. Never persist it.
        let checkpoint = ContinuityEngine.snapshot(state, title: "Before deletion")
        var preview = state; Reconciler.deleteSource(sourceID, from: &preview)
        return ContinuityComparator.compare(checkpoint, to: preview)
    }
}
