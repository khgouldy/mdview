import UIKit
import XCTest

/// The reading text size (V3): Larger in the reader menu grows the rendered heading, Reset brings it back. The Width
/// picker is only in regular width, so an iPhone's reader menu has none.
/// Runs wherever `make test-ios` runs.
@MainActor
final class ReadingSettingsTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testLargerTwiceGrowsHeadingAndResetRestoresIt() {
        // Not `-reader.textScale 1.0`: a launch argument outranks the app's writes, so Larger would do nothing.
        let app = ReaderLauncher.app(
            fixture: .sharedNote,
            scheme: "light",
            extraEnvironment: ["MDVIEW_RESET_READING_SETTINGS": "1"],
        )
        app.launchArguments += ["-reader.mode", "rendered"]
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

    func testWidthPickerIsHiddenOnIPhone() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Width shows in regular width (iPad)")
        let app = ReaderLauncher.app(fixture: .sharedNote, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()

        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
        menu.tap()
        let text = app.descendants(matching: .any)["reader.text"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5), app.debugDescription)
        let width = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "reader.width", "Width"),
        ).firstMatch
        XCTAssertFalse(width.exists, app.debugDescription)
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
