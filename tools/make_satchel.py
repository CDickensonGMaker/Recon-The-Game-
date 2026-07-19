"""THE M3 AID BAG - authored the way the M1956 harness was authored.

    blender -b -P tools/make_satchel.py

Caleb: "take that basic block satchel bag and make one using the fabric tool, just
like we did the webbing belt. It came out perfect first try yesterday."

So this does not invent anything. It follows `tools/fit_webbing.py`'s contract exactly,
because that contract is right and it is already proven on the harness:

  A STRAP lies ON him and must bend WITH him.
      -> live SHRINKWRAP onto the body (re-conforms to whatever soldier you point it
         at - a slimmer man gets a tighter sling for free), then SOLIDIFY for thickness.
      -> at fit time it takes its skin weights FROM THE BODY by Data Transfer.
      sat_sling IS A STRAP.

  A RIDER hangs off a STRAP, not off him.
      -> no shrinkwrap. It samples ITS HOST, over the patch it actually touches, and
         wears those weights RIGIDLY. "I want the attachments to ride on the webbing
         just like they would in the real world."
      -> sample the BODY instead and the classic bug appears: the sling slides one way,
         the bag slides another, and they shear apart mid-stride.
      sat_body RIDES sat_sling. The flap rides the bag. The buckles and the cross ride
      the flap.

WHY ITS OWN FILE AND NOT gear_armory.blend
Caleb had gear_armory.blend OPEN AND UNSAVED while this was written. Writing into it
headlessly would have been clobbered the moment he saved - or would have clobbered him.
So the bag lives in satchel_m3.blend, and fit_webbing.py loads BOTH lockers.

THE SHAPE. An M3 medical bag is a canvas box, ~30x20x12cm, worn slung: strap over the
RIGHT shoulder, bag on the LEFT hip, so it never fouls the rifle. The sling is a ribbon
that follows his chest - built as a path of quads and then shrunk onto him, which is
what makes it read as webbing rather than a plank.
"""
import bpy, os, sys, math
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from recon_paths import US_BASE_V3, US_PROPS_DIR

BASE = US_BASE_V3                                   # was art_source/base_psx/
OUT = os.path.join(US_PROPS_DIR, "satchel_m3.blend")  # was art_source/locker/

RIG = "PSXRig"
SLING_W = 0.052      # a 2-inch canvas sling
SLING_T = 0.010      # thickness after SOLIDIFY
BAG = (0.30, 0.12, 0.20)     # w, d, h - the real M3


def log(*a):
    print("[SATCHEL]", *a)


def body_and_rig():
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.data.objects
                if o.type == 'MESH' and 'joined' in o.name.lower())
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()
    return rig, body


def bone(rig, name):
    return rig.matrix_world @ rig.pose.bones["mixamorig:" + name].head


def ribbon(name, path, width):
    """A strip of quads following `path`. This is the sling BEFORE it is shrunk onto
    him - a flat ribbon in space. The Shrinkwrap is what turns it into webbing."""
    verts, faces = [], []
    for i, p in enumerate(path):
        # the ribbon's width runs across his body (X-ish), so it lies flat on his chest
        nxt = path[min(i + 1, len(path) - 1)]
        prv = path[max(i - 1, 0)]
        tan = (nxt - prv)
        tan.normalize()
        side = tan.cross(Vector((0, -1, 0)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        verts.append(p - side * (width * 0.5))
        verts.append(p + side * (width * 0.5))
        if i:
            k = (i - 1) * 2
            faces.append([k, k + 1, k + 3, k + 2])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def box(name, size, at, bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    o = bpy.context.active_object
    o.name = name
    o.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    b = o.modifiers.new("bevel", 'BEVEL')
    b.width = bevel
    b.segments = 1
    bpy.ops.object.modifier_apply(modifier="bevel")
    return o


def main():
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig, body = body_and_rig()
    log("base %s, rig %s" % (os.path.basename(BASE), rig.name))

    # scale: this base is not 1.7132m in-file; derive everything from the skeleton so
    # the bag is correct at ANY scale, forever.
    top = (rig.matrix_world @ rig.pose.bones["mixamorig:HeadTop_End"].tail).z
    S = top / 1.7132
    hip = bone(rig, "Hips")
    sp2 = bone(rig, "Spine2")
    rsh = bone(rig, "RightShoulder")
    log("skel scale %.2f  |  hips z=%.2f  R-shoulder (%.2f, %.2f, %.2f)"
        % (S, hip.z, rsh.x, rsh.y, rsh.z))

    # WHERE THE BAG HANGS: left hip, tucked against him, forward of the seam.
    bx = 0.155 * S            # his left flank (clamped anatomy - see fit_webbing)
    bz = hip.z + 0.02 * S
    by = -0.01 * S
    W, D, H = (v * S for v in BAG)

    # ---- THE SLING (a STRAP) --------------------------------------------------
    # Right shoulder -> across the chest -> left hip. A path, then a ribbon, then
    # SHRINKWRAP so it lies ON him instead of THROUGH him.
    p = [
        Vector((rsh.x * 0.75, rsh.y - 0.02 * S, rsh.z + 0.03 * S)),   # on the shoulder
        Vector((rsh.x * 0.55, -0.10 * S, sp2.z)),                     # over the collar
        Vector((rsh.x * 0.10, -0.13 * S, (sp2.z + bz) * 0.62)),       # across the chest
        Vector((bx * 0.75, -0.09 * S, bz + H * 0.72)),                # onto the ribs
        Vector((bx, by - D * 0.2, bz + H * 0.50)),                    # into the bag
    ]
    sling = ribbon("sat_sling", p, SLING_W * S)

    # *** THE SHRINKWRAP MUST NOT EAT THE WHOLE SLING. ***
    # First pass wrapped every vertex onto the body - which dragged the sling's lower
    # end onto his hip and left the BAG HANGING 287mm OUT IN SPACE, attached to nothing.
    # The fit gate caught it, and it was right: a rider must touch the thing it hangs
    # from.
    #
    # A real sling wraps over the SHOULDER and across the CHEST, and then LEAVES him to
    # carry the bag. So the wrap is masked by a vertex group: full weight on the
    # shoulder, feathering to zero by the time it reaches the bag. That is what a cloth
    # workflow actually does, and it is why the bag stays on the strap.
    vg = sling.vertex_groups.new(name="wrap")
    n_rings = len(p)
    for i in range(len(sling.data.vertices)):
        ring = i // 2                       # the ribbon is 2 verts per path point
        t = ring / max(1, n_rings - 1)      # 0 at the shoulder -> 1 at the bag
        w = 1.0 if t < 0.45 else max(0.0, 1.0 - (t - 0.45) / 0.35)
        vg.add([i], w, 'REPLACE')

    sw = sling.modifiers.new("shrinkwrap", 'SHRINKWRAP')
    sw.target = body
    sw.wrap_method = 'NEAREST_SURFACEPOINT'
    sw.wrap_mode = 'OUTSIDE_SURFACE'
    sw.vertex_group = "wrap"         # <- the mask. The tail stays out on the bag.
    sw.offset = 0.006 * S            # it sits ON the cloth, not in it
    sol = sling.modifiers.new("solidify", 'SOLIDIFY')
    sol.thickness = SLING_T * S
    sol.offset = 1.0
    log("sat_sling: %d verts, LIVE shrinkwrap -> %s (this is the fabric tool)"
        % (len(sling.data.vertices), body.name))

    # ---- THE BAG AND ITS FITTINGS (RIDERS) ------------------------------------
    parts = [sling]
    parts.append(box("sat_body", (W, D, H), (bx, by, bz), bevel=0.014 * S))
    parts.append(box("sat_flap", (W * 1.04, D * 1.06, H * 0.46),
                     (bx, by - D * 0.03, bz + H * 0.40), bevel=0.009 * S))
    for i, off in enumerate((-0.29, 0.29)):
        parts.append(box("sat_buckle_%s" % "ab"[i],
                         (W * 0.10, D * 0.18, H * 0.20),
                         (bx + W * off, by - D * 0.58, bz + H * 0.22),
                         bevel=0.003 * S))

    # THE RED CROSS - snapped to the flap's MEASURED surface, not to arithmetic.
    # I derived its position from the flap's nominal size and the fit gate caught it
    # 103mm out. Measure the thing you are sticking it to; do not compute where you
    # think it is. (This is the third time today that rule has earned its keep.)
    flap = parts[-3]                      # sat_flap
    bb = [flap.matrix_world @ Vector(c) for c in flap.bound_box]
    fx = (min(v.x for v in bb) + max(v.x for v in bb)) * 0.5
    fy = min(v.y for v in bb)             # the face pointing away from him
    fz = (min(v.z for v in bb) + max(v.z for v in bb)) * 0.5
    fw = max(v.x for v in bb) - min(v.x for v in bb)
    y = fy - 0.003 * S                    # a hair proud, so it never z-fights
    Lb, Tb = fw * 0.19, fw * 0.065
    vs, fs = [], []
    for (sx, sz) in ((Lb, Tb), (Tb, Lb)):
        k = len(vs)
        vs += [(fx - sx, y, fz - sz), (fx + sx, y, fz - sz),
               (fx + sx, y, fz + sz), (fx - sx, y, fz + sz)]
        fs.append([k, k + 1, k + 2, k + 3])
    me = bpy.data.meshes.new("sat_cross")
    me.from_pydata(vs, [], fs)
    me.update()
    cross = bpy.data.objects.new("sat_cross", me)
    bpy.context.scene.collection.objects.link(cross)
    parts.append(cross)
    log("cross snapped to the flap face at y=%.3f (flap width %.3f)" % (y, fw))

    # ---- materials: flat, PSX. NOT the grunt's Fatigue - its atlas is a reference
    # photo, and a fresh box's UVs land in the middle of it (I shipped that once).
    def flat(n, rgb):
        m = bpy.data.materials.new(n)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*rgb, 1.0)
        b.inputs["Roughness"].default_value = 0.93
        return m
    canvas = flat("AidBagCanvas", (0.215, 0.235, 0.170))
    strapm = flat("AidBagWebbing", (0.155, 0.170, 0.125))
    redx = flat("MedicCross", (0.66, 0.06, 0.05))
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(
            redx if o.name == "sat_cross"
            else (strapm if o.name in ("sat_sling", "sat_buckle_a", "sat_buckle_b")
                  else canvas))

    # ---- write the locker. The SHRINKWRAP STAYS LIVE - that is the whole point.
    for o in parts:
        o.parent = None
    bpy.data.libraries.write(OUT, set(parts), fake_user=True)
    log("WROTE %s (%.0f KB)" % (OUT, os.path.getsize(OUT) / 1024))
    log("pieces: %s" % [o.name for o in parts])
    log("the shrinkwrap is LEFT LIVE, so fit_webbing re-solves it per soldier.")


if __name__ == "__main__":
    main()
