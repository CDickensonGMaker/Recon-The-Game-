"""NVA/VC gear library - fix #3: pack_rpg's launcher+warhead sat ~2m away
from its own canvas sling, in a totally different part of local space.

DIAGNOSIS (measured): `pack_worn_rpg` has 3 material slots -
`pack_canvas` (the sling, 48 tris, sits at Z -0.02 to -0.25 - correct,
matches the socket_pack back-mount convention every other pack here uses),
`BluedSteelVC.001` (the launcher tube, 208 tris) and `WarheadOD` (the
PG-7V warhead, 264 tris) - and the LATTER TWO sit at Z -2.19 to -2.11,
almost exactly 2 METRES away from the sling in the same object's local
space. This is not a poly-budget problem, it is a placement bug: the
launcher assembly was never baked into the pack socket's local frame the
way the sling was - it reads as "outlier 520 tris" in the manifest, but
the real defect a player would see is a canvas strap on someone's back
with no gun attached to it anywhere on screen.

The 520-tri COUNT is legitimate once the pieces are actually joined - an
RPG-7 tube + warhead is a materially more complex item than a rucksack,
and the count is in line with `pack_ruck_full` (236) roughly doubled for
two extra distinct forms (tube + conical warhead) rather than one canvas
sack. No geometry is removed here; the fix is a rigid reposition of the
tube+warhead cluster onto the sling, verified by a fit-check against the
body afterward exactly like every other prop in this library.

    blender -b --factory-startup -P tools/fix_pack_rpg.py
"""
import bpy, os
from mathutils import Vector

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    rig = bpy.data.objects["PSXRig"]
    ob = bpy.data.objects["pack_worn_rpg"]
    me = ob.data

    canvas_verts, gun_verts = [], []
    for p in me.polygons:
        for vi in p.vertices:
            (canvas_verts if p.material_index == 0 else gun_verts).append(vi)
    canvas_verts, gun_verts = set(canvas_verts), set(gun_verts)

    def center(idxs):
        c = Vector((0, 0, 0))
        for i in idxs:
            c += me.vertices[i].co
        return c / len(idxs)

    canvas_c = center(canvas_verts)
    gun_c = center(gun_verts)
    print("canvas center", canvas_c, "gun center (before)", gun_c)

    # Rigid reposition only - preserve the tube+warhead's own internal
    # shape and relative orientation, just bring it onto the sling. Target:
    # resting across the upper back, slightly above the canvas strap
    # (matches real sling-carry - muzzle/warhead rides high near the
    # shoulder), X unchanged (its long axis is already X, a believable
    # diagonal-ish carry once joined), Y raised slightly above the sling,
    # Z brought from -2.15 to just behind the sling's own Z band.
    target = Vector((gun_c.x, canvas_c.y + 0.10, canvas_c.z - 0.10))
    delta = target - gun_c
    print("delta", delta)

    for i in gun_verts:
        me.vertices[i].co += delta
    me.update()

    new_gun_c = center(gun_verts)
    print("gun center (after)", new_gun_c)

    # ------------------------------------------------------------------
    # fit-check against the body (same method every other prop in this
    # library used): closest_point_on_mesh + normal-sign penetration test,
    # filtered to the gun's own local bbox area (not the whole body).
    # ------------------------------------------------------------------
    body = bpy.data.objects.get("vc_guerilla_joined")
    if body:
        spine1 = rig.matrix_world @ rig.pose.bones["mixamorig:Spine1"].matrix
        inside = 0
        max_depth = 0.0
        checked = 0
        body_eval = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        for i in (canvas_verts | gun_verts):
            local = me.vertices[i].co
            world = spine1 @ local
            body_local = body.matrix_world.inverted() @ world
            ok, loc, nrm, idx = body_eval.closest_point_on_mesh(body_local)
            if not ok:
                continue
            checked += 1
            depth = (body_local - loc).dot(nrm)
            if depth < 0:
                inside += 1
                max_depth = max(max_depth, -depth)
        print(f"fit-check: {inside}/{checked} verts inside body, max depth {max_depth:.4f}m")

    # ------------------------------------------------------------------
    # re-export
    # ------------------------------------------------------------------
    for x in bpy.data.objects:
        x.select_set(False)
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    out_path = os.path.join(PROPS_DIR, "packs", "pack_rpg.glb")
    kw = dict(filepath=out_path, export_format='GLB', use_selection=True,
              export_apply=True, export_animations=False, export_skins=False,
              export_morph=False, export_cameras=False, export_lights=False,
              export_yup=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
    print("exported", out_path)

    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)


if __name__ == "__main__":
    main()
