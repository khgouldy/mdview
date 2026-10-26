import SwiftUI

@main
struct mdviewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: TextDocument.self) { configuration in
            RawTextView(text: configuration.document.text)
        }
    }
}

private struct RawTextView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
    }
}
