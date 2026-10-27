import MDCore
import SwiftUI

/// Document viewer. Markdown files toggle Rendered and Source. Plain text is source only.
/// A non-empty find query shows the source with matches highlighted, then returns to the stored mode.
/// Markdown over 2 MB opens in Source with a "Render Anyway" bar; that choice is per document and never stored.
struct ReaderView: View {
    let document: TextDocument

    @AppStorage("reader.mode") private var mode: ReaderMode = .rendered
    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @AppStorage("reader.math") private var mathEnabled = false
    @Environment(\.documentConfiguration) private var documentConfiguration
    @Environment(\.readerContext) private var readerContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var searchQuery = ""
    @State private var currentMatch = 0
    @State private var find = FindResult()
    @State private var renderAnyway = false
    @State private var showsHelp = false
    @State private var headings: [OutlineHeading] = []
    @State private var showsOutline = false
    @State private var outlineJump: OutlineJump?
    @State private var pdfExport = PDFExport()

    /// Typing pauses this long before a search, so a 1 MB file isn't searched on every keystroke.
    private static let findDebounce = Duration.milliseconds(150)

    var body: some View {
        content
            .task { PerfSignposts.beginOpen(bytes: document.text.utf8.count) }
            .task(id: findKey) {
                await updateFind(findKey)
            }
            .task(id: outlineKey) {
                await updateOutline(outlineKey)
            }
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
                    if find.key != nil {
                        searchCount
                    }
                } else if showsLargeFileBar {
                    largeFileBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleView
                }
                if showsOutlineButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        outlineButton
                    }
                }
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
            .overlay {
                if pdfExport.isRendering {
                    ExportProgressView()
                }
            }
            .sheet(isPresented: $showsHelp) {
                OpenFilesHelpView()
            }
            .sheet(isPresented: $showsOutline) {
                OutlineSheet(headings: headings) { heading in
                    showsOutline = false
                    outlineJump = OutlineJump(heading: heading)
                }
            }
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
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(.bar)
            .accessibilityIdentifier("reader.searchCount")
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var largeFileBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Large file. Showing Source.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Render Anyway") {
                renderAnyway = true
            }
            .accessibilityIdentifier("reader.renderAnyway")
        }
        .font(.footnote)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.largeFile")
    }

    @ViewBuilder
    private var content: some View {
        if showsSource {
            SourceView(
                text: document.text,
                matches: isFindActive ? currentMatches : [],
                currentMatch: activeMatchIndex,
            )
        } else {
            RenderedView(
                markdown: document.text,
                baseDirectory: resolvedFileURL?.deletingLastPathComponent(),
                jump: outlineJump,
                fileURL: resolvedFileURL,
            )
            .accessibilityIdentifier("reader.rendered")
        }
    }

    /// Find always reads the source. Leaving find for Source keeps the same text view.
    private var showsSource: Bool {
        isFindActive || displayedMode == .source
    }

    private var activeMatchIndex: Int? {
        let matches = currentMatches
        guard isFindActive, !matches.isEmpty else {
            return nil
        }
        return min(currentMatch, matches.count - 1)
    }

    /// A segmented control can't grow with the text, so accessibility sizes switch to a menu. Smaller sizes keep the
    /// segments and add the Large Content Viewer.
    @ViewBuilder
    private var modePicker: some View {
        let picker = Picker("Mode", selection: modeBinding) {
            ForEach(ReaderMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker
                .pickerStyle(.menu)
                .accessibilityIdentifier("reader.modePicker")
        } else {
            picker
                .pickerStyle(.segmented)
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("reader.modePicker")
        }
    }

    /// The inline navigation title is one line, which cuts a long name at the front. This wraps to two lines (three at
    /// accessibility sizes) and cuts in the middle, so the extension survives. The label is always the full name.
    private var titleView: some View {
        Text(fileName)
            .font(.headline)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .accessibilityLabel(fileName)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("reader.title")
            .accessibilityShowsLargeContentViewer()
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

    private var findKey: FindKey {
        FindKey(query: searchQuery, text: document.text)
    }

    /// The last finished search, while it is for this text. Indices into an older text would be invalid.
    private var currentMatches: [Range<String.Index>] {
        find.key?.text == document.text ? find.matches : []
    }

    /// Plain text never writes `reader.mode`. The stored choice is for Markdown documents. Large Markdown shows
    /// Source until the reader asks for Rendered.
    private var displayedMode: ReaderMode {
        guard showsModePicker else {
            return .source
        }
        if isLargeFile {
            return renderAnyway ? .rendered : .source
        }
        return mode
    }

    /// For a large file the picker toggles `renderAnyway`, so one big file doesn't change the stored mode.
    private var modeBinding: Binding<ReaderMode> {
        Binding(
            get: { displayedMode },
            set: { newValue in
                if isLargeFile {
                    renderAnyway = newValue == .rendered
                } else {
                    mode = newValue
                }
            },
        )
    }

    private var isLargeFile: Bool {
        PreparedDocument.isLarge(byteCount: document.text.utf8.count)
    }

    private var showsLargeFileBar: Bool {
        showsModePicker && isLargeFile && !renderAnyway
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

/// What a search depends on. The text compares by storage first, so this is cheap for one document.
/// What the outline depends on. `isWanted` is false while the reader shows Source, so a large file isn't parsed twice
/// for a sheet nobody can open.
private struct OutlineKey: Equatable, Sendable {
    var text: String
    var obsidian: Bool
    var isWanted: Bool
}

private struct FindKey: Equatable, Sendable {
    var query: String
    var text: String
}

/// The matches for `key`, or nothing yet (`key == nil`).
private struct FindResult {
    var key: FindKey?
    var matches: [Range<String.Index>] = []
}

extension ReaderView {
    /// Clearing the query clears matches at once. Otherwise wait out the debounce, then search off the main actor.
    /// A newer key cancels this task, so a stale search never overwrites a fresh one.
    private func updateFind(_ key: FindKey) async {
        guard !key.query.isEmpty else {
            find = FindResult()
            return
        }
        do {
            try await Task.sleep(for: Self.findDebounce)
        } catch {
            return
        }
        let matches = await Task.detached(priority: .userInitiated) {
            PerfSignposts.measure("find") { TextSearch.ranges(of: key.query, in: key.text) }
        }.value
        guard !Task.isCancelled else {
            return
        }
        find = FindResult(key: key, matches: matches)
    }

    private var findSummary: String {
        let total = currentMatches.count
        guard total > 0 else {
            return "No matches"
        }
        let position = min(currentMatch, total - 1) + 1
        return "\(position) of \(total)"
    }

    private func advanceMatch() {
        let total = currentMatches.count
        guard total > 0 else {
            return
        }
        currentMatch = (min(currentMatch, total - 1) + 1) % total
    }

    private var outlineKey: OutlineKey {
        OutlineKey(text: document.text, obsidian: obsidianEnabled, isWanted: showsModePicker && !showsSource)
    }

    /// Finds headings off the main actor. Source keeps the last outline, so returning to Rendered shows the button
    /// at once.
    private func updateOutline(_ key: OutlineKey) async {
        guard key.isWanted else {
            return
        }
        let found = await Task.detached(priority: .utility) {
            HeadingOutline.headings(in: key.text, obsidian: key.obsidian, groupBytes: PreparedDocument.groupBytes)
        }.value
        guard !Task.isCancelled else {
            return
        }
        headings = found
    }

    /// The outline jumps within the rendered view, and a one-heading document has nowhere to jump.
    private var showsOutlineButton: Bool {
        showsModePicker && !showsSource && headings.count >= 2
    }

    private var outlineButton: some View {
        Button("Outline", systemImage: "list.bullet.indent") {
            showsOutline = true
        }
        .accessibilityIdentifier("reader.outline")
    }

    private var readerMenu: some View {
        Menu {
            Toggle("Obsidian extras", isOn: $obsidianEnabled)
                .accessibilityIdentifier("settings.obsidian")
            Toggle("Math (LaTeX)", isOn: $mathEnabled)
                .accessibilityIdentifier("settings.math")
            ReadingSettingsMenu()
            ExportMenu(
                markdown: document.text,
                baseDirectory: resolvedFileURL?.deletingLastPathComponent(),
                fileName: fileName,
                export: pdfExport,
            )
            Button("How to Open Files", systemImage: "questionmark.circle") {
                showsHelp = true
            }
            .accessibilityIdentifier("reader.help")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("reader.menu")
        .accessibilityLabel("Settings")
    }
}
