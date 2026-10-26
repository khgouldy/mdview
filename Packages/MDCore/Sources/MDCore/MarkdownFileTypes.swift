import Foundation

public enum MarkdownFileTypes {
    /// BEGIN markdownExtensions
    public static let markdownExtensions = ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdtxt", "mdtext"]
    // END markdownExtensions

    public static let plainTextExtensions = ["txt", "text"]

    public static let markdownMIMETypes = ["text/markdown", "text/x-markdown"]

    /// True for Markdown extensions, false for plain text, nil when the extension says nothing.
    public static func isMarkdown(pathExtension: String) -> Bool? {
        let ext = pathExtension.lowercased()
        if markdownExtensions.contains(ext) {
            return true
        }
        if plainTextExtensions.contains(ext) {
            return false
        }
        return nil
    }
}
