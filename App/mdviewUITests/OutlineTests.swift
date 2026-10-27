import XCTest

/// The outline sheet (V1): Outline (`reader.outline`) in the reader menu opens a list of headings, and tapping a row
/// lands on that heading.
/// Runs wherever `make test-ios` runs.
@MainActor
final class OutlineTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testCodeRowJumpsToCodeHeading() {
        let app = ReaderLauncher.app(fixture: .kitchenSink, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()

        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
        // Headings are found off the main actor, so the item can still be disabled for a moment after launch.
        let outline = app.descendants(matching: .any)["reader.outline"].firstMatch
        let deadline = Date().addingTimeInterval(20)
        repeat {
            menu.tap()
            XCTAssertTrue(outline.waitForExistence(timeout: 5), app.debugDescription)
            if outline.isEnabled {
                break
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)).tap()
            Thread.sleep(forTimeInterval: 1)
        } while Date() < deadline
        XCTAssertTrue(outline.isEnabled, "Outline stayed disabled:\n\(app.debugDescription)")
        outline.tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Heading level 3, Code")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        row.tap()

        // An exact label, so the row's "Heading level 3, Code" can't match.
        let heading = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Code")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(heading.isHittable, "the Code heading is not hittable after the jump")
    }
}
