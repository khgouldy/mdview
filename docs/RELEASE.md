# Release

Version 0.2.0, build 5 (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`). Bundle id `us.par72.mdview`.

Signing happens on keving's Mac. The Team ID stays in the gitignored `Config/Local.xcconfig`. Do not commit it, and do not put an Apple ID or Team ID in the repo.

## Sign and run on a device

1. In `Config/Local.xcconfig`, set `DEVELOPMENT_TEAM` to the Team ID from the Apple Developer account that will sign the app. Leave `PRODUCT_BUNDLE_IDENTIFIER` as `us.par72.mdview`. If the file is missing, `make gen` copies it from `Config/Local.xcconfig.example`.
2. `make open`.
3. Select the mdview target, Signing & Capabilities. Automatically manage signing should already be on with your team. The project sets `CODE_SIGN_STYLE` to Automatic and takes `DEVELOPMENT_TEAM` from `Config/Local.xcconfig`, so `make gen` keeps the team. A team picked only in Xcode is lost on the next `make gen`.
4. On the iPhone, turn on Developer Mode (Settings, Privacy & Security, Developer Mode) and trust the computer.
5. Choose the phone as the run destination and run from Xcode. The first launch asks to trust the developer on the device.

`project.yml` sets no team and no signing identity for the app target. `make build-ios`, `make test`, `make test-ios`, and CI pass `CODE_SIGNING_ALLOWED=NO`, so they build unsigned without a team. Do not put the Team ID into `project.yml`.

## App Store Connect and TestFlight

1. In App Store Connect, create an iOS app named `YAMD: Yet Another MD Viewer` (27/30 characters; see `docs/app-store/listing.md`) with bundle id `us.par72.mdview`. The SKU can be `mdview`.
2. In Xcode, scheme mdview, Any iOS Device (arm64). Product, Archive. The scheme archives with the Release configuration.
3. In the organizer, Distribute App, App Store Connect, Upload.

   From the command line instead: `make archive` then `make upload`. Both sign with an App Store Connect team API key read from `ASC_ENV` (default `~/.appstoreconnect/mdview.env`; override with `make upload ASC_ENV=...`), and `upload` adds the Team ID from `Config/Local.xcconfig` to a copy of `Config/ExportOptions.plist` outside the repo. The key needs Admin, or App Manager with access to cloud-managed distribution certificates, so Xcode can create the distribution certificate and App Store profile.
4. When the build finishes processing, add it to an internal TestFlight group and install it on the phone.

Export compliance: `Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO` (the app uses no encryption), so App Store Connect does not ask the encryption questions for each build.

Privacy answers for the product page: the app does not track, does not collect data, and does not use the network. The manifest is `App/mdview/PrivacyInfo.xcprivacy` (`NSPrivacyTracking` false, empty tracking domains, empty collected-data types, UserDefaults reason `CA92.1`). On-device settings are `reader.mode`, `obsidian.enabled`, `reader.math`, `reader.textScale`, `reader.width`, `reader.fontDesign` and `reader.positions`; the privacy policy lists every one.

## On-device checklist

Mark each line after the TestFlight or Xcode install. File one bead per failure.

- [ ] Open a `.md` file from Files. Rendered is the default. The title is the file name.
- [ ] From another app, share or Open In a Markdown file. YAMD opens it.
- [ ] Quit, reopen, and open the same file from Recents.
- [ ] On iPad, drag a Markdown file onto the app and it opens.
- [ ] Dark Mode: rendered Markdown and the source view both follow the appearance.
- [ ] Set the system text size to the largest accessibility size. Rendered text and the source view both grow.
- [ ] Obsidian extras (reader menu) is on: a leading YAML front matter block is hidden, and `[[Note]]`, `[[Note|Alias]]`, and `[[Note#Heading]]` show as plain text. Turn it off and those are rendered as written. Source still shows the original file either way.
- [ ] Find: tap the bottom bar's Find, Find in Document in the menu, and ⌘F on iPad. Each switches to Source and opens the system find bar; matches highlight and the arrows move between them. A plain text file has Find and the menu too.
- [ ] A remote image (`![alt](https://…)`) is a link, not an inline image. Tap it and Safari opens. The app does not show the image bytes.
- [ ] Grok Bot: share a message, tap YAMD. It renders (the "Text Document" case). Repeat from Messages, Mail and Files.
- [ ] In the share reader, the info button opens the What was shared panel with the registered types, name and byte count. Copy puts them on the pasteboard.
- [ ] If YAMD is missing from the share sheet, install a Debug build from Xcode, share again, and read the types in the What was shared panel. Debug also accepts `public.data`, so it is offered for anything.
- [ ] Speed budgets: measure the scenarios in `docs/perf/README.md` (cold and warm open, share extension time and memory, 200 KB, 1 MB, Find on 1 MB) on an iPhone 15 Pro or newer Release build, and fill the Device results table with the median of 5.
- [ ] The icon in light, dark and tinted: Home Screen, then Customize.
- [ ] The Home Screen name reads `YAMD`; the App Store name is `YAMD: Yet Another MD Viewer`.
- [ ] VoiceOver: the rotor's Headings steps through a document, a table reads by row and column, and list items read as one element with no "circle".
- [ ] Differentiate Without Color: the system find bar marks the current match by more than color.
- [ ] Largest accessibility text size: wide tables scroll sideways and nothing is truncated.
- [ ] Reduce Motion and Increased Contrast: no animated transitions, and the accent color stays readable.
- [ ] Task lists render as read-only checkboxes, with "Done" and "Not done" read by VoiceOver.
- [ ] Paste: copy Markdown, tap Paste on the launch screen, read it, then Save to Files. Cancel shows nothing.
- [ ] How to Open Files guide: opens from the launch screen and the reader menu; Done closes it.
- [ ] iPad: drag and drop a Markdown file, and open a document in Stage Manager. If drag and drop fails, remove the iPad guide section and the listing bullet.
- [ ] iOS 27: the Paste and How to Open Files buttons still show on the launch screen. If not, move them into `overlayAccessoryView` (see `mdviewApp.swift`).

## v0.2 checks

Run these on a device after the checklist above.

- [ ] Outline: open a document with several headings, open the ••• menu, tap Outline, tap a heading, and the document scrolls to it. A one-heading document shows Outline dimmed, and the top bar never moves. A duplicate heading lands on the first one.
- [ ] Copy: tap the copy button on a code block, paste elsewhere, and the code matches. VoiceOver reads the button as copy.
- [ ] Settings: change text size (the row stays open while you tap), width (iPad only) and font in the menu. Rendered and Source both follow, they survive a relaunch, and Reset returns to normal.
- [ ] Position: scroll halfway, close the file, reopen it from Recents, and it returns near the same spot. A pasted note and a shared item start at the top.
- [ ] PDF: Export PDF on a short and a long document. Pages are Letter or A4 with no cut-off lines. A file over 1 MB says "Too long to export".
- [ ] Print: Print shows the system print dialog with the rendered document.
- [ ] Math: off by default, so `$5 and $10` stays plain. Switch Math (LaTeX) on and `$x^2$` and `\(x^2\)` draw as formulas. Code spans stay literal.
- [ ] Callouts: `> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]` and `> [!tip]- My title` show as tinted boxes with a symbol and bold title, in light and dark, in the app and the share extension.
- [ ] Shortcuts (iPad, hardware keyboard): ⌘1, ⌘2, ⇧⌘O, ⌘F, ⌘+, ⌘−, ⌘0, ⌘P and ⇧⌘E work in a document and are disabled on the launch screen.
- [ ] Screenshots: run `scripts/screenshots.sh` on a Mac, check that `06-outline.png` and `07-tasks.png` exist in both folders, and upload all seven in order.
- [ ] Version: Settings, About or the App Store build shows 0.2.0 (3) for the app and the Share extension.
