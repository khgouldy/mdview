import MDCore
import SwiftUI

/// Document viewer. Markdown files toggle Rendered and Source. Plain text is source only.
/// Find opens the system find bar on the source (the text view's `UIFindInteraction`).
/// Markdown over 2 MB opens in Source with a "Render Anyway" bar; that choice is per document and never stored.
struct ReaderView: View {
    let document: TextDocument

    @AppStorage("reader.mode") private var mode: ReaderMode = .rendered
    @AppStorage("obsidian.enabled") var obsidianEnabled = true
    @AppStorage("reader.math") var mathEnabled = false
    @AppStorage(ReadingSettings.textScaleKey) var textScale = ReadingSettings.defaultTextScale
    @AppStorage(ReadingSettings.fontDesignKey) var fontDesign = ReaderFontDesign.system
    @Environment(\.documentConfiguration) private var documentConfiguration
    @Environment(\.readerContext) private var readerContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var findRequest: FindRequest?
    @State private var renderAnyway = false
    @State var showsHelp = false
    @State var headings: [OutlineHeading] = []
    @State var showsOutline = false
    @State private var outlineJump: OutlineJump?
    @State var pdfExport = PDFExport()

    var body: some View {
        content
            .task { PerfSignposts.beginOpen(bytes: document.text.utf8.count) }
            .task(id: outlineKey) {
                await updateOutline(outlineKey)
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsLargeFileBar {
                    largeFileBar
                }
            }
            .onChange(of: showsSource) {
                // A Source view made later (the reader switching back) must not reopen an old find bar.
                if !showsSource {
                    findRequest = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleView
                }
                ToolbarItem(placement: .topBarTrailing) {
                    readerMenu
                }
                if showsModePicker {
                    ToolbarItem(placement: .bottomBar) {
                        modePicker
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    findButton
                }
            }
            .focusedSceneValue(\.readerCommands, commands)
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
        /// Screenshot and audit runs open Find with a query already typed.
        private func applyScreenshotQuery() {
            let query = ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOT_QUERY"] ?? ""
            guard !query.isEmpty else {
                return
            }
            startFind(query: query)
        }
    #endif

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
            SourceView(text: document.text, findRequest: findRequest)
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

    var showsSource: Bool {
        displayedMode == .source
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

    /// Wraps to two lines (three at accessibility sizes) and cuts in the middle, so the extension survives. The label
    /// is always the full name.
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

    /// Plain text never writes `reader.mode`. The stored choice is for Markdown documents. Large Markdown shows
    /// Source until the reader asks for Rendered.
    var displayedMode: ReaderMode {
        guard showsModePicker else {
            return .source
        }
        if isLargeFile {
            return renderAnyway ? .rendered : .source
        }
        return mode
    }

    /// For a large file the picker toggles `renderAnyway`, so one big file doesn't change the stored mode.
    var modeBinding: Binding<ReaderMode> {
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

    var isLargeFile: Bool {
        PreparedDocument.isLarge(byteCount: document.text.utf8.count)
    }

    private var showsLargeFileBar: Bool {
        showsModePicker && isLargeFile && !renderAnyway
    }

    var showsModePicker: Bool {
        MarkdownFileTypes.isMarkdown(pathExtension: fileExtension) ?? document.allowsRenderedMode
    }

    private var fileExtension: String {
        resolvedFileURL?.pathExtension.lowercased() ?? ""
    }

    var fileName: String {
        let name = readerContext?.displayName ?? resolvedFileURL?.lastPathComponent ?? ""
        return name.isEmpty ? "Document" : name
    }

    /// The injected context wins (screenshot runs); DocumentGroup supplies the URL otherwise.
    var resolvedFileURL: URL? {
        readerContext?.fileURL ?? documentConfiguration?.fileURL
    }
}

/// What the outline depends on. `isWanted` is false for plain text and for a large file showing Source, so a large
/// file isn't parsed twice for a sheet nobody can open.
private struct OutlineKey: Equatable, Sendable {
    var text: String
    var obsidian: Bool
    var isWanted: Bool
}

extension ReaderView {
    private var outlineKey: OutlineKey {
        OutlineKey(text: document.text, obsidian: obsidianEnabled, isWanted: outlineIsReachable)
    }

    /// Finds headings off the main actor. A large file in Source keeps the last outline.
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

    /// Next to the mode picker in the bottom bar, for plain text as well as Markdown.
    private var findButton: some View {
        Button("Find", systemImage: "magnifyingglass") {
            startFind()
        }
        .accessibilityIdentifier("reader.find")
    }

    /// The system find bar works on the source text view, so Find switches a Markdown document to Source first.
    func startFind(query: String = "") {
        if displayedMode != .source {
            modeBinding.wrappedValue = .source
        }
        findRequest = FindRequest(query: query)
    }
}
