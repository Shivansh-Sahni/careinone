import Foundation
import CareCore

struct CloudExtractor: ExtractionProvider {
    let baseURL: URL; let token: String
    var version: String { "gateway-" + ProposalValidator.version }
    func extract(source: Source) async throws -> [Claim] {
        guard baseURL.scheme == "https", baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else { throw CareError.invalid("Cloud analysis requires an HTTPS backend URL without credentials, query, or fragment.") }
        guard !token.isEmpty else { throw CareError.invalid("Add your backend access token in Settings.") }
        struct Request: Encodable { var schemaVersion: String; var text: String; var sourceKind: String; var eventDate: String?; var consent: Bool }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/extract")); request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(schemaVersion: ProposalValidator.version, text: source.workingText, sourceKind: source.kind.rawValue, eventDate: source.eventAt?.ISO8601Format(), consent: true))
        let configuration = URLSessionConfiguration.ephemeral; configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let delegate = NoRedirectDelegate(); let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw CareError.invalid("Cloud analysis could not finish. Your source is saved. Retry or use local analysis.") }
        guard data.count <= 2_000_000 else { throw CareError.invalid("Analysis response exceeded the safe size limit.") }
        let envelope = try JSONDecoder().decode(ExtractionEnvelope.self, from: data)
        guard envelope.schemaVersion == ProposalValidator.version, envelope.claims.count <= 200 else { throw CareError.invalid("Unsupported analysis response schema or claim count.") }
        return try ProposalValidator.deduplicate(envelope.claims.map { try $0.claim(source: source, version: version) })
    }
}
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
