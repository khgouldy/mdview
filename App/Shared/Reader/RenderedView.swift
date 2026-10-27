import MDCore
import SwiftUI
import Textual

/// GitHub-styled Markdown. Textual lays out and highlights code. Remote images are links.
///
/// `DocumentPreparer` runs the pipeline and the parse in a detached task. Until it finishes, the first ~2 KB of the
/// source shows as plain text. A document over 64 KB is cut at headings and drawn as a `LazyVStack` of sections, so
/// only what is on screen is laid out.
struct RenderedView: View {
    let markdown: String
    var baseDirectory: URL?

    /// Wide enough for a reading column on iPad. Phones are narrower, so the cap does not bind.
    private static let readableWidth: CGFloat = 680
    /// Every section after the first starts with a heading, and GitHub headings ask for 24 pt above, so this is the
    /// gap Textual would leave there in one document.
    private static let sectionSpacing: CGFloat = 24
    private static let placeholderBytes = 2048

    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @State private var prepared: PreparedDocument?
    @State private var trace = RenderTrace()

    var body: some View {
        let key = PreparedDocument.Key(text: markdown, obsidian: obsidianEnabled, math: false)
        // A cached document draws on the first frame, so Source → Rendered doesn't flash the placeholder. While a new
        // key prepares (the Obsidian toggle), the previous render stays up instead.
        let document = prepared.flatMap { $0.key == key ? $0 : nil } ?? DocumentPreparer.shared.cached(key) ?? prepared
        ScrollView {
            Group {
                if let document {
                    rendered(document)
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task(id: key) {
            let document = await DocumentPreparer.shared.prepare(key)
            guard !Task.isCancelled else {
                return
            }
            prepared = document
        }
    }

    private func rendered(_ document: PreparedDocument) -> some View {
        Group {
            if document.sections.count == 1, let section = document.sections.first {
                StructuredText(section.markup, parser: PreparsedParser(section: section))
            } else {
                LazyVStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    ForEach(document.sections) { section in
                        StructuredText(section.markup, parser: PreparsedParser(section: section))
                            .id("section-\(section.id)")
                    }
                }
            }
        }
        .font(.body)
        .textual.structuredTextStyle(.gitHub)
        .textual.highlighterTheme(.default)
        .textual.textSelection(.enabled)
        .textual.imageAttachmentLoader(LocalImageLoader(baseDirectory: baseDirectory))
        .onAppear { trace.beginLayout() }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if height > 0 {
                trace.finish()
            }
        }
    }

    /// Real text, not a skeleton: the reader can start reading while the parse runs.
    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: Self.placeholderText(markdown))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if markdown.utf8.count > SectionSplitter.defaultMinimumBytes {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.placeholder")
        .onAppear { trace.showPlaceholder() }
    }

    /// The first `placeholderBytes` of the source, ending on a whole line when there is one.
    private static func placeholderText(_ markdown: String) -> String {
        let utf8 = markdown.utf8
        guard utf8.count > placeholderBytes else {
            return markdown
        }
        let head = markdown[..<utf8.index(utf8.startIndex, offsetBy: placeholderBytes)]
        guard let newline = head.utf8.lastIndex(of: UInt8(ascii: "\n")) else {
            return String(head)
        }
        return String(head[..<newline])
    }
}

/// Signposts for what happens on the main actor. `prepare` and `parse` are measured in `PreparedDocument.make`;
/// here `layout` runs from the prepared content appearing to its first non-zero height, which emits `firstRender`.
/// The event `placeholder` marks the first frame when the parse wasn't cached.
private final class RenderTrace {
    private var layout: PerfSignposts.Interval?
    private var placeholderShown = false
    private var isFinished = false

    func showPlaceholder() {
        guard !placeholderShown, !isFinished else {
            return
        }
        placeholderShown = true
        PerfSignposts.event("placeholder")
    }

    func beginLayout() {
        guard layout == nil, !isFinished else {
            return
        }
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
