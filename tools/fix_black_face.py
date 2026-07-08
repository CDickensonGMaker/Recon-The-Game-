"""Rebuild the black grunt's face texture so it matches his arm skin.

The first attempt multiplied every channel by a gain, which crushed the eyes,
brows and stubble to near-black along with the skin. Instead: find the original
texture's skin tone, and re-base every pixel onto the new skin tone, carrying
each pixel's DELTA from the old base. Features keep their contrast, and the flat
skin area lands exactly on the Skin_Black colour the arms use.

Run: blender -b sprite_stage.blend -P fix_black_face.py
"""
import bpy
import numpy as np

def lin2srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)

# --- the arm/body skin colour is the target (stored linear on the BSDF) ---
skin = bpy.data.materials['Skin_Black']
bsdf = next(n for n in skin.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
skin_lin = np.array(bsdf.inputs['Base Color'].default_value[:3], dtype=np.float32)
S1 = lin2srgb(skin_lin).astype(np.float32)          # texture space is sRGB
print(f"target skin sRGB {tuple(round(float(v),3) for v in S1)}", flush=True)

# --- read the ORIGINAL face texture, not the darkened one ---
src = bpy.data.images['face_tex']
w, h = src.size
px = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)
rgb = px[:, :, :3]
alpha = px[:, :, 3:]

lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
skin_mask = lum > 0.38                               # flat cheek/forehead area
if not skin_mask.any():
    raise SystemExit('could not find skin pixels in face_tex')
S0 = rgb[skin_mask].mean(axis=0)                     # original tan base
print(f"source skin sRGB {tuple(round(float(v),3) for v in S0)}", flush=True)

# re-base: new = S1 + (px - S0) * k
# darker-than-skin pixels (eyes, brows, stubble, shadow) get a softer factor so
# they stay visible against the darker base instead of crushing to black.
delta = rgb - S0
k = np.where(delta < 0, 0.55, 0.85).astype(np.float32)
out_rgb = np.clip(S1 + delta * k, 0.0, 1.0)

name = 'face_tex_black'
if name in bpy.data.images:
    bpy.data.images.remove(bpy.data.images[name])
img = bpy.data.images.new(name, w, h, alpha=True)
out = np.concatenate([out_rgb, alpha], axis=2)
img.pixels.foreach_set(np.ascontiguousarray(out, dtype=np.float32).ravel())
img.pack()

face = bpy.data.materials['FaceTex_Black']
for n in face.node_tree.nodes:
    if n.type == 'TEX_IMAGE':
        n.image = img
        n.interpolation = 'Closest'

# make sure the face material's shading matches the body skin
fb = next(n for n in face.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
fb.inputs['Roughness'].default_value = bsdf.inputs['Roughness'].default_value
fb.inputs['Metallic'].default_value = 0.0

# report what the flat skin area of the new face actually resolves to
new_skin = out_rgb[skin_mask].mean(axis=0)
print(f"result face skin sRGB {tuple(round(float(v),3) for v in new_skin)}  (should match target)", flush=True)

bpy.ops.wm.save_mainfile()
print("FACE FIXED + SAVED", flush=True)
