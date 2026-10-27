# Development

mdview is an iOS 18 SwiftUI app. Agents and CI enter through the Makefile. The Xcode project is generated. Do not edit `mdview.xcodeproj` by hand.

## Toolchain

Recorded on macOS 26.5.2 when this scaffold was created.

| Tool | Version |
| --- | --- |
| Xcode | 26.0.1 (build 17A400) |
| Swift | 6.2 (swiftlang-6.2.0.19.9, clang-1700.3.19.1) |
| xcodegen | 2.46.0 |
| swiftformat | 0.64.1 |
| swiftlint | 0.65.1 |

The app deployment target is iOS 18.0. `SWIFT_VERSION` is 6.0, with `SWIFT_STRICT_CONCURRENCY` set to complete. `Packages/MDCore` uses Swift tools version 6.0 and declares iOS 18 and macOS 15 so `swift test` runs on the Mac.

`make tools` installs xcodegen, swiftformat, and swiftlint with Homebrew when they are not on `PATH`.

## Makefile targets

| Target | What it does |
| --- | --- |
| `make tools` | Checks for xcodegen, swiftformat, and swiftlint. Installs any that are missing. |
| `make gen` | Copies `Config/Local.xcconfig.example` to `Config/Local.xcconfig` if the copy is missing, then runs `xcodegen generate`. |
| `make lint` | `swiftformat --lint`, `swiftlint lint --strict`, then `make check-config`. Exits non-zero when a file under `App/` or `Packages/` contains `URLSession`, `NWConnection`, `WKWebView`, or `CFNetwork`. |
| `make check-config` | `python3 scripts/check_app_config.py`. Prints `ok:` per check or `error:` lines and exits 1: no tracked file sets a non-empty `DEVELOPMENT_TEAM`, every `PRODUCT_BUNDLE_IDENTIFIER` is `us.par72.mdview` or a child, every `PrivacyInfo.xcprivacy` under `App/` has no tracking and no collected data, no plist under `App/` has `TRUEPREDICATE`, the display name and Markdown types agree, `App/Shared` has no `UIApplication.shared`, and the Share extension passes `check_share_extension` (below). `--self-test` runs each check against a bad example. |
| `make format` | Rewrites Swift with swiftformat, then `swiftlint lint --fix`. |
| `make test` | `swift test --package-path Packages/MDCore`, then `make build-tests`. |
| `make build-tests` | `xcodebuild build-for-testing -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. Compiles the app, the embedded `mdviewShare` extension and `mdviewUITests` without a simulator or development team. |
| `make build-ios` | `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. No simulator and no development team. |
| `make test-ios` | Runs `mdviewUITests` on the simulator with parallel testing off. Exits with an error unless `CI=true` or `MDVIEW_ALLOW_SIMULATOR=1`. |
| `make open` | Generates the project and opens it in Xcode. |
| `make clean` | Deletes `mdview.xcodeproj`, `.derivedData`, and the MDCore `.build` directory. Does not delete `Config/Local.xcconfig`. |

`make test-ios` defaults to `platform=iOS Simulator,name=iPhone 16`. Set `MDVIEW_IOS_DESTINATION` to a simulator that exists on the runner. Listing simulators is fine. Booting one locally is not.

The refusal checks `CI` and `MDVIEW_ALLOW_SIMULATOR`. Some agent shells export `CI=true` even on a developer Mac. That satisfies the guard, so do not run `make test-ios` from those shells. To see the refusal: `CI= make test-ios`. GitHub Actions is the run that should execute the tests.

## Signing

`Config/Local.xcconfig.example` sets:

```
PRODUCT_BUNDLE_IDENTIFIER = us.par72.mdview
DEVELOPMENT_TEAM =
```

`Config/Local.xcconfig` is gitignored and is the only place the team is set: `project.yml` sets no `DEVELOPMENT_TEAM` or `CODE_SIGN_IDENTITY` for the app or the extension. Both targets use it as their config file. Its `PRODUCT_BUNDLE_IDENTIFIER` is overridden by each target's own setting, so the extension stays `us.par72.mdview.share`. Automatic signing (`-allowProvisioningUpdates` in `make archive`) registers that App ID the first time. Leave the team empty in git. Device signing is in `docs/RELEASE.md`. Do not look up or commit a Team ID or an Apple account.

## Project layout

`project.yml` is the XcodeGen spec. The app target links two packages: Textual (`https://github.com/gonzalezreal/textual`, `.upToNextMinor(from: "0.5.0")`) and the local package `Packages/MDCore`. MDCore has no dependencies. The resolved pins are committed at `mdview.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. The rest of the generated project is gitignored.

`App/mdview/mdviewApp.swift` is a `DocumentGroup(viewing: TextDocument.self)` scene. `ReaderView` shows Rendered Markdown (Textual) or the original source. `TextDocument` reads an imported `net.daringfireball.markdown` UTI and `public.plain-text`. Behavior, the image policy, and the MDCore types are in `docs/ARCHITECTURE.md`.

`MARKETING_VERSION` is 0.1.0 and `CURRENT_PROJECT_VERSION` is 1, set on both the app and `mdviewShare`. Bump them together; `make lint` fails when they differ. `App/mdview/PrivacyInfo.xcprivacy` and `App/mdviewShare/PrivacyInfo.xcprivacy` are resources of their targets: tracking off, no collected data, UserDefaults reason CA92.1.

The app icon is `App/mdview/Assets.xcassets/AppIcon.appiconset/`: three 1024 images, `AppIcon.png` (any, opaque), `AppIcon-dark.png` and `AppIcon-tinted.png`, with `Contents.json` appearances `luminosity: dark` and `tinted`. `make icon ICON=a` (a, b or c; default a) regenerates all three, and a second run leaves `git status` clean. `make lint` runs `check_app_icon` (1024 size, no alpha in `AppIcon.png`, `Contents.json` entries). Three candidate directions (SVG and PNG, light, dark and tinted) are generated by `python3 scripts/generate_app_icon.py --all` into `docs/app-store/icon/` (Python standard library only); see its README.

`MDCore.TextDecoding.decode(_:)` tries UTF-8, then UTF-16 if the bytes start with `FF FE` or `FE FF`, then Windows-1252.

## Share extension

`mdviewShare` (`type: app-extension`) compiles `App/mdviewShare` and `App/Shared` and links Textual and MDCore. The app target embeds it (`- target: mdviewShare`). Its target settings are `PRODUCT_BUNDLE_IDENTIFIER: us.par72.mdview.share`, `GENERATE_INFOPLIST_FILE: NO`, `APPLICATION_EXTENSION_API_ONLY: YES`, and a per-config `INFOPLIST_FILE`: Debug reads `App/mdviewShare/Info-Debug.plist`, Release reads `App/mdviewShare/Info.plist`. Behavior is in `docs/ARCHITECTURE.md`.

`check_share_extension` in `scripts/check_app_config.py` checks:

- the point identifier `com.apple.share-services`, the principal class `$(PRODUCT_MODULE_NAME).ShareViewController` and `CFBundleDisplayName` `$(APP_DISPLAY_NAME)`;
- the Release rule is a `SUBQUERY` accepting `public.text` and `public.file-url`, with no `public.data` and no `TRUEPREDICATE`;
- the Debug rule is the Release rule plus `OR ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.data"`, and the two plists are otherwise equal;
- `App/mdviewShare/PrivacyInfo.xcprivacy` exists;
- the target's bundle id, type, `APPLICATION_EXTENSION_API_ONLY`, plist paths and versions in `project.yml`, and the app's embed;
- no `UIApplication.shared`, `URLSession` or `extensionContext.open` in Swift under `App/mdviewShare`.

To edit the activation rule, change both plists the same way. Only the Debug one carries the `public.data` clause.

**When a host doesn't offer MdV.** Install a Debug build from Xcode on the device, share from that app, and tap the info button. "What was shared" lists the registered type identifiers and suggested name; Copy puts them on the pasteboard. If none of them conforms to `public.text` and none is a `public.file-url`, the Release rule can't match that host. The share-sheet UI tests (M6) drive the real extension in CI.

### Share harness

`App/mdview/Debug/ShareHarness.swift` (Debug only) presents the real share sheet with the items a chat app hands over. Set `MDVIEW_SHARE_HARNESS` to one of `text`, `textDocument` (a nameless `public.utf8-plain-text` data item, the "Text Document" case), `fileMarkdown` (`Shared Note.md`), `fileText` (`notes.txt`) or `quickLook` (a Quick Look preview of `Shared Note.md`; tap its share button). The content comes from `MDVIEW_SHARE_MARKDOWN`, default `# Shared heading` plus a task item. The app then shows one `harness.share` button.

By hand on a device: Edit Scheme > Run > Arguments > Environment Variables, add `MDVIEW_SHARE_HARNESS=textDocument`, run, tap the button, choose MdV in the app row (or More). Tap the info button in the extension: the What was shared panel lists the registered type identifiers and the suggested name, and Copy puts them on the pasteboard. If MdV is missing from the sheet, those identifiers show why the Debug activation rule did not match.

`App/mdviewUITests/ShareSheetTests.swift` runs one test per case in CI only. It skips with the query used when no app row exists, and fails when the row exists but MdV is not in it or under More. `fileMarkdown` also asserts an Open in / Copy to MdV action. Run `make build-tests` to check they compile; do not run them on a developer Mac. The extension can't run in `swift test` and isn't launched locally.

## Tests

MDCore tests run on the Mac with `swift test`. They cover text decoding (UTF-8, UTF-16 with a BOM, Windows-1252 including the euro byte `0x80`), remote-image rewriting, the file-URL image policy, the Obsidian preprocessor, find ranges, and the share extension's logic: `SharedItemSelection` ranking (the nameless `public.utf8-plain-text` "Text Document", Markdown over plain text, file URL only, data only with and without `allowsData`) and `SharedContent` (titles, the Markdown decision, the binary sniff, the 5 MB and 2 MB limits, empty text).

`App/mdviewUITests/LaunchTests.swift` launches the app and checks that it reaches the foreground. That test runs only through `make test-ios`, which CI calls. `make test` compiles it through `make build-tests` but does not run it. UI tests open fixtures through `ReaderLauncher` (`ReaderFixture.kitchenSink` is the all-blocks document).

## CI

`.github/workflows/ci.yml` is the only place the iOS Simulator runs. A push to any branch starts the workflow, except when every changed file is under `docs/**` or matches `**/*.md`. `workflow_dispatch` starts the same job and takes no inputs. A newer push to the same ref cancels the run already in progress. The job times out after 30 minutes.

The job runs on the pinned `macos-26` runner. It selects Xcode 26.6 with `xcode-select` (iOS 26 SDK, which covers the iOS 18 deployment target), prints `xcrun simctl list devices available`, then runs `make lint`, `make test`, and `CI=true make test-ios`. `make test-ios` runs `mdviewUITests` with parallel testing off. The workflow sets `MDVIEW_IOS_DESTINATION` to an iPhone simulator installed for that Xcode. SwiftPM and `.derivedData` are cached between runs.

The repository is public, so GitHub-hosted macOS minutes cost nothing.

A failed run uploads the `.xcresult` bundle as the artifact named `xcresult`. Download it with:

```bash
gh run download <run-id> -n xcresult
```

The run id is the number printed by `gh run list`.
