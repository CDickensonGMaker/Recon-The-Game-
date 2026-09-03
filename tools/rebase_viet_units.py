"""Rebase the 9 units already on fixed_better_viet_faces to cell 0, inset B.

Their face island is already one whole 1/10 x 1/3 cell - it is just parked at a
different cell per unit, so the dresser's cell numbers mean a different face on
every man.  This translates each face_atlas_mat primitive to cell 0 and applies the
same v-inset (0.72) as the other twelve, so the neck/shoulder band at the bottom of
the cell stops eating a third of the head.

Skin_VC / Hair_Black sample the SAME sheet but are NOT cell-confined on 5 of the 9.
If they rode the atlas they would slide with uv1_offset and smear, so face_atlas_mat
is pointed at an ALIAS image - a second glTF image entry sharing the same bufferView,
zero extra bytes - named so it contains "face_atlas".  Skin/Hair keep the old name
and stay put.  Godot then reports them as "stranded", which is the pre-existing
face/skin merge gap, not a new one.

Usage: python tools/rebase_viet_units.py [--apply]
"""
import argparse, math, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrink_master_sheets import load_glb, save_glb

D = r"C:\Users\caleb\RECONgame\assets\nva_vc\characters"
UNITS = ["nva_mortar_dropper", "nva_mortar_gunner", "nva_mortar_runner", "nva_rpg",
         "nva_rto", "nva_sapper", "vc_rpg", "vc_sapper", "vc_sapper_stripped"]
OLD = "fixed_better_viet_faces"
ALIAS = "face_atlas_viet"
COLS, ROWS = 10, 3
V_INSET = 0.72


def process(path, apply):
    g, bc = load_glb(path)
    bc = bytearray(bc)
    old_img = next((i for i, im in enumerate(g.get('images', [])) if im.get('name') == OLD), None)
    if old_img is None:
        return ('NOIMG',)

    face_mats = {mi for mi, m in enumerate(g.get('materials', []))
                 if m.get('name', '').startswith('face_atlas')}
    if not face_mats:
        return ('NOMAT',)

    # alias image + texture sharing the SAME bufferView -> no extra bytes
    g['images'].append({'name': ALIAS,
                        'bufferView': g['images'][old_img]['bufferView'],
                        'mimeType': g['images'][old_img].get('mimeType', 'image/jpeg')})
    alias_img = len(g['images']) - 1
    samp = g['textures'][0].get('sampler') if g.get('textures') else None
    tex = {'source': alias_img}
    if samp is not None:
        tex['sampler'] = samp
    g.setdefault('textures', []).append(tex)
    alias_tex = len(g['textures']) - 1
    for mi in face_mats:
        pbr = g['materials'][mi].setdefault('pbrMetallicRoughness', {})
        if 'baseColorTexture' in pbr:
            pbr['baseColorTexture']['index'] = alias_tex

    # collect face accessors, refuse any shared with a non-face material
    mine, others = set(), set()
    for mesh in g.get('meshes', []):
        for p in mesh.get('primitives', []):
            ai = p['attributes'].get('TEXCOORD_0')
            if ai is None:
                continue
            (mine if p.get('material') in face_mats else others).add(ai)
    if mine & others:
        return ('SHARED', sorted(mine & others))

    def view(ai):
        a = g['accessors'][ai]; bv = g['bufferViews'][a['bufferView']]
        return bv.get('byteOffset', 0) + a.get('byteOffset', 0), (bv.get('byteStride') or 8), a['count']

    cw, ch = 1.0 / COLS, 1.0 / ROWS
    cells = []
    for ai in sorted(mine):
        off, st, n = view(ai)
        uv = [struct.unpack_from('<ff', bc, off + i * st) for i in range(n)]
        # pick the cell from the island CENTRE: a min on a cell boundary (0.399 vs
        # 0.400) or a sub-cell gib fragment both misfile under round-the-minimum.
        cu = (min(u for u, _ in uv) + max(u for u, _ in uv)) / 2.0
        cv = (min(v for _, v in uv) + max(v for _, v in uv)) / 2.0
        col = max(0, min(COLS - 1, int(math.floor(cu / cw))))
        row = max(0, min(ROWS - 1, int(math.floor(cv / ch))))
        cells.append((col, row))
        for i, (u, v) in enumerate(uv):
            nu = u - col * cw
            nv = (v - row * ch) * V_INSET
            struct.pack_into('<ff', bc, off + i * st, nu, nv)

    if apply:
        save_glb(path, g, bytes(bc))
    return ('OK', sorted(set(cells)), len(mine))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    for u in UNITS:
        r = process(os.path.join(D, u + ".glb"), a.apply)
        tag = "APPLY" if a.apply else "DRY"
        if r[0] != 'OK':
            print("  %-22s %s" % (u, r)); continue
        print("  %-6s %-22s cells found %-22s accessors=%d" % (tag, u, r[1], r[2]))


if __name__ == "__main__":
    main()
