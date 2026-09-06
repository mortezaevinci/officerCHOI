# Art provenance and licences

Every piece of art that ships in this game is listed here, with where it came
from and what the licence permits. **Nothing goes into `game/assets/` without an
entry here.**

The rule for this project: **CC0 only.** No attribution obligation, no
share-alike, nothing to get wrong on a store page years from now. It costs some
choice of style and it is worth it.

---

## In use

| Source | Licence | Used for | Where |
|---|---|---|---|
| [Kenney — Roguelike Characters](https://kenney.nl/assets/roguelike-characters) | **CC0 1.0** | Choi, Ward, Park — sprites and portraits | `kenney/roguelike-characters/` |
| [Kenney — Roguelike Indoors](https://kenney.nl/assets/roguelike-indoors) | **CC0 1.0** | The desk, file shelf, hallway cabinet | `kenney/roguelike-indoors/` |

Those two are **committed**, so the art rebuilds with no network access.

## Available, not yet used

Not committed — 7000 files nobody reads yet. Fetch them when they are wanted:
`python.exe tools\art\fetch_assets.py`

| Source | Licence | Likely use |
|---|---|---|
| [Kenney — UI Pack](https://kenney.nl/assets/ui-pack) | **CC0 1.0** | Panels and buttons, if the theme ever moves off flat colour |
| [Kenney — Input Prompts](https://kenney.nl/assets/input-prompts) | **CC0 1.0** | Key/button glyphs in the interact prompt |
| [Kenney — Roguelike Modern City](https://kenney.nl/assets/roguelike-modern-city) | **CC0 1.0** | Exteriors, if the story ever leaves the building |

CC0 1.0 is a public-domain dedication: commercial use, modification and
redistribution are all permitted, and credit is not required. Kenney is credited
in `steam/README.md` anyway, because it is deserved and it costs nothing.

---

## Generated from the above

These are built by the tools, not drawn, and are regenerated rather than edited:

| File | Built by | From |
|---|---|---|
| `game/assets/art/characters/*.png` | `tools/art/build_characters.py` | `characters.json` + Kenney character sheet |
| `game/assets/art/portraits/*.png` | `tools/art/build_characters.py` | same |
| `game/assets/art/props/*.png` | `tools/art/build_props.py` | `props.json` + Kenney indoor sheet |

Editing those PNGs by hand is a mistake — the next build overwrites them. Change
the JSON, or take the file out of the build and record it below as hand-made.

---

## Licences deliberately avoided

Worth writing down, because these come up constantly when searching for game art
and all of them are traps for a commercial release:

| Licence | Problem |
|---|---|
| **CC-BY-SA** | Share-alike. Modified art must be released under the same terms. The LPC (Liberated Pixel Cup) collection is mostly this — a large, tempting, and awkward set. |
| **CC-BY** | Fine, but creates a permanent attribution obligation you must not lose track of. Acceptable *if* recorded here on the day it is added. |
| **CC-BY-NC** | Non-commercial. Unusable — this game is going on Steam. |
| "Free, but no redistribution / no modification" | Common on itch.io. A game build redistributes the art, so this usually fails on its own terms. |

If something non-CC0 is ever added, it goes in a table of its own here with the
exact attribution string required, and that string goes in the game's credits
before release.

---

## Not art, but same rule

| Thing | Licence |
|---|---|
| Fonts | Godot's built-in default for now. Anything added must be OFL or CC0. |
| Audio | None yet. Same rule: CC0 preferred, CC-BY recorded here. |
