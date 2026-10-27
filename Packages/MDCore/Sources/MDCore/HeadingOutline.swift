import Foundation

/// One heading of a document, as the outline sheet lists it and the reader scrolls to it.
public struct OutlineHeading: Equatable, Sendable {
    /// 1 to 6.
    public let level: Int
    /// The heading's plain text, inline formatting removed.
    public let title: String
    /// The id Textual gives the heading view (`HeadingOutline.slug(of:)`).
    public let slug: String
    /// How many headings earlier in the document have the same slug. Textual gives them all one id, so a jump to a
    /// duplicate lands on the first one (`occurrence == 0`).
    public let occurrence: Int
    /// Index of the rendered section holding the heading. 0 for a document that is not sectioned.
    public let section: Int

    public init(level: Int, title: String, slug: String, occurrence: Int, section: Int) {
        self.level = level
        self.title = title
        self.slug = slug
        self.occurrence = occurrence
        self.section = section
    }
}

/// The headings of a document, found the way the reader finds them: the same pipeline, the same sections and
/// Foundation's Markdown parser, so setext headings, inline formatting and fences behave as they do on screen.
public enum HeadingOutline {
    /// The reader groups sections to about this size (`PreparedDocument.groupBytes`).
    public static let defaultGroupBytes = 8 * 1024

    /// Headings of `markdown` after `RenderPipeline.prepare`, so a front matter block that Obsidian extras hide
    /// contributes none. `section` counts the same groups the reader draws as `section-<n>` views.
    public static func headings(
        in markdown: String,
        obsidian: Bool = true,
        groupBytes: Int = defaultGroupBytes,
    ) -> [OutlineHeading] {
        let output = RenderPipeline.prepare(markdown, obsidian: obsidian)
        let sections = SectionSplitter.grouped(SectionSplitter.sections(output), targetBytes: groupBytes)
        return headings(inSections: sections)
    }

    /// Headings of already-prepared sections, numbered by their position in `sections`.
    public static func headings(inSections sections: [String]) -> [OutlineHeading] {
        var seen: [String: Int] = [:]
        var result: [OutlineHeading] = []
        for (index, section) in sections.enumerated() {
            for (level, text) in parseHeadings(in: section) {
                let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else {
                    continue
                }
                let slug = slug(of: text)
                let occurrence = seen[slug, default: 0]
                seen[slug] = occurrence + 1
                result.append(OutlineHeading(
                    level: level,
                    title: title,
                    slug: slug,
                    occurrence: occurrence,
                    section: index,
                ))
            }
        }
        return result
    }

    /// Textual's `slugified()` (Textual, MIT license, Copyright (c) Guille Gonzalez): lowercase, whitespace to `-`,
    /// keep letters, digits and `-`, and collapse runs of `-`.
    public static func slug(of text: String) -> String {
        String(
            text
                .lowercased()
                .map { $0.isWhitespace ? "-" : $0 }
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                .split(separator: "-", omittingEmptySubsequences: true)
                .joined(separator: "-"),
        )
    }

    /// Each heading's level and text, in document order. Parsed with default options, as Textual does.
    private static func parseHeadings(in section: String) -> [(level: Int, text: String)] {
        guard let parsed = try? AttributedString(markdown: section, options: .init()) else {
            return []
        }
        var headings: [(level: Int, text: String)] = []
        var currentIdentity: Int?
        for run in parsed.runs {
            guard let header = run.presentationIntent?.components.first(where: { $0.kind.headerLevel != nil }),
                  let level = header.kind.headerLevel
            else {
                currentIdentity = nil
                continue
            }
            let text = String(parsed[run.range].characters)
            if currentIdentity == header.identity, !headings.isEmpty {
                headings[headings.count - 1].text += text
            } else {
                headings.append((level, text))
                currentIdentity = header.identity
            }
        }
        return headings
    }
}

private extension PresentationIntent.Kind {
    var headerLevel: Int? {
        if case let .header(level) = self {
            return level
        }
        return nil
    }
}
