import Foundation

/// A client for NASA's open APIs.
///
/// - [api.nasa.gov](https://api.nasa.gov) with an API key: the Astronomy Picture of the Day,
///   Mars Rover Photos, Asteroids NeoWs and EPIC.
/// - Without a key: the EPIC API and archive at epic.gsfc.nasa.gov and the NASA Image and Video
///   Library at images-api.nasa.gov.
///
/// ```swift
/// let nasa = NASAClient(apiKey: "YOUR_KEY")          // or NASAClient() for DEMO_KEY
/// let today = try await nasa.apod()
/// let earth = try await nasa.epicImages(.natural)    // keyless
/// let found = try await nasa.searchMedia("apollo 11") // keyless
/// print(nasa.lastRateLimit?.remaining ?? 0)          // X-RateLimit-Remaining
/// ```
///
/// The client is `Sendable` and keeps no per-request state; share one across the app.
public final class NASAClient: Sendable {
    /// A client configured from the `NASA_API_KEY` environment variable, or `DEMO_KEY`.
    public static let shared = NASAClient(configuration: .fromEnvironment())

    public let configuration: NASAConfiguration
    private let rateLimitBox = RateLimitBox()

    public init(configuration: NASAConfiguration = NASAConfiguration()) {
        self.configuration = configuration
    }

    /// A client using `apiKey` for api.nasa.gov, with the default settings otherwise.
    public convenience init(apiKey: String) {
        self.init(configuration: NASAConfiguration(apiKey: apiKey))
    }

    /// The rate-limit headers of the latest api.nasa.gov answer, including refused ones; `nil`
    /// before the first request. The keyless hosts don't change it.
    public var lastRateLimit: NASARateLimit? {
        rateLimitBox.current
    }

    // MARK: - Requests

    /// The three hosts the client talks to.
    enum Service: Sendable {
        /// api.nasa.gov; requests carry the API key and answers carry rate-limit headers.
        case api
        /// epic.gsfc.nasa.gov, keyless.
        case epic
        /// images-api.nasa.gov, keyless.
        case images
    }

    /// The request for a path below a service's base URL. Each path segment is percent-encoded,
    /// so ids with spaces or slashes stay one segment.
    func request(_ service: Service, _ segments: [String], query: [URLQueryItem] = []) throws -> URLRequest {
        let base: URL
        switch service {
        case .api: base = configuration.apiBaseURL
        case .epic: base = configuration.epicBaseURL
        case .images: base = configuration.imagesBaseURL
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw NASAError.transport(URLError(.badURL))
        }
        var basePath = components.percentEncodedPath
        while basePath.hasSuffix("/") { basePath.removeLast() }
        let encoded = segments.map { segment in
            segment.addingPercentEncoding(withAllowedCharacters: NASAClient.segmentAllowed) ?? segment
        }
        components.percentEncodedPath = basePath + "/" + encoded.joined(separator: "/")
        var items = query
        if service == .api {
            items.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        }
        if !items.isEmpty {
            components.queryItems = items
            // URLComponents leaves "+" alone, but servers read it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else {
            throw NASAError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    /// Sends a GET request and decodes the JSON answer.
    func get<T: Decodable>(
        _ service: Service,
        _ segments: [String],
        query: [URLQueryItem] = [],
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try self.request(service, segments, query: query)
        let data = try await send(request, service: service)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw NASAError.decoding(type: String(describing: T.self), description: NASAClient.describe(error))
        }
    }

    /// Sends a request and returns the body of a successful answer; records rate-limit headers
    /// and maps everything else to ``NASAError``.
    func send(_ request: URLRequest, service: Service) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw NASAError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NASAError.invalidResponse
        }
        var rateLimit: NASARateLimit?
        if service == .api, let limit = NASARateLimit(response: http) {
            rateLimitBox.update(limit)
            rateLimit = limit
        }
        let status = http.statusCode
        if (200..<300).contains(status) {
            return data
        }
        let body = APIErrorBody.parse(data)
        switch status {
        case 429:
            throw NASAError.rateLimited(rateLimit)
        case 403 where body?.code == "OVER_RATE_LIMIT":
            throw NASAError.rateLimited(rateLimit)
        case 403 where body?.code?.hasPrefix("API_KEY") == true:
            throw NASAError.apiKeyRejected(code: body?.code ?? "API_KEY_INVALID", message: body?.text)
        case 404:
            throw NASAError.notFound(request.url ?? http.url ?? configuration.apiBaseURL)
        case 400:
            throw NASAError.badRequest(message: body?.text)
        default:
            throw NASAError.http(statusCode: status, message: body?.text)
        }
    }

    /// Characters left as they are in a path segment: everything URL-safe except `/`.
    private static let segmentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/;")
        return set
    }()

    static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { key in
                key.intValue.map { "[\($0)]" } ?? key.stringValue
            }
            return keys.isEmpty ? "the top level" : keys.joined(separator: ".")
        }
        switch error {
        case let .typeMismatch(type, context):
            return "Expected \(type) at \(path(context)): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "Missing \(type) at \(path(context)): \(context.debugDescription)"
        case let .keyNotFound(key, context):
            return "Missing key \(key.stringValue) at \(path(context))"
        case let .dataCorrupted(context):
            return "Invalid data at \(path(context)): \(context.debugDescription)"
        @unknown default:
            return String(describing: error)
        }
    }
}
