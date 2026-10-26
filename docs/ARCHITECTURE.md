# Architecture

mdview is a read-only SwiftUI document app. iOS 18, Swift 6, strict concurrency. The Xcode project is generated from `project.yml`. Product code is the app target plus `Packages/MDCore`.

## Opening a file

`mdviewApp` is a `DocumentGroup(viewing: TextDocument.self)`. There is no custom browser, recents store, or settings screen. Files, Recents, the share sheet, Open In, and iPad drag and drop come from the system document browser (`UISupportsDocumentBrowser`, `LSSupportsOpeningDocumentsInPlace`).

`TextDocument` is a read-only `FileDocument`. It imports the Markdown UTI `net.daringfireball.markdown` (extensions `md`, `markdown`, `mdown`) and accepts `public.plain-text` as an alternate type. `MDCore.TextDecoding` reads the bytes as UTF-8, then UTF-16 when a BOM is present, then Windows-1252. Writing throws `fileWriteNoPermission`.

The scene shows `ReaderView` with the document's text. The navigation title is the file name.

## Reader

`ReaderView` keeps two `@AppStorage` values, both local to the app:

- `reader.mode`, `rendered` or `source`, default rendered
- `obsidian.enabled`, default true

Markdown files get a segmented picker (`reader.modePicker`) and a menu (`reader.menu`) with one toggle, Obsidian extras (`settings.obsidian`). Files whose extension is `txt` or `text`, and any other file that is not the Markdown UTI, skip the picker and the menu and show source only.

A non-empty Find query (`.searchable`, placement `.navigationBarDrawer`) forces the source view, highlights matches, and shows `n of N` or `No matches` in `reader.searchCount`. Submit advances and wraps. Clearing the query does not write `reader.mode`, so the previous Rendered or Source choice comes back.

## Rendered Markdown

`RenderedView` (`reader.rendered`) puts Textual's `StructuredText` in a scroll view:

- `.textual.structuredTextStyle(.gitHub)`
- `.textual.highlighterTheme(.default)`, Textual's Prism-based highlighter, which follows light and dark
- `.textual.textSelection(.enabled)`
- width capped at 680 points

Textual parses and draws. This repo does not contain a Markdown renderer or a syntax highlighter. Two preprocessors run before Textual sees the string:

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

`SourceView` is a read-only `UITextView` (`reader.source`): monospaced body scaled with `UIFontMetrics`, `adjustsFontForContentSizeCategory`, `isFindInteractionEnabled`. Find paints match ranges from `TextSearch` and scrolls the current one into view.
