# Officer Choi

A 2D conversation game. You walk around a room, you go to a desk, and then you
talk to someone and pick what to say. The walking is simple on purpose; the
conversations are the game.

Built in **Godot 4.7.2**, which exports the same project to Windows (for Steam)
and to Android from one codebase.

---

## Where everything lives

| Folder | What is in it |
|---|---|
| `game/` | The Godot project. Open **this** folder in Godot, not the repo root. |
| `docs/` | How to work on it: writing, code, and shipping. |
| `tools/` | The pinned Godot editors, and the scripts that install, test, build and run the AI addon. |
| `build/` | Export output. Generated, never committed. |
| `steam/` | Store text, capsule art, depot config for the Steam upload. |
| `android/` | Play Store listing material and signing notes. |

Inside `game/`:

| Folder | What is in it |
|---|---|
| `src/` | All GDScript, grouped by role: `autoload/`, `dialogue/`, `entities/`, `rooms/`, `ui/`, `util/`. |
| `scenes/` | All `.tscn` files: `boot/`, `menus/`, `rooms/`, `conversations/`, `entities/`, `ui/`. |
| `content/` | The writing. `.dlg` conversation files, the character list, translations. |
| `assets/` | Art, audio and fonts. |
| `tests/` | The headless test suite. |
| `tools/` | Editor-side helper scripts (the input-map generator). |

The split that matters: **`content/` is written, `src/` is programmed.** A whole
chapter can be added without touching a line of code.

---

## First run

Everything is already installed and the project already runs. To open it:

```powershell
tools\godot\Godot_v4.7.2-stable_win64.exe --path game --editor
```

There are **two** editors in `tools\`, on purpose. `godot\` is the standard
build — use it for everything day to day. `godot-mono\` is the .NET build,
needed only by the ai-game.dev AI addon and for producing release builds. See
[docs/dev/ai-game-dev.md](docs/dev/ai-game-dev.md).

To play it without the editor:

```powershell
tools\godot\Godot_v4.7.2-stable_win64.exe --path game
```

To run the tests (do this before every commit):

```powershell
powershell -ExecutionPolicy Bypass -File tools\build\run-tests.ps1
```

On a fresh machine, `tools\setup\install-godot.ps1` fetches the pinned editor
and the export templates.

---

## Jumping straight to what you are working on

Loading the menu and walking to the desk every time gets old fast. In debug
builds these switches skip all of it:

```powershell
# straight into a room, at a named spawn point
tools\godot\Godot_v4.7.2-stable_win64.exe --path game -- --scene=res://scenes/rooms/precinct.tscn --spawn=desk

# straight into one conversation, with two characters on screen
tools\godot\Godot_v4.7.2-stable_win64.exe --path game -- --dialogue=desk_ward.dlg --left=choi --right=ward

# ...and let it read itself to you
... -- --dialogue=desk_ward.dlg --left=choi --right=ward --auto

# capture a PNG and quit (also how the Steam screenshots get made)
... -- --scene=res://scenes/rooms/precinct.tscn --screenshot=C:\temp\_samples\shot.png --shot-after=120
```

F12 takes a screenshot at any time, into `user://screenshots`.

---

## Where to go next

- Writing a conversation → **[docs/writing/dialogue-format.md](docs/writing/dialogue-format.md)**
- How the code fits together → **[docs/dev/architecture.md](docs/dev/architecture.md)**
- Adding a room or a desk → **[docs/dev/adding-content.md](docs/dev/adding-content.md)**
- Making or changing art → **[docs/dev/art-pipeline.md](docs/dev/art-pipeline.md)**
- Letting an AI drive the editor → **[docs/dev/ai-game-dev.md](docs/dev/ai-game-dev.md)**
- Shipping to Steam → **[docs/build/steam.md](docs/build/steam.md)**
- Shipping to Android → **[docs/build/android.md](docs/build/android.md)**
