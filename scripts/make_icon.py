#!/usr/bin/env python3
"""Generate a dependency-free 1024 px PNG app icon."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


SIZE = 1024


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def inside_round_rect(x: int, y: int, left: int, top: int, right: int, bottom: int, radius: int) -> bool:
    if left + radius <= x <= right - radius or top + radius <= y <= bottom - radius:
        return left <= x <= right and top <= y <= bottom
    cx = left + radius if x < left + radius else right - radius
    cy = top + radius if y < top + radius else bottom - radius
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def pixel(x: int, y: int) -> tuple[int, int, int, int]:
    t = y / (SIZE - 1)
    r = int(26 + 45 * t)
    g = int(31 + 55 * t)
    b = int(72 + 95 * t)

    if inside_round_rect(x, y, 205, 170, 585, 850, 72):
        r, g, b = (58, 118, 255)
    if inside_round_rect(x, y, 440, 170, 820, 850, 72):
        r, g, b = (32, 205, 170)

    if (x - 390) ** 2 + (y - 390) ** 2 <= 88 ** 2:
        r, g, b = (244, 247, 255)
    if (x - 625) ** 2 + (y - 390) ** 2 <= 88 ** 2:
        r, g, b = (255, 224, 102)
    return r, g, b, 255


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "DualWallpaperPicker/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            rows.extend(pixel(x, y))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    output.write_bytes(png)
    print(output)


if __name__ == "__main__":
    main()
