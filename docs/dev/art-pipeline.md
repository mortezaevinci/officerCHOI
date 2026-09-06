# Art pipeline

The game's art is **composed and generated**, not hand-drawn. A character is a
stack of open-licensed layers described in JSON — body, head, face, clothes,
hair — and two small tools turn that JSON into the PNGs the game loads.
Restyling a character is editing a colour name, not opening a paint program.

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

| Source | For | Committed? |
|---|---|---|
| [LPC](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) | Characters: 64×64, 4-direction walk cycles, faces, a huge wardrobe | No — ~400 MB |
| [Kenney](https://kenney.nl) CC0 packs | Props: desks, shelves, cabinets | Yes — 17 MB |

```powershell
python.exe tools\art\fetch_assets.py --lpc    # character art (~400 MB, needs git)
python.exe tools\art\fetch_assets.py          # Kenney CC0 packs
```

**Licence rule: CC0, OGA-BY or CC-BY only — never CC-BY-SA.** LPC assets are
usually multi-licensed and you elect one; we elect OGA-BY, which avoids
share-alike and explicitly permits DRM. `build_characters.py` checks every layer
against LPC's `CREDITS.csv` on each run and refuses to pass anything that only
offers CC-BY-SA. Full reasoning and the attribution we owe:
**[art-source/LICENSES.md](../../art-source/LICENSES.md)**.

---

## How a character is made

`art-source/characters.json` says which pieces stack up:

```json
"choi": {
    "display_name": "Choi",
    "head": "male",
    "layers": [
        {"path": "body/bodies/male/{anim}.png",      "palette": "body",  "color": "amber"},
        {"path": "head/faces/{head}/{mood}/{anim}.png", "palette": null, "color": null},
        {"path": "legs/pants2/male/{anim}.png",      "palette": "cloth", "color": "charcoal"},
        {"path": "hair/flat_top_straight/adult/{anim}.png", "palette": "hair", "color": "black"}
    ]
}
```

Layers draw in order — body, head, face, clothes, hair. `{anim}` is the
animation sheet, `{mood}` the facial expression, `{head}` the character's head
type.

**Colours are palette swaps.** LPC ships each sheet in one reference ramp and
recolours it; the tool does the same offline. `palette` picks the family
(`body`, `hair`, `cloth`), `color` the target ramp from
`art-source/lpc/palette_definitions/<family>/<family>_ulpc.json`. The tool works
out which ramp a sheet was drawn in rather than assuming — some sheets ship in
their own colours — and falls back to a luminance-ranked mapping if the sheet
matches no known ramp at all.

```powershell
python.exe tools\art\build_characters.py
python.exe tools\art\build_characters.py --only choi
```

Out come, per character:

- `game/assets/art/characters/<id>_walk.png` — a 9-frame × 4-direction walk
  sheet. The scenes read it as a `Sprite2D` with `hframes = 9, vframes = 4`;
  `player.gd` and `npc.gd` pick the frame from facing and stride. Column 0 is
  the standing pose, so idle costs nothing.
- `game/assets/art/portraits/<id>.png` plus one `<id>_<mood>.png` per mood —
  which is why `Choi @tired:` now changes the face instead of falling back to a
  single portrait. The mood-to-expression map is in `characters.json`.
- `art-source/CREDITS-USED.md` — the exact authors and licences for the layers
  that actually shipped. **These credits must go in the game before release.**

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
python.exe tools\art\sheet_grid.py kenney/roguelike-indoors/Tilesheets/roguelikeIndoor_transparent.png --cols 0 14 --rows 8 20 --zoom 5
```

(LPC needs no grid tool — its assets are separate files in named folders. Browse
`art-source/lpc/spritesheets/`, or try combinations in the upstream
[web generator](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/)
and copy the paths across. Check the licence before adopting one — the build
will refuse it otherwise.)

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
- Characters walk but have no idle animation, and no sitting pose for the desk
  scene (LPC has `sit.png` if that becomes worth wiring up).
- Portraits are full-body. A head-and-shoulders crop would carry expression
  better in a conversation.
- No UI art; the theme is flat colour. The Kenney UI pack is downloaded and
  waiting if that changes.
- No audio at all.
