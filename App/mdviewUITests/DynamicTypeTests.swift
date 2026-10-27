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
        // At this size the table starts about two screens down and its last header sits off screen to the right.
        // First scroll the reader with slow drags (no momentum) until the header row is near the middle, then drag
        // sideways along that row, where the table's horizontal scroll view is. `app.swipeLeft()` drags across the
        // middle of the screen, which is body text, and a drag at an off-screen y does nothing.
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let height = window.frame.height
        let middleX = window.frame.width / 2
        func drag(fromY: CGFloat, toY: CGFloat) {
            origin.withOffset(CGVector(dx: middleX, dy: fromY))
                .press(
                    forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(dx: middleX, dy: toY)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.1,
                )
        }
        for _ in 0 ..< 12 {
            let midY = owner.frame.midY
            if midY > height * 0.65 {
                drag(fromY: height * 0.75, toY: height * 0.75 - min(midY - height * 0.45, height * 0.45))
            } else if midY < height * 0.3 {
                drag(fromY: height * 0.3, toY: height * 0.3 + min(height * 0.45 - midY, height * 0.4))
            } else {
                break
            }
        }
        for _ in 0 ..< 6 where !owner.isHittable {
            let rowY = owner.frame.midY
            origin.withOffset(CGVector(dx: window.frame.width * 0.85, dy: rowY))
                .press(
                    forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(dx: window.frame.width * 0.15, dy: rowY)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.1,
                )
        }
        XCTAssertTrue(
            owner.isHittable,
            "the Owner header is not reachable by swiping the table:\n\(app.debugDescription)",
        )
    }
}
