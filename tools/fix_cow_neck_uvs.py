"""fix_cow_neck_uvs.py - the neck/jaw "gaps" on the Conquest of Worms cast heads.

    "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" --background ^
        "assets/us/characters/conquest_of_worms_us_cast.blend" --python tools/fix_cow_neck_uvs.py ^
        [-- --save]

Diagnosed 2026-09-11 in object space against `grunt_head` / `us_grunt_joined` in
us_base_v3.blend (vertex hash 65c3014e4844 on both, so the geometry is the canonical one):

  * the canonical wrap parks ALL EXPOSED SKIN - the 18 neck polys (z 1.507-1.591) AND the
    66 hand / rolled-sleeve forearm polys - on ONE 2-3 px patch of the face cell, at 52%
    across / 45% down the cell, which is the NOSE of the painted portrait. Only 14 of the
    112 face-material polys carry a real spread wrap (the face itself). On the stock face
    that patch is mid skin (0.65,0.45,0.32 linear); on the CoW-painted cells it is the nose
    highlight (0.82,0.63,0.53) - hence the pale neck and pale hands, and per-face flat
    shading of one flat colour is the "banding" with "triangle seams".
  * the two polygons BEHIND THE JAW under the ear (z 1.590-1.664, normals +-0.93 x) and the
    two on the nape (same z, facing +y) sit on the HAIR texel with the rest of the scalp
    (22% down the cell). On the painted cells that texel is (0.09,0.05,0.04) - near black -
    hence the "dark band" that reads as a hole. It is a black-textured polygon, not a gap.
  * open edges: 16 at the head/neck junction and 22 at the neck/torso junction, but they are
    two OVERLAPPING rings each (head shell 5 mm below the neck top at the front), identical
    in us_base_v3, and do not show at 640x480 - not the defect Caleb is seeing.

The fix moves ONLY those collapsed single-texel loops to a texel of the SAME cell whose
colour is the mean of the lower-cheek/jaw polygons (77/62/87/72). The face wrap is not
re-unwrapped, no vertex moves, and the hair polys above the ear stay on hair.
"""
import bpy
import sys
import numpy as np
from mathutils import Vector

D = bpy.data
FACE_COLS, FACE_ROWS = 10, 7        # grunt_dresser.gd:20-21
TAGS = ["michael", "gus_arrival", "gus_ears"]


def img_of(mat):
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            return n.image
    return None


def px(img):
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)


def uv_to_px(img, u, v):
    w, h = img.size
    return min(w - 1, int(u * w)), min(h - 1, int(v * h))


def fix_mesh(o, label):
    me = o.data
    uv = me.uv_layers.active.data
    fi = [i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")]
    if not fi:
        return None
    img = img_of(me.materials[fi[0]])
    a = px(img)
    W, H = img.size
    face_polys = [p for p in me.polygons if p.material_index in fi]

    def poly_uv_span(p):
        us = [uv[l].uv.x for l in p.loop_indices]
        vs = [uv[l].uv.y for l in p.loop_indices]
        return max(us) - min(us), max(vs) - min(vs)

    # collapsed = the whole polygon inside a ~4 px patch (the neck quads span 2-3 px)
    collapsed = [p for p in face_polys if max(poly_uv_span(p)) < 4.5 / W]
    # classify by geometry, never by index: the neck is below the jaw ring, the jaw-side
    # and nape polys sit on the head shell but under the ear line and face down/out.
    # skin = neck (18) + hands/forearms (66): everything on the skin patch below the jaw
    neck = [p for p in collapsed if p.center.z < 1.595]
    jawside = [p for p in collapsed if 1.58 <= p.center.z <= 1.67 and p.normal.z < -0.2
               and p.center.y > -0.03]
    hair = [p for p in collapsed if p not in neck and p not in jawside]
    # the reference colour: mean over the lower-cheek / jaw polys that carry real face
    # pixels - the face polys below the ear line with a real UV span, on the front half.
    cheek = [p for p in face_polys if p not in collapsed and p.center.z < 1.66
             and p.center.y < -0.02 and max(poly_uv_span(p)) > 6.0 / W]
    cols = []
    for p in cheek:
        us = [uv[l].uv.x for l in p.loop_indices]
        vs = [uv[l].uv.y for l in p.loop_indices]
        x0, y0 = uv_to_px(img, min(us), min(vs))
        x1, y1 = uv_to_px(img, max(us), max(vs))
        cols.append(a[y0:y1 + 1, x0:x1 + 1, :3].reshape(-1, 3))
    ref = np.concatenate(cols).mean(axis=0)
    # search the face island for the texel nearest that mean, restricted to the lower
    # half of the island (under the eye line) so we never pick a hair or eye pixel.
    us = [uv[l].uv.x for p in face_polys for l in p.loop_indices]
    vs = [uv[l].uv.y for p in face_polys for l in p.loop_indices]
    x0, y0 = uv_to_px(img, min(us), min(vs))
    x1, y1 = uv_to_px(img, max(us), max(vs))
    ymid = (y0 + y1) // 2
    win = a[y0:ymid, x0:x1 + 1, :3]
    d = ((win - ref) ** 2).sum(axis=2)
    # 3x3 box filter so a lone matching pixel in a noisy area does not win
    k = np.ones((3, 3)) / 9.0
    dd = d.copy()
    dd[1:-1, 1:-1] = sum(d[1 + dy:d.shape[0] - 1 + dy, 1 + dx:d.shape[1] - 1 + dx] * k[dy + 1, dx + 1]
                         for dy in (-1, 0, 1) for dx in (-1, 0, 1))
    iy, ix = np.unravel_index(dd.argmin(), dd.shape)
    tx, ty = x0 + ix, y0 + iy
    tu, tv = (tx + 0.5) / W, (ty + 0.5) / H
    got = a[ty, tx, :3]
    old_neck = uv[neck[0].loop_indices[0]].uv.copy() if neck else None
    old_jaw = uv[jawside[0].loop_indices[0]].uv.copy() if jawside else None
    onx, ony = uv_to_px(img, old_neck.x, old_neck.y) if old_neck else (0, 0)
    ojx, ojy = uv_to_px(img, old_jaw.x, old_jaw.y) if old_jaw else (0, 0)
    n_neck = sum(1 for p in neck if abs(p.center.x) < 0.12)
    print("%-38s face polys %3d, collapsed %2d = skin %2d (neck %d, hands/forearms %d) "
          "+ jawside/nape %d + hair %d"
          % (label, len(face_polys), len(collapsed), len(neck), n_neck, len(neck) - n_neck,
             len(jawside), len(hair)))
    print("      cheek ref (%d polys) mean rgb (%.2f,%.2f,%.2f)" % (len(cheek), *ref))
    if old_neck:
        print("      neck texel WAS px(%d,%d) rgb (%.2f,%.2f,%.2f)  -> px(%d,%d) rgb (%.2f,%.2f,%.2f)"
              % (onx, ony, *a[ony, onx, :3], tx, ty, *got))
    if old_jaw:
        print("      jaw/nape texel WAS px(%d,%d) rgb (%.2f,%.2f,%.2f)  -> same skin texel"
              % (ojx, ojy, *a[ojy, ojx, :3]))
    n = 0
    for p in neck + jawside:
        for l in p.loop_indices:
            uv[l].uv = (tu, tv)
            n += 1
    print("      moved %d loops on %d polys; hair polys untouched: %s"
          % (n, len(neck) + len(jawside), sorted(p.index for p in hair)))
    return dict(neck=len(neck), jaw=len(jawside), ref=tuple(ref), got=tuple(got))


def run():
    for tag in TAGS:
        for base in ("us_grunt_joined_", "grunt_head_"):
            o = D.objects.get(base + tag)
            if o is None:
                print("MISSING", base + tag)
                continue
            fix_mesh(o, base + tag)


if __name__ == "__main__":
    run()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--save" in argv:
        bpy.ops.wm.save_mainfile(filepath=bpy.data.filepath)
        print("SAVED", bpy.data.filepath)
