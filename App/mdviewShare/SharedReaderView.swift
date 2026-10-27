import MDCore
import SwiftUI
import UIKit

/// What the share extension shows. `ShareViewController` fills it; the view only reads it.
@MainActor @Observable
final class SharedReaderState {
    enum Phase: Equatable {
        case loading
        case loaded(SharedContent)
        case failed(SharedContentError)
    }

    var phase: Phase = .loading
    var title: String
    let attachments: [SharedAttachment]
    let selection: SharedSelection?
    var loadedName: String?
    var byteCount: Int?
    @ObservationIgnored var onDone: () -> Void = {}

    init(attachments: [SharedAttachment], selection: SharedSelection?) {
        self.attachments = attachments
        self.selection = selection
        title = SharedContent.title(suggestedName: selection?.candidate.suggestedName)
        loadedName = selection?.candidate.suggestedName
        if selection == nil {
            phase = .failed(.nothingShared)
        }
    }

    func finish(_ load: SharedLoad) {
        loadedName = load.name
        byteCount = load.byteCount
        title = SharedContent.title(suggestedName: load.name)
        switch load.result {
        case let .success(content):
            phase = .loaded(content)
        case let .failure(error):
            phase = .failed(error)
        }
    }

    /// Plain text for "Copy" in the info panel, so a support email can carry it.
    var report: String {
        var lines = [
            "Loaded type: \(selection?.typeIdentifier ?? "none")",
            "Name: \(loadedName ?? "none")",
            "Bytes: \(byteCount.map(String.init) ?? "unknown")",
        ]
        for attachment in attachments {
            lines.append("Attachment \(attachment.index + 1): \(attachment.suggestedName ?? "no suggested name")")
            lines.append(contentsOf: attachment.typeIdentifiers.map { "  \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

/// The share extension's reader: Rendered / Source for Markdown, Source for other text, or a message.
struct SharedReaderView: View {
    let state: SharedReaderState

    @State private var mode: ReaderMode = .rendered
    @State private var showsInfo = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(state.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showsInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("What was shared")
                        .accessibilityIdentifier("share.info")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            state.onDone()
                        }
                        .accessibilityIdentifier("share.done")
                    }
                    if showsModePicker {
                        ToolbarItem(placement: .bottomBar) {
                            modePicker
                        }
                    }
                }
                .toolbarVisibility(showsModePicker ? .visible : .hidden, for: .bottomBar)
                .sheet(isPresented: $showsInfo) {
                    SharedInfoView(state: state)
                }
        }
        // `firstRender` comes from RenderedView's first non-zero geometry (see PerfSignposts).
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("share.loading")
        case let .loaded(content):
            if content.allowsRendered, mode == .rendered {
                RenderedView(markdown: content.text)
                    .accessibilityIdentifier("reader.rendered")
            } else {
                SourceView(text: content.text)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if content.isMarkdown, !content.allowsRendered {
                            largeNote
                        }
                    }
            }
        case let .failed(error):
            ContentUnavailableView {
                Label(error.message(appName: AppName.display), systemImage: "doc.text.magnifyingglass")
            }
            .accessibilityIdentifier("share.error")
        }
    }

    private var showsModePicker: Bool {
        if case let .loaded(content) = state.phase {
            return content.allowsRendered
        }
        return false
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(ReaderMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("share.modePicker")
    }

    private var largeNote: some View {
        Text("Large text, shown as source.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.bar)
            .accessibilityIdentifier("share.largeNote")
    }
}

/// "What was shared": each attachment's registered types and suggested name, and what was loaded.
/// It reads only the request's own metadata and stores nothing.
private struct SharedInfoView: View {
    let state: SharedReaderState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Shown") {
                    LabeledContent("Type", value: state.selection?.typeIdentifier ?? "None")
                    LabeledContent("Name", value: state.loadedName ?? "None")
                    LabeledContent("Size", value: sizeText)
                        .accessibilityIdentifier("share.info.bytes")
                }
                ForEach(state.attachments) { attachment in
                    Section(sectionTitle(for: attachment)) {
                        LabeledContent("Suggested name", value: attachment.suggestedName ?? "None")
                        ForEach(attachment.typeIdentifiers, id: \.self) { identifier in
                            Text(verbatim: identifier)
                                .font(.footnote.monospaced())
                        }
                    }
                }
            }
            .textSelection(.enabled)
            .navigationTitle("What was shared")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Copy") {
                        UIPasteboard.general.string = state.report
                    }
                    .accessibilityIdentifier("share.info.copy")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("share.info.done")
                }
            }
        }
        .accessibilityIdentifier("share.info.panel")
    }

    private func sectionTitle(for attachment: SharedAttachment) -> String {
        let shown = state.selection?.candidate.index == attachment.index ? " (shown)" : ""
        return "Attachment \(attachment.index + 1)\(shown)"
    }

    private var sizeText: String {
        guard let byteCount = state.byteCount else {
            return "Not read"
        }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        return "\(formatted) (\(byteCount.formatted()) bytes)"
    }
}
