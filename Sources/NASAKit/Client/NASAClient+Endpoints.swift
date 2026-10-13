import Foundation

// MARK: - Astronomy Picture of the Day

extension NASAClient {
    /// The picture of a day (`/planetary/apod?date=`), today's when `date` is `nil`.
    ///
    /// - Parameters:
    ///   - date: A day from ``APODEntry/firstDate`` (June 16, 1995) to today, US Eastern time.
    ///   - thumbnails: Asks for ``APODEntry/thumbnailURL`` on video entries (`thumbs=true`).
    public func apod(date: CalendarDate? = nil, thumbnails: Bool = true) async throws -> APODEntry {
        var query: [URLQueryItem] = []
        if let date {
            try Self.validateAPODDate(date)
            query.append(URLQueryItem(name: "date", value: date.description))
        }
        if thumbnails { query.append(URLQueryItem(name: "thumbs", value: "true")) }
        return try await get(.api, ["planetary", "apod"], query: query)
    }

    /// The pictures of a range of days (`start_date` and `end_date`), oldest first. Without
    /// `end`, the range runs to today.
    public func apod(from start: CalendarDate, through end: CalendarDate? = nil, thumbnails: Bool = true) async throws -> [APODEntry] {
        try Self.validateAPODDate(start)
        var query = [URLQueryItem(name: "start_date", value: start.description)]
        if let end {
            guard end >= start else {
                throw NASAError.invalidArgument("The end date \(end) is before the start date \(start).")
            }
            query.append(URLQueryItem(name: "end_date", value: end.description))
        }
        if thumbnails { query.append(URLQueryItem(name: "thumbs", value: "true")) }
        let entries: [APODEntry] = try await get(.api, ["planetary", "apod"], query: query)
        return entries.sorted { $0.date < $1.date }
    }

    /// `count` pictures of randomly chosen days (`count=`), 1 to 100.
    public func randomAPOD(count: Int, thumbnails: Bool = true) async throws -> [APODEntry] {
        guard (1...100).contains(count) else {
            throw NASAError.invalidArgument("APOD returns 1 to 100 random entries; \(count) were asked for.")
        }
        var query = [URLQueryItem(name: "count", value: String(count))]
        if thumbnails { query.append(URLQueryItem(name: "thumbs", value: "true")) }
        return try await get(.api, ["planetary", "apod"], query: query)
    }

    private static func validateAPODDate(_ date: CalendarDate) throws {
        guard date >= APODEntry.firstDate else {
            throw NASAError.invalidArgument("APOD starts on \(APODEntry.firstDate); \(date) is earlier.")
        }
    }
}

// MARK: - Mars Rover Photos

extension NASAClient {
    /// Photos a rover took on a Martian day (`/rovers/:rover/photos?sol=`), 25 per page.
    ///
    /// - Parameters:
    ///   - camera: Only this camera's photos; `nil` for all.
    ///   - page: The 1-based page; `nil` returns every photo of the sol.
    public func marsPhotos(rover: MarsRover, sol: Int, camera: MarsCameraName? = nil, page: Int? = nil) async throws -> [MarsPhoto] {
        guard sol >= 0 else {
            throw NASAError.invalidArgument("A sol can't be negative.")
        }
        var query = [URLQueryItem(name: "sol", value: String(sol))]
        query += try Self.marsFilters(camera: camera, page: page)
        let response: MarsPhotosResponse = try await get(.api, Self.marsPath(rover, "photos"), query: query)
        return response.photos
    }

    /// Photos a rover took on an Earth day (`/rovers/:rover/photos?earth_date=`).
    public func marsPhotos(rover: MarsRover, earthDate: CalendarDate, camera: MarsCameraName? = nil, page: Int? = nil) async throws -> [MarsPhoto] {
        var query = [URLQueryItem(name: "earth_date", value: earthDate.description)]
        query += try Self.marsFilters(camera: camera, page: page)
        let response: MarsPhotosResponse = try await get(.api, Self.marsPath(rover, "photos"), query: query)
        return response.photos
    }

    /// The photos of the rover's most recent sol with photos (`/rovers/:rover/latest_photos`).
    public func latestMarsPhotos(rover: MarsRover, camera: MarsCameraName? = nil, page: Int? = nil) async throws -> [MarsPhoto] {
        let query = try Self.marsFilters(camera: camera, page: page)
        let response: MarsLatestPhotosResponse = try await get(.api, Self.marsPath(rover, "latest_photos"), query: query)
        return response.latestPhotos
    }

    /// The rover's mission manifest (`/manifests/:rover`).
    public func marsManifest(rover: MarsRover) async throws -> MarsMissionManifest {
        let response: MarsManifestResponse = try await get(.api, ["mars-photos", "api", "v1", "manifests", rover.rawValue])
        return response.manifest
    }

    /// Every rover with its cameras and mission status (`/rovers`).
    public func marsRovers() async throws -> [MarsRoverInfo] {
        let response: MarsRoversResponse = try await get(.api, ["mars-photos", "api", "v1", "rovers"])
        return response.rovers
    }

    private static func marsPath(_ rover: MarsRover, _ resource: String) -> [String] {
        ["mars-photos", "api", "v1", "rovers", rover.rawValue, resource]
    }

    private static func marsFilters(camera: MarsCameraName?, page: Int?) throws -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        if let camera { query.append(URLQueryItem(name: "camera", value: camera.rawValue)) }
        if let page {
            guard page >= 1 else { throw NASAError.invalidArgument("Pages start at 1.") }
            query.append(URLQueryItem(name: "page", value: String(page)))
        }
        return query
    }
}

// MARK: - Asteroids NeoWs

extension NASAClient {
    /// The longest range ``neoFeed(from:through:)`` accepts, in days after the start.
    public static let neoFeedMaximumDays = 7

    /// Near-Earth objects by the day of their closest approach (`/neo/rest/v1/feed`). NeoWs
    /// allows up to seven days after `start`; without `end` it returns seven.
    public func neoFeed(from start: CalendarDate, through end: CalendarDate? = nil) async throws -> NEOFeed {
        var query = [URLQueryItem(name: "start_date", value: start.description)]
        if let end {
            let span = start.days(until: end)
            guard span >= 0 else {
                throw NASAError.invalidArgument("The end date \(end) is before the start date \(start).")
            }
            guard span <= Self.neoFeedMaximumDays else {
                throw NASAError.invalidArgument("The NeoWs feed covers at most \(Self.neoFeedMaximumDays) days; \(start) to \(end) is \(span).")
            }
            query.append(URLQueryItem(name: "end_date", value: end.description))
        }
        return try await get(.api, ["neo", "rest", "v1", "feed"], query: query)
    }

    /// One object with all its close approaches and its orbit (`/neo/rest/v1/neo/:id`).
    public func neo(id: String) async throws -> NearEarthObject {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw NASAError.invalidArgument("An asteroid id is required.") }
        return try await get(.api, ["neo", "rest", "v1", "neo", trimmed])
    }

    /// A page of the whole catalog (`/neo/rest/v1/neo/browse`). Pages are zero-based.
    public func browseNEOs(page: Int = 0, size: Int = 20) async throws -> NEOBrowsePage {
        guard page >= 0, (1...20).contains(size) else {
            throw NASAError.invalidArgument("Pages start at 0 and hold 1 to 20 objects.")
        }
        return try await get(.api, ["neo", "rest", "v1", "neo", "browse"], query: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
        ])
    }
}

// MARK: - EPIC

extension NASAClient {
    /// The images of a day, or of the latest day with images when `date` is `nil`.
    ///
    /// With ``EPICSource/direct`` (the default) the request goes to epic.gsfc.nasa.gov without a
    /// key; with ``EPICSource/apiGateway`` to api.nasa.gov/EPIC with the client's key.
    public func epicImages(
        _ collection: EPICCollection = .natural,
        date: CalendarDate? = nil,
        source: EPICSource = .direct
    ) async throws -> [EPICImage] {
        var segments = Self.epicAPIPath(collection, source)
        if let date {
            segments += ["date", date.description]
        }
        var images: [EPICImage] = try await get(source == .direct ? .epic : .api, segments)
        for index in images.indices {
            images[index].collection = collection
        }
        return images.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// Every day that has images in a collection, oldest first (`/api/:collection/available`).
    public func epicAvailableDates(_ collection: EPICCollection = .natural, source: EPICSource = .direct) async throws -> [CalendarDate] {
        let strings: [String] = try await get(source == .direct ? .epic : .api, Self.epicAPIPath(collection, source) + ["available"])
        return strings.compactMap { CalendarDate(String($0.prefix(10))) }.sorted()
    }

    /// The URL of an image file. From ``EPICSource/direct`` it is the keyless archive; from
    /// ``EPICSource/apiGateway`` it is api.nasa.gov/EPIC/archive with the client's key.
    public func epicImageURL(for image: EPICImage, format: EPICImageFormat = .png, source: EPICSource = .direct) -> URL? {
        switch source {
        case .direct:
            return EPICImage.archiveURL(
                image: image.image,
                day: image.day,
                collection: image.collection,
                format: format,
                baseURL: configuration.epicBaseURL
            )
        case .apiGateway:
            guard let url = EPICImage.archiveURL(
                image: image.image,
                day: image.day,
                collection: image.collection,
                format: format,
                baseURL: configuration.apiBaseURL.appendingPathComponent("EPIC")
            ), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            components.queryItems = [URLQueryItem(name: "api_key", value: configuration.apiKey)]
            return components.url
        }
    }

    private static func epicAPIPath(_ collection: EPICCollection, _ source: EPICSource) -> [String] {
        switch source {
        case .direct: return ["api", collection.rawValue]
        case .apiGateway: return ["EPIC", "api", collection.rawValue]
        }
    }
}

// MARK: - NASA Image and Video Library

extension NASAClient {
    /// Searches the NASA Image and Video Library (`images-api.nasa.gov/search`). No key needed.
    public func searchMedia(_ query: NASAMediaQuery) async throws -> NASAMediaSearchResult {
        guard query.hasSearchTerm else {
            throw NASAError.invalidArgument("A library search needs a search term or a filter such as a keyword or NASA id.")
        }
        if let page = query.page, page < 1 {
            throw NASAError.invalidArgument("Pages start at 1.")
        }
        if let size = query.pageSize, size < 1 {
            throw NASAError.invalidArgument("A page holds at least one item.")
        }
        return try await get(.images, ["search"], query: query.queryItems)
    }

    /// Searches the library for `text`, images only by default.
    public func searchMedia(
        _ text: String,
        mediaType: NASAMediaType? = .image,
        page: Int? = nil,
        pageSize: Int? = nil
    ) async throws -> NASAMediaSearchResult {
        try await searchMedia(NASAMediaQuery(
            text,
            mediaTypes: mediaType.map { [$0] } ?? [],
            page: page,
            pageSize: pageSize
        ))
    }

    /// Every file of an item: each image size or video encoding, and its metadata
    /// (`/asset/:nasa_id`).
    public func mediaAsset(nasaID: String) async throws -> NASAMediaAsset {
        try await get(.images, ["asset", try Self.nonEmpty(nasaID)])
    }

    /// Where an item's full metadata file lives (`/metadata/:nasa_id`).
    public func mediaMetadataLocation(nasaID: String) async throws -> URL {
        let location: NASAMediaLocation = try await get(.images, ["metadata", try Self.nonEmpty(nasaID)])
        guard let url = NASAURL.parse(location.location) else { throw NASAError.invalidResponse }
        return url
    }

    /// Where a video's captions file lives (`/captions/:nasa_id`).
    public func mediaCaptionsLocation(nasaID: String) async throws -> URL {
        let location: NASAMediaLocation = try await get(.images, ["captions", try Self.nonEmpty(nasaID)])
        guard let url = NASAURL.parse(location.location) else { throw NASAError.invalidResponse }
        return url
    }

    /// The items of an album, such as `"Apollo"` (`/album/:name`).
    public func mediaAlbum(_ name: String, page: Int? = nil) async throws -> NASAMediaSearchResult {
        var query: [URLQueryItem] = []
        if let page {
            guard page >= 1 else { throw NASAError.invalidArgument("Pages start at 1.") }
            query.append(URLQueryItem(name: "page", value: String(page)))
        }
        return try await get(.images, ["album", try Self.nonEmpty(name)], query: query)
    }

    private static func nonEmpty(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NASAError.invalidArgument("An id is required.") }
        return trimmed
    }
}
