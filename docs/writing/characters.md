# Characters

The list of who exists lives in `game/content/characters/characters.json`. This
page is for the part that does not fit in a JSON field: who they are, and how
they talk.

Adding someone is one JSON entry — see
[../dev/adding-content.md](../dev/adding-content.md#a-new-character).

---

## Choi — the player character

Key `choi`. Third shift, two years in. Writes reports longhand because the
terminal is slower. Not naive, not cynical yet; somewhere in the gap.

**Voice.** Short sentences. Answers questions with statements. Says the obvious
thing on purpose, to see what someone does with it. Rarely asks twice.

Choi's lines are the player's lines, so they carry the choice the player made
without over-editorialising it. If a choice was "press him", Choi presses — it
does not also add a paragraph about how uncomfortable that felt.

## Ward — the detective

Key `ward`. Knows more than he says and says more than he should, which are not
the same problem. Signed in for nineteen hours and does not check the log
because he already knows.

**Voice.** Deflects with a general truth when asked a specific question ("It's
the department's. I just carried it."). Comfortable with silence; will make one
yours if you leave it. Occasionally lands one flat sentence with nothing under
it, and that is the one that is true.

## Park — the desk sergeant

Key `park`. Runs the shift, and the gossip. Not yet written into a scene.

**Voice.** Warm, fast, interruptible. Says three things where one would do, and
the third is the one that matters.

---

## Writing dialogue that fits

- **One word for the speaker id.** `Ward:` in the file; "Det. Ward" is
  `display_name` in the JSON. See the format doc for why.
- **Moods are cheap.** `Ward @tired:` costs nothing if the art does not exist —
  it falls back. Tag them as you write, so the artist has a list later.
- **Give the player something to be, not something to pick.** The best choice
  menus are three ways of being a person, not three ways of asking a question.
- **Let a condition do the callback.** Instead of a character re-explaining,
  write a second version of the node behind `if read_case_file ->`. It is two
  extra lines and it is the whole reason the flags exist.

## Registering a mood

Nothing to register. `Choi @tired:` looks for
`assets/art/portraits/choi_tired.png`, falls back to `choi.png`, then to a
labelled card. Write the mood you mean; the art catches up.

To see which moods the writing has actually asked for:

```powershell
findstr /S /R /C:"@[a-z]*:" game\content\dialogue\en\*.dlg
```
