import MDCore
import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument, Sendable {
    var text: String
    var contentType: UTType

    static var readableContentTypes: [UTType] {
        [.markdown, .plainText]
    }

    static var writableContentTypes: [UTType] {
        []
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = TextDecoding.decode(data)
        contentType = configuration.contentType
    }

    /// The Markdown UTI also conforms to `public.plain-text`, so plain text is every other type.
    var allowsRenderedMode: Bool {
        contentType.identifier == UTType.markdown.identifier || contentType.conforms(to: .markdown)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}
