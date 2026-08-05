"""Medical tent markers, DERIVED FROM THE MESH, not typed in.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\mark_medtent.py").read())
    mark()              # build/refresh the markers, no save
    mark(save=True)

Naming follows Caleb's 2026-08-03 ruling: work_<building>_<role> / prop_<building>_<thing>.
Nothing here is one letter from anything else here - that fault cost code in the chow hall
(mark_chowhall.py:126 carried a not-startswith guard because work_serve/work_server collided).

WHY THE GRID IS RAYCAST AND NOT A TABLE. `medical_complex` is ONE joined mesh (29448 verts,
20511 polys) - the cots are not separate objects, so there is nothing to parent to and no
origin to read. The cot lattice is recovered by casting DOWN in OBJECT space onto candidate
slots and keeping the ones that land on a cot surface instead of on the floor. Re-run this
after any edit to the complex and the markers follow the geometry.

THE CAST MUST START BELOW THE CANOPY. The tent canvas sits at local z ~2.70-2.85; a cast
from above hits the roof every time and reports 16 cots that are all fb_canvas. Start at 2.0.

THE COT CONTRACT, measured off `laying_idle` (anim_library.blend, 376 frames, 41 bones):
  hips   (0.000, -0.007, 0.116)      head y +0.563      feet y -0.966
  body Y-extent head..feet = 1.530 m ; hip travel over the whole clip 0.001 x / 0.004 y
  lowest body point = forearm z 0.020, so the clip's contact plane is z ~= 0.0
  elbow gate: 0 faults in 63 sampled frames
Mattress measured at 1.50 m long, flat, top at local z 0.575. Body 1.530 vs mattress 1.500
=> 15 mm overhang at each end when centred. The cot was built for this clip.

So the marker (which is the ARMATURE OBJECT ROOT, not the hips) goes at
    (cot_x, cot_y + BODY_MID_OFFSET, mattress_top)
with the body's +Y pointing at the head end. BODY_MID_OFFSET re-centres the man, because
the clip's root is at his hips, not at his middle: his midpoint sits 0.2005 m behind the root.

HEAD END. Both rows are laid the SAME way (not mirrored about the aisle) - the cot frame
timber extends past the mattress at +local Y on both rows and stops flush at -Y. That plus
the clip's own +Y head direction is the whole basis for HEAD_PLUS_Y. It is ONE constant:
flip it and all 16 cots turn round together.
"""
import bpy
import math
from mathutils import Vector, Matrix

COMPLEX = "medical_complex"
COLL = "WORKBENCH_medical_tent"

# --- the cot contract, all measured; see the docstring ---
MATTRESS_TOP = 0.575          # local z of the blanket surface
BODY_MID_OFFSET = 0.2005      # root -> body midpoint, along the body's +Y
HEAD_PLUS_Y = True            # head end is +local Y (see docstring)
COT_SURFACE_MIN = 0.40        # a cast landing above this is a cot, below it is the floor
CANOPY_CLEAR = 2.0            # cast from here: under the canvas, over the cots

# search lattice - generous; the raycast decides what is real
ROW_Y = (-5.136, 4.881)
X0, DX, NX = 13.752, -2.294, 10


def _complex():
    o = bpy.data.objects.get(COMPLEX)
    if o is None:
        raise RuntimeError("no %s in this file" % COMPLEX)
    return o


def find_cots(o):
    """Return [(local_x, local_y, surface_z, material)] for every real cot."""
    cots = []
    for ly in ROW_Y:
        for i in range(NX):
            lx = X0 + DX * i
            hit, loc, _n, idx = o.ray_cast(Vector((lx, ly, CANOPY_CLEAR)), Vector((0, 0, -1)))
            if not hit or loc.z < COT_SURFACE_MIN:
                continue
            mi = o.data.polygons[idx].material_index
            mat = o.data.materials[mi].name if o.data.materials[mi] else "-"
            cots.append((lx, ly, loc.z, mat))
    return cots


def _coll():
    c = bpy.data.collections.get(COLL)
    if c is None:
        c = bpy.data.collections.new(COLL)
        bpy.context.scene.collection.children.link(c)
    return c


def _empty(name, coll, size=0.25, kind='ARROWS'):
    """Replace by name so a re-run is idempotent and never leaves a .001 twin."""
    old = bpy.data.objects.get(name)
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    coll.objects.link(e)
    return e


def mark(save=False):
    o = _complex()
    MW = o.matrix_world
    coll = _coll()
    cots = find_cots(o)
    print("cots found: %d" % len(cots))

    yaw_body = 0.0 if HEAD_PLUS_Y else math.pi
    root = bpy.data.objects.get("work_med_root") or _empty("work_med_root", coll, 1.0, 'PLAIN_AXES')
    root.matrix_world = MW.copy()

    made = []
    for n, (lx, ly, sz, mat) in enumerate(sorted(cots, key=lambda c: (c[1], -c[0]))):
        dy = BODY_MID_OFFSET if HEAD_PLUS_Y else -BODY_MID_OFFSET
        local = Matrix.Translation(Vector((lx, ly + dy, MATTRESS_TOP))) @ \
            Matrix.Rotation(yaw_body, 4, 'Z')
        e = _empty("work_med_cot_%02d" % n, coll, 0.3, 'SINGLE_ARROW')
        e.matrix_world = MW @ local
        e["cot_surface_mat"] = mat
        e["cot_surface_z"] = round(sz, 4)
        e.parent = root
        e.matrix_parent_inverse = root.matrix_world.inverted()
        made.append(e)
    print("markers: %d" % len(made))
    check(made, o)
    if save:
        bpy.ops.wm.save_mainfile(compress=True)
        print("SAVED", bpy.data.filepath)
    return made


def check(made, o):
    """Gate on NUMBERS. Refuse to be believed without these."""
    bad = 0
    MWI = o.matrix_world.inverted()
    for e in made:
        L = MWI @ e.matrix_world
        p = L.to_translation()
        # 1. the root must sit exactly on the mattress
        if abs(p.z - MATTRESS_TOP) > 1e-4:
            print("  FAIL %s root z %.4f != %.4f" % (e.name, p.z, MATTRESS_TOP)); bad += 1
        # 2. head and feet must both land on the cot, not in the air
        fwd = L.to_quaternion() @ Vector((0, 1, 0))
        for tag, dist in (("head", 0.565), ("feet", -0.966)):
            q = p + fwd * dist
            hit, loc, _n, _i = o.ray_cast(Vector((q.x, q.y, CANOPY_CLEAR)), Vector((0, 0, -1)))
            if not hit or loc.z < COT_SURFACE_MIN:
                print("  FAIL %s %s end overhangs (%.2f,%.2f)" % (e.name, tag, q.x, q.y)); bad += 1
        # 3. no two men within body-spacing
        for f in made:
            if f is e:
                continue
            d = (f.matrix_world.to_translation() - e.matrix_world.to_translation()).length
            if d < 0.42:
                print("  FAIL %s/%s only %.3f m apart" % (e.name, f.name, d)); bad += 1
    print("  GATE: %s (%d failures over %d markers)" % ("PASS" if not bad else "FAIL", bad, len(made)))
    return bad == 0
