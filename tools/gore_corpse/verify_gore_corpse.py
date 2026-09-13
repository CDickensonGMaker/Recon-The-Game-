"""Verify the SHIPPED gore-corpse GLB from a clean scene against the manifest it was built
with. Exit 1 on any failure.

    blender -b --factory-startup --python tools/gore_corpse/verify_gore_corpse.py

Checks: node names (engine contract), tri counts vs manifest and budget, exactly two materials
on the corpse (baked atlas + the shared gore sheet) and one on maggot_mass, every embedded
image under 1 MB (Caleb's law), UVs present and not collapsed, the collider is a terminal
'-colonly' with no degenerate faces, nothing below z = -2 mm, the pelvis origin (a vertex of
the hips within 12 cm of the origin XY), footprint within 5 mm of the manifest, the four fx
anchors present, above ground and where the manifest says. Also the pose contacts the
manifest recorded: head, right hand, both feet, torso within 6 mm of the ground; the left hand
resting on the hip/thigh (0.05..0.30 m up). v2 gates (Caleb's review of v1): thigh, calf and
boot of BOTH legs within 5 mm of the ground; each forearm's roll about its own axis <= 15 deg,
each elbow bent 0..60 deg, each elbow point facing down/out (z <= 0.35); the gut is one tube
with >= 5 hairpin loops, 25..35 mm across; >= 120 geometry grubs on maggot_mass.
"""
import bpy, os, sys, json, struct

ROOT = r"C:\Users\caleb\RECONgame"
DIR = os.path.join(ROOT, "assets", "world", "props", "gore_corpse")
BUDGET = 2200
MAX_IMAGE = 1_000_000

fails = []


def glb_images(path):
    with open(path, "rb") as f:
        data = f.read()
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + length].decode("utf-8"))
    views = gltf.get("bufferViews", [])
    out = []
    for im in gltf.get("images", []):
        if "bufferView" in im:
            out.append((im.get("name", "?"), views[im["bufferView"]]["byteLength"]))
    return out, gltf


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("  FAIL", msg)
    else:
        print("  ok  ", msg)


man = json.load(open(os.path.join(DIR, "gore_corpse_manifest.json")))
for key, rep in man["corpses"].items():
    name = "gore_corpse_" + key
    path = os.path.join(DIR, name + ".glb")
    print("==", name)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    check(os.path.exists(path), "exists %s" % path)
    if not os.path.exists(path):
        continue
    imgs, gltf = glb_images(path)
    for n, b in imgs:
        check(b <= MAX_IMAGE, "image %s %d bytes <= 1MB" % (n, b))
    check(len(imgs) == 3, "3 embedded images (atlas + gore sheet + maggots_a), got %d %s" % (len(imgs), [n for n, _ in imgs]))
    check(os.path.getsize(path) < 1_500_000, "glb %d bytes" % os.path.getsize(path))
    bpy.ops.import_scene.gltf(filepath=path)
    objs = {o.name: o for o in bpy.data.objects}
    names = set(objs)
    want = (name, "maggot_mass", name + "_000-colonly", "fx_maggots_01", "fx_maggots_02", "fx_maggots_03", "fx_flies_01")
    for w in want:
        check(w in names, "node %s present" % w)
    stray = [n for n in names if n not in want]
    check(not stray, "no stray nodes %s" % stray)
    mesh = objs.get(name)
    if mesh is not None:
        tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
        check(tris == rep["tris"], "tris %d == manifest %d" % (tris, rep["tris"]))
        check(tris <= BUDGET, "tris %d <= budget %d" % (tris, BUDGET))
        check(all(len(p.vertices) == 3 for p in mesh.data.polygons), "triangulated, no n-gons")
        mats = [m.name for m in mesh.data.materials]
        check(len(mats) == 2, "two materials on the corpse %s" % mats)
        check(any(m.startswith("gore_cap_mat") for m in mats), "gore sheet material present %s" % mats)
        check(mesh.data.uv_layers.active is not None, "corpse has UVs")
        uvs = [l.uv for l in mesh.data.uv_layers.active.data]
        uniq = len({(round(u.x, 4), round(u.y, 4)) for u in uvs})
        check(uniq > 300, "UVs not collapsed (%d unique)" % uniq)
        vs = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
        mnz = min(v.z for v in vs)
        check(mnz >= -0.002, "lowest vertex z %.4f >= -0.002" % mnz)
        fx = max(v.x for v in vs) - min(v.x for v in vs)
        fy = max(v.y for v in vs) - min(v.y for v in vs)
        check(abs(fx - rep["footprint_m"][0]) < 0.005 and abs(fy - rep["footprint_m"][1]) < 0.005,
              "footprint %.3f x %.3f == manifest %s" % (fx, fy, rep["footprint_m"]))
        # origin under the pelvis: some vertex within 12 cm of the origin in XY at 0.05-0.30 z
        near = [v for v in vs if (v.x ** 2 + v.y ** 2) ** 0.5 < 0.12 and 0.03 < v.z < 0.32]
        check(len(near) > 3, "pelvis over the origin (%d verts within 12 cm)" % len(near))
        pc = rep.get("pose_contacts", {})
        for r in ("head", "hand_r", "foot_l", "foot_r", "torso", "arm_l"):
            d = pc.get(r)
            if d:
                check(d["min_z"] <= 0.006, "pose contact %s min_z %.4f <= 6 mm" % (r, d["min_z"]))
        d = pc.get("hand_l")
        if d:
            check(0.05 < d["min_z"] < 0.30, "left hand rests on the hip / thigh (min_z %.3f)" % d["min_z"])
        pg = rep.get("pose_gates", {})
        check(bool(pg), "pose gates recorded")
        for part, d in pg.get("legs_flattened_mm", {}).items():
            check(d["min_mm"] <= 5.0, "leg part %s %.1f mm above ground <= 5" % (part, d["min_mm"]))
        for part in ("foot_l", "foot_r"):
            mm = pg.get("legs_mm_above_ground", {}).get(part)
            if mm is not None:
                check(mm <= 5.0, "boot %s %.1f mm above ground <= 5" % (part, mm))
        for arm in ("arm_r", "arm_l"):
            a = pg.get(arm, {})
            check(abs(a.get("forearm_twist_deg", 999)) <= 15.0, "%s forearm twist %.1f deg <= 15" % (arm, a.get("forearm_twist_deg", 999)))
            check(0.0 <= a.get("elbow_deg", 999) <= 60.0, "%s elbow %.1f deg in 0..60" % (arm, a.get("elbow_deg", 999)))
            check(a.get("elbow_point_z", 9) <= 0.35, "%s elbow point z %.2f <= 0.35 (not spun up)" % (arm, a.get("elbow_point_z", 9)))
        g = rep.get("guts", {})
        check(g.get("loops", 0) >= 5, "gut loops %d >= 5" % g.get("loops", 0))
        check(25.0 <= g.get("tube_dia_mm", 0) <= 35.0, "gut tube %.0f mm across in 25..35" % g.get("tube_dia_mm", 0))
        mg = rep.get("maggots", {})
        check(mg.get("grubs", 0) >= 120, "geometry grubs %d >= 120" % mg.get("grubs", 0))
    mag = objs.get("maggot_mass")
    if mag is not None:
        check(mag.data.uv_layers.active is not None, "maggot_mass has UVs")
        check(len(mag.data.materials) == 1 and mag.data.materials[0].name.startswith("gore_pile_maggots"), "maggot material %s" % [m.name for m in mag.data.materials])
        mt = sum(len(p.vertices) - 2 for p in mag.data.polygons)
        check(mt == rep["tris_maggots"], "maggot tris %d == manifest %d" % (mt, rep["tris_maggots"]))
        check(mt >= rep.get("maggots", {}).get("grubs", 0) * 8, "maggot node carries the grub geometry (%d tris)" % mt)
        mz = [(mag.matrix_world @ v.co).z for v in mag.data.vertices]
        check(min(mz) >= -0.002, "maggots lowest z %.4f >= -2 mm" % min(mz))
    col = objs.get(name + "_000-colonly")
    if col is not None:
        check(len(col.data.polygons) > 4, "collider has %d faces" % len(col.data.polygons))
        check(col.name.endswith("-colonly"), "collider marker is terminal")
        degenerate = sum(1 for p in col.data.polygons if p.area < 1e-7)
        check(degenerate == 0, "collider has no degenerate faces (%d)" % degenerate)
        check(len(col.data.polygons) == rep["tris_collider"], "collider tris %d == manifest %d" % (len(col.data.polygons), rep["tris_collider"]))
    for a in ("fx_maggots_01", "fx_maggots_02", "fx_maggots_03", "fx_flies_01"):
        e = objs.get(a)
        if e is not None:
            check(e.type == 'EMPTY', "%s is an empty" % a)
            wz = e.matrix_world.translation
            check(wz.z > 0.02, "%s above ground (z %.3f)" % (a, wz.z))
            mz = rep["anchors"][a]
            check(abs(wz.x - mz[0]) < 0.01 and abs(wz.y - mz[1]) < 0.01 and abs(wz.z - mz[2]) < 0.01, "%s position matches manifest" % a)

print("\nRESULT: %s (%d failures)" % ("PASS" if not fails else "FAIL", len(fails)))
for f in fails:
    print("  -", f)
sys.exit(1 if fails else 0)
