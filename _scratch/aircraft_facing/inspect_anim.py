"""What is actually IN the aircraft GLBs: animation actions, spinnable parts,
and whether the materials carry any texture at all.

Blender 4.4+ moved actions to layers/strips/channelbags; `action.fcurves` is
empty for them, so both layouts have to be walked.
"""
import bpy, os

AIR = r"C:\Users\caleb\RECONgame\assets\us\aircraft"
VEH = r"C:\Users\caleb\RECONgame\assets\us\vehicles"
FILES = [
    os.path.join(AIR, "a1_skyraider.glb"),
    os.path.join(AIR, "a4_skyhawk.glb"),
    os.path.join(AIR, "f4_phantom.glb"),
    os.path.join(AIR, "ac47_spooky.glb"),
    os.path.join(AIR, "a1_skyraider_crashed.glb"),
    os.path.join(VEH, "huey_v3.glb"),
]
SPIN_HINTS = ("prop", "rotor", "blade", "spinner", "disc", "fan")


def fcurves_of(act):
    layers = getattr(act, "layers", None)
    if layers:
        for layer in layers:
            for strip in layer.strips:
                for cbag in getattr(strip, "channelbags", []):
                    for fc in cbag.fcurves:
                        yield fc
    else:
        for fc in act.fcurves:
            yield fc


for path in FILES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=path)
    except Exception as e:
        print("FAIL %s %s" % (os.path.basename(path), e))
        continue

    print("\n=== %s ===" % os.path.basename(path))

    for a in bpy.data.actions:
        fcs = list(fcurves_of(a))
        chans = sorted({fc.data_path.rsplit(".", 1)[-1] for fc in fcs})
        print("  action %-26s channels %d  drives %s" % (a.name, len(fcs), chans[:5]))
    if not bpy.data.actions:
        print("  (no actions)")

    spin = [o.name for o in bpy.data.objects
            if any(h in o.name.lower() for h in SPIN_HINTS)]
    print("  spinnable: %s" % (spin if spin else "NONE"))

    # Texture reality check: a material with no image is a white model.
    n_img = len(bpy.data.images)
    untex = []
    for m in bpy.data.materials:
        has_img = False
        if m.use_nodes and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image is not None:
                    has_img = True
                    break
        if not has_img:
            base = ""
            if m.use_nodes and m.node_tree:
                for n in m.node_tree.nodes:
                    if n.type == 'BSDF_PRINCIPLED':
                        c = n.inputs['Base Color'].default_value
                        base = " base=(%.2f,%.2f,%.2f)" % (c[0], c[1], c[2])
                        break
            untex.append(m.name + base)
    print("  materials %d  images %d  UNTEXTURED %d/%d"
          % (len(bpy.data.materials), n_img, len(untex), len(bpy.data.materials)))
    for u in untex[:8]:
        print("      %s" % u)

print("\nINSPECT_DONE")
