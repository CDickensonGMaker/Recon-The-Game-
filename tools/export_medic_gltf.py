"""Export the medic as a Godot-ready .glb, matching the other 7 units' contract.

  * join all armature-skinned body/gear meshes into one mesh
  * bone-parent the constrained items (M14 -> RightHand, bottle+cap -> Head)
  * feet at origin, exactly 1.7132 m tall, faces -Z, no colliders
  * 21 animations named like the sprite clips, root motion stripped
  * sockets MuzzlePoint / HandR / HandL / Head / Chest as empties
  * procedural materials flattened; image textures (face, insect-repellent label) kept

Run headless (never saves the .blend):
    blender -b unit_us_medic.blend -P export_medic_gltf.py
"""
import bpy, os
from mathutils import Vector, Matrix

OUT = r"C:\Users\caleb\RECONgame\assets\us\characters\us_medic.glb"
TARGET_HEIGHT = 1.7132
RIG = 'MixamoRig'
SOCKETS = {'HandR': 'mixamorig:RightHand', 'HandL': 'mixamorig:LeftHand',
           'Head': 'mixamorig:Head', 'Chest': 'mixamorig:Spine2'}
sc = bpy.context.scene
rig = bpy.data.objects[RIG]


def fcurves_of(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return []
    return list(act.layers[0].strips[0].channelbag(act.slots[0]).fcurves)


def strip_root_motion():
    n = 0
    for act in bpy.data.actions:
        bag = act.layers[0].strips[0].channelbag(act.slots[0])
        for fc in list(bag.fcurves):
            if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
                bag.fcurves.remove(fc); n += 1
    return n


def classify():
    skinned, constrained = [], []
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        has_arm = any(m.type == 'ARMATURE' for m in o.modifiers)
        has_childof = any(c.type == 'CHILD_OF' for c in o.constraints)
        if has_childof:
            constrained.append(o)
        elif has_arm:
            skinned.append(o)
        else:
            # loose mesh parented to nothing skinned - fold into skinned via its groups
            skinned.append(o)
    return skinned, constrained


def bone_parent(o, bone):
    sc.frame_set(1)
    bpy.context.view_layer.update()
    world = o.matrix_world.copy()
    for c in list(o.constraints):
        if c.type == 'CHILD_OF':
            c.mute = True
    bpy.context.view_layer.update()
    o.constraints.clear()
    o.parent = rig
    o.parent_type = 'BONE'
    o.parent_bone = bone
    bpy.context.view_layer.update()
    o.matrix_world = world
    bpy.context.view_layer.update()
    return (o.matrix_world.translation - world.translation).length


def _colors(nt):
    cols = []
    for n in nt.nodes:
        if n.type == 'VALTORGB':
            cols += [tuple(e.color[:3]) for e in n.color_ramp.elements]
        elif n.type == 'MIX' and getattr(n, 'data_type', '') == 'RGBA':
            for k in ('A', 'B'):
                if k in n.inputs and not n.inputs[k].is_linked:
                    cols.append(tuple(n.inputs[k].default_value[:3]))
    return cols


def flatten(m):
    if not m or not m.use_nodes:
        return 'skip'
    nt = m.node_tree
    b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not b:
        return 'no-bsdf'
    nrm = b.inputs.get('Normal')
    if nrm and nrm.is_linked:
        for l in list(nrm.links):
            nt.links.remove(l)
    bc = b.inputs['Base Color']
    if not bc.is_linked:
        return 'flat'
    if bc.links[0].from_node.type == 'TEX_IMAGE':
        return 'image (kept)'
    cols = _colors(nt)
    avg = (tuple(sum(c[i] for c in cols) / len(cols) for i in range(3))
           if cols else (0.35, 0.36, 0.28))
    for l in list(bc.links):
        nt.links.remove(l)
    bc.default_value = (*avg, 1.0)
    return f'flat ({avg[0]:.2f},{avg[1]:.2f},{avg[2]:.2f})'


def make_sockets():
    made = []
    for name, bone in SOCKETS.items():
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = 'ARROWS'; e.empty_display_size = 0.06
        sc.collection.objects.link(e)
        e.parent = rig; e.parent_type = 'BONE'; e.parent_bone = bone
        bpy.context.view_layer.update()
        pb = rig.pose.bones[bone]
        e.matrix_world = rig.matrix_world @ pb.matrix
        made.append(e)
    return made


def body_bbox(mesh_obj):
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    ev = mesh_obj.evaluated_get(dg); me = ev.to_mesh()
    for v in me.vertices:
        w = ev.matrix_world @ v.co
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ev.to_mesh_clear()
    return mn, mx


# ================================================================= run
print("=== purge cameras + lights ===", flush=True)
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'):
        bpy.data.objects.remove(o, do_unlink=True)
print(f"  meshes left: {[o.name for o in bpy.data.objects if o.type=='MESH']}", flush=True)

print("=== strip root motion ===", flush=True)
print(f"  removed {strip_root_motion()} Hips X/Z curves", flush=True)

print("=== classify meshes ===", flush=True)
rig.data.pose_position = 'REST'
if rig.animation_data:
    rig.animation_data.action = None
bpy.context.view_layer.update()
skinned, constrained = classify()
print(f"  skinned (join): {[o.name for o in skinned]}", flush=True)
print(f"  constrained (bone-parent): {[o.name for o in constrained]}", flush=True)

print("=== join skinned body ===", flush=True)
bpy.ops.object.select_all(action='DESELECT')
body = next(o for o in skinned if o.name == 'US_Grunt_Rigged')
for o in skinned:
    o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'Medic_Body'; body.data.name = 'Medic_Body'
print(f"  joined -> Medic_Body ({len(body.data.vertices)} verts, {len(body.data.materials)} mats)", flush=True)

print("=== bone-parent gun + bottle ===", flush=True)
GUNMAP = {'M14_Rifle': 'mixamorig:RightHand',
          'med_bottle': 'mixamorig:Head', 'med_bottle_cap': 'mixamorig:Head'}
for name, bone in GUNMAP.items():
    o = bpy.data.objects.get(name)
    if o:
        z_before = o.matrix_world.translation.z
        d = bone_parent(o, bone)
        z_after = o.matrix_world.translation.z
        print(f"  {name:16s} -> {bone.split(':')[1]:10s} drift {d*1000:.3f}mm  z {z_before:.3f}->{z_after:.3f}", flush=True)
# rename muzzle empty and re-parent to the M14 so it tracks the gun through anims
mz = bpy.data.objects.get('muzzle_m14') or bpy.data.objects.get('muzzle_m16a1')
if mz:
    mz.name = 'MuzzlePoint'
    m14 = bpy.data.objects.get('M14_Rifle')
    if m14:
        world = mz.matrix_world.copy()
        mz.parent = m14
        mz.matrix_parent_inverse = m14.matrix_world.inverted()
        bpy.context.view_layer.update()
        mz.matrix_world = world
        bpy.context.view_layer.update()
    print(f"  muzzle -> MuzzlePoint (parent {mz.parent.name if mz.parent else None})", flush=True)

print("=== flatten materials ===", flush=True)
for m in bpy.data.materials:
    print(f"  {m.name:20s} {flatten(m)}", flush=True)

print("=== sockets ===", flush=True)
make_sockets()
print(f"  {list(SOCKETS)}", flush=True)

print("=== normalize (feet->origin, 1.7132m) ===", flush=True)
mn, mx = body_bbox(body)
h = mx.z - mn.z
s = TARGET_HEIGHT / h
cx, cy = (mn.x+mx.x)/2, (mn.y+mx.y)/2
M = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-cx, -cy, -mn.z)))
# transform only roots; children (gun/bottle bone-parented, sockets, muzzle) follow the rig.
# include ANY unparented object (mesh or stray empty) so nothing is left at the wrong scale.
roots = [rig] + [o for o in bpy.data.objects
                 if o.parent is None and o is not rig]
for o in roots:
    o.matrix_world = M @ o.matrix_world
bpy.context.view_layer.update()
mn2, mx2 = body_bbox(body)
print(f"  {h:.3f} -> {mx2.z-mn2.z:.4f} m (x{s:.3f})  feet z={mn2.z:.4f}", flush=True)
bz = bpy.data.objects.get('med_bottle')
if bz:
    print(f"  bottle z after normalize: {bz.matrix_world.translation.z:.3f}", flush=True)

print("=== export ===", flush=True)
# explicit export set: rig + everything parented (directly or via bone) to it, only.
export_set = {rig}
for o in bpy.data.objects:
    p = o
    while p is not None:
        if p is rig:
            export_set.add(o); break
        p = p.parent
for o in bpy.data.objects:
    o.hide_set(False); o.hide_viewport = False
bpy.ops.object.select_all(action='DESELECT')
for o in export_set:
    o.select_set(True)
print(f"  exporting {len(export_set)} objects: {sorted(o.name for o in export_set)}", flush=True)
bpy.context.view_layer.objects.active = rig
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_apply=True, export_yup=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_bake_animation=True, export_anim_single_armature=True,
    export_optimize_animation_size=True, export_skins=True, export_morph=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False, export_extras=True)

dg = bpy.context.evaluated_depsgraph_get()
tris = 0
ev = body.evaluated_get(dg); me = ev.to_mesh(); me.calc_loop_triangles()
tris = len(me.loop_triangles); ev.to_mesh_clear()
mb = os.path.getsize(OUT) / (1024*1024)
print(f"  us_medic.glb  {tris:,} body tris  {mb:.2f} MB  {len(bpy.data.actions)} anims", flush=True)
print("EXPORT COMPLETE (blend NOT saved)", flush=True)
