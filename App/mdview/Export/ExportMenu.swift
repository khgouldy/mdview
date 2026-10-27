import MDCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Export PDF and Print for the reader menu (V5). Export is a `ShareLink`: the share sheet opens at once, and the PDF
/// renders when a destination asks for it. Print renders first, then opens the system print sheet. Both share one
/// `PDFExport`, so printing after exporting the same document reuses the PDF.
struct ExportMenu: View {
    let markdown: String
    let baseDirectory: URL?
    /// The document's file name, `Notes.md`; the PDF is `Notes.pdf`.
    let fileName: String
    let export: PDFExport

    @AppStorage("obsidian.enabled") private var obsidianEnabled = true
    @AppStorage(ReadingSettings.fontDesignKey) private var fontDesign = ReaderFontDesign.system

    var body: some View {
        if PDFExporter.exceedsLimit(markdown) {
            Section("Too long to export") {
                Button("Export PDF", systemImage: Self.exportSymbol) {}
                    .disabled(true)
                    .accessibilityIdentifier("reader.export.pdf")
                Button("Print", systemImage: Self.printSymbol) {}
                    .disabled(true)
                    .accessibilityIdentifier("reader.print")
            }
        } else {
            Section {
                ShareLink(
                    item: PDFFile(request: request, export: export),
                    preview: SharePreview(request.pdfName, image: Image(systemName: "doc.richtext")),
                ) {
                    Label("Export PDF", systemImage: Self.exportSymbol)
                }
                .disabled(export.isRendering)
                .accessibilityIdentifier("reader.export.pdf")
                Button("Print", systemImage: Self.printSymbol, action: printDocument)
                    .disabled(export.isRendering || !UIPrintInteractionController.isPrintingAvailable)
                    .accessibilityIdentifier("reader.print")
            }
        }
    }

    private static let exportSymbol = "arrow.down.doc"
    private static let printSymbol = "printer"

    private var request: PDFRequest {
        PDFRequest(
            markdown: markdown,
            baseDirectory: baseDirectory,
            name: PDFRequest.stem(of: fileName),
            obsidian: obsidianEnabled,
            fontDesign: fontDesign,
            paper: .forRegion(Locale.current.region?.identifier),
        )
    }

    private func printDocument() {
        let request = request
        Task {
            let data = await export.data(for: request)
            let info = UIPrintInfo.printInfo()
            info.outputType = .general
            info.jobName = request.name
            let controller = UIPrintInteractionController.shared
            controller.printInfo = info
            controller.printingItem = data
            controller.present(animated: true)
        }
    }
}

/// Everything a PDF depends on. An equal request reuses the last PDF.
struct PDFRequest: Hashable, Sendable {
    var markdown: String
    var baseDirectory: URL?
    /// The file name without its extension, already safe to use as one.
    var name: String
    var obsidian: Bool
    var fontDesign: ReaderFontDesign
    var paper: PaperSize

    var pdfName: String {
        name + ".pdf"
    }

    /// `Notes.md` → `Notes`. Path separators become dashes; an empty name is "Document".
    static func stem(of fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? "Document" : stem
    }
}

/// Renders PDFs for one reader and keeps the last one. While a render runs, `isRendering` is true and the reader
/// shows `ExportProgressView`; a second request for the same PDF waits for the first.
@MainActor @Observable
final class PDFExport {
    private(set) var isRendering = false
    @ObservationIgnored private var latest: (request: PDFRequest, data: Data)?
    @ObservationIgnored private var running: (request: PDFRequest, task: Task<Data, Never>)?

    func data(for request: PDFRequest) async -> Data {
        if let latest, latest.request == request {
            return latest.data
        }
        if let running, running.request == request {
            return await running.task.value
        }
        let task = Task {
            await PDFExporter.render(
                markdown: request.markdown,
                baseDirectory: request.baseDirectory,
                pageSize: PDFExporter.pageSize(for: request.paper),
                obsidian: request.obsidian,
                fontDesign: request.fontDesign,
                title: request.name,
            )
        }
        running = (request, task)
        isRendering = true
        let data = await task.value
        if running?.request == request {
            running = nil
        }
        isRendering = running != nil
        latest = (request, data)
        return data
    }
}

/// The PDF as a file named `<name>.pdf`, so Files, Mail and AirDrop keep the document's name. It renders only when
/// the share sheet's destination asks for it.
struct PDFFile: Transferable, Sendable {
    let request: PDFRequest
    let export: PDFExport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { file in
            let data = await file.export.data(for: file.request)
            return try SentTransferredFile(write(data, named: file.request.pdfName))
        }
    }

    /// Writes into a fresh folder under tmp, replacing the previous export's, so the receiver sees only the file name.
    private static func write(_ data: Data, named name: String) throws -> URL {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: "PDF Export", directoryHint: .isDirectory)
        try? manager.removeItem(at: root)
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// Shown over the reader while a PDF renders.
struct ExportProgressView: View {
    var body: some View {
        ProgressView("Preparing PDF…")
            .padding(20)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("reader.export.progress")
    }
}
