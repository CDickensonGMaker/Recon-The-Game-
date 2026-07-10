"""face_uv.py - map any head mesh's UVs onto a face cell of the packed face_atlas.

The atlas ('face_atlas' image, 768x1056, packed in base_psx blends) holds painted
game faces. This projects the head from the front (-Y) onto the chosen portrait
rect; back-of-head verts stretch the portrait's hair-edge columns.

Use over and over for every unit head:
    import face_uv; face_uv.remap("grunt_head", "us_mil_2")
Or in a Blender Text Editor: set PICK/TARGETS at the bottom and Run Script.

Rects measured on the atlas (pixels, top-origin). Add more faces as needed.
"""
import bpy

ATLAS_W, ATLAS_H = 768.0, 1056.0
FACES = {
    "vnm_older":  (68,  28, 162, 128),
    "vnm_mid":    (243, 28, 337, 128),
    "vnm_woman":  (425, 28, 520, 128),
    "vnm_f2":     (608, 28, 700, 128),
    "vnm_f2b":    (80, 165, 165, 255),
    "vnm_f2c":    (245, 165, 345, 255),
    "vnm_young":  (420, 165, 520, 255),
    "us_mil_1":   (70, 283, 170, 398),
    "us_mil_2":   (243, 283, 343, 398),
    "us_mil_3":   (418, 283, 518, 398),
    "us_dark_1":  (73, 420, 173, 520),
    "us_dark_2":  (243, 420, 345, 520),
}

# head fitting constants for the PSX base (world/rest space)
Z_BOT, Z_TOP = 1.573, 1.807     # chin..crown range mapped onto the portrait
HALF_W = 0.083                  # head half width
BACK_Y = 0.018                  # y beyond this = back of head -> hair edge


def remap(obj_name: str, face: str) -> bool:
    o = bpy.data.objects.get(obj_name)
    if not o:
        print(f"[face_uv] no object '{obj_name}'"); return False
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')   # mesh data is empty while in Edit Mode
    px0, py0, px1, py1 = FACES[face]
    u0, u1 = px0/ATLAS_W, px1/ATLAS_W
    v_top, v_bot = 1 - py0/ATLAS_H, 1 - py1/ATLAS_H
    fam = bpy.data.materials.get("face_atlas_mat")
    me = o.data
    if fam and len(o.material_slots) > 0:
        o.material_slots[0].material = fam
    uv_layer = me.uv_layers[0]
    for poly in me.polygons:
        if poly.material_index != 0:
            continue                              # skip gore caps
        for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
            v = me.vertices[me.loops[li].vertex_index].co
            zn = max(0.0, min(1.0, (v.z - Z_BOT) / (Z_TOP - Z_BOT)))
            if v.y > BACK_Y:
                u = u0 + 0.012 if v.x < 0 else u1 - 0.012
            else:
                xn = max(0.0, min(1.0, v.x / (2*HALF_W) + 0.5))
                u = u0 + xn * (u1 - u0)
            uv_layer.data[li].uv = (u, v_bot + zn * (v_top - v_bot))
    me.update()
    print(f"[face_uv] {obj_name} -> {face}")
    return True


if __name__ == "__main__":
    PICK = "us_mil_1"
    TARGETS = ["grunt_head", "splay_head"]
    for t in TARGETS:
        remap(t, PICK)
