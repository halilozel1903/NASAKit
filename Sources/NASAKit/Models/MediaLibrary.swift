import Foundation

/// The kind of a NASA Image and Video Library item.
public struct NASAMediaType: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String {
        rawValue
    }

    public static let image: NASAMediaType = "image"
    public static let video: NASAMediaType = "video"
    public static let audio: NASAMediaType = "audio"
}

/// What to search the NASA Image and Video Library for (`/search`). At least one field must be
/// set.
public struct NASAMediaQuery: Sendable, Hashable {
    /// Free text, matched against titles, descriptions and keywords (`q`).
    public var text: String?
    /// Only these kinds of media; empty for all (`media_type`).
    public var mediaTypes: [NASAMediaType]
    /// Only items created from this year on (`year_start`).
    public var yearStart: Int?
    /// Only items created up to this year (`year_end`).
    public var yearEnd: Int?
    /// The NASA center that made the item, such as `"JSC"` or `"GSFC"` (`center`).
    public var center: String?
    /// Every keyword must match (`keywords`, comma separated).
    public var keywords: [String]
    public var title: String?
    public var description: String?
    public var photographer: String?
    public var location: String?
    public var secondaryCreator: String?
    public var nasaID: String?
    /// The 1-based page (`page`).
    public var page: Int?
    /// Items per page, 100 by default (`page_size`).
    public var pageSize: Int?

    public init(
        _ text: String? = nil,
        mediaTypes: [NASAMediaType] = [],
        yearStart: Int? = nil,
        yearEnd: Int? = nil,
        center: String? = nil,
        keywords: [String] = [],
        title: String? = nil,
        description: String? = nil,
        photographer: String? = nil,
        location: String? = nil,
        secondaryCreator: String? = nil,
        nasaID: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil
    ) {
        self.text = text
        self.mediaTypes = mediaTypes
        self.yearStart = yearStart
        self.yearEnd = yearEnd
        self.center = center
        self.keywords = keywords
        self.title = title
        self.description = description
        self.photographer = photographer
        self.location = location
        self.secondaryCreator = secondaryCreator
        self.nasaID = nasaID
        self.page = page
        self.pageSize = pageSize
    }

    /// The query string items, in a stable order. Empty fields are left out.
    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }
        add("q", text)
        add("media_type", mediaTypes.map(\.rawValue).joined(separator: ","))
        add("year_start", yearStart.map(String.init))
        add("year_end", yearEnd.map(String.init))
        add("center", center)
        add("keywords", keywords.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ","))
        add("title", title)
        add("description", description)
        add("photographer", photographer)
        add("location", location)
        add("secondary_creator", secondaryCreator)
        add("nasa_id", nasaID)
        add("page", page.map(String.init))
        add("page_size", pageSize.map(String.init))
        return items
    }

    /// Whether the query has a search term or filter besides paging and media types; the API
    /// rejects queries that don't.
    public var hasSearchTerm: Bool {
        let pagingNames: Set<String> = ["page", "page_size", "media_type", "year_start", "year_end"]
        return queryItems.contains { !pagingNames.contains($0.name) }
    }
}

/// The descriptive data of a library item.
public struct NASAMediaMetadata: Decodable, Hashable, Sendable {
    /// The library's id, such as `"as11-40-5874"`.
    public let nasaID: String
    public let title: String
    public let mediaType: NASAMediaType
    /// The NASA center, such as `"JSC"`.
    public let center: String?
    /// When the item was created, as sent: `"1969-07-20T00:00:00Z"`.
    public let dateCreatedString: String?
    public let dateCreated: Date?
    /// The description; may contain a little HTML, see ``plainDescription``.
    public let description: String?
    /// The accessibility description, when there is one.
    public let description508: String?
    public let keywords: [String]
    public let photographer: String?
    public let secondaryCreator: String?
    public let location: String?
    public let album: [String]

    enum CodingKeys: String, CodingKey {
        case nasaID = "nasa_id"
        case title
        case mediaType = "media_type"
        case center
        case dateCreated = "date_created"
        case description
        case description508 = "description_508"
        case keywords
        case photographer
        case secondaryCreator = "secondary_creator"
        case location
        case album
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nasaID = try container.decode(String.self, forKey: .nasaID)
        title = try container.decodeTrimmedString(forKey: .title) ?? nasaID
        mediaType = try container.decodeIfPresent(NASAMediaType.self, forKey: .mediaType) ?? .image
        center = try container.decodeTrimmedString(forKey: .center)
        dateCreatedString = try container.decodeTrimmedString(forKey: .dateCreated)
        dateCreated = dateCreatedString.flatMap { Timestamp.parseISO8601($0) }
        description = try container.decodeTrimmedString(forKey: .description)
        description508 = try container.decodeTrimmedString(forKey: .description508)
        keywords = Self.decodeList(container, .keywords)
        photographer = try container.decodeTrimmedString(forKey: .photographer)
        secondaryCreator = try container.decodeTrimmedString(forKey: .secondaryCreator)
        location = try container.decodeTrimmedString(forKey: .location)
        album = Self.decodeList(container, .album)
    }

    /// The description as plain text, without HTML tags or entities.
    public var plainDescription: String? {
        guard let description else { return nil }
        let text = PlainText.from(html: description)
        return text.isEmpty ? nil : text
    }

    /// Keywords come as an array of strings, sometimes as one comma-separated string.
    private static func decodeList(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        let raw: [String]
        if let list = try? container.decodeIfPresent([String].self, forKey: key) {
            raw = list
        } else if let single = try? container.decodeIfPresent(String.self, forKey: key) {
            raw = single.split(separator: ",").map(String.init)
        } else {
            raw = []
        }
        // A list of one string may hold several comma-separated keywords too.
        return raw
            .flatMap { $0.split(separator: ",").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// A link of a library item, usually its preview image.
public struct NASAMediaLink: Decodable, Hashable, Sendable {
    public let href: URL
    /// `"preview"`, `"captions"`, `"alternate"`…
    public let rel: String?
    /// `"image"` for images.
    public let render: String?
    public let width: Int?
    public let height: Int?
    /// The file size in bytes.
    public let size: Int?

    enum CodingKeys: String, CodingKey {
        case href
        case rel
        case render
        case width
        case height
        case size
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let url = try container.decodeLenientURL(forKey: .href) else {
            throw DecodingError.dataCorruptedError(forKey: .href, in: container, debugDescription: "Expected a URL")
        }
        href = url
        rel = try container.decodeIfPresent(String.self, forKey: .rel)
        render = try container.decodeIfPresent(String.self, forKey: .render)
        width = try? container.decodeIfPresent(Int.self, forKey: .width)
        height = try? container.decodeIfPresent(Int.self, forKey: .height)
        size = try? container.decodeIfPresent(Int.self, forKey: .size)
    }
}

/// One search result of the NASA Image and Video Library.
public struct NASAMediaItem: Decodable, Hashable, Sendable, Identifiable {
    /// The item's `collection.json`, listing every file of the item.
    public let collectionURL: URL?
    public let metadata: NASAMediaMetadata
    public let links: [NASAMediaLink]

    enum CodingKeys: String, CodingKey {
        case collectionURL = "href"
        case data
        case links
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collectionURL = try container.decodeLenientURL(forKey: .collectionURL)
        let data = try container.decode([NASAMediaMetadata].self, forKey: .data)
        guard let first = data.first else {
            throw DecodingError.dataCorruptedError(forKey: .data, in: container, debugDescription: "An item without data")
        }
        metadata = first
        // Links are optional (audio items have none); skip any a link can't be read from.
        links = (try? container.decodeIfPresent([LossyLink].self, forKey: .links))?.compactMap(\.link) ?? []
    }

    public var id: String { metadata.nasaID }
    public var nasaID: String { metadata.nasaID }
    public var title: String { metadata.title }
    public var mediaType: NASAMediaType { metadata.mediaType }

    /// The preview image: for images a small JPEG (`~thumb.jpg`), for videos a still.
    public var previewURL: URL? {
        links.first { $0.rel == "preview" && ($0.render == nil || $0.render == "image") }?.href
            ?? links.first { $0.render == "image" }?.href
    }

    /// The preview link, with its width and height when the API sent them.
    public var previewLink: NASAMediaLink? {
        links.first { $0.rel == "preview" }
    }

    /// Whether the preview is wider than tall; `nil` when the API sent no size.
    public var isLandscape: Bool? {
        guard let link = previewLink, let width = link.width, let height = link.height, height > 0 else { return nil }
        return width > height
    }

    /// The item's page on images.nasa.gov.
    public var pageURL: URL? {
        let id = nasaID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nasaID
        return URL(string: "https://images.nasa.gov/details/" + id)
    }

    private struct LossyLink: Decodable {
        let link: NASAMediaLink?

        init(from decoder: any Decoder) throws {
            link = try? NASAMediaLink(from: decoder)
        }
    }
}

/// A page of search results.
public struct NASAMediaSearchResult: Decodable, Hashable, Sendable {
    public let items: [NASAMediaItem]
    /// How many items match in total.
    public let totalHits: Int?
    /// The next page, when there is one.
    public let nextPageURL: URL?
    /// The previous page, when there is one.
    public let previousPageURL: URL?

    enum RootKeys: String, CodingKey {
        case collection
    }

    enum CollectionKeys: String, CodingKey {
        case items
        case metadata
        case links
    }

    struct Metadata: Decodable {
        let totalHits: Int?

        enum CodingKeys: String, CodingKey {
            case totalHits = "total_hits"
        }
    }

    struct PageLink: Decodable {
        let rel: String?
        let href: String?
    }

    public init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let collection = try root.nestedContainer(keyedBy: CollectionKeys.self, forKey: .collection)
        items = try collection.decodeIfPresent([NASAMediaItem].self, forKey: .items) ?? []
        totalHits = try collection.decodeIfPresent(Metadata.self, forKey: .metadata)?.totalHits
        let pages = (try? collection.decodeIfPresent([PageLink].self, forKey: .links)) ?? []
        nextPageURL = NASAURL.parse(pages.first { $0.rel == "next" }?.href)
        previousPageURL = NASAURL.parse(pages.first { $0.rel == "prev" }?.href)
    }

    /// Only the items of a kind, for example images with a preview to show.
    public func items(of type: NASAMediaType) -> [NASAMediaItem] {
        items.filter { $0.mediaType == type }
    }
}

/// The files of a library item (`/asset/:nasa_id`): every size of an image, every encoding of a
/// video, and its metadata file.
public struct NASAMediaAsset: Decodable, Hashable, Sendable {
    /// Every file, as listed.
    public let files: [URL]

    /// The sizes the library keeps of images and videos, named by their file suffix (`~large.jpg`).
    public enum Rendition: String, CaseIterable, Sendable {
        case original = "orig"
        case large
        case medium
        case small
        case thumbnail = "thumb"
        /// Videos only.
        case mobile
        /// Videos only.
        case preview
    }

    enum RootKeys: String, CodingKey {
        case collection
    }

    enum CollectionKeys: String, CodingKey {
        case items
    }

    struct File: Decodable {
        let href: String
    }

    public init(files: [URL]) {
        self.files = files
    }

    public init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let collection = try root.nestedContainer(keyedBy: CollectionKeys.self, forKey: .collection)
        let items = try collection.decodeIfPresent([File].self, forKey: .items) ?? []
        files = items.compactMap { NASAURL.parse($0.href) }
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "wav"]

    /// The image file of a size (JPEG, PNG or GIF; TIFF originals are left out).
    public func image(_ rendition: Rendition) -> URL? {
        file(rendition, extensions: Self.imageExtensions)
    }

    /// The first image size that exists, in the order given. The default order prefers sizes
    /// that look sharp on a TV but skips originals, which can be tens of megabytes.
    public func bestImage(preferring order: [Rendition] = [.large, .medium, .small, .thumbnail]) -> URL? {
        for rendition in order {
            if let url = image(rendition) { return url }
        }
        return nil
    }

    /// The video file of a size.
    public func video(_ rendition: Rendition) -> URL? {
        file(rendition, extensions: Self.videoExtensions)
    }

    /// The first video size that exists, in the order given.
    public func bestVideo(preferring order: [Rendition] = [.medium, .large, .mobile, .small, .original, .preview]) -> URL? {
        for rendition in order {
            if let url = video(rendition) { return url }
        }
        return files.first { Self.videoExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// The audio file, for audio items.
    public var audio: URL? {
        files.first { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// The item's `metadata.json`.
    public var metadataURL: URL? {
        files.first { $0.lastPathComponent.lowercased() == "metadata.json" }
    }

    /// Captions of a video (`.srt` or `.vtt`).
    public var captionsURL: URL? {
        files.first { ["srt", "vtt"].contains($0.pathExtension.lowercased()) }
    }

    private func file(_ rendition: Rendition, extensions: Set<String>) -> URL? {
        let marker = "~" + rendition.rawValue + "."
        return files.first { url in
            extensions.contains(url.pathExtension.lowercased()) && url.lastPathComponent.lowercased().contains(marker)
        }
    }
}

/// `{"location": "https://…"}`, the answer of `/metadata/:id` and `/captions/:id`.
struct NASAMediaLocation: Decodable {
    let location: String
}
