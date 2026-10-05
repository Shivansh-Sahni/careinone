import Foundation
import CareCore

struct GatewayProviderInfo: Decodable, Sendable, Equatable {
    let adapter: String
    let model: String
    let host: String
    let maxOutputTokens: Int
    func validate() throws {
        if adapter == "mock", model == "synthetic-development", host == "local development", maxOutputTokens == 0 { return }
        guard model.range(of: "^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$", options: .regularExpression) != nil,
              !GatewayClient.looksLikeProviderSecret(model),
              !GatewayClient.looksLikeProviderSecret(host),
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: "https://" + host), url.host != nil, url.path.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || (1...65535).contains(url.port!),
              ["openai", "kimi", "compatible"].contains(adapter),
              (256...16000).contains(maxOutputTokens) else {
            throw CareError.invalid("The gateway returned unsafe model settings. Ask its operator to correct the model name and host; provider API keys must never appear in model details.")
        }
    }
}
struct GatewayProviders: Decodable, Sendable, Equatable {
    let primary: GatewayProviderInfo
    let fallback: GatewayProviderInfo?
    func validate() throws { try primary.validate(); try fallback?.validate() }
}
struct GatewayConfiguration: Decodable, Sendable {
    let schemaVersion: String
    let configurationID: String
    let providers: GatewayProviders
    let maxSourceCharacters: Int
    let patientContentStored: Bool
}
struct GatewayCheck: Decodable, Sendable {
    let schemaVersion: String
    let status: String
    let route: String
    let providers: GatewayProviders
    let syntheticOnly: Bool
}

/// Credentials are sent only to the configured gateway, never across redirects.
struct GatewayClient: Sendable {
    let baseURL: URL
    let token: String
    static func looksLikeProviderSecret(_ value: String) -> Bool {
        value.range(of: "^(sk[-_]|gh[pousr]_|github_pat_|AIza|AKIA|ASIA|xox[baprs]-|Bearer|eyJ)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    static func validate(endpoint: String, token: String) throws -> URL {
        guard endpoint.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: endpoint), url.scheme == "https", let host = url.host, !host.isEmpty,
              !looksLikeProviderSecret(host), url.port == nil || (1...65535).contains(url.port!),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw CareError.invalid("Use your gateway’s HTTPS address without embedded credentials, query parameters, or a fragment.")
        }
        guard !["api.openai.com", "api.moonshot.ai", "api.moonshot.cn"].contains(host.lowercased()) else {
            throw CareError.invalid("This is a model provider address. Enter the CareInOne gateway address instead. Provider API keys stay on your server.")
        }
        guard !looksLikeProviderSecret(token) else {
            throw CareError.invalid("This looks like a model provider API key. Use your gateway access token instead; OpenAI and other provider keys belong only on the server.")
        }
        guard token.utf8.count >= 32, token.utf8.count <= 4000, token.utf8.allSatisfy({ $0 > 32 && $0 < 127 }) else {
            throw CareError.invalid("Use the gateway access token from your server configuration (at least 32 characters).")
        }
        return url
    }
    func configuration() async throws -> GatewayConfiguration {
        let data = try await send(path: "v1/config", body: nil, limit: 32_000)
        let result = try JSONDecoder().decode(GatewayConfiguration.self, from: data)
        guard result.schemaVersion == ProposalValidator.version else { throw CareError.invalid("The gateway needs a compatible CareInOne update.") }
        try result.providers.validate()
        guard result.configurationID.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              (1...1_000_000).contains(result.maxSourceCharacters) else { throw CareError.invalid("The gateway returned an unsupported configuration.") }
        return result
    }
    func check() async throws -> GatewayCheck {
        let body = try JSONEncoder().encode(["schemaVersion": ProposalValidator.version])
        let data = try await send(path: "v1/check", body: body, limit: 32_000)
        let result = try JSONDecoder().decode(GatewayCheck.self, from: data)
        guard result.schemaVersion == ProposalValidator.version, result.status == "ok", result.syntheticOnly,
              ["primary", "fallback"].contains(result.route), result.route != "fallback" || result.providers.fallback != nil else { throw CareError.invalid("The gateway returned an unsupported connection-check result.") }
        try result.providers.validate()
        return result
    }
    func send(path: String, body: Data?, limit: Int = 2_000_000) async throws -> Data {
        _ = try Self.validate(endpoint: baseURL.absoluteString, token: token)
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 195 // Server's complete chunked-analysis deadline is 180 seconds.
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw CareError.invalid("The gateway did not return an HTTP response.") }
            if http.statusCode != 200 {
                // Never echo an untrusted server body: it may contain credentials or patient text.
                var errorData = Data()
                for try await byte in bytes {
                    guard errorData.count < 8_000 else { break }
                    errorData.append(byte)
                }
                struct Failure: Decodable { let errorCode: String? }
                let code = (try? JSONDecoder().decode(Failure.self, from: errorData))?.errorCode
                throw Self.responseError(http.statusCode, code: code)
            }
            guard response.expectedContentLength <= Int64(limit) else { throw CareError.invalid("The gateway response exceeded the safe size limit.") }
            var data = Data(); data.reserveCapacity(min(limit, 32_000))
            for try await byte in bytes {
                guard data.count < limit else { throw CareError.invalid("The gateway response exceeded the safe size limit.") }
                data.append(byte)
            }
            try Task.checkCancellation()
            return data
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw CareError.invalid("Could not reach the gateway securely. Check your connection, HTTPS address, and server availability. Your saved sources remain on this device.")
        }
    }
    static func responseError(_ status: Int, code: String? = nil) -> CareError {
        let message: String
        if status == 503, let code {
            let known = [
                "provider_configuration": "The gateway’s model settings need correction. Check its provider, model name, and HTTPS endpoint. Your original source is still saved.",
                "provider_authentication": "The model provider rejected the server’s API key. Its operator needs to replace the key on the server. Keep your gateway access token unchanged.",
                "provider_permission": "The server’s API key does not have access to this model. Its operator needs to check project permissions and model access.",
                "provider_model": "The configured model or provider endpoint is unavailable. Its operator needs to check the exact model identifier and endpoint.",
                "provider_quota": "The model provider has no available API quota or credits. Check its API billing without increasing your spending limit. Local analysis remains available.",
                "provider_rate_limit": "The model provider is receiving too many requests. Wait before retrying; your source is still saved.",
                "provider_response_invalid": "The model did not return supported, evidence-backed proposals. Nothing was added to My Care. You can retry or use local analysis.",
                "provider_unavailable": "The model provider is temporarily unavailable. Retry later or use local analysis. Your original source is still saved."
            ]
            if let safe = known[code] { return CareError.invalid(safe) }
        }
        switch status {
        case 401, 403: message = "The gateway did not accept this access token. Check its server configuration."
        case 404: message = "This address does not expose the expected CareInOne gateway endpoint. Check the URL and server version."
        case 409: message = "The model recipients changed. Open Cloud connection in Settings, check its configuration, and renew consent before sending more source text."
        case 413: message = "This source exceeds the gateway’s analysis limit. Use local analysis or split the source into smaller documents."
        case 429: message = "The gateway’s request limit was reached. Wait a minute before trying again."
        case 422: message = "The gateway could not validate this request. Check that the app and gateway versions match."
        case 503, 504: message = "The configured model could not complete analysis. Retry later or use local analysis."
        default: message = "The gateway could not complete this request. Your saved evidence remains on this device."
        }
        return CareError.invalid(message)
    }
}

struct CloudExtractor: ExtractionProvider {
    let baseURL: URL
    let token: String
    var configurationID: String? = nil
    var version: String { "gateway-" + ProposalValidator.version + "-" + (configurationID ?? "unapproved") }
    func extract(source: Source) async throws -> [Claim] {
        guard let configurationID else { throw CareError.invalid("Review and allow the configured model recipients in Settings → Cloud connection before cloud analysis.") }
        struct Request: Encodable { var schemaVersion: String; var text: String; var sourceKind: String; var eventDate: String?; var consent: Bool; var providerConfigurationID: String }
        let body = try JSONEncoder().encode(Request(schemaVersion: ProposalValidator.version, text: source.workingText, sourceKind: source.kind.rawValue, eventDate: source.eventAt?.ISO8601Format(), consent: true, providerConfigurationID: configurationID))
        let data = try await GatewayClient(baseURL: baseURL, token: token).send(path: "v1/extract", body: body)
        let envelope = try JSONDecoder().decode(ExtractionEnvelope.self, from: data)
        guard envelope.schemaVersion == ProposalValidator.version, envelope.claims.count <= 200 else { throw CareError.invalid("Unsupported analysis response schema or claim count.") }
        return try ProposalValidator.deduplicate(envelope.claims.map { try $0.claim(source: source, version: version) })
    }
}
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
