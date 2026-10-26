# mdview polish, accessibility, "open from anywhere", and reader features

Feature slug: `mdview-polish`. Base branch: `main`. Companion file: `beads.json` (same directory). Planned Oct 26, 2026.

The plan has two phases with a human stop between them:

- **Launch (0.1.0 build 2, App Store launch Tue Nov 10, 2026):** beads L1 to L12. Accessibility fixes, task lists, every Markdown extension declared, a "How to Open Files" guide, and Paste Markdown. L12 is a human bead: device check, merge, upload. The runner stops there.
- **v0.2 (0.2.0):** beads V1 to V11. The "View in mdview" Action extension and the reader features. V11 is the human ship bead.

Everything below **Deferred** in section 3.8 is not a bead.

## 1. Goal and non-goals

**Goal.** Make mdview launch-ready (accessible, honest App Store copy, task lists that render), give keving a working way to open a Markdown file a chat app sends him, then add a small set of reader features. All of it stays offline, collects nothing, and is built on Apple frameworks plus the already-shipped Textual 0.5.0.

**Non-goals.** Editing Markdown, sync, accounts, analytics, ads, a Mac app, network access of any kind (section 3.6), new Swift package dependencies (none are needed; section 3.7), a custom Markdown renderer, Mermaid, a folder/vault browser, Spotlight, widgets, Handoff.

## 2. Current state

What exists on `main` (v0.1.0 build 1, uploaded to App Store Connect):

| Area | File | Notes |
| --- | --- | --- |
| Scene | `App/mdview/mdviewApp.swift` | `DocumentGroup(viewing: TextDocument.self)`. No launch-scene customization. |
| Document | `App/mdview/TextDocument.swift` | Read-only `FileDocument` for `net.daringfireball.markdown` and `public.plain-text`. `init(text:contentType:)` exists only in DEBUG. |
| Reader | `App/mdview/Reader/ReaderView.swift` | Rendered / Source picker in the bottom bar, reader menu (Obsidian toggle), `.searchable` find. Markdown detection hard-codes `md`, `markdown`, `mdown` in `showsModePicker`. |
| Rendering | `App/mdview/Reader/RenderedView.swift` | Textual `StructuredText` with `.structuredTextStyle(.gitHub)`, `.textSelection(.enabled)`, `LocalImageLoader`, 680 pt column. Runs `ObsidianPreprocessor` then `RemoteImages.linkify`. |
| Source / find | `App/mdview/Reader/SourceView.swift` | `UITextView`. Matches: yellow at 35% alpha; current match: solid `systemYellow` with black text. Color is the only difference. |
| Images | `App/mdview/Reader/LocalImageLoader.swift` | Textual `AttachmentLoader`, local files only via `MDCore.ImagePolicy`. |
| Screenshot harness | `App/mdview/ScreenshotLaunch.swift` (DEBUG) | Opens a reader over the document browser from `MDVIEW_SCREENSHOT_NAME` / `MDVIEW_SCREENSHOT_MARKDOWN` env. UI tests reuse this to open a document without driving the browser. |
| Accent | `App/mdview/Assets.xcassets/AccentColor.colorset/Contents.json` | One universal color, #2E6B4A. 2.69:1 on #1C1C1E (dark bars). |
| Info.plist | `App/mdview/Info.plist` | Markdown doc type `LSHandlerRank Owner`, plain text `Alternate`, imported UTI with `md`, `markdown`, `mdown`, MIME `text/markdown`, `LSSupportsOpeningDocumentsInPlace` YES, `UISupportsDocumentBrowser` YES, multiple scenes YES. No `UIFileSharingEnabled`. |
| Logic | `Packages/MDCore` | Foundation only, `swift test` on the Mac: `TextDecoding`, `RemoteImages`, `ImagePolicy`, `ObsidianPreprocessor`, `TextSearch`. |
| UI tests | `App/mdviewUITests/` | `LaunchTests` (CI) and `ScreenshotTests` (skipped unless `scripts/screenshots.sh`). `make test` does **not** compile this target today: the scheme builds it for testing only. |
| Gate | `Makefile`, `.swiftlint.yml` | `make test` = `swift test` MDCore + unsigned `generic/platform=iOS` build. `make lint` = swiftformat + swiftlint strict with the `no_networking` rule. `make test-ios` only in CI (Xcode 26.6, iOS 26 simulator). |
| Docs | `docs/app-store/listing.md`, `docs/RELEASE.md`, `docs/support.md`, `docs/privacy.md`, `README.md`, `docs/ARCHITECTURE.md` | The listing in this repo still says "task lists" in the description although they render as plain text, and claims iPad drag and drop, which `docs/RELEASE.md` has not checked off. There are no localized listings in the repo. |

What Textual 0.5.0 gives us (read from its source at tag 0.5.0):

- No accessibility code at all: no header traits, no list semantics, no table semantics.
- Every block style is pluggable and public: `HeadingStyle`, `ListItemStyle`, `UnorderedListMarker`, `OrderedListMarker`, `TableStyle`, `TableCellStyle` (its configuration has `row` and `column`), `CodeBlockStyle` (its configuration has `codeBlock: CodeBlockProxy` with `copyToPasteboard()` and `languageHint`). A whole set is bundled with `StructuredText.Style`.
- `Overflow { }` is the public horizontal-scroll container. Textual says to use it instead of a bare horizontal `ScrollView`, which breaks text selection. `GitHubTableStyle` does not use it, so wide tables wrap and crush. `GitHubCodeBlockStyle` does.
- Each heading view gets `.id(slug)`, where slug = the heading's characters, lowercased, whitespace to `-`, keep letters, digits and `-`, collapse repeated `-`. `ScrollViewReader.scrollTo(slug)` can target it.
- Parsing is Foundation's `AttributedString(markdown:)` with default options. It has no task-list support (`- [ ] x` stays literal text). Custom `SyntaxExtension`s cannot be written outside Textual (the initializer is internal). Only `.emoji` and `.math` exist; `.math` matches `$$…$$` and `$…$`.
- `.textual.textSelection(.disabled)` is available (SwiftUI's `DisabledTextSelectability`).
- Textual is extension-safe (no `UIApplication`). Its only `URLSession` is the URL image loader mdview never installs.

## 3. Design

### 3.1 How a user opens a Markdown file shared from a chat app

iOS has no user-selectable default app for a file type. Which path works depends on what the chat app (Grok Bot, Messages, Slack, Mail) does with the attachment. The table is the answer for keving and for the help screen.

| # | What the user does | Works when the host app… | mdview controls | Phase |
| --- | --- | --- | --- | --- |
| 1 | Tap the attachment, tap Share, tap **mdview** in the app row | shares the attachment as a **file** whose name ends in a Markdown or text extension (or whose type is `net.daringfireball.markdown` / `public.plain-text`) | Document types and imported UTI (L7). mdview opens it in place or iOS copies it to `Documents/Inbox`. | Launch (exists today; L7 widens it, L12 verifies) |
| 2 | Share, then **View in mdview** in the action list | shares **text** (a message body) or a text/Markdown file | The Action extension renders it in place, Rendered and Source (V2) | v0.2 |
| 3 | Copy the message, open mdview, tap **Paste Markdown** | lets the user copy text (almost every app) | Everything (L9). `PasteButton` shows no paste prompt. | Launch |
| 4 | Save to Files, then open in mdview (browser or Recents) | offers Save to Files | Document types (L7) | Launch (exists) |
| 5 | Tap the attachment and get a rendered preview inside the chat app | previews with `QLPreviewController` **and** the device runs iOS 26 or earlier | A Quick Look preview extension would. On iOS 27, Quick Look no longer calls third-party extensions for `net.daringfireball.markdown` and shows plain text (Apple forums thread 843292, FB24481377, Aug 2026). From that preview, Share → mdview (path 1) still works. | Deferred (3.8) |
| 6 | Tap a link | turns custom-scheme or https links into tappable links, and the content is reachable | URL scheme / Universal Links. Needs either network (raw GitHub URLs) or a payload inside the link. | Deferred, owner decision (3.6) |

**Fully mdview-controlled:** path 3 always works, path 2 works wherever a share sheet exists, and the in-app reader. **Host-dependent:** path 1 (the host must share a file, not text, and keep the extension), path 5 (the host must use Quick Look, and the OS must call the extension), path 6 (the host must linkify).

**Grok Bot specifically.** Nobody can check from this repo whether Grok Bot's attachment viewer offers Share or uses Quick Look. L12 has keving try paths 1 to 4 on his phone and record the result in `docs/support.md`. keving runs the bot, so the strongest lever is on the bot side: send Markdown as a **file attachment named `*.md` with MIME `text/markdown`**, not as inline text. Then path 1 works in any host that has a share sheet. That change is outside this repo; see open question Q2.

### 3.2 Components and contracts

New and changed pieces, by phase. Names here are the contracts later beads rely on; do not rename them.

**MDCore (Foundation only, `swift test`):**

| Type | Contract | Bead |
| --- | --- | --- |
| `MarkdownFileTypes` | `static let markdownExtensions: [String]` = `md, markdown, mdown, mkd, mkdn, mdwn, mdtxt, mdtext`; `static let plainTextExtensions` = `txt, text`; `static let markdownMIMETypes` = `text/markdown, text/x-markdown`; `static func isMarkdown(pathExtension:) -> Bool?` (true, false, or nil for unknown). Literals sit between `// BEGIN markdownExtensions` / `// END markdownExtensions` markers so `scripts/check_app_config.py` can compare them with `Info.plist`. | L7 |
| `TaskListPreprocessor` | `static func process(_ markdown: String) -> String`. Rewrites a list item's leading `[ ]` / `[x]` / `[X]` into `![Not done](x-mdview-task:unchecked)` / `![Done](x-mdview-task:checked)`. Skips fenced and indented code. | L6 |
| `RenderPipeline` | `static func prepare(_ markdown: String, obsidian: Bool, math: Bool = false) -> String`. Order: `ObsidianPreprocessor` (if on), `TaskListPreprocessor`, `MathDelimiters` (if on, V8), `RemoteImages.linkify`. The Rendered view, the outline, PDF export and the Action extension all call this and nothing else. | L6 |
| `TaskMarker` | `static let scheme = "x-mdview-task"`; `enum State { case checked, unchecked }`; `static func state(for url: URL) -> State?`. | L6 |
| `FindHighlight` | `static func styles(matchCount: Int, current: Int?, differentiateWithoutColor: Bool) -> [MatchStyle]`, `MatchStyle { fill: .soft/.strong, underline: .none/.dotted/.thick, bold: Bool }`. | L5 |
| `HeadingOutline` | `static func headings(in markdown: String) -> [OutlineHeading]` with `level`, `title`, `slug`, `occurrence`. Parses with Foundation `AttributedString(markdown:)` (the same parser and default options as Textual), so titles match what Textual renders. `static func slug(_ title: String) -> String` reproduces Textual's `slugified()` exactly. | V3 |
| `SharedContent` | Pure decisions for the Action extension: title and Markdown-or-plain from a suggested file name; byte cap (5 MB) and the message when it is exceeded. | V2 |
| `ReadingPositionStore` | Per-file scroll fraction in a `[String: Double]` dictionary behind an injected storage protocol, keyed by SHA-256 of the standardized path, LRU-capped at 200 entries. | V6 |
| `PageSlicer` | Splits a content height into page rects for PDF export. | V7 |
| `MathDelimiters` | `\(…\)` → `$…$`, `\[…\]` → `$$…$$` outside code. Only runs when math is on. | V8 |

**App target:**

| Piece | Contract | Bead |
| --- | --- | --- |
| `ReaderStyle: StructuredText.Style` (`App/mdview/Reader/ReaderStyle.swift`) | The single style the app applies. GitHub look, plus: `AccessibleHeadingStyle` (`.isHeader`, `.accessibilityHeading(level)`; no identifiers, since the configuration has no text, so UI tests find headings by label), `AccessibleListItemStyle` (marker plus content read as one element), `QuietBulletMarker` (GitHub's hierarchical disc/circle/square, hidden from VoiceOver), ordered numbers kept, `ScrollingTableStyle` (GitHub table inside `Overflow`), `AccessibleTableCellStyle` (header trait on row 0, "Row r, column c" custom content), later `CopyableCodeBlockStyle` (V4). | L3, L4, V4 |
| `TaskCheckbox: Attachment` | SF Symbol `square` / `checkmark.square.fill`, about 1 em, `accessibilityLabel` "Done" / "Not done", `description` `[x]` / `[ ]` so copied text stays Markdown-like. Returned by `LocalImageLoader` for `x-mdview-task:` URLs **before** `ImagePolicy` runs. `ImagePolicy` itself stays file-only. | L6 |
| `Motion` (`App/mdview/Motion.swift`) | `Motion.animate(_ reduceMotion: Bool, _ body: () -> Void)`. A swiftlint custom rule bans `withAnimation(` everywhere else. | L5 |
| `ReaderContext` environment | Replaces the DEBUG-only `screenshotFileURL`: `fileURL: URL?`, `displayName: String?`. The paste reader, screenshot harness and Action extension set it. | L9 |
| Launch scene | `DocumentGroupLaunchScene` (iOS 18) with "How to Open Files" and "Paste Markdown" actions. | L8, L9 |
| `OpenFilesHelpView` | Static help listing only the shipped paths of 3.1. Reachable from the launch scene and the reader menu. | L8 |
| `App/Shared/` | Reader code compiled into the app **and** the Action extension (V1). | V1 |
| `mdviewAction` target | `us.par72.mdview.action`, `com.apple.ui-services`, full-screen, renders with the shared reader. | V2 |

**Tooling:**

| Piece | Contract | Bead |
| --- | --- | --- |
| `make build-tests` | `xcodebuild build-for-testing -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. `make test` runs it instead of `build-ios`, so UI test code compiles in the local gate without a simulator. | L1 |
| `scripts/check_app_config.py` | Python stdlib only, run by `make lint`, with `--self-test`. Checks: no team ID in tracked files, every bundle ID starts with `us.par72.mdview`, privacy manifests say no tracking and no collected data, no `TRUEPREDICATE` activation rules, the Markdown extension list in `Info.plist` matches `MarkdownFileTypes`, accent-color contrast (L2), and each extension has a `PrivacyInfo.xcprivacy` (V2). | L1, L2, L7, V2 |
| `ReaderLauncher` (UI tests) | Launches the app straight into a reader with a named fixture through the existing DEBUG harness env. Has `light`/`dark`, content-size and find-query options. `ReaderFixture.kitchenSink` covers H1 to H3, nested bullets, an ordered list, task items, a 7-column table, a fenced Swift block, a block quote and a long file name. | L1 |

### 3.3 Data flow

```
file / pasted text / shared item
  └─ TextDecoding.decode (bytes → String)
       ├─ Source: SourceView(text, FindHighlight styles)          ← original text, never preprocessed
       └─ Rendered: RenderPipeline.prepare(text, obsidian:, math:)
              ├─ StructuredText(markdown:) + ReaderStyle + LocalImageLoader(TaskCheckbox first, then ImagePolicy)
              ├─ HeadingOutline.headings(in:) → OutlineSheet → ScrollViewReader.scrollTo(slug)
              └─ PDF export: ImageRenderer(RenderedView without selection) → PageSlicer → PDF data
```

### 3.4 Key decisions (and what was rejected)

| # | Decision | Rejected alternative and why |
| --- | --- | --- |
| K1 | Accessibility is added **around** Textual through public styles (`ReaderStyle`), not by forking Textual. | Forking Textual or a different renderer: more code to own, against D11 ("off the shelf"). |
| K2 | Task lists: an MDCore preprocessor turns markers into image references with a private scheme, and the existing attachment loader returns a `TaskCheckbox` view. Public API only, keeps a real VoiceOver label. | Unicode ☐/☑ substitution: simplest, but VoiceOver reads "ballot box" and the glyphs don't follow the accent color. Kept as the fallback if attachments misalign (L6). A Textual `SyntaxExtension`: not possible from outside the package. |
| K3 | While VoiceOver is running, the Rendered view turns Textual's selection overlay off (`.textSelection(.disabled)`). VoiceOver users still get text navigation, and Source stays selectable. | Leaving the overlay on: its `UITextInteractionView` covers the whole document and sets no accessibility properties, which is the audit's open question. L10 and L12 check the result. |
| K4 | `LSHandlerRank` **Default** for Markdown, **Alternate** for plain text. Import `net.daringfireball.markdown`, never export it. | `Owner`: claims mdview creates the type. Exporting: the UTI belongs to Gruber, and iOS 27 already resolves it. Rank has no visible effect on iOS, so this is a correctness fix only. |
| K5 | `UIFileSharingEnabled` YES, so "Copy to mdview" files (in `Documents/Inbox`) show in Files under On My iPhone › mdview. | Leaving it off: copied files are reachable only through Recents. |
| K6 | Clipboard uses SwiftUI `PasteButton` (no "Allow Paste" alert) and opens an in-memory reader in a full-screen cover. "Save to Files" uses `.fileExporter`. | Reading `UIPasteboard` on launch: privacy prompt and surprise. Writing every paste into Documents: clutter. |
| K7 | Share-sheet entry is an **Action** extension with UI ("View in mdview") that renders in place. It does not try to open the containing app. | A Share extension: Apple positions those for posting content. Opening the app from an extension: there is no supported API (`extensionContext.open` is only for widgets and iMessage), and responder-chain hacks risk rejection. An App Group to hand the file to the app: new capability and entitlement for little gain. |
| K8 | Shared reader code lives in `App/Shared/` and is compiled into each target that needs it. Each target links Textual and MDCore statically. | An embedded framework: `APPLICATION_EXTENSION_API_ONLY`, rpaths, and duplicate-symbol risk with static SwiftPM products in both app and framework. More moving parts for a two-target app. |
| K9 | No Quick Look extension for now (3.8). | Building it: the iOS 27 regression means it would not run on keving's current OS, and it would add a third bundle ID and review surface. |
| K10 | No network. No `mdview://open?url=`. | A user-confirmed one-time fetch: needs `URLSession` (lint ban), changes the privacy story and App Review answers, and adds a server dependency for something paths 1 to 3 already cover. Open question Q1. |
| K11 | Launch build stays **0.1.0**, build **2**. v0.2 ships as **0.2.0** build 3 (build numbers stay increasing). | Bumping to 0.1.1 before launch: no user has 0.1.0 yet, so it would only add noise. |
| K12 | No new Swift package dependencies. | Every reader feature here is covered by Apple frameworks (ImageRenderer, UIPrintInteractionController, CryptoKit, PasteButton) plus Textual and swiftui-math, which already ship. |

### 3.5 Accessibility conventions (every bead)

- Every interactive control has an accessibility label and identifier (`reader.*`, `launch.*`, `help.*`, `outline.*`, `action.*`).
- Bars scale up to the largest accessibility size or use the Large Content Viewer (`.accessibilityShowsLargeContentViewer()`). Nothing truncates without a full-text label.
- Color is never the only signal (find, task boxes, copy confirmation).
- No `withAnimation` outside `Motion` (lint rule from L5). Scroll jumps are not animated when Reduce Motion is on.
- New UI gets a CI-only UI test plus a `performAccessibilityAudit()` call (pattern from L10).

### 3.6 Network and privacy

The default holds: **no network**. Nothing in this plan adds `URLSession` or any other networking. The privacy label stays **Data Not Collected**.

New on-device state: v0.2 adds `UserDefaults` keys (`reader.textScale`, `reader.width`, `reader.fontDesign`, `reader.positions`, `reader.math`). These are covered by the existing required-reason entry `CA92.1` and listed in `docs/privacy.md` and the README by the bead that adds them. The Action extension ships its own `PrivacyInfo.xcprivacy`. `ITSAppUsesNonExemptEncryption` stays NO: SHA-256 hashing for a dictionary key is exempt.

If keving wants path 6 later (Q1), there are two options without in-app networking:

- (a) `mdview://view?md=<base64url>` with the Markdown inside the link. Works only if the host linkifies custom schemes, and links get long.
- (b) Universal Links on `khgouldy.github.io`. The iOS system fetches the association file, not the app, so the app still makes no request. This needs the Associated Domains capability and an `apple-app-site-association` file at the **root** of `khgouldy.github.io`, which means a user-site repo, because the project site lives at `/mdview/`.

A raw-URL fetch (`mdview://open?url=`) is the only option that changes the privacy story: the app would need a network exception to the lint rule, the App Store privacy answers become "the app connects to servers you choose", and the listing's "never connects" line goes away.

### 3.7 Dependencies

No new packages. `THIRD_PARTY_NOTICES.md` changes only if V8 turns on Textual's math syntax (swiftui-math already ships and is MIT). Prism.js, Textual, swiftui-math and swift-concurrency-extras are all MIT.

### 3.8 Recommended feature sets

Ranked by value and effort. Effort is in beads.

| Feature | Value | Effort | Set |
| --- | --- | --- | --- |
| VoiceOver headings, lists, tables; contrast; Differentiate Without Color; accessibility sizes | Launch blocker (accessibility, review) | 4 S/M | Launch |
| Task-list checkboxes | High: chat and agent output is full of checklists; needed so the listing's claim is true | 1 M | Launch |
| Every Markdown extension declared; Files visibility | High, tiny | 1 S | Launch |
| Paste Markdown | High: the one path that works from every chat app | 1 M | Launch |
| How to Open Files guide | Medium-high: answers the top user question in the app | 1 M | Launch |
| View in mdview (Action extension) | High: renders shared text and files from any share sheet | 2 (M + L) | v0.2 |
| Outline (table of contents) | High for long docs | 1 M | v0.2 |
| Copy code button | Medium-high, small | 1 S | v0.2 |
| Reading settings: text size, width, serif/mono | Medium | 1 M | v0.2 |
| Reading position per file | Medium | 1 M | v0.2 |
| PDF export and print | Medium | 1 L | v0.2 |
| Math, off by default | Medium for AI output, small (library already ships) | 1 S | v0.2 |
| iPad keyboard shortcuts | Medium on iPad, small | 1 S | v0.2 |
| Stage Manager / multi-window | Already on (`UIApplicationSupportsMultipleScenes`), so only verified in L12 | 0 | Launch check |

**Deferred (not beads):**

| Item | Why it waits | Revisit when |
| --- | --- | --- |
| Quick Look preview extension | iOS 27 does not call third-party Markdown preview extensions (FB24481377). It would only help iOS 18 to 26 users. | Apple fixes the regression, or keving wants it for iOS 26 devices (Q4) |
| URL scheme / Universal Links | Q1 network decision; hosts rarely linkify custom schemes | keving answers Q1 |
| Relative `.md` links, wikilink resolution, folder/vault browsing and search | Needs a folder picker and a security-scoped bookmark (the sandbox grants only the opened file). That is a library feature, not a viewer feature. | After v0.2, if asked |
| Spotlight indexing of recents | mdview keeps no recents store (the system browser does); needs one | With vault browsing |
| App Intents "Open in mdview" | Shortcuts can already use Open In; low pull | Post v0.2 |
| Home screen widget of recents | Needs an App Group and a recents store | Post v0.2 |
| Handoff | No Mac app | Never, unless a Mac app returns |
| Mermaid diagrams | Every option needs a WebView (lint ban) or a JS engine and DOM shim; nothing light and offline | Native Swift renderer appears |
| Live Text | Text is already selectable; nothing to build | n/a |

## 4. Risks and containment

| Risk | Containment |
| --- | --- |
| The iOS 27 regression also breaks `DocumentGroupLaunchScene` action buttons (a known iOS 27 bug already breaks `NewDocumentButton`). CI only has an iOS 26 simulator. | L8 and L9 put plain `Button`s and a `PasteButton` in the launch scene's `actions`, plus the same entries in the reader menu. L12 tests them on keving's iOS 27 phone. If they fail there, a pre-written fallback moves them to `overlayAccessoryView` (L8 brief). |
| Textual's selection overlay hides Rendered content from VoiceOver | K3 turns the overlay off under VoiceOver. L10 checks that headings are reachable elements. L12 runs the rotor on a device. |
| Heading `.id(slug)` collides for duplicate headings; `scrollTo` lands on the first | The outline marks repeated titles with `occurrence`, and the V3 brief documents that the first copy wins. Acceptable for a viewer. |
| The copy button sits under Textual's selection overlay and gets no taps | The V4 brief puts the button on the `Overflow` region (Textual excludes those frames from the overlay) and has a fallback: a context-menu "Copy Code" on the block. |
| Task checkbox attachments load async and flicker or misalign | K2 fallback (Unicode glyph with an accessibility label), chosen inside L6 if needed |
| PDF export misses async attachments or highlighting | V7 renders after a settle delay, with images loaded synchronously by a render-only loader. MDCore tests cover pagination. |
| The Action extension hits the extension memory limit on a huge file | `SharedContent` caps input at 5 MB and shows Source only above 1 MB |
| An extension bundle ID inherits `us.par72.mdview` from `Local.xcconfig` | Target-level `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` overrides the xcconfig. `check_app_config.py` asserts every target's bundle ID. |
| A team ID leaks into the repo | `check_app_config.py` fails on a 10-character team ID in tracked files. `DEVELOPMENT_TEAM` stays only in gitignored `Config/Local.xcconfig`. |
| The launch slips because of v0.2 work on the same branch | The runner stops at L12 (`needs_human`). keving merges and uploads the launch work before any V bead runs. |
| CI is the only place UI tests run, and `CI=true` shells could run the simulator locally | The gate is `make test` + `make lint` only. UI tests are compiled locally (`make build-tests`) and run only in GitHub Actions. Beads never run `make test-ios`. |
| App Review rejects the Action extension's activation rule | SUBQUERY on `public.plain-text` with a max count of 1, never `TRUEPREDICATE` (checked by script) |

## 5. Beads

Every bead runs the section 6 gate. Every bead leaves `make test` and `make lint` green. No bead runs `make test-ios` or boots a simulator; UI tests run in GitHub Actions on push. Commit with Conventional Commits and `Agent:` / `Model:` / `Bead:` trailers. Read `CLAUDE.md`, `docs/DEVELOPMENT.md` and `docs/ARCHITECTURE.md` first.

### Launch-critical (0.1.0 build 2)

### L1 Add UI-test build and app config checks to the quality gate

Size M, P1, model sonnet, depends on nothing.

Owns: `Makefile`, `scripts/check_app_config.py`, `App/mdviewUITests/ReaderLauncher.swift`, `App/mdviewUITests/ReaderFixture.swift`, `App/mdviewUITests/ScreenshotTests.swift`, `docs/DEVELOPMENT.md`, `AGENTS.md`, `CLAUDE.md`.

1. **`make build-tests`:**
   `xcodebuild build-for-testing -project mdview.xcodeproj -scheme mdview -destination 'generic/platform=iOS' -derivedDataPath .derivedData -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO`.
   `make test` runs `swift test --package-path Packages/MDCore` and then `$(MAKE) build-tests` instead of `build-ios`. `build-tests` builds the app too. Keep `build-ios` for `make build-ios` and for callers that want only the app.
2. **`scripts/check_app_config.py`** (Python 3 stdlib only):
   - Exits 0 with one `ok:` line per check, or prints `error:` lines and exits 1.
   - Runs from `make lint` (add `python3 scripts/check_app_config.py` after swiftlint) and as `make check-config`.
   - First checks:
     - (a) No tracked file sets `DEVELOPMENT_TEAM` to a non-empty value. Use `git ls-files`; skip `Config/Local.xcconfig`, which is gitignored.
     - (b) Every `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` is `us.par72.mdview` or starts with `us.par72.mdview.`.
     - (c) Every `PrivacyInfo.xcprivacy` under `App/` has `NSPrivacyTracking` false, empty `NSPrivacyTrackingDomains` and empty `NSPrivacyCollectedDataTypes`.
     - (d) Every `Info.plist` under `App/` that has `NSExtension` has no `TRUEPREDICATE` in its activation rule.
   - Structure: one function per check, so later beads add checks (L2 contrast, L7 extension list, V2 extension privacy manifests).
   - `--self-test` feeds each check a bad in-memory example and asserts it fails.
3. **UI test helpers:**
   - Move the launch-env code out of `ScreenshotSession.makeApp` into `ReaderLauncher`: `static func app(fixture: ReaderFixture, scheme: "light"|"dark"|nil, contentSize: String? = nil, query: String? = nil) -> XCUIApplication`.
   - It sets `MDVIEW_SCREENSHOT_NAME`, `MDVIEW_SCREENSHOT_MARKDOWN`, `MDVIEW_SCREENSHOT_SCHEME` and `MDVIEW_SCREENSHOT_QUERY`.
   - `contentSize` adds `-UIPreferredContentSizeCategoryName <value>` to the launch arguments.
   - `ReaderFixture` has `name` and `markdown`. Fixtures: `kitchenSink` (named `A very long file name for accessibility checks.md`, with H1 "Overview" (containing a link), H2 "Tasks", H2 "Data", H3 "Code", nested bullets, an ordered list, `- [ ] Draft` and `- [x] Ship`, a 7-column table whose last column header is "Owner", a fenced `swift` block starting with `struct`, a block quote), and `cedarTrail` / `weeklyReview` (read from the screenshot env as today).
   - `ScreenshotTests` uses `ReaderLauncher` and captures the same five shots.
4. Document `make build-tests`, `make check-config` and the new `make test` in `docs/DEVELOPMENT.md` and the Build & Test sections of `AGENTS.md` and `CLAUDE.md`.

Edge cases: `build-for-testing` with signing disabled must not need a team. Do not add a simulator destination. `git ls-files` must work in a worktree.

Test approach: `make test` (now compiles `mdviewUITests`), `make lint`, `python3 scripts/check_app_config.py --self-test`.

### L2 Add dark and increased-contrast accent variants

Size S, P1, model sonnet, depends on L1.

Owns: `App/mdview/Assets.xcassets/AccentColor.colorset/Contents.json`, `scripts/check_app_config.py` (contrast check only), `docs/ARCHITECTURE.md` (one line).

Add appearance variants to the accent color set:

| Appearance | Color | Contrast |
| --- | --- | --- |
| Any (light) | #2E6B4A (unchanged) | 6.33 on #FFFFFF, 5.67 on #F2F2F7, 5.04 on #E5E5EA |
| Dark | #5BBF8A | 9.26 on #000000, 7.51 on #1C1C1E, 6.15 on #2C2C2E, 5.01 on #3A3A3C |
| Light, high contrast | #1F4A33 | |
| Dark, high contrast | #7AD3A3 | |

Use the asset catalog keys: `appearances` with `luminosity` `dark`, and `contrast` `high`.

Extend `check_app_config.py` with `check_accent_contrast`:
- Parse the colorset JSON.
- WCAG 2.x relative luminance and contrast ratio.
- Light and light-high-contrast must reach ≥ 4.5 against #FFFFFF, #F2F2F7 and #E5E5EA.
- Dark and dark-high-contrast must reach ≥ 4.5 against #000000, #1C1C1E and #2C2C2E, and ≥ 3.0 against #3A3A3C.
- Print each ratio. `--self-test` includes the old single #2E6B4A dark case, which must fail.

Edge case: components may be stored as 0 to 1 floats or as `0xNN` hex strings; handle both.

Test approach: `make lint` prints the ratios. `make test` builds.

### L3 Make rendered headings and lists VoiceOver-friendly

Size M, P1, model opus, depends on L1.

Owns: `App/mdview/Reader/ReaderStyle.swift` (new), `App/mdview/Reader/RenderedView.swift`, `App/mdviewUITests/ReaderAccessibilityTests.swift` (new), `docs/ARCHITECTURE.md`.

1. **`struct ReaderStyle: StructuredText.Style`.** Start from every member of `StructuredText.GitHubStyle`, then replace three:
   - `headingStyle = AccessibleHeadingStyle()`: wraps `StructuredText.GitHubHeadingStyle` `makeBody`, then `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(.isHeader)`, and `.accessibilityHeading(level)` mapping 1 to 6 onto `.h1` to `.h6`.
   - `listItemStyle = AccessibleListItemStyle()`: wraps `DefaultListItemStyle.default` with `.accessibilityElement(children: .combine)`, so "1. Buy milk" or "Buy milk" reads as one element.
   - `unorderedListMarker = QuietBulletMarker()`: GitHub's `.hierarchical(.disc, .circle, .square)` plus `.accessibilityHidden(true)`. Ordered markers stay `.decimal` and readable.
2. **`RenderedView`:**
   - Apply `.textual.structuredTextStyle(ReaderStyle())`.
   - Read `@Environment(\.accessibilityVoiceOverEnabled)`. When true, apply `.textual.textSelection(.disabled)`; otherwise `.enabled` (the types differ, so branch in a `@ViewBuilder`; K3).
3. **No heading identifiers.** `HeadingStyleConfiguration` has no text, and counters across `AnyView` bodies are unreliable. UI tests find headings by label (`app.staticTexts["Overview"]`).
4. **`ReaderAccessibilityTests`** (CI only), using `ReaderLauncher` with `kitchenSink`:
   - The heading "Overview" exists and is hittable while VoiceOver is off (shows the selection overlay doesn't hide it).
   - A bullet item's label does not contain "circle".
5. Document the style and K3 in `docs/ARCHITECTURE.md`.

Edge cases: `combine` on a heading must keep links inside the heading tappable; check with a heading that contains a link in the fixture. Nested lists: each level's item is one element. Do not change Source view.

Test approach: `make test` compiles the app and UI tests; `make lint`.

### L4 Scroll wide tables and fix accessibility-size truncation

Size M, P1, model sonnet, depends on L3.

Owns: `App/mdview/Reader/ReaderStyle.swift` (table members only), `App/mdview/Reader/ReaderView.swift` (toolbar and title only), `App/mdviewUITests/DynamicTypeTests.swift` (new).

1. **`ScrollingTableStyle`:** the GitHub table look (copy `GitHubTableStyle.makeBody`: border, even-row background, dividers; if Textual's `DynamicColor.gitHub*` colors are not public, use `Color(uiColor: .separator)` for borders and `Color(uiColor: .secondarySystemBackground)` for even rows) wrapped in Textual's `Overflow { state in … }` so wide tables scroll horizontally. Cap the width at `state.containerWidth * 1.5`, as `OverflowTableStyle` does. Never use a bare horizontal `ScrollView`.
2. **`AccessibleTableCellStyle`:** wraps the GitHub cell style. Add `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(.isHeader)` when `row == 0`, and `.accessibilityCustomContent("Position", "Row \(row + 1), column \(column + 1)")`. The reading order stays row by row (SwiftUI `Grid` order).
3. **Mode picker at accessibility sizes:**
   - When `dynamicTypeSize.isAccessibilitySize`, replace the segmented control with `Picker(...).pickerStyle(.menu)`, labeled with the current mode and the identifier `reader.modePicker`.
   - Otherwise keep the segmented control and add `.accessibilityShowsLargeContentViewer()`.
   - `ScreenshotTests` uses `segmentedControls["reader.modePicker"]` at the default size, so that keeps working.
4. **Title:**
   - Keep `.navigationTitle(fileName)` for the window and app switcher.
   - Add `ToolbarItem(placement: .principal)` with `Text(fileName)` at `.headline`, `.lineLimit(2)`, `.truncationMode(.middle)`, `.accessibilityShowsLargeContentViewer()` and `.accessibilityLabel(fileName)`.
   - At accessibility sizes, use `.lineLimit(3)` and `.minimumScaleFactor(0.8)`.
5. **`DynamicTypeTests`** (CI only):
   - Launch `kitchenSink` with `UICTContentSizeCategoryAccessibilityXXXL`.
   - Assert `reader.modePicker` exists and is hittable.
   - Assert the title text exists with the full file name as its label.
   - Swipe left on the table and assert a last-column header (e.g. "Owner") becomes hittable.

Edge cases: the `searchCount` line must wrap, not truncate (`.lineLimit(nil)`). The table must still select text inside cells.

Test approach: `make test`, `make lint`.

### L5 Mark the current find match without color and honor Reduce Motion

Size S, P1, model sonnet, depends on L1.

Owns: `Packages/MDCore/Sources/MDCore/FindHighlight.swift`, `Packages/MDCore/Tests/MDCoreTests/FindHighlightTests.swift`, `App/mdview/Reader/SourceView.swift`, `App/mdview/Motion.swift` (new), `.swiftlint.yml` (new custom rule only).

1. **MDCore `FindHighlight`** (contract in 3.2):
   - The current match is always `fill .strong`, `underline .thick`, `bold true`.
   - Other matches are `.soft`, with no underline, or `.dotted` when Differentiate Without Color is on.
   - `current` out of range means no current match.
2. **`SourceView`** maps styles to attributes: `.soft` = systemYellow at 35%, `.strong` = systemYellow with black text, `.thick` = `NSUnderlineStyle.thick`, `.dotted` = `[.single, .patternDot]`, bold = the bold monospaced variant at the same scaled size. Read `@Environment(\.accessibilityDifferentiateWithoutColor)` and add it to `SourceRenderSignature` so toggling it repaints.
3. **Reduce Motion:**
   - In `SourceTextView.layoutSubviews`, when `UIAccessibility.isReduceMotionEnabled`, scroll with `setContentOffset(_, animated: false)` to the rect of the range instead of `scrollRangeToVisible`.
   - Add `enum Motion { static func animate(_ reduceMotion: Bool, _ body: () -> Void) }`, which calls `body()` without animation when `reduceMotion` is true and `withAnimation(.default)` otherwise.
   - Add a swiftlint custom rule `use_motion_helper` (regex `withAnimation\(`, excluded path `App/mdview/Motion.swift`, severity error).

Test approach: `swift test` (FindHighlightTests: zero matches, one, current at 0 and at the last index, DWC on and off, out-of-range current), `make test`, `make lint`. Check that the rule fires by temporarily adding `withAnimation(` to a scratch file; do not commit that file.

### L6 Render task lists as read-only checkboxes

Size M, P1, model sonnet, depends on L1.

Owns: `Packages/MDCore/Sources/MDCore/TaskListPreprocessor.swift`, `Packages/MDCore/Sources/MDCore/TaskMarker.swift`, `Packages/MDCore/Sources/MDCore/RenderPipeline.swift`, matching tests, `App/mdview/Reader/TaskCheckbox.swift` (new), `App/mdview/Reader/LocalImageLoader.swift`, `App/mdview/Reader/RenderedView.swift` (pipeline call only).

1. **`TaskListPreprocessor.process`:**
   - A line matches when it has optional indentation, then a list marker (`-`, `*`, `+`, `1.` or `1)`), one or more spaces, then `[ ]`, `[x]` or `[X]`, then a space or end of line.
   - Replace only the bracket token with `![Not done](x-mdview-task:unchecked)` or `![Done](x-mdview-task:checked)`.
   - Skip fenced code (``` and ~~~, the same fence tracking as `ObsidianPreprocessor`), indented code blocks, and `[ ]` that is not at the start of a list item.
   - Keep line endings (`\n` and `\r\n`).
2. **`TaskMarker`:** contract in 3.2.
3. **`RenderPipeline.prepare(_:obsidian:)`:** contract in 3.2 (a `math` parameter comes later in V8; add it now with default `false`, ignored until V8). `RenderedView.markdownForDisplay` calls only this.
4. **`TaskCheckbox: Attachment`:**
   - SF Symbol `square` (unchecked) or `checkmark.square.fill` (checked), tinted with the accent color for checked and `.secondary` for unchecked.
   - `sizeThatFits` returns a square sized to the body font (`UIFontMetrics(forTextStyle: .body).scaledValue(for: 17)`) times 1.1.
   - `accessibilityLabel` "Done" / "Not done". `description` `[x]` / `[ ]`. `selectionStyle` text.
   - It is not tappable.
5. **`LocalImageLoader.attachment(for:)`:** change the return type from `LocalFileImage` to `AnyAttachment`. If `TaskMarker.state(for: url)` is non-nil, return `AnyAttachment(TaskCheckbox(state))` before any file work; otherwise wrap `LocalFileImage` as today. `ImagePolicy` is unchanged and still rejects `x-mdview-task:`; add a test that says so.
6. **Fallback (K2):** if attachments visibly misalign with the text baseline, use `baselineOffset`. If that cannot be fixed in this bead, switch the preprocessor output to `☐ ` / `☑ ` and note it in the handoff.

Test approach (MDCore): unchecked, checked and uppercase X; `*`, `+` and ordered markers; nested indentation; inside a fence (unchanged); `[ ]` mid-sentence (unchanged); a `[x]` link-like text `[x](url)` (unchanged, because the bracket is followed by `(`); CRLF; pipeline order (front matter removed before task rewrite; a remote image next to a task still linkified). Then `make test` and `make lint`.

### L7 Declare every Markdown extension and expose the app's Documents folder

Size S, P1, model sonnet, depends on L1.

Owns: `Packages/MDCore/Sources/MDCore/MarkdownFileTypes.swift`, its test, `App/mdview/Info.plist`, `App/mdview/Reader/ReaderView.swift` (`showsModePicker` only), `scripts/check_app_config.py` (extension-list check only).

1. Add `MarkdownFileTypes` (contract in 3.2, with BEGIN/END markers).
2. Change `ReaderView.showsModePicker` to:
   ```swift
   switch MarkdownFileTypes.isMarkdown(pathExtension: fileExtension) {
   case true?: true
   case false?: false
   case nil: document.allowsRenderedMode
   }
   ```
3. **`Info.plist`:**
   - Imported UTI `net.daringfireball.markdown`: `public.filename-extension` = every `markdownExtensions` entry; `public.mime-type` as an array (`text/markdown`, `text/x-markdown`); keep conforms-to `public.plain-text`.
   - Markdown document type `LSHandlerRank` = `Default` (K4). Plain text stays `Alternate`.
   - Add `UIFileSharingEnabled` = YES (K5). Keep `LSSupportsOpeningDocumentsInPlace` YES.
4. **`check_app_config.py` `check_markdown_extensions`:** the imported UTI's extensions equal the literals between the markers in `MarkdownFileTypes.swift`; both document types exist with the expected ranks; `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are true.

Edge cases:
- Upper-case extensions (`README.MD`): `isMarkdown` lowercases.
- `.txt` stays source-only.
- Unknown extension with Markdown content type keeps today's behavior.
- Do not export the UTI. Do not add `public.markdown` (no such system type).

Test approach: `swift test` (`isMarkdown` for each extension, uppercase, txt, unknown), `make lint` (plist check), `make test`.

### L8 Add a launch screen with a "How to Open Files" guide

Size M, P1, model sonnet, depends on L7.

Owns: `App/mdview/mdviewApp.swift`, `App/mdview/Help/OpenFilesHelpView.swift` (new), `App/mdview/Reader/ReaderView.swift` (menu item only), `App/mdviewUITests/LaunchSceneTests.swift` (new).

1. **Launch scene.** In `mdviewApp.body`, add `DocumentGroupLaunchScene("mdview") { … } background: { … }` (iOS 18 API).
   - Background: the accent color at low opacity over `systemBackground`, readable in both appearances.
   - Actions: a `Button("How to Open Files", systemImage: "questionmark.circle")` with identifier `launch.help` that presents `OpenFilesHelpView` in a sheet. L9 adds Paste beside it, so leave room.
2. **`OpenFilesHelpView`:** a `NavigationStack` with a `List` of sections. Each section has a `Label` header (`.isHeader`), one sentence, and short numbered steps. Shipped paths only:
   - "From a chat or mail app": tap the attachment, Share, mdview. If mdview isn't in the row, scroll to the end and tap More.
   - "Copy and paste": copy the text, open mdview, Paste Markdown.
   - "Save to Files first": Save to Files, then pick the file here or in Recents.
   - "Files app": long-press, Share, mdview.
   - "iPad": drag a file onto mdview. Mark this section with a comment `// drag-and-drop: remove if L12 fails`.
   - Footer: "mdview never connects to the internet."
   - Done button `help.done`. Supports Dynamic Type with no truncation, and VoiceOver headings.
3. **Reader menu:** add "How to Open Files" (`reader.help`), which presents the same view.
4. **iOS 27 fallback** (do not build; record it in a comment above the scene): if launch-scene actions don't fire on iOS 27 (L12 checks), move the buttons into `overlayAccessoryView`.
5. **`LaunchSceneTests`** (CI only, normal launch with no screenshot env): tap `launch.help`, assert the "Copy and paste" header exists, tap `help.done`.

Edge cases: the screenshot harness overlay must still cover the launch screen (it hides other windows, so check that `ScreenshotTests` code paths are unchanged). Multi-window iPad: each scene gets its own launch screen.

Test approach: `make test`, `make lint`.

### L9 Add Paste Markdown

Size M, P1, model opus, depends on L8.

Owns: `App/mdview/mdviewApp.swift` (launch actions only), `App/mdview/Paste/PastedReaderView.swift` (new), `App/mdview/TextDocument.swift`, `App/mdview/ReaderContext.swift` (new), `App/mdview/ScreenshotLaunch.swift`, `App/mdview/Reader/ReaderView.swift` (title source only), `App/mdviewUITests/PasteTests.swift` (new), `App/mdview/Help/OpenFilesHelpView.swift` (text only if needed).

1. **`TextDocument.init(text:contentType:)`** becomes available in Release; it has no file.
2. **`ReaderContext`:**
   - Holds `fileURL: URL?` and `displayName: String?`, as an `EnvironmentValues` entry `readerContext`.
   - `ReaderView` takes its file URL and title from `readerContext` first, then `documentConfiguration`.
   - Replace the DEBUG-only `screenshotFileURL` with it, and keep the screenshot harness working.
   - A pasted document has `fileURL` nil and `displayName` "Pasted Markdown". With no file URL, the image base directory is nil, so relative images don't load (that is expected).
3. **Launch scene `PasteButton(payloadType: String.self)`:**
   - Label "Paste Markdown", identifier `launch.paste`.
   - The first non-empty string is decoded as-is and opens `PastedReaderView` in a `.fullScreenCover`.
   - `PastedReaderView` = `NavigationStack { ReaderView(document: TextDocument(text:, contentType: .markdown)) }` with a Done button (`paste.done`) and a "Save to Files" toolbar button (`paste.save`) using `.fileExporter`. The default name is `Pasted <yyyy-MM-dd HHmm>.md`; it uses a `FileDocument` wrapper that writes UTF-8.
   - Empty or whitespace-only paste does nothing.
   - Paste lives on the launch scene only, not in the reader menu (one path, less clutter).
4. **Reader behavior:** Rendered / Source picker shown (treated as Markdown), find works, the Obsidian toggle applies.
5. **`PasteTests`** (CI only):
   - `UIPasteboard.general.string = "# Pasted\n\n- [x] done"` in the test process.
   - Launch normally, tap `launch.paste`, assert the title "Pasted Markdown" and the text "Pasted" exist, tap `paste.done`.
   - If `PasteButton` cannot be tapped in XCUITest, note it and skip with `XCTSkip` and a reason, not a failure.

Edge cases: huge pastes (10 MB) must not freeze the launch screen, so decode off the main actor if over 1 MB. Text that is not Markdown still renders as paragraphs.

Test approach: `make test`, `make lint`.

### L10 Add accessibility audit UI tests

Size M, P1, model sonnet, depends on L2, L3, L4, L5, L6, L8, L9.

Owns: `App/mdviewUITests/AccessibilityAuditTests.swift` (new), `App/mdviewUITests/ReaderFixture.swift` (fixture additions only), `docs/DEVELOPMENT.md` (tests section).

`AccessibilityAuditTests` (CI only, `XCUIApplication.performAccessibilityAudit()`, Xcode 15+):
- Rendered `kitchenSink` in light, rendered in dark, Source, find active (`query: "Draft"`), accessibility XXXL rendered, the help sheet, the pasted reader.
- Each test calls `try app.performAccessibilityAudit { issue in … }`. The handler may ignore only issues on system-owned elements (for example the search field placeholder), each with a comment that names the element and why. Never ignore by audit type alone.
- Also assert the task checkbox elements labeled "Done" and "Not done" exist.

Document in `docs/DEVELOPMENT.md` how to read audit failures from the CI `xcresult` artifact.

Test approach: `make test` (compiles), `make lint`. The runner's agent verify checks the next CI run on push.

### L11 Update launch docs, App Store listing and build number

Size S, P1, model sonnet, depends on L10.

Owns: `docs/app-store/listing.md`, `docs/support.md`, `docs/privacy.md`, `docs/RELEASE.md`, `README.md`, `docs/ARCHITECTURE.md`, `project.yml` (`CURRENT_PROJECT_VERSION` only).

1. `project.yml`: `CURRENT_PROJECT_VERSION` "2". `MARKETING_VERSION` stays "0.1.0" (K11). Update every "build 1" mention in the docs.
2. **`listing.md`:**
   - The description keeps "task lists" (now true) and adds "Paste Markdown copied from any app" and "A built-in guide to opening files from chat and mail apps". Keep the iPad drag-and-drop line, but add a comment in the doc: "remove both lines (FEATURES bullet and support FAQ) if L12 drag-and-drop fails".
   - Recount every character count with Python `len()` and update the numbers.
   - Review notes mention Paste Markdown and the help screen.
   - Promotional text unchanged unless it gets shorter.
3. **`support.md`:** new FAQ "How do I open a Markdown file someone sent me in a chat app?" with paths 1, 3 and 4 from plan section 3.1, in plain words. Mention that some apps share messages as text, not files, and that copy and paste works then.
4. **`privacy.md`:** state that pasted text is shown in memory and saved only when the user picks Save to Files. No new stored preferences.
5. **`RELEASE.md`** on-device checklist, new lines:
   - VoiceOver rotor jumps by heading.
   - Bullets are not read as "circle".
   - Table cells read row by row with the header trait.
   - Differentiate Without Color: the current match is underlined and bold.
   - Largest accessibility size: picker and title readable.
   - Reduce Motion: find jumps without animation.
   - Increased Contrast accent.
   - Task lists render as boxes.
   - Paste Markdown.
   - How to Open Files.
   - Share a `.md` from a chat app (record which app and which path worked).
   - iPad drag and drop, Stage Manager with two documents side by side.
   - On iOS 27: launch-scene buttons respond.
6. **README / ARCHITECTURE:** features list and architecture (ReaderStyle, RenderPipeline, TaskCheckbox, launch scene, ReaderContext).

Screenshots: no new screens are required for launch. Do not run `scripts/screenshots.sh` (it boots simulators); L12 decides.

Test approach: `make lint`, `make test`, plus `python3 -c` character counts pasted into the PR body.

### L12 Device check and ship 0.1.0 build 2

Size M, P1, needs_human, no_code, depends on L11. **The runner stops here.**

keving:
1. Merge the launch PR after CI is green.
2. `make archive && make upload` from `main`.
3. Install from TestFlight on the iOS 27 iPhone and an iPad.
4. Run the whole `docs/RELEASE.md` checklist.
5. Specifically:
   - (a) From Grok Bot (and Messages or Mail as a control), try paths 1 to 4 from plan 3.1 and note which work.
   - (b) Check whether Grok Bot's attachment view offers Share and whether it previews with Quick Look (a Quick Look preview shows a share button and a list icon in the bottom toolbar).
   - (c) iPad drag and drop.
   - (d) VoiceOver rotor on the kitchen-sink file, with selection off under VoiceOver.
   - (e) The launch-scene buttons on iOS 27.
6. If drag and drop fails, delete the drag-and-drop lines in `listing.md`, `support.md`, `README.md` and the help view section marked in L8.
7. If the launch buttons fail on iOS 27, file a bead for the `overlayAccessoryView` fallback before submitting.
8. Optionally regenerate screenshots with `scripts/screenshots.sh` (one simulator at a time).
9. Fill the App Store Connect fields from `listing.md`, including any localized copies kept only in App Store Connect, and submit for review by **Fri Nov 6** for the Nov 10 launch.

### v0.2 (0.2.0)

### V1 Move the reader core into App/Shared

Size M, P2, model sonnet, depends on L12.

Owns: `App/Shared/` (new), `App/mdview/Reader/` (moves out), `project.yml` (app target sources only), `scripts/check_app_config.py` (shared-code check only), `docs/ARCHITECTURE.md`.

1. Move these files to `App/Shared/Reader/` with no behavior change: `RenderedView.swift`, `ReaderStyle.swift`, `LocalImageLoader.swift`, `TaskCheckbox.swift`, `SourceView.swift`, `ReaderContext.swift`, and a new `ReaderCore.swift` holding `ReaderMode`. `Motion.swift` moves to `App/Shared/`.
2. `ReaderView.swift` stays in `App/mdview/Reader/` (it uses `DocumentGroup` configuration).
3. `project.yml`: the app target sources are `App/mdview` and `App/Shared`.
4. Shared code must be extension-safe: add a `check_app_config.py` check that no file under `App/Shared/` contains `UIApplication.shared` or `openURL(` on `UIApplication`.
5. Keep the swiftlint `no_networking` and `use_motion_helper` rules covering `App/` (they already do).

Test approach: `make test`, `make lint`. `git diff --stat -M` shows renames, not rewrites.

### V2 Add the "View in mdview" Action extension

Size L, P2, model opus, depends on V1.

Owns: `App/mdviewAction/` (new: `ActionViewController.swift`, `SharedReaderView.swift`, `Info.plist`, `PrivacyInfo.xcprivacy`), `Packages/MDCore/Sources/MDCore/SharedContent.swift` and its test, `project.yml` (new target, app dependency embed), `scripts/check_app_config.py` (extension checks), `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`.

1. **`project.yml` target `mdviewAction`:**
   - `type: app-extension`, iOS 18, sources `App/mdviewAction` + `App/Shared`, packages Textual and MDCore.
   - Settings: `PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview.action` (target settings override `Config/Local.xcconfig`; keep `configFiles` pointing at `Local.xcconfig` for the team), `INFOPLIST_FILE: App/mdviewAction/Info.plist`, `GENERATE_INFOPLIST_FILE: NO`, `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` equal to the app's, `APPLICATION_EXTENSION_API_ONLY: YES`.
   - The app target adds `- target: mdviewAction` (embed). No App Group (K7).
2. **`Info.plist`:**
   - `CFBundleDisplayName` "View in mdview".
   - `NSExtension`: `NSExtensionPointIdentifier` `com.apple.ui-services`, `NSExtensionPrincipalClass` `$(PRODUCT_MODULE_NAME).ActionViewController`.
   - `NSExtensionAttributes`: `NSExtensionServiceRoleType` `NSExtensionServiceRoleTypeViewer`, `NSExtensionActionWantsFullScreenPresentation` YES.
   - `NSExtensionActivationRule` (a string):
     `SUBQUERY(extensionItems, $item, SUBQUERY($item.attachments, $a, ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.plain-text").@count == 1).@count == 1`.
     This covers shared text, `.md` (conforms to plain text) and `.txt`, and excludes web URLs.
3. **`PrivacyInfo.xcprivacy`:** a copy of the app's (UserDefaults `CA92.1`, because `@AppStorage` reads `obsidian.enabled` in the extension's own domain).
4. **`ActionViewController: UIViewController`:**
   - Loads the first attachment conforming to `public.plain-text`.
   - Prefers `loadFileRepresentation(for: .plainText)`: copy the bytes inside the callback; keep `suggestedName`.
   - Otherwise `loadItem(forTypeIdentifier: "public.plain-text")` as `String` / `Data` / `URL`.
   - Decodes with `TextDecoding`, checks `SharedContent`, and hosts `SharedReaderView` in a `UIHostingController`.
5. **`SharedReaderView`:**
   - `NavigationStack` with the title from `SharedContent.title(suggestedName:)` ("Shared Text" when nil).
   - Rendered / Source segmented picker (Markdown only, using `MarkdownFileTypes`).
   - Done (`action.done`), which calls `extensionContext?.completeRequest(returningItems: nil)`.
   - Errors show a message plus Done.
   - `ReaderContext.fileURL` is nil (no sibling images).
6. **`SharedContent`** (MDCore): `title(suggestedName:)`, `isMarkdown(suggestedName:)` (nil name means Markdown), `limitBytes = 5_000_000`, `sourceOnlyAboveBytes = 1_000_000`, `tooLargeMessage`.
7. **`check_app_config.py`:** the extension plist has the expected point identifier, no `TRUEPREDICATE`, a `PrivacyInfo.xcprivacy` next to it, and a bundle ID under `us.par72.mdview.`.
8. **Help and docs:** add path 2 to `OpenFilesHelpView` and `docs/support.md`: "Share, then View in mdview (scroll the actions list; if missing, tap Edit Actions)".

Edge cases: the host shares RTF (conforms to `public.text`, not plain text), so the extension does not appear (expected). Shared text from Safari selection works. A file with no extension renders as Markdown. Dark mode and Dynamic Type follow the host trait collection. Never call `UIApplication.shared`.

Test approach: `swift test` (SharedContent), `make test` (builds the extension, unsigned), `make lint` (config checks). The device check is in V11.

### V3 Add the outline sheet

Size M, P2, model sonnet, depends on V1.

Owns: `Packages/MDCore/Sources/MDCore/HeadingOutline.swift` and its test, `App/mdview/Reader/OutlineSheet.swift` (new), `App/Shared/Reader/RenderedView.swift` (`ScrollViewReader` only), `App/mdview/Reader/ReaderView.swift` (toolbar button only), `App/mdviewUITests/OutlineTests.swift` (new).

1. **`HeadingOutline.headings(in:)`:**
   - Parse with `AttributedString(markdown:options: .init())`, the same as Textual's default.
   - Walk runs whose `presentationIntent` contains `.header(level)`. Group consecutive runs with the same intent identity into one heading; the title is the characters.
   - `slug` = Textual's `slugified()`: lowercase, whitespace → `-`, keep letters, numbers and `-`, split on `-` dropping empties, join with `-`. Add a comment crediting Textual (MIT).
   - `occurrence` counts repeats of the same slug.
   - Always run it on `RenderPipeline.prepare(…)` output, so front matter is gone and the titles match the rendered ones.
2. **`OutlineSheet`:**
   - A `List` of headings indented by level (min level = 0 indent), each row a `Button` with identifier `outline.row.<index>`.
   - VoiceOver label "Heading level N, <title>".
   - `.presentationDetents([.medium, .large])`.
3. **Toolbar button** `reader.outline` (`list.bullet.indent`, "Outline") shown only in Rendered mode with ≥ 2 headings.
4. **Jumping:** `RenderedView` wraps its content in `ScrollViewReader`. Selecting a row dismisses the sheet, then `proxy.scrollTo(slug, anchor: .top)` inside `Motion.animate(reduceMotion)`. Duplicate slugs land on the first heading (Textual's ids collide); document this in ARCHITECTURE.
5. **`OutlineTests`** (CI only): open `kitchenSink`, tap `reader.outline`, tap the "Code" row, assert the "Code" heading is hittable.

Test approach: `swift test` (ATX, setext, inline formatting `## **Bold** \`code\`` gives the title "Bold code", headings inside fences ignored, front matter removed via the pipeline, duplicates' occurrence, a slug table of 8 cases matching Textual's behavior including punctuation and Unicode), `make test`, `make lint`.

### V4 Add a copy button to code blocks

Size S, P2, model sonnet, depends on V3.

Owns: `App/Shared/Reader/ReaderStyle.swift` (code block member only), `App/Shared/Reader/CopyableCodeBlockStyle.swift` (new), `App/mdviewUITests/CodeBlockTests.swift` (new).

1. **`CopyableCodeBlockStyle`:**
   - Reproduce `GitHubCodeBlockStyle` (an `Overflow` with the label, 0.85 font scale, monospaced, 16 pt padding, secondary background, 6 pt corners).
   - Add `.overlay(alignment: .topTrailing)` **on the `Overflow` view** (its frame is excluded from Textual's selection overlay, so taps reach the button).
   - The overlay is a `Button` with `doc.on.doc`, `accessibilityLabel` "Copy code" and identifier `code.copy`. It calls `configuration.codeBlock.copyToPasteboard()`, then shows "Copied" with `checkmark` for 1.5 s (`Motion.animate`, `.sensoryFeedback(.success, trigger:)`). The confirmation is text, not color.
   - If `languageHint` is set, show it as a small caption leading in the same overlay row.
2. **Fallback** if the button gets no taps on device: a `.contextMenu { Button("Copy Code") }` on the block. Implement the context menu anyway; it's cheap and works with VoiceOver actions.
3. **`CodeBlockTests`** (CI only): tap `code.copy` in `kitchenSink`, then assert `UIPasteboard.general.string` contains `struct` (the fixture's Swift block). The test process can read the simulator pasteboard.

Test approach: `make test`, `make lint`.

### V5 Add reading settings: text size, width and font

Size M, P2, model sonnet, depends on V4.

Owns: `App/Shared/Reader/ReadingSettings.swift` (new), `App/Shared/Reader/RenderedView.swift` (settings application only), `App/Shared/Reader/SourceView.swift` (font scale only), `App/mdview/Reader/ReaderView.swift` (menu only), `docs/privacy.md`, `README.md`.

1. **`ReadingSettings`:** `@AppStorage` keys.
   - `reader.textScale`: Double, 0.85 to 1.6, steps of 0.15, default 1.0.
   - `reader.width`: `narrow` 560 / `standard` 680 / `wide` 860; default `standard`.
   - `reader.fontDesign`: `system` / `serif` / `mono`; default `system`.
2. **Rendered:** `.textual.fontScale(textScale)`, `.fontDesign(.serif / .monospaced)` (check that Textual fragments pick it up; if not, use `.font(.system(.body, design:))`), `frame(maxWidth: width)`. Code blocks stay monospaced.
3. **Source:** multiply the scaled font size by `textScale`.
4. **Reader menu:** a "Text" submenu with Smaller / Larger / Reset (identifiers `reader.text.smaller`, `.larger`, `.reset`), a Width picker and a Font picker.
5. Dynamic Type still applies on top. The scale multiplies; it does not replace it.
6. **Docs:** list the three keys in `docs/privacy.md` and the README privacy section (on device only, `CA92.1`).

Test approach: `make test`, `make lint`, plus a CI UI test in `App/mdviewUITests/ReadingSettingsTests.swift`: tap Larger twice, then assert a heading's frame height grew.

### V6 Remember reading position per file

Size M, P2, model sonnet, depends on V5.

Owns: `Packages/MDCore/Sources/MDCore/ReadingPositionStore.swift` and its test, `App/Shared/Reader/RenderedView.swift` (scroll position only), `App/mdview/Reader/ReaderView.swift` (key wiring only), `docs/privacy.md`.

1. **`ReadingPositionStore`:**
   - Built with `KeyValueStorage` (protocol with `data(forKey:)` / `set(_:forKey:)`; the app adapts `UserDefaults`, tests use an in-memory one).
   - `position(for path: String) -> Double?` and `record(_ fraction: Double, for path: String, at date: Date)`.
   - Key = SHA-256 hex of the standardized path (CryptoKit is available in MDCore on macOS 15 / iOS 18; if not, use a `Foundation`-only hash and note it). Stores `[key: (fraction, lastUsed)]` as JSON under `reader.positions`.
   - Prunes to the 200 most recent entries.
   - Fractions are clamped to 0...1. Nothing is recorded below 0.02.
2. **`RenderedView`:**
   - Read the offset with `.onScrollGeometryChange(for: Double.self)` as offset / (contentHeight − containerHeight), debounced to 1 s.
   - Restore once, after the first content-size change, with `ScrollPosition` (`scrollTo(y:)`).
   - Only for documents with a `fileURL` (not paste, not the extension).
   - Source view does not restore (it keeps its own offset during a session).
3. **Privacy:** `docs/privacy.md` says scroll positions are kept on the device for the 200 most recent files, keyed by a hash of the path, and removed with the app.

Test approach: `swift test` (record/restore, clamping, pruning at 201, hash stable across runs, path standardization of `/a/../b.md`), `make test`, `make lint`.

### V7 Export to PDF and print

Size L, P2, model opus, depends on V6.

Owns: `Packages/MDCore/Sources/MDCore/PageSlicer.swift` and its test, `App/mdview/Export/PDFExporter.swift` (new), `App/mdview/Export/ExportMenu.swift` (new), `App/mdview/Reader/ReaderView.swift` (menu only).

1. **`PageSlicer.slices(contentHeight:pageHeight:) -> [ClosedRange<Double>]`:** full pages plus the remainder; no empty last page; zero content means one empty page.
2. **`PDFExporter.render(markdown:baseDirectory:pageSize:) async -> Data`:**
   - Builds a `RenderedView`-equivalent `StructuredText` with `ReaderStyle`, light appearance, text selection disabled, fixed width = page width − 2 × 36 pt margins.
   - Loads local images synchronously first with a render-only attachment loader that reads files up front.
   - Waits one run-loop turn plus 0.3 s for the highlighter.
   - Renders with `ImageRenderer.render { size, draw in … }` into a `CGContext` PDF, one page per `PageSlicer` slice, translating the context for each.
   - Page size: Letter for US/CA/MX locale regions, A4 elsewhere.
3. **Menu items:**
   - "Export PDF" (`reader.export.pdf`): a `ShareLink` with a `Transferable` that exports `UTType.pdf`, named `<file name>.pdf`.
   - "Print" (`reader.print`): `UIPrintInteractionController` with `printingItem` = the PDF data, presented from the scene.
   - Show a progress view while rendering.
4. **Limits:** documents over 1 MB show "Too long to export" (avoid memory spikes).
5. Remote images stay links in the PDF (the pipeline already does this).

Test approach: `swift test` (PageSlicer: exact multiple, remainder, tiny content, zero), `make test`, `make lint`. CI UI test `ExportTests`: the export menu item exists and is enabled for `kitchenSink`. The device check (output quality) is in V11.

### V8 Add an optional math rendering toggle

Size S, P2, model sonnet, depends on V7.

Owns: `Packages/MDCore/Sources/MDCore/MathDelimiters.swift` and its test, `Packages/MDCore/Sources/MDCore/RenderPipeline.swift` (math branch), `App/Shared/Reader/RenderedView.swift` (syntax extension only), `App/mdview/Reader/ReaderView.swift` (menu toggle only), `THIRD_PARTY_NOTICES.md`, `README.md`, `docs/privacy.md`.

1. Add the toggle "Math (LaTeX)" (`settings.math`, `@AppStorage("reader.math")`), **default off**: `$5 and $10` would otherwise render as math.
2. When on: `RenderPipeline.prepare(…, math: true)` runs `MathDelimiters`. `\(x\)` becomes `$x$` and `\[x\]` becomes `$$x$$`, skipping fenced code and inline code spans. Foundation's parser would otherwise eat the backslashes.
3. `StructuredText(markdown:syntaxExtensions: math ? [.math] : [])`.
4. Update `THIRD_PARTY_NOTICES.md` (the "does not turn on math" sentence).

Test approach: `swift test` (inline and block conversion, code fences and spans untouched, escaped `\\(` untouched, off means identity), `make test`, `make lint`.

### V9 Add iPad keyboard shortcuts

Size S, P2, model sonnet, depends on V8.

Owns: `App/mdview/Reader/ReaderView.swift` (`.keyboardShortcut` modifiers and commands only), `App/mdview/mdviewApp.swift` (`.commands` only), `docs/support.md`.

Shortcuts:
- ⌘1 Rendered, ⌘2 Source (only when the picker shows).
- ⇧⌘O Outline.
- ⌘+ / ⌘− / ⌘0 text size.
- ⌘P Print.
- ⇧⌘E Export PDF.
- ⌘F focuses Find (use `.searchFocused` if available on iOS 18; otherwise rely on the system's ⌘F for `.searchable` and do not duplicate it).

Use `.commands { CommandMenu("View") { … } }` with focused values (`@FocusedValue` set by `ReaderView`) so the shortcuts show in the iPad ⌘ hold-down overlay. List them in `docs/support.md`.

Test approach: `make test`, `make lint`.

### V10 Update v0.2 docs, version 0.2.0 and screenshots

Size M, P2, model sonnet, depends on V2, V3, V4, V5, V6, V7, V8, V9.

Owns: `project.yml` (versions), `docs/app-store/listing.md`, `docs/support.md`, `docs/privacy.md`, `docs/RELEASE.md`, `README.md`, `docs/ARCHITECTURE.md`, `scripts/screenshots.sh`, `App/mdviewUITests/ScreenshotTests.swift`, `scripts/screenshot-samples/`.

1. **Versions:** `MARKETING_VERSION` "0.2.0", `CURRENT_PROJECT_VERSION` "3" for the app and the extension (K11).
2. **Listing:**
   - Add View in mdview, Outline, copy code, reading settings, reading position, PDF/print, math (optional), keyboard shortcuts.
   - Add "What's New" text (≤ 4000 chars).
   - Recount every character count.
   - Keep "No network access" claims (still true).
3. **Screenshots:**
   - Add `06-outline.png` (outline sheet over `Cedar Trail.md`; add 3+ headings to the sample if needed) and `07-tasks.png` (a sample with a task list and a table; new `scripts/screenshot-samples/Launch Checklist.md`).
   - Extend `ScreenshotTests`, `collect_shots`/`verify_shots` names and the listing's upload order.
   - Do not run the script (human, V11).
4. **`RELEASE.md` checklist:** the Action extension from Messages, Mail, Safari, Grok Bot; outline jump; copy button; settings persist; position restored after relaunch; PDF opens in Files and prints; math toggle; keyboard shortcuts on an iPad keyboard.
5. **Privacy docs:** every new `UserDefaults` key listed; the extension's privacy manifest mentioned; the label is still Data Not Collected.

Test approach: `make lint`, `make test`, character counts in the PR body.

### V11 Device check and ship 0.2.0

Size M, P2, needs_human, no_code, depends on V10.

keving:
1. Merge after CI is green.
2. Run `scripts/screenshots.sh` (one simulator at a time) and commit the screenshots.
3. `make archive && make upload` (automatic signing registers `us.par72.mdview.action` through the API key).
4. Run the v0.2 `RELEASE.md` checklist on the iPhone and iPad, including the Action extension from Grok Bot.
5. Submit 0.2.0.
6. Decide Q4 (Quick Look) based on whether iOS 27.x fixed FB24481377.

## 6. Quality gate

After every bead, from the repo root:

```bash
make test    # swift test --package-path Packages/MDCore, then (from L1) make build-tests: unsigned generic iOS build-for-testing of app, UI tests and (from V2) the extension
make lint    # swiftformat --lint, swiftlint --strict (no_networking, use_motion_helper from L5), then (from L1) python3 scripts/check_app_config.py
```

Rules:
- Never run `make test-ios`, `scripts/screenshots.sh`, `make archive` or `make upload` from a bead. Never boot a simulator. Some agent shells export `CI=true`; that does not make `make test-ios` allowed.
- UI tests (`*Tests.swift` under `App/mdviewUITests/`) are compiled by `make test` and run only in GitHub Actions on push.
- Never set `DEVELOPMENT_TEAM` in a tracked file. Never read or edit `.env` files or `Config/Local.xcconfig`.
- Run `make format` only on files the bead changed (`swiftformat <files>`), not the whole tree.
- MDCore stays Foundation-only (CryptoKit allowed in V6 if it builds on macOS 15 and iOS 18).

## 7. Open questions for keving

| # | Question | Recommended default |
| --- | --- | --- |
| Q1 | Allow any network use for "open a link" (`mdview://open?url=` one-time fetch of raw GitHub Markdown)? | **No.** Keep zero network and the "never connects" claim. If links matter later, use Universal Links on a `khgouldy.github.io` user site with the content inside the link fragment (the app still makes no request). |
| Q2 | Can Grok Bot send Markdown as a `.md` file attachment (MIME `text/markdown`) instead of, or as well as, inline text? | **Yes, change the bot.** It makes path 1 (Share → mdview) work in any chat app with a share sheet. It's outside this repo, so file it in the Grok Bot repo. |
| Q3 | Pull the Action extension (V1, V2) into the Nov 10 launch build? | **No.** Ship launch with Paste Markdown and the help screen. Submit 0.2.0 with the extension right after launch, to keep the launch build's review surface small. |
| Q4 | Build the Quick Look preview extension anyway, for iOS 18 to 26 users? | **Not now.** iOS 27 ignores third-party Markdown preview extensions (FB24481377). Revisit if 27.x fixes it. |
| Q5 | Keep the launch version at 0.1.0 (build 2)? | **Yes** (K11). v0.2 ships as 0.2.0 build 3. |
| Q6 | Turn on math rendering by default in v0.2? | **No, off by default.** Dollar amounts would render as math. |
| Q7 | Show "Save to Files" in the pasted reader (mdview then writes a new file the user chose)? | **Yes.** It never changes existing files, so the listing's "never changes them" still holds. |
| Q8 | If iPad drag and drop fails in L12, drop the claim (listing, support, README, help) rather than fix it before launch? | **Yes, drop the claim** for launch and file a v0.2 bead. |
| Q9 | Any localized App Store listings kept only in App Store Connect? | **Assume none.** If they exist, keving copies the L11 listing changes there by hand in L12. |
