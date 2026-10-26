import XCTest
@testable import MDCore

final class TextDecodingTests: XCTestCase {
    func testUTF8DecodesMultibyteText() {
        let data = Data("café".utf8)
        XCTAssertEqual(TextDecoding.decode(data), "café")
    }

    func testUTF8DoesNotReinterpretValidBytesAsWindows1252() {
        let data = Data("é".utf8) // C3 A9, which Windows-1252 would show as Ã©
        XCTAssertEqual(TextDecoding.decode(data), "é")
    }

    func testUTF16LittleEndianBOM() throws {
        let encoded = try XCTUnwrap("Hi".data(using: .utf16LittleEndian))
        let data = Data([0xFF, 0xFE]) + encoded
        XCTAssertEqual(TextDecoding.decode(data), "Hi")
    }

    func testUTF16BigEndianBOM() throws {
        let encoded = try XCTUnwrap("Hi".data(using: .utf16BigEndian))
        let data = Data([0xFE, 0xFF]) + encoded
        XCTAssertEqual(TextDecoding.decode(data), "Hi")
    }

    func testWindows1252FallsBackWhenUTF8IsInvalid() {
        // 0xE9 is é in Windows-1252 and illegal as a UTF-8 lead byte.
        // 0x80 is the euro sign, which Latin-1 would leave as a control character.
        let data = Data([0x63, 0x61, 0x66, 0xE9, 0x20, 0x80])
        XCTAssertEqual(TextDecoding.decode(data), "café €")
    }

    func testEmptyDataDecodesToEmptyString() {
        XCTAssertEqual(TextDecoding.decode(Data()), "")
    }
}
