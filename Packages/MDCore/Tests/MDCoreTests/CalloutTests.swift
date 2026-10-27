import Foundation
import Testing
@testable import MDCore

struct CalloutTests {
    private func title(_ kind: CalloutKind, _ title: String) -> String {
        "![\(kind.title)](x-mdview-callout:\(kind.rawValue)) **\(title)**"
    }

    @Test func `github alerts get a title paragraph and keep their body`() {
        let output = CalloutPreprocessor.process("> [!NOTE]\n> Body text.\n", obsidian: false)
        #expect(output == "> \(title(.note, "Note"))\n>\n> Body text.\n")
    }

    @Test(arguments: [
        ("NOTE", CalloutKind.note), ("tip", .tip), ("Important", .important), ("WARNING", .warning),
        ("caution", .caution),
    ])
    func `the five GitHub kinds are case-insensitive`(type: String, kind: CalloutKind) {
        #expect(CalloutKind.kind(forType: type, obsidian: false) == kind)
        let output = CalloutPreprocessor.process("> [!\(type)]\n> x", obsidian: false)
        #expect(output.hasPrefix("> \(title(kind, kind.title))"))
    }

    @Test(arguments: [
        ("info", CalloutKind.note), ("todo", .note), ("abstract", .note), ("summary", .note), ("tldr", .note),
        ("example", .note), ("quote", .note), ("cite", .note),
        ("success", .tip), ("check", .tip), ("done", .tip), ("hint", .tip),
        ("question", .important), ("help", .important), ("faq", .important),
        ("attention", .warning),
        ("danger", .caution), ("error", .caution), ("bug", .caution), ("failure", .caution), ("fail", .caution),
        ("missing", .caution),
    ])
    func `obsidian types map onto the five kinds`(type: String, kind: CalloutKind) {
        #expect(CalloutKind.kind(forType: type, obsidian: true) == kind)
        #expect(CalloutKind.kind(forType: type.uppercased(), obsidian: true) == kind)
        #expect(CalloutKind.kind(forType: type, obsidian: false) == nil)
    }

    @Test func `unknown types stay a plain quote`() {
        let markdown = "> [!banana]\n> Body\n"
        #expect(CalloutPreprocessor.process(markdown, obsidian: true) == markdown)
        #expect(CalloutKind.kind(forType: "banana", obsidian: true) == nil)
    }

    @Test func `an Obsidian type without a title reads as itself`() {
        let output = CalloutPreprocessor.process("> [!info]\n> Body", obsidian: true)
        #expect(output == "> \(title(.note, "Info"))\n>\n> Body")
    }

    @Test func `a custom title is kept`() {
        let output = CalloutPreprocessor.process("> [!tip] My title\n> Body", obsidian: true)
        #expect(output == "> \(title(.tip, "My title"))\n>\n> Body")
    }

    @Test(arguments: ["-", "+"])
    func `fold markers are dropped`(fold: String) {
        let output = CalloutPreprocessor.process("> [!faq]\(fold) Why?\n> Because.", obsidian: true)
        #expect(output == "> \(title(.important, "Why?"))\n>\n> Because.")
    }

    @Test func `a title-only callout adds no empty line`() {
        #expect(CalloutPreprocessor.process("> [!WARNING] Careful\n\nAfter", obsidian: false)
            == "> \(title(.warning, "Careful"))\n\nAfter")
    }

    @Test func `a body that already starts with an empty quote line gets no second one`() {
        let output = CalloutPreprocessor.process("> [!NOTE]\n>\n> Body", obsidian: false)
        #expect(output == "> \(title(.note, "Note"))\n>\n> Body")
    }

    @Test func `the marker must start the quote`() {
        let markdown = "> Intro\n> [!NOTE]\n> Body"
        #expect(CalloutPreprocessor.process(markdown, obsidian: false) == markdown)
    }

    @Test func `fenced code is untouched`() {
        let markdown = "```\n> [!NOTE]\n> Body\n```\n"
        #expect(CalloutPreprocessor.process(markdown, obsidian: false) == markdown)
    }

    @Test func `text right after the bracket is not a callout`() {
        let markdown = "> [!NOTE]x\n> Body"
        #expect(CalloutPreprocessor.process(markdown, obsidian: false) == markdown)
    }

    @Test func `indent and CRLF line endings are kept`() {
        let output = CalloutPreprocessor.process("  > [!TIP]\r\n  > Body\r\n", obsidian: false)
        #expect(output == "  > \(title(.tip, "Tip"))\r\n  >\r\n  > Body\r\n")
    }

    @Test func `marker URLs round-trip`() throws {
        for kind in CalloutKind.allCases {
            let url = try #require(URL(string: "x-mdview-callout:\(kind.rawValue)"))
            #expect(CalloutMarker.kind(of: url) == kind)
        }
        let task = try #require(URL(string: "x-mdview-task:checked"))
        #expect(CalloutMarker.kind(of: task) == nil)
    }

    @Test func `the pipeline turns callouts into title paragraphs`() {
        let output = RenderPipeline.prepare("> [!bug] Crash\n> Steps", obsidian: true)
        #expect(output.contains(title(.caution, "Crash")))
        let plain = RenderPipeline.prepare("> [!bug] Crash\n> Steps", obsidian: false)
        #expect(plain.contains("[!bug] Crash"))
    }
}
