import MDCore
import SwiftUI
import Textual

/// GitHub-styled Markdown. Textual parses, lays out, and highlights code. Remote images are links.
struct RenderedView: View {
    let markdown: String

    /// Wide enough for a reading column on iPad. Phones are narrower, so the cap does not bind.
    private static let readableWidth: CGFloat = 680

    @Environment(\.documentConfiguration) private var documentConfiguration

    var body: some View {
        ScrollView {
            StructuredText(markdown: RemoteImages.linkify(markdown))
                .font(.body)
                .textual.structuredTextStyle(.gitHub)
                .textual.highlighterTheme(.default)
                .textual.textSelection(.enabled)
                .textual.imageAttachmentLoader(LocalImageLoader(baseDirectory: baseDirectory))
                .frame(maxWidth: Self.readableWidth, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var baseDirectory: URL? {
        documentConfiguration?.fileURL?.deletingLastPathComponent()
    }
}
