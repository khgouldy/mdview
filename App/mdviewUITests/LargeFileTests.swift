import XCTest

/// Large Markdown (M8): a 300 KB file renders as lazy sections, and a 2.5 MB file opens in Source with
/// "Render Anyway". Runs wherever `make test-ios` runs.
///
/// The fixtures repeat one ~10 KB section through `MDVIEW_SCREENSHOT_REPEAT`, because a launch environment of
/// several megabytes is over the system's limit. Most of each section's bytes are link reference definitions: they
/// are parsed like any Markdown but draw nothing, so reaching the end takes a few swipes instead of hundreds.
@MainActor
final class LargeFileTests: XCTestCase {
    private static let sectionBytes = 10 * 1024

    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testSectionedFileRendersLastSectionAfterScrolling() {
        let count = Self.repeatCount(forBytes: 300 * 1024)
        let app = launch(name: "Large 300k.md", repeating: count)

        XCTAssertTrue(element("reader.rendered", in: app).waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(heading("Section 1", in: app).waitForExistence(timeout: 30), "first section never rendered")

        let last = heading("Section \(count)", in: app)
        var swipes = 0
        while !(last.exists && last.isHittable), swipes < 80 {
            app.swipeUp(velocity: .fast)
            swipes += 1
        }
        XCTAssertTrue(last.exists && last.isHittable, "Section \(count) not reached after \(swipes) swipes")
    }

    func testHugeFileOpensInSourceWithRenderAnyway() {
        let app = launch(name: "Large 2500k.md", repeating: Self.repeatCount(forBytes: 2500 * 1024))

        // The stored mode is Rendered (launch argument), so Source here comes from the size.
        XCTAssertTrue(app.textViews["reader.source"].waitForExistence(timeout: 30), app.debugDescription)
        let renderAnyway = app.buttons["reader.renderAnyway"]
        XCTAssertTrue(renderAnyway.waitForExistence(timeout: 5), "large-file bar missing")
        XCTAssertTrue(app.staticTexts["Large file. Showing Source."].exists)
        XCTAssertFalse(element("reader.rendered", in: app).exists)

        renderAnyway.tap()
        XCTAssertTrue(element("reader.rendered", in: app).waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(renderAnyway.exists, "the bar stays hidden once Rendered is chosen")
        XCTAssertTrue(heading("Section 1", in: app).waitForExistence(timeout: 90), "2.5 MB never finished rendering")
    }

    // MARK: Helpers

    private func launch(name: String, repeating count: Int) -> XCUIApplication {
        let fixture = ReaderFixture(name: name, markdown: Self.section)
        let app = ReaderLauncher.app(
            fixture: fixture,
            scheme: "light",
            extraEnvironment: ["MDVIEW_SCREENSHOT_REPEAT": String(count)],
        )
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// An exact label, so "Section 1" doesn't match "Section 10" or the paragraph under it.
    private func heading(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private static func repeatCount(forBytes bytes: Int) -> Int {
        (bytes + section.utf8.count - 1) / section.utf8.count
    }

    /// One section, about `sectionBytes`. `{n}` becomes the section number.
    private static let section: String = {
        var text = """
        ## Section {n}

        Section {n} opens with a paragraph that links to [its first reference][ref-{n}-1] and runs on for a line \
        or two, so each screen holds some real text.

        - First point in section {n}
        - Second point in section {n}

        ```swift
        let section = {n}
        ```


        """
        var reference = 1
        while text.utf8.count < sectionBytes {
            text += "[ref-{n}-\(reference)]: https://example.com/sections/{n}/\(reference)\n"
            reference += 1
        }
        return text + "\n"
    }()
}
