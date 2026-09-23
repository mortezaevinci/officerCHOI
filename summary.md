# Summary — what has been built, newest first

Append to this. Do not rewrite it.

---

## 2026-09-19 — backdrops, tooling, housekeeping

**Toronto Pearson backdrops regenerated** through kling (`C:\temp\aitools`), at
2720×1536, replacing the old 1920×1080 batch that carried a visible
`pollinations.ai` watermark. Each confirmed on screen before installing; old
copies in `backup/20260919-160728-backdrops/`.

- `SC-CHOI-BOOTH` — counter, glass, monitor angled away, belt barriers, yellow line.
- `SC-CHOI-BACKROOM` — interrogation room: bolted steel table, one-way mirror,
  two officers guarding it, arms folded, hostile. Deliberately not a waiting room.
- `SC-CHOI-DESK` — the refusal desk; passport, stamp, printed slip, no chair on
  the traveller's side.
- `SC-PEARSON` — two lanes: five white travellers walking a nearly empty lane
  into an open booth, and a packed lane of Black and brown travellers snaking
  back out of frame. The argument of the game in one frame.

**Iranian set (16) generated and rejected.** The prompt said "Persian signage
and architecture" and came back generically Middle Eastern. Iran is modern,
colourful and various, and people dress ordinarily. To be redone one at a time.

**`scene_queue.py`** added: builds a kling prompt queue from each run's own
scene records (`location`, `time`, `mood`, `note`), so prompts follow the
content rather than a separate table that drifts.

**`jdk-17` moved** from `C:\temp\jdk-17` to `C:\jdk-17`. Four references
updated: three `_script` `.bat` files and Godot's
`export/android/java_sdk_path`. Verified by running `java -version`.

**Queue restructured** to the `_queue` standard: `queue.py` CLI, append-only
`items/<id>.csv` as truth, `queue.csv` as a rebuildable cache.

**`prompt_beemo.md`** written: the writing register. Funny first, then the gap —
a laugh gets under the guard that outrage bounces off, and once the room has
laughed with the officer it is implicated. Restraint, specificity, the villain
gets the best lines, punch up, never explain the joke.

---

## 2026-09-14 — the encounter became a mechanic

**Choi's abuse is now playable, not described.** `choi_strikes` counts every
answer that is not submission and persists across the whole encounter.

- **Men** (Iranian, Palestinian, Mexican): first question earns a warning and a
  strike; the second reaches `door` — "THE DOOR IS THAT WAY. GOODBYE." — and the
  run ends. Asking for your own documents back ejects with no warning.
- **Nigerian nurse**: identical questions, never ejected. She is kept, leered at
  ("babe", "sweetheart", "darling") and runs out of questions he will tolerate.
- **US citizen**: never accrues a strike. Nineteen minutes, waved through with
  the drugs, apologised to.

**Ending cards** on all 17 terminal paths — "THE END. GAME OVER. YOU FAILED.",
and for the citizen alone "MISSION ACCOMPLISHED." Ejections carded too: being
thrown out ends the life as finally as the refusal.

**Engine changes.** `choi_strikes` / `choi_ejected` declared in
`GameState.DEFAULTS` (an undeclared variable makes a condition unparseable,
which *hides* the gated option instead of showing it); `journey_view` stops the
encounter on ejection; `dialogue_runner` reveals gated options as `[locked]`
when the cheat is on; dialogue box `mouse_filter` fixed so tapping the text
advances; "I understand" on the right, choices moved left.

**Verified on device**, not just built: played to an ejection on the emulator
and captured the door and the card. 81 tests, 0 failures.

**Known defects logged** (see the queue): gated options render as visible
duplicates under the cheat; choice buttons overlap Choi's portrait; the advance
button sits flush against the panel edge.

---

## Earlier

Five nationalities, each with its own ten-mission season and its own Choi
encounter (`choi_<run>`), drawn from the abuse/goodlife/hurdles datasets. Name
misspelling table ("Kaveh" → "Gaveh"). Cheat word `papers` on mission select.
Android export working (must use the **standard** Godot editor, not mono).
Script Map published as a browsable, editable artifact of every scene and branch.
