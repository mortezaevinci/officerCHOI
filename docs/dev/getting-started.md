# Getting started

## What is already done

The machine this was set up on has everything:

- Godot **4.7.2-stable** in `tools\godot\` (pinned; not the system-wide one).
- Export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- The project imports clean, the test suite passes, and Windows and Linux
  builds have been produced and run.

## On a new machine

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup\install-godot.ps1
```

That fetches the pinned editor into `tools\godot` and the export templates into
the place Godot looks for them. Add `-SkipTemplates` if you only intend to write
and play, not build (saves a 1 GB download).

Then check it works:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build\run-tests.ps1
```

Everything green means you are set up.

## Opening the project

```powershell
tools\godot\Godot_v4.7.2-stable_win64.exe --path game --editor
```

Open `game`, not the repo root — the repo root is not a Godot project.

The first time, Godot re-imports assets and writes `game\.godot\`. That folder is
generated and is not committed.

## Running it

| What | Command |
|---|---|
| The game | `tools\godot\Godot_v4.7.2-stable_win64.exe --path game` |
| Straight into a room | `... --path game -- --scene=res://scenes/rooms/precinct.tscn --spawn=desk` |
| Straight into a conversation | `... --path game -- --dialogue=desk_ward.dlg --left=choi --right=ward` |
| ...reading itself aloud | add `--auto` |
| Screenshot and quit | add `--screenshot=C:\temp\_samples\shot.png --shot-after=120` |
| Tests | `tools\build\run-tests.ps1` |
| Build | `tools\build\build.ps1 -Target windows` |
| Writing stats | `python.exe tools\dialogue\dialogue_stats.py` |

Note the bare `--`: everything after it goes to the game rather than to Godot.

## Two things worth knowing early

**The input map is generated, not clicked.** Bindings live in
`game\tools\bootstrap_input_map.gd`. Change the table there and re-run:

```powershell
tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/bootstrap_input_map.gd
```

Editing them in the Input Map panel works too, but the next person to run the
script will overwrite you.

**`.dlg` and `.json` are not resources.** Godot ships resources; those two file
types only reach a build because `include_filter` in `game\export_presets.cfg`
names them. If you add another loose data format, add it there — a build without
it runs perfectly in the editor and has no dialogue at all when exported.
