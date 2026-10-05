import XCTest
import CareCore
@testable import CareContinuity

/// Explicit opt-in only: consumes one local marker and sends two fixed fictional requests.
/// Never exports Keychain credentials or reads the user's saved patient records.
@MainActor final class LiveGatewayIntegrationTests: XCTestCase {
    func testOptInRealCloudSourceReviewAndPersistence() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneLiveVerification.request")
        guard (try? String(contentsOf: marker, encoding: .utf8)) == "fictional-cloud-check-v1" else {
            throw XCTSkip("Live cloud verification requires the explicit one-use fictional-data marker.")
        }
        try FileManager.default.removeItem(at: marker)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LiveGateway-" + UUID().uuidString)
        let cleanupRoot1 = root; addTeardownBlock { try? FileManager.default.removeItem(at: cleanupRoot1) }
        var report: [String: Any] = ["syntheticOnly": true, "paidRequestsAttempted": 0, "checkedAtUTC": Date().ISO8601Format(), "status": "pending"]
        var stage = "configuration"
        defer {
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let summary = String(data: data, encoding: .utf8) {
                print("CAREINONE_LIVE_VERIFICATION=" + summary)
            }
        }
        do {
            let credentials = KeychainStore.backend
            let url = try GatewayClient.validate(endpoint: credentials.endpoint, token: credentials.token)
            let client = GatewayClient(baseURL: url, token: credentials.token)
            let configuration = try await client.configuration()
            guard configuration.providers.primary.adapter != "mock", configuration.providers.fallback?.adapter != "mock" else {
                throw CareError.invalid("Real model verification cannot use a development mock.")
            }
            report["primaryModel"] = configuration.providers.primary.model
            report["primaryHost"] = configuration.providers.primary.host
            report["configurationID"] = configuration.configurationID
            stage = "synthetic_connection_check"; report["paidRequestsAttempted"] = 1
            let check = try await client.check()
            guard check.providers == configuration.providers, ["primary", "fallback"].contains(check.route) else {
                throw CareError.invalid("The checked model recipients changed or returned an unsupported route.")
            }
            report["checkRoute"] = check.route
            let repository = try SwiftDataRepository(root: root)
            let store = try AppStore(repository: repository, vault: EvidenceVault(root: root), systemServicesEnabled: false)
            var profile = store.state.profile
            profile.cloudConsent = true; profile.cloudConsentAt = Date(); profile.cloudProviderConfigurationID = configuration.configurationID
            guard store.saveProfile(profile) else { throw CareError.invalid("Could not save the isolated fictional profile.") }
            let text = "Follow up with the cardiology clinic within 7 days. This is fictional test information."
            let id = try store.capture(title: "Fictional cloud pipeline verification", kind: .typed, text: text, analyze: false)
            guard store.mutate({ state in state.sources[0].synthetic = true }) else { throw CareError.invalid("Could not save the isolated fictional source.") }
            stage = "source_analysis"; report["paidRequestsAttempted"] = 2
            store.analyze(id, force: true)
            for _ in 0..<2_000 {
                if !store.analysisInProgress(id) { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            guard !store.analysisInProgress(id), store.source(id)?.state == .needsReview else {
                store.cancelAnalysis(id)
                throw CareError.invalid("Real source analysis did not produce reviewable proposals.")
            }
            let proposals = store.state.claims.filter { $0.sourceID == id && $0.review == .pending }
            guard !proposals.isEmpty, proposals.allSatisfy({ !$0.quote.isEmpty && text.contains($0.quote) }) else {
                throw CareError.invalid("Real proposals did not preserve supporting quotations.")
            }
            guard store.state.entities.isEmpty else { throw CareError.invalid("Proposals entered care before review.") }
            stage = "review_and_persistence"
            guard store.accept(proposals) else { throw CareError.invalid("The reviewed fictional proposals could not be saved.") }
            let reopened = try AppStore(repository: SwiftDataRepository(root: root), vault: EvidenceVault(root: root), systemServicesEnabled: false)
            guard reopened.state.claims.filter({ $0.sourceID == id && $0.canonical }).count == proposals.count,
                  reopened.source(id)?.originalText == text else { throw CareError.invalid("Reviewed fictional care did not persist.") }
            report["proposals"] = proposals.count
            report["supportingQuotesPreserved"] = true
            report["reviewGateVerified"] = true
            report["savedCareSurvivedRelaunch"] = true
            report["status"] = "passed"
        } catch {
            report["status"] = "blocked_or_failed"; report["stage"] = stage
            report["recoveryMessage"] = String(error.localizedDescription.prefix(600))
            // A fixed category is sufficient; raw provider error bodies never reach test logs.
            XCTFail("Live fictional cloud verification failed at " + stage + ". Inspect the app’s sanitized recovery message; no credentials were printed.")
        }
    }
}
