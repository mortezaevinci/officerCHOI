"""Fetches journey backdrops from an online image generator.

    python.exe tools\\art\\fetch_scene_art.py
    python.exe tools\\art\\fetch_scene_art.py --only SC-REGISTRY
    python.exe tools\\art\\fetch_scene_art.py --force        # refetch everything

Reads the `prompt` on each scene in art-source/journey_scenes.json and writes
game/assets/art/backgrounds/journey/<scene>.png.

WHY THIS EXISTS. The backdrops used to be composed from Kenney tiles by
build_journey_scenes.py. They read as a tile grid rather than a place, so this
replaces them with generated art. That script is kept - it needs no network and
still works - but this is what produces the shipped backgrounds.

THE SERVICE. https://image.pollinations.ai - plain GET, and anonymous requests
do work. Rate limited to roughly one request every 15 seconds, so this paces
itself and skips anything already on disk.

ANONYMOUS OUTPUT IS NOT USABLE, AND HERE IS WHY, SO NOBODY RETRIES IT:

  - `nologo=true` alone does NOT remove the watermark. Tested: the image comes
    back with "pollinations.ai" burned into the bottom-right corner, which is
    exactly where the dialogue box sits.
  - Adding `referrer=` and a Referer header does not remove it either. Also
    tested. Removal is tied to a registered account.
  - Anonymous requests are additionally downscaled - asking for 1920x1080
    returned 1024x576.

So this needs a token from https://auth.pollinations.ai (free) passed via
--token or the POLLINATIONS_TOKEN environment variable. With one, the run is
unattended and produces clean, full-resolution art. Without one, do not ship
the output: cropping somebody else's branding off their image does not make it
ours, and the quality is good enough that it is worth getting the credential
rather than working around it.

LICENSING, WHICH IS NOT SETTLED. The rest of this project's art is CC0 or
OGA-BY with a named source, because a paid release needs provenance. Generated
images do not have that: the model's training data is not disclosed and the
legal position on output ownership differs by jurisdiction and is unresolved.
These are therefore recorded in art-source/LICENSES.md under their own heading,
NOT as CC0, and the decision about whether they ship is deliberately left open.
Every prompt is stored next to the image so any of it can be regenerated or
replaced without guesswork.

Deterministic: the seed comes from the scene id, so the same scene always
fetches the same picture and a rebuild does not silently change the game's look.
"""

from __future__ import annotations

import argparse
import io
import os
import json
import pathlib
import sys
import time
import urllib.parse
import zlib

try:
    import requests
except ImportError:
    sys.exit("requests is not installed for this interpreter.\n"
             "On this machine use the Windows Python: "
             "python.exe tools\\art\\fetch_scene_art.py")

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is not installed for this interpreter.\n"
             "On this machine use the Windows Python: "
             "python.exe tools\\art\\fetch_scene_art.py")

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONFIG = ROOT / "art-source" / "journey_scenes.json"
OUT_DIR = ROOT / "game" / "assets" / "art" / "backgrounds" / "journey"
MANIFEST = ROOT / "art-source" / "journey_scene_prompts.md"

ENDPOINT = "https://image.pollinations.ai/prompt/"

# The design resolution. Fetched at this size rather than upscaled, so the art
# is sharp behind a 1920x1080 dialogue box.
WIDTH, HEIGHT = 1920, 1080

# Anonymous requests are throttled at about one per fifteen seconds. Going
# faster earns 429s and a slower run overall.
PACE_SECONDS = 16
TIMEOUT = 180

# Appended to every prompt so twenty scenes look like one game rather than
# twenty. No people: the character portrait is drawn on top, and a painted
# figure behind it would read as a second person in the room.
STYLE = ("digital painting, muted desaturated palette, soft cinematic lighting, "
         "wide establishing shot, empty room with no people, no text, "
         "no lettering, no watermark, video game background art")


def seed_for(scene_id: str) -> int:
    """Stable per scene, so the art does not change under you on a rebuild."""
    return zlib.crc32(scene_id.encode("utf-8")) & 0x7FFFFFFF


def fetch(prompt: str, seed: int, token: str = "") -> Image.Image:
    url = ENDPOINT + urllib.parse.quote(f"{prompt}. {STYLE}", safe="")
    params = {"width": WIDTH, "height": HEIGHT, "seed": seed,
              "model": "flux", "nologo": "true", "private": "true"}
    headers = {"Referer": "officerchoi"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    response = requests.get(url, params=params, headers=headers, timeout=TIMEOUT)
    response.raise_for_status()
    if not response.content:
        raise RuntimeError("empty response body")
    image = Image.open(io.BytesIO(response.content)).convert("RGB")
    if image.size != (WIDTH, HEIGHT):
        image = image.resize((WIDTH, HEIGHT), Image.LANCZOS)
    return image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", help="fetch a single scene by id")
    parser.add_argument("--force", action="store_true",
                        help="refetch scenes that already have art")
    parser.add_argument("--list", action="store_true", help="list scenes and exit")
    parser.add_argument("--token", default=os.environ.get("POLLINATIONS_TOKEN", ""),
                        help="auth.pollinations.ai token; also read from "
                             "POLLINATIONS_TOKEN. Without it the output is "
                             "watermarked and downscaled, and must not ship.")
    args = parser.parse_args()

    if not args.token:
        print("WARNING: no token. Output will carry a pollinations.ai watermark\n"
              "         in the bottom-right and be downscaled. Fine for looking\n"
              "         at; not fine to ship. See the module docstring.\n")

    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    scenes = {k: v for k, v in config["scenes"].items() if not k.startswith("_")}

    if args.list:
        for scene_id in sorted(scenes):
            has = "has prompt" if scenes[scene_id].get("prompt") else "NO PROMPT"
            print(f"{scene_id:18} {has}")
        return

    wanted = [args.only] if args.only else sorted(scenes)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    written, skipped, failed = 0, 0, []
    for i, scene_id in enumerate(wanted):
        if scene_id not in scenes:
            sys.exit(f"no such scene {scene_id!r}; --list shows them all")
        prompt = str(scenes[scene_id].get("prompt", "")).strip()
        if not prompt:
            print(f"{scene_id:18} no prompt in journey_scenes.json, skipping")
            skipped += 1
            continue

        out = OUT_DIR / f"{scene_id}.png"
        if out.exists() and not args.force:
            print(f"{scene_id:18} already on disk, skipping")
            skipped += 1
            continue

        if written and i < len(wanted):
            time.sleep(PACE_SECONDS)

        try:
            image = fetch(prompt, seed_for(scene_id), args.token)
        except Exception as error:   # noqa: BLE001 - one bad scene must not stop the run
            print(f"{scene_id:18} FAILED: {error}")
            failed.append(scene_id)
            continue

        image.save(out)
        written += 1
        print(f"{scene_id:18} {image.width}x{image.height} -> "
              f"{out.relative_to(ROOT)}")

    # Keep the prompts beside the art. Regenerating or replacing a scene later
    # should never require reconstructing what was asked for.
    lines = ["# Journey scene prompts", "",
             "Generated by `tools/art/fetch_scene_art.py` from the `prompt` field",
             "of each scene in `art-source/journey_scenes.json`.", "",
             "Provenance is recorded in `LICENSES.md`; these are **not** CC0.", "",
             f"Shared style suffix:", "", f"> {STYLE}", "",
             "| Scene | Seed | Prompt |", "|---|---|---|"]
    for scene_id in sorted(scenes):
        prompt = str(scenes[scene_id].get("prompt", "")).replace("|", "/")
        if prompt:
            lines.append(f"| `{scene_id}` | {seed_for(scene_id)} | {prompt} |")
    MANIFEST.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"\n{written} fetched, {skipped} skipped"
          + (f", {len(failed)} failed: {', '.join(failed)}" if failed else ""))
    print(f"prompts recorded in {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
