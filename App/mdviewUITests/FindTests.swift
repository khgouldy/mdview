import XCTest

/// Find (B): the bottom bar's Find button and the menu's Find in Document switch to Source and open the system find
/// bar (`UIFindInteraction`), for Markdown and plain text alike.
/// Runs wherever `make test-ios` runs.
@MainActor
final class FindTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    /// No `-reader.mode` launch argument: it would outrank the switch to Source that Find makes. ReaderLauncher resets
    /// the stored mode, so the reader opens on Rendered.
    func testFindButtonOpensFindBarOnSource() {
        let app = ReaderLauncher.app(fixture: .kitchenSink, scheme: "light")
        app.launch()
        let picker = app.segmentedControls["reader.modePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 20), app.debugDescription)
        let rendered = picker.buttons["Rendered"]
        if !rendered.isSelected {
            rendered.tap()
        }

        let find = app.buttons["reader.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 5), app.debugDescription)
        find.tap()

        XCTAssertTrue(app.textViews["reader.source"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(FindBar.field(in: app).waitForExistence(timeout: 10), app.debugDescription)
    }

    func testMenuHasFindInDocument() {
        let app = ReaderLauncher.app(fixture: .kitchenSink, scheme: "light")
        app.launch()
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(menu.label, "More")
        menu.tap()
        let item = app.buttons["reader.findInDocument"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
        item.tap()
        XCTAssertTrue(app.textViews["reader.source"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(FindBar.field(in: app).waitForExistence(timeout: 10), app.debugDescription)
    }
}

/// The system find bar's text field. Its element type has been a search field or a text field depending on the OS.
enum FindBar {
    static func field(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "elementType == %d OR elementType == %d",
                XCUIElement.ElementType.searchField.rawValue,
                XCUIElement.ElementType.textField.rawValue,
            ),
        ).firstMatch
    }
}
