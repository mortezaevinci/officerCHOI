"""Downloads the CC0 source art packs into art-source/kenney/.

    python.exe tools\\art\\fetch_assets.py
    python.exe tools\\art\\fetch_assets.py --force

The packs are committed, so this is only needed to add a new one or to repair a
deleted folder. Everything it fetches is CC0 (public domain): usable in a
commercial release, no attribution required, no share-alike.

Adding a pack: put its kenney.nl slug in PACKS, run this, then record it in
art-source/LICENSES.md.
"""

from __future__ import annotations

import argparse
import io
import pathlib
import re
import sys
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "kenney"

# kenney.nl slugs. All CC0.
LPC_REPO = "https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator.git"

PACKS = [
    "roguelike-indoors",        # furniture: desks, shelves, cabinets
    "roguelike-modern-city",    # exteriors, vehicles, street furniture
    "ui-pack",                  # panels, buttons, sliders
    "input-prompts",            # keyboard / gamepad key icons
]

# The download sits behind a "consider a donation" interstitial; the real link
# is in the page under this id.
LINK = re.compile(r"https://kenney\.nl/media/pages/assets/[^'\"]*\.zip")
UA = {"User-Agent": "officerchoi-art-fetch"}


def fetch(url: str, timeout: int = 300) -> bytes:
    request = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def clone_lpc(force: bool) -> None:
    """Character art. Too big to commit (~400 MB), so it is fetched on demand.

    Licensing is per-asset and mixed; tools/art/build_characters.py refuses to
    use anything that does not offer CC0, OGA-BY or CC-BY. See LICENSES.md.
    """
    import shutil
    import subprocess

    target = ROOT / "art-source" / "lpc"
    if target.exists() and not force:
        print(f"{'lpc':24} present - use --force to re-clone")
        return
    if shutil.which("git") is None:
        print("  git is not on PATH; cannot fetch the LPC art")
        return
    if target.exists():
        shutil.rmtree(target)
    print(f"{'lpc':24} cloning (~400 MB, this takes a while)...")
    subprocess.run(["git", "clone", "--depth", "1", LPC_REPO, str(target)], check=True)
    print(f"  -> {target.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="re-download packs that already exist")
    parser.add_argument("--only", help="a single slug from PACKS")
    parser.add_argument("--lpc", action="store_true",
                        help="also clone the LPC character art (~400 MB, needs git)")
    args = parser.parse_args()

    if args.lpc:
        clone_lpc(args.force)

    OUT.mkdir(parents=True, exist_ok=True)
    packs = [args.only] if args.only else PACKS

    for slug in packs:
        target = OUT / slug
        if target.exists() and not args.force:
            count = len(list(target.rglob("*.png")))
            print(f"{slug:24} present ({count} png) - use --force to refresh")
            continue

        print(f"{slug:24} fetching...")
        try:
            page = fetch(f"https://kenney.nl/assets/{slug}").decode("utf-8", "replace")
        except Exception as error:
            print(f"  failed to open the pack page: {error}")
            continue

        match = LINK.search(page)
        if not match:
            print("  could not find a download link - the site layout may have changed")
            continue

        try:
            blob = fetch(match.group(0))
        except Exception as error:
            print(f"  download failed: {error}")
            continue

        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            archive.extractall(target)
        print(f"  {len(list(target.rglob('*.png')))} png -> {target.relative_to(ROOT)}")

    print("\nRebuild the game's art with:")
    print("  python.exe tools\\art\\build_characters.py")
    print("  python.exe tools\\art\\build_props.py")


if __name__ == "__main__":
    main()
