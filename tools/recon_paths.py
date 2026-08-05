"""THE PATH CONTRACT — the single place any Blender tool learns where a file lives.

No tool may hardcode an absolute path. Import from here instead:

    from recon_paths import US_BASE_V3, GEAR_ARMORY, out_glb

Tools are run by Blender as `blender -b <file> -P tools/<tool>.py`, so `tools/`
is not automatically importable. Every tool that imports this module must first
add this directory to sys.path:

    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from recon_paths import ...

ROOT is derived from this file's own location, never typed out. Move the repo
and every tool follows.

VERIFY: `python tools/recon_paths.py`  (plain Python — does NOT need Blender)
Exit 0 = every LIVE path resolves. Exit 1 = something moved; the report names it.
This is the loud failure that replaces 22 silent ones.

DEAD entries are recorded, not deleted. A tool asking for a dead source gets an
explanation of what happened to it instead of a confusing file-not-found.
"""

import glob
import json
import os
import re
import sys

# --------------------------------------------------------------------------
# ROOT — derived, never hardcoded.  tools/recon_paths.py -> repo root
# --------------------------------------------------------------------------
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _p(*parts):
    return os.path.join(ROOT, *parts)


ASSETS = _p("assets")
TOOLS = _p("tools")

# --------------------------------------------------------------------------
# LIVE SOURCES — authoring .blend files that exist today (verified 2026-07-19)
# --------------------------------------------------------------------------

# US characters
US_BASE_V3 = _p("assets", "us", "characters", "us_base_v3.blend")
US_CHARACTERS_DIR = _p("assets", "us", "characters")
US_SOLDIER_LINEUP = _p("assets", "us", "characters", "us_v3_soldier_lineup.blend")
US_HEAD_PARTS = _p("assets", "us", "characters", "grunt_head_parts.blend")
US_HELMET_VARIANTS = _p("assets", "us", "characters", "helmet_variants.blend")
US_PILOT_WHITE = _p("assets", "us", "characters", "us_pilot_white.blend")
US_PILOT_BLACK = _p("assets", "us", "characters", "us_pilot_black.blend")

# THE ARMORY.  assets/us/props/ is the TRUTH copy (carries the radio sync).
# assets/us/characters/gear_armory.blend is a STALE duplicate — never write it.
GEAR_ARMORY = _p("assets", "us", "props", "gear_armory.blend")
GEAR_ARMORY_STALE = _p("assets", "us", "characters", "gear_armory.blend")

# Weapons (authoring)
WEAPONS_US = _p("assets", "us", "characters", "weapons_us.blend")
WEAPONS_V1 = _p("assets", "us", "characters", "weapons_v1.blend")

# VC / NVA
VC_GUERILLA_V2 = _p("assets", "nva_vc", "characters", "vc_guerilla_v2.blend")
VC_CHARACTERS_DIR = _p("assets", "nva_vc", "characters")
# Build OUTPUT of build_weapons_vc.py (see OUTPUTS below).
WEAPONS_VC_OUT = _p("assets", "nva_vc", "weapons_vc.blend")

# Civilians
CIV_DIR = _p("assets", "civilians", "characters")
CIV_ANIM_WORKBENCH = _p("assets", "civilians", "characters", "civ_anim_workbench.blend")
CIV_PROPS = _p("assets", "civilians", "props", "civilian_props.blend")
VILLAGE_PROPS = _p("assets", "civilians", "props", "village_props.blend")

# Zombies (VC Zombies mode). Own faction folder, own workspace - a change to the
# undead can never reach into the fireteam or the village.
ZOMBIE_DIR = _p("assets", "zombies", "characters")
ZOMBIE_FACE_ATLAS = _p("assets", "zombies", "characters", "zombie_face_atlas_v1.png")

# Shared rig + animation
ANIM_LIBRARY_BLEND = _p("assets", "shared", "anim_library.blend")
ANIM_LIBRARY_GLB = _p("assets", "shared", "anim_library.glb")
BASE_HUMAN_RIGGED = _p("assets", "shared", "rigs", "base_human_rigged.blend")

# Player / first-person
ARMS_RIG = _p("assets", "player", "arms", "arms_rig.blend")
FP_ARMS_RIFLE = _p("assets", "player", "arms", "fp_arms_rifle.blend")
SEMI_AUTO_RIFLE_ARMS = _p("assets", "player", "arms", "semi_auto_rifle_arms.blend")
VIEWMODELS_DIR = _p("assets", "player", "viewmodels")

# Reference / review staging
REVIEW_DIR = _p("assets", "reference", "review")
LINEUP_REVIEW = _p("assets", "reference", "review", "lineup_review.blend")
CIVILIANS_LINEUP = _p("assets", "reference", "review", "civilians_all_lined_up.blend")
SPRITE_STAGE = _p("assets", "reference", "review", "sprite_stage.blend")

# World / structures
RUINS_BATCH1 = _p("assets", "world", "structures", "ruins_batch1.blend")
EMPLACEMENTS_BATCH2 = _p("assets", "world", "structures", "emplacements_batch2.blend")
STRUCTURES_DIR = _p("assets", "building models", "structures")

# Output dirs
US_PROPS_DIR = _p("assets", "us", "props")
HELMETS_OUT_DIR = _p("assets", "us", "props", "helmets")
VEGETATION_DIR = _p("assets", "world", "vegetation")
VEGETATION_RES = "res://assets/world/vegetation"
POSES_DIR = _p("art_source", "characters", "poses")

# Directories a tool may create on demand (absence is not a contract failure).
# Exporter scratch. Was art_source/characters/variants/ — that tree is a husk,
# so scratch no longer lives inside the rotten tree.
VARIANTS_SCRATCH = _p("_scratch", "variants")

# OUTPUTS — things tools WRITE. Absence is normal (not yet built), so verify()
# skips them. Only SOURCES are contract-checked; a missing source is a real fault.
OUTPUTS = {
    "HELMETS_OUT_DIR": HELMETS_OUT_DIR,
    "VIEWMODELS_DIR": VIEWMODELS_DIR,
    "VARIANTS_SCRATCH": VARIANTS_SCRATCH,
    "WEAPONS_VC_OUT": WEAPONS_VC_OUT,
    "ANIM_LIBRARY_GLB": ANIM_LIBRARY_GLB,
    "POSES_DIR": POSES_DIR,
}
CREATABLE_DIRS = OUTPUTS

# --------------------------------------------------------------------------
# DEAD SOURCES — recorded so a tool fails with an explanation, not a mystery.
# The art_source/ tree was gutted; only art_source/characters/poses/ survives.
# --------------------------------------------------------------------------
DEAD = {
    "gear_library.blend": (
        "art_source/characters/locker/gear_library.blend — GONE, no copy anywhere. "
        "Superseded by GEAR_ARMORY (assets/us/props/gear_armory.blend)."
    ),
    "us_grunt_v2.blend": (
        "art_source/characters/base_psx/us_grunt_v2.blend — GONE. "
        "Superseded by US_BASE_V3; it is the truth source for all US models."
    ),
    "weapons_vc.blend": (
        "art_source/characters/blends/weapons_vc.blend — GONE, no copy anywhere. "
        "No successor. VC weapons now live inside VC_GUERILLA_V2."
    ),
    "us_rto.blend": (
        "art_source/characters/us_troops/us_rto.blend — GONE, no copy anywhere. "
        "No successor authoring file; the RTO ships from US_BASE_V3 + GEAR_ARMORY."
    ),
    "satchel_medic.blend": (
        "art_source/characters/locker/satchel_medic.blend — GONE, no copy anywhere."
    ),
    "unit_us_pilot.blend": (
        "art_source pilot units — GONE. Successors: US_PILOT_WHITE / US_PILOT_BLACK."
    ),
    "variants/": (
        "art_source/characters/variants/ — GONE. Was an exporter scratch dir; "
        "recreate under a tool-local temp dir if an exporter still needs one."
    ),
    "sprite_frames/": (
        "art_source/characters/sprite_frames/ — GONE (~600 rendered frames). "
        "Sprite matrix killed by ADR-001; tooling retained on disk for the "
        "optional far-LOD A/B, but its input frames no longer exist."
    ),
    "us_troops/": (
        "art_source/characters/us_troops/ — GONE. US authoring moved to "
        "US_CHARACTERS_DIR (assets/us/characters/)."
    ),
    "base_psx/": (
        "art_source/characters/base_psx/ — GONE. anim_library.blend moved to "
        "assets/shared/; vc_guerilla_v2.blend moved to assets/nva_vc/characters/."
    ),
}


def dead(key):
    """Raise with the story of a source that no longer exists."""
    raise FileNotFoundError("DEAD SOURCE: %s" % DEAD.get(key, key))


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def out_glb(*parts):
    """Absolute path for an export target; creates the parent dir."""
    path = _p(*parts)
    parent = os.path.dirname(path)
    if parent and not os.path.isdir(parent):
        os.makedirs(parent)
    return path


def require(path):
    """Assert a source exists before a tool spends minutes on it."""
    if not os.path.exists(path):
        raise FileNotFoundError(
            "PATH CONTRACT VIOLATION: %s\n"
            "Run `python tools/recon_paths.py` to see the full report." % path
        )
    return path


# --------------------------------------------------------------------------
# VERIFICATION ENTRY POINT
# --------------------------------------------------------------------------

def _declared():
    """Every module-level path constant, by name."""
    g = globals()
    skip = {"ROOT", "ASSETS", "TOOLS"}
    out = {}
    for name, val in g.items():
        if name.startswith("_") or name in skip:
            continue
        if name.isupper() and isinstance(val, str) and val.startswith(ROOT):
            out[name] = val
    return out


_ABS = re.compile(r'[A-Za-z]:[\\/]{1,2}Users')
_BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "tool_path_baseline.json")


def scan_hardcoded():
    """Every tool still typing an absolute path, and how many times.

    This is the ratchet. The contract is only real if new violations cannot be
    added quietly, so the count is held against a ceiling that ONLY goes down —
    the same machine ADR-023 uses for fossils. Repoint a tool through this
    module, run with --write-baseline, and the ceiling tightens behind you.
    """
    counts = {}
    for path in sorted(glob.glob(os.path.join(TOOLS, "*.py"))):
        name = os.path.basename(path)
        if name == "recon_paths.py":
            continue
        src = open(path, encoding="utf-8", errors="replace").read()
        n = len(_ABS.findall(src))
        if n:
            counts[name] = n
    return counts


def _load_baseline():
    if not os.path.exists(_BASELINE):
        return None
    with open(_BASELINE, encoding="utf-8") as fh:
        return json.load(fh)


def check_ratchet(quiet=False):
    """Returns list of failure strings."""
    counts = scan_hardcoded()
    total = sum(counts.values())
    base = _load_baseline()
    fails = []

    if base is None:
        if not quiet:
            print("no baseline yet — run with --write-baseline")
        return fails

    ceiling = base.get("ceiling", 0)
    known = base.get("files", {})

    if total > ceiling:
        fails.append("hardcoded absolute paths: %d > ceiling %d" % (total, ceiling))
    for name, n in sorted(counts.items()):
        if n > known.get(name, 0):
            fails.append("%s: %d hardcoded paths (was %d) — import from "
                         "recon_paths instead" % (name, n, known.get(name, 0)))

    if not quiet:
        print("HARDCODED-PATH RATCHET")
        print("  total %d / ceiling %d   (%d files)" % (total, ceiling, len(counts)))
        for f in fails:
            print("  FAIL  %s" % f)
        if not fails:
            print("  OK — no new hardcoded paths.")
    return fails


def write_baseline():
    counts = scan_hardcoded()
    total = sum(counts.values())
    prev = _load_baseline()
    if prev is not None and total > prev.get("ceiling", 0):
        raise SystemExit(
            "REFUSED: baseline would GROW (%d > %d). This register only shrinks.\n"
            "Repoint the offending tool through recon_paths instead."
            % (total, prev["ceiling"]))
    with open(_BASELINE, "w", encoding="utf-8") as fh:
        json.dump({"ceiling": total, "files": counts}, fh, indent=2, sort_keys=True)
    print("baseline written: ceiling=%d across %d files" % (total, len(counts)))


def verify(quiet=False):
    """Check every declared LIVE path. Returns list of (name, path) missing."""
    missing = []
    ok = []
    for name, path in sorted(_declared().items()):
        if name in CREATABLE_DIRS:
            continue
        (ok if os.path.exists(path) else missing).append((name, path))

    if not quiet:
        print("RECON PATH CONTRACT")
        print("ROOT: %s" % ROOT)
        print("-" * 68)
        print("OK      : %d" % len(ok))
        print("MISSING : %d" % len(missing))
        if missing:
            print("-" * 68)
            for name, path in missing:
                rel = os.path.relpath(path, ROOT)
                print("  MISSING  %-24s %s" % (name, rel))
            print("-" * 68)
            print("A declared path moved. Repoint it HERE, in recon_paths.py —")
            print("not in the tool that broke. That is how this stays one fix.")
        else:
            print("-" * 68)
            print("All declared source paths resolve.")
    return missing


if __name__ == "__main__":
    if "--write-baseline" in sys.argv:
        write_baseline()
        sys.exit(0)
    bad = verify()
    print()
    bad += check_ratchet()
    sys.exit(1 if bad else 0)
