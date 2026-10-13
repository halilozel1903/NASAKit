import Foundation

/// A day without a time or time zone, as NASA's APIs write it: `"2026-10-08"`.
///
/// APOD dates, Mars rover Earth dates, NeoWs feed days and EPIC archive days are all calendar
/// days. Keeping them as `CalendarDate` avoids the off-by-one-day bugs a `Date` at midnight UTC
/// causes in other time zones.
public struct CalendarDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible, LosslessStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// A day; the values are not validated, use ``init(_:)`` to parse untrusted input.
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `"YYYY-MM-DD"` (single-digit months and days are accepted too). Returns `nil` for
    /// anything else, including days that don't exist such as `"2026-02-30"`.
    public init?(_ description: String) {
        let parts = description.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              (1...2).contains(parts[1].count),
              (1...2).contains(parts[2].count),
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        let calendar = CalendarDate.calendar(.nasaUTC)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        let components = CalendarDate.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Today in `timeZone`. APOD publishes by US Eastern time, so pass
    /// `TimeZone(identifier: "America/New_York")` to ask for "today's" picture.
    public static func today(in timeZone: TimeZone = .current, now: Date = Date()) -> CalendarDate {
        CalendarDate(now, in: timeZone)
    }

    /// `"2026-10-08"`.
    public var description: String {
        CalendarDate.pad(year, 4) + "-" + CalendarDate.pad(month, 2) + "-" + CalendarDate.pad(day, 2)
    }

    /// Midnight at the start of this day in `timeZone`.
    public func date(in timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> Date? {
        CalendarDate.calendar(timeZone).date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The day `days` days later (or earlier, when negative).
    public func adding(days: Int) -> CalendarDate {
        guard let start = date(in: .nasaUTC),
              let moved = CalendarDate.calendar(.nasaUTC).date(byAdding: .day, value: days, to: start)
        else { return self }
        return CalendarDate(moved, in: .nasaUTC)
    }

    /// The number of days from this day to `other`; negative when `other` is earlier.
    public func days(until other: CalendarDate) -> Int {
        guard let start = date(in: .nasaUTC), let end = other.date(in: .nasaUTC) else { return 0 }
        return CalendarDate.calendar(.nasaUTC).dateComponents([.day], from: start, to: end).day ?? 0
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = CalendarDate(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a YYYY-MM-DD date, got \"\(string)\"")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(abs(value))
        let padded = String(repeating: "0", count: max(0, width - digits.count)) + digits
        return value < 0 ? "-" + padded : padded
    }
}

extension TimeZone {
    /// Coordinated Universal Time.
    static let nasaUTC = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
}

/// Parses the timestamps NASA's APIs use.
enum Timestamp {
    /// `"2019-05-30 00:13:59"` in UTC, as EPIC writes it.
    static func parseSpaced(_ string: String) -> Date? {
        let halves = string.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard halves.count == 2, let day = CalendarDate(String(halves[0])) else { return nil }
        let time = halves[1].split(separator: ":")
        guard time.count == 3,
              let hour = Int(time[0]),
              let minute = Int(time[1]),
              let second = Double(time[2]),
              (0..<24).contains(hour), (0..<60).contains(minute), second >= 0, second < 61
        else { return nil }
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
        guard let date = CalendarDate.calendar(.nasaUTC).date(from: components) else { return nil }
        return date.addingTimeInterval(second)
    }

    /// ISO 8601, with or without fractional seconds: `"1969-07-20T00:00:00Z"`.
    static func parseISO8601(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if let date = try? Date.ISO8601FormatStyle().parse(trimmed) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(trimmed) {
            return date
        }
        // Some records only have a day.
        return CalendarDate(String(trimmed.prefix(10))).flatMap { $0.date(in: .nasaUTC) }
    }
}
