import MDCore
import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument, Sendable {
    var text: String

    static var readableContentTypes: [UTType] {
        [.markdown, .plainText]
    }

    static var writableContentTypes: [UTType] {
        []
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = TextDecoding.decode(data)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}
