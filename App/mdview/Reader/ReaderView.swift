import SwiftUI

/// Persisted Rendered / Source choice. Raw values are the `@AppStorage("reader.mode")` strings.
enum ReaderMode: String, CaseIterable, Identifiable {
    case rendered
    case source

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .rendered:
            "Rendered"
        case .source:
            "Source"
        }
    }
}

/// Document viewer. Markdown files toggle Rendered and Source. Plain text is source only.
struct ReaderView: View {
    let document: TextDocument

    @AppStorage("reader.mode") private var mode: ReaderMode = .rendered
    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @Environment(\.documentConfiguration) private var documentConfiguration

    var body: some View {
        content
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsModePicker {
                    ToolbarItem(placement: .bottomBar) {
                        modePicker
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        readerMenu
                    }
                }
            }
            .toolbarVisibility(showsModePicker ? .visible : .hidden, for: .bottomBar)
    }

    private var readerMenu: some View {
        Menu {
            Toggle("Obsidian extras", isOn: $obsidianEnabled)
                .accessibilityIdentifier("settings.obsidian")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("reader.menu")
        .accessibilityLabel("Settings")
    }

    @ViewBuilder
    private var content: some View {
        switch displayedMode {
        case .rendered:
            RenderedView(markdown: document.text)
                .accessibilityIdentifier("reader.rendered")
        case .source:
            SourceView(text: document.text)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(ReaderMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("reader.modePicker")
    }

    /// Plain text never writes `reader.mode`. The stored choice is for Markdown documents.
    private var displayedMode: ReaderMode {
        showsModePicker ? mode : .source
    }

    private var showsModePicker: Bool {
        switch fileExtension {
        case "txt", "text":
            false
        case "md", "markdown", "mdown":
            true
        default:
            document.allowsRenderedMode
        }
    }

    private var fileExtension: String {
        documentConfiguration?.fileURL?.pathExtension.lowercased() ?? ""
    }

    private var fileName: String {
        let name = documentConfiguration?.fileURL?.lastPathComponent ?? ""
        return name.isEmpty ? "Document" : name
    }
}
