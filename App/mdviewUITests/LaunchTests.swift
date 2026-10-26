import XCTest

final class LaunchTests: XCTestCase {
    func testLaunchReachesForeground() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
}
