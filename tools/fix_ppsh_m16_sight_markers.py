"""Fix the measured marker breaks in fp_arms_rifle.blend:

PPSh41: all three markers were never placed on the gun (muzzle mid-receiver,
        front sight behind the muzzle, rear sight floating near the left grip).
        Re-place them from mesh geometry: shroud tip, front blade top, rear
        notch top.
M16A1:  sight_rear sits ~3cm right of the bore plane and ~1.2cm high, yawing
        every marker align. Re-place it on the line through the front post
        parallel to the measured barrel axis (M16 sights are bore-parallel).

Also prints (read-only) the M16 charge-handle diagnostics and any non-identity
matrix_parent_inverse in the four finished rigs.

Measure -> act -> verify. Saves the .blend (save_versions=0, no .blend1).
"""
import bpy
from mathutils import Vector

bpy.context.preferences.filepaths.save_version = 0
sc = bpy.context.scene
EPS = 1e-6


def world_verts(objs, pred=None):
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(dg)
        m = ev.matrix_world
        me = ev.to_mesh()
        for v in me.vertices:
            w = m @ v.co
            if pred is None or pred(w):
                out.append(w.copy())
        ev.to_mesh_clear()
    return out


def centroid(pts):
    c = Vector((0, 0, 0))
    for p in pts:
        c += p
    return c / len(pts)


def place(marker_name, world_pos):
    o = bpy.data.objects[marker_name]
    before = o.matrix_world.translation.copy()
    m = o.matrix_world.copy()
    m.translation = world_pos
    o.matrix_world = m
    bpy.context.view_layer.update()
    after = o.matrix_world.translation
    print(f"  {marker_name}: ({before.x:+.3f},{before.y:+.3f},{before.z:+.3f}) -> "
          f"({after.x:+.3f},{after.y:+.3f},{after.z:+.3f})  (moved {(after-before).length:.3f} m)")
    if (after - world_pos).length > 0.001:
        raise SystemExit(f"VERIFY FAIL: {marker_name} did not land on target")


# ================= PPSh41 =================
print("\n===== PPSh41 markers =====")
coll = bpy.data.collections["RIG_PPSh41"]
guns = [o for o in coll.objects if o.type == 'MESH' and o.name.startswith("PPSh41_gun")]

allv = world_verts(guns)
ymin = min(v.y for v in allv)
ymax = max(v.y for v in allv)
print(f"  gun spans y {ymin:.3f}..{ymax:.3f} (front = min y)")

# barrel/bore: front-half verts at shroud height
barrel = [v for v in allv if v.y < ymin + 0.45 and 1.475 < v.z < 1.512]
if len(barrel) < 20:
    raise SystemExit(f"MEASURE FAIL: barrel slice has {len(barrel)} verts")
near = centroid([v for v in barrel if v.y < ymin + 0.15])
far = centroid([v for v in barrel if v.y > ymin + 0.25])
axis = (near - far).normalized()          # points forward (toward -y)
print(f"  bore axis (fwd) = ({axis.x:+.3f},{axis.y:+.3f},{axis.z:+.3f}) from {len(barrel)} verts")

# muzzle: front tip at bore height
tipv = [v for v in barrel if v.y < ymin + 0.02]
muzzle = centroid(tipv) if tipv else Vector((near.x, ymin, near.z))
muzzle.y = ymin
print(f"  muzzle target = ({muzzle.x:+.3f},{muzzle.y:+.3f},{muzzle.z:+.3f}) from {len(tipv)} tip verts")

# front sight: elevated verts near the front
fs = [v for v in allv if v.y < ymin + 0.15 and v.z > 1.512]
if not fs:
    raise SystemExit("MEASURE FAIL: no front-sight verts found")
fs_top = max(v.z for v in fs)
front = centroid([v for v in fs if v.z > fs_top - 0.004])
print(f"  front sight target = ({front.x:+.3f},{front.y:+.3f},{front.z:+.3f}) from {len(fs)} verts, top z {fs_top:.3f}")

# rear sight: elevated verts above the receiver, mid-rear
rs = [v for v in allv if ymin + 0.35 < v.y < ymin + 0.55 and v.z > 1.512]
if not rs:
    raise SystemExit("MEASURE FAIL: no rear-sight verts found")
rs_top = max(v.z for v in rs)
rear = centroid([v for v in rs if v.z > rs_top - 0.004])
print(f"  rear sight target = ({rear.x:+.3f},{rear.y:+.3f},{rear.z:+.3f}) from {len(rs)} verts, top z {rs_top:.3f}")

sight_vec = (front - rear).normalized()
ang = sight_vec.angle(axis)
print(f"  VERIFY sight line vs bore axis: {ang * 57.2958:.2f} deg (must be < 3)")
if ang * 57.2958 > 3.0:
    raise SystemExit("VERIFY FAIL: PPSh sight line not parallel to bore")

place("muzzle_PPSh41", muzzle)
place("sight_front_PPSh41", front)
place("sight_rear_PPSh41", rear)

# ================= M16A1 rear sight =================
print("\n===== M16A1 sight_rear =====")
gun = bpy.data.objects["M16A1_gun"]
front_mk = bpy.data.objects["sight_front_M16A1"].matrix_world.translation.copy()
rear_mk = bpy.data.objects["sight_rear_M16A1"].matrix_world.translation.copy()
muz_mk = bpy.data.objects["muzzle_M16A1"].matrix_world.translation.copy()

gv = world_verts([gun])
# barrel slices around the muzzle height, forward half of the gun
bz = muz_mk.z
b1 = [v for v in gv if -0.92 < v.y < -0.80 and abs(v.z - bz) < 0.02]
b2 = [v for v in gv if -0.62 < v.y < -0.50 and abs(v.z - bz) < 0.02]
if len(b1) < 10 or len(b2) < 10:
    raise SystemExit(f"MEASURE FAIL: M16 barrel slices {len(b1)}/{len(b2)} verts")
axis_b = (centroid(b2) - centroid(b1)).normalized()   # points backward (+y)
print(f"  barrel axis (back) = ({axis_b.x:+.3f},{axis_b.y:+.3f},{axis_b.z:+.3f}) from {len(b1)}+{len(b2)} verts")

L = (rear_mk - front_mk).dot(axis_b)
rear_new = front_mk + axis_b * L
print(f"  L along axis = {L:.3f} m")
off = rear_mk - rear_new
print(f"  current rear is off by ({off.x:+.3f},{off.y:+.3f},{off.z:+.3f})  |{off.length:.3f}| m")
place("sight_rear_M16A1", rear_new)

sv = (front_mk - rear_new).normalized()
ang2 = sv.angle(-axis_b)
print(f"  VERIFY M16 sight line vs bore: {ang2 * 57.2958:.2f} deg (must be < 0.5)")
if ang2 * 57.2958 > 0.5:
    raise SystemExit("VERIFY FAIL: M16 sight line not parallel to bore")

# ================= diagnostics (read-only) =================
print("\n===== parent-inverse audit (finished rigs) =====")
from mathutils import Matrix
for cn in ("RIG_M16A1", "RIG_AK47", "RIG_M14", "RIG_PPSh41"):
    c = bpy.data.collections.get(cn)
    if not c:
        continue
    for o in c.objects:
        if o.parent and (o.matrix_parent_inverse - Matrix.Identity(4)).median_scale is not None:
            pi = o.matrix_parent_inverse
            dev = max(abs(pi[i][j] - (1.0 if i == j else 0.0)) for i in range(4) for j in range(4))
            if dev > 1e-4:
                print(f"  {cn}/{o.name}: parent_inverse deviates {dev:.4f}")

print("\n===== M16 charge handle geometry =====")
rail = bpy.data.objects["M16A1_ch_rail"]
handle = bpy.data.objects["M16A1_charge_handle_slide_back"]
rail_x = rail.matrix_world.to_3x3().col[0].normalized()
print(f"  rail X (slide dir) vs bore axis: {rail_x.angle(axis_b) * 57.2958:.2f} deg "
      f"(and vs -bore: {rail_x.angle(-axis_b) * 57.2958:.2f})")
hv = world_verts([handle])
hc = centroid(hv)
print(f"  handle centroid world = ({hc.x:+.3f},{hc.y:+.3f},{hc.z:+.3f})  n={len(hv)} verts")
print(f"  handle rel-rail rot (rad): {tuple(round(a,3) for a in (rail.matrix_world.inverted() @ handle.matrix_world).to_euler())}")

bpy.ops.wm.save_mainfile()
print(f"\nSAVED {bpy.data.filepath} (save_versions=0)")
