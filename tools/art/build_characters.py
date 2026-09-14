"""Builds the game's character sprites and portraits from LPC source art.

    python.exe tools\\art\\build_characters.py
    python.exe tools\\art\\build_characters.py --only choi

Characters are composed, not drawn. Each one is a stack of LPC layers - body,
head, eyes, legs, shoes, shirt, coat, hair - listed in art-source/characters.json.
Restyling someone is editing a colour name, not opening a paint program.

LPC ships every sheet in a single reference palette and its web generator
recolours on the fly. This does the same offline: each palette family has a
known base ramp (body "light", hair "orange", cloth "white", eye "blue"), and a
layer is recoloured by mapping that ramp onto the target ramp, position for
position.

Output, into game/assets/art/:

    characters/<id>_walk.png   4-direction 9-frame walk sheet, at sprite_scale
    portraits/<id>.png         conversation portrait, default expression
    portraits/<id>_<mood>.png  one per mood used in dialogue

The mood files are why `Choi @tired:` now changes the face instead of falling
back to a single portrait.

Requires Pillow. On this machine that means the Windows Python:
    python.exe -c "import PIL; print(PIL.__version__)"
"""

from __future__ import annotations

import argparse
import csv
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
CREDITS_OUT = ART_SOURCE / "CREDITS-USED.md"

# The palette each family's shipped PNGs are drawn in. From the repo's
# palette_definitions/<family>/meta_<family>.json "base" field.
BASE_RAMP = {"body": "light", "hair": "orange", "cloth": "white", "eye": "blue"}

# Licences we are willing to ship. LPC assets are usually multi-licensed and you
# elect one; OGA-BY and CC-BY avoid share-alike, and OGA-BY explicitly permits
# DRM, which matters for a store build. See art-source/LICENSES.md.
ACCEPTABLE = ("CC0", "OGA-BY", "CC-BY 3.0", "CC-BY 4.0")


def hex_to_rgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


class Palettes:
    """Loads LPC palette ramps and recolours a layer from base to target."""

    def __init__(self, root: pathlib.Path) -> None:
        self.root = root
        self._cache: dict = {}

    def ramps(self, family: str) -> dict:
        if family not in self._cache:
            path = self.root / family / f"{family}_ulpc.json"
            if not path.exists():
                raise SystemExit(f"missing palette file {path}")
            self._cache[family] = json.loads(path.read_text(encoding="utf-8"))
        return self._cache[family]

    def detect_source(self, family: str, image: Image.Image) -> str:
        """Works out which ramp a sheet was actually drawn in.

        Most LPC sheets ship in the family's base ramp, but not all - the formal
        trousers ship green, for instance. Assuming the base ramp silently
        leaves those layers un-recoloured, which is exactly the bug this avoids.
        Whichever ramp accounts for most of the sheet's pixels wins.
        """
        present = {rgb[:3] for count, rgb in image.getcolors(1 << 16) or [] if rgb[3] > 0}
        best, best_hits = None, 0
        for name, ramp in self.ramps(family).items():
            hits = sum(1 for value in ramp if hex_to_rgb(value) in present)
            if hits > best_hits:
                best, best_hits = name, hits
        # Two matching colours is coincidence; three is a palette.
        return best if best_hits >= 3 else None

    def shade_mapping(self, family: str, target: str, image: Image.Image) -> dict:
        """Recolours a sheet that is not in any known ramp.

        The formal trousers, for example, ship in three bespoke greens that
        appear in no palette file. Rank the sheet's own colours darkest to
        lightest, rank the target ramp the same way, and map across. It keeps
        the shading relationships intact, which is all the ramp was doing.
        """
        ramp = [hex_to_rgb(value) for value in self.ramps(family)[target]]
        present = sorted(
            {rgb[:3] for _count, rgb in image.getcolors(1 << 16) or [] if rgb[3] > 0},
            key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
        if not present:
            return {}
        mapping = {}
        for i, colour in enumerate(present):
            position = i / (len(present) - 1) if len(present) > 1 else 0.0
            mapping[colour] = ramp[round(position * (len(ramp) - 1))]
        return mapping

    def mapping(self, family: str, target: str, source: str) -> dict:
        ramps = self.ramps(family)
        if source not in ramps:
            raise SystemExit(f"palette family '{family}' has no ramp '{source}'")
        if target not in ramps:
            raise SystemExit(f"palette '{family}' has no ramp '{target}'. "
                             f"Available: {', '.join(sorted(ramps))}")
        base, want = ramps[source], ramps[target]
        if len(base) != len(want):
            raise SystemExit(f"ramp length mismatch: {family}/{source} vs {family}/{target}")
        return {hex_to_rgb(a): hex_to_rgb(b) for a, b in zip(base, want)}


def recolour(image: Image.Image, mapping: dict) -> Image.Image:
    """Swaps exact palette colours. Pixels outside the ramp are left alone."""
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            swap = mapping.get((r, g, b))
            if swap is not None:
                pixels[x, y] = (swap[0], swap[1], swap[2], a)
    return image


def resolve(layer: dict, anim: str, mood: str, head: str) -> str:
    # A layer may remap the mood for itself. The eye sheets, for instance, have
    # no `happy` expression while the shared mood map emits one - without this
    # the eyes would be silently dropped from every amused portrait, because
    # compose() skips whatever it cannot find.
    mood = layer.get("mood_map", {}).get(mood, mood)
    return layer["path"].format(anim=anim, mood=mood, head=head)


def compose(sheets: pathlib.Path, palettes: Palettes, layers: list,
            anim: str, mood: str, head: str, used: set) -> Image.Image:
    """Stacks every layer of one character into a single animation sheet."""
    out = None
    for layer in layers:
        rel = resolve(layer, anim, mood, head)
        path = sheets / rel
        if not path.exists():
            print(f"    missing layer, skipped: {rel}")
            continue
        used.add(rel)

        piece = Image.open(path).convert("RGBA")
        family, colour = layer.get("palette"), layer.get("color")
        if family and colour:
            source = layer.get("from") or palettes.detect_source(family, piece)
            if source:
                mapping = palettes.mapping(family, colour, source)
            else:
                mapping = palettes.shade_mapping(family, colour, piece)
            piece = recolour(piece, mapping)

        if out is None:
            out = Image.new("RGBA", piece.size, (0, 0, 0, 0))
        out.alpha_composite(piece)
    if out is None:
        raise SystemExit("no layers resolved - check the paths in characters.json")
    return out


def scale(image: Image.Image, factor: int) -> Image.Image:
    return image.resize((image.width * factor, image.height * factor), Image.NEAREST)


def portrait_from(sheet: Image.Image, config: dict) -> Image.Image:
    """Crops the standing, facing-the-player frame and blows it up.

    Frame 0 of the walk row is a standing pose, so it doubles as the portrait
    without needing a separate idle sheet.
    """
    frame = int(config["frame"])
    row = int(config["walk_rows"]["down"])
    still = sheet.crop((0, row * frame, frame, row * frame + frame))

    # Head and shoulders, measured rather than guessed. An LPC walk frame has
    # empty headroom above the figure - for a 128px frame the opaque box starts
    # 30px down - so taking a fraction from the top of the FRAME yields air and
    # the crown of the skull. Crop to the figure's own bounding box first, then
    # take the top share of that.
    box = still.getbbox()
    if box:
        left, top, right, bottom = box
        # Head AND shoulders. 0.38 of the figure cut off at the eyes; the head
        # plus shoulders of an LPC figure runs to roughly 55% of its height.
        share = float(config.get("portrait_bust", 0.55))
        still = still.crop((left, top, right, top + max(1, int((bottom - top) * share))))

    canvas = Image.new("RGBA", tuple(config["portrait_size"]), (0, 0, 0, 0))
    # Fill the card without distorting: integer scale, bounded by both axes.
    factor = max(1, min(canvas.width // still.width, canvas.height // still.height))
    big = scale(still, factor)
    x = (canvas.width - big.width) // 2
    y = (canvas.height - big.height) // 2
    canvas.alpha_composite(big, (max(x, 0), max(y, 0)))
    return canvas


def write_credits(credits_csv: pathlib.Path, used: set) -> None:
    """Records authors and licences for exactly the layers that got used."""
    if not credits_csv.exists():
        print(f"  (no CREDITS.csv at {credits_csv}, skipping attribution file)")
        return

    rows = {}
    with credits_csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            rows[row["filename"].strip().strip('"')] = row

    def lookup(rel: str):
        """CREDITS.csv writes body-type segments as a ${head} template, so
        head/faces/male/sad/walk.png is credited as head/faces/${head}/sad/walk.png."""
        if rel in rows:
            return rows[rel]
        parts = rel.split("/")
        for i in range(len(parts)):
            probe = "/".join(parts[:i] + ["${head}"] + parts[i + 1:])
            if probe in rows:
                return rows[probe]
        return None

    lines = [
        "# Attribution for the character art actually used",
        "",
        "Generated by `tools/art/build_characters.py` — do not edit by hand.",
        "",
        "Every row below is a layer that ends up in a shipped sprite. LPC assets are",
        "multi-licensed; we elect **OGA-BY 3.0** (or CC0/CC-BY where that is the only",
        "option), which avoids share-alike and permits DRM. See `LICENSES.md`.",
        "",
        "**These credits must appear in the game before release.**",
        "",
        "| Layer | Authors | Licences offered |",
        "|---|---|---|",
    ]

    flagged = []
    authors: set = set()
    for rel in sorted(used):
        row = lookup(rel)
        if row is None:
            flagged.append(f"{rel} — not listed in CREDITS.csv")
            lines.append(f"| `{rel}` | *not listed* | *unknown* |")
            continue
        who = row.get("authors", "").strip().strip('"')
        lic = row.get("licenses", "").strip().strip('"')
        authors.update(a.strip() for a in who.split(",") if a.strip())
        if not any(ok in lic for ok in ACCEPTABLE):
            flagged.append(f"{rel} — only offers: {lic}")
        lines.append(f"| `{rel}` | {who} | {lic} |")

    lines += ["", "## Combined author list, for the credits screen", "",
              ", ".join(sorted(authors)) or "*none resolved*", ""]

    if flagged:
        lines += ["## NEEDS ATTENTION", ""]
        lines += [f"- {item}" for item in flagged]
        lines.append("")

    CREDITS_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"\nattribution -> {CREDITS_OUT.relative_to(ROOT)}  "
          f"({len(used)} layers, {len(authors)} authors)")
    if flagged:
        print("  WARNING: some layers need a licence check:")
        for item in flagged:
            print(f"    {item}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", help="build a single character by id")
    args = parser.parse_args()

    if not CONFIG.exists():
        sys.exit(f"missing {CONFIG}")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))

    sheets = ART_SOURCE / config["source"]["sheets"]
    if not sheets.exists():
        sys.exit(f"LPC art missing at {sheets}\n"
                 f"Fetch it with: python.exe tools\\art\\fetch_assets.py --lpc")

    palettes = Palettes(ART_SOURCE / config["source"]["palettes"])
    SPRITE_OUT.mkdir(parents=True, exist_ok=True)
    PORTRAIT_OUT.mkdir(parents=True, exist_ok=True)

    characters = config["characters"]
    if args.only:
        if args.only not in characters:
            sys.exit(f"no such character '{args.only}'. Known: {', '.join(characters)}")
        characters = {args.only: characters[args.only]}

    moods = config.get("moods", {"default": "default"})
    used: set = set()

    for char_id, spec in characters.items():
        print(f"{char_id}:")

        # One walk sheet, in the neutral expression - nobody sees the eyes at
        # room scale, and one sheet per mood would be wasteful.
        head = spec.get("head", "male")
        walk = compose(sheets, palettes, spec["layers"], "walk",
                       moods.get("default", "neutral"), head, used)
        walk_scaled = scale(walk, int(config["sprite_scale"]))
        walk_path = SPRITE_OUT / f"{char_id}_walk.png"
        walk_scaled.save(walk_path)
        print(f"  walk sheet {walk_scaled.width}x{walk_scaled.height} "
              f"({config['walk_frames']} frames x {len(config['walk_rows'])} directions)"
              f" -> {walk_path.relative_to(ROOT)}")

        # A portrait per distinct expression, named so CharacterDb finds them.
        by_expression: dict = {}
        for mood, expression in moods.items():
            by_expression.setdefault(expression, []).append(mood)

        for expression, mood_names in sorted(by_expression.items()):
            sheet = compose(sheets, palettes, spec["layers"], "walk", expression, head, used)
            portrait = portrait_from(sheet, config)
            for mood in mood_names:
                name = f"{char_id}.png" if mood == "default" else f"{char_id}_{mood}.png"
                portrait.save(PORTRAIT_OUT / name)
        print(f"  portraits  {len(moods)} moods -> {len(by_expression)} expressions")

    write_credits(ART_SOURCE / config["source"]["credits"], used)

    print("\nDone. Re-import with:")
    print("  tools\\godot\\Godot_v4.7.2-stable_win64_console.exe --headless --path game --import")


if __name__ == "__main__":
    main()
