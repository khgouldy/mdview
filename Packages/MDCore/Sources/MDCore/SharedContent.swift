import Foundation

/// Why the share extension shows a message instead of text.
public enum SharedContentError: Error, Equatable, Sendable {
    /// No attachment has a type the reader can load.
    case nothingShared
    case empty
    case tooLarge(byteCount: Int)
    case binary
    case unreadable

    /// `appName` is `AppName.display`; MDCore never spells the product name.
    public func message(appName: String) -> String {
        switch self {
        case .nothingShared, .binary:
            "\(appName) shows Markdown and text files."
        case .empty:
            "Nothing to show."
        case .tooLarge:
            "This is too large to show here. \(appName) shows shared text up to \(SharedContent.limitDescription)."
        case .unreadable:
            "The shared item could not be read."
        }
    }
}

/// Shared text, checked and decoded, ready for the share extension's reader.
public struct SharedContent: Equatable, Sendable {
    /// Larger items are refused before they are decoded.
    public static let limitBytes = 5_000_000
    /// Larger text opens in Source only, which keeps the extension inside its memory budget.
    public static let sourceOnlyAboveBytes = 2_000_000
    /// `looksBinary` reads this many leading bytes.
    public static let binarySniffBytes = 8192
    public static let untitled = "Shared Text"

    public let text: String
    public let title: String
    public let isMarkdown: Bool
    public let byteCount: Int

    public init(text: String, title: String, isMarkdown: Bool, byteCount: Int) {
        self.text = text
        self.title = title
        self.isMarkdown = isMarkdown
        self.byteCount = byteCount
    }

    /// Rendered is offered only for Markdown at or under `sourceOnlyAboveBytes`.
    public var allowsRendered: Bool {
        isMarkdown && byteCount <= Self.sourceOnlyAboveBytes
    }

    /// The navigation title: the suggested file name, or "Shared Text" when there is none.
    public static func title(suggestedName: String?) -> String {
        guard let name = cleanedName(suggestedName) else {
            return untitled
        }
        return name
    }

    /// True for a Markdown extension and for a name without one (chat apps share nameless Markdown).
    /// False for plain text and every other extension.
    public static func isMarkdown(suggestedName: String?) -> Bool {
        guard let ext = pathExtension(of: suggestedName) else {
            return true
        }
        return MarkdownFileTypes.isMarkdown(pathExtension: ext) ?? false
    }

    /// The Markdown decision for a loaded item. The Markdown UTI always renders. Plain text, file URLs and
    /// data follow the name. Other `public.text` types (RTF, HTML) render only with a Markdown extension.
    public static func isMarkdown(kind: SharedItemKind, suggestedName: String?) -> Bool {
        switch kind {
        case .markdown:
            true
        case .plainText, .fileURL, .data:
            isMarkdown(suggestedName: suggestedName)
        case .text:
            pathExtension(of: suggestedName).flatMap(MarkdownFileTypes.isMarkdown(pathExtension:)) ?? false
        }
    }

    /// Hosts often drop the extension from `suggestedName` but keep it on the file they hand over.
    /// The file's name wins when it is the suggested name plus an extension. A nameless item stays nameless,
    /// because the system names its temporary files itself.
    public static func displayName(suggestedName: String?, fileName: String?) -> String? {
        guard let suggested = cleanedName(suggestedName) else {
            return nil
        }
        guard pathExtension(of: suggested) == nil,
              let file = cleanedName(fileName),
              pathExtension(of: file) != nil,
              (file as NSString).deletingPathExtension == suggested
        else {
            return suggested
        }
        return file
    }

    /// A NUL byte in the first `binarySniffBytes` means binary, except after a UTF-16 byte order mark.
    public static func looksBinary(_ data: Data) -> Bool {
        let head = data.prefix(binarySniffBytes)
        guard head.contains(0) else {
            return false
        }
        let bom = Array(head.prefix(2))
        return bom != [0xFF, 0xFE] && bom != [0xFE, 0xFF]
    }

    /// Checks size, then binary, then decodes with `TextDecoding`. Call it off the main actor.
    public static func make(
        data: Data,
        kind: SharedItemKind,
        suggestedName: String?,
    ) -> Result<SharedContent, SharedContentError> {
        if data.count > limitBytes {
            return .failure(.tooLarge(byteCount: data.count))
        }
        if looksBinary(data) {
            return .failure(.binary)
        }
        return checked(TextDecoding.decode(data), byteCount: data.count, kind: kind, suggestedName: suggestedName)
    }

    /// For hosts that share a `String`. The byte count is its UTF-8 length.
    public static func make(
        text: String,
        kind: SharedItemKind,
        suggestedName: String?,
    ) -> Result<SharedContent, SharedContentError> {
        let byteCount = text.utf8.count
        if byteCount > limitBytes {
            return .failure(.tooLarge(byteCount: byteCount))
        }
        if text.utf8.prefix(binarySniffBytes).contains(0) {
            return .failure(.binary)
        }
        return checked(text, byteCount: byteCount, kind: kind, suggestedName: suggestedName)
    }

    /// "5 MB", from `limitBytes`.
    static var limitDescription: String {
        "\(limitBytes / 1_000_000) MB"
    }

    private static func checked(
        _ text: String,
        byteCount: Int,
        kind: SharedItemKind,
        suggestedName: String?,
    ) -> Result<SharedContent, SharedContentError> {
        guard text.contains(where: { !$0.isWhitespace }) else {
            return .failure(.empty)
        }
        return .success(SharedContent(
            text: text,
            title: title(suggestedName: suggestedName),
            isMarkdown: isMarkdown(kind: kind, suggestedName: suggestedName),
            byteCount: byteCount,
        ))
    }

    /// The last path component, trimmed; nil when nothing is left.
    private static func cleanedName(_ name: String?) -> String? {
        guard let name else {
            return nil
        }
        let trimmed = (name as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The extension, or nil for none. "Meeting v2.0 notes" has none: a real extension has no spaces.
    private static func pathExtension(of name: String?) -> String? {
        guard let name = cleanedName(name) else {
            return nil
        }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty, !ext.contains(where: \.isWhitespace) else {
            return nil
        }
        return ext
    }
}
