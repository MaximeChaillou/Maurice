import Foundation

/// Pure functions that deal with `{{placeholder}}` tokens inside template
/// files. Extracted out of `TemplateUpdateService` to keep that type small.
enum TemplatePlaceholderEngine {

    /// A line carrying two representations: `canonical` for equality/hashing
    /// comparisons (placeholders neutralized), and `display` for rendering in
    /// the UI (user's actual substituted content preserved).
    struct TaggedLine: Hashable, Sendable {
        let canonical: String
        let display: String

        static func == (lhs: TaggedLine, rhs: TaggedLine) -> Bool {
            lhs.canonical == rhs.canonical
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(canonical)
        }
    }

    // MARK: - Tagging

    static func taggedLines(of data: Data, template: Data) -> [TaggedLine] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let patterns = placeholderPatterns(in: template)
        return text.components(separatedBy: "\n").map { line in
            tag(line: line, patterns: patterns)
        }
    }

    private static func tag(line: String, patterns: [PlaceholderPattern]) -> TaggedLine {
        if line.contains("{{") {
            return TaggedLine(canonical: canonicalize(bundledLine: line), display: line)
        }
        for pattern in patterns {
            let range = nsRange(line)
            if pattern.regex.firstMatch(in: line, range: range) != nil {
                return TaggedLine(canonical: pattern.canonical, display: line)
            }
        }
        return TaggedLine(canonical: line, display: line)
    }

    private struct PlaceholderPattern {
        let regex: NSRegularExpression
        let canonical: String
    }

    private static func placeholderPatterns(in template: Data) -> [PlaceholderPattern] {
        guard let text = String(data: template, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n").compactMap { line in
            guard line.contains("{{") else { return nil }
            let escaped = NSRegularExpression.escapedPattern(for: line)
            let wildcarded = escaped.replacingOccurrences(
                of: #"\\\{\\\{[^}]*\\\}\\\}"#,
                with: ".+?",
                options: .regularExpression
            )
            guard let regex = try? NSRegularExpression(pattern: "^" + wildcarded + "$")
            else { return nil }
            return PlaceholderPattern(regex: regex, canonical: canonicalize(bundledLine: line))
        }
    }

    private static func canonicalize(bundledLine: String) -> String {
        bundledLine.replacingOccurrences(
            of: #"\{\{[^}]+\}\}"#,
            with: "\u{0001}VAR\u{0001}",
            options: .regularExpression
        )
    }

    // MARK: - Extraction

    /// Scans `userData` for lines matching the template's placeholder lines
    /// and extracts the values. Falls back to `fallback` for any placeholder
    /// not found in the user file. Empty values in `fallback` are discarded.
    static func extractedOrFallbackReplacements(
        userData: Data?, template: Data, fallback: [String: String]
    ) -> [String: String] {
        var result = fallback.filter { !$0.value.isEmpty }
        guard let userData,
              let userText = String(data: userData, encoding: .utf8),
              let templateText = String(data: template, encoding: .utf8) else {
            return result
        }
        let userLines = userText.components(separatedBy: "\n")
        for templateLine in templateText.components(separatedBy: "\n") {
            guard let (regex, names) = buildCaptureRegex(for: templateLine) else { continue }
            mergeCaptures(from: userLines, regex: regex, names: names, into: &result)
        }
        return result
    }

    private static func buildCaptureRegex(
        for templateLine: String
    ) -> (NSRegularExpression, [String])? {
        guard let placeholderRegex = try? NSRegularExpression(pattern: #"\{\{([^}]+)\}\}"#)
        else { return nil }
        let matches = placeholderRegex.matches(in: templateLine, range: nsRange(templateLine))
        guard !matches.isEmpty else { return nil }

        var pattern = ""
        var cursor = templateLine.startIndex
        var names: [String] = []
        for match in matches {
            guard let fullRange = Range(match.range, in: templateLine),
                  let nameRange = Range(match.range(at: 1), in: templateLine) else { continue }
            pattern += NSRegularExpression.escapedPattern(
                for: String(templateLine[cursor..<fullRange.lowerBound])
            )
            names.append(String(templateLine[nameRange]))
            pattern += "(.+?)"
            cursor = fullRange.upperBound
        }
        pattern += NSRegularExpression.escapedPattern(for: String(templateLine[cursor...]))
        guard let regex = try? NSRegularExpression(pattern: "^" + pattern + "$") else { return nil }
        return (regex, names)
    }

    private static func mergeCaptures(
        from userLines: [String],
        regex: NSRegularExpression,
        names: [String],
        into result: inout [String: String]
    ) {
        for userLine in userLines {
            guard let hit = regex.firstMatch(in: userLine, range: nsRange(userLine)) else { continue }
            for (index, name) in names.enumerated() {
                guard let swiftRange = Range(hit.range(at: index + 1), in: userLine) else { continue }
                let key = "{{\(name)}}"
                if result[key]?.isEmpty ?? true {
                    result[key] = String(userLine[swiftRange])
                }
            }
            return
        }
    }

    // MARK: - Helpers

    private static func nsRange(_ string: String) -> NSRange {
        NSRange(string.startIndex..., in: string)
    }
}
