import XCTest
@testable import CareCore

final class PatientHomeTests: XCTestCase {
    func testEmptyPatientCanPrepareWithoutAnInventedAppointment() {
        let action = PatientHome.appointment(CareState())
        XCTAssertNil(action.companionID)
        XCTAssertNil(action.encounterID)
        XCTAssertTrue(action.detail.contains("before an appointment is saved"))
    }

    func testResumePrioritizesAnInProgressConversationOverANewerDraft() throws {
        var state = CareState()
        let earlier = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try VisitCompanionEngine.create(title: "Earlier conversation", in: &state, now: earlier)
        try VisitCompanionEngine.setProgress(.inVisit, companionID: first, in: &state, now: earlier)
        let second = try VisitCompanionEngine.create(title: "New preparation", in: &state, now: earlier.addingTimeInterval(3600))
        XCTAssertEqual(PatientHome.appointment(state).companionID, first)
        try VisitCompanionEngine.setProgress(.finished, companionID: first, in: &state)
        XCTAssertEqual(PatientHome.appointment(state).companionID, second)
    }

    func testUnknownAppointmentTimingIsNotPromotedToAnUpcomingVisit() throws {
        var state = CareState()
        let source = Source(title: "An appointment", kind: .typed, text: "Appointment: cardiology", contentHash: "test")
        state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: .appointment, label: "cardiology", quote: source.originalText)
        claim.action = .scheduled; claim.eventAt = Date().addingTimeInterval(86400)
        try Reconciler.accept([claim], into: &state)
        XCTAssertFalse(PatientHome.appointment(state).detail.contains("Saved appointment:"))
    }

    func testFutureAppointmentDoesNotInheritTheEncounterWhereItWasMentioned() throws {
        var state = CareState()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let appointmentDate = now.addingTimeInterval(30 * 86400)
        let reportingEncounter = EncounterRecord(title: "Earlier PCP visit", date: now.addingTimeInterval(-86400))
        state.encounters.append(reportingEncounter)
        var source = Source(title: "PCP recap", kind: .typed, text: "Cardiology appointment next month", contentHash: "appointment-test")
        source.encounterID = reportingEncounter.id
        source.eventAt = reportingEncounter.date
        state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: .appointment, label: "Cardiology", quote: source.originalText)
        claim.action = .scheduled
        claim.dueAt = appointmentDate
        claim.duePrecision = .exact
        try Reconciler.accept([claim], into: &state)

        let shortcut = PatientHome.appointment(state, now: now)
        XCTAssertEqual(shortcut.appointmentAt, appointmentDate)
        XCTAssertEqual(shortcut.appointmentTitle, "Cardiology")
        XCTAssertNil(shortcut.encounterID, "The source's reporting visit is not the future appointment.")
    }

    func testPersonalCheckBackAppearsLocallyWithNotificationsOffAndNeverChangesClinicalDate() throws {
        var state = try fixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let loop = try XCTUnwrap(state.loops.first)
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var plan = try XCTUnwrap(FollowThroughAssistEngine.plan(for: loop.id, in: state))
        plan.checkBackAt = now.addingTimeInterval(-60)
        try FollowThroughAssistEngine.save(plan, in: &state)
        XCTAssertEqual(PatientHome.checkBacks(state, now: now).map(\.id), [plan.id])
        XCTAssertEqual(state.loops.first, loop)
        XCTAssertTrue(ReminderPlanner.plan(state, now: now).isEmpty)
        state.loopOverrides[loop.id] = LoopOverride()
        state.loopOverrides[loop.id]?.status = .completed
        state.loopOverrides[loop.id]?.evidenceIDs = loop.claimIDs
        Reconciler.rebuild(&state)
        XCTAssertTrue(PatientHome.checkBacks(state, now: now).isEmpty)
    }

    func testPersonalNotificationRespectsTaskConsentAndFutureDates() throws {
        var state = try fixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let loop = try XCTUnwrap(state.loops.first)
        _ = try FollowThroughAssistEngine.create(loopID: loop.id, in: &state)
        var plan = try XCTUnwrap(FollowThroughAssistEngine.plan(for: loop.id, in: state))
        plan.checkBackAt = now.addingTimeInterval(3600)
        try FollowThroughAssistEngine.save(plan, in: &state)
        state.profile.notifications = true
        XCTAssertEqual(ReminderPlanner.plan(state, now: now).map(\.date), [plan.checkBackAt!])
        state.profile.notifyTasks = false
        XCTAssertTrue(ReminderPlanner.plan(state, now: now).isEmpty)
        state.profile.notifyTasks = true
        XCTAssertTrue(ReminderPlanner.plan(state, now: now.addingTimeInterval(7200)).isEmpty)
    }

    private func fixture() throws -> CareState {
        var state = CareState()
        let source = Source(title: "Synthetic request", kind: .typed, text: "Lab: lipid panel ordered", contentHash: "test")
        state.sources.append(source)
        var claim = Claim(sourceID: source.id, kind: .labTest, label: "lipid panel", quote: source.originalText)
        claim.action = .ordered
        try Reconciler.accept([claim], into: &state)
        return state
    }
}
