# Vendored Textual

Textual 0.5.0 (https://github.com/gonzalezreal/textual, tag 0.5.0, `01b51875a5406eefc95f52a058cb059e7bc94dc4`), MIT
(`LICENSE`). Only `Sources`, `LICENSE`, `LICENSE-3rdparty.csv` and `Package.swift` are copied. `Package.swift` drops the
`TextualTests` target and its swift-snapshot-testing dependency. Everything else is upstream except the patch below.

## Patch: the selection overlay sees the text it covers (link taps)

Two files under `Sources/Textual/Internal/TextInteraction/Shared/`, each change marked `MDView patch`:

1. `TextSelectionInteraction.swift` and `TextSelectionModel.swift`. The overlay that reads the `Text.LayoutKey`
   preference calls the new `TextSelectionModel.receiveLayoutCollection(_:)` on every pass. While nothing is
   selected it stores the new collection directly (the stored collection is not observed, so this changes no view
   state). With a selection it does nothing and upstream's `onChange(of:initial:)` path reconciles as before.
2. `TextLayout/LiveTextLayoutCollection.swift`. `LiveTextLayoutCollection` resolves each layout's origin in `init`,
   while the `GeometryProxy` is valid, and `isEqual(to:)` compares those origins as well as the anchored layouts.
   Needed because (1) keeps collections built during a view update; upstream resolved origins lazily, usually at
   the first tap.

Why: upstream only fed the model from `onChange(of: AnyTextLayoutCollection(...), initial: true)` inside that
overlay. In MDView's reader it fired once, for the initial empty preference value, and never for the later value
that held the text (CI logging showed the preference reaching 3 text fragments while the model stayed at 0
layouts). `UITextInteractionView.handleTap(_:)` then got `nil` from `url(for:)` and only cleared the selection, so
a tapped link did nothing. It showed up once commit 8ef4b69 (native Find bar) removed the `.searchable` drawer,
whose extra update pass used to re-deliver the value.

Caveat: with a selection active, a layout change still depends on upstream's `onChange` path, so a stale hit-map
there is possible; tapping to clear the selection, then tapping the link, works.

Bisect, experiments and CI runs: `link-bisect-notes.md` in the release notes folder, and the commit message.
Guarded by `ReaderAccessibilityTests.testLinkInHeadingStillOpens` on CI.

## Upgrading

Drop this patch only if upstream feeds the selection model every layout change and resolves origins eagerly (or otherwise fixes link taps under selection); otherwise re-apply it to the new version and keep
the test passing on CI.
