import XCTest
@testable import MDCore

final class SectionSplitterTests: XCTestCase {
    // MARK: sections

    func testAtOrBelowThresholdIsOneSection() {
        let small = "# One\n\ntext\n\n# Two\n\nmore\n"
        XCTAssertEqual(SectionSplitter.sections(small), [small])
        let exact = padded("# A\n\n# B\n", toBytes: SectionSplitter.defaultMinimumBytes)
        XCTAssertEqual(exact.utf8.count, SectionSplitter.defaultMinimumBytes)
        XCTAssertEqual(SectionSplitter.sections(exact), [exact])
    }

    func testEmptyInputIsOneEmptySection() {
        XCTAssertEqual(SectionSplitter.sections(""), [""])
        XCTAssertEqual(SectionSplitter.sections("", minimumBytes: 0), [""])
    }

    func testCutsBeforeEveryATXLevelAboveThreshold() {
        let text = "intro\n# H1\na\n## H2\nb\n### H3\nc\n#### H4\nd\n##### H5\ne\n###### H6\nf\n"
        XCTAssertEqual(
            SectionSplitter.sections(text, minimumBytes: 0),
            ["intro\n", "# H1\na\n", "## H2\nb\n", "### H3\nc\n", "#### H4\nd\n", "##### H5\ne\n", "###### H6\nf\n"],
        )
    }

    func testDocumentStartingWithHeadingHasNoEmptyFirstSection() {
        let text = "# First\nbody\n# Second\nbody\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), ["# First\nbody\n", "# Second\nbody\n"])
    }

    func testOnlyRealATXHeadingsCut() {
        let text = """
        top
        #hashtag is an Obsidian tag
        ####### seven hashes is a paragraph
         # indented one space is a heading, but not at column 0
        #
        \\# escaped
        #\theading after a tab
        end

        """
        XCTAssertEqual(
            SectionSplitter.sections(text, minimumBytes: 0),
            [
                "top\n#hashtag is an Obsidian tag\n####### seven hashes is a paragraph\n"
                    + " # indented one space is a heading, but not at column 0\n#\n\\# escaped\n",
                "#\theading after a tab\nend\n",
            ],
        )
    }

    func testHeadingsInsideFencesDoNotCut() {
        let text = """
        # Real
        ```bash
        # a shell comment
        ```
        ~~~~
        # tilde fence
        ```
        # still inside: a backtick line does not close a tilde fence
        ~~~~
        ````md
        ```
        # still inside: three backticks do not close four
        ````
        # After

        """
        let sections = SectionSplitter.sections(text, minimumBytes: 0)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.last, "# After\n")
        XCTAssertEqual(sections.joined(), text)
    }

    func testIndentedFenceUpToThreeSpacesOpensAndCloses() {
        let text = "a\n   ```\n# inside\n   ```\n# out\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), ["a\n   ```\n# inside\n   ```\n", "# out\n"])
    }

    func testFourSpaceIndentIsNotAFence() {
        let text = "a\n    ```\n# out\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), ["a\n    ```\n", "# out\n"])
    }

    func testBacktickFenceWithBacktickInInfoIsNotAFence() {
        let text = "a\n``` not `a` fence\n# out\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), ["a\n``` not `a` fence\n", "# out\n"])
    }

    func testUnclosedFenceRunsToTheEnd() {
        let text = "a\n```\n# inside\n# still inside\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), [text])
    }

    func testFenceCloseNeedsOnlyTrailingWhitespace() {
        let text = "```\n``` x\n# inside\n```  \n# out\n"
        XCTAssertEqual(SectionSplitter.sections(text, minimumBytes: 0), ["```\n``` x\n# inside\n```  \n", "# out\n"])
    }

    func testSetextHeadingsDoNotCut() {
        let text = "Intro\n\nTitle\n=====\n\nbody\n\nSubtitle\n--------\n\nmore\n# ATX\nend\n"
        XCTAssertEqual(
            SectionSplitter.sections(text, minimumBytes: 0),
            ["Intro\n\nTitle\n=====\n\nbody\n\nSubtitle\n--------\n\nmore\n", "# ATX\nend\n"],
        )
    }

    func testHTMLCommentsAndRawBlocksDoNotCut() {
        let text = """
        a
        <!--
        # commented out
        -->
        <!-- one line --> trailing
        # cut 1
        <PRE class="x">
        # raw
        </pre>
        <script>
        # raw
        </script>
        # cut 2

        """
        let sections = SectionSplitter.sections(text, minimumBytes: 0)
        XCTAssertEqual(sections.map { $0.split(separator: "\n").first ?? "" }, ["a", "# cut 1", "# cut 2"])
        XCTAssertEqual(sections.joined(), text)
    }

    func testJoinReproducesInputExactly() {
        let inputs = [
            PerfFixtures.note(bytes: 200 * 1024),
            "# no trailing newline\nbody\n# last",
            "\n\n# blank lines first\n\n\n# and between\n\n",
            "Unicode: café ✓ 日本語\n# 見出し\nテキスト\n# 🎉 emoji\n",
        ]
        for input in inputs {
            let sections = SectionSplitter.sections(input, minimumBytes: 0)
            XCTAssertEqual(sections.joined(), input)
            XCTAssertFalse(sections.contains(""), "no empty sections")
        }
    }

    func testCRLFCutsAtTheSameLines() {
        let unix = """
        intro
        ```
        # fenced
        ```
        Title
        ===
        # One
        body
        ## Two
        ~~~
        # fenced
        ~~~
        end

        """
        let crlf = unix.replacingOccurrences(of: "\n", with: "\r\n")
        let lfSections = SectionSplitter.sections(unix, minimumBytes: 0)
        let crlfSections = SectionSplitter.sections(crlf, minimumBytes: 0)
        XCTAssertEqual(lfSections.count, 3)
        XCTAssertEqual(crlfSections, lfSections.map { $0.replacingOccurrences(of: "\n", with: "\r\n") })
        XCTAssertEqual(crlfSections.joined(), crlf)
    }

    func testLargeFixtureSplitsAboveThresholdOnly() {
        let large = PerfFixtures.note(bytes: 200 * 1024)
        let sections = SectionSplitter.sections(large)
        XCTAssertGreaterThan(sections.count, 1)
        XCTAssertEqual(sections.joined(), large)
        for section in sections.dropFirst() {
            XCTAssertTrue(section.hasPrefix("#"), "every later section starts at a heading")
        }
    }

    // MARK: grouped

    func testGroupedJoinsSmallSectionsUntilTarget() {
        let sections = ["aaaa", "# b\n", "# c\n", "# dddddddd\n", "# e\n"]
        let groups = SectionSplitter.grouped(sections, targetBytes: 8)
        XCTAssertEqual(groups, ["aaaa# b\n", "# c\n# dddddddd\n", "# e\n"])
        XCTAssertEqual(groups.joined(), sections.joined())
    }

    func testGroupedKeepsSingleAndEmptyInputs() {
        XCTAssertEqual(SectionSplitter.grouped([], targetBytes: 10), [])
        XCTAssertEqual(SectionSplitter.grouped(["only"], targetBytes: 10), ["only"])
    }

    // MARK: link reference definitions

    func testCollectsLinkDefinitionsOutsideCode() {
        let text = """
        # Changelog
        See [1.0.0] and [the docs][Docs].

        [1.0.0]: https://example.com/compare/0.9...1.0
        [docs]:   <https://example.com/docs> "Docs title"
        [^1]: a footnote is not a definition
        [bad]: two words
        text
        [para]: https://example.com/continues-a-paragraph
        ```
        [code]: https://example.com/in-code
        ```

        """
        let definitions = SectionSplitter.linkDefinitions(in: text)
        XCTAssertEqual(definitions.map(\.label), ["1.0.0", "docs"])
        XCTAssertEqual(definitions.first?.line, "[1.0.0]: https://example.com/compare/0.9...1.0")
    }

    func testDefinitionsUsedBySectionMatchCaseInsensitively() {
        let definitions = SectionSplitter
            .linkDefinitions(in: "\n[One  Two]: https://a.example\n\n[three]: https://b.example\n")
        XCTAssertEqual(definitions.map(\.label), ["one two", "three"])
        let used = SectionSplitter.definitions(usedBy: "## [one two]\nSee [x][THREE].\n", from: definitions)
        XCTAssertEqual(used.map(\.label), ["one two", "three"])
        XCTAssertEqual(SectionSplitter.definitions(usedBy: "## Nothing here\n", from: definitions), [])
    }

    func testDefinitionLinesDoNotCountAsUses() {
        let definitions = SectionSplitter.linkDefinitions(in: "\n[a]: https://a.example\n")
        XCTAssertEqual(SectionSplitter.definitions(usedBy: "# Refs\n\n[a]: https://a.example\n", from: definitions), [])
    }

    func testNoDefinitionsAppendedToSectionEndingInsideFence() {
        let definitions = SectionSplitter.linkDefinitions(in: "\n[a]: https://a.example\n")
        XCTAssertEqual(SectionSplitter.definitions(usedBy: "# Last\nsee [a]\n```\nopen fence\n", from: definitions), [])
    }

    func testParseInputAppendsUsedDefinitions() {
        let definitions = SectionSplitter.linkDefinitions(in: "\n[a]: https://a.example\n")
        XCTAssertEqual(
            SectionSplitter.parseInput(for: "# A\nsee [a]", definitions: definitions),
            "# A\nsee [a]\n\n[a]: https://a.example\n",
        )
        XCTAssertEqual(SectionSplitter.parseInput(for: "# B\nplain\n", definitions: definitions), "# B\nplain\n")
    }

    // MARK: helpers

    private func padded(_ text: String, toBytes bytes: Int) -> String {
        text + String(repeating: "x", count: bytes - text.utf8.count)
    }
}
