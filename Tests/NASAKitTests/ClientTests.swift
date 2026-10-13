import Foundation
import Testing
@testable import NASAKit

@Suite("NASAClient requests")
struct ClientTests {
    // MARK: APOD

    @Test func apodOfADay() async throws {
        let stub = StubbedClient { _ in try .json("apod-image") }
        let entry = try await stub.client.apod(date: CalendarDate(year: 2026, month: 10, day: 8))

        #expect(entry.title == "A Sample Spiral Galaxy")
        #expect(stub.lastService == "api")
        #expect(stub.lastPath == "/planetary/apod")
        #expect(stub.lastQueryValue("date") == "2026-10-08")
        #expect(stub.lastQueryValue("thumbs") == "true")
        #expect(stub.lastQueryValue("api_key") == "TEST_KEY")
    }

    @Test func apodTodayWithoutThumbnails() async throws {
        let stub = StubbedClient { _ in try .json("apod-image") }
        _ = try await stub.client.apod(thumbnails: false)

        #expect(stub.lastQueryValue("date") == nil)
        #expect(stub.lastQueryValue("thumbs") == nil)
    }

    @Test func apodRangeIsSortedOldestFirst() async throws {
        let stub = StubbedClient { _ in try .json("apod-range") }
        let start = CalendarDate(year: 2026, month: 10, day: 6)
        let end = CalendarDate(year: 2026, month: 10, day: 8)
        let entries = try await stub.client.apod(from: start, through: end)

        let dates = entries.map(\.date.description)
        let expected: [String] = ["2026-10-06", "2026-10-07", "2026-10-08"]
        #expect(dates == expected)
        #expect(stub.lastQueryValue("start_date") == "2026-10-06")
        #expect(stub.lastQueryValue("end_date") == "2026-10-08")
    }

    @Test func apodRangeToToday() async throws {
        let stub = StubbedClient { _ in try .json("apod-range") }
        _ = try await stub.client.apod(from: CalendarDate(year: 2026, month: 10, day: 6))

        #expect(stub.lastQueryValue("end_date") == nil)
    }

    @Test func randomAPOD() async throws {
        let stub = StubbedClient { _ in try .json("apod-count") }
        let entries = try await stub.client.randomAPOD(count: 2)

        #expect(entries.count == 2)
        #expect(stub.lastQueryValue("count") == "2")
    }

    @Test func apodArgumentsAreCheckedBeforeSending() async throws {
        let stub = StubbedClient { _ in try .json("apod-count") }

        await #expect(throws: NASAError.self) {
            _ = try await stub.client.randomAPOD(count: 0)
        }
        await #expect(throws: NASAError.self) {
            _ = try await stub.client.randomAPOD(count: 101)
        }
        await #expect(throws: NASAError.self) {
            _ = try await stub.client.apod(date: CalendarDate(year: 1995, month: 6, day: 15))
        }
        await #expect(throws: NASAError.self) {
            _ = try await stub.client.apod(
                from: CalendarDate(year: 2026, month: 10, day: 8),
                through: CalendarDate(year: 2026, month: 10, day: 1)
            )
        }
        #expect(stub.requests.isEmpty)
    }

    // MARK: Mars

    @Test func marsPhotosBySol() async throws {
        let stub = StubbedClient { _ in try .json("mars-photos") }
        let photos = try await stub.client.marsPhotos(rover: .curiosity, sol: 1000, camera: .fhaz, page: 1)

        #expect(photos.count == 3)
        #expect(stub.lastPath == "/mars-photos/api/v1/rovers/curiosity/photos")
        #expect(stub.lastQueryValue("sol") == "1000")
        #expect(stub.lastQueryValue("camera") == "fhaz")
        #expect(stub.lastQueryValue("page") == "1")
    }

    @Test func marsPhotosByEarthDate() async throws {
        let stub = StubbedClient { _ in try .json("mars-photos") }
        _ = try await stub.client.marsPhotos(rover: .perseverance, earthDate: CalendarDate(year: 2021, month: 3, day: 1), camera: "NAVCAM_LEFT")

        #expect(stub.lastPath == "/mars-photos/api/v1/rovers/perseverance/photos")
        #expect(stub.lastQueryValue("earth_date") == "2021-03-01")
        #expect(stub.lastQueryValue("camera") == "navcam_left")
        #expect(stub.lastQueryValue("page") == nil)
    }

    @Test func latestPhotosManifestAndRovers() async throws {
        let stub = StubbedClient { request in
            switch request.url?.path ?? "" {
            case "/mars-photos/api/v1/rovers/curiosity/latest_photos": return try .json("mars-latest")
            case "/mars-photos/api/v1/manifests/curiosity": return try .json("mars-manifest")
            case "/mars-photos/api/v1/rovers": return try .json("mars-rovers")
            default: return .status(404)
            }
        }

        let latest = try await stub.client.latestMarsPhotos(rover: .curiosity)
        #expect(latest.first?.sol == 4102)
        let manifest = try await stub.client.marsManifest(rover: .curiosity)
        #expect(manifest.sols.count == 3)
        let rovers = try await stub.client.marsRovers()
        let names = rovers.map(\.name)
        let expectedNames: [String] = ["Curiosity", "Opportunity"]
        #expect(names == expectedNames)
    }

    // MARK: NeoWs

    @Test func neoFeed() async throws {
        let stub = StubbedClient { _ in try .json("neo-feed") }
        let feed = try await stub.client.neoFeed(
            from: CalendarDate(year: 2015, month: 9, day: 7),
            through: CalendarDate(year: 2015, month: 9, day: 8)
        )

        #expect(feed.elementCount == 3)
        #expect(stub.lastPath == "/neo/rest/v1/feed")
        #expect(stub.lastQueryValue("start_date") == "2015-09-07")
        #expect(stub.lastQueryValue("end_date") == "2015-09-08")
    }

    @Test func neoFeedRejectsMoreThanSevenDays() async throws {
        let stub = StubbedClient { _ in try .json("neo-feed") }
        await #expect(throws: NASAError.self) {
            _ = try await stub.client.neoFeed(
                from: CalendarDate(year: 2015, month: 9, day: 1),
                through: CalendarDate(year: 2015, month: 9, day: 9)
            )
        }
        // Seven days after the start is the most NeoWs allows.
        _ = try await stub.client.neoFeed(
            from: CalendarDate(year: 2015, month: 9, day: 1),
            through: CalendarDate(year: 2015, month: 9, day: 8)
        )
        #expect(stub.requests.count == 1)
    }

    @Test func neoLookupAndBrowse() async throws {
        let stub = StubbedClient { request in
            switch request.url?.path ?? "" {
            case "/neo/rest/v1/neo/2000433": return try .json("neo-lookup")
            case "/neo/rest/v1/neo/browse": return try .json("neo-browse")
            default: return .status(404)
            }
        }

        let eros = try await stub.client.neo(id: "2000433")
        #expect(eros.name == "433 Eros (A898 PA)")
        let page = try await stub.client.browseNEOs(page: 0, size: 2)
        #expect(page.objects.count == 2)
        #expect(stub.lastQueryValue("size") == "2")
        #expect(stub.lastQueryValue("page") == "0")
    }

    // MARK: EPIC

    @Test func epicDirectIsKeyless() async throws {
        let stub = StubbedClient { _ in try .json("epic-natural") }
        let images = try await stub.client.epicImages(.natural)

        #expect(images.count == 3)
        #expect(stub.lastService == "epic")
        #expect(stub.lastPath == "/api/natural")
        #expect(stub.lastQueryValue("api_key") == nil)
        #expect(stub.client.lastRateLimit == nil)
    }

    @Test func epicByDateThroughTheGateway() async throws {
        let stub = StubbedClient { _ in try .json("epic-natural") }
        let images = try await stub.client.epicImages(.enhanced, date: CalendarDate(year: 2019, month: 5, day: 30), source: .apiGateway)

        #expect(stub.lastService == "api")
        #expect(stub.lastPath == "/EPIC/api/enhanced/date/2019-05-30")
        #expect(stub.lastQueryValue("api_key") == "TEST_KEY")
        #expect(images.allSatisfy { $0.collection == .enhanced })
    }

    @Test func epicImagesAreSortedByTime() async throws {
        let stub = StubbedClient { _ in try .json("epic-natural") }
        let images = try await stub.client.epicImages()

        let identifiers = images.map(\.identifier)
        let expected: [String] = ["20190530011359", "20190530053359", "20190530104359"]
        #expect(identifiers == expected)
    }

    @Test func epicAvailableDates() async throws {
        let stub = StubbedClient { _ in try .json("epic-available") }
        let dates = try await stub.client.epicAvailableDates(.natural)

        #expect(dates.count == 4)
        #expect(dates.last == CalendarDate(year: 2019, month: 5, day: 30))
        #expect(stub.lastPath == "/api/natural/available")
    }

    @Test func epicImageURLs() async throws {
        let stub = StubbedClient { _ in try .json("epic-natural") }
        let images = try await stub.client.epicImages()
        let image = try #require(images.first)

        let direct = stub.client.epicImageURL(for: image, format: .png)
        #expect(direct?.absoluteString == "https://epic.\(stub.token).nasa.test/archive/natural/2019/05/30/png/epic_1b_20190530011359.png")

        let gateway = stub.client.epicImageURL(for: image, format: .jpg, source: .apiGateway)
        #expect(gateway?.absoluteString == "https://api.\(stub.token).nasa.test/EPIC/archive/natural/2019/05/30/jpg/epic_1b_20190530011359.jpg?api_key=TEST_KEY")

        let thumbnail = image.imageURL(.thumbnail)
        #expect(thumbnail?.absoluteString == "https://epic.gsfc.nasa.gov/archive/natural/2019/05/30/thumbs/epic_1b_20190530011359.jpg")
    }

    // MARK: Image and Video Library

    @Test func librarySearchIsKeyless() async throws {
        let stub = StubbedClient { _ in try .json("media-search") }
        let result = try await stub.client.searchMedia("apollo 11", page: 2, pageSize: 24)

        #expect(result.items.count == 3)
        #expect(stub.lastService == "images")
        #expect(stub.lastPath == "/search")
        #expect(stub.lastQueryValue("q") == "apollo 11")
        #expect(stub.lastQueryValue("media_type") == "image")
        #expect(stub.lastQueryValue("page") == "2")
        #expect(stub.lastQueryValue("page_size") == "24")
        #expect(stub.lastQueryValue("api_key") == nil)
        let query = stub.lastURL?.query ?? ""
        #expect(query.contains("q=apollo%2011"))
    }

    @Test func libraryQueryWithFilters() async throws {
        let stub = StubbedClient { _ in try .json("media-search") }
        let query = NASAMediaQuery(
            "saturn",
            mediaTypes: [.image, .video],
            yearStart: 2004,
            yearEnd: 2017,
            center: "JPL",
            keywords: ["Cassini", " rings "]
        )
        _ = try await stub.client.searchMedia(query)

        #expect(stub.lastQueryValue("media_type") == "image,video")
        #expect(stub.lastQueryValue("year_start") == "2004")
        #expect(stub.lastQueryValue("year_end") == "2017")
        #expect(stub.lastQueryValue("center") == "JPL")
        #expect(stub.lastQueryValue("keywords") == "Cassini,rings")
    }

    @Test func librarySearchNeedsATerm() async throws {
        let stub = StubbedClient { _ in try .json("media-search") }
        await #expect(throws: NASAError.self) {
            _ = try await stub.client.searchMedia(NASAMediaQuery(mediaTypes: [.image], page: 1))
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func assetMetadataAndCaptions() async throws {
        let stub = StubbedClient { request in
            let path = request.url?.path ?? ""
            if path.hasPrefix("/asset/") { return try .json("media-asset") }
            if path.hasPrefix("/metadata/") { return try .json("media-metadata") }
            if path.hasPrefix("/captions/") {
                return StubResponse(status: 200, headers: [:], body: Data(#"{"location":"https://images-assets.nasa.gov/video/sample-video-0004/sample-video-0004.srt"}"#.utf8))
            }
            return .status(404)
        }

        let asset = try await stub.client.mediaAsset(nasaID: "sample-apollo-0001")
        #expect(stub.lastPath == "/asset/sample-apollo-0001")
        #expect(asset.files.count == 7)
        let metadata = try await stub.client.mediaMetadataLocation(nasaID: "sample-apollo-0001")
        #expect(metadata.lastPathComponent == "metadata.json")
        let captions = try await stub.client.mediaCaptionsLocation(nasaID: "sample-video-0004")
        #expect(captions.pathExtension == "srt")
    }

    @Test func idsWithSpacesAndSlashesStayOneSegment() async throws {
        let stub = StubbedClient { _ in try .json("media-asset") }
        _ = try await stub.client.mediaAsset(nasaID: "sample apollo/0002")

        let url = try #require(stub.lastURL)
        #expect(url.absoluteString.hasSuffix("/asset/sample%20apollo%2F0002"))
    }

    @Test func album() async throws {
        let stub = StubbedClient { _ in try .json("media-search") }
        _ = try await stub.client.mediaAlbum("Apollo", page: 3)

        #expect(stub.lastPath == "/album/Apollo")
        #expect(stub.lastQueryValue("page") == "3")
    }

    @Test func headers() async throws {
        let stub = StubbedClient { _ in try .json("apod-image") }
        _ = try await stub.client.apod()

        let request = try #require(stub.requests.last)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let agent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        #expect(agent.hasPrefix("NASAKit"))
    }

    @Test func emptyKeyFallsBackToDemoKey() {
        let configuration = NASAConfiguration(apiKey: "  ")
        #expect(configuration.apiKey == "DEMO_KEY")
        #expect(configuration.usesDemoKey)
    }

    @Test func keyFromTheEnvironment() {
        let withKey = NASAConfiguration.fromEnvironment(["NASA_API_KEY": "abc123"])
        #expect(withKey.apiKey == "abc123")
        let empty = NASAConfiguration.fromEnvironment(["NASA_API_KEY": ""])
        #expect(empty.apiKey == "DEMO_KEY")
        let missing = NASAConfiguration.fromEnvironment([:])
        #expect(missing.usesDemoKey)
        #expect(NASAConfiguration.apiKeyFromEnvironment([:]) == nil)
    }
}
