"""The firebase building kit: shapes for a US fire support base, c. 1968.

    python tools/gen_firebase_textures.py      (once - writes tex/)
    blender -b -P tools/gen_firebase.py        (writes the review kit + manifest)

This module is IMPORTED BY tools/build_fsb_main.py, which assembles the canonical
fsb_main.glb from an authored layout table. It is a shapes library first and a script
second: the kit GLBs it can write are a REVIEW artefact, not a shipped asset set -
nothing in the game places a firebase piece individually (site_layouts.gd has no
firebase entries and stamp_firebase died with fsb_main), so shipping 24 kit GLBs would
be 24 files with one consumer, which ADR-023 would correctly come for.

WHAT THIS REPLACES
  The shipped fsb_main.glb carries `fsb_main_FRAInfantry.png` - a SPRING 1944 French
  faction atlas - and 65 of its 97 materials have no baseColorTexture at all. Its budget
  is inverted: mortar_pit 9,390 tris for a 2 m hole and mg_nest 8,129, while MessHall
  (13x9x4.5 m) and Hootch are 56 tris each. A mortar pit costs 168x a mess hall.

THE OWNER'S BRIEF
  "more open tents" - GP tents with the sides ROLLED AND TIED, not canvas boxes.
  "sleeping bunkers" - dug in, overhead cover, where you go when the mortars land.
  "enterable buildings" - verified with the player capsule (r=0.4, h=1.8), not asserted.
  "real defenses" - a bunker line on a berm, three belts of wire, claymores between.
  "real mg bunkers" - an embrasure that actually sees out, proven by a LOS fan.

DOCTRINE (assets/reference/references/reference_firebase_layout.md - 17 sources,
25 claims adversarially verified)
  Circle laid from a centre stake; fighting bunkers every 15 degrees; ~4 ft earth berm;
  wire 1-3 concertina belts with claymores and trip flares laced between; 6-gun battery
  in a STAR (5 on the points, #6 centre firing illumination); gun pit circular ~9 m with
  a 3 ft berm; TOC/FDC central and dug in; mortar pits circular, parapet <=50 cm with a
  1 m sighting gap. A GATE IS A ROAD GAP interrupting the trench and wire - not a
  fortress gate. Today's SOCKET_A->SOCKET_B span is 28.6 m, which is a highway.

CONTRACTS THIS KIT HONOURS
  -col        Godot builds trimesh collision from the suffix. Applied SELECTIVELY here:
              walls, berms, bunker shells, decks and the tower get it; wire ribbons, guy
              lines, antennas and clutter do not. The incumbent put -col on all 652
              meshes, which is a physics tax nobody collects.
  markers     Empties read by name. LOCAL +Z is facing in Godot, which is Blender local
              -Y, so a marker looking along world angle `a` needs rotation_euler.z =
              a + 90deg (measured, tools/make_huey_interior.py:22-23). Never re-derive it.
  wire        assets/us/props/emplacements/barbwire_card.glb is THE only wire (war room
              2026-07-17, 2.88 m tiling). Imported, never re-modelled. Mesh names must
              keep the `bwire_card` prefix or tools/diag_fsb_seat.gd:100 fails HARD with
              a misleading message about wire base height.
"""
import bpy, bmesh, math, random, os, json, sys
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fb_kit

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\firebase"
KIT_DIR = os.path.join(OUT_DIR, "kit")
TEX_DIR = os.path.join(OUT_DIR, "tex")
WIRE_GLB = r"C:\Users\caleb\RECONgame\assets\us\props\emplacements\barbwire_card.glb"

# Player capsule r=0.4 h=1.8 (scenes/player/player.tscn:9-11). Bunker crawl-ins are
# deliberately tighter than a house door but never below stand-up height inside.
DOOR_W, DOOR_H = 1.05, 1.95
CRAWL_W, CRAWL_H = 0.95, 1.60

MATS = {
    "fb_sandbag":    ((0.54, 0.49, 0.38, 1.0), 0.94),
    "fb_earth":      ((0.48, 0.35, 0.24, 1.0), 0.96),
    "fb_timber":     ((0.42, 0.33, 0.22, 1.0), 0.90),
    "fb_psp":        ((0.38, 0.39, 0.36, 1.0), 0.62),
    "fb_canvas":     ((0.41, 0.42, 0.31, 1.0), 0.88),
    "fb_corrugated": ((0.44, 0.44, 0.42, 1.0), 0.70),
    "fb_crate":      ((0.34, 0.36, 0.24, 1.0), 0.86),
    # Weapons are SOLID colour, never fb_psp. Pierced steel planking is perforated - it
    # has holes punched through it - and putting it on a gun barrel or a mortar tube
    # reads as slotted metal. No texture file exists for these two on purpose, so
    # ensure_materials leaves them flat.
    "fb_gunmetal":   ((0.055, 0.055, 0.060, 1.0), 0.42),
    "fb_olive":      ((0.152, 0.180, 0.110, 1.0), 0.78),
    # Appended, never inserted: every face in this file is assigned by index into MAT_INDEX.
    fb_kit.WALL_MAT: ((0.54, 0.49, 0.38, 1.0), 0.94),
    "fb_mud":        ((0.26, 0.18, 0.12, 1.0), 0.55),
}
MAT_INDEX = {n: i for i, n in enumerate(MATS)}
assert MAT_INDEX[fb_kit.WALL_MAT] == fb_kit.WALL_MAT_INDEX

## The wall tile is 2.0 m because that is the only square footprint holding a whole number of
## both 0.50 m bags and 0.125 m courses; at the kit's 1.6 m it would land mid-bag and tile wrong.
UV_TILE = {fb_kit.WALL_MAT: fb_kit.WALL_TILE}
SIDES = {0: (0, -1), 1: (1, 0), 2: (0, 1), 3: (-1, 0)}


def ensure_materials():
    mats = []
    for name, (col, rough) in MATS.items():
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf:
                bsdf.inputs["Base Color"].default_value = col
                bsdf.inputs["Roughness"].default_value = rough
                path = os.path.join(TEX_DIR, name + ".png")
                if os.path.exists(path):
                    img = bpy.data.images.load(path, check_existing=True)
                    tex = nt.nodes.new("ShaderNodeTexImage")
                    tex.image = img
                    tex.location = (-420, 220)
                    tex.interpolation = 'Closest'
                    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.diffuse_color = col
        mats.append(m)
    return mats


def box_project_uvs(mesh, tile=1.6):
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    names = [m.name if m else None for m in mesh.materials]
    for poly in mesh.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        mt = names[poly.material_index] if poly.material_index < len(names) else None
        tile = UV_TILE.get(mt, 1.6)
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv.data[li].uv = (u / tile, v / tile)


def box(bm, centre, size, mat="fb_timber", rot=None, taper=1.0):
    cx, cy, cz = centre
    sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    tx, ty = sx * taper, sy * taper
    pts = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
           (-tx, -ty, sz), (tx, -ty, sz), (tx, ty, sz), (-tx, ty, sz)]
    if rot is not None:
        R = Euler(rot).to_matrix()
        pts = [R @ Vector(p) for p in pts]
    vs = [bm.verts.new((p[0] + cx, p[1] + cy, p[2] + cz)) for p in pts]
    idx = MAT_INDEX[mat]
    for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([vs[i] for i in f]).material_index = idx
        except ValueError:
            pass


## A riser taller than this and the player cannot walk in - they have to jump into their own
## bunker. Godot's CharacterBody3D has no automatic step-up, so the geometry has to be kind.
MAX_STEP = 0.24


def dug_pit(bm, w, d, sink, door_w, door_side=-1, mat="fb_earth", t=0.55):
    """Excavated pit as four walls plus a floor, with the doorway slot OPEN TO THE FLOOR.

    One solid earth box looked identical from outside but left no opening below grade: the
    door gap existed only in the sandbag wall above z=0, so the way in was over the lip.
    """
    box(bm, (0, -door_side * (d / 2.0 - t / 2.0), -sink / 2.0), (w, t, sink), mat)
    for sx in (-1, 1):
        box(bm, (sx * (w / 2.0 - t / 2.0), 0, -sink / 2.0), (t, d - t * 2.0, sink), mat)
    seg = (w - door_w) / 2.0
    if seg > 0.05:
        for sx in (-1, 1):
            box(bm, (sx * (door_w + seg) / 2.0, door_side * (d / 2.0 - t / 2.0), -sink / 2.0),
                (seg, t, sink), mat)
    box(bm, (0, 0, -sink - 0.06), (w, d, 0.12), mat)


def beam_between(bm, p0, p1, thick, mat):
    """A beam spanning two explicit points, so nothing floats at a guessed pitch."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    if ln < 0.05:
        return
    box(bm, ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0, (p0[2] + p1[2]) / 2.0),
        (ln, thick, thick), mat,
        rot=(0, -math.asin(max(-1.0, min(1.0, dz / ln))), math.atan2(dy, dx)))


## ------------------------------------------------------- the sandbag modules --
## Revetments are generated by fb_kit.build_sandbag_wall from the 0.50 x 0.25 x 0.13 m bag:
## a slab whose outer face carries a per-bag lump, with the top course as real bag meshes.
## Heights land on whole courses - a bag is never scaled to reach a requested height.
BAG_RUNS = []

## "real" spends ~88 tris per linear metre on the top course and is what gives a revetment its
## silhouette; "slab" drops it to zero and lets the texture carry the crest.
BAG_TOP_COURSE = "real"


def bag_run(p0, p1, h, rng, jitter=0.05, side=1.0):
    """Record a revetment centreline from p0 to p1, stacked to height h.

    The run is resolved into geometry in build_piece so the whole piece stays one mesh.
    """
    ln = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    if ln < 0.3:
        return
    z = p0[2] if len(p0) > 2 else 0.0
    BAG_RUNS.append(([(p0[0], p0[1]), (p1[0], p1[1])], h, z, side,
                     rng.randint(0, 1 << 20)))


def bag_ring(r, h, rng, seg=12, z=0.0):
    """Closed revetment ring of real modules - gun pits, mortar pits, tower base."""
    for i in range(seg):
        a0, a1 = math.tau * i / seg, math.tau * (i + 1) / seg
        bag_run((math.cos(a0) * r, math.sin(a0) * r, z),
                (math.cos(a1) * r, math.sin(a1) * r, z), h, rng)


def berm(bm, p0, p1, h, w, mat="fb_earth"):
    """Trapezoidal earth berm - wide at grade, narrow on top, the way spoil actually sits.

    Doctrine puts ~4 ft of turned earth on the bunker line (FSB Kramer). Bunkers are cut
    INTO this, not stood beside it: "crewmen on the berm had built bunkers into the
    earthen wall of the perimeter" (production/research/firebase_construction_1968_70.md).
    """
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy)
    if ln < 0.1:
        return
    box(bm, ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0, h / 2.0),
        (ln, w, h), mat, rot=(0, 0, math.atan2(dy, dx)), taper=0.45)


def corrugated_roof(bm, cx, cy, cz, w, d, mat="fb_corrugated", n=None, th=0.06):
    """Overlapping tin sheets. One box per sheet so the roof has a seam rhythm."""
    n = n or max(2, int(w / 0.85))
    for i in range(n):
        x = cx - w / 2.0 + w * (i + 0.5) / n
        box(bm, (x, cy, cz + (0.02 if i % 2 else 0.0)), (w / n * 1.12, d, th), mat)


def overhead_cover(bm, cx, cy, cz, w, d, rng):
    """The bunker roof of record: timber stringers, PSP, then two courses of sandbags.

    This layering is the whole reason a bunker reads as protection instead of a shed.
    """
    for i in range(max(3, int(d / 0.55))):
        y = cy - d / 2.0 + d * (i + 0.5) / max(3, int(d / 0.55))
        box(bm, (cx, y, cz + 0.09), (w + 0.35, 0.16, 0.18), "fb_timber")
    box(bm, (cx, cy, cz + 0.24), (w + 0.4, d + 0.4, 0.05), "fb_psp")
    # Same trick as the walls: the sandbag mass is a slab, and only the PERIMETER ring
    # is individual bags. A full 2-course field over a 7x5 m roof is 216 boxes, and you
    # can only ever see the edge of it from the ground.
    box(bm, (cx, cy, cz + 0.42), (w + 0.3, d + 0.3, 0.32), "fb_sandbag")
    nx, ny = max(2, int(w / 0.62)), max(2, int(d / 0.62))
    for i in range(nx):
        x = cx - w / 2.0 + w * (i + 0.5) / nx
        for sy in (-1, 1):
            box(bm, (x, cy + sy * (d / 2.0 + 0.12), cz + 0.60), (0.60, 0.42, 0.22),
                "fb_sandbag", rot=(0, 0, rng.uniform(-0.07, 0.07)))
    for j in range(ny):
        y = cy - d / 2.0 + d * (j + 0.5) / ny
        for sx in (-1, 1):
            box(bm, (cx + sx * (w / 2.0 + 0.12), y, cz + 0.60), (0.42, 0.60, 0.22),
                "fb_sandbag", rot=(0, 0, rng.uniform(-0.07, 0.07)))


# ------------------------------------------------------------------- markers --
MARKERS = []


def marker(name, pos, face=0.0, **props):
    MARKERS.append({"name": name, "pos": pos, "face": face, "props": props})


## Godot local +Z == Blender local -Y (measured, tools/make_huey_interior.py:22-23) and
## seat_system.gd:9 makes local +Z the facing axis. Blender local -Y under
## rotation_euler (0,0,t) points at (sin t, -cos t), so a marker meant to face
## (cos a, sin a) needs t = a + 90deg. Getting this wrong aims FACE_OUT the wrong way,
## which boots the player outside the wire and inverts the whole gate economy.
def face_to_euler_z(a):
    return a + math.pi / 2.0


def reset_markers():
    global MARKERS
    MARKERS = []
    return MARKERS


# ------------------------------------------------------- families: defences --
def fam_bunker_mg(bm, rng):
    """THE MG BUNKER. A wide embrasure that actually sees out, and you can get inside.

    Sunk 0.9 m so the firing slit sits at grade. A bunker whose slit is at chest height
    above ground is a pillbox, which is the wrong war.
    """
    w, d, sink, wall = 4.6, 3.8, 0.9, 1.95
    dug_pit(bm, w, d, sink, CRAWL_W, door_side=1)
    box(bm, (0, 0, -sink + 0.06), (w - 0.5, d - 0.5, 0.12), "fb_psp")
    slit_w, slit_z = 2.5, 0.42
    for s in (-1, 1):
        bag_run((s * slit_w / 2.0, -d / 2.0, 0), (s * w / 2.0, -d / 2.0, 0), wall, rng)
    bag_run((-slit_w / 2.0, -d / 2.0, 0), (slit_w / 2.0, -d / 2.0, 0), slit_z, rng)
    box(bm, (0, -d / 2.0, slit_z + 0.78), (slit_w + 0.4, 0.6, 0.32), "fb_timber")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), wall, rng)
    for s in (-1, 1):
        bag_run((s * CRAWL_W / 2.0, d / 2.0, 0), (s * w / 2.0, d / 2.0, 0), wall, rng)
    box(bm, (0, d / 2.0, CRAWL_H + 0.2), (CRAWL_W + 0.4, 0.55, 0.34), "fb_timber")
    overhead_cover(bm, 0, 0, wall, w, d, rng)
    box(bm, (0, -d / 2.0 + 0.55, -sink + 0.5), (1.5, 0.5, 0.75), "fb_crate")
    marker("mg_fire_point", (0.0, -d / 2.0 + 0.35, slit_z - sink + 0.55), -math.pi / 2.0,
           work_type="mg")
    marker("bunker_los_point", (0.0, -d / 2.0 + 0.2, slit_z + 0.1), -math.pi / 2.0)
    marker("door_main", (0.0, d / 2.0 + 0.9, -sink + 0.12), math.pi / 2.0, door_width=CRAWL_W)
    return w, d, wall + 0.6


def fam_bunker_fighting(bm, rng, sealed=False):
    """Perimeter fighting bunker, one per 15 degrees of the line."""
    w, d, sink, wall = 3.4, 2.9, 0.85, 1.9
    dug_pit(bm, w, d, sink, CRAWL_W, door_side=1)
    box(bm, (0, 0, -sink + 0.06), (w - 0.45, d - 0.45, 0.12), "fb_psp")
    slit_w, slit_z = 1.6, 0.45
    for s in (-1, 1):
        bag_run((s * slit_w / 2.0, -d / 2.0, 0), (s * w / 2.0, -d / 2.0, 0), wall, rng)
    bag_run((-slit_w / 2.0, -d / 2.0, 0), (slit_w / 2.0, -d / 2.0, 0), slit_z, rng)
    box(bm, (0, -d / 2.0, slit_z + 0.73), (slit_w + 0.35, 0.55, 0.3), "fb_timber")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), wall, rng)
    if sealed:
        bag_run((-w / 2.0, d / 2.0, 0), (w / 2.0, d / 2.0, 0), wall, rng)
    else:
        for s in (-1, 1):
            bag_run((s * CRAWL_W / 2.0, d / 2.0, 0), (s * w / 2.0, d / 2.0, 0),
                         wall, rng)
        box(bm, (0, d / 2.0, CRAWL_H + 0.18), (CRAWL_W + 0.35, 0.5, 0.3), "fb_timber")
        marker("door_main", (0.0, d / 2.0 + 0.8, -sink + 0.12), math.pi / 2.0,
               door_width=CRAWL_W)
    overhead_cover(bm, 0, 0, wall, w, d, rng)
    return w, d, wall + 0.6


def fam_sleeping_bunker(bm, rng):
    """SLEEPING BUNKER. Fully dug in, steps down, two tiers of bunks."""
    w, d, sink, wall = 5.2, 3.6, 1.55, 0.85
    dug_pit(bm, w, d, sink, DOOR_W, door_side=-1)
    box(bm, (0, 0, -sink + 0.06), (w - 0.5, d - 0.5, 0.12), "fb_psp")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), wall, rng)
    bag_run((-w / 2.0, d / 2.0, 0), (w / 2.0, d / 2.0, 0), wall, rng)
    for s in (-1, 1):
        bag_run((s * DOOR_W / 2.0, -d / 2.0, 0), (s * w / 2.0, -d / 2.0, 0), wall, rng)
    for i in range(5):
        box(bm, (0, -d / 2.0 - 0.5 + i * 0.42, -sink + 0.1 + i * (sink - 0.15) / 5.0),
            (DOOR_W + 0.3, 0.44, 0.16), "fb_timber")
    for sx in (-1, 1):
        for t in range(2):
            box(bm, (sx * (w / 2.0 - 0.75), 0, -sink + 0.55 + t * 0.72),
                (1.05, d - 1.0, 0.10), "fb_timber")
            for e in (-1, 1):
                box(bm, (sx * (w / 2.0 - 0.75), e * (d / 2.0 - 0.6), -sink + 0.35 + t * 0.72),
                    (1.05, 0.09, 0.5), "fb_timber")
    overhead_cover(bm, 0, 0, wall, w, d, rng)
    marker("door_main", (0.0, -(d / 2.0 + 1.5), 0.0), math.pi / 2.0, door_width=DOOR_W)
    marker("prop_bunk", (0.0, 0.0, -sink + 0.12), 0.0, prop_class="sleep")
    return w, d, wall + 0.6


def fam_tower(bm, rng):
    """Observation tower - laddered, revetted base, roofed platform."""
    w, h = 2.6, 7.4
    bag_ring(w * 0.95, 1.1, rng, seg=10)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w / 2.0, sy * w / 2.0, h / 2.0), (0.18, 0.18, h), "fb_timber")
    for k in range(3):
        z = h * (0.28 + k * 0.24)
        for s2 in range(4):
            nx, ny = SIDES[s2]
            box(bm, (nx * w / 2.0, ny * w / 2.0, z),
                (0.09, w, 0.09) if nx else (w, 0.09, 0.09), "fb_timber")
        for sx in (-1, 1):
            beam_between(bm, (sx * w / 2.0, -w / 2.0, z), (sx * w / 2.0, w / 2.0, z + 0.9),
                         0.07, "fb_timber")
    box(bm, (0, 0, h), (w + 0.55, w + 0.55, 0.14), "fb_timber")
    bag_run((-w / 2.0, -w / 2.0, h + 0.07), (w / 2.0, -w / 2.0, h + 0.07), 0.85, rng)
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -w / 2.0, h + 0.07), (sx * w / 2.0, w / 2.0, h + 0.07),
                     0.85, rng)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w / 2.0, sy * w / 2.0, h + 1.15), (0.09, 0.09, 2.1), "fb_timber")
    corrugated_roof(bm, 0, 0, h + 2.2, w + 0.9, w + 0.9)
    for i in range(int(h / 0.32)):
        box(bm, (0, w / 2.0 + 0.28, i * 0.32 + 0.2), (0.62, 0.07, 0.06), "fb_timber")
    for sx in (-1, 1):
        beam_between(bm, (sx * 0.31, w / 2.0 + 0.28, 0.0), (sx * 0.31, w / 2.0 + 0.28, h),
                     0.07, "fb_timber")
    marker("tower_los_point", (0.0, 0.0, h + 1.5), -math.pi / 2.0)
    ## Ladder pair read by scripts/world/ladder.gd. The facing angle is +Y because that is
    ## the face the rungs are on above - the marker's local +Z ends up pointing away from
    ## the tower, which is the side the climber stands on.
    marker("ladder_bottom", (0.0, w / 2.0 + 0.28, 0.0), math.pi / 2.0)
    marker("ladder_top", (0.0, w / 2.0 + 0.28, h), math.pi / 2.0)
    return w + 1.0, w + 1.0, h + 2.3


def fam_berm_arc(bm, rng):
    """One 15-degree arc of the perimeter berm - ~1.2 m of turned earth."""
    berm(bm, (-4.6, 0, 0), (4.6, 0, 0), 1.2, 2.6)
    for i in range(5):
        box(bm, (-3.7 + i * 1.85, -1.0, 0.5), (0.09, 0.09, 1.0), "fb_timber")
    return 9.2, 2.6, 1.2


def fam_trench_run(bm, rng):
    """Walkable connecting trench, 1.4 m deep, revetted cheeks, duckboards."""
    ln, wd, dp = 6.0, 1.25, 1.4
    box(bm, (0, 0, -dp / 2.0), (ln, wd, dp), "fb_earth")
    for sy in (-1, 1):
        for i in range(8):
            box(bm, (-ln / 2.0 + ln * (i + 0.5) / 8.0, sy * (wd / 2.0 + 0.09), -dp / 2.0),
                (ln / 8.0 * 0.95, 0.18, dp), "fb_timber")
        berm(bm, (-ln / 2.0, sy * (wd / 2.0 + 0.55), 0),
             (ln / 2.0, sy * (wd / 2.0 + 0.55), 0), 0.45, 0.9)
    box(bm, (0, 0, -dp + 0.05), (ln - 0.2, wd - 0.3, 0.10), "fb_timber")
    return ln, wd + 1.6, 0.45


def fam_wire_belt(bm, rng):
    """Concertina PICKETS only. The wire itself is laid by gen_firebase_layout.wire_ring.

    Never re-model the wire: barbwire_card is the only wire (war room 2026-07-17), and
    tools/diag_fsb_seat.gd:100 keys on the bwire_card name prefix - rename it and the
    seat probe fails HARD with a misleading message about wire base height.
    """
    ln = 8.64
    for i in range(4):
        x = -ln / 2.0 + ln * i / 3.0
        box(bm, (x, 0, 0.55), (0.08, 0.08, 1.1), "fb_timber")
        for sy in (-1, 1):
            beam_between(bm, (x, 0, 1.05), (x + 0.02, sy * 0.42, 1.32), 0.05, "fb_timber")
    return ln, 1.0, 1.35


def fam_gate_gap(bm, rng):
    """THE GATE - doctrinally a road gap in the wire, not a fortress door.

    Today's SOCKET_A->SOCKET_B span is 28.6 m, which is a highway. Nothing measures the
    separation (only the midpoint and the A->B perpendicular are read), so a 9 m road
    gap is free to author and reads correctly.
    """
    gap = 9.0
    for sx in (-1, 1):
        box(bm, (sx * gap / 2.0, 0, 1.55), (0.26, 0.26, 3.1), "fb_timber")
        bag_run((sx * gap / 2.0, -2.2, 0), (sx * gap / 2.0, 2.2, 0), 1.15, rng)
    beam_between(bm, (-gap / 2.0, 0, 2.85), (gap / 2.0, 0, 2.85), 0.14, "fb_timber")
    beam_between(bm, (-gap / 2.0 + 0.3, -0.5, 2.35), (gap / 2.0 - 1.4, -0.5, 2.05),
                 0.11, "fb_timber")
    box(bm, (-gap / 2.0 + 0.3, -0.5, 2.15), (0.34, 0.34, 0.34), "fb_crate")
    bag_run((gap / 2.0 - 2.6, 2.4, 0), (gap / 2.0 - 0.4, 2.4, 0), 1.15, rng)
    box(bm, (gap / 2.0 - 1.5, 3.0, 1.2), (2.4, 1.4, 0.12), "fb_corrugated")
    for sx in (-1, 1):
        bag_run((sx * 1.4, sx * 3.4, 0), (sx * 1.4 + 2.2, sx * 3.4, 0), 1.0, rng)
    marker("SOCKET_A", (-gap / 2.0, 0.0, 0.0), 0.0)
    marker("SOCKET_B", (gap / 2.0, 0.0, 0.0), 0.0)
    marker("FACE_OUT", (0.0, -4.0, 1.0), -math.pi / 2.0)
    return gap + 2.0, 8.0, 3.1


def fam_claymore(bm, rng):
    box(bm, (0, 0, 0.28), (0.34, 0.09, 0.16), "fb_crate", rot=(0.18, 0, 0))
    for sx in (-1, 1):
        beam_between(bm, (sx * 0.12, 0, 0.2), (sx * 0.16, 0.05, 0.0), 0.02, "fb_timber")
    return 0.4, 0.2, 0.36


# ----------------------------------------------------------- families: guns --
def fam_gun_pit(bm, rng):
    """105 mm pit: circular revetment ~9 m across, 1 m berm, ready racks, walk-down.

    Doctrine puts the pit at ~30 ft (9 m) with a 3 ft berm. The incumbent kit answered
    this shape with a 9,390-tri mortar_pit; the shape is what matters, not the budget.
    """
    r, h = 4.5, 1.0
    bag_ring(r, h, rng, seg=14)
    box(bm, (0, 0, -0.14), (r * 1.85, r * 1.85, 0.28), "fb_earth")
    for i in range(4):
        box(bm, (0, r + 0.3 + i * 0.42, -0.1 + i * 0.06), (1.5, 0.44, 0.14), "fb_timber")
    for k in range(6):
        a = math.tau * k / 6.0 + 0.3
        box(bm, (math.cos(a) * (r - 0.75), math.sin(a) * (r - 0.75), 0.28),
            (0.85, 0.55, 0.55), "fb_crate", rot=(0, 0, a))
    for k in range(2):
        box(bm, (math.cos(-1.2) * (r + 2.4 + k * 1.6), math.sin(-1.2) * (r + 2.4 + k * 1.6),
                 0.55), (0.07, 0.07, 1.1), "fb_timber")
    marker("GUN_POINT", (0.0, 0.0, 0.0), math.pi / 2.0, work_type="gun")
    return r * 2, r * 2, h


def fam_howitzer(bm, rng):
    """The gun in the pit - without it the star reads as six empty holes."""
    box(bm, (0, -0.2, 0.62), (0.34, 3.5, 0.30), "fb_gunmetal")
    box(bm, (0, 1.05, 0.62), (0.46, 1.0, 0.46), "fb_gunmetal")
    box(bm, (0, 0.75, 0.34), (1.5, 1.2, 0.5), "fb_olive")
    for sx in (-1, 1):
        beam_between(bm, (sx * 0.35, 0.9, 0.3), (sx * 1.15, 3.1, 0.12), 0.16, "fb_olive")
        for k in range(8):
            box(bm, (sx * 0.95, 0.55, 0.55), (0.12, 1.05, 0.12), "fb_gunmetal",
                rot=(math.pi * k / 8.0, 0, 0))
        box(bm, (sx * 0.95, 0.55, 0.55), (0.22, 0.34, 0.34), "fb_gunmetal")
    box(bm, (0, 1.5, 0.95), (1.3, 0.10, 0.62), "fb_olive")
    return 2.4, 4.0, 1.3


def fam_mortar_pit(bm, rng):
    """Circular mortar pit: parapet <=0.5 m, >=0.9 m wide, with a 1 m sighting gap."""
    r, h, seg = 2.1, 0.48, 14
    for i in range(seg):
        if i < 2:                                   # the sighting gap
            continue
        a0, a1 = math.tau * i / seg, math.tau * (i + 1) / seg
        bag_run((math.cos(a0) * r, math.sin(a0) * r, 0),
                     (math.cos(a1) * r, math.sin(a1) * r, 0), h, rng)
    box(bm, (0, 0, -0.12), (r * 1.7, r * 1.7, 0.24), "fb_earth")
    box(bm, (0, 0, 0.16), (0.7, 0.7, 0.32), "fb_gunmetal")
    beam_between(bm, (0, 0, 0.2), (0, -0.55, 1.35), 0.11, "fb_gunmetal")
    for k in range(3):
        a = 1.1 + k * 1.9
        box(bm, (math.cos(a) * (r - 0.55), math.sin(a) * (r - 0.55), 0.22),
            (0.5, 0.5, 0.44), "fb_crate", rot=(0, 0, a))
    marker("work_mortar", (0.0, r + 0.8, 0.0), -math.pi / 2.0, work_type="gun")
    return r * 2, r * 2, 1.4


# --------------------------------------------------------- families: living --
def fam_gp_tent(bm, rng):
    """OPEN TENT. GP medium with the side walls ROLLED AND TIED - you see straight in.

    A closed canvas box is the thing being replaced. The roll bundle along the eave and
    the daylight gap beneath it are the entire read.
    """
    w, d, eave, ridge, roll = 5.0, 9.5, 1.85, 3.05, 0.30
    box(bm, (0, 0, 0.05), (w + 0.6, d + 0.6, 0.10), "fb_earth")
    for e in (-1, 1):
        box(bm, (0, e * d / 2.0, ridge / 2.0), (0.11, 0.11, ridge), "fb_timber")
    box(bm, (0, 0, ridge), (0.10, d + 0.3, 0.10), "fb_timber")
    n = 12
    pitch = math.atan2(ridge - eave, w / 2.0)
    for i in range(n):
        y = -d / 2.0 + d * (i + 0.5) / n
        for sx in (-1, 1):
            box(bm, (sx * w / 4.0, y, (ridge + eave) / 2.0), (w / 2.0, d / n * 1.06, 0.05),
                "fb_canvas", rot=(0, pitch * sx, 0))
    for sx in (-1, 1):
        box(bm, (sx * w / 2.0, 0, eave), (0.09, d, 0.09), "fb_timber")
        box(bm, (sx * (w / 2.0 - 0.04), 0, eave - roll / 2.0), (roll, d - 0.2, roll),
            "fb_canvas")
        for i in range(5):
            box(bm, (sx * (w / 2.0 - 0.04), -d / 2.0 + d * (i + 0.5) / 5.0, eave - roll),
                (0.04, 0.04, roll * 1.4), "fb_canvas")
        for i in range(4):
            y = -d / 2.0 + d * (i + 0.5) / 4.0
            beam_between(bm, (sx * w / 2.0, y, eave), (sx * (w / 2.0 + 1.15), y, 0.0),
                         0.03, "fb_canvas")
    for sx in (-1, 1):
        for i in range(4):
            y = -d / 2.0 + 0.9 + i * (d - 1.8) / 3.0
            box(bm, (sx * (w / 2.0 - 0.85), y, 0.42), (0.72, 1.85, 0.09), "fb_canvas")
            for e in (-1, 1):
                box(bm, (sx * (w / 2.0 - 0.85), y + e * 0.85, 0.21), (0.72, 0.07, 0.42),
                    "fb_timber")
    marker("door_main", (0.0, -(d / 2.0 + 1.0), 0.0), math.pi / 2.0, door_width=w * 0.6)
    marker("prop_cot", (0.0, 0.0, 0.0), 0.0, prop_class="sleep")
    return w, d, ridge


def fam_hootch(bm, rng):
    """Sandbag-revetted hootch: waist wall, timber frame, tin roof, OPEN ends."""
    w, d, revet, post_h = 4.4, 7.2, 1.25, 2.35
    box(bm, (0, 0, 0.05), (w + 0.5, d + 0.5, 0.10), "fb_earth")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), revet, rng)
        for i in range(4):
            box(bm, (sx * w / 2.0, -d / 2.0 + d * (i + 0.5) / 4.0, post_h / 2.0),
                (0.13, 0.13, post_h), "fb_timber")
        box(bm, (sx * w / 2.0, 0, post_h), (0.11, d, 0.11), "fb_timber")
    corrugated_roof(bm, 0, 0, post_h + 0.16, w + 0.7, d + 0.4)
    for i in range(5):
        box(bm, (0, -d / 2.0 + d * (i + 0.5) / 5.0, post_h + 0.06), (w + 0.6, 0.11, 0.11),
            "fb_timber")
    # Bunks are the fb_cot prop, placed by gen_fb_interior's authored layout. The six
    # legless 0.78x1.85x0.09 planks that used to float here at z=0.52 were the whole
    # "seats with no legs" read, and keeping both would be two systems for one bunk.
    marker("door_main", (0.0, -(d / 2.0 + 1.0), 0.0), math.pi / 2.0, door_width=w * 0.7)
    marker("prop_sleep", (0.0, 0.0, 0.0), 0.0, prop_class="sleep")
    return w, d, post_h + 0.4


def fam_toc(bm, rng):
    """TOC/FDC - the nerve centre, central and dug in. Ramp, map board, antenna farm."""
    w, d, sink, wall = 7.4, 5.6, 1.15, 1.05
    dug_pit(bm, w, d, sink, DOOR_W, door_side=-1)
    box(bm, (0, 0, -sink + 0.06), (w - 0.5, d - 0.5, 0.12), "fb_psp")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), wall, rng)
    bag_run((-w / 2.0, d / 2.0, 0), (w / 2.0, d / 2.0, 0), wall, rng)
    for s in (-1, 1):
        bag_run((s * (DOOR_W / 2.0 + 0.1), -d / 2.0, 0), (s * w / 2.0, -d / 2.0, 0),
                     wall, rng)
    for i in range(5):
        box(bm, (0, -d / 2.0 - 0.5 + i * 0.4, -sink + 0.1 + i * (sink - 0.15) / 5.0),
            (DOOR_W + 0.4, 0.42, 0.14), "fb_timber")
    overhead_cover(bm, 0, 0, wall, w, d, rng)
    box(bm, (0, d / 2.0 - 0.5, -sink + 0.9), (w - 1.4, 0.12, 1.2), "fb_timber")
    box(bm, (-w / 4.0, 0, -sink + 0.45), (1.9, 0.9, 0.75), "fb_timber")
    box(bm, (w / 4.0, 0, -sink + 0.4), (1.1, 0.7, 0.65), "fb_crate")
    for i in range(3):
        box(bm, (-1.6 + i * 1.6, d / 2.0 - 0.4, wall + 2.3), (0.06, 0.06, 3.4), "fb_timber")
    marker("door_main", (0.0, -(d / 2.0 + 1.8), 0.0), math.pi / 2.0, door_width=DOOR_W)
    marker("work_radio", (w / 4.0, 0.0, -sink + 0.12), math.pi, work_type="radio")
    marker("prop_map", (0.0, d / 2.0 - 0.9, -sink + 0.12), math.pi / 2.0,
           prop_class="furniture")
    return w, d, wall + 4.0


def fam_mess(bm, rng):
    """Mess tent + field kitchen - the chow line, an ADR-020 ambience anchor."""
    w, d, eave, ridge = 5.0, 8.0, 2.0, 3.0
    pitch = math.atan2(ridge - eave, w / 2.0)
    for e in (-1, 1):
        box(bm, (0, e * d / 2.0, ridge / 2.0), (0.11, 0.11, ridge), "fb_timber")
    box(bm, (0, 0, ridge), (0.10, d + 0.3, 0.10), "fb_timber")
    for i in range(10):
        y = -d / 2.0 + d * (i + 0.5) / 10.0
        for sx in (-1, 1):
            box(bm, (sx * w / 4.0, y, (ridge + eave) / 2.0), (w / 2.0, d / 10.0 * 1.06, 0.05),
                "fb_canvas", rot=(0, pitch * sx, 0))
    for sx in (-1, 1):
        box(bm, (sx * w / 2.0, 0, eave), (0.09, d, 0.09), "fb_timber")
        for i in range(4):
            box(bm, (sx * w / 2.0, -d / 2.0 + d * (i + 0.5) / 4.0, eave / 2.0),
                (0.09, 0.09, eave), "fb_timber")
    # Chow tables at EATING height with four legs, benches either side. The old slab was
    # 0.45 high (that is bench height), made of fb_psp, and spanned 2.8 m between two end
    # blocks - so it read as a perforated plank floating in mid-air, with nothing to sit on.
    for i in range(2):
        y = -d / 2.0 + 2.4 + i * 2.7
        box(bm, (0, y, 0.73), (w - 1.4, 0.80, 0.06), "fb_timber")
        for ex in (-1, 1):
            for ey in (-1, 1):
                box(bm, (ex * (w / 2.0 - 0.98), y + ey * 0.31, 0.365),
                    (0.08, 0.08, 0.73), "fb_timber")
        for ey in (-1, 1):
            box(bm, (0, y + ey * 0.76, 0.45), (w - 1.7, 0.28, 0.05), "fb_timber")
            for ex in (-1, 1):
                box(bm, (ex * (w / 2.0 - 1.08), y + ey * 0.76, 0.225),
                    (0.07, 0.07, 0.45), "fb_timber")
    # Serving counter at the kitchen end, timber not fb_psp: perforated planking reads as
    # slotted metal on anything that is not planking (see MATS above).
    box(bm, (0, d / 2.0 - 1.2, 0.90), (2.8, 0.70, 0.06), "fb_timber")
    box(bm, (0, d / 2.0 - 1.2, 0.44), (2.6, 0.60, 0.05), "fb_timber")
    for ex in (-1, 1):
        for ey in (-1, 1):
            box(bm, (ex * 1.3, d / 2.0 - 1.2 + ey * 0.29, 0.45), (0.09, 0.09, 0.90),
                "fb_timber")
    marker("APPROACH", (0.0, -(d / 2.0 + 1.2), 0.0), math.pi / 2.0)
    marker("work_mess", (0.0, d / 2.0 - 2.0, 0.0), math.pi / 2.0, work_type="cook")
    return w, d, ridge


def fam_aid_station(bm, rng):
    """Dug-in aid station - revetted, cots, enterable."""
    w, d, sink, wall = 5.6, 4.2, 1.0, 1.0
    dug_pit(bm, w, d, sink, DOOR_W, door_side=-1)
    box(bm, (0, 0, -sink + 0.06), (w - 0.5, d - 0.5, 0.12), "fb_psp")
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), wall, rng)
    bag_run((-w / 2.0, d / 2.0, 0), (w / 2.0, d / 2.0, 0), wall, rng)
    for s in (-1, 1):
        bag_run((s * (DOOR_W / 2.0 + 0.1), -d / 2.0, 0), (s * w / 2.0, -d / 2.0, 0),
                     wall, rng)
    for i in range(4):
        box(bm, (0, -d / 2.0 - 0.45 + i * 0.4, -sink + 0.1 + i * (sink - 0.15) / 4.0),
            (DOOR_W + 0.35, 0.42, 0.14), "fb_timber")
    overhead_cover(bm, 0, 0, wall, w, d, rng)
    for sx in (-1, 1):
        box(bm, (sx * (w / 2.0 - 0.9), 0, -sink + 0.55), (0.85, 2.0, 0.10), "fb_canvas")
    marker("door_main", (0.0, -(d / 2.0 + 1.5), 0.0), math.pi / 2.0, door_width=DOOR_W)
    marker("work_aid", (0.0, 0.0, -sink + 0.12), math.pi / 2.0, work_type="medic")
    return w, d, wall + 0.6


# -------------------------------------------------------- families: support --
def fam_helipad(bm, rng):
    """15 x 15 PSP deck at true ground level - air_traffic reads pad Y verbatim."""
    s, n = 15.0, 10
    for i in range(n):
        box(bm, (0, -s / 2.0 + s * (i + 0.5) / n, 0.04), (s, s / n * 0.97, 0.08), "fb_psp")
    for sx in (-1, 1):
        box(bm, (sx * s / 2.0, 0, 0.07), (0.22, s, 0.14), "fb_timber")
        for sy in (-1, 1):
            box(bm, (sx * (s / 2.0 - 1.2), sy * (s / 2.0 - 1.2), 0.10), (0.3, 0.3, 0.2),
                "fb_psp")
    marker("PSPHelipad", (0.0, 0.0, 0.0), 0.0)
    return s, s, 0.14


def fam_supply_dump(bm, rng):
    """Ammo/supply point: revetted three sides, dunnage, crate stacks, drums."""
    w, d = 7.0, 5.0
    bag_run((-w / 2.0, d / 2.0, 0), (w / 2.0, d / 2.0, 0), 1.35, rng)
    for sx in (-1, 1):
        bag_run((sx * w / 2.0, -d / 2.0, 0), (sx * w / 2.0, d / 2.0, 0), 1.35, rng)
    for i in range(3):
        box(bm, (0, -d / 2.0 + 0.9 + i * 1.5, 0.09), (w - 0.8, 0.16, 0.18), "fb_timber")
    for i in range(9):
        x = -w / 2.0 + 0.9 + (i % 3) * 2.1
        y = -d / 2.0 + 1.0 + (i // 3) * 1.5
        for k in range(rng.randint(2, 3)):
            box(bm, (x + rng.uniform(-.06, .06), y, 0.44 + k * 0.52), (1.5, 0.85, 0.5),
                "fb_crate", rot=(0, 0, rng.uniform(-0.06, 0.06)))
    for i in range(4):
        box(bm, (w / 2.0 - 0.8, -d / 2.0 + 0.8 + i * 0.72, 0.42), (0.6, 0.6, 0.84), "fb_psp")
    marker("USSupplyDepot", (0.0, -(d / 2.0 + 1.1), 0.0), math.pi / 2.0, work_type="carry")
    return w, d, 1.5


def fam_latrine(bm, rng):
    w, d, h = 1.9, 1.3, 2.1
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w / 2.0, sy * d / 2.0, h / 2.0), (0.09, 0.09, h), "fb_timber")
    for s2 in (1, 2, 3):
        nx, ny = SIDES[s2]
        box(bm, (nx * w / 2.0, ny * d / 2.0, h * 0.45),
            (0.06, d, h * 0.9) if nx else (w, 0.06, h * 0.9), "fb_corrugated")
    corrugated_roof(bm, 0, 0, h + 0.06, w + 0.25, d + 0.25, n=3)
    box(bm, (0, d / 2.0 - 0.35, 0.45), (w - 0.25, 0.5, 0.1), "fb_timber")
    return w, d, h


def fam_sandbag_stack(bm, rng):
    """Working stock of filled bags - a base still being built."""
    for c in range(4):
        for i in range(4 - c):
            for j in range(2):
                box(bm, (-0.9 + i * 0.62 + c * 0.15, -0.25 + j * 0.5, 0.11 + c * 0.22),
                    (0.60, 0.42, 0.22), "fb_sandbag", rot=(0, 0, rng.uniform(-0.09, 0.09)))
    return 2.6, 1.2, 0.9


def fam_water_point(bm, rng):
    for i in range(3):
        box(bm, (-0.9 + i * 0.9, 0, 0.55), (0.72, 0.72, 1.1), "fb_psp")
    box(bm, (0, 0, 1.18), (2.7, 0.9, 0.1), "fb_timber")
    marker("work_water", (0.0, -1.1, 0.0), math.pi / 2.0, work_type="water")
    return 2.7, 1.0, 1.25


def fam_burn_barrel(bm, rng):
    box(bm, (0, 0, 0.44), (0.62, 0.62, 0.88), "fb_psp")
    for k in range(3):
        box(bm, (rng.uniform(-.2, .2), rng.uniform(-.2, .2), 0.92 + k * 0.06),
            (0.5 - k * 0.1, 0.5 - k * 0.1, 0.1), "fb_earth", rot=(0, 0, rng.uniform(0, 3)))
    return 0.7, 0.7, 1.0


FAMILIES = {
    "fb_bunker_mg": fam_bunker_mg, "fb_bunker_fighting": fam_bunker_fighting,
    "fb_sleeping_bunker": fam_sleeping_bunker, "fb_tower": fam_tower,
    "fb_berm_arc": fam_berm_arc, "fb_trench_run": fam_trench_run,
    "fb_wire_belt": fam_wire_belt, "fb_gate_gap": fam_gate_gap,
    "fb_claymore": fam_claymore, "fb_gun_pit": fam_gun_pit,
    "fb_howitzer": fam_howitzer, "fb_mortar_pit": fam_mortar_pit,
    "fb_gp_tent": fam_gp_tent, "fb_hootch": fam_hootch, "fb_toc": fam_toc,
    "fb_mess": fam_mess, "fb_aid_station": fam_aid_station,
    "fb_helipad": fam_helipad, "fb_supply_dump": fam_supply_dump,
    "fb_latrine": fam_latrine, "fb_sandbag_stack": fam_sandbag_stack,
    "fb_water_point": fam_water_point, "fb_burn_barrel": fam_burn_barrel,
}

## Pieces that get a -col trimesh twin. The incumbent put -col on all 652 of its meshes,
## which is 652 concave shapes of physics nobody collects.
SOLID = {"fb_bunker_mg", "fb_bunker_fighting", "fb_sleeping_bunker", "fb_hootch", "fb_toc",
         "fb_gun_pit", "fb_howitzer", "fb_mortar_pit", "fb_tower", "fb_berm_arc",
         "fb_trench_run", "fb_gate_gap", "fb_helipad", "fb_supply_dump", "fb_mess",
         "fb_aid_station", "fb_latrine", "fb_sandbag_stack", "fb_water_point"}

## Verified with the player capsule (r=0.4, h=1.8), never asserted.
ENTERABLE = {"fb_bunker_mg", "fb_bunker_fighting", "fb_sleeping_bunker", "fb_gp_tent",
             "fb_hootch", "fb_toc", "fb_mess", "fb_aid_station"}


def build_piece(name, seed, **kw):
    """Build one family into a fresh object. Returns (object, markers, dims)."""
    global BAG_RUNS
    reset_markers()
    BAG_RUNS = []
    rng = random.Random(seed)
    bm = bmesh.new()
    dims = FAMILIES[name](bm, rng, **kw)
    # Revetments weld straight into the same bmesh, so the piece stays ONE mesh without a
    # join pass - the -col contract is per-mesh.
    for path, h, z, side, s in BAG_RUNS:
        fb_kit.build_sandbag_wall(path=path, height=h, base_z=z, side=side, seed=s,
                                  into=bm, top_course=BAG_TOP_COURSE)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ensure_materials():
        me.materials.append(m)
    box_project_uvs(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob, list(MARKERS), dims


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def main():
    """Review build: every family once, in a labelled grid, plus the manifest."""
    bpy.ops.wm.read_homefile(use_empty=True)
    os.makedirs(KIT_DIR, exist_ok=True)
    manifest, x, row, tallest = {}, 0.0, 0.0, 0.0
    print(f"{'family':22s}{'tris':>7}{'mk':>4}  size (m)")
    for i, name in enumerate(sorted(FAMILIES)):
        ob, marks, dims = build_piece(name, 9100 + i * 53)
        ob.location = (x + dims[0] / 2.0, row, 0.0)
        x += dims[0] + 3.0
        tallest = max(tallest, dims[1])
        if x > 60.0:
            x, row, tallest = 0.0, row - tallest - 5.0, 0.0
        t = tri_count(ob)
        manifest[name] = {"tris": t, "size": [round(v, 2) for v in dims],
                          "solid": name in SOLID, "enterable": name in ENTERABLE,
                          "markers": [{"name": m["name"],
                                       "pos": [round(v, 3) for v in m["pos"]],
                                       "face": round(m["face"], 4), **m["props"]}
                                      for m in marks]}
        print(f"{name:22s}{t:>7}{len(marks):>4}  {[round(v, 1) for v in dims]}")
    json.dump(manifest, open(os.path.join(KIT_DIR, "firebase_set.json"), "w"), indent=1)
    print(f"\n{len(manifest)} families, {sum(m['tris'] for m in manifest.values())} tris")
    blend = os.path.join(KIT_DIR, "firebase_kit_review.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    print("review blend:", blend, round(os.path.getsize(blend) / 1048576.0, 2), "MB")


if __name__ == "__main__":
    main()
