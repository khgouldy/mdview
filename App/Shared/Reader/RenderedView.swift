import MDCore
import SwiftUI
import Textual

/// GitHub-styled Markdown with VoiceOver headings and lists (`ReaderStyle`). Textual lays out and highlights code.
/// Remote images are links.
///
/// `DocumentPreparer` runs the pipeline and the parse in a detached task. Until it finishes, the first ~2 KB of the
/// source shows as plain text. A document over 64 KB is cut at headings and drawn as a `LazyVStack` of sections, so
/// only what is on screen is laid out.
struct RenderedView: View {
    let markdown: String
    var baseDirectory: URL?
    /// Set by the outline sheet (V1). Each request has its own id, so jumping to the same heading twice scrolls twice.
    var jump: OutlineJump?

    /// Every section after the first starts with a heading, and GitHub headings ask for 24 pt above, so this is the
    /// gap Textual would leave there in one document.
    private static let sectionSpacing: CGFloat = 24
    private static let placeholderBytes = 2048
    /// Time for a lazy section to lay out after the first scroll, before the second one finds the heading in it.
    private static let sectionSettleDelay = Duration.milliseconds(250)

    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @AppStorage(ReadingSettings.textScaleKey) private var textScale = ReadingSettings.defaultTextScale
    @AppStorage(ReadingSettings.widthKey) private var storedWidth = ReaderWidth.defaultValue.rawValue
    @AppStorage(ReadingSettings.fontDesignKey) private var fontDesign = ReaderFontDesign.system
    @State private var prepared: PreparedDocument?
    @State private var trace = RenderTrace()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let key = PreparedDocument.Key(text: markdown, obsidian: obsidianEnabled, math: false)
        // A cached document draws on the first frame, so Source → Rendered doesn't flash the placeholder. While a new
        // key prepares (the Obsidian toggle), the previous render stays up instead.
        let document = prepared.flatMap { $0.key == key ? $0 : nil } ?? DocumentPreparer.shared.cached(key) ?? prepared
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if let document {
                        rendered(document)
                    } else {
                        placeholder
                    }
                }
                .frame(maxWidth: ReaderWidth.resolve(storedWidth).points, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .onChange(of: jump) { _, request in
                if let request, let document {
                    scroll(to: request, in: document, with: proxy)
                }
            }
        }
        .task(id: key) {
            let document = await DocumentPreparer.shared.prepare(key)
            guard !Task.isCancelled else {
                return
            }
            prepared = document
        }
    }

    /// A single section has every heading id realized, so one scroll to the slug is enough. In a lazy stack the
    /// heading's id exists only once its section is realized, so go to `section-<n>` first (which realizes it), let
    /// the layout settle, then to the slug. Duplicate slugs share one id and land on the first heading.
    private func scroll(to request: OutlineJump, in document: PreparedDocument, with proxy: ScrollViewProxy) {
        let heading = request.heading
        guard document.sections.count > 1 else {
            Motion.animate(reduceMotion: reduceMotion) {
                proxy.scrollTo(heading.slug, anchor: .top)
            }
            return
        }
        Task { @MainActor in
            Motion.animate(reduceMotion: reduceMotion) {
                proxy.scrollTo("section-\(heading.section)", anchor: .top)
            }
            try? await Task.sleep(for: Self.sectionSettleDelay)
            guard !Task.isCancelled else {
                return
            }
            Motion.animate(reduceMotion: reduceMotion) {
                proxy.scrollTo(heading.slug, anchor: .top)
            }
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
        .font(.system(.body, design: fontDesign.design))
        .textual.fontScale(ReadingSettings.clamped(textScale))
        .textual.structuredTextStyle(.reader)
        .textual.highlighterTheme(.default)
        .modifier(ReaderTextSelection())
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
                .font(.system(.body, design: fontDesign.design))
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

/// A request from the outline sheet to scroll to one heading.
struct OutlineJump: Equatable {
    let id = UUID()
    let heading: OutlineHeading
}

/// Text selection, except while VoiceOver runs (K3). Textual's selection overlay covers the document with a view that
/// has no accessibility properties, so VoiceOver would find nothing under it. Turning VoiceOver off brings selection
/// back.
private struct ReaderTextSelection: ViewModifier {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        if voiceOverEnabled {
            content.textual.textSelection(.disabled)
        } else {
            content.textual.textSelection(.enabled)
        }
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
