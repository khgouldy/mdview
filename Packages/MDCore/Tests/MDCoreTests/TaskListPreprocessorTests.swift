import Foundation
import Testing
@testable import MDCore

struct TaskListPreprocessorTests {
    private let open = "![Not done](x-mdview-task:unchecked)"
    private let done = "![Done](x-mdview-task:checked)"

    @Test func `rewrites every bullet and ordered marker`() {
        for bullet in ["-", "*", "+", "1.", "12)"] {
            #expect(TaskListPreprocessor.process("\(bullet) [ ] a") == "\(bullet) \(open) a")
            #expect(TaskListPreprocessor.process("\(bullet) [x] a") == "\(bullet) \(done) a")
            #expect(TaskListPreprocessor.process("\(bullet) [X] a") == "\(bullet) \(done) a")
        }
    }

    @Test func `marker at end of line counts`() {
        #expect(TaskListPreprocessor.process("- [ ]") == "- \(open)")
        #expect(TaskListPreprocessor.process("- [x]\nnext") == "- \(done)\nnext")
    }

    @Test func `nested items are rewritten`() {
        let input = "- [ ] a\n  - [x] b\n    - [ ] c\n"
        #expect(TaskListPreprocessor.process(input) == "- \(open) a\n  - \(done) b\n    - \(open) c\n")
    }

    @Test func `deeply indented nested item in a list is not code`() {
        let input = "- a\n\n    - [x] b\n"
        #expect(TaskListPreprocessor.process(input) == "- a\n\n    - \(done) b\n")
    }

    @Test func `fenced code is untouched`() {
        let input = "```\n- [ ] a\n```\n~~~sh\n- [x] b\n~~~\n- [x] c\n"
        #expect(TaskListPreprocessor.process(input) == "```\n- [ ] a\n```\n~~~sh\n- [x] b\n~~~\n- \(done) c\n")
    }

    @Test func `unclosed fence runs to the end`() {
        let input = "```\n- [ ] a\n"
        #expect(TaskListPreprocessor.process(input) == input)
    }

    @Test func `indented code is untouched`() {
        let input = "para\n\n    - [ ] a\n\n- [ ] b\n"
        #expect(TaskListPreprocessor.process(input) == "para\n\n    - [ ] a\n\n- \(open) b\n")
    }

    @Test func `mid-line brackets are untouched`() {
        let input = "text - [ ] a\n- a [x] b\n[ ] alone\n"
        #expect(TaskListPreprocessor.process(input) == input)
    }

    @Test func `links and other brackets are untouched`() {
        for input in [
            "- [x](https://example.com)",
            "- [x]text",
            "- [ x] a",
            "- [] a",
            "- [y] a",
            "-[ ] a",
            "- [xx] a",
        ] {
            #expect(TaskListPreprocessor.process(input) == input)
        }
    }

    @Test func `crlf line endings are kept`() {
        let input = "- [ ] a\r\n- [x] b\r\n"
        #expect(TaskListPreprocessor.process(input) == "- \(open) a\r\n- \(done) b\r\n")
    }

    @Test func `text without brackets returns unchanged`() {
        #expect(TaskListPreprocessor.process("plain\n") == "plain\n")
        #expect(TaskListPreprocessor.process("") == "")
    }

    @Test func `marker parses its own url`() throws {
        for marker in [TaskMarker.checked, .unchecked] {
            let url = try #require(URL(string: "\(TaskMarker.scheme):\(marker.isChecked ? "checked" : "unchecked")"))
            #expect(TaskMarker(url: url) == marker)
        }
        #expect(try TaskMarker(url: #require(URL(string: "x-mdview-task:other"))) == nil)
        #expect(try TaskMarker(url: #require(URL(string: "https://example.com/checked"))) == nil)
    }
}
