import Foundation

/// The five GitHub alert kinds. Obsidian's callout types map onto them.
public enum CalloutKind: String, CaseIterable, Equatable, Sendable {
    case note
    case tip
    case important
    case warning
    case caution

    /// The title a callout shows when it has none of its own: "Note", "Tip", and so on.
    public var title: String {
        rawValue.capitalized
    }

    /// The kind for a `[!type]` marker, case-insensitive. GitHub's five always count; Obsidian's other types only
    /// when `obsidian` is on. Obsidian's `caution` is a warning there, but GitHub's own `CAUTION` wins here.
    public static func kind(forType type: String, obsidian: Bool) -> CalloutKind? {
        let name = type.lowercased()
        if let kind = CalloutKind(rawValue: name) {
            return kind
        }
        guard obsidian else {
            return nil
        }
        return obsidianTypes[name]
    }

    private static let obsidianTypes: [String: CalloutKind] = [
        "info": .note, "todo": .note, "abstract": .note, "summary": .note, "tldr": .note,
        "example": .note, "quote": .note, "cite": .note,
        "success": .tip, "check": .tip, "done": .tip, "hint": .tip,
        "question": .important, "help": .important, "faq": .important,
        "attention": .warning,
        "danger": .caution, "error": .caution, "bug": .caution, "failure": .caution, "fail": .caution,
        "missing": .caution,
    ]
}

/// The `x-mdview-callout:` image URL that `CalloutPreprocessor` writes before a callout's title. The reader draws it
/// as the kind's symbol and styles the enclosing block quote as a callout.
public enum CalloutMarker {
    public static let scheme = "x-mdview-callout"

    public static func kind(of url: URL) -> CalloutKind? {
        guard url.scheme?.lowercased() == scheme else {
            return nil
        }
        return CalloutKind(rawValue: String(url.absoluteString.dropFirst(scheme.count + 1)))
    }

    /// The title paragraph: the marker image, then the title in bold.
    public static func markdown(kind: CalloutKind, title: String) -> String {
        "![\(kind.title)](\(scheme):\(kind.rawValue)) **\(title)**"
    }
}

/// GitHub alerts (`> [!NOTE]`) and Obsidian callouts (`> [!info] Title`): the marker line of a block quote becomes
/// a title paragraph that starts with an `x-mdview-callout:` image, and the rest of the quote stays as written.
/// Fold markers (`[!tip]-`, `[!tip]+`) are dropped; the callout is always open. Unknown types, nested quotes, and
/// anything in fenced code are left alone.
public enum CalloutPreprocessor {
    public static func process(_ markdown: String, obsidian: Bool) -> String {
        guard markdown.contains("[!") else {
            return markdown
        }
        // Foundation splits on the UTF-16 "\n", so a CRLF line keeps its "\r" (Swift's split sees "\r\n" as one
        // character).
        var lines = markdown.components(separatedBy: "\n")
        var fence: (marker: Character, length: Int)?
        var previousWasQuote = false
        var index = 0
        while index < lines.count {
            let line = lines[index]
            defer { index += 1 }
            if let open = fence {
                if closesFence(line, open) {
                    fence = nil
                }
                previousWasQuote = false
                continue
            }
            if let opening = openingFence(of: line) {
                fence = opening
                previousWasQuote = false
                continue
            }
            let isQuote = quoteContent(of: line) != nil
            defer { previousWasQuote = isQuote }
            guard !previousWasQuote, let callout = Callout(line: line, obsidian: obsidian) else {
                continue
            }
            let ending = line.hasSuffix("\r") ? "\r" : ""
            lines[index] = callout.titleLine + ending
            let next = index + 1 < lines.count ? lines[index + 1] : nil
            if let next, quoteContent(of: next) != nil, !isBlankQuote(next) {
                // An empty quote line ends the title paragraph, so the body starts a paragraph of its own.
                lines.insert(callout.prefix + ending, at: index + 1)
                index += 1
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The text after `>` and one optional space, when the line is a block quote line (up to three spaces of indent).
    static func quoteContent(of line: String) -> Substring? {
        let body = line.drop { $0 == " " }
        guard line.count - body.count <= 3, body.first == ">" else {
            return nil
        }
        let rest = body.dropFirst()
        return rest.first == " " || rest.first == "\t" ? rest.dropFirst() : rest
    }

    private static func isBlankQuote(_ line: String) -> Bool {
        quoteContent(of: line)?.allSatisfy(\.isWhitespace) ?? false
    }

    private static func openingFence(of line: String) -> (marker: Character, length: Int)? {
        let body = line.drop { $0 == " " }
        guard line.count - body.count <= 3, let marker = body.first, marker == "`" || marker == "~" else {
            return nil
        }
        let length = body.prefix { $0 == marker }.count
        guard length >= 3 else {
            return nil
        }
        if marker == "`", body.dropFirst(length).contains("`") {
            return nil
        }
        return (marker, length)
    }

    private static func closesFence(_ line: String, _ open: (marker: Character, length: Int)) -> Bool {
        let body = line.drop { $0 == " " }
        let length = body.prefix { $0 == open.marker }.count
        guard length >= open.length, line.count - body.count <= 3 else {
            return false
        }
        return body.dropFirst(length).allSatisfy(\.isWhitespace)
    }
}

/// One `> [!type][+-] Title` line.
struct Callout: Equatable {
    var kind: CalloutKind
    var title: String
    /// The indent and `>` the title line keeps.
    var prefix: String

    init?(line: String, obsidian: Bool) {
        let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
        guard let content = CalloutPreprocessor.quoteContent(of: trimmed), content.hasPrefix("[!") else {
            return nil
        }
        let afterOpen = content.dropFirst(2)
        guard let close = afterOpen.firstIndex(of: "]") else {
            return nil
        }
        let type = afterOpen[..<close]
        guard !type.isEmpty, type.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
              let kind = CalloutKind.kind(forType: String(type), obsidian: obsidian)
        else {
            return nil
        }
        var rest = afterOpen[afterOpen.index(after: close)...]
        if rest.first == "+" || rest.first == "-" {
            rest = rest.dropFirst()
        }
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else {
            return nil
        }
        let custom = rest.trimmingCharacters(in: .whitespaces)
        self.kind = kind
        title = custom.isEmpty ? Self.defaultTitle(type: String(type), kind: kind) : custom
        let body = trimmed.drop { $0 == " " }
        prefix = String(trimmed.prefix(trimmed.count - body.count)) + ">"
    }

    /// GitHub's kinds read "Note", "Tip"; an Obsidian type reads as itself ("Info", "Faq"), as Obsidian shows it.
    private static func defaultTitle(type: String, kind: CalloutKind) -> String {
        type.lowercased() == kind.rawValue ? kind.title : type.prefix(1).uppercased() + type.dropFirst().lowercased()
    }

    var titleLine: String {
        prefix + " " + CalloutMarker.markdown(kind: kind, title: title)
    }
}
