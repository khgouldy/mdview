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
        // The header sits off screen to the right until the table is swiped.
        for _ in 0 ..< 6 where !owner.isHittable {
            app.swipeLeft()
        }
        XCTAssertTrue(owner.isHittable, "the Owner header is not reachable by swiping the table")
    }
}
