"""Fresh-session verification of the SHIPPED etool_shovel.glb + renders.

    blender -b --factory-startup -P verify_etool.py

Imports the exported GLB into an empty scene, re-measures it, and renders three
check views. Nothing here reads the build script's in-memory state.
"""
import bpy, os, math, sys
from mathutils import Vector

REPO = r"C:\Users\caleb\RECONgame"
GLB = os.path.join(REPO, "assets", "world", "props", "etool_shovel.glb")
OUT = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0027fdb1-7538-4d57-aa88-85a876fd7c17\scratchpad"

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=GLB)
objs = [o for o in bpy.data.objects if o.type == "MESH"]
assert len(objs) == 1, objs
obj = objs[0]
me = obj.data

tris = sum(len(p.vertices) - 2 for p in me.polygons)
ngons = [len(p.vertices) for p in me.polygons if len(p.vertices) > 4]
co = [obj.matrix_world @ v.co for v in me.vertices]
mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
d = mx - mn

print("=" * 62)
print("object      : %s   mesh: %s" % (obj.name, me.name))
print("materials   : %s" % [m.name for m in me.materials])
print("verts %d  faces %d  TRIS %d  ngons %s" % (len(me.vertices), len(me.polygons), tris, ngons or "none"))
print("world bbox  : min %s" % [round(v, 4) for v in mn])
print("              max %s" % [round(v, 4) for v in mx])
print("dims X/Y/Z  : %s" % [round(v, 4) for v in d])
print("LONGEST AXIS: %.4f m  (target 0.711)" % max(d))
print("origin      : object at %s" % [round(v, 4) for v in obj.location])
print("  -> butt end %+.4f, blade tip %+.4f along longest axis" % (max(mx), min(mn)))
print("UV layers   : %s" % [u.name for u in me.uv_layers])
uv = me.uv_layers[0].data
us = sorted({round(l.uv[0], 4) for l in uv})
vs = sorted({round(l.uv[1], 4) for l in uv})
print("UV range    : u %.3f..%.3f (%d distinct)  v %.3f..%.3f (%d distinct)"
      % (us[0], us[-1], len(us), vs[0], vs[-1], len(vs)))
assert len(us) > 1 and len(vs) > 1, "single UV coordinate -> unpaintable"
assert us[0] >= 0.0 and us[-1] <= 1.0 and vs[0] >= 0.0 and vs[-1] <= 1.0

for im in bpy.data.images:
    if im.name == "Render Result":
        continue
    print("image       : %s %dx%d  packed %s" % (im.name, im.size[0], im.size[1],
          bool(im.packed_file)))
    if im.packed_file:
        print("              embedded bytes %d (%.3f MB)" % (im.packed_file.size,
              im.packed_file.size / 1048576.0))
        assert im.packed_file.size < 1048576, "TEXTURE BUDGET LAW breached"

# loose geometry / interior check
loose = [v.index for v in me.vertices if not any(v.index in p.vertices for p in me.polygons)]
print("loose verts : %d" % len(loose))
print("=" * 62)

# ---------------------------------------------------------------- renders --------
for im in bpy.data.materials:
    for n in (im.node_tree.nodes if im.use_nodes else []):
        if n.type == "TEX_IMAGE":
            n.interpolation = "Closest"          # PSX: nearest, never linear

sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = 900
sc.render.resolution_y = 700
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.18, 1)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.2

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(52), 0, math.radians(38))
bpy.context.collection.objects.link(sun)

cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 0.98
cam = bpy.data.objects.new("cam", cam_d)
bpy.context.collection.objects.link(cam)
sc.camera = cam
ctr = (mn + mx) / 2.0

VIEWS = {"profile": (90.0, 0.0), "face": (0.0, 88.0), "threequarter": (52.0, 26.0)}
paths = []
for name, (az, el) in VIEWS.items():
    r = 2.0
    a, e = math.radians(az), math.radians(el)
    cam.location = ctr + Vector((r * math.sin(a) * math.cos(e),
                                 -r * math.cos(a) * math.cos(e),
                                 r * math.sin(e)))
    dirv = (ctr - cam.location).normalized()
    cam.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
    p = os.path.join(OUT, "etool_%s.png" % name)
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)
    print("RENDER %s" % p)

print("VERIFY OK")
