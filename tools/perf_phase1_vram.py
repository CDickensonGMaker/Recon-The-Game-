"""Phase 1 of the 2026-09-08 perf plan: flip the shipped 3D texture set between
Lossless (compress/mode=0) and VRAM compressed (mode=2), both directions, from one
explicit manifest.

Git alone cannot revert this: 32 of the 241 .import files live under an ignored
path (terrain/vegetation/textures), so a `git revert` would leave them compressed
and the A/B would be measuring a mixture. The manifest is the authority.

    python tools/perf_phase1_vram.py            # dry run, prints the current state
    python tools/perf_phase1_vram.py --apply    # -> VRAM compressed
    python tools/perf_phase1_vram.py --revert   # -> Lossless

Then ALWAYS: godot --headless --path . --import
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "perf_phase1_set.txt")
# Foliage and terrain go to BPTC/BC7: identical 8 bpp to DXT5, far better on the
# alpha edges of the canopy cards, which is the named look risk of this change.
HQ_MARKERS = ("/vegetation/", "terrain/")


def main() -> int:
    apply_ = "--apply" in sys.argv
    revert = "--revert" in sys.argv
    if apply_ and revert:
        print("pick one of --apply / --revert")
        return 2
    if not (apply_ or revert):
        counts = {}
        for rel in io.open(MANIFEST, encoding="utf-8").read().splitlines():
            rel = rel.strip()
            if not rel:
                continue
            p = os.path.join(ROOT, rel + ".import")
            if not os.path.exists(p):
                counts["MISSING"] = counts.get("MISSING", 0) + 1
                continue
            t = io.open(p, encoding="utf-8").read()
            for line in t.splitlines():
                if line.startswith("compress/mode="):
                    counts[line] = counts.get(line, 0) + 1
        for k in sorted(counts):
            print("%5d  %s" % (counts[k], k))
        print("(0 = Lossless, 2 = VRAM compressed. Pass --apply or --revert to change.)")
        return 0
    mode_to = "2" if apply_ else "0"
    changed = 0
    already = 0
    missing = 0
    for rel in io.open(MANIFEST, encoding="utf-8").read().splitlines():
        rel = rel.strip()
        if not rel:
            continue
        p = os.path.join(ROOT, rel + ".import")
        if not os.path.exists(p):
            missing += 1
            print("MISSING", rel)
            continue
        t = io.open(p, encoding="utf-8").read()
        hq = "true" if (apply_ and any(m in rel for m in HQ_MARKERS)) else "false"
        n = t
        for m in ("0", "2"):
            n = n.replace("compress/mode=" + m, "compress/mode=" + mode_to)
        for h in ("true", "false"):
            n = n.replace("compress/high_quality=" + h, "compress/high_quality=" + hq)
        if n == t:
            already += 1
            continue
        if apply_ or revert:
            io.open(p, "w", encoding="utf-8", newline="\n").write(n)
        changed += 1
    verb = "would change" if not (apply_ or revert) else "changed"
    print("%s %d of %d import files (%d already in target state, %d missing)"
          % (verb, changed, changed + already + missing, already, missing))
    if apply_ or revert:
        print("NOW RUN: godot --headless --path . --import")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
