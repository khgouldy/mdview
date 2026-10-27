import MDCore
import SwiftUI

/// What the View menu's keyboard shortcuts can do for the focused reader. Each `can…` flag mirrors when the matching
/// toolbar control is available, so a shortcut never does what the screen wouldn't.
struct ReaderCommands {
    var canSwitchMode: Bool
    var mode: ReaderMode
    var setMode: (ReaderMode) -> Void
    var canShowOutline: Bool
    var showOutline: () -> Void
    var canMakeTextSmaller: Bool
    var canMakeTextLarger: Bool
    var canResetText: Bool
    var stepText: (Int) -> Void
    var resetText: () -> Void
    var canExport: Bool
    var printDocument: () -> Void
    var exportPDF: () -> Void
}

extension FocusedValues {
    /// Set per scene with `focusedSceneValue`, so the shortcuts work wherever focus sits in the reader's window
    /// (the Find field included) and are disabled when no reader is in the active scene (the launch screen).
    @Entry var readerCommands: ReaderCommands?
}

extension ReaderView {
    var commands: ReaderCommands {
        let canExport = showsModePicker && !PDFExporter.exceedsLimit(document.text) && !pdfExport.isRendering
        return ReaderCommands(
            canSwitchMode: showsModePicker,
            mode: displayedMode,
            setMode: { modeBinding.wrappedValue = $0 },
            canShowOutline: showsOutlineButton,
            showOutline: { showsOutline = true },
            canMakeTextSmaller: textScale > ReadingSettings.minimumTextScale,
            canMakeTextLarger: textScale < ReadingSettings.maximumTextScale,
            canResetText: textScale != ReadingSettings.defaultTextScale,
            stepText: { textScale = ReadingSettings.stepped(textScale, by: $0) },
            resetText: { textScale = ReadingSettings.defaultTextScale },
            canExport: canExport,
            printDocument: { pdfExport.printDocument(pdfRequest) },
            exportPDF: { pdfExport.shareDocument(pdfRequest) },
        )
    }

    var pdfRequest: PDFRequest {
        PDFRequest(
            markdown: document.text,
            baseDirectory: resolvedFileURL?.deletingLastPathComponent(),
            name: PDFRequest.stem(of: fileName),
            obsidian: obsidianEnabled,
            fontDesign: fontDesign,
            paper: .forRegion(Locale.current.region?.identifier),
        )
    }
}
