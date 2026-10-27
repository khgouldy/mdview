import XCTest

final class LaunchSceneTests: XCTestCase {
    func testHelpGuideOpensAndDismisses() {
        let app = XCUIApplication()
        app.launch()

        let help = app.buttons["launch.help"]
        XCTAssertTrue(help.waitForExistence(timeout: 15))
        help.tap()

        XCTAssertTrue(app.staticTexts["Copy and paste"].waitForExistence(timeout: 5))

        let done = app.buttons["help.done"]
        XCTAssertTrue(done.exists)
        done.tap()
        XCTAssertTrue(help.waitForExistence(timeout: 5))
    }
}
