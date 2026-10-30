# YAMD app icon directions

Three directions for the app icon, each in three appearances. They are generated, not drawn by hand:

```bash
python3 scripts/generate_app_icon.py --all
```

The script uses only the Python standard library. Every glyph is a vector path (no fonts), one shape list feeds both the SVG and the 4x supersampled PNG, and the output is byte-identical on every run. For one file:
`python3 scripts/generate_app_icon.py --direction a --appearance any --size 1024 --out /tmp/a.png` (`.svg` or `.png` by extension).

Files: `directions/{a,b,c}/{any,dark,tinted}.{svg,png}` and `contact-sheet.png`. The contact sheet shows each direction as any, dark (over black) and tinted (over `#3A6EA5`) at 256 px, then the any image at 180, 120, 87, 58 and 40 px, all clipped to the iOS corner radius.

## Directions

| Direction | Concept | any | dark | tinted |
| --- | --- | --- | --- | --- |
| **A, Folded page** (default) | A page with a dog-ear carrying the Markdown mark: a bold M and a down arrow | White page, green mark, on a `#2E6B4A` to `#1F4A33` gradient | Page `#5BBF8A`, mark `#E8F5EE`, transparent background | Grayscale page and mark, transparent |
| B, YAMD monogram | Geometric "YAMD" letterforms as paths; the V's point doubles as a down arrow | White letters on the gradient | `#5BBF8A` letters, transparent | Grayscale |
| C, Reading lines | An off-white `#F4F1EA` card with a heading bar, three text lines and a checked box | Green shapes on the card, on the gradient | Light card and green shapes, transparent | Grayscale |

B differs from the plan's wording: the V stays a plain V, because a shaft or tail on it read as a "Y" or "MdY" in testing.
A's dark variant has modest contrast between page and mark (about 2:1); strengthen the mark colour if A wins.

## Rules

- 1024 x 1024 sRGB. The `any` PNG is RGB with no alpha (an App Store requirement); `dark` and `tinted` are RGBA with a transparent background.
- No rounded corners baked in. iOS applies the mask.
- Nothing finer than 24 px at 1024.
- Readable at 40 px (Spotlight): check the contact sheet.
- One 1024 image per appearance in a single-size `AppIcon.appiconset`; Xcode generates every device size.
- Icon Composer (`.icon`, Liquid Glass layers) can come later.

## Default and decision

keving picked a final icon for 0.2.0 build 5 (a 1024x1024 RGB PNG, no alpha, based on direction C). It is installed as all three images in `App/mdview/Assets.xcassets/AppIcon.appiconset` (any, dark and tinted), so `make icon` would overwrite it; don't run it unless the icon changes again.
