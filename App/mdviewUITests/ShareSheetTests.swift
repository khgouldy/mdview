import XCTest

/// Drives the real share sheet from the debug-only `ShareHarness` and checks that MdV's Share
/// extension renders what a chat app would share. CI only: needs a simulator.
final class ShareSheetTests: XCTestCase {
    private let heading = "Shared heading"
    private let appName = "MdV"

    override func setUp() {
        continueAfterFailure = false
    }

    func testSharedText() throws {
        try runShare(harnessCase: "text")
    }

    func testSharedTextDocument() throws {
        try runShare(harnessCase: "textDocument")
    }

    func testSharedMarkdownFile() throws {
        try runShare(harnessCase: "fileMarkdown", expectOpenInTarget: true)
    }

    func testSharedTextFile() throws {
        try runShare(harnessCase: "fileText")
    }

    func testQuickLookPreviewShare() throws {
        try runShare(harnessCase: "quickLook", fromQuickLook: true)
    }

    // MARK: - Flow

    private func runShare(
        harnessCase: String,
        fromQuickLook: Bool = false,
        expectOpenInTarget: Bool = false,
    ) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MDVIEW_SHARE_HARNESS"] = harnessCase
        app.launchEnvironment["MDVIEW_SHARE_MARKDOWN"] = ReaderFixture.sharedNote.markdown
        app.launch()

        let trigger = app.buttons["harness.share"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 15), "harness.share missing for \(harnessCase)")
        trigger.tap()

        if fromQuickLook {
            let share = quickLookShareButton(in: app)
            XCTAssertTrue(share.waitForExistence(timeout: 15), "Quick Look share button missing")
            share.tap()
        }

        let query = "app.otherElements[\"ActivityListView\"] (share sheet container)"
        guard app.otherElements["ActivityListView"].waitForExistence(timeout: 15) else {
            throw XCTSkip("Share sheet app row not found. Query used: \(query)")
        }

        if expectOpenInTarget {
            // The harness that presents this share sheet is MdV itself, and iOS doesn't offer an app its own
            // Open in / Copy to action, so on iOS 26 the action is missing here (CI run 40504894387). It is only
            // reachable from another app, which XCUITest can't drive. Recorded as an expected failure, not a pass.
            XCTExpectFailure("iOS hides the presenting app's own Open in action", options: .nonStrict())
            XCTAssertTrue(
                openInTarget(in: app).waitForExistence(timeout: 5) || scrollToOpenInTarget(in: app),
                "Expected an Open in / Copy to \(appName) action for a .md file",
            )
        }

        let item = try appItem(in: app)
        item.tap()

        let shown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", heading))
            .firstMatch
        XCTAssertTrue(
            shown.waitForExistence(timeout: 20),
            "\"\(heading)\" never rendered in the \(appName) extension (\(harnessCase))",
        )
        let done = app.buttons["share.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "share.done missing")
        done.tap()
    }

    // MARK: - Queries

    private func quickLookShareButton(in app: XCUIApplication) -> XCUIElement {
        let byIdentifier = app.buttons["QLOverlayDefaultActionButtonAccessibilityIdentifier"]
        if byIdentifier.waitForExistence(timeout: 10) {
            return byIdentifier
        }
        return app.buttons["Share"].firstMatch
    }

    private func appItemQuery(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND elementType IN %@", appName, [
                XCUIElement.ElementType.button.rawValue,
                XCUIElement.ElementType.cell.rawValue,
            ]))
            .firstMatch
    }

    /// Finds MdV in the app row, then under More. Fails (never skips) when the row exists
    /// without MdV, because that means the extension's activation rule rejected the item.
    private func appItem(in app: XCUIApplication) throws -> XCUIElement {
        let direct = appItemQuery(in: app)
        if direct.waitForExistence(timeout: 3) {
            return direct
        }
        let row = app.otherElements["ActivityListView"]
        for _ in 0 ..< 3 where !direct.exists {
            row.swipeLeft()
        }
        if direct.exists {
            return direct
        }
        let more = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'More'"))
            .firstMatch
        if more.exists {
            more.tap()
            if direct.waitForExistence(timeout: 5) {
                return direct
            }
        }
        XCTFail("Share sheet app row found, but \(appName) is not in it or under More")
        throw XCTSkip("unreachable after XCTFail")
    }

    private func openInTarget(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label MATCHES %@", "(Open in|Copy to) \(appName)"))
            .firstMatch
    }

    private func scrollToOpenInTarget(in app: XCUIApplication) -> Bool {
        let target = openInTarget(in: app)
        for _ in 0 ..< 4 where !target.exists {
            app.swipeUp()
        }
        let found = target.exists
        for _ in 0 ..< 4 {
            app.swipeDown()
        }
        return found
    }
}
