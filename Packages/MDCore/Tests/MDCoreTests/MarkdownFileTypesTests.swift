import XCTest
@testable import MDCore

final class MarkdownFileTypesTests: XCTestCase {
    func testEveryMarkdownExtensionIsMarkdown() {
        XCTAssertEqual(MarkdownFileTypes.markdownExtensions.count, 8)
        for ext in MarkdownFileTypes.markdownExtensions {
            XCTAssertEqual(MarkdownFileTypes.isMarkdown(pathExtension: ext), true, ext)
        }
    }

    func testUppercaseIsLowercased() {
        XCTAssertEqual(MarkdownFileTypes.isMarkdown(pathExtension: "MD"), true)
        XCTAssertEqual(MarkdownFileTypes.isMarkdown(pathExtension: "TXT"), false)
    }

    func testPlainTextExtensionsAreNotMarkdown() {
        XCTAssertEqual(MarkdownFileTypes.isMarkdown(pathExtension: "txt"), false)
        XCTAssertEqual(MarkdownFileTypes.isMarkdown(pathExtension: "text"), false)
    }

    func testUnknownAndEmptyGiveNil() {
        XCTAssertNil(MarkdownFileTypes.isMarkdown(pathExtension: "rtf"))
        XCTAssertNil(MarkdownFileTypes.isMarkdown(pathExtension: ""))
    }

    func testMIMETypes() {
        XCTAssertEqual(MarkdownFileTypes.markdownMIMETypes, ["text/markdown", "text/x-markdown"])
    }
}
