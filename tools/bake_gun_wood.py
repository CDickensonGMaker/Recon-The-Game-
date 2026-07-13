"""Bake procedural (ColorRamp) gun wood materials to image textures.

glTF cannot export procedural shader chains, so every material whose Principled
Base Color comes from a node chain (VALTORGB wood ramps) shows WHITE in Godot
(RECONgame-w16p). Metal mats use flat base colors and survive.

For each affected gun: fresh Smart UV (safe - no gun uses image textures),
Cycles-bake DIFFUSE color per procedural material into its own 512px PNG under
art_source/characters/fp_arms/gun_bakes/, then wire the image into Base Color
(the old ramp chain is left in the tree, just unlinked).

Run per-gun from the Blender MCP against the open fp_arms_rifle.blend:
    import bake_gun_wood; bake_gun_wood.bake_gun("PPSh41_Gun")
Split shared materials once first: bake_gun_wood.split_shared()
"""
import bpy, os

BAKE_DIR = r"C:\Users\caleb\RECONgame\assets\player\arms\gun_bakes"
SIZE = 512

def _is_proc(m):
    if not m or not m.use_nodes:
        return False
    bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bsdf:
        return False
    bc = bsdf.inputs['Base Color']
    return bc.is_linked and bc.links[0].from_node.type != 'TEX_IMAGE'

def split_shared(gun_names):
    """Give each gun its own copy of any procedural material shared between guns."""
    seen = {}
    out = []
    for gn in gun_names:
        o = bpy.data.objects.get(gn)
        if not o:
            continue
        for s in o.material_slots:
            m = s.material
            if not _is_proc(m):
                continue
            if m.name in seen and seen[m.name] != gn:
                cp = m.copy()
                cp.name = f"{m.name}_{gn}"
                s.material = cp
                out.append(f"{gn}: {m.name} -> {cp.name}")
            else:
                seen[m.name] = gn
    return out

def bake_gun(gun_name):
    o = bpy.data.objects[gun_name]
    scene = bpy.context.scene
    prev_engine = scene.render.engine
    prev_hidden = o.hide_get()
    prev_render = o.hide_render

    o.hide_set(False)
    o.hide_viewport = False
    o.hide_render = False
    bpy.context.view_layer.objects.active = o
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    o.select_set(True)

    # fresh non-overlapping UVs (no gun material uses image textures yet)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    # bake targets: real image per procedural mat, shared scrap for the rest
    scrap = bpy.data.images.get("BAKE_SCRAP") or bpy.data.images.new("BAKE_SCRAP", 64, 64)
    added = []   # (mat, node) to clean up scrap nodes
    baked = []   # (mat, img)
    for s in o.material_slots:
        m = s.material
        if not m or not m.use_nodes:
            continue
        nt = m.node_tree
        if _is_proc(m):
            img_name = f"bake_{m.name}"
            img = bpy.data.images.get(img_name)
            if img is None:
                img = bpy.data.images.new(img_name, SIZE, SIZE)
            node = nt.nodes.new('ShaderNodeTexImage')
            node.image = img
            node.location = (-500, 600)
            nt.nodes.active = node
            baked.append((m, img, node))
        else:
            node = nt.nodes.new('ShaderNodeTexImage')
            node.image = scrap
            nt.nodes.active = node
            added.append((m, node))

    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 4
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=8, use_clear=True)

    # clean scrap nodes, wire baked images into Base Color, save PNGs
    for m, node in added:
        m.node_tree.nodes.remove(node)
    os.makedirs(BAKE_DIR, exist_ok=True)
    for m, img, node in baked:
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        bc = bsdf.inputs['Base Color']
        for l in list(bc.links):
            nt.links.remove(l)
        nt.links.new(node.outputs['Color'], bc)
        img.filepath_raw = os.path.join(BAKE_DIR, f"{img.name}.png")
        img.file_format = 'PNG'
        img.save()

    scene.render.engine = prev_engine
    o.hide_set(prev_hidden)
    o.hide_render = prev_render
    return [f"{m.name} -> {img.name}.png" for m, img, node in baked]
