import MDCore
import SwiftUI
import Textual

/// Textual's GitHub look with VoiceOver semantics, which Textual itself has none of. Headings are one element each,
/// with the header trait and their level, so the rotor can jump between them. A list item reads as one element, and an
/// unordered bullet is silent; ordered numbers stay in the label. A task item has no bullet and reads its state first.
///
/// Headings carry no accessibility identifier: the style only sees an opaque label view, not its text. Tests find
/// headings by label.
struct ReaderStyle: StructuredText.Style {
    let inlineStyle: InlineStyle = .gitHub
    let headingStyle = AccessibleHeadingStyle()
    let paragraphStyle: StructuredText.GitHubParagraphStyle = .gitHub
    let blockQuoteStyle: StructuredText.GitHubBlockQuoteStyle = .gitHub
    let codeBlockStyle = CopyableCodeBlockStyle()
    let listItemStyle = AccessibleListItemStyle()
    let unorderedListMarker = QuietBulletMarker()
    let orderedListMarker = TaskAwareDecimalMarker()
    let tableStyle = ScrollingTableStyle()
    let tableCellStyle = AccessibleTableCellStyle()
    let thematicBreakStyle: StructuredText.GitHubThematicBreakStyle = .gitHub
}

extension StructuredText.Style where Self == ReaderStyle {
    /// The reader's GitHub look with VoiceOver headings, list items, bullets and table cells, and scrolling tables.
    static var reader: Self {
        ReaderStyle()
    }
}

/// `GitHubHeadingStyle` as one header element. The H1 and H2 divider has no label, so the element reads as the
/// heading text alone.
struct AccessibleHeadingStyle: StructuredText.HeadingStyle {
    private let base: StructuredText.GitHubHeadingStyle = .gitHub

    func makeBody(configuration: Configuration) -> some View {
        base.makeBody(configuration: configuration)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(Self.level(configuration.headingLevel))
    }

    static func level(_ headingLevel: Int) -> AccessibilityHeadingLevel {
        switch headingLevel {
        case ...1: .h1
        case 2: .h2
        case 3: .h3
        case 4: .h4
        case 5: .h5
        default: .h6
        }
    }
}

/// `DefaultListItemStyle` as one element, so VoiceOver reads the marker and the text together instead of stopping on
/// the marker. A nested list is part of its parent item's block, so it joins that item's element.
struct AccessibleListItemStyle: StructuredText.ListItemStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccessibleListItem(configuration: configuration)
    }
}

/// Owns the item's `ListItemTask`, which its checkbox, if any, fills in and its marker reads.
private struct AccessibleListItem: View {
    let configuration: StructuredText.ListItemStyleConfiguration
    @State private var task = ListItemTask()
    private let base: StructuredText.DefaultListItemStyle = .default

    var body: some View {
        base.makeBody(configuration: configuration)
            .environment(task)
            .accessibilityElement(children: .combine)
    }
}

/// GitHub's disc, circle and square bullets by depth, drawn as shapes. Textual's `HierarchicalSymbolListMarker` draws
/// SF Symbols, and an `Image(systemName:)` stays in the accessibility tree with its symbol name ("circle.fill") even
/// under `.accessibilityHidden(true)` inside the item's combined element. A shape has no element and no name.
///
/// A task item has no bullet, as on GitHub. Its slot holds the checkbox's state for VoiceOver instead.
struct QuietBulletMarker: StructuredText.UnorderedListMarker {
    /// About the size of Textual's symbol bullets, which are SF Symbols at a third of the font size.
    private static let size: FontScaled<CGFloat> = .fontScaled(0.35)
    /// Textual's marker column width, so text lines up as it did with the symbol bullets.
    private static let minWidth: FontScaled<CGFloat> = .fontScaled(1.5)

    @Environment(ListItemTask.self) private var task: ListItemTask?

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if let marker = task?.marker {
                TaskStateElement(marker: marker)
            } else {
                BulletShape(indentationLevel: configuration.indentationLevel)
                    .accessibilityHidden(true)
            }
        }
        .textual.frame(width: Self.size, height: Self.size)
        .textual.frame(minWidth: Self.minWidth, alignment: .trailing)
    }
}

/// `.decimal`, and for a task item (`1. [ ] Draft`) the checkbox's state after the number. GitHub keeps the number.
struct TaskAwareDecimalMarker: StructuredText.OrderedListMarker {
    private let base: StructuredText.DecimalListMarker = .decimal
    @Environment(ListItemTask.self) private var task: ListItemTask?

    func makeBody(configuration: Configuration) -> some View {
        base.makeBody(configuration: configuration)
            .overlay {
                if let marker = task?.marker {
                    TaskStateElement(marker: marker)
                }
            }
    }
}

/// A filled disc at the top level, a ring one level down and a filled square below that, repeating, like
/// `.hierarchical(.disc, .circle, .square)`.
private struct BulletShape: Shape {
    var indentationLevel: Int

    func path(in rect: CGRect) -> Path {
        switch (max(indentationLevel, 1) - 1) % 3 {
        case 0:
            return Circle().path(in: rect)
        case 1:
            let lineWidth = rect.width * 0.2
            let ring = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            return Circle().path(in: ring).strokedPath(StrokeStyle(lineWidth: lineWidth))
        default:
            return Rectangle().path(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
        }
    }
}

/// `GitHubTableStyle`'s look inside Textual's `Overflow`, so a wide table scrolls sideways instead of squeezing its
/// columns. The table is at most 1.5 times the container's width. `Overflow` rather than a bare horizontal
/// `ScrollView` keeps text selection working. Textual's `DynamicColor.gitHub*` is internal, so the borders and the
/// even-row fill use system colors, which also follow dark mode and Increased Contrast.
struct ScrollingTableStyle: StructuredText.TableStyle {
    private static let borderWidth: CGFloat = 1
    private static let relativeWidth: CGFloat = 1.5

    func makeBody(configuration: Configuration) -> some View {
        Overflow { state in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: state.containerWidth.map { $0 * Self.relativeWidth }, alignment: .leading)
                .textual.tableBackground { layout in
                    Canvas { context, _ in
                        for row in layout.rowIndices.dropFirst() where row.isMultiple(of: 2) {
                            context.fill(
                                Path(layout.rowBounds(row).integral),
                                with: .color(Color(uiColor: .secondarySystemBackground)),
                            )
                        }
                    }
                }
                .textual.tableOverlay { layout in
                    Canvas { context, _ in
                        for divider in layout.dividers() {
                            context.fill(Path(divider), with: .color(Color(uiColor: .separator)))
                        }
                    }
                }
                .padding(Self.borderWidth)
                .border(Color(uiColor: .separator), width: Self.borderWidth)
                .padding(Self.borderWidth)
        }
        .textual.tableCellSpacing(horizontal: Self.borderWidth, vertical: Self.borderWidth)
        .textual.blockSpacing(.init(top: 0, bottom: 16))
    }
}

/// `GitHubTableCellStyle` as one element per cell. Row 0 is a header, and every cell says where it is, since a cell
/// read alone has no row or column context.
struct AccessibleTableCellStyle: StructuredText.TableCellStyle {
    private let base: StructuredText.GitHubTableCellStyle = .gitHub

    func makeBody(configuration: Configuration) -> some View {
        base.makeBody(configuration: configuration)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(configuration.row == 0 ? .isHeader : [])
            .accessibilityCustomContent(
                "Position",
                "Row \(configuration.row + 1), column \(configuration.column + 1)",
            )
    }
}
