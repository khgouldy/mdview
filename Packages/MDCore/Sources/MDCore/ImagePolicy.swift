import Foundation

public enum ImagePolicy {
    /// True only for `file:` URLs. Every other scheme stays out of the image loader.
    public static func allows(_ url: URL) -> Bool {
        url.isFileURL
    }
}
