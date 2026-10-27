import UIKit
import XCTest

/// `performAccessibilityAudit` over each screen. CI only (`make test-ios`); `make test` just compiles this.
///
/// Reading a failure: open the `.xcresult` from the CI run (Xcode, or `xcrun xcresulttool get test-results tests
/// --path <bundle>`), pick the failed test, and read the issue line. It is `<audit type>: <description>` and names
/// the element. The attached "App UI hierarchy" snapshot shows where it sits. Fix the view. Ignore an issue only for
/// an element the system owns, by adding a named `KnownSystemIssue` with a comment. Never ignore a whole audit type.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    private static let xxxl = "UICTContentSizeCategoryAccessibilityXXXL"

    override nonisolated func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testRenderedLight() throws {
        let app = launchReader(scheme: "light")
        try audit(app)
    }

    func testRenderedDark() throws {
        let app = launchReader(scheme: "dark")
        try audit(app)
    }

    func testSource() throws {
        let app = launchReader(scheme: "light", mode: "source")
        XCTAssertTrue(
            app.descendants(matching: .any)["reader.source"].firstMatch.waitForExistence(timeout: 20),
            app.debugDescription,
        )
        try audit(app)
    }

    func testFindActive() throws {
        let app = launchReader(scheme: "light", query: "Draft")
        let count = app.descendants(matching: .any)["reader.searchCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 10), app.debugDescription)
        try audit(app)
    }

    func testAccessibilityXXXLText() throws {
        let app = launchReader(scheme: "light", contentSize: Self.xxxl)
        try audit(app)
    }

    /// The Done and Not done labels come from `TaskMarker.label`; the kitchen sink holds one of each.
    func testTaskCheckboxesAreLabeled() {
        let app = launchReader(scheme: "light")
        for label in ["Done", "Not done"] {
            let checkbox = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
                .firstMatch
            XCTAssertTrue(
                checkbox.waitForExistence(timeout: 20),
                "No \(label) checkbox element:\n\(app.debugDescription)",
            )
        }
    }

    func testHelpSheet() throws {
        let app = launchReader(scheme: "light")
        let menu = app.buttons["reader.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), app.debugDescription)
        menu.tap()
        let help = app.buttons["reader.help"]
        XCTAssertTrue(help.waitForExistence(timeout: 5), app.debugDescription)
        help.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["help.root"].firstMatch.waitForExistence(timeout: 10),
            app.debugDescription,
        )
        try audit(app)
    }

    func testPastedReader() throws {
        UIPasteboard.general.string = "# Pasted heading\n\nSome **pasted** text."
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let byIdentifier = app.buttons["launch.paste"]
        let paste = byIdentifier.waitForExistence(timeout: 15) ? byIdentifier : app.buttons["Paste"]
        guard paste.waitForExistence(timeout: 5), paste.isHittable else {
            throw XCTSkip("The system paste control is not exposed or hittable, so the pasted reader can't be reached")
        }
        paste.tap()
        guard app.buttons["paste.done"].waitForExistence(timeout: 10) else {
            throw XCTSkip("The system paste control did not accept XCUITest's tap, so the pasted reader never opened")
        }
        try audit(app)
    }

    /// The extension runs in the share sheet's remote view. This audits what the host app can reach there, and
    /// skips when the sheet or MdV's row can't be found (`ShareSheetTests` fails on those).
    func testShareExtensionReader() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MDVIEW_SHARE_HARNESS"] = "textDocument"
        app.launchEnvironment["MDVIEW_SHARE_MARKDOWN"] = ReaderFixture.sharedNote.markdown
        app.launch()

        let trigger = app.buttons["harness.share"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 15), "harness.share missing")
        trigger.tap()
        guard app.otherElements["ActivityListView"].waitForExistence(timeout: 15) else {
            throw XCTSkip("Share sheet not found (app.otherElements[\"ActivityListView\"])")
        }
        let item = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND elementType IN %@", "MdV", [
                XCUIElement.ElementType.button.rawValue,
                XCUIElement.ElementType.cell.rawValue,
            ]))
            .firstMatch
        guard item.waitForExistence(timeout: 5) else {
            throw XCTSkip("MdV is not in the visible share row; ShareSheetTests covers finding it")
        }
        item.tap()
        XCTAssertTrue(app.buttons["share.done"].waitForExistence(timeout: 20), "share.done missing")
        try audit(app)
    }

    // MARK: Helpers

    /// A system-owned element's issue that is safe to ignore: one audit type on one system element, matched by its
    /// label and/or a class name in the issue's description.
    private struct KnownSystemIssue {
        var type: XCUIAccessibilityAuditType
        var elementLabel: String?
        var descriptionContains: String?
        /// Why this is not ours to fix.
        var reason: String

        func matches(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
            guard issue.auditType == type else {
                return false
            }
            if let elementLabel, issue.element?.label != elementLabel {
                return false
            }
            if let descriptionContains, !issue.detailedDescription.contains(descriptionContains) {
                return false
            }
            return true
        }
    }

    /// Each entry was named by a CI audit failure (iOS 26.5 simulator).
    private static let knownSystemIssues: [KnownSystemIssue] = [
        KnownSystemIssue(
            type: .textClipped,
            elementLabel: "Find",
            descriptionContains: "UISearchBarTextField",
            reason: "The `.searchable` field is UIKit's UISearchBarTextField; the navigation bar drawer fixes its "
                + "height. MdV only supplies the prompt.",
        ),
        KnownSystemIssue(
            type: .contrast,
            elementLabel: "Find",
            descriptionContains: "UISearchBarTextField",
            reason: "UIKit draws the search field's placeholder and fill on the bar's glass.",
        ),
        KnownSystemIssue(
            type: .hitRegion,
            elementLabel: nil,
            descriptionContains: "_UITextFieldClearButton",
            reason: "The search field's clear button belongs to UISearchBar, which sizes it.",
        ),
        KnownSystemIssue(
            type: .dynamicType,
            elementLabel: "Done",
            descriptionContains: nil,
            reason: "A toolbar Done button is a UIKit bar button item. Bar items keep a fixed size and show the "
                + "Large Content Viewer on a long press instead of scaling.",
        ),
    ]

    /// iOS 26 fades and blurs content that scrolls under the navigation bar and the bottom toolbar (the scroll edge
    /// effect, about this far past each bar). The contrast audit samples those pixels, so text partly under a bar fails
    /// though nobody reads it there. Contrast is still audited for everything clear of the bars.
    private static let scrollEdgeEffectDepth: CGFloat = 60

    private static func barRegions(in app: XCUIApplication) -> [CGRect] {
        var regions: [CGRect] = []
        let navigationBar = app.navigationBars.firstMatch
        if navigationBar.exists {
            let frame = navigationBar.frame
            regions.append(CGRect(
                x: 0,
                y: 0,
                width: .greatestFiniteMagnitude,
                height: frame.maxY + scrollEdgeEffectDepth,
            ))
        }
        let toolbar = app.toolbars.firstMatch
        if toolbar.exists {
            let frame = toolbar.frame
            regions.append(CGRect(
                x: 0,
                y: frame.minY - scrollEdgeEffectDepth,
                width: .greatestFiniteMagnitude,
                height: .greatestFiniteMagnitude,
            ))
        }
        return regions
    }

    private static func isContrastUnderBars(_ issue: XCUIAccessibilityAuditIssue, bars: [CGRect]) -> Bool {
        guard issue.auditType == .contrast, let frame = issue.element?.frame, !frame.isEmpty else {
            return false
        }
        return bars.contains { $0.intersects(frame) }
    }

    /// Runs every audit and reports all issues at once, each with its type, description and element, so one CI run
    /// shows everything to fix instead of stopping at the first issue.
    private func audit(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        let found = AuditFindings()
        let bars = Self.barRegions(in: app)
        try app.performAccessibilityAudit { issue in
            let ignored = Self.knownSystemIssues.contains(where: { $0.matches(issue) })
                || Self.isContrastUnderBars(issue, bars: bars)
            if ignored {
                return true
            }
            found.add(Self.describe(issue))
            return true
        }
        if !found.lines.isEmpty {
            XCTFail(
                "\(found.lines.count) accessibility audit issue(s):\n" + found.lines.joined(separator: "\n"),
                file: file,
                line: line,
            )
        }
    }

    private static func describe(_ issue: XCUIAccessibilityAuditIssue) -> String {
        let element = issue.element
        let what = element.map { element in
            "type \(element.elementType.rawValue), id '\(element.identifier)', label '\(element.label)', "
                + "frame \(NSCoder.string(for: element.frame))"
        } ?? "no element"
        let type = auditTypeName(issue.auditType)
        return "- \(type): \(issue.compactDescription). \(issue.detailedDescription) [\(what)]"
    }

    private static func auditTypeName(_ type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"), (.trait, "trait"),
        ]
        let matched = names.filter { type.contains($0.0) }.map(\.1)
        return matched.isEmpty ? "auditType \(type.rawValue)" : matched.joined(separator: "+")
    }

    private func launchReader(
        scheme: String,
        mode: String = "rendered",
        contentSize: String? = nil,
        query: String? = nil,
    ) -> XCUIApplication {
        let app = ReaderLauncher.app(fixture: .kitchenSink, scheme: scheme, contentSize: contentSize, query: query)
        app.launchArguments += ["-reader.mode", mode]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["reader.modePicker"].firstMatch.waitForExistence(timeout: 20),
            app.debugDescription,
        )
        return app
    }
}

/// Collects audit issue descriptions from the audit handler.
private final class AuditFindings {
    private(set) var lines: [String] = []

    func add(_ line: String) {
        lines.append(line)
    }
}
