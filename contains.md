# What is in this folder

`C:\temp\officerchoi` — **Officer Choi**, a 2D conversation game in Godot 4.7.
You play a life from birth to an airport, and then you meet the officer.

The scripts that *build* this game's content do not live here. They live in
`C:\temp\_script\officerchoi` — see `layout.md`.

---

## The `.md` files at the top level, and what each holds

| File | What kind of information |
|---|---|
| `contains.md` | this file — what lives in this folder |
| `layout.md` | every folder here and in `_script\officerchoi`, and what goes in it |
| `summary.md` | what has been built and decided, newest first |
| `prompt.md` | what each of these `.md` files is for, and which to read when |
| `CLAUDE.md` | rules an agent must follow while working in this repo |
| `README.md` | what the game is, for a human arriving cold |
| `how to build.md` | build the Windows exe and the Android APK |
| `how to run android.md` | boot the emulator, install, launch, screenshot |
| `prompt_beemo.md` | the writing register — funny and provocative, and why |
| `prompt_forscenes.txt` | image prompts for scene backdrops |
| `prompt_spritesheetfor2d.txt` | image prompts for character spritesheets |
| `game details.txt`, `game details 0.txt` | the original brief, kept as written |

## Everything else, in one line each

- `game/` — the Godot project. Nothing outside it ships.
- `assets/text/` — the source CSVs the content is written from (never shipped).
- `art-source/` — LPC spritesheet layers and working art (never shipped).
- `tools/` — the pinned Godot binaries, build and art tooling.
- `docs/` — design, build and writing notes.
- `preview/` — generated reports: the script map, text dumps, screenshots.
- `android/`, `steam/` — per-platform packaging assets.
- `backup/` — timestamped copies taken before an asset or data file is replaced.
- `build/` — export output. Disposable.
- `cheat-unlock.bat` — types the cheat word into the running emulator.

## Borrowed from elsewhere

- `C:\temp\_script\officerchoi` — every build and content script.
- `C:\temp\aitools` — image generation (kling) for backdrops.
- `C:\temp\_queue\officerchoi` — the work queue.
- `C:\jdk-17` — JDK for the Android export.
