import Foundation

/// What an Astronomy Picture of the Day entry shows.
public enum APODMediaType: Hashable, Sendable, Codable, CustomStringConvertible {
    /// A picture: `url` is the image, `hdurl` its full resolution version.
    case image
    /// A video: `url` is an embeddable player (YouTube, Vimeo) or a video file, and the
    /// `thumbnail_url` (when asked for with `thumbs=true`) a still of it.
    case video
    /// Anything else, such as an interactive page; there may be no `url` at all.
    case other(String)

    public init(rawValue: String) {
        switch rawValue.lowercased() {
        case "image": self = .image
        case "video": self = .video
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .image: return "image"
        case .video: return "video"
        case let .other(value): return value
        }
    }

    public var description: String {
        rawValue
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One Astronomy Picture of the Day (`/planetary/apod`).
public struct APODEntry: Decodable, Hashable, Sendable, Identifiable {
    /// The first day APOD published: June 16, 1995.
    public static let firstDate = CalendarDate(year: 1995, month: 6, day: 16)

    /// The day it was the picture of the day (US Eastern time).
    public let date: CalendarDate
    public let title: String
    /// The astronomer's explanation.
    public let explanation: String
    public let mediaType: APODMediaType
    /// The image, the video's player or file, or `nil` for some `other` entries.
    public let url: URL?
    /// The full resolution image, for images.
    public let hdURL: URL?
    /// A still of a video, sent when the request asked for thumbnails.
    public let thumbnailURL: URL?
    /// The copyright holder, trimmed of the line breaks the API adds; `nil` when the entry has no
    /// copyright line.
    public let copyright: String?
    /// The API version that answered, such as `"v1"`.
    public let serviceVersion: String?

    public var id: CalendarDate { date }

    public init(
        date: CalendarDate,
        title: String,
        explanation: String,
        mediaType: APODMediaType,
        url: URL?,
        hdURL: URL? = nil,
        thumbnailURL: URL? = nil,
        copyright: String? = nil,
        serviceVersion: String? = nil
    ) {
        self.date = date
        self.title = title
        self.explanation = explanation
        self.mediaType = mediaType
        self.url = url
        self.hdURL = hdURL
        self.thumbnailURL = thumbnailURL
        self.copyright = copyright
        self.serviceVersion = serviceVersion
    }

    enum CodingKeys: String, CodingKey {
        case date
        case title
        case explanation
        case mediaType = "media_type"
        case url
        case hdURL = "hdurl"
        case thumbnailURL = "thumbnail_url"
        case copyright
        case serviceVersion = "service_version"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(CalendarDate.self, forKey: .date)
        title = try container.decodeTrimmedString(forKey: .title) ?? ""
        explanation = try container.decodeTrimmedString(forKey: .explanation) ?? ""
        mediaType = try container.decodeIfPresent(APODMediaType.self, forKey: .mediaType) ?? .other("")
        url = try container.decodeLenientURL(forKey: .url)
        hdURL = try container.decodeLenientURL(forKey: .hdURL)
        thumbnailURL = try container.decodeLenientURL(forKey: .thumbnailURL)
        copyright = try container.decodeTrimmedString(forKey: .copyright).map { raw in
            raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        serviceVersion = try container.decodeIfPresent(String.self, forKey: .serviceVersion)
    }

    public var isImage: Bool { mediaType == .image }
    public var isVideo: Bool { mediaType == .video }

    /// The picture to show for this entry: the image for images, the thumbnail for videos, else
    /// `nil`. For a sharper image, use ``hdURL`` where the screen is large.
    public var displayImageURL: URL? {
        switch mediaType {
        case .image:
            return url ?? hdURL
        case .video:
            return thumbnailURL
        case .other:
            return thumbnailURL
        }
    }

    /// The largest image available: `hdurl` for images, else ``displayImageURL``.
    public var bestImageURL: URL? {
        isImage ? (hdURL ?? url) : displayImageURL
    }

    /// The video's address, for videos.
    public var videoURL: URL? {
        isVideo ? url : nil
    }

    /// The YouTube video id of a YouTube embed (`https://www.youtube.com/embed/<id>?rel=0`).
    public var youTubeID: String? {
        guard isVideo, let url, let host = url.host?.lowercased(), host.contains("youtube.com") || host == "youtu.be" else {
            return nil
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "youtu.be" { return parts.first }
        if let index = parts.firstIndex(of: "embed"), parts.indices.contains(index + 1) {
            return parts[index + 1]
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
    }

    /// The entry's page on apod.nasa.gov, such as `https://apod.nasa.gov/apod/ap261008.html`.
    public var pageURL: URL? {
        let yy = date.year % 100
        let digits = [yy, date.month, date.day].map { $0 < 10 ? "0\($0)" : "\($0)" }.joined()
        return URL(string: "https://apod.nasa.gov/apod/ap" + digits + ".html")
    }
}
