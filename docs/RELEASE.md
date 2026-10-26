# Release

Version 0.1.0, build 1 (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`). Bundle id `us.par72.mdview`.

Signing happens on keving's Mac. The Team ID stays in the gitignored `Config/Local.xcconfig`. Do not commit it, and do not put an Apple ID or Team ID in the repo.

## Sign and run on a device

1. In `Config/Local.xcconfig`, set `DEVELOPMENT_TEAM` to the Team ID from the Apple Developer account that will sign the app. Leave `PRODUCT_BUNDLE_IDENTIFIER` as `us.par72.mdview`. If the file is missing, `make gen` copies it from `Config/Local.xcconfig.example`.
2. `make open`.
3. Select the mdview target, Signing & Capabilities. Automatically manage signing should already be on with your team. The project sets `CODE_SIGN_STYLE` to Automatic and takes `DEVELOPMENT_TEAM` from `Config/Local.xcconfig`, so `make gen` keeps the team. A team picked only in Xcode is lost on the next `make gen`.
4. On the iPhone, turn on Developer Mode (Settings, Privacy & Security, Developer Mode) and trust the computer.
5. Choose the phone as the run destination and run from Xcode. The first launch asks to trust the developer on the device.

`project.yml` sets no team and no signing identity for the app target. `make build-ios`, `make test`, `make test-ios`, and CI pass `CODE_SIGNING_ALLOWED=NO`, so they build unsigned without a team. Do not put the Team ID into `project.yml`.

## App Store Connect and TestFlight

1. In App Store Connect, create an iOS app named mdview with bundle id `us.par72.mdview`. The SKU can be `mdview`.
2. In Xcode, scheme mdview, Any iOS Device (arm64). Product, Archive. The scheme archives with the Release configuration.
3. In the organizer, Distribute App, App Store Connect, Upload.
4. When the build finishes processing, add it to an internal TestFlight group and install it on the phone.

Export compliance: `Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO` (the app uses no encryption), so App Store Connect does not ask the encryption questions for each build.

Privacy answers for the product page: the app does not track, does not collect data, and does not use the network. The manifest is `App/mdview/PrivacyInfo.xcprivacy` (`NSPrivacyTracking` false, empty tracking domains, empty collected-data types, UserDefaults reason `CA92.1`).

## On-device checklist

Mark each line after the TestFlight or Xcode install. File one bead per failure.

- [ ] Open a `.md` file from Files. Rendered is the default. The title is the file name.
- [ ] From another app, share or Open In a Markdown file. mdview opens it.
- [ ] Quit, reopen, and open the same file from Recents.
- [ ] On iPad, drag a Markdown file onto the app and it opens.
- [ ] Dark Mode: rendered Markdown and the source view both follow the appearance.
- [ ] Set the system text size to the largest accessibility size. Rendered text and the source view both grow.
- [ ] Obsidian extras (reader menu) is on: a leading YAML front matter block is hidden, and `[[Note]]`, `[[Note|Alias]]`, and `[[Note#Heading]]` show as plain text. Turn it off and those are rendered as written. Source still shows the original file either way.
- [ ] Find: type a query, matches are highlighted in the source, the count reads `n of N` (or `No matches`). Submit moves to the next match and wraps. Clear the query and the previous Rendered or Source choice returns.
- [ ] A remote image (`![alt](https://…)`) is a link, not an inline image. Tap it and Safari opens. The app does not show the image bytes.
