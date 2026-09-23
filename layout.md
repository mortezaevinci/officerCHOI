# Layout — where things go

Two trees: the game repo, and the scripts that build its content. They are
deliberately separate. **Nothing that generates content lives in the repo**, and
nothing the game needs at runtime lives in `_script`.

---

## `C:\temp\officerchoi` — the repo

| Folder | What goes in it |
|---|---|
| `game/` | the Godot project. The only thing that ships. |
| `game/src/` | GDScript. `autoload/` globals, `journey/` the run, `ui/`, `dialogue/`, `entities/`. |
| `game/scenes/` | `.tscn` scenes, mirroring `src/`. |
| `game/content/` | **compiled** content — `journey/<run>/journey.json`, `names/`, `dialogue/`. Generated; never hand-edited. |
| `game/assets/` | art, audio, fonts, themes. `art/backgrounds/journey/` and `journey2/` hold scene backdrops; `art/portraits/` the faces. |
| `game/tests/` | the suite. `cases/` one file per area. Run before every build. |
| `game/addons/` | third-party Godot addons. |
| `assets/text/` | the **source** CSVs content is written from — one folder per dataset (`iran`, `Mexico`, `abuse`, `goodlife`, `war`…). Not shipped. |
| `art-source/` | LPC layers, palettes, Kenney packs, working files. Not shipped. |
| `C:/temp/godotsetup/engine/godot/`, `C:/temp/godotsetup/engine/godot-mono/` | pinned editors. **Android exports must use the standard one**, not mono. |
| `tools/build/` | `build.ps1` — tests, then export. |
| `tools/art/` | spritesheet composition. |
| `docs/` | `build/`, `design/`, `dev/`, `writing/`. |
| `preview/` | generated output for a human: `script_map.html`, `all_text.*`, screenshots, logs. |
| `backup/` | `<timestamp>-<what>/` copies taken before replacing data or assets. |
| `android/`, `steam/` | packaging assets per platform. |
| `build/` | export output. Disposable, regenerated. |

## `C:\temp\_script\officerchoi` — the content tooling

Scripts live here because every agent's scripts live under `_script`. They write
*into* `game/content/` and read *from* `assets/text/`.

| Group | Files | What it does |
|---|---|---|
| journey compiler | `journey_schema.py`, `journey_build.py` | validates and compiles a run to `journey.json` |
| authored events | `journey_<run>_events.py`, `journey_choi_<run>_events.py` | the written scenes, one file per run |
| datasets | `abuse_*`, `goodlife_*`, `*_hurdles_*` | the node graphs each run draws on |
| names | `names_build.py` | the misspelling table |
| text tools | `journey_text.py`, `script_map_build.py`, `script_map_template.html` | the browsable/editable script map and text dumps |
| scenes | `scene_queue.py`, `restyle_iran_scenes.py`, `rewire_run_scenes.py`, `add_*_scenes.py` | scene records and backdrop prompt queues |
| characters | `officerchoi-*.py`, `hairprobe.py` | spritesheet probes and grids |
| android | `apkexport.bat`, `androidexport.bat`, `stdexport.bat`, `bootemu*.bat`, `emulator_setup.bat`, `android_setup*.bat`, `adbcheck.bat`, `aaptcheck.bat`, `run-android.sh` | export, emulator, install |
| one-offs | `choi_escalation*.py`, `check_run_gate_flow.py` | migrations already applied; kept as a record |

**The rule:** a script that writes into `game/content/` belongs here. A script
the *game* runs belongs in `game/`.

---

## The pipeline, end to end

```
assets/text/<dataset>/*.csv          hand-written source
        |
        |  _script/officerchoi/<dataset>_build.py
        v
_script/officerchoi/journey_<run>_events.py   authored scenes
        |
        |  journey_build.py --run <run>
        v
game/content/journey/<run>/journey.json       compiled, shipped
        |
        |  tools/build/build.ps1  (tests, then export)
        v
build/windows/OfficerChoi.exe
build/android/OfficerChoi.apk
```

Backdrops run beside it: `scene_queue.py <run>` builds a prompt queue from the
scene records, `C:\temp\aitools` generates them, they are staged in
`C:\temp\_samples\choi_scenes\<run>`, confirmed, then copied into
`game/assets/art/backgrounds/`.
