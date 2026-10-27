import SwiftUI

/// How to get a Markdown file into MdV. Shown from the launch screen and the reader menu.
struct OpenFilesHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.launchDismiss) private var launchDismiss

    var body: some View {
        NavigationStack {
            List {
                section(
                    "From a chat or mail app",
                    "Tap Share, then tap \(AppName.display). If it isn't in the row, tap More, then Edit, "
                        + "and add \(AppName.display) to Favorites. "
                        + "\(AppName.display) shows the file right away. Tap Done to close it.",
                )
                section(
                    "Open the file in \(AppName.display)",
                    "For a file, tap Share, then the \(AppName.display) \"Open in\" item. That opens the full app.",
                )
                section(
                    "Copy and paste",
                    "Copy the text, open \(AppName.display), then tap Paste on the start screen.",
                )
                section(
                    "Save to Files first",
                    "In the app that has the file, choose Save to Files. Then open it from \(AppName.display).",
                )
                section(
                    "Files app",
                    "Find the file in Files and tap it. Or touch and hold, choose Share, then \(AppName.display).",
                )
                // drag-and-drop: remove if L10 fails
                section(
                    "iPad",
                    "Drag a file from another app and drop it on \(AppName.display).",
                )
                Section {
                    Text("\(AppName.display) never connects to the internet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("help.footer")
                }
            }
            .navigationTitle("How to Open Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { launchDismiss.map { $0() } ?? dismiss() }
                        .accessibilityIdentifier("help.done")
                }
            }
        }
        .accessibilityIdentifier("help.root")
    }

    private func section(_ title: String, _ body: String) -> some View {
        Section {
            Text(body)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(title)
                .font(.headline)
                .textCase(nil)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// Button that presents the guide; used by the launch screen.
struct OpenFilesHelpButton: View {
    var body: some View {
        Button("How to Open Files", systemImage: "questionmark.circle") {
            LaunchPresenter.present(OpenFilesHelpView(), style: .pageSheet)
        }
        .accessibilityIdentifier("launch.help")
    }
}
