"""Builds room props from CC0 tilesheet art.

    python.exe tools\\art\\build_props.py

A prop is a small grid of tiles stitched together and scaled up - three desk
tiles in a row make one long desk. What goes where lives in art-source/props.json,
so re-cutting a prop is a config edit rather than an image edit.

Output: game/assets/art/props/<name>.png

Same conventions as build_characters.py: nearest-neighbour scaling, and the
project's default texture filter is nearest, so the pixels stay crisp.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is not installed for this interpreter.\n"
             "On this machine use the Windows Python: python.exe tools\\art\\build_props.py")

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART_SOURCE = ROOT / "art-source"
CONFIG = ART_SOURCE / "props.json"
OUT_DIR = ROOT / "game" / "assets" / "art" / "props"


def build(sheet: Image.Image, grid: list, tile: int, stride: int, scale: int) -> Image.Image:
    rows = len(grid)
    cols = max(len(r) for r in grid)
    out = Image.new("RGBA", (cols * tile, rows * tile), (0, 0, 0, 0))

    for r, row in enumerate(grid):
        for c, cell in enumerate(row):
            if cell is None:
                continue
            col, srow = cell
            piece = sheet.crop((col * stride, srow * stride,
                                col * stride + tile, srow * stride + tile))
            out.alpha_composite(piece, (c * tile, r * tile))

    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", help="build a single prop by name")
    args = parser.parse_args()

    if not CONFIG.exists():
        sys.exit(f"missing {CONFIG}")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))

    sheet_path = ART_SOURCE / config["sheet"]
    if not sheet_path.exists():
        sys.exit(f"source sheet missing: {sheet_path}\n"
                 f"Re-download the Kenney packs - see docs/dev/art-pipeline.md")

    sheet = Image.open(sheet_path).convert("RGBA")
    tile, stride, scale = int(config["tile"]), int(config["stride"]), int(config["scale"])

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    props = config["props"]
    if args.only:
        if args.only not in props:
            sys.exit(f"no such prop '{args.only}'. Known: {', '.join(props)}")
        props = {args.only: props[args.only]}

    for name, spec in props.items():
        image = build(sheet, spec["grid"], tile, stride, scale)
        path = OUT_DIR / f"{name}.png"
        image.save(path)
        print(f"{name:12} {image.width}x{image.height} -> {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
