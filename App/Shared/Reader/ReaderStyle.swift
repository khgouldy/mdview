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
    let codeBlockStyle: StructuredText.GitHubCodeBlockStyle = .gitHub
    let listItemStyle = AccessibleListItemStyle()
    let unorderedListMarker = QuietBulletMarker()
    let orderedListMarker: StructuredText.DecimalListMarker = .decimal
    let tableStyle: StructuredText.GitHubTableStyle = .gitHub
    let tableCellStyle: StructuredText.GitHubTableCellStyle = .gitHub
    let thematicBreakStyle: StructuredText.GitHubThematicBreakStyle = .gitHub
}

extension StructuredText.Style where Self == ReaderStyle {
    /// The reader's GitHub look with VoiceOver headings, list items and bullets.
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
