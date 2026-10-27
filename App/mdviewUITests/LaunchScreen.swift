import XCTest

/// The system launch screen (`DocumentGroupLaunchScene`).
///
/// On iOS 26 the launch scene redraws the app's actions as its own buttons. Those keep the label but not the
/// accessibility identifier, which stays on a hidden, unhittable source copy (`launch.help` at hit point {-1, -1} in
/// CI). So actions are found by label among the hittable buttons.
@MainActor
enum LaunchScreen {
    static let pasteLabel = "Paste"
    static let helpLabel = "How to Open Files"

    /// The visible button with this label, or nil if none becomes hittable within the timeout.
    static func action(_ label: String, in app: XCUIApplication, timeout: TimeInterval = 15) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for index in 0 ..< matches.count {
                let button = matches.element(boundBy: index)
                if button.exists, button.isHittable {
                    return button
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return nil
    }

    /// Taps Paste and answers iOS's "Allow Paste" prompt if it appears (the app reads `UIPasteboard` on the tap).
    static func tapPaste(_ paste: XCUIElement, in app: XCUIApplication) {
        paste.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for host in [app, springboard] {
            let allow = host.buttons["Allow Paste"]
            if allow.waitForExistence(timeout: 3) {
                allow.tap()
                return
            }
        }
    }
}
