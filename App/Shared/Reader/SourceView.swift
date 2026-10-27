import SwiftUI
import UIKit

/// Read-only, selectable source. Find highlights matches here; the system find interaction stays on.
struct SourceView: UIViewRepresentable {
    var text: String
    var matches: [Range<String.Index>] = []
    var currentMatch: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        textView.isEditable = false
        textView.isSelectable = true
        textView.adjustsFontForContentSizeCategory = true
        textView.isFindInteractionEnabled = true
        textView.accessibilityIdentifier = "reader.source"

        let font = Self.monospacedBodyFont(compatibleWith: textView.traitCollection)
        let ranges = utf16Ranges(in: text)
        let current = currentMatch.flatMap { ranges.indices.contains($0) ? $0 : nil }
        let signature = SourceRenderSignature(
            text: text,
            ranges: ranges,
            current: current,
            fontSize: font.pointSize,
            contentSize: textView.traitCollection.preferredContentSizeCategory,
            interfaceStyle: textView.traitCollection.userInterfaceStyle,
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
    private static func monospacedBodyFont(compatibleWith traits: UITraitCollection?) -> UIFont {
        let base = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
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
        for (index, range) in ranges.enumerated() {
            if let current, index == current {
                continue
            }
            result.addAttribute(.backgroundColor, value: Self.matchBackground, range: range)
        }
        if let current {
            result.addAttributes(
                [
                    .backgroundColor: UIColor.systemYellow,
                    .foregroundColor: UIColor.black,
                ],
                range: ranges[current],
            )
        }
        return result
    }

    private static let matchBackground = UIColor.systemYellow.withAlphaComponent(0.35)

    final class Coordinator {
        fileprivate var signature: SourceRenderSignature?
    }
}

private struct SourceRenderSignature: Equatable {
    var text: String
    var ranges: [NSRange]
    var current: Int?
    var fontSize: CGFloat
    var contentSize: UIContentSizeCategory
    var interfaceStyle: UIUserInterfaceStyle
}

/// Scrolls the current match once the text view has a real height. `updateUIView` often runs before that.
final class SourceTextView: UITextView {
    var pendingScroll: NSRange?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0, contentSize.height > 0, let pendingScroll else {
            return
        }
        self.pendingScroll = nil
        // Glyphs are often not ready until after this layout pass.
        scrollRangeToVisible(pendingScroll)
        Task { @MainActor [weak self] in
            self?.scrollRangeToVisible(pendingScroll)
        }
    }
}
