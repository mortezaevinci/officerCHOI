# How the code fits together

The shape of the whole thing in one sentence: **six autoloads hold the state, a
room handles walking, and a conversation is a data file played by a runner that
does not know what a dialogue box looks like.**

---

## The six autoloads

Autoloads are the only globals. Everything else is a scene.

| Autoload | Owns | File |
|---|---|---|
| `Settings` | Player preferences. Text speed, volume, language. Saved separately from progress. | `src/autoload/settings.gd` |
| `GameState` | Story variables, visited nodes, playtime, where the player is. The thing that gets saved. | `src/autoload/game_state.gd` |
| `AudioDirector` | Music (crossfaded between two players) and a pool of sound-effect voices. | `src/autoload/audio_director.gd` |
| `Dialogue` | Plays a conversation. Emits signals; owns no UI. | `src/autoload/dialogue_runner.gd` |
| `SaveGame` | JSON save slots under `user://saves`. | `src/autoload/save_game.gd` |
| `SceneFlow` | Scene changes, fades, and the push/pop stack. | `src/autoload/scene_flow.gd` |
| `DevTools` | Screenshots and development switches. | `src/autoload/dev_tools.gd` |

`Settings` loads first because everything else may want to read it.

---

## A conversation, end to end

```
   .dlg file
      |  DialogueParser.parse_file()          src/dialogue/dialogue_parser.gd
      v
   DialogueScript          nodes -> [steps]  src/dialogue/dialogue_script.gd
      |  Dialogue.start()
      v
   Dialogue (autoload)     walks the steps
      |                    reads + writes GameState
      |                    evaluates conditions via DialogueExpression
      |
      |-- line_shown(speaker, mood, text) ------> DialogueBox shows it
      |-- choices_offered(options) -------------> DialogueBox draws buttons
      |-- command_issued(name, args) -----------> the scene acts on it
      +-- finished(script_id) ------------------> the scene closes / pops
                                    ^
                                    |
              DialogueBox calls back: advance(), choose(i)
```

The important property: **the runner never touches a node.** That is why the
same conversation plays identically in a room, in a desk close-up, and in a
test with no display attached at all.

`DialogueExpression` wraps Godot's `Expression` class, so a writer gets the whole
of GDScript's expression syntax in a condition without anyone hand-rolling a
parser. Story variables are passed in as named inputs.

---

## Walking around: rooms

A room is a `Node2D` with `src/rooms/room.gd` on it, laid out like this:

```
Precinct (Room)
├── Floor / BackWall / Rug        plain ColorRects for now, art later
├── Walls (StaticBody2D)          collision layer 1
├── Spawns (Node2D)
│   ├── entrance (Marker2D)       named arrival points
│   └── desk (Marker2D)
├── Desk (Node2D)
│   ├── ...polygons...
│   └── Interact (Interactable)   layer 4, mask 2
├── Ward (Npc)
├── Player                        layer 2, mask 1
├── InteractPrompt                world space, floats over the focused object
└── UI (CanvasLayer)
    └── DialogueBox               screen space
```

Every frame the room asks which `Interactable` the player is standing in, picks
the nearest one whose condition passes, and parks the prompt on it. Pressing
`interact` runs it.

Collision layers, all of them:

| Layer | Used by |
|---|---|
| 1 | Walls and furniture |
| 2 | The player |
| 4 | Interactable reach areas (mask 2, so they only see the player) |

---

## Interactables: the four things a desk can do

`src/entities/interactable.gd`, all set in the inspector:

| Action | What happens |
|---|---|
| `DIALOGUE` | Play a `.dlg` in the room's own dialogue box. Short exchanges. |
| `PUSH_SCENE` | Open another scene *on top*, and come back to this exact room afterwards. **This is the desk.** |
| `GOTO_SCENE` | Leave for another room for good, arriving at a named spawn. Doors. |
| `CUSTOM` | Emit a signal and let the room decide. |

Plus `condition` (same syntax as dialogue), `once`, and `sets_flag`. Which means
a door that only unlocks in chapter 2 is a string in the inspector, not code.

---

## Push and pop: why the desk works

`SceneFlow.push()` does not free the room. It detaches it — the node, the
player's position, every NPC, all still in memory — and installs the desk scene
in its place. `pop()` frees the desk and puts the room back. Nothing has to be
saved and restored, because nothing was ever lost.

`goto()` is the other case: it frees everything and clears the stack.

Three optional hooks a scene can implement, and the order they fire in:

1. `scene_configure(payload)` — **before** it enters the tree. Read your
   arguments here so `_ready` already knows them.
2. `scene_entered(payload)` — after it is in the tree and `@onready` works.
3. `scene_resumed(payload)` — a scene that was pushed on top of you just popped.

Getting 1 and 2 the wrong way round is how the portraits ended up blank the
first time this was built.

---

## Saving

`SaveGame` writes JSON to `user://saves/slot_N.json`. Slot 0 is the autosave,
written whenever the player walks into a room. Slots 1-3 are manual.

A save holds `GameState.to_dict()` and nothing else: story variables, visited
nodes, playtime, and the scene plus spawn point to restore to. Loading a save
that predates a new story variable is fine — `from_dict` starts from `DEFAULTS`
and merges the file over it, so anything missing keeps its default.

---

## Input

Actions are generated by `game/tools/bootstrap_input_map.gd` rather than being
clicked into the Input Map panel, so they are reviewable in a diff and identical
on every machine. Edit the table there and re-run it:

```powershell
C:\temp\godotsetup\engine\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tools/bootstrap_input_map.gd
```

| Action | Keyboard | Gamepad |
|---|---|---|
| `move_left/right/up/down` | WASD, arrows | left stick |
| `interact` | E, F | A |
| `advance` | Space, Enter | A |
| `pause` | Escape | Start |
| `skip` | Ctrl, Tab | RB |

Touch is not in that table because it does not need to be: tapping the floor
walks there (`Player._unhandled_input`) and tapping the dialogue box advances it
(`DialogueBox._gui_input`). The `_unhandled_input` / `_gui_input` split is what
stops a tap on a choice button from also being a walk order.

---

## Testing

`game/tests/` is a ~60-line runner and a `TestCase` base class. No addon.

```powershell
powershell -ExecutionPolicy Bypass -File tools\build\run-tests.ps1
```

| File | Covers |
|---|---|
| `test_dialogue_parser.gd` | Every line form the format allows. |
| `test_dialogue_runner.gd` | Branching, conditions, counters, interpolation, loop safety. |
| `test_game_state.gd` | Variables, save round-trips, old-save compatibility. |
| `test_content.gd` | The real `.dlg` files: parse errors, dangling jumps, unreachable nodes, unknown speakers. |
| `test_scenes.gd` | Instantiates every scene into the tree; checks Interactables point at files that exist. |
| `test_scripts.gd` | Loads every script, so a parse error fails a test instead of a playthrough. |

The last three are the ones that earn their keep — they catch the mistakes that
otherwise only show up when somebody walks up to the wrong desk.
