import Foundation

/// The `x-mdview-task:` image URL that `TaskListPreprocessor` writes in place of a `[ ]` or `[x]` bracket.
public enum TaskMarker: Equatable, Sendable {
    case unchecked
    case checked

    public static let scheme = "x-mdview-task"

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else {
            return nil
        }
        switch url.absoluteString.dropFirst(Self.scheme.count + 1) {
        case "checked": self = .checked
        case "unchecked": self = .unchecked
        default: return nil
        }
    }

    public var isChecked: Bool {
        self == .checked
    }

    /// Accessibility label for the checkbox, also the image's alt text in the rewritten Markdown.
    public var label: String {
        isChecked ? "Done" : "Not done"
    }

    /// The Markdown image that replaces the bracket.
    public var markdown: String {
        "![\(label)](\(Self.scheme):\(isChecked ? "checked" : "unchecked"))"
    }
}
