import XCTest
@testable import MDCore

final class TextSearchTests: XCTestCase {
    func testCaseInsensitiveMatchesEveryCapitalization() {
        let text = "Hello hello HELLO"
        let ranges = TextSearch.ranges(of: "hello", in: text)
        XCTAssertEqual(slices(text, ranges), ["Hello", "hello", "HELLO"])
    }

    func testDiacriticInsensitivePrecomposed() {
        let text = "Café"
        XCTAssertEqual(slices(text, TextSearch.ranges(of: "cafe", in: text)), ["Café"])
    }

    func testDiacriticInsensitiveCombiningMark() {
        let text = "Cafe\u{0301}"
        let ranges = TextSearch.ranges(of: "cafe", in: text)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String(text[ranges[0]]), text)
    }

    func testDiacriticOnQueryMatchesPlainText() {
        let text = "cafe"
        XCTAssertEqual(slices(text, TextSearch.ranges(of: "café", in: text)), ["cafe"])
    }

    func testCaseAndDiacriticTogether() {
        let text = "CAFÉ naive nai\u{0308}ve"
        XCTAssertEqual(
            slices(text, TextSearch.ranges(of: "cafe", in: text)) +
                slices(text, TextSearch.ranges(of: "naive", in: text)),
            ["CAFÉ", "naive", "nai\u{0308}ve"],
        )
    }

    func testOverlappingAscii() {
        let text = "aaa"
        let ranges = TextSearch.ranges(of: "aa", in: text)
        XCTAssertEqual(slices(text, ranges), ["aa", "aa"])
        XCTAssertEqual(
            ranges.map { text.distance(from: text.startIndex, to: $0.lowerBound) },
            [0, 1],
        )
    }

    func testOverlappingWord() {
        let text = "banana"
        XCTAssertEqual(slices(text, TextSearch.ranges(of: "ana", in: text)), ["ana", "ana"])
    }

    func testOverlappingRunAdvancesOneClusterAtATime() {
        let text = String(repeating: "a", count: 40)
        XCTAssertEqual(TextSearch.ranges(of: "aa", in: text).count, 39)
    }

    func testOverlappingCombiningMarks() {
        let text = "e\u{0301}e\u{0301}e\u{0301}"
        let ranges = TextSearch.ranges(of: "ee", in: text)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(slices(text, ranges), ["e\u{0301}e\u{0301}", "e\u{0301}e\u{0301}"])
    }

    func testEmptyQueryMatchesNothing() {
        XCTAssertTrue(TextSearch.ranges(of: "", in: "hello").isEmpty)
        XCTAssertTrue(TextSearch.ranges(of: "", in: "").isEmpty)
    }

    func testEmptyTextMatchesNothing() {
        XCTAssertTrue(TextSearch.ranges(of: "a", in: "").isEmpty)
    }

    func testNoMatch() {
        XCTAssertTrue(TextSearch.ranges(of: "zzz", in: "hello").isEmpty)
    }

    func testEmojiIsOneMatch() {
        let text = "hello 👋 world"
        XCTAssertEqual(slices(text, TextSearch.ranges(of: "👋", in: text)), ["👋"])
    }

    func testZWJEmojiStaysOneCluster() {
        let family = "👨‍👩‍👧‍👦"
        let text = "x \(family) y"
        let ranges = TextSearch.ranges(of: family, in: text)
        XCTAssertEqual(slices(text, ranges), [family])
        XCTAssertEqual(text.distance(from: ranges[0].lowerBound, to: ranges[0].upperBound), 1)
    }

    func testBaseCharacterCoversCombiningCluster() {
        let text = "e\u{0301}"
        let ranges = TextSearch.ranges(of: "e", in: text)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String(text[ranges[0]]), text)
        XCTAssertEqual(text.distance(from: ranges[0].lowerBound, to: ranges[0].upperBound), 1)
    }

    func testQueryIsLiteralNotAPattern() {
        let text = "a.b axb"
        XCTAssertEqual(slices(text, TextSearch.ranges(of: "a.b", in: text)), ["a.b"])
    }

    private func slices(_ text: String, _ ranges: [Range<String.Index>]) -> [String] {
        ranges.map { String(text[$0]) }
    }
}
