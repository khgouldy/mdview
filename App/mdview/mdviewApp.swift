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
        #endif
    }

    var body: some Scene {
        DocumentGroup(viewing: TextDocument.self) { configuration in
            ReaderView(document: configuration.document)
        }
        // The launch scene redraws these actions as system buttons, so they must be plain `Button`s (a `PasteButton`
        // is dropped on iOS 26) and their accessibility identifiers stay on hidden source copies. If a later iOS stops
        // showing custom actions, move them into `overlayAccessoryView`.
        DocumentGroupLaunchScene(AppName.display) {
            PasteMarkdownButton()
            OpenFilesHelpButton()
        } background: {
            Color.accentColor.opacity(0.25)
        }
    }
}
