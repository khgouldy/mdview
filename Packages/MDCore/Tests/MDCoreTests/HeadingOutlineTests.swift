import Foundation
import Testing
@testable import MDCore

struct HeadingOutlineTests {
    private func titles(_ markdown: String, obsidian: Bool = true) -> [String] {
        HeadingOutline.headings(in: markdown, obsidian: obsidian).map(\.title)
    }

    @Test func `atx headings keep level and order`() {
        let headings = HeadingOutline.headings(in: "# One\n\ntext\n\n## Two\n\n###### Six\n")
        #expect(headings.map(\.level) == [1, 2, 6])
        #expect(headings.map(\.title) == ["One", "Two", "Six"])
    }

    @Test func `atx closing hashes are dropped`() {
        #expect(titles("## Closed ##\n") == ["Closed"])
    }

    @Test func `setext headings count`() {
        let headings = HeadingOutline.headings(in: "Big title\n=========\n\nSmaller\n-------\n")
        #expect(headings.map(\.level) == [1, 2])
        #expect(headings.map(\.title) == ["Big title", "Smaller"])
    }

    @Test func `inline formatting is removed from titles`() {
        let headings = HeadingOutline.headings(in: "## The `code` and *emphasis* in [a link](https://example.com)\n")
        #expect(headings.map(\.title) == ["The code and emphasis in a link"])
        #expect(headings.first?.slug == "the-code-and-emphasis-in-a-link")
    }

    @Test func `fenced code and indented code are not headings`() {
        let markdown = """
        # Real

        ```
        # not a heading
        ```

        ~~~
        ## nor this
        ~~~

            # indented code
        """
        #expect(titles(markdown) == ["Real"])
    }

    @Test func `front matter is excluded with obsidian extras`() {
        let markdown = "---\ntitle: Note\n---\n# Body\n"
        #expect(titles(markdown) == ["Body"])
    }

    @Test func `duplicates count occurrences`() {
        let headings = HeadingOutline.headings(in: "# Notes\n\n## Notes\n\n## Other\n\n## notes\n")
        #expect(headings.map(\.occurrence) == [0, 1, 0, 2])
        #expect(Set(headings.map(\.slug)) == ["notes", "other"])
    }

    @Test func `empty headings are skipped`() {
        #expect(titles("#\n\n## Kept\n") == ["Kept"])
    }

    @Test(arguments: [
        ("Hello World", "hello-world"),
        ("  Spaced   out  ", "spaced-out"),
        ("What's new?", "whats-new"),
        ("C++ & Swift", "c-swift"),
        ("Über Café", "über-café"),
        ("Step 2: Install", "step-2-install"),
        ("snake_case and kebab-case", "snakecase-and-kebab-case"),
        ("日本語 の 見出し", "日本語-の-見出し"),
    ])
    func `slug matches textual`(text: String, expected: String) {
        #expect(HeadingOutline.slug(of: text) == expected)
    }

    @Test func `small document is one section`() {
        let headings = HeadingOutline.headings(in: "# A\n\n## B\n")
        #expect(headings.map(\.section) == [0, 0])
    }

    @Test func `section indices follow the readers grouping`() {
        let filler = String(repeating: "word ", count: 400)
        var markdown = ""
        for index in 0 ..< 6 {
            markdown += "## Part \(index)\n\n\(filler)\n\n"
        }
        // Force sectioning with a tiny threshold by splitting the same way the reader does.
        let sections = SectionSplitter.grouped(SectionSplitter.sections(markdown, minimumBytes: 100), targetBytes: 4000)
        let headings = HeadingOutline.headings(inSections: sections)
        #expect(headings.map(\.title) == (0 ..< 6).map { "Part \($0)" })
        #expect(headings.map(\.section) == headings.map { heading in
            sections.firstIndex { $0.contains("## \(heading.title)\n") } ?? -1
        })
        #expect(Set(headings.map(\.section)).count > 1)
        #expect(headings.map(\.section) == headings.map(\.section).sorted())
    }

    @Test func `large document sections match the pipeline`() {
        let filler = String(repeating: "word ", count: 3000)
        let markdown = (0 ..< 12).map { "# Heading \($0)\n\n\(filler)\n" }.joined(separator: "\n")
        let headings = HeadingOutline.headings(in: markdown)
        #expect(headings.count == 12)
        #expect(headings.map(\.section).last ?? 0 > 0)
    }
}
