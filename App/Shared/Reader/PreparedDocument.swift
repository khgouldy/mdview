import Foundation
import MDCore
import os
import Textual
import UIKit

/// One block of a prepared document: the Markdown `StructuredText` is given and the parse Textual draws for it.
struct PreparedSection: Identifiable, Sendable {
    let id: Int
    let markup: String
    let attributed: AttributedString
}

/// Markdown made ready to draw, entirely off the main actor: `RenderPipeline`, then `SectionSplitter`, then the
/// parse Textual would otherwise run in `StructuredText.body`. A document at or under 64 KB is one section.
struct PreparedDocument: Sendable {
    /// What a preparation depends on. Comparing keys is cheap while the text shares storage, which it does for one
    /// document: Swift compares a string's storage before its bytes.
    struct Key: Hashable, Sendable {
        var text: String
        var obsidian: Bool
        var math: Bool
    }

    /// Sections are grouped to about this size, so a 1 MB note is ~130 views instead of one per heading.
    static let groupBytes = 8 * 1024
    /// Over this, the app opens a Markdown file in Source and the extension offers only Source.
    static let largeBytes = SharedContent.sourceOnlyAboveBytes

    let key: Key
    let sections: [PreparedSection]
    /// UTF-8 bytes of the source text, before the pipeline.
    let byteCount: Int

    var isLarge: Bool {
        Self.isLarge(byteCount: byteCount)
    }

    static func isLarge(byteCount: Int) -> Bool {
        byteCount > largeBytes
    }

    /// The whole preparation. Runs in a detached task from `DocumentPreparer`; never on the main actor.
    static func make(_ key: Key) -> PreparedDocument {
        let (markups, definitions) = PerfSignposts.measure("prepare") {
            let output = RenderPipeline.prepare(key.text, obsidian: key.obsidian, math: key.math)
            let markups = SectionSplitter.grouped(SectionSplitter.sections(output), targetBytes: groupBytes)
            let definitions = markups.count > 1 ? SectionSplitter.linkDefinitions(in: output) : []
            return (markups, definitions)
        }
        let sections = PerfSignposts.measure("parse") {
            markups.enumerated().map { index, markup in
                let input = SectionSplitter.parseInput(for: markup, definitions: definitions)
                return PreparedSection(id: index, markup: markup, attributed: parse(input))
            }
        }
        return PreparedDocument(key: key, sections: sections, byteCount: key.text.utf8.count)
    }

    /// Exactly what Textual's `AttributedStringMarkdownParser.markdown()` does: Foundation's full-document Markdown
    /// with the `\.textual` scope and default options. With no syntax extensions its pattern pass returns the input.
    /// `MarkupParser` is `@MainActor`, so the parser type itself can't be called from here.
    nonisolated static func parse(_ markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown, including: \.textual, options: .init(), baseURL: nil)
        } catch {
            return AttributedString(markdown)
        }
    }
}

/// Prepares documents in a detached task and keeps the last few, so switching Source → Rendered or reopening a
/// note draws at once. Concurrent requests for the same key share one task.
actor DocumentPreparer {
    static let shared = DocumentPreparer()

    private static let cacheCount = 3
    /// Source bytes across cached documents.
    private static let cacheBytes = 3_000_000

    private nonisolated let cache = OSAllocatedUnfairLock(initialState: [PreparedDocument]())
    private var running: [(key: PreparedDocument.Key, task: Task<PreparedDocument, Never>)] = []

    /// A parse holds several times its source in memory, so a memory warning empties the cache.
    init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil,
        ) { [cache] _ in
            cache.withLock { $0.removeAll() }
        }
    }

    func prepare(text: String, obsidian: Bool, math: Bool = false) async -> PreparedDocument {
        await prepare(PreparedDocument.Key(text: text, obsidian: obsidian, math: math))
    }

    func prepare(_ key: PreparedDocument.Key) async -> PreparedDocument {
        if let hit = cached(key) {
            return hit
        }
        if let task = running.first(where: { $0.key == key })?.task {
            return await task.value
        }
        // Detached: the caller's cancellation must not stop work another caller (or the cache) is waiting for.
        let task = Task.detached(priority: .userInitiated) { PreparedDocument.make(key) }
        running.append((key, task))
        let document = await task.value
        running.removeAll { $0.key == key }
        store(document)
        return document
    }

    /// Starts preparing without waiting, so the parse overlaps whatever runs before the view asks for it.
    nonisolated func prewarm(text: String, obsidian: Bool, math: Bool = false) {
        let key = PreparedDocument.Key(text: text, obsidian: obsidian, math: math)
        Task.detached(priority: .userInitiated) {
            _ = await self.prepare(key)
        }
    }

    /// The cached document for `key`, if any. Synchronous, so a view can draw it on its first frame.
    nonisolated func cached(_ key: PreparedDocument.Key) -> PreparedDocument? {
        cache.withLock { documents in
            documents.first { $0.key == key }
        }
    }

    private nonisolated func store(_ document: PreparedDocument) {
        cache.withLock { documents in
            documents.removeAll { $0.key == document.key }
            documents.insert(document, at: 0)
            var bytes = 0
            var kept = 0
            for cached in documents {
                bytes += cached.byteCount
                // The newest document is always kept, however large.
                guard kept == 0 || (kept < Self.cacheCount && bytes <= Self.cacheBytes) else {
                    break
                }
                kept += 1
            }
            documents.removeLast(documents.count - kept)
        }
    }
}

/// Hands `StructuredText` the parse `DocumentPreparer` already made, so `StructuredText(_:parser:)` does no work on
/// the main actor. Any other input (never expected) falls back to Textual's own parser.
struct PreparsedParser: MarkupParser {
    let section: PreparedSection
    /// Math needs Textual's own parser (its pattern pass is `@MainActor`), so a math document is parsed here and the
    /// off-main parse is skipped. Off by default, so the common path stays free.
    var math = false

    func attributedString(for input: String) throws -> AttributedString {
        if math {
            return try AttributedStringMarkdownParser.markdown(syntaxExtensions: [.math]).attributedString(for: input)
        }
        if input == section.markup {
            return section.attributed
        }
        return try AttributedStringMarkdownParser.markdown().attributedString(for: input)
    }
}
