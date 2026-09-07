import Foundation
import UserNotifications
import EventKit
import CareCore

actor ReminderService {
    private static let shared = ReminderService()
    private var generation = UUID()
    static func requestPermission() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
    static func reconcile(_ state: CareState) async {
        await shared.apply(state)
    }
    private func apply(_ state: CareState) async {
        let batch = UUID(); generation = batch
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard generation == batch else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("care-") }.map(\.identifier))
        guard state.profile.notifications else { return }
        for reminder in ReminderPlanner.plan(state) {
            guard generation == batch else { return }
            let content = UNMutableNotificationContent(); content.title = "CareContinuity"; content.body = "You have a saved follow-through item to review."; content.sound = .default
            // Deliberately no health details, source quotes, names, or medication labels on the lock screen.
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let requestID = "care-" + batch.uuidString + "-" + reminder.id
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
            if generation != batch { center.removePendingNotificationRequests(withIdentifiers: [requestID]); return }
        }
    }
}
@MainActor enum CalendarService {
    static func addAppointment(_ claim: Claim) async throws {
        guard let date = claim.dueAt, claim.duePrecision == .exact else { throw CareError.invalid("Confirm an exact appointment date first.") }
        let store = EKEventStore()
        guard try await store.requestWriteOnlyAccessToEvents() else { throw CareError.invalid("Calendar permission was not granted.") }
        let event = EKEvent(eventStore: store); event.title = claim.label; event.startDate = date
        event.endDate = claim.dueTimeKnown ? date.addingTimeInterval(3600) : Calendar.current.date(byAdding:.day,value:1,to:date)
        event.isAllDay = !claim.dueTimeKnown; event.calendar = store.defaultCalendarForNewEvents
        event.notes = "Added by you from CareContinuity. Confirm time and duration with your appointment source."
        try store.save(event, span: .thisEvent)
    }
}
