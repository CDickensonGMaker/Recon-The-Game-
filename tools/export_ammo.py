"""Export every casing and live round as its own GLB for runtime spawning.

    python tools/export_ammo.py

Reads collections CASINGS (spent brass) and ROUNDS (live cartridges) from the
FP arms blend and writes assets/player/ammo/<name>.glb, one object per file,
origin at the object's own centre so a spawned case tumbles about its middle.

Blender path: RECON_BLENDER env var, else the default install below.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.environ.get("RECON_BLENDER",
                         r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe")
BLEND = os.path.join(ROOT, "assets", "player", "arms", "fp_arms_rifle.blend")
OUT = os.path.join(ROOT, "assets", "player", "ammo")

INNER = r'''
import bpy, os, sys, traceback
from mathutils import Matrix
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)

# the arms blend is saved in Pose Mode; every object operator polls false until
# we drop back to Object Mode
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

written = []
for coll in ("CASINGS", "ROUNDS"):
    c = bpy.data.collections.get(coll)
    if c is None:
        print("MISSING COLLECTION", coll)
        continue
    for o in sorted(c.objects, key=lambda x: x.name):
        if o.type != 'MESH':
            continue
        try:
            for x in bpy.context.view_layer.objects:
                x.select_set(False)
            o.hide_set(False)
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            keep = o.matrix_world.copy()
            o.matrix_world = Matrix.Identity(4)      # spawn-ready: origin at world zero
            path = os.path.join(out, o.name + ".glb")
            bpy.ops.export_scene.gltf(
                filepath=path, export_format='GLB', use_selection=True,
                export_animations=False, export_skins=False, export_morph=False,
                export_apply=True, export_yup=True)
            o.matrix_world = keep
            written.append((o.name, len(o.data.vertices), os.path.getsize(path)))
        except Exception:
            print("AMMOFAIL", o.name, traceback.format_exc().replace("\n", " | "))
for n, v, s in written:
    print("AMMO %-18s verts=%-4d %6.1f KB" % (n, v, s / 1024.0))
print("TOTAL", len(written))
'''

if not os.path.exists(BLENDER):
    sys.exit(f"blender not found at {BLENDER} (set RECON_BLENDER)")

script = os.path.join(ROOT, "tools", "_ammo_inner.py")
with open(script, "w") as fh:
    fh.write(INNER)
try:
    r = subprocess.run([BLENDER, "-b", BLEND, "-P", script, "--", OUT],
                       capture_output=True, text=True)
finally:
    os.remove(script)

for line in r.stdout.splitlines():
    if line.startswith(("AMMO", "TOTAL", "MISSING", "AMMOFAIL")):
        print(line)
if r.returncode != 0:
    print(r.stdout[-3000:])
    print(r.stderr[-2000:])
    sys.exit(f"AMMO EXPORT FAILED (blender exit {r.returncode})")
