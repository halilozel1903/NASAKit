import Foundation

/// Errors thrown by ``NASAClient``.
public enum NASAError: Error, Equatable, Sendable, LocalizedError {
    /// api.nasa.gov answered 429: the key has used up its hourly requests. `DEMO_KEY` allows 30
    /// an hour per IP address, a personal key 1,000. The rate-limit headers, when sent, are
    /// attached.
    case rateLimited(NASARateLimit?)
    /// api.nasa.gov refused the key (HTTP 403 with `API_KEY_INVALID`, `API_KEY_MISSING` and the
    /// like).
    case apiKeyRejected(code: String, message: String?)
    /// Nothing exists at this address (HTTP 404), for example an unknown asteroid id or NASA id.
    case notFound(URL)
    /// The server rejected the parameters (HTTP 400), with its explanation, such as
    /// "Date must be between Jun 16, 1995 and Oct 13, 2026.".
    case badRequest(message: String?)
    /// Any other unsuccessful HTTP status, with the server's message when it sent one.
    case http(statusCode: Int, message: String?)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The arguments can't make a valid request; nothing was sent.
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case let .rateLimited(limit):
            if let limit, let total = limit.limit {
                return "The NASA API key has used all \(total) requests of this hour. Try again later or use a personal API key."
            }
            return "The NASA API key has used all its requests for now. Try again later or use a personal API key."
        case let .apiKeyRejected(code, message):
            return message ?? "api.nasa.gov rejected the API key (\(code))."
        case .notFound:
            return "NASA has nothing at this address."
        case let .badRequest(message):
            return message ?? "NASA rejected the request."
        case let .http(statusCode, message):
            return message ?? "NASA answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "NASA sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "NASA sent an invalid response."
        case let .invalidArgument(message):
            return message
        }
    }
}

/// The error bodies the APIs send, in every shape they use.
struct APIErrorBody: Decodable {
    /// api.nasa.gov gateway: `{"error":{"code":"OVER_RATE_LIMIT","message":"…"}}`.
    struct Gateway: Decodable {
        let code: String?
        let message: String?
    }

    let error: Gateway?
    /// APOD: `{"code":400,"msg":"…","service_version":"v1"}`.
    let msg: String?
    /// NeoWs: `{"code":404,"http_error":"NOT_FOUND","error_message":"…"}`.
    let errorMessage: String?
    /// NASA Image and Video Library: `{"reason":"…"}`.
    let reason: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case msg
        case errorMessage = "error_message"
        case reason
        case message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `error` is an object at the gateway, but a plain string elsewhere.
        error = try? container.decodeIfPresent(Gateway.self, forKey: .error)
        msg = try? container.decodeIfPresent(String.self, forKey: .msg)
        errorMessage = try? container.decodeIfPresent(String.self, forKey: .errorMessage)
        reason = try? container.decodeIfPresent(String.self, forKey: .reason)
        let plainError = try? container.decodeIfPresent(String.self, forKey: .error)
        message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? plainError
    }

    static func parse(_ data: Data) -> APIErrorBody? {
        try? JSONDecoder().decode(APIErrorBody.self, from: data)
    }

    var code: String? {
        error?.code
    }

    var text: String? {
        let candidates = [error?.message, msg, errorMessage, reason, message]
        return candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }
}
