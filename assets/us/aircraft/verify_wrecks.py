"""Assert the wreck contract on the SHIPPED GLBs, from a clean scene.

    blender -b --factory-startup -P verify_wrecks.py -- [a1|huey|f4|all]

`build_wrecks.py` proves its own output at the end of each build. This proves the files
that are actually on disk, which is a different claim: it catches a hand-edit, a stale
export, a rebuild that was never run, and a donor swap that changed the facing. It reads
nothing from the build scene and imports nothing but the file itself.

Checked, per wreck:
  * every mesh AND every collider carries a `wreck_hard_`/`wreck_soft_` prefix
    (ballistics reads the collider name, destruction reads the mesh name - a piece that
     loses its prefix ships bulletproof and silent)
  * every collider name ENDS with `-colonly`, and there is at least one
  * no `.` in any exported node name (Blender's `.001` breaks the colonly suffix)
  * `fire_socket_1..3` + `pilot_anchor` present; each fire socket <= 2.5 m from wreck
    geometry, the anchor 4-7 m off the hull in plan and >= 8 m from every fire socket
  * nose at Blender +Y (== Godot -Z)
  * mound RIM at z 0 (its bbox floor is the entry furrow, ~0.4 m lower - measuring that
    instead convicts every wreck ever shipped) and the origin at the footprint centre
  * every embedded image carries a human-chosen name, so Godot's extraction produces
    `{glb}_{image}.png` and not a tempfile name that regenerates on every import
"""
import bpy, json, math, os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wrecklib as W
from wrecklib import AIR

WRECKS = {
    "a1": "a1_skyraider_crashed.glb",
    "huey": "huey_crashed.glb",
    "f4": "f4_phantom_crashed.glb",
}


def glb_json(path):
    with open(path, "rb") as f:
        d = f.read()
    n = struct.unpack("<I", d[12:16])[0]
    return json.loads(d[20:20 + n].decode("utf-8"))


def check(name, path):
    print("=" * 72)
    print("%s  ->  %s" % (name, path))
    fail = []
    j = glb_json(path)
    stem = os.path.splitext(os.path.basename(path))[0]
    imgs = [i.get("name", "") for i in j.get("images", [])]
    for im in imgs:
        if im.startswith("tmp") or not im.replace("_", "").isalnum():
            fail.append("image %r embeds under a machine-generated name" % im)
    print("  images %s -> Godot extracts %s"
          % (imgs, ["%s_%s.png" % (stem, i) for i in imgs] or "nothing"))

    W.wipe()
    bpy.ops.import_scene.gltf(filepath=path)
    objs = list(bpy.context.scene.objects)
    meshes = [o for o in objs if o.type == 'MESH']
    empties = {o.name for o in objs if o.type == 'EMPTY'}
    cols = [o for o in meshes if o.name.endswith("-colonly")]
    vis = [o for o in meshes if not o.name.endswith("-colonly")]

    dotted = [o.name for o in objs if "." in o.name]
    if dotted:
        fail.append("'.' in exported name(s): %s" % dotted)
    halfcol = [o.name for o in meshes
               if "colonly" in o.name and not o.name.endswith("-colonly")]
    if halfcol:
        fail.append("collider suffix not final: %s" % halfcol)
    if not cols:
        fail.append("no -colonly collider in the file")
    unpref = [o.name for o in meshes
              if not o.name.startswith(("wreck_hard_", "wreck_soft_"))]
    if unpref:
        fail.append("mesh/collider with no wreck_ prefix, ships bulletproof: %s" % unpref)

    n = 0
    for o in vis:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    lo, hi = W.bbox(vis)
    print("  %d visible meshes (%d tris) + %d colliders, %d empties"
          % (len(vis), n, len(cols), len(empties)))
    print("  dims X %.2f  Y %.2f  Z %.2f   bbox lo %s hi %s"
          % (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
             [round(v, 2) for v in lo], [round(v, 2) for v in hi]))

    mound = next((o for o in vis if "mound" in o.name), None)
    if mound is not None:
        # the TOE is the outer rim, not the bbox floor. The scar's entry furrow is dug
        # 0.4-0.5 m BELOW the rim, so a bbox-minimum test convicts every wreck ever
        # shipped - including the signed-off Huey, which is how this check was caught
        # being wrong rather than the assets being wrong.
        mp = W.verts(mound)
        cx = sum(p.x for p in mp) / len(mp)
        cy = sum(p.y for p in mp) / len(mp)
        rim = sorted(mp, key=lambda p: -((p.x - cx) ** 2 + (p.y - cy) ** 2))
        rim = rim[:max(4, len(rim) // 20)]
        rz = sum(p.z for p in rim) / len(rim)
        ml, mh = W.bbox([mound])
        print("  mound rim z %+.3f (outer 5%% of verts), furrow floor %+.3f, crest %+.3f"
              % (rz, ml.z, mh.z))
        if abs(rz) > 0.12:
            fail.append("mound rim sits at z %+.3f - place_structure drops the ORIGIN "
                        "onto terrain height, so the toe has to meet it" % rz)
    if abs(lo.x + hi.x) > 0.05 or abs(lo.y + hi.y) > 0.05:
        fail.append("origin is not at the footprint centre (x %+.3f, y %+.3f)"
                    % (lo.x + hi.x, lo.y + hi.y))

    for e in ("fire_socket_1", "fire_socket_2", "fire_socket_3", "pilot_anchor"):
        if e not in empties:
            fail.append("socket %s missing" % e)

    def mean_y(subs):
        v = [p.y for o in vis for p in W.verts(o) if any(k in o.name for k in subs)]
        return sum(v) / len(v) if v else None

    fwd, aft = mean_y(("engine", "nose", "fuselage")), mean_y(("tail", "boom", "stab"))
    if fwd is not None and aft is not None:
        print("  facing: fwd parts mean y %+.2f, aft %+.2f -> %s"
              % (fwd, aft, "nose +Y (Godot -Z) OK" if fwd > aft else "**REVERSED**"))
        if fwd <= aft:
            fail.append("exported nose is not +Y")

    wp = [p for o in vis if "mound" not in o.name for p in W.verts(o)]
    hull = [p for o in vis if o.name.startswith("wreck_hard")
            and "mound" not in o.name for p in W.verts(o)]
    fires = [o for o in objs if o.type == 'EMPTY' and o.name.startswith("fire_socket")]
    for f in sorted(fires, key=lambda o: o.name):
        loc = f.matrix_world.translation
        d = min((loc - p).length for p in wp)
        print("  %s: %.2f m to nearest wreck surface (max 2.5)" % (f.name, d))
        if d > 2.5:
            fail.append("%s is %.2f m off the wreck" % (f.name, d))
    anc = next((o for o in objs if o.name == "pilot_anchor"), None)
    if anc is not None and fires and hull:
        a = anc.matrix_world.translation
        dh = min(math.hypot(a.x - p.x, a.y - p.y) for p in hull)
        df = min(math.hypot(a.x - f.matrix_world.translation.x,
                            a.y - f.matrix_world.translation.y) for f in fires)
        print("  pilot_anchor: %.2f m off the hull (want 4.0..7.0), %.2f m from the "
              "nearest fire socket (min 8.0)" % (dh, df))
        if not (4.0 <= dh <= 7.0):
            fail.append("pilot_anchor %.2f m off the hull" % dh)
        if df < 8.0:
            fail.append("pilot_anchor only %.2f m from a fire socket" % df)

    for f in fail:
        print("  FAIL: %s" % f)
    print("  %s" % ("PASS" if not fail else "**%d FAILURE(S)**" % len(fail)))
    return fail


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
    which = argv[0] if argv else "all"
    bad = {}
    for k, v in WRECKS.items():
        if which not in ("all", k):
            continue
        f = check(k, os.path.join(AIR, v))
        if f:
            bad[k] = f
    print("=" * 72)
    if bad:
        raise SystemExit("VERIFY FAILED: %s" % bad)
    print("ALL WRECKS PASS")
