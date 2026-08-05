"""THE AID STATION'S TWO NON-COMBATANTS: the tent doctor and the man on the cot.

    blender -b --factory-startup -P tools/make_tent_bodies.py            (build + gate)
    blender -b --factory-startup -P tools/make_tent_bodies.py -- --export   (owner gate)

WHY THESE TWO EXIST. The aid station is already live and has been for weeks. Markers
(`tools/gen_firebase_v3.py:629`), post seeding (`scripts/world/site_planner.gd:969-978`,
one `medic` + one `patient`), clips (`scripts/world/civilian.gd:452-465`) and the daily
schedule (`scripts/ai/civilian_schedules.gd:186-200`) are all built. The only missing
piece is the BODY - so what is in the tent right now is a fully armed rifleman in a
steel helmet miming surgery over a second fully armed rifleman in a steel helmet lying
on the cot. A man in full battle order lying down does not read as wounded at all.

THE BASE IS A SQUAD BODY. `us_grunt_rifleman.glb`, for the reason spelled out in
make_medic.py: the shipped role GLBs are the verified article, and the v3 base man's
UVs reach into an atlas strip no squad body uses, which is the "different color pants".
Deriving from the squad body means these two can never drift off the cast.

WHAT IS AUTHORED HERE, AND WHAT IS INHERITED
  inherited: the whole 41-bone PSXRig, the body mesh, the gore caps, the head frags,
             the face atlas, the boots and trousers.
  authored : two flat materials (the shirt colours), a UV move that rolls the doctor's
             sleeves, and two small wrapped bands - the doctor's brassard and the
             patient's chest dressing.

RULINGS THIS FILE OBEYS (owner, 2026-08-03)
  * NO red cross on the field medic - he is outside the wire, and the marking is what
    got medics shot. The cross lives INSIDE the wire: on this doctor and on the tent.
  * The doctor wears the plain blue-green shirt, not teal scrubs and not khaki.
  * NO surgical mask. A mask hides the face atlas and kills the per-man face variation
    GruntDresser gets by sliding uv1_offset over it.
  * Both are BARE-HEADED. That is the point of them.
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import US_CHARACTERS_DIR
from bone_attach import attach
from probe_gear_fit import assert_clear, limb_mask
import make_medic as MM

BASE = os.path.join(US_CHARACTERS_DIR, "us_grunt_rifleman.glb")

# Everything that makes a man a combatant. Deleted, not hidden: a hidden mesh still
# exports, and `select_set()` silently no-ops on hidden objects, so "hide it" is how a
# helmet ends up in a GLB nobody meant to put it in.
# head_frag_* is deliberately NOT here. GibSystem.dismember_head_burst() collects
# head_frag_* and returns false on an empty list, so a body without them cannot lose its
# head - and these two men stand in a tent that gets mortared. Icosphere IS stripped:
# it is the glTF importer's bone display shape, viewport furniture that belongs in no
# exported file.
STRIP = ("helmet_", "web_", "ruck_", "pouch_belt", "canteen", "m16_world",
         "bandolier", "prc25_", "socket_", "target_", "Icosphere")

# The shirt. Dominant-weight bones, not a vertex box: a box catches the top of the
# trousers and the bottom of the neck, and both show.
SHIRT_BONES = ("Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder",
               "LeftArm", "RightArm")
# Rolled sleeves: the forearm stops being cloth and becomes skin.
SLEEVE_BONES = ("LeftForeArm", "RightForeArm")
HAND_BONES = ("LeftHand", "RightHand")

# Ruled by the owner: "the plain blue-green shirt". Sampled off the aid-station footage
# (US Navy medical film, *The Gentle Hand*) - a desaturated hospital blue-green, several
# stops away from every olive in the cast so it reads across the compound.
SHIRT_RGB = (0.322, 0.482, 0.463)
# The man on the cot is in his undershirt. Sun-bleached OD cotton, much lighter than the
# fatigues, so "he is not dressed for the field" reads at a glance.
UNDER_RGB = (0.560, 0.565, 0.505)
GAUZE_RGB = (0.870, 0.855, 0.795)
CROSS_RGB = (0.660, 0.060, 0.050)


def log(*a):
    print("[TENT]", *a)


def flat(name, rgb, rough=0.94):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.12
    return m


def load_base():
    """Import the shipped squad body and flatten it into an identity world.

    glTF is Y-up, so the importer hangs everything under a root with a -90 X rotation.
    bone_attach solves its basis in that space, and a band built in world coords then
    lands a metre and a half out. Bake it before anything else touches the scene.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BASE)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = next(
        o for o in bpy.data.objects if o.type == 'ARMATURE')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.data.objects):
        if o.parent is None and o.type == 'EMPTY' and not o.children:
            bpy.data.objects.remove(o, do_unlink=True)
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.name = "PSXRig"
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()
    body = bpy.data.objects["us_grunt_joined"]
    return rig, body


def strip_gear(scope=None):
    """Delete every combatant piece. Returns what went.

    `scope` is the object set for THIS man. Unscoped, run inside the owner's open
    us_base_v3.blend, this would walk `bpy.data.objects` and delete the helmets off all
    seven of his squad variants.
    """
    gone = []
    for o in list(scope if scope is not None else bpy.data.objects):
        if o.name not in bpy.data.objects:
            continue
        if o.type in ('MESH', 'EMPTY') and any(o.name.startswith(p) or p in o.name
                                               for p in STRIP):
            gone.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    log("stripped %d combatant pieces" % len(gone))
    return gone


def dominant(mesh):
    gi = {g.index: g.name for g in mesh.vertex_groups}
    out = {}
    for v in mesh.data.vertices:
        best, w = None, -1.0
        for g in v.groups:
            if g.weight > w:
                best, w = g.group, g.weight
        out[v.index] = gi.get(best, "")
    return out


def _slot(mesh, mat):
    for i, m in enumerate(mesh.data.materials):
        if m is mat:
            return i
    mesh.data.materials.append(mat)
    return len(mesh.data.materials) - 1


def retint(objs, bones, mat):
    """Give every polygon whose vertices are dominantly weighted to `bones` a new
    material. Applied to the joined body AND to the gib donors - a dismembered doctor
    whose severed arm is still olive drab is the same defect as never fixing it."""
    n = 0
    for ob in objs:
        if ob.type != 'MESH' or not ob.vertex_groups:
            continue
        dom = dominant(ob)
        idx = None
        for p in ob.data.polygons:
            hits = sum(1 for i in p.vertices
                       if any(dom[i].endswith(b) for b in bones))
            if hits * 2 > len(p.vertices):
                if idx is None:
                    idx = _slot(ob, mat)
                p.material_index = idx
                n += 1
    log("  retint %-14s %d polys across %d meshes"
        % (mat.name, n, len([o for o in objs if o.type == 'MESH'])))
    return n


def roll_sleeves(objs, body=None):
    """SLEEVES ROLLED, without inventing a skin colour.

    The forearm is cloth because its UVs sit on the sleeve patch of the shared atlas.
    His HANDS are already bare, on the same material, at u[0.278,0.324] v[0.157,0.187].
    So rolling a sleeve is not a new texture and not a new material - it is moving the
    forearm's UVs onto the patch his own hands already use. Do it any other way (a flat
    tan, a new page) and the forearm will not match the hand it is attached to, and the
    atlas grows for nothing on a disk that is nearly full.
    """
    # Derive the patch from THIS body, never from the numbers written above - they are
    # a note about what was measured, not an input.
    src = None
    # by IDENTITY, not by the literal name. A second import into the same file is
    # `us_grunt_joined.001`, and a name test silently finds nothing and then raises
    # "no hand polys" - a true message about a false cause.
    for ob in objs:
        if body is not None and ob is not body:
            continue
        if body is None and not ob.name.startswith("us_grunt_joined"):
            continue
        dom = dominant(ob)
        uvl = ob.data.uv_layers[0].data
        pts = [Vector(uvl[li].uv) for p in ob.data.polygons
               for li in p.loop_indices
               if all(any(dom[i].endswith(h) for h in HAND_BONES) for i in p.vertices)]
        if pts:
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts)))
            # inset hard: a UV on the seam of a patch bleeds the neighbouring patch in,
            # and on a 3600x5700 sheet the neighbour is a photograph.
            c = (lo + hi) * 0.5
            src = (c, (hi - lo) * 0.18)
            break
    if src is None:
        raise RuntimeError("no hand polys found - cannot derive the bare-skin patch")
    c, half = src
    log("  bare-forearm patch derived from his own hands: (%.4f, %.4f) +-(%.4f, %.4f)"
        % (c.x, c.y, half.x, half.y))

    n = 0
    for ob in objs:
        if ob.type != 'MESH' or not ob.vertex_groups or not ob.data.uv_layers:
            continue
        dom = dominant(ob)
        uvl = ob.data.uv_layers[0].data
        # remap, do not collapse: a single UV coordinate is unpaintable, and it looks
        # perfect right up until somebody paints the atlas.
        sel = [p for p in ob.data.polygons
               if sum(1 for i in p.vertices
                      if any(dom[i].endswith(b) for b in SLEEVE_BONES)) * 2
               > len(p.vertices)]
        if not sel:
            continue
        pts = [Vector(uvl[li].uv) for p in sel for li in p.loop_indices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts)))
        span = Vector((max(hi.x - lo.x, 1e-6), max(hi.y - lo.y, 1e-6)))
        for p in sel:
            for li in p.loop_indices:
                u = Vector(uvl[li].uv)
                t = Vector(((u.x - lo.x) / span.x, (u.y - lo.y) / span.y))
                uvl[li].uv = (c.x + (t.x * 2.0 - 1.0) * half.x,
                              c.y + (t.y * 2.0 - 1.0) * half.y)
            n += 1
    log("  sleeves rolled: %d forearm polys moved onto the bare-skin patch" % n)
    return n


def wrap(name, rig, body, bone_a, bone_b, t, half_h, mat, sides=8, clearance=0.010):
    """A band WRAPPED round a limb - the brassard and the field dressing.

    Radius is MEASURED off the body verts that belong to that limb, not typed in. A
    typed radius is how a bandage ends up inside a thigh, and "gear never intersects a
    body" is a standing ruling, not a preference.
    """
    S = MM._skel_scale(rig)
    a = rig.matrix_world @ rig.pose.bones["mixamorig:" + bone_a].head
    b = rig.matrix_world @ rig.pose.bones["mixamorig:" + bone_b].head
    axis = (b - a)
    L = axis.length
    axis.normalize()
    centre = a + axis * (L * t)

    # ONLY the verts in the band's own slice, and only the segment it sits on. A
    # +-2.5x window on `bone_a` OR `bone_b` swept the whole deltoid in and sized the
    # brassard at an 8.7 cm radius - a band that reads as a barrel round his shoulder
    # instead of a strip round his arm.
    dom = dominant(body)
    r = 0.0
    # WIDEN UNTIL THE SLICE HAS VERTICES IN IT. A PSX limb has maybe ten rings on it,
    # so a tight window can legitimately contain none - and a hard failure there is a
    # true error message about a false cause. Start tight (so the deltoid does not size
    # an arm band) and open up only as far as it takes to measure something.
    for k in (1.2, 2.0, 3.0, 5.0, 1e9):
        for v in body.data.vertices:
            if not dom[v.index].endswith(bone_a):
                continue
            d = (body.matrix_world @ v.co) - centre
            along = d.dot(axis)
            if abs(along) > half_h * k:
                continue
            r = max(r, (d - axis * along).length)
        if r > 0.0:
            break
    if r <= 0.0:
        raise RuntimeError("%s: no body verts on %s - radius unmeasurable"
                           % (name, bone_a))
    r += clearance * S

    up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    e1 = axis.cross(up).normalized()
    e2 = axis.cross(e1).normalized()
    verts, faces = [], []
    for k in range(sides):
        ang = 2.0 * math.pi * k / sides
        rad = e1 * math.cos(ang) * r + e2 * math.sin(ang) * r
        verts.append(centre + rad - axis * half_h)
        verts.append(centre + rad + axis * half_h)
    for k in range(sides):
        i, j = k * 2, ((k + 1) % sides) * 2
        faces.append([i, j, j + 1, i + 1])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    n_out = lift_clear(ob, body, clearance * S)
    log("  %-22s r=%.3f (measured) on %s->%s, %d verts lifted onto the surface"
        % (name, r, bone_a, bone_b, n_out))
    ob["band_centre"] = tuple(centre)
    ob["band_axis"] = tuple(axis)
    ob["band_r"] = r
    ob["band_half_h"] = half_h
    return ob


def lift_clear(ob, body, clearance):
    """Any vertex that is INSIDE the body is moved out onto the surface plus clearance.
    Vertices already outside are left alone.

    One radius cannot fit a limb: an upper arm at the deltoid is fatter than the same
    arm at mid-humerus, and a ring sized off the average buries two verts in the
    shoulder - which is exactly what the gate caught on the first build. Conforming
    per-vertex, and only ever OUTWARD, cannot collapse the band and cannot bury it.
    """
    inv = body.matrix_world.inverted()
    back = ob.matrix_world.inverted()
    moved = 0
    # ITERATE. One pass is not enough where the body is concave: the armpit's nearest
    # surface point is on the far wall of the crease, so lifting a vertex out of the
    # ribs can set it down inside the arm. Each pass strictly reduces penetration, and
    # the loop stops the moment nothing is inside.
    for _ in range(8):
        n = 0
        for v in ob.data.vertices:
            p = inv @ (ob.matrix_world @ v.co)
            ok, hit, nor, _i = body.closest_point_on_mesh(p)
            if not ok or (p - hit).dot(nor) >= 0.0:
                continue
            tgt = hit + nor.normalized() * clearance
            v.co = back @ (body.matrix_world @ tgt)
            n += 1
        moved += n
        if n == 0:
            break
    ob.data.update()
    return moved


def cross_patch(name, band, mat, size=0.55, lift=0.004):
    """Two quads laid PROUD of a band - geometry, not a decal, which is what a PSX-era
    model does and what reads from across a compound.

    Placed off the BAND's own geometry (its widest ring vertex and that vertex's
    outward direction), so it lands on the outside of the arm wherever the arm is,
    instead of at a hand-typed coordinate that is right for exactly one body.
    """
    # Off the band's OWN recorded frame, never off its bounding box. In a T-pose the
    # brassard's axis is horizontal, so the ring's z-extent IS its diameter - sizing the
    # cross from that made a 15 cm cross on a 6 cm band, and it read as a chest panel.
    c = Vector(band["band_centre"])
    axis = Vector(band["band_axis"]).normalized()
    r = float(band["band_r"])
    half_h = float(band["band_half_h"])
    fwd = Vector((0.0, -1.0, 0.0))                 # his front, glTF flattened
    n = (fwd - axis * fwd.dot(axis))               # forward, projected off the arm axis
    if n.length < 1e-4:
        n = Vector((0.0, 0.0, 1.0))
    n.normalize()
    side = axis
    up = n.cross(side).normalized()
    o = c + n * (r + lift)
    half = min(half_h, r) * size * 1.7
    Lb, Tb = half, half * 0.34
    verts, faces = [], []
    for (sa, sb) in ((Lb, Tb), (Tb, Lb)):
        i = len(verts)
        verts += [o - side * sa - up * sb, o + side * sa - up * sb,
                  o + side * sa + up * sb, o - side * sa + up * sb]
        faces.append([i, i + 1, i + 2, i + 3])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def hang(gear, rig, bone):  # noqa: E302
    """Gear contract: rigid, no skin, bone-parented, name-hinted, at identity."""
    for o in gear:
        if o.vertex_groups or any(m.type == 'ARMATURE' for m in o.modifiers):
            raise RuntimeError("%s is SKINNED - it would enter the hurtbox" % o.name)
        if "strap" not in o.name.lower():
            raise RuntimeError(
                "%s carries no _GEAR_NAME_HINTS word (hitzone_builder.gd:43-48). "
                "It WILL be harvested into the torso hull." % o.name)
    for o in gear:
        o.data.transform(o.matrix_world)
        o.data.update()
        o.matrix_world = Matrix.Identity(4)
    for o in gear:
        attach(o, rig, bone)
    for o in gear:
        m = o.matrix_world
        err = max(abs(m[i][j] - Matrix.Identity(4)[i][j])
                  for i in range(4) for j in range(4))
        if err > 1e-3:
            raise RuntimeError("%s displaced by %.4f" % (o.name, err))


def tri_count():
    n = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n, len([o for o in bpy.data.objects if o.type == 'MESH'])


def build_doctor():
    rig, body = load_base()
    strip_gear(MM.owned_by(rig) + [o for o in bpy.data.objects if o.type == 'EMPTY'])
    skinned = [o for o in MM.owned_by(rig) if o.vertex_groups]
    retint(skinned, SHIRT_BONES, flat("DoctorShirt", SHIRT_RGB))
    roll_sleeves(skinned, body)

    # THE CROSS, and the only man in the game who wears one. Ruled: inside the wire,
    # where it says "this is the aid station" and where nobody is shooting at him.
    band = wrap("brassard_strap_l", rig, body, "LeftArm", "LeftForeArm",
                t=0.42, half_h=0.028 * MM._skel_scale(rig),
                mat=flat("BrassardGauze", GAUZE_RGB))
    cross = cross_patch("brassard_strap_cross", band, flat("BrassardCross", CROSS_RGB))
    lift_clear(cross, body, 0.014 * MM._skel_scale(rig))
    gear = [band, cross]
    # The brassard rides the ARM, so the arm is exactly what it must be measured
    # against - the default mask throws arms away, which here would measure nothing.
    assert_clear("doctor brassard", body, gear, pmask=[False] * len(body.data.polygons))
    hang(gear, rig, "mixamorig:LeftArm")
    return rig, "us_doctor"


def build_patient():
    rig, body = load_base()
    strip_gear(MM.owned_by(rig) + [o for o in bpy.data.objects if o.type == 'EMPTY'])
    skinned = [o for o in MM.owned_by(rig) if o.vertex_groups]
    retint(skinned, SHIRT_BONES, flat("PatientUndershirt", UNDER_RGB))

    # The field dressing. Chest, not head: a head wrap would cover the face atlas and
    # kill the per-man face variation, which is the same reason the mask was ruled out.
    band = wrap("dressing_strap_chest", rig, body, "Spine1", "Spine2",
                t=0.65, half_h=0.055 * MM._skel_scale(rig),
                mat=flat("DressingGauze", GAUZE_RGB), sides=10)
    gear = [band]
    assert_clear("patient dressing", body, gear,
                 pmask=[False] * len(body.data.polygons))
    hang(gear, rig, "mixamorig:Spine1")
    return rig, "us_patient"


def export(rig, name):
    out = os.path.join(US_CHARACTERS_DIR, name + ".glb")
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig    # or the rig is dropped
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_animations=False, export_skins=True,
        export_morph=False, export_materials='EXPORT', export_extras=True,
        export_draco_mesh_compression_enable=False)
    log("WROTE %s (%.1f MB)" % (out, os.path.getsize(out) / 1e6))


def main(do_export=False):
    for fn in (build_doctor, build_patient):
        log("=== %s ===" % fn.__name__)
        rig, name = fn()
        t, m = tri_count()
        log("%s: %d tris across %d meshes" % (name, t, m))
        if do_export:
            export(rig, name)
        else:
            log("NOT EXPORTED (owner gate, 2026-08-03 'dont export til i pass it'). "
                "A .glb in assets/us/characters/ IS shipping - ModelActor.model_path() "
                "resolves a unit_id straight off the folder.")


if __name__ == "__main__":
    main(do_export="--export" in sys.argv)
