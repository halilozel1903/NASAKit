import Foundation
@testable import NASAKit

/// Recorded JSON responses in `Fixtures/`, in the APIs' real formats with sample values.
enum Fixture {
    struct Missing: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Missing(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(name))
    }
}

/// A canned HTTP response.
struct StubResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    static func json(_ fixture: String, headers: [String: String] = [:]) throws -> StubResponse {
        var all = ["Content-Type": "application/json"]
        all.merge(headers) { _, new in new }
        return try StubResponse(status: 200, headers: all, body: Fixture.data(fixture))
    }

    static func status(_ status: Int, body: String = "", headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: headers, body: Data(body.utf8))
    }
}

typealias StubHandler = @Sendable (URLRequest) throws -> StubResponse

/// Answers requests from the handler registered for the request's stub token (the second label
/// of the host), so every test runs in parallel with hosts of its own. Nothing ever reaches the
/// network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host,
              let token = StubRegistry.token(of: host),
              let handler = StubRegistry.shared.handler(for: token)
        else {
            // A plain server error: unlike a connectivity error, it never makes URLSession wait.
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        StubRegistry.shared.record(request, for: token)
        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()

    private let lock = NSLock()
    private var handlers: [String: StubHandler] = [:]
    private var requests: [String: [URLRequest]] = [:]

    /// `"api.<token>.nasa.test"` → `"<token>"`.
    static func token(of host: String) -> String? {
        let labels = host.split(separator: ".")
        guard labels.count >= 2 else { return nil }
        return String(labels[1])
    }

    func register(_ handler: @escaping StubHandler, for token: String) {
        lock.withLock { handlers[token] = handler }
    }

    func handler(for token: String) -> StubHandler? {
        lock.withLock { handlers[token] }
    }

    func record(_ request: URLRequest, for token: String) {
        lock.withLock { requests[token, default: []].append(request) }
    }

    func requests(for token: String) -> [URLRequest] {
        lock.withLock { requests[token] ?? [] }
    }
}

/// A client whose three hosts (api, epic, images) are answered by one stub handler.
struct StubbedClient {
    let token: String
    let client: NASAClient

    init(apiKey: String = "TEST_KEY", handler: @escaping StubHandler) {
        token = "t" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        StubRegistry.shared.register(handler, for: token)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = NASAClient(configuration: NASAConfiguration(
            apiKey: apiKey,
            apiBaseURL: URL(string: "https://api.\(token).nasa.test")!,
            epicBaseURL: URL(string: "https://epic.\(token).nasa.test")!,
            imagesBaseURL: URL(string: "https://images.\(token).nasa.test")!,
            session: URLSession(configuration: configuration)
        ))
    }

    /// Every request the client sent, in order.
    var requests: [URLRequest] {
        StubRegistry.shared.requests(for: token)
    }

    /// The last request's URL.
    var lastURL: URL? {
        requests.last?.url
    }

    /// The last request's path.
    var lastPath: String? {
        lastURL?.path
    }

    /// The first label of the last request's host: `"api"`, `"epic"` or `"images"`.
    var lastService: String? {
        lastURL?.host?.split(separator: ".").first.map(String.init)
    }

    /// The last request's query items, decoded.
    var lastQuery: [URLQueryItem] {
        guard let url = lastURL, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [] }
        return components.queryItems ?? []
    }

    /// The value of a query item of the last request.
    func lastQueryValue(_ name: String) -> String? {
        lastQuery.first(where: { $0.name == name })?.value
    }
}

/// Headers api.nasa.gov sends with an answer.
func rateLimitHeaders(limit: Int, remaining: Int) -> [String: String] {
    ["X-RateLimit-Limit": String(limit), "X-RateLimit-Remaining": String(remaining)]
}
