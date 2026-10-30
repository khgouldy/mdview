---
title: YAMD Support
permalink: /support/
---

# YAMD Support

YAMD is a private Markdown viewer for iPhone and iPad (iOS 18 and later). Open a `.md`, `.markdown`, `.mdown`, or plain text file and read it, rendered or as source. Everything happens on your device: no network access, no account, no analytics.

## Contact

- Email: [support@par72.us](mailto:support@par72.us)
- Bug reports and feature requests: [GitHub issues](https://github.com/khgouldy/mdview/issues)

## FAQ

### How do I open a file?

Launch YAMD and pick a file in the document browser, which shows the same locations as the Files app (On My iPhone or iPad, iCloud Drive, and any file providers you have enabled). You can also:

- In the Files app, tap a Markdown file, or long-press it and choose Share, then YAMD.
- From another app, use Share and choose YAMD to read it in place, or Open In to open it in the full app.
- On iPad, drag a Markdown file onto YAMD.
- Copy Markdown text and tap Paste on the launch screen.
- Reopen a file from Recents in the document browser.

YAMD reads the file where it is. It does not make a copy.

### Open a Markdown file someone sent me in a chat app

Try these in order:

1. **Share, then tap YAMD.** In the chat app, tap Share on the message or file and choose YAMD in the app row. YAMD shows it right there, rendered, with a Source switch and no app change. The first time, YAMD may sit under More: tap More, then Edit, and add YAMD to Favorites. After that it is one tap. Tap Done to close.
2. **Share a file, then choose YAMD as the Open In target.** If the chat app shares a file with a Markdown or text extension, YAMD can open it in the full app.
3. **Copy and paste.** Copy the text, open YAMD, and tap Paste on the launch screen. YAMD shows it as a document. Use Save to Files to keep it.
4. **Save to Files, then open it in YAMD.** Choose Save to Files in the chat app's share sheet, then open the saved file from YAMD's document browser.

YAMD's How to Open Files guide on the launch screen (and in the reader menu) explains the same steps.

### Why does the share sheet say Text Document?

Some chat apps share a message as plain text with no file name, so iOS can only label it "Text Document". It is still your Markdown. Tap YAMD in the share sheet and it opens as Shared Text, rendered as Markdown. If YAMD is not offered, tap More and add it to Favorites. If it still does not appear, email [support@par72.us](mailto:support@par72.us) with the app you shared from.

### What does the Obsidian extras toggle do?

Open the ••• menu (top right of a document; VoiceOver calls it More) and switch Obsidian extras on or off under Rendering. It is on by default. When it is on, YAMD hides a YAML front matter block at the top of the file and shows wikilinks such as `[[Note]]`, `[[Note|Alias]]`, and `[[Note#Heading]]` as plain text. When it is off, those are shown exactly as written. The setting does not change your file.

### How do I jump to a heading?

Open the ••• menu and tap Outline, then tap a heading. If you are in Source, YAMD switches to Rendered first. Outline is dimmed when the document has fewer than two headings. On iPad with a keyboard, press ⇧⌘O.

### Does YAMD remember where I stopped reading?

Yes. When you reopen a file, YAMD scrolls back to where you left it. It keeps this for your 200 most recent files, stores only a position and a hash of the file's path (never a name or content), and keeps it on your device. Deleting the app removes it. Pasted text and items from the Share extension are not remembered.

### How do I change the text size, width or font?

Open the ••• menu and use the Reading section. The text size row (smaller, Reset, larger) keeps the menu open, so you can tap it a few times and watch the text change. Below it are column width (Narrow, Standard, Wide) and font (System, Serif, Mono). They apply on top of your system text size. Plain text files show only the text size row. Column width is on iPad only: an iPhone screen is narrower than every column width, so the menu leaves it out there (and in a narrow iPad Split View or Slide Over window).

### What is in the ••• menu?

From top to bottom, for Markdown: Outline and Find in Document; Reading (text size, column width on iPad, font); Rendering (Obsidian extras, Math (LaTeX)); Export PDF and Print; How to Open Files. Plain text files get the text size row and How to Open Files.

### How do I copy a code block?

Tap the copy button (two overlapping pages) in the code block's header row; it turns into a checkmark for a moment. The code goes to your clipboard. You can also touch and hold the block and choose Copy Code.

### How do I save a PDF or print?

Open the menu and choose Export PDF or Print. The PDF is built on your device and handed to the share sheet, so you choose where it goes. Documents over 1 MB are too long to export.

### What is Math (LaTeX)?

Math is off by default, so text like `$5 and $10` stays as written. Switch Math (LaTeX) on in the menu and `$…$`, `$$…$$`, `\(…\)` and `\[…\]` draw as formulas. Math is drawn on your device with no network. Very large sections (over 64 KB) show the formula source.

### What is Source view?

Use the Rendered / Source control at the bottom of the screen. Source shows the file exactly as stored, in a monospaced font you can select and copy. YAMD remembers your choice for the next document. Plain text files always open in Source.

### How do I search in a document?

Tap Find (the magnifying glass next to Rendered / Source at the bottom of the screen), choose Find in Document in the ••• menu, or press ⌘F on iPad. YAMD switches to Source and opens the system find bar: type to highlight every match, and use the arrows to move between them. Tap Rendered to go back to the rendered document.

### What keyboard shortcuts are there?

On iPad with a hardware keyboard, the View menu (hold ⌘ to see it) works while a document is open. The shortcuts are disabled on the launch screen.

| Shortcut | Action |
| --- | --- |
| ⌘1 | Rendered |
| ⌘2 | Source |
| ⇧⌘O | Outline (rendered Markdown with two or more headings) |
| ⌘+ | Larger text |
| ⌘− | Smaller text |
| ⌘0 | Actual size |
| ⌘P | Print |
| ⇧⌘E | Export PDF |
| ⌘F | Find in Document |

### Does YAMD show callouts?

Yes. GitHub alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`, in any letter case) show as a tinted box with a colored bar, a symbol and a bold title. With Obsidian extras on, Obsidian callouts such as `> [!info]`, `> [!success]`, `> [!question]` or `> [!danger]` use the closest of those five looks, and a title after the marker (`> [!tip] My title`) replaces the default one. Foldable callouts (`[!tip]-`) are always shown open.

### Why don't web images show?

YAMD never uses the network, so images from `http` or `https` addresses are shown as a link instead. Tap the link to open the image in Safari. Images stored next to your document (relative paths) are shown inline.

### Does YAMD edit files?

No. YAMD is a viewer. It never changes your files.

### Does it follow Dark Mode and text size?

Yes. Rendered and Source views follow the system appearance and Dynamic Type.

## Reporting a bug

Email [support@par72.us](mailto:support@par72.us) or open an issue at [github.com/khgouldy/mdview/issues](https://github.com/khgouldy/mdview/issues). Please include:

- your device model and iOS version
- the YAMD version (listed on its App Store page under Version History)
- what you did, what you expected, and what happened
- if you can share it, a small Markdown file that shows the problem

YAMD is open source under the MIT license: [github.com/khgouldy/mdview](https://github.com/khgouldy/mdview).
