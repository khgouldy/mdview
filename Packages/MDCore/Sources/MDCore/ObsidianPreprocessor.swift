import Foundation

public enum ObsidianPreprocessor {
    /// Removes a leading YAML front matter block and rewrites Obsidian wikilinks to plain text.
    /// Fenced code, inline code, embeds, and callout blocks stay as written.
    public static func process(_ markdown: String) -> String {
        let body = removingFrontMatter(from: markdown) ?? markdown
        return rewritingWikilinks(in: body)
    }
}

private struct TextLine {
    var content: Substring
    var end: String.Index
}

private func removingFrontMatter(from markdown: String) -> String? {
    guard !markdown.isEmpty else {
        return nil
    }
    let opening = textLine(in: markdown, at: markdown.startIndex)
    guard isDelimiter(opening.content, marker: "---") else {
        return nil
    }
    var cursor = opening.end
    while cursor < markdown.endIndex {
        let line = textLine(in: markdown, at: cursor)
        if isDelimiter(line.content, marker: "---") || isDelimiter(line.content, marker: "...") {
            return String(markdown[line.end...])
        }
        cursor = line.end
    }
    return nil
}

private func textLine(in markdown: String, at start: String.Index) -> TextLine {
    var cursor = start
    while cursor < markdown.endIndex, !markdown[cursor].isNewline {
        cursor = markdown.index(after: cursor)
    }
    let content = markdown[start ..< cursor]
    if cursor < markdown.endIndex {
        cursor = markdown.index(after: cursor)
    }
    return TextLine(content: content, end: cursor)
}

private func isDelimiter(_ content: Substring, marker: String) -> Bool {
    var end = content.endIndex
    while end > content.startIndex {
        let previous = content.index(before: end)
        let character = content[previous]
        if character != " ", character != "\t" {
            break
        }
        end = previous
    }
    return String(content[..<end]) == marker
}

private func rewritingWikilinks(in markdown: String) -> String {
    var output = ""
    output.reserveCapacity(markdown.count)
    var index = markdown.startIndex
    var atLineStart = true
    while index < markdown.endIndex {
        if let end = verbatimEnd(in: markdown, at: index, atLineStart: atLineStart) {
            output.append(contentsOf: markdown[index ..< end])
            atLineStart = endsOnLineBreak(markdown, at: end)
            index = end
            continue
        }
        if let link = wikilink(in: markdown, at: index) {
            output.append(link.display)
            index = link.end
            atLineStart = false
            continue
        }
        let character = markdown[index]
        output.append(character)
        index = markdown.index(after: index)
        atLineStart = character.isNewline
    }
    return output
}

private func endsOnLineBreak(_ markdown: String, at end: String.Index) -> Bool {
    guard end > markdown.startIndex else {
        return true
    }
    return markdown[markdown.index(before: end)].isNewline
}

private func verbatimEnd(in markdown: String, at index: String.Index, atLineStart: Bool) -> String.Index? {
    if atLineStart, let end = fencedCodeEnd(in: markdown, from: index) {
        return end
    }
    if atLineStart, let end = calloutBlockEnd(in: markdown, from: index) {
        return end
    }
    if markdown[index] == "`", let end = inlineCodeEnd(in: markdown, from: index) {
        return end
    }
    return nil
}

private func calloutBlockEnd(in markdown: String, from start: String.Index) -> String.Index? {
    guard let content = blockquoteContentStart(in: markdown, at: start), startsCallout(in: markdown, at: content) else {
        return nil
    }
    var cursor = lineEnd(in: markdown, from: start)
    while cursor < markdown.endIndex, blockquoteContentStart(in: markdown, at: cursor) != nil {
        cursor = lineEnd(in: markdown, from: cursor)
    }
    return cursor
}

private func startsCallout(in markdown: String, at index: String.Index) -> Bool {
    guard index < markdown.endIndex, markdown[index] == "[" else {
        return false
    }
    let next = markdown.index(after: index)
    return next < markdown.endIndex && markdown[next] == "!"
}

/// Index of the callout body after the `>` markers, when this line is a block quote.
private func blockquoteContentStart(in markdown: String, at start: String.Index) -> String.Index? {
    var cursor = start
    var indent = 0
    while cursor < markdown.endIndex, markdown[cursor] == " ", indent < 3 {
        indent += 1
        cursor = markdown.index(after: cursor)
    }
    guard cursor < markdown.endIndex, markdown[cursor] == ">" else {
        return nil
    }
    while cursor < markdown.endIndex, markdown[cursor] == ">" {
        cursor = markdown.index(after: cursor)
        if cursor < markdown.endIndex, markdown[cursor] == " " {
            cursor = markdown.index(after: cursor)
        }
    }
    return cursor
}

private struct Wikilink {
    var display: String
    var end: String.Index
}

private func wikilink(in markdown: String, at start: String.Index) -> Wikilink? {
    guard markdown[start] == "[", !isEscaped(markdown, at: start), !isEmbedStart(markdown, at: start) else {
        return nil
    }
    let second = markdown.index(after: start)
    guard second < markdown.endIndex, markdown[second] == "[" else {
        return nil
    }
    let interiorStart = markdown.index(after: second)
    guard let close = closingWikilink(in: markdown, from: interiorStart) else {
        return nil
    }
    let interior = markdown[interiorStart ..< close.interiorEnd]
    return Wikilink(display: plainText(for: interior), end: close.end)
}

private struct WikilinkClose {
    var interiorEnd: String.Index
    var end: String.Index
}

private func closingWikilink(in markdown: String, from start: String.Index) -> WikilinkClose? {
    var cursor = start
    while cursor < markdown.endIndex {
        let character = markdown[cursor]
        if character.isNewline {
            return nil
        }
        if character == "\\" {
            cursor = skipEscaped(in: markdown, at: cursor)
            continue
        }
        if character == "]" {
            return doubledClose(in: markdown, at: cursor)
        }
        cursor = markdown.index(after: cursor)
    }
    return nil
}

private func skipEscaped(in markdown: String, at cursor: String.Index) -> String.Index {
    let next = markdown.index(after: cursor)
    guard next < markdown.endIndex else {
        return next
    }
    return markdown.index(after: next)
}

private func doubledClose(in markdown: String, at cursor: String.Index) -> WikilinkClose? {
    let after = markdown.index(after: cursor)
    guard after < markdown.endIndex, markdown[after] == "]" else {
        return nil
    }
    return WikilinkClose(interiorEnd: cursor, end: markdown.index(after: after))
}

private func plainText(for interior: Substring) -> String {
    if let pipe = interior.firstIndex(of: "|") {
        return trimmed(interior[interior.index(after: pipe)...])
    }
    let parts = interior.split(separator: "#", omittingEmptySubsequences: true).compactMap { part -> String? in
        let text = trimmed(part)
        return text.isEmpty ? nil : text
    }
    return parts.joined(separator: " > ")
}

private func trimmed(_ text: some StringProtocol) -> String {
    String(text.trimmingCharacters(in: .whitespaces))
}

private func isEmbedStart(_ markdown: String, at bracket: String.Index) -> Bool {
    guard bracket > markdown.startIndex else {
        return false
    }
    let previous = markdown.index(before: bracket)
    guard markdown[previous] == "!" else {
        return false
    }
    return !isEscaped(markdown, at: previous)
}

private func isEscaped(_ markdown: String, at index: String.Index) -> Bool {
    var count = 0
    var cursor = index
    while cursor > markdown.startIndex {
        let previous = markdown.index(before: cursor)
        guard markdown[previous] == "\\" else {
            break
        }
        count += 1
        cursor = previous
    }
    return !count.isMultiple(of: 2)
}

private struct FenceMark {
    var marker: Character
    var length: Int
}

private func fencedCodeEnd(in markdown: String, from start: String.Index) -> String.Index? {
    guard let fence = openingFence(in: markdown, at: start) else {
        return nil
    }
    var cursor = lineEnd(in: markdown, from: start)
    while cursor < markdown.endIndex {
        if closingFence(in: markdown, at: cursor, matching: fence) {
            return lineEnd(in: markdown, from: cursor)
        }
        cursor = lineEnd(in: markdown, from: cursor)
    }
    return markdown.endIndex
}

private func openingFence(in markdown: String, at start: String.Index) -> FenceMark? {
    let content = lineContentStart(in: markdown, at: start)
    guard content.index < markdown.endIndex else {
        return nil
    }
    let marker = markdown[content.index]
    guard marker == "`" || marker == "~" else {
        return nil
    }
    let length = runLength(of: marker, in: markdown, at: content.index)
    guard length >= 3, fenceInfoIsValid(in: markdown, marker: marker, from: content.index, length: length) else {
        return nil
    }
    return FenceMark(marker: marker, length: length)
}

private func fenceInfoIsValid(
    in markdown: String,
    marker: Character,
    from markStart: String.Index,
    length: Int,
) -> Bool {
    guard marker == "`" else {
        return true
    }
    let afterMark = markdown.index(markStart, offsetBy: length)
    let info = markdown[afterMark ..< newlineIndex(in: markdown, from: afterMark)]
    return !info.contains("`")
}

private func closingFence(in markdown: String, at start: String.Index, matching fence: FenceMark) -> Bool {
    let content = lineContentStart(in: markdown, at: start)
    guard content.indent <= 3, content.index < markdown.endIndex, markdown[content.index] == fence.marker else {
        return false
    }
    let length = runLength(of: fence.marker, in: markdown, at: content.index)
    guard length >= fence.length else {
        return false
    }
    let afterMark = markdown.index(content.index, offsetBy: length)
    let rest = markdown[afterMark ..< newlineIndex(in: markdown, from: afterMark)]
    return rest.allSatisfy(\.isWhitespace)
}

private func inlineCodeEnd(in markdown: String, from start: String.Index) -> String.Index? {
    let length = runLength(of: "`", in: markdown, at: start)
    guard length > 0 else {
        return nil
    }
    let contentStart = markdown.index(start, offsetBy: length)
    guard let closer = backtickRun(in: markdown, from: contentStart, length: length) else {
        return nil
    }
    return markdown.index(closer, offsetBy: length)
}

private func backtickRun(in markdown: String, from start: String.Index, length: Int) -> String.Index? {
    var cursor = start
    while cursor < markdown.endIndex {
        if markdown[cursor] == "`" {
            let run = runLength(of: "`", in: markdown, at: cursor)
            if run == length {
                return cursor
            }
            cursor = markdown.index(cursor, offsetBy: run)
            continue
        }
        cursor = markdown.index(after: cursor)
    }
    return nil
}

private struct LineContent {
    var index: String.Index
    var indent: Int
}

private func lineContentStart(in markdown: String, at start: String.Index) -> LineContent {
    var cursor = start
    var indent = 0
    while cursor < markdown.endIndex, markdown[cursor] == " ", indent < 3 {
        indent += 1
        cursor = markdown.index(after: cursor)
    }
    return LineContent(index: cursor, indent: indent)
}

private func newlineIndex(in markdown: String, from start: String.Index) -> String.Index {
    var cursor = start
    while cursor < markdown.endIndex, !markdown[cursor].isNewline {
        cursor = markdown.index(after: cursor)
    }
    return cursor
}

private func lineEnd(in markdown: String, from start: String.Index) -> String.Index {
    let newline = newlineIndex(in: markdown, from: start)
    guard newline < markdown.endIndex else {
        return newline
    }
    return markdown.index(after: newline)
}

private func runLength(of marker: Character, in markdown: String, at start: String.Index) -> Int {
    markdown[start...].prefix { $0 == marker }.count
}
