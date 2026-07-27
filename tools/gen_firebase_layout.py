"""Assemble a whole 1969 fire support base from the kit, revetted with fb_kit sandbag walls.

Concentric, per the reference brief: wire -> berm and bunker line -> trench -> living and
supply -> gun battery -> FDC at the centre. Nothing is symmetrical; engineers built to the
terrain, so every ring is jittered off its ideal bearing.

Pieces are LINKED duplicates of one master mesh per family, so a base with ~90 placements
still carries 23 meshes.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fb_kit
import gen_firebase as gf

R_PERIM = 52.0
R_WIRE = 60.0
R_LIVING = 30.0
R_BATTERY = 16.0
GATE_BEARING = math.radians(200.0)
GATE_HALF = math.radians(9.0)

SEED = 4471


def place(master, pos, bearing, rng, jitter=0.0):
    """Linked duplicate facing outward along `bearing`. Local -Y is the piece's front."""
    ob = bpy.data.objects.new(master.name.split(".")[0] + "_i", master.data)
    ob.location = (pos[0] + rng.uniform(-jitter, jitter),
                   pos[1] + rng.uniform(-jitter, jitter), pos[2])
    ob.rotation_euler = (0.0, 0.0, bearing + math.pi / 2.0 + rng.uniform(-0.05, 0.05))
    bpy.context.collection.objects.link(ob)
    return ob


def polar(r, a, z=0.0):
    return (math.cos(a) * r, math.sin(a) * r, z)


def in_gate(a):
    d = (a - GATE_BEARING + math.pi) % math.tau - math.pi
    return abs(d) < GATE_HALF


def perimeter_revetment(rng):
    """One continuous sandbag parapet on the berm crest, broken at the gate."""
    bm = bmesh.new()
    seg = 96
    run, runs = [], []
    for i in range(seg + 1):
        a = math.tau * i / seg
        if in_gate(a):
            if len(run) > 1:
                runs.append(run)
            run = []
            continue
        rr = R_PERIM + rng.uniform(-0.5, 0.5)
        run.append((math.cos(a) * rr, math.sin(a) * rr))
    if len(run) > 1:
        runs.append(run)
    for r in runs:
        fb_kit.build_sandbag_wall(path=r, courses=9, base_z=1.15, side=1.0,
                                  seed=rng.randint(0, 1 << 20), into=bm)
    me = bpy.data.meshes.new("fb_perimeter_revetment")
    bm.to_mesh(me)
    bm.free()
    for m in gf.ensure_materials():
        me.materials.append(m)
    gf.box_project_uvs(me)
    ob = bpy.data.objects.new("fb_perimeter_revetment", me)
    bpy.context.collection.objects.link(ob)
    return ob


def wire_ring(rng):
    """The actual barbed wire. fam_wire_belt builds PICKETS ONLY - its docstring says the
    builder imports the wire, and nothing ever did, so the belt was bare posts.

    barbwire_card.glb is the only wire (war room 2026-07-17). Measured: one 2.73 x 0.93 m
    alpha card, 2 tris. Cards are merged into a single object whose name keeps the
    `bwire_card` prefix - tools/diag_fsb_seat.gd:100 keys on it and fails hard without it.
    """
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=gf.WIRE_GLB)
    new = [bpy.data.objects[n] for n in set(bpy.data.objects.keys()) - before]
    card = next((o for o in new if o.type == 'MESH' and o.name.startswith("bwire_card")
                 and "colonly" not in o.name), None)
    src = card.data.copy() if card else None
    mat = src.materials[0] if src is not None and src.materials else None
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    if src is None:
        print("   MISSING wire:", gf.WIRE_GLB)
        return None

    pitch = 2.70                                   # card is 2.73 wide; overlap beats a gap
    bm = bmesh.new()
    cards = 0
    for radius in (R_WIRE, R_WIRE - 2.6):
        cnt = int(round(math.tau * radius / pitch))
        for i in range(cnt):
            a = math.tau * i / cnt
            if in_gate(a):
                continue
            rr = radius + rng.uniform(-0.12, 0.12)
            m = (Matrix.Translation((math.cos(a) * rr, math.sin(a) * rr, 0.0))
                 @ Euler((rng.uniform(-0.05, 0.05), rng.uniform(-0.06, 0.06),
                          a + math.pi / 2.0)).to_matrix().to_4x4())
            tmp = src.copy()
            tmp.transform(m)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
            cards += 1
    me = bpy.data.meshes.new("bwire_card_ring")
    bm.to_mesh(me)
    bm.free()
    if mat is not None:
        me.materials.append(mat)
    ob = bpy.data.objects.new("bwire_card_ring", me)
    bpy.context.collection.objects.link(ob)
    bpy.data.meshes.remove(src)
    print(f"   wire cards: {cards} ({cards * 2} tris) in one mesh")
    return ob


def ground():
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, radius=R_WIRE + 14.0, segments=48)
    idx = gf.MAT_INDEX["fb_earth"]
    for f in bm.faces:
        f.material_index = idx
    me = bpy.data.meshes.new("fb_ground")
    bm.to_mesh(me)
    bm.free()
    for m in gf.ensure_materials():
        me.materials.append(m)
    gf.box_project_uvs(me)
    ob = bpy.data.objects.new("fb_ground", me)
    ob.location.z = -0.02
    bpy.context.collection.objects.link(ob)
    return ob


def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    rng = random.Random(SEED)

    masters = {}
    for i, name in enumerate(sorted(gf.FAMILIES)):
        ob, _, dims = gf.build_piece(name, 9100 + i * 53)
        ob.location = (0.0, 0.0, -500.0)          # parked off-stage; only its mesh is used
        masters[name] = ob
    print("masters built:", len(masters))

    ground()
    perimeter_revetment(rng)
    wire_ring(rng)

    n = 0
    # Berm ring under the parapet. The count is circumference/piece-length, not a round
    # number - short it and the revetment spans open air between arcs.
    n_berm = int(math.ceil(math.tau * R_PERIM / (masters["fb_berm_arc"].dimensions.x * 0.92)))
    for i in range(n_berm):
        a = math.tau * i / n_berm
        if in_gate(a):
            continue
        place(masters["fb_berm_arc"], polar(R_PERIM, a), a, rng, 0.4); n += 1

    # bunker line, cut into the berm every ~30 m
    bunkers = ["fb_bunker_mg", "fb_bunker_fighting", "fb_bunker_fighting", "fb_sleeping_bunker"]
    for i in range(11):
        a = math.tau * i / 11 + rng.uniform(-0.05, 0.05)
        if in_gate(a):
            continue
        place(masters[bunkers[i % len(bunkers)]], polar(R_PERIM - 3.5, a), a, rng, 0.8); n += 1

    # trench segments linking parts of the line
    for i in range(7):
        a = math.tau * i / 7 + 0.28
        if in_gate(a):
            continue
        place(masters["fb_trench_run"], polar(R_PERIM - 7.5, a), a, rng, 0.6); n += 1

    # wire belt outside the berm - same rule, an unbroken band or it is not an obstacle
    n_wire = int(math.ceil(math.tau * R_WIRE / (masters["fb_wire_belt"].dimensions.x * 0.94)))
    for i in range(n_wire):
        a = math.tau * i / n_wire
        if in_gate(a):
            continue
        place(masters["fb_wire_belt"], polar(R_WIRE, a), a, rng, 0.5); n += 1
    for i in range(14):
        a = math.tau * i / 14 + 0.11
        if in_gate(a):
            continue
        place(masters["fb_claymore"], polar(R_WIRE - 3.0, a), a, rng, 1.2); n += 1

    # gate
    place(masters["fb_gate_gap"], polar(R_PERIM - 1.0, GATE_BEARING), GATE_BEARING, rng); n += 1

    # six-gun 105 battery, arced round the FDC, plus a mortar section
    for i in range(6):
        a = math.tau * i / 6 + 0.4
        place(masters["fb_gun_pit"], polar(R_BATTERY, a), a, rng, 0.7); n += 1
        place(masters["fb_howitzer"], polar(R_BATTERY, a), a, rng, 0.5); n += 1
    for i in range(2):
        a = math.tau * (i + 0.5) / 2 + 1.1
        place(masters["fb_mortar_pit"], polar(R_BATTERY - 7.0, a), a, rng, 0.5); n += 1

    # FDC / TOC at the centre
    place(masters["fb_toc"], (0.0, 0.0, 0.0), rng.uniform(0, math.tau), rng); n += 1

    # living and supply ring
    camp = ["fb_hootch", "fb_hootch", "fb_gp_tent", "fb_hootch", "fb_mess", "fb_hootch",
            "fb_supply_dump", "fb_aid_station", "fb_hootch", "fb_gp_tent", "fb_hootch",
            "fb_supply_dump"]
    for i, fam in enumerate(camp):
        a = math.tau * i / len(camp) + 0.17
        place(masters[fam], polar(R_LIVING, a), a + math.pi, rng, 1.4); n += 1
    for i, fam in enumerate(["fb_latrine", "fb_water_point", "fb_burn_barrel",
                             "fb_latrine", "fb_burn_barrel", "fb_sandbag_stack",
                             "fb_sandbag_stack", "fb_water_point"]):
        a = math.tau * i / 8 + 0.9
        place(masters[fam], polar(R_LIVING + 8.0, a), a, rng, 2.0); n += 1

    # towers on the two flanks of the gate, and one opposite
    for a in (GATE_BEARING - 0.42, GATE_BEARING + 0.42, GATE_BEARING + math.pi):
        place(masters["fb_tower"], polar(R_PERIM - 5.0, a), a, rng); n += 1

    # pad, scoured clear, outside the living ring
    place(masters["fb_helipad"], polar(R_PERIM - 16.0, GATE_BEARING + 2.6),
          GATE_BEARING + 2.6, rng); n += 1

    for m in masters.values():
        bpy.data.objects.remove(m, do_unlink=True)

    tris = 0
    seen = set()
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
            seen.add(o.data.name)
    print(f"placements: {n}  objects: {len(bpy.context.scene.objects)}  "
          f"unique meshes: {len(seen)}  frame tris: {tris}")

    out = os.path.join(gf.KIT_DIR, "firebase_v2_layout.blend")
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print("saved", out, round(os.path.getsize(out) / 1048576.0, 2), "MB")


if __name__ == "__main__":
    main()
