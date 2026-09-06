"""Builds the game's character sprites and portraits from CC0 source art.

    python.exe tools\\art\\build_characters.py
    python.exe tools\\art\\build_characters.py --only choi

Characters are composed, not drawn: each one is a stack of pieces (body, then
clothing, then hair) taken from Kenney's CC0 roguelike character sheet. Which
pieces make which character lives in art-source/characters.json, so a character
can be restyled by editing three pairs of numbers rather than by opening a paint
program.

Two things come out of it, both into game/assets/art/:

    characters/<id>.png   the in-world sprite, scaled for the room
    portraits/<id>.png    the close-up portrait for conversations

Everything is nearest-neighbour scaled - the project sets Godot's default
texture filter to nearest, so the pixels stay crisp at any size.

Requires Pillow. On this machine that means the Windows Python:
    python.exe -c "import PIL; print(PIL.__version__)"
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
             "On this machine use the Windows Python: python.exe tools\\art\\build_characters.py")

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART_SOURCE = ROOT / "art-source"
CONFIG = ART_SOURCE / "characters.json"
SPRITE_OUT = ROOT / "game" / "assets" / "art" / "characters"
PORTRAIT_OUT = ROOT / "game" / "assets" / "art" / "portraits"


def load_config() -> dict:
    if not CONFIG.exists():
        sys.exit(f"missing {CONFIG}")
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def compose(sheet: Image.Image, layers: list, tile: int, stride: int) -> Image.Image:
    """Stacks the listed cells into one tile-sized image."""
    out = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    for layer in layers:
        col, row = layer["cell"]
        piece = sheet.crop((col * stride, row * stride, col * stride + tile, row * stride + tile))
        if piece.getbbox() is None:
            print(f"  warning: layer '{layer.get('part', '?')}' at {col},{row} is empty")
        out.alpha_composite(piece)
    return out


def trim_bottom(image: Image.Image) -> Image.Image:
    """Crops empty rows off the bottom so the sprite's feet sit on its origin."""
    box = image.getbbox()
    if box is None:
        return image
    return image.crop((0, 0, image.width, box[3]))


def build_sprite(base: Image.Image, scale: int) -> Image.Image:
    trimmed = trim_bottom(base)
    return trimmed.resize((trimmed.width * scale, trimmed.height * scale), Image.NEAREST)


def build_portrait(base: Image.Image, scale: int, size: tuple) -> Image.Image:
    """A big, crisp version of the character, centred with headroom.

    Sits on transparency: the portrait slot draws a per-character coloured card
    behind it, so the character reads against its own backdrop.
    """
    big = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
    canvas = Image.new("RGBA", tuple(size), (0, 0, 0, 0))
    x = (canvas.width - big.width) // 2
    y = (canvas.height - big.height) // 2
    canvas.alpha_composite(big, (x, y))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", help="build a single character by id")
    args = parser.parse_args()

    config = load_config()
    sheet_path = ART_SOURCE / config["sheet"]
    if not sheet_path.exists():
        sys.exit(f"source sheet missing: {sheet_path}\n"
                 f"Re-download the Kenney packs - see docs/dev/art-pipeline.md")

    sheet = Image.open(sheet_path).convert("RGBA")
    tile = int(config["tile"])
    stride = int(config["stride"])

    SPRITE_OUT.mkdir(parents=True, exist_ok=True)
    PORTRAIT_OUT.mkdir(parents=True, exist_ok=True)

    characters = config["characters"]
    if args.only:
        if args.only not in characters:
            sys.exit(f"no such character '{args.only}'. Known: {', '.join(characters)}")
        characters = {args.only: characters[args.only]}

    for char_id, spec in characters.items():
        print(f"{char_id}:")
        base = compose(sheet, spec["layers"], tile, stride)

        sprite = build_sprite(base, int(config["sprite_scale"]))
        sprite_path = SPRITE_OUT / f"{char_id}.png"
        sprite.save(sprite_path)
        print(f"  sprite   {sprite.width}x{sprite.height}  -> {sprite_path.relative_to(ROOT)}")

        portrait = build_portrait(base, int(config["portrait_scale"]), config["portrait_size"])
        portrait_path = PORTRAIT_OUT / f"{char_id}.png"
        portrait.save(portrait_path)
        print(f"  portrait {portrait.width}x{portrait.height}  -> {portrait_path.relative_to(ROOT)}")

    print("\nDone. Godot re-imports on next focus, or force it with:")
    print("  tools\\godot\\Godot_v4.7.2-stable_win64_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
