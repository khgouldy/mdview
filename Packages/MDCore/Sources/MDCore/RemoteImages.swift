import Foundation

public enum RemoteImages {
    /// `![alt](http(s)://…)` outside code becomes `[Image: alt](http(s)://…)`.
    public static func linkify(_ markdown: String) -> String {
        segments(of: markdown)
            .map { segment in
                segment.isCode ? segment.text : rewriteRemoteImages(in: segment.text)
            }
            .joined()
    }
}

private struct MarkdownSegment {
    var isCode: Bool
    var text: String
}

private func segments(of markdown: String) -> [MarkdownSegment] {
    var parts: [MarkdownSegment] = []
    var prose = ""
    var index = markdown.startIndex
    var atLineStart = true

    func flushProse() {
        guard !prose.isEmpty else {
            return
        }
        parts.append(MarkdownSegment(isCode: false, text: prose))
        prose = ""
    }

    while index < markdown.endIndex {
        if atLineStart, let end = fencedCodeEnd(in: markdown, from: index) {
            flushProse()
            parts.append(MarkdownSegment(isCode: true, text: String(markdown[index ..< end])))
            index = end
            atLineStart = true
            continue
        }
        if markdown[index] == "`", let end = inlineCodeEnd(in: markdown, from: index) {
            flushProse()
            parts.append(MarkdownSegment(isCode: true, text: String(markdown[index ..< end])))
            index = end
            atLineStart = false
            continue
        }
        let character = markdown[index]
        prose.append(character)
        index = markdown.index(after: index)
        atLineStart = character == "\n"
    }
    flushProse()
    return parts
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

private struct FenceMark {
    var marker: Character
    var length: Int
}

private func openingFence(in markdown: String, at start: String.Index) -> FenceMark? {
    let content = lineContentStart(in: markdown, at: start, maxIndent: 3)
    guard content.index < markdown.endIndex else {
        return nil
    }
    let marker = markdown[content.index]
    guard marker == "`" || marker == "~" else {
        return nil
    }
    let length = runLength(of: marker, in: markdown, at: content.index)
    guard length >= 3 else {
        return nil
    }
    let afterMark = markdown.index(content.index, offsetBy: length)
    let info = markdown[afterMark ..< newlineIndex(in: markdown, from: afterMark)]
    if marker == "`", info.contains("`") {
        return nil
    }
    return FenceMark(marker: marker, length: length)
}

private func closingFence(in markdown: String, at start: String.Index, matching fence: FenceMark) -> Bool {
    let content = lineContentStart(in: markdown, at: start, maxIndent: 3)
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

private struct ImageSyntax {
    var alt: String
    var destination: String
    var end: String.Index
}

private func rewriteRemoteImages(in prose: String) -> String {
    var output = ""
    var index = prose.startIndex
    while index < prose.endIndex {
        if let image = remoteImage(in: prose, at: index) {
            output.append(imageLink(alt: image.alt, destination: image.destination))
            index = image.end
            continue
        }
        output.append(prose[index])
        index = prose.index(after: index)
    }
    return output
}

private func remoteImage(in markdown: String, at start: String.Index) -> ImageSyntax? {
    guard markdown[start] == "!", !isEscaped(markdown, at: start), let image = imageSyntax(in: markdown, at: start),
          isRemoteHTTP(image.destination)
    else {
        return nil
    }
    return image
}

private func imageSyntax(in markdown: String, at start: String.Index) -> ImageSyntax? {
    var cursor = markdown.index(after: start)
    guard cursor < markdown.endIndex, markdown[cursor] == "[" else {
        return nil
    }
    cursor = markdown.index(after: cursor)
    guard let altEnd = closingBracket(in: markdown, from: cursor) else {
        return nil
    }
    let alt = String(markdown[cursor ..< altEnd.index])
    cursor = altEnd.after
    guard cursor < markdown.endIndex, markdown[cursor] == "(" else {
        return nil
    }
    cursor = markdown.index(after: cursor)
    cursor = skipWhitespace(in: markdown, from: cursor)
    guard let destination = destination(in: markdown, from: &cursor) else {
        return nil
    }
    cursor = skipWhitespace(in: markdown, from: cursor)
    if let quote = quoteMarker(in: markdown, at: cursor) {
        guard let afterTitle = endOfTitle(in: markdown, from: markdown.index(after: cursor), quote: quote) else {
            return nil
        }
        cursor = skipWhitespace(in: markdown, from: afterTitle)
    }
    guard cursor < markdown.endIndex, markdown[cursor] == ")" else {
        return nil
    }
    return ImageSyntax(
        alt: alt,
        destination: destination,
        end: markdown.index(after: cursor),
    )
}

private struct BracketEnd {
    var index: String.Index
    var after: String.Index
}

private func closingBracket(in markdown: String, from start: String.Index) -> BracketEnd? {
    var depth = 1
    var cursor = start
    while cursor < markdown.endIndex {
        let character = markdown[cursor]
        if character == "\\" {
            cursor = markdown.index(after: cursor)
            if cursor < markdown.endIndex {
                cursor = markdown.index(after: cursor)
            }
            continue
        }
        if character == "[" {
            depth += 1
        } else if character == "]" {
            depth -= 1
            if depth == 0 {
                return BracketEnd(index: cursor, after: markdown.index(after: cursor))
            }
        }
        cursor = markdown.index(after: cursor)
    }
    return nil
}

private func destination(in markdown: String, from cursor: inout String.Index) -> String? {
    guard cursor < markdown.endIndex else {
        return nil
    }
    if markdown[cursor] == "<" {
        return angleDestination(in: markdown, from: &cursor)
    }
    return bareDestination(in: markdown, from: &cursor)
}

private func angleDestination(in markdown: String, from cursor: inout String.Index) -> String? {
    cursor = markdown.index(after: cursor)
    var value = ""
    while cursor < markdown.endIndex, markdown[cursor] != ">" {
        if markdown[cursor].isNewline {
            return nil
        }
        value.append(markdown[cursor])
        cursor = markdown.index(after: cursor)
    }
    guard cursor < markdown.endIndex else {
        return nil
    }
    cursor = markdown.index(after: cursor)
    return value
}

private func bareDestination(in markdown: String, from cursor: inout String.Index) -> String? {
    var value = ""
    var depth = 0
    while cursor < markdown.endIndex {
        if appendBareCharacter(markdown, cursor: &cursor, value: &value, depth: &depth) == false {
            break
        }
    }
    guard !value.isEmpty else {
        return nil
    }
    return value
}

private func appendBareCharacter(
    _ markdown: String,
    cursor: inout String.Index,
    value: inout String,
    depth: inout Int,
) -> Bool {
    let character = markdown[cursor]
    if character == "\\" {
        cursor = markdown.index(after: cursor)
        if cursor < markdown.endIndex {
            value.append(markdown[cursor])
            cursor = markdown.index(after: cursor)
        }
        return true
    }
    if character.isWhitespace {
        return false
    }
    if character == "(" {
        depth += 1
    } else if character == ")", depth == 0 {
        return false
    } else if character == ")" {
        depth -= 1
    }
    value.append(character)
    cursor = markdown.index(after: cursor)
    return true
}

private func endOfTitle(in markdown: String, from start: String.Index, quote: Character) -> String.Index? {
    var cursor = start
    while cursor < markdown.endIndex {
        if markdown[cursor] == "\\" {
            cursor = markdown.index(after: cursor)
            if cursor < markdown.endIndex {
                cursor = markdown.index(after: cursor)
            }
            continue
        }
        if markdown[cursor] == quote {
            return markdown.index(after: cursor)
        }
        cursor = markdown.index(after: cursor)
    }
    return nil
}

private func quoteMarker(in markdown: String, at index: String.Index) -> Character? {
    guard index < markdown.endIndex else {
        return nil
    }
    switch markdown[index] {
    case "\"", "'":
        return markdown[index]
    default:
        return nil
    }
}

private func imageLink(alt: String, destination: String) -> String {
    "[Image: \(escapedAlt(alt))](\(destination))"
}

private func escapedAlt(_ alt: String) -> String {
    var escaped = ""
    escaped.reserveCapacity(alt.count)
    for character in alt {
        if character == "\\" || character == "[" || character == "]" {
            escaped.append("\\")
        }
        escaped.append(character)
    }
    return escaped
}

private func isRemoteHTTP(_ destination: String) -> Bool {
    let scheme = destination.lowercased()
    return scheme.hasPrefix("http://") || scheme.hasPrefix("https://")
}

private func isEscaped(_ markdown: String, at index: String.Index) -> Bool {
    var count = 0
    var cursor = index
    while cursor > markdown.startIndex, markdown[markdown.index(before: cursor)] == "\\" {
        count += 1
        cursor = markdown.index(before: cursor)
    }
    return !count.isMultiple(of: 2)
}

private func skipWhitespace(in markdown: String, from start: String.Index) -> String.Index {
    markdown[start...].firstIndex { !$0.isWhitespace } ?? markdown.endIndex
}

private struct LineContent {
    var index: String.Index
    var indent: Int
}

private func lineContentStart(in markdown: String, at start: String.Index, maxIndent: Int) -> LineContent {
    var cursor = start
    var indent = 0
    while cursor < markdown.endIndex, markdown[cursor] == " ", indent < maxIndent {
        indent += 1
        cursor = markdown.index(after: cursor)
    }
    return LineContent(index: cursor, indent: indent)
}

private func newlineIndex(in markdown: String, from start: String.Index) -> String.Index {
    markdown[start...].firstIndex(of: "\n") ?? markdown.endIndex
}

private func lineEnd(in markdown: String, from start: String.Index) -> String.Index {
    let newline = newlineIndex(in: markdown, from: start)
    return newline < markdown.endIndex ? markdown.index(after: newline) : newline
}

private func runLength(of marker: Character, in markdown: String, at start: String.Index) -> Int {
    markdown[start...].prefix { $0 == marker }.count
}
