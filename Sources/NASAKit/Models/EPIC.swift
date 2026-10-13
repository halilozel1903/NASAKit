import Foundation

/// The image collections of EPIC, the Earth Polychromatic Imaging Camera on NOAA's DSCOVR
/// spacecraft, a million miles from Earth.
public enum EPICCollection: String, CaseIterable, Sendable, Hashable, Codable {
    /// Color images as the camera saw them.
    case natural
    /// Color-corrected images that bring out land features.
    case enhanced
    /// Aerosol index maps.
    case aerosol
    /// Cloud fraction maps.
    case cloud
}

/// The files the EPIC archive keeps of each image.
public enum EPICImageFormat: String, CaseIterable, Sendable, Hashable {
    /// 2048 × 2048 PNG, several megabytes.
    case png
    /// 2048 × 2048 JPEG, much smaller.
    case jpg
    /// A small JPEG thumbnail.
    case thumbnail

    /// The archive folder: `png`, `jpg` or `thumbs`.
    var folder: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        case .thumbnail: return "thumbs"
        }
    }

    /// The file extension.
    var fileExtension: String {
        self == .png ? "png" : "jpg"
    }
}

/// Where EPIC requests go.
public enum EPICSource: Sendable, Hashable {
    /// epic.gsfc.nasa.gov: no API key, no rate limit headers.
    case direct
    /// api.nasa.gov/EPIC: uses the client's API key and counts against its rate limit.
    case apiGateway
}

/// A position relative to Earth's center in the J2000 frame, in kilometers.
public struct EPICVector: Decodable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// The distance from Earth's center in kilometers.
    public var length: Double {
        (x * x + y * y + z * z).squareRoot()
    }
}

/// A latitude and longitude in degrees.
public struct EPICCoordinates: Decodable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
    }

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// The spacecraft's attitude quaternion.
public struct EPICQuaternion: Decodable, Hashable, Sendable {
    public let q0: Double
    public let q1: Double
    public let q2: Double
    public let q3: Double
}

/// One EPIC image of the whole sunlit side of Earth.
public struct EPICImage: Decodable, Hashable, Sendable, Identifiable {
    /// `"20190530011359"`.
    public let identifier: String
    /// The file name without extension, such as `"epic_1b_20190530011359"`.
    public let image: String
    public let caption: String?
    /// The processing version, such as `"03"`.
    public let version: String?
    /// When the image was taken, as sent: `"2019-05-30 00:13:59"` (UTC).
    public let dateString: String
    /// When the image was taken.
    public let date: Date?
    /// The point on Earth at the center of the image.
    public let centroid: EPICCoordinates?
    public let dscovrPosition: EPICVector?
    public let lunarPosition: EPICVector?
    public let sunPosition: EPICVector?
    public let attitude: EPICQuaternion?
    /// The collection the image was loaded from; the archive URL depends on it.
    public internal(set) var collection: EPICCollection

    public var id: String { collection.rawValue + "/" + image }

    enum CodingKeys: String, CodingKey {
        case identifier
        case image
        case caption
        case version
        case date
        case centroid = "centroid_coordinates"
        case dscovrPosition = "dscovr_j2000_position"
        case lunarPosition = "lunar_j2000_position"
        case sunPosition = "sun_j2000_position"
        case attitude = "attitude_quaternions"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        image = try container.decode(String.self, forKey: .image)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier) ?? image
        caption = try container.decodeTrimmedString(forKey: .caption)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        dateString = try container.decode(String.self, forKey: .date)
        date = Timestamp.parseSpaced(dateString)
        centroid = try container.decodeIfPresent(EPICCoordinates.self, forKey: .centroid)
        dscovrPosition = try container.decodeIfPresent(EPICVector.self, forKey: .dscovrPosition)
        lunarPosition = try container.decodeIfPresent(EPICVector.self, forKey: .lunarPosition)
        sunPosition = try container.decodeIfPresent(EPICVector.self, forKey: .sunPosition)
        attitude = try container.decodeIfPresent(EPICQuaternion.self, forKey: .attitude)
        collection = .natural
    }

    /// The UTC day the image was taken, which is also its archive folder.
    public var day: CalendarDate? {
        CalendarDate(String(dateString.prefix(10)))
    }

    /// DSCOVR's distance from Earth's center in kilometers.
    public var spacecraftDistance: Double? {
        dscovrPosition?.length
    }

    /// The image file in the keyless archive at epic.gsfc.nasa.gov:
    /// `https://epic.gsfc.nasa.gov/archive/natural/2019/05/30/png/epic_1b_20190530011359.png`.
    public func imageURL(_ format: EPICImageFormat = .png) -> URL? {
        EPICImage.archiveURL(
            image: image,
            day: day,
            collection: collection,
            format: format,
            baseURL: NASAConfiguration.defaultEPICBaseURL
        )
    }

    /// The archive URL of an image, on `baseURL` (the keyless archive by default). For the
    /// api.nasa.gov archive, use ``NASAClient/epicImageURL(for:format:source:)``.
    public static func archiveURL(
        image: String,
        day: CalendarDate?,
        collection: EPICCollection,
        format: EPICImageFormat,
        baseURL: URL = NASAConfiguration.defaultEPICBaseURL
    ) -> URL? {
        guard let day, !image.isEmpty else { return nil }
        let month = day.month < 10 ? "0\(day.month)" : "\(day.month)"
        let dayOfMonth = day.day < 10 ? "0\(day.day)" : "\(day.day)"
        return baseURL
            .appendingPathComponent("archive")
            .appendingPathComponent(collection.rawValue)
            .appendingPathComponent(String(day.year))
            .appendingPathComponent(month)
            .appendingPathComponent(dayOfMonth)
            .appendingPathComponent(format.folder)
            .appendingPathComponent(image + "." + format.fileExtension)
    }
}
