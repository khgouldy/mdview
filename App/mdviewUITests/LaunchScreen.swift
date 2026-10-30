import XCTest

/// The system launch screen (`DocumentGroupLaunchScene`).
///
/// On iOS 26 the launch scene redraws the app's actions as its own buttons. Those keep the label but not the
/// accessibility identifier, which stays on a hidden, unhittable source copy (`launch.help` at hit point {-1, -1} in
/// CI). So actions are found by label among the hittable buttons, through the More… menu when iOS folds them into one.
@MainActor
enum LaunchScreen {
    static let pasteLabel = "Paste"
    static let helpLabel = "How to Open Files"

    /// iOS 26 shows one launch action as a button and folds two or more into a "More…" menu (CI run 40507377953).
    static let moreLabel = "More…"

    /// The visible action with this label, opening the "More…" menu if the actions are folded into it. Nil if neither
    /// the action nor More… becomes hittable within the timeout.
    static func action(_ label: String, in app: XCUIApplication, timeout: TimeInterval = 15) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let button = hittableButton(label, in: app) {
                return button
            }
            if let more = hittableButton(moreLabel, in: app) {
                more.tap()
                let menuDeadline = Date().addingTimeInterval(5)
                repeat {
                    if let button = hittableButton(label, in: app) {
                        return button
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                } while Date() < menuDeadline
                return nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return nil
    }

    /// Whether the launch screen is showing: the action itself or the More… menu that holds it.
    static func isShowing(_ label: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if hittableButton(label, in: app) != nil || hittableButton(moreLabel, in: app) != nil {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline
        return false
    }

    private static func hittableButton(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        for index in 0 ..< matches.count {
            let button = matches.element(boundBy: index)
            if button.exists, button.isHittable {
                return button
            }
        }
        return nil
    }

    /// Launches YAMD with this text on the pasteboard, put there by the app itself (`MDVIEW_SEED_PASTEBOARD`), so
    /// tapping Paste shows no "Allow Paste" prompt. That prompt blocks the app's main thread, and XCUITest queries
    /// on the app then time out.
    static func launch(pasteboard text: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["MDVIEW_SEED_PASTEBOARD"] = text
        app.launch()
        return app
    }
}
