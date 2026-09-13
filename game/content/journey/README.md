# Journeys

One life, birth to adult, as a directed graph with playable conversations
hanging off it. One self-contained document per nationality.

```
content/journey/<run>/journey.json     the whole run
assets/art/backgrounds/journey/*.png   the backdrops it names
```

Built by `C:\temp\_script\journey_build.py` from `journey_schema.py` and
`journey_<run>_events.py`. **Edit those and re-run; never hand-edit the JSON.**

```powershell
python.exe C:\temp\_script\journey_build.py --run iran
python.exe C:\temp\_script\journey_build.py --all
python.exe tools\art\build_journey_scenes.py
```

Both need **Windows** python: the build paths are `C:\` literals, and WSL
python3 treats the backslashes as one filename and silently writes a junk
directory instead of the game folder.

## Why JSON, and why under `content/`

The first version of this was a binary container at `assets/journey/`. That was
wrong in one specific, silent way: `game/export_presets.cfg` ships
`include_filter="*.dlg,*.json"`, so a `.bin` outside `game/` reaches the editor
and reaches **neither a Steam build nor an Android one**. It would have worked
perfectly in development and shipped with no journey data at all.

JSON under `content/` ships on Windows and Android with no export change,
diffs readably, and parses in milliseconds. The backdrops moved to
`assets/art/backgrounds/journey/` for the same reason — Godot only imports, and
only ships, images inside the project.

## Runs are independent

Each nationality is a complete document: its own graph, its own cast, its own
scenes. Loading `iran` does not read, need or touch `mexico`. Nothing is shared
at load time and **no run can break another** — which is the point, since the
five difficulties are different games that happen to share a codebase.

Adding one is a row in `RUNS` in the build script plus a
`journey_<run>_events.py`. Nothing else changes.

| Run | Hurdle datasets it draws on | Built |
|---|---|---|
| `iran` | `iran`, `general`, `war` | yes |
| `mexico` | `Mexico`, `general` | events not written yet |
| `nigeria` | `nigeria`, `general` | events not written yet |
| `palestine` | `palestine`, `general`, `war` | events not written yet |

## The causal rule

The join was already in the datasets and unused. Every `goodlife` row carries a
`triggers` column — what a good thing exposes you to — and the build maps each
trigger onto the hurdle categories that may follow it.

> **A good event may only be followed by a hurdle one of its own triggers
> justifies.**

`goodlife:FOO-004`, a pomegranate, triggers nothing, so nothing can follow it.
That is what makes it a rest rather than a trap. `goodlife:TRV-143`, studying in
London, triggers `visa;border;airport;documents;credential`, so five kinds of
refusal are legal successors. **Visiting Isfahan cannot cost you a visa; going
to Paris can.**

`TRIGGER_TO_CATEGORY` in the build script is the only place causality is
decided — one table, 25 triggers, readable in a minute.

### The Iranian run, as built

| | |
|---|---|
| nodes | 1,074 — 889 good, 185 hurdles |
| edges | 20,385 — 16,426 consequence, 2,760 sequel, 740 recovery, 459 cascade |
| events | 20 authored, 235 steps |
| cast | 14 named characters |
| scenes | 17 |
| size | 570 KB |

**228 of the 889 good events trigger nothing at all.** They are the floor of the
game: whichever difficulty was chosen, they stay reachable and cannot be taken
away. Mostly `SEN`, `FOO`, `HUM`, `RST` and `NAT` — fruit in season, laughing,
sleep, weather.

## Identity: every event has a UUID

Derived as `uuid5` from a lowercase slug, so:

- a rebuild produces the same UUID, which makes diffs meaningful
- **the same beat authored in two runs gets the same UUID on purpose** — give it
  the same slug and shared experiences line up across nationalities with nobody
  maintaining a table by hand
- renaming a slug changes identity, which is correct: it is now a different beat

## The player types their own name

No name for the player is written anywhere in content. Text carries the token
`{player}`, and `JourneyData.render(text, name)` substitutes it before display.
The player never speaks in their own voice — their lines are choices, which are
things they do.

**Who uses the name is an authorial decision, not an oversight.** The people who
love you use it: Farideh, Omid, Mrs Ebadi, your mother, the employer who likes
you. The institutions never do — Sgt Karimi says "Card.", Officer Doyle says
"sir", Mr Hosseini does not address you at all. The asymmetry is the game in
miniature, so the token is not sprinkled evenly, and the first time an official
uses your name it should mean something.

Every other character is invented and named, in the run's own `cast`. They are
deliberately **not** added to `content/characters/characters.json`: a shared
character namespace would couple the runs together.

## Node ids are namespaced

`goodlife:TRV-143`, `iran:VIS-001`. This is load-bearing, not cosmetic. The
datasets collide on bare ids — `FIN-001`, `PSY-001`, `DIS-001` and `EDU-001`
each exist in more than one — and goodlife `FAM-001` (a family memory) is not
iran `FAM-001` (parents refused a visa). An earlier build keyed on bare ids,
silently dropped 44 hurdles, and attached an event to the wrong node. The build
now asserts node count equals rows read.

## Conversations

Step kinds are deliberately the same set as `DialogueScript` in
`src/dialogue/dialogue_script.gd` — line, narration, choices, set, jump, branch,
command, end — so a journey event maps onto **the dialogue runner that already
exists** rather than needing a second one.

Writing rules, enforced by review and by the build:

- The player is *you*; use `{player}` where a character says the name.
- Nobody explains the system to you. The clerk does not know he is a hurdle —
  he is bored, or kind, or following a rule he did not write.
- No number appears in dialogue unless a person in that room would say it. The
  statistics stay in the CSVs, reachable through each event's `source`.
- If it is not in a dataset, it does not get a scene. The build refuses to
  compile when an event's `source` basename disagrees with its node id.

## Backdrops

Composed by `tools/art/build_journey_scenes.py` from **Kenney's Roguelike Modern
City pack (CC0)**, vendored under `art-source/kenney/`. Nothing is drawn or
synthesised: each scene is three tile bands — wall, detail, ground — plus a few
props, defined in `art-source/journey_scenes.json`. Re-dressing a scene is a
config edit, not an image edit. Provenance is in `art-source/LICENSES.md`.

The horizon sits at the same height in every scene on purpose — it is what makes
cutting between them not feel like a jump.

## Tests

`tests/cases/test_journey.gd` is the only thing keeping the Python writer and
the GDScript reader in agreement: rename a key on one side and every record
still parses, into nothing. It asserts the design rules rather than fixed
counts, so adding events or whole nationalities does not break it.

It is also there because **a green suite is not proof on its own** —
`test_every_script_parses` passed for two full runs while `journey_data.gd` was
failing to compile, since it loads each script without asserting the result.
These tests read the data instead.

## Not done yet

- **Nothing plays this.** `JourneyData` exposes the graph; it does not walk it.
- **Only `iran` has events.** The other three runs have dataset mappings and no
  authored conversations.
- **Officer Choi is a naming collision.** `content/characters/characters.json`
  defines `choi` as the player character, a detective. The brief makes Officer
  Choi the final boss at Pearson. `SC-PEARSON` is built and waiting; the clash
  needs resolving before the encounter is written.
- **New scripts need an import pass** before headless tests can see them:
  `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --import`
