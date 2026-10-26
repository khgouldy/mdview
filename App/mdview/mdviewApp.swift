import SwiftUI

@main
struct mdviewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: TextDocument.self) { configuration in
            RenderedView(markdown: configuration.document.text)
        }
    }
}
