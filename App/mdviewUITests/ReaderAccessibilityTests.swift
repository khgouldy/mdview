import XCTest

/// VoiceOver semantics from `ReaderStyle` (L2): headings are single elements, bullets are silent, ordered numbers stay
/// readable, and links inside a heading still open. Runs wherever `make test-ios` runs.
///
/// VoiceOver itself is off under XCUITest, so selection stays on here; the K3 switch is checked by hand (L10).
@MainActor
final class ReaderAccessibilityTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testOverviewHeadingIsOneHittableElement() {
        let app = launch(.kitchenSink)

        let overview = labeled("Overview", in: app)
        XCTAssertTrue(overview.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(overview.isHittable, "the Overview heading is not hittable")
    }

    func testBulletsAreSilentAndNumbersStayReadable() {
        let app = launch(.kitchenSink)
        let build = containing("Build", in: app)
        XCTAssertTrue(build.waitForExistence(timeout: 20), app.debugDescription)

        // The toolbar's ellipsis.circle menu is not a bullet.
        let symbolLabels = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@ AND identifier != %@", "circle", "reader.menu"),
        )
        XCTAssertEqual(symbolLabels.count, 0, "a bullet symbol name reached VoiceOver:\n\(app.debugDescription)")
        for item in ["Plan", "Outline", "Review", "Build"] {
            XCTAssertTrue(containing(item, in: app).exists, "\(item) has no element")
        }

        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "1.", "First"))
            .firstMatch
        XCTAssertTrue(first.exists, "the ordered item lost its number:\n\(app.debugDescription)")
    }

    func testLinkInHeadingStillOpens() {
        let app = launch(.linkedHeading)
        let heading = labeled("Guide", in: app)
        XCTAssertTrue(heading.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(heading.isHittable, "the linked heading is not hittable")

        heading.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "tapping the heading link did not open Safari")
    }

    // MARK: Helpers

    private func launch(_ fixture: ReaderFixture) -> XCUIApplication {
        let app = ReaderLauncher.app(fixture: fixture, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()
        XCTAssertTrue(rendered(in: app).waitForExistence(timeout: 15), app.debugDescription)
        return app
    }

    /// Only checked for existence. Content queries stay at app scope, as in `LargeFileTests`, because SwiftUI may
    /// copy a container's identifier onto its children.
    private func rendered(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["reader.rendered"].firstMatch
    }

    /// An exact label, so "Overview" doesn't match a paragraph that mentions it.
    private func labeled(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// A combined list item's label holds its marker and any nested items too, so match a substring.
    private func containing(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}

private extension ReaderFixture {
    /// An H3 that is only a link. H3 has no divider, so the element's center lands on the link text.
    static let linkedHeading = ReaderFixture(
        name: "Linked Heading.md",
        markdown: """
        # Linked heading

        ### [Guide](https://example.com/guide)

        A paragraph under the link.
        """,
    )
}
