import Foundation

/// The rate-limit headers api.nasa.gov sends with every answer:
/// `X-RateLimit-Limit` and `X-RateLimit-Remaining`.
///
/// Limits are per key, per rolling hour. `DEMO_KEY` is also limited per IP address, which makes it
/// unreliable on shared machines such as CI runners.
public struct NASARateLimit: Sendable, Hashable, CustomStringConvertible {
    /// Requests allowed per hour, from `X-RateLimit-Limit`.
    public let limit: Int?
    /// Requests left in the current hour, from `X-RateLimit-Remaining`.
    public let remaining: Int

    public init(limit: Int?, remaining: Int) {
        self.limit = limit
        self.remaining = remaining
    }

    /// The headers of `response`, or `nil` when it has no `X-RateLimit-Remaining` (the keyless
    /// hosts never send it).
    public init?(response: HTTPURLResponse) {
        guard let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
            .flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) })
        else { return nil }
        self.remaining = remaining
        limit = response.value(forHTTPHeaderField: "X-RateLimit-Limit").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Whether the next request will be refused.
    public var isExhausted: Bool {
        remaining <= 0
    }

    /// `"27 of 30 requests left"`.
    public var description: String {
        if let limit {
            return "\(remaining) of \(limit) requests left"
        }
        return "\(remaining) requests left"
    }
}

/// The last rate limit a client saw, shared between concurrent requests.
final class RateLimitBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: NASARateLimit?

    var current: NASARateLimit? {
        lock.withLock { value }
    }

    func update(_ newValue: NASARateLimit) {
        lock.withLock { value = newValue }
    }
}
