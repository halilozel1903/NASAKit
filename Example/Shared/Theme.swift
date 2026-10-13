import SwiftUI
import NASAKit

/// The look of "Orbit", the demo app.
@MainActor
enum Theme {
    static let brand = "ORBIT"
    static let background = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let surface = Color(red: 0.07, green: 0.09, blue: 0.15)
    static let accent = Color(red: 0.35, green: 0.68, blue: 1.0)
    static let warm = Color(red: 1.0, green: 0.62, blue: 0.32)

    /// "July 20, 1969", for library items (dates are midnight UTC).
    static func longDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        var style = Date.FormatStyle.dateTime.year().month(.wide).day()
        style.timeZone = TimeZone(identifier: "UTC") ?? .current
        return date.formatted(style)
    }

    /// "Thursday, October 8".
    static func longDay(_ day: CalendarDate) -> String {
        let utc = TimeZone(identifier: "UTC") ?? .current
        guard let date = day.date(in: utc) else { return day.description }
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        style.timeZone = utc
        return date.formatted(style)
    }

    /// "Oct 8".
    static func shortDay(_ day: CalendarDate) -> String {
        let utc = TimeZone(identifier: "UTC") ?? .current
        guard let date = day.date(in: utc) else { return day.description }
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.timeZone = utc
        return date.formatted(style)
    }

    /// "14:32 UTC".
    static func utcTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        var style = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        style.timeZone = TimeZone(identifier: "UTC") ?? .current
        style.locale = Locale(identifier: "en_GB")
        return date.formatted(style) + " UTC"
    }

    /// "JSC · July 20, 1969".
    static func itemFacts(_ item: NASAMediaItem) -> String {
        var parts: [String] = []
        if let center = item.metadata.center { parts.append(center) }
        if let date = longDate(item.metadata.dateCreated) { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    /// "8.4° N, 18.8° W".
    static func coordinates(_ point: EPICCoordinates?) -> String? {
        guard let point else { return nil }
        let latitude = String(format: "%.1f° %@", abs(point.latitude), point.latitude >= 0 ? "N" : "S")
        let longitude = String(format: "%.1f° %@", abs(point.longitude), point.longitude >= 0 ? "E" : "W")
        return latitude + ", " + longitude
    }

    /// "1,452,800 km".
    static func kilometers(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.formatted(.number.precision(.fractionLength(0))) + " km"
    }
}

/// The brand mark: an orbit symbol and the name.
struct BrandMark: View {
    var size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.4) {
            Image(systemName: "circle.circle")
                .foregroundStyle(Theme.accent)
            Text(Theme.brand)
                .tracking(size * 0.25)
                .foregroundStyle(Color.white)
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Orbit")
    }
}

/// The note every screen with NASA content carries.
struct CreditLine: View {
    var text: String = "Images and data: NASA. Not endorsed by NASA."

    var body: some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
