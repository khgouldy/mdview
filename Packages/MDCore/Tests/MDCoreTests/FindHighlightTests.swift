import XCTest
@testable import MDCore

final class FindHighlightTests: XCTestCase {
    private let strong = FindHighlight.MatchStyle(fill: .strong, underline: .thick, bold: true)
    private func soft(_ underline: FindHighlight.Underline) -> FindHighlight.MatchStyle {
        .init(fill: .soft, underline: underline, bold: false)
    }

    func testZeroMatches() {
        XCTAssertEqual(FindHighlight.styles(matchCount: 0, current: nil, differentiateWithoutColor: true), [])
        XCTAssertEqual(FindHighlight.styles(matchCount: 0, current: 0, differentiateWithoutColor: false), [])
    }

    func testOneMatchIsCurrent() {
        XCTAssertEqual(FindHighlight.styles(matchCount: 1, current: 0, differentiateWithoutColor: false), [strong])
        XCTAssertEqual(FindHighlight.styles(matchCount: 1, current: 0, differentiateWithoutColor: true), [strong])
    }

    func testFirstCurrent() {
        let styles = FindHighlight.styles(matchCount: 3, current: 0, differentiateWithoutColor: false)
        XCTAssertEqual(styles, [strong, soft(.none), soft(.none)])
    }

    func testLastCurrent() {
        let styles = FindHighlight.styles(matchCount: 3, current: 2, differentiateWithoutColor: false)
        XCTAssertEqual(styles, [soft(.none), soft(.none), strong])
    }

    func testOutOfRangeAndNilMarkNothingCurrent() {
        let expected = [soft(.none), soft(.none)]
        XCTAssertEqual(FindHighlight.styles(matchCount: 2, current: 2, differentiateWithoutColor: false), expected)
        XCTAssertEqual(FindHighlight.styles(matchCount: 2, current: -1, differentiateWithoutColor: false), expected)
        XCTAssertEqual(FindHighlight.styles(matchCount: 2, current: nil, differentiateWithoutColor: false), expected)
    }

    func testDifferentiateWithoutColorDottedUnderlinesOthers() {
        let styles = FindHighlight.styles(matchCount: 3, current: 1, differentiateWithoutColor: true)
        XCTAssertEqual(styles, [soft(.dotted), strong, soft(.dotted)])
    }
}
