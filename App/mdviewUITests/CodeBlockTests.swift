import UIKit
import XCTest

/// The code block copy button (V2): `code.copy` puts the block's source on the pasteboard and says "Copied".
/// Runs wherever `make test-ios` runs.
@MainActor
final class CodeBlockTests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testCopyButtonPutsCodeOnPasteboard() {
        let app = ReaderLauncher.app(fixture: .kitchenSink, scheme: "light")
        app.launchArguments += ["-reader.mode", "rendered"]
        app.launch()

        let copy = app.descendants(matching: .any)["code.copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(copy.label, "Copy code")
        UIPasteboard.general.string = ""
        copy.tap()

        let copied = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Copied")).firstMatch
        XCTAssertTrue(copied.waitForExistence(timeout: 5), app.debugDescription)
        // The pasteboard can lag the tap by a moment.
        let deadline = Date().addingTimeInterval(5)
        while !(UIPasteboard.general.string ?? "").contains("struct"), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(
            (UIPasteboard.general.string ?? "").contains("struct"),
            "pasteboard: \(UIPasteboard.general.string ?? "nil")",
        )
    }
}
