import MDCore
import SwiftUI
import Textual
import UIKit

/// A read-only task list checkbox drawn inline with the item text.
struct TaskCheckbox: Attachment {
    var marker: TaskMarker

    var description: String {
        marker.isChecked ? "[x]" : "[ ]"
    }

    /// The glyph is not selectable text, so selection does not dim it.
    var selectionStyle: AttachmentSelectionStyle {
        .text
    }

    var body: some View {
        Image(systemName: marker.isChecked ? "checkmark.square.fill" : "square")
            .resizable()
            .scaledToFit()
            .foregroundStyle(marker.isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .accessibilityLabel(marker.label)
            .accessibilityAddTraits(.isStaticText)
    }

    func sizeThatFits(_: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
        let side = Self.side(for: environment.dynamicTypeSize)
        return CGSize(width: side, height: side)
    }

    /// About 1.1 em of body text, scaled for the current Dynamic Type size.
    static func side(for size: DynamicTypeSize) -> CGFloat {
        let bodySize = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category(for: size)),
        ).pointSize
        return (bodySize * 1.1).rounded()
    }

    private static let categories: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
    ]

    /// `DynamicTypeSize.allCases` runs from xSmall to accessibility5 in the same order as `categories`.
    private static func category(for size: DynamicTypeSize) -> UIContentSizeCategory {
        let index = DynamicTypeSize.allCases.firstIndex(of: size).map { DynamicTypeSize.allCases.distance(
            from: DynamicTypeSize.allCases.startIndex,
            to: $0,
        ) }
        return index.flatMap { categories.indices.contains($0) ? categories[$0] : nil } ?? .large
    }
}
