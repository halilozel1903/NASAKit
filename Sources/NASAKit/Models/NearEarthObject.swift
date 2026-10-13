import Foundation

/// An asteroid or comet that comes near Earth, from Asteroids NeoWs (`/neo/rest/v1`).
public struct NearEarthObject: Decodable, Hashable, Sendable, Identifiable {
    /// The SPK-ID, such as `"2465633"`; what ``NASAClient/neo(id:)`` takes.
    public let id: String
    public let neoReferenceID: String?
    /// `"465633 (2009 JR5)"`.
    public let name: String
    /// The object's page in JPL's Small-Body Database.
    public let jplURL: URL?
    /// Absolute magnitude H; smaller is bigger and brighter.
    public let absoluteMagnitude: Double?
    public let estimatedDiameter: EstimatedDiameter?
    public let isPotentiallyHazardous: Bool
    /// Close approaches: in a feed, the one of that day; from a lookup, all known ones.
    public let closeApproaches: [CloseApproach]
    /// Whether the object is on the Sentry impact-monitoring list.
    public let isSentryObject: Bool
    /// The orbit, sent by lookups and browse.
    public let orbitalData: OrbitalData?

    enum CodingKeys: String, CodingKey {
        case id
        case neoReferenceID = "neo_reference_id"
        case name
        case jplURL = "nasa_jpl_url"
        case absoluteMagnitude = "absolute_magnitude_h"
        case estimatedDiameter = "estimated_diameter"
        case isPotentiallyHazardous = "is_potentially_hazardous_asteroid"
        case closeApproaches = "close_approach_data"
        case isSentryObject = "is_sentry_object"
        case orbitalData = "orbital_data"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .id) {
            id = text
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        neoReferenceID = try container.decodeIfPresent(String.self, forKey: .neoReferenceID)
        name = try container.decode(String.self, forKey: .name)
        jplURL = try container.decodeLenientURL(forKey: .jplURL)
        absoluteMagnitude = try container.decodeFlexibleDoubleIfPresent(forKey: .absoluteMagnitude)
        estimatedDiameter = try container.decodeIfPresent(EstimatedDiameter.self, forKey: .estimatedDiameter)
        isPotentiallyHazardous = try container.decodeIfPresent(Bool.self, forKey: .isPotentiallyHazardous) ?? false
        closeApproaches = try container.decodeIfPresent([CloseApproach].self, forKey: .closeApproaches) ?? []
        isSentryObject = try container.decodeIfPresent(Bool.self, forKey: .isSentryObject) ?? false
        orbitalData = try container.decodeIfPresent(OrbitalData.self, forKey: .orbitalData)
    }

    /// The name without the number in front: `"2009 JR5"` for `"465633 (2009 JR5)"`.
    public var designation: String {
        guard let open = name.firstIndex(of: "("), let close = name.lastIndex(of: ")"), open < close else {
            return name
        }
        return String(name[name.index(after: open)..<close])
    }

    /// The closest of the listed approaches to Earth.
    public var closestApproachToEarth: CloseApproach? {
        closeApproaches
            .filter { $0.orbitingBody == "Earth" }
            .min { $0.missDistance.kilometers < $1.missDistance.kilometers }
    }

    /// The estimated diameter range in meters.
    public struct EstimatedDiameter: Decodable, Hashable, Sendable {
        public let kilometers: DiameterRange
        public let meters: DiameterRange
        public let miles: DiameterRange
        public let feet: DiameterRange
    }

    /// A smallest and largest estimate.
    public struct DiameterRange: Decodable, Hashable, Sendable {
        public let min: Double
        public let max: Double

        enum CodingKeys: String, CodingKey {
            case min = "estimated_diameter_min"
            case max = "estimated_diameter_max"
        }

        public init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            min = try container.decodeFlexibleDouble(forKey: .min)
            max = try container.decodeFlexibleDouble(forKey: .max)
        }

        /// The middle of the range.
        public var average: Double {
            (min + max) / 2
        }
    }

    /// One pass near a planet. NeoWs sends the numbers as strings; they are decoded to `Double`.
    public struct CloseApproach: Decodable, Hashable, Sendable {
        public let date: CalendarDate
        /// `"2015-Sep-08 20:28"`, when known.
        public let dateFull: String?
        /// The moment of closest approach.
        public let epoch: Date?
        public let relativeVelocity: Velocity
        public let missDistance: Distance
        /// `"Earth"`, `"Mars"`, `"Juptr"`…
        public let orbitingBody: String

        enum CodingKeys: String, CodingKey {
            case date = "close_approach_date"
            case dateFull = "close_approach_date_full"
            case epoch = "epoch_date_close_approach"
            case relativeVelocity = "relative_velocity"
            case missDistance = "miss_distance"
            case orbitingBody = "orbiting_body"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(CalendarDate.self, forKey: .date)
            dateFull = try container.decodeTrimmedString(forKey: .dateFull)
            epoch = try container.decodeFlexibleDoubleIfPresent(forKey: .epoch).map { Date(timeIntervalSince1970: $0 / 1000) }
            relativeVelocity = try container.decode(Velocity.self, forKey: .relativeVelocity)
            missDistance = try container.decode(Distance.self, forKey: .missDistance)
            orbitingBody = try container.decodeIfPresent(String.self, forKey: .orbitingBody) ?? ""
        }
    }

    /// Speed relative to the body passed.
    public struct Velocity: Decodable, Hashable, Sendable {
        public let kilometersPerSecond: Double
        public let kilometersPerHour: Double
        public let milesPerHour: Double

        enum CodingKeys: String, CodingKey {
            case kilometersPerSecond = "kilometers_per_second"
            case kilometersPerHour = "kilometers_per_hour"
            case milesPerHour = "miles_per_hour"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kilometersPerSecond = try container.decodeFlexibleDouble(forKey: .kilometersPerSecond)
            kilometersPerHour = try container.decodeFlexibleDouble(forKey: .kilometersPerHour)
            milesPerHour = try container.decodeFlexibleDouble(forKey: .milesPerHour)
        }
    }

    /// How far the object stays from the body passed.
    public struct Distance: Decodable, Hashable, Sendable {
        public let astronomical: Double
        /// In Earth–Moon distances.
        public let lunar: Double
        public let kilometers: Double
        public let miles: Double

        enum CodingKeys: String, CodingKey {
            case astronomical
            case lunar
            case kilometers
            case miles
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            astronomical = try container.decodeFlexibleDouble(forKey: .astronomical)
            lunar = try container.decodeFlexibleDouble(forKey: .lunar)
            kilometers = try container.decodeFlexibleDouble(forKey: .kilometers)
            miles = try container.decodeFlexibleDouble(forKey: .miles)
        }
    }

    /// A summary of the object's orbit. NeoWs sends many more fields; these are the common ones.
    public struct OrbitalData: Decodable, Hashable, Sendable {
        public let orbitID: String?
        public let orbitDeterminationDate: String?
        public let firstObservationDate: CalendarDate?
        public let lastObservationDate: CalendarDate?
        public let orbitalPeriodDays: Double?
        public let eccentricity: Double?
        public let semiMajorAxisAU: Double?
        public let inclinationDegrees: Double?
        public let perihelionDistanceAU: Double?
        public let aphelionDistanceAU: Double?
        public let orbitClass: OrbitClass?

        public struct OrbitClass: Decodable, Hashable, Sendable {
            /// `"APO"`, `"ATE"`, `"AMO"`…
            public let type: String
            public let description: String?
            public let range: String?

            enum CodingKeys: String, CodingKey {
                case type = "orbit_class_type"
                case description = "orbit_class_description"
                case range = "orbit_class_range"
            }
        }

        enum CodingKeys: String, CodingKey {
            case orbitID = "orbit_id"
            case orbitDeterminationDate = "orbit_determination_date"
            case firstObservationDate = "first_observation_date"
            case lastObservationDate = "last_observation_date"
            case orbitalPeriodDays = "orbital_period"
            case eccentricity
            case semiMajorAxisAU = "semi_major_axis"
            case inclinationDegrees = "inclination"
            case perihelionDistanceAU = "perihelion_distance"
            case aphelionDistanceAU = "aphelion_distance"
            case orbitClass = "orbit_class"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            orbitID = try container.decodeTrimmedString(forKey: .orbitID)
            orbitDeterminationDate = try container.decodeTrimmedString(forKey: .orbitDeterminationDate)
            firstObservationDate = try container.decodeTrimmedString(forKey: .firstObservationDate).flatMap { CalendarDate($0) }
            lastObservationDate = try container.decodeTrimmedString(forKey: .lastObservationDate).flatMap { CalendarDate($0) }
            orbitalPeriodDays = try container.decodeFlexibleDoubleIfPresent(forKey: .orbitalPeriodDays)
            eccentricity = try container.decodeFlexibleDoubleIfPresent(forKey: .eccentricity)
            semiMajorAxisAU = try container.decodeFlexibleDoubleIfPresent(forKey: .semiMajorAxisAU)
            inclinationDegrees = try container.decodeFlexibleDoubleIfPresent(forKey: .inclinationDegrees)
            perihelionDistanceAU = try container.decodeFlexibleDoubleIfPresent(forKey: .perihelionDistanceAU)
            aphelionDistanceAU = try container.decodeFlexibleDoubleIfPresent(forKey: .aphelionDistanceAU)
            orbitClass = try container.decodeIfPresent(OrbitClass.self, forKey: .orbitClass)
        }
    }
}

/// Links NeoWs sends for paging.
public struct NEOLinks: Decodable, Hashable, Sendable {
    public let next: URL?
    public let previous: URL?
    public let current: URL?

    enum CodingKeys: String, CodingKey {
        case next
        case previous = "prev"
        case current = "self"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        next = try container.decodeLenientURL(forKey: .next)
        previous = try container.decodeLenientURL(forKey: .previous)
        current = try container.decodeLenientURL(forKey: .current)
    }
}

/// The objects passing Earth over up to seven days (`/neo/rest/v1/feed`).
public struct NEOFeed: Decodable, Hashable, Sendable {
    public let elementCount: Int
    /// The objects of each day, keyed by the day of their close approach.
    public let objectsByDay: [CalendarDate: [NearEarthObject]]
    public let links: NEOLinks?

    enum CodingKeys: String, CodingKey {
        case elementCount = "element_count"
        case objectsByDay = "near_earth_objects"
        case links
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elementCount = try container.decodeIfPresent(Int.self, forKey: .elementCount) ?? 0
        links = try container.decodeIfPresent(NEOLinks.self, forKey: .links)
        let raw = try container.decode([String: [NearEarthObject]].self, forKey: .objectsByDay)
        var byDay: [CalendarDate: [NearEarthObject]] = [:]
        for (key, objects) in raw {
            guard let day = CalendarDate(key) else {
                throw DecodingError.dataCorruptedError(forKey: .objectsByDay, in: container, debugDescription: "Unexpected day \"\(key)\"")
            }
            byDay[day] = objects
        }
        objectsByDay = byDay
    }

    /// The days in the feed, in order.
    public var days: [CalendarDate] {
        objectsByDay.keys.sorted()
    }

    /// Every object, day by day, each day's objects in order of their closest approach.
    public var allObjects: [NearEarthObject] {
        days.flatMap { day in
            (objectsByDay[day] ?? []).sorted { lhs, rhs in
                (lhs.closeApproaches.first?.epoch ?? .distantFuture) < (rhs.closeApproaches.first?.epoch ?? .distantFuture)
            }
        }
    }

    /// The objects flagged potentially hazardous.
    public var hazardousObjects: [NearEarthObject] {
        allObjects.filter(\.isPotentiallyHazardous)
    }
}

/// A page of the whole NEO catalog (`/neo/rest/v1/neo/browse`).
public struct NEOBrowsePage: Decodable, Hashable, Sendable {
    public let objects: [NearEarthObject]
    public let page: Page
    public let links: NEOLinks?

    public struct Page: Decodable, Hashable, Sendable {
        public let size: Int
        public let totalElements: Int
        public let totalPages: Int
        /// Zero-based.
        public let number: Int

        enum CodingKeys: String, CodingKey {
            case size
            case totalElements = "total_elements"
            case totalPages = "total_pages"
            case number
        }
    }

    enum CodingKeys: String, CodingKey {
        case objects = "near_earth_objects"
        case page
        case links
    }

    /// Whether there is a page after this one.
    public var hasNextPage: Bool {
        page.number + 1 < page.totalPages
    }
}
