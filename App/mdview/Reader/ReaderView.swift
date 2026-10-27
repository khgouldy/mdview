import MDCore
import SwiftUI

/// Document viewer. Markdown files toggle Rendered and Source. Plain text is source only.
/// A non-empty find query shows the source with matches highlighted, then returns to the stored mode.
struct ReaderView: View {
    let document: TextDocument

    @AppStorage("reader.mode") private var mode: ReaderMode = .rendered
    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @Environment(\.documentConfiguration) private var documentConfiguration
    @Environment(\.readerContext) private var readerContext

    @State private var searchQuery = ""
    @State private var currentMatch = 0

    var body: some View {
        content
            .task { PerfSignposts.beginOpen(bytes: document.text.utf8.count) }
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
        #if DEBUG
            .onAppear(perform: applyScreenshotQuery)
        #endif
    }

    #if DEBUG
        /// Screenshot runs fill Find without focusing the field, so the keyboard stays hidden.
        private func applyScreenshotQuery() {
            let query = ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOT_QUERY"] ?? ""
            guard !query.isEmpty else {
                return
            }
            searchQuery = query
        }
    #endif

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
            RenderedView(
                markdown: document.text,
                baseDirectory: resolvedFileURL?.deletingLastPathComponent(),
            )
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
        MarkdownFileTypes.isMarkdown(pathExtension: fileExtension) ?? document.allowsRenderedMode
    }

    private var fileExtension: String {
        resolvedFileURL?.pathExtension.lowercased() ?? ""
    }

    private var fileName: String {
        let name = readerContext?.displayName ?? resolvedFileURL?.lastPathComponent ?? ""
        return name.isEmpty ? "Document" : name
    }

    /// The injected context wins (screenshot runs); DocumentGroup supplies the URL otherwise.
    private var resolvedFileURL: URL? {
        readerContext?.fileURL ?? documentConfiguration?.fileURL
    }
}
