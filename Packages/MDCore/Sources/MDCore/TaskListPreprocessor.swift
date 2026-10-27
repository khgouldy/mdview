import Foundation

/// Foundation's parser has no task lists, so a list item's leading `[ ]`, `[x]` or `[X]` becomes an image
/// with the `x-mdview-task:` scheme. The reader draws that image as a read-only checkbox.
public enum TaskListPreprocessor {
    public static func process(_ markdown: String) -> String {
        guard markdown.contains("[") else {
            return markdown
        }
        var output = ""
        output.reserveCapacity(markdown.count)
        var state = ScanState()
        var start = markdown.startIndex
        while start < markdown.endIndex {
            let newline = markdown[start...].firstIndex(where: \.isNewline) ?? markdown.endIndex
            let next = newline < markdown.endIndex ? markdown.index(after: newline) : newline
            let line = markdown[start ..< newline]
            output += state.consume(line)
            output += markdown[newline ..< next]
            start = next
        }
        return output
    }
}

private struct ScanState {
    private var fence: Fence?
    private var previousBlank = true
    private var inList = false
    private var inIndentedCode = false

    private struct Fence {
        var marker: Character
        var length: Int
    }

    /// Returns the line, rewritten when it is a task item outside code.
    mutating func consume(_ line: Substring) -> String {
        if let open = fence {
            if closes(line, open) {
                fence = nil
            }
            return String(line)
        }
        let blank = line.allSatisfy { $0 == " " || $0 == "\t" }
        defer { previousBlank = blank }
        if blank {
            return String(line)
        }
        let indent = indentWidth(of: line)
        if inIndentedCode, indent >= 4 {
            return String(line)
        }
        inIndentedCode = false
        if indent >= 4, previousBlank, !inList {
            inIndentedCode = true
            return String(line)
        }
        if indent < 4, let opening = openingFence(of: line) {
            fence = opening
            return String(line)
        }
        if ListItem.hasBullet(line) {
            inList = true
            return ListItem(line)?.rewritten() ?? String(line)
        }
        if indent == 0, previousBlank {
            inList = false
        }
        return String(line)
    }

    private func indentWidth(of line: Substring) -> Int {
        var width = 0
        for character in line {
            if character == " " {
                width += 1
            } else if character == "\t" {
                width += 4 - width % 4
            } else {
                break
            }
        }
        return width
    }

    private func openingFence(of line: Substring) -> Fence? {
        let body = line.drop { $0 == " " }
        guard let marker = body.first, marker == "`" || marker == "~" else {
            return nil
        }
        let length = body.prefix { $0 == marker }.count
        guard length >= 3 else {
            return nil
        }
        if marker == "`", body.dropFirst(length).contains("`") {
            return nil
        }
        return Fence(marker: marker, length: length)
    }

    private func closes(_ line: Substring, _ open: Fence) -> Bool {
        let body = line.drop { $0 == " " }
        let length = body.prefix { $0 == open.marker }.count
        guard length >= open.length, line.count - body.count <= 3 else {
            return false
        }
        return body.dropFirst(length).allSatisfy { $0 == " " || $0 == "\t" }
    }
}

/// A list item line whose content starts with a task bracket.
private struct ListItem {
    var prefix: Substring
    var marker: TaskMarker
    var rest: Substring

    init?(_ line: Substring) {
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        cursor = Self.skipBullet(in: line, from: cursor) ?? cursor
        guard cursor > line.startIndex, line[..<cursor].contains(where: { $0 != " " && $0 != "\t" }) else {
            return nil
        }
        let spacesStart = cursor
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        guard cursor > spacesStart else {
            return nil
        }
        let bracket = line[cursor...]
        guard bracket.count >= 3, bracket.first == "[", bracket[bracket.index(bracket.startIndex, offsetBy: 2)] == "]"
        else {
            return nil
        }
        switch bracket[bracket.index(after: bracket.startIndex)] {
        case " ": marker = .unchecked
        case "x", "X": marker = .checked
        default: return nil
        }
        let after = bracket.dropFirst(3)
        guard after.isEmpty || after.first == " " || after.first == "\t" else {
            return nil
        }
        prefix = line[..<cursor]
        rest = after
    }

    static func hasBullet(_ line: Substring) -> Bool {
        let start = line.firstIndex { $0 != " " && $0 != "\t" } ?? line.endIndex
        guard let end = skipBullet(in: line, from: start) else {
            return false
        }
        return end == line.endIndex || line[end] == " " || line[end] == "\t"
    }

    func rewritten() -> String {
        prefix + marker.markdown + rest
    }

    /// Index after `-`, `*`, `+`, `1.` or `1)`, or nil when the line has no bullet at `start`.
    private static func skipBullet(in line: Substring, from start: String.Index) -> String.Index? {
        guard start < line.endIndex else {
            return nil
        }
        if "-*+".contains(line[start]) {
            return line.index(after: start)
        }
        var cursor = start
        var digits = 0
        while cursor < line.endIndex, line[cursor].isASCII, line[cursor].isNumber {
            digits += 1
            cursor = line.index(after: cursor)
        }
        guard (1 ... 9).contains(digits), cursor < line.endIndex, line[cursor] == "." || line[cursor] == ")" else {
            return nil
        }
        return line.index(after: cursor)
    }
}
