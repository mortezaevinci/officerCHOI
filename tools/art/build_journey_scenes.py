"""Builds journey backdrops from CC0 tilesheet art.

    python.exe tools\\art\\build_journey_scenes.py

A scene is three horizontal bands - a wall band, a detail band and a ground
band - with a handful of props dropped on top. What goes where lives in
art-source/journey_scenes.json, so re-dressing a scene is a config edit rather
than an image edit.

Output: game/assets/art/backgrounds/journey/<scene_id>.png

It goes under game/assets/ because that is where docs/dev/adding-content.md puts
conversation backdrops, and because Godot only imports - and only ships - images
that live inside the project.

Nothing here draws or synthesises pixels. Every tile is cut from Kenney's
Roguelike Modern City pack (CC0), which is vendored under C:/temp/godotsetup/assets/kenney/.
That is the same rule build_props.py follows, and the reason the art in this
repo can ship in a paid build without anybody having to trace provenance later.

Same conventions as build_props.py: nearest-neighbour scaling, and the project's
default texture filter is nearest, so the pixels stay crisp.
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
             "On this machine use the Windows Python: "
             "python.exe tools\\art\\build_journey_scenes.py")

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART_SOURCE = ROOT / "art-source"
CONFIG = ART_SOURCE / "journey_scenes.json"
OUT_DIR = ROOT / "game" / "assets" / "art" / "backgrounds" / "journey"


def cut(sheet: Image.Image, col: int, row: int, tile: int, stride: int) -> Image.Image:
    return sheet.crop((col * stride, row * stride,
                       col * stride + tile, row * stride + tile))


def build_scene(sheet: Image.Image, spec: dict, cfg: dict) -> Image.Image:
    tile = cfg["tile"]
    stride = cfg["stride"]
    width = cfg["width"]
    height = cfg["height"]
    bands = cfg["bands"]
    props = cfg["props"]

    out = Image.new("RGBA", (width * tile, height * tile), (0, 0, 0, 0))

    # Three bands, top to bottom. The split is fixed rather than configurable
    # because every scene in the set reads better with the horizon in the same
    # place - it is what makes cutting between them not feel like a jump.
    sky_rows = range(0, height // 2 - 1)
    mid_rows = range(height // 2 - 1, height - 3)
    ground_rows = range(height - 3, height)

    for name, rows in (("sky", sky_rows), ("mid", mid_rows), ("ground", ground_rows)):
        band = spec.get(name)
        if not band:
            continue
        if band not in bands:
            raise KeyError(f"unknown band {band!r}; add it to 'bands'")
        col, row = bands[band]
        piece = cut(sheet, col, row, tile, stride)
        for y in rows:
            for x in range(width):
                out.alpha_composite(piece, (x * tile, y * tile))

    for entry in spec.get("place", []):
        prop, x, y = entry
        if prop not in props:
            raise KeyError(f"unknown prop {prop!r}; add it to 'props'")
        col, row = props[prop]
        if not (0 <= x < width and 0 <= y < height):
            raise ValueError(f"prop {prop!r} at ({x},{y}) falls outside the scene")
        out.alpha_composite(cut(sheet, col, row, tile, stride), (x * tile, y * tile))

    scale = cfg["scale"]
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", help="build a single scene by id")
    parser.add_argument("--list", action="store_true", help="list scene ids and exit")
    parser.add_argument("--replace", action="store_true",
                        help="overwrite backdrops that are already there, "
                             "including generated ones")
    args = parser.parse_args()

    if not CONFIG.exists():
        sys.exit(f"missing {CONFIG}")
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))

    scenes = {k: v for k, v in cfg["scenes"].items() if not k.startswith("_")}
    if args.list:
        for scene_id in sorted(scenes):
            print(scene_id)
        return

    sheet_path = ART_SOURCE / cfg["sheet"]
    if not sheet_path.exists():
        sys.exit(f"missing sheet {sheet_path}\n"
                 "Run tools\\art\\fetch_assets.py to vendor the Kenney packs.")
    sheet = Image.open(sheet_path).convert("RGBA")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    wanted = [args.only] if args.only else sorted(scenes)

    # Both this and fetch_scene_art.py write to OUT_DIR. This one composes Kenney
    # tiles offline; that one downloads generated paintings. Whichever runs last
    # wins, and the difference is obvious on screen but not in a file listing -
    # so say so rather than silently replacing better art with worse.
    existing = sorted(p.name for p in OUT_DIR.glob("*.png"))
    if existing and not args.replace:
        print(f"{len(existing)} backdrop(s) already in {OUT_DIR.relative_to(ROOT)}.")
        print("This composes them from Kenney tiles and will overwrite whatever")
        print("is there, including anything fetched by fetch_scene_art.py.")
        print("Pass --replace if that is what you want.")
        return
    built = 0
    for scene_id in wanted:
        if scene_id not in scenes:
            sys.exit(f"no such scene {scene_id!r}; --list shows them all")
        image = build_scene(sheet, scenes[scene_id], cfg)
        path = OUT_DIR / f"{scene_id}.png"
        image.save(path)
        print(f"{scene_id:18} {image.width}x{image.height} -> {path.relative_to(ROOT)}")
        built += 1

    print(f"\n{built} scene(s) -> {OUT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
