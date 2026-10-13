import Foundation
import Observation
import NASAKit

/// Whether a screen's data is there yet.
enum LoadPhase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// A library item with the image to show for it: a sharp size from its asset list, or the
/// search result's preview when the asset list can't be read. Both are the item's real image.
struct LibraryEntry: Identifiable, Hashable {
    let item: NASAMediaItem
    let imageURL: URL

    var id: String { item.nasaID }
}

/// A titled row of library results.
struct LibraryRail: Identifiable {
    let topic: Explorer.Topic
    let entries: [LibraryEntry]

    var id: String { topic.query }
}

/// The app's data, all live: NASA Image and Video Library searches, the latest EPIC images of
/// Earth and recent Astronomy Pictures of the Day.
@Observable
@MainActor
final class Explorer {
    /// A library search shown as a rail.
    struct Topic: Sendable, Hashable {
        let title: String
        let query: String
    }

    /// The rails of the home screen.
    static let topics: [Topic] = [
        Topic(title: "Nebulae", query: "nebula"),
        Topic(title: "Apollo 11", query: "apollo 11"),
        Topic(title: "Space Station", query: "international space station"),
    ]

    /// Items per rail.
    static let railLength = 12

    let client: NASAClient
    /// Whether api.nasa.gov requests use a personal key rather than `DEMO_KEY`.
    let hasPersonalKey: Bool
    /// Screenshot scenes never fall back to `DEMO_KEY`: without a key they show nothing.
    private let requiresPersonalKey: Bool
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    private(set) var homePhase: LoadPhase = .idle
    private(set) var hero: LibraryEntry?
    private(set) var rails: [LibraryRail] = []

    private(set) var earthPhase: LoadPhase = .idle
    /// The latest day's EPIC images, oldest first.
    private(set) var earthImages: [EPICImage] = []

    private(set) var apodPhase: LoadPhase = .idle
    /// Recent pictures of the day with an image to show, newest first.
    private(set) var apodEntries: [APODEntry] = []
    /// The rate-limit headers of the latest api.nasa.gov answer.
    private(set) var rateLimit: NASARateLimit?

    private var assetCache: [String: NASAMediaAsset] = [:]

    init(client: NASAClient, hasPersonalKey: Bool, requiresPersonalKey: Bool = false, attempts: Int = 1) {
        self.client = client
        self.hasPersonalKey = hasPersonalKey
        self.requiresPersonalKey = requiresPersonalKey
        self.attempts = max(1, attempts)
    }

    /// An explorer on the live APIs, with the `NASA_API_KEY` environment variable as the key when
    /// it is set. Screenshot scenes retry failed requests up to four times.
    static func make(for scene: ScreenshotScene?) -> Explorer {
        let key = NASAConfiguration.apiKeyFromEnvironment()
        let client = NASAClient(configuration: NASAConfiguration(apiKey: key ?? NASAConfiguration.demoKey))
        return Explorer(
            client: client,
            hasPersonalKey: key != nil,
            requiresPersonalKey: scene != nil,
            attempts: scene == nil ? 2 : 4
        )
    }

    // MARK: - Library

    /// Searches every topic, resolves sharp images for the results and picks the hero.
    func loadHome() async {
        guard homePhase != .loading else { return }
        homePhase = .loading
        let client = self.client
        let attempts = self.attempts
        do {
            var loaded: [LibraryRail] = []
            for topic in Self.topics {
                let query = topic.query
                let result = try await Self.retrying(attempts: attempts) {
                    try await client.searchMedia(query, mediaType: .image, pageSize: 40)
                }
                let items = Array(result.items(of: .image).filter { $0.previewURL != nil }.prefix(Self.railLength + 1))
                let entries = await Self.resolveImages(of: items, client: client, attempts: attempts, sizes: [.medium, .small, .large])
                if !entries.isEmpty {
                    loaded.append(LibraryRail(topic: topic, entries: entries))
                }
            }
            guard let first = loaded.first else {
                throw NASAError.invalidArgument("The NASA Image and Video Library returned no images.")
            }
            // The hero is the first landscape image of the first rail, in a large size.
            let pick = first.entries.first { $0.item.isLandscape == true } ?? first.entries[0]
            let heroURL = try? await asset(for: pick.item.nasaID).bestImage(preferring: [.large, .medium])
            hero = LibraryEntry(item: pick.item, imageURL: heroURL ?? pick.imageURL)
            rails = loaded.map { rail in
                LibraryRail(topic: rail.topic, entries: Array(rail.entries.filter { $0.id != pick.id }.prefix(Self.railLength)))
            }
            homePhase = .loaded
        } catch {
            homePhase = .failed(error.localizedDescription)
        }
    }

    /// Library images matching `text`.
    func search(_ text: String) async throws -> [NASAMediaItem] {
        let client = self.client
        let result = try await Self.retrying(attempts: attempts) {
            try await client.searchMedia(text, mediaType: .image, pageSize: 50)
        }
        return result.items(of: .image).filter { $0.previewURL != nil }
    }

    /// The files of an item, cached after the first load.
    func asset(for nasaID: String) async throws -> NASAMediaAsset {
        if let cached = assetCache[nasaID] {
            return cached
        }
        let client = self.client
        let asset = try await Self.retrying(attempts: attempts) {
            try await client.mediaAsset(nasaID: nasaID)
        }
        assetCache[nasaID] = asset
        return asset
    }

    /// The best image of an item in the given sizes, or its preview when it has none of them.
    func image(of item: NASAMediaItem, preferring sizes: [NASAMediaAsset.Rendition]) async throws -> URL {
        let asset = try await asset(for: item.nasaID)
        guard let url = asset.bestImage(preferring: sizes) ?? item.previewURL else {
            throw NASAError.invalidArgument("\(item.title) has no image.")
        }
        return url
    }

    // MARK: - EPIC

    /// The latest day of natural-color EPIC images, from epic.gsfc.nasa.gov (no key).
    func loadEarth() async {
        guard earthPhase != .loading else { return }
        earthPhase = .loading
        let client = self.client
        do {
            var images = try await Self.retrying(attempts: attempts) {
                try await client.epicImages(.natural)
            }
            if images.isEmpty {
                // The latest-day endpoint can come back empty while a day is processed; ask for
                // the newest day the archive lists instead.
                let days = try await Self.retrying(attempts: attempts) {
                    try await client.epicAvailableDates(.natural)
                }
                if let day = days.last {
                    images = try await Self.retrying(attempts: attempts) {
                        try await client.epicImages(.natural, date: day)
                    }
                }
            }
            guard !images.isEmpty else {
                throw NASAError.invalidArgument("EPIC returned no images.")
            }
            earthImages = images
            earthPhase = .loaded
        } catch {
            earthPhase = .failed(error.localizedDescription)
        }
    }

    // MARK: - APOD

    /// The pictures of the last ten days from api.nasa.gov.
    func loadAPOD() async {
        guard apodPhase != .loading else { return }
        if requiresPersonalKey && !hasPersonalKey {
            apodPhase = .failed("Set the NASA_API_KEY environment variable to show the Astronomy Picture of the Day.")
            return
        }
        apodPhase = .loading
        let client = self.client
        // APOD publishes by US Eastern time; today's picture may not be up yet.
        let today = CalendarDate.today(in: TimeZone(identifier: "America/New_York") ?? .current)
        let start = today.adding(days: -10)
        let end = today.adding(days: -1)
        do {
            var entries = try await Self.retrying(attempts: attempts) {
                try await client.apod(from: start, through: end)
            }
            if let latest = try? await client.apod(date: today) {
                entries.append(latest)
            }
            rateLimit = client.lastRateLimit
            let shown = entries
                .filter { $0.displayImageURL != nil }
                .sorted { $0.date > $1.date }
            guard !shown.isEmpty else {
                throw NASAError.invalidArgument("APOD returned no pictures.")
            }
            apodEntries = shown
            apodPhase = .loaded
        } catch {
            rateLimit = client.lastRateLimit
            apodPhase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Finds a sharp image for each item in its asset list, in parallel. Items whose asset list
    /// can't be read keep their preview image.
    private nonisolated static func resolveImages(
        of items: [NASAMediaItem],
        client: NASAClient,
        attempts: Int,
        sizes: [NASAMediaAsset.Rendition]
    ) async -> [LibraryEntry] {
        let resolved = await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, item) in items.enumerated() {
                let nasaID = item.nasaID
                group.addTask {
                    let asset = try? await Explorer.retrying(attempts: attempts) {
                        try await client.mediaAsset(nasaID: nasaID)
                    }
                    return (index, asset?.bestImage(preferring: sizes))
                }
            }
            var urls: [Int: URL] = [:]
            for await (index, url) in group {
                if let url { urls[index] = url }
            }
            return urls
        }
        return items.enumerated().compactMap { index, item in
            guard let url = resolved[index] ?? item.previewURL else { return nil }
            return LibraryEntry(item: item, imageURL: url)
        }
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    /// Invalid arguments are not retried.
    private nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                if let nasaError = error as? NASAError, case .invalidArgument = nasaError { throw error }
                guard attempt < attempts, !Task.isCancelled else { throw error }
                print("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 2))
                attempt += 1
            }
        }
    }
}
