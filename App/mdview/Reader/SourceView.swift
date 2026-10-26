import SwiftUI
import UIKit

/// Read-only, selectable source. The system find bar is the text view's find interaction.
struct SourceView: UIViewRepresentable {
    let text: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context _: Context) -> UITextView {
        let textView = UITextView()
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
        apply(text, to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context _: Context) {
        _ = dynamicTypeSize
        textView.isEditable = false
        textView.isSelectable = true
        textView.adjustsFontForContentSizeCategory = true
        textView.isFindInteractionEnabled = true
        textView.accessibilityIdentifier = "reader.source"
        apply(text, to: textView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView _: UITextView, context _: Context) -> CGSize? {
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

    private func apply(_ text: String, to textView: UITextView) {
        if textView.text != text {
            textView.text = text
        }
        textView.font = Self.monospacedBodyFont(compatibleWith: textView.traitCollection)
        textView.textColor = .label
    }
}
