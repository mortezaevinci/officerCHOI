# How to build

Three things you might mean by "build". They are separate and you usually only
need one.

| You changed...            | Run this                                    |
|---------------------------|---------------------------------------------|
| GDScript, scenes, UI      | the **game build** below                     |
| story text, events, runs  | the **content build**, then the game build   |
| scene backdrops           | the **art fetch**, then the game build       |

---

## 1. Game build (Windows)

```powershell
cd C:\temp\officerchoi
tools\build\build.ps1 -Target windows -Debug
```

Output: `build\windows\OfficerChoi.exe`

- Leave off `-Debug` for a release build.
- `-Target linux` and `-Target all` also work.
- **Tests run first by default.** They only prove the scripts parse - a green
  run does not mean the game works. Pass `-SkipTests` to skip them when you
  know why you are skipping them.
- For Android, do **not** use this script. See `how to run android.md`.

---

## 2. Content build (story, events, journeys)

The story lives outside the repo, in `C:\temp\_script`, as Python that compiles
into the game.

```powershell
cd C:\temp\_script
python journey_build.py --all
```

Output: `game\content\journey\<run>\journey.json` for each of iran, palestine,
nigeria, mexico, usa, choi.

Build just one while you are iterating:

```powershell
python journey_build.py --run palestine
```

What it prints is worth reading - node counts, step counts, and how many lines
name the player. If a run says only 3 or 4 lines name the player, the writing
has drifted; the others sit around 10-11.

The name misspellings (Kaveh -> Gaveh, Jose -> Hose) come from a CSV and need
their own compile step after you edit it:

```powershell
python C:\temp\_script\officerchoi\names_build.py
```

Source: `assets\text\names\misspellings.csv`
Output: `game\content\names\misspellings.json`

> The CSV is the editable copy. The game only ever reads the JSON, because the
> export filter ships `*.json` and would silently drop a `.csv` from the build.

---

## 3. Art fetch (scene backdrops)

```powershell
cd C:\temp\officerchoi
python tools\art\fetch_scene_art.py                 # fetch anything missing
python tools\art\fetch_scene_art.py --only SC-PLAZA --force   # redo one
```

- Prompts live in `art-source\journey_scenes.json`.
- Images land in `game\assets\art\backgrounds\journey\` and are **gitignored on
  purpose** - they are watermarked and their licensing is unsettled, so a fresh
  clone has no backdrops until you fetch them.
- If a scene comes back wrong, rewrite its prompt rather than retrying. Lead
  with one subject stated first and short. Long adjective lists get averaged
  away, and telling it what to avoid removes the character along with the thing
  you excluded.

---

## Running it without clicking through menus

```powershell
build\windows\OfficerChoi.exe -- --set=journey_run:mexico;player_name:Jose ^
  --scene=res://scenes/journey/journey_view.tscn
```

- `--set=key:value;key:value` writes straight into the save state.
- `--scene=` opens one scene directly.
- `--screenshot=C:\path\shot.png --shot-after=120` captures a frame and exits.
- `--type=papers` types a word, for testing typed input.

All of these are development-only and do nothing in a shipped build.

---

## When a build looks fine but is not

Two traps that have already cost time here:

- **A green test run only means the scripts parse.** It does not mean anything
  renders. Look at the thing.
- **Exit code 0 does not mean work happened.** Check the file that was supposed
  to be produced, and its size.
