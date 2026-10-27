import UIKit
import UniformTypeIdentifiers
import XCTest

/// The code block copy button (V2): `code.copy` puts the block's source on the pasteboard. The checkmark (accessibility
/// value "Copied") lasts 1.5 s, shorter than an idle wait plus a snapshot on the hosted runner, so it isn't asserted.
/// Runs wherever `make test-ios` runs.
///
/// The test never reads the pasteboard's contents. The app wrote them, and since iOS 16 a read of another app's
/// pasteboard contents from this runner raises the "Allow Paste" prompt and blocks the runner's main thread until
/// someone answers. Nobody answers on CI, so `UIPasteboard.general.string` here hung the job until its 45 minute
/// timeout (run 40545218869). `changeCount`, `hasStrings` and `contains(pasteboardTypes:)` don't read the contents
/// and never prompt.
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
        let before = UIPasteboard.general.changeCount
        copy.tap()

        // The pasteboard can lag the tap by a moment.
        let deadline = Date().addingTimeInterval(5)
        while UIPasteboard.general.changeCount == before, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertNotEqual(UIPasteboard.general.changeCount, before, "the copy button did not write the pasteboard")
        XCTAssertTrue(UIPasteboard.general.hasStrings)
        XCTAssertTrue(UIPasteboard.general.contains(pasteboardTypes: [UTType.plainText.identifier]))
    }
}
