# mdview App Store listing

Everything App Store Connect asks for that doesn't need the Apple login. Character counts were measured with Python `len()` on the exact text below. App Store Connect counts characters, not bytes.

Bundle ID `us.par72.mdview`, version 0.1.0 (build 1), SKU `mdview`. iPhone and iPad, iOS 18.0 or later.

## App name

**mdview** (6/30)

Name check, Oct 26, 2026, on the iTunes Search API (`term=mdview`, `entity=software` and `macSoftware`): no app is named exactly "mdview". Close names that already exist: "MDViewer — Quick Markdown" (iOS, Crocopliers OU), "MDView: Markdown Viewer" (Mac, RD Software Services LLP), "MDViewer — Markdown Viewer" (Mac). App names must be unique across the store, so "mdview" should be available, but App Store Connect only confirms that when the app record is created. If it is refused, use the fallback:

**mdview: Markdown Reader** (23/30)

The home screen name stays `mdview` (`CFBundleDisplayName` in `Info.plist`) either way.

## Subtitle

Private Markdown reader

23/30

## Promotional text

Read Markdown files on iPhone and iPad, rendered or as source. Everything stays on your device: no network access, no account, no tracking.

139/170

## Description

```text
mdview opens a Markdown file and shows it. That's the whole app.

Pick a .md file in the Files app, from another app's share sheet, or from Recents, and mdview renders it cleanly: headings, lists, task lists, tables, block quotes, links, and code blocks with syntax highlighting. One tap switches to Source, which shows the file exactly as stored in a monospaced font you can select and copy.

PRIVATE BY DESIGN
• No network access. mdview never connects to the internet.
• No account, no sign-in, no analytics, no ads, no tracking.
• Your files never leave your device. mdview reads them in place and never changes them.
• Web images are not downloaded. They show as a link you can tap to open in Safari. Images stored next to your document are shown inline.

FEATURES
• Opens .md, .markdown, .mdown, and plain text files from Files, iCloud Drive, other file providers, Share, Open In, and Recents.
• Rendered and Source views, with your choice remembered.
• Find in document: matches are highlighted with a running "2 of 7" count.
• Obsidian extras: hides YAML front matter and shows [[wikilinks]] as plain text. Turn it off in the menu to see them as written.
• Follows Dark Mode and Dynamic Type.
• iPhone and iPad, including drag and drop on iPad.

WHAT IT ISN'T
mdview is a viewer, not an editor. It doesn't sync, and it doesn't manage a library of notes. It opens the file you choose and gets out of the way.

mdview is open source under the MIT license: github.com/khgouldy/mdview
```

1488/4000

## Keywords

```text
md,viewer,notes,readme,preview,offline,wikilinks,yaml,front matter,plain text,txt,docs,code,syntax
```

98/100. Comma separated, no spaces after commas. Words already in the name and subtitle (mdview, markdown, private, reader) are left out because Apple indexes those anyway. Third-party trademarks (Obsidian, GitHub) are left out of the keywords to avoid a guideline 2.3.7 rejection; the description mentions Obsidian only to describe a feature.

## Categories

- Primary: Productivity
- Secondary: Utilities

## Copyright

2026 Kevin Gould

## URLs

- Privacy policy URL: https://khgouldy.github.io/mdview/privacy/
- Support URL: https://khgouldy.github.io/mdview/support/
- Marketing URL (optional): https://khgouldy.github.io/mdview/

## Age rating

Answer None / No to every question:

| Question | Answer |
| --- | --- |
| Cartoon or fantasy violence | None |
| Realistic violence | None |
| Prolonged graphic or sadistic realistic violence | None |
| Profanity or crude humor | None |
| Mature or suggestive themes | None |
| Horror or fear themes | None |
| Medical or treatment information | None |
| Alcohol, tobacco, or drug use or references | None |
| Simulated gambling | None |
| Sexual content or nudity | None |
| Graphic sexual content and nudity | None |
| Contests | None |
| Unrestricted web access | No |
| Gambling | No |
| User-generated content (social, messaging) | No |
| Loot boxes, in-app purchases, advertising, parental controls, age assurance | No |

Expected rating: 4+ (the lowest band). Note for the reviewer and for the "user-generated content" question: mdview displays files the user opens from their own device. It has no unrestricted web access (no browser, no network), no sharing between users, and no content from the developer beyond the app itself. Displaying the user's own local files is not user-generated content in Apple's sense, so the answer is No.

## App privacy (privacy nutrition label)

- Data collection: **No, we do not collect data from this app.**
- Resulting label: **Data Not Collected**
- Tracking: none. `App/mdview/PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` false, no tracking domains, no collected data types, and the UserDefaults required-reason API with reason `CA92.1` (two on-device settings: `reader.mode` and `obsidian.enabled`).

## Export compliance

The app uses no encryption. `App/mdview/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO`, so App Store Connect skips the encryption questions for each build. If asked anyway: "Does your app use encryption?" No. No export compliance documentation is needed.

## Content rights

Does the app contain, show, or access third-party content? No. It shows only files the user opens. (Bundled open-source code and licenses are listed in `THIRD_PARTY_NOTICES.md`.)

## Pricing and availability

- Availability: United States, Canada, and Mexico only. Deselect every other country or region in App Store Connect.
- The app is not offered in the European Union, so the Digital Services Act trader status and trader contact information are not needed. If EU storefronts are added later, the DSA trader declaration must be completed first.
- Price: set in App Store Connect.

## Apple account facts

- Bundle ID `us.par72.mdview` is registered with Apple.
- The signing Team ID is set in the gitignored `Config/Local.xcconfig` (not committed, per `docs/RELEASE.md`).

## App Review information

- Sign-in required: **No.** There is no account or login.
- Contact email: support@par72.us
- Contact name and phone: fill in App Store Connect.
- Notes:

```text
mdview is a local Markdown viewer. No login, account, or network access is needed.

To test: launch mdview. The system document browser appears. Open any .md file from Files (for example, save a README.md from any GitHub repository to On My iPhone, or create a text file named test.md). The file opens rendered. Use the Rendered / Source control at the bottom to switch views. Pull down on the document to show Find and type a word to see matches highlighted. The ellipsis menu (top right) has one setting, Obsidian extras, which hides YAML front matter and shows [[wikilinks]] as plain text.

The app never uses the network. Web images in a document are shown as a link that opens Safari only when tapped. The app collects no data.
```

## Screenshots

Taken on the simulator with `scripts/screenshots.sh`. See `docs/app-store/screenshots/`.

- iPhone 6.9" display (iPhone 16 Pro Max, 1320 x 2868): `screenshots/iphone-6.9/`
- iPad 13" display (iPad Pro 13-inch (M4), 2064 x 2752): `screenshots/ipad-13/`

Upload order: rendered light, rendered dark, source, find, Obsidian.
