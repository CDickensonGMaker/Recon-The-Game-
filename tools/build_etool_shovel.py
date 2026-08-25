"""US M-1943 pattern folding entrenching tool, FOLDED OUT (spade configuration).

    blender -b --factory-startup -P build_etool_shovel.py

Game-ready NPC hand prop for RECONgame. Real-world scale, PSX register, one material,
one 64x64 embedded atlas. Re-runnable from an empty scene.

DIMENSIONS (researched, reconciled 2026-08-24):
  overall extended 28 in = 0.711 m   (worthpoint M1943 listing; venturesurplus M1943/M1951)
  wood handle      16 in = 0.406 m   (venturesurplus M1943 "roughly 16 inches")
  shank + collar    3 in = 0.076 m   (28 - 16 - 9, the residual)
  blade             9 x 6.3 in = 0.229 x 0.160 m  (proportion off photo reference;
                                       repro listing gives 18 x 14 cm, repros run small)

ORIENTATION CONTRACT (measured off assets/world/props/sog_bowie.glb, the project's only
shipped held hand prop): origin AT THE GRIP, working end toward glTF +Z, butt toward
glTF -Z. With export_yup that is Blender -Y = blade, Blender +Y = butt.
"""
import bpy, bmesh, math, os, struct, zlib, sys
from mathutils import Vector

REPO = r"C:\Users\caleb\RECONgame"
SCRATCH = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0027fdb1-7538-4d57-aa88-85a876fd7c17\scratchpad"
BLEND = os.path.join(REPO, "assets", "world", "props", "etool_shovel.blend")
GLB = os.path.join(REPO, "assets", "world", "props", "etool_shovel.glb")
TEX = os.path.join(SCRATCH, "etool_psx.png")
NAME = "prop_etool_shovel"

# --- researched geometry, metres -------------------------------------------------
OVERALL = 0.711
HANDLE_L = 0.406
BLADE_L = 0.229
BLADE_W = 0.160
Y_BUTT = HANDLE_L / 2.0            # +0.203  origin = mid-shaft fist grip
Y_HBOT = -HANDLE_L / 2.0           # -0.203
Y_TIP = -(OVERALL - Y_BUTT)        # -0.508
Y_SHLD = Y_TIP + BLADE_L           # -0.279
R_BUTT, R_BOT = 0.0180, 0.0160     # ~1.4 in -> 1.26 in dia, tapered wood
DISH = 0.016                       # blade dish depth
BTHICK = 0.004

# atlas rects (u0,v0,u1,v1)
UV_WOOD = (0.03, 0.03, 0.46, 0.97)
UV_STEEL = (0.54, 0.03, 0.97, 0.97)


# ---------------------------------------------------------------- texture ---------
def _rand(seed):
    s = seed & 0xFFFFFFFF
    while True:
        s = (1103515245 * s + 12345) & 0x7FFFFFFF
        yield s / 0x7FFFFFFF


def write_atlas(path, size=64):
    """64x64 PSX sheet: left half oiled hickory, right half worn olive-drab steel."""
    r = _rand(20260824)
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            if x < size // 2:                      # wood, grain runs down v
                g = math.sin(x * 1.9 + math.sin(y * 0.20) * 1.4)
                t = 0.5 + 0.5 * g
                n = next(r) * 0.07
                cr = 0.30 + 0.20 * t + n
                cg = 0.20 + 0.14 * t + n
                cb = 0.11 + 0.07 * t + n
                if (x * 7 + y * 3) % 53 == 0:      # dark grain fleck
                    cr, cg, cb = cr * 0.6, cg * 0.6, cb * 0.6
            else:                                   # olive-drab steel
                u = x - size // 2
                n = next(r) * 0.10
                cr = 0.20 + n
                cg = 0.22 + n
                cb = 0.14 + n
                if u < 4 or u > 27:                # darker edge wear band
                    cr, cg, cb = cr * 1.25, cg * 1.25, cb * 1.20
                if (u * 5 + y * 11) % 37 == 0:     # bare-metal scuff
                    cr, cg, cb = 0.40, 0.41, 0.38
                if (u * 3 - y * 2) % 61 == 0:      # rust speck
                    cr, cg, cb = 0.32, 0.17, 0.08
            row += bytes((min(255, int(c * 255)) for c in (cr, cg, cb)))
        rows.append(bytes(row))
    raw = b"".join(b"\x00" + rw for rw in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return len(png)


# ---------------------------------------------------------------- mesh helpers ----
V, F, UV = [], [], []          # verts, faces (index tuples), per-face uv tuples


def add(vs, uvs):
    base = len(V)
    V.extend(vs)
    return list(range(base, base + len(uvs) and base + len(vs)))


def face(idx, uvs):
    F.append(tuple(idx))
    UV.append(tuple(uvs))


def rect_uv(rect, s, t):
    """s,t in 0..1 -> point inside an atlas rect, inset so PSX texels never bleed."""
    u0, v0, u1, v1 = rect
    return (u0 + (u1 - u0) * min(max(s, 0.0), 1.0),
            v0 + (v1 - v0) * min(max(t, 0.0), 1.0))


def ring(y, radius, n=8, phase=0.0):
    out = []
    for i in range(n):
        a = phase + 2.0 * math.pi * i / n
        out.append(Vector((radius * math.cos(a), y, radius * math.sin(a))))
    return out


def push(vs):
    base = len(V)
    V.extend(vs)
    return list(range(base, base + len(vs)))


def tube(rings, radii, ys, rect, n=8, cap_lo=False, cap_hi=False, vspan=(0.0, 1.0)):
    """rings: list of index lists, bottom-first."""
    for k in range(len(rings) - 1):
        lo, hi = rings[k], rings[k + 1]
        t0 = vspan[0] + (vspan[1] - vspan[0]) * (k / (len(rings) - 1))
        t1 = vspan[0] + (vspan[1] - vspan[0]) * ((k + 1) / (len(rings) - 1))
        for i in range(n):
            j = (i + 1) % n
            s0, s1 = i / n, (i + 1) / n
            face([lo[i], lo[j], hi[j], hi[i]],
                 [rect_uv(rect, s0, t0), rect_uv(rect, s1, t0),
                  rect_uv(rect, s1, t1), rect_uv(rect, s0, t1)])
    if cap_hi:
        face(list(reversed(rings[-1])),
             [rect_uv(rect, 0.5 + 0.4 * math.cos(2 * math.pi * i / n),
                      0.5 + 0.4 * math.sin(2 * math.pi * i / n)) for i in reversed(range(n))])
    if cap_lo:
        face(rings[0],
             [rect_uv(rect, 0.5 + 0.4 * math.cos(2 * math.pi * i / n),
                      0.5 + 0.4 * math.sin(2 * math.pi * i / n)) for i in range(n)])


# ---------------------------------------------------------------- parts -----------
def build_handle():
    """Tapered octagonal wood shaft. Real M-1943 shaft is one piece of hickory,
    round-to-slightly-oval; 8 sides is the PSX read of that."""
    lo = push(ring(Y_HBOT, R_BOT))
    hi = push(ring(Y_BUTT, R_BUTT))
    tube([lo, hi], None, None, UV_WOOD, cap_lo=True, cap_hi=True)


def build_collar():
    """The folding collar / locking nut at the blade-handle junction. Historynet:
    'an aluminum nut locked the curved blade in place, either at 180 degrees as a
    spade or 90 degrees as a pick or hoe'. Folded out = the 180 degree seat."""
    a = push(ring(-0.170, 0.0192))
    b = push(ring(-0.200, 0.0255))     # the nut bulge
    c = push(ring(-0.230, 0.0192))
    tube([a, b, c], None, None, UV_STEEL, vspan=(0.62, 0.98))


def build_shank():
    """Flat steel strap (the riveted 'wings' hilt) from the collar to the blade.

    Both ends are BURIED - the top inside the collar sleeve, the bottom inside the
    blade shoulder - so the box carries no end caps: a cap there would be an interior
    face, and an un-overlapped butt joint reads as a broken gap (it did on pass 1)."""
    y0, y1 = -0.220, Y_SHLD - 0.020
    hx, hz = 0.0190, 0.0050
    lo = push([Vector((-hx, y1, -hz)), Vector((hx, y1, -hz)),
               Vector((hx, y1, hz)), Vector((-hx, y1, hz))])
    hi = push([Vector((-hx, y0, -hz)), Vector((hx, y0, -hz)),
               Vector((hx, y0, hz)), Vector((-hx, y0, hz))])
    sq = [rect_uv(UV_STEEL, a, b) for a, b in
          ((0.05, 0.45), (0.30, 0.45), (0.30, 0.60), (0.05, 0.60))]
    for i in range(4):
        j = (i + 1) % 4
        face([lo[i], lo[j], hi[j], hi[i]], sq)


# blade rows: (t along blade 0=shoulder .. 1=tip, half width). The M-1943 spade
# flares fast off a narrow shoulder and closes to a BLUNT point, not a spear tip.
ROWS = [(0.00, 0.050), (0.26, 0.080), (0.66, 0.074), (1.00, 0.030)]
COLS = 5


def build_blade():
    """Slightly dished spade with a tapered point. Concave face toward +Z."""
    front, back = [], []
    for t, hw in ROWS:
        y = Y_SHLD + (Y_TIP - Y_SHLD) * t
        fr, bk = [], []
        for c in range(COLS):
            u = -1.0 + 2.0 * c / (COLS - 1)
            x = hw * u
            z = DISH * (u * u) - DISH * 0.5
            fr.append(Vector((x, y, z)))
            bk.append(Vector((x, y, z - BTHICK)))
        front.append(push(fr))
        back.append(push(bk))

    def uvf(r, c, flip):
        s = c / (COLS - 1)
        t = 1.0 - r / (len(ROWS) - 1)
        return rect_uv(UV_STEEL, s if not flip else 1.0 - s, t * 0.58)

    for r in range(len(ROWS) - 1):
        for c in range(COLS - 1):
            face([front[r][c], front[r][c + 1], front[r + 1][c + 1], front[r + 1][c]],
                 [uvf(r, c, 0), uvf(r, c + 1, 0), uvf(r + 1, c + 1, 0), uvf(r + 1, c, 0)])
            face([back[r][c], back[r + 1][c], back[r + 1][c + 1], back[r][c + 1]],
                 [uvf(r, c, 1), uvf(r + 1, c, 1), uvf(r + 1, c + 1, 1), uvf(r, c + 1, 1)])
    rim = [rect_uv(UV_STEEL, x, y) for x, y in
           ((0.02, 0.60), (0.14, 0.60), (0.14, 0.64), (0.02, 0.64))]
    for r in range(len(ROWS) - 1):                       # left / right edges
        face([front[r][0], front[r + 1][0], back[r + 1][0], back[r][0]], rim)
        face([front[r + 1][COLS - 1], front[r][COLS - 1],
              back[r][COLS - 1], back[r + 1][COLS - 1]], rim)
    for c in range(COLS - 1):                            # tip edge and shoulder edge
        face([front[-1][c], front[-1][c + 1], back[-1][c + 1], back[-1][c]], rim)
        face([front[0][c + 1], front[0][c], back[0][c], back[0][c + 1]], rim)


# ---------------------------------------------------------------- assemble --------
def wipe():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for d in list(coll):
            try:
                coll.remove(d, do_unlink=True)
            except Exception:
                pass


def make_material():
    img = bpy.data.images.load(TEX)
    img.name = "etool_psx"
    img.colorspace_settings.name = "sRGB"
    img.pack()
    mat = bpy.data.materials.new("etool_psx")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.92
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"          # -> glTF magFilter NEAREST (9728)
    tex.extension = "EXTEND"
    tex.location = (-360, 260)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.diffuse_color = (0.28, 0.30, 0.20, 1.0)
    return mat


def main():
    wipe()
    kb = write_atlas(TEX)
    build_handle()
    build_collar()
    build_shank()
    build_blade()

    me = bpy.data.meshes.new(NAME)
    me.from_pydata([tuple(v) for v in V], [], F)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for pi, poly in enumerate(me.polygons):
        poly.use_smooth = False            # PSX: flat shading throughout
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = UV[pi][k]

    obj = bpy.data.objects.new(NAME, me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(make_material())

    # hygiene: doubles, normals outside, no loose geometry
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    dims = tuple(round(max(p[i] for p in bb) - min(p[i] for p in bb), 4) for i in range(3))
    print("PARTS ok | verts %d | quads/ngons %d | TRIS %d" % (len(me.vertices), len(me.polygons), tris))
    print("atlas 64x64 = %d bytes" % kb)
    print("local dims X/Y/Z %s   overall along Y %.4f m" % (dims, dims[1]))
    print("origin at mid-shaft grip: butt y=+%.3f  tip y=%.3f" % (Y_BUTT, Y_TIP))

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0        # no .blend1
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_animations=False,
                              export_cameras=False, export_lights=False)
    print("SAVED  %s" % BLEND)
    print("EXPORT %s  %.1f KB" % (GLB, os.path.getsize(GLB) / 1024.0))


main()
