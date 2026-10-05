import Foundation
import CareCore

@MainActor extension AppStore {
    @discardableResult func createFollowThroughPlan(loopID: String) -> UUID? {
        var id: UUID?
        return mutate { id = try FollowThroughAssistEngine.create(loopID: loopID, in: &$0) } ? id : nil
    }
    @discardableResult func saveFollowThroughPlan(_ plan: FollowThroughPlan) -> Bool {
        let previous = state.followThroughPlans?.plans.first { $0.id == plan.id }
        let saved = mutate { try FollowThroughAssistEngine.save(plan, in: &$0) }
        if saved { followThroughRecoveryDrafts[plan.id] = nil }
        else if state.followThroughPlans?.plans.contains(where: { $0.id == plan.id }) == true { followThroughRecoveryDrafts[plan.id] = plan }
        if saved && previous?.checkBackAt != plan.checkBackAt { refreshNotifications() }
        return saved
    }
    @discardableResult func refreshFollowThroughMessage(_ id: UUID) -> Bool {
        mutate { try FollowThroughAssistEngine.refreshMessage(id, in: &$0) }
    }
    @discardableResult func recordFollowThroughAttempt(_ id: UUID, kind: FollowThroughAttemptKind, note: String) -> Bool {
        mutate { try FollowThroughAssistEngine.recordAttempt(planID: id, kind: kind, note: note, in: &$0) }
    }
    @discardableResult func captureFollowThroughReply(_ text: String, eventAt: Date?, planID: UUID, synthetic: Bool) -> UUID? {
        var id: UUID?
        let saved = mutate { id = try FollowThroughAssistEngine.captureReply(text, eventAt: eventAt, planID: planID, synthetic: synthetic, in: &$0) }
        if saved, let id, source(id)?.state == .pending { analyze(id) }
        return saved ? id : nil
    }
}
