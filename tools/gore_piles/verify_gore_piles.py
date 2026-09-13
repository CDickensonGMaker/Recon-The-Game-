"""Verify the SHIPPED gore-pile GLBs from a clean scene, against the manifest they were built
with. Exit 1 on any failure.

    blender -b --factory-startup --python tools/gore_piles/verify_gore_piles.py

Checks per GLB: node names (engine contract), tri counts vs manifest and budget, exactly two
materials, every embedded image under 1 MB (Caleb's law), UVs present on both meshes, the
collider is terminal '-colonly', nothing below z = -2 mm, footprint within 5 mm of the
manifest, the four fx anchors present and above ground.
"""
import bpy, os, sys, json, struct

ROOT = r"C:\Users\caleb\RECONgame"
DIR = os.path.join(ROOT, "assets", "world", "props", "gore_piles")
BUDGET = {"small": 900, "large": 1800}
MAX_IMAGE = 1_000_000

fails = []


def glb_images(path):
    """(name, byteLength) of every embedded image, read off the bytes, not through Blender."""
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


man = json.load(open(os.path.join(DIR, "gore_piles_manifest.json")))
for key, rep in man["piles"].items():
    name = "gore_pile_" + key
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
    check(len(imgs) == 2, "2 embedded images (atlas + maggots_a), got %d" % len(imgs))
    bpy.ops.import_scene.gltf(filepath=path)
    objs = {o.name: o for o in bpy.data.objects}
    names = set(objs)
    for want in (name, "maggot_mass", name + "_000-colonly", "fx_maggots_01", "fx_maggots_02", "fx_maggots_03", "fx_flies_01"):
        check(want in names, "node %s present" % want)
    stray = [n for n in names if n not in (name, "maggot_mass", name + "_000-colonly", "fx_maggots_01", "fx_maggots_02", "fx_maggots_03", "fx_flies_01")]
    check(not stray, "no stray nodes %s" % stray)
    mesh = objs.get(name)
    if mesh is not None:
        tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
        size = key.split("_")[1]
        check(tris == rep["tris"], "tris %d == manifest %d" % (tris, rep["tris"]))
        check(tris <= BUDGET[size], "tris %d <= budget %d" % (tris, BUDGET[size]))
        check(all(len(p.vertices) == 3 for p in mesh.data.polygons), "triangulated, no n-gons")
        check(len(mesh.data.materials) == 1, "one material on the pile mesh (%s)" % [m.name for m in mesh.data.materials])
        check(mesh.data.uv_layers.active is not None, "pile has UVs")
        uvs = [l.uv for l in mesh.data.uv_layers.active.data]
        check(len({(round(u.x, 4), round(u.y, 4)) for u in uvs}) > 100, "pile UVs are not collapsed (%d unique)" % len({(round(u.x, 4), round(u.y, 4)) for u in uvs}))
        vs = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
        mnz = min(v.z for v in vs)
        check(mnz >= -0.002, "lowest vertex z %.4f >= -0.002" % mnz)
        fx = max(v.x for v in vs) - min(v.x for v in vs)
        fy = max(v.y for v in vs) - min(v.y for v in vs)
        check(abs(fx - rep["footprint_m"][0]) < 0.005 and abs(fy - rep["footprint_m"][1]) < 0.005,
              "footprint %.3f x %.3f == manifest %s" % (fx, fy, rep["footprint_m"]))
        cx = (max(v.x for v in vs) + min(v.x for v in vs)) / 2
        cy = (max(v.y for v in vs) + min(v.y for v in vs)) / 2
        check(abs(cx) < 0.01 and abs(cy) < 0.01, "XY centred on origin (%.3f, %.3f)" % (cx, cy))
    mag = objs.get("maggot_mass")
    if mag is not None:
        check(mag.data.uv_layers.active is not None, "maggot_mass has UVs")
        check(len(mag.data.materials) == 1 and mag.data.materials[0].name.startswith("gore_pile_maggots"), "maggot material %s" % [m.name for m in mag.data.materials])
    col = objs.get(name + "_000-colonly")
    if col is not None:
        check(len(col.data.polygons) > 4, "collider has %d faces" % len(col.data.polygons))
        check(col.name.endswith("-colonly"), "collider marker is terminal")
    for a in ("fx_maggots_01", "fx_maggots_02", "fx_maggots_03", "fx_flies_01"):
        e = objs.get(a)
        if e is not None:
            check(e.type == 'EMPTY', "%s is an empty" % a)
            check(e.matrix_world.translation.z > 0.02, "%s above ground (z %.3f)" % (a, e.matrix_world.translation.z))
            mz = rep["anchors"][a]
            wz = e.matrix_world.translation
            check(abs(wz.x - mz[0]) < 0.01 and abs(wz.z - mz[2]) < 0.01, "%s position matches manifest" % a)

print("\nRESULT: %s (%d failures)" % ("PASS" if not fails else "FAIL", len(fails)))
for f in fails:
    print("  -", f)
sys.exit(1 if fails else 0)
