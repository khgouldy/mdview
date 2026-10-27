import Foundation

/// The one entry point that turns stored Markdown into the string Textual draws.
public enum RenderPipeline {
    /// Obsidian extras (when on), then remote images become links. `math` is reserved and ignored.
    public static func prepare(_ markdown: String, obsidian: Bool, math _: Bool = false) -> String {
        let source = obsidian ? ObsidianPreprocessor.process(markdown) : markdown
        return RemoteImages.linkify(source)
    }
}
