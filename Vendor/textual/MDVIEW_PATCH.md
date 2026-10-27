# Vendored Textual

Textual 0.5.0 (https://github.com/gonzalezreal/textual, tag 0.5.0, `01b51875a5406eefc95f52a058cb059e7bc94dc4`), MIT
(`LICENSE`). Only `Sources`, `LICENSE`, `LICENSE-3rdparty.csv` and `Package.swift` are copied. `Package.swift` drops the
`TextualTests` target and its swift-snapshot-testing dependency. Everything else is upstream except the patch below.

## Patch: link and selection hit-testing follows the text

`Sources/Textual/Internal/TextInteraction/Shared/TextLayout/LiveTextLayoutCollection.swift`. `LiveTextLayoutCollection`
resolves each text layout's origin in `init`, while the `GeometryProxy` from `overlayTextLayoutCollection` is valid,
and `isEqual(to:)` compares those origins as well as the anchored layouts.

Why: upstream stored the `GeometryProxy`, resolved origins lazily (first use was often a tap), and treated two
collections with the same anchors as equal even after the text moved. `TextSelectionModel.url(for:)` then looked for
links at stale positions. `UITextInteractionView.handleTap(_:)` found no link and only cleared the selection, so a
tapped link did nothing. It showed up in the reader once commit 8ef4b69 (native Find bar) removed the `.searchable`
drawer, which changed how the content settles at launch. Selection rects use the same origins, so they benefit too.

Bisect, experiments and CI runs: `link-bisect-notes.md` in the release notes folder, and the commit message.
Guarded by `ReaderAccessibilityTests.testLinkInHeadingStillOpens` on CI.

## Upgrading

Drop this patch only if upstream resolves layout origins eagerly (or otherwise fixes link taps under selection); otherwise re-apply it to the new version and keep
the test passing on CI.
