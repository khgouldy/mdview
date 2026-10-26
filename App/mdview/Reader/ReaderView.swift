import MDCore
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
/// A non-empty find query shows the source with matches highlighted, then returns to the stored mode.
struct ReaderView: View {
    let document: TextDocument

    @AppStorage("reader.mode") private var mode: ReaderMode = .rendered
    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @Environment(\.documentConfiguration) private var documentConfiguration

    @State private var searchQuery = ""
    @State private var currentMatch = 0

    var body: some View {
        content
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: searchQueryBinding,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Find",
            )
            .onSubmit(of: .search) {
                advanceMatch()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if isFindActive {
                    searchCount
                }
            }
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

    /// The searchable prompt is only a placeholder, so it disappears once the query is typed.
    /// This line sits in the bar directly under the search field for the whole query.
    private var searchCount: some View {
        Text(findSummary)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.bar)
            .accessibilityIdentifier("reader.searchCount")
            .accessibilityAddTraits(.updatesFrequently)
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
        if showsSource {
            SourceView(
                text: document.text,
                matches: isFindActive ? findMatches : [],
                currentMatch: activeMatchIndex,
            )
        } else {
            RenderedView(markdown: document.text)
                .accessibilityIdentifier("reader.rendered")
        }
    }

    /// Find always reads the source. Leaving find for Source keeps the same text view.
    private var showsSource: Bool {
        isFindActive || displayedMode == .source
    }

    private var activeMatchIndex: Int? {
        guard isFindActive, !findMatches.isEmpty else {
            return nil
        }
        return min(currentMatch, findMatches.count - 1)
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

    /// Clears and Cancel both empty the query. The stored mode is never overwritten, so the previous view returns.
    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { searchQuery },
            set: { newValue in
                if newValue != searchQuery {
                    currentMatch = 0
                }
                searchQuery = newValue
            },
        )
    }

    private var isFindActive: Bool {
        !searchQuery.isEmpty
    }

    private var findMatches: [Range<String.Index>] {
        TextSearch.ranges(of: searchQuery, in: document.text)
    }

    private var findSummary: String {
        let total = findMatches.count
        guard total > 0 else {
            return "No matches"
        }
        let position = min(currentMatch, total - 1) + 1
        return "\(position) of \(total)"
    }

    private func advanceMatch() {
        let total = findMatches.count
        guard total > 0 else {
            return
        }
        currentMatch = (min(currentMatch, total - 1) + 1) % total
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
