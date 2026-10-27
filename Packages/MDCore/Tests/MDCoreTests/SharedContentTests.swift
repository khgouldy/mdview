import Foundation
import Testing
@testable import MDCore

struct SharedContentTests {
    @Test func `title uses the suggested name or Shared Text`() {
        #expect(SharedContent.title(suggestedName: nil) == "Shared Text")
        #expect(SharedContent.title(suggestedName: "  ") == "Shared Text")
        #expect(SharedContent.title(suggestedName: "notes.md") == "notes.md")
        #expect(SharedContent.title(suggestedName: "/tmp/x/notes.md") == "notes.md")
    }

    @Test func `a nil or extension-less name is markdown`() {
        #expect(SharedContent.isMarkdown(suggestedName: nil))
        #expect(SharedContent.isMarkdown(suggestedName: "Text Document"))
        #expect(SharedContent.isMarkdown(suggestedName: "Meeting v2.0 notes"))
        #expect(SharedContent.isMarkdown(suggestedName: "notes.md"))
        #expect(SharedContent.isMarkdown(suggestedName: "NOTES.MARKDOWN"))
    }

    @Test func `plain text and other extensions are not markdown`() {
        #expect(!SharedContent.isMarkdown(suggestedName: "notes.txt"))
        #expect(!SharedContent.isMarkdown(suggestedName: "page.html"))
        #expect(!SharedContent.isMarkdown(suggestedName: "report.pdf"))
    }

    @Test func `markdown decision by kind`() {
        #expect(SharedContent.isMarkdown(kind: .markdown, suggestedName: "notes.txt"))
        #expect(SharedContent.isMarkdown(kind: .plainText, suggestedName: nil))
        #expect(!SharedContent.isMarkdown(kind: .plainText, suggestedName: "notes.txt"))
        #expect(!SharedContent.isMarkdown(kind: .text, suggestedName: nil))
        #expect(!SharedContent.isMarkdown(kind: .text, suggestedName: "letter.rtf"))
        #expect(SharedContent.isMarkdown(kind: .text, suggestedName: "odd.md"))
        #expect(SharedContent.isMarkdown(kind: .fileURL, suggestedName: "Shared Note.md"))
        #expect(!SharedContent.isMarkdown(kind: .fileURL, suggestedName: "notes.txt"))
    }

    @Test func `display name takes the file name only when it extends the suggested name`() {
        #expect(SharedContent.displayName(suggestedName: "notes", fileName: "notes.md") == "notes.md")
        #expect(SharedContent.displayName(suggestedName: "notes.md", fileName: "notes.md.txt") == "notes.md")
        #expect(SharedContent.displayName(suggestedName: "notes", fileName: "text-3F2A.txt") == "notes")
        #expect(SharedContent.displayName(suggestedName: nil, fileName: "text-3F2A.txt") == nil)
        #expect(SharedContent.displayName(suggestedName: "notes", fileName: nil) == "notes")
    }

    @Test func `binary sniff finds a NUL in the first 8 KB`() {
        #expect(!SharedContent.looksBinary(Data("# Hi\n".utf8)))
        #expect(!SharedContent.looksBinary(Data()))
        #expect(SharedContent.looksBinary(Data("%PDF-1.7\n".utf8) + Data([0x00, 0x01])))
        let lateNUL = Data(repeating: 0x41, count: SharedContent.binarySniffBytes) + Data([0x00])
        #expect(!SharedContent.looksBinary(lateNUL))
        let edgeNUL = Data(repeating: 0x41, count: SharedContent.binarySniffBytes - 1) + Data([0x00])
        #expect(SharedContent.looksBinary(edgeNUL))
    }

    @Test func `UTF-16 with a byte order mark is text`() throws {
        let encoded = try #require("Hi".data(using: .utf16LittleEndian))
        let data = Data([0xFF, 0xFE]) + encoded
        #expect(!SharedContent.looksBinary(data))
        let content = try SharedContent.make(data: data, kind: .plainText, suggestedName: nil).get()
        #expect(content.text == "Hi")
    }

    @Test func `limits are 5 MB and 2 MB`() {
        #expect(SharedContent.limitBytes == 5_000_000)
        #expect(SharedContent.sourceOnlyAboveBytes == 2_000_000)
    }

    @Test func `data over the limit is refused before decoding`() {
        let data = Data(repeating: 0x61, count: SharedContent.limitBytes + 1)
        let result = SharedContent.make(data: data, kind: .plainText, suggestedName: nil)
        #expect(result == .failure(.tooLarge(byteCount: SharedContent.limitBytes + 1)))
    }

    @Test func `text over the limit is refused`() {
        let text = String(repeating: "a", count: SharedContent.limitBytes + 1)
        let result = SharedContent.make(text: text, kind: .plainText, suggestedName: nil)
        #expect(result == .failure(.tooLarge(byteCount: SharedContent.limitBytes + 1)))
    }

    @Test func `text at the limit is accepted and source only`() throws {
        let data = Data(repeating: 0x61, count: SharedContent.limitBytes)
        let content = try SharedContent.make(data: data, kind: .markdown, suggestedName: nil).get()
        #expect(content.byteCount == SharedContent.limitBytes)
        #expect(content.isMarkdown)
        #expect(!content.allowsRendered)
    }

    @Test func `markdown at the source threshold still renders`() throws {
        let data = Data(repeating: 0x61, count: SharedContent.sourceOnlyAboveBytes)
        let content = try SharedContent.make(data: data, kind: .markdown, suggestedName: nil).get()
        #expect(content.allowsRendered)
    }

    @Test func `binary data is refused`() {
        let result = SharedContent.make(data: Data([0x25, 0x50, 0x00]), kind: .fileURL, suggestedName: "a.pdf")
        #expect(result == .failure(.binary))
        #expect(SharedContent.make(text: "a\u{0}b", kind: .plainText, suggestedName: nil) == .failure(.binary))
    }

    @Test func `empty and whitespace-only items show nothing`() {
        #expect(SharedContent.make(text: "", kind: .plainText, suggestedName: nil) == .failure(.empty))
        #expect(SharedContent.make(text: " \n\t", kind: .plainText, suggestedName: nil) == .failure(.empty))
        #expect(SharedContent.make(data: Data(), kind: .markdown, suggestedName: nil) == .failure(.empty))
    }

    @Test func `a nameless text document renders as markdown`() throws {
        let content = try SharedContent.make(
            data: Data("# Shared heading\n".utf8),
            kind: .plainText,
            suggestedName: nil,
        ).get()
        #expect(content.title == "Shared Text")
        #expect(content.text == "# Shared heading\n")
        #expect(content.isMarkdown)
        #expect(content.allowsRendered)
        #expect(content.byteCount == 17)
    }

    @Test func `rtf decodes as text and stays in source`() throws {
        let content = try SharedContent.make(
            data: Data("{\\rtf1 Hello}".utf8),
            kind: .text,
            suggestedName: nil,
        ).get()
        #expect(content.text == "{\\rtf1 Hello}")
        #expect(!content.allowsRendered)
    }

    @Test func `messages use the app name`() {
        #expect(SharedContentError.binary.message(appName: "MdV") == "MdV shows Markdown and text files.")
        #expect(SharedContentError.empty.message(appName: "MdV") == "Nothing to show.")
        #expect(SharedContentError.tooLarge(byteCount: 6_000_000).message(appName: "MdV").contains("5 MB"))
        #expect(SharedContentError.nothingShared.message(appName: "X").hasPrefix("X "))
        #expect(!SharedContentError.unreadable.message(appName: "MdV").isEmpty)
    }
}
