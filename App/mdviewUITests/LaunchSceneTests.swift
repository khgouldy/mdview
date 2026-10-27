import XCTest

final class LaunchSceneTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHelpGuideOpensAndDismisses() {
        let app = XCUIApplication()
        app.launch()

        let help = app.buttons["launch.help"]
        XCTAssertTrue(help.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(help.isHittable, "launch.help is not hittable:\n\(app.debugDescription)")
        help.tap()

        XCTAssertTrue(
            app.staticTexts["Copy and paste"].waitForExistence(timeout: 5),
            "the guide did not open:\n\(app.debugDescription)",
        )

        let done = app.buttons["help.done"]
        XCTAssertTrue(done.exists, app.debugDescription)
        done.tap()
        XCTAssertTrue(help.waitForExistence(timeout: 5))
    }
}
