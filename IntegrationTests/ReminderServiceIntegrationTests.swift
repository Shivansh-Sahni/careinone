import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class ReminderServiceIntegrationTests: XCTestCase {
    private func state(enabled: Bool = true) -> CareState {
        var state = CareState(); state.profile.notifications = enabled; state.profile.notifyAppointments = true; state.profile.notifyTasks = false
        let source = Source(title: "Fictional reminder evidence", kind: .typed, text: "Fictional appointment A. Fictional appointment B.", contentHash: "synthetic-only")
        state.sources = [source]
        for (index, label) in ["Fictional appointment A", "Fictional appointment B"].enumerated() {
            var claim = Claim(sourceID: source.id, kind: .appointment, label: label, quote: label + ".")
            claim.review = .accepted; claim.action = .scheduled; claim.certainty = .documented
            claim.dueAt = Date().addingTimeInterval(Double(index + 7) * 86400); claim.duePrecision = .exact; claim.dueTimeKnown = true
            state.claims.append(claim)
        }
        Reconciler.rebuild(&state)
        return state
    }
    private func waitForPause(_ center: FakeReminderCenter) async -> Bool {
        for _ in 0..<100 {
            if await center.snapshot().paused { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
    func testDeniedPermissionClearsOnlyAppRequestsAndReportsRecoveryWithoutPrompting() async {
        let center = FakeReminderCenter(authorization: .denied)
        let result = await ReminderService(center: center).update(state())
        let snapshot = await center.snapshot()
        XCTAssertEqual(result.authorization, .denied); XCTAssertEqual(result.scheduledCount, 0)
        XCTAssertTrue(result.warningMessage?.contains("iOS Settings") == true)
        XCTAssertEqual(snapshot.pending, ["another-app-request"])
        XCTAssertEqual(snapshot.addAttempts, 0); XCTAssertEqual(snapshot.permissionRequests, 0)
    }
    func testPermissionRequestOccursOnlyForUndeterminedStatusAndChecksActualGrant() async throws {
        let center = FakeReminderCenter(authorization: .notDetermined)
        let service = ReminderService(center: center)
        let before = await service.update(state())
        XCTAssertEqual(before.authorization, .notDetermined); XCTAssertNotNil(before.warningMessage)
        let granted = try await service.authorize(); XCTAssertTrue(granted)
        let again = try await service.authorize(); XCTAssertTrue(again)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.permissionRequests, 1)
        let after = await service.update(state())
        XCTAssertEqual(after.scheduledCount, 2); XCTAssertEqual(after.failedCount, 0); XCTAssertNil(after.warningMessage)
    }
    func testPermissionRevokedAfterGrantIsRecheckedAndNeverReportedAsScheduled() async throws {
        let center = FakeReminderCenter(authorization: .authorized)
        let service = ReminderService(center: center)
        let first = await service.update(state()); XCTAssertEqual(first.scheduledCount, 2)
        await center.setAuthorization(.denied)
        let granted = try await service.authorize(); XCTAssertFalse(granted)
        let result = await service.update(state())
        XCTAssertEqual(result.authorization, .denied); XCTAssertEqual(result.scheduledCount, 0); XCTAssertNotNil(result.warningMessage)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.permissionRequests, 0)
        XCTAssertEqual(snapshot.pending, ["another-app-request"])
    }
    func testPartialSchedulingFailureIsCountedAndDoesNotEchoPrivateErrorText() async {
        let center = FakeReminderCenter(authorization: .authorized, failures: 1)
        let result = await ReminderService(center: center).update(state())
        XCTAssertEqual(result.plannedCount, 2); XCTAssertEqual(result.scheduledCount, 1); XCTAssertEqual(result.failedCount, 1)
        XCTAssertTrue(result.warningMessage?.contains("only 1 of 2") == true)
        XCTAssertFalse(result.statusMessage.contains("private fictional patient"))
        let snapshot = await center.snapshot()
        XCTAssertEqual(snapshot.pending.filter { $0.hasPrefix("care-") }.count, 1)
    }
    func testCompleteSchedulingFailureProvidesRetryWithoutFalseSuccess() async {
        let center = FakeReminderCenter(authorization: .authorized, failures: 2)
        let result = await ReminderService(center: center).update(state())
        XCTAssertEqual(result.plannedCount, 2); XCTAssertEqual(result.scheduledCount, 0); XCTAssertEqual(result.failedCount, 2)
        XCTAssertTrue(result.warningMessage?.contains("could not schedule") == true)
        XCTAssertFalse(result.statusMessage.contains("private fictional patient"))
    }
    func testDisablingRemindersClearsOnlyCareInOneRequests() async {
        let center = FakeReminderCenter(authorization: .authorized)
        let result = await ReminderService(center: center).update(state(enabled: false))
        XCTAssertFalse(result.enabled); XCTAssertEqual(result.scheduledCount, 0); XCTAssertNil(result.warningMessage)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.pending, ["another-app-request"]); XCTAssertEqual(snapshot.addAttempts, 0)
    }
    func testFictionalDemoNeverReadsOrChangesPersonalNotificationRequests() async {
        let center = FakeReminderCenter(authorization: .authorized)
        let result = await ReminderService(center: center).update(state(), isDemoWorkspace: true)
        XCTAssertTrue(result.isDemoWorkspace); XCTAssertNil(result.warningMessage)
        XCTAssertTrue(result.statusMessage.contains("does not schedule"))
        let snapshot = await center.snapshot()
        XCTAssertEqual(snapshot.totalCalls, 0); XCTAssertEqual(snapshot.pending, ["care-personal-existing", "another-app-request"])
    }
    func testOlderSchedulingCompletionCannotRepublishAfterRemindersAreDisabled() async {
        let center = FakeReminderCenter(authorization: .authorized, pauseNextAdd: true)
        let service = ReminderService(center: center)
        let original = state(); XCTAssertEqual(ReminderPlanner.plan(original).count, 2)
        let older = Task { await service.update(original) }
        let paused = await waitForPause(center); XCTAssertTrue(paused)
        let disabled = await service.update(state(enabled: false)); XCTAssertFalse(disabled.enabled)
        await center.resumeAdd()
        let oldResult = await older.value; XCTAssertTrue(oldResult.superseded); XCTAssertNil(oldResult.warningMessage)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.pending, ["another-app-request"])
    }
    func testOpeningDemoDoesNotInterruptPersonalSchedulingInProgress() async {
        let center = FakeReminderCenter(authorization: .authorized, pauseNextAdd: true)
        let service = ReminderService(center: center)
        let original = state(); XCTAssertEqual(ReminderPlanner.plan(original).count, 2)
        let personal = Task { await service.update(original) }
        let paused = await waitForPause(center); XCTAssertTrue(paused)
        let demo = await service.update(state(), isDemoWorkspace: true); XCTAssertTrue(demo.isDemoWorkspace)
        await center.resumeAdd()
        let result = await personal.value; XCTAssertFalse(result.superseded); XCTAssertEqual(result.scheduledCount, 2)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.pending.filter { $0.hasPrefix("care-") }.count, 2)
    }
    func testCancelledSchedulingCleansUpItsLateCompletion() async {
        let center = FakeReminderCenter(authorization: .authorized, pauseNextAdd: true)
        let service = ReminderService(center: center)
        let original = state(); XCTAssertEqual(ReminderPlanner.plan(original).count, 2)
        let work = Task { await service.update(original) }
        let paused = await waitForPause(center); XCTAssertTrue(paused)
        work.cancel(); await center.resumeAdd()
        let result = await work.value; XCTAssertTrue(result.superseded); XCTAssertNil(result.warningMessage)
        let snapshot = await center.snapshot(); XCTAssertEqual(snapshot.pending, ["another-app-request"])
    }
}

private actor FakeReminderCenter: ReminderNotificationCenter {
    struct Snapshot: Sendable {
        var pending: Set<String>; var permissionRequests: Int; var addAttempts: Int; var totalCalls: Int; var paused: Bool
    }
    private var status: ReminderAuthorization
    private var pending: Set<String> = ["care-personal-existing", "another-app-request"]
    private var permissionRequests = 0; private var addAttempts = 0; private var totalCalls = 0
    private var failures: Int; private var pauseNextAdd: Bool; private var suspendedAdd: CheckedContinuation<Void, Never>?
    init(authorization: ReminderAuthorization, failures: Int = 0, pauseNextAdd: Bool = false) { status = authorization; self.failures = failures; self.pauseNextAdd = pauseNextAdd }
    func authorization() async -> ReminderAuthorization { totalCalls += 1; return status }
    func requestPermission() async throws -> Bool { totalCalls += 1; permissionRequests += 1; status = .authorized; return true }
    func pendingIdentifiers() async -> [String] { totalCalls += 1; return Array(pending) }
    func removePending(_ identifiers: [String]) async { totalCalls += 1; pending.subtract(identifiers) }
    func add(_ reminder: NotificationReminder) async throws {
        totalCalls += 1; addAttempts += 1
        if pauseNextAdd { pauseNextAdd = false; await withCheckedContinuation { suspendedAdd = $0 } }
        if failures > 0 { failures -= 1; throw CareError.invalid("private fictional patient must never appear in scheduling feedback") }
        pending.insert(reminder.id)
    }
    func resumeAdd() { suspendedAdd?.resume(); suspendedAdd = nil }
    func setAuthorization(_ value: ReminderAuthorization) { status = value }
    func snapshot() -> Snapshot { Snapshot(pending: pending, permissionRequests: permissionRequests, addAttempts: addAttempts, totalCalls: totalCalls, paused: suspendedAdd != nil) }
}
