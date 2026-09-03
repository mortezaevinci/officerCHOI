# Conventions

Short, and worth following, because most of them exist to keep the two halves
of the project — the writing and the code — from tangling.

## Where a thing goes

| Kind of thing | Where |
|---|---|
| Something the story knows | `GameState.vars`, set from a `.dlg` file |
| Something the player prefers | `Settings` |
| Words a player reads | `content/`, never a string literal in a script |
| A rule about how the game behaves | `src/` |

The test: **could a writer change this without opening Godot?** If yes, it
belongs in `content/`.

## Naming

- Files and folders: `snake_case.gd`, `snake_case.tscn`.
- Classes: `PascalCase`, and only where a `class_name` is genuinely useful.
- Nodes in scenes: `PascalCase`. Scripts reach for them by path, so renaming a
  node is a code change — `test_scenes.gd` will catch it.
- Spawn markers and dialogue nodes: `snake_case`, named for the place they
  are entered from (`from_hallway`) or what happens there (`ask_about_file`).
- Story variables: `snake_case`, and phrased so `if x` reads as English —
  `read_case_file`, `has_badge`, `told_truth`.

## GDScript

- Static typing everywhere: `var x: int = 0`, `func f(a: String) -> void:`.
  It is what makes `test_scripts.gd` able to catch things at load time.
- Tabs, which is Godot's own convention.
- Private members lead with `_`.
- `@export` anything a designer might want to change. A number in the inspector
  beats a number in a script.
- Comment *why*, not *what*. The code says what.

## Signals over polling

The dialogue runner emits; the UI listens. Nothing reaches up. If a scene finds
itself wanting to ask `Dialogue` what is on screen, the answer is usually a
signal it should have connected to.

## Scenes

- One responsibility each. `conversation.tscn` presents a conversation; it does
  not know which one until it is told.
- Prefer inheriting a scene over copying it.
- A scene must survive being instantiated and dropped into the tree with no
  setup — that is exactly what `test_scenes.gd` does to all of them.

## Before committing

```powershell
powershell -ExecutionPolicy Bypass -File tools\build\run-tests.ps1
```

It takes seconds and it reads every script, every scene and every line of
dialogue in the game.

## Git

- `game\.godot\`, `build\`, `tools\godot\` and `*.translation` are generated.
  They are in `.gitignore`; keep them there.
- `.tscn` and `.tres` are text and diff readably — as long as everyone is on the
  same Godot build. That is why the editor is pinned in `tools\godot`.
- Commit content and the code that serves it separately when you can. "Add
  chapter 2 dialogue" and "add a condition type" are different reviews.

## Secrets

Nothing secret goes in this repo. The Android signing keystore and its passwords
live in `C:\temp\_secrets`; `game\export_presets.cfg` is committed precisely
because it does **not** contain them — the keystore path goes in the editor's
per-machine Android settings instead. See
[../build/android.md](../build/android.md).
