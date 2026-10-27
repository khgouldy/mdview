import Foundation
import XCTest
@testable import MDCore

/// Hard time budgets for the MDCore stages on the generated notes (docs/perf/README.md).
///
/// Each stage runs five times and the median is compared with its budget: 3x the median recorded on the
/// development Mac, rounded up to the next 50 ms. That lets noise through and catches a quadratic regression.
final class PerformanceTests: XCTestCase {
    private static let runs = 5
    private static let query = "render"

    /// Medians in milliseconds from `swift test` (debug build). Keep in step with docs/perf/README.md.
    private enum Recorded {
        static let decode20k = 0.005
        static let decode1m = 0.07
        static let prepare20k = 2.65
        static let prepare1m = 135.0
        static let search20k = 0.26
        static let search1m = 150.0
    }

    private let note20k = PerfFixtures.note(bytes: 20 * 1024)
    private let note1m = PerfFixtures.note(bytes: 1024 * 1024)

    func testFixtureSizesAndDeterminism() {
        XCTAssertEqual(PerfFixtures.note(bytes: 20 * 1024), note20k)
        for (size, note) in [(20 * 1024, note20k), (1024 * 1024, note1m)] {
            XCTAssertLessThanOrEqual(note.utf8.count, size)
            XCTAssertGreaterThan(note.utf8.count, size - 200)
            XCTAssertTrue(note.hasSuffix("\n"))
        }
    }

    /// The committed files must equal the generator. `MDVIEW_WRITE_PERF_FIXTURES=1 swift test` rewrites them.
    func testCommittedFixturesMatchTheGenerator() throws {
        let write = ProcessInfo.processInfo.environment["MDVIEW_WRITE_PERF_FIXTURES"] == "1"
        for (file, bytes) in PerfFixtures.sizes {
            let url = PerfFixtures.directory.appendingPathComponent(file)
            let expected = PerfFixtures.note(bytes: bytes)
            if write {
                try FileManager.default.createDirectory(at: PerfFixtures.directory, withIntermediateDirectories: true)
                try Data(expected.utf8).write(to: url)
            }
            let actual = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(actual, expected, "\(file) is stale. Run MDVIEW_WRITE_PERF_FIXTURES=1 swift test.")
        }
    }

    func testDecode20k() {
        let data = Data(note20k.utf8)
        assertBudget("decode 20 KB", recorded: Recorded.decode20k) { _ = TextDecoding.decode(data) }
    }

    func testDecode1m() {
        let data = Data(note1m.utf8)
        assertBudget("decode 1 MB", recorded: Recorded.decode1m) { _ = TextDecoding.decode(data) }
    }

    func testPrepare20k() {
        assertBudget("prepare 20 KB", recorded: Recorded.prepare20k) {
            _ = RenderPipeline.prepare(note20k, obsidian: true)
        }
    }

    func testPrepare1m() {
        assertBudget("prepare 1 MB", recorded: Recorded.prepare1m) {
            _ = RenderPipeline.prepare(note1m, obsidian: true)
        }
    }

    func testSearch20k() {
        assertBudget("search 20 KB", recorded: Recorded.search20k) {
            XCTAssertFalse(TextSearch.ranges(of: Self.query, in: note20k).isEmpty)
        }
    }

    func testSearch1m() {
        assertBudget("search 1 MB", recorded: Recorded.search1m) {
            XCTAssertFalse(TextSearch.ranges(of: Self.query, in: note1m).isEmpty)
        }
    }

    func testBudgetRoundsUpToFiftyMilliseconds() {
        XCTAssertEqual(Self.budget(forRecorded: 0.1), 50)
        XCTAssertEqual(Self.budget(forRecorded: 16), 50)
        XCTAssertEqual(Self.budget(forRecorded: 17), 100)
        XCTAssertEqual(Self.budget(forRecorded: 135), 450)
    }

    /// 3x the recorded median, rounded up to the next multiple of 50 ms (and never below 50 ms).
    static func budget(forRecorded median: Double) -> Double {
        max(50, (median * 3 / 50).rounded(.up) * 50)
    }

    private func assertBudget(
        _ label: String,
        recorded: Double,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ work: () -> Void,
    ) {
        work() // Warm up caches and lazy statics so the five timed runs are steady.
        var samples: [Double] = []
        for _ in 0 ..< Self.runs {
            let start = ContinuousClock.now
            work()
            let elapsed = start.duration(to: .now)
            samples.append(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
        }
        let median = samples.sorted()[Self.runs / 2]
        let budget = Self.budget(forRecorded: recorded)
        print("perf \(label): median \(String(format: "%.2f", median)) ms, budget \(budget) ms")
        XCTAssertLessThanOrEqual(
            median,
            budget,
            "\(label) took \(median) ms; budget \(budget) ms",
            file: file,
            line: line,
        )
    }
}
