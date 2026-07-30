"""Export the assembled M26 as a standalone world prop.

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/export_m26_grenade_prop.py

Writes assets/world/props/m26_grenade.glb — body, pin and spoon as three separately named
nodes so the engine can hide the pin and the spoon on a grenade that has already been thrown.

This is the WORLD object, not the viewmodel: `grenade.gd:41` currently builds the thrown
grenade out of a `SphereMesh`, and this replaces that ball. The viewmodel is a different
export entirely (`export_all_viewmodels.py m26_grenade`), off the same source meshes.

Runs headless so the three objects can be unparented and cleanly named without disturbing
the live rig. Never saves the .blend.
"""
import bpy, os
from mathutils import Matrix, Vector

OUT = r"C:\Users\caleb\RECONgame\assets\world\props\m26_grenade.glb"
PARTS = ["M26_Grenade", "M26_pin", "M26_spoon"]

keep = []
for n in PARTS:
    o = bpy.data.objects.get(n)
    if o is None:
        raise SystemExit("missing %s - has the grenade rig been built?" % n)
    keep.append(o)

# Drop everything else, then strip the rig ties. The meshes share the original grenade
# local space, so identity transforms reassemble them exactly as they sit on the rig.
for o in list(bpy.data.objects):
    if o not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
for o in keep:
    o.parent = None
    for c in list(o.constraints):
        o.constraints.remove(c)
    o.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()

allv = [v.co for o in keep for v in o.data.vertices]
mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
mx = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
# base on the ground, centred in X/Y - what a world prop wants
off = Vector((-(mn.x + mx.x) / 2.0, -(mn.y + mx.y) / 2.0, -mn.z))
for o in keep:
    o.matrix_world = Matrix.Translation(off)
bpy.context.view_layer.update()

for o in bpy.data.objects:
    o.select_set(o in keep)
bpy.context.view_layer.objects.active = keep[0]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_materials="EXPORT",
                          export_animations=False, export_cameras=False, export_lights=False)
print("nodes: %s" % [o.name for o in keep])
print("verts %d, size %s mm" % (sum(len(o.data.vertices) for o in keep),
                                tuple(round(v * 1000, 1) for v in (mx - mn))))
print("EXPORTED %s  %.1f KB" % (OUT, os.path.getsize(OUT) / 1024.0))
