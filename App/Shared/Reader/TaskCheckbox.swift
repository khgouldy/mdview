import MDCore
import SwiftUI
import Textual
import UIKit

/// A read-only task list checkbox drawn inline with the item text.
///
/// Textual draws attachments as `Canvas` symbols, which VoiceOver never sees, so a label here would go unread. The
/// checkbox instead reports its marker to the enclosing list item (`ListItemTask`), whose marker slot speaks for it.
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
        TaskCheckboxImage(marker: marker)
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

/// The checkbox glyph. A `Canvas` symbol still gets the environment and `onAppear`, though not preferences, so this is
/// how the state leaves the attachment.
private struct TaskCheckboxImage: View {
    let marker: TaskMarker
    @Environment(ListItemTask.self) private var task: ListItemTask?

    var body: some View {
        Image(systemName: marker.isChecked ? "checkmark.square.fill" : "square")
            .resizable()
            .scaledToFit()
            .foregroundStyle(marker.isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .onAppear { task?.marker = marker }
            .onDisappear {
                if task?.marker == marker {
                    task?.marker = nil
                }
            }
    }
}

/// The task checkbox a list item starts with, if any. `AccessibleListItemStyle` puts one in each item's environment
/// and `TaskCheckboxImage` fills it in. A nested item has its own, so a checkbox reports to its own item.
@MainActor @Observable
final class ListItemTask {
    var marker: TaskMarker?
}

/// Speaks for a task checkbox from the item's marker slot: VoiceOver reads "Not done, Draft". It draws nothing; the
/// checkbox itself stays inline in the text.
struct TaskStateElement: View {
    let marker: TaskMarker

    var body: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityLabel(marker.label)
            .accessibilityAddTraits(.isStaticText)
    }
}
