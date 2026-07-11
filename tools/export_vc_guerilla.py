"""Export us_grunt_v2 as a Godot-ready .glb.

Engine contract (same as export_units_gltf.py — do not drift):
  * origin at the FEET, y=0; exactly 1.7132 m tall (helmet top)
  * faces -Z in Godot (units face -Y in Blender; export_yup maps it)
  * animations = ONLY the rifle_reel strip set, "_fixed" suffix stripped,
    so the engine sees clean names (reloading, firing_rifle, idle_aiming...)
  * root motion stripped on Hips X/Z (engine drives velocity; Y kept so
    deaths drop, crouches lower, jumps rise)
  * sockets as empties: MuzzlePoint (bore = -Z in Godot) + HandR/HandL/Head/Chest
  * procedural node materials flattened to representative colors (glTF can't
    export noise/ramp trees — this is why the helmet came out white)

Never saves the .blend.
    blender -b art_source/characters/base_psx/vc_guerilla_v2.blend -P tools/export_vc_guerilla.py
"""
import bpy, os, math, sys
from mathutils import Vector, Matrix, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_head_frags import build_head_frags
import append_gun

# variant args:  -- <gun> <out_name> <face_cell> [mesh_only]
# defaults reproduce the AK guerilla. <gun> is either a gun object in the
# master blend (all four ship there; the chosen one stays, the others are
# deleted from the export copy) or an armory key from append_gun.GUNS
# (e.g. 'rpg2'), which appends the gun and attaches it AK-style.
argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
GUN = argv[0] if argv else 'ak47_world'
OUTNAME = argv[1] if len(argv) > 1 else 'vc_guerilla'
FACE = argv[2] if len(argv) > 2 else 'vnm_mid'
MESH_ONLY = 'mesh_only' in argv[3:]

ALL_GUNS = ["ak47_world", "mosin_world", "ppsh_world", "rpd_world"]
FACES_V2 = {"vnm_older": (6,6,90,126), "vnm_mid": (102,6,186,126), "vnm_young": (198,6,282,126),
            "vnm_woman": (300,10,378,120), "nva_1": (102,390,186,510), "nva_2": (198,390,282,510)}

OUT = rf"C:\Users\caleb\RECONgame\assets\models\characters\{OUTNAME}.glb"
TARGET_HEIGHT = 1.7132
# Set False once the engine plays clips from the shared anim_library.glb —
# the export then ships meshes/skeleton/sockets only and takes seconds.
# The shipped roster (vc_guerilla/_mosin/_ppsh/_rpd) still bakes clips; NEW
# gun variants pass 'mesh_only' (probe-proven: tests/test_anim_library.tscn).
EXPORT_ANIMATIONS = not MESH_ONLY
RIG = "PSXRig"
SOCKETS = {
    'HandR': 'mixamorig:RightHand',
    'HandL': 'mixamorig:LeftHand',
    'Head':  'mixamorig:Head',
    'Chest': 'mixamorig:Spine2',
}

sc = bpy.context.scene
rig = bpy.data.objects[RIG]
IS_ARMORY_GUN = GUN not in ALL_GUNS
if IS_ARMORY_GUN:
    # armory key: append + attach exactly like the AK, drop all native guns
    gun = append_gun.bring(GUN, ref_gun='ak47_world', rig=rig)
    EXCLUDE = list(ALL_GUNS)
else:
    gun = bpy.data.objects[GUN]
    EXCLUDE = [g for g in ALL_GUNS if g != GUN]

# Drop the guns this variant doesn't carry (export copy only).
print(f"=== 0. variant {OUTNAME}: gun={gun.name} face={FACE} anims={EXPORT_ANIMATIONS} ===", flush=True)
for name in EXCLUDE:
    o = bpy.data.objects.get(name)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
    a = bpy.data.actions.get(f"{name}_visibility_reel")
    if a:
        a.use_fake_user = False
        bpy.data.actions.remove(a)
print(f"  removed {len(EXCLUDE)} other guns", flush=True)

# per-variant face: remap the face-patch polys onto the chosen atlas cell
px0, py0, px1, py1 = FACES_V2[FACE]
_AW, _AH = 576.0, 640.0
_u0, _u1 = px0/_AW, px1/_AW
_vt, _vb = 1 - py0/_AH, 1 - py1/_AH
fam = bpy.data.materials.get("face_atlas_mat")
for hname in ("vc_head", "grunt_head"):
    ho = bpy.data.objects.get(hname)
    if not ho or fam is None:
        continue
    hme = ho.data
    fam_idx = next((i for i, s in enumerate(ho.material_slots) if s.material == fam), None)
    if fam_idx is None or not hme.uv_layers:
        continue
    fps = [p for p in hme.polygons if p.material_index == fam_idx]
    if not fps:
        continue
    xs = [hme.vertices[i].co.x for p in fps for i in p.vertices]
    zs = [hme.vertices[i].co.z for p in fps for i in p.vertices]
    X0, X1, Z0, Z1 = min(xs), max(xs), min(zs), max(zs)
    uvl = hme.uv_layers[0]
    for p in fps:
        for li in range(p.loop_start, p.loop_start + p.loop_total):
            c = hme.vertices[hme.loops[li].vertex_index].co
            a_ = (c.x - X0) / (X1 - X0)
            b_ = (c.z - Z0) / (Z1 - Z0)
            uvl.data[li].uv = (_u0 + a_*(_u1-_u0), _vb + b_*(_vt - _vb))
    hme.update()
    print(f"  {hname}: face -> {FACE}", flush=True)

# head fracture chunks (bead rc55) - after the face remap so the fragments
# inherit this variant's face UVs; skips cleanly on rigs without grunt_head
print("=== 0.5 head fragments (rc55) ===", flush=True)
build_head_frags()

# ---------------------------------------------------------------- actions
print("=== 1. reduce to reel actions, strip _fixed ===", flush=True)
track = rig.animation_data.nla_tracks["rifle_reel"]
keep = {s.action for s in track.strips if s.action} if EXPORT_ANIMATIONS else set()
for a in list(bpy.data.actions):
    if a not in keep:
        bpy.data.actions.remove(a)
if not EXPORT_ANIMATIONS:
    for tr in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(tr)
    rig.animation_data.action = None
for a in bpy.data.actions:
    if a.name.endswith("_fixed"):
        a.name = a.name[:-6]
print(f"  {len(bpy.data.actions)} clips", flush=True)

# gun visibility was reel-preview only; make sure the gun exports visible
if gun.animation_data:
    gun.animation_data_clear()
gun.hide_viewport = False
gun.hide_render = False

def channelbag(act):
    return act.layers[0].strips[0].channelbag(act.slots[0])

print("=== 2. strip root motion (Hips X/Z) ===", flush=True)
n = 0
for act in bpy.data.actions:
    bag = channelbag(act)
    for fc in list(bag.fcurves):
        if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
            bag.fcurves.remove(fc)
            n += 1
print(f"  removed {n} curves", flush=True)

# ---------------------------------------------------------------- sockets
print("=== 3. sockets ===", flush=True)
sc.frame_set(1)
bpy.context.view_layer.update()
made = []
for name, bone in SOCKETS.items():
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'ARROWS'
    e.empty_display_size = 0.06
    sc.collection.objects.link(e)
    e.parent = rig
    e.parent_type = 'BONE'
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = rig.matrix_world @ rig.pose.bones[bone].matrix
    made.append(e)

# MuzzlePoint: child of the gun, at the bbox end farthest from the grip hand,
# local +Y (Blender) down the bore -> -Z in Godot
old = bpy.data.objects.get("MuzzlePoint")
if old:
    bpy.data.objects.remove(old, do_unlink=True)
mz = bpy.data.objects.new("MuzzlePoint", None)
mz.empty_display_type = 'ARROWS'
mz.empty_display_size = 0.06
sc.collection.objects.link(mz)
mz.parent = gun
bb = gun.bound_box
ext = [max(c[i] for c in bb) - min(c[i] for c in bb) for i in range(3)]
ax = ext.index(max(ext))
lo = Vector([min(c[i] for c in bb) for i in range(3)])
hi = Vector([max(c[i] for c in bb) for i in range(3)])
end_a, end_b = lo.copy(), lo.copy()
end_a[ax], end_b[ax] = lo[ax], hi[ax]
mid = (lo + hi) / 2
end_a[(ax+1)%3] = end_b[(ax+1)%3] = mid[(ax+1)%3]
end_a[(ax+2)%3] = end_b[(ax+2)%3] = mid[(ax+2)%3]
hand_w = rig.matrix_world @ rig.pose.bones[SOCKETS['HandR']].head
da = (gun.matrix_world @ end_a - hand_w).length
db = (gun.matrix_world @ end_b - hand_w).length
muzzle_local = end_a if da > db else end_b
bore = (muzzle_local - (end_b if da > db else end_a)).normalized()
if IS_ARMORY_GUN:
    # appended meshes keep the armory rack orientation: muzzle is ALWAYS the
    # -X end (the hand-distance heuristic flips on the RPG-2, whose grip is
    # near the front of the tube)
    muzzle_local, rear = (end_a, end_b) if end_a.x < end_b.x else (end_b, end_a)
    bore = (muzzle_local - rear).normalized()
mz.matrix_parent_inverse = Matrix.Identity(4)
mz.location = muzzle_local
mz.rotation_mode = 'QUATERNION'
mz.rotation_quaternion = Vector((0, 1, 0)).rotation_difference(bore)
made.append(mz)
print(f"  {len(made)} sockets (muzzle at gun-local {tuple(round(v,3) for v in muzzle_local)})", flush=True)

# ---------------------------------------------------------------- materials
print("=== 4. flatten procedural materials ===", flush=True)
def _collect_colors(nt):
    cols = []
    for nd in nt.nodes:
        if nd.type == 'VALTORGB':
            cols += [tuple(e.color[:3]) for e in nd.color_ramp.elements]
        elif nd.type == 'MIX' and getattr(nd, 'data_type', '') == 'RGBA':
            for k in ('A', 'B'):
                if k in nd.inputs and not nd.inputs[k].is_linked:
                    cols.append(tuple(nd.inputs[k].default_value[:3]))
        elif nd.type == 'MIX_RGB':
            for i in (1, 2):
                if not nd.inputs[i].is_linked:
                    cols.append(tuple(nd.inputs[i].default_value[:3]))
    return cols

for m in bpy.data.materials:
    if not m or not m.use_nodes:
        continue
    nt = m.node_tree
    bsdf = next((nd for nd in nt.nodes if nd.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        continue
    nrm = bsdf.inputs.get('Normal')
    if nrm and nrm.is_linked:
        for l in list(nrm.links):
            nt.links.remove(l)
    bc = bsdf.inputs['Base Color']
    if not bc.is_linked:
        continue
    if bc.links[0].from_node.type == 'TEX_IMAGE':
        print(f"  {m.name}: image kept", flush=True)
        continue
    cols = _collect_colors(nt)
    avg = (tuple(sum(c[i] for c in cols) / len(cols) for i in range(3))
           if cols else (0.35, 0.36, 0.28))
    for l in list(bc.links):
        nt.links.remove(l)
    bc.default_value = (*avg, 1.0)
    print(f"  {m.name}: flattened ({avg[0]:.2f},{avg[1]:.2f},{avg[2]:.2f})", flush=True)

# ---------------------------------------------------------------- normalize
print("=== 5. normalize height ===", flush=True)
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_set(False)

def body_bbox():
    """Bounds of the CHARACTER only: the vc_* body parts (head/torso/arms/
    legs/feet). Never the whole scene — gib donors and the gun would skew
    the box (that bug shipped once on the grunt; don't reintroduce it)."""
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.startswith("vc_"):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx

# measure in rest pose so animation state doesn't skew the bbox
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
mn, mx = body_bbox()
h = mx.z - mn.z
s = TARGET_HEIGHT / h
M = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(mn.x+mx.x)/2, -(mn.y+mx.y)/2, -mn.z)))
exportables = [o for o in bpy.data.objects if o.type in ('MESH', 'ARMATURE', 'EMPTY')]
names = {o.name for o in exportables}
roots = [o for o in exportables if o.parent is None or o.parent.name not in names]
for o in roots:
    o.matrix_world = M @ o.matrix_world
bpy.context.view_layer.update()
mn2, mx2 = body_bbox()
rig.data.pose_position = 'POSE'
bpy.context.view_layer.update()
print(f"  height {h:.4f} -> {mx2.z-mn2.z:.4f} m (x{s:.4f}), feet z {mn2.z:.5f}", flush=True)

# ---------------------------------------------------------------- export
print("=== 6. export ===", flush=True)
bpy.ops.object.select_all(action='DESELECT')
for o in exportables:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_animations=EXPORT_ANIMATIONS,
    export_animation_mode='ACTIONS',
    export_bake_animation=True,
    export_anim_single_armature=True,
    export_optimize_animation_size=True,
    export_skins=True,
    export_morph=False,
    export_materials='EXPORT',
    export_cameras=False,
    export_lights=False,
    export_draco_mesh_compression_enable=False,
    export_extras=True,
)
mb = os.path.getsize(OUT) / (1024 * 1024)
print(f"EXPORT COMPLETE -> {OUT}  {mb:.2f} MB  {len(bpy.data.actions)} clips  (blend NOT saved)", flush=True)
