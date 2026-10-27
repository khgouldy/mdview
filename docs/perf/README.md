# Performance

How fast MdV opens a note, how that is measured, and where the numbers live.

## Budgets

iPhone 15 Pro or newer, release build.

| Scenario | Budget |
| --- | --- |
| Cold start, from tapping a typical note (20 KB or less, about 300 lines, 3 code blocks) to the first rendered screen | **under 500 ms** |
| Warm open of the same note | under 250 ms |
| Share extension, from tapping MdV in the share sheet to the first rendered screen | **under 400 ms**, resident memory under 60 MB |
| 1 MB file, first screen | under 1.5 s, no main-thread stall over 100 ms |
| Typing in Find on a 1 MB file | No dropped frames; the count updates within 200 ms of the last keystroke |

## Method

1. **Signposts** (`App/Shared/Perf/PerfSignposts.swift`). `OSSignposter(subsystem: "us.par72.mdview", category: "Performance")`.
   - Intervals: `open` (the whole open), `decode`, `prepare`, `parse`, `layout`, and `find` (one Find search). Events: `placeholder` (the plain-text first frame, when the parse wasn't cached) and `firstRender`, emitted from the first non-zero height of the rendered content, which also ends `open`.
   - App: `decode` is `TextDocument.init`; `open` starts in `ReaderView.task`. Launch time before that comes from `XCTApplicationLaunchMetric` or Instruments App Launch.
   - Extension: `open` starts in `ShareViewController.viewDidLoad`. `decode` covers reading the shared item and decoding it, because `SharedContent` does both.
   - `prepare` (pipeline, split, link definitions) and `parse` (one `AttributedString(markdown:)` per section) run in `DocumentPreparer`'s detached task, off the main actor. `layout` runs from the prepared content appearing to `firstRender`. A cached document skips `prepare` and `parse`, so they log as 0.
   - Source mode and the extension's Source view do not emit `firstRender`; only the rendered view does.
2. **Console line.** A DEBUG build run with `MDVIEW_PERF_LOG=1` logs one line at `firstRender` (subsystem above, `info`):
   `perf open=<ms> decode=<ms> prepare=<ms> parse=<ms> layout=<ms> bytes=<n>`.
3. **MDCore performance tests** (`swift test --package-path Packages/MDCore`, part of `make test`). `TextDecoding`, `RenderPipeline.prepare` and `TextSearch.ranges` on the generated 20 KB and 1 MB notes, and the `SectionSplitter` work of a prepare on the 1 MB note. Each stage runs five times after a warm-up; the median must be under its budget, which is 3x the median recorded below, rounded up to the next 50 ms. On the GitHub-hosted CI runner (`MDVIEW_HOSTED_CI=1`) the multiple is 6x, because that VM runs the debug build 3.4x to 4.6x slower than the development Mac. The whole suite takes under 3 s.
4. **CI UI tests** (with `make test-ios`). `App/mdviewUITests/LargeFileTests.swift` checks that a 300 KB file renders its last section after scrolling and that a 2.5 MB file opens in Source with `reader.renderAnyway`. `App/mdviewUITests/PerformanceTests.swift`: `XCTApplicationLaunchMetric` and `XCTOSSignpostMetric(name: "open")` over five launches of the 20 KB note through `ReaderLauncher`. A simulator is not representative, so the results are only reported. The one hard check is launch to rendered under 3x the open budget (1.5 s) plus a 5 s launch allowance.
5. **On a device** (human, bead L10). See below.

### Fixtures

`docs/perf/fixtures/` holds `note-20k.md`, `note-200k.md` and `note-1m.md`. `PerfFixtures.note(bytes:)` (in the MDCore tests) generates them from a fixed pattern: front matter, headings, prose, lists, a table, a Swift code block, wikilinks and remote images, repeated. The same input gives the same bytes. A test fails if a committed file differs from the generator. To regenerate after changing it:

```bash
MDVIEW_WRITE_PERF_FIXTURES=1 swift test --package-path Packages/MDCore --filter PerformanceTests
```

## Recorded MDCore medians

`swift test` (debug build), Apple silicon Mac, 2026-10-26. The test file records these in `PerformanceTests.Recorded`; update both together.

| Stage | 20 KB median | 20 KB budget | 1 MB median | 1 MB budget |
| --- | --- | --- | --- | --- |
| `TextDecoding.decode` | 0.005 ms | 50 ms | 0.07 ms | 50 ms |
| `RenderPipeline.prepare` (Obsidian on) | 2.65 ms | 50 ms | 135 ms | 450 ms |
| `TextSearch.ranges` ("render") | 0.26 ms | 50 ms | 150 ms | 450 ms |
| `SectionSplitter`: sections, grouping, link definitions, parse inputs | n/a (one section) | n/a | 28 ms | 100 ms |

### Before and after M8

Medians of three `swift test --filter PerformanceTests` runs on the same Mac: before at `ead0a9a` (M7), after with M8. M8 doesn't change these functions, so their own times stay within noise. What changes is where they run and how often, which is what the reader feels.

| Stage | Before, 1 MB | After, 1 MB | Before: runs | After: runs |
| --- | --- | --- | --- | --- |
| `RenderPipeline.prepare` | 138 ms | 136 ms | On the main actor, in every `RenderedView.body` | Once per text and Obsidian setting, in a detached task; cached |
| `TextSearch.ranges` | 167 ms | 164 ms | On the main actor, 4 times per body (the highlights, the current index twice, the count), so every keystroke | Once per query, in a detached task, 150 ms after the last keystroke |
| `SectionSplitter` | n/a | 28 ms | n/a | In the detached prepare |
| Textual parse | not in MDCore | not in MDCore | On the main actor, in `StructuredText`'s `onChange` | Per section, in the detached prepare |

Per keystroke in Find on the 1 MB note, main-actor search time goes from about 670 ms (4 × 167 ms) to none; the count lands 150 ms plus one search (about 165 ms in debug) after typing stops. Opening the 1 MB note rendered moves the 136 ms prepare, the 28 ms split and the whole parse off the main actor; the main actor draws the placeholder at once, then lays out only the sections on screen.

## Profiling on a device

1. Build a Release configuration onto the phone from Xcode (Product > Profile, or `make open`). Use a real phone, not a simulator.
2. Copy `docs/perf/fixtures/*.md` to the phone's Files app (AirDrop or iCloud Drive), for example into "On My iPhone".
3. **App launch.** Instruments > **App Launch** template, record, and in Files tap `note-20k.md` after killing MdV from the app switcher (cold) or after opening it once and leaving it (warm). Stop when the text is on screen. Read the time from process start to the first frame.
4. **Signposts.** Add the **os_signpost** instrument (or use the "Points of Interest" template) and filter to subsystem `us.par72.mdview`. The `open` interval is the open-to-render time; `decode`, `prepare`, `parse` and `layout` split it, and `firstRender` marks the end. Check `layout` on the 200 KB and 1 MB notes for main-thread stalls over 100 ms (the Hangs instrument shows them).
5. **Share extension.** Choose the MdV target when Instruments asks which process to attach to, or attach by name `mdviewShare`, then share `note-20k.md` text from Files or Notes. Read `open` from the `viewDidLoad` start, and Memory (Allocations or the Debug navigator gauge) for resident size against the 60 MB budget.
6. Repeat each scenario five times and record the median.

## Device results

Filled in by L10. Empty until a human runs the steps above.

| Scenario | Device | iOS | Build | Median of 5 | Budget | Pass |
| --- | --- | --- | --- | --- | --- | --- |
| Cold open, 20 KB | | | | | 500 ms | |
| Warm open, 20 KB | | | | | 250 ms | |
| Share extension, 20 KB | | | | | 400 ms | |
| Share extension memory | | | | | 60 MB | |
| Open, 200 KB | | | | | n/a | |
| Open, 1 MB | | | | | 1.5 s | |
| Find on 1 MB, keystroke to count | | | | | 200 ms | |
