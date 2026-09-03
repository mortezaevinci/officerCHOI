# Scene flow

How the player gets from the title screen to a conversation and back, and which
piece of code owns each arrow.

```
                 boot.tscn
                     |  reads dev switches, then:
                     v
              main_menu.tscn
             /               \
   Continue /                 \ New Game
           v                   v
   SaveGame.load          GameState.reset()
           \                   /
            v                 v
        SceneFlow.goto(room, spawn)
                     |
                     v
             +---------------+
             |   a Room      |<--------------------+
             |  precinct /   |                     |
             |  hallway      |                     |
             +---------------+                     |
                |    |    |                        |
      DIALOGUE  |    |    | GOTO_SCENE             | SceneFlow.pop()
                |    |    +---> another Room       | (the room was never
                v    |          (goto: this one    |  freed - it comes
      dialogue box   |           is freed)         |  back untouched)
      over the room  |                             |
                     | PUSH_SCENE                  |
                     v                             |
             +---------------+                     |
             | conversation  |---------------------+
             |  desk_ward    |   when the .dlg ends
             +---------------+
```

## Who owns what

| Arrow | Owner |
|---|---|
| Boot to menu | `src/ui/boot.gd` |
| Menu to room | `src/ui/main_menu.gd` calling `SceneFlow.goto` |
| Room to room | `Interactable` with `GOTO_SCENE` |
| Room to desk | `Interactable` with `PUSH_SCENE` |
| Desk back to room | `ConversationView` on `Dialogue.finished` calling `SceneFlow.pop` |
| Any fade | `SceneFlow` |
| Pause on top of all of it | `Room.open_pause_menu` |

## goto vs push, and why it matters

`goto` frees the current scene and clears the stack. Use it for anywhere the
player is not coming straight back to.

`push` **detaches** the current scene instead of freeing it. The room, the
player's exact position, every NPC and every timer stay in memory. `pop` puts it
back. Nothing has to be serialised and restored, because nothing was lost.

That is what makes a desk feel like a place in a room rather than a level
transition, and it is why the desk does not need its own save/restore logic.

## Spawn points

A `goto` carries a spawn name. The target room looks for `Spawns/<name>` and
puts the player there, falling back to its `default_spawn`.

Naming them after where the player came *from* (`from_hallway`, `from_precinct`)
makes two-way doors obvious and keeps them symmetrical.

## Where a save lands you

`GameState.current_scene` and `current_spawn` are written whenever a room is
entered. Loading a save calls `SceneFlow.goto` with exactly those. A save made
inside a desk conversation is deliberately prevented — the pause menu disables
Save while `Dialogue.is_active`, because restoring into a room with a
half-finished conversation would be a lie about where the player was.
