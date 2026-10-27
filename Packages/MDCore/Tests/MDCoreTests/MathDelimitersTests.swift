import Testing
@testable import MDCore

struct MathDelimitersTests {
    @Test func `inline parentheses become dollars`() {
        #expect(MathDelimiters.convert("Euler: \\( e^{i\\pi} + 1 = 0 \\) holds") == "Euler: $e^{i\\pi} + 1 = 0$ holds")
    }

    @Test func `display brackets become double dollars`() {
        #expect(MathDelimiters.convert("\\[ x^2 \\]") == "$$x^2$$")
        #expect(MathDelimiters.convert("\\[\nx^2\n\\]\n") == "$$\nx^2\n$$\n")
    }

    @Test func `several on one line`() {
        #expect(MathDelimiters.convert("\\(a\\) and \\(b\\)") == "$a$ and $b$")
    }

    @Test func `fenced code is untouched`() {
        let text = "```\n\\(a\\)\n```\n~~~\n\\[b\\]\n~~~\n"
        #expect(MathDelimiters.convert(text) == text)
    }

    @Test func `fence does not leak past its close`() {
        #expect(MathDelimiters.convert("```\nx\n```\n\\(a\\)\n") == "```\nx\n```\n$a$\n")
    }

    @Test func `indented code is untouched`() {
        let text = "para\n\n    \\(a\\)\n"
        #expect(MathDelimiters.convert(text) == text)
    }

    @Test func `code spans are untouched`() {
        let text = "use `\\(a\\)` and ``\\[b\\]`` here"
        #expect(MathDelimiters.convert(text) == text)
        #expect(MathDelimiters.convert("`x` \\(a\\)") == "`x` $a$")
    }

    @Test func `escaped backslash is untouched`() {
        let text = "a \\\\(b\\\\) c"
        #expect(MathDelimiters.convert(text) == text)
    }

    @Test func `unclosed delimiter is untouched`() {
        let text = "open \\( never closed\n\nnext \\) paragraph"
        #expect(MathDelimiters.convert(text) == text)
    }

    @Test func `empty delimiters are untouched`() {
        #expect(MathDelimiters.convert("\\(\\)") == "\\(\\)")
    }

    @Test func `text without math is identity`() {
        let text = "Cost $5 and $10, [link](x) (paren)\n"
        #expect(MathDelimiters.convert(text) == text)
    }

    @Test func `pipeline converts only when math is on`() {
        let input = "see \\(a\\)\n"
        #expect(RenderPipeline.prepare(input, obsidian: false, math: false) == input)
        #expect(RenderPipeline.prepare(input, obsidian: false, math: true) == "see $a$\n")
    }
}
