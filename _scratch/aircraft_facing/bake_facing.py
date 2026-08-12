"""Bake the Summoner's recorded facings into the aircraft GLBs.

Reads production/model_facing.json (path -> yaw degrees, set by hand in
scenes/levels/facing_bench.tscn) and applies each yaw via a NEW PARENT ROOT
rather than by editing the objects. Three of these airframes carry animation
actions driving rotation_quaternion (propellers); rewriting object transforms
would fight those curves. A root node reorients everything on top of them and
the curves are never touched.

Also fixes the pure-white fuselage: A1_VietnamCamo and A4_VietnamCamo have base
colour (1,1,1) and no texture, which is why those two render as white models.
A flat SEA-scheme green is a holding colour, NOT camo - a real two-tone camo
needs authored art.

Every file is read back after export and re-measured. Nothing is trusted.
"""
import bpy, os, json, math
from mathutils import Matrix

ROOT = r"C:\Users\caleb\RECONgame"
JSON_PATH = os.path.join(ROOT, "production", "model_facing.json")
SCALES = {"ac47_spooky.glb": 0.1498}   # 196.31m span vs a real C-47's 29.41m

# FS34079-ish dark green. Holding colour until camo art exists.
SEA_GREEN = (0.16, 0.20, 0.13, 1.0)
WHITE_EPS = 0.97


def res_to_abs(p):
    return os.path.join(ROOT, p.replace("res://", "").replace("/", os.sep))


def survey():
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices)]
    return {"meshes": len(ms), "verts": sum(len(o.data.vertices) for o in ms),
            "materials": len(bpy.data.materials), "images": len(bpy.data.images),
            "actions": len(bpy.data.actions)}


def bounds_y():
    lo, hi = 1e9, -1e9
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        for v in o.data.vertices:
            y = (o.matrix_world @ v.co).y
            lo, hi = min(lo, y), max(hi, y)
    return lo, hi


def nose_y():
    ys = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        if not any(h in o.name.lower() for h in
                   ("prop", "pitot", "spinner", "gunpod", "cockpit", "canopy")):
            continue
        vs = [(o.matrix_world @ v.co).y for v in o.data.vertices]
        ys.append(sum(vs) / len(vs))
    return (sum(ys) / len(ys)) if ys else None


def fix_white_camo():
    fixed = []
    for m in bpy.data.materials:
        if not (m.use_nodes and m.node_tree):
            continue
        has_img = any(n.type == 'TEX_IMAGE' and n.image is not None
                      for n in m.node_tree.nodes)
        if has_img:
            continue
        for n in m.node_tree.nodes:
            if n.type != 'BSDF_PRINCIPLED':
                continue
            c = n.inputs['Base Color'].default_value
            if c[0] > WHITE_EPS and c[1] > WHITE_EPS and c[2] > WHITE_EPS:
                n.inputs['Base Color'].default_value = SEA_GREEN
                m.diffuse_color = SEA_GREEN
                fixed.append(m.name)
    return fixed


with open(JSON_PATH) as fh:
    facings = json.load(fh)

ok_all = True
for res_path, yaw in facings.items():
    fname = os.path.basename(res_path)
    abs_path = res_to_abs(res_path)
    scl = SCALES.get(fname, 1.0)
    if abs(float(yaw)) < 0.01 and scl == 1.0:
        print("\n%s  yaw 0, no rescale - already correct, untouched" % fname)
        continue
    if not os.path.exists(abs_path):
        print("\n%s  MISSING at %s" % (fname, abs_path))
        ok_all = False
        continue

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=abs_path)
    before = survey()
    n0, y0 = nose_y(), bounds_y()

    root = bpy.data.objects.new("AirframeRoot", None)
    bpy.context.collection.objects.link(root)
    M = Matrix.Rotation(math.radians(float(yaw)), 4, 'Z')
    if scl != 1.0:
        M = Matrix.Scale(scl, 4) @ M
    root.matrix_world = M
    for o in list(bpy.data.objects):
        if o is root or o.parent is not None:
            continue
        o.parent = root
        o.matrix_parent_inverse = Matrix.Identity(4)

    recoloured = fix_white_camo()

    bpy.ops.export_scene.gltf(filepath=abs_path, export_format='GLB',
                              use_selection=False, export_apply=False,
                              export_yup=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=abs_path)
    after = survey()
    n1, y1 = nose_y(), bounds_y()
    centre = (y1[0] + y1[1]) * 0.5
    lost = [k for k in ("meshes", "materials", "images", "actions")
            if after[k] < before[k]]
    facing_ok = (n1 is not None) and (n1 > centre)

    print("\n%s  yaw %.0f  scale %.4f" % (fname, float(yaw), scl))
    print("  meshes %d->%d  verts %d->%d  materials %d->%d  actions %d->%d"
          % (before["meshes"], after["meshes"], before["verts"], after["verts"],
             before["materials"], after["materials"], before["actions"], after["actions"]))
    print("  length Y %.2f -> %.2f   nose %.2f -> %.2f (centre %.2f)"
          % (y0[1] - y0[0], y1[1] - y1[0],
             n0 if n0 is not None else 0.0, n1 if n1 is not None else 0.0, centre))
    if recoloured:
        print("  recoloured white materials: %s" % recoloured)
    if lost:
        print("  FAIL lost %s" % lost)
        ok_all = False
    elif not facing_ok:
        print("  FAIL nose still behind centre")
        ok_all = False
    else:
        print("  OK")

print("\nBAKE_%s" % ("OK" if ok_all else "PROBLEM"))
