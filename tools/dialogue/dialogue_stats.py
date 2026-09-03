"""Reports on the writing: how long it is, who talks, where it branches.

    python tools\\dialogue\\dialogue_stats.py
    python tools\\dialogue\\dialogue_stats.py --file desk_ward.dlg --map

Correctness is the test suite's job (tools\\build\\run-tests.ps1 reads every
.dlg file and fails on a bad jump). This is the other question a writer has:
how much game is actually written, and is anyone getting all the lines.

Use the Windows Python: `python.exe tools\\dialogue\\dialogue_stats.py`.
"""

from __future__ import annotations

import argparse
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIALOGUE_DIR = ROOT / "game" / "content" / "dialogue"

# Kept deliberately in step with game/src/dialogue/dialogue_parser.gd.
RE_NODE = re.compile(r"^::\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
RE_CHOICE = re.compile(r"^\+\s*\[(.+?)\]\s*(?:if\s+(.+?)\s*)?->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
RE_JUMP = re.compile(r"^->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
RE_BRANCH = re.compile(r"^if\s+(.+?)\s*->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
RE_SET = re.compile(r"^set\s+([A-Za-z_][A-Za-z0-9_]*)\s*(=|\+=|-=)\s*(.+?)\s*$")
RE_COMMAND = re.compile(r"^@([A-Za-z_][A-Za-z0-9_]*)\s*(.*?)\s*$")
RE_LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]{0,23})(?:\s+@([A-Za-z_][A-Za-z0-9_]*))?\s*:\s+(.+)$")


class Script:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.name = path.name
        self.nodes: dict[str, list[str]] = {}
        self.edges: list[tuple[str, str, str]] = []  # (from, to, label)
        self.speakers: Counter[str] = Counter()
        self.words: Counter[str] = Counter()
        self.variables: Counter[str] = Counter()
        self.commands: Counter[str] = Counter()
        self.choices = 0
        self.narration_lines = 0
        self._parse()

    def _parse(self) -> None:
        node = ""
        for raw in self.path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue

            match = RE_NODE.match(line)
            if match:
                node = match.group(1)
                self.nodes.setdefault(node, [])
                continue
            if not node:
                continue

            match = RE_CHOICE.match(line)
            if match:
                self.choices += 1
                label = match.group(1)
                if match.group(2):
                    label += f"  [if {match.group(2)}]"
                self.edges.append((node, match.group(3), label))
                self.words["(choices)"] += len(match.group(1).split())
                continue

            match = RE_JUMP.match(line)
            if match:
                self.edges.append((node, match.group(1), ""))
                continue

            match = RE_BRANCH.match(line)
            if match:
                self.edges.append((node, match.group(2), f"if {match.group(1)}"))
                continue

            match = RE_SET.match(line)
            if match:
                self.variables[match.group(1)] += 1
                continue

            match = RE_COMMAND.match(line)
            if match:
                self.commands[match.group(1)] += 1
                continue

            if line == "end":
                self.edges.append((node, "END", ""))
                continue

            if line.startswith(">"):
                text = line[1:].strip()
                self.narration_lines += 1
                self.speakers["(narration)"] += 1
                self.words["(narration)"] += len(text.split())
                self.nodes[node].append(text)
                continue

            match = RE_LINE.match(line)
            if match:
                speaker, text = match.group(1), match.group(3)
                self.speakers[speaker] += 1
                self.words[speaker] += len(text.split())
                self.nodes[node].append(text)
                continue

            self.narration_lines += 1
            self.speakers["(narration)"] += 1
            self.words["(narration)"] += len(line.split())
            self.nodes[node].append(line)

    @property
    def total_lines(self) -> int:
        return sum(self.speakers.values())

    @property
    def total_words(self) -> int:
        return sum(self.words.values())


def print_summary(scripts: list[Script]) -> None:
    print(f"{'file':<28}{'nodes':>7}{'lines':>8}{'words':>8}{'choices':>9}")
    print("-" * 60)
    for script in sorted(scripts, key=lambda s: s.name):
        print(f"{script.name:<28}{len(script.nodes):>7}{script.total_lines:>8}"
              f"{script.total_words:>8}{script.choices:>9}")
    print("-" * 60)
    print(f"{'TOTAL':<28}{sum(len(s.nodes) for s in scripts):>7}"
          f"{sum(s.total_lines for s in scripts):>8}"
          f"{sum(s.total_words for s in scripts):>8}"
          f"{sum(s.choices for s in scripts):>9}")

    # Roughly 150 spoken words a minute, which is a fair reading pace too.
    minutes = sum(s.total_words for s in scripts) / 150
    print(f"\nrough reading time: {minutes:.0f} min")


def print_speakers(scripts: list[Script]) -> None:
    lines: Counter[str] = Counter()
    words: Counter[str] = Counter()
    for script in scripts:
        lines.update(script.speakers)
        words.update(script.words)

    print(f"\n{'speaker':<20}{'lines':>8}{'words':>8}{'share':>8}")
    print("-" * 44)
    total = sum(words.values()) or 1
    for speaker, count in lines.most_common():
        print(f"{speaker:<20}{count:>8}{words[speaker]:>8}{words[speaker] / total:>7.0%}")


def print_variables(scripts: list[Script]) -> None:
    variables: Counter[str] = Counter()
    commands: Counter[str] = Counter()
    for script in scripts:
        variables.update(script.variables)
        commands.update(script.commands)

    if variables:
        print("\nstory variables written:")
        for name, count in variables.most_common():
            print(f"  {name:<24} {count}x")
    if commands:
        print("\nstage directions used:")
        for name, count in commands.most_common():
            print(f"  @{name:<23} {count}x")


def print_map(script: Script) -> None:
    print(f"\nbranch map - {script.name}")
    print("-" * 60)
    for node in script.nodes:
        line_count = len(script.nodes[node])
        print(f"  :: {node}   ({line_count} line{'s' if line_count != 1 else ''})")
        for src, dst, label in script.edges:
            if src != node:
                continue
            arrow = f"      -> {dst}"
            print(f"{arrow}{'   ' + label if label else ''}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", help="only this .dlg file name")
    parser.add_argument("--lang", default="en", help="language folder (default: en)")
    parser.add_argument("--map", action="store_true", help="print the branch map too")
    args = parser.parse_args()

    directory = DIALOGUE_DIR / args.lang
    if not directory.is_dir():
        raise SystemExit(f"no dialogue folder at {directory}")

    paths = sorted(directory.glob("*.dlg"))
    if args.file:
        paths = [p for p in paths if p.name == args.file or p.stem == args.file]
        if not paths:
            raise SystemExit(f"no such file: {args.file}")

    scripts = [Script(p) for p in paths]
    if not scripts:
        raise SystemExit(f"no .dlg files in {directory}")

    print_summary(scripts)
    print_speakers(scripts)
    print_variables(scripts)
    if args.map:
        for script in scripts:
            print_map(script)


if __name__ == "__main__":
    main()
