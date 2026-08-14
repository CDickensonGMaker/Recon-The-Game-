"""Build the three RECONgame crashed-aircraft wrecks, headless.

  blender -b --factory-startup -P build_wrecks.py -- a1|huey|f4|all [--norender]

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
                      export_glb, save_blend, render_views, verify_roundtrip, AIR)

OUT = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0201f774-4017-48d5-924a-0296e7efee35\scratchpad\wrecks"
HUEY_GLB = os.path.join(W.ART, "us", "vehicles", "huey_v3.glb")


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
            if dmin < 6.0 or abs(gz) > 0.45:
                continue
            s = dmin - abs(gz) * 6.0
            if s > best_s:
                best_s, best = s, (px, py, max(0.0, gz), dmin, db)
    if best is None:
        raise SystemExit("FATAL: no pilot_anchor satisfies 4-6 m off the hull, "
                         ">=6 m from fire, on flat ground")
    return best


def finish(tag, glb_name, trimesh_prefixes, sockets, anchor, mound, render=True):
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
        for t in (0.15, 0.35, 0.55, 0.75):
            yy = hl.y + (hh.y - hl.y) * t
            band = [p.z for o in hull for p in verts(o) if abs(p.y - yy) < 0.9]
            if not band:
                continue
            gz = mound_height_at(mound, 0.0, yy)
            rows.append((round(yy, 1), round(gz, 2), round(max(band), 2),
                         round(max(band) - gz, 2)))
        print("   burial (y, earth_z, hull_top_z, proud_m): %s" % rows)
    tall = sorted(((bbox([o])[1].z, o.name) for o in meshes()
                   if not o.name.endswith("-colonly")), reverse=True)[:4]
    print("   tallest parts: %s" % [(n, round(z, 2)) for z, n in tall])

    blend = os.path.join(AIR, glb_name.replace(".glb", ".blend"))
    save_blend(blend)
    glb = os.path.join(AIR, glb_name)
    mb = export_glb(glb)
    print("   exported %s  %.2f MB" % (glb_name, mb))
    if render:
        render_views(OUT, tag)
    # LAST, because it wipes the scene: prove the shipped file, not the build scene.
    verify_roundtrip(glb, [s[0] for s in sockets] + ["pilot_anchor"])


# =============================================================== A-1 SKYRAIDER
def build_a1(render=True):
    print("=" * 72)
    print("A-1 SKYRAIDER WRECK")
    wipe()
    got = import_glb(os.path.join(AIR, "a1_skyraider.glb"))
    body = got["A1_Skyraider_Body"]
    prop = got["A1_Propeller"]
    bomb = got["Ord_L5_Mk82"]
    keep_only([body.name, prop.name, bomb.name])

    # nose must be +Y before anything else is believed
    lo, hi = bbox([body])
    assert hi.y > lo.y, "degenerate"
    pv = verts(prop)
    assert sum(p.y for p in pv) / len(pv) > 0.0, "prop is not at +Y: donor facing changed"
    print("  donor body %s .. %s  prop mean y %.3f" %
          ([round(x, 2) for x in lo], [round(x, 2) for x in hi],
           sum(p.y for p in pv) / len(pv)))

    # ---- 1. break the airframe up along existing edges
    canopy = W.split_material(body, "Canopy", "wreck_soft_canopy")
    wing_t = split_faces(body, lambda c: c.x < -1.15 and -4.75 < c.y < -2.25,
                         "wreck_soft_wing_thrown")
    wing_a = split_faces(body, lambda c: c.x > 1.15 and -4.75 < c.y < -2.25,
                         "wreck_soft_wing_r")
    tail = split_faces(body, lambda c: c.y < -9.2, "wreck_soft_tail")
    engine = split_faces(body, lambda c: c.y > -0.20, "wreck_hard_engine")
    rename(body, "wreck_hard_fuselage")
    print("  split: fus %d, engine %d, wing_a %d, wing_t %d, tail %d, canopy %d tris" %
          (tris([body]), tris([engine]) if engine else 0, tris([wing_a]) if wing_a else 0,
           tris([wing_t]) if wing_t else 0, tris([tail]) if tail else 0,
           tris([canopy]) if canopy else 0))

    # a torn-off wing tip panel, cut from the wing's own outer bay
    panel = split_faces(wing_t, lambda c: c.x < -5.4, "wreck_soft_panel_1")

    # ---- 2. crush the core. Nose worst: it went in first and stopped first.
    floor = -0.805
    crush(body, floor, lambda y: 0.46 if y > -1.0 else (0.62 if y > -6.0 else 0.88),
          widen=0.30)
    crush(engine, floor, lambda y: 0.44, widen=0.34)
    buckle(body, -3.1, 7.5, hinge_z=floor)
    dent(engine, (0.0, 0.30, 0.05), 1.5, 0.55)
    crumple(body, 0.045, seed=21)
    crumple(engine, 0.05, seed=22)
    tear_seam(body, 0, 1.15, band=0.22, amp=0.09, seed=31)
    tear_seam(body, 0, -1.15, band=0.22, amp=0.09, seed=32)

    # ---- 3. prop: aft sweep with curled tips (engine was making power)
    bend_blades(prop, (0.0, 0.78, 0.30), radial_axes=(0, 2), span_axis=1,
                sweep=0.42, curl=0.30, shorten=0.13, rmin=0.42)
    # and FOLD the disc. A 5.1 m prop left at full diameter stands 4.1 m proud and the
    # wreck reads as a windmill; blades that reach the ground get flattened, not swept.
    crush(prop, 0.30, lambda y: 0.42, widen=0.0)
    rigid(prop, rot_deg=(0, 0, 0), translate=(0.10, -0.35, 0.0))
    rename(prop, "wreck_soft_prop")

    # ---- 4. attached wing droops and digs in; thrown wing lands on edge 10 m out
    rigid(wing_a, rot_deg=(-14.0, 0, 4.0))
    edit_verts(wing_a, lambda p: p + Vector((0, 0, -0.30 * max(0.0, (p.x - 1.2) / 5.8))))
    tear_seam(wing_a, 0, 1.15, band=0.22, amp=0.10, seed=33)

    rigid(wing_t, rot_deg=(31.0, 5.0, -38.0), translate=(-3.4, 3.6, 0))
    tear_seam(wing_t, 0, -1.15, band=0.26, amp=0.12, seed=34)
    rigid(panel, rot_deg=(48.0, 0, 51.0), translate=(2.2, -6.0, 0))
    crumple(panel, 0.07, seed=35)

    rigid(tail, rot_deg=(0, 26.0, 0), translate=(0.5, 0.2, -0.25))
    rigid(canopy, rot_deg=(38.0, 0, 22.0), translate=(-3.1, -2.4, 0))
    rename(bomb, "wreck_soft_ord_mk82")
    rigid(bomb, rot_deg=(0, 74.0, 28.0), translate=(3.4, 1.4, 0))

    # ---- 5. ground it, then plough the earth up around it
    core = [body, engine]
    sink(core, -0.30)
    for o in (wing_a, prop):
        sink([o], -0.22)

    mound = build_mound("wreck_hard_mound", half_x=6.2, half_y=7.6,
                        nose_y=0.3, tail_y=-7.4, berm_h=1.05, furrow_d=0.50,
                        hull_hw=1.35, seed=5)
    for o in (wing_t, panel, tail, canopy, bomb):
        W.seat_on_mound(o, mound, bury=0.10)
    gaps = [(o.name, round(min(p.z - mound_height_at(mound, p.x, p.y)
                               for p in verts(o)), 3))
            for o in (wing_t, panel, tail, canopy, bomb)]
    print("  seated (name, min clearance to ground): %s" % gaps)

    # ---- 6. fresh burn: soot at the engine and along the wing-root fuel spill
    fire = [(0.0, -0.15, 0.35), (2.0, -3.3, -0.05), (-1.3, -3.6, -0.15)]
    n, tot = scorch([body, engine, wing_a, prop, tail], fire, 2.1, seed=11)
    print("  scorched %d / %d faces (%.0f%%)" % (n, tot, 100.0 * n / max(1, tot)))

    anchor = pick_pilot_anchor([body, engine], fire, mound)
    print("  pilot_anchor %s : %.2f m off the hull, %.2f m from nearest fire, "
          "ground z %.2f" % ([round(x, 2) for x in anchor[:2]], anchor[4],
                             anchor[3], anchor[2]))

    finish("a1", "a1_skyraider_crashed.glb",
           trimesh_prefixes=("wreck_hard_mound", "wreck_soft_wing", "wreck_soft_tail",
                             "wreck_soft_panel", "wreck_soft_prop", "wreck_soft_canopy"),
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
    rigid_group(boom_grp, translate=(-7.0, -4.8, 0.0), rot_deg=(2.0, 0.0, 41.0))
    tear_seam(boom, 1, -0.815, band=0.30, amp=0.13, seed=41)

    # blade-strike notch in the boom - the classic tell (ref obs 3)
    dent(boom, (-8.6, -9.0, 1.2), 1.1, 0.42, seed=42)

    # ---- 3. crush the cabin. A downed Huey reads as a LOW DARK HEAP (ref obs 1).
    crush(fwd, 0.32, lambda y: 0.50 if y > 3.4 else (0.44 if y > 0.5 else 0.70),
          widen=0.26)
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
    # the attached blade droops until its tip is in the dirt
    ba = by_name("wreck_soft_rotor_att")
    edit_verts(ba, lambda p: p + Vector((0, 0, -2.35 * min(1.0, (abs(p.x) / 7.3)) ** 1.3)))
    rigid(blade_t, rot_deg=(3.0, 4.0, 63.0), translate=(6.6, -7.8, -3.6))

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
    dl = by_name("door_l")
    rigid(dl, rot_deg=(22.0, 0, 38.0), translate=(4.3, -3.1, -1.2))
    rename(dl, "wreck_soft_door_thrown")
    dr = by_name("door_r")
    rigid(dr, rot_deg=(0, 0, -22.0), translate=(-0.35, 0.1, -0.55))
    rename(dr, "wreck_soft_door_r")
    for nm in ("door_frame_l", "door_frame_r"):
        o = by_name(nm)
        if o:
            rename(o, "wreck_soft_" + nm)

    # ---- 5. ground and plough
    attached = [o for o in meshes() if o.name not in
                {"wreck_soft_rotor_thrown", "wreck_soft_door_thrown"}
                and o not in boom_grp]
    sink(attached, -0.95)

    mound = build_mound("wreck_hard_mound", half_x=5.2, half_y=7.2,
                        nose_y=5.4, tail_y=-1.6, berm_h=1.02, furrow_d=0.46,
                        hull_hw=1.31, seed=6)
    W.seat_group_on_mound(boom_grp, mound, bury=0.12)
    for nm in ("wreck_soft_rotor_thrown", "wreck_soft_door_thrown"):
        W.seat_on_mound(by_name(nm), mound, bury=0.10)

    fire = [(0.0, 1.3, 1.05), (0.55, 4.6, 0.55), (-6.9, -6.4, 0.2)]
    n, tot = scorch([o for o in meshes() if o.name.startswith("wreck_")
                     and "mound" not in o.name and "canopy" not in o.name],
                    fire, 2.0, seed=12)
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
           anchor=anchor, mound=mound, render=render)


# =================================================================== F-4 PHANTOM
def build_f4(render=True):
    print("=" * 72)
    print("F-4 PHANTOM WRECK")
    wipe()
    got = import_glb(os.path.join(AIR, "f4_phantom.glb"))
    keep_only(["F4_Fuselage", "F4_Wing_L", "F4_Wing_R", "F4_Canopy", "F4_Intake_L",
               "F4_Intake_R", "F4_Tank_L", "F4_Tank_R", "F4_GunPod_M61", "F4_HStab_R",
               "F4_VFin_L", "F4_VFin_L.001", "F4_Exhaust_R", "F4_Pylon_Center",
               "F4_Pylon_L", "F4_Pylon_R"])
    # the donor ships two parts whose names are swapped relative to their geometry:
    # `F4_Exhaust_R` is the 2.9 m VERTICAL FIN (z 1.62..4.51) and the `F4_VFin_*` pair
    # are the horizontal stabilators. Named here for what they ARE.
    fus = by_name("F4_Fuselage")
    lo, hi = bbox([fus])
    assert hi.y > 10.0, "nose is not at +Y: donor facing changed"
    print("  donor fuselage %s .. %s" % ([round(x, 2) for x in lo],
                                         [round(x, 2) for x in hi]))

    # ---- 1. jets break behind the cockpit; keep it to TWO big pieces (ref obs 9)
    nose = split_faces(fus, lambda c: c.y > 3.05, "wreck_hard_nose")
    rename(fus, "wreck_hard_fuselage")
    tear_seam(fus, 1, 3.05, band=0.45, amp=0.16, seed=51)
    tear_seam(nose, 1, 3.05, band=0.45, amp=0.16, seed=52)

    crush(fus, 0.084, lambda y: 0.55 if y > -2.0 else 0.78, widen=0.32)
    buckle(fus, -3.0, 8.0, hinge_z=0.084)
    crumple(fus, 0.06, seed=53)

    rigid(nose, rot_deg=(19.0, 0, -33.0), translate=(-2.4, 3.4, -1.1))
    crush(nose, 0.10, lambda y: 0.72, widen=0.20)

    # ---- 2. one wing attached and bent, one thrown clear
    wr = rename(by_name("F4_Wing_R"), "wreck_soft_wing_r")
    rigid(wr, rot_deg=(-19.0, 0, 6.0))
    edit_verts(wr, lambda p: p + Vector((0, 0, -0.34 * max(0.0, (p.x - 1.0) / 4.8))))
    tear_seam(wr, 0, 1.0, band=0.25, amp=0.11, seed=54)

    wl = rename(by_name("F4_Wing_L"), "wreck_soft_wing_thrown")
    rigid(wl, rot_deg=(63.0, 8.0, 41.0), translate=(-5.6, -5.9, 0))
    tear_seam(wl, 0, -1.0, band=0.28, amp=0.13, seed=55)

    # ---- 3. intakes crumple, fin leans, one tank bursts clear
    for nm, new, sd in (("F4_Intake_L", "wreck_soft_intake_l", 56),
                        ("F4_Intake_R", "wreck_soft_intake_r", 57)):
        o = rename(by_name(nm), new)
        dent(o, (0.0, 4.2, 1.1), 3.0, 0.55, seed=sd)
        crush(o, 0.58, lambda y: 0.55, widen=0.35)

    fin = rename(by_name("F4_Exhaust_R"), "wreck_soft_tailfin")
    rigid(fin, rot_deg=(41.0, 0, 9.0))
    for nm, new in (("F4_VFin_L", "wreck_soft_stab_l"),
                    ("F4_VFin_L.001", "wreck_soft_stab_r"),
                    ("F4_HStab_R", "wreck_soft_stab_aft")):
        o = by_name(nm)
        if o:
            rename(o, new)
            rigid(o, rot_deg=(0, 17.0, 0))
    rename(by_name("F4_Tank_R"), "wreck_soft_tank_r")
    tk = rename(by_name("F4_Tank_L"), "wreck_soft_tank_thrown")
    rigid(tk, rot_deg=(0, 84.0, 37.0), translate=(-2.6, -3.4, -0.4))
    crumple(tk, 0.05, seed=58)
    gp = rename(by_name("F4_GunPod_M61"), "wreck_soft_gunpod")
    rigid(gp, rot_deg=(8.0, 0, -21.0), translate=(-1.9, -1.4, -0.7))
    cp = rename(by_name("F4_Canopy"), "wreck_soft_canopy")
    rigid(cp, rot_deg=(44.0, 0, 31.0), translate=(3.7, -2.2, -1.3))
    for nm in ("F4_Pylon_Center", "F4_Pylon_L", "F4_Pylon_R"):
        o = by_name(nm)
        if o:
            rename(o, "wreck_soft_" + nm.lower()[3:])

    # ---- 4. ground and plough
    thrown = {"wreck_hard_nose", "wreck_soft_wing_thrown", "wreck_soft_tank_thrown",
              "wreck_soft_gunpod", "wreck_soft_canopy"}
    sink([o for o in meshes() if o.name not in thrown], -0.26)

    mound = build_mound("wreck_hard_mound", half_x=5.6, half_y=9.0,
                        nose_y=3.0, tail_y=-8.4, berm_h=1.05, furrow_d=0.52,
                        hull_hw=1.10, seed=7)
    for nm in sorted(thrown):
        o = by_name(nm)
        if o:
            W.seat_on_mound(o, mound, bury=0.12)

    fire = [(0.0, -4.6, 0.6), (0.0, 1.4, 0.7), (-2.6, -3.4, 0.1)]
    n, tot = scorch([o for o in meshes() if o.name.startswith("wreck_")
                     and "mound" not in o.name and "canopy" not in o.name],
                    fire, 4.2, seed=13, core=0.42)
    print("  scorched %d / %d faces (%.0f%%)" % (n, tot, 100.0 * n / max(1, tot)))

    anchor = pick_pilot_anchor([fus], fire, mound)
    print("  pilot_anchor %s : %.2f m off the hull, %.2f m from nearest fire, "
          "ground z %.2f" % ([round(x, 2) for x in anchor[:2]], anchor[4],
                             anchor[3], anchor[2]))

    finish("f4", "f4_phantom_crashed.glb",
           trimesh_prefixes=("wreck_hard_mound", "wreck_soft_wing", "wreck_soft_stab",
                             "wreck_soft_tailfin", "wreck_soft_canopy",
                             "wreck_soft_intake"),
           sockets=[("fire_socket_1", fire[0]), ("fire_socket_2", fire[1]),
                    ("fire_socket_3", fire[2])],
           anchor=anchor, mound=mound, render=render)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
    which = argv[0] if argv else "all"
    rend = "--norender" not in argv
    os.makedirs(OUT, exist_ok=True)
    if which in ("a1", "all"):
        build_a1(rend)
    if which in ("huey", "all"):
        build_huey(rend)
    if which in ("f4", "all"):
        build_f4(rend)
    print("\nALL DONE")
