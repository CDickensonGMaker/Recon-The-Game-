"""wiring_audit.py - which systems EXIST but are not in the game.

The fossil probe (tests/test_fossils.gd) answers a symbol-level question: is this
declaration ever read? That catches a dead function inside a live system. It does
NOT catch a whole system that is never reached at all, because every symbol in it
references the others and the module looks internally busy.

This tool answers the level-up question the Summoner asked for: what is built and
not wired in? It classifies every script by how production reaches it.

    LIVE            reachable from an autoload or a scene the game actually loads
    TEST-ONLY       nothing but tests/ references it - the classic false alibi
    ORPHAN          nothing anywhere references it
    TOOL/EDITOR     @tool scripts and tools/ - reached by the editor, not the game

TEST-ONLY and ORPHAN are the answer to "what still needs to be wired up".

This is a REPORT, not a gate. It does not fail a build and it holds no baseline;
judgment about whether a system should be wired or deleted stays with a human.

    python tools/wiring_audit.py            # summary + the unwired list
    python tools/wiring_audit.py --verbose  # every script with its verdict
"""
from __future__ import annotations

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCAN_DIRS = ["scripts", "terrain"]
REF_DIRS = ["scripts", "terrain", "scenes", "data", "tests", "tools"]
REF_EXTS = {".gd", ".tscn", ".tres", ".cfg", ".json"}

# A reference that only appears in one of these is not production reachability.
TEST_DIRS = ("tests",)
TOOL_DIRS = ("tools",)


def read(path: str) -> str:
    try:
        with io.open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def walk(dirs: list[str], exts: set[str] | None = None) -> list[str]:
    out: list[str] = []
    for d in dirs:
        base = os.path.join(ROOT, d)
        for cur, _sub, files in os.walk(base):
            for f in files:
                if exts is None or os.path.splitext(f)[1] in exts:
                    out.append(os.path.join(cur, f))
    return out


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace("\\", "/")


def autoload_scripts() -> set[str]:
    """Autoloads are reachable by definition - they are the roots of the graph."""
    out: set[str] = set()
    text = read(os.path.join(ROOT, "project.godot"))
    for m in re.finditer(r'^\s*\w+\s*=\s*"\*?res://([^"]+)"', text, re.M):
        out.add(m.group(1))
    return out


def class_name_of(text: str) -> str:
    m = re.search(r"^class_name\s+(\w+)", text, re.M)
    return m.group(1) if m else ""


def main() -> int:
    verbose = "--verbose" in sys.argv

    scripts = [p for p in walk(SCAN_DIRS, {".gd"})]
    ref_files = walk(REF_DIRS, REF_EXTS)

    autoloads = autoload_scripts()

    # Index every reference file's text once.
    corpus: list[tuple[str, str]] = [(rel(p), read(p)) for p in ref_files]

    verdicts: dict[str, str] = {}
    detail: dict[str, list[str]] = {}

    for sp in scripts:
        srel = rel(sp)
        text = read(sp)
        cname = class_name_of(text)
        base = os.path.basename(srel)

        if srel in autoloads:
            verdicts[srel] = "LIVE"
            detail[srel] = ["autoload"]
            continue

        if text.lstrip().startswith("@tool") or srel.startswith("tools/"):
            verdicts[srel] = "TOOL/EDITOR"
            detail[srel] = []
            continue

        # Who names this script? By path, by class_name, or by uid-less filename.
        hits: list[str] = []
        for orel, otext in corpus:
            if orel == srel:
                continue
            named = base in otext or srel in otext
            if not named and cname:
                # Word-boundary match so `Convoy` does not match `ConvoySpawner`.
                named = re.search(r"\b%s\b" % re.escape(cname), otext) is not None
            if named:
                hits.append(orel)

        detail[srel] = hits
        if not hits:
            verdicts[srel] = "ORPHAN"
        elif all(h.startswith(TEST_DIRS) or h.startswith(TOOL_DIRS) for h in hits):
            verdicts[srel] = "TEST-ONLY"
        else:
            verdicts[srel] = "LIVE"

    counts: dict[str, int] = {}
    for v in verdicts.values():
        counts[v] = counts.get(v, 0) + 1

    print("=== WIRING AUDIT: what exists but is not in the game ===")
    print("scanned %d scripts under %s" % (len(scripts), ", ".join(SCAN_DIRS)))
    for k in ("LIVE", "TEST-ONLY", "ORPHAN", "TOOL/EDITOR"):
        print("  %-12s %d" % (k, counts.get(k, 0)))
    print("")

    unwired = sorted(k for k, v in verdicts.items() if v in ("TEST-ONLY", "ORPHAN"))
    if not unwired:
        print("Nothing unwired. Every system under scan is reached by production.")
    else:
        print("--- NOT REACHED BY PRODUCTION (%d) ---" % len(unwired))
        for k in unwired:
            why = verdicts[k]
            if why == "TEST-ONLY":
                who = ", ".join(detail[k][:3])
                print("  TEST-ONLY  %s" % k)
                print("             kept alive only by: %s" % who)
            else:
                print("  ORPHAN     %s" % k)
        print("")
        print("TEST-ONLY is the dangerous class: the symbol looks alive to the")
        print("fossil probe because a test references it, but the game never")
        print("reaches it. Decide per system: wire it, or delete it.")

    if verbose:
        print("")
        print("--- ALL VERDICTS ---")
        for k in sorted(verdicts):
            print("  %-12s %s" % (verdicts[k], k))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
