# mdview: a one-button, fully local iOS Markdown viewer

Feature slug: `mdview`. Base branch: `main`. Companion file: `beads.json` (same directory).

## 1. Goal and non-goals

**Goal.** A tiny native SwiftUI app (iOS 17+) that opens any `.md` / `.markdown` file instantly from the Files app,
the share sheet / "Open in", the in-app picker, or drag-and-drop on iPad, renders GitHub-flavored Markdown (GFM)
with great typography in light and dark mode with Dynamic Type, and has one control: a **Rendered / Source**
toggle. The home screen is a recent-files list. Find-in-page is included because it turns out to be cheap with the
chosen architecture. Everything is local: no network, no telemetry, no SDKs that phone home.

**Non-goals.** Editing, sync, accounts, cloud, analytics, any network access by the app process (remote images are
not fetched; see decision D2), Android, macOS/Catalyst, App Store release (TestFlight is the ceiling), settings
screens beyond one small Obsidian toggle (decision D6), themes, fonts pickers. Footnotes and math are not rendered (shown as plain text).

**Who it is for.** keving reads reports, plans and bot output plus Obsidian vault notes on an iPhone. Obsidian
conveniences (YAML front matter, `[[wikilinks]]`, `![[embeds]]`, callouts) are handled so vault notes look right; they
are on by default and one setting turns them off (D6).

## 2. Current state

The repo is a bootstrap: `README.md`, beads tracker config (`.beads/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`,
`.codex/`, `.cursor/`), and a `.gitignore` that already ignores `xcuserdata/`, `DerivedData/`, `build/`. There is no
Xcode project, no Swift package, no Makefile, no CI, no tests. `AGENTS.md` and `CLAUDE.md` contain no build or test
commands yet; bead B1 creates them and documents them.

Facts that shape the plan:

- The GitHub repo `khgouldy/mdview` is **public under the MIT license** (decision D1, `LICENSE` at the repo root),
  so GitHub-hosted macOS runners cost nothing. CI still stays lean (one job, push-only, path-filtered).
- Bots must never boot the iOS Simulator on keving's Mac. The local quality gate therefore consists only of
  macOS-native `swift test` for the Swift package plus a device-SDK `xcodebuild build` with signing disabled, which
  compiles the app without any simulator. Simulator tests (XCUITest) run only in GitHub Actions. Snapshot tests are deferred (D8).
- The toolchain on keving's Mac could not be probed while planning (approval hook). B1 verifies and pins it.

## 3. Design

### 3.1 Repository layout

```
Makefile                     # the only entry point agents and CI use (gen, lint, format, test, build-ios, test-ios)
project.yml                  # XcodeGen spec; mdview.xcodeproj is generated and gitignored
Config/Local.xcconfig.example# DEVELOPMENT_TEAM / bundle id overrides; Local.xcconfig is gitignored
Packages/MarkdownKit/        # Swift package; all logic lives here and is tested on macOS without a simulator
  Package.swift
  Sources/MarkdownModel/     # Foundation only: document model, parser facade, Obsidian preprocess, highlighter, search
  Sources/MarkdownViews/     # SwiftUI renderer (compiles on iOS 17 and macOS 14 so `swift test` builds it)
  Sources/ReaderCore/        # Foundation only: file opening, security-scoped access, bookmarks, recents, image loading
  Tests/MarkdownModelTests/  Tests/MarkdownViewsTests/  Tests/ReaderCoreTests/  Tests/Fixtures/*.md
App/mdview/                  # thin app target: App entry, HomeView, ReaderView, SourceView, navigation, resources
App/mdviewUITests/           # XCUITest (CI only)
.github/workflows/ci.yml
docs/DEVELOPMENT.md  docs/ARCHITECTURE.md  docs/RELEASE.md  docs/plans/mdview/
```

### 3.2 Components and contracts

**MarkdownModel** (no UI, no UIKit, Foundation + swift-markdown).

```swift
public struct MarkdownDocument: Equatable, Sendable {
    public var frontMatter: String?      // raw YAML between leading --- fences, stripped from the body
    public var title: String?            // text of the first H1, if any
    public var blocks: [Block]
}
public struct BlockID: Hashable, Sendable { public let raw: Int }   // pre-order index, stable for one parse
public enum Block: Equatable, Sendable {
    case heading(id: BlockID, level: Int, slug: String, inlines: [Inline])
    case paragraph(id: BlockID, inlines: [Inline])
    case figure(id: BlockID, image: Inline)                 // paragraph consisting of a single image
    case codeBlock(id: BlockID, language: String?, code: String)
    case blockQuote(id: BlockID, callout: String?, children: [Block])   // callout = Obsidian "> [!note]" tag
    case list(id: BlockID, ordered: Bool, start: Int, items: [ListItem])
    case table(id: BlockID, alignments: [ColumnAlignment], header: [TableCell], rows: [[TableCell]])
    case thematicBreak(id: BlockID)
    case html(id: BlockID, raw: String)                     // rendered as monospaced plain text
}
public struct ListItem: Equatable, Sendable { public var checkbox: Bool?; public var blocks: [Block] }
public struct TableCell: Equatable, Sendable { public var inlines: [Inline] }
public enum ColumnAlignment: Sendable { case left, center, right, none }
public indirect enum Inline: Equatable, Sendable {
    case text(String), softBreak, lineBreak
    case emphasis([Inline]), strong([Inline]), strikethrough([Inline])
    case code(String)
    case link(destination: String, children: [Inline])
    case image(source: String, alt: String, title: String?)
    case html(String)
}
public struct MarkdownParser: Sendable {
    public struct Options: Sendable { public var obsidian: Bool = true }   // app passes @AppStorage("obsidian.enabled") (D6)
    public init(options: Options = .init())
    public func parse(_ text: String) -> MarkdownDocument      // pure, synchronous, callable off the main actor
}
public enum InlineText { public static func flatten(_ inlines: [Inline]) -> String }  // canonical plain text, see 3.4
public struct CodeHighlighter { public func tokens(for code: String, language: String?) -> [Token] }
public struct Token: Equatable, Sendable { public var range: Range<String.Index>; public var kind: TokenKind }
public enum TokenKind: Sendable { case plain, keyword, string, comment, number, type, attribute, punctuation, added, removed }
public struct DocumentSearch { public init(_ doc: MarkdownDocument); public func matches(for query: String) -> [SearchMatch] }
public struct RunID: Hashable, Sendable { public var block: BlockID; public var cell: Int? }    // cell for table cells
public struct SearchMatch: Equatable, Sendable { public var run: RunID; public var utf16Range: Range<Int> }
public protocol ImageLoading: Sendable { func loadImage(source: String) async -> ImageLoadResult }
public enum ImageLoadResult: Sendable { case data(Data), remote(URL), missing, needsFolderAccess(folder: URL) }
```

**MarkdownViews** (SwiftUI). Entry point:

```swift
public struct MarkdownView: View {
    public init(document: MarkdownDocument,
                theme: MarkdownTheme = .default,
                highlights: [RunID: [Range<Int>]] = [:],   // find-in-page matches, utf16 offsets into flatten()
                currentHighlight: SearchMatch? = nil,
                scrollTarget: Binding<BlockID?> = .constant(nil))
}
public struct MarkdownTheme: Sendable { fonts (text styles, Dynamic Type), spacing, measure (max width 680), colors (light/dark), code palette }
public struct InlineRenderer { public static func attributedString(_ inlines: [Inline], theme:, baseFont:, highlights:) -> AttributedString }
```

Environment keys: `\.imageLoader: any ImageLoading` (default `NoImageLoader` returning `.missing`), `\.markdownLinkHandler:
(URL) -> Void` (default opens with `openURL`). `MarkdownView` is a `LazyVStack` of `BlockView`s inside a `ScrollView`
wrapped in a `ScrollViewReader`; each block has `.id(block.id)`.

**ReaderCore** (Foundation only, no UIKit).

```swift
public struct OpenedFile: Identifiable, Sendable {
    public enum Source: Sendable { case picker, openURL, drop, recent, bundled }
    public let id: UUID; public let url: URL; public let bookmark: Data?; public let displayName: String
    public let source: Source; public let text: String; public let inboxCopy: Bool
}
public enum FileOpenError: Error { case unreadable(URL), undecodable(URL), tooLarge(URL, Int), accessDenied(URL) }
public actor FileOpener { public func open(_ url: URL, source: OpenedFile.Source) async throws -> OpenedFile }
public enum SecurityScope { public static func withAccess<T>(_ url: URL, _ body: () throws -> T) rethrows -> T }
public struct RecentEntry: Codable, Identifiable, Equatable, Sendable { id, displayName, folderHint, bookmark: Data, lastOpened: Date }
@Observable @MainActor public final class RecentsStore { init(persistence: RecentsPersistence); entries; record(_:); remove(_:); resolve(_:) async -> URL? }
public protocol RecentsPersistence: Sendable { func load() throws -> [RecentEntry]; func save(_:) throws }
@Observable @MainActor public final class FolderAccessStore { grantedFolders; grant(_ url: URL); folderCovering(_ url: URL) -> URL? }
public struct FileImageLoader: ImageLoading { init(baseURL: URL?, folderAccess: FolderAccessStore?) }
```

**App target** (SwiftUI, iOS only): `mdviewApp` (WindowGroup, `onOpenURL`, environment wiring), `HomeView`
(recents, Open File…, welcome sample, empty state, drop target), `ReaderView` (nav title = file name, segmented
`Rendered | Source` picker, hidden pull-down find, link handling, folder-access prompt), `SourceView`
(`UITextView` wrapper, read-only, selectable, monospaced, `isFindInteractionEnabled = true`), `ReaderModel`
(`@Observable`, parses off-main, holds `MarkdownDocument`, mode, search state), `AppRouter` (NavigationStack path).

### 3.3 Data flow

1. A URL arrives (`onOpenURL`, `fileImporter`, `onDrop`, recents tap, bundled sample).
2. `FileOpener.open` takes security scope, reads bytes, decodes (UTF-8 → UTF-16 with BOM → Latin-1 fallback),
   creates a bookmark, releases scope, and for Inbox copies moves the file to `Documents/Imported/`.
3. `RecentsStore.record` upserts the entry (dedupe by bookmark-resolved path) and saves JSON to Application Support.
4. `ReaderModel.load(file)` runs `MarkdownParser.parse` in a detached task, then publishes the document.
5. `MarkdownView` renders blocks; images ask `FileImageLoader`, which resolves `source` relative to the file's
   folder, honours granted folder bookmarks, and never touches the network.
6. Find: `DocumentSearch.matches(query)` → `highlights` + `scrollTarget` into `MarkdownView`.

### 3.4 Key decisions (and the alternative rejected)

| Decision | Chosen | Rejected and why |
|---|---|---|
| Project format | **XcodeGen `project.yml`**, generated `.xcodeproj` gitignored, all logic in a local SwiftPM package | Checked-in `.xcodeproj` (binary-ish pbxproj merges, agents cannot edit reliably); Tuist (heavier, Swift DSL to learn); package-only app (Xcode cannot archive a package as an app). |
| Markdown parser | **apple/swift-markdown** (pinned release tag). GFM tables, task lists, strikethrough and autolinks are on by default; it gives a typed AST we walk once into our own model; Apple-maintained; no network code. | `AttributedString(markdown:)` (no tables, no block structure, no code-block fences); writing our own CommonMark parser (weeks of edge cases); MarkdownUI (large, opinionated, brings its own views); cmark-gfm via C directly (swift-markdown already wraps it). |
| Rendering | **Native SwiftUI block renderer** over the model | `WKWebView` + GitHub CSS: WebKit process adds 150–400 ms to first paint, Dynamic Type and VoiceOver are second-class, and guaranteeing "no network" needs content-rule-lists and audits. Single `UITextView` with one `NSAttributedString`: continuous selection and free find, but tables with horizontal scroll and images-as-figures are painful in TextKit. |
| Where logic lives | **Swift package with 3 targets** that compile on macOS, tested with `swift test` | Logic in the app target: unit tests would need the iOS Simulator, which bots may not run locally. |
| Source mode | `UITextView` wrapper (read-only) | SwiftUI `Text`: slow and memory-hungry above ~100 KB, no native find. |
| Syntax highlighting | **Own single-pass tokenizer** with small per-language grammars (keywords, comments, strings, numbers) | Highlightr (JavaScriptCore + highlight.js, ~1 MB, JS context spin-up on first code block); tree-sitter (binary grammars, build complexity). |
| Find-in-page | Hidden pull-down search bar (`.searchable` navigation-bar drawer) so the one visible control stays the toggle; matches highlighted via `AttributedString` ranges; `UIFindInteraction` in Source mode | Visible magnifier button (second control); skipping find (it is cheap because `InlineText.flatten` and `InlineRenderer` share one text rule). |
| Text-rule invariant | `String(InlineRenderer.attributedString(inlines).characters) == InlineText.flatten(inlines)` for every inline list. A `swift test` enforces it, so search offsets map 1:1 onto rendered text. | Separate plain-text extraction (offsets drift the moment someone changes a renderer rule). |
| Images | `ImageLoading` protocol; file images loaded from the file's folder; remote image URLs rendered as a tappable chip that opens Safari | Fetching on tap inside the app (makes the process network-capable; rejected in decision D2). |
| Recents | JSON of security-scoped bookmarks in Application Support, max 50 | `UIDocumentBrowserViewController` / `DocumentGroup` home (system chrome, not "no clutter", recents not customizable); UserDefaults (fine for size, but no room for migration). |
| Concurrency | Swift 6 language mode, strict concurrency | Swift 5 mode (defer the pain). Fallback: if a dependency blocks mode 6 in a target, set that target to 5 and note it in `docs/ARCHITECTURE.md`. |
| Signing config | Bundle id `us.par72.mdview`; `DEVELOPMENT_TEAM` is left unset in the repo (empty in `Config/Local.xcconfig.example`) and keving fills it into the gitignored `Config/Local.xcconfig` at B15; CI builds with `CODE_SIGNING_ALLOWED=NO` | Team id in `project.yml` (leaks across machines, blocks CI). |
| "No network" enforcement | SwiftLint custom rule that fails on `URLSession`, `NWConnection`, `WKWebView`, `CFNetwork`, `NSURLConnection`, `URLSessionConfiguration` anywhere in `App/` and `Packages/`; `PrivacyInfo.xcprivacy` declares no tracking | Trusting code review. |

### 3.5 Typography defaults (B5/B11 implement, B11 may tune)

Body: `.body` system font (SF), line spacing 4 pt, paragraph spacing 12 pt, measure max 680 pt centered, horizontal
padding 20 pt (16 on compact widths below 375). Headings H1–H6: `.largeTitle` bold, `.title` bold, `.title2`
semibold, `.title3` semibold, `.headline`, `.subheadline` semibold uppercase-tracking. Code: `.body` monospaced
design at 0.92× scale for blocks, inline code `.monospaced` on a tinted rounded background. Quotes: 3 pt leading bar,
secondary text. Tables: header row semibold, 1 px separators, horizontal `ScrollView` when wider than measure. All
sizes come from text styles or `@ScaledMetric`, so Dynamic Type scales everything.

## 4. Risks and containment

| Risk | Containment |
|---|---|
| Simulator CI time | The repo is public (D1), so macOS minutes are free. CI still runs on `push` only (no duplicate `pull_request` runs), path-filtered, `concurrency: cancel-in-progress`, 30-min timeout, one required job. Local gate catches most failures before CI. |
| Bots cannot run the simulator locally | All logic in the package; `make test-ios` refuses to run unless `CI=true` or `MDVIEW_ALLOW_SIMULATOR=1`. |
| Security-scoped URL quirks (Files in-place vs Inbox copies, siblings not readable) | `FileOpener` handles both paths and is tested with temp directories; images degrade to a placeholder with a "grant folder access" action instead of failing. |
| swift-markdown API drift or Swift 6 Sendable friction | Pin a release tag; convert the AST to our own `Sendable` model in one visitor and never leak `Markup` types out of `MarkdownModel`. |
| Large files freeze the UI | Parse off the main actor; `LazyVStack`; highlighting capped at 20 000 characters per code block; Source mode uses `UITextView`. Fixture generator produces a 500 KB document for a measured test. |
| Visual regressions with no snapshot tests | Snapshot tests are deferred until a working prototype exists (D8). Until then B11 checks visuals with SwiftUI previews in light/dark and at several Dynamic Type sizes, and XCUITests cover behaviour. Snapshot tests come back as a follow-up bead after B15. |
| Scope creep ("just one more control") | Non-goals above; any new visible control needs keving's explicit yes. |
| Signing / Apple Developer steps | Isolated in the final `needs_human` bead with a checklist in `docs/RELEASE.md`; nothing else depends on them. |

## 5. Beads

Conventions for every bead: work on the single feature branch; run the quality gate (section 6) before finishing;
never boot a simulator or run `xcodebuild test` locally; keep `swift test` passing on macOS (that means
`MarkdownViews` must keep compiling on macOS 14, guard UIKit-only code with `#if canImport(UIKit)`); format only the
files you changed (`swiftformat <paths>`), never the whole tree; Conventional Commits with `Agent:` / `Model:` /
`Bead:` trailers.

### B1 Scaffold project, package, Makefile and lint

Create the skeleton everything else builds on. Files to create:

- `project.yml` (XcodeGen): `name: mdview`; `options.bundleIdPrefix: us.par72`, `deploymentTarget.iOS: "17.0"`,
  `createIntermediateGroups: true`; base settings `SWIFT_VERSION: 6.0`, `SWIFT_STRICT_CONCURRENCY: complete`,
  `ENABLE_USER_SCRIPT_SANDBOXING: YES`, `TARGETED_DEVICE_FAMILY: "1,2"`, `SUPPORTS_MACCATALYST: NO`,
  `ITSAppUsesNonExemptEncryption: NO` in Info properties; `configFiles` pointing at `Config/Local.xcconfig` for all
  configurations; package reference `MarkdownKit: { path: Packages/MarkdownKit }`; targets `mdview` (application,
  sources `App/mdview`, depends on products `MarkdownViews` and `ReaderCore`) and `mdviewUITests` (ui-testing bundle,
  sources `App/mdviewUITests`, depends on `mdview`); scheme `mdview` with both test targets and `-uiTesting` not yet
  needed. Info properties: `UILaunchScreen: {}` (native launch), `UISupportedInterfaceOrientations` all four for
  iPad and portrait+landscape for iPhone, `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes:
  false`. Do **not** add document types yet (B8 owns them).
- `Config/Local.xcconfig.example` with `DEVELOPMENT_TEAM =` (deliberately empty: the Team ID is an unset build
  setting until keving fills it in at B15; never look up or commit Apple account details) and
  `PRODUCT_BUNDLE_IDENTIFIER = us.par72.mdview`; add `Config/Local.xcconfig` and `*.xcodeproj` to `.gitignore`. `make gen` copies the example to
  `Config/Local.xcconfig` when absent so XcodeGen never fails on a missing config file.
- `Packages/MarkdownKit/Package.swift`: `swift-tools-version: 5.10` (or 6.0 if the installed toolchain is 6.x; record
  which), `platforms: [.iOS(.v17), .macOS(.v14)]`, products and targets `MarkdownModel`, `MarkdownViews`
  (depends on MarkdownModel), `ReaderCore` (depends on MarkdownModel), test targets for each, and
  `Tests/Fixtures` as a copied resource of `MarkdownModelTests`. Dependency `apple/swift-markdown` pinned to the
  newest release tag (`.upToNextMinor(from:)`), used by `MarkdownModel` only. Each target gets one placeholder
  source file (`public enum MarkdownModelVersion { public static let current = "0.1.0" }` style) and one passing
  test, so `swift test` runs three test bundles.
- `App/mdview/mdviewApp.swift` (`@main`, `WindowGroup { ContentView() }`), `App/mdview/ContentView.swift` showing
  the text "mdview" with `.accessibilityIdentifier("home.title")`, `App/mdview/Assets.xcassets` with an empty
  `AppIcon` set and an `AccentColor`. `App/mdviewUITests/LaunchTests.swift`: one XCUITest that launches the app and
  asserts `home.title` exists (runs only in CI).
- `Makefile` targets: `tools` (`HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen swiftformat swiftlint`, idempotent),
  `gen` (`xcodegen generate --use-cache`, after ensuring `Config/Local.xcconfig`), `lint` (`swiftformat --lint
  Packages App` then `swiftlint lint --strict --quiet`; if a tool is missing, print `run: make tools` and exit 1),
  `format` (same paths, write mode; document that agents should format only changed files), `test`
  (`swift test --package-path Packages/MarkdownKit` then `$(MAKE) build-ios`), `build-ios` (`gen` then
  `xcodebuild build -project mdview.xcodeproj -scheme mdview -destination 'generic/platform=iOS'
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY= -quiet`; if `xcodebuild` is missing print a warning and exit 0 so the
  package tests still gate on non-Mac hosts), `test-ios` (CI only: exits 1 with an explanation unless `CI=true` or
  `MDVIEW_ALLOW_SIMULATOR=1`; runs `xcodebuild test -project mdview.xcodeproj -scheme mdview -destination
  "platform=iOS Simulator,name=$(SIM_NAME),OS=$(SIM_OS)" -resultBundlePath build/test.xcresult`, with
  `SIM_NAME ?= iPhone 16` and `SIM_OS ?= latest`), `open` (`gen` then `open mdview.xcodeproj`), `clean`.
- `.swiftformat` (`--swiftversion 6.0`, 4-space indent, `--maxwidth 120`, `--exclude .build,build,*.xcodeproj`) and
  `.swiftlint.yml` (`included: [App, Packages]`, `excluded: [Packages/MarkdownKit/.build, build]`, line length 120
  warning / 160 error, `custom_rules.no_networking`: regex `\b(URLSession|URLSessionConfiguration|NWConnection|
  WKWebView|CFNetwork|NSURLConnection|NWPathMonitor)\b`, severity error, message "mdview is fully local; no
  networking APIs").
- `docs/DEVELOPMENT.md`: toolchain versions found on the machine (Xcode, Swift, xcodegen, swiftformat, swiftlint),
  the Makefile targets, the rule that simulators run only in CI, how to open in Xcode. Replace the placeholder
  "Build & Test" section of `CLAUDE.md` and add the same commands to `AGENTS.md` (they are separate files; edit
  both).

Edge cases: Homebrew may need `HOMEBREW_NO_AUTO_UPDATE=1`; `xcodegen generate --use-cache` needs a writable
`.xcodegen` cache dir (add to `.gitignore`); `swift test` must not need Xcode's iOS platform; the device build must
succeed with no team selected. If Swift 6 language mode breaks a placeholder, keep mode 6 and fix the code, do not
downgrade.

Test approach: `make lint` and `make test` pass locally; `swift test` lists three test bundles; `git status` shows no
generated project files. Commit `mdview.xcodeproj`? No: it is generated.

### B2 GitHub Actions CI with simulator tests

Create `.github/workflows/ci.yml` so every push gets lint, package tests, the device build and simulator tests
without anyone running a simulator locally.

- Triggers: `push` on all branches with `paths-ignore: ["docs/**", "**/*.md", "LICENSE"]`; `workflow_dispatch` (no inputs;
  manual re-runs). No `pull_request` trigger (avoids duplicate runs;
  pushes still show as checks on the PR).
- `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`, `timeout-minutes: 30`,
  `permissions: contents: read`.
- One job `ios` on a pinned macOS image. Pick the newest stable image from
  https://github.com/actions/runner-images (e.g. `macos-15`; check the README for what Xcode and iOS simulator
  runtimes it preinstalls) and pin Xcode with `sudo xcode-select -s /Applications/Xcode_<ver>.app`. Set `SIM_NAME`
  and `SIM_OS` env vars to a device/runtime that exists on that image; add a diagnostic step
  `xcrun simctl list devices available` so failures are debuggable from the log.
- Steps: `actions/checkout@v4`; `brew install xcodegen swiftformat swiftlint` (`HOMEBREW_NO_AUTO_UPDATE=1`, or
  `make tools`); cache `Packages/MarkdownKit/.build` and `~/Library/Developer/Xcode/DerivedData` keyed on
  `Package.resolved` + `project.yml`; `make lint`; `make test`; `make test-ios` with `CI=true`; on failure upload
  `build/test.xcresult` as an artifact (`actions/upload-artifact@v4`, 7-day retention). No snapshot recording or
  snapshot artifacts (snapshot tests are deferred, D8).
- `make test-ios` gains `-parallel-testing-enabled NO` for determinism.
- Add a CI status badge to `README.md` and a "CI" section to `docs/DEVELOPMENT.md` describing cost (free: the repo is
  public, decision D1) and how to download the xcresult artifact with `gh run download`.

Edge cases: first boot of a simulator on a fresh runner can take 60–90 s (add a `xcrun simctl boot` warm-up step
with `|| true`); Homebrew on runners already has some tools (`brew install` of an installed formula is a no-op);
`xcodebuild` needs `-destination` with an `OS=` that exists, so prefer `OS=latest` only if the image has exactly one
runtime, otherwise pin it.

Test approach: push the branch and confirm with `gh run list --branch <branch> --limit 1` and `gh run watch` that
the run is green (lint, `swift test`, device build, XCUITest LaunchTests). The agent may need to push once to see
it; that is allowed (the runner pushes the feature branch anyway).

### B3 Markdown document model and parser facade

Implement `MarkdownModel`'s core: the types in section 3.2 (`MarkdownDocument`, `Block`, `Inline`, `ListItem`,
`TableCell`, `ColumnAlignment`, `BlockID`, `RunID`), `MarkdownParser`, `InlineText.flatten`, front matter and
Obsidian preprocessing. Files: `Sources/MarkdownModel/Model/*.swift`, `Sources/MarkdownModel/Parser/MarkdownParser.swift`,
`Parser/ModelBuilder.swift` (a `MarkupVisitor` over swift-markdown), `Parser/FrontMatter.swift`,
`Parser/Obsidian.swift`, `Parser/Slug.swift`, `Text/InlineText.swift`.

Rules:
- `parse` is pure and synchronous; no `Markup` type leaks outside the module. Assign `BlockID` in pre-order,
  including nested blocks inside quotes and list items.
- Front matter (when `options.obsidian`): if the text begins with `---\n` (allow `\r\n`) and a line that is exactly
  `---` or `...` closes it within the first 200 lines, strip it into `frontMatter`; otherwise leave the text alone.
- `options.obsidian == false` (D6 setting off): no front matter stripping, wikilinks, embeds or callouts; the text
  parses as plain GFM (e.g. `[[Note]]` stays literal text, `> [!note]` stays an ordinary quote).
- Obsidian (when `options.obsidian`): operate on `Inline.text` nodes only (code spans and code blocks are separate
  nodes and must be untouched). `![[name.png]]` / `![[name.png|300]]` → `.image(source: "name.png", alt: "name")`;
  `[[Note]]`, `[[Note|Alias]]`, `[[Note#Heading]]` → `.link(destination: "Note.md" (+ `#slug`), children: [.text(Alias or Note)])`.
  A block quote whose first paragraph starts with `[!tag]` (optionally followed by `+`/`-` and a title) becomes
  `.blockQuote(callout: "tag", ...)` with the marker removed from the text; the rest of the quote is unchanged.
- Soft breaks become `.softBreak` (renderer decides spacing); hard breaks `.lineBreak`. A paragraph whose only
  inline is an image becomes `.figure`. Headings get `slug` computed GitHub-style (lowercase, strip punctuation
  except hyphen/space, spaces → hyphens, dedupe with `-1`, `-2` suffixes per document).
- Tables: map `Table.columnAlignments`; pad short rows with empty cells to the header width; truncate longer rows.
- Task list items: `ListItem.checkbox` from swift-markdown's `checkbox` (`.checked` → true, `.unchecked` → false,
  nil otherwise).
- `InlineText.flatten`: text → as is; softBreak → " "; lineBreak → "\n"; emphasis/strong/strikethrough/link →
  flatten(children); code → the code string; image → alt; html → raw. This is the canonical text rule; B5 and B12
  depend on it verbatim.
- `title`: flatten of the first level-1 heading, if any.

Fixtures (`Tests/Fixtures/`): `gfm-kitchen-sink.md` (every block and inline type, nested lists three deep, a task
list, a table with all alignments, fenced code with and without language, indented code, HTML block, hard breaks,
autolinks), `obsidian-note.md` (front matter, wikilinks with alias and heading, embeds, two callouts, a wikilink
inside a code span that must stay literal), `edge-cases.md` (empty file is a separate test, front matter without
closing fence, CRLF line endings, a heading-only file, unicode and emoji, a 10 000-character paragraph).

Tests (`Tests/MarkdownModelTests/`): one test per fixture asserting the block structure (compare against hand-written
expected `Block` values for the small fixtures; for the kitchen sink assert counts and a few spot checks), front
matter round trip, Obsidian conversions, the same fixture parsed with `obsidian: false` (everything stays literal),
slug dedupe, `flatten` rules, empty input → empty document, CRLF handling,
`BlockID` uniqueness and pre-order, and an `XCTest.measure` baseline parsing a generated 500 KB document (no hard
limit, but log the time).

### B4 Syntax highlighter tokenizer

Implement `CodeHighlighter` in `Sources/MarkdownModel/Highlighting/`: `CodeHighlighter.swift`, `Grammar.swift`,
`Grammars/*.swift` (one file per language family), `Token.swift`.

- `Grammar` is data: `keywords: Set<String>`, `types: Set<String>` (optional), `lineComment: [String]`,
  `blockComment: [(open: String, close: String)]`, `stringDelimiters: [StringRule]` (quote char, escape char,
  multiline allowed, raw prefixes), `numberPattern` (simple scanner, not regex), `caseSensitive`, `attributePrefix`
  (e.g. `@` for Swift/Kotlin/Python decorators, `#` for Swift compiler directives). Grammars for: swift, objective-c,
  c/c++, python, javascript, typescript (shares js), jsx/tsx (alias), json, bash/sh/zsh/shell, yaml/yml, toml, sql,
  go, rust, kotlin, java, ruby, html/xml (tags and attributes), css, markdown (headings, emphasis markers), diff
  (`+` lines → `.added`, `-` lines → `.removed`, `@@` → `.punctuation`), dockerfile, makefile. Language lookup is
  case-insensitive and accepts common aliases (`js`, `ts`, `py`, `rb`, `yml`, `sh`, `zsh`, `console`, `shell`).
- Single forward scan, O(n), no backtracking, no `NSRegularExpression`. Unknown or nil language → one `.plain`
  token. Input over 20 000 characters → one `.plain` token (renderer relies on this cap). Tokens cover the whole
  string contiguously with no gaps or overlaps (test this invariant).
- JSON: keys (strings followed by `:`) as `.attribute`, other strings `.string`, `true/false/null` keywords.

Tests (`Tests/MarkdownModelTests/Highlighting/`): a golden test per grammar using a small snippet and expected
`[(kind, text)]` pairs; the contiguity invariant on every fixture; alias resolution; the size cap; a measure test on
a 10 000-line generated file (log time, target under 100 ms on CI hardware but do not assert).

### B5 SwiftUI block renderer: text, headings, lists, quotes, links

Implement the core of `MarkdownViews`: `MarkdownView.swift`, `BlockView.swift`, `Blocks/HeadingView.swift`,
`Blocks/ParagraphView.swift`, `Blocks/ListView.swift`, `Blocks/BlockQuoteView.swift`, `Blocks/ThematicBreakView.swift`,
`Blocks/HTMLBlockView.swift`, `Inline/InlineRenderer.swift`, `Theme/MarkdownTheme.swift`, `Theme/Environment.swift`
(`imageLoader`, `markdownLinkHandler` environment keys), `Previews/PreviewDocuments.swift` (SwiftUI previews with the
fixtures). Code blocks, tables and images are stubs in this bead (render code as monospaced text, tables as
"table" placeholder, images as alt text); B6 replaces them.

- `InlineRenderer.attributedString(inlines, theme, baseFont, highlights)` builds an `AttributedString` with SwiftUI
  attributes (`font`, `foregroundColor`, `backgroundColor`, `strikethroughStyle`, `link`, `inlinePresentationIntent`).
  Invariant: `String(result.characters) == InlineText.flatten(inlines)`; `highlights` are utf16 ranges into that
  string and apply a background colour (theme `highlight` / `currentHighlight`). Soft breaks render as a space.
- `MarkdownView`: `ScrollViewReader` + `ScrollView` + `LazyVStack(alignment: .leading, spacing: theme.blockSpacing)`,
  `.frame(maxWidth: theme.measure)` centered, padding from theme, `.textSelection(.enabled)` on text blocks, blocks
  `.id(block.id)`; when `scrollTarget` changes, `withAnimation { proxy.scrollTo(id, anchor: .top) }` then reset the
  binding to nil.
- Headings: text styles from section 3.5, `.accessibilityAddTraits(.isHeader)`, top spacing larger than bottom,
  `.id` also usable for `#slug` navigation (B7 maps slug → BlockID via the document).
- Lists: bullets `•`, `◦`, `▪` by depth, ordered numbers with `start`, task items show `checkmark.square.fill` /
  `square` symbols (non-interactive) with accessibility value "checked"/"unchecked"; nested blocks indent by
  `theme.listIndent` (scaled metric); tight vs loose spacing from whether items contain multiple blocks.
- Block quotes: leading 3 pt bar in `theme.quoteBar`, secondary foreground; if `callout` is set, show a small
  capitalised label row (icon by tag: note → `info.circle`, tip → `lightbulb`, warning → `exclamationmark.triangle`,
  default `quote.bubble`).
- Links: `.link` attribute; `MarkdownView` installs `.environment(\.openURL, OpenURLAction { url in
  markdownLinkHandler(url); return .handled })`. Default handler opens external URLs with the system `openURL`.
- Must compile and run previews on macOS 14 too (guard any UIKit use with `#if canImport(UIKit)`).

Tests (`Tests/MarkdownViewsTests/`, run on macOS via `swift test`): the flatten invariant for every inline list in all
fixtures (parse fixture → for each text-bearing block assert `characters == flatten`); highlight ranges set the
background attribute on exactly the requested characters; `MarkdownTheme.default` text styles for H1–H6; a smoke
test that `MarkdownView(document:)` can be instantiated with every fixture. Visual verification happens in B11's
preview pass.

### B6 Renderer: code blocks, tables, images

Replace the B5 stubs. Files: `Blocks/CodeBlockView.swift`, `Blocks/TableView.swift`, `Blocks/FigureView.swift`,
`Inline/InlineImageView.swift`, `Theme/CodePalette.swift`.

- Code blocks: rounded background (`theme.codeBackground`, light/dark), horizontal `ScrollView` when the longest line
  exceeds the measure (no soft wrap, matching GitHub), monospaced font at 0.92× body, language label in the top-right
  corner in secondary colour when a language is set, `CodeHighlighter` tokens mapped to `CodePalette` colours for
  light and dark (`@Environment(\.colorScheme)`), `.textSelection(.enabled)`. Highlighting runs synchronously; the
  20 000-character cap from B4 keeps it cheap. Line count above 2 000: render as plain text.
- Tables: `Grid` (iOS 16+) inside a horizontal `ScrollView`; header row semibold with a bottom rule, alternating row
  background at 4 % opacity, cell padding 8×6, column alignment from the model, minimum column width 64 pt, inline
  content via `InlineRenderer` (cells get `RunID(block:, cell:)` so B12 highlights work; pass `highlights` through).
  A table narrower than the measure does not scroll.
- Images: `FigureView` for `.figure`, `InlineImageView` for images inside paragraphs. Ask `imageLoader.loadImage(source:)`
  in `.task(id: source)`; result handling: `.data` → decode (`UIImage`/`NSImage` behind `#if canImport(UIKit)`),
  render `resizable().scaledToFit()` with max height 480 pt and the alt text as accessibility label, title as a
  caption below in `.caption` secondary; `.remote(url)` → a chip with `globe` icon, the host name, and "Opens in
  Safari"; tapping calls `markdownLinkHandler(url)`; `.missing` → chip with `photo` icon and the alt or file name;
  `.needsFolderAccess(folder)` → chip with `folder.badge.questionmark` and label "Allow access to <folder name>",
  tapping calls a new environment action `\.requestFolderAccess: (URL) -> Void` (default no-op; B10 wires it).
  Never block the main thread decoding: decode in the loader task.
- Any `Inline.html` renders as its raw text in monospaced secondary style.

Tests (macOS `swift test`): `CodePalette` has a colour for every `TokenKind` in both schemes; table cell `RunID`s are
unique per table; a fake `ImageLoading` returning each `ImageLoadResult` case can be injected via the environment
(instantiation smoke test). Visuals are checked in B11's preview pass.

### B7 Reader screen with Rendered / Source toggle

Build the reader in the app target. Files: `App/mdview/Reader/ReaderView.swift`, `Reader/ReaderModel.swift`,
`Reader/SourceView.swift`, `Reader/ReaderMode.swift`, `App/mdview/Resources/Samples/Welcome.md`,
`App/mdview/Support/LaunchArguments.swift`, `App/mdviewUITests/ReaderTests.swift`. Temporarily wire `ContentView`
to open the bundled `Welcome.md` so the screen can be exercised before B8/B9 (B9 replaces `ContentView` with
`HomeView`).

- `ReaderModel` (`@Observable @MainActor`): `file: OpenedFile`, `document: MarkdownDocument?`, `mode: ReaderMode`,
  `isParsing`, `error`. `load()` runs `MarkdownParser().parse(text)` in `Task.detached(priority: .userInitiated)`
  and publishes on the main actor; show a `ProgressView` only if parsing exceeds 250 ms (use a delayed task).
- `ReaderMode` (`.rendered`, `.source`) persisted in `UserDefaults` key `reader.mode` (app-wide last choice).
- `ReaderView`: `navigationTitle` = file display name without extension, `.navigationBarTitleDisplayMode(.inline)`;
  toolbar `.principal` or `.topBarTrailing` holds a segmented `Picker` "Rendered | Source" with accessibility
  identifiers `reader.mode`, `reader.mode.rendered`, `reader.mode.source`; body switches between `MarkdownView`
  and `SourceView` without re-parsing; keeps the one-control rule (no other toolbar items). `.toolbarRole(.editor)`
  on iPad to compact the back button.
- Link handling: install `\.markdownLinkHandler`. Fragment-only links (`#slug`) scroll to the heading with that slug
  (set `scrollTarget`). Relative links ending in `.md`/`.markdown` are forwarded to an `onOpenRelative: (URL) -> Void`
  closure (B10 implements opening); everything else goes to the system `openURL`.
- `SourceView`: `UIViewRepresentable` around `UITextView` (`isEditable = false`, `isSelectable = true`,
  `isFindInteractionEnabled = true`, `adjustsFontForContentSizeCategory = true`, font
  `UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 15, weight: .regular))`,
  `textContainerInset` 16/20, background clear, `alwaysBounceVertical`). Set text once; update only when the file
  changes. Dark mode comes from semantic colours.
- `LaunchArguments`: `-uiTesting` disables animations and uses an in-memory recents persistence (B9), `-openSample
  <name>` opens `Resources/Samples/<name>.md` at launch. `Welcome.md` is a short, friendly document that exercises
  headings, a list, a task list, a table, a code block and a quote (it doubles as the demo and the UI-test fixture).
- Accessibility: the picker is reachable with VoiceOver; the source view exposes its text.

Tests: XCUITest `ReaderTests` (CI only) launches with `-uiTesting -openSample Welcome`, asserts the title
"Welcome", taps `reader.mode.source`, asserts a `UITextView` containing "# Welcome" exists, taps
`reader.mode.rendered`, asserts the heading text exists. Add the mode persistence to a small `ReaderMode` unit test
in `ReaderCore` if you move the enum there (allowed; keep UIKit out of `ReaderCore`).

### B8 Open files from Files, share sheet, picker and drag-drop

Make the app a real Markdown handler. Files: `project.yml` (Info properties), `Packages/MarkdownKit/Sources/ReaderCore/Files/OpenedFile.swift`,
`Files/FileOpener.swift`, `Files/SecurityScope.swift`, `Files/TextDecoding.swift`, `App/mdview/App/AppRouter.swift`,
`App/mdview/mdviewApp.swift`, `App/mdview/Files/FilePicker.swift`, `App/mdview/Files/DropHandling.swift`,
`Tests/ReaderCoreTests/FileOpenerTests.swift`.

- Info properties in `project.yml`: `CFBundleDocumentTypes` with one entry (`CFBundleTypeName: Markdown`,
  `LSHandlerRank: Alternate`, `LSItemContentTypes: [net.daringfireball.markdown]`), `UTImportedTypeDeclarations`
  for `net.daringfireball.markdown` (conforms to `public.plain-text`, extensions `md markdown mdown mkdn mkd
  mdwn`, MIME `text/markdown`, description "Markdown"), `LSSupportsOpeningDocumentsInPlace: true`,
  `UISupportsDocumentBrowser: false`, `UIFileSharingEnabled: true`. Decision D5: add a second
  `CFBundleDocumentTypes` entry (`CFBundleTypeName: Plain Text`, `LSHandlerRank: Alternate`,
  `LSItemContentTypes: [public.plain-text]`) so `.txt` files open in mdview too.
- Plain-text files (D5): `OpenedFile` gains `kind: Kind` (`.markdown`, `.plainText`), set from the extension
  (`txt`, `text` → `.plainText`; Markdown extensions and anything else → `.markdown`). `ReaderView` shows a
  `.plainText` file in `SourceView` only, never parsed as Markdown, and hides the Rendered / Source picker for it
  (the stored `reader.mode` preference is left unchanged).
- `FileOpener.open(url, source)`: `SecurityScope.withAccess(url)` (ignore a `false` return from
  `startAccessingSecurityScopedResource`, which is normal for Inbox and bundled files), read `Data`, reject above
  25 MB with `.tooLarge`, decode via `TextDecoding` (UTF-8 → UTF-16 BOM → ISO Latin-1; normalise CRLF to LF),
  create `bookmarkData()` (no options; iOS bookmarks keep scope implicitly) inside the access window, and if the
  URL is inside `<Documents>/Inbox` move it to `<Documents>/Imported/<name>` (unique suffix on collision) and
  bookmark the new location, setting `inboxCopy = true`. `displayName` = last path component without extension.
- `AppRouter` (`@Observable @MainActor`): `path: [OpenedFile]`, `open(url:source:)` async which calls `FileOpener`,
  records in recents (B9 adds; leave a hook), and replaces the navigation path with the new file; errors surface as
  an alert with the file name and a plain-language reason.
- `mdviewApp`: `WindowGroup { RootView() }.onOpenURL { router.open($0, source: .openURL) }`. `RootView` hosts
  `NavigationStack(path:)` with `ContentView` (B9 swaps in `HomeView`) and `navigationDestination(for: OpenedFile.self)`.
- `FilePicker`: `.fileImporter(isPresented:allowedContentTypes:[UTType("net.daringfireball.markdown")!, .plainText,
  .text], allowsMultipleSelection: false)`; the chosen URL goes through `router.open(source: .picker)`.
- `DropHandling`: `.dropDestination(for: URL.self)` on the root view (iPad drag from Files); dropped URLs go through
  `router.open(source: .drop)`. If the provider only yields a file representation copy, open the copy (images will
  not resolve; that is acceptable).
- Edge cases: opening the same file twice replaces the path instead of stacking; a `.txt` file opens as plain
  source text; a URL with a non-`md` extension but
  text content still opens; an unreadable file shows the alert and does not crash; `onOpenURL` while already
  showing a reader swaps documents; bookmark creation failure is non-fatal (`bookmark = nil`).

Tests (`swift test`, macOS): `FileOpenerTests` using temp directories: UTF-8, UTF-16 with BOM and Latin-1 files
decode; a `.txt` file opens with `kind == .plainText` and a `.md` file with `.markdown`; CRLF normalised; a simulated `Inbox/` file is moved to `Imported/` and `inboxCopy` is true; collision adds a
suffix; a 30 MB file throws `.tooLarge`; a directory URL throws `.unreadable`; `displayName` strips the extension.
Manual verification is impossible for bots; the XCUITest from B7 still passes and `make test` builds the plist
changes (`plutil -lint` the generated Info.plist in `build-ios` output is optional).

### B9 Recents store and home screen

Files: `Sources/ReaderCore/Recents/RecentEntry.swift`, `Recents/RecentsStore.swift`, `Recents/RecentsPersistence.swift`
(`JSONFileRecentsPersistence(url:)` and `InMemoryRecentsPersistence`), `Tests/ReaderCoreTests/RecentsStoreTests.swift`,
`App/mdview/Home/HomeView.swift`, `Home/RecentRow.swift`, `Home/EmptyStateView.swift`; delete `ContentView.swift`
and wire `HomeView` into `RootView`; `App/mdviewUITests/HomeTests.swift`.

- `RecentsStore`: `entries` sorted by `lastOpened` desc, max 50; `record(file:)` creates or updates the entry whose
  bookmark resolves to the same path (compare `standardizedFileURL.path`); `remove`; `resolve(entry)` returns a URL
  from the bookmark, refreshing and re-saving the bookmark when `isStale`, and removes the entry when resolution
  throws (file deleted). `folderHint` = the parent folder's display name (e.g. "iCloud Drive › Notes" is too hard;
  use the last path component of the parent, or "On My iPhone" when under the app container). Persistence writes
  atomically to `Application Support/mdview/recents.json`; corrupt JSON is logged and treated as empty.
  Bundled samples are not recorded.
- `HomeView`: `navigationTitle("mdview")` large title; `List` of `RecentRow` (document icon, display name,
  folder hint + relative date in secondary caption), swipe to remove, tap → `router.open(url, source: .recent)`;
  toolbar: one `Open…` button (`folder` icon, identifier `home.open`) presenting the `FilePicker`. Empty state:
  friendly copy ("Open a Markdown file from Files, the share sheet, or drop one here") plus a secondary button
  "Read the welcome guide" that opens the bundled sample. Pull-to-refresh is not needed. `-uiTesting` uses
  `InMemoryRecentsPersistence` seeded empty.
- Obsidian setting (D6): a second, small toolbar button on `HomeView` only (`gearshape` icon, identifier
  `home.settings`) opens `SettingsSheet` (`App/mdview/Settings/SettingsSheet.swift`): a `.medium`-detent sheet with
  one `Toggle("Obsidian extras", ...)` (identifier `settings.obsidian`) bound to
  `@AppStorage("obsidian.enabled") var obsidianEnabled = true`, a one-line footer ("Front matter, [[wikilinks]],
  embeds and callouts") and a Done button. Nothing else goes in the sheet. `ReaderModel` reads the same key and
  passes it as `MarkdownParser.Options(obsidian:)`; when the value changes it re-parses the open document. The
  reader toolbar stays one control (the Rendered / Source picker). `-uiTesting` resets the key to `true`.
- Privacy manifest note for B13: resolving bookmarks and reading modification dates uses file-timestamp APIs; the
  reason code is recorded there, not here.

Tests: `RecentsStoreTests` on macOS with temp files: record/upsert/dedupe, cap at 50, remove, stale bookmark refresh
(move the file, resolve again), deleted file drops the entry, corrupt JSON → empty, atomic save round trip.
XCUITest `HomeTests` (CI): launch with `-uiTesting`, assert `home.open` and the empty-state button exist, tap "Read
the welcome guide", assert the reader title "Welcome", go back, assert the list is still empty (samples are not
recorded); tap `home.settings`, assert `settings.obsidian` exists and is on, toggle it off, dismiss.

### B10 Relative images, folder access and relative links

Files: `Sources/ReaderCore/Images/FileImageLoader.swift`, `Sources/ReaderCore/Images/FolderAccessStore.swift`,
`Tests/ReaderCoreTests/FileImageLoaderTests.swift`, `App/mdview/Files/FolderAccessPrompt.swift`, edits in
`ReaderView` and `AppRouter`.

- `FileImageLoader(baseURL: file.url.deletingLastPathComponent(), folderAccess:)`: `source` parsing: `http(s)://`
  → `.remote(url)`; `data:` URIs → decode base64 → `.data`; absolute `file://` or paths starting with `/` → treat as
  relative to the base anyway (vault exports); otherwise percent-decode and resolve relative to `baseURL`, also
  trying `<base>/attachments/<name>` and `<base>/assets/<name>` for bare file names (Obsidian default attachment
  folders). Reading: if `folderAccess.folderCovering(url)` exists, read inside that folder's security scope; else
  try reading directly inside the file's own scope; on permission failure return `.needsFolderAccess(folder:
  baseURL)`; on not-found return `.missing`. Only `png jpg jpeg gif heic webp svg(as missing, unsupported) bmp tiff`
  are attempted; others `.missing`. Decoding to an image happens in the view (B6); the loader returns `Data`.
- `FolderAccessStore`: granted folder bookmarks persisted like recents (`folder-access.json`), `grant(url)` stores
  the bookmark, `folderCovering(url)` returns the deepest granted folder whose path is a prefix.
- App wiring: `ReaderView` sets `\.imageLoader` to a `FileImageLoader` for the current file and
  `\.requestFolderAccess` to present `fileImporter(allowedContentTypes: [.folder])` preselected at the file's
  folder; on success `FolderAccessStore.grant` and bump a `reloadToken` so images retry. Relative `.md` links
  (`onOpenRelative` from B7) resolve against the base URL and open through `router.open(source: .recent)`; if
  unreadable, show the standard alert.
- Edge cases: `inboxCopy` files have no siblings; skip the folder prompt and show `.missing` with a tooltip-style
  caption "Images are not included when a file is shared as a copy". Case-insensitive file systems: try exact
  name first, then a case-insensitive directory scan when the folder is readable and has fewer than 2 000 entries.

Tests (macOS): temp folder with `note.md`, `img/a.png`, `attachments/b.png`; loader returns `.data` for `img/a.png`,
`b.png` (attachment fallback), `.missing` for `nope.png`, `.remote` for `https://…`, `.data` for a base64 `data:`
URI; `FolderAccessStore.folderCovering` picks the deepest grant; percent-encoded names resolve. Permission-denied
behaviour cannot be simulated on macOS without sandboxing, so unit-test the decision function
(`classify(error:)`) directly.

### B11 Typography, dark mode and Dynamic Type polish

Files: `Theme/MarkdownTheme.swift` tuning, `Previews/PreviewDocuments.swift`, new fixtures
`Tests/Fixtures/code-languages.md` (6 languages) and `Tests/Fixtures/tables.md` (wide and narrow tables),
`docs/DEVELOPMENT.md` (a short "Visual checks" section). Snapshot tests are **deferred** (decision D8): no snapshot
target, no `swift-snapshot-testing` dependency, no snapshot CI job or recording flow in this plan.

- Visual pass against section 3.5 using the previews: heading rhythm, list indentation at three depths, quote and
  callout styling, inline code chip, code block padding and language label, table rules, figure captions, link
  colour (accent) in both schemes, selection colours, iPad measure centering, landscape iPhone. Verify Dynamic Type
  at `.xSmall`, `.large`, `.accessibility3`: nothing truncates, tables and code scroll instead of clipping,
  `@ScaledMetric` drives indents and bars.
- Previews for `gfm-kitchen-sink.md`, `obsidian-note.md`, `code-languages.md` and `tables.md` in light and dark, and
  the kitchen sink at `.xSmall` and `.accessibility3`, so the visual pass can be repeated by hand in Xcode.
- Note in the bead report what was tuned and any visual issue left for later.

Tests: `swift test` keeps passing (theme unit tests updated if constants moved; the new fixtures parse without
error); `make test` builds. No snapshot tests.

### B12 Find in page

Files: `Sources/MarkdownModel/Search/DocumentSearch.swift`, `Tests/MarkdownModelTests/SearchTests.swift`,
`App/mdview/Reader/Find/FindState.swift`, `Reader/Find/FindBar.swift`, edits to `ReaderView`, `ReaderModel`,
`App/mdviewUITests/FindTests.swift`.

- `DocumentSearch(document)`: precompute `[(RunID, String)]` text runs in document order using `InlineText.flatten`
  for headings, paragraphs, list item blocks (recursively), quote children, table cells (each cell its own run),
  code blocks (the code string), html blocks (raw). `matches(for:)` returns all non-overlapping matches, case- and
  diacritic-insensitive (`range(of:options:[.caseInsensitive, .diacriticInsensitive])`), as utf16 ranges; empty or
  whitespace-only query → `[]`. Cache nothing across documents.
- Rendered mode UI: `.searchable(text:isPresented:placement: .navigationBarDrawer(displayMode: .automatic),
  prompt: "Find in document")` on `ReaderView` so the bar is hidden until pull-down (keeps the one visible
  control). While the query is non-empty, a bottom `FindBar` shows "n of N" with up/down chevrons (identifiers
  `find.count`, `find.next`, `find.previous`), wraps around, and the current match is passed as `currentHighlight`
  plus `scrollTarget = match.run.block`. Debounce query changes by 150 ms; search runs off the main actor for
  documents above 200 KB.
- Source mode: forward the query to `UITextView`'s `findInteraction` (`presentFindNavigator(showingReplace:
  false)`) when the searchable field is activated, or at minimum keep the native find available via the text view's
  edit menu and ⌘F on iPad; document which.
- Highlight styling: `theme.highlight` yellow at 35 % (light) / 45 % (dark), current match `theme.currentHighlight`
  orange; both pass through `InlineRenderer` and `CodeBlockView` (code blocks highlight by utf16 range on the code
  string) and `TableView` cells.

Tests: `SearchTests`: matches across every block kind in the kitchen sink, case/diacritic insensitivity, no
overlap for repeated patterns (`aaa` in `aaaa` → one match at 0..<3 then none), table cell `RunID.cell` set, empty
query. `MarkdownViewsTests`: highlight range applied inside a code block and a table cell. XCUITest `FindTests`
(CI): pull down on the Welcome document, type "table", assert `find.count` reads "1 of N" with N ≥ 1, tap next,
assert the count changed.

### B13 Release preparation: icon, privacy manifest, release docs

Files: `App/mdview/Assets.xcassets/AppIcon.appiconset/` (single 1024×1024 PNG, generated by a script under
`scripts/make-icon.swift` or Python with Pillow if present: a rounded "M" glyph or `#` on an accent background;
commit the PNG and the script), `App/mdview/PrivacyInfo.xcprivacy`, `project.yml` (ensure the manifest is a
resource of `mdview`, set `CFBundleDisplayName: mdview`, `MARKETING_VERSION: 0.1.0`, `CURRENT_PROJECT_VERSION: 1`,
and `ITSAppUsesNonExemptEncryption: NO` if B1 did not), `docs/RELEASE.md`, `Config/Local.xcconfig.example` check.

- `PrivacyInfo.xcprivacy`: `NSPrivacyTracking: false`, empty `NSPrivacyTrackingDomains`, empty
  `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes` with `NSPrivacyAccessedAPICategoryUserDefaults`
  reason `CA92.1` (reader mode and the Obsidian setting) and `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1` (recents and
  bookmarks). Validate with `plutil -lint`.
- `docs/RELEASE.md`, written for keving as a checklist he performs by hand (bots never do these):
  1. Apple Developer account: a free Apple ID installs on a personal device for 7 days at a time; the paid Apple
     Developer Program is required for TestFlight and 1-year personal signing.
  2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill the empty `DEVELOPMENT_TEAM` with the
     10-character Team ID from developer.apple.com → Membership; keep the bundle id `us.par72.mdview`.
  3. `make open`; in Xcode select the `mdview` target → Signing & Capabilities → Automatically manage signing, pick
     the team. Connect the iPhone, enable Developer Mode on the phone (Settings → Privacy & Security), trust the
     Mac, pick the device as run destination, Run. First run: on the phone trust the developer certificate under
     Settings → General → VPN & Device Management (free accounts only).
  4. TestFlight: App Store Connect → Apps → + → New App (platform iOS, bundle id from step 2, SKU `mdview`);
     Xcode → Product → Archive (Any iOS Device) → Distribute App → TestFlight & App Store → Upload; in App Store
     Connect → TestFlight add yourself as an internal tester; install from the TestFlight app. Export compliance is
     pre-answered by `ITSAppUsesNonExemptEncryption = NO`. Builds expire after 90 days; re-archive to refresh.
  5. Optional later: automated TestFlight uploads from CI need an App Store Connect API key stored as repository
     secrets and a fastlane or `xcodebuild -exportArchive` lane; not part of this plan.
  Also list what to verify on the device: open a file from Files, share a file from Obsidian or Mail to mdview,
  drag a file onto the app on iPad, dark mode, a large text size, a note with images in the same folder (grant
  folder access when prompted).
- `README.md` (B13 owns the user-facing rewrite; B14 only adds to it): short description, screenshot placeholder,
  features (including `.txt` files shown as plain text), "fully local" statement, a License section (MIT, see
  `LICENSE`), links to `docs/RELEASE.md` and `docs/DEVELOPMENT.md`. Keep the CI badge from B2.

Tests: `plutil -lint App/mdview/PrivacyInfo.xcprivacy` passes; `make test` (device build) succeeds with the icon
and manifest; the icon PNG is exactly 1024×1024 (check with `sips -g pixelWidth -g pixelHeight`).

### B14 Final docs, architecture notes and end-to-end review

Files: `docs/ARCHITECTURE.md`, updates to `docs/DEVELOPMENT.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`; small code
fixes allowed anywhere when the review finds them. B14 depends on B13 and starts from B13's `README.md`: it only adds
a link to `docs/ARCHITECTURE.md` and corrects facts the review finds, it does not rewrite the README.

- `docs/ARCHITECTURE.md`: the layout from section 3.1, the module dependency graph, the data flow from 3.3, the
  decision table from 3.4 (updated with anything that changed during implementation, including the swift-markdown
  version and the Swift language mode per target), the text-rule invariant, the no-networking lint rule, the
  Obsidian setting (D6), the CI flow, and a "Deferred" note that snapshot tests come after the prototype (D8).
- End-to-end review checklist, each item verified by a command or a CI artifact and recorded in the bead notes:
  `make lint`, `make test`, CI green on the branch (`gh run list`), XCUITests cover launch, home, reader toggle,
  find and the Obsidian setting; `grep -rn "URLSession\|WKWebView" App Packages` returns nothing outside tests;
  `Package.resolved` pins exactly swift-markdown (+ its cmark dependency) and nothing else; Info.plist contains the
  document types, in-place opening and no multi-scene; `PrivacyInfo.xcprivacy` present; accessibility
  identifiers listed in `docs/DEVELOPMENT.md` for future UI tests.
- Measure and record (CI log or `swift test` output): parse time for the 500 KB fixture, tokenizer time for the
  10 000-line fixture. Add to `ARCHITECTURE.md` under "Performance baselines".
- Open follow-up beads via notes in the final report (not in `.beads/`): anything found but not fixed.

### B15 Sign, install on iPhone and ship to TestFlight (human)

keving performs `docs/RELEASE.md` steps 1–4 on his Mac: fills the unset `DEVELOPMENT_TEAM` into `Config/Local.xcconfig`, personal install
via Xcode on his iPhone, then App Store Connect app record, archive, upload, TestFlight internal test. He verifies
the device checklist from B13 and reports back: what worked, what did not (file a bead per defect). No bot action;
the runner stops here.

## 6. Quality gate

After every bead (the runner runs these from the repo root; B1 creates them, so they first apply after B1):

```bash
make lint      # swiftformat --lint + swiftlint --strict (includes the no-networking rule)
make test      # swift test for Packages/MarkdownKit on macOS, then xcodebuild build for generic/platform=iOS with signing off
```

Rules: never run `make test-ios`, `xcodebuild test`, `xcrun simctl`, or any simulator locally; simulator tests run in
GitHub Actions on push, and beads that add UI tests confirm them with `gh run watch` / `gh run list`.
`make test` must finish without a `DEVELOPMENT_TEAM` and without network access beyond SwiftPM fetching the pinned
packages on first build.

## 7. Decisions (Oct 25, 2026)

The planner's ten open questions are closed. keving reviewed every decision on Oct 25, 2026: he confirmed D1, D2,
D3, D4, D5, D7, D9 and D10, and changed D6 (add a setting) and D8 (defer snapshot tests). Grok Bot had proposed the
first answers to D2, D3 and D5–D10 with his go-ahead; all ten are now keving's.

| # | Question | Decision | Decided by | Beads affected |
|---|---|---|---|---|
| D1 | Repo visibility and CI minutes | **Public, MIT license.** `LICENSE` (MIT, copyright 2026 Kevin Gould / Par72 Labs, LLC) is committed on the plan branch. Before the visibility flip, `gitleaks detect` ran over the full history of all branches. macOS Actions minutes are free on a public repo. | keving (confirmed Oct 25, 2026) | B2 (CI cost text), B13 (README License section) |
| D2 | Remote images | **Open in Safari on tap; never loaded inline.** The app process makes no network request (keeps the no-network promise and the `no_networking` lint rule). | Confirmed by keving, Oct 25, 2026 | none (B6/B10 already do this) |
| D3 | Bundle id and team | **`us.par72.mdview`.** `DEVELOPMENT_TEAM` stays an unset build setting (empty in `Config/Local.xcconfig.example`); keving fills it in at B15. Bots never look up or store Apple account details. | Confirmed by keving, Oct 25, 2026 | B1, B13, B15 |
| D4 | Body typeface | **System SF font** (default), no setting. | Confirmed by keving, Oct 25, 2026 | none |
| D5 | Plain-text files | **Open `.txt` files too**, registered as an Alternate handler for `public.plain-text` and shown as plain source text (Source view only, no toggle, never parsed as Markdown). | Confirmed by keving, Oct 25, 2026 | B8 |
| D6 | Obsidian conveniences | **On by default, with one user setting to turn them off.** Covers front matter, wikilinks, embeds and callouts. Stored with `@AppStorage("obsidian.enabled")` (default `true`). Kept minimal: a small gear button on the home screen opens a one-toggle settings sheet; the reader toolbar keeps its single control. | keving's call (changed Oct 25, 2026) | B3 (`obsidian: false` path), B9 (settings sheet and wiring), B13 (privacy reason), B14 |
| D7 | CI provider | **GitHub Actions** (macOS runners free on public repos). | Confirmed by keving, Oct 25, 2026 | B2 |
| D8 | Snapshot tests | **Deferred.** No snapshot tests, no `swift-snapshot-testing` dependency and no snapshot CI job or recording flow for now. Add them back after a working prototype exists. | keving's call (changed Oct 25, 2026) | B2, B11, B14 (and sections 2–4) |
| D9 | Swift language mode | **Swift 6 with strict concurrency**; per-target fallback to 5 only if a dependency forces it, recorded in `docs/ARCHITECTURE.md`. | Confirmed by keving, Oct 25, 2026 | none |
| D10 | Find-in-page placement | **Pull-down search bar** (SwiftUI `.searchable`, navigation-bar drawer) plus a bottom count bar only while searching; no magnifier button. | Confirmed by keving, Oct 25, 2026 | none (B12 already does this) |

### Deferred

- **Snapshot tests (D8).** After a working prototype (B15 done), a follow-up bead adds an `mdviewSnapshotTests`
  target with `pointfreeco/swift-snapshot-testing` (test-only), reference images recorded in CI (never locally), and
  a `workflow_dispatch` recording flow. If they prove flaky, they go into a non-blocking CI job rather than being
  deleted. Not part of this plan's beads.

Plan fix: B13 and B14 both edit `README.md`. B14 depends on B13 (also in bd), B13 owns the README rewrite, and B14
only adds to it.
