# Rewrite prompt — apply to every journey

The instruction for converting the Choi encounters, and every other scene, into
the register in `scene_examples.md`. Work one event file at a time.

---

## The prompt

> Rewrite this scene so that **nothing happens off screen.**
>
> Every rule, every decision, every refusal is a physical act somebody performs
> in front of the player. If a rule is invented, the player watches it being
> made: the drawer, the marker, the tape, the sheet straightened on the glass.
> If a document is dismissed, a finger slides it off the edge of the desk. If a
> phone call is refused, the receiver comes up, hangs in the air, and goes back
> in the cradle. If contraband is waved through, somebody walks four paces to a
> bin.
>
> Never write "he decides", "it is refused", "nobody checks", "whatever it is,
> it is now true". Those are summaries of something the player should have
> watched. Find the object and the movement and write those instead.
>
> Officer Choi does not reason and cannot be reasoned with. He does not have
> criteria. He has moods and a keyboard. A rule exists from the moment he says
> it and was always true. Do not let him explain himself, do not let him be
> persuaded, and never give the player a line that would have worked.
>
> His register splits by who is in front of him, and the split is the point:
> shouting, interruption and the door for the men; "babe", "sweetheart" and
> leering familiarity for the women; a nickname, an apology and a wink for the
> American. Same shift, same officer, same language that would survive any
> complaint.
>
> Let the player be good at their job before you take anything from them. Nine
> years of nights. A doctorate. Fourteen years at the same firm. The loss is
> measured against what was there.
>
> Give the player at least one answer that is correct, precise, useful, and
> changes nothing.
>
> No line explains another. Nothing is resolved. No moral at the end. If a
> sentence tells the reader how to feel, delete it and write what was on the
> table instead.

---

## The specific fix, everywhere

Search each event file for narration that **summarises** rather than shows.
These are the phrases that hide the beat:

| Found in the text | What it is hiding | Write instead |
|---|---|---|
| "it is now true" | the record being typed | four seconds of typing you will never read |
| "nobody checks" | a number nobody dials | the receiver lifted and replaced |
| "the answer does not change" | a monitor turned away | the scrollbar going past P and not stopping |
| "he is not going to look at it" | paper refused | one finger sliding it off the edge of the desk |
| "there is no form" | impunity | four paces to a grey bin by the door |
| "he decides" / "it is refused" | the whole hearing | the physical act that was the hearing |
| "nobody tells you" | the flight going | BOARDING → DEPARTED on the corridor board |
| "he says it again" | the name | write it three more times in his dialogue |

## Per journey

Same treatment, different objects. The object is what makes it that person's
life rather than a generic one.

- **Iranian** — the marker and tape; the degree that is not on a list nobody
  will show; the credential evaluation that cost 340 dollars, placed on the desk
  and not picked up; *Gaveh*, said eleven times in his dialogue, not summarised.
- **Palestinian** — the dropdown scrolled past P; the travel document put
  somewhere out of sight, which is the part that actually frightens him; the
  permit with a date on it.
- **Nigerian** — the folder with the coffee cup on it; the registration number
  recited from memory; the desk phone lifted and put down.
- **Mexican** — the return ticket placed on the counter and shouted over; the
  name *Jose* used for somebody else's whole life; the daughter's graduation at
  two o'clock.
- **US citizen** — the bin, the bag held up at chest height, Ward looking at
  Choi a second too long, the apology.

## Order of work

1. `journey_choi_iran_events.py` — the sign, the name, the list.
2. `journey_choi_usa_events.py` — the warm one. Currently written shouted, which
   is backwards, and the contrast is the argument of the game (t002).
3. `journey_choi_nigeria_events.py` — the leering register.
4. `journey_choi_palestine_events.py`, `journey_choi_mexico_events.py`.
5. `journey_choi_events.py` — the fallback encounter.
6. The life runs, where the same rule applies to registries, banks and
   consulates: show the stamp, the counter, the window closing.

After each file: `python journey_build.py --run choi_<run>`, then the tests,
then the build. An export is not an install.
