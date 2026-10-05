import Foundation
import UserNotifications
import EventKit
import CareCore

enum ReminderAuthorization: Equatable, Sendable {
    case notDetermined, denied, authorized, provisional, ephemeral, unavailable
    var permitsScheduling: Bool { [.authorized, .provisional, .ephemeral].contains(self) }
    var statusMessage: String {
        switch self {
        case .notDetermined: "iOS has not granted notification permission."
        case .denied: "Notifications are off in iOS Settings."
        case .authorized: "iOS allows notifications. Delivery also depends on Focus and notification settings."
        case .provisional: "iOS allows quiet notifications. Check iOS Settings if you want banners or sounds."
        case .ephemeral: "iOS currently allows temporary notifications."
        case .unavailable: "Notification permission could not be checked."
        }
    }
}

struct ReminderReconciliation: Equatable, Sendable {
    var enabled: Bool
    var authorization: ReminderAuthorization = .notDetermined
    var plannedCount = 0
    var scheduledCount = 0
    var failedCount = 0
    var superseded = false
    var isDemoWorkspace = false
    var warningMessage: String? {
        guard enabled, !superseded, !isDemoWorkspace else { return nil }
        switch authorization {
        case .denied:
            return "Your care is saved, but iOS has turned notifications off. Open iOS Settings → Notifications → CareInOne to allow reminders, then return to CareInOne."
        case .notDetermined:
            return "Your care is saved, but reminder permission has not been granted. Open CareInOne Settings, enable local reminders, and save preferences to request permission."
        case .unavailable:
            return "Your care is saved, but notification permission could not be checked. Return to CareInOne and retry reminder setup."
        case .authorized, .provisional, .ephemeral: break
        }
        guard failedCount > 0 else { return nil }
        if scheduledCount == 0 { return "Your care is saved, but iOS could not schedule your reminders. Open Settings and retry reminders; do not rely on an alert until setup succeeds." }
        return "Your care is saved, but only \(scheduledCount) of \(plannedCount) reminders were scheduled. Open Settings and retry reminders; some saved items will not send an alert."
    }
    var statusMessage: String {
        if isDemoWorkspace { return "Fictional practice does not schedule notifications or change your personal reminders." }
        if superseded { return "Reminder settings are being refreshed." }
        if !enabled { return "Local reminders are off in CareInOne." }
        if let warningMessage { return warningMessage }
        if plannedCount == 0 { return "Reminders are allowed. No upcoming items currently have an eligible explicit date." }
        return "\(scheduledCount) private reminder\(scheduledCount == 1 ? "" : "s") scheduled. \(authorization.statusMessage)"
    }
}

struct NotificationReminder: Equatable, Sendable {
    var id: String
    var date: Date
}

protocol ReminderNotificationCenter: Sendable {
    func authorization() async -> ReminderAuthorization
    func requestPermission() async throws -> Bool
    func pendingIdentifiers() async -> [String]
    func removePending(_ identifiers: [String]) async
    func add(_ reminder: NotificationReminder) async throws
}

private struct SystemReminderNotificationCenter: ReminderNotificationCenter {
    func authorization() async -> ReminderAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unavailable
        }
    }
    func requestPermission() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
    func pendingIdentifiers() async -> [String] { await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier) }
    func removePending(_ identifiers: [String]) async { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers) }
    func add(_ reminder: NotificationReminder) async throws {
        let content = UNMutableNotificationContent(); content.title = "CareInOne"; content.body = "You have a saved follow-through item to review."; content.sound = .default
        // No health details, source quotes, names, or medication labels on the lock screen.
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        try await UNUserNotificationCenter.current().add(request)
    }
}

actor ReminderService {
    private static let shared = ReminderService()
    private let center: any ReminderNotificationCenter
    private var generation = UUID()
    private init() { center = SystemReminderNotificationCenter() }
    init(center: any ReminderNotificationCenter) { self.center = center }
    static func requestPermission() async throws -> Bool { try await shared.authorize() }
    static func authorizationStatus() async -> ReminderAuthorization { await shared.center.authorization() }
    @discardableResult static func reconcile(_ state: CareState, isDemoWorkspace: Bool = false) async -> ReminderReconciliation {
        await shared.update(state, isDemoWorkspace: isDemoWorkspace)
    }
    func authorize() async throws -> Bool {
        let status = await center.authorization()
        if status.permitsScheduling { return true }
        guard status == .notDetermined else { return false }
        do {
            guard try await center.requestPermission() else { return false }
            return await center.authorization().permitsScheduling
        } catch { throw CareError.invalid("Notification permission could not be requested. Retry setup or review CareInOne in iOS Settings.") }
    }
    func update(_ state: CareState, isDemoWorkspace: Bool = false) async -> ReminderReconciliation {
        var result = ReminderReconciliation(enabled: state.profile.notifications, isDemoWorkspace: isDemoWorkspace)
        // Demo visits must never clear, replace, or interrupt personal requests.
        guard !isDemoWorkspace else { return result }
        let batch = UUID(); generation = batch
        let pending = await center.pendingIdentifiers()
        guard generation == batch, !Task.isCancelled else { result.superseded = true; return result }
        await center.removePending(pending.filter { $0.hasPrefix("care-") })
        guard generation == batch, !Task.isCancelled else { result.superseded = true; return result }
        guard state.profile.notifications else { return result }
        result.authorization = await center.authorization()
        guard generation == batch, !Task.isCancelled else { result.superseded = true; return result }
        guard result.authorization.permitsScheduling else { return result }
        let plan = ReminderPlanner.plan(state); result.plannedCount = plan.count
        for reminder in plan {
            guard generation == batch, !Task.isCancelled else { result.superseded = true; return result }
            let requestID = "care-" + batch.uuidString + "-" + reminder.id
            do { try await center.add(NotificationReminder(id: requestID, date: reminder.date)); result.scheduledCount += 1 }
            catch { result.failedCount += 1 }
            if generation != batch || Task.isCancelled {
                await center.removePending([requestID]); result.superseded = true; return result
            }
        }
        return result
    }
}
enum CalendarExportResult: Equatable { case added, alreadyAdded }

@MainActor protocol AppointmentCalendarWriter {
    func requestPermission() async throws -> Bool
    func save(_ claim: Claim) throws
}

@MainActor protocol AppointmentCalendarReceipts {
    func hasExport(for key: String) -> Bool
    func recordExport(for key: String, snapshot: String)
    func clear()
}

@MainActor private final class SystemAppointmentCalendarWriter: AppointmentCalendarWriter {
    private let store = EKEventStore()
    func requestPermission() async throws -> Bool { try await store.requestWriteOnlyAccessToEvents() }
    func save(_ claim: Claim) throws {
        guard let date = claim.dueAt, let calendar = store.defaultCalendarForNewEvents else { throw CareError.invalid("No writable calendar is available.") }
        let event = EKEvent(eventStore: store); event.title = claim.label; event.startDate = date
        event.endDate = claim.dueTimeKnown ? date.addingTimeInterval(3600) : Calendar.current.date(byAdding: .day, value: 1, to: date)
        event.isAllDay = !claim.dueTimeKnown; event.calendar = calendar
        event.notes = "Added by you from CareInOne. Confirm time and duration with your appointment source. Edits in CareInOne do not change this calendar copy."
        try store.save(event, span: .thisEvent)
    }
}

@MainActor final class LocalAppointmentCalendarReceipts: AppointmentCalendarReceipts {
    // Opaque hashes only; no medical dates, event identifiers or names in preferences.
    private let defaults: UserDefaults
    private let key = "CareInOne.calendarExportReceipts.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func hasExport(for key: String) -> Bool { defaults.dictionary(forKey: self.key)?[key] != nil }
    func recordExport(for key: String, snapshot: String) {
        var receipts = defaults.dictionary(forKey: self.key) as? [String: String] ?? [:]
        receipts[key] = snapshot
        defaults.set(receipts, forKey: self.key)
    }
    func clear() { defaults.removeObject(forKey: key) }
}

@MainActor final class AppointmentCalendarExporter {
    private let writer: any AppointmentCalendarWriter
    private let receipts: any AppointmentCalendarReceipts
    private var inFlight = Set<String>()
    private var generation = UUID()
    init(writer: any AppointmentCalendarWriter, receipts: any AppointmentCalendarReceipts) {
        self.writer = writer; self.receipts = receipts
    }
    func hasExport(_ claim: Claim) -> Bool { receipts.hasExport(for: AppointmentCalendarPolicy.claimKey(claim)) }
    func clearExportReceipts() { generation = UUID(); receipts.clear() }
    func add(_ claim: Claim, state: CareState, isDemoWorkspace: Bool = false, allowDuplicate: Bool = false, stillEligible: (() -> Bool)? = nil) async throws -> CalendarExportResult {
        guard !isDemoWorkspace else { throw CareError.invalid("Fictional practice does not add events to your personal calendar.") }
        guard AppointmentCalendarPolicy.canExport(claim, in: state) else { throw CareError.invalid("Only a reviewed, explicitly scheduled appointment with an exact date and no unresolved discrepancy can be added to Calendar.") }
        let key = AppointmentCalendarPolicy.claimKey(claim)
        guard !inFlight.contains(key) else { throw CareError.invalid("This appointment is already being saved to Calendar. Wait for that save to finish.") }
        if receipts.hasExport(for: key), !allowDuplicate { return .alreadyAdded }
        let operationGeneration = generation
        inFlight.insert(key); defer { inFlight.remove(key) }
        let permitted: Bool
        do { permitted = try await writer.requestPermission() }
        catch { throw CareError.invalid("Calendar access could not be checked. Retry or open iOS Settings to review CareInOne's Calendar permission.") }
        guard generation == operationGeneration else { throw CareError.invalid("Local records changed while Calendar access was being checked. This appointment was not added.") }
        guard permitted else { throw CareError.invalid("Calendar permission was not granted. Allow Calendar access for CareInOne in iOS Settings, then retry.") }
        try Task.checkCancellation()
        guard stillEligible?() != false else { throw CareError.invalid("The saved appointment changed while Calendar access was being checked. Review the current appointment before exporting it.") }
        do { try writer.save(claim) }
        catch { throw CareError.invalid("The appointment was not saved to Calendar. Check that a writable calendar is available and retry.") }
        receipts.recordExport(for: key, snapshot: AppointmentCalendarPolicy.receiptKey(claim))
        return .added
    }
}

@MainActor enum CalendarService {
    private static let exporter = AppointmentCalendarExporter(writer: SystemAppointmentCalendarWriter(), receipts: LocalAppointmentCalendarReceipts())
    static func hasExport(_ claim: Claim) -> Bool { exporter.hasExport(claim) }
    static func clearExportReceipts() { exporter.clearExportReceipts() }
    static func addAppointment(_ claim: Claim, state: CareState, isDemoWorkspace: Bool = false, allowDuplicate: Bool = false, stillEligible: (() -> Bool)? = nil) async throws -> CalendarExportResult {
        try await exporter.add(claim, state: state, isDemoWorkspace: isDemoWorkspace, allowDuplicate: allowDuplicate, stillEligible: stillEligible)
    }
}
