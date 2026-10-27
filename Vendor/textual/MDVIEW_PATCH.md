# Vendored Textual

Textual 0.5.0 (https://github.com/gonzalezreal/textual, tag 0.5.0, `01b51875a5406eefc95f52a058cb059e7bc94dc4`), MIT
(`LICENSE`). Only `Sources`, `LICENSE`, `LICENSE-3rdparty.csv` and `Package.swift` are copied. `Package.swift` drops the
`TextualTests` target and its swift-snapshot-testing dependency. Everything else is upstream except the patch below.

## Patch: links open with text selection on

`Sources/Textual/Internal/TextInteraction/UIKit/UITextInteractionView.swift`, `point(inside:with:)` returns `false`
when `model.url(for:)` finds a link under the point.

Why: with `.textual.textSelection(.enabled)`, `UITextInteractionView` covers the text. Its link tap
(`handleTap(_:)`) is required to wait for every `UITextInteraction` selection gesture to fail. On iOS 26, once the
reader no longer had a `.searchable` drawer (commit 8ef4b69, native Find bar), a selection gesture claimed single
taps, so tapping a link did nothing. With the patch, a touch on a link goes to the fragment's own SwiftUI link tap
(`TextLinkInteraction`), the same path used when selection is off.

Trade-off: a long press that starts on a link does not start a text selection. Selection that starts elsewhere can
still extend across a link.

Guarded by `ReaderAccessibilityTests.testLinkInHeadingStillOpens` (CI). Bisect notes: commit history around 8ef4b69.

## Upgrading

Drop this patch only if upstream fixes link taps under selection; otherwise re-apply it to the new version and keep
the test passing on CI.
