"""Rebase the VC/NVA face-atlas UV island to cell 0 so the dresser's cell numbers
mean the same face on every unit.

VcNvaDresser._set_face adds uv1_offset = (col/COLS, row/ROWS) to whatever the GLB
baked. If two units bake their island at different bases, the same cell index deals
two different faces. This shifts every face_atlas_mat island back to cell (0,0).

face_atlas_v2 is a 6x5 sheet (576x640, 96x128 cells, 84x120 face art) - measured from
the three bases that actually ship, which step by exactly 1/6 in u and 1/5 in v.

Dry-run by default.  Usage: python tools/rebase_face_uv.py [--apply]
"""
import argparse, glob, json, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrink_master_sheets import load_glb, save_glb

D = r"C:\Users\caleb\RECONgame\assets\nva_vc\characters"
COLS, ROWS = 6, 5          # face_atlas_v2's real grid
TARGET_ATLAS = "face_atlas_v2"
EPS = 0.02


def uv_view(g, ai):
    a = g['accessors'][ai]
    bv = g['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride') or 8
    return off, stride, a['count']


def process(path, apply):
    g, bc = load_glb(path)
    imgname = {ti: g['images'][t['source']].get('name', '')
               for ti, t in enumerate(g.get('textures', [])) if 'source' in t}
    targets = set()
    for mi, m in enumerate(g.get('materials', [])):
        bct = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        if bct and imgname.get(bct['index'], '') == TARGET_ATLAS:
            targets.add(mi)
    if not targets:
        return None

    # which TEXCOORD accessors belong to target materials, and to anything else
    mine, others = set(), set()
    for mesh in g.get('meshes', []):
        for p in mesh.get('primitives', []):
            ai = p['attributes'].get('TEXCOORD_0')
            if ai is None:
                continue
            (mine if p.get('material') in targets else others).add(ai)
    shared = mine & others
    if shared:
        return ('SHARED', sorted(shared))          # refuse: would corrupt other surfaces

    bc = bytearray(bc)
    umin = vmin = 9.0
    for ai in mine:
        off, stride, n = uv_view(g, ai)
        for i in range(n):
            u, v = struct.unpack_from('<ff', bc, off + i * stride)
            umin = min(umin, u); vmin = min(vmin, v)

    col = int(round(umin * COLS))
    row = int(round(vmin * ROWS))
    du, dv = -col / COLS, -row / ROWS
    if abs(du) < 1e-9 and abs(dv) < 1e-9:
        return ('OK', umin, vmin, col, row, 0.0, 0.0)

    for ai in mine:
        off, stride, n = uv_view(g, ai)
        for i in range(n):
            u, v = struct.unpack_from('<ff', bc, off + i * stride)
            struct.pack_into('<ff', bc, off + i * stride, u + du, v + dv)

    if apply:
        save_glb(path, g, bytes(bc))
    return ('MOVED', umin, vmin, col, row, du, dv)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    n = 0
    for f in sorted(glob.glob(os.path.join(D, "*.glb"))):
        r = process(f, args.apply)
        if r is None:
            continue
        name = os.path.basename(f)
        if r[0] == 'SHARED':
            print("  SKIP  %-24s TEXCOORD shared with non-face surfaces: %s" % (name, r[1]))
            continue
        _, umin, vmin, col, row, du, dv = r
        n += 1
        print("  %-6s %-24s base u=%.4f v=%.4f  cell(col=%d,row=%d)  delta=(%+.4f,%+.4f)" % (
            "APPLY" if args.apply else "DRY", name, umin, vmin, col, row, du, dv))
    print("\n%d unit(s) on %s%s" % (n, TARGET_ATLAS, "" if args.apply else "  (dry run)"))


if __name__ == "__main__":
    main()
