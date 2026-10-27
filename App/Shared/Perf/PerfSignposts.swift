import Foundation
import os

/// Open-to-render timing for the reader and the share extension (docs/perf/README.md).
///
/// Intervals `decode`, `prepare`, `parse`, `layout` and the whole-open interval `open` go to
/// `OSSignposter(subsystem: "us.par72.mdview", category: "Performance")`, and the event `firstRender` closes `open`.
/// With `MDVIEW_PERF_LOG=1` in a DEBUG build, `firstRender` also logs one line:
/// `perf open=<ms> decode=<ms> prepare=<ms> parse=<ms> layout=<ms> bytes=<n>`.
/// Nothing here reads or writes user data, and nothing is stored beyond one open.
enum PerfSignposts {
    static let subsystem = "us.par72.mdview"
    static let category = "Performance"

    private static let signposter = OSSignposter(subsystem: subsystem, category: category)
    private static let store = OSAllocatedUnfairLock(initialState: Store())

    /// One running interval. `end()` closes the signpost and records the duration for the console line.
    struct Interval: Sendable {
        fileprivate let name: StaticString
        fileprivate let state: OSSignpostIntervalState
        fileprivate let start: ContinuousClock.Instant

        func end() {
            PerfSignposts.signposter.endInterval(name, state)
            let elapsed = start.duration(to: .now)
            PerfSignposts.record("\(name)", elapsed)
        }
    }

    /// Starts an interval. Call `end()` on the result, from any thread.
    static func interval(_ name: StaticString) -> Interval {
        Interval(name: name, state: signposter.beginInterval(name, id: signposter.makeSignpostID()), start: .now)
    }

    /// Runs `body` inside an interval.
    static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let running = interval(name)
        defer { running.end() }
        return try body()
    }

    static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }

    /// Starts the `open` interval: `ReaderView.task` in the app, `viewDidLoad` in the extension.
    /// Durations recorded earlier (the app decodes in `TextDocument.init`) stay; stale ones from a previous open go.
    static func beginOpen(bytes: Int) {
        let running = interval("open")
        store.withLock { store in
            store.durations = store.durations.filter { $0.key == "decode" }
            store.bytes = bytes
            store.open = running
        }
    }

    /// The extension learns the size only after it has loaded the item.
    static func noteBytes(_ bytes: Int) {
        store.withLock { $0.bytes = bytes }
    }

    /// The first rendered content with a non-zero height. Only the first call per `beginOpen` counts.
    static func firstRender() {
        let finished = store.withLock { store -> Interval? in
            defer { store.open = nil }
            return store.open
        }
        guard let finished else {
            return
        }
        event("firstRender")
        finished.end()
        logSummary()
    }

    fileprivate static func record(_ key: String, _ elapsed: Duration) {
        let milliseconds = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        store.withLock { $0.durations[key] = milliseconds }
    }

    private struct Store {
        var durations: [String: Double] = [:]
        var bytes = 0
        var open: Interval?
    }

    #if DEBUG
        private static let logger = Logger(subsystem: subsystem, category: category)
        private static let logsSummary = ProcessInfo.processInfo.environment["MDVIEW_PERF_LOG"] == "1"

        private static func logSummary() {
            let snapshot = store.withLock { store -> (durations: [String: Double], bytes: Int) in
                defer { store.durations = [:] }
                return (store.durations, store.bytes)
            }
            guard logsSummary else {
                return
            }
            func ms(_ key: String) -> String {
                String(format: "%.1f", snapshot.durations[key] ?? 0)
            }
            let line = "perf open=\(ms("open")) decode=\(ms("decode")) prepare=\(ms("prepare"))"
                + " parse=\(ms("parse")) layout=\(ms("layout")) bytes=\(snapshot.bytes)"
            logger.info("\(line, privacy: .public)")
        }
    #else
        private static func logSummary() {
            store.withLock { $0.durations = [:] }
        }
    #endif
}
