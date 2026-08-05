"""fix_pilot_rig_defects.py - the white pilot's stretched flight helmet and orphaned gore cap.

    blender -b -P tools/fix_pilot_rig_defects.py -- [--apply]

Two defects, both on the white pilot (PSXRig_pointman.001), both pre-existing:

  1. helmet_sph4_pilot carries Scale(1.0003, 1.0058, 1.1256) - 34.2 mm / 19.5% taller
     than the identical mesh on the black pilot. Object scale on worn gear is the same
     class of bug as the 1.13 that was removed from the M1 shells: it is invisible in
     the mesh and rides the object. Scale goes to 1.0 and the helmet is re-seated using
     the BLACK pilot as the template - he is the one that measures correct.

  2. cap_head_pilot has NO parent and an ARMATURE modifier pointing at nothing, while
     every other gore cap in the file is bound to its own rig. Blow the white pilot's
     head off and his head cap does not follow him.

Placement is solved in REST through bone_attach, never by hand-rolled matrices.
"""
import bpy, os, sys
from mathutils import Vector, Matrix

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from bone_attach import attach

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_PILOTRIG.blend")

WHITE_RIG = "PSXRig_pointman.001"
BLACK_RIG = "PSXRig_pilot_black"
HEAD = "mixamorig:Head"

bpy.ops.wm.open_mainfile(filepath=SRC)
for r in bpy.data.objects:
    if r.type == 'ARMATURE':
        r.data.pose_position = 'REST'
        if r.animation_data:
            r.animation_data.action = None
bpy.context.view_layer.update()


def bb(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def bone_head(rig_name):
    r = bpy.data.objects[rig_name]
    return r.matrix_world @ r.data.bones[HEAD].head_local


# ---------------------------------------------------------------- 1. the stretch
white = bpy.data.objects["helmet_sph4_pilot"]
black = bpy.data.objects["helmet_sph4_pilot_black"]
wlo, whi = bb(white)
blo, bhi = bb(black)
print("=== SPH-4 ===")
print("  before  white scale=%s height=%.4f | black scale=%s height=%.4f"
      % (tuple(round(v, 4) for v in white.scale), whi.z - wlo.z,
         tuple(round(v, 4) for v in black.scale), bhi.z - blo.z))

# the black pilot is correct - learn his helmet's offset from his own Head bone
offset = ((blo + bhi) / 2) - bone_head(BLACK_RIG)
print("  black helmet sits %s from his Head bone" % (tuple(round(v, 4) for v in offset),))

# scale only. His ORIENTATION is his own - a tilted helmet has a taller world-aligned
# bounding box, and copying the black pilot's rotation would silently re-aim his helmet
# to fix a number that was never measuring size in the first place.
white.scale = (1.0, 1.0, 1.0)
bpy.context.view_layer.update()
nlo, nhi = bb(white)
target_ctr = bone_head(WHITE_RIG) + offset
M = Matrix.Translation(target_ctr - (nlo + nhi) / 2) @ white.matrix_world
attach(white, bpy.data.objects[WHITE_RIG], HEAD, world=M)
bpy.context.view_layer.update()
nlo, nhi = bb(white)
print("  after   white scale=%s height=%.4f  centre=(%.4f, %.4f, %.4f)"
      % (tuple(round(v, 4) for v in white.scale), nhi.z - nlo.z,
         (nlo.x + nhi.x) / 2, (nlo.y + nhi.y) / 2, (nlo.z + nhi.z) / 2))

# ---------------------------------------------------------------- 2. the orphan cap
print("\n=== cap_head_pilot ===")
cap = bpy.data.objects["cap_head_pilot"]
sib = bpy.data.objects["cap_head_pilot_black"]
rig = bpy.data.objects[WHITE_RIG]
print("  before  parent=%s modifiers=%s vgroups=%d"
      % (cap.parent, [(m.type, getattr(m, 'object', None)) for m in cap.modifiers],
         len(cap.vertex_groups)))
print("  sibling parent=%s modifiers=%s vgroups=%d"
      % (sib.parent.name if sib.parent else None,
         [(m.type, m.object.name if getattr(m, 'object', None) else None) for m in sib.modifiers],
         len(sib.vertex_groups)))

keep = cap.matrix_world.copy()
if cap.name not in bpy.context.scene.collection.all_objects:
    try:
        bpy.context.scene.collection.objects.link(cap)
    except RuntimeError:
        pass
cap.parent = rig
cap.parent_type = 'OBJECT'
cap.matrix_parent_inverse = rig.matrix_world.inverted()
cap.matrix_world = keep
for m in list(cap.modifiers):
    if m.type == 'ARMATURE':
        m.object = rig
if not any(m.type == 'ARMATURE' for m in cap.modifiers):
    m = cap.modifiers.new("Armature", 'ARMATURE')
    m.object = rig
bpy.context.view_layer.update()
print("  after   parent=%s modifiers=%s vgroups=%d"
      % (cap.parent.name, [(m.type, m.object.name if getattr(m, 'object', None) else None)
                           for m in cap.modifiers], len(cap.vertex_groups)))

# ---------------------------------------------------------------- gates
print("\n=== GATES ===")
fail = []
# Size is the MESH's own dimensions, not the world bounding box - a rotated object has
# a taller world box while being exactly the same helmet. Comparing world boxes is what
# made the first run of this script "fail" a helmet that was already correct.
def local_dims(o):
    vs = [v.co for v in o.data.vertices]
    return Vector((max(v.x for v in vs) - min(v.x for v in vs),
                   max(v.y for v in vs) - min(v.y for v in vs),
                   max(v.z for v in vs) - min(v.z for v in vs)))


wd, bd = local_dims(white), local_dims(black)
print("  sph4 mesh dims: white (%.4f, %.4f, %.4f) vs black (%.4f, %.4f, %.4f)"
      % (wd.x, wd.y, wd.z, bd.x, bd.y, bd.z))
if abs(wd.z - bd.z) > 0.002:
    fail.append("sph4 mesh heights differ by %.1f mm" % (abs(wd.z - bd.z) * 1000))
if max(abs(v - 1.0) for v in white.scale) > 1e-4:
    fail.append("sph4 scale is still %s" % (tuple(white.scale),))
d = ((Vector(bb(white)[0]) + Vector(bb(white)[1])) / 2 - bone_head(WHITE_RIG)).length
print("  sph4 sits %.4f m from the white pilot's Head bone (black: %.4f)" % (d, offset.length))
if abs(d - offset.length) > 0.005:
    fail.append("sph4 offset from the bone differs from the black pilot's by %.1f mm"
                % (abs(d - offset.length) * 1000))
amod = [m for m in cap.modifiers if m.type == 'ARMATURE' and m.object is rig]
if not amod:
    fail.append("cap_head_pilot still has no armature modifier bound to %s" % WHITE_RIG)
if cap.parent is not rig:
    fail.append("cap_head_pilot is still not parented to %s" % WHITE_RIG)
if len(cap.vertex_groups) == 0:
    fail.append("cap_head_pilot has NO vertex groups - binding it will not deform it")
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  all gates pass")

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
