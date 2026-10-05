import XCTest
import SwiftData
import PDFKit
import UIKit
import CareCore
@testable import CareContinuity

@MainActor final class CareInOneIntegrationTests: XCTestCase {
    func testHandoffSnapshotAndReplyDraftSurviveSQLiteAndEncryptedRestore() throws {
        let vault = try vault(); let cleanupRoot1 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, clearBackendOnErase: false, systemServicesEnabled: false)
        let sourceID = try store.capture(title: "Synthetic source", kind: .typed, text: "Allergy: latex", analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(sourceID)))))
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(store.state))
        let id = try XCTUnwrap(store.createHandoff(title: "Synthetic handoff", recipient: "Care team", options: options))
        XCTAssertTrue(store.mutate { try HandoffEngine.saveReplyDraft("Private reply draft", eventAt: nil, handoffID: id, in: &$0) })
        XCTAssertTrue(store.mutate { try HandoffEngine.recordShared(id, in: &$0) })
        let saved = try XCTUnwrap(store.state.handoffs?.handoffs.first)
        let reloaded = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(reloaded.state.handoffs, store.state.handoffs)
        let text = try XCTUnwrap(saved.snapshotText)
        let pdf = try ExportService.textPDF(text, name: "CareInOne-handoff-integration.pdf")
        XCTAssertTrue(try XCTUnwrap(PDFDocument(url: pdf)?.string).contains("latex"))
        let encrypted = try ArchiveCodec.encrypt(store.archive(includeAudio: true), passphrase: "integration handoff passphrase")
        store.eraseAll(); XCTAssertNil(store.state.handoffs)
        try store.restore(ArchiveCodec.decrypt(encrypted, passphrase: "integration handoff passphrase"))
        XCTAssertEqual(store.state.handoffs?.handoffs.first, saved)
        XCTAssertFalse(store.state.profile.cloudConsent)
    }
    func testFailedHandoffSaveAndReplyKeepDraftAndPriorCommittedState() throws {
        let vault = try vault(); let cleanupRoot2 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let repository = FailingRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        XCTAssertTrue(store.addQuestion("Which records should I bring?"))
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(store.state))
        let beforeCreate = store.state; repository.fail = true
        XCTAssertNil(store.createHandoff(title: "Unsaved", recipient: "", options: options)); XCTAssertEqual(store.state, beforeCreate)
        repository.fail = false
        let id = try XCTUnwrap(store.createHandoff(title: "Saved", recipient: "", options: options))
        XCTAssertTrue(store.mutate { try HandoffEngine.saveReplyDraft("Allergy: latex", eventAt: nil, handoffID: id, in: &$0) })
        let beforeReply = store.state; repository.fail = true
        XCTAssertNil(store.captureHandoffReply("Allergy: latex", eventAt: nil, handoffID: id, synthetic: false))
        XCTAssertEqual(store.state, beforeReply); XCTAssertTrue(store.state.sources.isEmpty)
    }
    func testHandoffReplyLocalPipelineChangesCareOnlyAfterReview() async throws {
        let vault = try vault(); let cleanupRoot3 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot3) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let sourceID = try store.capture(title: "Original report", kind: .typed, text: "Allergy: latex", analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(sourceID)))))
        let entityID = try XCTUnwrap(store.state.claims.first?.entityID)
        var options = PacketOptions(); options.selectedIDs = ["care:" + entityID.uuidString]
        let id = try XCTUnwrap(store.createHandoff(title: "Follow up", recipient: "", options: options))
        let before = try XCTUnwrap(store.state.handoffs?.handoffs.first)
        let replyID = try XCTUnwrap(store.captureHandoffReply("Allergy: latex", eventAt: nil, handoffID: id, synthetic: false))
        for _ in 0..<100 where store.source(replyID)?.state == .pending || store.source(replyID)?.state == .processing { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(store.source(replyID)?.state, .needsReview)
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 1)
        XCTAssertTrue(try HandoffEngine.changes(for: before, in: store.state).isEmpty)
        XCTAssertTrue(store.accept(store.state.claims.filter { $0.sourceID == replyID && $0.review == .pending }))
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 2)
        XCTAssertFalse(try HandoffEngine.changes(for: before, in: store.state).isEmpty)
        XCTAssertEqual(store.state.handoffs?.handoffs.first?.snapshotText, before.snapshotText)
    }
    func testSourceDeletionInvalidatesHandoffAndExportOnlyAfterSuccessfulSave() throws {
        let vault = try vault(); let cleanupRoot4 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot4) }
        let repository = FailingRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let sourceID = try store.capture(title: "PRIVATE_SENTENCE", kind: .typed, text: "Allergy: latex", analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(sourceID)))))
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(store.state))
        XCTAssertNotNil(store.createHandoff(title: "Copy", recipient: "", options: options))
        let text = try XCTUnwrap(store.state.handoffs?.handoffs.first?.snapshotText)
        let pdf = try ExportService.textPDF(text, name: "CareInOne-handoff-deletion.pdf")
        repository.fail = true; XCTAssertFalse(store.deleteSource(sourceID))
        XCTAssertEqual(store.state.handoffs?.handoffs.first?.snapshotText, text)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdf.path))
        repository.fail = false; XCTAssertTrue(store.deleteSource(sourceID))
        XCTAssertNil(store.state.handoffs?.handoffs.first?.snapshotText)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state), as: UTF8.self).contains("PRIVATE_SENTENCE"))
        XCTAssertNoThrow(try store.archive(includeAudio: true))
    }
    func testDemoRemovalRedactsHandoffWhilePatientReplyRemains() throws {
        let vault = try vault(); let cleanupRoot5 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot5) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false); store.loadDemo()
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(VisitPacketBuilder.items(store.state))
        let id = try XCTUnwrap(store.createHandoff(title: "Demo comparison", recipient: "", options: options))
        var replyID: UUID?
        XCTAssertTrue(store.mutate { replyID = try HandoffEngine.captureReply("My independent reply", eventAt: nil, handoffID: id, in: &$0) })
        store.removeDemo()
        XCTAssertNil(store.state.handoffs?.handoffs.first?.snapshotText)
        XCTAssertNotNil(store.source(try XCTUnwrap(replyID)))
        XCTAssertNoThrow(try store.archive(includeAudio: true))
    }
    func testVisitWorkspaceCheckpointAndDraftSurviveSQLiteRelaunch() throws {
        let vault = try vault(); let cleanupRoot6 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot6) }
        let repository = try SwiftDataRepository(root: vault.root)
        let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let sourceID = try store.capture(title: "Synthetic report", kind: .typed, text: "Allergy: latex", analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(sourceID)))))
        let workspaceID = try XCTUnwrap(store.createWorkspace(title: "Synthetic visit"))
        let checkpointID = try XCTUnwrap(store.saveCheckpoint(title: "Before visit", workspaceID: workspaceID))
        var workspace = try XCTUnwrap(store.state.continuity?.workspaces.first)
        workspace.debrief.heard = "A saved draft"; XCTAssertTrue(store.saveWorkspace(workspace))
        let loaded = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertEqual(loaded.state.continuity, store.state.continuity)
        XCTAssertEqual(loaded.state.continuity?.workspaces.first?.checkpointID, checkpointID)
        XCTAssertEqual(loaded.state.continuity?.checkpoints.first?.facts.count, 1)
    }
    func testLegacyPreferencesPayloadWithoutContinuityOpens() throws {
        let vault = try vault(); let cleanupRoot7 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot7) }
        let repository = try SwiftDataRepository(root: vault.root)
        var state = CareState(); try SyntheticDemo.load(into: &state); try repository.save(state)
        let record = try XCTUnwrap(repository.context.fetch(FetchDescriptor<PatientProfile>()).first)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: record.payload) as? [String: Any])
        json.removeValue(forKey: "continuity"); json.removeValue(forKey: "handoffs"); record.payload = try JSONSerialization.data(withJSONObject: json); try repository.context.save()
        let opened = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        XCTAssertNil(opened.state.continuity); XCTAssertEqual(opened.state.sources.count, state.sources.count)
        XCTAssertNil(opened.state.handoffs)
        XCTAssertEqual(Set(opened.state.claims.map(\.id)), Set(state.claims.map(\.id)))
    }
    func testDebriefFailurePreservesSavedDraftAndDoesNotCreateEvidence() throws {
        let vault = try vault(); let cleanupRoot8 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot8) }
        let repository = FailingRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let workspaceID = try XCTUnwrap(store.createWorkspace(title: "My visit"))
        var workspace = try XCTUnwrap(store.state.continuity?.workspaces.first)
        workspace.debrief.heard = "Allergy: latex"; workspace.debrief.questions = "What should I bring?"
        XCTAssertTrue(store.saveWorkspace(workspace)); let before = store.state
        repository.fail = true
        XCTAssertFalse(store.saveDebrief(workspace.debrief, workspaceID: workspaceID).saved)
        XCTAssertEqual(store.state, before)
        XCTAssertNil(store.saveCheckpoint(title: "Unsaved checkpoint", workspaceID: workspaceID))
        XCTAssertEqual(store.state, before)
    }
    func testDebriefRunsLocalExtractionButRequiresReviewBeforeCheckpointChanges() async throws {
        let vault = try vault(); let cleanupRoot9 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot9) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let workspaceID = try XCTUnwrap(store.createWorkspace(title: "Visit"))
        let checkpointID = try XCTUnwrap(store.saveCheckpoint(title: "Starting point", workspaceID: workspaceID))
        var draft = VisitDebriefDraft(); draft.heard = "Allergy: latex"; draft.questions = "Should I change my medicine?"
        let saved = store.saveDebrief(draft, workspaceID: workspaceID); XCTAssertTrue(saved.saved)
        let id = try XCTUnwrap(saved.sourceID)
        for _ in 0..<100 where store.source(id)?.state == .pending || store.source(id)?.state == .processing { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(store.source(id)?.state, .needsReview)
        let checkpoint = try XCTUnwrap(store.state.continuity?.checkpoints.first { $0.id == checkpointID })
        XCTAssertTrue(ContinuityComparator.compare(checkpoint, to: store.state).differences.isEmpty)
        let proposals = store.state.claims.filter { $0.sourceID == id && $0.review == .pending }
        XCTAssertEqual(proposals.map(\.label), ["latex"]); XCTAssertTrue(proposals.allSatisfy { $0.provenance == .patientReported })
        XCTAssertFalse((store.source(id)?.originalText ?? "").contains(draft.questions))
        XCTAssertTrue(store.accept(proposals))
        XCTAssertTrue(ContinuityComparator.compare(checkpoint, to: store.state).differences.contains { $0.kind == .reportAdded })
        XCTAssertEqual(store.state.questions.count, 1)
    }
    func testCheckpointDeletionRollsBackAndSuccessfulDeletionPurgesCachedEvidence() throws {
        let vault = try vault(); let cleanupRoot10 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot10) }
        let repository = FailingRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let id = try store.capture(title: "Private source title", kind: .textFile, text: "Allergy: latex", data: Data("original file bytes".utf8), analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(id)))))
        XCTAssertNotNil(store.saveCheckpoint(title: "Reference"))
        let file = try XCTUnwrap(store.source(id)?.originalFile); let before = store.state
        repository.fail = true; XCTAssertFalse(store.deleteSource(id)); XCTAssertEqual(store.state, before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try vault.url(file).path))
        repository.fail = false; XCTAssertTrue(store.deleteSource(id))
        XCTAssertEqual(store.state.continuity?.checkpoints.first?.facts.count, 0)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(store.state), as: UTF8.self).contains("Private source title"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: try vault.url(file).path))
        XCTAssertNoThrow(try store.archive(includeAudio: true))
    }
    func testRestoreAndEraseIncludeContinuityWhileConsentRemainsLocal() throws {
        let vault = try vault(); let cleanupRoot11 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot11) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, clearBackendOnErase: false, systemServicesEnabled: false)
        store.loadDemo()
        let id = try XCTUnwrap(store.createWorkspace(title: "Visit"))
        XCTAssertNotNil(store.saveCheckpoint(title: "Reference", workspaceID: id))
        let backup = try store.archive(includeAudio: true)
        store.removeDemo(); XCTAssertTrue(store.state.continuity?.checkpoints.first?.facts.isEmpty == true)
        store.eraseAll(); XCTAssertNil(store.state.continuity)
        try store.restore(backup)
        XCTAssertEqual(store.state.continuity, backup.state.continuity)
        XCTAssertFalse(store.state.profile.cloudConsent)
    }
    func testExportCleanupRemovesPreRenameCopiesAndPreservesOtherFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot12 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot12) }
        for folder in ["CareInOneExports", "CareContinuityExports", "Unrelated"] {
            let directory = root.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("synthetic exported copy".utf8).write(to: directory.appendingPathComponent("copy.txt"))
        }
        ExportService.clean(root: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("CareInOneExports").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("CareContinuityExports").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Unrelated/copy.txt").path))
    }

    func testSelectedPacketPDFContainsOnlyThePreviewSnapshot() throws {
        let text = "CAREINONE · SELECTED VISIT PACKET\nA single selected question\nEvent date unknown"
        let url = try ExportService.textPDF(text, name: "selected-packet-test.pdf")
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertTrue((pdf.string ?? "").contains("A single selected question"))
        XCTAssertFalse((pdf.string ?? "").contains("metoprolol"))
        XCTAssertGreaterThan(pdf.pageCount, 0)
    }

    func testPracticeFilesUseRealImportersAndKeepReviewGate() async throws {
        let files = try ExportService.practiceFiles()
        XCTAssertEqual(files.count, 4)
        let localVault = try vault(); let cleanupRoot13 = localVault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot13) }
        let store = try AppStore(repository: SwiftDataRepository(root: localVault.root), vault: localVault, systemServicesEnabled: false)
        for url in files {
            let original = try DocumentProcessor.readOriginal(url)
            let processed = try await DocumentProcessor.process(original, language: "en-US")
            let id: UUID
            if processed.kind == .fhir {
                id = try store.importFHIR(title: processed.title, data: processed.data, event: nil, encounter: nil)
            } else {
                XCTAssertTrue(processed.text.localizedCaseInsensitiveContains("latex"))
                id = try store.capture(title: processed.title, kind: processed.kind, text: processed.text, data: processed.data, extension: processed.ext, pages: processed.pages, analyze: false)
                let proposals = try LocalExtractor.proposals(try XCTUnwrap(store.source(id)))
                XCTAssertFalse(proposals.isEmpty)
                XCTAssertTrue(store.state.entities.isEmpty)
            }
            XCTAssertNotNil(store.source(id)?.originalFile)
        }
        XCTAssertTrue(store.state.entities.isEmpty)
        let pending = store.state.claims.filter { $0.review == .pending }
        XCTAssertFalse(pending.isEmpty)
        XCTAssertTrue(store.accept(pending))
        XCTAssertFalse(store.state.entities.isEmpty)
    }
    func testRemovingDemoDeletesSyntheticFilesAndKeepsPatientEvidence() throws {
        let localVault = try vault(); let cleanupRoot14 = localVault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot14) }
        let store = try AppStore(repository: SwiftDataRepository(root: localVault.root), vault: localVault, systemServicesEnabled: false)
        let patient = try store.capture(title: "My source", kind: .textFile, text: "My own note", data: Data("patient".utf8), analyze: false)
        let sample = try store.capture(title: "Practice", kind: .textFile, text: "Fictional note", data: Data("synthetic".utf8), analyze: false)
        let file = try XCTUnwrap(store.source(sample)?.originalFile)
        XCTAssertTrue(store.mutate { state in state.sources[state.sources.firstIndex { $0.id == sample }!].synthetic = true })
        store.loadDemo(); store.removeDemo()
        XCTAssertNil(store.source(sample))
        XCTAssertNotNil(store.source(patient))
        XCTAssertFalse(FileManager.default.fileExists(atPath: try localVault.url(file).path))
        XCTAssertFalse(store.state.profile.demoLoaded)
    }
    func testQuestionSaveFailureCanBeRetriedWithoutDataLoss() throws {
        let localVault = try vault(); let cleanupRoot15 = localVault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot15) }
        let repository = FailingRepository()
        let store = try AppStore(repository: repository, vault: localVault, systemServicesEnabled: false)
        repository.fail = true
        XCTAssertFalse(store.addQuestion("What changed?"))
        XCTAssertTrue(store.state.questions.isEmpty)
        repository.fail = false
        XCTAssertTrue(store.addQuestion("What changed?"))
        XCTAssertTrue(store.addQuestion("What changed?"))
        XCTAssertEqual(store.state.questions.count, 1)
    }
    func testBackupRestoresOriginalsAndDoesNotTransferConsent() throws {
        let vault = try vault(); let cleanupRoot16 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot16) }
        let store = try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false)
        let original = Data("Synthetic original PDF bytes".utf8)
        let id = try store.capture(title: "Backup evidence", kind: .pdf, text: "Allergy: penicillin", data: original, extension: "pdf", analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(try XCTUnwrap(store.source(id)))))
        var profile = store.state.profile; profile.cloudConsent = true; profile.notifications = true
        XCTAssertTrue(store.mutate { $0.profile = profile })
        let backup = try store.archive(includeAudio: true)
        XCTAssertTrue(store.deleteSource(id)); XCTAssertTrue(store.state.sources.isEmpty)
        try store.restore(backup)
        let restored = try XCTUnwrap(store.source(id)); let filename = try XCTUnwrap(restored.originalFile)
        XCTAssertEqual(try Data(contentsOf: vault.url(filename)), original)
        XCTAssertFalse(store.state.profile.cloudConsent); XCTAssertFalse(store.state.profile.notifications)
        XCTAssertEqual(store.state.claims.filter(\.canonical).count, 1)
    }
    func testFailedRestoreAndDeletionPreserveExistingRecordsAndFiles() throws {
        let vault = try vault(); let cleanupRoot17 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot17) }
        let repository = FailingRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        let id = try store.capture(title: "Kept evidence", kind: .textFile, text: "Saved evidence", data: Data("Saved evidence".utf8), analyze: false)
        let backup = try store.archive(includeAudio: true); let prior = store.state
        let files = try FileManager.default.contentsOfDirectory(atPath: vault.files.path)
        repository.fail = true
        XCTAssertThrowsError(try store.restore(backup))
        XCTAssertEqual(store.state, prior)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: vault.files.path), files)
        XCTAssertFalse(store.deleteSource(id)); XCTAssertNotNil(store.source(id))
    }
    func testGatewayCredentialsRejectProviderKeysAndUnsafeAddresses() throws {
        let token = String(repeating: "a", count: 40)
        for address in ["http://gateway.example", "https://api.openai.com/v1", "https://api.moonshot.ai/v1", "https://user:password@gateway.example", "https://gateway.example?token=secret"] {
            XCTAssertThrowsError(try GatewayClient.validate(endpoint: address, token: token))
        }
        XCTAssertThrowsError(try GatewayClient.validate(endpoint: "https://gateway.example", token: "short"))
        XCTAssertEqual(try GatewayClient.validate(endpoint: "https://gateway.example/care", token: token).path, "/care")
    }
    func vault() throws -> EvidenceVault { try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) }
    func testSwiftDataRoundTripAndDerivedRecords() throws {
        let vault = try vault(); let cleanupRoot18 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot18) }
        let repository = try SwiftDataRepository(root: vault.root)
        var state = CareState(); try SyntheticDemo.load(into: &state)
        try repository.save(state); let loaded = try repository.load()
        XCTAssertEqual(Set(loaded.sources.map(\.id)),Set(state.sources.map(\.id)))
        XCTAssertEqual(loaded.claims.count,state.claims.count); XCTAssertEqual(loaded.conflicts.count,state.conflicts.count)
        XCTAssertEqual(try repository.context.fetchCount(FetchDescriptor<CareClaim>()),state.claims.count)
        XCTAssertEqual(try repository.context.fetchCount(FetchDescriptor<ClaimRelation>()),state.relations.count)
        XCTAssertEqual(try repository.context.fetchCount(FetchDescriptor<OpenLoop>()),state.loops.count)
        let second = try SwiftDataRepository(root: vault.root); XCTAssertEqual(try second.load().sources.count,state.sources.count)
    }
    func testOfflineCaptureReviewDeletionPersistence() async throws {
        let vault = try vault(); let cleanupRoot19 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot19) }
        let repository = try SwiftDataRepository(root: vault.root); let store = try AppStore(repository: repository,vault:vault, systemServicesEnabled: false)
        let id = try store.capture(title:"Synthetic note",kind:.typed,text:"Allergy: penicillin")
        for _ in 0..<100 where store.source(id)?.state == .processing || store.source(id)?.state == .pending { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertEqual(store.source(id)?.state,.needsReview); XCTAssertTrue(store.state.entities.isEmpty)
        XCTAssertTrue(store.accept(store.state.claims.filter { $0.sourceID == id && $0.review == .pending }))
        XCTAssertEqual(store.state.entities.count,1); XCTAssertEqual(try repository.load().entities.count,1)
        store.deleteSource(id); XCTAssertTrue(store.state.entities.isEmpty); XCTAssertTrue(try repository.load().claims.isEmpty)
    }
    func testDuplicateOriginalFileIsNotCopiedTwice() throws {
        let vault = try vault(); let cleanupRoot20 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot20) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault, systemServicesEnabled: false)
        let data = Data("synthetic original".utf8)
        let a = try store.capture(title:"First",kind:.textFile,text:"synthetic original",data:data,analyze:false)
        let b = try store.capture(title:"Again",kind:.textFile,text:"synthetic original",data:data,analyze:false)
        XCTAssertEqual(a,b); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:vault.files.path).count,1)
        store.deleteSource(a); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:vault.files.path).count,0)
    }
    func testAudioDeletionPreservesTranscriptAndClaims() throws {
        let vault = try vault(); let cleanupRoot21 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot21) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault, systemServicesEnabled: false)
        let id = try store.capture(title:"Voice",kind:.voice,text:"A remembered update",analyze:false)
        let filename = try vault.write(Data([1,2,3]),extension:"m4a")
        _ = store.mutate { state in state.sources[0].audioFile=filename }
        store.deleteAudio(id); XCTAssertEqual(store.source(id)?.workingText,"A remembered update"); XCTAssertNil(store.source(id)?.audioFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath:try vault.url(filename).path))
    }
    func testSourceEditRetiresClaimsAndKeepsOriginal() throws {
        let vault = try vault(); let cleanupRoot22 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot22) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault, systemServicesEnabled: false)
        let id = try store.capture(title:"Visit",kind:.typed,text:"metoprolol 25 mg",analyze:false)
        let source = try XCTUnwrap(store.source(id)); XCTAssertTrue(store.accept(try LocalExtractor.proposals(source)))
        store.editSource(id,title:"Visit corrected",text:"metoprolol 50 mg",event:nil,encounter:nil,provider:"")
        XCTAssertEqual(store.source(id)?.originalText,"metoprolol 25 mg"); XCTAssertEqual(store.source(id)?.previousText,["metoprolol 25 mg"])
        XCTAssertTrue(store.state.entities.isEmpty); XCTAssertTrue(store.state.claims.allSatisfy { !$0.canonical })
    }
    func testFailedTransactionDoesNotPublishUncommittedState() throws {
        let vault = try vault(); let cleanupRoot23 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot23) }
        let repo = FailingRepository(); let store = try AppStore(repository:repo,vault:vault, systemServicesEnabled: false); repo.fail = true
        let before = store.state; XCTAssertFalse(store.mutate { $0.profile.displayName="Unsaved" }); XCTAssertEqual(store.state,before)
    }
    func testInterruptedAnalysisRecoversWithoutLoss() throws {
        let vault = try vault(); let cleanupRoot24 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot24) }
        let repository = try SwiftDataRepository(root:vault.root); var state = CareState()
        var source=Source(title:"Interrupted",kind:.typed,text:"Saved before analysis",contentHash:"hash"); source.state = .processing; state.sources=[source]; try repository.save(state)
        let store=try AppStore(repository:repository,vault:vault, systemServicesEnabled: false); XCTAssertEqual(store.source(source.id)?.state,.pending); XCTAssertEqual(store.source(source.id)?.originalText,"Saved before analysis")
    }
    func testVaultTraversalRejected() throws {
        let vault = try vault(); let cleanupRoot25 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot25) }
        XCTAssertThrowsError(try vault.url("../outside")); XCTAssertThrowsError(try vault.url("a/b"))
    }
    func testKeychainUpdateAndDeletion() throws {
        let key="synthetic-test-" + UUID().uuidString; defer { try? KeychainStore.set("",key:key) }
        try KeychainStore.set("synthetic-first",key:key); XCTAssertEqual(KeychainStore.get(key),"synthetic-first")
        try KeychainStore.set("synthetic-replaced",key:key); XCTAssertEqual(KeychainStore.get(key),"synthetic-replaced")
        try KeychainStore.set("",key:key); XCTAssertEqual(KeychainStore.get(key),"")
    }
    func testCareBriefPDFIsReadableAndPaginated() throws {
        var state=CareState(); try SyntheticDemo.load(into:&state)
        for i in 0..<70 { state.questions.append(Question(text:"Synthetic question \(i): clarify the source before changing saved information.")) }
        let url=try ExportService.briefPDF(state); defer { ExportService.clean() }
        let document=try XCTUnwrap(PDFDocument(url:url)); XCTAssertGreaterThan(document.pageCount,1)
        XCTAssertTrue(document.string?.contains("SYNTHETIC") == true); XCTAssertTrue(document.string?.contains("Synthetic question 69") == true)
    }
    func testLocalImageOCRAndScannedPDFFallback() async throws {
        let renderer=UIGraphicsImageRenderer(size:CGSize(width:1200,height:400))
        let image=renderer.image { context in UIColor.white.setFill(); context.fill(CGRect(x:0,y:0,width:1200,height:400)); ("SYNTHETIC CARE NOTE\nCBC ordered" as NSString).draw(at:CGPoint(x:60,y:80),withAttributes:[.font:UIFont.systemFont(ofSize:48),.foregroundColor:UIColor.black]) }
        let data=try XCTUnwrap(image.pngData()); let text=try await DocumentProcessor.ocr(data); XCTAssertTrue(text.localizedCaseInsensitiveContains("CBC"), "Synthetic image OCR returned: \(text)")
        let pdf=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:600,height:200)).pdfData { ctx in ctx.beginPage(); image.draw(in:CGRect(x:0,y:0,width:600,height:200)) }
        let pages=try await DocumentProcessor.pdf(pdf); XCTAssertEqual(pages.count,1); XCTAssertTrue(pages[0].text.localizedCaseInsensitiveContains("CBC"), "Synthetic scanned PDF OCR returned: \(pages[0].text)")
    }
    func testCancelledAnalysisCannotReplaceNewerRun() async throws {
        let vault = try vault(); let cleanupRoot26 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot26) }
        let provider = ControlledExtractor()
        let store = try AppStore(repository: FailingRepository(), vault: vault, extractionProvider: provider, systemServicesEnabled: false)
        let id = try store.capture(title:"Synthetic",kind:.typed,text:"Allergy: penicillin",analyze:false)
        store.analyze(id,force:true)
        for _ in 0..<100 { if await provider.count == 1 { break }; try await Task.sleep(for:.milliseconds(10)) }
        let first = await provider.count; XCTAssertEqual(first,1)
        store.analyze(id,force:true)
        for _ in 0..<100 { if await provider.count == 2 { break }; try await Task.sleep(for:.milliseconds(10)) }
        let count = await provider.count; XCTAssertEqual(count,2)
        await provider.finish(1)
        for _ in 0..<100 where store.source(id)?.state == .processing { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(store.source(id)?.state,.needsReview)
        let acceptedRun = store.state.claims
        await provider.finish(0)
        try await Task.sleep(for:.milliseconds(50))
        XCTAssertEqual(store.state.claims,acceptedRun); XCTAssertEqual(store.source(id)?.state,.needsReview)
        XCTAssertEqual(store.state.claims.count,1)
    }
    func testRevokedConsentDiscardsInflightAnalysis() async throws {
        let vault = try vault(); let cleanupRoot27 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot27) }
        let provider = ControlledExtractor(); let repository = FailingRepository()
        repository.value.profile.cloudConsent = true
        let store = try AppStore(repository:repository,vault:vault,extractionProvider:provider, systemServicesEnabled: false)
        let id = try store.capture(title:"Synthetic",kind:.typed,text:"Allergy: penicillin")
        for _ in 0..<100 { if await provider.count == 1 { break }; try await Task.sleep(for:.milliseconds(10)) }
        var profile = store.state.profile; profile.cloudConsent = false; XCTAssertTrue(store.saveProfile(profile))
        await provider.finish(0); try await Task.sleep(for:.milliseconds(50))
        XCTAssertTrue(store.state.claims.isEmpty); XCTAssertEqual(store.source(id)?.state,.cancelled)
        XCTAssertEqual(store.source(id)?.originalText,"Allergy: penicillin")
    }
    func testRecoveredTranscriptKeepsVerifiedTimestampEvidence() throws {
        let vault = try vault(); let cleanupRoot28 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot28) }
        let store = try AppStore(repository:FailingRepository(),vault:vault, systemServicesEnabled: false)
        let id = try store.capture(title:"Saved voice",kind:.voice,text:"",analyze:false)
        let segment = TranscriptSegment(text:"Allergy",startUTF16:0,lengthUTF16:7,seconds:12)
        XCTAssertTrue(store.saveRecoveredTranscript(id,text:"Allergy: penicillin",segments:[segment]))
        let source = try XCTUnwrap(store.source(id)); let claims = try LocalExtractor.proposals(source)
        XCTAssertEqual(source.originalText,source.workingText); XCTAssertEqual(claims.first?.transcriptSeconds,12)
        XCTAssertFalse(store.saveRecoveredTranscript(id,text:"Replacement",segments:[]))
    }
}
private actor ControlledExtractor: ExtractionProvider {
    nonisolated let version = "controlled-test-1"
    private var pending: [(Source, CheckedContinuation<[Claim], any Error>)] = []
    var count: Int { pending.count }
    func extract(source:Source) async throws -> [Claim] {
        try await withCheckedThrowingContinuation { pending.append((source,$0)) }
    }
    func finish(_ index:Int) {
        guard pending.indices.contains(index) else { return }
        pending[index].1.resume(with:Result { try LocalExtractor.proposals(pending[index].0) })
    }
}
@MainActor private final class FailingRepository: CareRepository {
    var fail = false; var value=CareState()
    func load() throws -> CareState { value }
    func save(_ state:CareState) throws { if fail { throw CareError.invalid("Injected storage failure") }; value=state }
}
