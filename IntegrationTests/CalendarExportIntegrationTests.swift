import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class CalendarExportIntegrationTests: XCTestCase {
    private func example() throws -> (CareState, Claim) {
        let source = Source(title: "Fictional calendar source", kind: .typed, text: "Fictional appointment is scheduled.", contentHash: "fictional-only")
        var claim = Claim(sourceID: source.id, kind: .appointment, label: "Fictional appointment", quote: source.workingText)
        claim.action = .scheduled; claim.certainty = .documented
        claim.dueAt = Date().addingTimeInterval(7 * 86400); claim.duePrecision = .exact; claim.dueTimeKnown = true
        var state = CareState(); state.sources = [source]; try Reconciler.accept([claim], into: &state)
        return (state, try XCTUnwrap(state.claims.first))
    }
    private func waitForPermission(_ writer: FakeAppointmentCalendarWriter) async -> Bool {
        for _ in 0..<100 {
            if writer.paused { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
    func testSuccessCreatesOneEventAndPersistentReceiptPreventsRelaunchDuplicate() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(); let receipts = FakeAppointmentCalendarReceipts()
        let first = AppointmentCalendarExporter(writer: writer, receipts: receipts)
        let added = try await first.add(claim, state: state); XCTAssertEqual(added, .added)
        let second = AppointmentCalendarExporter(writer: writer, receipts: receipts)
        let repeated = try await second.add(claim, state: state); XCTAssertEqual(repeated, .alreadyAdded)
        XCTAssertEqual(writer.saveAttempts, 1); XCTAssertEqual(writer.permissionRequests, 1)
        XCTAssertEqual(receipts.keys.count, 1); XCTAssertFalse(receipts.keys.joined().contains("Fictional"))
    }
    func testConcurrentTapsNeverCreateTwoEvents() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(pausePermission: true)
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        let first = Task { try await exporter.add(claim, state: state) }
        let paused = await waitForPermission(writer); XCTAssertTrue(paused)
        do { _ = try await exporter.add(claim, state: state); XCTFail("Concurrent save must be blocked") }
        catch { XCTAssertTrue(error.localizedDescription.contains("already being saved")) }
        writer.resumePermission(); let result = try await first.value
        XCTAssertEqual(result, .added); XCTAssertEqual(writer.saveAttempts, 1); XCTAssertEqual(writer.permissionRequests, 1)
    }
    func testDeniedPermissionCreatesNoEventAndAllowsRecovery() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(granted: false)
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        do { _ = try await exporter.add(claim, state: state); XCTFail("Denied permission must fail") }
        catch { XCTAssertTrue(error.localizedDescription.contains("iOS Settings")) }
        XCTAssertEqual(writer.saveAttempts, 0); XCTAssertFalse(exporter.hasExport(claim))
        writer.granted = true
        let recovered = try await exporter.add(claim, state: state); XCTAssertEqual(recovered, .added)
        XCTAssertEqual(writer.saveAttempts, 1)
    }
    func testWriteFailureDoesNotRecordFalseSuccessAndCanRetry() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(failures: 1)
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        do { _ = try await exporter.add(claim, state: state); XCTFail("Failed event save must throw") }
        catch { XCTAssertTrue(error.localizedDescription.contains("was not saved")); XCTAssertFalse(error.localizedDescription.contains("private fictional")) }
        XCTAssertFalse(exporter.hasExport(claim))
        let recovered = try await exporter.add(claim, state: state); XCTAssertEqual(recovered, .added)
        XCTAssertEqual(writer.saveAttempts, 2); XCTAssertTrue(exporter.hasExport(claim))
    }
    func testUnsafeAndDemoAppointmentsNeverQueryCalendarPermission() async throws {
        var (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter()
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        do { _ = try await exporter.add(claim, state: state, isDemoWorkspace: true); XCTFail("Demo must not touch personal Calendar") } catch {}
        claim.negated = true; state.claims[0] = claim
        do { _ = try await exporter.add(claim, state: state); XCTFail("Negated appointment must not export") } catch {}
        XCTAssertEqual(writer.permissionRequests, 0); XCTAssertEqual(writer.saveAttempts, 0)
    }
    func testCancellationWhilePermissionIsPendingNeverSavesEvent() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(pausePermission: true)
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        let task = Task { try await exporter.add(claim, state: state) }
        let paused = await waitForPermission(writer); XCTAssertTrue(paused)
        task.cancel(); writer.resumePermission()
        do { _ = try await task.value; XCTFail("Cancelled export must not save") } catch is CancellationError {} catch { XCTFail("Expected cancellation") }
        XCTAssertEqual(writer.saveAttempts, 0); XCTAssertFalse(exporter.hasExport(claim))
    }
    func testChangedAppointmentWhilePermissionIsPendingRequiresReview() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(pausePermission: true)
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        var stillCurrent = true
        let task = Task { try await exporter.add(claim, state: state, stillEligible: { stillCurrent }) }
        let paused = await waitForPermission(writer); XCTAssertTrue(paused)
        stillCurrent = false; writer.resumePermission()
        do { _ = try await task.value; XCTFail("A changed appointment must not export the old snapshot") }
        catch { XCTAssertTrue(error.localizedDescription.contains("changed while")) }
        XCTAssertEqual(writer.saveAttempts, 0); XCTAssertFalse(exporter.hasExport(claim))
    }
    func testAnotherCopyRequiresExplicitOptInAndChangedDateDoesNotSilentlyDuplicate() async throws {
        var (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter()
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: FakeAppointmentCalendarReceipts())
        _ = try await exporter.add(claim, state: state)
        claim.dueAt = claim.dueAt!.addingTimeInterval(86400); claim.revision += 1; state.claims[0] = claim
        let repeated = try await exporter.add(claim, state: state); XCTAssertEqual(repeated, .alreadyAdded)
        XCTAssertEqual(writer.saveAttempts, 1)
        let explicit = try await exporter.add(claim, state: state, allowDuplicate: true); XCTAssertEqual(explicit, .added)
        XCTAssertEqual(writer.saveAttempts, 2)
    }
    func testClearingLocalReceiptsPreventsAnInFlightExportFromRestoringThem() async throws {
        let (state, claim) = try example(); let writer = FakeAppointmentCalendarWriter(pausePermission: true)
        let receipts = FakeAppointmentCalendarReceipts()
        let exporter = AppointmentCalendarExporter(writer: writer, receipts: receipts)
        let task = Task { try await exporter.add(claim, state: state) }
        let paused = await waitForPermission(writer); XCTAssertTrue(paused)
        exporter.clearExportReceipts(); writer.resumePermission()
        do { _ = try await task.value; XCTFail("A pending export cannot outlive a local erase") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Local records changed")) }
        XCTAssertEqual(writer.saveAttempts, 0); XCTAssertFalse(exporter.hasExport(claim))
    }
    func testLocalReceiptCleanupRemovesOnlyItsOwnPreference() throws {
        let suite = "CareInOne.CalendarReceiptTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unrelated preference", forKey: "unrelated")
        let receipts = LocalAppointmentCalendarReceipts(defaults: defaults)
        receipts.recordExport(for: "opaque key", snapshot: "opaque snapshot")
        XCTAssertTrue(receipts.hasExport(for: "opaque key"))
        receipts.clear()
        XCTAssertFalse(receipts.hasExport(for: "opaque key"))
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "unrelated preference")
    }
}

@MainActor private final class FakeAppointmentCalendarWriter: AppointmentCalendarWriter {
    var granted: Bool; var permissionRequests = 0; var saveAttempts = 0
    var failures: Int; var pausePermission: Bool; var continuation: CheckedContinuation<Void, Never>?
    var paused: Bool { continuation != nil }
    init(granted: Bool = true, failures: Int = 0, pausePermission: Bool = false) { self.granted = granted; self.failures = failures; self.pausePermission = pausePermission }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        if pausePermission { pausePermission = false; await withCheckedContinuation { continuation = $0 } }
        return granted
    }
    func save(_ claim: Claim) throws {
        saveAttempts += 1
        if failures > 0 { failures -= 1; throw CareError.invalid("private fictional patient details must not appear in feedback") }
    }
    func resumePermission() { continuation?.resume(); continuation = nil }
}

@MainActor private final class FakeAppointmentCalendarReceipts: AppointmentCalendarReceipts {
    private var receipts: [String: String] = [:]
    var keys: [String] { Array(receipts.keys) }
    func hasExport(for key: String) -> Bool { receipts[key] != nil }
    func recordExport(for key: String, snapshot: String) { receipts[key] = snapshot }
    func clear() { receipts.removeAll() }
}
