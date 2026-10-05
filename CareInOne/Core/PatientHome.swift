import Foundation

public struct AppointmentShortcut: Equatable, Sendable {
    public var companionID: UUID?
    public var encounterID: UUID?
    public var appointmentAt: Date? = nil
    public var appointmentTitle: String? = nil
    public var title: String
    public var detail: String
    public var action: String
}

/// A small, usable next action, never a medical risk score or an inference about outside care.
public enum PatientHome {
    public static func appointment(_ state: CareState, now: Date = Date()) -> AppointmentShortcut {
        // Preserve the patient's place before offering a new preparation flow.
        let active = state.visitCompanions?.sessions.filter { $0.progress != .finished }.sorted {
            if $0.progress != $1.progress { return $0.progress == .inVisit }
            return $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt
        }.first
        if let active {
            return AppointmentShortcut(companionID: active.id, encounterID: active.encounterID, title: active.title,
                detail: active.progress == .inVisit ? "Your place and saved answers are here. Pick up where you left off." : "A short opening, your top questions, and a place to keep the answers.",
                action: active.progress == .inVisit ? "Continue my visit" : "Continue getting ready")
        }
        let next = state.upcomingAppointments(now: now).first
        // A recap can mention a different, future appointment. Its reporting encounter
        // must not become that appointment's encounter or medical event date.
        return AppointmentShortcut(companionID: nil, encounterID: nil,
            appointmentAt: next?.dueAt, appointmentTitle: next?.label,
            title: next?.label ?? "Walk in with your thoughts together",
            detail: next.map { claim in
                "Saved appointment: " + claim.dueAt!.formatted(date: .abbreviated, time: claim.dueTimeKnown ? .shortened : .omitted) + (claim.dueTimeKnown ? "." : ". Time not provided.")
            } ?? "You can prepare for a conversation even before an appointment is saved.",
            action: "Get ready for my visit")
    }

    /// Personal dates stay distinct from the timing recorded in medical evidence.
    public static func checkBacks(_ state: CareState, now: Date = Date(), calendar: Calendar = .current) -> [FollowThroughPlan] {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let openIDs = Set(state.loops.filter { [.open, .uncertain].contains($0.status) }.map(\.id))
        return (state.followThroughPlans?.plans ?? []).filter {
            openIDs.contains($0.loopID) && $0.checkBackAt.map { $0 < end } == true
        }.sorted {
            $0.checkBackAt == $1.checkBackAt ? $0.id.uuidString < $1.id.uuidString : $0.checkBackAt! < $1.checkBackAt!
        }
    }
}
