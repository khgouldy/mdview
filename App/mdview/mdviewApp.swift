import SwiftUI

@main
struct mdviewApp: App {
    init() {
        #if DEBUG
            ScreenshotOpener.shared.arm()
        #endif
    }

    var body: some Scene {
        DocumentGroup(viewing: TextDocument.self) { configuration in
            ReaderView(document: configuration.document)
        }
    }
}
