import Foundation

/// Literal matches of a query in text, ignoring case and diacritics.
public enum TextSearch {
    /// Ranges of `query` in `text`. An empty query matches nothing.
    /// The search resumes one grapheme cluster after each match starts, so overlaps are returned.
    /// Each range covers the matched text in `text`, including combining marks.
    public static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        guard !query.isEmpty, !text.isEmpty else {
            return []
        }
        var matches: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex {
            guard let match = text[start...].range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: locale,
            ), match.lowerBound < text.endIndex, !match.isEmpty else {
                break
            }
            matches.append(match)
            let next = text.index(after: match.lowerBound)
            if next <= start {
                break
            }
            start = next
        }
        return matches
    }

    /// POSIX folding stays the same on every device language.
    private static let locale = Locale(identifier: "en_US_POSIX")
}
