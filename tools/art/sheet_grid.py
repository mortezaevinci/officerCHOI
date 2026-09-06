"""Renders a spritesheet as a labelled grid, so tiles can be picked by coordinate.

    python.exe tools\\art\\sheet_grid.py kenney/roguelike-indoors/Tilesheets/roguelikeIndoor_transparent.png
    python.exe tools\\art\\sheet_grid.py <sheet> --cols 20 26 --zoom 6

The path is relative to art-source/. The output lands in C:\\temp\\_samples and
is meant to be looked at, not committed - it is a contact sheet for choosing
which cells go into characters.json / props.json.

Kenney's roguelike sheets are a 16px grid with a 1px gutter, which is the
default; pass --tile/--stride for anything else.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is not installed for this interpreter.\n"
             "On this machine use the Windows Python: python.exe tools\\art\\sheet_grid.py ...")

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART_SOURCE = ROOT / "art-source"
DEFAULT_OUT = pathlib.Path(r"C:\temp\_samples\officerchoi\sheet-grid.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", help="path relative to art-source/")
    parser.add_argument("--tile", type=int, default=16)
    parser.add_argument("--stride", type=int, default=17)
    parser.add_argument("--zoom", type=int, default=4)
    parser.add_argument("--cols", type=int, nargs=2, metavar=("FROM", "TO"),
                        help="restrict to a column range, so a wide sheet stays readable")
    parser.add_argument("--rows", type=int, nargs=2, metavar=("FROM", "TO"))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args()

    path = ART_SOURCE / args.sheet
    if not path.exists():
        sys.exit(f"no sheet at {path}")

    src = Image.open(path).convert("RGBA")
    total_cols = (src.size[0] + 1) // args.stride
    total_rows = (src.size[1] + 1) // args.stride

    col_from, col_to = args.cols if args.cols else (0, total_cols)
    row_from, row_to = args.rows if args.rows else (0, total_rows)
    col_to = min(col_to, total_cols)
    row_to = min(row_to, total_rows)

    px = args.tile * args.zoom
    cell_w, cell_h = px + 16, px + 20
    out = Image.new("RGBA",
                    ((col_to - col_from) * cell_w + 12, (row_to - row_from) * cell_h + 12),
                    (28, 30, 36, 255))
    draw = ImageDraw.Draw(out)

    used = 0
    for r_i, row in enumerate(range(row_from, row_to)):
        for c_i, col in enumerate(range(col_from, col_to)):
            box = (col * args.stride, row * args.stride,
                   col * args.stride + args.tile, row * args.stride + args.tile)
            tile = src.crop(box)
            if tile.getbbox() is None:
                continue
            used += 1
            big = tile.resize((px, px), Image.NEAREST)
            x, y = 6 + c_i * cell_w, 6 + r_i * cell_h
            out.paste(big, (x, y), big)
            draw.text((x, y + px + 3), f"{col},{row}", fill=(150, 160, 182, 255))

    out_path = pathlib.Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    print(f"{path.name}: grid {total_cols}x{total_rows}, "
          f"showing cols {col_from}..{col_to - 1} rows {row_from}..{row_to - 1}, "
          f"{used} non-empty -> {out_path}")


if __name__ == "__main__":
    main()
