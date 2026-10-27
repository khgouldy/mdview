import MDCore
import SwiftUI
import Textual

/// GitHub-styled Markdown. Textual parses, lays out, and highlights code. Remote images are links.
struct RenderedView: View {
    let markdown: String
    var baseDirectory: URL?

    /// Wide enough for a reading column on iPad. Phones are narrower, so the cap does not bind.
    private static let readableWidth: CGFloat = 680

    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @State private var trace = RenderTrace()

    var body: some View {
        let displayed = markdownForDisplay
        trace.beginParse()
        return ScrollView {
            StructuredText(markdown: displayed)
                .font(.body)
                .textual.structuredTextStyle(.gitHub)
                .textual.highlighterTheme(.default)
                .textual.textSelection(.enabled)
                .textual.imageAttachmentLoader(LocalImageLoader(baseDirectory: baseDirectory))
                .frame(maxWidth: Self.readableWidth, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
                .onAppear { trace.beginLayout() }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if height > 0 {
                        trace.finish()
                    }
                }
        }
    }

    /// Front matter and wikilinks change only when Obsidian extras are on. Remote images always become links.
    private var markdownForDisplay: String {
        PerfSignposts.measure("prepare") {
            RenderPipeline.prepare(markdown, obsidian: obsidianEnabled, math: false)
        }
    }
}

/// Signposts for the stages Textual keeps inside `StructuredText`. Textual parses synchronously while the body is
/// built, so `parse` runs from body to first appearance and `layout` from there to the first non-zero height.
/// M8 moves parsing off the main actor and narrows `parse` to the real parse.
private final class RenderTrace {
    private var parse: PerfSignposts.Interval?
    private var layout: PerfSignposts.Interval?
    private var isFinished = false

    func beginParse() {
        guard parse == nil, !isFinished else {
            return
        }
        parse = PerfSignposts.interval("parse")
    }

    func beginLayout() {
        guard layout == nil, !isFinished else {
            return
        }
        parse?.end()
        layout = PerfSignposts.interval("layout")
    }

    func finish() {
        guard !isFinished else {
            return
        }
        isFinished = true
        layout?.end()
        PerfSignposts.firstRender()
    }
}
