"""M16 charge handle re-seat, v2 (minimal-change, measured).

Facts: rail X is 24deg off the bore axis; handle centroid rides 3.8cm left of
the bore plane; the handle's clips key LOCATION ONLY (slide on parent X), so
all rotation junk is object-level. The handle is ROUGHLY in place (right
station along the receiver, right height), so the nearest axis-mapping of the
bore frame is the unambiguous seat orientation.

Act: rail basis := bore frame at the handle origin; handle := same origin+basis
(rel identity), translated so its centroid sits on the bore vertical plane.
Verify, then save (save_versions=0). ABORTS unsaved on any verify failure.
"""
import bpy
from itertools import permutations, product
from mathutils import Vector, Matrix

bpy.context.preferences.filepaths.save_version = 0
sc = bpy.context.scene

gun = bpy.data.objects["M16A1_gun"]
rail = bpy.data.objects["M16A1_ch_rail"]
handle = bpy.data.objects["M16A1_charge_handle_slide_back"]
muz = bpy.data.objects["muzzle_M16A1"].matrix_world.translation.copy()

for a in bpy.data.actions:
    a.use_frame_range = False

# --- bore axis (same slice fit, verified twice already) -----------------------
dg = bpy.context.evaluated_depsgraph_get()
ev = gun.evaluated_get(dg)
m = ev.matrix_world
me = ev.to_mesh()
gv = [m @ v.co for v in me.vertices]
ev.to_mesh_clear()
b1 = [v for v in gv if -0.92 < v.y < -0.80 and abs(v.z - muz.z) < 0.02]
b2 = [v for v in gv if -0.62 < v.y < -0.50 and abs(v.z - muz.z) < 0.02]
axis_back = ((sum(b2, Vector()) / len(b2)) - (sum(b1, Vector()) / len(b1))).normalized()
side = axis_back.cross(Vector((0, 0, 1))).normalized()
print(f"bore axis (back) = ({axis_back.x:+.4f},{axis_back.y:+.4f},{axis_back.z:+.4f})")

# bore frame: X = pull direction (back), Z = up
X = axis_back.copy()
Z = Vector((0, 0, 1))
Z = (Z - X * Z.dot(X)).normalized()
Y = Z.cross(X)
B = Matrix((X, Y, Z)).transposed()   # columns are the frame axes

# --- current state -------------------------------------------------------------
W = handle.matrix_world.copy()
R_cur = W.to_3x3().normalized()
c_local = sum((v.co for v in handle.data.vertices), Vector()) / len(handle.data.vertices)
cen_cur = W @ c_local
lat_cur = (cen_cur - muz).dot(side)
print(f"handle centroid now ({cen_cur.x:+.3f},{cen_cur.y:+.3f},{cen_cur.z:+.3f}), lateral {lat_cur*100:+.1f} cm")

# local mesh bbox: confirm the mesh is modeled axis-aligned in its own space
los = [min(v.co[i] for v in handle.data.vertices) for i in range(3)]
his = [max(v.co[i] for v in handle.data.vertices) for i in range(3)]
dims = [his[i] - los[i] for i in range(3)]
print(f"handle local dims = ({dims[0]:.3f},{dims[1]:.3f},{dims[2]:.3f})")

# --- nearest axis-mapping of the bore frame -------------------------------------
best = None
for perm in permutations(range(3)):
    for signs in product((1, -1), repeat=3):
        P = Matrix(((0,0,0),(0,0,0),(0,0,0)))
        for r in range(3):
            P[r][perm[r]] = signs[r]
        if Matrix(P).determinant() < 0.5:
            continue
        R_t = B @ Matrix(P)
        ang = (R_t.transposed() @ R_cur).to_quaternion().angle
        if best is None or ang < best[0]:
            best = (ang, R_t)
ang, R_new = best
print(f"nearest seat orientation is {ang*57.2958:.1f} deg away from current")
if ang * 57.2958 > 45.0:
    raise SystemExit("VERIFY FAIL: nearest candidate >45 deg away - ambiguous, NOT fixing")

# --- new transforms --------------------------------------------------------------
cen_target = cen_cur - side * lat_cur          # slide onto the bore plane, keep station+height
t_new = cen_target - R_new @ c_local
M_new = R_new.to_4x4()
M_new.translation = t_new

rail.matrix_parent_inverse = Matrix.Identity(4)
rail.matrix_world = M_new
bpy.context.view_layer.update()
handle.matrix_parent_inverse = Matrix.Identity(4)
handle.matrix_world = M_new
bpy.context.view_layer.update()

# --- verify ---------------------------------------------------------------------
rx = rail.matrix_world.to_3x3().col[0].normalized()
print(f"rail X vs bore: {rx.angle(axis_back)*57.2958:.3f} deg")
rel = rail.matrix_world.inverted() @ handle.matrix_world
e = rel.to_euler()
print(f"handle rel-rail: loc=({rel.translation.x:+.4f},{rel.translation.y:+.4f},{rel.translation.z:+.4f}) rot=({e.x:+.3f},{e.y:+.3f},{e.z:+.3f})")
cen_after = handle.matrix_world @ c_local
lat_after = (cen_after - muz).dot(side)
print(f"handle centroid after ({cen_after.x:+.3f},{cen_after.y:+.3f},{cen_after.z:+.3f}), lateral {lat_after*100:+.2f} cm")
if rx.angle(axis_back) * 57.2958 > 0.1 or abs(lat_after) > 0.003 or max(abs(e.x), abs(e.y), abs(e.z)) > 0.001:
    raise SystemExit("VERIFY FAIL: static seat wrong, NOT saving")
if (cen_after - cen_cur).length > 0.08:
    raise SystemExit("VERIFY FAIL: centroid moved more than 8cm, NOT saving")

# under animation: rotation must stay zero, slide must stay pure X
objs = list(bpy.data.collections["RIG_M16A1"].objects)
for tname in ("rifle_idle", "reload_empty"):
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != tname)
    for f in (0, 40, 80):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        d = bpy.context.evaluated_depsgraph_get()
        hw = handle.evaluated_get(d).matrix_world
        rw = rail.evaluated_get(d).matrix_world
        r2 = rw.inverted() @ hw
        e2 = r2.to_euler()
        print(f"  {tname} f{f}: rel loc=({r2.translation.x:+.4f},{r2.translation.y:+.4f},{r2.translation.z:+.4f}) rot=({e2.x:+.3f},{e2.y:+.3f},{e2.z:+.3f})")
        if max(abs(e2.x), abs(e2.y), abs(e2.z)) > 0.01:
            raise SystemExit("VERIFY FAIL: rotated under animation, NOT saving")
        if abs(r2.translation.y) > 0.005 or abs(r2.translation.z) > 0.005:
            raise SystemExit("VERIFY FAIL: slide is not pure X, NOT saving")

bpy.ops.wm.save_mainfile()
print(f"SAVED {bpy.data.filepath}")
