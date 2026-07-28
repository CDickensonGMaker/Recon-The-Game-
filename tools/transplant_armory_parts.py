"""Replace fused single-mesh gun copies in fp_arms_rifle.blend with the finished
armory assemblies (split moving parts, correct origins) so every gun can carry
rails and contact markers. Marker/rail contract: war_room/2026-07-27_viewmodel_pipeline_v2.

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/transplant_armory_parts.py -- [gun ...]

Per gun: the 2026-07-19 join baked armory-world coords into the fused copy's
mesh-local verts, so the copy's object matrix IS the armory->arms mapping.
Verified per gun against the fused mesh's own bounding box (>60mm center drift
aborts that gun). Cache every empty riding the fused mesh, delete it, append
the armory assembly by prefix, place with the same matrix, hang everything on
the rig's root empty, dedupe .0xx material copies, clamp known rails.
Saves ONLY if at least one gun lands clean.
"""
import bpy, sys, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
US = os.path.join(ROOT, "assets", "us", "characters", "weapons_us.blend")
VC = os.path.join(ROOT, "assets", "nva_vc", "weapons_vc.blend")

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []

# key -> (armory, fused arms mesh, armory name prefixes, marker suffix,
#         {sight marker -> tracking part}, [(part, axis, min, max) rails])
GUNS = {
    "m70": (US, "M70sniper_gun", ("M70sniper", "M70_"), "M70sniper", {}, []),
    "colt45": (US, "Colt45_Pistol_gun", ("Colt45",), "Colt45_Pistol",
               {"sight_front_Colt45_Pistol": "Colt45_slide",
                "sight_rear_Colt45_Pistol": "Colt45_slide"}, []),
    "ithaca": (US, "Ithaca37_Shotgun_gun", ("Ithaca37",), "Ithaca37_Shotgun",
               {}, [("Ithaca37_pump", "x", 0.0, 0.045)]),
    "m60": (US, "M60_MG_gun", ("M60_",), "M60_MG", {}, []),
    "thompson": (US, "Thompson_Submachine_Gun_gun", ("Thompson",),
                 "Thompson_Submachine_Gun", {}, []),
    "m72_law": (US, "M72_LAW_gun", ("M72_LAW",), "M72_LAW", {},
                [("M72_LAW_inner_tube", "x", 0.0, 0.230)]),
    "m79": (US, "M79_Launcher_gun", ("M79_",), "M79_Launcher", {}, []),
    "mosin": (VC, "Mosin_gun", ("Mosin_", "mosin_stock"), "Mosin", {}, []),
    "rpd": (VC, "RPD_gun", ("RPD_", "rpd_stock"), "RPD", {}, []),
    "rpg2": (VC, "RPG2_gun", ("RPG2_",), "RPG2", {}, []),
    "rpg7": (VC, "RPG7_gun", ("RPG7_",), "RPG7", {}, []),
}

todo = {k: v for k, v in GUNS.items() if not argv or k in argv}
O = bpy.data.objects
SKIP_PREFIX = ("grip_", "muzzle_", "sight_")

# rigs whose arms-file markers are stranded at armory coordinates (no valid
# anchor): place by center translation, then RE-SEAT their contract markers
# from the armory's own marker empties - the armory is the truth for these
RESEAT = {"m72_law", "m79"}


def world_bbox_center(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return sum(pts, Vector()) / 8.0


def frame_of(p0, p1, p2):
    """Orthonormal frame from a marker triangle (origin at p0). Falls back to
    world-up when the three markers are collinear (LAW: all on the bore plane) -
    both armories rack guns level, so world-up maps roll consistently."""
    from mathutils import Matrix
    x = (p1 - p0).normalized()
    z = x.cross(p2 - p0)
    if z.length < 1e-8:
        z = x.cross(Vector((0, 0, 1)))
        if z.length < 1e-8:
            z = Vector((0, 0, 1))
    z.normalize()
    y = z.cross(x)
    m = Matrix.Identity(4)
    for i, ax in enumerate((x, y, z)):
        for r in range(3):
            m[r][i] = ax[r]
    m.translation = p0
    return m


transplanted, skipped = [], []
for key, (path, fused_n, prefixes, suffix, sight_parents, rails) in todo.items():
    fused = O.get(fused_n)
    if fused is None:
        skipped.append((key, f"fused mesh {fused_n} missing"))
        continue
    rig_coll = fused.users_collection[0]
    fused_center = world_bbox_center(fused)

    trio_names = [f"sight_front_{suffix}", f"sight_rear_{suffix}", f"muzzle_{suffix}"]
    grip_names = ([f"grip_LeftHand_{suffix}", f"grip_RightHand_{suffix}"]
                  if key in RESEAT else [])
    mats_before = {m.name for m in bpy.data.materials}
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects
                       if (any(n == p or n.startswith(p) for p in prefixes)
                           and not n.startswith(SKIP_PREFIX))
                       or n in trio_names or n in grip_names]
    loaded = [o for o in dst.objects if o is not None]
    # LAW (recon-us-armory-rig): an appended-but-unlinked object reads
    # matrix_world as zeros - link everything BEFORE measuring anything
    for o in loaded:
        rig_coll.objects.link(o)
    bpy.context.view_layer.update()
    arm_trio, arm_markers = {}, {}
    body = []
    for o in loaded:
        base = o.name.rsplit(".", 1)[0] if "." in o.name else o.name
        if base in trio_names and o.type == 'EMPTY':
            arm_trio[base] = o
            arm_markers[base] = o
        elif base in grip_names and o.type == 'EMPTY':
            arm_markers[base] = o
        else:
            body.append(o)
    marker_worlds = {n: e.matrix_world.copy() for n, e in arm_markers.items()}
    if not body:
        for o in loaded:
            bpy.data.objects.remove(o)
        skipped.append((key, "no armory objects matched"))
        continue
    body_set = set(body)
    roots = [o for o in body if o.parent is None or o.parent not in body_set]
    meshes = [o for o in body if o.type == 'MESH']

    def drift_under(M):
        centers = [M @ world_bbox_center(o) for o in meshes]
        return ((sum(centers, Vector()) / len(centers)) - fused_center).length

    # mapping candidate 1: the fused copy's own matrix (valid when the 2026-07-19
    # join baked armory-world coords into its mesh-local verts)
    T = fused.matrix_world.copy()
    drift = drift_under(T)
    how = "fused-matrix"
    if drift > 0.060:
        # candidate 2: put the armory gun's sight line ON the arms rig's sight
        # line (re-racked/remade armories - the old copy is only staging, these
        # rigs carry no animations). Congruence is NOT required: the gun was
        # remade since the copy, only the sight-line frame is trusted.
        arms_trio = [O.get(n) for n in trio_names]
        if len(arm_trio) == 3 and all(arms_trio):
            a = [arm_trio[n].matrix_world.translation.copy() for n in trio_names]
            b = [t.matrix_world.translation.copy() for t in arms_trio]
            print(f"  [{key}] armory trio:", [tuple(round(v, 3) for v in p) for p in a])
            print(f"  [{key}] arms trio:  ", [tuple(round(v, 3) for v in p) for p in b])
            try:
                T = frame_of(*b) @ frame_of(*a).inverted()
            except ValueError:
                for o in loaded:
                    bpy.data.objects.remove(o)
                skipped.append((key, "degenerate marker trio - cannot solve"))
                continue
            axis = (b[0] - b[1]).normalized()      # arms sight line
            centers = [T @ world_bbox_center(o) for o in meshes]
            off = (sum(centers, Vector()) / len(centers)) - fused_center
            perp = (off - off.dot(axis) * axis).length
            if perp <= 0.110:
                drift, how = perp, "sight-trio(perp)"
            else:
                drift, how = perp, "sight-trio-FAIL"
        if how in ("fused-matrix", "sight-trio-FAIL") and key in RESEAT:
            # both armories and all staging rows rack guns level, muzzle -X:
            # identity rotation + center translation is the honest remainder
            centers = [world_bbox_center(o) for o in meshes]
            armory_center = sum(centers, Vector()) / len(centers)
            from mathutils import Matrix as _M
            T = _M.Translation(fused_center - armory_center)
            drift, how = 0.0, "center-translate+reseat"
        if how in ("fused-matrix", "sight-trio-FAIL"):
            for o in loaded:
                bpy.data.objects.remove(o)
            skipped.append((key, f"drift {drift*1000:.0f}mm ({how}) - no valid mapping"))
            continue
    for o in arm_markers.values():
        bpy.data.objects.remove(o)

    # root empty: reuse the rig's existing one, else create
    root_e = O.get(suffix)
    if root_e is None or root_e.type != 'EMPTY':
        root_e = bpy.data.objects.new(f"{suffix}_root", None)
        rig_coll.objects.link(root_e)
        root_e.empty_display_type = 'PLAIN_AXES'
        root_e.empty_display_size = 0.05
        root_e.matrix_world = T.copy()

    # cache empties riding the fused mesh, then delete it
    riders = [e for e in O if e.parent is fused]
    cached = {e.name: e.matrix_world.copy() for e in riders}
    for e in riders:
        e.parent = None
        e.matrix_world = cached[e.name]
    bpy.data.objects.remove(fused)

    for o in roots:
        o.matrix_world = T @ o.matrix_world
    for o in roots:
        keep = o.matrix_world.copy()
        o.parent = root_e
        o.matrix_world = keep

    for name, mw in cached.items():
        e = O[name]
        target = O.get(sight_parents.get(name, "")) or root_e
        e.parent = target
        e.matrix_parent_inverse.identity()
        e.matrix_world = mw

    if key in RESEAT:
        remap = {f"sight_front_{suffix}": f"sight_front_{suffix}",
                 f"sight_rear_{suffix}": f"sight_rear_{suffix}",
                 f"muzzle_{suffix}": f"muzzle_{suffix}",
                 f"grip_L_{suffix}": f"grip_LeftHand_{suffix}",
                 f"grip_R_{suffix}": f"grip_RightHand_{suffix}"}
        for arms_n, armory_n in remap.items():
            e, mw = O.get(arms_n), marker_worlds.get(armory_n)
            if e is None or mw is None:
                continue
            e.parent = root_e
            e.matrix_parent_inverse.identity()
            e.matrix_world = T @ mw

    # the append brings Foo.001 copies of materials the arms file already has
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if m and "." in m.name and m.name not in mats_before:
                base = bpy.data.materials.get(m.name.rsplit(".", 1)[0])
                if base:
                    slot.material = base
    for m in [m for m in bpy.data.materials
              if m.name not in mats_before and m.users == 0]:
        bpy.data.materials.remove(m)

    for part_n, axis, lo, hi in rails:
        p = O.get(part_n)
        if p is None:
            continue
        c = p.constraints.new('LIMIT_LOCATION')
        setattr(c, f"use_min_{axis}", True)
        setattr(c, f"use_max_{axis}", True)
        setattr(c, f"min_{axis}", lo)
        setattr(c, f"max_{axis}", hi)
        c.owner_space = 'LOCAL'

    transplanted.append((key, len(body),
                         f"{how}, drift {drift*1000:.1f}mm, {len(cached)} markers rehomed"))

print("\n=== TRANSPLANT REPORT ===")
for k, n, note in transplanted:
    print(f"  OK   {k}: {n} objects, {note}")
for k, why in skipped:
    print(f"  SKIP {k}: {why}")

if transplanted:
    bpy.ops.wm.save_mainfile()
    print("SAVED", bpy.data.filepath)
else:
    print("nothing transplanted - NOT saved")
