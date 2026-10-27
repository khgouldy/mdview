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
        // iOS 27 fallback: if the system launch scene stops showing custom actions,
        // move the guide button into `overlayAccessoryView`. Not built; iOS 18 shows it as an action.
        // Leave room here for the Paste Markdown action (L7).
        DocumentGroupLaunchScene(AppName.display) {
            OpenFilesHelpButton()
        } background: {
            Color.accentColor.opacity(0.25)
        }
    }
}
