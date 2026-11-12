import Foundation

/// Light Markdown for task titles. Titles stay plain text (that's what's
/// saved, and what you see while editing); only the row's display turns
/// the marks into formatting:
///
/// - `**bold**`, `*italic*` (also `__bold__`, `_italic_`, `~~strike~~`, `` `code` ``)
/// - a line starting with `- `, `* ` or `• ` becomes a bullet point
enum TaskTitleFormat {
    struct Line: Equatable {
        let isBullet: Bool
        let text: AttributedString
    }

    private static let bulletPrefixes = ["- ", "* ", "• "]
    /// Characters that can start inline formatting. A title without any of
    /// them skips the Markdown parser entirely - the common case.
    private static let inlineMarkers = CharacterSet(charactersIn: "*_~`\\")

    static func lines(from title: String) -> [Line] {
        title
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line(from: String($0)) }
    }

    private static func line(from raw: String) -> Line {
        let leadingTrimmed = raw.drop { $0 == " " || $0 == "\t" }
        for prefix in bulletPrefixes where leadingTrimmed.hasPrefix(prefix) {
            let content = leadingTrimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespaces)
            return Line(isBullet: true, text: inline(content))
        }
        // An empty line keeps its height in the list.
        return Line(isBullet: false, text: inline(raw.isEmpty ? " " : raw))
    }

    static func inline(_ text: String) -> AttributedString {
        guard text.rangeOfCharacter(from: inlineMarkers) != nil else {
            return AttributedString(text)
        }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard var parsed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        // Links aren't part of the format: clicking a task checks it off,
        // and a link would hide its address. Keep the text, drop the link.
        for run in parsed.runs where run.link != nil {
            parsed[run.range].link = nil
        }
        return parsed
    }
}
