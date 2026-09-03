"""Give a VC body the NVA body's (correct) UV layout, shifted to the Viet Cong row.

'better textures' is a labelled kit board: five faction rows stacked, column-aligned,
so shirt/sleeve/legs sit at the same u in every row.

nva_regular's NVA_Uniform is hand-fitted - every island lands inside the NVA row.
The VC bodies never got that treatment: their islands are strewn across five rows,
which is why a Viet Cong torso reads "NORTH VIETNAMESE ARMY" off a row label.

Both are the same base humanoid, so this is a positional UV transfer: copy the donor
uv for the vertex at the same 3D point, then map v from the donor row down to the
Viet Cong row.  --align handles the units that are the same mesh translated in world
space; --already-mapped copies verbatim when the donor is itself already correct.

Usage:
  python tools/transfer_body_uv.py vc_guerilla vc_medic --apply
  python tools/transfer_body_uv.py vc_rpg --donor vc_guerilla --align --already-mapped --apply
"""
import argparse, math, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrink_master_sheets import load_glb, save_glb

D = r"C:\Users\caleb\RECONgame\assets\nva_vc\characters"
DONOR, DONOR_MAT = "nva_regular", "NVA_Uniform"
H = 1425.0
SRC_ROW, VC_ROW = (778.0, 930.0), (933.0, 1080.0)


def prims(g, matname):
    mi = next((i for i, m in enumerate(g['materials']) if m.get('name', '') == matname), None)
    if mi is None:
        return
    for mesh in g.get('meshes', []):
        for p in mesh.get('primitives', []):
            if p.get('material') == mi:
                yield mesh, p


def rw(g, p, attr):
    a = g['accessors'][p['attributes'][attr]]
    bv = g['bufferViews'][a['bufferView']]
    default = 12 if attr == 'POSITION' else 8
    return bv.get('byteOffset', 0) + a.get('byteOffset', 0), (bv.get('byteStride') or default), a['count']


def bbox_of(g, bc, matname):
    mn = [9e9] * 3
    for _, p in prims(g, matname):
        po, ps, n = rw(g, p, 'POSITION')
        for i in range(n):
            v = struct.unpack_from('<fff', bc, po + i * ps)
            for k in range(3):
                mn[k] = min(mn[k], v[k])
    return mn


def donor_points(unit, matname):
    """Flat list of (pos, uv) - for nearest-neighbour when hashing misses."""
    g, bc = load_glb(os.path.join(D, unit + ".glb"))
    pts = []
    for _, p in prims(g, matname):
        po, ps, n = rw(g, p, 'POSITION')
        uo, us, _ = rw(g, p, 'TEXCOORD_0')
        for i in range(n):
            pts.append((struct.unpack_from('<fff', bc, po + i * ps),
                        struct.unpack_from('<ff', bc, uo + i * us)))
    return pts


def donor_map(unit, matname):
    g, bc = load_glb(os.path.join(D, unit + ".glb"))
    out = {}
    for _, p in prims(g, matname):
        po, ps, n = rw(g, p, 'POSITION')
        uo, us, _ = rw(g, p, 'TEXCOORD_0')
        for i in range(n):
            x, y, z = struct.unpack_from('<fff', bc, po + i * ps)
            u, v = struct.unpack_from('<ff', bc, uo + i * us)
            out[(round(x, 4), round(y, 4), round(z, 4))] = (u, v)
            out[(round(x, 3), round(y, 3), round(z, 3))] = (u, v)
    return out


def process(unit, matname, dmap, apply, align, src_row, dpts=None, radius=0.002):
    path = os.path.join(D, unit + ".glb")
    g, bc = load_glb(path); bc = bytearray(bc)
    off3 = (0.0, 0.0, 0.0)
    if align is not None:
        mn = bbox_of(g, bc, matname)
        off3 = tuple(align[k] - mn[k] for k in range(3))
    hit = miss = 0
    for _, p in prims(g, matname):
        po, ps, n = rw(g, p, 'POSITION')
        uo, us, _ = rw(g, p, 'TEXCOORD_0')
        for i in range(n):
            x, y, z = struct.unpack_from('<fff', bc, po + i * ps)
            x += off3[0]; y += off3[1]; z += off3[2]
            src = dmap.get((round(x, 4), round(y, 4), round(z, 4))) \
                or dmap.get((round(x, 3), round(y, 3), round(z, 3)))
            if src is None and dpts:
                best = None; bd = radius * radius
                for dp, duv in dpts:
                    d = (x - dp[0]) ** 2 + (y - dp[1]) ** 2 + (z - dp[2]) ** 2
                    if d < bd:
                        bd = d; best = duv
                src = best
            if src is None:
                miss += 1
                continue
            u, v = src
            f = (v * H - src_row[0]) / (src_row[1] - src_row[0])
            nv = (VC_ROW[0] + f * (VC_ROW[1] - VC_ROW[0])) / H
            struct.pack_into('<ff', bc, uo + i * us, u, nv)
            hit += 1
    if apply and hit:
        save_glb(path, g, bytes(bc))
    return hit, miss


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("units", nargs='*', default=["vc_guerilla"])
    ap.add_argument("--material", default="BlackPajama")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--donor")
    ap.add_argument("--donor-material")
    ap.add_argument("--align", action="store_true",
                    help="same mesh moved in world space - translate onto the donor bbox first")
    ap.add_argument("--already-mapped", action="store_true",
                    help="donor UVs already sit on the Viet Cong row - copy verbatim")
    ap.add_argument("--nearest", type=float, default=0.0,
                    help="fall back to the nearest donor vertex within this radius (metres)")
    a = ap.parse_args()
    donor_u = a.donor or DONOR
    donor_m = a.donor_material or DONOR_MAT
    dmap = donor_map(donor_u, donor_m)
    src_row = VC_ROW if a.already_mapped else SRC_ROW
    print("donor %s/%s: %d keyed positions" % (donor_u, donor_m, len(dmap)))
    align = None
    if a.align:
        dg, dbc = load_glb(os.path.join(D, donor_u + ".glb"))
        align = bbox_of(dg, dbc, donor_m)
    dpts = donor_points(donor_u, donor_m) if a.nearest > 0 else None
    for u in a.units:
        hit, miss = process(u, a.material, dmap, a.apply, align, src_row, dpts, a.nearest)
        print("  %-6s %-24s %d verts transferred, %d unmatched" % (
            "APPLY" if a.apply else "DRY", u, hit, miss))


if __name__ == "__main__":
    main()
