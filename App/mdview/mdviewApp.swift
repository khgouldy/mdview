import SwiftUI
import UIKit

@main
struct mdviewApp: App {
    init() {
        #if DEBUG
            ScreenshotOpener.shared.arm()
            ShareHarnessOpener.shared.arm()
            // UI tests put their paste text here so the app itself is the pasteboard's source. A paste from another
            // app makes iOS show "Allow Paste", and while it waits the app's main thread is blocked, so XCUITest can't
            // query the app at all (CI run 40514001894). Debug builds only.
            if let seed = ProcessInfo.processInfo.environment["MDVIEW_SEED_PASTEBOARD"] {
                UIPasteboard.general.string = seed
            }
            // UI tests start from default reading settings and mode. A `-reader.textScale` launch argument can't do
            // this: the argument domain outranks the app's own writes, so Larger and Reset would change nothing. The
            // mode is reset too, because Find writes Source and a later test launched without `-reader.mode` expects
            // Rendered.
            if ProcessInfo.processInfo.environment["MDVIEW_RESET_READING_SETTINGS"] == "1" {
                let keys = [ReadingSettings.textScaleKey, ReadingSettings.widthKey, ReadingSettings.fontDesignKey]
                for key in keys + ["reader.mode"] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        #endif
    }

    var body: some Scene {
        DocumentGroup(viewing: TextDocument.self) { configuration in
            ReaderView(document: configuration.document)
        }
        // The launch scene redraws these actions as system buttons, so they must be plain `Button`s (a `PasteButton`
        // is dropped on iOS 26) and their accessibility identifiers stay on hidden source copies. If a later iOS stops
        // showing custom actions, move them into `overlayAccessoryView`.
        .commands {
            ReaderCommandMenu()
        }
        DocumentGroupLaunchScene(AppName.display) {
            PasteMarkdownButton()
            OpenFilesHelpButton()
        } background: {
            Color.accentColor.opacity(0.25)
        }
    }
}

/// The View menu behind the iPad keyboard shortcuts (hold ⌘ to see them). Find in Document (⌘F) opens the source's
/// system find bar. Every item is disabled while no reader is in the active scene.
private struct ReaderCommandMenu: Commands {
    @FocusedValue(\.readerCommands) private var reader

    var body: some Commands {
        CommandMenu("View") {
            Button("Rendered") { reader?.setMode(.rendered) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(!(reader?.canSwitchMode ?? false) || reader?.mode == .rendered)
            Button("Source") { reader?.setMode(.source) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(!(reader?.canSwitchMode ?? false) || reader?.mode == .source)
            Divider()
            Button("Outline") { reader?.showOutline() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!(reader?.canShowOutline ?? false))
            Button("Find in Document") { reader?.find() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(reader == nil)
            Divider()
            Button("Larger Text") { reader?.stepText(1) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!(reader?.canMakeTextLarger ?? false))
            Button("Smaller Text") { reader?.stepText(-1) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!(reader?.canMakeTextSmaller ?? false))
            Button("Actual Size") { reader?.resetText() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!(reader?.canResetText ?? false))
            Divider()
            Button("Print") { reader?.printDocument() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!(reader?.canExport ?? false) || !UIPrintInteractionController.isPrintingAvailable)
            Button("Export PDF") { reader?.exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!(reader?.canExport ?? false))
        }
    }
}
