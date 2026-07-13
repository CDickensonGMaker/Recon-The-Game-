"""Append an armory gun into a character export copy and attach it to the
right hand exactly like the character's native gun (gun variants, 2026-07-11).

Placement law (derived by headless inspection of the 4 shipped VC guns + the
US M16 against the armory blends): every shipped gun is its armory mesh
PURE-TRANSLATED into the native gun's local frame (bbox size deltas 0.000 on
all five). The shipped guns share NO trigger anchor (they scatter +/-30 cm -
each was eyeballed), so new guns use the strongest convention available:
the new gun's TRIGGER lands exactly where the character's NATIVE gun's
trigger sits -> the hand grips every variant like the base weapon.

Derived constants (see inspection numbers in the session report):
  * us m16_world local frame = armory M16A1 world - (0.5387, 0.5008, 0.2988)
    M16 trigger in m16-local: (0.136, 0.0, -0.064)  [wrist 13 cm behind - the
    same anatomy as the shipped Mosin]
  * vc ak47_world local frame = armory AK47_stock world - (0.3049, 0.0005, 0.2817)
    AK trigger in ak-local:   (0.245, 0.0, -0.072)  [WoodT56 grip cluster]
Armory trigger coordinates below were read from per-material vertex clusters
(M79/RPG2 ship literal trigger parts; M60/M14/M16A1 from grip/guard clusters).

Armory meshes keep the rack orientation (muzzle = -X) after the translation,
so exporters must place MuzzlePoint at the -X end for appended guns (the
hand-distance heuristic flips on the RPG-2, where the grip is near the front).

Never saves any .blend - bpy.data.libraries.load appends copies into the
in-memory export scene only.
"""
import bpy
import bmesh
from mathutils import Matrix, Vector

W1 = r"C:\Users\caleb\RECONgame\assets\us\characters\weapons_v1.blend"
WUS = r"C:\Users\caleb\RECONgame\assets\us\characters\weapons_us.blend"

# key -> armory blend, object selection, trigger position in armory world
GUNS = {
    "m60":   dict(blend=WUS, objects=["M60_MG"],       trigger=(0.565, 1.9699, 0.165)),
    "m79":   dict(blend=WUS, objects=["M79_Launcher"], trigger=(-0.045, 2.5, 0.078)),
    "m14":   dict(blend=WUS, objects=["M14"],          trigger=(0.815, 0.0, 0.222)),
    "m16a1": dict(blend=WUS, objects=["M16A1"],        trigger=(0.675, 0.5, 0.235)),
    "rpg2":  dict(blend=W1,  prefix="RPG2_",           trigger=(0.155, 2.0, 0.235)),
}

# native-gun-local point where a new gun's trigger must land, per character
ANCHOR = {
    "m16_world":  Vector((0.136, 0.0, -0.064)),
    "ak47_world": Vector((0.245, 0.0, -0.072)),
}


def bring(key, ref_gun, rig):
    """Append armory gun `key`, bake it (modifiers + armory transforms) into a
    single mesh in the reference gun's local frame, and bone-attach it with
    the reference gun's exact matrices. Returns the new object."""
    spec = GUNS[key]
    ref = bpy.data.objects[ref_gun]
    anchor = ANCHOR[ref_gun]
    with bpy.data.libraries.load(spec["blend"]) as (df, dt):
        if "objects" in spec:
            names = [n for n in spec["objects"] if n in df.objects]
        else:
            names = [n for n in df.objects if n.startswith(spec["prefix"])]
        dt.objects = names
    parts = [o for o in dt.objects if o is not None]
    if not parts:
        raise RuntimeError(f"armory gun '{key}': no objects found in {spec['blend']}")
    sc = bpy.context.scene
    for o in parts:
        sc.collection.objects.link(o)
    bpy.context.view_layer.update()  # matrix_world is stale until the depsgraph runs

    # armory world -> ref-gun local: pure translation putting trigger on anchor
    t = Matrix.Translation(anchor - Vector(spec["trigger"]))
    dg = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    mats = []
    for o in parts:
        ev = o.evaluated_get(dg)
        tme = bpy.data.meshes.new_from_object(ev)  # bakes bevel modifiers
        tme.transform(t @ o.matrix_world)
        remap = [0] * max(len(tme.materials), 1)
        for i, m in enumerate(tme.materials):
            if m not in mats:
                mats.append(m)
            remap[i] = mats.index(m)
        for p in tme.polygons:
            p.material_index = remap[p.material_index]
        bm.from_mesh(tme)
        bpy.data.meshes.remove(tme)
    me = bpy.data.meshes.new(f"{key}_world")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)

    ob = bpy.data.objects.new(f"{key}_world", me)
    sc.collection.objects.link(ob)
    ob.parent = rig
    ob.parent_type = 'BONE'
    ob.parent_bone = ref.parent_bone
    ob.matrix_parent_inverse = ref.matrix_parent_inverse.copy()
    ob.matrix_basis = ref.matrix_basis.copy()

    for o in parts:  # drop the appended armory source copies
        ome = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if ome is not None and ome.users == 0:
            bpy.data.meshes.remove(ome)
    bpy.context.view_layer.update()
    tris = sum(max(0, len(p.vertices) - 2) for p in me.polygons)
    print(f"[GUN] {key}: {len(parts)} armory part(s) -> {ob.name} "
          f"({len(me.vertices)}v/{tris}tris, {len(mats)} mats) on {ref.parent_bone}", flush=True)
    return ob
