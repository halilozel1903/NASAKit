import Foundation
import Testing
@testable import NASAKit

@Suite("Decoding")
struct DecodingTests {
    // MARK: APOD

    @Test func apodImage() throws {
        let entry = try Fixture.decode(APODEntry.self, from: "apod-image")

        #expect(entry.date == CalendarDate(year: 2026, month: 10, day: 8))
        #expect(entry.mediaType == .image)
        #expect(entry.isImage)
        #expect(entry.copyright == "Jane Rivera")
        #expect(entry.serviceVersion == "v1")
        #expect(entry.displayImageURL?.lastPathComponent == "SampleGalaxy_Rivera_1080.jpg")
        #expect(entry.bestImageURL?.lastPathComponent == "SampleGalaxy_Rivera_4000.jpg")
        #expect(entry.videoURL == nil)
        #expect(entry.pageURL?.absoluteString == "https://apod.nasa.gov/apod/ap261008.html")
    }

    @Test func apodVideoShowsItsThumbnail() throws {
        let entry = try Fixture.decode(APODEntry.self, from: "apod-video")

        #expect(entry.mediaType == .video)
        #expect(entry.copyright == nil)
        #expect(entry.hdURL == nil)
        #expect(entry.displayImageURL?.absoluteString == "https://img.youtube.com/vi/abcDEF12345/0.jpg")
        #expect(entry.bestImageURL == entry.thumbnailURL)
        #expect(entry.videoURL?.host == "www.youtube.com")
        #expect(entry.youTubeID == "abcDEF12345")
    }

    @Test func apodOtherMediaHasNoImage() throws {
        let entries = try Fixture.decode([APODEntry].self, from: "apod-range")
        let other = try #require(entries.first { $0.date == CalendarDate(year: 2026, month: 10, day: 6) })

        #expect(other.mediaType == .other("other"))
        #expect(other.url == nil)
        #expect(other.displayImageURL == nil)
    }

    @Test func apodOldEntriesAreUpgradedToHTTPS() throws {
        let entries = try Fixture.decode([APODEntry].self, from: "apod-count")
        let first = try #require(entries.first)

        #expect(first.date == APODEntry.firstDate)
        #expect(first.url?.scheme == "https")
        #expect(first.hdURL?.absoluteString == "https://apod.nasa.gov/apod/image/e_lens.gif")
    }

    // MARK: Mars

    @Test func marsPhoto() throws {
        let response = try Fixture.decode(MarsPhotosResponse.self, from: "mars-photos")
        let photo = try #require(response.photos.first)

        #expect(photo.id == 102693)
        #expect(photo.sol == 1000)
        #expect(photo.camera.name == "FHAZ")
        #expect(photo.camera.fullName == "Front Hazard Avoidance Camera")
        #expect(photo.camera.parameter == .fhaz)
        #expect(photo.earthDate == CalendarDate(year: 2015, month: 5, day: 30))
        #expect(photo.imageURL?.scheme == "https")
        #expect(photo.imageURL?.host == "mars.jpl.nasa.gov")
        #expect(photo.rover.rover == .curiosity)
        #expect(photo.rover.isActive)
        #expect(photo.rover.cameras.count == 7)
    }

    @Test func marsManifest() throws {
        let response = try Fixture.decode(MarsManifestResponse.self, from: "mars-manifest")
        let manifest = response.manifest

        #expect(manifest.name == "Curiosity")
        #expect(manifest.maxSol == 4102)
        #expect(manifest.totalPhotos == 695670)
        #expect(manifest.sols.first?.totalPhotos == 3702)
        #expect(manifest.sols.first?.cameras.contains("MARDI") == true)
    }

    @Test func marsRovers() throws {
        let response = try Fixture.decode(MarsRoversResponse.self, from: "mars-rovers")
        let opportunity = try #require(response.rovers.last)

        #expect(opportunity.rover == .opportunity)
        #expect(opportunity.isActive == false)
        #expect(opportunity.landingDate == CalendarDate(year: 2004, month: 1, day: 25))
        #expect(opportunity.cameras.first?.roverID == 6)
    }

    // MARK: NeoWs

    @Test func neoFeedStringsBecomeNumbers() throws {
        let feed = try Fixture.decode(NEOFeed.self, from: "neo-feed")

        let days = feed.days.map(\.description)
        let expectedDays: [String] = ["2015-09-07", "2015-09-08"]
        #expect(days == expectedDays)
        #expect(feed.allObjects.count == 3)
        #expect(feed.links?.previous != nil)

        let hazardous = try #require(feed.hazardousObjects.first)
        #expect(hazardous.id == "2465633")
        #expect(hazardous.designation == "2009 JR5")
        let approach = try #require(hazardous.closeApproaches.first)
        #expect(approach.orbitingBody == "Earth")
        #expect(approach.dateFull == "2015-Sep-08 20:28")
        let speed: Double = approach.relativeVelocity.kilometersPerSecond
        #expect(abs(speed - 18.1279360862) < 0.000001)
        let lunar: Double = approach.missDistance.lunar
        #expect(abs(lunar - 117.7685618773) < 0.000001)
        let epoch: Double = approach.epoch?.timeIntervalSince1970 ?? 0
        #expect(epoch == 1441744080)
        let diameter: Double = hazardous.estimatedDiameter?.meters.max ?? 0
        #expect(abs(diameter - 503.5469604) < 0.001)
    }

    @Test func neoFeedOrdersEachDayByApproachTime() throws {
        let feed = try Fixture.decode(NEOFeed.self, from: "neo-feed")
        let names = feed.allObjects.map(\.name)
        let expected: [String] = ["(2010 XT10)", "(2008 QV11)", "465633 (2009 JR5)"]
        #expect(names == expected)
    }

    @Test func neoLookupWithOrbit() throws {
        let eros = try Fixture.decode(NearEarthObject.self, from: "neo-lookup")

        #expect(eros.closeApproaches.count == 3)
        #expect(eros.closeApproaches[1].dateFull == nil)
        #expect(eros.closestApproachToEarth?.date == CalendarDate(year: 1907, month: 11, day: 5))
        let orbit = try #require(eros.orbitalData)
        #expect(orbit.orbitClass?.type == "AMO")
        #expect(orbit.firstObservationDate == CalendarDate(year: 1893, month: 10, day: 29))
        let eccentricity: Double = orbit.eccentricity ?? 0
        #expect(abs(eccentricity - 0.2229512647434284) < 0.0000001)
        let period: Double = orbit.orbitalPeriodDays ?? 0
        #expect(period > 643 && period < 644)
    }

    @Test func neoBrowsePage() throws {
        let page = try Fixture.decode(NEOBrowsePage.self, from: "neo-browse")

        #expect(page.objects.count == 2)
        #expect(page.page.totalElements == 41187)
        #expect(page.hasNextPage)
        #expect(page.links?.next?.scheme == "https")
    }

    // MARK: EPIC

    @Test func epicImage() throws {
        let images = try Fixture.decode([EPICImage].self, from: "epic-natural")
        let image = try #require(images.first { $0.identifier == "20190530011359" })

        #expect(image.image == "epic_1b_20190530011359")
        #expect(image.version == "03")
        #expect(image.day == CalendarDate(year: 2019, month: 5, day: 30))
        #expect(image.caption?.hasPrefix("This image was taken by NASA's EPIC camera") == true)
        let latitude: Double = image.centroid?.latitude ?? 0
        #expect(abs(latitude - 9.141602) < 0.000001)

        let expectedDate = try #require(CalendarDate(year: 2019, month: 5, day: 30).date())
        #expect(image.date == expectedDate.addingTimeInterval(13 * 60 + 59))

        let distance: Double = image.spacecraftDistance ?? 0
        #expect(distance > 1_400_000 && distance < 1_500_000)
        #expect(image.imageURL(.jpg)?.absoluteString == "https://epic.gsfc.nasa.gov/archive/natural/2019/05/30/jpg/epic_1b_20190530011359.jpg")
    }

    @Test func epicArchiveURLPadsMonthAndDay() {
        let url = EPICImage.archiveURL(
            image: "epic_RGB_20160105003633",
            day: CalendarDate(year: 2016, month: 1, day: 5),
            collection: .enhanced,
            format: .png
        )
        #expect(url?.absoluteString == "https://epic.gsfc.nasa.gov/archive/enhanced/2016/01/05/png/epic_RGB_20160105003633.png")
    }

    // MARK: Image and Video Library

    @Test func librarySearch() throws {
        let result = try Fixture.decode(NASAMediaSearchResult.self, from: "media-search")

        #expect(result.totalHits == 336)
        #expect(result.nextPageURL?.query?.contains("page=2") == true)
        #expect(result.previousPageURL == nil)
        #expect(result.items(of: .image).count == 2)

        let first = try #require(result.items.first)
        #expect(first.nasaID == "sample-apollo-0001")
        #expect(first.metadata.center == "JSC")
        #expect(first.metadata.photographer == "Sample Photographer")
        let keywords: [String] = ["APOLLO 11", "MOON"]
        #expect(first.metadata.keywords == keywords)
        #expect(first.previewURL?.lastPathComponent == "sample-apollo-0001~thumb.jpg")
        #expect(first.isLandscape == true)
        #expect(first.metadata.plainDescription == "A sample description & its HTML.\nSecond line.")
        let created = try #require(first.metadata.dateCreated)
        #expect(CalendarDate(created, in: TimeZone(identifier: "UTC")!) == CalendarDate(year: 1969, month: 7, day: 20))
    }

    @Test func libraryItemQuirks() throws {
        let result = try Fixture.decode(NASAMediaSearchResult.self, from: "media-search")

        // Spaces in ids and URLs, a single comma-separated keyword string, fractional seconds.
        let spaced = result.items[1]
        #expect(spaced.previewURL?.absoluteString.contains("sample%20apollo%200002") == true)
        let keywords: [String] = ["Apollo 11", "Saturn V"]
        #expect(spaced.metadata.keywords == keywords)
        #expect(spaced.isLandscape == nil)
        #expect(spaced.metadata.dateCreated != nil)

        // Audio items have no links.
        let audio = result.items[2]
        #expect(audio.mediaType == .audio)
        #expect(audio.links.isEmpty)
        #expect(audio.previewURL == nil)
    }

    @Test func imageAsset() throws {
        let asset = try Fixture.decode(NASAMediaAsset.self, from: "media-asset")

        #expect(asset.image(.large)?.lastPathComponent == "sample-apollo-0001~large.jpg")
        #expect(asset.image(.original)?.lastPathComponent == "sample-apollo-0001~orig.jpg")
        #expect(asset.bestImage()?.lastPathComponent == "sample-apollo-0001~large.jpg")
        #expect(asset.bestImage(preferring: [.medium])?.lastPathComponent == "sample-apollo-0001~medium.jpg")
        #expect(asset.metadataURL?.lastPathComponent == "metadata.json")
        #expect(asset.bestVideo() == nil)
    }

    @Test func videoAsset() throws {
        let asset = try Fixture.decode(NASAMediaAsset.self, from: "media-asset-video")

        #expect(asset.bestVideo()?.lastPathComponent == "sample-video-0004~mobile.mp4")
        #expect(asset.video(.original)?.scheme == "https")
        #expect(asset.captionsURL?.pathExtension == "srt")
        #expect(asset.bestImage()?.lastPathComponent == "sample-video-0004~large.jpg")
    }
}
