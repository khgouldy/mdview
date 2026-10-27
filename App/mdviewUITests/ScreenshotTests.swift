import XCTest

/// App Store captures. Skipped unless `scripts/screenshots.sh` requests them, so CI's `xcodebuild test` stays on
/// LaunchTests.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try XCTSkipUnless(
            ScreenshotRun.requested,
            "Set MDVIEW_SCREENSHOTS=1 to capture App Store screenshots.",
        )
    }

    func testCaptureAppStoreScreenshots() throws {
        let session = ScreenshotSession { [self] name in
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let cedar = try ReaderFixture.cedarTrail()
        let light = ReaderLauncher.app(fixture: cedar, scheme: "light")
        light.launch()
        try session.captureRendered(light, name: "01-rendered-light.png")
        let dark = ReaderLauncher.app(fixture: cedar, scheme: "dark")
        dark.launch()
        try session.captureRendered(dark, name: "02-rendered-dark.png")
        let source = ReaderLauncher.app(fixture: cedar, scheme: "light")
        source.launch()
        try session.captureSource(source)
        let find = ReaderLauncher.app(fixture: cedar, scheme: "light", query: "Cedar")
        find.launch()
        try session.captureFind(find)
        let review = try ReaderLauncher.app(fixture: ReaderFixture.weeklyReview(), scheme: "light")
        review.launch()
        try session.captureObsidian(review)
        let checklist = try ReaderFixture.launchChecklist()
        let outline = ReaderLauncher.app(fixture: checklist, scheme: "light")
        outline.launch()
        try session.captureOutline(outline)
        let tasks = ReaderLauncher.app(fixture: checklist, scheme: "light")
        tasks.launch()
        try session.captureTasks(tasks)
    }
}

private struct ScreenshotRun: Decodable {
    var enabled: Bool

    static var requested: Bool {
        if ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOTS"] == "1" {
            return true
        }
        guard let data = try? Data(contentsOf: fileURL),
              let run = try? JSONDecoder().decode(ScreenshotRun.self, from: data)
        else {
            return false
        }
        return run.enabled
    }

    private static let fileURL = URL(fileURLWithPath: "/tmp/mdview-screenshot-run.json")
}

private struct ScreenshotSession {
    var attach: (String) -> Void

    func captureRendered(_ app: XCUIApplication, name: String) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Cedar Trail.md")
        try selectMode("Rendered", in: app)
        dismissSystemBanner(app)
        capture(name)
    }

    func captureSource(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Cedar Trail.md")
        try selectMode("Source", in: app)
        XCTAssertTrue(app.textViews["reader.source"].waitForExistence(timeout: 8))
        dismissSystemBanner(app)
        capture("03-source.png")
    }

    func captureFind(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Cedar Trail.md")
        XCTAssertTrue(app.textViews["reader.source"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(FindBar.field(in: app).waitForExistence(timeout: 8), app.debugDescription)
        dismissSystemBanner(app)
        capture("04-find.png")
    }

    func captureObsidian(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Weekly Review.md")
        try selectMode("Rendered", in: app)
        try ensureObsidianEnabled(app)
        try selectMode("Rendered", in: app)
        dismissSystemBanner(app)
        capture("05-obsidian.png")
    }

    func captureOutline(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Launch Checklist.md")
        try selectMode("Rendered", in: app)
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8), app.debugDescription)
        menu.tap()
        let button = app.buttons["reader.outline"]
        XCTAssertTrue(button.waitForExistence(timeout: 8), app.debugDescription)
        button.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["outline.sheet"].waitForExistence(timeout: 8),
            app.debugDescription,
        )
        dismissSystemBanner(app)
        capture("06-outline.png")
    }

    func captureTasks(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .portrait
        try requireReader(app, title: "Launch Checklist.md")
        try selectMode("Rendered", in: app)
        dismissSystemBanner(app)
        capture("07-tasks.png")
    }

    private func requireReader(_ app: XCUIApplication, title: String) throws {
        let titled = app.navigationBars[title]
        let inline = app.navigationBars.staticTexts[title]
        if titled.waitForExistence(timeout: 20) || inline.waitForExistence(timeout: 3) {
            let picker = app.segmentedControls["reader.modePicker"]
            if picker.waitForExistence(timeout: 8) {
                return
            }
        }
        XCTFail("Expected \(title) with reader.modePicker.\n\(app.debugDescription)")
    }

    private func selectMode(_ title: String, in app: XCUIApplication) throws {
        let picker = app.segmentedControls["reader.modePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 8), app.debugDescription)
        let button = picker.buttons[title]
        if !button.isSelected {
            button.tap()
        }
    }

    private func dismissSystemBanner(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for owner in [springboard, app] {
            let banner = owner.staticTexts["Ready for Apple Intelligence"]
            if banner.waitForExistence(timeout: 0.8) {
                banner.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    private func ensureObsidianEnabled(_ app: XCUIApplication) throws {
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), app.debugDescription)
        menu.tap()
        let toggle = obsidianControl(in: app)
        if isOff(toggle) {
            toggle.tap()
        }
        dismissMenu(app)
    }

    private func obsidianControl(in app: XCUIApplication) -> XCUIElement {
        let identified = app.switches["settings.obsidian"]
        if identified.waitForExistence(timeout: 3) {
            return identified
        }
        let namedSwitch = app.switches["Obsidian extras"]
        if namedSwitch.exists {
            return namedSwitch
        }
        let button = app.buttons["Obsidian extras"]
        if button.exists {
            return button
        }
        let menuItem = app.menuItems["Obsidian extras"]
        if menuItem.exists {
            return menuItem
        }
        XCTFail("Obsidian toggle not found.\n\(app.debugDescription)")
        return identified
    }

    private func isOff(_ element: XCUIElement) -> Bool {
        let value = String(describing: element.value ?? "").lowercased()
        return value == "0" || value == "false" || value == "off"
    }

    private func dismissMenu(_ app: XCUIApplication) {
        if app.switches["settings.obsidian"].exists || app.buttons["Obsidian extras"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.55)).tap()
        }
        if app.switches["settings.obsidian"].exists || app.buttons["Obsidian extras"].exists {
            app.buttons["reader.menu"].tap()
        }
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        attach(name)
    }
}
