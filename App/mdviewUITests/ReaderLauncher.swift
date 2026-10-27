import XCTest

/// Builds an `XCUIApplication` that opens a fixture straight in the reader through the debug-only
/// `MDVIEW_SCREENSHOT_*` launch environment (see `App/mdview/ScreenshotLaunch.swift`). Does not launch it.
enum ReaderLauncher {
    static func app(
        fixture: ReaderFixture,
        scheme: String,
        contentSize: String? = nil,
        query: String? = nil,
        extraEnvironment: [String: String] = [:],
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-document", fixture.name,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launchEnvironment["MDVIEW_SCREENSHOT_NAME"] = fixture.name
        app.launchEnvironment["MDVIEW_SCREENSHOT_MARKDOWN"] = fixture.markdown
        app.launchEnvironment["MDVIEW_SCREENSHOT_SCHEME"] = scheme
        // Every launch starts from default reading settings and Rendered; see `MDVIEW_RESET_READING_SETTINGS` in
        // `mdviewApp.swift`. `extraEnvironment` can turn it off with "0".
        app.launchEnvironment["MDVIEW_RESET_READING_SETTINGS"] = "1"
        if let query {
            app.launchEnvironment["MDVIEW_SCREENSHOT_QUERY"] = query
        }
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        return app
    }
}
