# MdV App Store listing

Everything App Store Connect asks for that doesn't need the Apple login. Character counts were measured with Python `len()` on the exact text below. App Store Connect counts characters, not bytes.

Bundle ID `us.par72.mdview`, version 0.1.0 (build 2), SKU `mdview`. iPhone and iPad, iOS 18.0 or later.

## App name

**MdV: Markdown Viewer** (20/30)

The home screen name is `MdV`. It comes from `APP_DISPLAY_NAME` in `project.yml` through `CFBundleDisplayName` in `Info.plist`. The bundle ID, SKU, repo, scheme and target stay `mdview`. `make lint` fails if this heading and `APP_DISPLAY_NAME` disagree.

Name check, Oct 26, 2026 (App Store search): no app is named MdV. "Midea MDV" (an HVAC remote) and "MDView: Markdown Viewer" exist. App names must be unique across the store, so only App Store Connect confirms availability, when the app record is created or renamed. If MdV is refused, pick another row below and change `APP_DISPLAY_NAME` (one line) and this heading together.

| # | Home-screen name | App Store name (chars) | Notes |
| --- | --- | --- | --- |
| 1 | **MdV** | **MdV: Markdown Viewer** (20) | **Chosen.** Three letters, reads as "Markdown Viewer". VoiceOver says "M D V". |
| 2 | MDV | MDV: Markdown Viewer (20) | Reads like an acronym (DMV, Midea MDV) |
| 3 | Mdown | Mdown: Markdown Viewer (22) | Nods to the `.mdown` extension; looks lowercase-ish |
| 4 | Markd | Markd: Markdown Reader (22) | Short word mark; "marked" pun |
| 5 | Marky | Marky: Markdown Viewer (22) | Friendly; less serious |
| 6 | Margin | Margin: Markdown Reader (23) | A reading word; generic, likely taken |
| 7 | Inkdown | Inkdown: Markdown Reader (24) | Distinctive; not obviously "md" |
| 8 | Downmark | Downmark: Markdown Reader (25) | Inverts "Markdown"; long on the home screen |

Rejected: MDView / MdView (clashes with "MDView: Markdown Viewer").

## Subtitle

Private Markdown reader

23/30

## Promotional text

Read Markdown files on iPhone and iPad, rendered or as source. Everything stays on your device: no network access, no account, no tracking.

139/170

## Description

```text
MdV opens a Markdown file and shows it. That's the whole app.

Pick a .md file in the Files app or from Recents, and MdV renders it cleanly: headings, lists, task lists, tables, block quotes, links, and code blocks with syntax highlighting. One tap switches to Source, which shows the file exactly as stored in a monospaced font you can select and copy.

READ ANYTHING SHARED TO YOU
• Share any Markdown or text to MdV from any app's share sheet and read it instantly. It opens right there, with no app switch.
• Paste Markdown: copy text from a chat or an email, open MdV, and tap Paste. Save it to Files if you want to keep it.
• A built-in guide, How to Open Files, shows every way to get a file into MdV.

PRIVATE BY DESIGN
• No network access. MdV never connects to the internet.
• No account, no sign-in, no analytics, no ads, no tracking.
• Your files never leave your device. MdV reads them in place and never changes them.
• Web images are not downloaded. They show as a link you can tap to open in Safari. Images stored next to your document are shown inline.

FEATURES
• Opens .md, .markdown, .mdown, and plain text files from Files, iCloud Drive, other file providers, Share, Open In, and Recents.
• Rendered and Source views, with your choice remembered.
• Find in document: matches are highlighted with a running "2 of 7" count.
• Obsidian extras: hides YAML front matter and shows [[wikilinks]] as plain text. Turn it off in the menu to see them as written.
• Follows Dark Mode and Dynamic Type, and works with VoiceOver.
• iPhone and iPad, including drag and drop on iPad.

WHAT IT ISN'T
MdV is a viewer, not an editor. It doesn't sync, and it doesn't manage a library of notes. It opens the file you choose and gets out of the way.

MdV is open source under the MIT license: github.com/khgouldy/mdview
```

1818/4000

## Keywords

```text
md,viewer,notes,readme,preview,offline,wikilinks,yaml,front matter,plain text,txt,docs,code,syntax
```

98/100. Comma separated, no spaces after commas. Words already in the name and subtitle (MdV, markdown, private, reader) are left out because Apple indexes those anyway. Third-party trademarks (Obsidian, GitHub) are left out of the keywords to avoid a guideline 2.3.7 rejection; the description mentions Obsidian only to describe a feature.

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

Expected rating: 4+ (the lowest band). Note for the reviewer and for the "user-generated content" question: MdV displays files the user opens from their own device. It has no unrestricted web access (no browser, no network), no sharing between users, and no content from the developer beyond the app itself. Displaying the user's own local files is not user-generated content in Apple's sense, so the answer is No.

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
- Notes (1219/4000 characters):

```text
MdV is a local Markdown viewer. No login, account, or network access is needed.

The app includes a Share extension (MdV in the share sheet). It shows the one text or Markdown item you share, in the share sheet itself. It reads only that item, keeps nothing, and never leaves the device or opens the network. To test it: in Notes or Messages, select some Markdown text, tap Share, and choose MdV (under More the first time). It renders; Done closes it. The launch screen also has Paste, which shows the clipboard as a document, and How to Open Files, a guide.

To test the main app: launch MdV. The system document browser appears. Open any .md file from Files (for example, save a README.md from any GitHub repository to On My iPhone, or create a text file named test.md). The file opens rendered. Use the Rendered / Source control at the bottom to switch views. Pull down on the document to show Find and type a word to see matches highlighted. The ellipsis menu (top right) has one setting, Obsidian extras, which hides YAML front matter and shows [[wikilinks]] as plain text.

The app never uses the network. Web images in a document are shown as a link that opens Safari only when tapped. The app collects no data.
```

## Screenshots

Taken on the simulator with `scripts/screenshots.sh`. See `docs/app-store/screenshots/`.

- iPhone 6.9" display (iPhone 16 Pro Max, 1320 x 2868): `screenshots/iphone-6.9/`
- iPad 13" display (iPad Pro 13-inch (M4), 2064 x 2752): `screenshots/ipad-13/`

Upload order: rendered light, rendered dark, source, find, Obsidian.

If L10 finds drag and drop broken, remove the iPad drag-and-drop bullet from the description and recount.
