# mdview

[![CI](https://github.com/khgouldy/mdview/actions/workflows/ci.yml/badge.svg)](https://github.com/khgouldy/mdview/actions/workflows/ci.yml)

mdview is an iOS app that opens a Markdown file and shows it. Nothing leaves the phone. There is no account, no sync, and no image download. One control switches Rendered and Source.

Version 0.1.0 (build 1). iOS 18 and later, iPhone and iPad.

## Features

- Opens `.md`, `.markdown`, `.mdown`, and plain text from Files, the share sheet, Open In, Recents, and iPad drag and drop. The system document browser does that work. There is no separate file list in the app.
- Renders Markdown with [Textual](https://github.com/gonzalezreal/textual) in the GitHub style, with Textual's built-in code highlighting. The reading column stays narrow on iPad. Text follows Dynamic Type and Dark Mode.
- Source is the file as stored: selectable, monospaced, and scaled with Dynamic Type.
- A plain-text file stays on Source. The Rendered / Source switch is hidden.
- An `http` or `https` image becomes a link labeled `Image: …`. Tap it and Safari opens. The image is not fetched.
- A local image is read from the document's folder. Any other URL is refused.
- Obsidian extras are on by default. They hide a leading YAML front matter block and show `[[Note]]`, `[[Note|Alias]]`, and `[[Note#Heading]]` as plain text. The reader menu has one switch, Obsidian extras. Source always shows the original file.
- Find highlights matches in the source, shows `n of N` (or `No matches`), and moves to the next match when you submit. Clearing the query returns to Rendered or Source, whichever was already selected.

## Privacy

The app does not use the network. `URLSession`, `NWConnection`, `WKWebView`, and `CFNetwork` are lint errors under `App/` and `Packages/`.

Two preferences are stored in UserDefaults on the device: the Rendered / Source choice (`reader.mode`) and the Obsidian switch (`obsidian.enabled`). The privacy manifest reports no tracking and no collected data. See `App/mdview/PrivacyInfo.xcprivacy`.

## Build

Toolchain versions and the Makefile targets are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). How the pieces fit is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Signing and the on-device checklist are in [docs/RELEASE.md](docs/RELEASE.md).

```bash
make tools
make test
make open
```

`make test` runs the MDCore tests on the Mac, then an unsigned generic iOS build. It does not boot the Simulator and it does not need a development team.

Regenerate the app icon (stdlib only, no network) with:

```bash
python3 scripts/generate_app_icon.py
```

## License

[MIT](LICENSE). Copyright (c) 2026 Kevin Gould / Par72 Labs, LLC.

Third-party licenses for Textual, swiftui-math, swift-concurrency-extras, and the bundled Prism.js are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
