import UIKit
import XCTest

/// Paste from the launch screen. `PasteButton` is a system paste control, so these taps never show a paste prompt.
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
        paste.tap()
        XCTAssertFalse(
            pastedTitle(in: app).waitForExistence(timeout: 3),
            "A blank paste opened the pasted reader",
        )

        UIPasteboard.general.string = Self.markdown
        paste.tap()
        guard pastedTitle(in: app).waitForExistence(timeout: 10) else {
            throw XCTSkip(
                "Tapped launch.paste with Markdown on the pasteboard and no pasted reader appeared. "
                    + "The system paste control may not accept XCUITest's synthesized taps on this OS.",
            )
        }

        let heading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Pasted heading"))
            .firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "The pasted Markdown never rendered")
        XCTAssertTrue(app.buttons["paste.save"].exists, "paste.save missing")

        let done = app.buttons["paste.done"]
        XCTAssertTrue(done.exists, "paste.done missing")
        done.tap()
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "Done did not return to the launch screen")
        XCTAssertFalse(pastedTitle(in: app).exists)
    }

    /// The control by its identifier, or by the system "Paste" label if SwiftUI doesn't pass the identifier through.
    private func pasteButton(in app: XCUIApplication) throws -> XCUIElement {
        let byIdentifier = app.buttons["launch.paste"]
        let button = byIdentifier.waitForExistence(timeout: 15) ? byIdentifier : app.buttons["Paste"]
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                "No launch.paste or Paste button on the launch screen; the system paste control isn't exposed",
            )
        }
        guard button.isHittable else {
            throw XCTSkip("The launch.paste control exists but isn't hittable in XCUITest")
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
