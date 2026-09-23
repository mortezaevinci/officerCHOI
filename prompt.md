# Which file to read, and when

Five `.md` files sit at the top of this folder and they do not overlap. Read the
one that answers your question rather than all of them.

| If you need to know | Read | It will not tell you |
|---|---|---|
| what is in this folder | `contains.md` | where a *new* file should go |
| where a new file goes | `layout.md` | what is currently in there |
| what has already been built and decided | `summary.md` | how to build it |
| the rules you must follow here | `CLAUDE.md` | anything about content |
| how to write the dialogue | `prompt_beemo.md` | what the dialogue currently says |
| how to build and run it | `how to build.md`, `how to run android.md` | why it is built that way |
| what the game *is* | `README.md` | how any of it works |

## The division of labour

- **`contains.md`** — an inventory. One line per thing that exists here now.
  Kept current when something is added or removed.
- **`layout.md`** — the rules of placement. Which folder a kind of file belongs
  in, for both this repo and `C:\temp\_script\officerchoi`, plus the pipeline
  from source CSV to shipped build. Changes only when the structure changes.
- **`summary.md`** — the running record. What was built, what was decided and
  why, newest first. Append to it; do not rewrite history.
- **`prompt.md`** — this file. The index to the other four.

`C:\temp\layout.md` and `C:\temp\prompt.md` do the same job one level up, for
every project on the machine. This folder's copies are the local, detailed
version — when they disagree, the machine-level files win on anything about
other folders, and these win on anything inside this one.

## Before you start work here

1. `contains.md` — what exists.
2. `summary.md` — what already happened, so you do not redo or undo it.
3. `CLAUDE.md` — the rules, especially: **build and install after a batch of
   changes**; a green test suite only proves it parses.
4. The queue at `C:\temp\_queue\officerchoi` — what is actually outstanding.
   `python.exe queue.py list`.

## When you finish

- Append what you did to `summary.md`.
- Update `contains.md` if you added or removed something at the top level.
- Close or add queue items — one item per thing.
- Do not leave a change built but not installed. An export is not an install.
