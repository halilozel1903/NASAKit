import Foundation

/// Settings of a ``NASAClient``.
public struct NASAConfiguration: Sendable {
    /// `DEMO_KEY`, the shared key api.nasa.gov accepts for exploring: 30 requests an hour and 50 a
    /// day per IP address. Get a free personal key (1,000 requests an hour) at
    /// [api.nasa.gov](https://api.nasa.gov).
    public static let demoKey = "DEMO_KEY"

    /// The name of the environment variable ``apiKeyFromEnvironment(_:)`` reads.
    public static let apiKeyEnvironmentVariable = "NASA_API_KEY"

    /// `https://api.nasa.gov`: APOD, Mars Rover Photos, NeoWs and EPIC. Needs an API key.
    public static let defaultAPIBaseURL = URL(string: "https://api.nasa.gov")!
    /// `https://epic.gsfc.nasa.gov`: the EPIC API and image archive, without a key.
    public static let defaultEPICBaseURL = URL(string: "https://epic.gsfc.nasa.gov")!
    /// `https://images-api.nasa.gov`: the NASA Image and Video Library, without a key.
    public static let defaultImagesBaseURL = URL(string: "https://images-api.nasa.gov")!

    /// The key sent as `api_key` to api.nasa.gov. Never sent to the keyless hosts.
    public var apiKey: String
    /// Where api.nasa.gov requests go.
    public var apiBaseURL: URL
    /// Where keyless EPIC requests and archive images go.
    public var epicBaseURL: URL
    /// Where NASA Image and Video Library requests go.
    public var imagesBaseURL: URL
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// Sent as `User-Agent`.
    public var userAgent: String?
    /// The request timeout in seconds.
    public var timeout: TimeInterval

    public init(
        apiKey: String = NASAConfiguration.demoKey,
        apiBaseURL: URL = NASAConfiguration.defaultAPIBaseURL,
        epicBaseURL: URL = NASAConfiguration.defaultEPICBaseURL,
        imagesBaseURL: URL = NASAConfiguration.defaultImagesBaseURL,
        session: URLSession = .shared,
        userAgent: String? = "NASAKit (+https://github.com/halilozel1903/NASAKit)",
        timeout: TimeInterval = 30
    ) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = trimmed.isEmpty ? NASAConfiguration.demoKey : trimmed
        self.apiBaseURL = apiBaseURL
        self.epicBaseURL = epicBaseURL
        self.imagesBaseURL = imagesBaseURL
        self.session = session
        self.userAgent = userAgent
        self.timeout = timeout
    }

    /// Whether requests use the shared `DEMO_KEY`.
    public var usesDemoKey: Bool {
        apiKey == NASAConfiguration.demoKey
    }

    /// The `NASA_API_KEY` environment variable when it is set and not empty, else `nil`.
    public static func apiKeyFromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard let value = environment[apiKeyEnvironmentVariable]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    /// A configuration with the `NASA_API_KEY` environment variable as the key, or `DEMO_KEY`.
    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> NASAConfiguration {
        NASAConfiguration(apiKey: apiKeyFromEnvironment(environment) ?? demoKey)
    }
}
