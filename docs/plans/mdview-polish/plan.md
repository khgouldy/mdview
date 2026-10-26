# mdview polish: one-tap open, speed, rebrand, accessibility, reader features

Feature slug: `mdview-polish`. Base branch: `main`. Companion file: `beads.json` (same directory). Planned Oct 26, 2026; revised the same day for keving's launch addendum (4:39 PM CT).

The plan has three phases. Each ends at a human stop, and the runner stops at each human bead.

| Phase | Beads | Ships as | Priority | What |
| --- | --- | --- | --- | --- |
| **Must-ship before App Review** | M1 to M10 | 0.1.0 build 2 | P0 | Quality-gate harness; rename to **MdV**; every Markdown and text type declared; shared reader core; the **MdV Share extension** (one tap from Grok Bot's share sheet, rendered in place); share-sheet UI tests; speed budget, measurement and fixes; a new icon (3 directions, then wiring) |
| **Launch polish** | L1 to L10 | 0.1.0 build 2 | P1 | Accessibility (contrast, VoiceOver, tables, Dynamic Type, Differentiate Without Color, Reduce Motion), task lists, a How to Open Files guide, Paste Markdown, audits, docs, then **L10: keving's device check and submission** |
| **v0.2** | V1 to V9 | 0.2.0 build 3 | P2 | Outline, copy code, reading settings, reading position, PDF/print, optional math, iPad shortcuts, docs, then **V9: ship** |

On-device AI (Foundation Models) is ranked in 3.9 as a v0.3 idea and is not a bead yet.

**Cut line.** Submission is due by **Fri Nov 6** for the Tue Nov 10 launch. If the runner is behind on Nov 5, keving runs L10 with M1 to M10 plus L9 (docs and listing) done. Any unfinished L bead moves to 0.1.1 (D10).

## 1. Goal and non-goals

**Goal.**
- A Markdown or text file shared from any app (Grok Bot first) opens in one tap and renders fast.
- The app launches under a capitalized name (**MdV**) with a new icon.
- Accessibility passes an audit.
- Afterwards, a small set of reader features ships in 0.2.0.

All of it stays offline, collects nothing, and uses Apple frameworks plus the Textual 0.5.0 already shipping.

**Non-goals:**
- Editing, sync, accounts, analytics and ads.
- A Mac app.
- In-app network access (D1).
- New Swift packages (3.7).
- A custom Markdown renderer, Mermaid, and folder/vault browsing.
- Spotlight, widgets and Handoff.
- Changing the bundle ID (`us.par72.mdview`, which can't change after upload) or the repo name.

## 2. Current state

On `main` today: v0.1.0 build 1. keving has installed it from TestFlight. Its App Store record is named "mdview: Markdown Reader" because "mdview" was taken.

**What keving saw (addendum):** when Grok Bot shares an `.md` file, the share sheet labels it **"Text Document"**, and mdview appears neither in the app row nor under More. The header text points to an item provider carrying `public.plain-text` (or `public.utf8-plain-text`) **data or text without a file URL or file name**. The share sheet's app row lists two kinds of apps:
- (a) apps with a **Share extension** whose activation rule matches the item;
- (b) "Open in" / "Copy to" targets, but only for **file URLs** whose type matches `CFBundleDocumentTypes`.

mdview has no extension, and the item is not a file URL, so neither kind applies. Document types alone can't fix this. M5 can.

| Area | File | Notes |
| --- | --- | --- |
| Scene | `App/mdview/mdviewApp.swift` | `DocumentGroup(viewing: TextDocument.self)`. No launch-scene customization. `App.init` arms the DEBUG screenshot harness only. |
| Document | `App/mdview/TextDocument.swift` | Read-only `FileDocument`, readable `net.daringfireball.markdown` and `public.plain-text`. `init(text:contentType:)` exists only in DEBUG. |
| Reader | `App/mdview/Reader/ReaderView.swift` | Rendered / Source segmented picker in the bottom bar, reader menu (Obsidian toggle), `.searchable` find. `findMatches` is a computed property that re-runs `TextSearch` over the whole text **on every access** (4+ times per body pass). Markdown detection hard-codes `md`, `markdown`, `mdown`. |
| Rendering | `App/mdview/Reader/RenderedView.swift` | Textual `StructuredText`, `.gitHub` style, selection enabled, 680 pt column. `markdownForDisplay` re-runs both preprocessors on every body pass. Textual parses synchronously on the main actor in `onChange(of: markup, initial: true)` and lays out every block eagerly (no lazy stack). |
| Source / find | `App/mdview/Reader/SourceView.swift` | `UITextView`. Find highlights differ only by yellow intensity. |
| Images | `App/mdview/Reader/LocalImageLoader.swift` | Local files only via `MDCore.ImagePolicy`. |
| DEBUG harness | `App/mdview/ScreenshotLaunch.swift` | Opens a reader over the document browser from `MDVIEW_SCREENSHOT_*` env. UI tests reuse it. |
| Accent | `App/mdview/Assets.xcassets/AccentColor.colorset/Contents.json` | One universal #2E6B4A; 2.69:1 on #1C1C1E (dark bars). |
| Icon | `App/mdview/Assets.xcassets/AppIcon.appiconset/` and `scripts/generate_app_icon.py` | One 1024 PNG (stdlib Python generator); no dark or tinted variant. |
| Info.plist | `App/mdview/Info.plist` | `CFBundleDisplayName` mdview; Markdown doc type `Owner`, plain text `Alternate`; imported UTI with `md`/`markdown`/`mdown`; `LSSupportsOpeningDocumentsInPlace`; no `UIFileSharingEnabled`. |
| Logic | `Packages/MDCore` | Foundation only, `swift test` on the Mac: `TextDecoding`, `RemoteImages`, `ImagePolicy`, `ObsidianPreprocessor`, `TextSearch`. |
| UI tests | `App/mdviewUITests/` | `LaunchTests` (CI), `ScreenshotTests` (only via `scripts/screenshots.sh`). `make test` does **not** compile this target today. |
| Gate | `Makefile`, `.swiftlint.yml`, `.github/workflows/ci.yml` | `make test` = MDCore `swift test` + unsigned generic iOS build. `make lint` = swiftformat + swiftlint strict with the `no_networking` rule. Simulator tests run only in CI (Xcode 26.6, iOS 26 simulator). |
| Docs | `docs/app-store/listing.md`, `docs/RELEASE.md`, `docs/support.md`, `docs/privacy.md`, `docs/index.md`, `README.md`, `docs/ARCHITECTURE.md` | The listing still says "task lists", which render as plain text, and claims iPad drag and drop, which isn't verified. There are no localized listings in the repo. |

What Textual 0.5.0 gives us (read from its source at tag 0.5.0):

- **No accessibility code.**
- **Pluggable public styles:** `HeadingStyle`, `ListItemStyle`, `UnorderedListMarker`, `OrderedListMarker`, `TableStyle`, `TableCellStyle` (has `row`, `column`) and `CodeBlockStyle` (has `codeBlock.copyToPasteboard()` and `languageHint`), bundled by `StructuredText.Style`.
- **Horizontal scrolling:** `Overflow { }` is the public horizontal-scroll container (a bare horizontal `ScrollView` breaks selection). `GitHubTableStyle` doesn't use it.
- **Heading ids:** each heading gets `.id(slug)` (characters lowercased, whitespace to `-`, keep letters, digits and `-`, collapse dashes).
- **Parsing:**
  - `StructuredText(_ markup:, parser: any MarkupParser)` is public, so mdview can supply a parser that returns a **pre-parsed** `AttributedString`.
  - Parsing is Foundation's `AttributedString(markdown:)`, which has no task lists and no outside `SyntaxExtension`s.
  - `.math` matches `$…$` and `$$…$$`.
- **Selection:** `.textual.textSelection(.disabled)` exists.
- **Extension-safe:** no `UIApplication`; its only `URLSession` is the URL image loader mdview never installs.

## 3. Design

### 3.1 How a user opens a Markdown file shared from a chat app

iOS has no user-selectable default app per file type. These are the paths after this plan, best first:

| # | User action | Works when the host app… | mdview controls | Phase |
| --- | --- | --- | --- | --- |
| 1 | Share, then tap **MdV** in the app row. It renders in place, Rendered and Source, with no app switch. | has a share sheet. The item can be text, plain-text or Markdown data with no name (Grok Bot's "Text Document"), or a file URL. | Share extension (M5) and its activation rule. The first time, MdV may sit under **More**; add it to Favorites once (the help screen says how) and later shares are one tap. | **Must-ship** |
| 2 | Share, then tap **MdV** as an "Open in" target, which opens the main app | shares a **file URL** with a Markdown or text extension | Document types (M3) | Must-ship (widened) |
| 3 | Copy, open MdV, tap **Paste Markdown** | allows copying | Everything (L7); `PasteButton` shows no paste alert | Launch |
| 4 | Save to Files, then open in MdV | offers Save to Files | Document types (M3) | Exists |
| 5 | A rendered preview inside the chat app | uses `QLPreviewController`, **and** the device runs iOS 26 or earlier | A Quick Look extension. On iOS 27 Quick Look no longer calls third-party extensions for `net.daringfireball.markdown` (Apple forums 843292, FB24481377), so Share → MdV (path 1) from the Quick Look toolbar is the route. | Deferred (3.9) |
| 6 | Tap a link | linkifies custom schemes or Universal Links | URL scheme / Universal Links | Deferred (D1) |

**Fully mdview-controlled:** path 1 (needs only a share sheet), path 3, and the reader.
**Host-dependent:**
- Path 2 needs a file URL.
- Path 5 needs Quick Look, and the OS must call the extension.
- Path 6 needs the host to linkify.

**Grok Bot.**
- Path 1 is built to match exactly what keving saw. The **Debug** build of the extension also activates for any `public.data` item and shows a "What was shared" panel listing the registered type identifiers and suggested name. If MdV still isn't offered in Release, keving installs a Debug build from Xcode, shares from Grok Bot, and reads off the types; that answers why in one try (M5, L10).
- If keving controls Grok Bot's sharing code, sharing a **file URL named `*.md`** also enables path 2 (D2). That change is outside this repo.

### 3.2 Inline render vs hand-off (decision K7)

The extension **renders inline**. Text over the size limit is refused with a message.

- It's fastest: no app switch and no second launch.
- It needs no new capability.
- It works on every iOS version.

Rejected for launch:
- **Hand-off by URL scheme:** a Share extension has no supported API to open its containing app. `extensionContext.open` works only in widgets and iMessage, and responder-chain hacks get rejected.
- **Hand-off by App Group** (write the file into a shared container, then tell the user to open the app): adds an App Group entitlement and a second step for the user. It's kept as a later "Keep in MdV" button (D11).

**Share extension, not Action extension.** For a text item, only Share extensions appear in the **app row**; Action extensions sit in the list below, which is more taps and was missed in the test. The Action extension idea from the first plan revision is dropped.

### 3.3 Speed budget and measurement

| Scenario (iPhone 15 Pro or newer, release build) | Budget |
| --- | --- |
| Cold start, from tapping a typical note (≤ 20 KB, ~300 lines, 3 code blocks) to the first rendered screen | **< 500 ms** |
| Warm open of the same note | < 250 ms |
| Share extension: from tapping MdV in the share sheet to the first rendered screen | **< 400 ms**, and resident memory < 60 MB |
| 1 MB file: first screen | < 1.5 s, and no main-thread stall over 100 ms |
| Typing in Find on a 1 MB file | No dropped frames; the count updates within 200 ms of the last keystroke |

**Measurement method:**

1. **Signposts.** `OSSignposter(subsystem: "us.par72.mdview", category: "Performance")` intervals `decode`, `prepare`, `parse` and `layout`, plus an event `firstRender` emitted from the first `onGeometryChange` of the rendered content with a non-zero height.
   - App: the open-to-render interval starts in `ReaderView.task`; launch time before that comes from `XCTApplicationLaunchMetric`.
   - Extension: the interval starts in `viewDidLoad`.
2. **DEBUG console line.** With `MDVIEW_PERF_LOG=1`, a `Logger` prints `perf open=<ms> decode=<ms> prepare=<ms> parse=<ms> layout=<ms> bytes=<n>`.
3. **MDCore performance tests** (`swift test`, every bead): `TextDecoding`, `RenderPipeline.prepare`, `TextSearch` and `SectionSplitter` on generated 20 KB and 1 MB fixtures. Hard budgets are 3× the medians M7 measures on the CI Mac, so a quadratic regression fails and noise doesn't.
4. **CI UI performance test**, `PerformanceTests`: `XCTApplicationLaunchMetric` plus `XCTOSSignpostMetric` for `firstRender` on the 20 KB fixture. It reports results and fails only above 3× budget, because simulators aren't representative.
5. **On device (L10, human):** Instruments "App Launch" and "os_signpost" templates on keving's phone with `docs/perf/fixtures/` (20 KB, 200 KB, 1 MB). The results go into `docs/perf/README.md`.

**Design for speed (M8):**
- **Pre-parse off the main actor.** Decode, `RenderPipeline.prepare` and `AttributedString(markdown:)` run in a detached task. `StructuredText` then gets a `PreparsedParser: MarkupParser` that returns the cached `AttributedString` immediately (Textual's synchronous main-actor parse becomes a dictionary lookup).
- **Cache by content.** Find matches are stored in `@State` and recomputed only when the query changes (debounced 150 ms) or the text changes.
- **Lazy rendering for large files.**
  - Above 64 KB, MDCore `SectionSplitter` cuts the prepared Markdown at top-level ATX headings outside code fences.
  - `RenderedView` renders each section as its own `StructuredText` inside a `LazyVStack`, with id `section-<n>`.
  - Lists and tables are never split, because the cuts happen only at headings.
  - Selection can't cross a section boundary on these large files only; that is accepted.
- **Very large files.** Above 2 MB the reader opens in Source with a "Large file. Render anyway" bar.
- **The extension stays light.** It links the same shared code and loads nothing else. It makes no `UserDefaults` writes, has no launch screen, and does no work before `viewDidLoad`. Prism highlighting starts only when a code block renders (Textual is lazy here; M7 confirms with signposts).
- **No work in `App.init`** beyond the DEBUG harness. No animation on first render.

### 3.4 Rename (MdV) and icon

**Names** (N1). The store name must be unique across the App Store; ≤ 30 characters. A 2026-10-26 search found no app named MdV; "Midea MDV" (an HVAC remote) and "MDView: Markdown Viewer" exist. Only App Store Connect's rename is the final check.

| # | Home-screen name | App Store name (chars) | Notes |
| --- | --- | --- | --- |
| 1 | **MdV** | **MdV: Markdown Viewer** (20) | **Recommended.** keving's suggestion, 3 letters, reads as "Markdown Viewer". VoiceOver says "M D V". |
| 2 | MDV | MDV: Markdown Viewer (20) | Reads like an acronym (DMV, Midea MDV) |
| 3 | Mdown | Mdown: Markdown Viewer (22) | Nods to the `.mdown` extension; looks lowercase-ish |
| 4 | Markd | Markd: Markdown Reader (22) | Short word mark; "marked" pun |
| 5 | Marky | Marky: Markdown Viewer (22) | Friendly; less serious |
| 6 | Margin | Margin: Markdown Reader (23) | A reading word; generic, likely taken |
| 7 | Inkdown | Inkdown: Markdown Reader (24) | Distinctive; not obviously "md" |
| 8 | Downmark | Downmark: Markdown Reader (25) | Inverts "Markdown"; long on the home screen |

Rejected: MDView / MdView (clashes with "MDView: Markdown Viewer").

**What changes:**
- `CFBundleDisplayName`, from one build setting `APP_DISPLAY_NAME` in `project.yml`, read by both targets.
- The Share extension's display name (shown under its icon in the app row): `$(APP_DISPLAY_NAME)`.
- In-app strings, through one `AppName.display`, which reads the bundle's display name.
- The App Store name, set by keving in App Store Connect in L10.
- `listing.md`, `support.md`, `privacy.md`, `index.md`, the README product prose, `RELEASE.md` and `ARCHITECTURE.md`. Screenshots are regenerated in L10; they show the launch-screen title.

**What does not change:** the bundle IDs (`us.par72.mdview`, `us.par72.mdview.share`), the repo name, the Xcode project, target, scheme and `PRODUCT_NAME` (`mdview`, the module name and not user-visible), and the `mdview` names in file paths and identifiers.

**Icon directions** (N2). All are generated by `scripts/generate_app_icon.py` (stdlib Python, deterministic, no fonts: every glyph is a vector path). The script writes matching SVG and PNG.

| Direction | Concept | Light (any) | Dark | Tinted |
| --- | --- | --- | --- | --- |
| **A, "Folded page"** (recommended) | A white page with a dog-ear carrying the bold Markdown mark (an "M" and a down arrow, after the CC0 markdown-mark) | Deep-green squircle gradient #2E6B4A → #1F4A33, white page, green mark | The page and mark in #5BBF8A / #E8F5EE on a transparent background (iOS 18 dark template) | Grayscale page and mark on transparent |
| B, "MdV monogram" | Geometric "MdV" letterforms; the V's point extends into a down arrow | White letters on the green gradient | Green letters on transparent | Grayscale |
| C, "Reading lines" | A rounded card with a heading bar, three text lines and a checked box | Green shapes on an off-white #F4F1EA card over green | Light shapes on transparent | Grayscale |

Rules for every direction:
- 1024 × 1024 sRGB; the light ("any") image has no alpha (an App Store requirement). No rounded corners baked in.
- Nothing finer than 24 px at 1024.
- Readable at 40 px (Spotlight). M9 renders a contact sheet at 1024, 180, 120, 87, 58 and 40 px in all three appearances.
- One 1024 image per appearance in a single-size `AppIcon.appiconset`: Xcode generates every device size, which covers "all sizes".
- Icon Composer (`.icon`, Liquid Glass layers) can come later. The asset-catalog icon renders correctly on iOS 18 to 27.

### 3.5 Components and contracts

Names here are contracts later beads rely on. Don't rename them.

**MDCore (Foundation only; `swift test`):**

| Type | Contract | Bead |
| --- | --- | --- |
| `MarkdownFileTypes` | `markdownExtensions` = `md, markdown, mdown, mkd, mkdn, mdwn, mdtxt, mdtext`; `plainTextExtensions` = `txt, text`; `markdownMIMETypes` = `text/markdown, text/x-markdown`; `isMarkdown(pathExtension:) -> Bool?`. The literals sit between `// BEGIN markdownExtensions` / `// END markdownExtensions`. | M3 |
| `SharedItemSelection` | `static func pick(_ candidates: [SharedCandidate]) -> SharedCandidate?`, where `SharedCandidate` = (index, registered type identifiers, suggested name, `isFileURL`). The type to load comes first by rank: `net.daringfireball.markdown` > `public.plain-text` conformers > `public.text` > `public.file-url` > `public.data`. Returns which UTI to load. `UTType` conformance is passed in as a closure, so MDCore stays Foundation-only. | M5 |
| `SharedContent` | `title(suggestedName:)` ("Shared Text" when nil); `isMarkdown(suggestedName:)` (nil → true); `limitBytes` = 5 000 000; `sourceOnlyAboveBytes` = 2 000 000; `looksBinary(_ data: Data) -> Bool` (a NUL byte in the first 8 KB); the messages. | M5 |
| `RenderPipeline` | `static func prepare(_ markdown: String, obsidian: Bool, math: Bool = false) -> String`. Order: `ObsidianPreprocessor` (if on) → `TaskListPreprocessor` (from L5) → `MathDelimiters` (if `math`, from V6) → `RemoteImages.linkify`. Rendering, the outline, PDF export and the extension all call only this. | M4 (L5 and V6 add steps) |
| `SectionSplitter` | `static func sections(_ markdown: String, minimumBytes: Int = 65_536) -> [String]`. Below `minimumBytes` it returns one element. Above that it cuts before each top-level ATX heading outside fences. Joining the sections reproduces the input exactly. | M8 |
| `PerfFixtures` (test support) | `static func note(bytes: Int) -> String`: deterministic Markdown with headings, lists, a table and code blocks | M7 |
| `TaskListPreprocessor`, `TaskMarker` | Rewrite list-item `[ ]` / `[x]` / `[X]` to `![Not done](x-mdview-task:unchecked)` / `![Done](x-mdview-task:checked)`, skipping code; `TaskMarker.scheme`, `state(for:)` | L5 |
| `FindHighlight` | `styles(matchCount:current:differentiateWithoutColor:) -> [MatchStyle]`, where `MatchStyle` is `fill .soft/.strong`, `underline .none/.dotted/.thick` and `bold` | L4 |
| `HeadingOutline`, `ReadingPositionStore`, `PageSlicer`, `MathDelimiters` | As in the v0.2 beads | V1, V4, V5, V6 |

**App, shared code (`App/Shared/`, compiled into the app and the extension):**

| Piece | Contract | Bead |
| --- | --- | --- |
| `AppName` | `static var display: String`: the bundle's `CFBundleDisplayName`, falling back to `CFBundleName` | M2 |
| `ReaderContext` (environment) | `fileURL: URL?`, `displayName: String?`. Replaces the DEBUG-only `screenshotFileURL`. | M4 |
| `RenderedView`, `SourceView`, `LocalImageLoader`, `ReaderCore` (`ReaderMode`), `Motion` | Moved from `App/mdview` in M4 | M4 |
| `PreparedDocument` | `actor DocumentPreparer` with `prepare(text:obsidian:math:) async -> PreparedDocument`. `PreparedDocument` holds `sections: [AttributedString]`, `isLarge` and `byteCount`. `PreparsedParser: MarkupParser` returns a cached `AttributedString`. | M8 |
| `PerfSignposts` | `PerfSignposts.interval(_ name: StaticString)`, `.event(_:)`, DEBUG `MDVIEW_PERF_LOG` | M7 |
| `ReaderStyle` | The GitHub look plus accessible headings, list items, bullets, scrolling tables and table cells; later the copyable code block | L2, L3, V2 |
| `TaskCheckbox` | Attachment returned by `LocalImageLoader` for `x-mdview-task:` URLs before `ImagePolicy` | L5 |

**Targets:**

| Target | Contract | Bead |
| --- | --- | --- |
| `mdviewShare` (`App/mdviewShare/`) | `app-extension`; `PRODUCT_BUNDLE_IDENTIFIER us.par72.mdview.share` set in **target settings**, which override `Config/Local.xcconfig`; `com.apple.share-services`; display name `$(APP_DISPLAY_NAME)`; `ShareViewController` hosts `SharedReaderView`; own `PrivacyInfo.xcprivacy`; `APPLICATION_EXTENSION_API_ONLY` YES; Debug and Release Info.plists that differ only in the activation rule | M5 |

**Tooling:**

| Piece | Contract | Bead |
| --- | --- | --- |
| `make build-tests` | `xcodebuild build-for-testing -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. `make test` runs it after `swift test`. | M1 |
| `scripts/check_app_config.py` | Stdlib Python, run by `make lint` and `make check-config`, with `--self-test`; one function per check. Later beads add checks: the Markdown list (M3), the extension (M5), icon images (M10), accent contrast (L1). | M1 |
| `ReaderLauncher`, `ReaderFixture` (UI tests) | Launch straight into a reader with a named fixture through the DEBUG harness env | M1 |
| `ShareHarness` (DEBUG, app) | `MDVIEW_SHARE_HARNESS=<case>` presents a `UIActivityViewController` or `QLPreviewController` with a fixture item, so UI tests can drive the real share sheet into the real extension | M6 |
| `make icon ICON=a\|b\|c` | Writes the chosen direction into `AppIcon.appiconset` | M10 |

### 3.6 Data flow

```
file URL / shared item (text, data, file) / pasted text
  └─ (extension) SharedItemSelection.pick → load bytes or String → SharedContent checks
  └─ TextDecoding.decode
       ├─ Source: SourceView(text, FindHighlight styles, cached matches)    ← original text
       └─ Rendered: DocumentPreparer (detached task)
              RenderPipeline.prepare → SectionSplitter → AttributedString(markdown:) per section
              └─ LazyVStack { StructuredText(section, parser: PreparsedParser) + ReaderStyle + LocalImageLoader }
                    (one section for files ≤ 64 KB, so small notes keep full selection)
```

### 3.7 Key decisions

| # | Decision | Rejected alternative and why |
| --- | --- | --- |
| K1 | Accessibility is added around Textual through public styles (`ReaderStyle`). | Forking Textual: more code to own. |
| K2 | Task lists: an MDCore preprocessor plus a `TaskCheckbox` attachment from the existing loader. | Unicode ☐/☑: VoiceOver reads "ballot box" (kept only as a fallback). A Textual `SyntaxExtension`: impossible from outside the package. |
| K3 | While VoiceOver runs, the Rendered view turns Textual's selection overlay off. | Leaving it on: the overlay covers the document with no accessibility properties. |
| K4 | Markdown document type rank **Default**. Plain text **Alternate**. **New: `public.text` Alternate** (RTF and HTML open in Source as raw text). Import `net.daringfireball.markdown`; never export it. | `Owner`: mdview doesn't create the type. `public.data`: MdV would appear for every file, which is noise and a review risk. |
| K5 | `UIFileSharingEnabled` YES, so "Copy to MdV" files in `Documents/Inbox` are visible in Files. | Hidden copies reachable only through Recents |
| K6 | Paste uses `PasteButton` plus an in-memory reader; "Save to Files" uses `.fileExporter`. | Reading `UIPasteboard` on launch: privacy prompt. |
| K7 | **Share extension, inline render, launch-critical** (3.2) | Action extension: not in the app row. URL or App Group hand-off: unsupported, or a new entitlement. |
| K8 | Shared code lives in `App/Shared/`, compiled per target; Textual and MDCore are linked statically into each target. | An embedded framework: extension-API-only settings, rpaths, and duplicate SwiftPM symbol risk. |
| K9 | The Release activation rule matches `public.text` conformers or a `public.file-url`, at most one attachment, never `TRUEPREDICATE`. The Debug rule adds `public.data` for diagnostics. | `public.data` in Release: MdV would show for photos and PDFs. |
| K10 | Large files render as heading sections in a `LazyVStack` above 64 KB, and in Source above 2 MB. | A custom lazy renderer: against D11 ("off the shelf"). Always eager: multi-second stalls on large files. |
| K11 | The launch build is **0.1.0 build 2** (N3). v0.2 ships as 0.2.0 build 3. | 0.2.0 for launch: no user has 0.1.0, so a bump would only add noise. keving may still choose it. |
| K12 | No new Swift packages | Everything is covered by Apple frameworks plus Textual and swiftui-math, which already ship. |
| K13 | The display name comes from one build setting, `APP_DISPLAY_NAME`, plus `AppName.display` in code. | Hard-coded strings: the next rename would be a sweep. |
| K14 | Icons are procedurally generated (stdlib Python); the script also writes matching SVG. | Hand-drawn PNGs: not reproducible by agents. A new tool such as rsvg-convert: an extra dependency. |
| K15 | No Quick Look extension for now | The iOS 27 regression (FB24481377) |

### 3.8 Accessibility conventions (every bead)

- Every interactive control has a label and an identifier (`reader.*`, `launch.*`, `help.*`, `share.*`, `outline.*`).
- Bars scale up or use the Large Content Viewer; nothing truncates without a full-text label.
- Color is never the only signal.
- No `withAnimation` outside `Motion` (lint rule from L4); scroll jumps aren't animated when Reduce Motion is on.
- New UI gets a CI-only UI test and a `performAccessibilityAudit()` call (pattern from L8).

### 3.9 Feature ranking (v0.2 and later)

| Feature | Value | Effort | Set |
| --- | --- | --- | --- |
| Outline (table of contents) | High for long docs | 1 M | v0.2 |
| Copy code button | Medium-high | 1 S | v0.2 |
| Reading settings (size, width, serif/mono) | Medium | 1 M | v0.2 |
| Reading position per file | Medium | 1 M | v0.2 |
| PDF export and print | Medium | 1 L | v0.2 |
| Math (off by default) | Medium for AI output | 1 S | v0.2 |
| iPad keyboard shortcuts | Medium on iPad | 1 S | v0.2 |
| **On-device AI: "Summarize" and "Ask about this file"** (Foundation Models) | **High** (distinctive and private) | 2 (M + L) | **v0.3**, right after 0.2.0 (N6) |
| Quick Look preview extension | Low on iOS 27 (regression) | 1 M | Deferred |
| "Keep in MdV" from the extension (App Group) | Medium | 1 M | Deferred (D11) |
| URL scheme / Universal Links | Low (hosts rarely linkify) | 1 M | Deferred (D1) |
| Relative links, vault browsing, cross-file search | Medium for Obsidian users | 3 L | Deferred |
| Spotlight, App Intents, widget, Handoff | Low | various | Deferred |
| Mermaid | Low; needs a WebView (lint ban) | n/a | Rejected |

**On-device AI design sketch (v0.3, not a bead yet):**

- **Framework.** Apple's Foundation Models framework (iOS 26+; Apple Intelligence devices such as iPhone 15 Pro and later, including iPhone 17; Apple Intelligence turned on in Settings). Use `SystemLanguageModel.default`, the **on-device** model, only. If the framework offers any server-backed or Private Cloud Compute model, mdview never selects it; a lint rule and a review checklist item enforce that. With processing on device, the label stays **Data Not Collected**, and the no-network claims hold.
- **Gating.** `if #available(iOS 26, *)` plus `SystemLanguageModel.default.availability`:
  - `.available`: show "Summarize" (reader menu and a toolbar sparkle) and "Ask about this file" (a sheet with a text field).
  - `.unavailable(.appleIntelligenceNotEnabled)`: a hint to turn it on in Settings.
  - `.modelNotReady`: "Getting ready…".
  - `.deviceNotEligible`: no AI UI at all.
  - Deployment target stays iOS 18.
- **Long documents.** The context window is about 4K tokens. MDCore `TokenChunker` (about 4 characters per token, cut at headings and paragraphs) chunks the input, the app summarizes each chunk, then summarizes the summaries. Output streams with `streamResponse`. The result is labeled "Generated on this iPhone. May be inaccurate." "Ask" answers from the most relevant chunks, chosen by keyword overlap.
- **Testing.** A `DocumentSummarizer` protocol with a fake for unit tests; the real one is exercised only on device. Follow Apple's acceptable-use requirements for the framework; App Review notes explain that it runs on device.
- **Beads when scheduled:** A1 "Summarize with on-device Foundation Models" (M, opus) and A2 "Ask about this file" (L, opus).

## 4. Risks and containment

| Risk | Containment |
| --- | --- |
| The Share extension still isn't offered for Grok Bot's item | The Debug activation rule includes `public.data`, and the extension's "What was shared" panel lists the registered types (M5). The L10 device step reads them; widening the Release rule is then a one-line change. |
| The extension is slow or hits the ~120 MB extension memory limit | 5 MB input cap, Source above 2 MB, sectioned lazy rendering, a 60 MB budget measured in L10 |
| App Review questions a Share extension that only shows content | Its role is "view this shared text in MdV". The review notes describe it. The rule never uses `TRUEPREDICATE`. Fallback: none needed, since Paste works without it. |
| The extension bundle ID inherits `us.par72.mdview` from `Local.xcconfig` | Target-level setting in `project.yml`; `check_app_config.py` asserts every target's bundle ID |
| Driving the share sheet from XCUITest is flaky | `ShareHarness` presents the share sheet inside mdview, so its elements are queryable. Each test falls back to `XCTSkip` with a reason only when the sheet's app row cannot be found, never when MdV is missing from a found row. The device check in L10 is mandatory. |
| Sectioned rendering breaks cross-section selection, or headings' `scrollTo` | Sections apply only above 64 KB, and cuts happen only at headings. The outline (V1) scrolls to section ids when the document is sectioned. |
| Pre-parsing changes rendering versus Textual's own parse | `PreparsedParser` uses the same `AttributedString(markdown:)` default options as Textual's `.markdown()` parser; an M8 UI test compares heading counts. |
| The rename collides in App Store Connect | 8 options (3.4); keving reserves the name in L10. `APP_DISPLAY_NAME` is a one-line change. |
| The icon direction keving picks isn't the default | All three directions are generated in M9; `make icon ICON=b` switches in one command. |
| The iOS 27 launch-scene regression (custom document-creation buttons) affects the help and paste buttons | The same entries also live in the reader menu; L10 checks on iOS 27; a fallback (`overlayAccessoryView`) is pre-written in L6. |
| Textual's selection overlay hides content from VoiceOver | K3 plus the L8 audit and the L10 rotor check |
| A team ID leaks into the repo | `check_app_config.py` fails on a non-empty `DEVELOPMENT_TEAM` in tracked files |
| The launch slips | P0 order, the cut line (top of file), and L10 as a human stop before any V bead |
| `CI=true` shells could run the simulator locally | The gate is only `make test` and `make lint`; UI tests compile locally and run only in GitHub Actions |

## 5. Beads

Every bead:
- runs the section 6 gate and leaves `make test` and `make lint` green;
- never runs `make test-ios` or boots a simulator (UI tests run in GitHub Actions on push);
- uses Conventional Commits with `Agent:` / `Model:` / `Bead:` trailers.

Read `CLAUDE.md`, `docs/DEVELOPMENT.md` and `docs/ARCHITECTURE.md` first. File paths are as of the bead's start: after M4, reader files live in `App/Shared/Reader/`.

### Must-ship before App Review (P0)

### M1 Add UI-test build and app config checks to the quality gate

Size M, P0, model sonnet, depends on nothing.

Owns: `Makefile`, `scripts/check_app_config.py`, `App/mdviewUITests/ReaderLauncher.swift`, `App/mdviewUITests/ReaderFixture.swift`, `App/mdviewUITests/ScreenshotTests.swift`, `docs/DEVELOPMENT.md`, `AGENTS.md`, `CLAUDE.md`.

1. **`make build-tests`:**
   `xcodebuild build-for-testing -project mdview.xcodeproj -scheme mdview -destination 'generic/platform=iOS' -derivedDataPath .derivedData -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO`.
   `make test` = `swift test --package-path Packages/MDCore`, then `$(MAKE) build-tests`. Keep `build-ios`.
2. **`scripts/check_app_config.py`** (Python 3 stdlib):
   - Prints `ok: <check>` lines, or `error:` lines and exits 1. Runs from `make lint` (after swiftlint) and from `make check-config`.
   - One function per check. `--self-test` runs each check against a bad in-memory example and asserts it fails.
   - First checks:
     - (a) No tracked file (`git ls-files`) sets `DEVELOPMENT_TEAM` to a non-empty value.
     - (b) Every `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` is `us.par72.mdview` or starts with `us.par72.mdview.`.
     - (c) Every `PrivacyInfo.xcprivacy` under `App/` has `NSPrivacyTracking` false and empty tracking domains and collected data types.
     - (d) No `Info.plist` under `App/` contains `TRUEPREDICATE`.
3. **UI test helpers:**
   - `ReaderLauncher.app(fixture:scheme:contentSize:query:extraEnvironment:) -> XCUIApplication`, factored out of `ScreenshotSession.makeApp`. It sets `MDVIEW_SCREENSHOT_NAME`, `_MARKDOWN`, `_SCHEME` and `_QUERY`; `contentSize` adds `-UIPreferredContentSizeCategoryName <value>`.
   - `ReaderFixture` has `name` and `markdown`. The `kitchenSink` fixture, named `A very long file name for accessibility checks.md`, contains:
     - H1 "Overview" with a link, H2 "Tasks", H2 "Data", H3 "Code";
     - nested bullets and an ordered list;
     - `- [ ] Draft` and `- [x] Ship`;
     - a 7-column table whose last header is "Owner";
     - a fenced `swift` block starting with `struct`;
     - a block quote.
   - `cedarTrail` and `weeklyReview` are read from the screenshot env as today. `ScreenshotTests` uses `ReaderLauncher` and keeps its five shot names.
4. Document `build-tests`, `check-config` and the new `make test` in `docs/DEVELOPMENT.md` and in the Build & Test sections of `AGENTS.md` and `CLAUDE.md`.

Test approach: `make test`, `make lint`, `python3 scripts/check_app_config.py --self-test`.

### M2 Rename the app to MdV through one display-name setting

Size S, P0, model sonnet, depends on M1.

Owns: `project.yml` (`APP_DISPLAY_NAME` only), `App/mdview/Info.plist` (`CFBundleDisplayName` only), `App/mdview/AppName.swift` (new; moves to `App/Shared/` in M4), user-facing strings under `App/`, `docs/app-store/listing.md` (name sections only), `docs/index.md`, `docs/support.md`, `docs/privacy.md`, `README.md`, `docs/RELEASE.md`, `scripts/check_app_config.py` (name check only).

1. **The name.** `project.yml` `settings.base.APP_DISPLAY_NAME: MdV` (N1). `Info.plist` `CFBundleDisplayName` = `$(APP_DISPLAY_NAME)`. `AppName.display` per 3.5.
2. **In-app strings.** Every user-visible "mdview" in Swift goes through `AppName.display` (today there are none besides the display name; future help and launch text must use it).
3. **Docs.**
   - Product prose uses **MdV**: the page titles "MdV Support" and "MdV Privacy Policy"; the README title "MdV" with "(repo: mdview)".
   - Keep "mdview" for the repo, bundle IDs, paths, the scheme and commands.
   - `listing.md`: App name **MdV: Markdown Viewer** (20/30). Record the 3.4 options table and the Oct 26 search result. Note that App Store Connect confirms availability. Keep the bundle ID and SKU `mdview`.
   - `privacy.md` keeps the bundle ID line.
4. **`check_app_config.py` `check_display_name`:** `Info.plist` uses `$(APP_DISPLAY_NAME)`; `project.yml` defines it; `listing.md`'s "App name" heading starts with the same value.

Edge case: `CFBundleName` stays `$(PRODUCT_NAME)` (mdview), which Spotlight may show as a secondary name. That's acceptable.

Test approach: `make lint` (name check), `make test`. `grep -rn 'mdview' docs/support.md docs/privacy.md docs/index.md` shows only bundle IDs, URLs and repo mentions.

### M3 Declare every Markdown and text type, widen to public.text, expose Documents

Size S, P0, model sonnet, depends on M1.

Owns: `Packages/MDCore/Sources/MDCore/MarkdownFileTypes.swift` and its test, `App/mdview/Info.plist` (document types and UTIs), `App/mdview/TextDocument.swift` (readable types only), `App/mdview/Reader/ReaderView.swift` (`showsModePicker` only), `scripts/check_app_config.py` (type check only).

1. **`MarkdownFileTypes`** per 3.5. `ReaderView.showsModePicker` uses `isMarkdown(pathExtension:)` (nil falls back to `document.allowsRenderedMode`).
2. **`Info.plist`:**
   - Imported `net.daringfireball.markdown` lists all 8 extensions and an array of both MIME types; it conforms to `public.plain-text`.
   - `CFBundleDocumentTypes`:
     - Markdown, `LSHandlerRank Default`;
     - Plain Text (`public.plain-text`), `Alternate`;
     - **Text (`public.text`), `Alternate`** (K4).
   - Add `UIFileSharingEnabled` YES; keep `LSSupportsOpeningDocumentsInPlace` YES.
3. **`TextDocument.readableContentTypes`** = `[.markdown, .plainText, .text]`. Non-plain text (RTF, HTML) shows in Source only: `allowsRenderedMode` stays true only for Markdown.
4. **`check_markdown_types`:** the plist's extensions equal the literals between the markers; the three document types exist with the expected ranks; both Boolean keys are true.

Edge cases:
- Uppercase `README.MD` (`isMarkdown` lowercases).
- `.txt` stays Source-only.
- An `.rtf` file opens in Source as raw text.
- Never export the UTI; don't invent `public.markdown`.

Test approach: `swift test` (each extension, uppercase, txt, unknown → nil), `make lint`, `make test`.

### M4 Move the reader core into App/Shared and add RenderPipeline

Size M, P0, model sonnet, depends on M2, M3.

Owns: `App/Shared/` (new), `App/mdview/Reader/`, `App/mdview/AppName.swift`, `App/mdview/Motion.swift` (if present), `App/mdview/ScreenshotLaunch.swift`, `Packages/MDCore/Sources/MDCore/RenderPipeline.swift` and its test, `project.yml` (app sources only), `scripts/check_app_config.py` (shared-code check), `docs/ARCHITECTURE.md`.

1. **Move** to `App/Shared/Reader/` with no behavior change: `RenderedView`, `SourceView`, `LocalImageLoader`, and a new `ReaderCore.swift` (`ReaderMode`). Move `AppName.swift` to `App/Shared/`. `ReaderView` stays in `App/mdview/Reader/`.
2. **`ReaderContext`** environment (`fileURL`, `displayName`) in `App/Shared/Reader/ReaderContext.swift`. `ReaderView` reads it before `documentConfiguration`. The DEBUG `screenshotFileURL` is replaced by it, and the screenshot harness keeps working.
3. **MDCore `RenderPipeline.prepare(_:obsidian:math:)`:** today it runs Obsidian (if on), then `RemoteImages`; `math` is ignored until V6. `RenderedView` calls only it.
4. **`project.yml`:** app target sources = `App/mdview` and `App/Shared`.
5. **`check_app_config.py` `check_shared_extension_safe`:** no file under `App/Shared/` contains `UIApplication.shared`.

Test approach: `swift test` (pipeline: Obsidian on and off, remote image linkified in both), `make test`, `make lint`. `git diff -M --stat` shows renames.

### M5 Add the MdV Share extension that renders shared Markdown and text in place

Size L, P0, model opus, depends on M4.

Owns: `App/mdviewShare/` (new: `ShareViewController.swift`, `SharedReaderView.swift`, `SharedItemLoader.swift`, `Info.plist`, `Info-Debug.plist`, `PrivacyInfo.xcprivacy`), `Packages/MDCore/Sources/MDCore/SharedItemSelection.swift`, `Packages/MDCore/Sources/MDCore/SharedContent.swift` and their tests, `project.yml` (new target and embed), `scripts/check_app_config.py` (extension checks), `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`.

1. **Target `mdviewShare`** in `project.yml`:
   - `type: app-extension`, iOS 18.
   - Sources `App/mdviewShare` and `App/Shared`; packages Textual and MDCore.
   - Target settings: `PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview.share`, `GENERATE_INFOPLIST_FILE: NO`, `APPLICATION_EXTENSION_API_ONLY: YES`, and the app's `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
   - Per-config `INFOPLIST_FILE`: Debug `App/mdviewShare/Info-Debug.plist`, Release `App/mdviewShare/Info.plist`.
   - `configFiles` use `Config/Local.xcconfig` (team only; the target setting wins for the bundle ID).
   - The app target embeds it (`- target: mdviewShare`). No App Group (K7).
2. **`Info.plist`:**
   - `CFBundleDisplayName` = `$(APP_DISPLAY_NAME)`.
   - `NSExtensionPointIdentifier` `com.apple.share-services`; `NSExtensionPrincipalClass` `$(PRODUCT_MODULE_NAME).ShareViewController`.
   - Release `NSExtensionActivationRule` (K9):
     ```
     SUBQUERY(extensionItems, $item, SUBQUERY($item.attachments, $a, ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.text" OR ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.file-url").@count == 1).@count == 1
     ```
     `public.plain-text`, `public.utf8-plain-text` and `net.daringfireball.markdown` all conform to `public.text`.
   - `Info-Debug.plist` is identical except the rule also accepts `UTI-CONFORMS-TO "public.data"`.
3. **`PrivacyInfo.xcprivacy`:** a copy of the app's (UserDefaults `CA92.1`, because `@AppStorage("obsidian.enabled")` is read in the extension's own domain).
4. **MDCore `SharedItemSelection` and `SharedContent`** per 3.5.
5. **`SharedItemLoader`:**
   - For each attachment, build a `SharedCandidate` with conformance from `UTType`, then `pick`.
   - Load the picked type: prefer `loadFileRepresentation(for:)`, copying the bytes inside the callback and keeping `suggestedName`. Otherwise `loadDataRepresentation`, then `loadItem` as `String`, `Data` or a file `URL` (read with security scope).
   - Check `limitBytes` and `looksBinary`, then decode with `TextDecoding`.
   - All of it is off the main actor.
6. **`ShareViewController`:**
   - `viewDidLoad` immediately installs `UIHostingController(rootView: SharedReaderView(state:))` showing the title and a progress view, then starts loading. Respect the host's trait collection.
   - Requests `preferredContentSize` full height (`modalPresentationStyle` as the system allows).
7. **`SharedReaderView`:**
   - A `NavigationStack` with the title from `SharedContent.title`.
   - A Rendered / Source segmented picker (Markdown only), using the same `RenderedView` / `SourceView`; Source above `sourceOnlyAboveBytes`.
   - Done (`share.done`) calls `completeRequest(returningItems: [])`. An error state shows the message and Done.
   - An info button (`share.info`) shows **What was shared**: the registered type identifiers of each attachment, the suggested name and the byte count. It reads nothing else and stores nothing; it's shown in Release too (useful for support).
   - Signposts from M7 are added later; leave a `// PerfSignposts` hook comment.
8. **`check_app_config.py` `check_share_extension`:**
   - The point identifier is right.
   - The Release rule has no `public.data` and no `TRUEPREDICATE`.
   - The Debug and Release plists are equal except `NSExtensionActivationRule`.
   - A `PrivacyInfo.xcprivacy` is present.
   - The bundle ID is `us.par72.mdview.share`.
   - No `UIApplication.shared`, `URLSession` or `extensionContext?.open` under `App/mdviewShare`.

Edge cases:
- Several attachments: pick the best one.
- An RTF item conforms to `public.text`: decode it as text and show it in Source.
- A `public.file-url` to a PDF: `looksBinary` → "MdV shows Markdown and text files."
- An empty string: "Nothing to show."
- Shared text over 5 MB: refused with a message.
- Dark mode and Dynamic Type follow the host.

Test approach: `swift test` (pick ranking for: markdown + plain; utf8 plain only, the "Text Document" case; file-url only; data only, which is nil in Release terms unless the caller allows data; title with a nil name and with `notes.md`; binary sniff; the limits), `make test` (builds the extension unsigned), `make lint`. The UI tests are M6.

### M6 Add share-sheet UI tests for chat-app style items

Size M, P0, model sonnet, depends on M5.

Owns: `App/mdview/Debug/ShareHarness.swift` (new, `#if DEBUG`), `App/mdview/mdviewApp.swift` (arm the harness only), `App/mdviewUITests/ShareSheetTests.swift` (new), `App/mdviewUITests/ReaderFixture.swift` (share fixtures only), `docs/DEVELOPMENT.md`.

1. **`ShareHarness`** (DEBUG only, armed like `ScreenshotOpener` when `MDVIEW_SHARE_HARNESS` is set):
   - Shows a single button `harness.share` that presents one case:
     - `text`: `UIActivityViewController(activityItems: [markdownString])`;
     - `textDocument`: an `NSItemProvider` registering only `public.utf8-plain-text` **data** with no suggested name (keving's "Text Document" case);
     - `fileMarkdown`: a file URL `Shared Note.md` written to `tmp`;
     - `fileText`: a `notes.txt` file URL;
     - `quickLook`: a `QLPreviewController` showing `Shared Note.md` (as chat apps' attachment previews do). The test taps its share button.
   - The fixture content comes from `MDVIEW_SHARE_MARKDOWN` (UI test env), defaulting to `# Shared heading\n\n- [x] done`.
2. **`ShareSheetTests`** (CI only), one test per case:
   - Launch with the case, tap `harness.share` (and, for `quickLook`, the preview's share button).
   - Find the share sheet's app row and the **MdV** item there or under More. Tap it.
   - Assert "Shared heading" appears in the extension UI (query through the app and, if needed, `XCUIApplication(bundleIdentifier: "com.apple.springboard")`). Tap `share.done`.
   - If the share sheet's app row can't be found at all, `XCTSkip` with the query used. If the row is found but MdV is missing, **fail**.
   - For `fileMarkdown`, also assert that MdV's "Open in" / "Copy to MdV" target exists (path 2).
3. **`docs/DEVELOPMENT.md`:** how to run the harness by hand on a device from Xcode (`MDVIEW_SHARE_HARNESS=textDocument` in the scheme's environment) and how to read the extension's What was shared panel.

Test approach: `make test` (compiles), `make lint`. CI runs the tests on push; the runner's verify step checks that CI run.

### M7 Set the speed budget and measure open-to-render time

Size M, P0, model sonnet, depends on M5.

Owns: `App/Shared/Perf/PerfSignposts.swift` (new), `App/Shared/Reader/RenderedView.swift` (signposts only), `App/mdview/Reader/ReaderView.swift` (signposts only), `App/mdviewShare/ShareViewController.swift` (signposts only), `Packages/MDCore/Tests/MDCoreTests/PerformanceTests.swift`, `Packages/MDCore/Tests/MDCoreTests/PerfFixtures.swift`, `App/mdviewUITests/PerformanceTests.swift`, `docs/perf/README.md`, `docs/perf/fixtures/`.

1. **`PerfSignposts`** per 3.5, with intervals `decode`, `prepare`, `parse`, `layout` and the event `firstRender`. The DEBUG console line comes from `MDVIEW_PERF_LOG=1` (3.3). Instrument the app reader and the extension.
2. **`PerfFixtures.note(bytes:)`:** deterministic content. Generate `docs/perf/fixtures/note-20k.md`, `note-200k.md` and `note-1m.md` with a tiny `swift`-free script or a test helper that writes them (commit the files).
3. **MDCore `PerformanceTests`:**
   - Measure `TextDecoding`, `RenderPipeline.prepare` and `TextSearch.ranges` on 20 KB and 1 MB, as a median of 5 runs.
   - Record the medians observed on this Mac in `docs/perf/README.md`. Hard-assert at 3× those medians, rounded up to 50 ms.
   - Keep the whole performance suite under 10 s of wall time.
4. **UI `PerformanceTests`** (CI only): `measure(metrics: [XCTApplicationLaunchMetric(), XCTOSSignpostMetric(subsystem: "us.par72.mdview", category: "Performance", name: "open")])` on a 20 KB fixture through `ReaderLauncher`. Fail only above 1.5 s (3× the 500 ms budget), because the simulator isn't representative.
5. **`docs/perf/README.md`:** the 3.3 budget table, the method, how to profile on a device with Instruments (App Launch and os_signpost) with the fixtures copied to Files, and an empty results table for L10.

Test approach: `swift test`, `make test`, `make lint`.

### M8 Make opening fast: background parse, caches, lazy sections

Size L, P0, model opus, depends on M7.

Owns: `App/Shared/Reader/PreparedDocument.swift` (new), `App/Shared/Reader/RenderedView.swift`, `App/mdview/Reader/ReaderView.swift` (find caching and large-file bar), `App/mdviewShare/SharedReaderView.swift` (use the preparer), `Packages/MDCore/Sources/MDCore/SectionSplitter.swift` and its test, `App/mdviewUITests/LargeFileTests.swift`, `docs/perf/README.md`, `docs/ARCHITECTURE.md`.

1. **`SectionSplitter`** per 3.5 (fence-aware; cuts only before a line starting `#`–`######` followed by a space at column 0; joining the sections reproduces the input).
2. **`DocumentPreparer` and `PreparsedParser`:**
   - Prepare runs in a detached task: pipeline → splitter → `AttributedString(markdown:including:options:baseURL:)` per section, using the **same** options and `\.textual` scope as Textual's `AttributedStringMarkdownParser`. If the `\.textual` attribute scope isn't public, call `AttributedStringMarkdownParser.markdown(baseURL:).attributedString(for:)`, which is public, inside the task.
   - `PreparsedParser.attributedString(for:)` returns the cached value for its section string (fallback: parse).
3. **`RenderedView`:**
   - Show a lightweight placeholder: the first ~2 KB of the source as plain body text (real text, not a redacted skeleton). Then show `ScrollView { LazyVStack(alignment: .leading) { ForEach(sections) { StructuredText($0.markup, parser: PreparsedParser(...)).id("section-\(index)") } } }`.
   - One section (≤ 64 KB) keeps today's layout and selection.
   - The task restarts when the text or the Obsidian setting changes.
4. **`ReaderView`:**
   - `findMatches` becomes `@State` computed in `.task(id: FindKey(query, text))` after a 150 ms debounce; the count and highlights read the state.
   - Files over 2 MB open in Source with a bar "Large file. Showing Source." and a button `reader.renderAnyway`.
5. **Extension:** uses the same preparer. Its first frame is the placeholder, so `viewDidLoad` → first pixels in < 100 ms.
6. **Tests:**
   - `SectionSplitter`: below threshold → 1 section; headings inside fences don't cut; setext headings don't cut; the join is exact; the output is identical for CRLF.
   - UI `LargeFileTests` (CI): a 300 KB fixture renders its last section's heading after scrolling to the end; a 2.5 MB fixture opens in Source with `reader.renderAnyway`.
7. Update `docs/perf/README.md` with before and after medians from the MDCore tests.

Test approach: `swift test`, `make test`, `make lint`.

### M9 Design three icon directions as SVG and PNG

Size M, P0, model sonnet, depends on M2.

Owns: `scripts/generate_app_icon.py`, `docs/app-store/icon/` (new: `directions/{a,b,c}/{any,dark,tinted}.{svg,png}`, `contact-sheet.png`, `README.md`).

1. **Rewrite `scripts/generate_app_icon.py`** (stdlib only):
   - A tiny vector model of shapes (rounded rect, polygon, circle, stroked path, linear gradient) that renders to PNG with 4× supersampling and an anti-aliased downsample, and to SVG text from the same shape list.
   - CLI: `--direction a|b|c --appearance any|dark|tinted --size N --out PATH`, and `--all` to write everything under `docs/app-store/icon/`.
2. **Directions A, B and C** exactly as in plan 3.4, including the colors, transparent backgrounds for dark and tinted, and no alpha for `any`. For B, draw the letterforms as paths, not text.
3. **`contact-sheet.png`:** a grid of rows per direction × columns {any, dark (over #000), tinted (over a #3A6EA5 tint preview)} at 1024 (scaled to 256) plus small renders at 180, 120, 87, 58 and 40 px. Label each row with a drawn letter A/B/C (path-based).
4. **`docs/app-store/icon/README.md`:** the three directions, the rules from 3.4, how to regenerate (`python3 scripts/generate_app_icon.py --all`), and the default (A, N2). It says keving picks the direction in L10.
5. Running the script twice gives byte-identical PNGs (deterministic).

Test approach: `python3 scripts/generate_app_icon.py --all` and a second run gives identical `shasum` output; `python3 -c` with `struct` reads the PNG IHDR to confirm 1024×1024 and the color type (2 = RGB without alpha for `any`); `make lint`; `make test`.

### M10 Wire the chosen icon into the asset catalog with dark and tinted variants

Size S, P0, model sonnet, depends on M9.

Owns: `App/mdview/Assets.xcassets/AppIcon.appiconset/`, `Makefile` (`icon` target only), `scripts/check_app_config.py` (icon check only), `README.md` (icon section), `docs/DEVELOPMENT.md`.

1. **`make icon ICON=a`** (default `a`) runs the generator for the three appearances into `AppIcon.appiconset/AppIcon.png`, `AppIcon-dark.png` and `AppIcon-tinted.png`.
2. **`Contents.json`:** single-size `universal`/`ios` `1024x1024` entries, with `appearances` `luminosity: dark` and `luminosity: tinted` for the variants.
3. **`check_app_config.py` `check_app_icon`:** all three files exist at 1024×1024; `AppIcon.png` has no alpha; `Contents.json` references exactly those files with the right appearances.
4. Docs: README "Regenerate the app icon" becomes `make icon ICON=a`; `docs/DEVELOPMENT.md` gets the same.

Test approach: `make icon ICON=a` is idempotent (`git status` clean on a second run), then `make lint` and `make test`.

### Launch polish (P1)

### L1 Add dark and increased-contrast accent color variants

Size S, P1, model sonnet, depends on M1.

Owns: `App/mdview/Assets.xcassets/AccentColor.colorset/Contents.json`, `scripts/check_app_config.py` (contrast check only), `docs/ARCHITECTURE.md` (one line).

Appearances:

| Appearance | Color | Contrast |
| --- | --- | --- |
| Any | #2E6B4A (unchanged) | 6.33 on #FFFFFF, 5.67 on #F2F2F7, 5.04 on #E5E5EA |
| Dark | #5BBF8A | 9.26 on #000000, 7.51 on #1C1C1E, 6.15 on #2C2C2E, 5.01 on #3A3A3C |
| Light, high contrast | #1F4A33 | |
| Dark, high contrast | #7AD3A3 | |

The asset catalog uses `appearances` `luminosity dark` and `contrast high`.

`check_accent_contrast` (WCAG 2.x):
- Light variants need ≥ 4.5 against #FFFFFF, #F2F2F7 and #E5E5EA.
- Dark variants need ≥ 4.5 against #000000, #1C1C1E and #2C2C2E, and ≥ 3.0 against #3A3A3C.
- Print each ratio. Handle float and `0xNN` components.
- `--self-test`: a single-#2E6B4A colorset fails.

Test approach: `make lint` (prints ratios), `make test`.

### L2 Make rendered headings and lists VoiceOver-friendly

Size M, P1, model opus, depends on M8.

Owns: `App/Shared/Reader/ReaderStyle.swift` (new), `App/Shared/Reader/RenderedView.swift` (style and selection only), `App/mdviewUITests/ReaderAccessibilityTests.swift` (new), `docs/ARCHITECTURE.md`.

1. **`struct ReaderStyle: StructuredText.Style`:** the GitHub members, with three replaced:
   - `AccessibleHeadingStyle`: wraps `GitHubHeadingStyle` with `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(.isHeader)` and `.accessibilityHeading(.h1…h6)`.
   - `AccessibleListItemStyle`: `DefaultListItemStyle` plus `.combine`.
   - `QuietBulletMarker`: the hierarchical disc/circle/square marker plus `.accessibilityHidden(true)`. Ordered numbers stay readable.
   - No heading identifiers (the configuration has no text); tests find headings by label.
2. **`RenderedView`** applies `ReaderStyle()` to every section, and `.textual.textSelection(.disabled)` while `accessibilityVoiceOverEnabled` is true (K3).
3. **`ReaderAccessibilityTests`** (CI): the "Overview" heading is hittable; no bullet item's label contains "circle"; the heading's link stays tappable.

Test approach: `make test`, `make lint`.

### L3 Scroll wide tables and fix accessibility-size truncation

Size M, P1, model sonnet, depends on L2.

Owns: `App/Shared/Reader/ReaderStyle.swift` (table members only), `App/mdview/Reader/ReaderView.swift` (toolbar and title only), `App/mdviewUITests/DynamicTypeTests.swift` (new).

1. **`ScrollingTableStyle`:**
   - The GitHub table look inside Textual's `Overflow`, capped at 1.5× the container width. Never a bare horizontal `ScrollView`.
   - If `DynamicColor.gitHub*` isn't public, use `Color(uiColor: .separator)` for borders and `.secondarySystemBackground` for even rows.
2. **`AccessibleTableCellStyle`:** `.combine`, `.isHeader` on row 0, `.accessibilityCustomContent("Position", "Row r, column c")`.
3. **Mode picker:** at accessibility sizes, `.pickerStyle(.menu)` with the same identifier `reader.modePicker`; otherwise segmented with `.accessibilityShowsLargeContentViewer()`.
4. **Title:** a `.principal` toolbar item with `.headline`, 2 lines (3 at accessibility sizes), `.truncationMode(.middle)`, `.accessibilityLabel(fileName)` and the Large Content Viewer. Keep `.navigationTitle`. The search count wraps.
5. **`DynamicTypeTests`** (CI) at `UICTContentSizeCategoryAccessibilityXXXL`: the picker is hittable; the title label is the full name; after a swipe on the table, the "Owner" header is hittable.

Test approach: `make test`, `make lint`.

### L4 Mark the current find match without color and honor Reduce Motion

Size S, P1, model sonnet, depends on M8.

Owns: `Packages/MDCore/Sources/MDCore/FindHighlight.swift` and its test, `App/Shared/Reader/SourceView.swift`, `App/Shared/Motion.swift` (new), `.swiftlint.yml` (custom rule only).

1. **`FindHighlight`** per 3.5. The current match is strong fill, thick underline and bold. Others are soft fill, with a dotted underline when Differentiate Without Color is on.
2. **`SourceView`** maps the styles to attributes. It reads `accessibilityDifferentiateWithoutColor` and includes it in `SourceRenderSignature`.
3. **Reduce Motion:** `SourceTextView` scrolls with `setContentOffset(_, animated: false)` when it's on.
4. **`Motion.animate(_:_:)`**, plus a swiftlint rule `use_motion_helper` (`withAnimation\(`, excluding `App/Shared/Motion.swift`, severity error).

Test approach: `swift test` (zero, one, first/last current, out of range, DWC on and off), `make test`, `make lint`.

### L5 Render task lists as read-only checkboxes

Size M, P1, model sonnet, depends on M8.

Owns: `Packages/MDCore/Sources/MDCore/TaskListPreprocessor.swift`, `TaskMarker.swift` and their tests, `Packages/MDCore/Sources/MDCore/RenderPipeline.swift` (task step), `App/Shared/Reader/TaskCheckbox.swift` (new), `App/Shared/Reader/LocalImageLoader.swift`.

1. **`TaskListPreprocessor`:**
   - A line matches with optional indentation, a list marker (`-`, `*`, `+`, `1.`, `1)`), spaces, then `[ ]`, `[x]` or `[X]`, then a space or end of line.
   - Replace only the bracket with `![Not done](x-mdview-task:unchecked)` or `![Done](x-mdview-task:checked)`.
   - Skip fenced and indented code and mid-line brackets; `[x](url)` is untouched. Keep line endings.
2. **`RenderPipeline`** inserts the step after Obsidian.
3. **`TaskCheckbox: Attachment`:**
   - SF Symbols `square` and `checkmark.square.fill` (accent color when checked, `.secondary` when unchecked), about 1.1 em via `UIFontMetrics`.
   - Labels "Done" / "Not done"; `description` `[x]` / `[ ]`; not tappable.
4. **`LocalImageLoader`** returns `AnyAttachment`. A `TaskMarker` URL gives the checkbox before any file work; `ImagePolicy` is unchanged and still rejects the scheme (test).
5. **Fallback** if the baseline misaligns and `baselineOffset` can't fix it: ☐/☑ glyphs. Say so in the handoff.

Test approach: `swift test` (markers, nesting, fences, mid-line, `[x](url)`, CRLF, pipeline order), `make test`, `make lint`.

### L6 Add a launch screen with a How to Open Files guide

Size M, P1, model sonnet, depends on M6.

Owns: `App/mdview/mdviewApp.swift` (launch scene), `App/mdview/Help/OpenFilesHelpView.swift` (new), `App/mdview/Reader/ReaderView.swift` (menu item only), `App/mdviewUITests/LaunchSceneTests.swift` (new).

1. **`DocumentGroupLaunchScene(AppName.display)`:** an accessible accent background, and a `Button("How to Open Files", systemImage: "questionmark.circle")` (`launch.help`) presenting `OpenFilesHelpView`. Leave room for Paste (L7).
2. **`OpenFilesHelpView`** sections (header trait, Dynamic Type, no truncation; Done `help.done`):
   - "From a chat or mail app": Share, then tap MdV. If it's not in the row, tap More, then Edit, and add MdV to Favorites. MdV shows it right away; Done closes it.
   - "Open the file in MdV": for files, Share, then the MdV "Open in" item opens the full app.
   - "Copy and paste": copy the text, open MdV, tap Paste Markdown.
   - "Save to Files first".
   - "Files app".
   - "iPad": drag and drop, with the comment `// drag-and-drop: remove if L10 fails`.
   - Footer: "MdV never connects to the internet."
3. The reader menu gets the same entry, `reader.help`.
4. Comment the iOS 27 fallback (`overlayAccessoryView`) above the scene. Don't build it.
5. **`LaunchSceneTests`** (CI): tap `launch.help`, find "Copy and paste", tap `help.done`.

Test approach: `make test`, `make lint`.

### L7 Add Paste Markdown

Size M, P1, model opus, depends on L6.

Owns: `App/mdview/mdviewApp.swift` (launch actions only), `App/mdview/Paste/PastedReaderView.swift` (new), `App/mdview/TextDocument.swift`, `App/mdviewUITests/PasteTests.swift` (new).

1. **`TextDocument.init(text:contentType:)`** moves out of `#if DEBUG`.
2. **Launch scene `PasteButton(payloadType: String.self)`** (`launch.paste`): the first non-empty string opens `PastedReaderView` in a `.fullScreenCover`. That view is `NavigationStack { ReaderView(...) }` with `ReaderContext(displayName: "Pasted Markdown")`, plus:
   - Done (`paste.done`);
   - Save to Files (`paste.save`, `.fileExporter`, default `Pasted <yyyy-MM-dd HHmm>.md`, UTF-8).
3. Empty pastes do nothing. Over 1 MB, prepare off the main actor (M8's preparer already does). Paste lives on the launch scene only.
4. **`PasteTests`** (CI): set `UIPasteboard.general.string`, tap `launch.paste`, assert "Pasted Markdown", then Done. `XCTSkip` with a reason if `PasteButton` isn't tappable in XCUITest.

Test approach: `make test`, `make lint`.

### L8 Add accessibility audit UI tests

Size M, P1, model sonnet, depends on L1, L2, L3, L4, L5, L6, L7.

Owns: `App/mdviewUITests/AccessibilityAuditTests.swift` (new), `App/mdviewUITests/ReaderFixture.swift` (additions only), `docs/DEVELOPMENT.md` (tests section).

`performAccessibilityAudit()` covers:
- Rendered `kitchenSink` in light and dark;
- Source;
- find active (`Draft`);
- the accessibility XXXL size;
- the help sheet;
- the pasted reader;
- the Share extension reader through `ShareHarness` `textDocument`, if reachable.

The handler may ignore only named system-owned elements, each with a comment; never a whole audit type. Also assert that "Done" and "Not done" checkbox elements exist. Document how to read audit failures from the CI `xcresult`.

Test approach: `make test`, `make lint`.

### L9 Update launch docs, App Store listing and build number

Size S, P1, model sonnet, depends on L8, M10.

Owns: `docs/app-store/listing.md`, `docs/support.md`, `docs/privacy.md`, `docs/RELEASE.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/index.md`, `project.yml` (`CURRENT_PROJECT_VERSION` only).

1. **Version:** `CURRENT_PROJECT_VERSION` "2"; `MARKETING_VERSION` stays "0.1.0" (N3). Both targets inherit it. Update the build mentions.
2. **`listing.md`:**
   - Name MdV: Markdown Viewer.
   - The description keeps "task lists", adds "Share any Markdown or text to MdV from any app's share sheet and read it instantly", plus Paste Markdown and the guide. Mark the drag-and-drop lines for removal if L10 fails.
   - Review notes explain the Share extension (it views shared text in place and never leaves the device).
   - Recount every character count with Python `len()`.
3. **`support.md`:** a FAQ "Open a Markdown file someone sent me in a chat app" (3.1 paths 1, 2, 3 and 4, plus the Favorites tip) and "Why does the share sheet say Text Document?".
4. **`privacy.md`:**
   - The Share extension reads only the item you share, shows it, and keeps nothing.
   - Pasted text stays in memory unless saved.
   - The bundle ID line is unchanged.
5. **`RELEASE.md` checklist adds:**
   - Grok Bot share → MdV renders (Text Document case), plus Messages, Mail and Files;
   - the What was shared panel;
   - the Debug-build diagnosis steps if MdV is missing;
   - the speed budget table with measured values (`docs/perf/README.md`);
   - the new icon in light, dark and tinted (Home Screen, Customize);
   - the name on the home screen;
   - VoiceOver headings and tables, Differentiate Without Color, the largest text, Reduce Motion, Increased Contrast;
   - task lists, Paste, the guide;
   - iPad drag and drop, Stage Manager;
   - the iOS 27 launch buttons.
6. **README / ARCHITECTURE:** the name, features, the extension, the speed design, `App/Shared`.

Test approach: `make lint`, `make test`. Put the character counts in the PR body.

### L10 Device check, name, icon pick and submission of 0.1.0 build 2

Size M, P1, needs_human, no_code, depends on L9. **The runner stops here.**

keving:
1. Pick the icon direction from `docs/app-store/icon/contact-sheet.png` (default A). If it's not A, run `make icon ICON=b|c` and commit.
2. In App Store Connect, rename the app to the chosen name (default "MdV: Markdown Viewer"). If it's taken, choose the next option from plan 3.4 and edit `APP_DISPLAY_NAME`.
3. Merge the launch PR after CI is green. Run `make archive && make upload` (automatic signing registers `us.par72.mdview.share`).
4. On the iOS 27 iPhone, install from TestFlight:
   - (a) Grok Bot → Share → MdV renders, and time it (budget < 400 ms);
   - (b) if MdV is missing, install the Debug build from Xcode and read the What was shared panel;
   - (c) Messages, Mail, Files, and a Quick Look preview's share button;
   - (d) cold-open a 20 KB note from Files (budget < 500 ms), using Instruments per `docs/perf/README.md`;
   - (e) the rest of the `RELEASE.md` checklist, including iPad drag and drop and VoiceOver.
5. Record the results in `docs/perf/README.md` and `docs/support.md`. Remove failed claims.
6. Optionally regenerate screenshots (`scripts/screenshots.sh`, one simulator at a time).
7. Fill in App Store Connect from `listing.md`, including any localized copies kept only there, and submit by **Fri Nov 6**.

### v0.2 (P2)

### V1 Add an outline sheet that jumps to headings

Size M, P2, model sonnet, depends on L10.

Owns: `Packages/MDCore/Sources/MDCore/HeadingOutline.swift` and its test, `App/mdview/Reader/OutlineSheet.swift` (new), `App/Shared/Reader/RenderedView.swift` (`ScrollViewReader` only), `App/mdview/Reader/ReaderView.swift` (toolbar only), `App/mdviewUITests/OutlineTests.swift` (new).

1. **`HeadingOutline.headings(in:) -> [OutlineHeading(level, title, slug, occurrence, section)]`:**
   - Parse each `SectionSplitter` section of the `RenderPipeline` output with Foundation `AttributedString(markdown:)` (Textual's default options).
   - `slug` reproduces Textual's `slugified()`; credit Textual (MIT).
   - `section` is the section index.
2. **`OutlineSheet`:** a level-indented `List`; rows `outline.row.<index>` labeled "Heading level N, title"; detents medium and large.
3. **`reader.outline`** shows in Rendered mode with ≥ 2 headings.
4. **On tap:** dismiss, then `Motion.animate`. Scroll to `slug` for single-section documents. For sectioned documents, scroll first to `section-<n>` and then to `slug`, because ids inside unrealized lazy sections aren't known yet. Duplicate slugs land on the first heading (documented).
5. **`OutlineTests`** (CI): tap the "Code" row, then assert the "Code" heading is hittable.

Test approach: `swift test` (ATX, setext, inline formatting, fences ignored, front matter excluded, duplicates, an 8-case slug table, section indices), `make test`, `make lint`.

### V2 Add a copy button to code blocks

Size S, P2, model sonnet, depends on V1.

Owns: `App/Shared/Reader/ReaderStyle.swift` (code block member only), `App/Shared/Reader/CopyableCodeBlockStyle.swift` (new), `App/mdviewUITests/CodeBlockTests.swift` (new).

1. **`CopyableCodeBlockStyle`** reproduces `GitHubCodeBlockStyle`, with `.overlay(alignment: .topTrailing)` on the `Overflow` view (excluded from Textual's selection overlay):
   - a `Button` (`code.copy`, label "Copy code") calling `configuration.codeBlock.copyToPasteboard()`;
   - "Copied" with a checkmark for 1.5 s (`Motion.animate`, `.sensoryFeedback(.success, trigger:)`);
   - the language hint as a caption.
2. Also a `.contextMenu { Button("Copy Code") }`.
3. **`CodeBlockTests`** (CI): tap `code.copy`; the pasteboard contains `struct`.

Test approach: `make test`, `make lint`.

### V3 Add reading settings for text size, width and font

Size M, P2, model sonnet, depends on V2.

Owns: `App/Shared/Reader/ReadingSettings.swift` (new), `App/Shared/Reader/RenderedView.swift` (settings only), `App/Shared/Reader/SourceView.swift` (font scale only), `App/mdview/Reader/ReaderView.swift` (menu only), `App/mdviewUITests/ReadingSettingsTests.swift`, `docs/privacy.md`, `README.md`.

1. **`@AppStorage` keys:**
   - `reader.textScale`: 0.85 to 1.6 in steps of 0.15, default 1.0;
   - `reader.width`: narrow 560, standard 680, wide 860;
   - `reader.fontDesign`: system, serif or mono.
2. **Rendered:** `.textual.fontScale`, font design (fall back to `.font(.system(.body, design:))` if Textual ignores `.fontDesign`) and the column width. **Source:** multiply its font by the scale. Dynamic Type still applies.
3. **Menu:** a Text submenu (`reader.text.smaller`, `.larger`, `.reset`), a Width picker and a Font picker.
4. **Docs:** list the keys in `privacy.md` and the README.
5. **`ReadingSettingsTests`** (CI): the heading frame grows after two Larger taps.

Test approach: `make test`, `make lint`.

### V4 Remember reading position per file

Size M, P2, model sonnet, depends on V3.

Owns: `Packages/MDCore/Sources/MDCore/ReadingPositionStore.swift` and its test, `App/Shared/Reader/RenderedView.swift` (scroll position only), `App/mdview/Reader/ReaderView.swift` (key wiring only), `docs/privacy.md`.

1. **`ReadingPositionStore`:**
   - Built with an injected `KeyValueStorage`.
   - Stores a fraction per SHA-256 hex of the standardized path (CryptoKit), as JSON under `reader.positions`.
   - LRU-capped at 200; clamped to 0…1; nothing recorded below 0.02.
2. **`RenderedView`:**
   - Records with `onScrollGeometryChange`, debounced 1 s.
   - Restores once after first layout with `ScrollPosition`; for sectioned documents, scrolls to the section first.
   - Only for documents with a file URL (not paste, not the extension).
3. **`privacy.md`:** scroll positions for the 200 most recent files are kept on the device, keyed by a path hash.

Test approach: `swift test` (round trip, clamp, floor, pruning at 201, a stable hash, path standardization), `make test`, `make lint`.

### V5 Export to PDF and print

Size L, P2, model opus, depends on V4.

Owns: `Packages/MDCore/Sources/MDCore/PageSlicer.swift` and its test, `App/mdview/Export/PDFExporter.swift`, `App/mdview/Export/ExportMenu.swift` (new), `App/mdview/Reader/ReaderView.swift` (menu only), `App/mdviewUITests/ExportTests.swift`.

1. **`PageSlicer.slices(contentHeight:pageHeight:)`:** full pages plus the remainder; no empty last page; zero content gives one empty page.
2. **`PDFExporter.render(markdown:baseDirectory:pageSize:) async -> Data`:**
   - `ReaderStyle`, light appearance, selection disabled, page width minus 2 × 36 pt.
   - Local images preloaded by a render-only loader; a 0.3 s settle.
   - `ImageRenderer.render` into a `CGContext` PDF, one page per slice.
   - Letter for US/CA/MX regions, A4 elsewhere.
3. **Menu:**
   - `reader.export.pdf`: a `ShareLink` with a `Transferable` PDF named `<name>.pdf`;
   - `reader.print`: `UIPrintInteractionController` with the PDF data.
   - Show progress while rendering. Over 1 MB: "Too long to export".
4. **`ExportTests`** (CI): the export item exists and is enabled.

Test approach: `swift test`, `make test`, `make lint`.

### V6 Add an optional math rendering toggle, off by default

Size S, P2, model sonnet, depends on V5.

Owns: `Packages/MDCore/Sources/MDCore/MathDelimiters.swift` and its test, `Packages/MDCore/Sources/MDCore/RenderPipeline.swift` (math step), `App/Shared/Reader/RenderedView.swift` (syntax extension only), `App/mdview/Reader/ReaderView.swift` (toggle only), `THIRD_PARTY_NOTICES.md`, `README.md`, `docs/privacy.md`.

1. **Toggle** "Math (LaTeX)": `settings.math`, `@AppStorage("reader.math")`, default false (`$5 and $10` would otherwise render as math).
2. **When on:** `MathDelimiters` turns `\(…\)` into `$…$` and `\[…\]` into `$$…$$` outside fences and code spans, and the reader passes `syntaxExtensions: [.math]` (or the `PreparsedParser` path that applies `.math`).
3. **Docs:** update `THIRD_PARTY_NOTICES.md`, README and privacy (the new key).

Test approach: `swift test` (inline, block, fences and spans untouched, escaped backslash untouched, off is identity), `make test`, `make lint`.

### V7 Add iPad keyboard shortcuts

Size S, P2, model sonnet, depends on V6.

Owns: `App/mdview/Reader/ReaderView.swift` (focused values and shortcuts only), `App/mdview/mdviewApp.swift` (`.commands` only), `docs/support.md`.

A View `CommandMenu` driven by `@FocusedValue` from `ReaderView`:
- ⌘1 Rendered, ⌘2 Source;
- ⇧⌘O Outline;
- ⌘+ / ⌘− / ⌘0 text size;
- ⌘P Print;
- ⇧⌘E Export PDF.

Don't duplicate the system ⌘F of `.searchable`. Commands are disabled with no focused reader. List them in `support.md`.

Test approach: `make test`, `make lint`.

### V8 Update v0.2 docs, set version 0.2.0 and extend screenshots

Size M, P2, model sonnet, depends on V1, V2, V3, V4, V5, V6, V7.

Owns: `project.yml` (versions), `docs/app-store/listing.md`, `docs/support.md`, `docs/privacy.md`, `docs/RELEASE.md`, `README.md`, `docs/ARCHITECTURE.md`, `scripts/screenshots.sh`, `App/mdviewUITests/ScreenshotTests.swift`, `scripts/screenshot-samples/`.

1. **Versions:** 0.2.0 / 3 for both targets.
2. **Listing:** features, What's New, recounted character counts; still Data Not Collected and no network.
3. **Screenshots:** add `06-outline.png` and `07-tasks.png` (new sample `Launch Checklist.md`) to `ScreenshotTests`, `screenshots.sh` and the upload order. Don't run the script.
4. **`RELEASE.md`:** v0.2 checks for outline, copy, settings, position, PDF and print, math and shortcuts.
5. **Privacy docs:** every new key listed.

Test approach: `make lint`, `make test`; character counts in the PR body.

### V9 Device check and ship 0.2.0

Size M, P2, needs_human, no_code, depends on V8.

keving:
1. Merge after CI is green.
2. Run `scripts/screenshots.sh` and commit the screenshots.
3. `make archive && make upload`.
4. Run the v0.2 checklist on the iPhone and iPad.
5. Submit 0.2.0.
6. Decide whether to schedule the v0.3 on-device AI beads (N6) and the Quick Look extension (D4).

## 6. Quality gate

After every bead, from the repo root:

```bash
make test    # swift test --package-path Packages/MDCore (incl. MDCore performance tests from M7), then make build-tests (from M1): unsigned generic iOS build-for-testing of the app, the Share extension (from M5) and the UI tests
make lint    # swiftformat --lint, swiftlint --strict (no_networking; use_motion_helper from L4), python3 scripts/check_app_config.py (from M1)
```

Rules:
- Never run `make test-ios`, `scripts/screenshots.sh`, `make archive` or `make upload` from a bead. Never boot a simulator. An exported `CI=true` doesn't change that.
- UI tests compile in `make test` and run only in GitHub Actions on push.
- Never set `DEVELOPMENT_TEAM` in a tracked file. Never read or edit `.env` files or `Config/Local.xcconfig`.
- Format only the files the bead changed.
- MDCore stays Foundation-only (CryptoKit is allowed from V4).

## 7. Decisions and open questions

### 7.1 Earlier open questions, decided with the recommended defaults

| # | Question | Decision |
| --- | --- | --- |
| D1 | Network use for links (`mdview://open?url=`)? | **No network.** If links are wanted later: Universal Links on a `khgouldy.github.io` user site with the content in the fragment (no app request). |
| D2 | Should Grok Bot send `.md` file attachments? | **Yes, on the bot side** (outside this repo), as well as the Share extension; it enables the "Open in" path. |
| D3 | Share-sheet extension in the launch build? | **Yes, superseded by the addendum.** It's now must-ship (M5, as a Share extension, not an Action extension). |
| D4 | Quick Look preview extension? | **Not now** (iOS 27 regression, FB24481377). Revisit after 0.2.0. |
| D5 | Launch version 0.1.0? | **0.1.0 build 2** (see N3). |
| D6 | Math on by default? | **No, off.** |
| D7 | Save to Files for pasted text? | **Yes.** |
| D8 | If iPad drag and drop fails, drop the claim? | **Yes**, for launch; file a bead. |
| D9 | Localized listings? | **Assume none**; keving copies the changes by hand if some exist only in App Store Connect. |
| D10 | If behind schedule on Nov 5? | **Submit with M1–M10 plus L9.** Unfinished L beads ship in 0.1.1. |
| D11 | Hand-off from the extension to the main app? | **Inline render only for launch.** "Keep in MdV" (App Group) is deferred. |

### 7.2 New open questions for keving (recommended default in bold)

| # | Question | Recommended default |
| --- | --- | --- |
| N1 | App name: one of the 8 options in 3.4? | **MdV** on the home screen, **"MdV: Markdown Viewer"** in the App Store. Fallbacks in order: Mdown, Markd. |
| N2 | Icon direction: A folded page with the Markdown mark, B MdV monogram, or C reading lines? | **A**: name-independent, says "Markdown" at 40 px. Pick from `docs/app-store/icon/contact-sheet.png` in L10. |
| N3 | Launch version: 0.1.0 build 2, or 0.2.0? | **0.1.0 build 2.** No user has 0.1.0, and 0.2.0 stays meaningful for the reader features. |
| N4 | Accept `public.text` as an Alternate document type, so RTF and HTML open as raw text in Source? | **Yes.** It covers hosts that label Markdown as generic text. |
| N5 | Keep the extension's "What was shared" panel in Release builds? | **Yes.** It's read-only, stores nothing, and helps support. |
| N6 | Schedule on-device AI (Summarize, Ask) as v0.3 right after 0.2.0? | **Yes, v0.3**: 2 beads (A1, A2 in 3.9), on-device model only, hidden on unsupported devices. |
