import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Launch-screen Paste. The system `PasteButton` reads the pasteboard only on the user's tap, so iOS shows no paste
/// prompt. Blank pastes do nothing. Paste lives on the launch scene only.
struct PasteMarkdownButton: View {
    @State private var pasted: PastedMarkdown?

    var body: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let text = strings.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            else {
                return
            }
            pasted = PastedMarkdown(text: text)
        }
        .labelStyle(.titleAndIcon)
        .accessibilityIdentifier("launch.paste")
        .fullScreenCover(item: $pasted) { item in
            PastedReaderView(text: item.text)
        }
    }
}

/// One paste. A new identity per paste, so pasting the same text twice still opens a fresh reader.
private struct PastedMarkdown: Identifiable {
    let id = UUID()
    let text: String
}

/// Pasted text in the normal reader. It stays in memory unless the reader saves it with Save to Files.
/// Large pastes go through `DocumentPreparer` like any other document, so they are prepared off the main actor.
struct PastedReaderView: View {
    static let displayName = "Pasted Markdown"

    let document: TextDocument

    @Environment(\.dismiss) private var dismiss
    @State private var savesToFiles = false
    @State private var exportName = ""
    @State private var saveError: String?

    init(text: String) {
        document = TextDocument(text: text, contentType: .markdown)
    }

    var body: some View {
        NavigationStack {
            ReaderView(document: document)
                .environment(\.readerContext, ReaderContext(displayName: Self.displayName))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Save to Files", systemImage: "square.and.arrow.down") {
                            exportName = Self.defaultFilename(for: .now)
                            savesToFiles = true
                        }
                        .accessibilityIdentifier("paste.save")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("paste.done")
                    }
                }
                .fileExporter(
                    isPresented: $savesToFiles,
                    item: PastedMarkdownFile(text: document.text),
                    contentTypes: [.markdown],
                    defaultFilename: exportName,
                ) { result in
                    if case let .failure(error) = result {
                        saveError = error.localizedDescription
                    }
                }
                .alert(
                    "Couldn't Save",
                    isPresented: showsSaveError,
                    presenting: saveError,
                ) { _ in
                    Button("OK") {}
                } message: { message in
                    Text(message)
                }
        }
    }

    /// Cancelling the exporter isn't an error; only a failed write shows the alert.
    private var showsSaveError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isShown in
                if !isShown {
                    saveError = nil
                }
            },
        )
    }

    /// `Pasted 2026-10-27 1830.md`, in the reader's time zone. POSIX locale, so the digits and calendar never change.
    static func defaultFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return "Pasted \(formatter.string(from: date)).md"
    }
}

/// The pasted text as a UTF-8 `.md` file for `.fileExporter`. `TextDocument` stays read-only for DocumentGroup.
private struct PastedMarkdownFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .markdown) { file in
            Data(file.text.utf8)
        }
    }
}
