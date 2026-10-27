import Foundation

/// Deterministic Markdown notes for the performance tests and `docs/perf/fixtures`.
/// ASCII only, so the byte count equals the character count.
enum PerfFixtures {
    static let sizes: [(file: String, bytes: Int)] = [
        ("note-20k.md", 20 * 1024),
        ("note-200k.md", 200 * 1024),
        ("note-1m.md", 1024 * 1024),
    ]

    /// `docs/perf/fixtures`, found from this file's path.
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/perf/fixtures", isDirectory: true)
    }

    /// A note of at most `bytes` bytes that ends on a whole line. The same input always gives the same note.
    /// It repeats a mix of headings, prose, lists, tables, code, wikilinks and remote images, about 300 lines per 20
    /// KB.
    static func note(bytes: Int) -> String {
        var output = "---\ntitle: Performance note\ntags: [perf, fixture]\n---\n\n"
        var section = 0
        while output.utf8.count < bytes {
            let block = block(section)
            if output.utf8.count + block.utf8.count > bytes {
                // Fill the tail with whole prose lines, then stop.
                var lineNumber = 0
                while true {
                    let line = "Closing line \(lineNumber) of the performance note.\n"
                    guard output.utf8.count + line.utf8.count <= bytes else {
                        break
                    }
                    output += line
                    lineNumber += 1
                }
                break
            }
            output += block
            section += 1
        }
        return output
    }

    private static let words = [
        "reader", "document", "render", "markdown", "heading", "parse", "layout", "scroll", "select", "search",
        "note", "list", "table", "token", "stream", "cache", "budget", "frame", "measure", "signal",
    ]

    /// `count` words picked by a small linear congruential generator, so no randomness leaks in.
    private static func sentence(_ seed: Int, count: Int = 12) -> String {
        var state = UInt64(seed &* 2_654_435_761 &+ 1)
        var picked: [String] = []
        for _ in 0 ..< count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            picked.append(words[Int((state >> 33) % UInt64(words.count))])
        }
        let text = picked.joined(separator: " ")
        return text.prefix(1).uppercased() + text.dropFirst() + "."
    }

    private static func block(_ index: Int) -> String {
        let n = index // swiftlint:disable:this identifier_name
        return """
        ## Section \(n)

        \(sentence(n)) \(sentence(n + 1)) See [[Note \(n % 17)]] and the [docs](https://example.com/docs/\(n)).
        \(sentence(n + 2)) **\(sentence(n + 3, count: 3))** and `inline\(n)` code.

        - \(sentence(n + 4, count: 6))
        - \(sentence(n + 5, count: 6))
          - \(sentence(n + 6, count: 5))
        - [x] \(sentence(n + 7, count: 4))

        | Id | Name | Score |
        | --- | --- | --- |
        | \(n) | \(sentence(n + 8, count: 2)) | \(n * 7 % 100) |

        ```swift
        func step\(n)(_ value: Int) -> Int {
            let doubled = value * 2
            return doubled + \(n)
        }
        ```

        ![diagram \(n)](https://example.com/images/\(n).png)

        > \(sentence(n + 9))


        """
    }
}
