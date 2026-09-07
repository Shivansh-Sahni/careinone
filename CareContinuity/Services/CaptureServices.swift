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
enum DocumentProcessor {
    static func imageFileExtension(_ data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source) else { return "jpg" }
        return UTType(type as String)?.preferredFilenameExtension ?? "jpg"
    }
    static func readOriginal(_ url: URL) throws -> ImportedEvidence {
        let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 30_000_000 else { throw CareError.invalid("Files must be smaller than 30 MB.") }
        let data = try Data(contentsOf: url); let ext = url.pathExtension.lowercased(); let title = url.deletingPathExtension().lastPathComponent
        guard ["pdf", "jpg", "jpeg", "png", "heic", "tiff", "txt", "text", "json", "md", "csv"].contains(ext) else { throw CareError.invalid("Choose a PDF, image, text file, or FHIR JSON file.") }
        let kind: SourceKind = ext == "pdf" ? .pdf : ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? .photo : ext == "json" ? .fhir : .textFile
        let text = [.fhir, .textFile].contains(kind) ? String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? "" : ""
        return ImportedEvidence(data: data, text: text, kind: kind, pages: [], ext: ext, title: title)
    }
    static func importFile(_ url: URL, language: String? = nil) async throws -> ImportedEvidence { try await process(readOriginal(url), language: language) }
    static func process(_ original: ImportedEvidence, language: String? = nil) async throws -> ImportedEvidence {
        let data = original.data, ext = original.ext, title = original.title
        if ext == "pdf" {
            do { let pages = try await pdf(data, language: language); return ImportedEvidence(data: data, text: pages.map(\.text).joined(separator: "\n\n"), kind: .pdf, pages: pages, ext: ext, title: title) }
            catch is CancellationError { throw CancellationError() }
            catch { return ImportedEvidence(data: data, text: "", kind: .pdf, pages: [], ext: ext, title: title, message: "Text extraction failed. Save the original and add a typed recap. \(error.localizedDescription)") }
        }
        if ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) {
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
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw CareError.invalid("This image could not be decoded.") }
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
            guard document.pageCount <= 200 else { throw CareError.invalid("Split PDFs longer than 200 pages before importing.") }
            var pages: [EvidencePage] = []
            for index in 0..<document.pageCount {
                try Task.checkCancellation(); guard let page = document.page(at: index) else { continue }
                var text = page.string ?? ""
                if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                    let bounds = page.bounds(for: .mediaBox); let scale = min(2.5, 2200 / max(bounds.width, bounds.height))
                    let thumbnail = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                    if let image = thumbnail.cgImage { text = try recognize(image, language: language) }
                }
                pages.append(EvidencePage(number: index + 1, text: text))
            }
            return pages
        }
        return try await withTaskCancellationHandler { let pages = try await worker.value; try Task.checkCancellation(); return pages } onCancel: { worker.cancel() }
    }
}

@MainActor @Observable final class AudioCapture: NSObject, AVAudioRecorderDelegate {
    var recording = false; var paused = false; var elapsed: TimeInterval = 0; var transcribing = false; var transcript = ""; var message = ""
    var segments: [TranscriptSegment] = []
    private var recorder: AVAudioRecorder?; private var clockTask: Task<Void, Never>?
    private var speechTask: SFSpeechRecognitionTask?
    private var interruption: NSObjectProtocol?
    private var recognitionContinuation: CheckedContinuation<String, Error>?
    private var recognitionID: UUID?
    func start(url: URL) async throws {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { throw CareError.invalid("Microphone access is disabled. Enable it in iOS Settings or type your recap.") }
        let session = AVAudioSession.sharedInstance(); try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP]); try session.setActive(true)
        recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
        recorder?.delegate = self
        guard recorder?.record() == true else { throw CareError.invalid("Recording could not start.") }
        recording = true; paused = false; elapsed = 0
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause(); self?.message = "Recording was interrupted and paused. Resume when everyone is ready." }
        }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250)); guard let self, !Task.isCancelled else { return }
                self.elapsed = self.recorder?.currentTime ?? self.elapsed
                if self.elapsed >= 7200 { self.pause(); self.message = "Two-hour limit reached. Stop and save this recording." }
            }
        }
    }
    func pause() { recorder?.pause(); paused = true }
    func resume() { guard elapsed < 7200 else { return }; if recorder?.record() == true { paused = false } }
    func stop() { elapsed = recorder?.currentTime ?? elapsed; recorder?.stop(); recording = false; paused = false; clockTask?.cancel(); clockTask = nil; if let interruption { NotificationCenter.default.removeObserver(interruption); self.interruption = nil }; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    func transcribe(_ url: URL) async throws -> String {
        cancelTranscription()
        let run = UUID(); recognitionID = run
        transcribing = true; defer { if recognitionID == run { transcribing = false; recognitionID = nil; speechTask = nil } }
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        try Task.checkCancellation(); guard recognitionID == run else { throw CancellationError() }
        guard status == .authorized, let recognizer = SFSpeechRecognizer(), recognizer.supportsOnDeviceRecognition else { throw CareError.invalid("On-device transcription is unavailable for this language/device. Audio is saved locally. Add an editable typed recap or try again later.") }
        let request = SFSpeechURLRecognitionRequest(url: url); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; request.addsPunctuation = true
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.recognitionContinuation = continuation
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
        speechTask?.cancel(); speechTask = nil
        if let continuation = recognitionContinuation { recognitionContinuation = nil; continuation.resume(throwing: CancellationError()) }
        transcribing = false
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor [weak self] in self?.stop(); self?.message = "Recording encountered a storage error. Review the saved audio." }
    }
}

@MainActor @Observable final class AudioPlayback: NSObject, AVAudioPlayerDelegate {
    var playing = false; private var player: AVAudioPlayer?
    func toggle(_ url: URL) throws {
        if playing { stop(); return }
        try AVAudioSession.sharedInstance().setCategory(.playback); try AVAudioSession.sharedInstance().setActive(true)
        player = try AVAudioPlayer(contentsOf: url); player?.delegate = self; playing = player?.play() == true
        if !playing { stop(); throw CareError.invalid("This saved audio could not be played.") }
    }
    func stop() { player?.stop(); playing = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor [weak self] in self?.stop() } }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) { Task { @MainActor [weak self] in self?.stop() } }
}
