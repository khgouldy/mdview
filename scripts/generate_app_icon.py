#!/usr/bin/env python3
"""Write the mdview app icon: a 1024x1024 opaque PNG.

Stdlib only. No network and no third-party image libraries. Run from the
repo root, or from anywhere:

    python3 scripts/generate_app_icon.py

The default output is App/mdview/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
Pass another path as the first argument to write elsewhere.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

SIZE = 1024
SAMPLES = 2

# sRGB. The icon is opaque: iOS masks the square, and an alpha channel is rejected.
BACKGROUND = (22, 56, 44)
SHADOW = (12, 32, 24)
PAGE = (246, 243, 234)
INK = (23, 64, 48)
RULE = (168, 180, 168)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "App" / "mdview" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def inside_round_rect(x: float, y: float, rect: tuple[float, float, float, float, float]) -> bool:
    rx, ry, rw, rh, radius = rect
    if x < rx or y < ry or x > rx + rw or y > ry + rh:
        return False
    left = x < rx + radius
    right = x > rx + rw - radius
    top = y < ry + radius
    bottom = y > ry + rh - radius
    if not (left or right) or not (top or bottom):
        return True
    corner_x = rx + radius if left else rx + rw - radius
    corner_y = ry + radius if top else ry + rh - radius
    dx = x - corner_x
    dy = y - corner_y
    return dx * dx + dy * dy <= radius * radius


def shapes() -> list[tuple[tuple[float, float, float, float, float], tuple[int, int, int]]]:
    """Back to front. Coordinates are top-left, y down, in the 1024 canvas."""
    page = (188.0, 148.0, 648.0, 712.0, 72.0)
    shadow = (page[0] + 10.0, page[1] + 16.0, page[2], page[3], page[4])
    # A markdown heading mark, centered on the page, with two body rules under it.
    return [
        (shadow, SHADOW),
        (page, PAGE),
        ((412.0, 292.0, 44.0, 252.0, 14.0), INK),
        ((568.0, 292.0, 44.0, 252.0, 14.0), INK),
        ((362.0, 354.0, 300.0, 40.0, 12.0), INK),
        ((362.0, 442.0, 300.0, 40.0, 12.0), INK),
        ((332.0, 628.0, 360.0, 22.0, 11.0), RULE),
        ((332.0, 672.0, 248.0, 22.0, 11.0), RULE),
    ]


def color_at(x: float, y: float, drawn: list[tuple[tuple[float, float, float, float, float], tuple[int, int, int]]]) -> tuple[int, int, int]:
    for rect, color in reversed(drawn):
        if inside_round_rect(x, y, rect):
            return color
    return BACKGROUND


def render() -> bytes:
    drawn = shapes()
    pixels = bytearray(SIZE * SIZE * 3)
    offset = 0
    sample_count = SAMPLES * SAMPLES
    for py in range(SIZE):
        for px in range(SIZE):
            red = green = blue = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    sample_x = px + (sx + 0.5) / SAMPLES
                    sample_y = py + (sy + 0.5) / SAMPLES
                    color = color_at(sample_x, sample_y, drawn)
                    red += color[0]
                    green += color[1]
                    blue += color[2]
            pixels[offset] = red // sample_count
            pixels[offset + 1] = green // sample_count
            pixels[offset + 2] = blue // sample_count
            offset += 3
    return bytes(pixels)


def png_chunk(tag: bytes, data: bytes) -> bytes:
    checksum = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", checksum)


def write_png(path: Path, rgb: bytes) -> None:
    if len(rgb) != SIZE * SIZE * 3:
        raise RuntimeError(f"expected {SIZE * SIZE * 3} bytes, got {len(rgb)}")
    rows = bytearray()
    stride = SIZE * 3
    for y in range(SIZE):
        rows.append(0)  # filter: none
        rows.extend(rgb[y * stride : (y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += png_chunk(b"IHDR", ihdr)
    png += png_chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    write_png(output, render())
    print(f"wrote {output} ({SIZE}x{SIZE}, no alpha)")


if __name__ == "__main__":
    main()
