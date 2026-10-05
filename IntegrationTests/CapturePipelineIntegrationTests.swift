import XCTest
import SwiftData
import PDFKit
import UIKit
import CareCore
@testable import CareContinuity

@MainActor final class CapturePipelineIntegrationTests: XCTestCase {
    func testEditedEvidenceRetiresReportsAndPersistsTruthfulAnalysisStatus() throws {
        let root = try makeVault(); let cleanup = root.root
        addTeardownBlock { try? FileManager.default.removeItem(at: cleanup) }
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let original = "Allergy: latex.\nAllergy: penicillin."
        let bytes = Data(original.utf8)
        let id = try store.capture(title: "Fictional source-status check", kind: .textFile, text: original, data: bytes, extension: "txt", analyze: false)
        var accepted = Claim(sourceID: id, kind: .allergy, label: "latex", quote: "Allergy: latex.")
        accepted.userEdited = true; accepted.confidence = 1
        XCTAssertTrue(store.accept([accepted]))
        let pending = Claim(sourceID: id, kind: .allergy, label: "penicillin", quote: "Allergy: penicillin.")
        XCTAssertTrue(store.mutate { state in
            state.claims.append(pending)
            let index = state.sources.firstIndex { $0.id == id }!
            state.sources[index].state = .needsReview
            state.sources[index].processingMessage = "2 proposals ready. Nothing enters My Care until you review it."
        })
        let originalFile = try XCTUnwrap(store.source(id)?.originalFile)
        XCTAssertTrue(store.editSource(id, title: "Fictional source-status check", text: "Allergy: penicillin.", event: nil, encounter: nil, provider: ""))
        let changed = try XCTUnwrap(store.source(id))
        XCTAssertEqual(changed.state, .pending)
        XCTAssertTrue(changed.processingMessage.contains("withdrawn from My Care"))
        XCTAssertTrue(changed.processingMessage.contains("Analyze the updated source"))
        XCTAssertFalse(changed.processingMessage.contains("2 proposals ready"))
        XCTAssertTrue(store.state.claims.filter { $0.sourceID == id }.allSatisfy { $0.review == .rejected })
        XCTAssertTrue(store.state.entities.isEmpty)
        XCTAssertEqual(try Data(contentsOf: root.url(originalFile)), bytes)

        let reopened = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        XCTAssertEqual(reopened.source(id)?.processingMessage, changed.processingMessage)
        XCTAssertTrue(reopened.editSource(id, title: "Fictional source-status check", text: " \n ", event: nil, encounter: nil, provider: ""))
        let cleared = try XCTUnwrap(reopened.source(id))
        XCTAssertEqual(cleared.state, .saved)
        XCTAssertTrue(cleared.processingMessage.hasPrefix("Working text cleared."))
        XCTAssertTrue(cleared.processingMessage.contains("Add working text before analysis"))
        XCTAssertEqual(cleared.originalText, original)
        XCTAssertTrue(cleared.previousText.contains(original))
        XCTAssertTrue(cleared.previousText.contains("Allergy: penicillin."))
        XCTAssertEqual(try Data(contentsOf: root.url(originalFile)), bytes)
        let clearedReopened = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        XCTAssertEqual(clearedReopened.source(id)?.processingMessage, cleared.processingMessage)
    }

    func testDateOnlySourceChangeRequiresReanalysisAndTitleOnlyEditKeepsCurrentStatus() throws {
        let root = try makeVault(); let cleanup = root.root
        addTeardownBlock { try? FileManager.default.removeItem(at: cleanup) }
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let id = try store.capture(title: "Fictional unreviewed source", kind: .typed, text: "Bring my list.", analyze: false)
        XCTAssertTrue(store.editSource(id, title: "Fictional new title", text: "Bring my list.", event: Date(timeIntervalSince1970: 1_760_000_000), encounter: nil, provider: ""))
        let updated = try XCTUnwrap(store.source(id))
        XCTAssertEqual(updated.state, .pending)
        XCTAssertTrue(updated.processingMessage.contains("event date changed"))
        XCTAssertFalse(updated.processingMessage.contains("withdrawn"))
        XCTAssertTrue(store.editSource(id, title: "Fictional renamed source", text: updated.workingText, event: updated.eventAt, encounter: nil, provider: ""))
        XCTAssertEqual(store.source(id)?.processingMessage, updated.processingMessage)
        XCTAssertEqual(store.source(id)?.version, updated.version)
    }

    func testMultilineUnicodePasteSurvivesCaptureRelaunchAndDuplicateSubmission() throws {
        let root = try makeVault(); let cleanupRoot1 = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let first = "Patient recap 🫶🏽\nAllergy: latex\n"
        let pasted = "Bring my medication list.\nQuestions:\n• Can we review this together?\n保留原文"
        let text = try CaptureText.appendingPaste([pasted], to: first)
        XCTAssertEqual(text, first + pasted)
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let id = try store.capture(title: "My complete recap", kind: .typed, text: text, analyze: false)
        XCTAssertEqual(try store.capture(title: "Repeated save", kind: .typed, text: text, analyze: false), id)
        XCTAssertEqual(store.state.sources.count, 1)
        let restored = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        XCTAssertEqual(restored.source(id)?.originalText, text)
        XCTAssertEqual(restored.source(id)?.workingText, text)
        XCTAssertTrue(restored.state.claims.isEmpty)
    }

    func testIdenticalEvidenceAtDistinctEventVisitProviderAndKindKeepsEachContext() throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let text = "Bring your medication list to the next visit."
        let bytes = Data(text.utf8)
        let event = Date(timeIntervalSince1970: 1_760_000_000)
        let firstVisit = EncounterRecord(title: "Fictional first visit", date: event, provider: "Fictional primary care")
        let nextVisit = EncounterRecord(title: "Fictional later visit", date: event.addingTimeInterval(86_400), provider: "Fictional primary care")
        XCTAssertTrue(store.mutate { $0.encounters += [firstVisit, nextVisit] })
        let first = try store.capture(title: "First instruction", kind: .textFile, text: text, data: bytes, event: event, encounterID: firstVisit.id, provider: "Fictional primary care", analyze: false)
        let laterEvent = try store.capture(title: "Instruction later", kind: .textFile, text: text, data: bytes, event: event.addingTimeInterval(86_400), encounterID: firstVisit.id, provider: "Fictional primary care", analyze: false)
        let otherVisit = try store.capture(title: "Different visit", kind: .textFile, text: text, data: bytes, event: event, encounterID: nextVisit.id, provider: "Fictional primary care", analyze: false)
        let otherProvider = try store.capture(title: "Different provider", kind: .textFile, text: text, data: bytes, event: event, encounterID: firstVisit.id, provider: "Fictional specialist", analyze: false)
        let otherKind = try store.capture(title: "Typed instruction", kind: .typed, text: text, event: event, encounterID: firstVisit.id, provider: "Fictional primary care", analyze: false)
        XCTAssertEqual(Set([first, laterEvent, otherVisit, otherProvider, otherKind]).count, 5)
        let reopened = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        XCTAssertEqual(reopened.state.sources.count, 5)
        XCTAssertEqual(reopened.source(laterEvent)?.eventAt, event.addingTimeInterval(86_400))
        XCTAssertEqual(reopened.source(otherVisit)?.encounterID, nextVisit.id)
        XCTAssertEqual(reopened.source(otherProvider)?.provider, "Fictional specialist")
        XCTAssertTrue(reopened.state.claims.isEmpty)
    }

    func testSameContextRepeatedImportIgnoresTitleAndProviderWhitespaceWithoutExtraFile() throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let store = try AppStore(repository: CaptureFailureRepository(), vault: root, systemServicesEnabled: false)
        let text = "Fictional original\nKeep every line."
        let bytes = Data(text.utf8)
        let event = Date(timeIntervalSince1970: 1_760_000_000)
        let id = try store.capture(title: "First original", kind: .textFile, text: text, data: bytes, event: event, provider: "Fictional clinic", analyze: false)
        let count = try FileManager.default.contentsOfDirectory(atPath: root.files.path).count
        let repeated = try store.capture(title: "Second button press", kind: .textFile, text: text, data: bytes, event: event, provider: "  Fictional clinic\n", analyze: false)
        XCTAssertEqual(repeated, id)
        XCTAssertEqual(store.source(id)?.title, "First original")
        XCTAssertEqual(store.state.sources.count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.files.path).count, count)
        XCTAssertTrue(store.notice?.contains("already saved") == true)
    }

    func testOversizedPasteRejectsWithoutMutatingExistingText() throws {
        let existing = "My original draft"
        XCTAssertThrowsError(try CaptureText.appendingPaste([String(repeating: "x", count: CaptureText.maximumCharacters)], to: existing))
        XCTAssertEqual(existing, "My original draft")
        XCTAssertNoThrow(try CaptureText.validate(String(repeating: "é", count: CaptureText.maximumCharacters)))
        XCTAssertThrowsError(try CaptureText.validate(String(repeating: "é", count: CaptureText.maximumCharacters + 1)))
    }

    func testSmallFieldPastePreservesUnicodeMultilineAtExactLimit() throws {
        let existing = "Visit questions 🫶🏽"
        let items = ["", "Bring all records.\n保留原文", "", "Ask about the next visit."]
        let expected = existing + "\nBring all records.\n保留原文\nAsk about the next visit."
        XCTAssertEqual(try CaptureText.appendingPaste(items, to: existing, limit: expected.count), expected)
        XCTAssertEqual(try CaptureText.appendingPaste(["Next line"], to: existing + "\n", limit: 100), existing + "\nNext line")
        XCTAssertEqual(try CaptureText.appendingPaste(["", ""], to: existing, limit: existing.count), existing)
    }

    func testSmallFieldOversizedPasteKeepsEditableDraftWithoutTruncation() throws {
        var draft = "My existing question"
        let previous = draft
        do {
            draft = try CaptureText.appendingPaste([String(repeating: "é", count: 20_000)], to: draft, limit: 20_000)
            XCTFail("A small-field limit must reject the entire oversized paste")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("20,000"))
            XCTAssertTrue(error.localizedDescription.contains("kept"))
        }
        XCTAssertEqual(draft, previous)
        draft = try CaptureText.appendingPaste(["Short follow-up"], to: draft, limit: 20_000)
        XCTAssertEqual(draft, previous + "\nShort follow-up")
    }

    func testTextAndCSVFilesKeepOriginalBytesAndMultilineText() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let cleanupRoot2 = folder; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let text = "Name,Instruction\nAlex Example,Bring records\nQuoted,“keep this”\n"
        for ext in ["txt", "csv", "md"] {
            let url = folder.appendingPathComponent("Fictional note." + ext)
            let bytes = Data(text.utf8); try bytes.write(to: url)
            let result = try await DocumentProcessor.importFile(url)
            XCTAssertEqual(result.text, text)
            XCTAssertEqual(result.data, bytes)
            XCTAssertEqual(result.kind, .textFile)
        }
        let utf16 = try XCTUnwrap(text.data(using: .utf16))
        let url = folder.appendingPathComponent("UTF16.txt"); try utf16.write(to: url)
        let result = try await DocumentProcessor.importFile(url)
        XCTAssertEqual(result.text, text); XCTAssertEqual(result.data, utf16)
    }

    func testBlankPDFFailsTextExtractionClearlyButPreservesOriginal() async throws {
        let bytes = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { $0.beginPage() }
        let original = ImportedEvidence(data: bytes, text: "", kind: .pdf, pages: [], ext: "pdf", title: "Blank PDF")
        let result = try await DocumentProcessor.process(original, language: "en-US")
        XCTAssertEqual(result.data, bytes)
        XCTAssertTrue(result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(result.message.contains("No readable text"))
        XCTAssertEqual(result.pages.count, 1)
    }

    func testShortEmbeddedPDFTextSurvivesEmptyOCRFallback() async throws {
        let bytes = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { context in
            context.beginPage()
            ("CBC" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: [.font: UIFont.systemFont(ofSize: 0.5), .foregroundColor: UIColor.black])
        }
        XCTAssertTrue(try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string).contains("CBC"))
        let pages = try await DocumentProcessor.pdf(bytes, language: "en-US")
        XCTAssertEqual(pages.count, 1)
        XCTAssertTrue(pages[0].text.contains("CBC"))
    }

    func testMalformedPhotoAndPDFRemainRecoverableOriginalEvidence() async throws {
        let bytes = Data("This is not an image or PDF".utf8)
        for (ext, kind) in [("png", SourceKind.photo), ("pdf", SourceKind.pdf)] {
            let result = try await DocumentProcessor.process(ImportedEvidence(data: bytes, text: "", kind: kind, pages: [], ext: ext, title: "Unreadable original"))
            XCTAssertEqual(result.data, bytes); XCTAssertTrue(result.text.isEmpty)
            XCTAssertFalse(result.message.isEmpty)
        }
    }

    func testEncryptedPDFRetainsOriginalAndExplainsUnlockRecovery() async throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let bytes = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { context in
            context.beginPage()
            ("Fictional visit notes remain private." as NSString).draw(at: CGPoint(x: 15, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        }
        let document = try XCTUnwrap(PDFDocument(data: bytes))
        let encryptedURL = root.root.appendingPathComponent("Locked fictional notes.pdf")
        XCTAssertTrue(document.write(to: encryptedURL, withOptions: [.ownerPasswordOption: "fictional-owner-passphrase", .userPasswordOption: "fictional-reader-passphrase"]))
        let encryptedBytes = try Data(contentsOf: encryptedURL)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(data: encryptedBytes)).isLocked)
        let result = try await DocumentProcessor.importFile(encryptedURL, language: "en-US")
        XCTAssertEqual(result.data, encryptedBytes)
        XCTAssertTrue(result.text.isEmpty)
        XCTAssertTrue(result.pages.isEmpty)
        XCTAssertTrue(result.message.localizedCaseInsensitiveContains("unlock"))
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let id = try store.capture(title: result.title, kind: result.kind, text: result.text, data: result.data, extension: result.ext, analyze: false)
        let saved = try XCTUnwrap(store.source(id))
        XCTAssertEqual(saved.state, .saved)
        XCTAssertEqual(try Data(contentsOf: root.url(try XCTUnwrap(saved.originalFile))), encryptedBytes)
        XCTAssertTrue(store.state.claims.isEmpty)
    }

    func testCancelledOCRCannotReturnExtractedText() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 200)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 200))
            ("Fictional allergy: latex" as NSString).draw(at: CGPoint(x: 20, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 32)])
        }
        let bytes = try XCTUnwrap(image.pngData())
        let task = Task { try await DocumentProcessor.ocr(bytes, language: "en-US") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled extraction must not publish text") }
        catch is CancellationError { }
    }

    func testCancelledPDFProcessingCannotBecomeEmptySuccessfulImport() async throws {
        let bytes = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { context in
            for _ in 0..<4 {
                context.beginPage()
                ("Fictional evidence from the original care document." as NSString).draw(at: CGPoint(x: 15, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
            }
        }
        let original = ImportedEvidence(data: bytes, text: "", kind: .pdf, pages: [], ext: "pdf", title: "Cancelled fictional PDF")
        let task = Task { try await DocumentProcessor.process(original, language: "en-US") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must reach the importer rather than returning an empty successful result") }
        catch is CancellationError { }
    }

    func testCancelledOriginalExtractionKeepsFileAndAllowsSuccessfulRetry() async throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let text = "Fictional visit recap 🫶🏽\nBring my records.\nQuestions stay with the source."
        let bytes = Data(text.utf8)
        let id = try store.capture(title: "Preserved original", kind: .textFile, text: "", data: bytes, analyze: false)
        store.extractOriginal(id)
        XCTAssertTrue(store.analysisInProgress(id))
        store.cancelAnalysis(id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(store.analysisInProgress(id))
        XCTAssertEqual(store.source(id)?.state, .cancelled)
        XCTAssertEqual(store.source(id)?.workingText, "")
        XCTAssertEqual(try Data(contentsOf: root.url(try XCTUnwrap(store.source(id)?.originalFile))), bytes)
        store.extractOriginal(id)
        try await waitForExtraction(store, id: id)
        XCTAssertEqual(store.source(id)?.state, .pending)
        XCTAssertEqual(store.source(id)?.originalText, text)
        XCTAssertEqual(store.source(id)?.workingText, text)
        XCTAssertTrue(store.state.claims.isEmpty)
    }

    func testInterruptedFileExtractionRelaunchRetainsOriginalAndReportsEmptyRetry() async throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let store = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        let bytes = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { $0.beginPage() }
        let id = try store.capture(title: "Interrupted blank original", kind: .pdf, text: "", data: bytes, extension: "pdf", analyze: false)
        XCTAssertTrue(store.mutate { state in state.sources[0].state = .processing })
        let reopened = try AppStore(repository: SwiftDataRepository(root: root.root), vault: root, systemServicesEnabled: false)
        XCTAssertEqual(reopened.source(id)?.state, .pending)
        XCTAssertTrue(reopened.source(id)?.processingMessage.contains("interrupted") == true)
        XCTAssertFalse(reopened.analysisInProgress(id))
        reopened.extractOriginal(id)
        try await waitForExtraction(reopened, id: id)
        XCTAssertEqual(reopened.source(id)?.state, .failed)
        XCTAssertTrue(reopened.source(id)?.processingMessage.contains("No readable text") == true)
        XCTAssertEqual(try Data(contentsOf: root.url(try XCTUnwrap(reopened.source(id)?.originalFile))), bytes)
        XCTAssertTrue(reopened.state.claims.isEmpty)
    }

    func testExtractionSaveFailureRetainsOriginalAndTerminatesLiveProgress() async throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let repository = CaptureFailureRepository()
        let store = try AppStore(repository: repository, vault: root, systemServicesEnabled: false)
        let text = "Fictional source\nPreserve these words for a retry."
        let bytes = Data(text.utf8)
        let id = try store.capture(title: "Recoverable extraction", kind: .textFile, text: "", data: bytes, analyze: false)
        store.extractOriginal(id)
        repository.fail = true
        try await waitForExtraction(store, id: id)
        XCTAssertEqual(store.source(id)?.state, .processing)
        XCTAssertEqual(store.source(id)?.workingText, "")
        XCTAssertFalse(store.analysisInProgress(id))
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: root.url(try XCTUnwrap(store.source(id)?.originalFile))), bytes)
        repository.fail = false
        store.extractOriginal(id)
        try await waitForExtraction(store, id: id)
        XCTAssertEqual(store.source(id)?.workingText, text)
        XCTAssertEqual(store.source(id)?.state, .pending)
    }

    func testDeletingSourceCancelsExtractionWithoutResurrectingFileOrText() async throws {
        let root = try makeVault(); let cleanupRoot = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot) }
        let store = try AppStore(repository: CaptureFailureRepository(), vault: root, systemServicesEnabled: false)
        let id = try store.capture(title: "Fictional file to remove", kind: .textFile, text: "", data: Data("Fictional raw source".utf8), analyze: false)
        let filename = try XCTUnwrap(store.source(id)?.originalFile)
        store.extractOriginal(id)
        XCTAssertTrue(store.deleteSource(id))
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(store.source(id))
        XCTAssertFalse(store.analysisInProgress(id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: try root.url(filename).path))
        XCTAssertTrue(store.state.claims.isEmpty)
    }

    func testClearingWorkingTextPreservesOriginalAndRetiresClaims() throws {
        let root = try makeVault(); let cleanupRoot3 = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot3) }
        let store = try AppStore(repository: CaptureFailureRepository(), vault: root, systemServicesEnabled: false)
        let original = "Allergy: latex"
        let id = try store.capture(title: "Original care note", kind: .typed, text: original, analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(id)))))
        XCTAssertTrue(store.editSource(id, title: "Original care note", text: "", event: nil, encounter: nil, provider: ""))
        XCTAssertEqual(store.source(id)?.originalText, original)
        XCTAssertEqual(store.source(id)?.workingText, "")
        XCTAssertEqual(store.source(id)?.previousText, [original])
        XCTAssertTrue(store.state.claims.allSatisfy { !$0.canonical })
    }

    func testFileCaptureStorageFailureRollsBackStateAndVault() throws {
        let root = try makeVault(); let cleanupRoot4 = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot4) }
        let repository = CaptureFailureRepository()
        let store = try AppStore(repository: repository, vault: root, systemServicesEnabled: false)
        repository.fail = true
        XCTAssertThrowsError(try store.capture(title: "Unsaved file", kind: .textFile, text: "Fictional original", data: Data("Fictional original".utf8), analyze: false))
        XCTAssertTrue(store.state.sources.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.files.path)
        XCTAssertTrue(files.isEmpty)
    }

    func testStagedFHIRImportRunsLocalParserAndKeepsReviewGate() async throws {
        let root = try makeVault(); let cleanupRoot5 = root.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot5) }
        let store = try AppStore(repository: CaptureFailureRepository(), vault: root, systemServicesEnabled: false)
        let url = try XCTUnwrap(try ExportService.practiceFiles().first { $0.pathExtension == "json" })
        let processed = try await DocumentProcessor.importFile(url)
        let id = try store.capture(title: processed.title, kind: processed.kind, text: processed.text, data: processed.data, extension: processed.ext, analyze: false)
        store.analyze(id)
        for _ in 0..<100 where store.source(id)?.state == .processing { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(store.source(id)?.state, .needsReview)
        XCTAssertFalse(store.state.claims.isEmpty)
        XCTAssertTrue(store.state.claims.allSatisfy { $0.review == .pending })
        XCTAssertTrue(store.state.entities.isEmpty)
        XCTAssertEqual(try Data(contentsOf: root.url(try XCTUnwrap(store.source(id)?.originalFile))), processed.data)
    }

    private func makeVault() throws -> EvidenceVault {
        try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent("CapturePipeline-" + UUID().uuidString))
    }

    private func waitForExtraction(_ store: AppStore, id: UUID) async throws {
        for _ in 0..<300 where store.analysisInProgress(id) { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(store.analysisInProgress(id), "The extraction must terminate so its recovery controls are available")
    }
}

@MainActor private final class CaptureFailureRepository: CareRepository {
    var value = CareState()
    var fail = false
    func load() throws -> CareState { value }
    func save(_ state: CareState) throws { if fail { throw CareError.invalid("Injected save failure") }; value = state }
}
