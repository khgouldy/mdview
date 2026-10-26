import MDCore
import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument, Sendable {
    var text: String
    var contentType: UTType

    static var readableContentTypes: [UTType] {
        [.markdown, .plainText, .text]
    }

    static var writableContentTypes: [UTType] {
        []
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = TextDecoding.decode(data)
        contentType = configuration.contentType
    }

    #if DEBUG
        /// Screenshot runs build a document from sample Markdown passed into the process.
        init(text: String, contentType: UTType) {
            self.text = text
            self.contentType = contentType
        }
    #endif

    /// The Markdown UTI also conforms to `public.plain-text`, so plain text, RTF and HTML are every other type and show
    /// in Source.
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
