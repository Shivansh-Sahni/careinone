import XCTest
import SwiftData
import PDFKit
import UIKit
import CareCore
@testable import CareContinuity

@MainActor final class CareContinuityIntegrationTests: XCTestCase {
    func vault() throws -> EvidenceVault { try EvidenceVault(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) }
    func testSwiftDataRoundTripAndDerivedRecords() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at: vault.root) }
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
        let vault = try vault(); defer { try? FileManager.default.removeItem(at: vault.root) }
        let repository = try SwiftDataRepository(root: vault.root); let store = try AppStore(repository: repository,vault:vault)
        let id = try store.capture(title:"Synthetic note",kind:.typed,text:"Allergy: penicillin")
        for _ in 0..<100 where store.source(id)?.state == .processing || store.source(id)?.state == .pending { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertEqual(store.source(id)?.state,.needsReview); XCTAssertTrue(store.state.entities.isEmpty)
        XCTAssertTrue(store.accept(store.state.claims.filter { $0.sourceID == id && $0.review == .pending }))
        XCTAssertEqual(store.state.entities.count,1); XCTAssertEqual(try repository.load().entities.count,1)
        store.deleteSource(id); XCTAssertTrue(store.state.entities.isEmpty); XCTAssertTrue(try repository.load().claims.isEmpty)
    }
    func testDuplicateOriginalFileIsNotCopiedTwice() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at: vault.root) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault)
        let data = Data("synthetic original".utf8)
        let a = try store.capture(title:"First",kind:.textFile,text:"synthetic original",data:data,analyze:false)
        let b = try store.capture(title:"Again",kind:.textFile,text:"synthetic original",data:data,analyze:false)
        XCTAssertEqual(a,b); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:vault.files.path).count,1)
        store.deleteSource(a); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:vault.files.path).count,0)
    }
    func testAudioDeletionPreservesTranscriptAndClaims() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault)
        let id = try store.capture(title:"Voice",kind:.voice,text:"A remembered update",analyze:false)
        let filename = try vault.write(Data([1,2,3]),extension:"m4a")
        _ = store.mutate { state in state.sources[0].audioFile=filename }
        store.deleteAudio(id); XCTAssertEqual(store.source(id)?.workingText,"A remembered update"); XCTAssertNil(store.source(id)?.audioFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath:try vault.url(filename).path))
    }
    func testSourceEditRetiresClaimsAndKeepsOriginal() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let store = try AppStore(repository:SwiftDataRepository(root:vault.root),vault:vault)
        let id = try store.capture(title:"Visit",kind:.typed,text:"metoprolol 25 mg",analyze:false)
        let source = try XCTUnwrap(store.source(id)); XCTAssertTrue(store.accept(try LocalExtractor.proposals(source)))
        store.editSource(id,title:"Visit corrected",text:"metoprolol 50 mg",event:nil,encounter:nil,provider:"")
        XCTAssertEqual(store.source(id)?.originalText,"metoprolol 25 mg"); XCTAssertEqual(store.source(id)?.previousText,["metoprolol 25 mg"])
        XCTAssertTrue(store.state.entities.isEmpty); XCTAssertTrue(store.state.claims.allSatisfy { !$0.canonical })
    }
    func testFailedTransactionDoesNotPublishUncommittedState() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let repo = FailingRepository(); let store = try AppStore(repository:repo,vault:vault); repo.fail = true
        let before = store.state; XCTAssertFalse(store.mutate { $0.profile.displayName="Unsaved" }); XCTAssertEqual(store.state,before)
    }
    func testInterruptedAnalysisRecoversWithoutLoss() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let repository = try SwiftDataRepository(root:vault.root); var state = CareState()
        var source=Source(title:"Interrupted",kind:.typed,text:"Saved before analysis",contentHash:"hash"); source.state = .processing; state.sources=[source]; try repository.save(state)
        let store=try AppStore(repository:repository,vault:vault); XCTAssertEqual(store.source(source.id)?.state,.pending); XCTAssertEqual(store.source(source.id)?.originalText,"Saved before analysis")
    }
    func testVaultTraversalRejected() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
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
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let provider = ControlledExtractor()
        let store = try AppStore(repository: FailingRepository(), vault: vault, extractionProvider: provider)
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
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let provider = ControlledExtractor(); let repository = FailingRepository()
        repository.value.profile.cloudConsent = true
        let store = try AppStore(repository:repository,vault:vault,extractionProvider:provider)
        let id = try store.capture(title:"Synthetic",kind:.typed,text:"Allergy: penicillin")
        for _ in 0..<100 { if await provider.count == 1 { break }; try await Task.sleep(for:.milliseconds(10)) }
        var profile = store.state.profile; profile.cloudConsent = false; XCTAssertTrue(store.saveProfile(profile))
        await provider.finish(0); try await Task.sleep(for:.milliseconds(50))
        XCTAssertTrue(store.state.claims.isEmpty); XCTAssertEqual(store.source(id)?.state,.cancelled)
        XCTAssertEqual(store.source(id)?.originalText,"Allergy: penicillin")
    }
    func testRecoveredTranscriptKeepsVerifiedTimestampEvidence() throws {
        let vault = try vault(); defer { try? FileManager.default.removeItem(at:vault.root) }
        let store = try AppStore(repository:FailingRepository(),vault:vault)
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
