# Art pipeline

The game's art is **composed and generated**, not hand-drawn. Characters and
props are stacks of CC0 tiles described in JSON, and two small tools turn that
JSON into the PNGs the game loads. Restyling a character is editing three pairs
of numbers, not opening a paint program.

That is deliberate: it means the look can be iterated on quickly and
consistently, and it means the art is reproducible from the repo.

---

## The tools

Installed portable under `tools/art/` (gitignored, ~880 MB — get them with
`tools\art\install-art-tools.ps1`):

| Tool | Licence | For |
|---|---|---|
| **[Pixelorama](https://orama-interactive.itch.io/pixelorama) 1.2.1** | MIT | Pixel art and animation. Built in Godot itself. Sprites, portraits, touch-ups to generated art. |
| **[Material Maker](https://www.materialmaker.org/) 1.7** | MIT | Node-based procedural textures. Floors, walls, surfaces. Also Godot-based. Exports PNG. |
| **[Krita](https://krita.org/) 5.3.3** | GPL-3.0 | Full painting app. For anything wanting a brush rather than a pixel grid — painted backgrounds, key art, store capsules. |

Krita's GPL covers the application, not what you draw with it.

```powershell
tools\art\pixelorama\Pixelorama-Windows-64bit\Pixelorama.exe
tools\art\material-maker\material_maker_1_7_windows\material_maker.exe
tools\art\krita\krita-x64-5.3.3\bin\krita.exe
```

## The source art

CC0 packs from [Kenney](https://kenney.nl), committed under `art-source/kenney/`
(17 MB). Public domain: commercial use, modification, no attribution required.

Provenance and licence rules: **[art-source/LICENSES.md](../../art-source/LICENSES.md)**.
The project rule is CC0 only — read that file before adding anything.

```powershell
python.exe tools\art\fetch_assets.py          # re-download / add a pack
```

---

## How a character is made

`art-source/characters.json` says which pieces stack up:

```json
"choi": {
    "display_name": "Choi",
    "layers": [
        {"part": "body",  "cell": [1, 0]},
        {"part": "shirt", "cell": [16, 5]},
        {"part": "hair",  "cell": [23, 4]}
    ]
}
```

Each `cell` is a `[column, row]` on Kenney's modular character sheet. Layers draw
in order — body, then clothing, then hair.

```powershell
python.exe tools\art\build_characters.py
python.exe tools\art\build_characters.py --only choi
```

Out come two files per character:

- `game/assets/art/characters/<id>.png` — the in-world sprite (8× — 128 px tall)
- `game/assets/art/portraits/<id>.png` — the conversation portrait (16×)

The portrait is transparent; the portrait slot draws the character's colour card
behind it, so each character reads against their own backdrop. That colour comes
from `game/content/characters/characters.json`, which is the one source of truth
for who a character is.

## How a prop is made

`art-source/props.json`, same idea, but a prop is a grid of tiles — three desk
tiles in a row make one long desk:

```json
"desk": { "grid": [[[0, 12], [4, 12], [0, 12]]] }
```

```powershell
python.exe tools\art\build_props.py
```

Out: `game/assets/art/props/<name>.png`.

## Finding the cell numbers

Do not count tiles by eye. Render a labelled contact sheet:

```powershell
python.exe tools\art\sheet_grid.py kenney/roguelike-characters/Spritesheet/roguelikeChar_transparent.png
python.exe tools\art\sheet_grid.py kenney/roguelike-indoors/Tilesheets/roguelikeIndoor_transparent.png --cols 0 14 --rows 8 20 --zoom 5
```

It writes `C:\temp\_samples\officerchoi\sheet-grid.png` with every cell labelled
`col,row`. Pick from that, put the numbers in the JSON, rebuild.

---

## After a rebuild

Godot picks new PNGs up when it next has focus. Headless, force it:

```powershell
tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --import
```

Then look at it, rather than assuming:

```powershell
tools\godot\Godot_v4.7.2-stable_win64.exe --path game -- --scene=res://scenes/rooms/precinct.tscn --spawn=desk --screenshot=C:\temp\_samples\officerchoi\room.png --shot-after=110
```

---

## Rules that keep this from rotting

- **Never hand-edit a generated PNG.** `characters/`, `portraits/` and `props/`
  are build output; the next run overwrites them. Change the JSON instead.
- **Hand-made art is fine** — put it somewhere the tools do not write to, and
  record it in `art-source/LICENSES.md` as hand-made.
- **Working files go in `art-source/working/`** — `.pxo` (Pixelorama), `.ptex`
  (Material Maker), `.kra` (Krita). Never in `game/`; Godot would try to import
  them and they would bloat the export.
- **Nearest-neighbour everywhere.** The project sets Godot's default texture
  filter to nearest and the tools scale with nearest. Introducing a bilinear
  filter anywhere will make the pixel art mushy at exactly one scale and wrong
  at all the others.
- **New art source ⇒ new row in LICENSES.md, same commit.** A licence you cannot
  reconstruct later is a licence you cannot ship.

---

## What is still placeholder

Honest list, so nobody mistakes it for finished:

- Room floors, walls and the rug are flat `ColorRect`s. Material Maker is
  installed for exactly this.
- The door in the precinct is still two polygons.
- Characters have one pose, no walk animation and no mood variants — the
  `Choi @tired:` moods in the dialogue all fall back to the one portrait.
- No UI art; the theme is flat colour. The Kenney UI pack is downloaded and
  waiting if that changes.
- No audio at all.
