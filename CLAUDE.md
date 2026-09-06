# Officer Choi — notes for an agent working here

A 2D conversation game in Godot 4.7.2, targeting Steam (Windows/Linux) and
Android from one project. Read `README.md` first; `docs/dev/architecture.md`
explains the code.

## Rules specific to this project

- **Two pinned Godot binaries, both in `tools/`.** Use them, not a system-wide
  Godot — a different build silently rewrites every `.tscn` it touches.
  `tools/godot/` (standard) for tests and everyday work; `tools/godot-mono/`
  (.NET) only for the ai-game.dev addon and for release builds.
- **The project has a `.csproj` but no C# gameplay code, and should keep none.**
  It exists solely so the godot_mcp editor addon can compile. See
  `docs/dev/ai-game-dev.md`.
- **Open `game/`, not the repo root.** The repo root is not a Godot project.
- **Run the tests before saying anything works:**
  `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game res://tests/test_runner.tscn`
  Exit code 0 means green. They parse every script, instantiate every scene, and
  read every `.dlg` file, so they catch most of what can break.
- **Words go in `content/`, rules go in `src/`.** If a writer could change it
  without opening Godot, it does not belong in a script.
- **Adding a loose data format means editing `include_filter`** in
  `game/export_presets.cfg`. Godot only ships files it recognises as resources;
  `.dlg` and `.json` reach a build only because they are named there. A build
  missing that runs perfectly in the editor and has no dialogue at all.
- **`camera_bounds` on a room must be at least 1920x1080** or the camera shows
  past the walls.
- **Input actions are generated**, from `game/tools/bootstrap_input_map.gd`.
  Edit that table and re-run it rather than clicking in the Input Map panel.
- **No secrets here.** The Android keystore lives in `C:\temp\_secrets` and its
  path goes in per-machine editor settings, never in the repo.

## Checking a change visually

There is a built-in capture, so no window-grabbing is needed:

```
tools\godot\Godot_v4.7.2-stable_win64.exe --path game -- \
  --scene=res://scenes/rooms/precinct.tscn --spawn=desk \
  --screenshot=C:\temp\_samples\officerchoi\shot.png --shot-after=120
```

Add `--dialogue=<file>.dlg --left=choi --right=ward --auto` to look at a
conversation instead of a room.
