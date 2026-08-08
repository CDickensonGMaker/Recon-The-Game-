"""NVA/VC gear library - fix #2: the systemic texture/UV defect Caleb flagged
on the packs AND the pith band trim.

ROOT CAUSE (measured, not per-prop nudging): the shared `pack_canvas`
material - used by pack_ammo, pack_frame, pack_roll, pack_rpg,
pack_ruck_full, pack_ruck_light, pack_satchel, chest_rig_ak, bandolier_ammo
(9 of the 20 audited props, all sharing ONE material datablock) - has its
Principled BSDF Base Color Image Texture node wired to `pith_worn_cover.png`,
the PITH HELMET's cover sheet, instead of a canvas-appropriate image. This
is not a UV problem (islands are fine) - it is the wrong SOURCE IMAGE on a
shared material, which is why it showed up identically across nine
unrelated props at once. `chest_rig_worn` (a 10th prop) points directly at
`pith_worn_cover` material rather than `pack_canvas`, same root defect by a
different path.

`pith_band_cover` (all six pith/cap "_band" trim objects, already
regeometried by fix_nva_gear_bands.py) has the SAME wrong wiring - also
pointed at pith_worn_cover.png. A pith helmet's leatherette/vinyl trim band
is a distinct dark material, not a copy of the fabric dome cover.

THE PATTERN THAT ESCAPED IT (Caleb's own example, `pack_rice_tube`,
approved/untouched): `webbing_canvas` material correctly points at
`canvas_od` (`art_source/characters/textures/canvas_od.png`), a real
canvas sheet already packed into this exact file. This fix repoints
`pack_canvas` at that SAME already-present, already-correct image rather
than authoring a new one - one shared canvas sheet across the pack family,
matching the PSX-era "few shared material sheets" approach and the
project's own painted-clothing direction.

Fixes, one node-graph edit each (cascades to every consumer at once):
  pack_canvas material   : pith_worn_cover.png -> canvas_od   (9 props)
  pith_band_cover material: pith_worn_cover.png -> flat dark vinyl/leather
                            colour (no image - a helmet trim band is a
                            small solid-colour strip at PSX texel density,
                            not worth a bespoke sheet)
  chest_rig_worn          : new dedicated material (canvas_od image, same
                            as pack_canvas, but a darker/desaturated tint)
                            instead of borrowing the pith cover wholesale -
                            keeps the "share topology, weather the material"
                            trick the pith plain/faded/worn/star family
                            already uses, but on the RIGHT base material.

    blender -b --factory-startup -P tools/fix_nva_gear_textures.py
"""
import bpy, os

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")

PACK_OBJECTS = {
    "pack_ammo": "pack_worn_ammo",
    "pack_frame": "pack_worn_frame",
    "pack_roll": "pack_roll",
    "pack_rpg": "pack_worn_rpg",
    "pack_ruck_full": "pack_worn_ruck_full",
    "pack_ruck_light": "pack_worn_ruck_light",
    "pack_satchel": "pack_worn_satchel",
}
CHEST_OBJECTS = {
    "chest_rig_ak": "chest_rig_ak",
    "bandolier_ammo": "bandolier_ammo",
}
GLB_DIRS = {**{k: "packs" for k in PACK_OBJECTS}, **{k: "chest" for k in CHEST_OBJECTS}}
GLB_OBJECTS = {**PACK_OBJECTS, **CHEST_OBJECTS}


def repoint_image(mat, new_img):
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            n.image = new_img


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    rig = bpy.data.objects["PSXRig"]
    canvas_od = bpy.data.images["canvas_od"]

    # --- fix 1: pack_canvas -> canvas_od (fixes 7 packs + chest_rig_ak +
    # bandolier_ammo in one edit, since they all share this ONE material) ---
    pack_canvas = bpy.data.materials["pack_canvas"]
    old_img = next((n.image.name for n in pack_canvas.node_tree.nodes
                     if n.type == 'TEX_IMAGE' and n.image), None)
    repoint_image(pack_canvas, canvas_od)
    print(f"pack_canvas: {old_img} -> canvas_od")

    # --- fix 2: pith_band_cover -> flat dark vinyl/leather colour ---
    band_mat = bpy.data.materials["pith_band_cover"]
    old_img2 = next((n.image.name for n in band_mat.node_tree.nodes
                      if n.type == 'TEX_IMAGE' and n.image), None)
    for n in list(band_mat.node_tree.nodes):
        if n.type == 'TEX_IMAGE':
            band_mat.node_tree.nodes.remove(n)
    bsdf = next(n for n in band_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (0.035, 0.028, 0.022, 1.0)  # dark vinyl/leather brown-black
    bsdf.inputs['Roughness'].default_value = 0.55
    print(f"pith_band_cover: {old_img2} -> flat dark vinyl colour (no image)")

    # --- fix 3: chest_rig_worn gets its OWN weathered material, not a
    # straight borrow of the pith cover ---
    old_worn_mat = bpy.data.materials.get("pith_worn_cover")
    worn_mat = bpy.data.materials.new("chest_rig_worn_cover")
    worn_mat.use_nodes = True
    for n in list(worn_mat.node_tree.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            worn_mat.node_tree.nodes.remove(n)
    bsdf2 = worn_mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    out = next(n for n in worn_mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL')
    worn_mat.node_tree.links.new(bsdf2.outputs['BSDF'], out.inputs['Surface'])
    tex = worn_mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = canvas_od
    tex.interpolation = 'Closest'
    worn_mat.node_tree.links.new(tex.outputs['Color'], bsdf2.inputs['Base Color'])
    bsdf2.inputs['Roughness'].default_value = 0.95
    try:
        worn_mat.diffuse_color = (0.32, 0.30, 0.24, 1.0)  # weathered/faded tint reference
    except Exception:
        pass

    rig_ob = bpy.data.objects["chest_rig_worn"]
    rig_ob.data.materials.clear()
    rig_ob.data.materials.append(worn_mat)
    print("chest_rig_worn: pith_worn_cover (borrowed) -> chest_rig_worn_cover (own material, canvas_od image, weathered tint)")

    # --- re-export every touched glb ---
    for key, obname in GLB_OBJECTS.items():
        for x in bpy.data.objects:
            x.select_set(False)
        ob = bpy.data.objects[obname]
        ob.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        out_path = os.path.join(PROPS_DIR, GLB_DIRS[key], key + ".glb")
        kw = dict(filepath=out_path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
        print("exported", out_path)

    # chest_rig_worn's own glb
    for x in bpy.data.objects:
        x.select_set(False)
    bpy.data.objects["chest_rig_worn"].select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    out_path = os.path.join(PROPS_DIR, "chest", "chest_rig_worn.glb")
    kw = dict(filepath=out_path, export_format='GLB', use_selection=True,
              export_apply=True, export_animations=False, export_skins=False,
              export_morph=False, export_cameras=False, export_lights=False,
              export_yup=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
    print("exported", out_path)

    # re-export the 6 headgear glbs too (band material changed under them)
    HEADGEAR_PARTS = {
        "pith_plain.glb": ["pith_plain", "pith_plain_band"],
        "pith_faded.glb": ["pith_faded", "pith_faded_band"],
        "pith_worn.glb":  ["pith_worn", "pith_worn_band"],
        "pith_star.glb":  ["pith_star", "pith_star_band"],
        "pith_net.glb":   ["pith_net", "pith_net_band", "pith_net_scrim", "pith_net_tabs"],
        "cap_cloth.glb":  ["cap_cloth", "cap_cloth_band"],
    }
    for glb_name, parts in HEADGEAR_PARTS.items():
        for x in bpy.data.objects:
            x.select_set(False)
        for p in parts:
            bpy.data.objects[p].select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        out_path = os.path.join(PROPS_DIR, "headgear", glb_name)
        kw = dict(filepath=out_path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
        print("exported", out_path)

    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)


if __name__ == "__main__":
    main()
