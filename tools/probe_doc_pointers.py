"""THE POINTER LAW (CLAUDE.md). A doc asserting the state of code must cite file:line
or name a probe. Otherwise it must carry a date banner and read as of-its-time.

Weak by design: this checks the SHAPE of an assertion, never its truth. A green run means
"nothing asserts code state unpointered", not "the docs are correct".

    python tools/probe_doc_pointers.py            # gate: exit 1 if the count exceeds CEILING
    python tools/probe_doc_pointers.py --list     # every offending line

CEILING ratchets DOWN only, exactly like tests/fossil_baseline.json. Fix docs, lower the number.
Raising it is the forbidden move.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Established 2026-07-19 by the first run of this probe. ONLY SHRINKS.
CEILING = 44

SCAN_DIRS = ["production", "."]

# war_room/ is dated deliberation history, not law (ADR-014). Research and archives likewise
# describe a moment. The law binds docs that read as CURRENT STATE.
SKIP_PARTS = (".git", ".godot", ".claude", "node_modules", "addons",
              "war_room", "archive", "research", "cinematics")

# An assertion is "about code" if it names a source file, a call, or a screaming-snake const.
CODE_SHAPE = re.compile(r"\b\w+\.(?:gd|tscn|tres|py)\b|\b[a-z_]+\w*\(\)|\b[A-Z][A-Z0-9_]{4,}\b")

# ...and only if it CLAIMS something about that code, present tense. Naming a file is not a claim.
CLAIMS = re.compile(
    r"\b(?:is|are|was|were|does|do|has|have|holds|returns|exists?|lives?|sits?|reads?|writes?|"
    r"calls?|fires?|drives?|wires?|owns?|runs?|ships?|zero|no such|nothing|only|already|still)\b",
    re.I)

# A pointer discharges it: file.gd:123, a :123 line ref, or a named probe/test.
POINTER = re.compile(r"\.(?:gd|tscn|tres|py|json|cfg):\d+|(?<![\w.]):\d{1,5}\b|\b(?:probe|test)_\w+|\btests/\w+")

# A date marks the claim as of-its-time.
DATE = re.compile(r"\b20\d\d-\d\d-\d\d\b|\b20\d\d\d\d\d\d\b")

# Prose that proposes, forbids or plans is not an assertion of current code state.
HEDGE = re.compile(r"\b(?:should|must|will|would|proposed|propose|plan|if |never |do not|don't|todo|"
                   r"recommend|consider|law|rule|decree)\b", re.I)


def is_banner_dated(lines: list[str]) -> bool:
    """A date in the masthead marks the whole doc as of-its-time."""
    return any(DATE.search(ln) for ln in lines[:15])


def near_dated(lines: list[str], idx: int) -> bool:
    """A dated section heading covers the lines beneath it."""
    return any(DATE.search(ln) for ln in lines[max(0, idx - 12):idx])


def scan(path: str) -> list[tuple[int, str]]:
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return []
    if is_banner_dated(lines):
        return []

    bad: list[tuple[int, str]] = []
    fenced = False
    for i, raw in enumerate(lines, 1):
        line = raw.strip()
        if line.startswith("```"):
            fenced = not fenced
            continue
        if fenced or not line or line.startswith(("#", ">", "|", "-", "*")):
            continue
        if not (CODE_SHAPE.search(line) and CLAIMS.search(line)):
            continue
        if POINTER.search(line) or DATE.search(line) or HEDGE.search(line):
            continue
        if near_dated(lines, i - 1):
            continue
        bad.append((i, line[:120]))
    return bad


def main() -> int:
    show_all = "--list" in sys.argv
    offenders: dict[str, list[tuple[int, str]]] = {}

    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        for dirpath, dirnames, filenames in os.walk(base):
            rel = os.path.relpath(dirpath, ROOT).replace("\\", "/")
            if any(p in rel for p in SKIP_PARTS):
                dirnames[:] = []
                continue
            if d == "." and rel != ".":
                continue  # root scan is non-recursive; production/ is walked on its own
            for fn in filenames:
                if not fn.endswith(".md"):
                    continue
                full = os.path.join(dirpath, fn)
                key = os.path.relpath(full, ROOT).replace("\\", "/")
                if key in offenders:
                    continue
                hits = scan(full)
                if hits:
                    offenders[key] = hits

    total = sum(len(v) for v in offenders.values())
    print(f"POINTER LAW: {total} unpointered assertion(s) across {len(offenders)} doc(s). "
          f"Ceiling {CEILING}.")
    print("Each names code but cites no file:line, no probe, and no date covering it.\n")
    for key in sorted(offenders, key=lambda k: -len(offenders[k])):
        hits = offenders[key]
        print(f"  {key}  ({len(hits)})")
        for ln, text in (hits if show_all else hits[:3]):
            print(f"    :{ln}  {text}")
        if not show_all and len(hits) > 3:
            print(f"    ... {len(hits) - 3} more (--list)")

    if total > CEILING:
        print(f"\nFAIL: {total} exceeds ceiling {CEILING}. Cite a pointer or date the claim.")
        print("Do NOT raise CEILING - it ratchets down only.")
        return 1
    if total < CEILING:
        print(f"\nPASS - and {CEILING - total} under ceiling. "
              f"Lower CEILING to {total} in this file to bank the ground.")
    else:
        print("\nPASS at ceiling.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
