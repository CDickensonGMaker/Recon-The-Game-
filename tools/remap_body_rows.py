"""Move a unit's body UV islands onto its own faction row of 'better textures'.

'better textures' is a labelled kit board: five faction rows stacked (US ARMY,
US MARINES, SPECIAL FORCES, NVA, VIET CONG), then patches, then skin swatches.
The rows are column-aligned - shirt, sleeve, legs, gear sit at the same u in every
row - so an island on the wrong row can be moved down to the right one and lands on
the matching garment.

nva_regular's NVA_Uniform is already correct (every island inside the NVA row).
vc_guerilla's BlackPajama is not: 36 islands spread over five rows, which is why
"US ARMY" lettering reads across a Viet Cong torso.

Only islands sitting on a WRONG FACTION row are moved.  Islands already on the
target row, on the skin swatches, or on the empty black margin are left alone -
black margin is legitimate VC cloth and skin is legitimate bare arms.

Usage: python tools/remap_body_rows.py UNIT MATERIAL TARGET_ROW [--apply]
"""
import argparse, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shrink_master_sheets import load_glb, save_glb

D = r"C:\Users\caleb\RECONgame\assets\nva_vc\characters"
H = 1425.0
ROWS = {"US ARMY": (265, 455), "US MARINES": (462, 618), "SPECIAL FORCES": (620, 772),
        "NVA": (778, 930), "VIET CONG": (933, 1080), "patches": (1080, 1118),
        "skin": (1120, 1425)}
FACTION = ["US ARMY", "US MARINES", "SPECIAL FORCES", "NVA", "VIET CONG"]


def band(v):
    y = v * H
    for n, (a, b) in ROWS.items():
        if a - 14 <= y <= b + 14:
            return n
    return None


def accessor(g, ai):
    a = g['accessors'][ai]; bv = g['bufferViews'][a['bufferView']]
    return bv.get('byteOffset', 0) + a.get('byteOffset', 0), (bv.get('byteStride') or 8), a['count']


def indices(g, bc, ai):
    a = g['accessors'][ai]; bv = g['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    fmt = {5121: '<B', 5123: '<H', 5125: '<I'}[a['componentType']]
    sz = {5121: 1, 5123: 2, 5125: 4}[a['componentType']]
    return [struct.unpack_from(fmt, bc, off + i * sz)[0] for i in range(a['count'])]


def process(unit, matname, target, apply):
    path = os.path.join(D, unit + ".glb")
    g, bc = load_glb(path); bc = bytearray(bc)
    mi = next((i for i, m in enumerate(g['materials']) if m.get('name', '') == matname), None)
    if mi is None:
        return None
    ta, tb = ROWS[target]
    moved = kept = 0
    detail = []
    for mesh in g.get('meshes', []):
        for p in mesh.get('primitives', []):
            if p.get('material') != mi:
                continue
            ai = p['attributes']['TEXCOORD_0']
            off, st, n = accessor(g, ai)
            uv = [struct.unpack_from('<ff', bc, off + i * st) for i in range(n)]
            idx = indices(g, bc, p['indices'])
            parent = list(range(n))
            def find(x):
                while parent[x] != x:
                    parent[x] = parent[parent[x]]; x = parent[x]
                return x
            for t in range(0, len(idx), 3):
                for a_, b_ in ((idx[t], idx[t+1]), (idx[t+1], idx[t+2])):
                    ra, rb = find(a_), find(b_)
                    if ra != rb: parent[rb] = ra
            groups = {}
            for i in range(n):
                groups.setdefault(find(i), []).append(i)
            for _, members in groups.items():
                vs = [uv[i][1] for i in members]
                src = band((min(vs) + max(vs)) / 2)
                if src is None or src == target or src not in FACTION:
                    kept += 1
                    continue
                sa, sb = ROWS[src]
                for i in members:
                    u, v = uv[i]
                    f = (v * H - sa) / float(sb - sa)          # position within source row
                    struct.pack_into('<ff', bc, off + i * st, u, (ta + f * (tb - ta)) / H)
                moved += 1
                detail.append((mesh.get('name', '?')[:30], src, len(members)))
    if apply:
        save_glb(path, g, bytes(bc))
    return moved, kept, detail


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("unit"); ap.add_argument("material"); ap.add_argument("target_row")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    r = process(a.unit, a.material, a.target_row, a.apply)
    if r is None:
        print("material not found"); return
    moved, kept, detail = r
    for mesh, src, n in detail:
        print("   %-32s %-16s -> %-12s (%d verts)" % (mesh, src, a.target_row, n))
    print("\n%s %s: %d islands moved to %s, %d left alone%s" % (
        a.unit, a.material, moved, a.target_row, kept, "" if a.apply else "  (dry run)"))


if __name__ == "__main__":
    main()
