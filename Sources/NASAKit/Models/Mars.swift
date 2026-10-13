import Foundation

/// The rovers the Mars Rover Photos API has photos of.
public enum MarsRover: String, CaseIterable, Sendable, Hashable, Codable {
    case curiosity
    case opportunity
    case spirit
    case perseverance

    /// "Curiosity".
    public var name: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// A rover camera's short name, as the API's `camera` parameter takes it (`"fhaz"`, `"navcam"`…).
public struct MarsCameraName: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public var description: String {
        rawValue
    }

    /// Front Hazard Avoidance Camera (Curiosity, Opportunity, Spirit).
    public static let fhaz: MarsCameraName = "fhaz"
    /// Rear Hazard Avoidance Camera (Curiosity, Opportunity, Spirit).
    public static let rhaz: MarsCameraName = "rhaz"
    /// Mast Camera (Curiosity).
    public static let mast: MarsCameraName = "mast"
    /// Chemistry and Camera Complex (Curiosity).
    public static let chemcam: MarsCameraName = "chemcam"
    /// Mars Hand Lens Imager (Curiosity).
    public static let mahli: MarsCameraName = "mahli"
    /// Mars Descent Imager (Curiosity).
    public static let mardi: MarsCameraName = "mardi"
    /// Navigation Camera (Curiosity, Opportunity, Spirit).
    public static let navcam: MarsCameraName = "navcam"
    /// Panoramic Camera (Opportunity, Spirit).
    public static let pancam: MarsCameraName = "pancam"
    /// Miniature Thermal Emission Spectrometer (Opportunity, Spirit).
    public static let minites: MarsCameraName = "minites"
    /// Left Navigation Camera (Perseverance).
    public static let navcamLeft: MarsCameraName = "navcam_left"
    /// Right Navigation Camera (Perseverance).
    public static let navcamRight: MarsCameraName = "navcam_right"
    /// Mastcam-Z Left (Perseverance).
    public static let mastcamZLeft: MarsCameraName = "mcz_left"
    /// Mastcam-Z Right (Perseverance).
    public static let mastcamZRight: MarsCameraName = "mcz_right"
    /// Front Hazard Avoidance Camera, left (Perseverance).
    public static let frontHazcamLeft: MarsCameraName = "front_hazcam_left_a"
    /// SkyCam (Perseverance).
    public static let skycam: MarsCameraName = "skycam"
    /// SHERLOC WATSON (Perseverance).
    public static let sherlocWatson: MarsCameraName = "sherloc_watson"
    /// SuperCam Remote Micro Imager (Perseverance).
    public static let supercamRMI: MarsCameraName = "supercam_rmi"
}

/// A rover camera as the API describes it.
public struct MarsCamera: Decodable, Hashable, Sendable {
    public let id: Int?
    /// `"FHAZ"`.
    public let name: String
    public let roverID: Int?
    /// `"Front Hazard Avoidance Camera"`.
    public let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case roverID = "rover_id"
        case fullName = "full_name"
    }

    /// The short name as the `camera` parameter takes it.
    public var parameter: MarsCameraName {
        MarsCameraName(rawValue: name)
    }
}

/// A rover and its mission, from `/rovers` or embedded in a photo.
public struct MarsRoverInfo: Decodable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// `"Curiosity"`.
    public let name: String
    public let landingDate: CalendarDate?
    public let launchDate: CalendarDate?
    /// `"active"` or `"complete"`.
    public let status: String
    public let maxSol: Int?
    public let maxDate: CalendarDate?
    public let totalPhotos: Int?
    public let cameras: [MarsCamera]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case landingDate = "landing_date"
        case launchDate = "launch_date"
        case status
        case maxSol = "max_sol"
        case maxDate = "max_date"
        case totalPhotos = "total_photos"
        case cameras
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        landingDate = try container.decodeIfPresent(CalendarDate.self, forKey: .landingDate)
        launchDate = try container.decodeIfPresent(CalendarDate.self, forKey: .launchDate)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        maxSol = try container.decodeIfPresent(Int.self, forKey: .maxSol)
        maxDate = try container.decodeIfPresent(CalendarDate.self, forKey: .maxDate)
        totalPhotos = try container.decodeIfPresent(Int.self, forKey: .totalPhotos)
        cameras = try container.decodeIfPresent([MarsCamera].self, forKey: .cameras) ?? []
    }

    /// The rover as a ``MarsRover`` value, when it is one of the four.
    public var rover: MarsRover? {
        MarsRover(rawValue: name.lowercased())
    }

    public var isActive: Bool {
        status.lowercased() == "active"
    }
}

/// A raw image taken by a rover.
public struct MarsPhoto: Decodable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// The Martian day of the mission, counted from landing.
    public let sol: Int
    public let camera: MarsCamera
    /// The image. The API sends `http://` links; NASA hosts are upgraded to HTTPS.
    public let imageURL: URL?
    public let earthDate: CalendarDate
    public let rover: MarsRoverInfo

    enum CodingKeys: String, CodingKey {
        case id
        case sol
        case camera
        case imageURL = "img_src"
        case earthDate = "earth_date"
        case rover
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        sol = try container.decode(Int.self, forKey: .sol)
        camera = try container.decode(MarsCamera.self, forKey: .camera)
        imageURL = try container.decodeLenientURL(forKey: .imageURL)
        earthDate = try container.decode(CalendarDate.self, forKey: .earthDate)
        rover = try container.decode(MarsRoverInfo.self, forKey: .rover)
    }
}

/// A rover's mission manifest (`/manifests/:rover`): which sols have photos, from which cameras.
public struct MarsMissionManifest: Decodable, Hashable, Sendable {
    public let name: String
    public let landingDate: CalendarDate?
    public let launchDate: CalendarDate?
    public let status: String
    public let maxSol: Int
    public let maxDate: CalendarDate?
    public let totalPhotos: Int
    public let sols: [Sol]

    /// The photos of one sol.
    public struct Sol: Decodable, Hashable, Sendable, Identifiable {
        public let sol: Int
        public let earthDate: CalendarDate?
        public let totalPhotos: Int
        /// Short camera names, such as `"FHAZ"`.
        public let cameras: [String]

        public var id: Int { sol }

        enum CodingKeys: String, CodingKey {
            case sol
            case earthDate = "earth_date"
            case totalPhotos = "total_photos"
            case cameras
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case landingDate = "landing_date"
        case launchDate = "launch_date"
        case status
        case maxSol = "max_sol"
        case maxDate = "max_date"
        case totalPhotos = "total_photos"
        case sols = "photos"
    }
}

/// `{"photos": [...]}`.
struct MarsPhotosResponse: Decodable {
    let photos: [MarsPhoto]
}

/// `{"latest_photos": [...]}`.
struct MarsLatestPhotosResponse: Decodable {
    let latestPhotos: [MarsPhoto]

    enum CodingKeys: String, CodingKey {
        case latestPhotos = "latest_photos"
    }
}

/// `{"photo_manifest": {...}}`.
struct MarsManifestResponse: Decodable {
    let manifest: MarsMissionManifest

    enum CodingKeys: String, CodingKey {
        case manifest = "photo_manifest"
    }
}

/// `{"rovers": [...]}`.
struct MarsRoversResponse: Decodable {
    let rovers: [MarsRoverInfo]
}
