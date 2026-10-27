#!/usr/bin/env python3
"""Generate the MdV app icon directions as SVG and PNG.

Stdlib only, no network, no fonts: every glyph is a vector path. One shape
list per icon renders to both formats, so the SVG and the PNG always match.
Output is deterministic (same bytes on every run).

    python3 scripts/generate_app_icon.py --all
    python3 scripts/generate_app_icon.py --direction a --appearance any --size 1024 --out /tmp/a.png

`--all` writes docs/app-store/icon/directions/{a,b,c}/{any,dark,tinted}.{svg,png}
and docs/app-store/icon/contact-sheet.png. `--out` picks SVG or PNG by its
extension. The "any" image is opaque RGB (an App Store requirement); dark and
tinted are RGBA with a transparent background.
"""

from __future__ import annotations

import argparse
import math
import struct
import sys
import zlib
from dataclasses import dataclass
import pathlib
from pathlib import Path

CANVAS = 1024
SS = 4  # supersampling factor per axis

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "docs" / "app-store" / "icon"

RGB = tuple[int, int, int]
KAPPA = 0.5522847498


def hexrgb(value: str) -> RGB:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def hexstr(color: RGB) -> str:
    return "#%02X%02X%02X" % color


# ---------------------------------------------------------------- vector model


@dataclass(frozen=True)
class Gradient:
    """Vertical linear gradient from y0 (color c0) to y1 (color c1), canvas units."""

    y0: float
    y1: float
    c0: RGB
    c1: RGB

    def at(self, y: float) -> RGB:
        t = min(1.0, max(0.0, (y - self.y0) / (self.y1 - self.y0)))
        return tuple(int(round(a + (b - a) * t)) for a, b in zip(self.c0, self.c1))  # type: ignore[return-value]


Fill = RGB | Gradient


def fmt(value: float) -> str:
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("-0", "") else "0"


def flatten_cubic(p0, p1, p2, p3, steps: int = 24):
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        points.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return points


@dataclass
class Path:
    """Filled path. Commands: ("M",x,y) ("L",x,y) ("C",x1,y1,x2,y2,x,y) ("Z",)."""

    commands: list[tuple]
    fill: Fill

    def contours(self) -> list[list[tuple[float, float]]]:
        result: list[list[tuple[float, float]]] = []
        current: list[tuple[float, float]] = []
        for command in self.commands:
            op = command[0]
            if op == "M":
                if len(current) > 2:
                    result.append(current)
                current = [(command[1], command[2])]
            elif op == "L":
                current.append((command[1], command[2]))
            elif op == "C":
                current.extend(flatten_cubic(current[-1], command[1:3], command[3:5], command[5:7]))
            elif op == "Z":
                if len(current) > 2:
                    result.append(current)
                current = []
        if len(current) > 2:
            result.append(current)
        return result

    def svg_d(self) -> str:
        parts = []
        for command in self.commands:
            parts.append(command[0] + " ".join(fmt(v) for v in command[1:]))
        return "".join(parts)


@dataclass
class Stroke:
    """Stroked polyline with round caps and joins."""

    points: list[tuple[float, float]]
    width: float
    fill: RGB

    def contours(self) -> list[list[tuple[float, float]]]:
        half = self.width / 2
        pieces: list[list[tuple[float, float]]] = []
        for (x0, y0), (x1, y1) in zip(self.points, self.points[1:]):
            length = math.hypot(x1 - x0, y1 - y0)
            if length == 0:
                continue
            nx, ny = -(y1 - y0) / length * half, (x1 - x0) / length * half
            pieces.append([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])
        for cx, cy in self.points:
            pieces.append([(cx + half * math.cos(a * math.pi / 24), cy + half * math.sin(a * math.pi / 24)) for a in range(48)])
        # One winding direction for every piece so the nonzero union never cancels.
        oriented = []
        for piece in pieces:
            area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(piece, piece[1:] + piece[:1]))
            oriented.append(piece if area > 0 else piece[::-1])
        return oriented

    def svg_d(self) -> str:
        first, *rest = self.points
        return f"M{fmt(first[0])} {fmt(first[1])}" + "".join(f"L{fmt(x)} {fmt(y)}" for x, y in rest)


Shape = Path | Stroke


def rrect(x: float, y: float, w: float, h: float, r: float, fill: Fill) -> Path:
    k = r * KAPPA
    return Path(
        [
            ("M", x + r, y),
            ("L", x + w - r, y),
            ("C", x + w - r + k, y, x + w, y + r - k, x + w, y + r),
            ("L", x + w, y + h - r),
            ("C", x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h),
            ("L", x + r, y + h),
            ("C", x + r - k, y + h, x, y + h - r + k, x, y + h - r),
            ("L", x, y + r),
            ("C", x, y + r - k, x + r - k, y, x + r, y),
            ("Z",),
        ],
        fill,
    )


def polygon(points: list[tuple[float, float]], fill: Fill) -> Path:
    commands: list[tuple] = [("M", *points[0])] + [("L", *p) for p in points[1:]] + [("Z",)]
    return Path(commands, fill)


@dataclass
class Scene:
    shapes: list[Shape]
    opaque: bool  # True when the shapes fully cover the canvas (the "any" image)

    def to_svg(self) -> str:
        defs: list[str] = []
        body: list[str] = []
        for shape in self.shapes:
            if isinstance(shape.fill, Gradient):
                gid = f"g{len(defs)}"
                g = shape.fill
                defs.append(
                    f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="0" y1="{fmt(g.y0)}" x2="0" y2="{fmt(g.y1)}">'
                    f'<stop offset="0" stop-color="{hexstr(g.c0)}"/><stop offset="1" stop-color="{hexstr(g.c1)}"/></linearGradient>'
                )
                paint = f"url(#{gid})"
            else:
                paint = hexstr(shape.fill)
            if isinstance(shape, Stroke):
                body.append(
                    f'<path d="{shape.svg_d()}" fill="none" stroke="{paint}" stroke-width="{fmt(shape.width)}" '
                    'stroke-linecap="round" stroke-linejoin="round"/>'
                )
            else:
                body.append(f'<path d="{shape.svg_d()}" fill="{paint}"/>')
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" height="{CANVAS}">']
        if defs:
            out.append("<defs>" + "".join(defs) + "</defs>")
        out.extend(body)
        out.append("</svg>")
        return "\n".join(out) + "\n"


# ------------------------------------------------------------------- rasterizer


def scanline_spans(contours, scale: float, rows: int, width: int) -> dict[int, list[tuple[int, int]]]:
    """Nonzero-winding spans per sample row. Samples are tested at their centers."""
    crossings: dict[int, list[tuple[float, int]]] = {}
    for contour in contours:
        pts = [(x * scale, y * scale) for x, y in contour]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
            if y0 == y1:
                continue
            direction = 1 if y1 > y0 else -1
            lo, hi = (y0, y1) if y0 < y1 else (y1, y0)
            first = max(0, math.ceil(lo - 0.5))
            last = min(rows - 1, math.ceil(hi - 0.5) - 1)
            slope = (x1 - x0) / (y1 - y0)
            for row in range(first, last + 1):
                crossings.setdefault(row, []).append((x0 + (row + 0.5 - y0) * slope, direction))
    spans: dict[int, list[tuple[int, int]]] = {}
    for row, items in crossings.items():
        items.sort()
        winding = 0
        start = 0.0
        row_spans = []
        for x, direction in items:
            if winding == 0:
                start = x
            winding += direction
            if winding == 0:
                c0 = max(0, math.ceil(start - 0.5))
                c1 = min(width, math.ceil(x - 0.5))
                if c1 > c0:
                    row_spans.append((c0, c1))
        if row_spans:
            spans[row] = row_spans
    return spans


def render(scene: Scene, size: int) -> bytes:
    """Returns interleaved un-premultiplied RGBA, size x size, 4x4 supersampled."""
    scale = size / CANVAS * SS
    big = size * SS
    layers = [(spans, shape.fill) for shape in scene.shapes for spans in [scanline_spans(shape.contours(), scale, big, big)]]
    out = bytearray(size * size * 4)
    planes_rows: list[list[bytearray]] = []  # per sub-row: [r, g, b, a]
    for sub in range(big):
        planes = [bytearray(big) for _ in range(4)]
        y_canvas = (sub + 0.5) / scale
        for spans, fill in layers:
            row_spans = spans.get(sub)
            if not row_spans:
                continue
            color = fill.at(y_canvas) if isinstance(fill, Gradient) else fill
            for c0, c1 in row_spans:
                n = c1 - c0
                planes[0][c0:c1] = bytes([color[0]]) * n
                planes[1][c0:c1] = bytes([color[1]]) * n
                planes[2][c0:c1] = bytes([color[2]]) * n
                planes[3][c0:c1] = b"\xff" * n
        planes_rows.append(planes)
        if (sub + 1) % SS:
            continue
        row = (sub + 1) // SS - 1
        group = planes_rows
        planes_rows = []
        sums = []
        for p in range(3 if scene.opaque else 4):
            slices = [plane[p][k::SS] for plane in group for k in range(SS)]
            sums.append([sum(t) for t in zip(*slices)])
        base = row * size * 4
        if scene.opaque:
            for p in range(3):
                out[base + p : base + size * 4 : 4] = bytes(v >> 4 for v in sums[p])
            out[base + 3 : base + size * 4 : 4] = b"\xff" * size
        else:
            a_sum = sums[3]
            full = SS * SS * 255
            for p in range(3):
                out[base + p : base + size * 4 : 4] = bytes(
                    (v // (SS * SS) if a == full else ((v * 255 + a // 2) // a if a else 0)) for v, a in zip(sums[p], a_sum)
                )
            out[base + 3 : base + size * 4 : 4] = bytes((a + 8) >> 4 for a in a_sum)
    return bytes(out)


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def encode_png(width: int, height: int, rgba: bytes, with_alpha: bool) -> bytes:
    rows = bytearray()
    for y in range(height):
        row = rgba[y * width * 4 : (y + 1) * width * 4]
        rows.append(0)
        if with_alpha:
            rows.extend(row)
        else:
            rgb = bytearray(width * 3)
            for p in range(3):
                rgb[p::3] = row[p::4]
            rows.extend(rgb)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if with_alpha else 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + png_chunk(b"IEND", b"")


# ------------------------------------------------------------------- icon designs

GREEN_TOP = hexrgb("#2E6B4A")
GREEN_BOTTOM = hexrgb("#1F4A33")
MINT_DARK = hexrgb("#5BBF8A")
MINT_LIGHT = hexrgb("#E8F5EE")
WHITE = (255, 255, 255)
CARD = hexrgb("#F4F1EA")


def background() -> Path:
    return rrect(0, 0, CANVAS, CANVAS, 0, Gradient(0, CANVAS, GREEN_TOP, GREEN_BOTTOM))


def palette(appearance: str, any_: dict[str, RGB], dark: dict[str, RGB], tinted: dict[str, RGB]) -> dict[str, RGB]:
    return {"any": any_, "dark": dark, "tinted": tinted}[appearance]


def md_mark(color: RGB, width: float, shift_x: float = 0, shift_y: float = 0) -> list[Shape]:
    """The Markdown mark: a bold M and a down arrow, as stroked paths."""
    sx, sy = shift_x, shift_y
    m = [(300, 698), (300, 462), (400, 598), (500, 462), (500, 698)]
    stem = [(650, 462), (650, 640)]
    head = [(590, 600), (650, 686), (710, 600)]
    return [Stroke([(x + sx, y + sy) for x, y in pts], width, color) for pts in (m, stem, head)]


def direction_a(appearance: str) -> Scene:
    c = palette(
        appearance,
        {"page": WHITE, "ear": hexrgb("#CFE3D6"), "mark": GREEN_TOP},
        {"page": MINT_DARK, "ear": hexrgb("#3E9B6C"), "mark": MINT_LIGHT},
        {"page": hexrgb("#F0F0F0"), "ear": hexrgb("#B8B8B8"), "mark": hexrgb("#3C3C3C")},
    )
    x, y, w, h, r, ear = 192.0, 148.0, 640.0, 728.0, 64.0, 168.0
    k = r * KAPPA
    page = Path(
        [
            ("M", x + r, y),
            ("L", x + w - ear, y),
            ("L", x + w, y + ear),
            ("L", x + w, y + h - r),
            ("C", x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h),
            ("L", x + r, y + h),
            ("C", x + r - k, y + h, x, y + h - r + k, x, y + h - r),
            ("L", x, y + r),
            ("C", x, y + r - k, x + r - k, y, x + r, y),
            ("Z",),
        ],
        c["page"],
    )
    fold = polygon([(x + w - ear, y), (x + w - ear, y + ear), (x + w, y + ear)], c["ear"])
    shapes: list[Shape] = [page, fold, *md_mark(c["mark"], 56, shift_x=-0, shift_y=-2)]
    if appearance == "any":
        shapes.insert(0, background())
    return Scene(shapes, opaque=appearance == "any")


def direction_b(appearance: str) -> Scene:
    c = palette(
        appearance,
        {"ink": WHITE},
        {"ink": MINT_DARK},
        {"ink": hexrgb("#F0F0F0")},
    )
    ink, stroke = c["ink"], 60
    top, bottom = 352.0, 672.0
    # M
    m0 = 148.0  # centres the 788-wide word on the canvas
    m = [(m0, bottom), (m0, top), (m0 + 85, top + 190), (m0 + 170, top), (m0 + 170, bottom)]
    # d: a bowl and a full-height stem
    bowl_r = 88.0
    d_cx = m0 + 170 + 36 + 30 + bowl_r + 30  # outer M edge + gap + stroke halves + radius
    d_cy = bottom - bowl_r
    bowl = [(d_cx + bowl_r * math.cos(a * math.pi / 32), d_cy + bowl_r * math.sin(a * math.pi / 32)) for a in range(65)]
    d_stem = [(d_cx + bowl_r, top), (d_cx + bowl_r, bottom)]
    # V: its point reads as a down arrow
    v0 = d_cx + bowl_r + 30 + 36 + 30
    vm = v0 + 95
    v = [(v0, top), (vm, bottom), (v0 + 190, top)]
    shapes: list[Shape] = [Stroke(pts, stroke, ink) for pts in (m, bowl, d_stem, v)]
    if appearance == "any":
        shapes.insert(0, background())
    return Scene(shapes, opaque=appearance == "any")


def direction_c(appearance: str) -> Scene:
    c = palette(
        appearance,
        {"card": CARD, "head": GREEN_BOTTOM, "line": hexrgb("#7FB394"), "box": GREEN_TOP, "tick": CARD},
        {"card": MINT_LIGHT, "head": hexrgb("#3E9B6C"), "line": hexrgb("#8CCBAA"), "box": MINT_DARK, "tick": MINT_LIGHT},
        {"card": hexrgb("#EDEDED"), "head": hexrgb("#3C3C3C"), "line": hexrgb("#8A8A8A"), "box": hexrgb("#4A4A4A"), "tick": hexrgb("#EDEDED")},
    )
    left = 268.0
    shapes: list[Shape] = [
        rrect(192, 192, 640, 640, 72, c["card"]),
        rrect(left, 268, 292, 64, 24, c["head"]),
        rrect(left, 388, 488, 32, 16, c["line"]),
        rrect(left, 452, 440, 32, 16, c["line"]),
        rrect(left, 516, 360, 32, 16, c["line"]),
        rrect(left, 624, 104, 104, 28, c["box"]),
        Stroke([(left + 28, 676), (left + 48, 698), (left + 80, 654)], 24, c["tick"]),
        rrect(404 + 4, 660, 344, 32, 16, c["line"]),
    ]
    if appearance == "any":
        shapes.insert(0, background())
    return Scene(shapes, opaque=appearance == "any")


DIRECTIONS = {"a": direction_a, "b": direction_b, "c": direction_c}
APPEARANCES = ("any", "dark", "tinted")


def build(direction: str, appearance: str) -> Scene:
    return DIRECTIONS[direction](appearance)


def render_png(scene: Scene, size: int) -> bytes:
    return encode_png(size, size, render(scene, size), with_alpha=not scene.opaque)


# ------------------------------------------------------------------ contact sheet


def label_scene(letter: str) -> Scene:
    ink = hexrgb("#333333")
    width = 8.0
    if letter == "A":
        strokes = [[(14, 90), (50, 10), (86, 90)], [(28, 62), (72, 62)]]
    elif letter == "B":
        bowl1 = [(24 + 38 * math.sin(a * math.pi / 24), 10 + 20 + -20 * math.cos(a * math.pi / 24)) for a in range(25)]
        bowl2 = [(24 + 46 * math.sin(a * math.pi / 24), 50 + 20 + -20 * math.cos(a * math.pi / 24)) for a in range(25)]
        strokes = [[(24, 10), (24, 90)], bowl1, bowl2]
    else:
        arc = [(52 + 38 * math.cos(math.pi * (0.25 + 1.5 * a / 32)), 50 + 38 * math.sin(math.pi * (0.25 + 1.5 * a / 32))) for a in range(33)]
        strokes = [arc]
    return Scene([Stroke([(x, y) for x, y in pts], width, ink) for pts in strokes], opaque=False)


def render_label(letter: str, size: int) -> bytes:
    scene = label_scene(letter)
    # The label is drawn on a 100-unit design grid; scale it to the 1024 canvas.
    factor = CANVAS / 100
    scaled = Scene(
        [Stroke([(x * factor, y * factor) for x, y in s.points], s.width * factor, s.fill) for s in scene.shapes],  # type: ignore[union-attr]
        opaque=False,
    )
    return render(scaled, size)


def blend_into(sheet: bytearray, sheet_w: int, dx: int, dy: int, size: int, pixels: bytes, backdrop: RGB | None, mask: bytes | None) -> None:
    """Composite an RGBA image over an optional backdrop colour, clipped by mask alpha, onto the RGB sheet."""
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            m = mask[i + 3] if mask else 255
            if m == 0:
                continue
            sa = pixels[i + 3]
            if backdrop is None:
                color = (pixels[i], pixels[i + 1], pixels[i + 2])
                cov = m * sa // 255
            else:
                color = tuple((pixels[i + p] * sa + backdrop[p] * (255 - sa) + 127) // 255 for p in range(3))
                cov = m
            if cov == 0:
                continue
            o = ((dy + y) * sheet_w + dx + x) * 3
            if cov == 255:
                sheet[o : o + 3] = bytes(color)
            else:
                for p in range(3):
                    sheet[o + p] = (color[p] * cov + sheet[o + p] * (255 - cov) + 127) // 255


def mask_scene() -> Scene:
    return Scene([rrect(0, 0, CANVAS, CANVAS, CANVAS * 0.2237, WHITE)], opaque=False)


def contact_sheet() -> tuple[int, int, bytes]:
    pad, label_w, tile = 32, 72, 256
    smalls = (180, 120, 87, 58, 40)
    grid_w = label_w + 3 * (tile + pad)
    smalls_w = sum(smalls) + pad // 2 * (len(smalls) - 1)
    width = pad + grid_w + smalls_w + pad
    height = pad + 3 * (tile + pad)
    background_color = hexrgb("#E5E5EA")
    sheet = bytearray(bytes(background_color) * (width * height))
    mask_cache: dict[int, bytes] = {}

    def mask_for(size: int) -> bytes:
        if size not in mask_cache:
            mask_cache[size] = render(mask_scene(), size)
        return mask_cache[size]

    backdrops = {"any": None, "dark": hexrgb("#000000"), "tinted": hexrgb("#3A6EA5")}
    for row, direction in enumerate(("a", "b", "c")):
        top = pad + row * (tile + pad)
        label = render_label(direction.upper(), 56)
        blend_into(sheet, width, pad + (label_w - 56) // 2, top + (tile - 56) // 2, 56, label, None, None)
        for col, appearance in enumerate(APPEARANCES):
            pixels = render(build(direction, appearance), tile)
            blend_into(sheet, width, pad + label_w + col * (tile + pad), top, tile, pixels, backdrops[appearance], mask_for(tile))
        x = pad + grid_w
        for size in smalls:
            pixels = render(build(direction, "any"), size)
            blend_into(sheet, width, x, top + (tile - size) // 2, size, pixels, None, mask_for(size))
            x += size + pad // 2
    rgba = bytearray(width * height * 4)
    for p in range(3):
        rgba[p::4] = sheet[p::3]
    rgba[3::4] = b"\xff" * (width * height)
    return width, height, bytes(rgba)


# --------------------------------------------------------------------------- CLI


def write_all(out_dir: pathlib.Path) -> None:
    for direction in DIRECTIONS:
        for appearance in APPEARANCES:
            scene = build(direction, appearance)
            target = out_dir / "directions" / direction
            target.mkdir(parents=True, exist_ok=True)
            (target / f"{appearance}.svg").write_text(scene.to_svg())
            (target / f"{appearance}.png").write_bytes(render_png(scene, CANVAS))
            print(f"wrote {target / appearance}.{{svg,png}}")
    width, height, rgba = contact_sheet()
    sheet_path = out_dir / "contact-sheet.png"
    sheet_path.write_bytes(encode_png(width, height, rgba, with_alpha=False))
    print(f"wrote {sheet_path} ({width}x{height})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--all", action="store_true", help="write every direction and appearance plus the contact sheet")
    parser.add_argument("--direction", choices=sorted(DIRECTIONS))
    parser.add_argument("--appearance", choices=APPEARANCES, default="any")
    parser.add_argument("--size", type=int, default=CANVAS, help="PNG size in pixels (default 1024)")
    parser.add_argument("--out", type=pathlib.Path, help="output file; .svg or .png")
    parser.add_argument("--out-dir", type=pathlib.Path, default=ICON_DIR, help="root for --all (default docs/app-store/icon)")
    args = parser.parse_args(argv)

    if args.all:
        write_all(args.out_dir)
        return 0
    if not args.direction or not args.out:
        parser.error("pass --all, or both --direction and --out")
    scene = build(args.direction, args.appearance)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.out.suffix.lower() == ".svg":
        args.out.write_text(scene.to_svg())
    else:
        args.out.write_bytes(render_png(scene, args.size))
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
