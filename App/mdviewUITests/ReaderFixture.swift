import Foundation

/// A Markdown document handed to the app through `ReaderLauncher`.
struct ReaderFixture {
    var name: String
    var markdown: String

    /// Needs `MDVIEW_SAMPLE_CEDAR`, which `scripts/screenshots.sh` injects.
    static func cedarTrail() throws -> ReaderFixture {
        try screenshotSample(named: "Cedar Trail.md", key: "MDVIEW_SAMPLE_CEDAR")
    }

    /// Needs `MDVIEW_SAMPLE_REVIEW`, which `scripts/screenshots.sh` injects.
    static func weeklyReview() throws -> ReaderFixture {
        try screenshotSample(named: "Weekly Review.md", key: "MDVIEW_SAMPLE_REVIEW")
    }

    /// Every block type the reader renders, under a long file name for title truncation checks.
    static let kitchenSink = ReaderFixture(
        name: "A very long file name for accessibility checks.md",
        markdown: """
        # Overview

        A short intro with a [link to the docs](https://example.com/docs) in it.

        ## Tasks

        - Plan
          - Outline
          - Review
        - Build

        1. First
        2. Second
        3. Third

        - [ ] Draft
        - [x] Ship

        ## Data

        | Id | Name | Team | Status | Due | Score | Owner |
        | --- | --- | --- | --- | --- | --- | --- |
        | 1 | Alpha | Core | Open | Mon | 10 | Ada |
        | 2 | Beta | Web | Done | Tue | 20 | Grace |

        ### Code

        ```swift
        struct Greeter {
            func greet(_ name: String) -> String { "Hello, \\(name)" }
        }
        ```

        > A block quote that closes the document.
        """,
    )

    private static func screenshotSample(named name: String, key: String) throws -> ReaderFixture {
        guard let text = ProcessInfo.processInfo.environment[key], !text.isEmpty else {
            throw ReaderFixtureError.missingSample(name)
        }
        return ReaderFixture(name: name, markdown: text)
    }
}

enum ReaderFixtureError: Error, CustomStringConvertible {
    case missingSample(String)

    var description: String {
        switch self {
        case let .missingSample(name):
            "Missing screenshot sample \(name). scripts/screenshots.sh injects it into the test environment."
        }
    }
}
