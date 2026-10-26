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
| `make lint` | `swiftformat --lint` and `swiftlint lint --strict`. Exits non-zero when a file under `App/` or `Packages/` contains `URLSession`, `NWConnection`, `WKWebView`, or `CFNetwork`. |
| `make format` | Rewrites Swift with swiftformat, then `swiftlint lint --fix`. |
| `make test` | `swift test --package-path Packages/MDCore`, then the `build-ios` target. |
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

`Config/Local.xcconfig` is gitignored. Leave the team empty. Device signing fills it in later, on a machine that has the Apple account. Do not look up or commit a Team ID.

## Project layout

`project.yml` is the XcodeGen spec. The app target links two packages: Textual (`https://github.com/gonzalezreal/textual`, `.upToNextMinor(from: "0.5.0")`) and the local package `Packages/MDCore`. MDCore has no dependencies. The resolved pins are committed at `mdview.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. The rest of the generated project is gitignored.

`App/mdview/mdviewApp.swift` is a `DocumentGroup(viewing: TextDocument.self)` scene. The viewer shows the decoded string. `TextDocument` reads an imported `net.daringfireball.markdown` UTI and `public.plain-text`.

`MDCore.TextDecoding.decode(_:)` tries UTF-8, then UTF-16 if the bytes start with `FF FE` or `FE FF`, then Windows-1252.

## Tests

MDCore tests run on the Mac with `swift test`. They cover UTF-8, UTF-16 with a BOM (little and big endian), and Windows-1252 (including the euro byte `0x80`).

`App/mdviewUITests/LaunchTests.swift` launches the app and checks that it reaches the foreground. That test runs only through `make test-ios`, which CI calls. `make test` does not run it.

## CI

`.github/workflows/ci.yml` is the only place the iOS Simulator runs. A push to any branch starts the workflow, except when every changed file is under `docs/**` or matches `**/*.md`. `workflow_dispatch` starts the same job and takes no inputs. A newer push to the same ref cancels the run already in progress. The job times out after 30 minutes.

The job runs on the pinned `macos-26` runner. It selects Xcode 26.6 with `xcode-select` (iOS 26 SDK, which covers the iOS 18 deployment target), prints `xcrun simctl list devices available`, then runs `make lint`, `make test`, and `CI=true make test-ios`. `make test-ios` runs `mdviewUITests` with parallel testing off. The workflow sets `MDVIEW_IOS_DESTINATION` to an iPhone simulator installed for that Xcode. SwiftPM and `.derivedData` are cached between runs.

The repository is public, so GitHub-hosted macOS minutes cost nothing.

A failed run uploads the `.xcresult` bundle as the artifact named `xcresult`. Download it with:

```bash
gh run download <run-id> -n xcresult
```

The run id is the number printed by `gh run list`.
