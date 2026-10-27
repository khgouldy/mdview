import Foundation

/// Textual's math syntax reads `$…$` and `$$…$$`. LaTeX's own `\(…\)` and `\[…\]` become those, outside fenced and
/// indented code and outside code spans. A backslash that is itself escaped (`\\(`) and a delimiter with no closing
/// partner in the same paragraph are left alone. The reader runs this only when the Math toggle is on.
public enum MathDelimiters {
    public static func convert(_ markdown: String) -> String {
        guard markdown.contains("\\(") || markdown.contains("\\[") else {
            return markdown
        }
        var output = ""
        output.reserveCapacity(markdown.count)
        var state = CodeState()
        var chunk = ""
        func flush() {
            output += convertInline(chunk)
            chunk = ""
        }
        var start = markdown.startIndex
        while start < markdown.endIndex {
            let newline = markdown[start...].firstIndex(where: \.isNewline) ?? markdown.endIndex
            let next = newline < markdown.endIndex ? markdown.index(after: newline) : newline
            let line = markdown[start ..< newline]
            if state.isCode(line) {
                flush()
                output += markdown[start ..< next]
            } else {
                chunk += markdown[start ..< next]
            }
            start = next
        }
        flush()
        return output
    }

    /// Scans prose (no fences, no indented code) for code spans and math delimiters.
    private static func convertInline(_ text: String) -> String {
        let chars = Array(text)
        var output = ""
        var index = 0
        // A search that failed once fails for every later start in the same stretch, so remember it. Without this a
        // run of unmatched `\(` or backticks rescans to the paragraph end each time (quadratic).
        var failedDelimiter: [Character: Int] = [:]
        var failedRuns: Set<Int> = []
        while index < chars.count {
            let char = chars[index]
            if char == "`" {
                let run = backtickRun(chars, at: index)
                output += String(chars[index ..< min(index + run, chars.count)])
                index += run
                if !failedRuns.contains(run) {
                    if let close = closingRun(chars, from: index, length: run) {
                        output += String(chars[index ..< close + run])
                        index = close + run
                    } else {
                        failedRuns.insert(run)
                    }
                }
            } else if char == "\\", index + 1 < chars.count {
                let next = chars[index + 1]
                let skip = (failedDelimiter[next] ?? 0) > index
                let close = (next == "(" || next == "[") && !skip
                    ? closingDelimiter(chars, from: index + 2, kind: next) : nil
                if let close = close?.found {
                    output += rewrite(chars[index + 2 ..< close], display: next == "[")
                    index = close + 2
                } else {
                    if let stop = close?.stop {
                        failedDelimiter[next] = stop
                    }
                    output += String(chars[index ... index + 1])
                    index += 2
                }
            } else {
                output.append(char)
                index += 1
            }
        }
        return output
    }

    private static func rewrite(_ body: ArraySlice<Character>, display: Bool) -> String {
        var content = String(body)
        if !content.contains(where: \.isNewline) {
            content = content.trimmingCharacters(in: .whitespaces)
        }
        let fence = display ? "$$" : "$"
        return fence + content + fence
    }

    private static func backtickRun(_ chars: [Character], at start: Int) -> Int {
        var end = start
        while end < chars.count, chars[end] == "`" {
            end += 1
        }
        return end - start
    }

    /// The index of the next backtick run of exactly `length`, or nil when the span never closes.
    private static func closingRun(_ chars: [Character], from start: Int, length: Int) -> Int? {
        var index = start
        while index < chars.count {
            if chars[index] == "`" {
                let run = backtickRun(chars, at: index)
                if run == length {
                    return index
                }
                index += run
            } else {
                index += 1
            }
        }
        return nil
    }

    /// The index of the backslash that closes `\(` or `\[`, searched up to the end of the paragraph.
    /// `found` is the closing backslash; when there is none, `stop` is where the search gave up.
    private static func closingDelimiter(
        _ chars: [Character],
        from start: Int,
        kind: Character,
    ) -> (found: Int?, stop: Int) {
        let close: Character = kind == "(" ? ")" : "]"
        var index = start
        var lineBreaks = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\\" {
                if index + 1 < chars.count, chars[index + 1] == close {
                    return (index > start ? index : nil, index)
                }
                index += 2
                lineBreaks = 0
                continue
            }
            if char.isNewline {
                lineBreaks += 1
                if lineBreaks == 2 {
                    return (nil, index)
                }
            } else if char != " ", char != "\t" {
                lineBreaks = 0
            }
            index += 1
        }
        return (nil, chars.count)
    }
}

/// Tracks fenced and indented code across lines.
private struct CodeState {
    private var fence: (marker: Character, length: Int)?
    private var previousBlank = true
    private var inIndented = false
    private var inList = false

    /// True when `line` belongs to code, so math in it is left alone.
    mutating func isCode(_ line: Substring) -> Bool {
        if let open = fence {
            let body = line.drop { $0 == " " }
            let length = body.prefix { $0 == open.marker }.count
            let tail = body.dropFirst(length)
            let closes = length >= open.length && line.count - body.count <= 3
            if closes, tail.allSatisfy({ $0 == " " || $0 == "\t" }) {
                fence = nil
            }
            return true
        }
        let blank = line.allSatisfy { $0 == " " || $0 == "\t" }
        defer { previousBlank = blank }
        if blank {
            return inIndented
        }
        let indent = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
        if inIndented, indent >= 4 {
            return true
        }
        inIndented = false
        if indent >= 4, previousBlank, !inList {
            inIndented = true
            return true
        }
        let body = line.drop { $0 == " " }
        if indent < 4, let marker = body.first, marker == "`" || marker == "~" {
            let length = body.prefix { $0 == marker }.count
            if length >= 3, !(marker == "`" && body.dropFirst(length).contains("`")) {
                fence = (marker, length)
                return true
            }
        }
        let bullets = ["- ", "* ", "+ "]
        if bullets.contains(where: { body.hasPrefix($0) }) || body.first?.isNumber == true {
            inList = true
        } else if indent == 0, previousBlank {
            inList = false
        }
        return false
    }
}
