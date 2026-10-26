# mdview: a one-button, fully local iOS Markdown viewer

Feature slug: `mdview`. Base branch: `main`. Companion file: `beads.json` (same directory).

> **Revised Oct 25, 2026 (decision D11, keving): build as little as possible.** Off-the-shelf components, limited
> functionality. This replaces the earlier 15-bead plan with its custom model, parser, renderer, highlighter, file
> browser and recents store. Development runs overnight with Grok only (D13).

## 1. Goal and non-goals

**Goal.** A tiny native SwiftUI app (iOS 18+) that opens `.md` / `.markdown` and `.txt` files from the Files app,
the share sheet / "Open in", or drag-and-drop on iPad, renders them nicely in light and dark mode with Dynamic Type,
and has one main control: a **Rendered / Source** toggle. Recents, find, and a single Obsidian setting round it out.
Everything is local: no network, no telemetry, no SDKs that phone home.

**Scope (all of it).** Open .md/.txt; Rendered/Source toggle; recents; dark mode; Dynamic Type; find via
`.searchable`; Obsidian setting (default on) that hides YAML front matter and shows `[[wikilinks]]` as plain text.

**Non-goals.** Editing, sync, accounts, cloud, analytics, any network access by the app (remote images become links
to Safari, D2), Android, macOS/Catalyst, App Store release (TestFlight is the ceiling), themes, font pickers, a
settings screen, a custom file browser or recents list, Obsidian embeds and callouts, relative `.md` links, folder
access prompts for sibling images, footnotes, math, snapshot tests (see Deferred).

## 2. Current state

The repo `khgouldy/mdview` is **public under MIT** (D1, `LICENSE` at the root on this branch). It contains only the
bootstrap: `README.md`, beads tracker config (`.beads/`, `AGENTS.md`, `CLAUDE.md`, agent config dirs) and a
`.gitignore`. No Xcode project, package, Makefile, CI or tests yet. Toolchain on keving's Mac: macOS 26.5,
Xcode 26.0.1 (B1 records exact versions). Bots never boot the iOS Simulator on keving's Mac: locally they run only
`swift test` for the small MDCore package and a device-SDK `xcodebuild build` with signing disabled. Simulator tests
run only in GitHub Actions (D7), which is free for a public repo.

## 3. Design: use what exists

### 3.1 Off-the-shelf components

| Need | Component | License | Notes |
|---|---|---|---|
| Markdown rendering (GFM-ish: headings, lists, quotes, code, tables, links, images) | [Textual](https://github.com/gonzalezreal/textual) 0.5.x, `StructuredText(markdown:)` with `.gitHub` style | MIT | Active successor of MarkdownUI by the same author; parses with Foundation's `AttributedString` Markdown parser; Swift 6 tools version; requires iOS 18. Pinned `upToNextMinor(from: "0.5.0")` because it is pre-1.0. |
| Code syntax highlighting | Textual's built-in highlighter (Prism.js via JavaScriptCore, bundled) | MIT (Prism.js) | Plugs straight into the renderer, so no Splash or HighlightSwift. |
| Transitive dependencies | swiftui-math (gonzalezreal), swift-concurrency-extras (Point-Free) | MIT, MIT | swift-snapshot-testing is only a Textual test-target dependency (MIT) and is not shipped. |
| Open files, Files/share/Open-in/drag-drop, **recents** | SwiftUI `DocumentGroup(viewing:)` and the system document browser | Apple SDK | The browser has Recents and Browse built in; no custom browser, bookmarks or recents store. |
| Find | SwiftUI `.searchable` plus `UITextView` find interaction in Source | Apple SDK | |
| Settings | `@AppStorage` and one `Toggle` in a toolbar `Menu` | Apple SDK | |
| Dark mode, Dynamic Type | System, Textual font-relative metrics, `UIFontMetrics` | Apple SDK | |

Every shipped component is MIT, which works with this public MIT repo; B7 records them in `THIRD_PARTY_NOTICES.md`.
Fallback if Textual blocks a bead: MarkdownUI 2.4.1 (MIT, maintenance mode, iOS 15+) with Splash 0.16 (MIT) as its
code highlighter (D12).

### 3.2 What we write ourselves (small)

- `App/mdview/`: `mdviewApp` (a `DocumentGroup(viewing: TextDocument.self)` scene), `TextDocument` (read-only
  `FileDocument` for an imported Markdown UTI and `public.plain-text`), `ReaderView` (toolbar picker, menu,
  `.searchable`), `RenderedView` (Textual), `SourceView` (read-only `UITextView`), `LocalImageLoader` (Textual
  `AttachmentLoader` that only reads local files).
- `Packages/MDCore/`: Foundation-only pure functions tested with `swift test` on the Mac: `TextDecoding`,
  `RemoteImages.linkify`, `ImagePolicy`, `ObsidianPreprocessor` (front matter + wikilinks), `TextSearch`.

### 3.3 Repository layout

```
Makefile                      # entry point for agents and CI: tools, gen, lint, format, test, build-ios, test-ios (CI only), open, clean
project.yml                   # XcodeGen spec; mdview.xcodeproj is generated and gitignored
Config/Local.xcconfig.example # PRODUCT_BUNDLE_IDENTIFIER = us.par72.mdview, empty DEVELOPMENT_TEAM; Local.xcconfig gitignored
Packages/MDCore/              # Foundation-only logic + tests (macOS 15 / iOS 18)
App/mdview/                   # app target (SwiftUI + Textual)
App/mdviewUITests/            # XCUITest launch test (CI only)
.github/workflows/ci.yml
README.md  THIRD_PARTY_NOTICES.md  docs/DEVELOPMENT.md  docs/ARCHITECTURE.md  docs/RELEASE.md
```

### 3.4 Data flow

DocumentGroup opens a file (Files, Recents, share/Open in, drag-drop) and hands `TextDocument` to `ReaderView`.
`TextDocument` decodes bytes with `MDCore.TextDecoding`. For Markdown, Rendered mode runs
`ObsidianPreprocessor` (if `obsidian.enabled`) and then `RemoteImages.linkify`, and passes the result to Textual's
`StructuredText`. Source mode shows the original text. A non-empty search query shows Source with highlighted
matches. `.txt` files always show Source.

### 3.5 Network-free guarantee

- `make lint` has a custom `no_networking` rule over `App/` and `Packages/` (URLSession, NWConnection, WKWebView, CFNetwork).
- Textual can fetch images from URLs, so the app installs `LocalImageLoader` via `.textual.imageAttachmentLoader`
  and never uses Textual's `.image()` URL loader. `ImagePolicy` allows only `file:` URLs.
- Remote images are rewritten into links (`[Image: alt](url)`) that open in Safari on tap (D2).
- Links open through the system (`openURL`), i.e. in Safari, outside the app process.

## 4. Risks and containment

| Risk | Containment |
|---|---|
| Textual is pre-1.0 and its API can change | Pin `upToNextMinor(from: "0.5.0")`; Package.resolved committed; fallback MarkdownUI + Splash (D12). |
| Foundation's Markdown parser lacks some GFM extras (task-list checkboxes, footnotes) | Accepted as limited functionality (D11); they show as plain text. |
| Textual image loading could reach the network | Local-only loader + `ImagePolicy` tests + lint rule (3.5). |
| Sibling images are unreadable under the sandbox because only the document is granted | Accepted; images just do not show. Folder access deferred. |
| DocumentGroup is hard to drive in XCUITest | UI tests limited to a launch test; logic tested in MDCore with `swift test`. |
| Simulator on keving's Mac | `make test-ios` refuses unless `CI=true` or `MDVIEW_ALLOW_SIMULATOR=1`; bots never set the latter. |
| Grok-only overnight run stalls on a bead | Runner stops on failure and waits; dispatch caps unchanged (4 jobs / 2 heavy / memory gate). |

## 5. Beads

Eight small beads, all `model: grok`. Chain integration: one branch `feat/mdview` from `plan/mdview`; beads land in
order B1, then B2 and B3 (both need only B1), B4, B5, B6, B7, and B8 (human). Every bead runs the quality gate
(section 6) and must leave CI green from B2 on.

### B1 Scaffold project with Textual, DocumentGroup viewer, MDCore package, Makefile and lint

Size M, priority P1, model `grok`, depends on nothing.

Owns: `project.yml`, `Makefile`, `Config/`, `Packages/MDCore/`, `App/mdview/mdviewApp.swift`, `App/mdview/TextDocument.swift`, `App/mdview/Info.plist`, `App/mdview/Assets.xcassets/`, `App/mdviewUITests/LaunchTests.swift`, `.swiftformat`, `.swiftlint.yml`, `.gitignore`, `docs/DEVELOPMENT.md`, `AGENTS.md`, `CLAUDE.md`.

Create the skeleton every later bead builds on, using off-the-shelf parts (D11): an XcodeGen project.yml (iOS 18.0 minimum because Textual requires it, Swift 6 language mode with strict concurrency, generated .xcodeproj gitignored) with one SPM dependency for the app target: Textual (https://github.com/gonzalezreal/textual, MIT) pinned upToNextMinor from 0.5.0. A tiny local Swift package Packages/MDCore (Foundation only, platforms iOS 18 + macOS 15, no dependencies) holds the pure logic later beads add and is tested with swift test on the Mac; B1 adds MDCore.TextDecoding (UTF-8, then UTF-16 with BOM, then Windows-1252 fallback) with tests. The app is a read-only SwiftUI DocumentGroup(viewing: TextDocument.self): TextDocument is a FileDocument whose readableContentTypes are an imported Markdown UTI (net.daringfireball.markdown; extensions md, markdown, mdown) and public.plain-text, decoded with TextDecoding; the viewer shows the raw text for now. The system document browser supplies Files access, Recents, share-sheet/Open-in and drag-and-drop, so there is no custom browser or recents store. Info.plist: CFBundleDocumentTypes (Markdown as Owner/Default, plain text as Alternate, D5), UTImportedTypeDeclarations, LSSupportsOpeningDocumentsInPlace YES, UISupportsDocumentBrowser YES. Add one XCUITest launch test (CI only), a Makefile (tools, gen, lint, format, test, build-ios, test-ios guarded to CI, open, clean), swiftformat/swiftlint config including a custom no_networking rule over App/ and Packages/ (URLSession, NWConnection, WKWebView, CFNetwork), and docs/DEVELOPMENT.md plus the build/test sections of CLAUDE.md and AGENTS.md. Record the toolchain versions. Never boot a simulator locally. Config/Local.xcconfig.example sets PRODUCT_BUNDLE_IDENTIFIER = us.par72.mdview and leaves DEVELOPMENT_TEAM empty (keving fills it at B8); never look up or commit Apple account details.

**Acceptance**

- `make lint` exits 0 and exits non-zero when a file containing `URLSession` is added under App/ or Packages/
- `make test` exits 0: `swift test --package-path Packages/MDCore` passes (TextDecoding tests for UTF-8, UTF-16 BOM and Windows-1252 input) and `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` succeeds with Textual resolved and no DEVELOPMENT_TEAM set
- `make test-ios` exits non-zero with an explanatory message unless CI=true or MDVIEW_ALLOW_SIMULATOR=1
- The app's only package dependency is Textual pinned `.upToNextMinor(from: "0.5.0")`; MDCore has no dependencies; the deployment target is iOS 18.0 and SWIFT_VERSION is 6
- Info.plist declares the Markdown UTI (imported) and public.plain-text document types, LSSupportsOpeningDocumentsInPlace and UISupportsDocumentBrowser; the app entry is a DocumentGroup(viewing:) scene
- `git status` after `make gen` shows no untracked .xcodeproj or Config/Local.xcconfig; Config/Local.xcconfig.example contains `PRODUCT_BUNDLE_IDENTIFIER = us.par72.mdview` and an empty `DEVELOPMENT_TEAM =` line
- docs/DEVELOPMENT.md lists the Xcode, Swift, xcodegen, swiftformat and swiftlint versions and the Makefile targets; CLAUDE.md and AGENTS.md no longer contain the placeholder build/test section

### B2 Add GitHub Actions CI with device build and simulator launch test

Size S, priority P1, model `grok`, depends on B1.

Owns: `.github/workflows/`, `README.md`, `docs/DEVELOPMENT.md`.

Create .github/workflows/ci.yml: push trigger on all branches with docs path-ignore (no pull_request trigger), workflow_dispatch with no inputs, concurrency cancel-in-progress keyed on github.ref, 30-minute timeout, one job on a pinned macOS runner image with an Xcode that has the iOS 18+ SDK selected via xcode-select, SwiftPM/DerivedData caching, steps: xcrun simctl list devices available (diagnostic), make lint, make test, make test-ios (CI=true) against a simulator that exists on that image, xcresult upload on failure. make test-ios runs tests non-parallel. Add a CI badge to README.md and a CI section to docs/DEVELOPMENT.md (free because the repo is public, D1; gh run download for the xcresult). This is the only place simulators run.

**Acceptance**

- .github/workflows/ci.yml exists with triggers push (paths-ignore docs/** and **/*.md) and workflow_dispatch, a concurrency group on github.ref with cancel-in-progress, and timeout-minutes <= 30
- After pushing the branch, `gh run list --branch <branch> --limit 1` shows a completed run with conclusion success that ran make lint, make test and make test-ios (LaunchTests pass on the simulator)
- docs/DEVELOPMENT.md has a CI section (cost, `gh run download` for the xcresult) and README.md shows the CI badge

### B3 Render Markdown with Textual: GitHub style, built-in code highlighting, local-only images

Size M, priority P1, model `grok`, depends on B1.

Owns: `App/mdview/Reader/RenderedView.swift`, `App/mdview/Reader/LocalImageLoader.swift`, `App/mdview/mdviewApp.swift`, `Packages/MDCore/Sources/MDCore/RemoteImages.swift`, `Packages/MDCore/Sources/MDCore/ImagePolicy.swift`, `Packages/MDCore/Tests/MDCoreTests/RemoteImagesTests.swift`, `Packages/MDCore/Tests/MDCoreTests/ImagePolicyTests.swift`.

Replace the raw-text viewer with RenderedView: a ScrollView containing Textual's StructuredText(markdown:) with .textual.structuredTextStyle(.gitHub), .textual.textSelection(.enabled) and Textual's built-in Prism-based code highlighting (default highlighter theme, follows light/dark). Do not write a parser, renderer or highlighter. Text scales with Dynamic Type through Textual's font-relative metrics; cap the readable width on iPad. Keep the app network-free (D2): MDCore.RemoteImages.linkify(_:) rewrites `![alt](http(s)://...)` outside code into a link `[Image: alt](url)` so remote images show as a tappable link that opens Safari through the default openURL; MDCore.ImagePolicy.allows(_ url: URL) returns true only for file: URLs; LocalImageLoader is a Textual AttachmentLoader installed with .textual.imageAttachmentLoader(...) that resolves URLs relative to the document's directory (from @Environment(\.documentConfiguration)?.fileURL), refuses anything ImagePolicy rejects, and reads file data only (no URLSession, no Textual URL loader). If a local image is unreadable it is simply not shown (folder access is deferred). Links open via the system (Safari for http/https).

**Acceptance**

- `make test` passes, including RemoteImagesTests (remote image becomes a link, local image and images inside fenced/inline code untouched) and ImagePolicyTests (http, https, data and ftp rejected; file accepted)
- RenderedView uses Textual StructuredText with the GitHub style and text selection; the repo contains no custom Markdown parser, renderer or syntax highlighter
- The image loader passed to `.textual.imageAttachmentLoader` is LocalImageLoader, never Textual's `.image()` URL loader; `make lint` passes (no networking APIs in App/ or Packages/)
- CI on the branch is green

### B4 Reader screen with Rendered / Source toggle and native source view

Size S, priority P1, model `grok`, depends on B3.

Owns: `App/mdview/Reader/ReaderView.swift`, `App/mdview/Reader/SourceView.swift`, `App/mdview/mdviewApp.swift`, `App/mdviewUITests/`.

Add ReaderView as the DocumentGroup viewer: a segmented Picker in the toolbar (accessibility id reader.modePicker) switching Rendered (RenderedView, accessibility id reader.rendered) and Source (SourceView, id reader.source), persisted with @AppStorage("reader.mode") defaulting to Rendered. SourceView is a read-only, selectable UITextView wrapper (UIViewRepresentable) with a monospaced font that scales with Dynamic Type (UIFontMetrics), adjustsFontForContentSizeCategory, and isFindInteractionEnabled = true so the system find bar works there. Plain-text files (.txt, D5) always show SourceView and hide the picker. Navigation title is the file name.

**Acceptance**

- `make test` passes
- ReaderView shows the picker for Markdown files and switches between RenderedView and SourceView; the choice persists via @AppStorage("reader.mode")
- For a public.plain-text document no picker is shown and SourceView is used
- SourceView is not editable, uses a Dynamic Type-scaled monospaced font, and has isFindInteractionEnabled set
- CI on the branch is green

### B5 Obsidian setting: hide front matter and turn wikilinks into plain text

Size S, priority P1, model `grok`, depends on B4.

Owns: `Packages/MDCore/Sources/MDCore/ObsidianPreprocessor.swift`, `Packages/MDCore/Tests/MDCoreTests/ObsidianPreprocessorTests.swift`, `App/mdview/Reader/ReaderView.swift`, `App/mdview/Reader/RenderedView.swift`.

Only the cheap Obsidian parts (D6, D11). MDCore.ObsidianPreprocessor.process(_:) (a) removes a leading YAML front matter block (--- at line 1 through the next --- or ... line; leave the text alone if unterminated) and (b) turns [[Note]] into `Note`, [[Note|Alias]] into `Alias` and [[Note#Heading]] into `Note > Heading` as plain text, skipping fenced code blocks and inline code spans and leaving ![[embeds]] and > [!callout] blocks untouched (embeds and callouts are deferred). RenderedView feeds Markdown through it when @AppStorage("obsidian.enabled") is true (default true). The Source view always shows the original text. The setting lives in a small toolbar Menu (ellipsis.circle, accessibility id reader.menu) in ReaderView containing one Toggle "Obsidian extras" (id settings.obsidian); DocumentGroup owns the home screen, so there is no settings screen.

**Acceptance**

- `make test` passes, including ObsidianPreprocessorTests covering front matter (present, absent, unterminated, `...` terminator), [[Note]], [[Note|Alias]], [[Note#Heading]], wikilinks inside fenced and inline code left alone, and ![[embed]] left unchanged
- With obsidian.enabled true (default) the rendered view hides front matter and shows wikilinks as plain text; with it false the Markdown is rendered unmodified
- The reader toolbar Menu (reader.menu) has exactly one Toggle (settings.obsidian) bound to @AppStorage("obsidian.enabled"); hidden for .txt files
- CI on the branch is green

### B6 Find in page with .searchable

Size S, priority P1, model `grok`, depends on B5.

Owns: `Packages/MDCore/Sources/MDCore/TextSearch.swift`, `Packages/MDCore/Tests/MDCoreTests/TextSearchTests.swift`, `App/mdview/Reader/ReaderView.swift`, `App/mdview/Reader/SourceView.swift`.

Add find with SwiftUI .searchable(text:placement: .navigationBarDrawer(displayMode: .automatic)) on ReaderView (D10). MDCore.TextSearch.ranges(of:in:) returns case- and diacritic-insensitive match ranges. While the query is non-empty the reader shows SourceView with every match highlighted (background color) and the current one emphasized, scrolled into view; the search bar shows `n of N` (or `No matches`) and submitting moves to the next match, wrapping. Clearing or cancelling the search returns to the mode the user had. No custom find UI beyond that.

**Acceptance**

- `make test` passes, including TextSearchTests (case/diacritic insensitive, overlapping text, empty query, no match, emoji/combining characters)
- Typing a query shows highlighted matches in the source text with an `n of N` count; submit advances and wraps; cancel restores the previous Rendered/Source mode
- CI on the branch is green

### B7 Release prep and docs: icon, privacy manifest, licenses, README, RELEASE.md, review

Size M, priority P1, model `grok`, depends on B2, B6.

Owns: `App/mdview/Assets.xcassets/AppIcon.appiconset/`, `App/mdview/PrivacyInfo.xcprivacy`, `project.yml`, `scripts/`, `README.md`, `THIRD_PARTY_NOTICES.md`, `docs/RELEASE.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`.

Make the app shippable and documented. Generate a simple single-size 1024 app icon with a committed script under scripts/ (no external services). Add PrivacyInfo.xcprivacy (NSPrivacyTracking false, no tracking domains, no collected data, required-reason API entries for what the app actually uses such as UserDefaults CA92.1). Set MARKETING_VERSION 0.1.0 and CURRENT_PROJECT_VERSION 1 in project.yml. Write THIRD_PARTY_NOTICES.md with the license text and copyright of every shipped component (Textual, swiftui-math, swift-concurrency-extras, Prism.js bundled inside Textual; all MIT) and link it from README. Rewrite README.md (what mdview does, features, privacy: no network, how to build, CI badge kept, license MIT) and add a short docs/ARCHITECTURE.md (DocumentGroup, Textual, MDCore, network-free image policy). Write docs/RELEASE.md: keving's signing steps (fill DEVELOPMENT_TEAM in the gitignored Config/Local.xcconfig, make open, automatic signing, run on device with Developer Mode, App Store Connect record, archive, upload, TestFlight) and an on-device checklist (open from Files, share/Open in from another app, Recents, iPad drag-drop, dark mode, largest text size, Obsidian toggle, find, a remote image link opening Safari). Finally review B1-B6 acceptance end to end and list any gap in the PR body.

**Acceptance**

- `make test` and `make lint` pass and CI on the branch is green
- PrivacyInfo.xcprivacy is included in the app target and declares no tracking and no collected data
- THIRD_PARTY_NOTICES.md lists Textual, swiftui-math, swift-concurrency-extras and Prism.js with their MIT license text and copyright, and every dependency in Package.resolved is MIT/BSD/Apache-2.0 compatible with this MIT repo
- README.md, docs/ARCHITECTURE.md and docs/RELEASE.md exist and match the shipped behavior; docs/RELEASE.md contains the on-device checklist; no Team ID or Apple account detail appears anywhere in the repo

### B8 Sign, install on iPhone and ship to TestFlight (human)

Size M, priority P2, model `grok`, depends on B7, **needs a human (keving)**.

Owns: `Config/Local.xcconfig`.

keving follows docs/RELEASE.md on his own Mac: fill the unset DEVELOPMENT_TEAM (his Team ID) into the gitignored Config/Local.xcconfig, open the project with make open, enable automatic signing, install on his iPhone (Developer Mode on), then create the App Store Connect record, archive, upload and install from TestFlight. He runs the on-device checklist and files one bead per defect found. No bot action; the runner stops here and waits.

**Acceptance**

- mdview runs on keving's iPhone from an Xcode install
- A TestFlight build is available to the internal tester and installs
- Each item of the on-device checklist in docs/RELEASE.md is marked pass or has a bead filed

## 6. Quality gate

Each bead (except B8) passes `make lint` and `make test` locally and, from B2 on, a green GitHub Actions run on the
branch. `make test` = `swift test --package-path Packages/MDCore` plus `xcodebuild build -destination
'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. Never run the simulator locally; `make test-ios` runs in CI only.

## 7. Decisions (Oct 25, 2026)

| ID | By | Decision |
|---|---|---|
| D1 | keving (confirmed Oct 25, 2026) | Repo public under MIT (LICENSE: 2026 Kevin Gould / Par72 Labs, LLC); gitleaks full-history scan before the flip; Actions macOS minutes free. |
| D2 | keving (confirmed Oct 25, 2026) | Remote images are never loaded inline: they render as a link that opens Safari on tap (MDCore.RemoteImages.linkify) and the Textual image loader is a local-file-only loader; the app stays network-free. |
| D3 | keving (confirmed Oct 25, 2026) | Bundle id us.par72.mdview; DEVELOPMENT_TEAM stays an unset build setting that keving fills in at B8. |
| D4 | keving (confirmed Oct 25, 2026) | System SF font (default). |
| D5 | keving (confirmed Oct 25, 2026) | Open .txt files too (Alternate handler for public.plain-text), shown as plain source text with no toggle. |
| D6 | keving's call (changed Oct 25, 2026) | Obsidian extras on by default with one setting to turn them off: @AppStorage("obsidian.enabled") default true, one Toggle in a small reader toolbar menu. Narrowed by D11 to the cheap parts only: hide front matter and show [[wikilinks]] as plain text; embeds and callouts deferred. |
| D7 | keving (confirmed Oct 25, 2026) | GitHub Actions CI. |
| D8 | keving's call (changed Oct 25, 2026) | Snapshot tests deferred: no snapshot target, no snapshot CI job; add them back after a working prototype exists. |
| D9 | keving (confirmed Oct 25, 2026) | Swift 6 strict concurrency. |
| D10 | keving (confirmed Oct 25, 2026) | Find-in-page via SwiftUI .searchable; matches are highlighted in the source text. |
| D11 | keving (Oct 25, 2026) | Use off-the-shelf components and keep functionality limited: build as little as possible. Textual for Markdown rendering and code highlighting, SwiftUI DocumentGroup for opening files and recents, .searchable for find; no custom parser, renderer, highlighter, file browser or recents store. Scope: open .md/.txt, Rendered/Source toggle, recents, dark mode, Dynamic Type, cheap Obsidian setting, find. |
| D12 | planner, following D11 (Oct 25, 2026) | Package choice: Textual 0.5.x (gonzalezreal/textual, MIT, active successor of MarkdownUI) pinned upToNextMinor; it brings swiftui-math and swift-concurrency-extras (MIT) and bundles Prism.js (MIT) for highlighting, so no Splash/HighlightSwift. Consequence: iOS 18.0 minimum (Textual requirement). Fallback if Textual blocks: MarkdownUI 2.4.1 (MIT, maintenance mode) plus Splash 0.16 (MIT). |
| D13 | keving (Oct 25, 2026) | Development runs overnight with Grok only: every bead has model grok and the run uses --model grok, so every job dispatches with --tool grok. Builds and tests run in GitHub Actions; bots never boot the simulator on keving's Mac. |

### Deferred

- **Snapshot tests (D8)**: after a working prototype (B8 done). test-only swift-snapshot-testing target, references recorded in CI only.
- **Obsidian embeds (![[...]]) and callouts (D11)**: after B8. embeds currently show as literal text; callouts as block quotes.
- **Relative .md links, folder access for sibling images, footnotes, math, task-list checkboxes**: only if keving asks. not built in this run (D11).
