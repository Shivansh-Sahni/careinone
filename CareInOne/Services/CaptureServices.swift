import Foundation
import AVFoundation
import Speech
import Vision
import PDFKit
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Observation
import CareCore

struct ImportedEvidence: Sendable { var data: Data; var text: String; var kind: SourceKind; var pages: [EvidencePage]; var ext: String; var title: String; var message: String = "" }
enum CaptureText {
    static let maximumCharacters = 1_000_000
    static func validate(_ text: String) throws {
        guard text.count <= maximumCharacters else { throw CareError.invalid("This source is longer than one million characters. Split it into smaller sources; your text has not been discarded.") }
    }
    static func appendingPaste(_ strings: [String], to current: String, limit: Int = maximumCharacters) throws -> String {
        let pasted = strings.filter { !$0.isEmpty }.joined(separator: "\n")
        guard !pasted.isEmpty else { return current }
        let separator = current.isEmpty || current.hasSuffix("\n") ? "" : "\n"
        let result = current + separator + pasted
        try validate(result)
        guard result.count <= limit else { throw CareError.invalid("Paste would exceed this field’s \(limit.formatted())-character limit. Your current text has been kept; shorten the pasted text and try again.") }
        return result
    }
}
enum DocumentProcessor {
    static func imageFileExtension(_ data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source) else { return "jpg" }
        return UTType(type as String)?.preferredFilenameExtension ?? "jpg"
    }
    static func readOriginal(_ url: URL) throws -> ImportedEvidence {
        let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 30_000_000 else { throw CareError.invalid("Files must be smaller than 30 MB.") }
        let ext = url.pathExtension.lowercased(); let title = url.deletingPathExtension().lastPathComponent
        guard ["pdf", "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif", "webp", "txt", "text", "json", "md", "csv"].contains(ext) else { throw CareError.invalid("Choose a PDF, image, text file, or FHIR JSON file.") }
        let data = try ArchiveCodec.readFile(url, limit: 30_000_000)
        let kind: SourceKind = ext == "pdf" ? .pdf : ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif", "webp"].contains(ext) ? .photo : ext == "json" ? .fhir : .textFile
        let text = [.fhir, .textFile].contains(kind) ? String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? "" : ""
        return ImportedEvidence(data: data, text: text, kind: kind, pages: [], ext: ext, title: title)
    }
    static func importFile(_ url: URL, language: String? = nil) async throws -> ImportedEvidence { try await process(readOriginal(url), language: language) }
    static func process(_ original: ImportedEvidence, language: String? = nil) async throws -> ImportedEvidence {
        let data = original.data, ext = original.ext, title = original.title
        if ext == "pdf" {
            do {
                let pages = try await pdf(data, language: language)
                let text = pages.map(\.text).joined(separator: "\n\n")
                return ImportedEvidence(data: data, text: text, kind: .pdf, pages: pages, ext: ext, title: title, message: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No readable text found. The original PDF is preserved; add a typed recap or retry extraction from Sources." : "")
            }
            catch is CancellationError { throw CancellationError() }
            catch { return ImportedEvidence(data: data, text: "", kind: .pdf, pages: [], ext: ext, title: title, message: "Text extraction failed. Save the original and add a typed recap. \(error.localizedDescription)") }
        }
        if ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif", "webp"].contains(ext) {
            let text: String
            do { text = try await ocr(data, language: language) } catch is CancellationError { throw CancellationError() } catch { text = "" }
            return ImportedEvidence(data: data, text: text, kind: .photo, pages: [], ext: ext, title: title, message: text.isEmpty ? "No readable text found. You can save the image and add a recap." : "")
        }
        guard ["txt", "text", "json", "md", "csv"].contains(ext), let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else { throw CareError.invalid("Choose a PDF, image, UTF-8/UTF-16 text file, or FHIR JSON file.") }
        return ImportedEvidence(data: data, text: text, kind: ext == "json" ? .fhir : .textFile, pages: [], ext: ext, title: title)
    }
    static func ocr(_ data: Data, language: String? = nil) async throws -> String {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 4096, kCGImageSourceShouldCache: false] as CFDictionary) else { throw CareError.invalid("This image could not be decoded.") }
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            let orientation = CGImagePropertyOrientation(rawValue: (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1) ?? .up
            return try recognize(image, orientation: orientation, language: language)
        }
        return try await withTaskCancellationHandler { let text = try await worker.value; try Task.checkCancellation(); return text } onCancel: { worker.cancel() }
    }
    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up, language: String? = nil) throws -> String {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        let preferred = language.map { [$0] } ?? Locale.preferredLanguages
        var selected: [String] = []
        for preferred in preferred {
            let base = preferred.split(separator:"-").first
            if let match = supported.first(where: { $0 == preferred }) ?? supported.first(where: { $0.split(separator:"-").first == base }), !selected.contains(match) { selected.append(match) }
        }
        // Automatic script detection can confuse short Latin abbreviations with
        // Cyrillic lookalikes. Prefer the chosen/device languages; retain opt-in auto.
        request.automaticallyDetectsLanguage = language == "auto" || selected.isEmpty
        if !selected.isEmpty { request.recognitionLanguages = Array(selected.prefix(1)) }
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        try Task.checkCancellation()
        let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
        let latin = ["en", "es", "fr", "de", "it", "pt"].contains(selected.first?.components(separatedBy:"-").first ?? "")
        let cyrillic = #"[\u0400-\u04FF]"#
        if !request.automaticallyDetectsLanguage && latin && text.range(of:cyrillic,options:.regularExpression) != nil {
            // iOS 18's accurate engine can emit Cyrillic lookalikes even with an
            // English hint. Independently recognize with its Latin fast model.
            let fallback = VNRecognizeTextRequest(); fallback.recognitionLevel = .fast; fallback.usesLanguageCorrection = true
            let supported = try fallback.supportedRecognitionLanguages()
            if let chosen = selected.first, supported.contains(chosen) {
                fallback.recognitionLanguages = [chosen]
                try VNImageRequestHandler(cgImage:image,orientation:orientation).perform([fallback]); try Task.checkCancellation()
                let alternate = fallback.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator:"\n") ?? ""
                if !alternate.isEmpty && alternate.range(of:cyrillic,options:.regularExpression) == nil { return alternate }
            }
        }
        return text
    }
    static func pdf(_ data: Data, language: String? = nil) async throws -> [EvidencePage] {
        let worker = Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(data: data), !document.isLocked else { throw CareError.invalid("This PDF is locked or unreadable. Unlock it before importing.") }
            guard document.pageCount > 0 else { throw CareError.invalid("This PDF has no readable pages.") }
            guard document.pageCount <= 200 else { throw CareError.invalid("Split PDFs longer than 200 pages before importing.") }
            var pages: [EvidencePage] = []; var textCount = 0
            for index in 0..<document.pageCount {
                try Task.checkCancellation(); guard let page = document.page(at: index) else { continue }
                var text = page.string ?? ""
                if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                    let bounds = page.bounds(for: .mediaBox)
                    guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { throw CareError.invalid("This PDF has invalid page dimensions.") }
                    let scale = min(2.5, 2200 / max(bounds.width, bounds.height))
                    let thumbnail = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                    if let image = thumbnail.cgImage {
                        let recognized = try recognize(image, language: language)
                        // A failed scan must not erase a short but valid embedded text layer.
                        if !recognized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { text = recognized }
                    }
                }
                textCount += text.count
                guard textCount <= 1_000_000 else { throw CareError.invalid("Split documents with more than one million text characters before analysis.") }
                pages.append(EvidencePage(number: index + 1, text: text))
            }
            return pages
        }
        return try await withTaskCancellationHandler { let pages = try await worker.value; try Task.checkCancellation(); return pages } onCancel: { worker.cancel() }
    }
}

// AVAudioSession activation may block. Serialize it away from UI work, and release
// only the run that owns the session so delayed cancellation cannot stop new audio.
enum AudioSessionMode: Sendable { case recording, playback, spoken }
final class AudioSessionCoordinator: @unchecked Sendable {
    static let shared = AudioSessionCoordinator()
    private let queue = DispatchQueue(label: "org.careinone.audio-session")
    private var owner: UUID?
    private let activate: @Sendable (AudioSessionMode) throws -> Void
    private let deactivate: @Sendable () -> Void
    init(activate: @escaping @Sendable (AudioSessionMode) throws -> Void = { mode in
        let session = AVAudioSession.sharedInstance()
        if mode == .recording { try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP]) }
        else if mode == .spoken { try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers) }
        else { try session.setCategory(.playback) }
        try session.setActive(true)
    }, deactivate: @escaping @Sendable () -> Void = {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }) { self.activate = activate; self.deactivate = deactivate }
    func acquire(_ run: UUID, mode: AudioSessionMode) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do { try activate(mode); owner = run; continuation.resume() }
                catch { if owner == nil { deactivate() }; continuation.resume(throwing: error) }
            }
        }
    }
    func release(_ run: UUID) {
        queue.async { [self] in
            guard owner == run else { return }
            owner = nil; deactivate()
        }
    }
    func waitUntilIdle() async {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
    }
}

@MainActor protocol AudioRecordingDevice: AnyObject {
    var currentTime: TimeInterval { get }
    var delegate: (any AVAudioRecorderDelegate)? { get set }
    func record() -> Bool
    func pause()
    func stop()
}
extension AVAudioRecorder: AudioRecordingDevice { }

@MainActor @Observable final class AudioCapture: NSObject, AVAudioRecorderDelegate {
    var recording = false; var paused = false; var elapsed: TimeInterval = 0; var transcribing = false; var transcript = ""; var message = ""
    var segments: [TranscriptSegment] = []
    private var recorder: (any AudioRecordingDevice)?; private var clockTask: Task<Void, Never>?
    private let makeRecorder: (URL) throws -> any AudioRecordingDevice
    private let recordPermission: () async -> Bool
    private let activateSession: (UUID) async throws -> Void
    private let deactivateSession: (UUID) -> Void
    private var startingID: UUID?
    private var resumingID: UUID?
    private var sessionID: UUID?
    private var speechTask: SFSpeechRecognitionTask?
    private var interruption: NSObjectProtocol?
    private var recognitionContinuation: CheckedContinuation<String, Error>?
    private var recognitionID: UUID?
    private var recognitionTimeout: Task<Void, Never>?
    init(makeRecorder: @escaping (URL) throws -> any AudioRecordingDevice = { url in
        try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
    }, recordPermission: @escaping () async -> Bool = { await AVAudioApplication.requestRecordPermission() }, activateSession: (() async throws -> Void)? = nil, deactivateSession: (() -> Void)? = nil) {
        self.makeRecorder = makeRecorder; self.recordPermission = recordPermission
        self.activateSession = { run in if let activateSession { try await activateSession() } else { try await AudioSessionCoordinator.shared.acquire(run, mode: .recording) } }
        self.deactivateSession = { run in if let deactivateSession { deactivateSession() } else { AudioSessionCoordinator.shared.release(run) } }
        super.init()
    }
    func start(url: URL) async throws {
        guard !recording, startingID == nil else { throw CareError.invalid("A recording is already in progress.") }
        let run = UUID(); startingID = run
        defer { if startingID == run { startingID = nil } }
        try Task.checkCancellation()
        let allowed = await recordPermission()
        try Task.checkCancellation()
        guard startingID == run else { throw CancellationError() }
        guard allowed else { throw CareError.invalid("Microphone access is disabled. Enable it in iOS Settings or type your recap.") }
        transcript = ""; segments = []; message = ""
        do {
        try await activateSession(run)
        guard startingID == run, !Task.isCancelled else { deactivateSession(run); throw CancellationError() }
        sessionID = run
        recorder = try makeRecorder(url)
        recorder?.delegate = self
        guard recorder?.record() == true else { throw CareError.invalid("Recording could not start.") }
        recording = true; paused = false; elapsed = 0
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in if began, self?.recording == true { self?.pause(); self?.message = "Recording was interrupted and paused. Resume when everyone is ready." } }
        }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250)); guard let self, !Task.isCancelled else { return }
                self.elapsed = self.recorder?.currentTime ?? self.elapsed
                if self.elapsed >= 7200 { self.pause(); self.message = "Two-hour limit reached. Stop and save this recording." }
            }
        }
        } catch { if startingID == run || sessionID == run { stop() }; throw error }
    }
    func pause() { guard recording else { return }; recorder?.pause(); paused = true }
    func resume() async {
        guard recording, paused, let session = sessionID, resumingID == nil else { return }
        guard elapsed < 7200 else { message = "Two-hour limit reached. Stop and save this recording."; return }
        let run = UUID(); resumingID = run
        defer { if resumingID == run { resumingID = nil } }
        do { try await activateSession(session) }
        catch {
            guard recording, sessionID == session else { return }
            message = "The microphone could not resume. The recording remains saved. Stop to review it or retry when audio access is available."; return
        }
        guard recording, sessionID == session, resumingID == run, !Task.isCancelled else { deactivateSession(session); return }
        if recorder?.record() == true { paused = false; message = "" }
        else { message = "Recording did not resume. The captured audio remains saved. Try again or stop to review it." }
    }
    func stop() {
        startingID = nil; resumingID = nil
        elapsed = recorder?.currentTime ?? elapsed; recorder?.stop(); recorder = nil
        recording = false; paused = false; clockTask?.cancel(); clockTask = nil
        if let interruption { NotificationCenter.default.removeObserver(interruption); self.interruption = nil }
        if let session = sessionID { sessionID = nil; deactivateSession(session) }
    }
    func transcribe(_ url: URL) async throws -> String {
        cancelTranscription()
        let run = UUID(); recognitionID = run
        transcribing = true; transcript = ""; segments = []
        defer { if recognitionID == run { transcribing = false; recognitionID = nil; speechTask = nil; recognitionTimeout?.cancel(); recognitionTimeout = nil } }
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        try Task.checkCancellation(); guard recognitionID == run else { throw CancellationError() }
        guard status == .authorized, let recognizer = SFSpeechRecognizer(), recognizer.supportsOnDeviceRecognition else { throw CareError.invalid("On-device transcription is unavailable for this language/device. Audio is saved locally. Add an editable typed recap or try again later.") }
        let request = SFSpeechURLRecognitionRequest(url: url); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; request.addsPunctuation = true
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.recognitionContinuation = continuation
                recognitionTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(300)) } catch { return }
                    guard let self, self.recognitionID == run, let pending = self.recognitionContinuation else { return }
                    self.recognitionContinuation = nil; self.speechTask?.cancel()
                    pending.resume(throwing: CareError.invalid("On-device transcription took too long. Your audio remains saved. Retry with a shorter recording or type a recap."))
                }
                speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    // Speech's callback may run on a private queue; transfer value types only.
                    let text = result?.bestTranscription.formattedString; let final = result?.isFinal ?? false; let failed = error != nil
                    let segments = result?.bestTranscription.segments.map { TranscriptSegment(text: $0.substring, startUTF16: $0.substringRange.location, lengthUTF16: $0.substringRange.length, seconds: $0.timestamp) } ?? []
                    Task { @MainActor in
                        guard let self, self.recognitionID == run else { return }
                        if let text { self.transcript = text }
                        self.segments = segments
                        if final, let continuation = self.recognitionContinuation { self.recognitionContinuation = nil; continuation.resume(returning: text ?? "") }
                        else if failed, let continuation = self.recognitionContinuation { self.recognitionContinuation = nil; continuation.resume(throwing: CareError.invalid("Transcription was interrupted. Audio remains saved; retry or type a recap.")) }
                    }
                }
            }
        } onCancel: { Task { @MainActor [weak self] in if self?.recognitionID == run { self?.cancelTranscription() } } }
    }
    func cancelTranscription() {
        recognitionID = nil
        recognitionTimeout?.cancel(); recognitionTimeout = nil
        speechTask?.cancel(); speechTask = nil
        if let continuation = recognitionContinuation { recognitionContinuation = nil; continuation.resume(throwing: CancellationError()) }
        transcribing = false
    }
    func recordingFinished(recorderID: ObjectIdentifier, successfully: Bool) {
        guard recording, recorder.map(ObjectIdentifier.init) == recorderID else { return }
        stop()
        message = successfully ? "Recording stopped. Review the captured audio or transcribe it before saving your recap." : "Recording stopped unexpectedly. Captured audio may be incomplete. Review it or make another recording; your saved sources remain available."
    }
    func recordingFailed(recorderID: ObjectIdentifier) {
        guard recording, recorder.map(ObjectIdentifier.init) == recorderID else { return }
        stop(); message = "Recording encountered a storage error. Review the saved audio."
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let identifier = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in self?.recordingFinished(recorderID: identifier, successfully: flag) }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        let identifier = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in self?.recordingFailed(recorderID: identifier) }
    }
}

@MainActor protocol AudioPlayingDevice: AnyObject {
    var delegate: (any AVAudioPlayerDelegate)? { get set }
    func play() -> Bool
    func stop()
}
extension AVAudioPlayer: AudioPlayingDevice { }

@MainActor @Observable final class AudioPlayback: NSObject, AVAudioPlayerDelegate {
    var playing = false
    private var player: (any AudioPlayingDevice)?
    private var startingID: UUID?
    private var sessionID: UUID?
    private let makePlayer: (URL) throws -> any AudioPlayingDevice
    private let activateSession: (UUID) async throws -> Void
    private let deactivateSession: (UUID) -> Void
    init(makePlayer: @escaping (URL) throws -> any AudioPlayingDevice = { try AVAudioPlayer(contentsOf: $0) }, activateSession: (() async throws -> Void)? = nil, deactivateSession: (() -> Void)? = nil) {
        self.makePlayer = makePlayer
        self.activateSession = { run in if let activateSession { try await activateSession() } else { try await AudioSessionCoordinator.shared.acquire(run, mode: .playback) } }
        self.deactivateSession = { run in if let deactivateSession { deactivateSession() } else { AudioSessionCoordinator.shared.release(run) } }
        super.init()
    }
    func toggle(_ url: URL) async throws {
        try Task.checkCancellation()
        if playing || startingID != nil { stop(); return }
        let run = UUID(); startingID = run
        defer { if startingID == run { startingID = nil } }
        do {
            try await activateSession(run)
            guard startingID == run, !Task.isCancelled else { deactivateSession(run); throw CancellationError() }
            sessionID = run
            player = try makePlayer(url); player?.delegate = self
            playing = player?.play() == true
            guard playing else { throw CareError.invalid("This saved audio could not be played.") }
        } catch is CancellationError { if sessionID == run || startingID == run { stop() }; throw CancellationError() }
        catch {
            if sessionID == run || startingID == run { stop() }
            throw CareError.invalid("This saved audio could not be played. The source is still saved; review its transcript or retry with audio access available.")
        }
    }
    func stop() {
        startingID = nil; player?.stop(); player = nil; playing = false
        if let session = sessionID { sessionID = nil; deactivateSession(session) }
    }
    func playbackEnded(playerID: ObjectIdentifier) {
        guard player.map(ObjectIdentifier.init) == playerID else { return }
        stop()
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identifier = ObjectIdentifier(player)
        Task { @MainActor [weak self] in self?.playbackEnded(playerID: identifier) }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let identifier = ObjectIdentifier(player)
        Task { @MainActor [weak self] in self?.playbackEnded(playerID: identifier) }
    }
}

@MainActor protocol AudioSpeakingDevice: AnyObject {
    var delegate: (any AVSpeechSynthesizerDelegate)? { get set }
    func speak(_ utterance: AVSpeechUtterance)
    @discardableResult func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}
extension AVSpeechSynthesizer: AudioSpeakingDevice { }

@MainActor @Observable final class AudioReadAloud: NSObject, AVSpeechSynthesizerDelegate {
    private let speaker: any AudioSpeakingDevice
    private let activateSession: (UUID) async throws -> Void
    private let deactivateSession: (UUID) -> Void
    private var runID: UUID?
    private var sessionID: UUID?
    private var utteranceID: ObjectIdentifier?
    init(speaker: any AudioSpeakingDevice = AVSpeechSynthesizer(), activateSession: (() async throws -> Void)? = nil, deactivateSession: (() -> Void)? = nil) {
        self.speaker = speaker
        self.activateSession = { run in if let activateSession { try await activateSession() } else { try await AudioSessionCoordinator.shared.acquire(run, mode: .spoken) } }
        self.deactivateSession = { run in if let deactivateSession { deactivateSession() } else { AudioSessionCoordinator.shared.release(run) } }
        super.init(); self.speaker.delegate = self
    }
    func speak(_ text: String) async throws {
        try Task.checkCancellation()
        stop(); let run = UUID(); runID = run
        do {
            try await activateSession(run)
            guard runID == run, !Task.isCancelled else { deactivateSession(run); throw CancellationError() }
            sessionID = run
            let utterance = AVSpeechUtterance(string: text); utteranceID = ObjectIdentifier(utterance)
            speaker.speak(utterance)
        } catch { if runID == run { stop() }; throw error }
    }
    func stop() {
        runID = nil; utteranceID = nil; speaker.stopSpeaking(at: .immediate)
        if let session = sessionID { sessionID = nil; deactivateSession(session) }
    }
    func utteranceEnded(_ identifier: ObjectIdentifier) {
        guard utteranceID == identifier else { return }
        stop()
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.utteranceEnded(identifier) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.utteranceEnded(identifier) }
    }
}
