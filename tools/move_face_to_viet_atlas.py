"""Move a VC/NVA unit's face from face_atlas_v2 onto fixed_better_viet_faces.

The target sheet is a 10x3 grid of full head-wraps (1737x579, cells 173.7x193).
The units already on it (nva_mortar_dropper, nva_rto, nva_sapper...) map their head
island to exactly ONE WHOLE CELL - 1/10 x 1/3.  The August attempt fitted the island
to 0.910 x 0.940 of the cell instead, which is why the face read as a narrow strip
with a blank slab where the jaw should be.  Full cell, or it looks wrong.

Also renames the embedded image so it contains "face_atlas": VcNvaDresser
._rides_face_atlas matches on that substring, and the glTF exporter names images
from the file basename, so "fixed_better_viet_faces" is invisible to the dealer.

Usage: python tools/move_face_to_viet_atlas.py UNIT [UNIT...] [--apply]
"""
import argparse, glob, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrink_master_sheets import load_glb, save_glb

D = r"C:\Users\caleb\RECONgame\assets\nva_vc\characters"
DONOR = os.path.join(D, "nva_sapper.glb")     # already carries the viet sheet
SRC_ATLAS = "face_atlas_v2"
NEW_NAME = "face_atlas_viet"                  # must contain "face_atlas"
COLS, ROWS = 10, 3


def donor_image():
    g, bc = load_glb(DONOR)
    for im in g.get('images', []):
        if im.get('name') == 'fixed_better_viet_faces':
            bv = g['bufferViews'][im['bufferView']]
            off = bv.get('byteOffset', 0)
            return bytes(bc[off:off + bv['byteLength']]), im.get('mimeType', 'image/png')
    raise SystemExit("donor atlas not found in " + DONOR)


def process(path, blob, mime, cell, apply, inset=(0.0,0.0,1.0,0.72)):
    g, bc = load_glb(path)
    imgname = {ti: g['images'][t['source']].get('name', '')
               for ti, t in enumerate(g.get('textures', [])) if 'source' in t}
    img_idx = {i for i, im in enumerate(g.get('images', [])) if im.get('name') == SRC_ATLAS}
    if not img_idx:
        return None
    mats = {mi for mi, m in enumerate(g.get('materials', []))
            if (m.get('pbrMetallicRoughness', {}).get('baseColorTexture') or {})
            .get('index') in [ti for ti, n in imgname.items() if n == SRC_ATLAS]}
    mine, others = set(), set()
    for mesh in g.get('meshes', []):
        for p in mesh.get('primitives', []):
            ai = p['attributes'].get('TEXCOORD_0')
            if ai is None:
                continue
            (mine if p.get('material') in mats else others).add(ai)
    if mine & others:
        return ('SHARED',)

    bc = bytearray(bc)

    def view(ai):
        a = g['accessors'][ai]; bv = g['bufferViews'][a['bufferView']]
        return bv.get('byteOffset', 0) + a.get('byteOffset', 0), (bv.get('byteStride') or 8), a['count']

    umin = vmin = 9.0; umax = vmax = -9.0
    for ai in mine:
        off, st, n = view(ai)
        for i in range(n):
            u, v = struct.unpack_from('<ff', bc, off + i * st)
            umin = min(umin, u); umax = max(umax, u)
            vmin = min(vmin, v); vmax = max(vmax, v)
    du, dv = umax - umin, vmax - vmin
    col, row = cell % COLS, (cell // COLS) % ROWS
    cw, ch = 1.0 / COLS, 1.0 / ROWS

    for ai in mine:
        off, st, n = view(ai)
        for i in range(n):
            u, v = struct.unpack_from('<ff', bc, off + i * st)
            iu0, iv0, iu1, iv1 = inset
            nu = (col + iu0 + (iu1 - iu0) * (u - umin) / du) * cw
            nv = (row + iv0 + (iv1 - iv0) * (v - vmin) / dv) * ch
            struct.pack_into('<ff', bc, off + i * st, nu, nv)

    # swap the image bytes and rename so the dresser can see it
    new_bin = bytearray(); 
    for vi, bv in enumerate(g['bufferViews']):
        start = bv.get('byteOffset', 0)
        raw = bytes(bc[start:start + bv['byteLength']])
        if any(g['images'][i].get('bufferView') == vi for i in img_idx):
            raw = blob
        new_bin += b"\x00" * ((4 - len(new_bin) % 4) % 4)
        bv['byteOffset'] = len(new_bin); bv['byteLength'] = len(raw)
        new_bin += raw
    for i in img_idx:
        g['images'][i]['name'] = NEW_NAME
        g['images'][i]['mimeType'] = mime
    g['buffers'][0]['byteLength'] = len(new_bin)

    if apply:
        save_glb(path, g, bytes(new_bin))
    return ('OK', umin, vmin, du, dv, col, row)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("units", nargs='+')
    ap.add_argument("--cell", type=int, default=0)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--inset", default="0,0,1,0.72",
                    help="u0,v0,u1,v1 sub-rect of the cell (default drops the neck band)")
    a = ap.parse_args()
    inset = tuple(float(x) for x in a.inset.split(','))
    blob, mime = donor_image()
    print("donor atlas %d bytes (%s)\n" % (len(blob), mime))
    for u in a.units:
        p = os.path.join(D, u + ".glb")
        r = process(p, blob, mime, a.cell, a.apply, inset)
        if r is None:
            print("  %-22s not on %s" % (u, SRC_ATLAS)); continue
        if r[0] == 'SHARED':
            print("  %-22s SKIP shared TEXCOORD" % u); continue
        _, umin, vmin, du, dv, col, row = r
        print("  %-6s %-22s island %.3fx%.3f at (%.3f,%.3f) -> full cell %d (col %d,row %d)" % (
            "APPLY" if a.apply else "DRY", u, du, dv, umin, vmin, a.cell, col, row))


if __name__ == "__main__":
    main()
