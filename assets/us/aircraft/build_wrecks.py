"""Build the three RECONgame crashed-aircraft wrecks, headless.

  blender -b --factory-startup -P build_wrecks.py -- a1|huey|f4|all
                                                     [--norender] [--dry] [--tag=_v2]

`--dry` writes the .blend/.glb into the render directory instead of over the shipped
asset, so a change can be judged from its renders before anything ships. `--tag`
suffixes the render filenames so a new pass sits beside the one it is being judged against.

Each wreck is DERIVED from its shipped donor GLB plus the shipped bomb_crater mesh.
Nothing is invented from parameters. See production/blender_notes.md (2026-08-13) for
the ten reference observations that decided each edit.

NAMING IS THE API (skill: recon-destructible-export). A mesh or collider that misses its
prefix ships invulnerable and bulletproof, silently:
    wreck_hard_*   stops rounds   - engine, fuselage structure, the earth mound
    wreck_soft_*   shoot-through  - skin panels, wings, tail, doors, blades, debris
Ballistics reads the COLLIDER name, destruction reads the MESH name, so both carry it.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wrecklib as W
from wrecklib import (wipe, meshes, by_name, drop, import_glb, keep_only, verts, bbox,
                      tris, vcount, edit_verts, split_faces, tear_seam, crush, buckle,
                      rigid, bend_blades, dent, crumple, flat_mat, scorch, build_mound,
                      mound_height_at, max_slope_deg, socket, make_colonly, zero_to_ground,
                      export_glb, save_blend, render_views, verify_roundtrip, AIR,
                      weld, components, part_split, join_objs)

OUT = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0201f774-4017-48d5-924a-0296e7efee35\scratchpad\wrecks"
HUEY_GLB = os.path.join(W.ART, "us", "vehicles", "huey_v3.glb")

# `--dry` writes the .blend/.glb to OUT instead of over the shipped asset, so the
# renders can be judged before anything ships. TAG suffixes the render filenames.
SHIP_DIR = AIR
TAG = ""

# How deep the keel sits below the FLOOR OF ITS OWN SLOT - the trench build_mound digs
# along the centreline, not the berm crest beside it. Those differ by 0.6 m here, and
# burying 0.55 below the slot floor (i.e. ~1.1 below the berm) put the cowl top 0.12 m
# above the dirt: the aeroplane had gone into the ground. Earth comes up the SIDES, and
# the berm has to stay under the wreck's own crushed height or the dirt is the subject.
HULL_BURY = 0.04

# ------------------------------------------------------------------- the paint
# ONE muted base per airframe. The values are chosen AGAINST THE EARTH MOUND the wreck
# lies in: the old SEA tan measured 0.393 linear, within a few percent of the mound's
# own value, so the fuselage dissolved into the dirt in patches while the dark green
# blobs read as unrelated objects. Linear here; the hex is what a paint chip would read.
OLIVE = (0.062, 0.062, 0.032, 1.0)             # #464632  scorched olive - A-1 and Huey
OLIVE_LIT = (0.084, 0.084, 0.045, 1.0)         # #52523C  control surfaces, sun-bleached
# The Phantom's blue channel is what decides whether it reads as grey-green or as naval
# slate: the render sky is 0.42/0.46/0.52, so a near-neutral paint takes the sky's cast
# into every shadowed facet. Holding blue at ~0.6 of green keeps it green in the shade.
GREYGREEN = (0.048, 0.056, 0.034, 1.0)         # #3E4334  darker grey-green - F-4
GREYGREEN_LIT = (0.065, 0.076, 0.046, 1.0)     # #484E3D
TRIM_BLACK = (0.018, 0.018, 0.018, 1.0)        # #242424  anti-glare, prop, rotor
INSIGNIA = (0.075, 0.075, 0.073, 1.0)          # #4D4D4C  one faded star, nothing brighter


def repaint(base_name, base, lit_name, lit, camo_subs, lit_parts):
    """One solid base across the whole airframe - thrown pieces included, so the scatter
    reads as ONE aeroplane - plus a single lighter value on the control surfaces so the
    mass is not dead flat. Materials only: no vertex moves, no renames, no reordering."""
    shown = [o for o in meshes() if not o.name.endswith("-colonly")
             and "mound" not in o.name]
    W.unify_paint(shown, camo_subs, base_name, base)
    W.unify_paint([o for o in shown if any(k in o.name for k in lit_parts)],
                  (base_name,), lit_name, lit)
    W.set_base(("black", "prop_blade", "huey_rotor"), TRIM_BLACK)
    W.set_base(("marking",), INSIGNIA)


# --------------------------------------------------------------- shared helpers
def rename(obj, new):
    obj.name = new
    obj.data.name = new
    return obj


def sink(objs, target_min_z):
    """Drop a group so its lowest point lands at `target_min_z`. Negative = plowed in."""
    lo, _ = bbox(objs)
    d = target_min_z - lo.z
    for o in objs:
        edit_verts(o, lambda p, d=d: p + Vector((0, 0, d)))
    return d


def sink_ref(objs, ref, target_min_z):
    """Sink a whole attached assembly by the amount that puts the REFERENCE piece's
    lowest point at `target_min_z`.

    `sink()` uses the GROUP minimum, which seats the aeroplane on whatever hangs lowest -
    a wing pylon, a bomb, a drop tank - and leaves the fuselage standing 0.58 m proud of
    the scar it is supposed to be ploughed into. The keel is the datum; the stores under
    the wings go into the dirt with it, which is what ploughing in means.
    """
    d = target_min_z - bbox([ref])[0].z
    for o in objs:
        edit_verts(o, lambda p, d=d: p + Vector((0, 0, d)))
    return d


def rigid_group(objs, translate=(0, 0, 0), rot_deg=(0, 0, 0)):
    """Move several objects as ONE rigid body about their SHARED centroid. Moving them
    one at a time about their own centroids shears the assembly apart - the tail boom
    and its fin/rotor must travel together."""
    lo, hi = bbox(objs)
    piv = (lo + hi) / 2.0
    for o in objs:
        rigid(o, translate=translate, rot_deg=rot_deg, pivot=piv)


def pick_pilot_anchor(body_objs, fire_pts, mound, r_lo=4.0, r_hi=6.5):
    """Sweep for the downed-pilot stage: 4-6 m off the FUSELAGE SURFACE, on the side
    away from every fire socket, on ground that is measurably flat.

    Caleb's ruling is that danger lives INSIDE the flames only - this is a rescue site,
    and a pilot staged in or beside a burn seat sends the rescue AI into fire. So the
    distances are measured against real geometry: nearest fuselage VERTEX in plan, not
    a bounding box (the first pass used the bbox half-extent and put the anchor 17 m
    downrange on an 11 m fuselage), and the mound's own surface for flatness.
    """
    pts = []
    for o in body_objs:
        pts.extend([(p.x, p.y) for p in verts(o)])
    lo, hi = bbox(body_objs)
    cx, cy = (lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0
    fp = [Vector(f) for f in fire_pts]

    def dist_to_body(px, py):
        return min(math.hypot(px - ax, py - ay) for ax, ay in pts)

    best, best_s = None, -1e9
    for bi in range(96):
        a = math.radians(bi * 3.75)
        for step in range(1, 60):
            r = step * 0.4
            px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
            db = dist_to_body(px, py)
            if db < r_lo or db > r_hi:
                continue
            gz = mound_height_at(mound, px, py)
            dmin = min(math.hypot(px - f.x, py - f.y) for f in fp)
            # 8 m, not 6: verify_roundtrip() asserts >= 8 m on the SHIPPED file, so a
            # sweep that accepted 6 could hand the exporter a placement its own gate
            # would then reject. Two thresholds for one rule is a defect waiting for
            # the day the scoring term stops carrying it.
            if dmin < 8.0 or abs(gz) > 0.45:
                continue
            s = dmin - abs(gz) * 6.0
            if s > best_s:
                best_s, best = s, (px, py, max(0.0, gz), dmin, db)
    if best is None:
        raise SystemExit("FATAL: no pilot_anchor satisfies 4-6.5 m off the hull, "
                         ">=8 m from fire, on flat ground")
    return best


def finish(tag, glb_name, trimesh_prefixes, sockets, anchor, mound, render=True,
           debris_gate="strict", excuse=()):
    """Common tail: collision twins, origin, export, round-trip proof, renders."""
    print("\n-- %s: sealing" % tag)
    shown = [o for o in meshes() if not o.name.endswith("-colonly")]
    print("   visual parts %d, tris %d, verts %d" % (len(shown), tris(shown), vcount(shown)))
    hard = [o.name for o in shown if o.name.startswith("wreck_hard")]
    soft = [o.name for o in shown if o.name.startswith("wreck_soft")]
    stray = [o.name for o in shown if not o.name.startswith("wreck_")]
    if stray:
        raise SystemExit("FATAL: unprefixed mesh(es) would ship bulletproof: %s" % stray)
    print("   HARD %d: %s" % (len(hard), hard))
    print("   SOFT %d: %s" % (len(soft), soft))

    # ORIENTATION, before anything else is believed. Clearance cannot see which way up a
    # panel is, and the hand list that was supposed to cover that named three pieces out
    # of twenty-nine. This enumeration comes off the scene, so nothing can miss it.
    W.assert_debris_grounded(mound, view_az=W.VIEW_AZ, excuse=excuse,
                             strict=(debris_gate == "strict"))
    rr = W.rim_report(mound)
    print("   mound rim: r %.2f..%.2f  |  r/ellipse spread %.2f over %d bulges"
          % (rr["rmin"], rr["rmax"], rr["spread"], rr["bulges"]))
    print("   rim k by bearing: %s" % " ".join("%.2f" % v for v in rr["k"]))

    wreck_pts = [p for o in shown if "mound" not in o.name for p in verts(o)]
    for nm, loc in sockets:
        d = min((Vector(loc) - p).length for p in wreck_pts)
        if d > 2.5:
            raise SystemExit("FATAL: %s is %.2f m from any wreck geometry. Caleb's "
                             "ruling: danger lives INSIDE the flames, so fire sockets "
                             "sit ON the wreck - a socket out on the approach ground "
                             "makes the rescue AI walk into fire." % (nm, d))
        print("   %s at %s : %.2f m to nearest wreck surface" %
              (nm, [round(x, 2) for x in loc], d))
        socket(nm, loc)
    socket("pilot_anchor", (anchor[0], anchor[1], anchor[2]))

    make_colonly(trimesh_names=trimesh_prefixes)
    zero_to_ground()

    lo, hi = bbox([o for o in meshes() if not o.name.endswith("-colonly")])
    print("   AABB lo %s hi %s" % ([round(x, 3) for x in lo], [round(x, 3) for x in hi]))
    print("   dims X %.2f  Y %.2f  Z %.2f  (above ground: %.2f)" %
          (hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, hi.z))
    air = []
    for o in shown:
        if "mound" in o.name:
            continue
        c = min(p.z - mound_height_at(mound, p.x, p.y) for p in verts(o))
        if c > 0.15:
            air.append((o.name, round(c, 2)))
    print("   AIRBORNE (clearance>0.15m, ok only if bolted to the hull): %s"
          % sorted(air, key=lambda a: -a[1]))
    sr = W.slope_report(mound)
    print("   mound slope: median %.1f  p95 %.1f  max %.1f deg  |  %d/%d faces over 45"
          % (sr["median"], sr["p95"], sr["max"], sr["over_limit"], sr["faces"]))
    hull = [o for o in meshes() if o.name.startswith("wreck_hard")
            and "mound" not in o.name]
    if hull:
        hl, hh = bbox(hull)
        rows = []
        hx = (hl.x + hh.x) / 2.0
        for t in (0.15, 0.35, 0.55, 0.75):
            yy = hl.y + (hh.y - hl.y) * t
            band = [p.z for o in hull for p in verts(o) if abs(p.y - yy) < 0.9]
            if not band:
                continue
            # the HULL's own centreline. World x=0 is the FOOTPRINT centre after
            # zero_to_ground(), which a thrown wing drags metres off the fuselage and
            # out onto the flank berm - the old figures were sampling the wrong ground.
            gz = mound_height_at(mound, hx, yy)
            rows.append((round(yy, 1), round(gz, 2), round(max(band), 2),
                         round(max(band) - gz, 2)))
        print("   burial (y, earth_z, hull_top_z, proud_m): %s" % rows)
    tall = sorted(((bbox([o])[1].z, o.name) for o in meshes()
                   if not o.name.endswith("-colonly")), reverse=True)[:4]
    print("   tallest parts: %s" % [(n, round(z, 2)) for z, n in tall])

    blend = os.path.join(SHIP_DIR, glb_name.replace(".glb", ".blend"))
    save_blend(blend)
    glb = os.path.join(SHIP_DIR, glb_name)
    mb = export_glb(glb)
    print("   exported %s -> %s  %.2f MB" % (glb_name, SHIP_DIR, mb))
    if render:
        render_views(OUT, tag + TAG)
    # LAST, because it wipes the scene: prove the shipped file, not the build scene.
    verify_roundtrip(glb, [s[0] for s in sockets] + ["pilot_anchor"])


# =============================================================== A-1 SKYRAIDER
# DONOR: `a1_skyraider_v2.glb` (2026-08-14), which replaced the 11,870-tri third-party
# `a1_skyraider.glb`. The v2 airframe is FOUR meshes, not a per-part tree, so the wreck's
# pieces are found by welding the donor and taking whole connected components - the wing,
# the fin, each stabiliser, each bomb are separate lofted shells of one mesh. Nothing here
# depends on a donor part NAME any more, only on the aeroplane's own topology.
def build_a1(render=True):
    print("=" * 72)
    print("A-1 SKYRAIDER WRECK  (donor a1_skyraider_v2.glb)")
    wipe()
    import_glb(os.path.join(AIR, "a1_skyraider_v2.glb"))
    keep_only(["A1_Airframe", "A1_Stores", "A1_Markings", "A1_Prop"])
    air, stores = by_name("A1_Airframe"), by_name("A1_Stores")
    marks, prop = by_name("A1_Markings"), by_name("A1_Prop")
    for o in (air, stores, marks, prop):
        n0, n1 = weld(o)
        print("  weld %-14s %4d -> %4d verts, %d parts"
              % (o.name, n0, n1, len(components(o))))

    # nose must be +Y before anything else is believed
    pv = verts(prop)
    assert sum(p.y for p in pv) / len(pv) > 3.0, "prop is not at +Y: donor facing changed"
    lo, hi = bbox([air])
    print("  donor airframe %s .. %s  prop mean y %.3f" %
          ([round(x, 2) for x in lo], [round(x, 2) for x in hi],
           sum(p.y for p in pv) / len(pv)))
    # the keel line, MEASURED off the fuselage barrel (the largest component) rather than
    # typed. The old build hardcoded -0.805 for a donor that no longer exists, and the
    # v2 chin duct and centreline tank both hang below the keel - crushing about the
    # object bbox floor would leave the fuselage untouched and squash only the tank.
    keel = max(components(air).values(), key=lambda d: d["n"])["lo"].z
    print("  keel (fuselage barrel lowest z) %.3f" % keel)

    # ---- 1. the decals ride the wing they are painted on
    join_objs(air, [marks])

    # ---- 2. take the aeroplane apart by its own parts
    canopy = W.split_material(air, "canopy", "wreck_soft_canopy")

    def wing(sgn):
        return lambda lo, hi, c, n: c.x * sgn > 0.25 and -2.8 < c.y < 1.6

    wing_a = part_split(air, wing(1.0), "wreck_soft_wing_r")
    wing_t = part_split(air, wing(-1.0), "wreck_soft_wing_thrown")
    fin = part_split(air, lambda lo, hi, c, n: c.y < -3.0 and abs(c.x) < 0.3
                     and hi.z > 1.5, "wreck_soft_tailfin")
    stab_r = part_split(air, lambda lo, hi, c, n: c.y < -3.0 and c.x > 0.3,
                        "wreck_soft_stab_r")
    stab_l = part_split(air, lambda lo, hi, c, n: c.y < -3.0 and c.x < -0.3,
                        "wreck_soft_stab_l")

    # stores: one bomb tears clear, the rest go with the wing they hang under. A pylon
    # left behind on a wing that has been thrown 10 m is a rack floating in mid-air.
    bomb = part_split(stores, lambda lo, hi, c, n: c.x < -2.0 and n >= 40,
                      "wreck_soft_ord_mk82")
    # the centreline tank and its pylon come off too. Left bolted on they hang 0.7 m
    # below the keel, and any "sit the wreck in the ground" pass then seats the whole
    # aeroplane ON THE TANK instead of on its belly.
    tank = part_split(stores, lambda lo, hi, c, n: abs(c.x) < 0.5, "wreck_soft_tank_thrown")
    st_r = part_split(stores, lambda lo, hi, c, n: c.x > 0.2, "a1_stores_r")
    st_l = part_split(stores, lambda lo, hi, c, n: c.x < -0.2, "a1_stores_l")
    join_objs(air, [stores])            # centreline tank + its pylon stay on the hull
    join_objs(wing_a, [st_r])
    join_objs(wing_t, [st_l])
    print("  parts: wing_r %d, wing_thrown %d, fin %d, stab %d/%d, canopy %d, bomb %d tris"
          % (tris([wing_a]), tris([wing_t]), tris([fin]), tris([stab_r]), tris([stab_l]),
             tris([canopy]), tris([bomb])))

    # a torn-off wing tip panel, cut from the thrown wing's own outer bay (ref obs 7)
    panel = W.cut_at(wing_t, 0, -5.6, "wreck_soft_panel_1")

    # ---- 3. break the hull in two at the FIREWALL (y 2.70 is the donor's own barrel
    # step, FUSE_STATIONS 3.16 in build_a1_skyraider_v2.py) and again at the fin root
    body = W.cut_at(air, 1, 2.70, "wreck_hard_fuselage")
    engine = rename(air, "wreck_hard_engine")
    tail = W.cut_at(body, 1, -2.95, "wreck_soft_tail")
    tear_seam(engine, 1, 2.70, band=0.22, amp=0.09, seed=31)
    tear_seam(body, 1, 2.70, band=0.22, amp=0.09, seed=32)
    tear_seam(body, 1, -2.95, band=0.20, amp=0.08, seed=33)
    tear_seam(tail, 1, -2.95, band=0.20, amp=0.08, seed=34)

    # ---- 4. crush the core. Nose worst: it went in first and stopped first.
    crush(body, keel, lambda y: 0.62 if y > 0.6 else (0.74 if y > -1.5 else 0.90),
          widen=0.28)
    crush(engine, keel, lambda y: 0.54, widen=0.34)
    buckle(body, -1.2, 7.5, hinge_z=keel)
    dent(engine, (0.0, 3.9, 0.10), 1.6, 0.55)
    crumple(body, 0.045, seed=21)
    crumple(engine, 0.05, seed=22)
    # the whole tail group is bolted to the aft fuselage: it rides the same crush and the
    # same buckle, then the assembly twists about the BREAK, not about its own centroid.
    tail_grp = [o for o in (tail, fin, stab_l, stab_r) if o is not None]
    for o in tail_grp:
        crush(o, keel, lambda y: 0.86, widen=0.0)
        buckle(o, -1.2, 7.5, hinge_z=keel)
        rigid(o, rot_deg=(0, 21.0, 0), translate=(0.35, 0.10, 0.0),
              pivot=(0.0, -2.95, keel))

    # ---- 5. prop: aft sweep with curled tips (engine was making power, ref obs 4)
    hub = (0.0, 5.20, 0.13)
    bend_blades(prop, hub, radial_axes=(0, 2), span_axis=1,
                sweep=0.34, curl=0.26, shorten=0.13, rmin=0.40)
    # and FOLD the disc. A 4.12 m prop left at full diameter stands 2 m proud of a wreck
    # whose whole point is a crushed silhouette; blades that reach the ground flatten.
    crush(prop, hub[2], lambda y: 0.40, widen=0.0)
    rigid(prop, rot_deg=(0, 0, 0), translate=(0.10, -0.30, 0.0))
    rename(prop, "wreck_soft_prop")

    # ---- 6. attached wing droops and digs in; thrown wing lands inverted 9 m out.
    # Pivot at the ROOT: rigid() about the centroid swings the root clear of the
    # fuselage it is still bolted to and opens daylight along the wing root.
    # ry droops the tip; rx only pitches the CHORD. The old builds leaned wings and fins
    # with an X euler and got a wing whose tip rode 1.5 m in the air with its leading edge
    # tipped up - a rotation that does not do what its comment says it does.
    # 4 deg of droop, not 10. The slot build_mound digs is only as wide as the hull, so
    # past +-1.7 m the ground climbs into the berm - a 10 deg droop over a 7.3 m half-span
    # dropped the tip 1.5 m and the whole starboard wing disappeared under the spoil.
    rigid(wing_a, rot_deg=(-5.0, 4.0, 3.0), pivot=(0.30, -0.6, keel + 0.55))
    edit_verts(wing_a, lambda p: p + Vector((0, 0, -0.18 * max(0.0, (p.x - 1.2) / 6.4))))
    tear_seam(wing_a, 0, 0.30, band=0.22, amp=0.10, seed=35)

    # INVERTED (ref obs 8). Upright it comes to rest on its own pylons and bombs with the
    # panel 0.4 m clear of the dirt; inverted it lies on its skin with the racks in the air.
    tear_seam(wing_t, 0, -0.30, band=0.26, amp=0.12, seed=36)
    W.place_at(wing_t, -9.4, 2.9)
    W.lay_flat(wing_t, tilt_deg=8.0, tilt_dir_deg=210.0, spin_deg=118.0, flip=True)
    crumple(panel, 0.07, seed=37)
    W.place_at(panel, 4.6, -6.4)
    W.lay_flat(panel, tilt_deg=7.0, tilt_dir_deg=40.0, spin_deg=64.0, flip=True)

    # a canopy off a crash is a smashed frame, not a bubble: crush it before it is thrown,
    # or it lies on the dirt as a dome touching along one arc and reads as hovering.
    cl, ch = bbox([canopy])
    crush(canopy, cl.z, lambda y: 0.34, widen=0.22)
    crumple(canopy, 0.04, seed=38)
    W.place_at(canopy, -4.9, -4.6)
    W.lay_flat(canopy, tilt_deg=6.0, tilt_dir_deg=120.0, spin_deg=27.0)
    rigid(bomb, rot_deg=(0, 6.0, 34.0))
    W.place_at(bomb, 5.4, 2.6)
    rigid(tank, rot_deg=(0, 86.0, 63.0))
    crumple(tank, 0.05, seed=39)
    W.place_at(tank, 2.9, -7.4)

    # ---- 7. plough the earth, THEN seat the aeroplane in the scar it dug.
    # Order matters. Sinking to a fixed world z before the mound exists means the burial
    # depth is whatever the mound's centreline profile happens to work out at - it came
    # out at 0.02 m of hull standing proud, i.e. the aeroplane had vanished into the dirt.
    # light lobing only. This wreck's long airframe already breaks the outline; the rim
    # only has to stop resolving into a smooth arc.
    mound = build_mound("wreck_hard_mound", half_x=6.4, half_y=7.6,
                        nose_y=4.0, tail_y=-5.8, berm_h=0.86, furrow_d=0.50,
                        hull_hw=1.15, seed=5, rim_noise=0.20,
                        lobes=((1, 0.09, 70.0), (2, 0.10, 25.0), (3, 0.085, 150.0)))
    hl, hh = bbox([body])
    grade = mound_height_at(mound, 0.0, (hl.y + hh.y) * 0.5)
    print("  slot floor under the hull %.2f -> keel %.2f" % (grade, grade - HULL_BURY))
    sink_ref([body, engine, wing_a, prop] + tail_grp, body, grade - HULL_BURY)
    # the thrown wing goes 0.30 m INTO the plough, not 0.16. Inverted, better than half
    # its vertices are pylon and bomb geometry standing clear of the skin, so a seating
    # that only kisses the dirt scored 17% contact - the panel has to be in the ground.
    for o, bury in ((wing_t, 0.30), (panel, 0.10), (canopy, 0.09)):
        W.drape_on_mound(o, mound, bury=bury)
    W.seat_on_mound(bomb, mound, bury=0.26)
    W.seat_on_mound(tank, mound, bury=0.24)
    gaps = [(o.name, round(min(p.z - mound_height_at(mound, p.x, p.y)
                               for p in verts(o)), 3))
            for o in (wing_t, panel, canopy, bomb)]
    print("  seated (name, min clearance to ground): %s" % gaps)

    # ---- 8. fresh burn: soot at the engine and along the wing-root fuel spill
    fire = [(0.0, 3.55, 0.10), (1.7, -0.30, -0.25), (-1.4, -1.20, -0.30)]
    repaint("wreck_a1_olive", OLIVE, "wreck_a1_olive_lit", OLIVE_LIT,
            camo_subs=("sea_", "underside_grey", "store_"),
            lit_parts=("stab", "tailfin", "panel_"))
    W.spatter([wing_t, panel, canopy, bomb, tank], frac=0.45, seed=17)
    # SOLID at the seat, then STOP. A wide radius with a small core dithers ~50% of the
    # faces over the whole airframe, and on the low-poly sunlit wing that half-and-half
    # speckle is exactly the chequerboard the camo repaint was done to kill - the same
    # defect wearing soot instead of tan.
    n, tot = scorch([body, engine, wing_a, prop] + tail_grp, fire, 1.8, seed=11, core=0.72)
    print("  scorched %d / %d faces (%.0f%%)" % (n, tot, 100.0 * n / max(1, tot)))

    anchor = pick_pilot_anchor([body, engine], fire, mound)
    print("  pilot_anchor %s : %.2f m off the hull, %.2f m from nearest fire, "
          "ground z %.2f" % ([round(x, 2) for x in anchor[:2]], anchor[4],
                             anchor[3], anchor[2]))
    W.matte()

    finish("a1", "a1_skyraider_crashed.glb",
           trimesh_prefixes=("wreck_hard_mound", "wreck_soft_wing", "wreck_soft_tail",
                             "wreck_soft_panel", "wreck_soft_prop", "wreck_soft_canopy",
                             "wreck_soft_stab", "wreck_soft_tailfin"),
           sockets=[("fire_socket_1", fire[0]), ("fire_socket_2", fire[1]),
                    ("fire_socket_3", fire[2])],
           anchor=anchor, mound=mound, render=render)


# ======================================================================= HUEY
HUEY_KEEP = ["fuselage_fwd", "fuselage_aft", "floor_cabin", "floor_cockpit",
             "transmission_bulkhead", "transmission_hump", "mast_fairing",
             "MainRotorMast", "New_Rotor_Hub", "New_Rotor_Flybar", "New_Blade_2",
             "New_TailBlade_1", "New_TailBlade_Hub", "TailRotorMast", "tail_fin",
             "tail_skid", "Elevator", "door_l", "door_r", "door_frame_l", "door_frame_r",
             "skid_rail_l", "skid_rail_r", "skid_cross_fwd", "skid_cross_aft",
             "skid_strut_l_fwd", "skid_strut_l_aft", "skid_strut_r_fwd",
             "skid_strut_r_aft", "exhaust_stack"]


def build_huey(render=True):
    print("=" * 72)
    print("HUEY WRECK")
    wipe()
    got = import_glb(HUEY_GLB)
    keep_only(HUEY_KEEP)
    print("  kept %d exterior parts, %d tris (donor GLB was 60,354 with markings+guns)"
          % (len(meshes()), tris()))

    fwd = by_name("fuselage_fwd")
    boom = by_name("fuselage_aft")
    blades = by_name("New_Blade_2")
    lo, hi = bbox([fwd])
    assert hi.y > 5.0, "nose is not at +Y: donor facing changed"

    # ---- 1. the main rotor is ONE bar spanning +-7.32; split it at the mast
    blade_t = split_faces(blades, lambda c: c.x > 0.02, "wreck_soft_rotor_thrown")
    rename(blades, "wreck_soft_rotor_att")

    # ---- 2. the boom parts at its ATTACH FITTINGS and travels as one assembly
    boom_grp = [boom, by_name("tail_fin"), by_name("tail_skid"), by_name("Elevator"),
                by_name("TailRotorMast"), by_name("New_TailBlade_1"),
                by_name("New_TailBlade_Hub")]
    boom_grp = [o for o in boom_grp if o is not None]
    rename(boom, "wreck_soft_boom")
    for o in boom_grp[1:]:
        rename(o, "wreck_soft_boom_" + o.name.lower().replace("new_", ""))
    # ry is the boom's ROLL: the XYZ euler applies X first, and the boom's long axis is
    # still +Y at this point, so rx would pitch it instead. A boom set down dead upright
    # on its belly reads as placed; rolled onto a chine it reads as landed.
    rigid_group(boom_grp, translate=(-7.0, -4.8, 0.0), rot_deg=(2.0, 14.0, 41.0))
    tear_seam(boom, 1, -0.815, band=0.30, amp=0.13, seed=41)

    # blade-strike notch in the boom - the classic tell (ref obs 3)
    dent(boom, (-8.6, -9.0, 1.2), 1.1, 0.42, seed=42)

    # ---- 3. crush the cabin. A downed Huey reads as a LOW DARK HEAP (ref obs 1).
    cabin_k = lambda y: 0.50 if y > 3.4 else (0.44 if y > 0.5 else 0.70)
    crush(fwd, 0.32, cabin_k, widen=0.26)
    # the exhaust stack is bolted to the roof and has to ride the roof down with it. Left
    # out of the crush it ends up hanging 1.6 m over the ground behind the cabin, reading
    # as a rock rather than as part of the aircraft.
    crush(by_name("exhaust_stack"), 0.32, cabin_k, widen=0.26)
    buckle(fwd, 1.2, 6.0, hinge_z=0.32)
    dent(fwd, (0.0, 5.4, 2.2), 2.3, 0.85, seed=43)
    crumple(fwd, 0.05, seed=44)
    rename(fwd, "wreck_hard_fuselage")

    for nm, new in (("transmission_bulkhead", "wreck_hard_transmission"),
                    ("transmission_hump", "wreck_hard_transmission_hump"),
                    ("floor_cabin", "wreck_hard_floor"),
                    ("floor_cockpit", "wreck_hard_floor_fwd"),
                    ("mast_fairing", "wreck_hard_mast_fairing"),
                    ("MainRotorMast", "wreck_hard_mast"),
                    ("exhaust_stack", "wreck_hard_exhaust")):
        o = by_name(nm)
        if o:
            rename(o, new)
    for nm in ("New_Rotor_Hub", "New_Rotor_Flybar"):
        o = by_name(nm)
        if o:
            rename(o, "wreck_soft_rotor_" + nm.split("_")[-1].lower())

    # the mast and head fold over with the roof
    head = [by_name("wreck_hard_mast"), by_name("wreck_hard_mast_fairing"),
            by_name("wreck_soft_rotor_hub"), by_name("wreck_soft_rotor_flybar"),
            by_name("wreck_soft_rotor_att")]
    head = [o for o in head if o is not None]
    rigid_group(head, rot_deg=(23.0, 0.0, 0.0), translate=(0.15, -0.35, -1.35))

    # ref obs 3: one blade SNAPPED SHORT at the hub, one drooping to the dirt. Left at
    # full span the attached blade is a 7.8 m razor ruled straight across the silhouette
    # from every angle - the single most prominent line in the whole wreck.
    ba = by_name("wreck_soft_rotor_att")
    hub_x = bbox([ba])[1].x
    frag = W.cut_at(ba, 0, hub_x - 3.9, "wreck_soft_rotor_frag")
    tear_seam(ba, 0, hub_x - 3.9, band=0.16, amp=0.10, seed=46)
    edit_verts(ba, lambda p: p + Vector(
        (0, 0, -2.45 * min(1.0, abs(p.x - hub_x) / 3.9) ** 2.0)))

    # the separated pieces LIE DOWN. A rotor blade is a 7 m plank 30 mm thick: stood on
    # its edge it is a one-pixel card from every angle and reads as a render glitch, which
    # is how the first pass shipped it. lay_flat solves for the plate's measured normal,
    # and bend_mid's `toward` decides which end rises instead of leaving it to an SVD sign.
    def throw(o, heading, x, y, kink, frac):
        d = (math.cos(math.radians(heading)), math.sin(math.radians(heading)))
        rigid(o, rot_deg=(0.0, 0.0, heading))
        W.place_at(o, x, y)
        W.lay_flat(o)
        W.bend_mid(o, kink, frac=frac, toward=d)

    # HEADINGS ARE NOT FREE. A 7 m blade lying perfectly flat still reads as a plank
    # standing on end when its plan heading points at the camera - measured 52 deg
    # against the threequarter view's 40 deg azimuth, and the frag was worse at 37 deg.
    # Both were 3-5 deg of tilt, both passed every seating number, and the render showed
    # a vertical bar. Render azimuths are 0/40/90/150 (wrecklib.VIEW_AZ), so the only
    # headings clear of all four by >=25 deg are ~65 and ~120. The gate now enforces it.
    throw(blade_t, 120.0, 7.6, -4.1, 9.0, 0.63)
    throw(frag, 65.0, -6.2, -1.6, 12.0, 0.55)
    crumple(frag, 0.04, seed=47)

    # ---- 4. skids splay, one door torn off
    for nm, roll in (("skid_rail_l", -26.0), ("skid_rail_r", 26.0)):
        o = by_name(nm)
        rigid(o, rot_deg=(roll, 0, 0))
        rename(o, "wreck_soft_" + nm)
    for nm in ("skid_cross_fwd", "skid_cross_aft", "skid_strut_l_fwd", "skid_strut_l_aft",
               "skid_strut_r_fwd", "skid_strut_r_aft"):
        o = by_name(nm)
        if o:
            rename(o, "wreck_soft_" + nm)
    # the torn-off door lands as a flattish bent sheet, half in the dirt (ref obs 7) -
    # not as a signboard. Thrown forward-left, off the mound, on flat ground where a
    # rigid plate can make contact along its whole face.
    dl = by_name("door_l")
    W.place_at(dl, -7.7, 4.9)
    # 2 deg, not 4: at 4 deg the crumpled panel still showed 0.26 m of daylight under its
    # far edge and read as hovering. Measured contact went 74% -> see the gate table.
    W.lay_flat(dl, tilt_deg=2.0, tilt_dir_deg=200.0, spin_deg=34.0)
    crumple(dl, 0.055, seed=45)
    rename(dl, "wreck_soft_door_thrown")
    dr = by_name("door_r")
    rigid(dr, rot_deg=(0, 0, -22.0), translate=(-0.35, 0.1, -0.55))
    rename(dr, "wreck_soft_door_r")
    for nm in ("door_frame_l", "door_frame_r"):
        o = by_name(nm)
        if o:
            rename(o, "wreck_soft_" + nm)

    # ---- 5. ground and plough
    THROWN = {"wreck_soft_rotor_thrown", "wreck_soft_door_thrown", "wreck_soft_rotor_frag"}
    attached = [o for o in meshes() if o.name not in THROWN and o not in boom_grp]
    sink(attached, -0.95)

    # ONE dominant ejecta lobe ahead of the nose, flank ridges dead behind the tail, and
    # a lobed rim. The Huey is the wreck that needed all three: its hulk is a low crushed
    # heap that fills almost none of the scar, so a ring berm around it read as a donut
    # with a nut in the middle from every angle.
    # and it is SMALLER and LOWER than the other two. The A-1 and the Phantom are long
    # airframes that cover their own scar; a crushed Huey cabin is 1.5 m of low dark heap,
    # so a 1.9 m ejecta pile simply stood in front of it and the dirt became the subject.
    # Spoil must stay under the wreck's own height or the silhouette belongs to the mound.
    mound = build_mound("wreck_hard_mound", half_x=4.5, half_y=6.1,
                        nose_y=5.4, tail_y=-1.6, berm_h=0.92, furrow_d=0.38,
                        hull_hw=1.20, seed=6, centre_y=2.2, churn=1.6, rim_noise=0.16,
                        lobes=((1, 0.10, 92.0), (2, 0.11, 22.0), (3, 0.09, 150.0)),
                        ridge_rear=0.20, ridge_fwd=1.35, rear_fade=0.60,
                        nose_gain=1.05, nose_reach=1.45, nose_sig=1.55,
                        nose_wx=0.72, nose_skew=0.85, furrow_w=2.2)
    # 0.30 m of a 1.05 m boom below grade: the first pass buried 0.12 m and the contact
    # was arguable from every angle. A thrown structure has to be measurably IN the ground.
    W.seat_group_on_mound(boom_grp, mound, bury=0.30)
    # thin plates get a thin burial or they vanish under the terrain they are lying on
    W.seat_on_mound(by_name("wreck_soft_rotor_thrown"), mound, bury=0.015)
    W.seat_on_mound(by_name("wreck_soft_rotor_frag"), mound, bury=0.02)
    W.seat_on_mound(by_name("wreck_soft_door_thrown"), mound, bury=0.09)

    fire = [(0.0, 1.3, 1.05), (0.55, 4.6, 0.55), (-6.9, -6.4, 0.2)]
    repaint("wreck_huey_olive", OLIVE, "wreck_huey_olive_lit", OLIVE_LIT,
            camo_subs=("od_exterior", "od_interior", "deck", "huey_metal"),
            lit_parts=("door", "elevator", "tail_fin"))
    n, tot = scorch([o for o in meshes() if o.name.startswith("wreck_")
                     and "mound" not in o.name and "canopy" not in o.name],
                    fire, 1.9, seed=12, core=0.72)
    print("  scorched %d / %d faces (%.0f%%)" % (n, tot, 100.0 * n / max(1, tot)))

    anchor = pick_pilot_anchor([by_name("wreck_hard_fuselage")], fire, mound)
    print("  pilot_anchor %s : %.2f m off the hull, %.2f m from nearest fire, "
          "ground z %.2f" % ([round(x, 2) for x in anchor[:2]], anchor[4],
                             anchor[3], anchor[2]))

    finish("huey", "huey_crashed.glb",
           trimesh_prefixes=("wreck_hard_mound", "wreck_soft_rotor", "wreck_soft_boom",
                             "wreck_soft_door", "wreck_soft_skid", "wreck_hard_floor"),
           sockets=[("fire_socket_1", fire[0]), ("fire_socket_2", fire[1]),
                    ("fire_socket_3", fire[2])],
           anchor=anchor, mound=mound, render=render, debris_gate="strict")


# =================================================================== F-4 PHANTOM
# DONOR: `f4_phantom_v2.glb` (2026-08-14), which replaced the third-party `f4_phantom.glb`
# whose part NAMES were swapped against its geometry (`F4_Exhaust_R` was the fin) and
# which embedded a tempfile-named JPEG that Godot re-extracted on every import. The v2
# airframe is three meshes; parts are found by welding and taking whole components.
def build_f4(render=True):
    print("=" * 72)
    print("F-4 PHANTOM WRECK  (donor f4_phantom_v2.glb)")
    wipe()
    import_glb(os.path.join(AIR, "f4_phantom_v2.glb"))
    keep_only(["F4_Airframe", "F4_Stores", "F4_Markings"])
    air, stores, marks = by_name("F4_Airframe"), by_name("F4_Stores"), by_name("F4_Markings")
    for o in (air, stores, marks):
        n0, n1 = weld(o)
        print("  weld %-14s %4d -> %4d verts, %d parts"
              % (o.name, n0, n1, len(components(o))))

    lo, hi = bbox([air])
    assert hi.y > 9.0, "nose is not at +Y: donor facing changed"
    print("  donor airframe %s .. %s" % ([round(x, 2) for x in lo],
                                         [round(x, 2) for x in hi]))
    keel = max(components(air).values(), key=lambda d: d["n"])["lo"].z
    print("  keel (fuselage barrel lowest z) %.3f" % keel)

    join_objs(air, [marks])

    # ---- 1. take the aeroplane apart by its own parts
    canopy = W.split_material(air, "canopy", "wreck_soft_canopy")
    wing_a = part_split(air, lambda lo, hi, c, n: hi.x > 3.0 and lo.x > 0.3,
                        "wreck_soft_wing_r")
    wing_t = part_split(air, lambda lo, hi, c, n: lo.x < -3.0 and hi.x < -0.3,
                        "wreck_soft_wing_thrown")
    fin = part_split(air, lambda lo, hi, c, n: abs(c.x) < 0.3 and c.y < -3.0
                     and hi.z > 1.5, "wreck_soft_tailfin")
    intake_r = part_split(air, lambda lo, hi, c, n: 0.3 < c.x < 2.0 and c.y > 0.0,
                          "wreck_soft_intake_r")
    intake_l = part_split(air, lambda lo, hi, c, n: -2.0 < c.x < -0.3 and c.y > 0.0,
                          "wreck_soft_intake_l")
    noz_r = part_split(air, lambda lo, hi, c, n: c.x > 0.1 and -6.0 < c.y < -3.0,
                       "wreck_soft_nozzle_r")
    noz_l = part_split(air, lambda lo, hi, c, n: c.x < -0.1 and -6.0 < c.y < -3.0,
                       "wreck_soft_nozzle_l")
    stab_r = part_split(air, lambda lo, hi, c, n: c.x > 0.3 and c.y < -6.0,
                        "wreck_soft_stab_r")
    stab_l = part_split(air, lambda lo, hi, c, n: c.x < -0.3 and c.y < -6.0,
                        "wreck_soft_stab_l")

    # stores: one 500 lb bomb tears clear, the wing racks travel with their wing, and the
    # centreline tank and the belly Sparrows stay on the hull (|x| 0.4-0.8: a plan-x rule
    # alone would have thrown them 9 m with the port wing).
    bomb = part_split(stores, lambda lo, hi, c, n: 1.8 < c.x < 2.2 and n >= 40,
                      "wreck_soft_ord_bomb")
    # the centreline tank and its pylon go too. Left bolted on they hang 0.8 m below the
    # keel, so any "sit the wreck in the ground" pass seats the aeroplane ON THE TANK and
    # the belly ends up 0.41 m proud of a scar it is supposed to be ploughed into.
    tank = part_split(stores, lambda lo, hi, c, n: abs(c.x) < 0.5, "wreck_soft_tank_thrown")
    st_r = part_split(stores, lambda lo, hi, c, n: c.x > 1.5, "f4_stores_r")
    st_l = part_split(stores, lambda lo, hi, c, n: c.x < -1.5, "f4_stores_l")
    join_objs(air, [stores])
    join_objs(wing_a, [st_r])
    join_objs(wing_t, [st_l])
    print("  parts: wing_r %d, wing_thrown %d, fin %d, intake %d/%d, nozzle %d/%d, "
          "stab %d/%d, canopy %d, bomb %d tris"
          % (tris([wing_a]), tris([wing_t]), tris([fin]), tris([intake_r]),
             tris([intake_l]), tris([noz_r]), tris([noz_l]), tris([stab_r]),
             tris([stab_l]), tris([canopy]), tris([bomb])))

    # ---- 2. jets break behind the cockpit; keep it to TWO big pieces (ref obs 9).
    # y 4.80 is just forward of the intake lips (donor station 5.55), so the break takes
    # the radome, the gun bay and the cockpit floor and leaves the intakes on the centre
    # section where they belong.
    body = W.cut_at(air, 1, 4.80, "wreck_hard_fuselage")
    nose = rename(air, "wreck_hard_nose")
    tear_seam(nose, 1, 4.80, band=0.45, amp=0.16, seed=51)
    tear_seam(body, 1, 4.80, band=0.45, amp=0.16, seed=52)

    crush(body, keel, lambda y: 0.72 if y > -2.0 else 0.88, widen=0.32)
    buckle(body, -3.0, 8.0, hinge_z=keel)
    crumple(body, 0.06, seed=53)
    # the whole tail group is bolted to the aft fuselage and has to ride the crush and the
    # buckle down with it. Left out, the fin's root ends up standing clear of the spine it
    # is attached to and the fin reads as a loose plate planted in the ground.
    tail_grp = [o for o in (fin, stab_l, stab_r, noz_l, noz_r) if o is not None]
    for o in tail_grp:
        crush(o, keel, lambda y: 0.78, widen=0.0)
        buckle(o, -3.0, 8.0, hinge_z=keel)
    # lean the fin about its ROOT. rigid() defaults to the vertex centroid, which for a
    # 2.4 m fin swings the root clear of the spine and opens daylight under it.
    # rot_deg=(34, 0, 7) RAKED the fin fore-and-aft and left it dead upright at a
    # measured 90 deg plate tilt - a fin plate lies in the x=0 plane, so an X euler
    # cannot lean it. ry is the axis that knocks a fin over.
    fl, fh = bbox([fin])
    rigid(fin, rot_deg=(14.0, 36.0, 0.0),
          pivot=((fl.x + fh.x) / 2.0, (fl.y + fh.y) / 2.0, fl.z))
    for o in (stab_l, stab_r):
        if o:
            rigid(o, rot_deg=(0, 15.0, 0))

    # ---- 3. intakes crumple where the centre section ploughed in
    for o, sd in ((intake_r, 56), (intake_l, 57)):
        if o is None:
            continue
        ic = bbox([o])
        dent(o, (ic[0].x + (ic[1].x - ic[0].x) * 0.5, 3.6, 0.35), 2.6, 0.45, seed=sd)
        crush(o, keel, lambda y: 0.62, widen=0.30)

    # ---- 4. one wing attached and bent, one thrown clear and INVERTED (ref obs 8) -
    # upright it rests on its own pylons with the panel 0.4 m clear of the dirt.
    rigid(wing_a, rot_deg=(-6.0, 6.0, 6.0), pivot=(0.95, -0.7, keel + 0.6))
    edit_verts(wing_a, lambda p: p + Vector((0, 0, -0.20 * max(0.0, (p.x - 1.0) / 4.9))))
    tear_seam(wing_a, 0, 0.95, band=0.25, amp=0.11, seed=54)
    tear_seam(wing_t, 0, -0.95, band=0.28, amp=0.13, seed=55)
    W.place_at(wing_t, -8.2, -6.4)
    W.lay_flat(wing_t, tilt_deg=8.0, tilt_dir_deg=150.0, spin_deg=64.0, flip=True)

    # a canopy off a burning wreck is crazed and OPAQUE - and it is a smashed frame by the
    # time it lands, not a bubble sitting on one arc of contact.
    canopy.data.materials.clear()
    # 0.065, not 0.10. Measured on the shipped palette, the crazed canopy was the
    # BRIGHTEST thing on the site (lum 0.107 against a 0.053 airframe) and, being neutral,
    # it took the sky's blue - a slate slab lying beside the hulk pulling the eye off the
    # aeroplane. Crazed perspex is lighter than paint, but not by two stops.
    canopy.data.materials.append(flat_mat("wreck_canopy_crazed",
                                          (0.065, 0.070, 0.062, 1.0), rough=0.85))
    # crushed to 0.18 of its height, and NO residual tilt. A 4 m tandem greenhouse is a
    # long piece: 6 deg of deliberate tilt lifts one end 0.42 m, which on its own took
    # ground contact down to 14%. Long debris gets flattened, not tilted.
    ccl, cch = bbox([canopy])
    crush(canopy, ccl.z, lambda y: 0.18, widen=0.20)
    crumple(canopy, 0.045, seed=58)
    W.place_at(canopy, 4.9, 2.4)
    W.lay_flat(canopy, tilt_deg=0.0, spin_deg=118.0)
    # heading, not decoration: render azimuths are 0/40/90/150 and a 1.8 m bomb
    # lying along 152 deg projects to a vertical bar in the high view.
    rigid(bomb, rot_deg=(0, 8.0, 25.0))
    W.place_at(bomb, -3.9, 5.6)

    # the nose section is thrown, yawed and dropped just off the break: a 5 m chunk of
    # fuselage that clears the hulk entirely is a lone rounded body, and a rounded body
    # lying on flat ground touches along one line - 5% contact was the old build's score.
    rigid(nose, rot_deg=(11.0, 0, -29.0), translate=(-2.3, 0.5, -1.35))
    crush(nose, keel, lambda y: 0.70, widen=0.20)
    crumple(nose, 0.05, seed=59)

    # ---- 5. ground and plough
    thrown = {"wreck_soft_wing_thrown", "wreck_soft_canopy", "wreck_soft_ord_bomb",
              "wreck_soft_tank_thrown"}
    mound = build_mound("wreck_hard_mound", half_x=5.9, half_y=9.4,
                        nose_y=5.2, tail_y=-8.0, berm_h=0.88, furrow_d=0.52,
                        hull_hw=1.15, seed=7, rim_noise=0.20,
                        lobes=((1, 0.10, 55.0), (2, 0.09, 15.0), (3, 0.075, 140.0)))
    hl, hh = bbox([body])
    grade = mound_height_at(mound, 0.0, (hl.y + hh.y) * 0.5)
    print("  slot floor under the hull %.2f -> keel %.2f" % (grade, grade - HULL_BURY))
    # the mound is in meshes() now that it is built first, and sinking THE GROUND with
    # the aeroplane leaves every relative clearance exactly where it started.
    sink_ref([o for o in meshes() if o.name not in thrown and o is not mound],
             body, grade - HULL_BURY)
    W.drape_on_mound(wing_t, mound, bury=0.30)
    W.drape_on_mound(canopy, mound, bury=0.12)
    rigid(tank, rot_deg=(0, 88.0, 118.0))
    crumple(tank, 0.05, seed=60)
    W.place_at(tank, -5.4, 4.4)
    W.seat_on_mound(tank, mound, bury=0.24)
    W.seat_on_mound(bomb, mound, bury=0.26)
    W.seat_group_on_mound([nose], mound, bury=0.42)

    fire = [(0.0, -2.6, 0.20), (1.5, 1.0, -0.10), (-1.6, -0.4, -0.15)]
    repaint("wreck_f4_greygreen", GREYGREEN, "wreck_f4_greygreen_lit", GREYGREEN_LIT,
            camo_subs=("sea_", "underside_grey", "store_"),
            lit_parts=("stab", "tailfin"))
    W.spatter([wing_t, canopy, bomb, tank], frac=0.45, seed=17)
    # 2.8 m and a 0.28 core, not 4.2 / 0.42: at the wider setting the soot covered the
    # whole spine and the Phantom read as a black smear with camo edges. Fresh burn is
    # soot AT THE SEATS fading out, and the aeroplane has to survive it.
    n, tot = scorch([o for o in meshes() if o.name.startswith("wreck_")
                     and "mound" not in o.name and "canopy" not in o.name],
                    fire, 2.3, seed=13, core=0.70)
    print("  scorched %d / %d faces (%.0f%%)" % (n, tot, 100.0 * n / max(1, tot)))

    anchor = pick_pilot_anchor([body], fire, mound)
    print("  pilot_anchor %s : %.2f m off the hull, %.2f m from nearest fire, "
          "ground z %.2f" % ([round(x, 2) for x in anchor[:2]], anchor[4],
                             anchor[3], anchor[2]))

    # PSX materials do not sparkle, and metallic/roughness export into the GLB so Godot
    # inherits whatever the donor carried. The v2 donor is already flat, so this is the
    # guard rather than the fix - it also forces the canopy opaque.
    W.matte()

    finish("f4", "f4_phantom_crashed.glb",
           trimesh_prefixes=("wreck_hard_mound", "wreck_soft_wing", "wreck_soft_stab",
                             "wreck_soft_tailfin", "wreck_soft_canopy",
                             "wreck_soft_intake", "wreck_soft_nozzle"),
           sockets=[("fire_socket_1", fire[0]), ("fire_socket_2", fire[1]),
                    ("fire_socket_3", fire[2])],
           anchor=anchor, mound=mound, render=render)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
    which = argv[0] if argv else "all"
    rend = "--norender" not in argv
    if "--dry" in argv:
        SHIP_DIR = OUT
    for a in argv:
        if a.startswith("--tag="):
            TAG = a.split("=", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    if which in ("a1", "all"):
        build_a1(rend)
    if which in ("huey", "all"):
        build_huey(rend)
    if which in ("f4", "all"):
        build_f4(rend)
    print("\nALL DONE")
