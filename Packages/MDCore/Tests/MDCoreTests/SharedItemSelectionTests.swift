import Testing
@testable import MDCore

struct SharedItemSelectionTests {
    @Test func `nameless utf8 plain text, the Text Document case, picks plain text`() throws {
        let candidates = [SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.utf8-plain-text"])]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.kind == .plainText)
        #expect(selection.typeIdentifier == "public.utf8-plain-text")
        #expect(selection.candidate.suggestedName == nil)
    }

    @Test func `markdown is preferred over plain text in one attachment`() throws {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.plain-text", "net.daringfireball.markdown"]),
        ]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.kind == .markdown)
        #expect(selection.typeIdentifier == "net.daringfireball.markdown")
    }

    @Test func `markdown is preferred over plain text across attachments`() throws {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.utf8-plain-text"]),
            SharedCandidate(
                index: 1,
                registeredTypeIdentifiers: ["net.daringfireball.markdown"],
                suggestedName: "a.md",
            ),
        ]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.candidate.index == 1)
        #expect(selection.kind == .markdown)
    }

    @Test func `file url only picks the file url`() throws {
        let candidates = [SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.file-url"])]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.kind == .fileURL)
        #expect(selection.typeIdentifier == "public.file-url")
        #expect(selection.candidate.isFileURL)
    }

    @Test func `text beats a file url`() throws {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.file-url"]),
            SharedCandidate(index: 1, registeredTypeIdentifiers: ["public.rtf"]),
        ]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.candidate.index == 1)
        #expect(selection.kind == .text)
    }

    @Test func `an isFileURL candidate with no usable type falls back to the file url`() throws {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["com.adobe.pdf"], isFileURL: true),
        ]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.kind == .fileURL)
        #expect(selection.typeIdentifier == "public.file-url")
    }

    @Test func `data only is nil unless data is allowed`() throws {
        let candidates = [SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.data"])]
        #expect(SharedItemSelection.pick(candidates) == nil)
        let selection = try #require(SharedItemSelection.pick(candidates, allowsData: true))
        #expect(selection.kind == .data)
    }

    @Test func `images and pdfs count only as data`() {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.jpeg"]),
            SharedCandidate(index: 1, registeredTypeIdentifiers: ["com.adobe.pdf"]),
        ]
        #expect(SharedItemSelection.pick(candidates) == nil)
        #expect(SharedItemSelection.pick(candidates, allowsData: true)?.candidate.index == 0)
    }

    @Test func `ties keep the first attachment and the first registered type`() throws {
        let candidates = [
            SharedCandidate(index: 0, registeredTypeIdentifiers: ["public.utf8-plain-text", "public.plain-text"]),
            SharedCandidate(index: 1, registeredTypeIdentifiers: ["public.plain-text"]),
        ]
        let selection = try #require(SharedItemSelection.pick(candidates))
        #expect(selection.candidate.index == 0)
        #expect(selection.typeIdentifier == "public.utf8-plain-text")
    }

    @Test func `no candidates and unknown types give nil`() {
        #expect(SharedItemSelection.pick([]) == nil)
        let unknown = [SharedCandidate(index: 0, registeredTypeIdentifiers: ["com.example.thing"])]
        #expect(SharedItemSelection.pick(unknown, allowsData: true) == nil)
    }

    @Test func `the caller's conformance closure is used`() throws {
        let candidates = [SharedCandidate(index: 0, registeredTypeIdentifiers: ["com.example.notes"])]
        let selection = try #require(SharedItemSelection.pick(candidates) { type, parent in
            type == "com.example.notes" && parent == "net.daringfireball.markdown"
        })
        #expect(selection.kind == .markdown)
    }

    @Test func `known conformance is transitive`() {
        #expect(SharedItemSelection.knownConformance("public.utf8-plain-text", "public.text"))
        #expect(SharedItemSelection.knownConformance("net.daringfireball.markdown", "public.text"))
        #expect(SharedItemSelection.knownConformance("public.utf8-tab-separated-values-text", "public.text"))
        #expect(SharedItemSelection.knownConformance("public.file-url", "public.data"))
        #expect(!SharedItemSelection.knownConformance("public.file-url", "public.text"))
        #expect(!SharedItemSelection.knownConformance("public.rtf", "public.plain-text"))
    }

    @Test func `kinds of common types`() {
        #expect(SharedItemSelection.kind(of: "net.daringfireball.markdown") == .markdown)
        #expect(SharedItemSelection.kind(of: "public.utf16-plain-text") == .plainText)
        #expect(SharedItemSelection.kind(of: "public.html") == .text)
        #expect(SharedItemSelection.kind(of: "public.file-url") == .fileURL)
        #expect(SharedItemSelection.kind(of: "public.url") == nil)
        #expect(SharedItemSelection.kind(of: "public.url", allowsData: true) == .data)
    }

    @Test func `kinds rank markdown first and data last`() {
        #expect(SharedItemKind.allCases.sorted() == [.markdown, .plainText, .text, .fileURL, .data])
    }
}
