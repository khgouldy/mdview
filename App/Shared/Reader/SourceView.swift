import MDCore
import SwiftUI
import UIKit

/// Read-only, selectable source with the system find interaction on. A new `findRequest` opens its find bar.
/// `matches` paints highlights; the reader no longer passes any, since the find bar highlights its own.
struct SourceView: UIViewRepresentable {
    var text: String
    var findRequest: FindRequest?
    var matches: [Range<String.Index>] = []
    var currentMatch: Int?

    @AppStorage(ReadingSettings.textScaleKey) private var textScale = ReadingSettings.defaultTextScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> SourceTextView {
        let textView = SourceTextView()
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.adjustsFontForContentSizeCategory = true
        textView.isFindInteractionEnabled = true
        textView.accessibilityIdentifier = "reader.source"
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: SourceTextView, context: Context) {
        _ = dynamicTypeSize
        defer {
            if let findRequest, context.coordinator.findRequestID != findRequest.id {
                context.coordinator.findRequestID = findRequest.id
                textView.requestFind(query: findRequest.query)
            }
        }
        textView.reduceMotion = reduceMotion
        textView.isEditable = false
        textView.isSelectable = true
        textView.adjustsFontForContentSizeCategory = true
        textView.isFindInteractionEnabled = true
        textView.accessibilityIdentifier = "reader.source"

        let font = Self.monospacedBodyFont(
            scale: ReadingSettings.clamped(textScale),
            compatibleWith: textView.traitCollection,
        )
        let ranges = utf16Ranges(in: text)
        let current = currentMatch.flatMap { ranges.indices.contains($0) ? $0 : nil }
        let signature = SourceRenderSignature(
            text: text,
            ranges: ranges,
            current: current,
            fontSize: font.pointSize,
            contentSize: textView.traitCollection.preferredContentSizeCategory,
            interfaceStyle: textView.traitCollection.userInterfaceStyle,
            differentiateWithoutColor: differentiateWithoutColor,
        )
        guard context.coordinator.signature != signature else {
            return
        }
        let previous = context.coordinator.signature
        context.coordinator.signature = signature
        if ranges.isEmpty {
            applyPlain(text, font: font, clearingHighlights: previous?.ranges.isEmpty == false, to: textView)
            textView.pendingScroll = nil
        } else {
            textView.attributedText = highlighted(text, font: font, ranges: ranges, current: current)
            textView.pendingScroll = current.map { ranges[$0] }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView _: SourceTextView, context _: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height, width > 0, height > 0 else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// 17pt is body at the large content-size category. `UIFontMetrics` scales that face for Dynamic Type.
    /// The reading text scale multiplies the base size before Dynamic Type does.
    private static func monospacedBodyFont(scale: Double, compatibleWith traits: UITraitCollection?) -> UIFont {
        let base = UIFont.monospacedSystemFont(ofSize: 17 * scale, weight: .regular)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: traits)
    }

    /// Replacing attributed text resets the scroll offset. Keep it when the string itself did not change.
    private func applyPlain(
        _ text: String,
        font: UIFont,
        clearingHighlights: Bool,
        to textView: UITextView,
    ) {
        if textView.text != text {
            textView.text = text
        } else if clearingHighlights {
            let offset = textView.contentOffset
            textView.text = text
            textView.setContentOffset(offset, animated: false)
        }
        textView.font = font
        textView.textColor = .label
    }

    private func utf16Ranges(in text: String) -> [NSRange] {
        matches.compactMap { NSRange($0, in: text) }
    }

    /// Non-current matches are painted first so an overlapping current match stays on top.
    private func highlighted(
        _ text: String,
        font: UIFont,
        ranges: [NSRange],
        current: Int?,
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.label,
            ],
        )
        let styles = FindHighlight.styles(
            matchCount: ranges.count,
            current: current,
            differentiateWithoutColor: differentiateWithoutColor,
        )
        // Non-current styles first so an overlapping current match stays on top.
        let order = ranges.indices.filter { $0 != current } + (current.map { [$0] } ?? [])
        for index in order {
            apply(styles[index], to: ranges[index], in: result, font: font)
        }
        return result
    }

    private func apply(
        _ style: FindHighlight.MatchStyle,
        to range: NSRange,
        in result: NSMutableAttributedString,
        font: UIFont,
    ) {
        switch style.fill {
        case .soft:
            result.addAttribute(.backgroundColor, value: Self.matchBackground, range: range)
        case .strong:
            result.addAttributes(
                [.backgroundColor: UIColor.systemYellow, .foregroundColor: UIColor.black],
                range: range,
            )
        }
        switch style.underline {
        case .none:
            break
        case .dotted:
            result.addAttributes(
                [.underlineStyle: NSUnderlineStyle.patternDot.union(.single).rawValue, .underlineColor: UIColor.label],
                range: range,
            )
        case .thick:
            result.addAttributes(
                [.underlineStyle: NSUnderlineStyle.thick.rawValue, .underlineColor: UIColor.label],
                range: range,
            )
        }
        if style.bold {
            let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor
            result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: range)
        }
    }

    private static let matchBackground = UIColor.systemYellow.withAlphaComponent(0.35)

    final class Coordinator {
        fileprivate var signature: SourceRenderSignature?
        fileprivate var findRequestID: UUID?
    }
}

private struct SourceRenderSignature: Equatable {
    var text: String
    var ranges: [NSRange]
    var current: Int?
    var fontSize: CGFloat
    var contentSize: UIContentSizeCategory
    var interfaceStyle: UIUserInterfaceStyle
    var differentiateWithoutColor: Bool
}

/// Scrolls the current match once the text view has a real height. `updateUIView` often runs before that.
final class SourceTextView: UITextView {
    var pendingScroll: NSRange?
    /// Reduce Motion: jump to the match instead of animating the scroll.
    var reduceMotion = false
    /// A find bar asked for before the view was in a window (Find from Rendered makes a new text view).
    private var pendingFind: String?

    /// Opens the system find bar, with `query` typed when it isn't empty.
    func requestFind(query: String) {
        pendingFind = query
        presentPendingFind()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        presentPendingFind()
    }

    /// The find bar needs a window, and the text set in the same update, so it opens on the next main-actor turn.
    private func presentPendingFind() {
        guard window != nil, let query = pendingFind else {
            return
        }
        pendingFind = nil
        Task { @MainActor [weak self] in
            guard let interaction = self?.findInteraction else {
                return
            }
            interaction.presentFindNavigator(showingReplace: false)
            if !query.isEmpty {
                interaction.searchText = query
                interaction.findNext()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0, contentSize.height > 0, let pendingScroll else {
            return
        }
        self.pendingScroll = nil
        // Glyphs are often not ready until after this layout pass.
        reveal(pendingScroll)
        Task { @MainActor [weak self] in
            self?.reveal(pendingScroll)
        }
    }

    /// `scrollRangeToVisible` animates; under Reduce Motion set the offset directly.
    private func reveal(_ range: NSRange) {
        guard reduceMotion else {
            scrollRangeToVisible(range)
            return
        }
        UIView.performWithoutAnimation {
            scrollRangeToVisible(range)
        }
        setContentOffset(contentOffset, animated: false)
    }
}

/// Asks the source view to open its find bar. Each request is new, so asking again reopens a closed bar.
struct FindRequest: Equatable {
    let id = UUID()
    var query = ""
}
