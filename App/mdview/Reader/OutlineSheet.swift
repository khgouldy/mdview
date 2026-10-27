import MDCore
import SwiftUI

/// The headings of a document as a list indented by level. Tapping a row calls `onSelect`; the reader dismisses the
/// sheet and scrolls.
struct OutlineSheet: View {
    let headings: [OutlineHeading]
    let onSelect: (OutlineHeading) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Level 1 is flush; each deeper level indents one step, capped so a stray `######` still has room for text.
    private static let indentStep: CGFloat = 16

    var body: some View {
        NavigationStack {
            List(Array(headings.enumerated()), id: \.offset) { index, heading in
                Button {
                    onSelect(heading)
                } label: {
                    Text(heading.title)
                        .font(heading.level <= 2 ? .headline : .body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, CGFloat(heading.level - 1) * Self.indentStep)
                }
                .foregroundStyle(.primary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heading level \(heading.level), \(heading.title)")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("outline.row.\(index)")
            }
            .listStyle(.plain)
            .navigationTitle("Outline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("outline.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("outline.sheet")
    }
}
