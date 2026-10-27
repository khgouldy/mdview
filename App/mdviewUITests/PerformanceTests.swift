import XCTest

/// Open-to-render performance on the 20 KB fixture (docs/perf/README.md). Runs wherever `make test-ios` runs.
///
/// `reader.rendered` is matched as any element type: SwiftUI exposes it as a ScrollView, so an `otherElements` query
/// never matched and every run waited out its timeout (the 28-30 s "launch to rendered" CI failures).
///
/// A simulator isn't representative of a phone, so the test records the launch and the app's `open` signpost for
/// trend reports and fails only when a launch to the first rendered screen takes longer than three times the budget.
final class PerformanceTests: XCTestCase {
    /// Plan 3.3: a typical note reaches the first rendered screen in under 500 ms.
    private static let openBudget: TimeInterval = 0.5
    /// A launch is not part of the `open` interval, and a cold simulator launch takes a few seconds.
    private static let launchAllowance: TimeInterval = 5

    func testOpenTypicalNote() throws {
        let fixture = try Self.fixture20k()
        let metrics: [XCTMetric] = [
            XCTApplicationLaunchMetric(),
            XCTOSSignpostMetric(subsystem: "us.par72.mdview", category: "Performance", name: "open"),
        ]
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: metrics, options: options) {
            let app = ReaderLauncher.app(fixture: fixture, scheme: "light")
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["reader.rendered"].firstMatch.waitForExistence(timeout: 15))
            app.terminate()
        }
    }

    /// The only hard failure: launch to rendered, within 3x the 500 ms open budget plus the launch allowance.
    func testOpenStaysUnderThreeTimesBudget() throws {
        let fixture = try Self.fixture20k()
        let app = ReaderLauncher.app(fixture: fixture, scheme: "light")
        // Warm-up launch. The first launch after install also pays one-time system work (it took 9.4 s in CI run
        // 40504894387, while the five measured launches in testOpenTypicalNote averaged 2.3 s plus a 0.9 s open).
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["reader.rendered"].firstMatch.waitForExistence(timeout: 30))
        app.terminate()
        let start = ContinuousClock.now
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["reader.rendered"].firstMatch.waitForExistence(timeout: 15))
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        XCTAssertLessThan(seconds, Self.openBudget * 3 + Self.launchAllowance, "launch to rendered took \(seconds) s")
        app.terminate()
    }

    /// `docs/perf/fixtures/note-20k.md`, found from this file's path (the simulator shares the Mac's file system).
    private static func fixture20k() throws -> ReaderFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/perf/fixtures/note-20k.md")
        return try ReaderFixture(name: "note-20k.md", markdown: String(contentsOf: url, encoding: .utf8))
    }
}
