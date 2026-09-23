# Journeys

A life, birth to adult, as ten missions and then Officer Choi. One
self-contained document per run.

```
content/journey/<run>/journey.json     the whole run
assets/art/backgrounds/journey/*.png   the backdrops it names
```

Built by `C:\temp\_script\officerchoi\journey_build.py` from `journey_schema.py` and
`journey_<run>_events.py`. **Edit those and re-run; never hand-edit the JSON.**

```powershell
python.exe C:\temp\_script\officerchoi\journey_build.py --run iran
python.exe C:\temp\_script\officerchoi\journey_build.py --run choi
python.exe tools\art\build_journey_scenes.py
```

Both need **Windows** python: the build paths are `C:\` literals, and WSL
python3 treats the backslashes as one filename and silently writes a junk
directory instead of the game folder.

## How a life is played

| | |
|---|---|
| A **mission** | a good event, then the consequence of having chosen it |
| A **season** | ten missions, then the boss |
| A **new life** | a new season, drawn from parts of the graph the last one did not use |

New Game opens `name_entry.tscn`, because the player types their own name before
anything else happens. That hands off to `journey_view.tscn`, which owns the
order of events and nothing else: the conversation is played by the `Dialogue`
autoload, the box draws itself, and the graph decides what may follow what.

**Missions are assembled, not authored.** There are 1,074 nodes and a few dozen
hand-written conversations, so season one plays the authored spine and later
seasons draw on the rest of the graph with generated beats. Assembly is
deterministic in the season number, so a save stores two integers rather than an
itinerary.

## The causal rule

The join was already in the datasets and unused. Every `goodlife` row carries a
`triggers` column — what a good thing exposes you to — and the build maps each
trigger onto the hurdle categories that may follow it.

> **A good event may only be followed by a hurdle one of its own triggers
> justifies.**

`goodlife:FOO-004`, a pomegranate, triggers nothing, so nothing can follow it —
that is what makes it a rest rather than a trap, and why it can never carry a
mission. `goodlife:TRV-143`, studying in London, triggers
`visa;border;airport;documents;credential`, so five kinds of refusal are legal
successors. **Visiting Isfahan cannot cost you a visa; going to Paris can.**

`test_journey_season.gd` asserts this directly: every mission's hurdle must
appear in its good event's own consequence edges.

## The runs

Each is a complete document — own graph, own cast, own scenes. Loading `iran`
does not read, need or touch any other. Adding one is a row in `RUNS` plus a
`journey_<run>_events.py`.

| Run | Datasets | Nodes | Events | Built |
|---|---|---|---|---|
| `iran` | `iran`, `general`, `war` | 1,074 | 20 | yes |
| `choi` | `abuse` | 108 | 9 | yes — the boss |
| `mexico` | `Mexico`, `general` | — | — | no events yet |
| `nigeria` | `nigeria`, `general` | — | — | no events yet |
| `palestine` | `palestine`, `general`, `war` | — | — | no events yet |

**228 of the 889 good events trigger nothing at all.** They are the floor of the
game: whichever difficulty was chosen, they stay reachable and cannot be taken
away. Mostly fruit in season, laughing, sleep, weather.

## The boss

`choi` is the last act of every nationality, authored once, because the point is
that the ending is the same whichever life you lived.

It is an **all-hurdle run**: no good half, because there is nothing to choose and
nothing to enjoy. Every beat is a row in `assets/text/abuse` and names it in
`source`. Choi is not inventive — he performs, in sequence, the ordinary things
that dataset catalogues: the queue as an instrument, the question you are not
allowed to be unable to answer, any defect will do, compliance with the tone as a
condition of the outcome. Each is individually defensible, which is what makes
him a boss rather than a thug.

He practises on somebody else first. Mr Bae goes before you, so the player
watches the method work on a stranger, understands it, and then cannot use the
understanding for anything.

The fight is unwinnable and should only be legible as unwinnable in retrospect.
Early choices change what he says and never what he decides. The closing speech
is the thesis: rights belong to citizens, you are an applicant, and he believes
he is correcting a misunderstanding rather than doing harm.

**Officer Choi is the antagonist, not the player.** `characters.json` used to
describe `choi` as a detective the player controlled; that was scaffolding from
an earlier prototype and is fixed. The key stays `choi` because the placeholder
`.dlg` files reference it.

## Document shape

```
run, version, player_token       what this is
triggers, stages, requires       vocabularies, index-significant
cast                             this run's people, id -> {display, color}
sequence                         event ids in authored order
nodes[]                          id, kind, src, cat, title, sum, stage, w, trig, req, event
edges[]                          [src, dst, kind, weight, via] - flat, there are 20k
scenes{}                         scene id -> {art, location, time, mood, note}
events{}                         event id -> {uuid, node, scene, title, stage, source, nodes}
```

Three fields exist for specific reasons:

- **`sum`** is the dataset's own summary, carried so a node with no authored
  conversation can still produce a real beat. Without it, later seasons would be
  blank screens.
- **`sequence`** states the authored order. Recovering it from the edges does not
  work — the escalation ladder gives almost every abuse node an incoming edge, so
  "the node nothing leads to" finds nothing, and an earlier version fell through
  to dictionary iteration order and was right only by accident.
- **`uuid`** is `uuid5` of a lowercase slug, so rebuilds are stable and **the same
  beat authored in two runs gets the same UUID deliberately** — shared experiences
  line up across nationalities with no table to maintain.

## The player types their own name

No name for the player exists anywhere in content. Text carries `{player}`, and
`JourneyDialogue` substitutes it once on the way in, so nothing downstream ever
knows a name was typed. The player never speaks in their own voice — their lines
are choices, which are things they do.

**Who uses the name is an authorial decision, not an oversight.** The people who
love you use it: Farideh, Omid, Mrs Ebadi, your mother, the employer who likes
you. The institutions never do — Sgt Karimi says "Card.", Officer Doyle says
"sir", Mr Hosseini does not address you at all, and Choi uses it only when he
wants something from you. The asymmetry is the game in miniature.

Each run's cast lives in its own document rather than in
`content/characters/characters.json`, so the nationalities stay uncoupled.
`CharacterDb.register_cast()` announces them on the way in, which is all the
dialogue box needs.

## Code

| File | Does |
|---|---|
| `src/journey/journey_data.gd` | reads a run |
| `src/journey/journey_dialogue.gd` | turns an event into a `DialogueScript` |
| `src/journey/journey_season.gd` | assembles ten missions |
| `src/journey/journey_view.gd` | plays them, then the boss |
| `src/journey/name_entry.gd` | the name |

`JourneyDialogue` is a translation, **not a second dialogue system**: the events
were authored with exactly the step kinds `DialogueScript` already has, so the
runner, the box, the history and the condition evaluator are all the ones that
were already written and tested. It resolves two differences — the JSON uses
integer step kinds, and expresses narration as its own kind rather than as a line
with no speaker.

## Tests

`test_journey.gd` checks the data is sound. `test_journey_season.gd` checks the
game works — ten missions, causal pairing, determinism, a second life that
differs, every beat convertible, and the boss in order.

Both exist because **a green suite is not proof on its own here**:
`test_every_script_parses` loads each script without asserting the result and
reported `ok` for two full runs while `journey_data.gd` was failing to compile,
and `test_scenes` only checks a scene can be instantiated.

New scripts need an import pass before the headless runner sees them:

```
C:\temp\godotsetup\engine\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --import
```

## Not done yet

- **Only `iran` has events.** Mexico, Nigeria and Palestine have dataset mappings
  and no conversations.
- **No portrait art** for any journey character, so the box shows names and
  colours against the backdrop. Nothing breaks; the placeholder path is already
  handled by `CharacterDb.portrait_path`.
- **`_fallback_scene` returns nothing**, so a generated beat keeps whatever
  backdrop is already up rather than choosing one by category.
- **The end of a life returns to the main menu.** There is no summary screen
  showing what the run cost, though `dignity` is recorded throughout.
