"""Side-by-side headless renders: ORIGINAL (left) vs LOD (right), same camera.

    blender -b --factory-startup --python render_compare.py -- <orig.glb> <lod.glb> <outprefix> <gap>

Numbers do not prove a helicopter still reads as a Huey. Writes PNGs only.

Two traps this script exists to avoid, both hit on the first attempt:
  1. A fixed world-axis offset puts the two airframes one BEHIND the other the
     moment the camera swings onto that axis. The offset is recomputed per view
     along the camera's own right vector.
  2. A TRACK_TO constraint does NOT write back into cam.rotation_euler - only
     matrix_world carries the aimed orientation. Billboarding the text labels
     off rotation_euler produced labels lying on the ground at a random angle.
     Framing distance is solved analytically from the sensor, not guessed.
"""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ORIG, LOD, PREFIX = argv[0], argv[1], argv[2]
GAP = float(argv[3]) if len(argv) > 3 else 18.0
RES_X, RES_Y, LENS, SENSOR = 1800, 800, 50.0, 36.0

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
for eng in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
print("[RENDER] engine=%s blender=%s" % (sc.render.engine, bpy.app.version_string))


def bring_in(path, tag):
    have = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o.name not in have]
    roots = [(o, o.location.copy()) for o in new if o.parent is None]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons)
               for o in new if o.type == 'MESH')
    print("[RENDER] %-9s %s  %d objects (%d roots)  %d tris"
          % (tag, os.path.basename(path), len(new), len(roots), tris))
    return new, roots, tris


a_objs, a_roots, a_tris = bring_in(ORIG, "ORIGINAL")
b_objs, b_roots, b_tris = bring_in(LOD, "LOD")


def place(roots, off):
    for o, home in roots:
        o.location = home + off
    bpy.context.view_layer.update()


def corners(objs):
    out = []
    for o in objs:
        if o.type != 'MESH':
            continue
        for c in o.bound_box:
            out.append(o.matrix_world @ Vector(c))
    return out


place(a_roots, Vector((0, 0, 0)))
place(b_roots, Vector((0, 0, 0)))
pts = corners(a_objs)
lo = Vector((min(p[i] for p in pts) for i in range(3)))
hi = Vector((max(p[i] for p in pts) for i in range(3)))
size = hi - lo
print("[RENDER] single-airframe bbox %s .. %s" % ([round(v, 2) for v in lo],
                                                  [round(v, 2) for v in hi]))

aim = bpy.data.objects.new("AIM", None)
sc.collection.objects.link(aim)
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = LENS
cam_data.sensor_width = SENSOR
cam_data.sensor_fit = 'HORIZONTAL'
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
tc = cam.constraints.new('TRACK_TO')
tc.target = aim
tc.track_axis = 'TRACK_NEGATIVE_Z'
tc.up_axis = 'UP_Y'

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(52), 0.0, math.radians(35))
sc.collection.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", 'SUN'))
fill.data.energy = 1.7
fill.rotation_euler = (math.radians(68), 0.0, math.radians(215))
sc.collection.objects.link(fill)
sc.world = bpy.data.worlds.new("W")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.57, 0.64, 0.74, 1.0)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.85

sc.render.resolution_x = RES_X
sc.render.resolution_y = RES_Y
sc.render.image_settings.file_format = 'PNG'

TAN_H = (SENSOR * 0.5) / LENS
TAN_V = TAN_H * (float(RES_Y) / float(RES_X))


def solve_distance(target, d, pts_all, margin=1.10):
    """Smallest camera distance along +d from `target` that keeps every point
    inside the frustum. Solved from the sensor, not guessed."""
    right = d.cross(Vector((0, 0, 1)))
    if right.length < 1e-6:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(-d).normalized()
    need = 0.0
    for p in pts_all:
        v = p - target
        depth = v.dot(d)          # + = toward the camera
        x = abs(v.dot(right))
        y = abs(v.dot(up))
        need = max(need, depth + x / TAN_H, depth + y / TAN_V)
    return need * margin


def label(text, at, rot, h):
    cu = bpy.data.curves.new(text, type='FONT')
    cu.body = text
    cu.size = h
    cu.align_x = 'CENTER'
    ob = bpy.data.objects.new("L_" + text[:10], cu)
    sc.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = rot
    mat = bpy.data.materials.new("lbl")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (0.03, 0.03, 0.05, 1)
    ob.data.materials.append(mat)
    return ob


VIEWS = {
    "34front": Vector((0.80, 0.95, 0.40)),
    "profile": Vector((1.00, 0.00, 0.12)),
    "34rear": Vector((0.85, -0.80, 0.26)),
    "topdown": Vector((0.10, 0.08, 1.00)),
}

for vname, vdir in VIEWS.items():
    d = vdir.normalized()
    right = d.cross(Vector((0, 0, 1)))
    if right.length < 1e-6:
        right = Vector((1, 0, 0))
    right.normalize()
    off = right * (GAP * 0.5)
    # ORIGINAL must land on the LEFT of frame. Screen-right is -right here
    # (the camera looks back along d, which flips the handedness).
    place(a_roots, off)
    place(b_roots, -off)
    pts_all = corners(a_objs + b_objs)
    mid = Vector(((min(p[i] for p in pts_all) + max(p[i] for p in pts_all)) * 0.5
                  for i in range(3)))
    aim.location = mid
    # provisional label placement needs the camera basis, so solve distance first
    dist = solve_distance(mid, d, pts_all)
    cam.location = mid + d * dist
    bpy.context.view_layer.update()
    cam_rot = cam.matrix_world.to_euler()          # TRACK_TO lives here, NOT in rotation_euler
    cam_up = cam.matrix_world.to_3x3().col[1].normalized()
    drop = -cam_up * (size.z * 0.62 + dist * 0.035)
    hgt = dist * 0.026
    labels = [label("ORIGINAL   %d tris" % a_tris, mid + off + drop, cam_rot, hgt),
              label("LOD   %d tris" % b_tris, mid - off + drop, cam_rot, hgt)]
    # labels widen the scene - reframe once with them included
    dist = solve_distance(mid, d, pts_all + corners(labels))
    cam.location = mid + d * dist
    bpy.context.view_layer.update()
    out = "%s_%s.png" % (PREFIX, vname)
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("[RENDER] wrote %s   cam=%s dist=%.1f" % (out, [round(v, 1) for v in cam.location], dist))
    for lb in labels:
        bpy.data.objects.remove(lb, do_unlink=True)
