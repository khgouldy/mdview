import SwiftUI

@main
struct mdviewApp: App {
    init() {
        #if DEBUG
            ScreenshotOpener.shared.arm()
            ShareHarnessOpener.shared.arm()
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
