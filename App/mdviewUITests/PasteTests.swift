import UIKit
import XCTest

/// Paste from the launch screen. The app reads `UIPasteboard` on the tap, so `LaunchScreen.tapPaste` answers the
/// "Allow Paste" prompt.
@MainActor
final class PasteTests: XCTestCase {
    private static let markdown = """
    # Pasted heading

    Some **pasted** text.
    """

    /// A blank paste first: nothing opens. Then real Markdown opens the pasted reader, which Done closes.
    /// The blank check only counts because the real paste afterwards proves the taps reach the control.
    func testPasteOpensReaderAndDoneCloses() throws {
        UIPasteboard.general.string = "  \n\t "
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let paste = try pasteButton(in: app)
        LaunchScreen.tapPaste(paste, in: app)
        XCTAssertFalse(
            pastedTitle(in: app).waitForExistence(timeout: 3),
            "A blank paste opened the pasted reader",
        )

        UIPasteboard.general.string = Self.markdown
        LaunchScreen.tapPaste(paste, in: app)
        XCTAssertTrue(
            pastedTitle(in: app).waitForExistence(timeout: 10),
            "Tapped Paste with Markdown on the pasteboard and no pasted reader appeared:\n\(app.debugDescription)",
        )

        let heading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Pasted heading"))
            .firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "The pasted Markdown never rendered")
        XCTAssertTrue(app.buttons["paste.save"].exists, "paste.save missing")

        let done = app.buttons["paste.done"]
        XCTAssertTrue(done.exists, "paste.done missing")
        done.tap()
        XCTAssertNotNil(
            LaunchScreen.action(LaunchScreen.pasteLabel, in: app, timeout: 5),
            "Done did not return to the launch screen",
        )
        XCTAssertFalse(pastedTitle(in: app).exists)
    }

    /// The visible Paste action. Fails, not skips: the launch screen must offer Paste.
    private func pasteButton(in app: XCUIApplication) throws -> XCUIElement {
        guard let button = LaunchScreen.action(LaunchScreen.pasteLabel, in: app) else {
            XCTFail("No hittable Paste button on the launch screen:\n\(app.debugDescription)")
            throw XCTSkip("unreachable after XCTFail")
        }
        return button
    }

    /// The reader's title, which shows the `ReaderContext` display name.
    private func pastedTitle(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Pasted Markdown"))
            .firstMatch
    }
}
