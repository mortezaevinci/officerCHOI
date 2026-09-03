# Game design

A living document. Right now it is mostly a frame with one example filled in —
the point is that the frame matches what the code already supports, so filling
it in does not require anything new to be built.

---

## The pitch

You are a police officer on a night shift. You walk around a precinct, you sit
down at desks, and you talk to people. What you say changes what they tell you,
and what you end up believing.

Minimal graphics. Smooth, unfussy mechanics. The conversations carry it.

## Pillars

1. **Talking is the verb.** Walking exists to give conversations a place and a
   sense of choosing to have them. It never needs to be skilful.
2. **Choices accumulate.** No single choice is a fork in the road. Several small
   ones nudge counters, and a scene later reads the total. The player should
   feel the weight of a pattern, not of one button.
3. **Nothing is explained twice.** If the player worked something out, later
   lines assume it. That is what `read_case_file` and friends are for.
4. **A phone and a monitor play the same game.** No twitch input, no small
   targets, no text that only reads at 27 inches.

## The loop

```
walk into a room  ->  see who and what is there
      |                       |
      |                       v
      |              walk up to something  ->  prompt  ->  press / tap
      |                                                       |
      |                          +----------------------------+
      |                          v                            v
      |                short exchange in the room     sit down: close-up
      |                          |                            |
      |                          +------------> choices <-----+
      |                                            |
      +--------------- back to the room <----------+
```

## What is built

| Piece | State |
|---|---|
| Walking, collision, tap-to-move | Working |
| Interactables with conditions | Working |
| In-room conversations | Working |
| Close-up desk conversations with portraits | Working, placeholder art |
| Choices, conditions, counters, branching endings | Working |
| Save / load / autosave | Working |
| Settings, pause, main menu | Working |
| Music and SFX plumbing | Working, no audio yet |
| Localisation plumbing | Working, English only |
| Steam integration | Not started — see [../build/steam.md](../build/steam.md) |
| Art and audio | Not started |
| The actual story | Not started; three sample conversations stand in |

## Structure

Chapters, tracked by `GameState.vars.chapter`. Each is a set of rooms and the
conversations available in them. A chapter ends when a conversation sets
`chapter`, which changes which Interactables pass their conditions — so content
appears and disappears without any code branching on it.

## Characters

See [../writing/characters.md](../writing/characters.md).

## Relationship values

Small integers, nudged a point at a time and read in bulk:

| Variable | Range | Read at |
|---|---|---|
| `trust_ward` | 0-5 | End of the desk scenes |
| `trust_park` | 0-5 | Chapter ends |
| `suspicion` | 0-5 | Endings |

Keep the ranges small. A player can feel the difference between 1 and 3; nobody
feels the difference between 47 and 52.

## Scope, honestly

The reading-time counter is one command away:

```powershell
python.exe tools\dialogue\dialogue_stats.py
```

A conversation game lives or dies on how much of it there is. Run that often
enough that the number never surprises you.

## Open questions

- How many chapters? (A first estimate: three, ~45 minutes each.)
- Is there a fail state, or only different endings? (Leaning: only endings.)
- Voice acting? (Leaning no — `assets/audio/voice/` exists in case.)
- Does the player character have a name the player picks? (Leaning no: "Choi"
  is a character, not an avatar.)
