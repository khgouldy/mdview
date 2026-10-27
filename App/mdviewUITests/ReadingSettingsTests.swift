import XCTest

/// The reading text size (V3): Larger in the reader menu grows the rendered heading, Reset brings it back.
/// Runs wherever `make test-ios` runs.
@MainActor
final class ReadingSettingsTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testLargerTwiceGrowsHeadingAndResetRestoresIt() {
        let app = ReaderLauncher.app(fixture: .sharedNote, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered", "-reader.textScale", "1.0"]
        app.launch()

        let heading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Shared heading")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 20), app.debugDescription)
        let before = heading.frame.height

        for _ in 0 ..< 2 {
            choose("reader.text.larger", in: app)
        }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let grown = heading.frame.height
        XCTAssertGreaterThan(grown, before, "heading height \(before) -> \(grown)")

        choose("reader.text.reset", in: app)
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.frame.height, before, accuracy: 1)
    }

    private func choose(_ identifier: String, in app: XCUIApplication) {
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), app.debugDescription)
        menu.tap()
        let text = app.descendants(matching: .any)["reader.text"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5), app.debugDescription)
        text.tap()
        let item = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
        item.tap()
    }
}
