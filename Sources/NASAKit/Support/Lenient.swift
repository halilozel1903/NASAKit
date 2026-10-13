import Foundation

/// Turns the URL strings NASA's APIs send into `URL`s.
///
/// The APIs send URLs with unencoded spaces, protocol-relative URLs (`//apod.nasa.gov/…`) and
/// plain `http://` links to NASA hosts that also serve HTTPS. App Transport Security blocks
/// plain HTTP on Apple platforms, so links to `nasa.gov` hosts are upgraded to HTTPS.
public enum NASAURL {
    /// A URL for `string`, or `nil` when it is empty or not a URL.
    public static func parse(_ string: String?) -> URL? {
        guard var text = string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        if text.hasPrefix("//") {
            text = "https:" + text
        }
        let url = URL(string: text) ?? text.addingPercentEncoding(withAllowedCharacters: allowed).flatMap { URL(string: $0) }
        guard let url, url.scheme != nil else { return nil }
        return secured(url)
    }

    /// `url` with `http` replaced by `https` when the host is a `nasa.gov` host.
    public static func secured(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http",
              let host = url.host?.lowercased(),
              host == "nasa.gov" || host.hasSuffix(".nasa.gov"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        components.scheme = "https"
        return components.url ?? url
    }

    private static let allowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed.union(.urlPathAllowed)
        set.insert(charactersIn: "%#")
        return set
    }()
}

extension KeyedDecodingContainer {
    /// A URL sent as a string, decoded leniently (see ``NASAURL/parse(_:)``). `nil` when the key
    /// is missing, `null`, empty or not a URL.
    func decodeLenientURL(forKey key: Key) throws -> URL? {
        NASAURL.parse(try decodeIfPresent(String.self, forKey: key))
    }

    /// A number the API sends either as a JSON number or as a string (`"18.1279360862"`).
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        let string = try decode(String.self, forKey: key)
        guard let value = Double(string.trimmingCharacters(in: .whitespaces)) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected a number, got \"\(string)\"")
        }
        return value
    }

    /// Like ``decodeFlexibleDouble(forKey:)``, `nil` when missing, `null` or empty.
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        let string = try decode(String.self, forKey: key).trimmingCharacters(in: .whitespaces)
        return string.isEmpty ? nil : Double(string)
    }

    /// A string trimmed of surrounding whitespace and newlines, `nil` when it ends up empty.
    func decodeTrimmedString(forKey key: Key) throws -> String? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Plain text from the small amount of HTML some NASA descriptions contain.
public enum PlainText {
    /// Removes tags, turns `<br>` and paragraph ends into line breaks, decodes common entities
    /// and collapses runs of spaces. Runs on any thread; it does not use `NSAttributedString`.
    public static func from(html: String) -> String {
        var output = ""
        output.reserveCapacity(html.count)
        var index = html.startIndex
        while index < html.endIndex {
            let character = html[index]
            if character == "<", startsTag(html, after: index), let close = html[index...].firstIndex(of: ">") {
                let tag = html[html.index(after: index)..<close].lowercased()
                let name = tag.split(whereSeparator: { $0 == " " || $0 == "/" }).first.map(String.init) ?? ""
                if name == "br" || (tag.hasPrefix("/") && ["p", "div", "li"].contains(String(tag.dropFirst()))) {
                    output.append("\n")
                }
                index = html.index(after: close)
                continue
            }
            if character == "&", let semicolon = html[index...].prefix(10).firstIndex(of: ";") {
                let entity = String(html[html.index(after: index)..<semicolon])
                if let decoded = decode(entity: entity) {
                    output.append(decoded)
                    index = html.index(after: semicolon)
                    continue
                }
            }
            output.append(character)
            index = html.index(after: index)
        }
        return collapse(output)
    }

    /// Whether the `<` at `index` opens a tag (`<b>`, `</p>`, `<!-- -->`) rather than being a
    /// less-than sign in the text ("5 < 6").
    private static func startsTag(_ html: String, after index: String.Index) -> Bool {
        let next = html.index(after: index)
        guard next < html.endIndex else { return false }
        let character = html[next]
        return character.isLetter || character == "/" || character == "!"
    }

    private static func decode(entity: String) -> String? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return " "
        case "ndash": return "\u{2013}"
        case "mdash": return "\u{2014}"
        case "hellip": return "\u{2026}"
        case "rsquo": return "\u{2019}"
        case "lsquo": return "\u{2018}"
        case "rdquo": return "\u{201D}"
        case "ldquo": return "\u{201C}"
        default:
            guard entity.hasPrefix("#") else { return nil }
            let number = entity.dropFirst()
            let value: UInt32?
            if number.hasPrefix("x") || number.hasPrefix("X") {
                value = UInt32(number.dropFirst(), radix: 16)
            } else {
                value = UInt32(number)
            }
            return value.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
    }

    /// Collapses spaces and tabs, trims every line and drops runs of blank lines.
    private static func collapse(_ text: String) -> String {
        var lines: [String] = []
        var previousBlank = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine
                .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
                .joined(separator: " ")
            if line.isEmpty {
                if !previousBlank, !lines.isEmpty { lines.append("") }
                previousBlank = true
            } else {
                lines.append(line)
                previousBlank = false
            }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
