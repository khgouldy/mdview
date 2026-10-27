import XCTest

@MainActor
final class LaunchSceneTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testHelpGuideOpensAndDismisses() {
        let app = XCUIApplication()
        app.launch()

        guard let help = LaunchScreen.action(LaunchScreen.helpLabel, in: app) else {
            XCTFail("No hittable How to Open Files button on the launch screen:\n\(app.debugDescription)")
            return
        }
        help.tap()

        XCTAssertTrue(
            app.staticTexts["Copy and paste"].waitForExistence(timeout: 5),
            "the guide did not open:\n\(app.debugDescription)",
        )

        let done = app.buttons["help.done"]
        XCTAssertTrue(done.exists, app.debugDescription)
        done.tap()
        XCTAssertTrue(
            LaunchScreen.isShowing(LaunchScreen.helpLabel, in: app, timeout: 5),
            "Done did not close the guide",
        )
    }
}
