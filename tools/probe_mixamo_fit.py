"""Measure whether a downloaded Mixamo FBX fits the library rig.

    blender -b assets/shared/anim_library.blend -P tools/probe_mixamo_fit.py -- <fbx>

Prints the bone-name overlap both ways and the incoming action's frame range.
Saves nothing. A read of the FBX is a claim; this is the measurement.
"""
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not argv:
    print("[FIT] FATAL: no fbx given")
    sys.exit(1)
fbx = os.path.abspath(argv[0])

lib_rigs = [o for o in bpy.data.objects if o.type == "ARMATURE"]
print("[FIT] library armatures: %s" % [o.name for o in lib_rigs])
if not lib_rigs:
    print("[FIT] FATAL: no armature in library blend")
    sys.exit(1)
lib = lib_rigs[0]
lib_bones = {b.name for b in lib.data.bones}
print("[FIT] library rig '%s': %d bones" % (lib.name, len(lib_bones)))
print("[FIT] sample: %s" % sorted(lib_bones)[:6])

before = set(bpy.data.objects)
before_actions = set(bpy.data.actions)
bpy.ops.import_scene.fbx(filepath=fbx)
new_objs = [o for o in bpy.data.objects if o not in before]
new_rigs = [o for o in new_objs if o.type == "ARMATURE"]
print("[FIT] imported objects: %s" % [o.name for o in new_objs])
if not new_rigs:
    print("[FIT] FATAL: fbx carried no armature")
    sys.exit(1)
inc = new_rigs[0]
inc_bones = {b.name for b in inc.data.bones}
print("[FIT] incoming rig '%s': %d bones" % (inc.name, len(inc_bones)))

shared = lib_bones & inc_bones
print("[FIT] SHARED bones: %d" % len(shared))
print("[FIT] in library only: %d -> %s" % (len(lib_bones - inc_bones), sorted(lib_bones - inc_bones)[:10]))
print("[FIT] in incoming only: %d -> %s" % (len(inc_bones - lib_bones), sorted(inc_bones - lib_bones)[:10]))
pct = (100.0 * len(shared) / max(1, len(inc_bones)))
print("[FIT] incoming bones covered by library: %.1f%%" % pct)

for a in bpy.data.actions:
    if a in before_actions:
        continue
    fr = a.frame_range
    print("[FIT] incoming action '%s' frames %.1f..%.1f" % (a.name, fr[0], fr[1]))

print("[FIT] object scale incoming=%s library=%s" % (tuple(round(v, 4) for v in inc.scale),
                                                     tuple(round(v, 4) for v in lib.scale)))
print("[FIT] VERDICT: %s" % ("DROP-IN (no retarget needed)" if pct >= 95.0 else "NEEDS MAPPING"))
