import Foundation

/// Line-by-line Markdown walking for `SectionSplitter`: byte-level, so a 1 MB note scans in milliseconds.
enum MarkdownLines {
    /// Calls `body` with each line's UTF-8 offset and its bytes, without the `\n` or `\r\n` ending.
    static func forEach(in markdown: String, _ body: (_ offset: Int, _ line: UnsafeBufferPointer<UInt8>) -> Void) {
        var text = markdown
        text.withUTF8 { bytes in
            var start = 0
            while start < bytes.count {
                var end = start
                while end < bytes.count, bytes[end] != ASCII.newline {
                    end += 1
                }
                var contentEnd = end
                if contentEnd > start, bytes[contentEnd - 1] == ASCII.carriageReturn {
                    contentEnd -= 1
                }
                body(start, UnsafeBufferPointer(rebasing: bytes[start ..< contentEnd]))
                start = end + 1
            }
        }
    }

    /// The text between two UTF-8 offsets that fall on line starts or ends. No copy: offsetting a native string's
    /// UTF-8 view is constant time.
    static func slice(_ markdown: String, from start: Int, to end: Int) -> Substring {
        let utf8 = markdown.utf8
        let lower = utf8.index(utf8.startIndex, offsetBy: start)
        let upper = utf8.index(lower, offsetBy: end - start)
        return markdown[lower ..< upper]
    }

    static func isBlank(_ line: UnsafeBufferPointer<UInt8>) -> Bool {
        line.allSatisfy { $0 == ASCII.space || $0 == ASCII.tab }
    }
}

enum ASCII {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let hash = UInt8(ascii: "#")
    static let backtick = UInt8(ascii: "`")
    static let tilde = UInt8(ascii: "~")
    static let lessThan = UInt8(ascii: "<")
    static let greaterThan = UInt8(ascii: ">")
    static let openBracket = UInt8(ascii: "[")
}

/// Tracks whether a line is inside a fence, an HTML comment or a raw HTML block, per CommonMark's top-level rules.
struct BlockScanner {
    enum Kind: Equatable {
        case heading
        case other
        case insideBlock
    }

    private enum State {
        case none
        case fence(marker: UInt8, length: Int)
        case comment
        case raw(closing: [UInt8])
    }

    private static let rawTags: [[UInt8]] = ["pre", "script", "style", "textarea"].map { Array($0.utf8) }
    private static let commentOpen = Array("<!--".utf8)
    private static let commentClose = Array("-->".utf8)

    private var state = State.none

    var isInsideBlock: Bool {
        if case .none = state {
            return false
        }
        return true
    }

    /// Classifies one line (without its line ending) and advances the state.
    mutating func classify(_ line: UnsafeBufferPointer<UInt8>) -> Kind {
        if isInsideBlock {
            advanceInsideBlock(line)
            return .insideBlock
        }
        if Self.isATXHeading(line) {
            return .heading
        }
        openBlock(line)
        return .other
    }

    private mutating func advanceInsideBlock(_ line: UnsafeBufferPointer<UInt8>) {
        let closes = switch state {
        case let .fence(marker, length):
            Self.closesFence(line, marker: marker, length: length)
        case .comment:
            Self.contains(Self.commentClose, in: line, from: 0)
        case let .raw(closing):
            Self.contains(closing, in: line, from: 0)
        case .none:
            true
        }
        if closes {
            state = .none
        }
    }

    /// A fence, comment or raw block opens at up to three spaces of indent. One that closes on its own line doesn't.
    private mutating func openBlock(_ line: UnsafeBufferPointer<UInt8>) {
        let indent = Self.leadingSpaces(line)
        guard indent <= 3 else {
            return
        }
        if let fence = Self.fenceOpener(line, from: indent) {
            state = .fence(marker: fence.marker, length: fence.length)
            return
        }
        if Self.hasPrefix(Self.commentOpen, in: line, at: indent) {
            if !Self.contains(Self.commentClose, in: line, from: indent + Self.commentOpen.count) {
                state = .comment
            }
            return
        }
        guard let closing = Self.rawBlockClosing(line, at: indent) else {
            return
        }
        if !Self.contains(closing, in: line, from: indent) {
            state = .raw(closing: closing)
        }
    }

    /// One to six `#` at column 0, then a space or tab.
    private static func isATXHeading(_ line: UnsafeBufferPointer<UInt8>) -> Bool {
        let count = run(of: ASCII.hash, in: line, from: 0)
        guard (1 ... 6).contains(count), count < line.count else {
            return false
        }
        return line[count] == ASCII.space || line[count] == ASCII.tab
    }

    private static func leadingSpaces(_ line: UnsafeBufferPointer<UInt8>) -> Int {
        run(of: ASCII.space, in: line, from: 0)
    }

    private static func run(of marker: UInt8, in line: UnsafeBufferPointer<UInt8>, from start: Int) -> Int {
        var end = start
        while end < line.count, line[end] == marker {
            end += 1
        }
        return end - start
    }

    /// Three or more backticks or tildes. A backtick fence's info string may not contain a backtick.
    private static func fenceOpener(
        _ line: UnsafeBufferPointer<UInt8>,
        from start: Int,
    ) -> (marker: UInt8, length: Int)? {
        guard start < line.count, line[start] == ASCII.backtick || line[start] == ASCII.tilde else {
            return nil
        }
        let marker = line[start]
        let length = run(of: marker, in: line, from: start)
        guard length >= 3 else {
            return nil
        }
        if marker == ASCII.backtick, line[(start + length)...].contains(ASCII.backtick) {
            return nil
        }
        return (marker, length)
    }

    /// Up to three spaces, at least `length` of the same marker, then only spaces or tabs.
    private static func closesFence(_ line: UnsafeBufferPointer<UInt8>, marker: UInt8, length: Int) -> Bool {
        let indent = leadingSpaces(line)
        guard indent <= 3 else {
            return false
        }
        let count = run(of: marker, in: line, from: indent)
        guard count >= length else {
            return false
        }
        return line[(indent + count)...].allSatisfy { $0 == ASCII.space || $0 == ASCII.tab }
    }

    /// For `<pre`, `<script`, `<style` or `<textarea` (any case) followed by a space, tab, `>` or the line end,
    /// the lowercased closing tag that ends the block.
    private static func rawBlockClosing(_ line: UnsafeBufferPointer<UInt8>, at start: Int) -> [UInt8]? {
        guard start < line.count, line[start] == ASCII.lessThan else {
            return nil
        }
        for tag in rawTags where hasPrefix(tag, in: line, at: start + 1) {
            let after = start + 1 + tag.count
            if after == line.count || [ASCII.space, ASCII.tab, ASCII.greaterThan].contains(line[after]) {
                return Array("</".utf8) + tag + [ASCII.greaterThan]
            }
        }
        return nil
    }

    /// Case-insensitive for ASCII letters; `needle` is lowercase.
    private static func hasPrefix(_ needle: [UInt8], in line: UnsafeBufferPointer<UInt8>, at start: Int) -> Bool {
        guard start >= 0, start + needle.count <= line.count else {
            return false
        }
        for (offset, byte) in needle.enumerated() where lowercased(line[start + offset]) != byte {
            return false
        }
        return true
    }

    private static func contains(_ needle: [UInt8], in line: UnsafeBufferPointer<UInt8>, from start: Int) -> Bool {
        guard start + needle.count <= line.count else {
            return false
        }
        for position in start ... (line.count - needle.count) where hasPrefix(needle, in: line, at: position) {
            return true
        }
        return false
    }

    private static func lowercased(_ byte: UInt8) -> UInt8 {
        (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(byte) ? byte + 32 : byte
    }
}
