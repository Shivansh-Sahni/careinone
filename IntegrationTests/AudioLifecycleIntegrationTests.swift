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
        await capture.resume()
        XCTAssertTrue(capture.recording && capture.paused)
        XCTAssertTrue(capture.message.contains("did not resume"))
        XCTAssertEqual(recorder.stopCalls, 0); XCTAssertEqual(recorder.recordCalls, 2)
        recorder.succeeds = true; await capture.resume()
        XCTAssertTrue(capture.recording && !capture.paused); XCTAssertTrue(capture.message.isEmpty)
    }
    func testSessionReactivationFailureDoesNotLeakUnderlyingErrorOrAttemptRecording() async throws {
        let recorder = FakeAudioRecordingDevice(); var activationCalls = 0
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {
            activationCalls += 1
            if activationCalls > 1 { throw CareError.invalid("private fictional underlying error") }
        }, deactivateSession: {})
        defer { capture.stop() }
        try await capture.start(url: url); capture.pause(); await capture.resume()
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
        try await capture.start(url: url); capture.pause(); capture.elapsed = 7200; await capture.resume()
        XCTAssertEqual(recorder.recordCalls, 1); XCTAssertTrue(capture.paused)
        XCTAssertTrue(capture.message.contains("Two-hour limit"))
    }
    func testClosingNonAudioSourcesDoesNotConfigureOrDeactivateAnyAudioSession() {
        var activation = 0; var deactivation = 0
        let capture = AudioCapture(recordPermission: { true }, activateSession: { activation += 1 }, deactivateSession: { deactivation += 1 })
        let playback = AudioPlayback(activateSession: { activation += 1 }, deactivateSession: { deactivation += 1 })
        capture.stop(); capture.stop(); playback.stop(); playback.stop()
        XCTAssertEqual(activation, 0); XCTAssertEqual(deactivation, 0)
        XCTAssertFalse(capture.recording || playback.playing)
    }
    func testStopWhilePermissionIsPendingCannotStartMicrophoneAfterLeavingScreen() async throws {
        let gate = AudioTestGate(); var created = 0; var activated = 0
        let capture = AudioCapture(makeRecorder: { _ in created += 1; return FakeAudioRecordingDevice() }, recordPermission: { await gate.wait(); return true }, activateSession: { activated += 1 }, deactivateSession: {})
        let task = Task { try await capture.start(url: url) }
        await gate.waitForArrival(); capture.stop(); gate.open()
        do { try await task.value; XCTFail("A closed capture screen cannot begin recording after a permission response") } catch is CancellationError { }
        XCTAssertEqual(created, 0); XCTAssertEqual(activated, 0); XCTAssertFalse(capture.recording)
    }
    func testCancellationDuringActivationReleasesLateSessionWithoutCreatingRecorder() async throws {
        let gate = AudioTestGate(); var created = 0; var released = 0
        let capture = AudioCapture(makeRecorder: { _ in created += 1; return FakeAudioRecordingDevice() }, recordPermission: { true }, activateSession: { await gate.wait() }, deactivateSession: { released += 1 })
        let task = Task { try await capture.start(url: url) }
        await gate.waitForArrival(); task.cancel(); capture.stop(); gate.open()
        do { try await task.value; XCTFail("Cancelled session activation cannot resume recording") } catch is CancellationError { }
        XCTAssertEqual(created, 0); XCTAssertEqual(released, 1); XCTAssertFalse(capture.recording || capture.paused)
        capture.stop(); XCTAssertEqual(released, 1)
    }
    func testDuplicateStartWhileActivationPendingIsRejectedWithoutSecondPermissionOrRecorder() async throws {
        let gate = AudioTestGate(); let recorder = FakeAudioRecordingDevice(); var permissions = 0
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { permissions += 1; return true }, activateSession: { await gate.wait() }, deactivateSession: {})
        defer { capture.stop() }
        let first = Task { try await capture.start(url: url) }; await gate.waitForArrival()
        do { try await capture.start(url: url); XCTFail("A second tap cannot create overlapping microphone requests") } catch { XCTAssertTrue(error.localizedDescription.contains("already")) }
        XCTAssertEqual(permissions, 1); gate.open(); try await first.value
        XCTAssertEqual(recorder.recordCalls, 1); XCTAssertTrue(capture.recording)
    }
    func testInterruptionPausesRecordingAndStopIgnoresFurtherInterruptionNotifications() async throws {
        let recorder = FakeAudioRecordingDevice()
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: {}, deactivateSession: {})
        try await capture.start(url: url)
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        for _ in 0..<100 where !capture.paused { await Task.yield() }
        XCTAssertTrue(capture.recording && capture.paused); XCTAssertEqual(recorder.pauseCalls, 1)
        XCTAssertTrue(capture.message.contains("interrupted")); capture.stop()
        let message = capture.message
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        await Task.yield()
        XCTAssertEqual(recorder.pauseCalls, 1); XCTAssertEqual(capture.message, message)
    }
    func testStopDuringResumeCannotRestartRecorderAfterSessionResponse() async throws {
        let gate = AudioTestGate(); let recorder = FakeAudioRecordingDevice(); var activation = 0
        let capture = AudioCapture(makeRecorder: { _ in recorder }, recordPermission: { true }, activateSession: { activation += 1; if activation > 1 { await gate.wait() } }, deactivateSession: {})
        try await capture.start(url: url); capture.pause()
        let resume = Task { await capture.resume() }; await gate.waitForArrival(); capture.stop(); gate.open(); await resume.value
        XCTAssertFalse(capture.recording || capture.paused); XCTAssertEqual(recorder.recordCalls, 1); XCTAssertEqual(recorder.stopCalls, 1)
    }
    func testPlaybackFailureLeavesSavedSourceAvailableAndReleasesOnlyOnce() async throws {
        let player = FakeAudioPlayingDevice(); player.succeeds = false; var released = 0
        let playback = AudioPlayback(makePlayer: { _ in player }, activateSession: {}, deactivateSession: { released += 1 })
        do { try await playback.toggle(url); XCTFail("Native playback failure must be reported") }
        catch { XCTAssertTrue(error.localizedDescription.contains("source is still saved")) }
        XCTAssertFalse(playback.playing); XCTAssertEqual(player.stopCalls, 1); XCTAssertEqual(released, 1)
        playback.stop(); XCTAssertEqual(released, 1)
    }
    func testClosedSourceCancelsPendingPlaybackAndLateCompletionCannotPlayAudio() async throws {
        let gate = AudioTestGate(); var created = 0; var released = 0
        let playback = AudioPlayback(makePlayer: { _ in created += 1; return FakeAudioPlayingDevice() }, activateSession: { await gate.wait() }, deactivateSession: { released += 1 })
        let play = Task { try await playback.toggle(url) }; await gate.waitForArrival(); playback.stop(); gate.open()
        do { try await play.value; XCTFail("Leaving the source must cancel pending audio") } catch is CancellationError { }
        XCTAssertEqual(created, 0); XCTAssertEqual(released, 1); XCTAssertFalse(playback.playing)
    }
    func testPlaybackDelegateFromOldSourceCannotStopCurrentAudio() async throws {
        let old = FakeAudioPlayingDevice(); let current = FakeAudioPlayingDevice(); var created = 0
        let playback = AudioPlayback(makePlayer: { _ in created += 1; return created == 1 ? old : current }, activateSession: {}, deactivateSession: {})
        defer { playback.stop() }
        try await playback.toggle(url); playback.stop(); try await playback.toggle(url)
        playback.playbackEnded(playerID: ObjectIdentifier(old))
        XCTAssertTrue(playback.playing); XCTAssertEqual(current.stopCalls, 0)
        playback.playbackEnded(playerID: ObjectIdentifier(current)); XCTAssertFalse(playback.playing); XCTAssertEqual(current.stopCalls, 1)
    }
    func testSessionWorkRunsOffMainThreadAndObsoleteReleaseCannotStopNewOwner() async throws {
        let events = AudioSessionTestEvents()
        let coordinator = AudioSessionCoordinator(activate: { mode in events.append(mode == .recording ? "record" : "play") }, deactivate: { events.append("release") })
        let old = UUID(); let current = UUID()
        try await coordinator.acquire(old, mode: .recording)
        try await coordinator.acquire(current, mode: .playback)
        coordinator.release(old); await coordinator.waitUntilIdle()
        XCTAssertEqual(events.snapshot().events, ["record", "play"])
        coordinator.release(current); coordinator.release(current); await coordinator.waitUntilIdle()
        XCTAssertEqual(events.snapshot().events, ["record", "play", "release"])
        XCTAssertFalse(events.snapshot().usedMainThread, "AVAudioSession setup/cleanup cannot block the main UI thread")
    }
    func testSessionQueueFinishesReleaseBeforeFollowingActivation() async throws {
        let events = AudioSessionTestEvents()
        let coordinator = AudioSessionCoordinator(activate: { mode in events.append(mode == .recording ? "record" : "play") }, deactivate: { events.append("release") })
        let old = UUID(); let current = UUID()
        try await coordinator.acquire(old, mode: .recording); coordinator.release(old)
        try await coordinator.acquire(current, mode: .playback); coordinator.release(current); await coordinator.waitUntilIdle()
        XCTAssertEqual(events.snapshot().events, ["record", "release", "play", "release"])
        XCTAssertFalse(events.snapshot().usedMainThread)
    }

    func testReadAloudIdleDismissAndCompletedUtteranceReleaseOnlyOwnedSession() async throws {
        let speaker = FakeAudioSpeakingDevice(); var released = 0; var activated = 0
        let aloud = AudioReadAloud(speaker: speaker, activateSession: { activated += 1 }, deactivateSession: { released += 1 })
        aloud.stop(); XCTAssertEqual(activated, 0); XCTAssertEqual(released, 0)
        try await aloud.speak("Fictional opening brief.")
        let utterance = try XCTUnwrap(speaker.utterance)
        aloud.utteranceEnded(ObjectIdentifier(utterance)); aloud.stop()
        XCTAssertEqual(activated, 1); XCTAssertEqual(released, 1)
    }
    func testReadAloudStopWhileSessionPendingCannotSpeakAfterSheetDismissal() async throws {
        let gate = AudioTestGate(); let speaker = FakeAudioSpeakingDevice(); var released = 0
        let aloud = AudioReadAloud(speaker: speaker, activateSession: { await gate.wait() }, deactivateSession: { released += 1 })
        let speak = Task { try await aloud.speak("Fictional brief.") }; await gate.waitForArrival(); aloud.stop(); gate.open()
        do { try await speak.value; XCTFail("Dismissed brief cannot begin reading later") } catch is CancellationError { }
        XCTAssertNil(speaker.utterance); XCTAssertEqual(released, 1)
    }
    func testOldReadAloudCompletionCannotStopReplacementBrief() async throws {
        let speaker = FakeAudioSpeakingDevice(); var released = 0
        let aloud = AudioReadAloud(speaker: speaker, activateSession: {}, deactivateSession: { released += 1 })
        try await aloud.speak("Fictional first brief."); let old = try XCTUnwrap(speaker.utterance)
        try await aloud.speak("Fictional replacement brief."); let current = try XCTUnwrap(speaker.utterance)
        XCTAssertEqual(released, 1); aloud.utteranceEnded(ObjectIdentifier(old)); XCTAssertEqual(released, 1)
        aloud.utteranceEnded(ObjectIdentifier(current)); XCTAssertEqual(released, 2)
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

@MainActor private final class AudioTestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var arrived = false
    func wait() async { await withCheckedContinuation { continuation in self.continuation = continuation; arrived = true } }
    func waitForArrival() async { while !arrived { await Task.yield() } }
    func open() { continuation?.resume(); continuation = nil }
}
@MainActor private final class FakeAudioPlayingDevice: AudioPlayingDevice {
    weak var delegate: (any AVAudioPlayerDelegate)?
    var succeeds = true; var playCalls = 0; var stopCalls = 0
    func play() -> Bool { playCalls += 1; return succeeds }
    func stop() { stopCalls += 1 }
}
private final class AudioSessionTestEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    private var usedMainThread = false
    func append(_ event: String) { lock.withLock { events.append(event); usedMainThread = usedMainThread || Thread.isMainThread } }
    func snapshot() -> (events: [String], usedMainThread: Bool) { lock.withLock { (events, usedMainThread) } }
}

@MainActor private final class FakeAudioSpeakingDevice: AudioSpeakingDevice {
    weak var delegate: (any AVSpeechSynthesizerDelegate)?
    var utterance: AVSpeechUtterance?
    func speak(_ utterance: AVSpeechUtterance) { self.utterance = utterance }
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}
