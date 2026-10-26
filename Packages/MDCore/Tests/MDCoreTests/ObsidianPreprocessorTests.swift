import XCTest
@testable import MDCore

final class ObsidianPreprocessorTests: XCTestCase {
    func testFrontMatterIsRemoved() {
        let input = """
        ---
        title: Hello
        tags: [a, b]
        ---
        # Hello

        Body
        """
        let expected = """
        # Hello

        Body
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }

    func testAbsentFrontMatterIsUnchanged() {
        let input = """
        # Hello

        No front matter here.
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), input)
    }

    func testUnterminatedFrontMatterIsLeftAlone() {
        let input = """
        ---
        title: Hello
        tags: [a, b]
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), input)
    }

    func testFrontMatterClosedByDotsIsRemoved() {
        let input = """
        ---
        title: Hello
        ...
        # Hello
        """
        let expected = """
        # Hello
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }

    func testFrontMatterNotAtLineOneIsKept() {
        let input = """

        ---
        title: Hello
        ---
        Body
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), input)
    }

    func testWikilinkBecomesNoteName() {
        XCTAssertEqual(ObsidianPreprocessor.process("See [[Note]] today."), "See Note today.")
    }

    func testWikilinkAliasBecomesAlias() {
        XCTAssertEqual(ObsidianPreprocessor.process("See [[Note|Alias]] today."), "See Alias today.")
    }

    func testWikilinkHeadingBecomesBreadcrumb() {
        XCTAssertEqual(
            ObsidianPreprocessor.process("See [[Note#Heading]] today."),
            "See Note > Heading today.",
        )
    }

    func testFencedWikilinkIsUntouched() {
        let input = """
        ```markdown
        [[Note]]
        ```
        [[Outside]]
        """
        let expected = """
        ```markdown
        [[Note]]
        ```
        Outside
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }

    func testInlineWikilinkIsUntouched() {
        let input = "Type `[[Note]]` then [[Other]]."
        XCTAssertEqual(ObsidianPreprocessor.process(input), "Type `[[Note]]` then Other.")
    }

    func testEmbedIsUntouched() {
        let input = "See ![[diagram.png]] and [[Note]]."
        XCTAssertEqual(ObsidianPreprocessor.process(input), "See ![[diagram.png]] and Note.")
    }

    func testCalloutBlockIsUntouched() {
        let input = """
        > [!note]
        > Keep [[Note]] literal.
        [[Outside]]
        """
        let expected = """
        > [!note]
        > Keep [[Note]] literal.
        Outside
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }

    func testBlockquoteWikilinkIsRewritten() {
        XCTAssertEqual(ObsidianPreprocessor.process("> See [[Note]]"), "> See Note")
    }

    func testTildeFenceWikilinkIsUntouched() {
        let input = """
        ~~~
        [[Note]]
        ~~~
        [[Outside]]
        """
        let expected = """
        ~~~
        [[Note]]
        ~~~
        Outside
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }

    func testEscapedWikilinkIsUntouched() {
        XCTAssertEqual(ObsidianPreprocessor.process(#"\[[Note]]"#), #"\[[Note]]"#)
    }

    func testUnclosedWikilinkDoesNotSwallowTheNext() {
        let input = "[[oops\nSee [[Note]]"
        XCTAssertEqual(ObsidianPreprocessor.process(input), "[[oops\nSee Note")
    }

    func testCRLFFrontMatterIsRemoved() {
        let input = "---\r\ntitle: Hello\r\n---\r\nBody [[Note]]\r\n"
        XCTAssertEqual(ObsidianPreprocessor.process(input), "Body Note\r\n")
    }

    func testFrontMatterAndWikilinksTogether() {
        let input = """
        ---
        title: Hello
        ---
        See [[Note]], [[Other|Alias]], and [[Page#Heading]].
        """
        let expected = """
        See Note, Alias, and Page > Heading.
        """
        XCTAssertEqual(ObsidianPreprocessor.process(input), expected)
    }
}
