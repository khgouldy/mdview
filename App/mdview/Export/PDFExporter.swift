import MDCore
import SwiftUI
import Textual

/// Renders Markdown into a paged PDF (V5) with the reader's look on white paper: `ReaderStyle`, light appearance, no
/// selection, the page width minus 36 pt margins, Letter or A4 by region.
///
/// `ImageRenderer` hosts the document once, waits for it to settle, then draws it page by page into a PDF context,
/// clipped to each `PageSlicer` slice. SwiftUI skips drawing outside the clip, so a page holds only its own text and
/// the file grows with the document, not with pages × document.
@MainActor
enum PDFExporter {
    /// Over this many UTF-8 bytes the menu says "Too long to export" instead of rendering.
    static let maximumBytes = 1_000_000
    static let margin: CGFloat = 36

    /// Textual builds its text in `onChange` and `@State`, so the first `ImageRenderer` pass is short (on macOS a
    /// 12,300 pt document first measures 7,150 pt). Each settle lets the host run its updates, until two
    /// measurements agree.
    private static let settleDelay = Duration.milliseconds(300)
    private static let maximumSettles = 10
    /// The gap `RenderedView` leaves between sections, which each start with a heading.
    private static let sectionSpacing: CGFloat = 24

    static func exceedsLimit(_ markdown: String) -> Bool {
        markdown.utf8.count > maximumBytes
    }

    /// Letter in the US, Canada and Mexico, A4 elsewhere (`PaperSize.forRegion`).
    static func pageSize(for paper: PaperSize = .forRegion(Locale.current.region?.identifier)) -> CGSize {
        CGSize(width: paper.width, height: paper.height)
    }

    static func render(
        markdown: String,
        baseDirectory: URL?,
        pageSize: CGSize,
        obsidian: Bool = true,
        fontDesign: ReaderFontDesign = .system,
        title: String? = nil,
    ) async -> Data {
        let interval = PerfSignposts.interval("pdf")
        defer { interval.end() }
        let document = await DocumentPreparer.shared.prepare(text: markdown, obsidian: obsidian)
        let loader = LocalImageLoader(baseDirectory: baseDirectory)
        var preloaded: [URL: AnyAttachment] = [:]
        let sections = document.sections.map { preloadImages(in: $0, with: loader, into: &preloaded) }

        let width = max(pageSize.width - 2 * margin, 1)
        let renderer = ImageRenderer(content: page(
            sections,
            width: width,
            fontDesign: fontDesign,
            preloaded: preloaded,
        ))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        let height = await settledHeight(of: renderer)
        let slices = PageSlicer.slices(contentHeight: height, pageHeight: Double(pageSize.height - 2 * margin))
        return draw(renderer, slices: slices, pageSize: pageSize, title: title)
    }

    /// The printed document: every section at once (no lazy stack, which would draw only what is "on screen").
    private static func page(
        _ sections: [PreparedSection],
        width: CGFloat,
        fontDesign: ReaderFontDesign,
        preloaded: [URL: AnyAttachment],
    ) -> some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(sections) { section in
                StructuredText(section.markup, parser: PreparsedParser(section: section))
            }
        }
        .frame(width: width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .font(.system(.body, design: fontDesign.design))
        .textual.structuredTextStyle(PrintStyle())
        .textual.highlighterTheme(.default)
        // `Overflow` scrolls with a UIKit scroll view, which ImageRenderer draws as a placeholder. Paper wraps.
        .textual.overflowMode(.wrap)
        .textual.textSelection(.disabled)
        .textual.imageAttachmentLoader(PreloadedImageLoader(attachments: preloaded))
        .environment(\.colorScheme, .light)
        // The PDF is for paper, so it uses the default text size, not the reader's Dynamic Type size.
        .environment(\.dynamicTypeSize, .large)
    }

    /// Resolves the section's images and task checkboxes into the attributed string up front. `StructuredText` loads
    /// attachments in a `.task`, which an `ImageRenderer` host may never run; a resolved run draws without it.
    private static func preloadImages(
        in section: PreparedSection,
        with loader: LocalImageLoader,
        into preloaded: inout [URL: AnyAttachment],
    ) -> PreparedSection {
        var attributed = section.attributed
        var changed = false
        for run in section.attributed.runs {
            guard let url = run.imageURL else {
                continue
            }
            let text = String(section.attributed[run.range].characters)
            guard let attachment = preloaded[url] ?? (try? loader.attachment(for: url, text: text)) else {
                continue
            }
            preloaded[url] = attachment
            attributed[run.range].textual.attachment = attachment
            changed = true
        }
        guard changed else {
            return section
        }
        return PreparedSection(id: section.id, markup: section.markup, attributed: attributed)
    }

    private static func measuredHeight(of renderer: ImageRenderer<some View>) -> CGFloat {
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height
    }

    /// Measures, waits, measures again, until the height holds still or the settles run out.
    private static func settledHeight(of renderer: ImageRenderer<some View>) async -> CGFloat {
        var height = measuredHeight(of: renderer)
        for _ in 0 ..< maximumSettles {
            try? await Task.sleep(for: settleDelay)
            let previous = height
            height = measuredHeight(of: renderer)
            if abs(height - previous) < CGFloat(PageSlicer.tolerance) {
                break
            }
        }
        return height
    }

    /// One PDF page per slice. The renderer draws the whole document with its top-left at the page's top margin,
    /// shifted up by the slice's offset; the clip keeps one slice of it on the page.
    private static func draw(
        _ renderer: ImageRenderer<some View>,
        slices: [PageSlicer.Slice],
        pageSize: CGSize,
        title: String?,
    ) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        var info: [CFString: Any] = [kCGPDFContextCreator: AppName.display]
        if let title {
            info[kCGPDFContextTitle] = title
        }
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary)
        else {
            return Data()
        }
        renderer.render { size, drawContent in
            for slice in slices {
                let offset = CGFloat(slice.offset)
                let height = CGFloat(slice.height)
                context.beginPDFPage(nil)
                context.saveGState()
                // PDF space is bottom-up; the renderer draws its content into (0, 0, size) the same way.
                let top = pageSize.height - margin
                context.clip(to: CGRect(x: margin, y: top - height, width: size.width, height: height))
                context.translateBy(x: margin, y: top - size.height + offset)
                drawContent(context)
                context.restoreGState()
                context.endPDFPage()
            }
        }
        context.closePDF()
        return data as Data
    }
}

/// `ReaderStyle` for paper: the same headings, lists, tables and VoiceOver semantics, but GitHub's plain code block,
/// since a copy button means nothing on a page.
private struct PrintStyle: StructuredText.Style {
    let inlineStyle: InlineStyle = .gitHub
    let headingStyle = AccessibleHeadingStyle()
    let paragraphStyle: StructuredText.GitHubParagraphStyle = .gitHub
    let blockQuoteStyle = CalloutBlockQuoteStyle()
    let codeBlockStyle: StructuredText.GitHubCodeBlockStyle = .gitHub
    let listItemStyle = AccessibleListItemStyle()
    let unorderedListMarker = QuietBulletMarker()
    let orderedListMarker = TaskAwareDecimalMarker()
    let tableStyle = ScrollingTableStyle()
    let tableCellStyle = AccessibleTableCellStyle()
    let thematicBreakStyle: StructuredText.GitHubThematicBreakStyle = .gitHub
}

/// The render-only loader: hands back what `PDFExporter` already loaded and never touches a file, so if the host does
/// run Textual's loading task, it resolves at once to the same attachments.
private struct PreloadedImageLoader: AttachmentLoader {
    let attachments: [URL: AnyAttachment]

    func attachment(for url: URL, text _: String, environment _: ColorEnvironmentValues) async throws -> AnyAttachment {
        guard let attachment = attachments[url] else {
            throw MissingAttachment()
        }
        return attachment
    }

    private struct MissingAttachment: Error {}
}
