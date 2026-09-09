"""Give a kit GLB real collision without opening Blender.

WHY THIS EXISTS. Five of the seven placeable kit parts shipped with ZERO colliders -
fb_FoxholeSandbags, fb_sandbag_heavy, fb_sandbag_light, fb_gate_assembly,
fb_emplacement_m101. They are July REVIEW exports (gen_firebase.py:1-13 says so in as many
words) and a player walks through every one of them, a bullet passes through every one of
them, and a Destructible built on one has no shape to hit.

The source blends for the sandbag/gate review set are on disk, but Blender is not free to
open and the export path would rebuild far more than the collision. So this does the one
thing that is missing, directly in the glTF: it emits a `-colonly` TWIN NODE per solid mesh,
sharing the same mesh index and the same local transform, parented to the same node.

THAT IS THE SHAPE THE WORKING PARTS ALREADY HAVE. fb_bunker_fighting.glb ships
`fb_bunker_fighting_000-colonly` and `WB_bunker_rifle` BOTH pointing at mesh 0. This tool
reproduces, byte for byte in structure, what tools/gen_firebase_v3.py:make_collision() puts
in the monolith - the same `{base}_{i:03d}-colonly` name, the marker at the END.

WHAT IT DOES NOT DO. It never touches geometry, UVs, materials or images. It appends nodes
to the JSON chunk and nothing else. It is idempotent: a base that already has a twin is
skipped, so re-running cannot double up.

Read the `recon-destructible-export` skill before changing any name here. Names are the
contract; ballistics reads the COLLIDER name and destruction reads the MESH name, and a
marker that is not at the END of the name ships the collider as a VISIBLE WHITE BOX
(us_fb_ammo_crate_stack-colonly_P2, three consecutive exports).

Usage:
    python tools/add_kit_colliders.py            # audit only, writes nothing
    python tools/add_kit_colliders.py --apply
"""

from __future__ import annotations

import json
import os
import struct
import sys

KIT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "world",
                   "building models", "structures", "firebase", "kit")
KIT = os.path.normpath(KIT)

GLB_MAGIC = b"glTF"
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

# Per-part rules. `skip` prefixes are meshes that must stay PASSABLE - the same judgement
# COL_NONE makes in gen_firebase_v3.py. `rename` fixes names before the twins are cut, so a
# twin never inherits a defect: a Blender `.001` imports as `_001` (glTF naming_version=2
# maps `.` to `_`, it does not delete it) and fb_sbg_seg_046_001 shipped invulnerable among
# 80 destructible twins for weeks.
PARTS = {
    "fb_FoxholeSandbags.glb": {
        "skip": (),
        "rename": {},
    },
    "fb_sandbag_heavy.glb": {
        "skip": (),
        # The mesh is the part id everywhere else in the kit; sandbag_heavy was the Blender
        # object name and nothing but this file used it.
        "rename": {"sandbag_heavy": "fb_sandbag_heavy"},
    },
    "fb_sandbag_light.glb": {
        "skip": (),
        "rename": {},
    },
    "fb_gate_assembly.glb": {
        "skip": (),
        # watchtower_1.001 is the `.001` ADR-042 names as the cheapest way to break the
        # contract. It is also the tower art he is rebuilding, so it gets the name the kit
        # will keep.
        "rename": {
            "watchtower_1.001": "fb_gate_tower",
            "gate_left": "fb_gate_leaf_l",
            "gate_right": "fb_gate_leaf_r",
            "gate_post_left": "fb_gate_post_l",
            "gate_post_right": "fb_gate_post_r",
        },
    },
    "fb_emplacement_m101.glb": {
        # The crew rigs are PEOPLE (32 skinned meshes) and the loose rounds are clutter a
        # man should walk over, not into. What must stop him is the gun and the parapet
        # around the pit - which today he walks straight through.
        "skip": ("grunt_", "MC_", "m101_round_", "m101_shell_"),
        "rename": {},
    },
    # The two bunkers already carry colliders. They are listed so the audit covers the whole
    # palette, and so the workbench names get the same one-time cleanup: identity comes from
    # data/world/kit_parts.json now, so a mesh name only has to be readable.
    "fb_bunker_fighting.glb": {
        "skip": (),
        "rename": {"WB_bunker_rifle": "fb_bunker_fighting"},
    },
    "fb_bunker_mg.glb": {
        # The M60 and its pintle are the WEAPON on top of the bunker, not the bunker.
        # kit_parts.json excludes them from structure_meshes for the same reason - and a
        # trimesh body wrapped round a gun the player is meant to stand behind and fire is
        # a wall between him and the handles.
        "skip": ("m60",),
        "rename": {"WB_bunker_m60": "fb_bunker_mg"},
    },
}


def read_glb(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:4] != GLB_MAGIC:
        raise SystemExit("%s is not a GLB" % path)
    off = 12
    js = None
    chunks = []
    while off < len(raw):
        length, ctype = struct.unpack("<II", raw[off:off + 8])
        off += 8
        data = raw[off:off + length]
        off += length
        if ctype == CHUNK_JSON:
            js = json.loads(data.decode("utf-8"))
        else:
            chunks.append((ctype, data))
    return js, chunks


def write_glb(path, js, chunks):
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    out = [struct.pack("<II", len(js_bytes), CHUNK_JSON), js_bytes]
    for ctype, data in chunks:
        pad = b"\x00" if ctype == CHUNK_BIN else b" "
        data = data + pad * ((4 - len(data) % 4) % 4)
        out.append(struct.pack("<II", len(data), ctype))
        out.append(data)
    body = b"".join(out)
    header = struct.pack("<4sII", GLB_MAGIC, 2, 12 + len(body))
    with open(path, "wb") as f:
        f.write(header + body)


def parent_map(js):
    """node index -> parent index, or None when it hangs off a scene."""
    out = {}
    for i, n in enumerate(js.get("nodes", [])):
        for c in n.get("children", []):
            out[c] = i
    return out


def base_name(name):
    """Sanitise, do NOT truncate.

    gen_firebase_v3.make_collision() takes `o.name.split(".")[0]` because in that scene a
    `.001` is a Blender duplicate of one object. Here it is not: m101_trail_L.001 .. .004
    are five DIFFERENT meshes of the trail assembly, and truncating collapsed all five onto
    one collider, so four of them stayed passable. Godot's importer maps `.` to `_`, so
    doing the same here keeps every part distinct and keeps the node name legal.
    """
    return name.replace(".", "_")


def process(path, rule, apply_changes):
    js, chunks = read_glb(path)
    nodes = js.get("nodes", [])
    parents = parent_map(js)
    scene = js.get("scenes", [{}])[js.get("scene", 0)]
    scene_roots = scene.setdefault("nodes", [])

    renamed = 0
    for old, new in rule["rename"].items():
        for n in nodes:
            if n.get("name") == old:
                n["name"] = new
                renamed += 1

    # Which bases already own a twin. A twin is `{base}_{i:03d}-colonly`, so strip the
    # index back off. This is what makes the tool idempotent - re-running it must not
    # double the colliders on a part that already has them.
    have = set()
    for n in nodes:
        nm = n.get("name", "")
        if "-colonly" in nm:
            have.add(nm.split("-colonly")[0].rsplit("_", 1)[0])

    made = 0
    skipped = 0
    added = []
    for i in range(len(nodes)):
        n = nodes[i]
        if "mesh" not in n:
            continue
        nm = n.get("name", "")
        if "-colonly" in nm:
            continue
        if "skin" in n:
            skipped += 1
            continue
        base = base_name(nm)
        if any(base.startswith(p) for p in rule["skip"]):
            skipped += 1
            continue
        if base in have:
            continue
        twin = {"name": "%s_%03d-colonly" % (base, i), "mesh": n["mesh"]}
        for key in ("translation", "rotation", "scale", "matrix"):
            if key in n:
                twin[key] = list(n[key])
        added.append((twin, parents.get(i)))
        have.add(base)
        made += 1

    for twin, parent in added:
        idx = len(nodes)
        nodes.append(twin)
        if parent is None:
            scene_roots.append(idx)
        else:
            nodes[parent].setdefault("children", []).append(idx)

    # THE TERMINAL ASSERTION, before anything is written. gen_firebase_v3 raises here and so
    # does the shipped-bytes audit; a marker that is not at the end of the name defeats the
    # importer's parser entirely and the collider ships as a visible material-less box.
    for n in nodes:
        nm = n.get("name", "")
        if "-colonly" in nm and not nm.endswith("-colonly"):
            raise SystemExit("%s: '%s' carries -colonly but not at the END" % (path, nm))
        if "." in nm:
            print("   WARN %s still carries a '.' - it imports as '_'" % nm)

    total_col = sum(1 for n in nodes if "-colonly" in n.get("name", ""))
    print("%-34s +%d twin(s), %d rename(s), %d skipped, %d -colonly total"
          % (os.path.basename(path), made, renamed, skipped, total_col))
    # `made` ALONE WAS THE CONDITION HERE AND IT SHIPPED A LIE. The two bunkers already had
    # colliders, so made was 0, so nothing was written - and their renames (WB_bunker_rifle
    # -> fb_bunker_fighting, WB_bunker_m60 -> fb_bunker_mg) were applied to a dictionary
    # that was then thrown away. The tool printed a clean line, kit_parts.json was updated
    # to the new names, and the stamp wired ONE structure out of three because the meshes
    # in the GLB still carried the workbench names. Measured, 2026-09-09.
    if (made or renamed) and apply_changes:
        write_glb(path, js, chunks)
    return made + renamed


def main():
    apply_changes = "--apply" in sys.argv
    total = 0
    for fn, rule in PARTS.items():
        p = os.path.join(KIT, fn)
        if not os.path.exists(p):
            print("MISSING %s" % p)
            continue
        total += process(p, rule, apply_changes)
    print("%d change(s) %s" % (total, "written" if apply_changes else "would be written (dry run)"))


if __name__ == "__main__":
    main()
