"""THE FOSSIL LAW, pointed at files instead of symbols (ADR-023).

A `.uid` is Godot's IDENTITY RECORD for a script. When the script is deleted and the
`.uid` is committed anyway, the repo keeps a name for a thing that no longer exists --
and a scene holding a stale `uid://` resolves through the tombstone instead of failing
loudly. That is the file-level version of "a lie in the map".

    python tools/probe_orphan_files.py            # gate: exit 1 above CEILING
    python tools/probe_orphan_files.py --list     # every orphan, with its evidence
    python tools/probe_orphan_files.py --write-baseline
    python tools/probe_orphan_files.py --grandfather --reason="<why>"

CEILING ratchets DOWN only, exactly like tests/fossil_baseline.json. Raising it by hand
is the one forbidden move; --grandfather is the only door in and it demands a reason.

WHY A REFERENCE CHECK GATES EVERY DELETION. Deleting a `.uid` that something still
resolves through breaks a scene silently. So an orphan is only reported deletable when
NEITHER its uid string NOR its source path appears anywhere live.

WHY THE UID CHECK ALONE IS WORTHLESS -- measured 2026-07-19, and it is the trap this
probe exists to avoid. scripts/player/player.gd is unambiguously live, and its uid has
ZERO hits repo-wide: this project references scripts by res:// path, not by uid. A
uid-only probe reports "0 dangling references" against a tree where every reference is
broken. Both checks ship, or neither means anything.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "orphan_baseline.json")

BASELINE_COMMENT = (
    "ADR-023 THE FOSSIL LAW, file level. Orphaned .uid/.import sidecars whose source is "
    "gone, keyed by repo-relative path. THIS LIST ONLY SHRINKS. 'count' and 'ceiling' are "
    "the ratchet's witnesses: the probe FAILS if either disagrees with 'orphans', so a "
    "hand-edit cannot pass quietly. --write-baseline can only ever remove entries. New "
    "entries enter ONLY via --grandfather --reason=<text>."
)

SKIP_DIRS = (".git", ".godot", ".beads", "addons", "node_modules", "__pycache__")

# Sidecars Godot writes BESIDE a source file. Orphaned = the source is gone.
SIDECARS = (".uid", ".import")

# Files whose text can hold a live reference. `.beads/` and `production/` are history
# by design and must NOT keep a corpse alive -- but tools/ must be searched, because a
# stale pointer in a probe is exactly the kind of live wrongness this law targets.
REF_EXTS = (".tscn", ".tres", ".gd", ".gdshader", ".godot", ".cfg", ".import", ".py", ".ps1")
REF_SKIP_DIRS = SKIP_DIRS + ("production", "war_room")

UID_RE = re.compile(r"uid://[a-z0-9]+")


def _walk(base, skip):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fn in filenames:
            yield os.path.join(dirpath, fn)


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def find_orphans():
    """Every sidecar whose source file is missing.

    Walks the FILESYSTEM, never `git ls-files`. terrain/.gitignore:8 ignores `*.import`
    for the whole vendored terrain addon, so 71 .import files are invisible to git --
    including the 21 orphans under terrain/textures/billboards/.
    """
    out = []
    for path in _walk(ROOT, SKIP_DIRS):
        for ext in SIDECARS:
            if not path.endswith(ext):
                continue
            if not os.path.exists(path[: -len(ext)]):
                out.append(rel(path))
    return sorted(out)


def build_ref_index():
    """Every reference-bearing line in the live tree, as one searchable blob."""
    blob = []
    for path in _walk(ROOT, REF_SKIP_DIRS):
        if not path.lower().endswith(REF_EXTS):
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                blob.append((rel(path), fh.read()))
        except OSError:
            continue
    return blob


def referenced_by(orphan, blob):
    """Live files still naming this orphan, by uid string OR by source path.

    Returns [] when nothing points at it -- only then is deletion provably safe.
    """
    src = orphan
    for ext in SIDECARS:
        if src.endswith(ext):
            src = src[: -len(ext)]
            break

    uids = set()
    full = os.path.join(ROOT, orphan)
    if orphan.endswith(".uid") and os.path.exists(full):
        try:
            with open(full, encoding="utf-8", errors="replace") as fh:
                uids.update(UID_RE.findall(fh.read()))
        except OSError:
            pass

    needles = {src, "res://" + src} | uids
    hits = []
    for name, text in blob:
        if name == orphan or name == src:
            continue
        for needle in needles:
            if needle in text:
                hits.append("%s -> %s" % (name, needle))
                break
    return hits


# ---- baseline ---------------------------------------------------------------

def load_baseline():
    if not os.path.exists(BASELINE):
        return {}
    with open(BASELINE, encoding="utf-8") as fh:
        return json.load(fh)


def audit(doc, known):
    """`count` and `ceiling` are redundant on purpose: they witness a hand-edit."""
    fails = []
    if not doc:
        return fails
    if doc.get("count") != len(known):
        fails.append("REGISTER TAMPERED: count=%s but orphans=%d"
                     % (doc.get("count"), len(known)))
    if "ceiling" not in doc:
        fails.append("baseline has no 'ceiling' - the ratchet cannot hold")
    elif len(known) > doc["ceiling"]:
        fails.append("REGISTER GREW: %d > ceiling %d; this register only shrinks"
                     % (len(known), doc["ceiling"]))
    return fails


def save(doc):
    with open(BASELINE, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent="\t", sort_keys=False)
        fh.write("\n")


def write_baseline(orphans):
    """Can only ever REMOVE. Growth is impossible through this door."""
    doc = load_baseline()
    kept = [o for o in doc.get("orphans", []) if o in orphans]
    doc["_comment"] = BASELINE_COMMENT
    doc["orphans"] = kept
    doc["count"] = len(kept)
    doc["ceiling"] = min(doc.get("ceiling", len(kept)), len(kept))
    doc.setdefault("grandfather_log", [])
    save(doc)
    print("baseline written: %d orphans, ceiling %d" % (len(kept), doc["ceiling"]))


def grandfather(orphans, reason):
    import datetime
    doc = load_baseline()
    known = list(doc.get("orphans", []))
    added = [o for o in orphans if o not in known]
    known = sorted(set(known) | set(orphans))
    doc["_comment"] = BASELINE_COMMENT
    doc["orphans"] = known
    doc["count"] = len(known)
    doc["ceiling"] = len(known)
    doc.setdefault("grandfather_log", []).append({
        "date": datetime.date.today().isoformat(),
        "reason": reason,
        "added": added,
    })
    save(doc)
    print("grandfathered %d, ceiling %d, reason: %s" % (len(added), len(known), reason))


# ---- main -------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    orphans = find_orphans()

    if "--write-baseline" in args:
        write_baseline(orphans)
        return 0
    if "--grandfather" in args:
        reason = ""
        for a in args:
            if a.startswith("--reason="):
                reason = a[len("--reason="):]
        if len(reason.strip()) < 12:
            print("--grandfather requires --reason=\"<why these orphans stand>\"")
            return 1
        grandfather(orphans, reason)
        return 0

    doc = load_baseline()
    known = list(doc.get("orphans", []))
    fails = audit(doc, known)

    blob = build_ref_index()
    new = [o for o in orphans if o not in known]
    healed = [o for o in known if o not in orphans]

    print("ORPHAN SIDECARS: %d found, %d grandfathered, ceiling %s."
          % (len(orphans), len(known), doc.get("ceiling", "<none>")))
    print("A .uid whose script is gone is a name for a thing that does not exist.\n")

    show = orphans if "--list" in args else new
    load_bearing = 0
    for o in sorted(show):
        refs = referenced_by(o, blob)
        tag = "NEW " if o in new else "    "
        if refs:
            load_bearing += 1
            print("  %sLOAD-BEARING  %s" % (tag, o))
            for r in refs[:4]:
                print("        still referenced by %s" % r)
        else:
            print("  %sdelete-safe   %s" % (tag, o))

    if healed:
        print("\n%d register entr(ies) are gone - run --write-baseline to bank it:"
              % len(healed))
        for h in healed:
            print("    %s" % h)

    if load_bearing:
        print("\n%d orphan(s) are STILL REFERENCED. Fix the reference; do not delete "
              "the sidecar out from under it." % load_bearing)

    for f in fails:
        print("\nFAIL: %s" % f)
    if new:
        print("\nFAIL: %d NEW orphan sidecar(s). Delete the sidecar with its source, "
              "or --grandfather with a reason." % len(new))
    if fails or new:
        print("Do NOT raise the ceiling by hand - it ratchets down only.")
        return 1
    print("\nPASS - no new orphans.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
