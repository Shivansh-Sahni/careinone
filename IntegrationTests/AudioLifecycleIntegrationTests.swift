import XCTest
import AVFoundation
import CareCore
@testable import CareContinuity

@MainActor final class AudioLifecycleIntegrationTests: XCTestCase {
    private let url = URL(fileURLWithPath: "/private/tmp/CareInOne-fictional-audio-lifecycle.m4a")
    func testDeniedMicrophoneNeverActivatesSessionOrCreatesRecorder() async throws {
        var created = 0; var activated = 0
        let capture = AudioCapture(makeRecorder: { _ in created += 1; return FakeAudioRecordingDevice() }, recordPermission: { false }, activateSession: { activated += 1 }, deactivateSession: {})
        do { try await capture.start(url: url); XCTFail("Denied microphone cannot start recording") }
        catch { XCTAssertTrue(error.localizedDescription.contains("iOS Settings")) }
        XCTAssertEqual(created, 0); XCTAssertEqual(activated, 0)
        XCTAssertFalse(capture.recording || capture.paused)
    }
    func testFailedRecordingStartRestoresIdleStateAndReleasesAudioSession() async throws {
        let recorder = FakeAudioRecordingDevice(); recorder.succeeds = false
        var deactivated = 0
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {}, deactivateSession: { deactivated += 1 })
        do { try await capture.start(url: url); XCTFail("Failed native start cannot report recording") } catch { }
        XCTAssertFalse(capture.recording || capture.paused)
        XCTAssertEqual(recorder.stopCalls, 1); XCTAssertEqual(deactivated, 1)
    }
    func testFailedResumeKeepsCapturedAudioPausedAndExplainsRecovery() async throws {
        let recorder = FakeAudioRecordingDevice()
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {}, deactivateSession: {})
        defer { capture.stop() }
        try await capture.start(url: url); capture.pause(); recorder.succeeds = false
        capture.resume()
        XCTAssertTrue(capture.recording && capture.paused)
        XCTAssertTrue(capture.message.contains("did not resume"))
        XCTAssertEqual(recorder.stopCalls, 0); XCTAssertEqual(recorder.recordCalls, 2)
        recorder.succeeds = true; capture.resume()
        XCTAssertTrue(capture.recording && !capture.paused); XCTAssertTrue(capture.message.isEmpty)
    }
    func testSessionReactivationFailureDoesNotLeakUnderlyingErrorOrAttemptRecording() async throws {
        let recorder = FakeAudioRecordingDevice(); var activationCalls = 0
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {
            activationCalls += 1
            if activationCalls > 1 { throw CareError.invalid("private fictional underlying error") }
        }, deactivateSession: {})
        defer { capture.stop() }
        try await capture.start(url: url); capture.pause(); capture.resume()
        XCTAssertTrue(capture.recording && capture.paused)
        XCTAssertEqual(recorder.recordCalls, 1)
        XCTAssertTrue(capture.message.contains("could not resume")); XCTAssertFalse(capture.message.contains("private"))
    }
    func testUnexpectedFinishClearsActiveCaptureAndPreservesElapsedAudioForReview() async throws {
        let recorder = FakeAudioRecordingDevice(); recorder.currentTime = 42
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {}, deactivateSession: {})
        try await capture.start(url: url); capture.pause()
        capture.recordingFinished(recorderID: ObjectIdentifier(recorder), successfully: false)
        XCTAssertFalse(capture.recording || capture.paused)
        XCTAssertEqual(capture.elapsed, 42); XCTAssertEqual(recorder.stopCalls, 1)
        XCTAssertTrue(capture.message.contains("may be incomplete"))
    }
    func testOldDelegateCallbacksCannotStopNewRecordingOrReplaceItsFeedback() async throws {
        let old = FakeAudioRecordingDevice(); let current = FakeAudioRecordingDevice(); var created = 0
        let capture = AudioCapture(makeRecorder: { _ in created += 1; return created == 1 ? old : current }, recordPermission: { true }, activateSession: {}, deactivateSession: {})
        defer { capture.stop() }
        try await capture.start(url: url); capture.stop(); try await capture.start(url: url)
        capture.recordingFinished(recorderID: ObjectIdentifier(old), successfully: false)
        capture.recordingFailed(recorderID: ObjectIdentifier(old))
        XCTAssertTrue(capture.recording && !capture.paused)
        XCTAssertEqual(current.stopCalls, 0); XCTAssertTrue(capture.message.isEmpty)
        capture.recordingFailed(recorderID: ObjectIdentifier(current))
        XCTAssertFalse(capture.recording); XCTAssertEqual(current.stopCalls, 1)
        XCTAssertTrue(capture.message.contains("storage error"))
    }
    func testDurationLimitDoesNotAttemptToResumeAndInactivePauseDoesNotInventRecordingState() async throws {
        let recorder = FakeAudioRecordingDevice()
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {}, deactivateSession: {})
        defer { capture.stop() }
        capture.pause(); XCTAssertFalse(capture.paused)
        try await capture.start(url: url); capture.pause(); capture.elapsed = 7200; capture.resume()
        XCTAssertEqual(recorder.recordCalls, 1); XCTAssertTrue(capture.paused)
        XCTAssertTrue(capture.message.contains("Two-hour limit"))
    }
}

@MainActor private final class FakeAudioRecordingDevice: AudioRecordingDevice {
    var currentTime: TimeInterval = 0
    weak var delegate: (any AVAudioRecorderDelegate)?
    var succeeds = true; var recordCalls = 0; var pauseCalls = 0; var stopCalls = 0
    func record() -> Bool { recordCalls += 1; return succeeds }
    func pause() { pauseCalls += 1 }
    func stop() { stopCalls += 1 }
}
