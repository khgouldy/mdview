import XCTest

/// Export PDF and Print (V5) in the reader menu: both are there and enabled for a normal document, Export opens the
/// share sheet, and a document over 1 MB shows "Too long to export" with both items disabled.
/// Runs wherever `make test-ios` runs.
@MainActor
final class ExportTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testExportAndPrintItemsExistAndAreEnabled() {
        let app = launch(ReaderLauncher.app(fixture: .kitchenSink, scheme: "light"))
        openMenu(in: app)

        let export = element("reader.export.pdf", in: app)
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(export.isEnabled, "Export PDF is disabled")

        let print = element("reader.print", in: app)
        XCTAssertTrue(print.exists, app.debugDescription)
        XCTAssertTrue(print.isEnabled, "Print is disabled")
        XCTAssertFalse(tooLongNote(in: app).exists)
    }

    /// The PDF renders only when a destination asks for it, so the share sheet opens straight away.
    func testExportOpensShareSheet() {
        let app = launch(ReaderLauncher.app(fixture: .kitchenSink, scheme: "light"))
        openMenu(in: app)

        let export = element("reader.export.pdf", in: app)
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        export.tap()

        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), app.debugDescription)
    }

    func testDocumentOverOneMegabyteIsTooLongToExport() {
        let section = Self.section
        let count = (Self.oversizeBytes + section.utf8.count - 1) / section.utf8.count
        let app = launch(ReaderLauncher.app(
            fixture: ReaderFixture(name: "Too Long.md", markdown: section),
            scheme: "light",
            extraEnvironment: ["MDVIEW_SCREENSHOT_REPEAT": String(count)],
        ))
        openMenu(in: app)

        let export = element("reader.export.pdf", in: app)
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(export.isEnabled, "Export PDF is enabled for a document over 1 MB")
        XCTAssertFalse(element("reader.print", in: app).isEnabled, "Print is enabled for a document over 1 MB")
        XCTAssertTrue(tooLongNote(in: app).exists, app.debugDescription)
    }

    // MARK: Helpers

    /// Over `PDFExporter.maximumBytes` (1,000,000), under the 2 MB Source-only size, so the reader still renders.
    private static let oversizeBytes = 1_100_000

    /// About 10 KB, mostly link reference definitions, which parse but draw nothing (as in `LargeFileTests`).
    private static let section: String = {
        var text = "## Section {n}\n\nSection {n} has [a reference][ref-{n}-1].\n\n"
        var reference = 1
        while text.utf8.count < 10 * 1024 {
            text += "[ref-{n}-\(reference)]: https://example.com/sections/{n}/\(reference)\n"
            reference += 1
        }
        return text + "\n"
    }()

    private func launch(_ app: XCUIApplication) -> XCUIApplication {
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()
        return app
    }

    private func openMenu(in app: XCUIApplication) {
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
        menu.tap()
    }

    /// The menu section header over the disabled items. Any element type, since a menu header's type isn't fixed.
    private func tooLongNote(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Too long to export")).firstMatch
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
