import Foundation

public enum FollowThroughObstacle: String, Codable, CaseIterable, Sendable, Identifiable {
    case schedule, waiting, contact, paperwork
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .schedule: "I need to arrange it"
        case .waiting: "I'm waiting to hear back"
        case .contact: "I don't know who to ask"
        case .paperwork: "I need records or paperwork"
        }
    }
    public var symbol: String {
        switch self { case .schedule: "calendar.badge.plus"; case .waiting: "clock"; case .contact: "person.crop.circle.badge.questionmark"; case .paperwork: "doc.on.doc" }
    }
}
public enum FollowThroughAction: String, Codable, CaseIterable, Sendable, Identifiable {
    case call, message, askAtVisit, collectRecords
    public var id: String { rawValue }
    public var title: String {
        switch self { case .call: "Call the office"; case .message: "Send a portal message"; case .askAtVisit: "Ask at my visit"; case .collectRecords: "Gather my paperwork" }
    }
}
public enum FollowThroughAttemptKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case contacted, waiting, paperworkReady, replySaved
    public var id: String { rawValue }
    public var title: String {
        switch self { case .contacted: "I reached out"; case .waiting: "I'm waiting for a reply"; case .paperworkReady: "My paperwork is ready"; case .replySaved: "Reply saved for review" }
    }
}
public struct FollowThroughAttempt: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var kind: FollowThroughAttemptKind
    public var date: Date
    public var note: String
}
public struct FollowThroughPlan: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var loopID: String
    public var entityID: UUID
    /// Kept for a paused plan while edited source evidence is awaiting review.
    public var savedTitle: String?
    public var encounterID: UUID?
    public var createdAt: Date
    public var obstacle: FollowThroughObstacle = .schedule
    public var nextAction: FollowThroughAction = .message
    public var recipient = ""
    public var messageDraft = ""
    /// A personal reminder chosen by the patient. Never becomes a clinical due date.
    public var checkBackAt: Date?
    public var replyDraft = ""
    public var attemptDraft = ""
    public var replyEventAt: Date?
    public var replySynthetic = false
    public var supportingSourceIDs: [UUID]
    public var replySourceIDs: [UUID] = []
    public var evidenceDigest: String
    public var history: [FollowThroughAttempt] = []
}
public struct FollowThroughMemory: Codable, Equatable, Sendable {
    public var version = 1
    public var plans: [FollowThroughPlan] = []
    public init() {}
}
public struct FollowThroughCheckBack: Equatable, Sendable, Identifiable {
    public var id: String
    public var date: Date
}

public enum FollowThroughAssistEngine {
    public static let maximumPlans = 200
    public static let maximumDraftCharacters = 20_000
    public static let maximumHistory = 200
    public static let maximumStoredCharacters = 2_000_000
    public static func plan(for loopID: String, in state: CareState) -> FollowThroughPlan? {
        state.followThroughPlans?.plans.first { $0.loopID == loopID }
    }
    /// Recover patient edits onto the latest saved record, never its removed predecessor.
    /// Evidence links, history, identity, and timestamps always come from the live record.
    public static func rebaseEditableDraft(_ draft: FollowThroughPlan, baseline: FollowThroughPlan?, onto stored: FollowThroughPlan?) -> FollowThroughPlan? {
        guard var result = stored, result.id == draft.id, result.loopID == draft.loopID,
              baseline.map({ $0.id == draft.id && $0.loopID == draft.loopID }) != false else { return nil }
        func edited<Value: Equatable>(_ path: WritableKeyPath<FollowThroughPlan, Value>) {
            if baseline == nil || baseline?[keyPath: path] != draft[keyPath: path] { result[keyPath: path] = draft[keyPath: path] }
        }
        edited(\.obstacle); edited(\.nextAction); edited(\.recipient); edited(\.messageDraft)
        edited(\.checkBackAt); edited(\.replyDraft); edited(\.attemptDraft); edited(\.replyEventAt); edited(\.replySynthetic)
        return result
    }
    private static func loop(_ id: String, in state: CareState) throws -> CareLoop {
        guard let loop = state.loops.first(where: { $0.id == id }) else { throw CareError.invalid("This follow-through item is no longer in your saved care.") }
        return loop
    }
    public static func supportingClaims(for loop: CareLoop, in state: CareState) -> [Claim] {
        let ids = Set(loop.claimIDs)
        return state.claims.filter { ids.contains($0.id) && $0.canonical && state.source($0.sourceID) != nil }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
    private static func digest(for loop: CareLoop, in state: CareState) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        struct Context: Encodable { var loop: CareLoop; var claims: [Claim]; var sources: [Source] }
        let claims = supportingClaims(for: loop, in: state), ids = Set(claims.map(\.sourceID))
        let sources = state.sources.filter { ids.contains($0.id) }.sorted { $0.id.uuidString < $1.id.uuidString }
        return ContentHasher.hash((try? encoder.encode(Context(loop: loop, claims: claims, sources: sources))) ?? Data())
    }
    public static func savedInformationChanged(_ plan: FollowThroughPlan, in state: CareState) -> Bool {
        guard let loop = state.loops.first(where: { $0.id == plan.loopID }) else { return true }
        return digest(for: loop, in: state) != plan.evidenceDigest
    }
    public static func nextStepExplanation(for loop: CareLoop) -> String {
        if loop.status == .completed { return "You can keep a record of any last questions or replies here. Completion is shown separately in your saved care." }
        if loop.stage == .completed && loop.kind == .test { return "A completion is saved. If you are waiting for the result, ask where it will appear and who will explain the next step." }
        if [.scheduled, .appointmentScheduled, .prepNeeded].contains(loop.stage) { return "A scheduled step is saved. Use this to confirm the arrangements or ask what information the office needs from you." }
        if loop.kind == .resultFollowUp { return "Use your saved result to ask who will explain it and whether any follow-up has been arranged." }
        return "Make the next small step easier: choose what is getting in the way, use a ready-to-edit message, and keep track of what comes back."
    }
    public static func message(for loopID: String, obstacle: FollowThroughObstacle, recipient: String = "", in state: CareState) throws -> String {
        let loop = try loop(loopID, in: state)
        var lines = [recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hello," : "Hello \(recipient.trimmingCharacters(in: .whitespacesAndNewlines)),", "", "I'm following up about \(loop.title)."]
        let reports = supportingClaims(for: loop, in: state).prefix(3)
        if !reports.isEmpty {
            lines.append("My saved information includes:")
            for claim in reports {
                guard let source = state.source(claim.sourceID) else { continue }
                let quote = String(claim.quote.prefix(3_000))
                let suffix = claim.quote.count > 3_000 ? " [excerpt]" : ""
                let origin = source.title + (source.eventAt.map { " (event: " + $0.formatted(date: .abbreviated, time: .omitted) + ")" } ?? " (event date not saved)")
                lines.append("• \(origin): “\(quote)”\(suffix)")
            }
        }
        lines.append("")
        switch obstacle {
        case .schedule:
            if [.scheduled, .appointmentScheduled, .prepNeeded].contains(loop.stage) {
                lines.append("Could you confirm the arrangements and anything I need to bring or complete beforehand?")
            } else if loop.stage == .completed && loop.kind == .test {
                lines.append("Could you tell me where I can find the result and who I should contact to understand the next step?")
            } else { lines.append("Could you confirm the next step and how I can arrange it? Is there anything you need from me first?") }
        case .waiting: lines.append("Could you let me know the current status, whether anything is needed from me, and when I should check back if I haven't heard anything?")
        case .contact: lines.append("Which office or person handles this next step, and what is the best way to reach them? Do I need a referral or any records before contacting them?")
        case .paperwork: lines.append("Which records, forms, or authorization do you need, where should I send them, and how can I confirm you received them?")
        }
        if state.conflicts.contains(where: { $0.entityID == loop.entityID && $0.status == .unresolved }) { lines.append("Some of my saved information differs. Could you help me clarify the current instructions?") }
        lines.append("Thank you.")
        return lines.joined(separator: "\n")
    }
    @discardableResult public static func create(loopID: String, in state: inout CareState, now: Date = Date()) throws -> UUID {
        if let existing = plan(for: loopID, in: state) { return existing.id }
        let item = try loop(loopID, in: state)
        guard (state.followThroughPlans?.plans.count ?? 0) < maximumPlans else { throw CareError.invalid("You have reached the saved next-step plan limit. Remove a plan you no longer need first.") }
        let sources = Array(Set(supportingClaims(for: item, in: state).map(\.sourceID))).sorted { $0.uuidString < $1.uuidString }
        guard !sources.isEmpty, now.timeIntervalSince1970.isFinite else { throw CareError.invalid("This item needs supporting saved evidence before a plan can be made.") }
        var plan = FollowThroughPlan(loopID: loopID, entityID: item.entityID, encounterID: item.encounterID, createdAt: now, supportingSourceIDs: sources, evidenceDigest: digest(for: item, in: state))
        plan.savedTitle = String(item.title.prefix(200))
        plan.messageDraft = try message(for: loopID, obstacle: plan.obstacle, in: state)
        plan.replySynthetic = sources.contains { state.source($0)?.synthetic == true }
        var next = state
        if next.followThroughPlans == nil { next.followThroughPlans = FollowThroughMemory() }
        next.followThroughPlans?.plans.append(plan)
        try validate(next)
        next.audit.append(Audit(action: "follow_through_plan_created")); state = next
        return plan.id
    }
    public static func save(_ plan: FollowThroughPlan, in state: inout CareState) throws {
        guard let index = state.followThroughPlans?.plans.firstIndex(where: { $0.id == plan.id }), let stored = state.followThroughPlans?.plans[index],
              plan.loopID == stored.loopID, plan.entityID == stored.entityID, plan.createdAt == stored.createdAt,
              plan.supportingSourceIDs == stored.supportingSourceIDs, plan.replySourceIDs == stored.replySourceIDs,
              plan.evidenceDigest == stored.evidenceDigest, plan.history == stored.history, plan.encounterID == stored.encounterID, plan.savedTitle == stored.savedTitle else { throw CareError.invalid("This plan changed. Reopen it before saving.") }
        var next = state; next.followThroughPlans?.plans[index] = plan
        try validate(next); state = next
    }
    public static func refreshMessage(_ id: UUID, in state: inout CareState) throws {
        guard let index = state.followThroughPlans?.plans.firstIndex(where: { $0.id == id }), var plan = state.followThroughPlans?.plans[index] else { throw CareError.invalid("This plan was removed.") }
        let item = try loop(plan.loopID, in: state)
        plan.messageDraft = try message(for: plan.loopID, obstacle: plan.obstacle, recipient: plan.recipient, in: state)
        plan.supportingSourceIDs = Array(Set(plan.supportingSourceIDs + supportingClaims(for: item, in: state).map(\.sourceID))).sorted { $0.uuidString < $1.uuidString }
        plan.evidenceDigest = digest(for: item, in: state)
        var next = state; next.followThroughPlans?.plans[index] = plan; try validate(next); state = next
    }
    public static func recordAttempt(planID: UUID, kind: FollowThroughAttemptKind, note: String = "", in state: inout CareState, now: Date = Date()) throws {
        guard let index = state.followThroughPlans?.plans.firstIndex(where: { $0.id == planID }) else { throw CareError.invalid("This plan was removed.") }
        guard kind != .replySaved else { throw CareError.invalid("Save an actual reply as evidence to record it here.") }
        var next = state
        next.followThroughPlans?.plans[index].history.append(FollowThroughAttempt(kind: kind, date: now, note: note))
        next.followThroughPlans?.plans[index].attemptDraft = ""
        try validate(next); state = next; state.audit.append(Audit(action: "follow_through_attempt_recorded"))
    }
    public static func relink(_ planID: UUID, toLoopID loopID: String, in state: inout CareState) throws {
        guard let index = state.followThroughPlans?.plans.firstIndex(where: { $0.id == planID }), var plan = state.followThroughPlans?.plans[index] else { throw CareError.invalid("This plan was removed.") }
        guard state.followThroughPlans?.plans.contains(where: { $0.id != planID && $0.loopID == loopID }) != true else { throw CareError.invalid("That care task already has a helper plan. Choose another task or keep these plans separate.") }
        let target = try loop(loopID, in: state)
        plan.loopID = target.id; plan.entityID = target.entityID; plan.encounterID = target.encounterID; plan.savedTitle = String(target.title.prefix(200))
        plan.supportingSourceIDs = Array(Set(plan.supportingSourceIDs + supportingClaims(for: target, in: state).map(\.sourceID))).sorted { $0.uuidString < $1.uuidString }
        // Keep the previous digest and actual drafts. Reconnecting never silently replaces what the patient wrote.
        var next = state; next.followThroughPlans?.plans[index] = plan; try validate(next)
        next.audit.append(Audit(action: "follow_through_plan_reconnected")); state = next
    }
    @discardableResult public static func captureReply(_ text: String, eventAt: Date?, planID: UUID, synthetic: Bool, in state: inout CareState, now: Date = Date()) throws -> UUID {
        guard let index = state.followThroughPlans?.plans.firstIndex(where: { $0.id == planID }), let plan = state.followThroughPlans?.plans[index] else { throw CareError.invalid("This plan was removed.") }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= maximumDraftCharacters else { throw CareError.invalid("Add the reply or your recollection, up to 20,000 characters.") }
        guard eventAt?.timeIntervalSince1970.isFinite != false, now.timeIntervalSince1970.isFinite else { throw CareError.invalid("Choose a valid date or leave it unknown.") }
        let hash = ContentHasher.hash(text)
        if let duplicate = plan.replySourceIDs.compactMap({ state.source($0) }).first(where: { $0.contentHash == hash && $0.originalText == text && $0.workingText == text && $0.eventAt == eventAt && $0.synthetic == synthetic }) {
            state.followThroughPlans?.plans[index].replyDraft = ""; state.followThroughPlans?.plans[index].replyEventAt = nil
            return duplicate.id
        }
        let title = state.loops.first(where: { $0.id == plan.loopID })?.title ?? plan.savedTitle ?? "my saved care task"
        var source = Source(title: "Reply about " + String(title.prefix(160)), kind: .typed, text: text, contentHash: hash, eventAt: eventAt)
        source.capturedAt = now; source.encounterID = plan.encounterID; source.synthetic = synthetic; source.state = .pending
        var next = state; next.sources.append(source)
        next.followThroughPlans?.plans[index].replySourceIDs.append(source.id)
        next.followThroughPlans?.plans[index].replyDraft = ""; next.followThroughPlans?.plans[index].replyEventAt = nil
        next.followThroughPlans?.plans[index].history.append(FollowThroughAttempt(kind: .replySaved, date: now, note: ""))
        try validate(next); state = next; state.audit.append(Audit(action: "follow_through_reply_saved"))
        return source.id
    }
    public static func remove(_ id: UUID, from state: inout CareState) { state.followThroughPlans?.plans.removeAll { $0.id == id } }
    /// Remove the complete copied plan, including drafts and notes, when any supporting evidence is deleted.
    public static func removeSource(_ id: UUID, from state: inout CareState) {
        state.followThroughPlans?.plans.removeAll { $0.supportingSourceIDs.contains(id) || $0.replySourceIDs.contains(id) }
    }
    public static func detachEncounter(_ id: UUID, from state: inout CareState) {
        guard let plans = state.followThroughPlans?.plans else { return }
        for index in plans.indices where plans[index].encounterID == id { state.followThroughPlans?.plans[index].encounterID = nil }
    }
    public static func pruneUnavailableLoops(in state: inout CareState) {
        let sources = Set(state.sources.map(\.id))
        // A derived loop can disappear temporarily after source edits. Keep the patient's work while its evidence exists.
        state.followThroughPlans?.plans.removeAll { !$0.supportingSourceIDs.allSatisfy(sources.contains) || !$0.replySourceIDs.allSatisfy(sources.contains) }
    }
    public static func checkBacks(in state: CareState, now: Date = Date()) -> [FollowThroughCheckBack] {
        guard state.profile.notifications, state.profile.notifyTasks else { return [] }
        let open = Set(state.loops.filter { [.open, .uncertain].contains($0.status) }.map(\.id))
        return (state.followThroughPlans?.plans ?? []).compactMap { plan -> FollowThroughCheckBack? in
            guard open.contains(plan.loopID), let date = plan.checkBackAt, date > now else { return nil }
            return FollowThroughCheckBack(id: "checkback-" + plan.id.uuidString, date: date)
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
    public static func validate(_ state: CareState) throws {
        guard let memory = state.followThroughPlans else { return }
        guard memory.version == 1, memory.plans.count <= maximumPlans else { throw CareError.invalid("Unsupported or oversized next-step plan data.") }
        let sources = Set(state.sources.map(\.id)), encounters = Set(state.encounters.map(\.id))
        guard Set(memory.plans.map(\.id)).count == memory.plans.count, Set(memory.plans.map(\.loopID)).count == memory.plans.count else { throw CareError.invalid("Duplicate next-step plans.") }
        let totalCharacters = memory.plans.reduce(0) { total, plan in total + plan.loopID.count + (plan.savedTitle?.count ?? 0) + plan.recipient.count + plan.messageDraft.count + plan.replyDraft.count + plan.attemptDraft.count + plan.history.reduce(0) { $0 + $1.note.count } }
        guard totalCharacters <= maximumStoredCharacters else { throw CareError.invalid("Your next-step plans have reached their local text limit. Remove a plan you no longer need before adding more.") }
        for plan in memory.plans {
            let item = state.loops.first { $0.id == plan.loopID }
            guard !plan.loopID.isEmpty, plan.loopID.count <= 500, item.map({ $0.entityID == plan.entityID && state.entity(plan.entityID) != nil }) != false,
                  plan.savedTitle.map({ $0.count <= 200 }) != false,
                  plan.encounterID.map(encounters.contains) != false,
                  !plan.supportingSourceIDs.isEmpty, plan.supportingSourceIDs.count <= 10_000,
                  plan.replySourceIDs.count <= maximumHistory,
                  Set(plan.supportingSourceIDs).count == plan.supportingSourceIDs.count,
                  Set(plan.replySourceIDs).count == plan.replySourceIDs.count,
                  plan.supportingSourceIDs.allSatisfy(sources.contains), plan.replySourceIDs.allSatisfy(sources.contains),
                  plan.recipient.count <= 200, plan.messageDraft.count <= maximumDraftCharacters, plan.replyDraft.count <= maximumDraftCharacters, plan.attemptDraft.count <= 2_000,
                  plan.evidenceDigest.count == 64, plan.evidenceDigest.allSatisfy(\.isHexDigit),
                  plan.createdAt.timeIntervalSince1970.isFinite,
                  plan.checkBackAt?.timeIntervalSince1970.isFinite != false, plan.replyEventAt?.timeIntervalSince1970.isFinite != false,
                  plan.history.count <= maximumHistory, Set(plan.history.map(\.id)).count == plan.history.count,
                  plan.history.allSatisfy({ $0.date.timeIntervalSince1970.isFinite && $0.note.count <= 2_000 }) else { throw CareError.invalid("A next-step plan has invalid dates, links, or text. Your existing saved care has not changed.") }
        }
    }
}
