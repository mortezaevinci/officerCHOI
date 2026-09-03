# Writing a conversation

Conversations live in `game/content/dialogue/en/` as `.dlg` files. They are
plain text. You do not need Godot open to write one, and you never need to
touch code to add one.

Run the tests after editing (`tools\build\run-tests.ps1`) — they read every
`.dlg` file in the game and will tell you about a typo before a player finds it.

---

## The whole format on one page

```
# Lines starting with # are notes to yourself. Players never see them.

:: start                          <- a node: a labelled chunk of conversation
Ward: Choi. You're on tonight.    <- someone speaks
Choi @tired: Every night.         <- ...with a mood, which picks the portrait
> The lamp buzzes.                <- narration, printed in italics
It was late: later than the log.  <- also narration (no leading > needed)

+ [Ask about the file] -> ask_file            <- a choice
+ [Show the badge] if has_badge -> badge      <- ...only offered if true
+ [Say nothing] -> end                        <- 'end' stops the conversation

:: ask_file
set trust_ward += 1               <- change a story variable
set told_truth = true
if trust_ward >= 2 -> trusted     <- jump, but only if the condition holds
@music tense                      <- a stage direction (see below)
-> parting                        <- jump, always

:: trusted
Ward: When you write this up, leave the times out.
-> parting

:: parting
> The file stays on the desk.
end                               <- explicitly finish
```

That is everything. Nine kinds of line.

---

## Line by line

### Nodes: `:: name`

A node is a labelled chunk. Everything under a `::` label belongs to it, until
the next label. The **first** node in the file is where the conversation starts.

Names are lowercase with underscores. Keep them descriptive — `ask_about_file`
beats `node3`, because you will be reading a jump to it six weeks from now.

### Speech: `Name: text`

The name is **one word**, no spaces. That rule is what lets ordinary prose
contain a colon without being mistaken for a speaker.

A longer name on screen ("Det. Ward") comes from `display_name` in
`game/content/characters/characters.json`, not from the `.dlg` file.

### Moods: `Name @mood: text`

`Choi @tired:` shows `portraits/choi_tired.png` if it exists, `portraits/choi.png`
if not, and a labelled placeholder card if neither exists yet. **Write first,
draw later** — an undrawn mood never breaks anything.

### Narration: `> text`, or just text

Both are narration and both print in italics with no speaker name. Use the `>`
when the line starts with something that could be read as a name.

### Choices: `+ [text] -> node`

A run of `+` lines is one menu. Add `if <condition>` before the arrow and the
option only appears when the condition is true:

```
+ [Bring up the badge] if has_badge and not told_truth -> badge
```

If every option is filtered out the conversation walks on rather than hanging,
so it is worth having at least one option with no condition.

### Variables: `set name = value`

```
set told_truth = true       # assign
set trust_ward += 1         # add
set suspicion -= 1          # subtract
set mood = trust_ward * 2   # the right side is a full expression
```

New variables should also be listed in `DEFAULTS` in
`game/src/autoload/game_state.gd`. It is one line, and it means a condition on
that variable behaves the same in every playthrough.

### Conditions

Anywhere a condition is allowed (`if ... ->`, `+ [x] if ... ->`) you can write
ordinary comparisons and combine them:

```
trust_ward >= 2
not told_truth
has_badge and suspicion < 3
chapter == 2 or read_case_file
```

A variable nobody has ever set reads as **false**, so it is safe to test a flag
before anything sets it.

### Jumps: `-> node` and `if ... -> node`

`-> node` always jumps. `if cond -> node` jumps only when the condition holds,
and otherwise carries straight on to the next line. Stacking a few of those is
how endings get chosen:

```
if suspicion >= 2 -> cold_ending
if trust_ward >= 2 -> warm_ending
-> neutral_ending
```

`-> end` finishes the conversation.

### Ending: `end`

Stops the conversation. Falling off the bottom of a node does the same thing,
but writing `end` says you meant it.

### Stage directions: `@command args`

These do not print. The scene decides what they mean:

| Command | What it does | Where it works |
|---|---|---|
| `@music tense` | Crossfade to a track. `@music none` fades out. | anywhere |
| `@sfx page` | Play a one-shot. | anywhere |
| `@wait 0.8` | Pause, without asking the player to click. | anywhere |
| `@portrait right ward angry` | Change who is on a side, and how they look. | close-ups |
| `@walk_to Ward desk` | Send an NPC to a spawn marker. | rooms |
| `@goto res://scenes/rooms/hallway.tscn spawn` | Leave for another scene. | rooms |

Quote an argument that has a space: `@portrait left choi "very tired"`.

An unrecognised command prints a warning and is ignored — it will not break
the scene. To add a new one, add a case in `_on_dialogue_command` in
`game/src/rooms/room.gd` or `game/src/ui/conversation_view.gd`.

### Putting a number in a line

`{...}` is replaced with the value:

```
Ward: You've written that up {report_count} times now.
```

---

## Two shapes of conversation

**In the room.** The dialogue box appears over the room; nobody moves. Right for
anything short. Point an Interactable at the `.dlg` file and you are done.

**The close-up.** A separate screen with portraits — the desk scene. Right for
the scenes that carry the story. These can use `@portrait`, and the speaker's
portrait lights up while the other dims, automatically.

Which one you get depends on how the Interactable is set up, not on anything in
the file. The same `.dlg` works in both.

---

## Things that will bite you

- **A jump to a node that does not exist** is caught by the tests, not by the
  game. Run them.
- **A node nothing jumps to** is also caught by the tests. It usually means a
  rename that stopped halfway.
- **A speaker not in `characters.json`** gets the default colour and no
  portrait. The tests flag it.
- **Two nodes with the same name** — the second is ignored. Flagged too.

Run `tools\build\run-tests.ps1` and all four show up in seconds.
