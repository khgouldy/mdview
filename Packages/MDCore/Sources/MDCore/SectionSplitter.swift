import Foundation

/// Cuts large Markdown into sections that parse and render on their own, so the reader lays out only what is on
/// screen.
///
/// A cut goes only before an ATX heading line at column 0 (`#` to `######`, then a space or tab) that sits outside
/// fenced code, HTML comments and raw HTML blocks (`pre`, `script`, `style`, `textarea`). Such a heading always starts
/// a new block, and nothing before it continues past it, so each section renders as it would inside the whole
/// document. The one thing that crosses sections is a link reference definition; `parseInput(for:definitions:)`
/// carries the ones a section uses. Setext headings never cut. CRLF and LF input cut at the same lines.
public enum SectionSplitter {
    public static let defaultMinimumBytes = 65536

    /// At or below `minimumBytes`, one element: the input. Above, the input cut before each top-level ATX heading.
    /// Sections are never empty (except for empty input), and joining them reproduces the input exactly.
    public static func sections(_ markdown: String, minimumBytes: Int = defaultMinimumBytes) -> [String] {
        guard markdown.utf8.count > minimumBytes else {
            return [markdown]
        }
        var cuts = [0]
        var scanner = BlockScanner()
        MarkdownLines.forEach(in: markdown) { offset, line in
            if scanner.classify(line) == .heading, offset > 0 {
                cuts.append(offset)
            }
        }
        cuts.append(markdown.utf8.count)
        return zip(cuts, cuts.dropFirst()).map { start, end in
            String(MarkdownLines.slice(markdown, from: start, to: end))
        }
    }

    /// Joins consecutive sections until each group holds at least `targetBytes` (the last may hold less). Groups still
    /// start at headings, and joining them reproduces the joined input.
    public static func grouped(_ sections: [String], targetBytes: Int) -> [String] {
        var groups: [String] = []
        var current = ""
        for section in sections {
            current += section
            if current.utf8.count >= targetBytes {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups
    }

    // MARK: Link reference definitions

    /// A one-line link reference definition such as `[1.0.0]: https://example.com/compare`.
    public struct LinkDefinition: Equatable, Sendable {
        /// Lowercased, with runs of whitespace collapsed, as CommonMark matches labels.
        public let label: String
        /// The definition line, without its line ending.
        public let line: String
    }

    /// One-line definitions outside code and HTML blocks. A definition cannot interrupt a paragraph, so a candidate
    /// counts only after a blank line, another definition or the start of the document. Footnote-style labels
    /// (`[^1]:`) and lines with anything after the destination and title are skipped, because CommonMark reads those
    /// as paragraph text.
    public static func linkDefinitions(in markdown: String) -> [LinkDefinition] {
        var definitions: [LinkDefinition] = []
        scanDefinitions(in: markdown) { definition in
            definitions.append(definition)
        } onLine: { _, _ in }
        return definitions
    }

    /// The definitions whose label appears in brackets in `section`, outside definition lines. Returns none when the
    /// section ends inside a fence or HTML block, because appended lines would land inside it.
    public static func definitions(usedBy section: String, from definitions: [LinkDefinition]) -> [LinkDefinition] {
        guard !definitions.isEmpty else {
            return []
        }
        var used = Set<String>()
        let endsInsideBlock = scanDefinitions(in: section) { _ in } onLine: { bytes, text in
            if bytes.contains(ASCII.openBracket) {
                collectBracketLabels(in: text, into: &used)
            }
        }
        guard !endsInsideBlock, !used.isEmpty else {
            return []
        }
        var seen = Set<String>()
        return definitions.filter { used.contains($0.label) && seen.insert($0.label).inserted }
    }

    /// What to parse for `section`: the section itself, then the definitions it uses after a blank line. The
    /// definitions render nothing; they only resolve reference links whose definition sits in another section.
    public static func parseInput(for section: String, definitions: [LinkDefinition]) -> String {
        let used = self.definitions(usedBy: section, from: definitions)
        guard !used.isEmpty else {
            return section
        }
        let separator = section.hasSuffix("\n") ? "\n" : "\n\n"
        return section + separator + used.map(\.line).joined(separator: "\n") + "\n"
    }

    /// Walks top-level lines, reporting definitions and every other line outside blocks. Returns true when the text
    /// ends inside a fence or HTML block.
    @discardableResult
    private static func scanDefinitions(
        in markdown: String,
        onDefinition: (LinkDefinition) -> Void,
        onLine: (_ bytes: UnsafeBufferPointer<UInt8>, _ text: Substring) -> Void,
    ) -> Bool {
        var scanner = BlockScanner()
        var previousAllowsDefinition = true
        MarkdownLines.forEach(in: markdown) { offset, line in
            guard scanner.classify(line) != .insideBlock else {
                previousAllowsDefinition = false
                return
            }
            let text = MarkdownLines.slice(markdown, from: offset, to: offset + line.count)
            if previousAllowsDefinition, let definition = candidateDefinition(line, text: text) {
                onDefinition(definition)
                return
            }
            onLine(line, text)
            previousAllowsDefinition = MarkdownLines.isBlank(line)
        }
        return scanner.isInsideBlock
    }

    /// Parses only lines whose first non-space byte is `[`, so most lines cost one byte check.
    private static func candidateDefinition(_ line: UnsafeBufferPointer<UInt8>, text: Substring) -> LinkDefinition? {
        guard let first = line.first(where: { $0 != ASCII.space }), first == ASCII.openBracket else {
            return nil
        }
        return parseDefinition(text)
    }

    /// `[label]: destination` with an optional quoted or parenthesized title, up to three spaces of indent.
    private static func parseDefinition(_ line: Substring) -> LinkDefinition? {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3, let (label, afterLabel) = parseLabel(line.dropFirst(indent)), afterLabel.first == ":" else {
            return nil
        }
        guard let afterDestination = skipDestination(afterLabel.dropFirst().drop(while: isSpaceOrTab)),
              let rest = skipTitle(afterDestination),
              rest.allSatisfy(isSpaceOrTab)
        else {
            return nil
        }
        return LinkDefinition(label: label, line: String(line))
    }

    /// `[label]` with no nested `[`, not a footnote (`[^`), and not blank once normalized.
    private static func parseLabel(_ text: Substring) -> (label: String, rest: Substring)? {
        guard text.first == "[", let close = text.firstIndex(of: "]") else {
            return nil
        }
        let raw = text[text.index(after: text.startIndex) ..< close]
        guard raw.first != "^", !raw.contains("["), raw.count <= 999 else {
            return nil
        }
        let label = normalized(raw)
        guard !label.isEmpty else {
            return nil
        }
        return (label, text[text.index(after: close)...])
    }

    /// `<...>` or a non-empty run without spaces. Returns what follows.
    private static func skipDestination(_ text: Substring) -> Substring? {
        if text.first == "<" {
            guard let end = text.firstIndex(of: ">") else {
                return nil
            }
            return text[text.index(after: end)...]
        }
        let destination = text.prefix { !isSpaceOrTab($0) }
        return destination.isEmpty ? nil : text[destination.endIndex...]
    }

    /// Nothing, or whitespace then a `"..."`, `'...'` or `(...)` title. Returns what follows, for the caller to check
    /// is blank.
    private static func skipTitle(_ text: Substring) -> Substring? {
        let trimmed = text.drop(while: isSpaceOrTab)
        guard let opener = trimmed.first, trimmed.startIndex != text.startIndex else {
            return trimmed
        }
        let closers: [Character: Character] = ["\"": "\"", "'": "'", "(": ")"]
        guard let closer = closers[opener] else {
            return nil
        }
        let body = trimmed.dropFirst()
        guard let end = body.firstIndex(of: closer) else {
            return nil
        }
        return body[body.index(after: end)...]
    }

    /// Every `[...]` without a nested `[` in `line`, normalized. Covers full, collapsed and shortcut references.
    private static func collectBracketLabels(in line: Substring, into labels: inout Set<String>) {
        var open: Substring.Index?
        var index = line.startIndex
        while index < line.endIndex {
            switch line[index] {
            case "[":
                open = line.index(after: index)
            case "]":
                if let start = open {
                    let label = normalized(line[start ..< index])
                    if !label.isEmpty {
                        labels.insert(label)
                    }
                }
                open = nil
            default:
                break
            }
            index = line.index(after: index)
        }
    }

    private static func normalized(_ label: Substring) -> String {
        label.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    private static func isSpaceOrTab(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }
}
