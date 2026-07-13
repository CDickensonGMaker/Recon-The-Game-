"""Export each zoo unit as a Godot-ready .glb.

Contract (from the engine side - do not drift from these):
  * origin at the FEET, y=0
  * exactly 1.7132 m tall (== character_height_m in every sprite manifest,
    so 3D vs sprite is a true A/B and the HEAD hitzone at y=1.65 still lands)
  * faces -Z (Godot forward). In Blender the units face -Y; export_yup maps -Y -> -Z.
  * geometry only, no colliders (hitzones are procedural capsules)
  * animations named exactly like the sprite clips, so SpriteStateMap drives
    the models verbatim
  * root motion OFF - the engine drives velocity

Sockets exported as Empties (Godot: Node3D under the bone attachment):
  MuzzlePoint  barrel tip, -Z down the bore, parented to the weapon
  HandR HandL Head Chest   bone-parented, for runtime weapon/gear swap

Four things that silently break a naive export, all handled:
  1. Guns ride a CHILD_OF constraint - glTF has no constraints. Converted to a
     real BONE parent, world transform preserved.
  2. Materials are procedural noise/ramp trees - they export as flat white.
     Flattened to representative colours; image textures (faces) kept.
  3. Actions are shared across every rig. export_animation_mode='ACTIONS'
     emits each as a named glTF animation.
  4. Mixamo clips carry hip translation. Stripped on X/Z (kept on Y, so deaths
     still drop and crouches still lower).

Never saves the .blend.
    blender -b sprite_stage.blend -P export_units_gltf.py
"""
import bpy, sys, os
from mathutils import Vector, Matrix

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
from unit_registry import UNITS

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
TARGET_HEIGHT = 1.7132
HAND_BONE = 'mixamorig:RightHand'
SOCKETS = {                       # empty name -> bone
    'HandR': 'mixamorig:RightHand',
    'HandL': 'mixamorig:LeftHand',
    'Head':  'mixamorig:Head',
    'Chest': 'mixamorig:Spine2',
}
os.makedirs(OUT_DIR, exist_ok=True)
sc = bpy.context.scene


# ---------------------------------------------------------------- helpers
def fcurves_of(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return []
    return list(act.layers[0].strips[0].channelbag(act.slots[0]).fcurves)


def strip_root_motion():
    """Remove Hips X/Z location curves. Keep Y so deaths drop and crouches lower."""
    n = 0
    for act in bpy.data.actions:
        for fc in list(fcurves_of(act)):
            if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 1):
                # Blender bone-local: Y is along the bone (up the spine). X and Z are lateral.
                # Mixamo hips: index 0 = X lateral, 1 = Y along bone (vertical), 2 = Z fwd/back.
                pass
    # Blender pose-bone location is in BONE space. For mixamorig:Hips the bone points
    # +Y (up), so vertical == index 1, and the horizontal drift we want gone is 0 and 2.
    for act in bpy.data.actions:
        bag = act.layers[0].strips[0].channelbag(act.slots[0])
        for fc in list(bag.fcurves):
            if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
                bag.fcurves.remove(fc)
                n += 1
    return n


def bone_parent_gun(d):
    gun = bpy.data.objects.get(d['gun'])
    rig = bpy.data.objects.get(d['rig'])
    if not gun or not rig:
        return None
    sc.frame_set(15)
    bpy.context.view_layer.update()
    world = gun.matrix_world.copy()
    for c in list(gun.constraints):
        if c.type == 'CHILD_OF':
            gun.constraints.remove(c)
    gun.parent = rig
    gun.parent_type = 'BONE'
    gun.parent_bone = HAND_BONE
    bpy.context.view_layer.update()
    gun.matrix_world = world
    bpy.context.view_layer.update()
    return (gun.matrix_world.translation - world.translation).length


def make_sockets(unit, d):
    """Bone-parented empties. Named identically in every unit so code is generic."""
    rig = bpy.data.objects[d['rig']]
    made = []
    for name, bone in SOCKETS.items():
        obj_name = f"{name}"
        old = bpy.data.objects.get(obj_name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        e = bpy.data.objects.new(obj_name, None)
        e.empty_display_type = 'ARROWS'
        e.empty_display_size = 0.06
        sc.collection.objects.link(e)
        e.parent = rig
        e.parent_type = 'BONE'
        e.parent_bone = bone
        # sit the empty at the bone HEAD (Blender bone-parents to the tail)
        bpy.context.view_layer.update()
        pb = rig.pose.bones[bone]
        e.matrix_world = rig.matrix_world @ pb.matrix
        made.append(e)
    bpy.context.view_layer.update()
    return made


def _collect_colors(nt):
    cols = []
    for n in nt.nodes:
        if n.type == 'VALTORGB':
            cols += [tuple(e.color[:3]) for e in n.color_ramp.elements]
        elif n.type == 'MIX' and getattr(n, 'data_type', '') == 'RGBA':
            for k in ('A', 'B'):
                if k in n.inputs and not n.inputs[k].is_linked:
                    cols.append(tuple(n.inputs[k].default_value[:3]))
        elif n.type == 'MIX_RGB':
            for i in (1, 2):
                if not n.inputs[i].is_linked:
                    cols.append(tuple(n.inputs[i].default_value[:3]))
    return cols


def flatten_material(m):
    if not m or not m.use_nodes:
        return 'no-nodes'
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        return 'no-bsdf'
    nrm = bsdf.inputs.get('Normal')
    if nrm and nrm.is_linked:
        for l in list(nrm.links):
            nt.links.remove(l)
    bc = bsdf.inputs['Base Color']
    if not bc.is_linked:
        return 'flat'
    if bc.links[0].from_node.type == 'TEX_IMAGE':
        return 'image (kept)'
    cols = _collect_colors(nt)
    avg = (tuple(sum(c[i] for c in cols) / len(cols) for i in range(3))
           if cols else (0.35, 0.36, 0.28))
    for l in list(bc.links):
        nt.links.remove(l)
    bc.default_value = (*avg, 1.0)
    return f'flattened ({avg[0]:.2f},{avg[1]:.2f},{avg[2]:.2f})'


def unit_objects(u, include_sockets=True):
    d = UNITS[u]
    obs = []
    m = d['meshes']
    if isinstance(m, str):
        c = bpy.data.collections.get(m)
        if c:
            obs += [o for o in c.objects if o.type == 'MESH']
    else:
        obs += [bpy.data.objects[n] for n in m if n in bpy.data.objects]
    for extra in (d['gun'], f"muzzle_{d['weapon']}"):
        o = bpy.data.objects.get(extra)
        if o:
            obs.append(o)
    if include_sockets:
        obs += [bpy.data.objects[n] for n in SOCKETS if n in bpy.data.objects]
    rig = bpy.data.objects.get(d['rig'])
    if rig:
        obs.append(rig)
    return obs


def body_bbox(u):
    """Evaluated world AABB of the BODY meshes only (no gun)."""
    d = UNITS[u]
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in unit_objects(u, include_sockets=False):
        if o.type != 'MESH' or o.name == d['gun']:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


def normalize(u):
    """Move feet to the origin and scale to TARGET_HEIGHT. Transform only the
    roots - children (bone-parented gun, socket empties, parented meshes) follow."""
    objs = unit_objects(u)
    names = {o.name for o in objs}
    mn, mx = body_bbox(u)
    h = mx.z - mn.z
    s = TARGET_HEIGHT / h
    cx = (mn.x + mx.x) / 2.0
    cy = (mn.y + mx.y) / 2.0
    M = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-cx, -cy, -mn.z)))
    roots = [o for o in objs if o.parent is None or o.parent.name not in names]
    for o in roots:
        o.matrix_world = M @ o.matrix_world
    bpy.context.view_layer.update()
    mn2, mx2 = body_bbox(u)
    return h, s, (mx2.z - mn2.z), Vector(((mn2.x + mx2.x) / 2, (mn2.y + mx2.y) / 2, mn2.z))


def tri_count(u):
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in unit_objects(u, include_sockets=False):
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        ev.to_mesh_clear()
    return n


# ================================================================= run
print("=== 0. strip root motion (Hips X/Z) ===", flush=True)
print(f"  removed {strip_root_motion()} curves across {len(bpy.data.actions)} actions", flush=True)

print("\n=== 1. gun -> bone parent ===", flush=True)
for u, d in UNITS.items():
    drift = bone_parent_gun(d)
    tag = 'MISSING' if drift is None else ('ok ' if drift < 0.001 else '!! ')
    val = '' if drift is None else f'drift {drift*1000:.3f}mm'
    print(f"  {tag} {u:16s} {d['gun']:16s} {val}", flush=True)

print("\n=== 2. flatten materials ===", flush=True)
for m in bpy.data.materials:
    print(f"  {m.name:20s} {flatten_material(m)}", flush=True)

print("\n=== 3. rename muzzle empties -> MuzzlePoint ===", flush=True)
# one at a time; the name must be unique per export, so rename right before each
print(f"  {len([o for o in bpy.data.objects if o.name.startswith('muzzle_')])} muzzle empties found", flush=True)

print("\n=== 4. export ===", flush=True)
rig0 = bpy.data.objects[UNITS['us_grunt']['rig']]
print(f"  actions: {len(bpy.data.actions)}   bones: {len(rig0.data.bones)}", flush=True)

for u, d in UNITS.items():
    if bpy.data.objects.get(d['rig']) is None:
        print(f"  {u}: no rig, skipped"); continue

    make_sockets(u, d)
    h0, s, h1, feet = normalize(u)

    mz = bpy.data.objects.get(f"muzzle_{d['weapon']}")
    saved = None
    if mz:
        saved = mz.name
        mz.name = 'MuzzlePoint'

    for o in bpy.data.objects:
        o.hide_viewport = False
    bpy.ops.object.select_all(action='DESELECT')
    for o in unit_objects(u):
        o.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects[d['rig']]

    tris = tri_count(u)
    path = os.path.join(OUT_DIR, f"{u}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=True,
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
    if mz and saved:
        mz.name = saved

    mb = os.path.getsize(path) / (1024 * 1024)
    budget = 'OK' if tris <= 6000 else 'OVER'
    print(f"  {u:16s} h {h0:.3f}->{h1:.4f}m (x{s:.3f})  feet {tuple(round(v,4) for v in feet)}  "
          f"{tris:6,} tris [{budget}]  {mb:5.2f} MB", flush=True)

print(f"\nEXPORT COMPLETE -> {OUT_DIR}   (blend NOT saved)", flush=True)
