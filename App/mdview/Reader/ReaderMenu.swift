import SwiftUI

/// The ••• menu, for every document. Markdown gets Outline, Reading, Rendering, Export and Print, and help; plain
/// text gets the text size row and help, since the rest only changes rendered Markdown.
extension ReaderView {
    var readerMenu: some View {
        Menu {
            if showsModePicker {
                Section {
                    Button("Outline", systemImage: "list.bullet.indent", action: openOutline)
                        .disabled(!canShowOutline)
                        .accessibilityIdentifier("reader.outline")
                }
            }
            Section("Reading") {
                ReadingSettingsMenu(showsLayout: showsModePicker)
            }
            if showsModePicker {
                Section("Rendering") {
                    Toggle("Obsidian extras", isOn: $obsidianEnabled)
                        .accessibilityIdentifier("settings.obsidian")
                    Toggle("Math (LaTeX)", isOn: $mathEnabled)
                        .accessibilityIdentifier("settings.math")
                }
                ExportMenu(
                    markdown: document.text,
                    baseDirectory: resolvedFileURL?.deletingLastPathComponent(),
                    fileName: fileName,
                    export: pdfExport,
                )
            }
            Section {
                Button("How to Open Files", systemImage: "questionmark.circle") {
                    showsHelp = true
                }
                .accessibilityIdentifier("reader.help")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityIdentifier("reader.menu")
        .accessibilityLabel("More")
    }

    /// Headings are found for Markdown unless a large file is showing Source, where they would mean a second full
    /// parse.
    var outlineIsReachable: Bool {
        showsModePicker && !(isLargeFile && showsSource)
    }

    /// A one-heading document has nowhere to jump. The item stays in the menu, disabled, so nothing moves.
    var canShowOutline: Bool {
        outlineIsReachable && headings.count >= 2
    }

    /// The outline jumps within the rendered view, so Source switches to Rendered first.
    func openOutline() {
        if showsSource {
            modeBinding.wrappedValue = .rendered
        }
        showsOutline = true
    }
}
