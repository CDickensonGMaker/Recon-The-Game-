"""Repeatable FP weapon grip for the PSX arms.

The RIGHT (trigger) hand is universal: it holds the same trigger-loop finger
pose in the same spot in front of the camera for every gun. Each gun carries a
`grip_R` empty at its trigger and a `grip_L` empty at its foregrip. To fit a new
weapon:

    import fp_grip
    fp_grip.lock_right_hand(arm)          # right hand -> the captured trigger pose
    fp_grip.fit_gun(arm, gun)             # slide the gun so its grip_R meets the hand
    fp_grip.snap_left(arm, gun)           # left hand -> the gun's grip_L (foregrip)

Reference pose (finger curls + hand-vs-gun offset) lives in rifle_grip.json,
captured from the hand-authored M14 pose.
"""
import bpy, json, os
from mathutils import Vector, Matrix, Quaternion

REF = r"C:\Users\caleb\RECONgame\assets\player\arms\rifle_grip.json"

def _load():
    with open(REF) as f:
        return json.load(f)

def _set_ik(arm, name, world_mat):
    pb = arm.pose.bones[name]
    pb.matrix = arm.matrix_world.inverted() @ world_mat

def _apply_fingers(arm, side, ref):
    for bn, q in ref['fingers'].items():
        if not bn.endswith('.' + side):
            continue
        pb = arm.pose.bones.get(bn)
        if pb:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = Quaternion(q)

def add_grip_nodes(gun, grip_R_local, grip_L_local):
    """Place grip_R_<gun> / grip_L_<gun> empties on a gun from local matrices."""
    for tag, mat in (('grip_R', grip_R_local), ('grip_L', grip_L_local)):
        nm = f'{tag}_{gun.name}'
        old = bpy.data.objects.get(nm)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        e = bpy.data.objects.new(nm, None)
        e.empty_display_type = 'ARROWS'
        e.empty_display_size = 0.04
        bpy.context.scene.collection.objects.link(e)
        e.parent = gun
        e.matrix_parent_inverse = Matrix.Identity(4)
        e.matrix_world = gun.matrix_world @ Matrix(mat)
    return f'grip_R_{gun.name}', f'grip_L_{gun.name}'

def lock_right_hand(arm, ref=None):
    """Right hand -> the universal trigger-loop pose, at the captured world spot."""
    ref = ref or _load()
    # the captured right-hand world transform (from the M14 authoring) is the anchor
    world = Matrix(ref['grip_R_world']) if 'grip_R_world' in ref else None
    if world is None:
        # fall back: derive from grip_R_local relative to the M14 if present
        m14 = bpy.data.objects.get('M14_Rifle')
        world = m14.matrix_world @ Matrix(ref['grip_R_local'])
    _set_ik(arm, 'handIK.R', world)
    _apply_fingers(arm, 'R', ref)
    bpy.context.view_layer.update()

def fit_gun(arm, gun):
    """Slide+rotate the gun so its grip_R_<gun> empty meets handIK.R."""
    node = bpy.data.objects.get(f'grip_R_{gun.name}')
    if node is None:
        raise RuntimeError(f'no grip_R node on {gun.name}; call add_grip_nodes first')
    hand = arm.matrix_world @ arm.pose.bones['handIK.R'].matrix
    # current node world = gun.matrix_world @ node_local ; we want node world == hand
    node_local = gun.matrix_parent_inverse @ Matrix(node.matrix_basis) if node.parent else node.matrix_world
    # simplest: move the gun by the delta so the node lands on the hand
    delta = hand.to_translation() - node.matrix_world.to_translation()
    gun.location += delta
    bpy.context.view_layer.update()

def snap_left(arm, gun, ref=None):
    """Left hand -> the gun's grip_L foregrip node + left finger curls."""
    ref = ref or _load()
    node = bpy.data.objects.get(f'grip_L_{gun.name}')
    if node is None:
        raise RuntimeError(f'no grip_L node on {gun.name}')
    _set_ik(arm, 'handIK.L', node.matrix_world)
    _apply_fingers(arm, 'L', ref)
    bpy.context.view_layer.update()
