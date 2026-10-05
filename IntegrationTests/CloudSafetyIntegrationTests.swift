import XCTest
import CareCore
@testable import CareContinuity

@MainActor final class CloudSafetyIntegrationTests: XCTestCase {
    func testProviderSecretsAreRejectedAsGatewayTokensAndMetadata() throws {
        for value in ["sk-proj-" + String(repeating: "x", count: 70), "sk_" + String(repeating: "x", count: 40), "github_pat_" + String(repeating: "x", count: 40), "Bearer" + String(repeating: "x", count: 40)] {
            XCTAssertThrowsError(try GatewayClient.validate(endpoint: "https://gateway.example", token: value))
            let info = GatewayProviderInfo(adapter: "openai", model: value, host: "api.openai.com", maxOutputTokens: 6000)
            XCTAssertThrowsError(try info.validate())
        }
    }
    func testValidModelIdentifiersAndDevelopmentMockRemainSupported() throws {
        for name in ["gpt-4.1-mini-2025-04-14", "provider/model-v1:latest"] {
            XCTAssertNoThrow(try GatewayProviderInfo(adapter: "compatible", model: name, host: "model.example:8443", maxOutputTokens: 6000).validate())
        }
        XCTAssertNoThrow(try GatewayProviderInfo(adapter: "mock", model: "synthetic-development", host: "local development", maxOutputTokens: 0).validate())
    }
    func testMalformedMetadataCannotBeDisplayedAsModelInformation() throws {
        for host in ["api.example/path", "user:password@api.example", "api.example?secret=1", "api.example#secret", "api.example secret", "sk-proj-fake.example"] {
            XCTAssertThrowsError(try GatewayProviderInfo(adapter: "openai", model: "gpt-4.1-mini", host: host, maxOutputTokens: 6000).validate())
        }
        XCTAssertThrowsError(try GatewayProviderInfo(adapter: "openai", model: "model with spaces", host: "api.openai.com", maxOutputTokens: 6000).validate())
        XCTAssertThrowsError(try GatewayProviderInfo(adapter: "unknown", model: "model", host: "api.example", maxOutputTokens: 6000).validate())
    }
    func testGatewayErrorsOnlyUseRecognizedCodesAndNeverEchoServerText() {
        XCTAssertTrue(GatewayClient.responseError(503, code: "provider_authentication").localizedDescription.contains("API key"))
        XCTAssertTrue(GatewayClient.responseError(503, code: "provider_quota").localizedDescription.contains("spending limit"))
        XCTAssertTrue(GatewayClient.responseError(503, code: "provider_response_invalid").localizedDescription.contains("Nothing was added"))
        let untrusted = "sk-proj-fictional-secret-should-not-be-displayed"
        XCTAssertFalse(GatewayClient.responseError(503, code: untrusted).localizedDescription.contains(untrusted))
        XCTAssertFalse(GatewayClient.responseError(400, code: "provider_quota").localizedDescription.contains("credits"))
        for endpoint in ["https://gateway.example/path with spaces", "https://sk-proj-fake.example", "https://gateway.example:99999"] {
            XCTAssertThrowsError(try GatewayClient.validate(endpoint: endpoint, token: String(repeating: "x", count: 48)))
        }
    }
    func testExistingWorkingTextCannotBeOverwrittenByOriginalExtraction() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot1 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let id = try store.capture(title: "Reviewed original", kind: .textFile, text: "Allergy: latex", data: Data("Allergy: latex".utf8), analyze: false)
        XCTAssertTrue(store.accept(try LocalExtractor.proposals(XCTUnwrap(store.source(id)))))
        let before = store.state
        store.extractOriginal(id)
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.analysisInProgress(id))
        XCTAssertNotNil(store.error)
    }
    func testSourceEditRejectsMissingBlankAndOversizedChangesWithoutLosingEvidence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cleanupRoot2 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot2) }
        let store = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
        let id = try store.capture(title: "Original", kind: .typed, text: "Allergy: latex", analyze: false)
        let before = store.state
        XCTAssertFalse(store.editSource(id, title: "  ", text: "changed", event: nil, encounter: nil, provider: ""))
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.editSource(id, title: "New", text: String(repeating: "x", count: 1_000_001), event: nil, encounter: nil, provider: ""))
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.editSource(UUID(), title: "Missing", text: "changed", event: nil, encounter: nil, provider: ""))
        XCTAssertEqual(store.state, before)
        XCTAssertTrue(store.editSource(id, title: "  Renamed  ", text: "", event: nil, encounter: nil, provider: ""))
        XCTAssertEqual(store.source(id)?.title, "Renamed")
        XCTAssertEqual(store.source(id)?.originalText, "Allergy: latex")
        XCTAssertEqual(store.source(id)?.state, .saved)
    }
}
