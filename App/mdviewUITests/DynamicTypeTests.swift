import XCTest

/// The largest accessibility text size (L3): the mode picker is a menu that can still be tapped, the title wraps but
/// keeps the full file name as its label, and a wide table scrolls so its last header can be reached.
@MainActor
final class DynamicTypeTests: XCTestCase {
    private static let contentSize = "UICTContentSizeCategoryAccessibilityXXXL"

    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testPickerTitleAndTableAtLargestSize() {
        let fixture = ReaderFixture.kitchenSink
        let app = ReaderLauncher.app(fixture: fixture, scheme: "light", contentSize: Self.contentSize)
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()

        let picker = app.descendants(matching: .any)["reader.modePicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(picker.isHittable, "the mode picker is not hittable at AccessibilityXXXL")

        let title = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", fixture.name))
            .firstMatch
        XCTAssertTrue(title.exists, "no element is labelled with the full name:\n\(app.debugDescription)")

        let owner = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Owner"))
            .firstMatch
        XCTAssertTrue(owner.waitForExistence(timeout: 20), app.debugDescription)
        let window = app.windows.firstMatch
        Self.scrollIntoView(owner, in: window)
        // The header is a text range inside the table's text view, so it's never `isHittable` (a hit test lands on the
        // text view). Reachable means its whole frame is on screen (CI run 40507377953 scrolled it fully into view at
        // x 298-369 and still reported it unhittable).
        XCTAssertTrue(
            window.frame.contains(owner.frame),
            "the Owner header is not reachable by swiping the table:\n\(app.debugDescription)",
        )
    }

    /// At the largest size the table starts about two screens down and its last header sits off screen to the right.
    /// First scroll the reader with slow drags (no momentum) until the header row is near the middle, then drag
    /// sideways along that row, where the table's horizontal scroll view is. `app.swipeLeft()` drags across the
    /// middle of the screen, which is body text, and a drag at an off-screen y does nothing.
    private static func scrollIntoView(_ element: XCUIElement, in window: XCUIElement) {
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let height = window.frame.height
        let width = window.frame.width
        func drag(from start: CGVector, to end: CGVector) {
            origin.withOffset(start).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(end),
                withVelocity: .slow,
                thenHoldForDuration: 0.1,
            )
        }
        for _ in 0 ..< 12 {
            let midY = element.frame.midY
            if midY > height * 0.65 {
                let distance = min(midY - height * 0.45, height * 0.45)
                drag(
                    from: CGVector(dx: width / 2, dy: height * 0.75),
                    to: CGVector(dx: width / 2, dy: height * 0.75 - distance),
                )
            } else if midY < height * 0.3 {
                let distance = min(height * 0.45 - midY, height * 0.4)
                drag(
                    from: CGVector(dx: width / 2, dy: height * 0.3),
                    to: CGVector(dx: width / 2, dy: height * 0.3 + distance),
                )
            } else {
                break
            }
        }
        for _ in 0 ..< 6 where !window.frame.contains(element.frame) {
            let rowY = element.frame.midY
            drag(from: CGVector(dx: width * 0.85, dy: rowY), to: CGVector(dx: width * 0.15, dy: rowY))
        }
    }
}
