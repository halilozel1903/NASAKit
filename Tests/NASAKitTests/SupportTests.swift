import Foundation
import Testing
@testable import NASAKit

@Suite("Support")
struct SupportTests {
    @Test func calendarDateParsing() {
        #expect(CalendarDate("2026-10-08") == CalendarDate(year: 2026, month: 10, day: 8))
        #expect(CalendarDate("2015-6-3") == CalendarDate(year: 2015, month: 6, day: 3))
        #expect(CalendarDate("2026-02-30") == nil)
        #expect(CalendarDate("2026-13-01") == nil)
        #expect(CalendarDate("20261008") == nil)
        #expect(CalendarDate("") == nil)
        #expect(CalendarDate(year: 2026, month: 1, day: 5).description == "2026-01-05")
    }

    @Test func calendarDateArithmetic() {
        let day = CalendarDate(year: 2026, month: 12, day: 30)
        #expect(day.adding(days: 3) == CalendarDate(year: 2027, month: 1, day: 2))
        #expect(day.adding(days: -30) == CalendarDate(year: 2026, month: 11, day: 30))
        #expect(day.days(until: CalendarDate(year: 2027, month: 1, day: 6)) == 7)
        #expect(CalendarDate(year: 2026, month: 1, day: 1) < CalendarDate(year: 2026, month: 1, day: 2))
    }

    @Test func todayInATimeZone() throws {
        // 03:00 UTC on October 9 is still October 8 in New York.
        let moment = try #require(CalendarDate(year: 2026, month: 10, day: 9).date()).addingTimeInterval(3 * 3600)
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(CalendarDate.today(in: newYork, now: moment) == CalendarDate(year: 2026, month: 10, day: 8))
    }

    @Test func calendarDateCoding() throws {
        let data = try JSONEncoder().encode([CalendarDate(year: 2019, month: 5, day: 30)])
        #expect(String(decoding: data, as: UTF8.self) == #"["2019-05-30"]"#)
        let decoded = try JSONDecoder().decode([CalendarDate].self, from: data)
        #expect(decoded.first == CalendarDate(year: 2019, month: 5, day: 30))
    }

    @Test func timestamps() throws {
        let spaced = try #require(Timestamp.parseSpaced("2019-05-30 00:13:59"))
        let midnight = try #require(CalendarDate(year: 2019, month: 5, day: 30).date())
        #expect(spaced.timeIntervalSince(midnight) == 839)
        #expect(Timestamp.parseSpaced("2019-05-30") == nil)
        let landing = try #require(CalendarDate(year: 1969, month: 7, day: 20).date()).addingTimeInterval(20 * 3600 + 17 * 60 + 40)
        #expect(Timestamp.parseISO8601("1969-07-20T20:17:40Z") == landing)
        #expect(Timestamp.parseISO8601("2009-07-15T00:00:00.000Z") != nil)
        #expect(Timestamp.parseISO8601("2009-07-15") != nil)
    }

    @Test func urlsAreUpgradedOnlyForNASAHosts() {
        #expect(NASAURL.parse("http://mars.jpl.nasa.gov/a.JPG")?.absoluteString == "https://mars.jpl.nasa.gov/a.JPG")
        #expect(NASAURL.parse("http://nasa.gov/x")?.scheme == "https")
        #expect(NASAURL.parse("http://example.com/x")?.scheme == "http")
        #expect(NASAURL.parse("http://notnasa.gov/x")?.scheme == "http")
        #expect(NASAURL.parse("//apod.nasa.gov/apod/image/x.jpg")?.absoluteString == "https://apod.nasa.gov/apod/image/x.jpg")
        #expect(NASAURL.parse("  ") == nil)
        #expect(NASAURL.parse(nil) == nil)
        #expect(NASAURL.parse("not a url") == nil)
    }

    @Test func plainTextFromHTML() {
        let html = #"<p>Saturn&#39;s rings &amp; moons</p><p>Seen   by <a href="https://example.com">Cassini</a>&nbsp;&mdash; in 2004.</p>"#
        #expect(PlainText.from(html: html) == "Saturn's rings & moons\nSeen by Cassini \u{2014} in 2004.")
        #expect(PlainText.from(html: "AT&T 5 < 6") == "AT&T 5 < 6")
        #expect(PlainText.from(html: "5 < 6 and 7 > 3") == "5 < 6 and 7 > 3")
        #expect(PlainText.from(html: "Line<br/>Next<br>Last") == "Line\nNext\nLast")
    }

    @Test func marsRoverNames() {
        #expect(MarsRover.perseverance.name == "Perseverance")
        let all = MarsRover.allCases.map(\.rawValue)
        let expected: [String] = ["curiosity", "opportunity", "spirit", "perseverance"]
        #expect(all == expected)
    }

    @Test func libraryQueryItems() {
        let query = NASAMediaQuery("  ", mediaTypes: [], keywords: ["", " "], page: 2)
        #expect(query.hasSearchTerm == false)
        let names = query.queryItems.map(\.name)
        let expected: [String] = ["page"]
        #expect(names == expected)
        #expect(NASAMediaQuery(nasaID: "as11-40-5874").hasSearchTerm)
    }
}
