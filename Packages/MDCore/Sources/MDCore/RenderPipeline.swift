import Foundation

/// The one entry point that turns stored Markdown into the string Textual draws.
public enum RenderPipeline {
    /// Obsidian extras (when on), then callouts get their title paragraph, then LaTeX delimiters become `$` ones
    /// (when `math` is on), then task items become checkbox images, then remote images become links.
    public static func prepare(_ markdown: String, obsidian: Bool, math: Bool = false) -> String {
        let extras = obsidian ? ObsidianPreprocessor.process(markdown) : markdown
        let source = CalloutPreprocessor.process(extras, obsidian: obsidian)
        let delimited = math ? MathDelimiters.convert(source) : source
        return RemoteImages.linkify(TaskListPreprocessor.process(delimited))
    }
}
