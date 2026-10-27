import ImageIO
import MDCore
import SwiftUI
import Textual
import UIKit

/// Loads Markdown images from the document directory. Task list markers become checkboxes and callout markers
/// become their symbols without touching files; anything else `ImagePolicy` rejects is refused.
struct LocalImageLoader: AttachmentLoader {
    var baseDirectory: URL?

    func attachment(
        for url: URL,
        text: String,
        environment _: ColorEnvironmentValues,
    ) async throws -> AnyAttachment {
        try attachment(for: url, text: text)
    }

    /// The same load without Textual's color environment, which only Textual can create. The PDF exporter (V5) calls
    /// this to resolve images before rendering, since an `ImageRenderer` host may never run Textual's loading task.
    func attachment(for url: URL, text: String) throws -> AnyAttachment {
        if let marker = TaskMarker(url: url) {
            return AnyAttachment(TaskCheckbox(marker: marker) as any Textual.Attachment)
        }
        if let kind = CalloutMarker.kind(of: url) {
            return AnyAttachment(CalloutSymbol(kind: kind) as any Textual.Attachment)
        }
        guard let fileURL = resolvedFileURL(for: url), ImagePolicy.allows(fileURL) else {
            throw LoaderError.refused
        }
        let data = try Data(contentsOf: fileURL)
        guard let pixelSize = Self.pixelSize(of: data) else {
            throw LoaderError.unreadable
        }
        return AnyAttachment(LocalFileImage(data: data, altText: text, pixelSize: pixelSize) as any Textual.Attachment)
    }

    /// Absolute `file:` URLs are used as-is. Scheme-less paths are resolved against the document directory.
    private func resolvedFileURL(for url: URL) -> URL? {
        if url.isFileURL {
            return url.standardized
        }
        guard url.scheme == nil, let baseDirectory else {
            return nil
        }
        let reference = url.relativeString
        guard !reference.contains("://") else {
            return nil
        }
        let resolved = URL(string: reference, relativeTo: baseDirectory)
            ?? encodedFileURL(reference, relativeTo: baseDirectory)
        guard let absolute = resolved?.absoluteURL, absolute.isFileURL else {
            return nil
        }
        return absolute.standardized
    }

    private func encodedFileURL(_ reference: String, relativeTo baseDirectory: URL) -> URL? {
        guard let encoded = reference.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: encoded, relativeTo: baseDirectory)
    }

    private static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        let size = CGSize(width: image.width, height: image.height)
        guard size.width > 0, size.height > 0 else {
            return nil
        }
        return size
    }

    private enum LoaderError: Error {
        case refused
        case unreadable
    }
}

struct LocalFileImage: Attachment {
    var description: String {
        altText
    }

    private let data: Data
    private let altText: String
    private let pixelSize: CGSize

    init(data: Data, altText: String, pixelSize: CGSize) {
        self.data = data
        self.altText = altText
        self.pixelSize = pixelSize
    }

    var body: some View {
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .accessibilityLabel(altText)
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in _: TextEnvironmentValues,
    ) -> CGSize {
        let width = pixelSize.width
        let height = pixelSize.height
        guard height > 0, let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 else {
            return pixelSize
        }
        let fittedWidth = min(proposedWidth, width)
        return CGSize(width: fittedWidth, height: fittedWidth * height / width)
    }
}
