"""RETIRED-REF PROBE (companion to THE POINTER LAW probe).

probe_doc_pointers.py is content-agnostic: it checks the SHAPE of an assertion, never
its truth. This one is the opposite - a curated DENYLIST of things the project has
RETIRED, VOIDED or DELETED. It fails when a doc cites one as CURRENT: present-tense,
undated, unhedged, and not framed as historical. That is the exact drift that made two
architects "verify" a canon violation that did not exist (CLAUDE.md, NO MORE DRIFT).

It reuses probe_doc_pointers' scan set, skip rules and date logic verbatim (imported, not
copied) so the two probes can never disagree on what counts as a dated/hedged line.

    python tools/probe_retired_refs.py            # gate: exit 1 above ceiling
    python tools/probe_retired_refs.py --list     # every offending line
    python tools/probe_retired_refs.py --grandfather --reason="<why the scope widened>"

The ceiling lives in tools/retired_refs_baseline.json and ratchets DOWN only, through the
same --grandfather --reason= door the other baselines use. Raising it silently is the one
forbidden move (ADR-023).
"""

import datetime
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from probe_doc_pointers import (  # noqa: E402
    DATE, HEDGE, SCAN_DIRS, SKIP_PARTS, is_banner_dated, near_dated,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "retired_refs_baseline.json")
CEILING = 0

# (token pattern that is RETIRED, the correction to print when it is cited as live).
DENYLIST = [
    (re.compile(r"\bADR-025\b"),
     "ADR-025 is SUPERSEDED 2026-07-20 - do not cite its tier bands as the live spec"),
    (re.compile(r"\bADR-024\b"),
     "ADR-024 is voided - confirm status in production/adr/README.md before citing it live"),
    (re.compile(r"\bADR-027\b"),
     "ADR-027 is voided - confirm status in production/adr/README.md before citing it live"),
    (re.compile(r"25[-–]192"),
     "the 25-192ms AI wall is RETIRED (war_room/2026-07-18_ai_consolidation_plan/synthesis.md:21)"),
    (re.compile(r"\bduty[_ ]cycle\b", re.I),
     "duty_cycle was proposed, never built (zero code hits) - do not describe it as a live feature"),
    (re.compile(r"\b19[-–]chunk\b"),
     "the firebase is a monolithic fsb_main.glb + 16 markers (site_planner.gd:492-500), not a 19-chunk kit"),
    (re.compile(r"\bWorldBuilder\b"),
     "no WorldBuilder class exists - the path is MissionGenerator.build_patrol_world() (mission_generator.gd:619)"),
    (re.compile(r"\bSTATE_OF_PROJECT\b|\bMISSION_DESIGN_RESEARCH\b|\bRECON_ADAPTATION\b"),
     "that doc was DELETED ON PURPOSE 2026-07-23 (CLAUDE.md) - do not cite it as a live pointer"),
]

# Framing that marks a mention as historical/retired rather than a live assertion. A line
# that names a retired token AND carries one of these is describing its death, not asserting it.
EXCULPATORY = re.compile(
    r"\b(?:supersed\w*|void\w*|retired?|deleted?|remove\w*|former\w*|obsolete|stale|"
    r"no longer|no such|used to|was |were |does not exist|doesn'?t exist|never built|never "
    r"existed|ghost|zero hits?|instead of|not a |replaced|dead)\b",
    re.I)


def load_ceiling() -> int:
    if not os.path.exists(BASELINE):
        return CEILING
    with open(BASELINE, encoding="utf-8") as fh:
        return int(json.load(fh).get("ceiling", CEILING))


def rebaseline(total: int, reason: str) -> int:
    doc = {}
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as fh:
            doc = json.load(fh)
    old_c = int(doc.get("ceiling", CEILING))
    if total > old_c and len(reason.strip()) < 12:
        print("REFUSED: raising the ceiling requires --reason=\"<why the scope widened>\"")
        return 1
    doc["_comment"] = (
        "RETIRED-REF ceiling. ONLY SHRINKS in normal operation. A raise is legal only for a "
        "deliberate scope widening and only through --grandfather --reason=, which records "
        "dated provenance below. Silently raising it is the one forbidden move (ADR-023)."
    )
    doc["ceiling"] = total
    doc.setdefault("grandfather_log", []).append({
        "date": datetime.date.today().isoformat(),
        "reason": reason,
        "ceiling": [old_c, total],
    })
    with open(BASELINE, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent="\t")
        fh.write("\n")
    print("ceiling rebaselined: %d -> %d" % (old_c, total))
    return 0


def scan(path: str) -> list:
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return []
    if is_banner_dated(lines):
        return []

    bad = []
    fenced = False
    for i, raw in enumerate(lines, 1):
        line = raw.strip()
        if line.startswith("```"):
            fenced = not fenced
            continue
        if fenced or not line:
            continue
        if DATE.search(line) or HEDGE.search(line) or EXCULPATORY.search(line):
            continue
        if near_dated(lines, i - 1):
            continue
        for pat, correction in DENYLIST:
            if pat.search(line):
                bad.append((i, "%s  ->  %s" % (line[:88], correction)))
                break
    return bad


def _self_test_ok() -> bool:
    """Negative control: a live citation MUST flag; a dated/exculpated one MUST NOT."""
    live = "tier bands are specified in ADR-025 as the live spec"
    dated = "ADR-025 is SUPERSEDED 2026-07-20"
    live_flags = (any(p.search(live) for p, _ in DENYLIST)
                  and not (DATE.search(live) or HEDGE.search(live) or EXCULPATORY.search(live)))
    dated_clears = EXCULPATORY.search(dated) is not None
    return live_flags and dated_clears


def main() -> int:
    show_all = "--list" in sys.argv
    ceiling = load_ceiling()
    offenders = {}

    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        for dirpath, dirnames, filenames in os.walk(base):
            rel = os.path.relpath(dirpath, ROOT).replace("\\", "/")
            if any(p in rel for p in SKIP_PARTS):
                dirnames[:] = []
                continue
            if d == "." and rel != ".":
                continue
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
    print(f"RETIRED-REF PROBE: {total} live citation(s) of a retired/voided/deleted thing "
          f"across {len(offenders)} doc(s). Ceiling {ceiling}.\n")
    for key in sorted(offenders, key=lambda k: -len(offenders[k])):
        hits = offenders[key]
        print(f"  {key}  ({len(hits)})")
        for ln, text in (hits if show_all else hits[:3]):
            print(f"    :{ln}  {text}")
        if not show_all and len(hits) > 3:
            print(f"    ... {len(hits) - 3} more (--list)")

    if not _self_test_ok():
        print("\nFAIL: self-test broken - the probe cannot tell a live citation from a dated one.")
        return 1

    if "--grandfather" in sys.argv:
        reason = ""
        for a in sys.argv:
            if a.startswith("--reason="):
                reason = a[len("--reason="):]
        return rebaseline(total, reason)

    if total > ceiling:
        print(f"\nFAIL: {total} exceeds ceiling {ceiling}. Fix the citation, or date/hedge it. "
              f"Do NOT raise the ceiling - it ratchets down only.")
        return 1
    if total < ceiling:
        print(f"\nPASS - {ceiling - total} under ceiling. Lower ceiling to {total} to bank it.")
        return 0
    print("\nPASS at ceiling.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
