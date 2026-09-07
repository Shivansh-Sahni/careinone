import Foundation

public enum LoopEngine {
    public static func kind(_ claim: Claim) -> LoopKind? {
        switch claim.kind {
        case .labTest: .test; case .resultType: .resultFollowUp; case .referral: .referral
        case .followUp: .followUp; case .procedure: .procedure; case .administrativeTask: .administrative
        default: nil
        }
    }
    public static func states(_ kind: LoopKind) -> [ClaimAction] {
        switch kind {
        case .test: [.ordered, .requested, .scheduled, .completed, .resultAvailable, .followUpKnown]
        case .referral: [.requested, .referralPlaced, .appointmentScheduled, .visitCompleted]
        case .followUp: [.requested, .scheduled, .completed]
        case .procedure: [.ordered, .planned, .scheduled, .prepNeeded, .completed, .followUpKnown]
        case .resultFollowUp: [.requested, .scheduled, .followUpKnown, .completed]
        case .administrative: [.requested, .inProgress, .completed, .dismissed]
        }
    }
    public static func isTerminal(_ stage: ClaimAction, kind: LoopKind) -> Bool {
        switch kind {
        case .test: [.resultAvailable, .followUpKnown].contains(stage)
        case .referral: stage == .visitCompleted
        case .followUp, .administrative, .resultFollowUp: [.completed, .followUpKnown].contains(stage)
        case .procedure: [.completed, .followUpKnown].contains(stage)
        }
    }
    private static func rank(_ stage: ClaimAction, kind: LoopKind) -> Int {
        if kind == .test && [.ordered, .requested].contains(stage) { return 0 }
        if kind == .procedure && [.ordered, .planned].contains(stage) { return 0 }
        return states(kind).firstIndex(of: stage) ?? -1
    }
    public static func build(claims: [Claim], state: CareState) -> [CareLoop] {
        let sorted = claims.sorted { a, b in
            let ad = a.effectiveAt ?? a.eventAt, bd = b.effectiveAt ?? b.eventAt
            if let ad, let bd, ad != bd { return ad < bd }
            if ad != nil && bd == nil { return true }
            if ad == nil && bd != nil { return false }
            // Undated evidence has no inferred medical chronology; stable acceptance ordering is used only for iteration.
            let ac = a.acceptedAt ?? a.createdAt, bc = b.acceptedAt ?? b.createdAt
            return ac == bc ? a.id.uuidString < b.id.uuidString : ac < bc
        }
        var loops: [CareLoop] = []
        for claim in sorted {
            guard let eid = claim.entityID, let kind = kind(claim), !claim.conditional, !claim.negated,
                  ![.historical, .superseded, .unknown, .notProvided].contains(claim.certainty), states(kind).contains(claim.action) else { continue }
            let source = state.source(claim.sourceID)
            let existing = loops.lastIndex { $0.entityID == eid && $0.kind == kind }
            let actionable = rank(claim.action, kind: kind) >= 0
            guard actionable else { continue }
            let evidenceDate = claim.effectiveAt ?? claim.eventAt
            var due = claim.dueAt
            var precision = claim.duePrecision
            if due == nil, let days = claim.intervalDays, let anchor = evidenceDate {
                due = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: anchor); precision = .approximate
            }
            if let index = existing {
                let prior = loops[index]
                let lastClaim = claims.first { $0.id == prior.claimIDs.last }
                let priorDate = lastClaim?.effectiveAt ?? lastClaim?.eventAt
                let sameEncounter = source?.encounterID != nil && source?.encounterID == prior.encounterID
                let sameSource = lastClaim?.sourceID == claim.sourceID
                let knownLater = evidenceDate != nil && priorDate != nil && evidenceDate! >= priorDate!
                let startsNew = isTerminal(prior.stage, kind: kind) && rank(claim.action, kind: kind) <= 1 && knownLater && evidenceDate! > priorDate!
                if !startsNew {
                    loops[index].claimIDs.append(claim.id)
                    if knownLater || sameEncounter || sameSource {
                        if rank(claim.action, kind: kind) >= rank(prior.stage, kind: kind) {
                            loops[index].stage = claim.action
                            loops[index].status = claim.action == .dismissed ? .dismissed : isTerminal(claim.action, kind: kind) ? .completed : .open
                        }
                        if due != nil { loops[index].dueAt = due; loops[index].precision = precision; loops[index].dueConfidence = claim.confidence }
                    } else if claim.action != prior.stage { loops[index].status = .uncertain }
                    continue
                }
            }
            // A completion/result alone is evidence, not a fabricated open order.
            guard !isTerminal(claim.action, kind: kind), claim.action != .dismissed else { continue }
            loops.append(CareLoop(id: "\(eid)|\(kind.rawValue)|\(claim.id)", entityID: eid, kind: kind, title: claim.label, stage: claim.action,
                                  status: claim.certainty == .uncertain ? .uncertain : .open, claimIDs: [claim.id], dueAt: due, precision: precision,
                                  dueConfidence: due == nil ? 0 : claim.confidence, encounterID: source?.encounterID, createdAt: claim.acceptedAt ?? claim.createdAt))
        }
        for i in loops.indices {
            guard let override = state.loopOverrides[loops[i].id] else { continue }
            loops[i].note = override.note
            if override.dateEdited { loops[i].dueAt = override.dueAt; loops[i].precision = override.precision; loops[i].dueConfidence = override.dueAt == nil ? 0 : 1 }
            let newContradictory = claims.contains { claim in
                loops[i].claimIDs.contains(claim.id) && !override.evidenceIDs.contains(claim.id) &&
                [.ordered, .requested, .planned, .referralPlaced].contains(claim.action) &&
                (claim.effectiveAt ?? claim.eventAt).map { $0 > override.updatedAt } == true
            }
            if let status = override.status, !newContradictory { loops[i].status = status; loops[i].userCompleted = status == .completed }
            else if newContradictory { loops[i].status = .open }
        }
        return loops
    }
}
public struct PriorityItem: Identifiable, Sendable {
    public var id: String; public var title: String; public var detail: String; public var score: Int; public var reason: String
    public var sourceID: UUID?; public var entityID: UUID?; public var destination: String
}
public enum PriorityEngine {
    public static func items(_ state: CareState, now: Date = Date()) -> [PriorityItem] {
        var result: [PriorityItem] = []
        let upcoming = state.upcomingAppointments(now: now, through: now.addingTimeInterval(7 * 86400))
        for conflict in state.conflicts where conflict.status == .unresolved {
            let claim = state.claims.first { conflict.claimIDs.contains($0.id) }
            let urgentCategory = claim?.kind.consequential == true
            result.append(PriorityItem(id: conflict.id, title: conflict.reason, detail: "Your saved sources need clarification.", score: (urgentCategory ? 100 : 65) + (upcoming.isEmpty ? 0 : 10), reason: (urgentCategory ? "Medication, allergy, or instruction discrepancy" : "Unresolved source discrepancy") + (upcoming.isEmpty ? "" : "; an appointment is coming up"), sourceID: claim?.sourceID, entityID: conflict.entityID, destination: "discrepancies"))
        }
        for loop in state.loops where [.open, .uncertain].contains(loop.status) {
            let exactSoon = loop.precision == .exact && loop.dueAt.map { $0 < now.addingTimeInterval(7 * 86400) } == true
            let old = now.timeIntervalSince(loop.createdAt) > 30 * 86400
            result.append(PriorityItem(id: loop.id, title: loop.title, detail: loop.timing(now: now), score: exactSoon ? 90 : old ? 50 : 35, reason: exactSoon ? "Explicit saved due date is approaching or has passed" : old ? "Open in your saved record for over 30 days" : "An explicit follow-through step is saved", sourceID: state.claims.first { $0.id == loop.claimIDs.first }?.sourceID, entityID: loop.entityID, destination: "loops"))
        }
        for appointment in upcoming {
            result.append(PriorityItem(id: appointment.id.uuidString, title: appointment.label, detail: (appointment.dueAt ?? appointment.eventAt)!.formatted(date: .abbreviated, time: appointment.dueTimeKnown ? .shortened : .omitted) + (appointment.dueTimeKnown ? "" : " · time not provided"), score: 85, reason: "Appointment within the next seven days", sourceID: appointment.sourceID, entityID: appointment.entityID, destination: "prepare"))
        }
        for change in state.changes.prefix(8) where now.timeIntervalSince(change.date) < 14 * 86400 && [.added, .changed, .superseded].contains(change.kind) {
            result.append(PriorityItem(id: change.id, title: change.after, detail: change.kind.rawValue.capitalized, score: change.category == .other ? 20 : 60, reason: "Care information accepted in the last 14 days", sourceID: change.sourceID, entityID: change.entityID, destination: "changes"))
        }
        return result.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
    }
}

public struct PlannedReminder: Equatable, Sendable {
    public var id: String; public var date: Date
}
public enum ReminderPlanner {
    public static func plan(_ state: CareState, now: Date = Date(), calendar: Calendar = .current) -> [PlannedReminder] {
        guard state.profile.notifications else { return [] }
        var result: [PlannedReminder] = []
        if state.profile.notifyTasks {
            for loop in state.loops where loop.status == .open && loop.precision == .exact {
                if let due = loop.dueAt, let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due), date > now { result.append(PlannedReminder(id:"loop-" + loop.id, date:date)) }
            }
        }
        if state.profile.notifyAppointments {
            for claim in state.upcomingAppointments(now:now) where claim.duePrecision == .exact && ![.uncertain, .disputed].contains(claim.certainty) {
                guard let due = claim.dueAt, let appointment = claim.dueTimeKnown ? due : calendar.date(bySettingHour:9,minute:0,second:0,of:due), appointment > now else { continue }
                let dayBefore = calendar.date(byAdding:.day,value:-1,to:appointment) ?? appointment
                result.append(PlannedReminder(id:"visit-" + claim.id.uuidString,date:max(now.addingTimeInterval(60),dayBefore)))
            }
        }
        return Array(result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }.prefix(50))
    }
}
