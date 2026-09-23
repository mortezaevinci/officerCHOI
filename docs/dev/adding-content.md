# Adding content

Four recipes. None of them need new code.

---

## A new conversation

1. Write `game/content/dialogue/en/my_scene.dlg`
   (format: [../writing/dialogue-format.md](../writing/dialogue-format.md)).
2. Point something at it — an Interactable, or a desk scene.
3. `tools\build\run-tests.ps1`.

To read it back without playing to it:

```powershell
C:\temp\godotsetup\engine\godot\Godot_v4.7.2-stable_win64.exe --path game -- --dialogue=my_scene.dlg --left=choi --right=ward --auto
```

---

## Something to interact with in a room

1. In the room scene, add a `Node2D` for the object and give it a shape
   (a `Polygon2D` for now; a `Sprite2D` once there is art).
2. Add `scenes/entities/interactable.tscn` as a child of it.
3. Fill in the inspector:

   | Field | For a short chat | For a desk | For a door |
   |---|---|---|---|
   | Prompt | "Talk to Ward" | "Sit down at the desk" | "Step into the hallway" |
   | Action | `DIALOGUE` | `PUSH_SCENE` | `GOTO_SCENE` |
   | Dialogue File | the `.dlg` | — | — |
   | Target Scene | — | the conversation scene | the room scene |
   | Target Spawn | — | — | a Marker2D name in that room |

4. Optionally set **Condition** (`chapter >= 2`), **Once**, or **Sets Flag**.

`prompt_offset` is where the floating label sits relative to the object —
push it up until it clears the artwork.

---

## A desk (a close-up conversation)

The generic view is `scenes/conversations/conversation.tscn`. Two ways to use it:

**Authored** — make an inherited scene, like `desk_ward.tscn`:

```
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://scenes/conversations/conversation.tscn" id="1"]

[node name="DeskWard" instance=ExtResource("1")]
dialogue_file = "res://content/dialogue/en/desk_ward.dlg"
left_character = "choi"
right_character = "ward"
```

In the editor: right-click `conversation.tscn` → **New Inherited Scene**, fill in
the fields, save it under `scenes/conversations/`. Then point a `PUSH_SCENE`
Interactable at it.

**Decided at runtime** — push the generic scene with a payload, when who is
sitting there depends on the story:

```gdscript
SceneFlow.push(GamePaths.CONVERSATION, {
    "dialogue": GamePaths.dialogue("desk_ward.dlg"),
    "left": "choi",
    "right": "ward",
})
```

Either way the conversation pops back to the room when it ends, with the room
exactly as it was.

---

## A new room

1. Copy `scenes/rooms/hallway.tscn` — it is the smaller of the two and has one
   of everything.
2. Change on the root node: `room_id`, `display_name`, `music`,
   `default_spawn`, and **`camera_bounds`**.
3. Rename the `Spawns/*` markers to whatever the doors leading here will ask
   for. A door in another room says `target_spawn = "from_precinct"`; there must
   be a `Spawns/from_precinct` here.
4. Move the `Walls` collision shapes to match the new floor.
5. Point a door in an existing room at it, and put a door here going back.

**`camera_bounds` must be at least 1920x1080**, the design resolution. Smaller
and the camera shows past the walls. It is the mistake that is hardest to spot
in the editor and most obvious the second you play.

---

## A new character

Add them to `game/content/characters/characters.json`:

```json
"park": {
    "display_name": "Sgt. Park",
    "color": "#8fc99a",
    "portrait_prefix": "park",
    "notes": "Desk sergeant. Runs the shift, and the gossip."
}
```

The key is what you type in `.dlg` files (`Park:` — matching is
case-insensitive). `display_name` is what players see, so multi-word names live
here. `color` tints their name in the dialogue box and their placeholder card.

Portraits are optional. Drop `assets/art/portraits/park.png` and
`park_worried.png` in when they exist; until then a labelled card stands in and
nothing breaks.

---

## Art and audio, when they arrive

| Goes in | For |
|---|---|
| `assets/art/backgrounds/` | Room floors and walls, conversation backdrops |
| `assets/art/characters/` | In-world character sprites |
| `assets/art/portraits/` | Close-up portraits: `<prefix>_<mood>.png` |
| `assets/art/props/` | Desks, doors, machines |
| `assets/art/ui/` | UI art, and `theme.tres` |
| `assets/audio/music/` | Loops. Register short names in `AudioDirector.MUSIC`. |
| `assets/audio/sfx/` | One-shots. Register in `AudioDirector.SFX`. |
| `assets/fonts/` | Fonts. Point `theme.tres` at them. |

Registering a short name means `.dlg` files can say `@music tense` instead of a
path, and the path only exists in one place if the file ever moves.
