# Art provenance and licences

Every piece of art that ships in this game is listed here, with where it came
from and what the licence permits. **Nothing goes into `game/assets/` without an
entry here.**

---

## The rule

**Usable: CC0, OGA-BY 3.0, CC-BY.**
**Not usable: CC-BY-SA, CC-BY-NC, or anything whose licence cannot be established.**

That is not squeamishness, it is what a paid Steam release needs:

| Licence | Verdict | Why |
|---|---|---|
| **CC0** | Best | Public domain. No obligation at all. |
| **OGA-BY 3.0** | Good | Credit required, and it **explicitly permits DRM** — which CC-BY-SA does not, and a store build is exactly where that bites. |
| **CC-BY** | Fine | Credit required. No share-alike. |
| **CC-BY-SA** | **Avoided** | Share-alike: any art you modify must be released under the same terms, and it restricts "effective technological measures". Awkward for a commercial build, and permanent. |
| **CC-BY-NC** | Never | Non-commercial. We are selling this. |
| "Free, no redistribution / no modification" | Never | A game build redistributes the art, so it fails on its own terms. |

Most LPC assets are **multi-licensed** — a typical entry offers
`OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0`, and you **elect one**. We always elect
OGA-BY (or CC0/CC-BY where that is what is on offer). That is what makes LPC
usable here without inheriting share-alike.

`tools/art/build_characters.py` **enforces this on every run**: it looks each
layer up in LPC's `CREDITS.csv` and shouts if the asset does not offer an
acceptable licence. A character cannot quietly acquire a bad layer.

---

## In use

| Source | Licence elected | Used for | Where |
|---|---|---|---|
| [LPC — Universal Spritesheet collection](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) | **OGA-BY 3.0 / CC0 / CC-BY** per asset | Choi, Ward, Park — 4-direction walk sheets and conversation portraits | `lpc/` (not committed, ~400 MB) |
| [Kenney — Roguelike Indoors](https://kenney.nl/assets/roguelike-indoors) | **CC0 1.0** | The desk, file shelf, hallway cabinet | `kenney/roguelike-indoors/` |
| [Kenney — Roguelike Modern City](https://kenney.nl/assets/roguelike-modern-city) | **CC0 1.0** | Journey backdrops — street, courtyard, campus, consulate, airport, Pearson preclearance | `kenney/roguelike-modern-city/` |

**Attribution owed:** the exact per-layer author and licence list is generated
into **[CREDITS-USED.md](CREDITS-USED.md)** on every character build. Those
credits must appear in the game before release — that is the obligation OGA-BY
and CC-BY carry. Kenney's CC0 work needs no credit but gets one anyway.

### Fetching the sources

```powershell
python.exe tools\art\fetch_assets.py --lpc     # LPC character art (~400 MB, needs git)
python.exe tools\art\fetch_assets.py           # Kenney CC0 packs
```

`kenney/roguelike-indoors` and `kenney/roguelike-modern-city` are committed so
the props and the journey backdrops rebuild offline. LPC is too large to commit.

## Available, not yet used

Not committed. Fetch when wanted.

| Source | Licence | Likely use |
|---|---|---|
| [Kenney — UI Pack](https://kenney.nl/assets/ui-pack) | **CC0 1.0** | Panels and buttons, if the theme moves off flat colour |
| [Kenney — Input Prompts](https://kenney.nl/assets/input-prompts) | **CC0 1.0** | Key/button glyphs in the interact prompt |

---

## Generated from the above

Built by the tools, not drawn. Regenerated, never edited:

| File | Built by | From |
|---|---|---|
| `game/assets/art/characters/<id>_walk.png` | `tools/art/build_characters.py` | `characters.json` + LPC |
| `game/assets/art/portraits/<id>[_mood].png` | same | same |
| `game/assets/art/props/*.png` | `tools/art/build_props.py` | `props.json` + Kenney |
| `game/assets/art/backgrounds/journey/*.png` | `tools/art/build_journey_scenes.py` (offline fallback) | `journey_scenes.json` + Kenney |
| `CREDITS-USED.md` | `build_characters.py` | LPC `CREDITS.csv` |

Editing those by hand is a mistake — the next build overwrites them.

---

## Generated images — NOT CC0, and not cleared for release

The journey backdrops that currently ship are produced by
`tools/art/fetch_scene_art.py`, which sends the `prompt` field of each scene in
`journey_scenes.json` to **[Pollinations](https://pollinations.ai)** (Flux
model, no account, plain HTTP GET) and saves the result to
`game/assets/art/backgrounds/journey/`.

**These are deliberately recorded apart from everything above, because they do
not meet this file's own rule.** The rule at the top of this document is CC0,
OGA-BY or CC-BY with an establishable source. Generated images have none of
that:

- the model's training data is not disclosed, so no chain of provenance exists;
- ownership of model output is unsettled and differs by jurisdiction;
- no author can be credited, so the attribution obligations above cannot even
  be discharged.

They are fine as **placeholder art for development**. Whether they ship in a
paid release is an open decision for Morteza, not something this file settles.
If the answer is no, `tools/art/build_journey_scenes.py` still composes the same
twenty scenes from the Kenney CC0 tiles offline — worse looking, and clean.

Every prompt and seed is recorded in
**[journey_scene_prompts.md](journey_scene_prompts.md)** so any scene can be
regenerated, restyled, or handed to a commissioned artist as a brief.

---

## Superseded

**Kenney Roguelike Characters** (CC0) built the first pass of Choi and Ward.
They were 16×16 tiles meant to be seen at 16 pixels; scaled up for a
conversation game they were rectangles with no legs, faces or animation.
Replaced by LPC, and the pack removed. Kept here as a note on why, so nobody
reintroduces it looking for a simpler CC0 option.

---

## Not art, but same rule

| Thing | Licence |
|---|---|
| Fonts | Godot's built-in default for now. Anything added must be OFL or CC0. |
| Audio | None yet. CC0 preferred; CC-BY recorded here with its attribution string. |
