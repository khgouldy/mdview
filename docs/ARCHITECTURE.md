# Architecture

MdV is a read-only SwiftUI document app; the repo, target and module are named `mdview`. iOS 18, Swift 6, strict concurrency. The Xcode project is generated from `project.yml`. Version 0.2.0 (build 3). Product code is the app target, the `mdviewShare` Share extension, and `Packages/MDCore`.

## Opening a file

`mdviewApp` is a `DocumentGroup(viewing: TextDocument.self)`. There is no custom browser, recents store, or settings screen. Files, Recents, the share sheet, Open In, and iPad drag and drop come from the system document browser (`UISupportsDocumentBrowser`, `LSSupportsOpeningDocumentsInPlace`).

`TextDocument` is a read-only `FileDocument`. It imports the Markdown UTI `net.daringfireball.markdown` (the extensions in `MarkdownFileTypes.markdownExtensions`) and accepts `public.plain-text` and `public.text` as alternate types. `MDCore.TextDecoding` reads the bytes as UTF-8, then UTF-16 when a BOM is present, then Windows-1252. Writing throws `fileWriteNoPermission`.

The scene shows `ReaderView` with the document's text. The navigation title is the file name.

## Launch screen and Paste

`DocumentGroupLaunchScene(AppName.display)` adds two actions: `PasteMarkdownButton` (the system `PasteButton`, so no paste alert; Save to Files writes UTF-8 and `TextDocument` stays read-only) and `OpenFilesHelpButton` (the How to Open Files guide, also `reader.help` in the reader menu). Task lists (`- [ ]`, `- [x]`) become a read-only `TaskCheckbox` attachment through `LocalImageLoader`. The build number is `CURRENT_PROJECT_VERSION` in `project.yml`, shared by both targets.

## Reader

`ReaderView` keeps two `@AppStorage` values, both local to the app:

- `reader.mode`, `rendered` or `source`, default rendered
- `obsidian.enabled`, default true

Markdown files get a segmented picker (`reader.modePicker`) and a menu (`reader.menu`) with one toggle, Obsidian extras (`settings.obsidian`). Files whose extension is `txt` or `text`, and any other file that is not the Markdown UTI, skip the picker and the menu and show source only.

A non-empty Find query (`.searchable`, placement `.navigationBarDrawer`) forces the source view, highlights matches, and shows `n of N` or `No matches` in `reader.searchCount`. Submit advances and wraps. Clearing the query does not write `reader.mode`, so the previous Rendered or Source choice comes back.

Matches live in `@State`. A `.task(id:)` keyed on the query and the text waits 150 ms after the last keystroke, runs `TextSearch.ranges` in a detached task (signpost `find`), and stores the result; a newer keystroke cancels the wait. Clearing the query clears the matches at once. The count row appears once the first search for a query finishes; until the next search lands it shows the previous result.

Markdown over 2 MB (`PreparedDocument.largeBytes`, the same limit as `SharedContent.sourceOnlyAboveBytes`) opens in Source under a bar, "Large file. Showing Source." (`reader.largeFile`), with a Render Anyway button (`reader.renderAnyway`). The choice is `@State` for that document; the picker toggles it too, and neither writes `reader.mode`.

## Reader features (0.2)

- **Outline.** `HeadingOutline` (MDCore) finds headings with the same pipeline and sections the reader uses. `OutlineSheet` (`outline.sheet`, rows `outline.row.N`) lists them from the `reader.outline` toolbar button, shown only for rendered Markdown with two or more headings, and the reader scrolls to the heading's slug. ⇧⌘O opens it.
- **Copy code.** `CopyableCodeBlockStyle` gives each code block a slim header row above the code: the fence's language (if any) and an icon-only copy button (`code.copy`, label "Copy code", value "Copied" for 1.5 s after a tap). The header is outside Textual's `Overflow`, so it never covers code and stays put when a wide block scrolls. It writes only to the pasteboard.
- **Reading settings.** `ReadingSettings` holds `reader.textScale` (0.85 to 1.6), `reader.width` (560, 680 or 860 pt) and `reader.fontDesign`. They sit on top of Dynamic Type and apply to Rendered, Source and PDF export. ⌘+, ⌘− and ⌘0 step the scale.
- **Reading position.** `ReadingPositionStore` (MDCore) keeps one scroll fraction (0 to 1) for each of the 200 most recent files, in `reader.positions`. Files are keyed by a SHA-256 hash of the path. Positions under 0.02 are not stored, and pasted or shared text has no file, so nothing is kept for it.
- **PDF and print.** `ExportMenu` and `PDFExporter` (`App/mdview/Export`) draw the rendered document page by page with `PageSlicer`, on Letter or A4 by region, and hand it to the share sheet or `UIPrintInteractionController`. Documents over 1 MB show "Too long to export". Nothing leaves the device unless the user shares the PDF.
- **Math.** `reader.math`, off by default. `MathDelimiters` (MDCore) normalizes `\(…\)` and `\[…\]` for Textual's math extension, outside code. Math sections over 64 KB render without math.
- **Shortcuts.** `ReaderCommands` adds the View menu: ⌘1, ⌘2, ⇧⌘O, ⌘+, ⌘−, ⌘0, ⌘P and ⇧⌘E. They are disabled on the launch screen.

## Source layout

The app target compiles `App/mdview` (scene, `TextDocument`, `ReaderView`, debug screenshot launch) and `App/Shared` (`AppName`, `Reader/RenderedView`, `ReaderStyle`, `PreparedDocument`, `SourceView`, `LocalImageLoader`, `ReaderMode`, `ReaderContext`, `Perf/PerfSignposts`). The `mdviewShare` extension compiles `App/mdviewShare` and the same `App/Shared`; Textual and MDCore link statically into each target (K8). Because the extension builds with `APPLICATION_EXTENSION_API_ONLY`, `make lint` fails if any file in `App/Shared` contains `UIApplication.shared`. `ReaderContext` (`fileURL`, `displayName`) is an environment value that hosts without a `DocumentGroup` inject; `ReaderView` reads it before `documentConfiguration`.

## Share extension

`mdviewShare` (`us.par72.mdview.share`, `com.apple.share-services`, display name `$(APP_DISPLAY_NAME)`) shows shared Markdown and text in the share sheet itself. It never opens the app: a Share extension has no supported API for that, and an App Group hand-off would need a new entitlement (K7). It has its own `PrivacyInfo.xcprivacy` (UserDefaults `CA92.1`, for reading `obsidian.enabled` in its own defaults domain) and writes no defaults.

**Activation (K9).** `App/mdviewShare/Info.plist` (Release) offers MdV when exactly one attachment of exactly one item conforms to `public.text` or is a `public.file-url`:

```
SUBQUERY(extensionItems, $item, SUBQUERY($item.attachments, $a, ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.text" OR ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.file-url").@count == 1).@count == 1
```

`public.plain-text`, `public.utf8-plain-text` (a chat app's nameless "Text Document"), Markdown, RTF and HTML all conform to `public.text`. Photos, PDFs and web links don't. `Info-Debug.plist` is identical except the rule also accepts `public.data`, so a Debug build is offered for anything and its info panel shows what a host actually registered. Two matching attachments don't activate MdV, and in Debug a photo plus text counts as two. `make lint` enforces all of this (`check_share_extension`).

**Flow.**

1. `ShareViewController.viewDidLoad` flattens the attachments of every input item, builds a `SharedCandidate` per attachment (registered types, `suggestedName`) and calls `SharedItemSelection.pick` with `UTType` conformance. It installs `UIHostingController(rootView: SharedReaderView(state:))` at once, showing the title and a progress view.
2. A detached task runs `SharedItemLoader.load` off the main actor: `loadFileRepresentation(for:)` (bytes copied inside the callback, size checked before reading), then `loadDataRepresentation(for:)`, then `loadItem` as `String`, `Data` or a security-scoped file `URL`. A `public.file-url` selection goes straight to `loadItem`.
3. `SharedContent.make` refuses items over `limitBytes` (5 MB) and binary data (a NUL in the first 8 KB, unless a UTF-16 BOM leads), decodes with `TextDecoding`, and refuses whitespace-only text.
4. `SharedReaderState.finish` moves the view from loading to the reader or a message. For Markdown it can render, it first calls `DocumentPreparer.shared.prewarm`, so the parse starts before SwiftUI draws the reader; `RenderedView` then joins that task or finds it cached. The first frame is the plain-text placeholder.

**Reader.** `SharedReaderView` is a `NavigationStack` titled with `SharedContent.title` ("Shared Text" for a nameless item). Markdown gets a Rendered / Source picker (`share.modePicker`) over the same `RenderedView` and `SourceView` as the app. The choice is `@State`, not `reader.mode`. Markdown over `sourceOnlyAboveBytes` (2 MB) and every non-Markdown type open in Source only. Done (`share.done`) and swiping the sheet away call `completeRequest(returningItems: [])`. Errors show the message (`share.error`) with Done still there:

| Case | Message |
| --- | --- |
| No usable attachment, or binary bytes (a PDF file URL) | "MdV shows Markdown and text files." |
| Empty or whitespace-only | "Nothing to show." |
| Over 5 MB | "This is too large to show here. MdV shows shared text up to 5 MB." |
| Every load path failed | "The shared item could not be read." |

The product name comes from `AppName.display`.

**What was shared.** The info button (`share.info`, in Release too) opens a panel (`share.info.panel`) that lists each attachment's registered type identifiers and suggested name, plus the loaded type, name and byte count (`share.info.bytes`). Copy (`share.info.copy`) puts the same text on the pasteboard for a support email. The panel reads only the request's own metadata and stores nothing.

**Which type is loaded.** `SharedItemSelection.pick` ranks each attachment's registered types: `net.daringfireball.markdown` > `public.plain-text` conformers > other `public.text` > `public.file-url` > `public.data` (only with `allowsData`, which the Debug build sets). The best attachment wins, ties keep the host's order, and within an attachment ties keep the first-registered type. `SharedContent.isMarkdown(kind:suggestedName:)` then decides Rendered: the Markdown UTI always; plain text, file URLs and data when the name has a Markdown extension or none; RTF and HTML only with a Markdown extension.

**Accent color.** `AccentColor.colorset` has four variants: #2E6B4A (any), #5BBF8A (dark), #1F4A33 (light, high contrast) and #7AD3A3 (dark, high contrast). `make lint` prints each WCAG contrast ratio: at least 4.5 on white and light greys, at least 4.5 on dark greys up to #2C2C2E and at least 3.0 on #3A3A3C.

## Rendered Markdown

`RenderedView` (`reader.rendered`) puts Textual's `StructuredText` in a scroll view:

- `.textual.structuredTextStyle(.reader)`, `ReaderStyle` below
- `.textual.highlighterTheme(.default)`, Textual's Prism-based highlighter, which follows light and dark
- `.textual.textSelection(.enabled)`, or `.disabled` while VoiceOver runs (K3, `accessibilityVoiceOverEnabled`). Textual's selection overlay covers the document with a view that has no accessibility properties, so VoiceOver would find nothing under it. Selection comes back when VoiceOver stops.
- width capped at 680 points

The style and selection modifiers sit above the section stack, so every section gets them.

**VoiceOver (`ReaderStyle`).** Textual has no accessibility code. `ReaderStyle` (`App/Shared/Reader/ReaderStyle.swift`) is Textual's `GitHubStyle`, member for member, with three replaced:

- `AccessibleHeadingStyle` draws `GitHubHeadingStyle` and makes it one element (`.combine`) with `.isHeader` and `.accessibilityHeading(.h1…h6)`, so the rotor's Headings jump through the document. The H1/H2 divider has no label. Headings have no identifier, because the style gets an opaque label view and never the text. UI tests find a heading by its exact label.
- `AccessibleListItemStyle` is `DefaultListItemStyle` with `.combine`, so an item reads as one element. A nested list is part of its parent item's block, so it joins that element.
- `QuietBulletMarker` is GitHub's disc, circle and square by depth with `.accessibilityHidden(true)`. Without it, VoiceOver reads the SF Symbol name before every item. Ordered numbers (`DecimalListMarker`) stay in the label.

Links in Textual are a spatial tap gesture on the text layout, not accessibility links, so combining a heading or an item does not change what a tap opens. `ReaderAccessibilityTests` checks that the Overview heading is hittable, that no element's label contains "circle" (the toolbar's `reader.menu` is excluded), that ordered items keep their number, and that a heading made of a link still opens Safari.

Textual draws; nothing parses on the main actor. This repo does not contain a Markdown renderer or a syntax highlighter.

**Preparing.** `DocumentPreparer` (an actor, `App/Shared/Reader/PreparedDocument.swift`) turns a `PreparedDocument.Key` (text, `obsidian`, `math`) into a `PreparedDocument` in a detached task:

1. `RenderPipeline.prepare` (below). Signpost `prepare` covers this and step 2.
2. `SectionSplitter.sections`: at or under 64 KB the whole text is one section; above, it is cut before each ATX heading at column 0 outside fences, HTML comments and raw HTML blocks. `SectionSplitter.grouped` joins those into sections of at least 8 KB (`PreparedDocument.groupBytes`), so a 1 MB note is about 130 views rather than one per heading.
3. Per section, `AttributedString(markdown:including: \.textual, options: .init(), baseURL: nil)`, exactly what Textual's `AttributedStringMarkdownParser.markdown()` does (signpost `parse`). Link reference definitions are the one thing that crosses a cut, so each section's parse input gets the one-line definitions it uses appended (`SectionSplitter.parseInput`); a CHANGELOG's `[1.0.0]: …` links still resolve.

The actor shares one task between concurrent requests for a key and keeps the last three documents (up to 3 MB of source; the newest is always kept). `cached(_:)` is synchronous, so a cached document draws on the first frame: switching Source → Rendered doesn't flash. `PreparedDocument` holds `sections: [PreparedSection]` (`id`, `markup`, `attributed`), `byteCount` and `isLarge` (over 2 MB).

**Drawing.** Until the document is ready, `RenderedView` shows the first ~2 KB of the source, cut at a line, as plain secondary body text (`reader.placeholder`), with a spinner when the file is over 64 KB. Then one section is `StructuredText(markup, parser: PreparsedParser(section:))`, laid out as before. Several sections are a `LazyVStack(spacing: 24)` of those, each `.id("section-\(index)")`; every later section starts at a heading, and 24 pt is the gap GitHub style puts above one. `PreparsedParser` is a `MarkupParser` that returns the cached `AttributedString` for its section's markup (anything else falls back to Textual's parser). Text selection works within a section. The preparation restarts when the text or the Obsidian setting changes.

**Pipeline.** `RenderPipeline.prepare(_:obsidian:math:)` in MDCore is the only text transform rendering uses. It runs two preprocessors before the parse (`math` is reserved and ignored until the math bead):

1. When Obsidian extras are on, `ObsidianPreprocessor.process` drops a leading `---` / `...` front matter block and rewrites wikilinks to plain text. Fenced code, inline code, `![[embeds]]`, and callout blocks are left alone. Source view never runs this.
2. `RemoteImages.linkify` always rewrites `![alt](http://…)` and `![alt](https://…)` outside code into `[Image: alt](url)`.

Links use the system open action. An `http` or `https` link opens Safari.

## Images stay on device

`ImagePolicy.allows` is true only for `file:` URLs. `http`, `https`, `data`, and `ftp` are rejected.

`LocalImageLoader` is the loader installed with `.textual.imageAttachmentLoader`. It is not Textual's URL loader. A path with no scheme is resolved against the document directory (`documentConfiguration.fileURL`). The loader then checks `ImagePolicy` and reads bytes with `Data(contentsOf:)`. `ImageIO` supplies the pixel size for layout. A refused or unreadable file throws. Textual drops a thrown attachment (`try?`) and does not replace the image run, so a missing file is not given a placeholder view by mdview.

The app target's lint rule rejects `URLSession`, `NWConnection`, `WKWebView`, and `CFNetwork` under `App/` and `Packages/`.

## MDCore

Foundation only. No package dependencies. iOS 18 and macOS 15, so `swift test` runs on the Mac.

| Type | Role |
| --- | --- |
| `TextDecoding` | UTF-8, UTF-16 BOM, Windows-1252 |
| `RemoteImages` | Remote image syntax becomes a link |
| `ImagePolicy` | `file:` URLs only |
| `ObsidianPreprocessor` | Front matter and wikilinks |
| `TextSearch` | Case- and diacritic-insensitive ranges, including overlaps |
| `MarkdownFileTypes` | Markdown and plain-text extensions, `isMarkdown(pathExtension:)` |
| `RenderPipeline` | `prepare(_:obsidian:math:)`, the one entry point for rendered text |
| `SectionSplitter` | `sections(_:minimumBytes:)` cuts over 64 KB at top-level ATX headings outside code and HTML blocks (exact rejoin, CRLF-safe); `grouped(_:targetBytes:)`; `linkDefinitions(in:)` and `parseInput(for:definitions:)` carry reference definitions across cuts. The line scanner is `MarkdownBlockScanner.swift` |
| `HeadingOutline` | `OutlineHeading` list for the outline sheet, with slug, occurrence and section |
| `ReadingPositionStore` | Per-file scroll fraction, 200 files, over `KeyValueStorage` |
| `MathDelimiters` | Rewrites LaTeX `\(…\)` and `\[…\]` for the math extension, outside code, in linear time |
| `PageSlicer` | Cuts a tall rendered document into PDF pages |
| `SharedItemSelection` | Ranks a share request's attachments and types (`SharedCandidate` in, `SharedSelection` out); conformance is a closure, with a built-in table for common system types |
| `SharedContent` | Share limits (5 MB, Source above 2 MB), binary sniff, title, Markdown decision, `SharedContentError` messages |

`SourceView` is a read-only `UITextView` (`reader.source`): monospaced body scaled with `UIFontMetrics`, `adjustsFontForContentSizeCategory`, `isFindInteractionEnabled`. Find paints match ranges from `TextSearch` and scrolls the current one into view.
