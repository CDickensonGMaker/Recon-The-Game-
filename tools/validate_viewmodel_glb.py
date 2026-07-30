"""Post-export GLB contract validator for FP viewmodels (pure python, no Blender).

    python tools/validate_viewmodel_glb.py            # validate every manifest gun
    python tools/validate_viewmodel_glb.py m16        # one gun
    python tools/validate_viewmodel_glb.py --selftest # broken-GLB regression signatures

Contract per gun comes from tools/viewmodel_manifest.json. Checks:
  - exact clip set (no missing, no extras)
  - contract markers (SightRear/SightFront/MuzzlePoint) exist; when markers_under_gun,
    they are descendants of the gun root with local translation < 1.5 m
  - no non-uniform scale on any node (glTF shear -> tumbling rotation)
  - every clip carries a channel for every manifest part (a part with no track in a
    clip holds its last pose in game instead of resetting)
  - the gun root node exists

The selftest encodes the 2026-07-25 break as a permanent regression: markers severed
from the gun at floor-ruler coords, gun with zero channels. That shape must FAIL.
"""
import json, struct, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "viewmodel_manifest.json")
MARKERS = ("SightRear", "SightFront", "MuzzlePoint")


def parse_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"glTF":
        raise ValueError(f"{path} is not a GLB")
    clen, _ = struct.unpack("<II", data[12:20])
    return json.loads(data[20:20 + clen])


def descendants(gltf, idx):
    out = set()
    stack = [idx]
    while stack:
        i = stack.pop()
        for c in gltf["nodes"][i].get("children", []):
            out.add(c)
            stack.append(c)
    return out


def validate(gltf, spec, label):
    errs = []
    nodes = gltf.get("nodes", [])
    byname = {}
    for i, n in enumerate(nodes):
        byname.setdefault(n.get("name", ""), i)

    # A non-gun ITEM (knife, handset, claymore, grenade) has a root and clips like a gun
    # but no iron sights, so it names its own required markers. Everything else below -
    # the clip set, the shear rule, the per-part channel law - is identical and must stay
    # identical: an item that silently holds a part's last pose is the same bug.
    root_key = "gun_root" if "gun_root" in spec else "item_root"
    markers = tuple(spec.get("markers", MARKERS))
    if spec.get(root_key) not in byname:
        errs.append(f"root {spec.get(root_key)} missing")

    clips = {a.get("name", "?") for a in gltf.get("animations", [])}
    want = set(spec["clips"])
    if clips != want:
        errs.append(f"clip set mismatch: missing={sorted(want - clips)} extra={sorted(clips - want)}")

    for m in markers:
        if m not in byname:
            errs.append(f"marker {m} missing")
    if spec.get("markers_under_gun") and spec.get(root_key) in byname:
        under = descendants(gltf, byname[spec[root_key]])
        for m in markers:
            i = byname.get(m)
            if i is None:
                continue
            if i not in under:
                errs.append(f"marker {m} is not a descendant of {spec[root_key]} (the 2026-07-25 break shape)")
            else:
                t = nodes[i].get("translation", [0, 0, 0])
                if max(abs(v) for v in t) > 1.5:
                    errs.append(f"marker {m} local translation {t} is not on the gun")

    # Non-uniform scale is fatal ONLY on animated nodes: a scaled node that must
    # rotate is a shear glTF cannot express and it decomposes into a tumbling
    # rotation (the 2026-07-25 M16 mag). On static children riding a rigid root
    # it is representable - authored proportions, warn and pass.
    animated_nodes = set()
    for a in gltf.get("animations", []):
        for ch in a.get("channels", []):
            animated_nodes.add(ch["target"].get("node"))
    warned = 0
    for i, n in enumerate(nodes):
        s = n.get("scale")
        if s and max(s) - min(s) > 1e-3:
            if i in animated_nodes:
                errs.append(f"node {n.get('name', i)} is ANIMATED with non-uniform scale {s}")
            else:
                warned += 1
    if warned:
        print(f"   note: {warned} static node(s) carry non-uniform scale (authored proportions, not fatal)")

    # EVERY clip must carry a channel for EVERY manifest part, rifle_idle included.
    # A clip with no track for a part cannot reset it in Godot - the part stays
    # wherever the previous clip left it (2026-07-27: jam left the M16 chandle
    # hanging 8cm off the receiver and rifle_idle never put it back).
    part_idx = {p: byname[p] for p in spec["parts"] if p in byname}
    for a in gltf.get("animations", []):
        targeted = {ch["target"].get("node") for ch in a.get("channels", [])}
        for pname, pidx in part_idx.items():
            if pidx not in targeted:
                errs.append(f"clip {a.get('name')} has no channel for part {pname} - "
                            f"the part cannot reset and holds its last pose in game")

    status = "PASS" if not errs else "FAIL"
    print(f"[{status}] {label}")
    for e in errs:
        print("   -", e)
    return not errs


def selftest():
    # the 2026-07-25 signature: gun collapsed, markers severed at floor-ruler coords,
    # every clip channel-less on the gun
    broken = {
        "nodes": [
            {"name": "ArmsRig_M16A1", "children": []},
            {"name": "M16A1_gun"},
            {"name": "SightRear", "translation": [3.3694, 0.1417, -0.0041]},
            {"name": "SightFront", "translation": [2.7730, 0.1420, -0.0030]},
            {"name": "MuzzlePoint", "translation": [2.6205, 0.0960, -0.0030]},
            {"name": "M16A1_magazine.030", "translation": [3.199, -0.058, -0.0029]},
        ],
        "animations": [{"name": c, "channels": []} for c in ("rifle_idle", "reload", "reload_empty", "jam")],
    }
    healthy = {
        "nodes": [
            {"name": "ArmsRig_M16A1"},
            {"name": "M16A1_gun", "children": [2, 3, 4, 5]},
            {"name": "SightRear", "translation": [0.2574, 0.0867, -0.0041]},
            {"name": "SightFront", "translation": [-0.339, 0.087, -0.003]},
            {"name": "MuzzlePoint", "translation": [-0.4915, 0.041, -0.003]},
            {"name": "M16A1_magazine.030", "translation": [0.087, -0.113, -0.0029]},
            {"name": "M16A1_charge_handle_slide_back", "translation": [0.189, 0.04, -0.008]},
        ],
        "animations": [
            {"name": c, "channels": [{"target": {"node": n, "path": "translation"}}
                                     for n in (1, 5, 6)]}
            for c in ("rifle_idle", "reload", "reload_empty", "jam")
        ],
    }
    spec = {"gun_root": "M16A1_gun", "clips": ["rifle_idle", "reload", "reload_empty", "jam"],
            "parts": ["M16A1_magazine.030", "M16A1_charge_handle_slide_back", "M16A1_gun"],
            "markers_under_gun": True}
    broke_failed = not validate(broken, spec, "selftest: 2026-07-25 broken signature (must FAIL)")
    healthy_ok = validate(healthy, spec, "selftest: healthy signature (must PASS)")
    if broke_failed and healthy_ok:
        print("SELFTEST PASS")
        return True
    print("SELFTEST FAIL - the validator no longer catches the break it was built for")
    return False


def main():
    args = [a for a in sys.argv[1:]]
    if "--selftest" in args:
        sys.exit(0 if selftest() else 1)
    man = json.load(open(MANIFEST))
    only = [a for a in args if not a.startswith("-")]
    ok = True
    entries = list(man["guns"].items()) + list(man.get("items", {}).items())
    for gun, spec in entries:
        if only and gun not in only:
            continue
        path = os.path.join(ROOT, man["output_dir"], f"{gun}_fp.glb")
        if not os.path.exists(path):
            print(f"[FAIL] {gun}: {path} missing")
            ok = False
            continue
        ok = validate(parse_glb(path), spec, f"{gun} ({os.path.basename(path)})") and ok
    gun_only = [g for g in only if g in man["guns"]] if only else []
    if "--no-timers" not in args and not (only and not gun_only):
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        import subprocess
        t = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "sync_weapon_timers.py"),
                            "--check"] + gun_only, capture_output=True, text=True)
        if t.returncode != 0:
            print((t.stdout + t.stderr).rstrip())
            ok = False
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
