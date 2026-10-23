#!/usr/bin/env python3
"""Makes the app icon: signal yellow, one split-flap tile with the wordmark's "c" centred on the hinge line.

The tile and letter come from the wordmark (`apps/Clack/Clack/Design/WordmarkGlyphs.swift`, owner's logo of 2026-10-23).
In the wordmark the letters sit a little low in their tiles; here the "c" is centred on the line between the two
halves, as the owner asked. Writes the 1024 x 1024 PNG with no transparency (App Store icons can't have any) to the
app icon set. Needs macOS (qlmanage, sips). Run from the repository root:  python3 scripts/ios/make_icon.py
"""
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GLYPHS = (ROOT / "apps/Clack/Clack/Design/WordmarkGlyphs.swift").read_text()
OUT = ROOT / "apps/Clack/Clack/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"
SIZE = 1024
YELLOW = "#FFD400"

c_path = re.findall(r'^\s*"([^"]+)",$', GLYPHS, re.M)[0]  # the first letter: c

# The "c" in the logo spans x 12.62-43.51 and y 31.90-67.54 (tile 56 x 84, hinge at y = 42): centre (28.07, 49.72).
GLYPH_CENTRE = (28.07, 49.72)
TILE_W, TILE_H = 56, 84
TILE_HEIGHT_PX = 620  # the tile's height in the 1024 icon
LETTER_SCALE = 1.3  # a little larger than in the wordmark, for a small icon
k = TILE_HEIGHT_PX / TILE_H
tile_x = (SIZE - TILE_W * k) / 2
tile_y = (SIZE - TILE_H * k) / 2

svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
<rect width="{SIZE}" height="{SIZE}" fill="{YELLOW}"/>
<g transform="translate({tile_x:.2f} {tile_y:.2f}) scale({k:.4f})">
<path d="M0 10a10 10 0 0 1 10 -10h36a10 10 0 0 1 10 10v32.0h-56z" fill="#171717"/>
<path d="M0 42.0h56v32.0a10 10 0 0 1 -10 10h-36a10 10 0 0 1 -10 -10z" fill="#121212"/>
<g transform="translate(28 42) scale({LETTER_SCALE}) translate({-GLYPH_CENTRE[0]} {-GLYPH_CENTRE[1]})">
<path d="{c_path}" fill="#F4F4F0"/>
</g>
<rect x="0" y="41.5" width="56" height="1" fill="#000"/>
</g>
</svg>
"""

with tempfile.TemporaryDirectory() as tmp:
    svg_file = Path(tmp) / "icon.svg"
    svg_file.write_text(svg)
    subprocess.run(["qlmanage", "-t", "-s", str(SIZE), "-o", tmp, str(svg_file)], check=True, capture_output=True)
    rendered = Path(tmp) / "icon.svg.png"
    # No transparency: through JPEG (which has none) and back to PNG.
    jpg = Path(tmp) / "icon.jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "100", str(rendered), "--out", str(jpg)], check=True, capture_output=True)
    subprocess.run(["sips", "-s", "format", "png", str(jpg), "--out", str(OUT)], check=True, capture_output=True)
print("wrote", OUT, subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(OUT)], capture_output=True, text=True).stdout.split("\n", 1)[1].replace("\n", " "))
