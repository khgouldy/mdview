---
title: MdV Privacy Policy
permalink: /privacy/
---

# MdV Privacy Policy

Effective date: October 26, 2026

MdV is a Markdown viewer for iPhone and iPad, published by Kevin Gould / Par72 Labs, LLC. This policy covers the MdV app (bundle ID `us.par72.mdview`).

## Summary

MdV does not collect any data. It has no network access, no accounts, no analytics, no advertising, and no tracking. The files you open never leave your device.

## Data we collect

None. MdV does not collect, store on a server, sell, or share any personal information or usage data. There is no server to send it to.

## Your files

MdV reads the Markdown and text files you choose to open, through the iOS document browser, the Files app, the share sheet, Open In, or drag and drop. The app only reads files you open. It shows them on screen and does not upload, copy to any server, or modify them. Images referenced by a document are shown only when they are local files next to the document. Web images (`http` or `https`) are never downloaded; they appear as a link that opens in Safari only if you tap it.

## Network access

MdV does not connect to the internet. It contains no networking code and no analytics, advertising, or crash-reporting SDKs. The only third-party code is open-source Markdown rendering libraries that run on the device.

## Share extension and Paste

MdV includes a Share extension, so you can choose MdV in any app's share sheet. It reads only the one item you share, shows it on screen, and keeps nothing: no copy, no history, no upload. When you tap Done it is gone. If you use Paste Markdown, the pasted text stays in memory while it is on screen and is discarded when you close it, unless you choose Save to Files, which writes the file where you pick. MdV reads the clipboard only when you tap Paste.

## Settings stored on your device

MdV stores these preferences in the app's on-device settings:

- whether documents open in Rendered or Source view
- whether Obsidian extras are on
- text size (`reader.textScale`, 0.85 to 1.6)
- column width (`reader.width`: 560, 680 or 860 points)
- font style (`reader.fontDesign`: system, serif or mono)
- where you stopped reading (`reader.positions`): for the 200 most recently opened files, one scroll position (a number from 0 to 1) is kept so a file reopens where you left it. Each file is identified only by a SHA-256 hash of its path, so no file name or content is stored. Pasted text and items from the Share extension have no file, so nothing is kept for them. Deleting the app removes these positions.

iOS also keeps its own list of recently opened documents for the document browser. These stay on your device and are removed when you delete the app (the Recents list is managed by iOS).

## Tracking

MdV does not track you across apps or websites, and it does not use the advertising identifier.

## Children

MdV collects no data from anyone, including children.

## Changes

If this policy changes, the new version will be posted on this page with a new effective date.

## Contact

Questions about privacy: [support@par72.us](mailto:support@par72.us)
