"""THE POINTER LAW (CLAUDE.md). A doc asserting the state of code must cite file:line
or name a probe. Otherwise it must carry a date banner and read as of-its-time.

TWO INDEPENDENT RATCHETS.

  UNPOINTERED  a claim about code carrying no file:line, no probe and no date. Weak by
               design: it checks the SHAPE of an assertion, never its truth. Green means
               "nothing asserts code state unpointered", not "the docs are correct".

  BROKEN       a pointer that RESOLVES TO NOTHING - a file that does not exist, a line
               past end-of-file, a section number the cited document does not have.
               The shape check alone let `DESIGN.md §4.2` discharge a claim for months
               while DESIGN.md had no numbered sections at all. A pointer to nothing is
               worse than no pointer, because it reads as already verified.

    python tools/probe_doc_pointers.py            # gate: exit 1 above either ceiling
    python tools/probe_doc_pointers.py --list     # every offending line
    python tools/probe_doc_pointers.py --grandfather --reason="<why>"

Both ceilings live in tools/doc_pointer_baseline.json and ratchet DOWN only. Raising one
is legal solely for a deliberate scope widening, solely through --grandfather --reason=,
which writes dated provenance. Raising a ceiling silently is the one forbidden move.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "doc_pointer_baseline.json")

# Fallbacks only. The live ceilings live in doc_pointer_baseline.json so that a raise
# must be written down, dated and reasoned -- the same door tests/fossil_baseline.json
# uses. A constant in source can be edited in a diff nobody reads.
CEILING = 44
BROKEN_CEILING = 0


def load_ceilings() -> tuple[int, int]:
    if not os.path.exists(BASELINE):
        return CEILING, BROKEN_CEILING
    with open(BASELINE, encoding="utf-8") as fh:
        doc = json.load(fh)
    return int(doc.get("ceiling", CEILING)), int(doc.get("broken_ceiling", BROKEN_CEILING))


def rebaseline(total: int, dead_total: int, reason: str) -> int:
    """The ONLY door a ceiling may move through, in either direction.

    Lowering is always allowed and needs no argument. RAISING is legitimate exactly once
    per deliberate scope widening -- adding .claude/agents/ to the scan genuinely finds
    more, and that is not the same act as snoozing a failure. It must be written down.
    """
    import datetime
    doc = {}
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as fh:
            doc = json.load(fh)
    old_c = int(doc.get("ceiling", CEILING))
    old_b = int(doc.get("broken_ceiling", BROKEN_CEILING))
    if (total > old_c or dead_total > old_b) and len(reason.strip()) < 12:
        print("REFUSED: raising a ceiling requires --reason=\"<why the scope widened>\"")
        return 1
    doc["_comment"] = (
        "THE POINTER LAW ceilings. Both ONLY SHRINK in normal operation. A RAISE is legal "
        "only for a deliberate scope widening and only through --grandfather --reason=, "
        "which records dated provenance below. Silently raising a ceiling is the one "
        "forbidden move (ADR-023)."
    )
    doc["ceiling"] = total
    doc["broken_ceiling"] = dead_total
    doc.setdefault("grandfather_log", []).append({
        "date": datetime.date.today().isoformat(),
        "reason": reason,
        "ceiling": [old_c, total],
        "broken_ceiling": [old_b, dead_total],
    })
    with open(BASELINE, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent="\t")
        fh.write("\n")
    print("ceilings rebaselined: unpointered %d -> %d, broken %d -> %d"
          % (old_c, total, old_b, dead_total))
    return 0

SCAN_DIRS = ["production", ".claude/agents", "."]

# war_room/ is dated deliberation history, not law (ADR-014). Research and archives likewise
# describe a moment. The law binds docs that read as CURRENT STATE.
#
# .claude/agents/ is scanned DELIBERATELY: an agent charter has more reach than CLAUDE.md
# (it is injected into every call of that agent), and one of them enforced a retired
# damage grammar for weeks precisely because no probe could see it.
SKIP_PARTS = (".git", ".godot", "node_modules", "addons",
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


# A pointer that names a file AND a line: `scripts/foo.gd:123`, `ADR-003.md:2`.
FILE_LINE = re.compile(r"\b([\w./-]+\.(?:gd|tscn|tres|py|json|cfg|md|gdshader|ps1)):(\d{1,5})\b")

# A section pointer: `DESIGN.md §4.2`, `GAME_GUIDE.md §6`.
SECTION = re.compile(r"\b([\w.-]+\.md)\s*§\s*([\d.]+)")


def _resolve_file(name: str) -> str | None:
    """Repo-absolute path for a doc's file reference, or None if it names nothing.

    Docs cite paths at every depth (`ally_base.gd:9`, `scripts/allies/ally_base.gd:9`),
    so a bare basename is matched against the tree by name.
    """
    direct = os.path.join(ROOT, name.replace("/", os.sep))
    if os.path.isfile(direct):
        return direct
    base = os.path.basename(name)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames
                       if d not in (".git", ".godot", "node_modules", "addons", "__pycache__")]
        if base in filenames:
            return os.path.join(dirpath, base)
    return None


_FILE_CACHE: dict[str, str | None] = {}


def _lookup(name: str) -> str | None:
    if name not in _FILE_CACHE:
        _FILE_CACHE[name] = _resolve_file(name)
    return _FILE_CACHE[name]


def broken_pointers(path: str) -> list[tuple[int, str]]:
    """Pointers whose target does not exist. This is the RESOLVING half of the law.

    Deliberately narrow: only a pointer that is unambiguously checkable is judged.
    A missing file and a line past end-of-file are facts; anything softer is left alone,
    because a false positive here would train people to ignore the probe.
    """
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return []

    bad: list[tuple[int, str]] = []
    fenced = False
    for i, raw in enumerate(lines, 1):
        line = raw.strip()
        if line.startswith("```"):
            fenced = not fenced
            continue
        if fenced or not line:
            continue

        for name, lineno in FILE_LINE.findall(line):
            target = _lookup(name)
            if target is None:
                bad.append((i, "names %s:%s - that file does not exist" % (name, lineno)))
                continue
            try:
                with open(target, encoding="utf-8", errors="replace") as fh:
                    n = sum(1 for _ in fh)
            except OSError:
                continue
            if int(lineno) > n:
                bad.append((i, "cites %s:%s but that file has %d lines"
                            % (name, lineno, n)))

        for name, sect in SECTION.findall(line):
            target = _lookup(name)
            if target is None:
                bad.append((i, "names section %s §%s - that file does not exist"
                            % (name, sect)))
                continue
            try:
                with open(target, encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
            except OSError:
                continue
            head = sect.split(".")[0]
            if not re.search(r"^#{1,6}\s*\**\s*%s[.\s]" % re.escape(head), text, re.M):
                bad.append((i, "cites %s §%s but that document has no section %s"
                            % (name, sect, head)))
    return bad


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
    ceiling, broken_ceiling = load_ceilings()
    offenders: dict[str, list[tuple[int, str]]] = {}
    broken: dict[str, list[tuple[int, str]]] = {}

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
                dead = broken_pointers(full)
                if dead:
                    broken[key] = dead

    total = sum(len(v) for v in offenders.values())
    print(f"POINTER LAW: {total} unpointered assertion(s) across {len(offenders)} doc(s). "
          f"Ceiling {ceiling}.")
    print("Each names code but cites no file:line, no probe, and no date covering it.\n")
    for key in sorted(offenders, key=lambda k: -len(offenders[k])):
        hits = offenders[key]
        print(f"  {key}  ({len(hits)})")
        for ln, text in (hits if show_all else hits[:3]):
            print(f"    :{ln}  {text}")
        if not show_all and len(hits) > 3:
            print(f"    ... {len(hits) - 3} more (--list)")

    dead_total = sum(len(v) for v in broken.values())
    print(f"\nBROKEN POINTERS: {dead_total} pointer(s) that resolve to nothing "
          f"across {len(broken)} doc(s). Ceiling {broken_ceiling}.")
    print("A pointer to a file or section that does not exist reads as verified truth.\n")
    for key in sorted(broken, key=lambda k: -len(broken[k])):
        hits = broken[key]
        print(f"  {key}  ({len(hits)})")
        for ln, text in (hits if show_all else hits[:3]):
            print(f"    :{ln}  {text}")
        if not show_all and len(hits) > 3:
            print(f"    ... {len(hits) - 3} more (--list)")

    if "--grandfather" in sys.argv:
        reason = ""
        for a in sys.argv:
            if a.startswith("--reason="):
                reason = a[len("--reason="):]
        return rebaseline(total, dead_total, reason)

    failed = False
    if total > ceiling:
        print(f"\nFAIL: {total} unpointered exceeds ceiling {ceiling}. "
              f"Cite a pointer or date the claim.")
        failed = True
    elif total < ceiling:
        print(f"\nPASS - unpointered {ceiling - total} under ceiling. "
              f"Lower ceiling to {total} in this file to bank the ground.")
    else:
        print("\nPASS at unpointered ceiling.")

    if dead_total > broken_ceiling:
        print(f"FAIL: {dead_total} broken pointer(s) exceeds ceiling {broken_ceiling}. "
              f"Repoint it or delete the claim.")
        failed = True
    elif dead_total < broken_ceiling:
        print(f"PASS - broken {broken_ceiling - dead_total} under ceiling. "
              f"Lower broken_ceiling to {dead_total} to bank the ground.")

    if failed:
        print("Do NOT raise a ceiling - they ratchet down only.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
