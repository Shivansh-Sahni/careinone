import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class BackupWorkflowIntegrationTests: XCTestCase {
    private let phrase = "fictional patient backup phrase"

    func testWrongPassphraseCannotPreviewOrChangeCurrentCare() async throws {
        let fixture = try makeStore(); let cleanupRoot1 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let id = try fixture.store.capture(title: "Fictional care to keep", kind: .typed, text: "Allergy: latex", analyze: false)
        let before = fixture.store.state
        let encrypted = try ArchiveCodec.encrypt(fixture.store.archive(includeAudio: false), passphrase: phrase)
        let url = fixture.vault.root.appendingPathComponent("Fictional.carebackup"); try encrypted.write(to: url)
        let flow = BackupWorkflow(); flow.load(url); try await waitForIdle(flow)
        flow.unlock(passphrase: "an incorrect backup phrase"); try await waitForIdle(flow)
        XCTAssertNil(flow.preview)
        XCTAssertTrue(flow.message?.contains("current records have not been replaced") == true)
        XCTAssertEqual(fixture.store.state, before); XCTAssertNotNil(fixture.store.source(id))
        flow.unlock(passphrase: phrase); try await waitForIdle(flow)
        XCTAssertEqual(flow.preview?.state, before)
        XCTAssertEqual(fixture.store.state, before)
    }

    func testFailedReplacementImportClearsPriorUnlockedPreview() async throws {
        let fixture = try makeStore(); let cleanupRoot2 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let encrypted = try ArchiveCodec.encrypt(fixture.store.archive(includeAudio: false), passphrase: phrase)
        let url = fixture.vault.root.appendingPathComponent("Fictional.carebackup"); try encrypted.write(to: url)
        let flow = BackupWorkflow(); flow.load(url); try await waitForIdle(flow)
        flow.unlock(passphrase: phrase); try await waitForIdle(flow); XCTAssertNotNil(flow.preview)
        flow.load(fixture.vault.root.appendingPathComponent("missing.carebackup")); try await waitForIdle(flow)
        XCTAssertNil(flow.preview); XCTAssertNil(flow.input); XCTAssertEqual(flow.filename, ""); XCTAssertNotNil(flow.message)
    }

    func testCancelledUnlockCannotPublishLatePreview() async throws {
        let fixture = try makeStore(); let cleanupRoot3 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot3) }
        let encrypted = try ArchiveCodec.encrypt(fixture.store.archive(includeAudio: false), passphrase: phrase)
        let url = fixture.vault.root.appendingPathComponent("Fictional.carebackup"); try encrypted.write(to: url)
        let flow = BackupWorkflow(); flow.load(url); try await waitForIdle(flow)
        flow.unlock(passphrase: phrase)
        await Task.yield()
        flow.cancel()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(flow.busy); XCTAssertNil(flow.preview); XCTAssertEqual(flow.message, "Stopped. Your current care records remain saved.")
    }

    func testAudioChoiceAndCareChangesInvalidateSharedBackup() async throws {
        let fixture = try makeStore(); let cleanupRoot4 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot4) }
        let flow = BackupWorkflow()
        flow.create(store: fixture.store, passphrase: phrase, includeAudio: true); try await waitForIdle(flow)
        XCTAssertNotNil(flow.output)
        flow.invalidateOutput(); XCTAssertNil(flow.output)
        flow.create(store: fixture.store, passphrase: phrase, includeAudio: false); try await waitForIdle(flow)
        XCTAssertNotNil(flow.output)
        _ = try fixture.store.capture(title: "Later fictional note", kind: .typed, text: "Bring records", analyze: false)
        flow.careChanged(); XCTAssertNil(flow.output)
        XCTAssertTrue(flow.message?.contains("Create a new backup") == true)
    }

    func testAsyncBackupExcludesAudioAndPreservesOriginalFileBytes() async throws {
        let fixture = try makeStore(); let cleanupRoot5 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot5) }
        let bytes = Data(repeating: 0x61, count: 8_000_000)
        let id = try fixture.store.capture(title: "Fictional original", kind: .textFile, text: "Original file", data: bytes, analyze: false)
        let audio = try fixture.vault.write(Data("Fictional audio bytes".utf8), extension: "m4a")
        XCTAssertTrue(fixture.store.mutate { state in state.sources[state.sources.firstIndex(where: { $0.id == id })!].audioFile = audio })
        let archive = try await fixture.store.archiveInBackground(includeAudio: false)
        let source = try XCTUnwrap(archive.state.source(id))
        XCTAssertNil(source.audioFile); XCTAssertEqual(archive.files.count, 1)
        XCTAssertEqual(archive.files[try XCTUnwrap(source.originalFile)], bytes)
        XCTAssertEqual(fixture.store.source(id)?.audioFile, audio)
        XCTAssertNoThrow(try archive.validate())
    }

    func testAsyncRestoreReplacesPatientWithoutMergingOrTransferringConsent() async throws {
        let fixture = try makeStore(); let cleanupRoot6 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot6) }
        let original = Data("Patient A fictional original".utf8)
        let patientA = try fixture.store.capture(title: "Fictional patient A", kind: .textFile, text: "Allergy: latex", data: original, analyze: false)
        XCTAssertTrue(fixture.store.accept(try LocalExtractor.proposals(XCTUnwrap(fixture.store.source(patientA)))))
        XCTAssertTrue(fixture.store.mutate { $0.profile.displayName = "Fictional patient A"; $0.profile.cloudConsent = true; $0.profile.notifications = true })
        let archive = try await fixture.store.archiveInBackground(includeAudio: true)
        XCTAssertTrue(fixture.store.deleteSource(patientA))
        let patientB = try fixture.store.capture(title: "Fictional patient B", kind: .typed, text: "Unrelated patient", analyze: false)
        XCTAssertTrue(fixture.store.mutate { $0.profile.appLock = true })
        try await fixture.store.restoreInBackground(archive)
        XCTAssertNotNil(fixture.store.source(patientA)); XCTAssertNil(fixture.store.source(patientB))
        XCTAssertEqual(fixture.store.state.profile.displayName, "Fictional patient A")
        XCTAssertFalse(fixture.store.state.profile.cloudConsent); XCTAssertFalse(fixture.store.state.profile.notifications); XCTAssertTrue(fixture.store.state.profile.appLock)
        let restored = try XCTUnwrap(fixture.store.source(patientA)?.originalFile)
        XCTAssertEqual(try Data(contentsOf: fixture.vault.url(restored)), original)
        let reopened = try AppStore(repository: SwiftDataRepository(root: fixture.vault.root), vault: fixture.vault, systemServicesEnabled: false)
        XCTAssertNotNil(reopened.source(patientA)); XCTAssertNil(reopened.source(patientB)); XCTAssertEqual(reopened.state.claims.filter(\.canonical).count, 1)
    }

    func testAsyncRestoreSaveFailureRollsBackFilesAndExistingCare() async throws {
        let vault = try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let cleanupRoot7 = vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot7) }
        let repository = BackupFailureRepository(); let store = try AppStore(repository: repository, vault: vault, systemServicesEnabled: false)
        _ = try store.capture(title: "Fictional saved evidence", kind: .textFile, text: "Original saved text", data: Data("Original bytes".utf8), analyze: false)
        let archive = try await store.archiveInBackground(includeAudio: true)
        let before = store.state; let names = try FileManager.default.contentsOfDirectory(atPath: vault.files.path)
        repository.fail = true
        do { try await store.restoreInBackground(archive); XCTFail("A failed commit must throw") } catch { }
        XCTAssertEqual(store.state, before); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: vault.files.path), names)
        XCTAssertEqual(repository.state, before)
    }

    func testAsyncRestoreRejectsPersonalArchiveInDemoAndPreservesBothStores() async throws {
        let fixture = try makeStore(); let cleanupRoot8 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot8) }
        _ = try fixture.store.capture(title: "Personal fictional fixture", kind: .typed, text: "Saved personal care", analyze: false)
        let archive = try await fixture.store.archiveInBackground(includeAudio: false)
        let demoRoot = fixture.vault.root.appendingPathComponent("Demo")
        let demo = try AppStore(repository: SwiftDataRepository(root: demoRoot), vault: EvidenceVault(root: demoRoot), isDemoWorkspace: true, systemServicesEnabled: false)
        demo.resetDemoWorkspace(); let before = demo.state
        do { try await demo.restoreInBackground(archive); XCTFail("Personal care must not enter the fictional workspace") } catch { }
        XCTAssertEqual(demo.state, before); XCTAssertEqual(fixture.store.state, archive.state)
    }

    func testCancelledRestoreDoesNotReplaceExistingCare() async throws {
        let fixture = try makeStore(); let cleanupRoot9 = fixture.vault.root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot9) }
        _ = try fixture.store.capture(title: "Fictional retained care", kind: .typed, text: "Keep this record", analyze: false)
        let archive = CareArchive(state: CareState(), files: [:]); let before = fixture.store.state
        let task = Task { try await fixture.store.restoreInBackground(archive) }
        task.cancel()
        do { try await task.value; XCTFail("A cancelled restore cannot commit") } catch is CancellationError { } catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(fixture.store.state, before)
    }

    private func makeStore() throws -> (store: AppStore, vault: EvidenceVault) {
        let vault = try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        return (try AppStore(repository: SwiftDataRepository(root: vault.root), vault: vault, systemServicesEnabled: false), vault)
    }
    private func waitForIdle(_ flow: BackupWorkflow) async throws {
        for _ in 0..<400 {
            if !flow.busy { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("Backup operation did not finish: \(flow.activity)")
    }
}

@MainActor private final class BackupFailureRepository: CareRepository {
    var state = CareState(); var fail = false
    func load() throws -> CareState { state }
    func save(_ value: CareState) throws { if fail { throw CareError.invalid("Fictional full-disk failure") }; state = value }
}
