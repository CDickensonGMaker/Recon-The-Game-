"""Generate data/veg_break_bands.json from the segmented tree art.

Every number here is MEASURED off Caleb's GLBs; nothing is chosen.

    cut_low_m   top of the stump part      (the low break joint)
    cut_high_m  top of the stem part       (the high break joint)
    top_m       top of the crown part      (full tree height)
    trunk_r_m   radius of the BREAK FACE   (see below)

trunk_r is the one value an AABB cannot give. A stump's bounding box includes
root flare (broadleaf: 0.97-1.53 m vs a 0.18-0.31 m trunk) and a stem's includes
foliage (bamboo, palms). So instead of bounding either part, this decodes the
stump's vertices and measures the cross-section in a thin slice just under the
cut plane - the actual face the tree breaks along, and the surface a ray must
hit. Radius is taken as the 95th-percentile distance from the slice centroid so
one stray vertex cannot inflate it.

    python gen_veg_break_bands.py            # print the table
    python gen_veg_break_bands.py --write    # write data/veg_break_bands.json
"""
import json, struct, os, glob, math, sys

ROOT = r"C:\Users\caleb\RECONgame"
VEG = os.path.join(ROOT, "assets", "world", "vegetation")
OUT = os.path.join(ROOT, "data", "veg_break_bands.json")

CTYPE = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    d = open(path, "rb").read()
    jl, _ = struct.unpack("<II", d[12:20])
    j = json.loads(d[20:20 + jl])
    off = 20 + jl
    bin_chunk = b""
    while off < len(d):
        cl, ct = struct.unpack("<II", d[off:off + 8])
        if ct == 0x004E4942:
            bin_chunk = d[off + 8:off + 8 + cl]
            break
        off += 8 + cl
    return j, bin_chunk


def read_positions(j, blob, acc_idx):
    a = j["accessors"][acc_idx]
    bv = j["bufferViews"][a["bufferView"]]
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"]
    comp = NCOMP[a["type"]]
    fmt = CTYPE[a["componentType"]]
    size = struct.calcsize("<" + fmt) * comp
    stride = bv.get("byteStride", size)
    out = []
    for i in range(n):
        o = base + i * stride
        out.append(struct.unpack_from("<" + fmt * comp, blob, o))
    return out


def node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[0], m[4], m[8], m[12]],
                [m[1], m[5], m[9], m[13]],
                [m[2], m[6], m[10], m[14]]]
    t = n.get("translation", [0, 0, 0])
    s = n.get("scale", [1, 1, 1])
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    rot = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [[rot[i][k] * s[k] for k in range(3)] + [t[i]] for i in range(3)]


def mul(a, b):
    out = []
    for i in range(3):
        row = [sum(a[i][k] * b[k][c] for k in range(3)) for c in range(3)]
        row.append(sum(a[i][k] * b[k][3] for k in range(3)) + a[i][3])
        out.append(row)
    return out


def all_verts(path):
    """Every vertex of the GLB in the file's own (tree) space."""
    j, blob = load(path)
    nodes = j.get("nodes", [])
    meshes = j.get("meshes", [])
    pts = []

    def walk(idx, xf):
        n = nodes[idx]
        cur = mul(xf, node_matrix(n))
        if "mesh" in n:
            for prim in meshes[n["mesh"]].get("primitives", []):
                pi = prim.get("attributes", {}).get("POSITION")
                if pi is None:
                    continue
                for v in read_positions(j, blob, pi):
                    pts.append(tuple(
                        cur[i][0] * v[0] + cur[i][1] * v[1]
                        + cur[i][2] * v[2] + cur[i][3] for i in range(3)))
        for c in n.get("children", []):
            walk(c, cur)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0]]
    scenes = j.get("scenes", [])
    roots = scenes[j.get("scene", 0)]["nodes"] if scenes else range(len(nodes))
    for r in roots:
        walk(r, ident)
    return pts


def break_face_radius(pts, cut_y):
    """95th-percentile radius of the vertices in a thin slice under the cut."""
    for frac in (0.06, 0.12, 0.25):          # widen until the slice has substance
        band = frac * cut_y
        sl = [p for p in pts if cut_y - band <= p[1] <= cut_y + band * 0.25]
        if len(sl) >= 6:
            cx = sum(p[0] for p in sl) / len(sl)
            cz = sum(p[2] for p in sl) / len(sl)
            rr = sorted(math.hypot(p[0] - cx, p[2] - cz) for p in sl)
            return rr[max(0, int(len(rr) * 0.95) - 1)]
    return 0.0


def has_all(nm):
    return all(os.path.exists(os.path.join(VEG, "%s_%s.glb" % (nm, p)))
               for p in ("stump", "stem", "crown"))


species = sorted(nm for nm in (
    os.path.basename(p)[:-len("_stump.glb")]
    for p in glob.glob(os.path.join(VEG, "*_stump.glb"))) if has_all(nm))

out = {}
print("%-16s %8s %8s %8s %9s" % ("species", "cut_low", "cut_high", "top", "trunk_r"))
for nm in species:
    stump = all_verts(os.path.join(VEG, nm + "_stump.glb"))
    stem = all_verts(os.path.join(VEG, nm + "_stem.glb"))
    crown = all_verts(os.path.join(VEG, nm + "_crown.glb"))
    cut_low = max(p[1] for p in stump)
    cut_high = max(p[1] for p in stem)
    top = max(p[1] for p in crown)
    r = break_face_radius(stump, cut_low)
    out[nm] = {
        "parts": ["stump", "stem", "crown"],
        "cut_low_m": round(cut_low, 3),
        "cut_high_m": round(cut_high, 3),
        "top_m": round(top, 3),
        "trunk_r_m": round(r, 3),
    }
    print("%-16s %8.2f %8.2f %8.2f %9.3f" % (nm, cut_low, cut_high, top, r))

if "--write" in sys.argv:
    doc = {
        "_source": "generated by tools/gen_veg_break_bands.py from the "
                   "*_stump/_stem/_crown GLBs in assets/world/vegetation/ - "
                   "every value is measured, none is authored by hand. "
                   "Re-run after re-exporting any segment.",
        "species": out,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent="\t", sort_keys=True)
        f.write("\n")
    print("\nwrote %s (%d species)" % (OUT, len(out)))
