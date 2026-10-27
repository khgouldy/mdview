import SwiftUI
import Textual

/// Textual's GitHub look with VoiceOver semantics, which Textual itself has none of. Headings are one element each,
/// with the header trait and their level, so the rotor can jump between them. A list item reads as one element, and an
/// unordered bullet is silent; ordered numbers stay in the label.
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
    let orderedListMarker: StructuredText.DecimalListMarker = .decimal
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
    private let base: StructuredText.DefaultListItemStyle = .default

    func makeBody(configuration: Configuration) -> some View {
        base.makeBody(configuration: configuration)
            .accessibilityElement(children: .combine)
    }
}

/// GitHub's disc, circle and square bullets by depth, hidden from VoiceOver. Without this the SF Symbol names
/// ("circle.fill") are read before every item.
struct QuietBulletMarker: StructuredText.UnorderedListMarker {
    private let base: StructuredText.HierarchicalSymbolListMarker = .hierarchical(.disc, .circle, .square)

    func makeBody(configuration: Configuration) -> some View {
        base.makeBody(configuration: configuration)
            .accessibilityHidden(true)
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
