import XCTest

/// Callouts (G): a GitHub alert and an Obsidian callout render their titles, not their `[!type]` markers.
/// Runs wherever `make test-ios` runs.
@MainActor
final class CalloutTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testAlertAndCalloutShowTitlesNotMarkers() {
        let fixture = ReaderFixture(
            name: "Callouts.md",
            markdown: """
            # Callouts

            > [!WARNING]
            > Back up first.

            > [!tip]- Shortcut title
            > Press the button.
            """,
        )
        let app = ReaderLauncher.app(fixture: fixture, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered", "-obsidian.enabled", "YES"]
        app.launch()

        for label in ["Warning", "Back up first.", "Shortcut title", "Press the button."] {
            let element = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", label))
                .firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 20), "\(label) missing:\n\(app.debugDescription)")
        }
        let marker = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "[!"))
            .firstMatch
        XCTAssertFalse(marker.exists, "a callout marker is still shown:\n\(app.debugDescription)")
    }
}
