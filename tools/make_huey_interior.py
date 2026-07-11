"""Huey seat sockets + minimal PSX cabin interior (research batch section 7,
CALEB_TODO section 2 - the export that retires SeatSystem's fallback table).

What it does, headless:
  1. imports assets/building models/vehicles/huey.glb into a fresh scene
  2. probes the actual mesh: Huey_Copy fuselage AABB, Door_Left/Door_Right
     openings, cockpit windshield (nose direction), cabin floor height,
     hollow-shell raycast
  3. adds TEN empties named exactly per the SeatSystem contract:
       seat_pilot_l seat_pilot_r seat_gunner_l seat_gunner_r seat_pax_1..6
     positioned by fitting seat_system.gd's FALLBACK_LAYOUT (authored in
     recentered heli space) onto the measured mesh, anchored on the real
     door opening + fuselage midline.
  4. builds a minimal interior: transmission-hump bench (pax sit on it),
     two pilot seat boxes, cabin+cockpit floor quads (only if the shell is
     hollow) - flat-colour PSX materials derived from the existing
     ArmyGreen, everything well under 300 tris.
  5. exports back over huey.glb (GLB, Y-up, animations preserved) and
     verifies the result by parsing the GLB JSON chunk.

ORIENTATION CONTRACT: a Godot occupant faces the socket's LOCAL +Z.
glTF axis math: Godot local +Z == Blender local -Y, so an empty with
rotation_euler.z = heli_yaw + 180 deg faces the occupant the right way
(pilots at the nose = Blender -Y, gunners/pax out the doors = Blender +/-X).

FRAME MATH (probe-verified 2026-07-11):
  huey.tscn rotates Model 180 deg about Y; helicopter.gd recenters the
  fuselage AABB on the node origin. In that frame the fallback table maps to
  Blender import coordinates as:
     bl_x = fuselage_mid_x - heli_x
     bl_y = door_centre_y + (heli_z + 2.65)   (fallback door centre = -2.65)
     bl_z = heli_y
  Measured anchors on this GLB: mid_x=-7.737, door_centre_y=1.27, floor=1.27.

Run:
  & "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup --python tools/make_huey_interior.py

Idempotent: re-running deletes any previously generated seat_*/huey_int_*
objects before rebuilding. Never touches any .blend.
"""
import json
import math
import struct

import bpy
from mathutils import Vector

GLB = r"C:\Users\caleb\RECONgame\assets\building models\vehicles\huey.glb"

# SeatSystem FALLBACK_LAYOUT verbatim (heli space: [x, y, z, yaw_deg]).
# The sockets exported here land at EXACTLY these coordinates in the
# recentered runtime frame, so gameplay (door_staging_pos etc.) is unchanged.
SEATS = {
    "seat_pilot_l":  ( 0.55, 1.35, -5.35, 180.0),
    "seat_pilot_r":  (-0.55, 1.35, -5.35, 180.0),
    "seat_gunner_l": ( 1.15, 1.30, -2.70,  90.0),
    "seat_gunner_r": (-1.15, 1.30, -2.70, -90.0),
    "seat_pax_1":    ( 0.40, 1.30, -3.40,  90.0),
    "seat_pax_2":    ( 0.40, 1.30, -2.70,  90.0),
    "seat_pax_3":    ( 0.40, 1.30, -2.00,  90.0),
    "seat_pax_4":    (-0.40, 1.30, -3.40, -90.0),
    "seat_pax_5":    (-0.40, 1.30, -2.70, -90.0),
    "seat_pax_6":    (-0.40, 1.30, -2.00, -90.0),
}
DOOR_CENTRE_HELI_Z = -2.65   # fallback doors span heli z -3.4..-1.9
SEAT_HEIGHT = 0.45           # bench/seat-pan top above cabin floor
TRI_BUDGET = 300

GENERATED_PREFIX = "huey_int_"


# ------------------------------------------------------------------ helpers
def glb_stats(path):
    """Parse the GLB JSON chunk - node names / animation / material counts."""
    with open(path, "rb") as f:
        magic, _ver, _length = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            raise RuntimeError("%s is not a GLB" % path)
        clen, _ctype = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(clen))
    return {
        "nodes": [n.get("name", "?") for n in gltf.get("nodes", [])],
        "animations": len(gltf.get("animations", [])),
        "materials": [m.get("name", "?") for m in gltf.get("materials", [])],
        "meshes": len(gltf.get("meshes", [])),
    }


def world_aabb(ob):
    corners = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return mn, mx


def flat_material(name, rgb):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None:
            out = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def add_box(name, mn, mx, mat):
    """Axis-aligned flat-shaded box, 12 tris."""
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def add_quad(name, x0, x1, y0, y1, z, mat):
    """Upward-facing floor quad, 2 tris."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)],
                   [], [(0, 1, 2, 3)])
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ------------------------------------------------------------------ pipeline
def main():
    before = glb_stats(GLB)
    print("[huey_interior] BEFORE: %d nodes, %d anims, mats=%s" % (
        len(before["nodes"]), before["animations"], before["materials"]))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)

    # idempotency: strip anything a previous run generated
    for ob in list(bpy.data.objects):
        if ob.name.startswith("seat_") or ob.name.startswith(GENERATED_PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)

    # ---- probe the mesh ---------------------------------------------------
    fus = bpy.data.objects.get("Huey_Copy")
    door_l = bpy.data.objects.get("Door_Left")
    door_r = bpy.data.objects.get("Door_Right")
    shield = bpy.data.objects.get("Cockpit_Windshield")
    if fus is None or door_l is None or door_r is None or shield is None:
        raise RuntimeError("huey.glb structure changed - expected Huey_Copy, "
                           "Door_Left, Door_Right, Cockpit_Windshield")

    fmn, fmx = world_aabb(fus)
    dmn, dmx = world_aabb(door_l)
    smn, smx = world_aabb(shield)
    mid_x = (fmn.x + fmx.x) / 2.0
    door_cy = (dmn.y + dmx.y) / 2.0
    floor_z = dmn.z
    print("[huey_interior] PROBE fuselage aabb min=(%.2f,%.2f,%.2f) max=(%.2f,%.2f,%.2f)" %
          (fmn.x, fmn.y, fmn.z, fmx.x, fmx.y, fmx.z))
    print("[huey_interior] PROBE mid_x=%.3f door_centre_y=%.3f floor_z=%.3f "
          "door_z_span=%.2f..%.2f door_y_span=%.2f..%.2f" %
          (mid_x, door_cy, floor_z, dmn.z, dmx.z, dmn.y, dmx.y))

    # sanity: nose must be the -Y end (windshield ahead of the doors)
    if (smn.y + smx.y) / 2.0 >= door_cy:
        raise RuntimeError("orientation check failed: windshield is not -Y of the doors")
    # sanity: Door_Left on the -X side (== heli +X after the 180-degree flip)
    if (dmn.x + dmx.x) / 2.0 >= mid_x:
        raise RuntimeError("orientation check failed: Door_Left is not on -X")
    if abs(floor_z - 1.30) > 0.25:
        raise RuntimeError("cabin floor probe %.2f is far from the expected ~1.30" % floor_z)

    def to_bl(hx, hy, hz):
        return Vector((mid_x - hx, door_cy + (hz - DOOR_CENTRE_HELI_Z), hy))

    # hollow-shell check: ray straight down through the cabin interior
    inv = fus.matrix_world.inverted()
    ro = inv @ Vector((mid_x, door_cy, floor_z + 0.6))
    rd = (inv.to_3x3() @ Vector((0.0, 0.0, -1.0))).normalized()
    hit, loc, _n, _i = fus.ray_cast(ro, rd)
    hit_z = (fus.matrix_world @ loc).z if hit else None
    hollow = hit_z is None or hit_z < floor_z - 0.15
    print("[huey_interior] PROBE floor raycast: hit_z=%s -> hollow=%s" %
          ("%.2f" % hit_z if hit_z is not None else "none", hollow))

    # ---- 10 seat socket empties --------------------------------------------
    print("[huey_interior] SOCKETS (name | heli-space | blender | yaw_heli):")
    for name, (hx, hy, hz, yaw) in SEATS.items():
        pos = to_bl(hx, hy, hz)
        emp = bpy.data.objects.new(name, None)
        emp.empty_display_type = "PLAIN_AXES"
        emp.empty_display_size = 0.3
        emp.location = pos
        emp.rotation_euler = (0.0, 0.0, math.radians(yaw + 180.0))
        bpy.context.scene.collection.objects.link(emp)
        print("  %-14s heli=(%5.2f, %.2f, %5.2f)  bl=(%6.3f, %6.3f, %.3f)  yaw=%.0f" %
              (name, hx, hy, hz, pos.x, pos.y, pos.z, yaw))
        if not (fmn.x - 0.05 <= pos.x <= fmx.x + 0.05 and fmn.y <= pos.y <= fmx.y):
            raise RuntimeError("%s landed outside the fuselage footprint" % name)

    # ---- minimal PSX interior ----------------------------------------------
    # colours riffed off the existing ArmyGreen (0.15, 0.2, 0.1)
    army = bpy.data.materials.get("ArmyGreen")
    base = (0.15, 0.2, 0.1)
    if army is not None and army.node_tree is not None:
        bsdf = next((n for n in army.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            base = tuple(bsdf.inputs["Base Color"].default_value[:3])
    mat_floor = flat_material("HueyInteriorOlive", (base[0] * 0.55, base[1] * 0.55, base[2] * 0.55))
    mat_seat = flat_material("HueyInteriorCanvas", (base[0] * 0.85, base[1] * 0.72, base[2] * 0.95))

    made = []

    # transmission-hump bench: pax rows sit on it, backs together, facing out
    b0 = to_bl(0.55, 0.0, -3.68)   # +heli_x edge, forward end
    b1 = to_bl(-0.55, 0.0, -1.72)  # -heli_x edge, aft end
    made.append(add_box(GENERATED_PREFIX + "bench",
                        (min(b0.x, b1.x), min(b0.y, b1.y), floor_z),
                        (max(b0.x, b1.x), max(b0.y, b1.y), floor_z + SEAT_HEIGHT),
                        mat_seat))

    # two pilot seats: pan + backrest (pilots face the nose = -Y)
    for side, name in ((0.55, "seat_box_l"), (-0.55, "seat_box_r")):
        c = to_bl(side, 0.0, -5.35)
        made.append(add_box(GENERATED_PREFIX + name + "_pan",
                            (c.x - 0.28, c.y - 0.28, floor_z),
                            (c.x + 0.28, c.y + 0.28, floor_z + SEAT_HEIGHT),
                            mat_seat))
        made.append(add_box(GENERATED_PREFIX + name + "_back",
                            (c.x - 0.28, c.y + 0.18, floor_z + SEAT_HEIGHT),
                            (c.x + 0.28, c.y + 0.30, floor_z + 1.15),
                            mat_seat))

    if hollow:
        # cabin floor: full door span plus a lip, wall to wall
        f0 = to_bl(1.45, 0.0, -3.85)
        f1 = to_bl(-1.45, 0.0, -1.45)
        made.append(add_quad(GENERATED_PREFIX + "floor_cabin",
                             min(f0.x, f1.x), max(f0.x, f1.x),
                             min(f0.y, f1.y), max(f0.y, f1.y),
                             floor_z + 0.005, mat_floor))
        # cockpit floor: narrower (hull tapers toward the nose)
        c0 = to_bl(1.05, 0.0, -6.15)
        c1 = to_bl(-1.05, 0.0, -3.85)
        made.append(add_quad(GENERATED_PREFIX + "floor_cockpit",
                             min(c0.x, c1.x), max(c0.x, c1.x),
                             min(c0.y, c1.y), max(c0.y, c1.y),
                             floor_z + 0.005, mat_floor))

    tris = sum(tri_count(ob) for ob in made)
    print("[huey_interior] INTERIOR: %d objects, %d tris (budget %d)" %
          (len(made), tris, TRI_BUDGET))
    if tris > TRI_BUDGET:
        raise RuntimeError("interior blew the %d-tri budget: %d" % (TRI_BUDGET, tris))

    # ---- export -------------------------------------------------------------
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB")

    after = glb_stats(GLB)
    print("[huey_interior] AFTER: %d nodes, %d anims, mats=%s" % (
        len(after["nodes"]), after["animations"], after["materials"]))
    missing = [n for n in list(SEATS) + ["Huey_Copy", "Door_Left", "New_Blade_1",
                                         "New_TailBlade_2.002", "New_Skid_L"]
               if n not in after["nodes"]]
    if missing:
        raise RuntimeError("exported GLB lost nodes: %s" % missing)
    if after["animations"] != before["animations"]:
        print("[huey_interior] WARNING: animation count changed %d -> %d "
              "(runtime disables the AnimationPlayer, but report it)" %
              (before["animations"], after["animations"]))
    lost_mats = [m for m in before["materials"] if m not in after["materials"]]
    if lost_mats:
        raise RuntimeError("exported GLB lost materials: %s" % lost_mats)
    print("[huey_interior] DONE - %s rewritten, sockets + interior in place" % GLB)


main()
