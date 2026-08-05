"""fix_helmet_materials.py - give the welded helmets their palette colour back.

    blender -b -P tools/fix_helmet_materials.py -- [--apply]

reshape_welded_helmet.py swapped in a donor mesh that carried its own materials named
MitchellCamo and Webbing. us_base_v3.blend already had materials by those names, so the
donor's appended as MitchellCamo.001 / Webbing.001 - and once the swap removed the last
user of the originals, Blender purged them on save.

The two are NOT interchangeable. Measured off the exported GLBs:

    us_grunt_v3.glb   (2026-07-12)  MitchellCamo      baseColorFactor [0.127, 0.166, 0.070]
    us_grunt_rifleman (2026-08-04)  MitchellCamo.001  baseColorFactor [1, 1, 1]

The originals carry the olive palette value; the donor's export pure white, which is
exactly what model_actor.gd:611 shouts about. Neither has an image - these are flat
palette materials by decree (model_actor.gd:577-583), so colour is the whole point.

This re-appends the originals from us_base_v3_PRE_HELMET.blend, puts them back on every
helmet that got the donor copies, and drops the copies.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
DONOR = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3_PRE_HELMET.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_MATFIX.blend")
WANT = ("MitchellCamo", "Webbing")

bpy.ops.wm.open_mainfile(filepath=SRC)

print("=== before ===")
for m in sorted(bpy.data.materials, key=lambda x: x.name):
    if any(w in m.name for w in WANT):
        print("  %-22s users=%d" % (m.name, m.users))

# the donor copies currently in use, keyed by the name they SHOULD have
copies = {}
for m in bpy.data.materials:
    for w in WANT:
        if m.name.startswith(w + "."):
            copies[w] = m

# bring the originals back from before the helmet pass
with bpy.data.libraries.load(DONOR, link=False) as (df, dt):
    dt.materials = [n for n in df.materials if n in WANT]
restored = {m.name: m for m in dt.materials if m}
print("\nrestored from PRE_HELMET: %s" % sorted(restored))
for n, m in sorted(restored.items()):
    col = None
    if m.use_nodes:
        for node in m.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                c = node.inputs['Base Color']
                col = (tuple(round(v, 3) for v in c.default_value), c.is_linked)
    print("  %-22s base=%s" % (n, col))

# swap them onto every mesh wearing a copy
swapped = 0
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    for i, slot in enumerate(o.material_slots):
        m = slot.material
        if m is None:
            continue
        for w in WANT:
            if m.name.startswith(w + ".") and w in restored:
                slot.material = restored[w]
                swapped += 1
                break
print("\nswapped %d material slots back onto the originals" % swapped)

for w, m in sorted(copies.items()):
    if m.users == 0:
        print("  dropping unused copy %s" % m.name)
        bpy.data.materials.remove(m)
    else:
        print("  NOTE: %s still has %d user(s), left in place" % (m.name, m.users))

print("\n=== after ===")
fail = []
for w in WANT:
    m = bpy.data.materials.get(w)
    if m is None:
        fail.append("%s is still missing" % w)
        continue
    col = None
    if m.use_nodes:
        for node in m.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                col = node.inputs['Base Color']
    print("  %-22s users=%-3d linked=%s" % (m.name, m.users, col.is_linked if col else "?"))
    if m.users == 0:
        fail.append("%s ended with no users" % w)

helm = bpy.data.objects.get("helmet_shell_worn_rifleman")
if helm:
    names = [s.material.name if s.material else None for s in helm.material_slots]
    print("  helmet_shell_worn_rifleman slots=%s" % names)
    if any(n and "." in n for n in names):
        fail.append("helmet still wearing a .00N copy: %s" % names)

print("\n=== GATE ===")
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  every helmet is back on the original palette materials")

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
