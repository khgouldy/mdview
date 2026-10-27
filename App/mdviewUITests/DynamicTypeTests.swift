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
        // The header sits off screen to the right until the table is swiped. `app.swipeLeft()` drags across the middle
        // of the screen, which at this size is body text, not the table, so first bring the header row near the middle
        // and then drag sideways along that row, where the table's horizontal scroll view is.
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let middleX = window.frame.width / 2
        if abs(owner.frame.midY - window.frame.height * 0.45) > window.frame.height * 0.2 {
            origin.withOffset(CGVector(dx: middleX, dy: owner.frame.midY))
                .press(
                    forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(dx: middleX, dy: window.frame.height * 0.45)),
                )
        }
        for _ in 0 ..< 6 where !owner.isHittable {
            let rowY = owner.frame.midY
            origin.withOffset(CGVector(dx: window.frame.width * 0.85, dy: rowY))
                .press(
                    forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(dx: window.frame.width * 0.15, dy: rowY)),
                )
        }
        XCTAssertTrue(
            owner.isHittable,
            "the Owner header is not reachable by swiping the table:\n\(app.debugDescription)",
        )
    }
}
