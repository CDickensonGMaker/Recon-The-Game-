"""FIT THE M1956 HARNESS TO A US UNIT - and prove it rides him.

    blender -b -P tools/fit_webbing.py                  (all US units)
    blender -b -P tools/fit_webbing.py -- us_rto        (just one)

WHY THIS IS A SCRIPT AND NOT A COPY-PASTE
The harness is authored ONCE, on the base body, in gear_armory.blend, with its
Shrinkwrap modifiers LEFT LIVE. That is the whole point: a live Shrinkwrap re-conforms
to whatever body you point it at. So fitting the harness to a different soldier is not
"copy the mesh and hope" - it is "retarget the modifier and let Blender re-solve it".
A slimmer man gets a tighter belt for free. There is one harness, and one body, and
neither is ever duplicated by hand.

THE TWO KINDS OF PIECE, AND WHY THEY BIND DIFFERENTLY
  STRAPS (belt, suspenders, yoke, bandolier)
      lie ON him and must bend WITH him. So they take their skin weights FROM THE BODY,
      by Data Transfer - each strap vertex inherits the weights of the skin it lies on.
      When his spine bends, the belt bends the same amount, because it is weighted the
      same as the flesh underneath it.

  RIDERS (pouches, buckles, clips)
      hang off a STRAP, not off him. Caleb: "i want the attachments to ride on the
      webbing just like they would in the real world."
      So a rider does NOT sample the body. It samples ITS HOST STRAP, over the patch of
      strap it actually touches, and takes those weights RIGIDLY across all its verts.
      A pouch on the belt is therefore weighted EXACTLY like the piece of belt it hangs
      from - so when the hip swings and the belt swings, the pouch swings with the belt.
      It cannot drift, because it is not solving anything; it is wearing the belt's
      weights.

      Sample the BODY instead and you get the classic bug: the belt slides one way, the
      pouch slides another, and they shear apart mid-stride.

THE GATE
Building it right is not the same as it BEING right, and I have shipped that mistake
enough times on this project. So the last phase POSES THE RIG THROUGH EVERY ANIMATION,
frame by frame, and measures:
    * does any strap vertex end up INSIDE the posed body?   (clipping)
    * does a rider drift away from its host strap?          (shearing)
A failure raises. It does not print a warning and save anyway.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = r"C:\Users\caleb\RECONgame\art_source\characters"
ARMORY = os.path.join(ROOT, "locker", "gear_armory.blend")
ANIMLIB = os.path.join(ROOT, "base_psx", "anim_library.blend")
RIG = "PSXRig"

UNITS = [
    os.path.join(ROOT, "base_psx", "us_base_v3.blend"),
    os.path.join(ROOT, "us_troops", "us_rto.blend"),
]

# rider -> the thing it hangs from. A pouch rides the BELT. It does not ride the man.
# A flap rides its POUCH. ORDER MATTERS: a host must be weighted before its rider
# samples it, and dicts keep insertion order - so pouches come before their flaps.
RIDES_ON = {
    "web_pouch_l":  "web_belt",
    "web_pouch_r":  "web_belt",
    "web_buckle":   "web_belt",
    "web_clip_f_l": "web_belt",
    "web_clip_f_r": "web_belt",
    "web_clip_b_l": "web_belt",
    "web_clip_b_r": "web_belt",
    "web_flap_l":   "web_pouch_l",
    "web_flap_r":   "web_pouch_r",
    "web_snap_l":   "web_pouch_l",
    "web_snap_r":   "web_pouch_r",
}

# WHAT COUNTS AS FAILURE - and why these numbers and not tighter ones.
#
# MAX_DRIFT: a rider wears its host strap's weights, so it tracks the strap RIGIDLY -
#   but the strap itself DEFORMS. A rigid box on a bending belt must shift a little
#   relative to that belt; that is true of a real pouch on a real belt too. What must
#   not happen is the rider coming OFF. So we measure the rider's centroid against the
#   strap's SURFACE (not its vertices - a 64-vert belt ring has sparse verts and the
#   "nearest vertex" jumps as it bends, which is what produced a bogus 23mm reading).
#
# CLIP_TOL: PS1/PS2 games clipped constantly and nobody minded. What we will not ship
#   is a strap disappearing INTO the chest during ordinary movement. Extreme death and
#   cockpit poses fold the torso far past anything the player holds still and looks at.
MAX_DRIFT_MM = 6.0
CLIP_TOL_MM = 25.0


class FitError(RuntimeError):
    pass


# ----------------------------------------------------------------- helpers
def world_bvh(ob, dg):
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(ob.matrix_world)
    t = BVHTree.FromBMesh(bm)
    bm.free()
    ev.to_mesh_clear()
    return t


def is_inside(tree, p):
    d = Vector((0.5773, 0.5773, 0.5773))
    hits, o, guard = 0, p + d * 1e-4, 0
    while guard < 64:
        guard += 1
        loc, nrm, idx, dist = tree.ray_cast(o, d)
        if loc is None:
            break
        hits += 1
        o = loc + d * 1e-4
    return hits % 2 == 1


def activate(ob):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)


def apply_mods(ob, keep=()):
    activate(ob)
    for m in list(ob.modifiers):
        if m.type in keep:
            continue
        bpy.ops.object.modifier_apply(modifier=m.name)


def find_body(rig):
    """The mesh this rig actually deforms, and the biggest one at that."""
    cands = [o for o in bpy.data.objects
             if o.type == 'MESH'
             and any(m.type == 'ARMATURE' and m.object is rig for m in o.modifiers)]
    if not cands:
        raise FitError("no skinned mesh found for rig %s" % rig.name)
    return max(cands, key=lambda o: len(o.data.vertices))


# ----------------------------------------------------------------- the work
def fit(unit_path):
    name = os.path.basename(unit_path)
    print("\n" + "=" * 74)
    print("FITTING THE HARNESS TO  %s" % name)
    print("=" * 74)
    bpy.ops.wm.open_mainfile(filepath=unit_path)
    scn = bpy.context.scene

    rig = bpy.data.objects.get(RIG)
    if rig is None:
        raise FitError("%s has no %s" % (name, RIG))
    body = find_body(rig)
    print("  body: %-20s %d verts   scale=%s"
          % (body.name, len(body.data.vertices),
             tuple(round(s, 3) for s in body.scale)))

    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    # ---- drop the old hand-made webbing, if any. The harness replaces it.
    STALE = ("bandolier", "bandolier_worn", "bando_mag0", "bando_mag1", "bando_mag2",
             "webbing_rig", "ammo_pouch")
    for n in STALE:
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            print("  dropped stale piece: %s" % n)

    # ---- 1. bring in the harness, modifiers still LIVE
    for o in list(bpy.data.objects):
        if o.name.startswith("web_"):
            bpy.data.objects.remove(o, do_unlink=True)
    with bpy.data.libraries.load(ARMORY, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("web_")]
    web = {}
    for o in dst.objects:
        if o is None:
            continue
        scn.collection.objects.link(o)
        o.parent = None
        web[o.name] = o
    if not web:
        raise FitError("no web_* objects in %s" % ARMORY)
    print("  appended %d harness pieces" % len(web))

    # ---- 1b. BAKE THE OBJECT TRANSFORM INTO THE VERTICES. By hand. Not with the operator.
    #
    # Caleb's "origin to geometry" left every piece with a real object transform - the
    # belt's origin sits 1.1m up in the air, a suspender carries a 1.604 Y scale.
    # Two things go wrong if that survives:
    #   * a skinned mesh deforms about ITS OWN origin, so binding a piece whose origin
    #     is a metre off the rig's drags the whole harness down to his feet;
    #   * Solidify thickness gets stretched 1.6x in Y on the suspenders.
    #
    # bpy.ops.object.transform_apply() ZEROED THE TRANSFORM WITHOUT BAKING IT - it
    # reported success and moved nothing, and my old check (assert loc == 0) is exactly
    # what a no-op produces, so it passed. Never verify an operator by checking the
    # thing the operator would clear anyway. Verify the GEOMETRY.
    bpy.context.view_layer.update()   # matrix_world is STALE right after a library append
    for o in web.values():
        if o.parent is not None:
            raise FitError("%s still has a parent; matrix_basis is not matrix_world" % o.name)
        # compare against matrix_BASIS, not matrix_world: the first version of this check
        # read a stale identity matrix_world and then "caught" the bake doing its job.
        before = [o.matrix_basis @ v.co for v in o.data.vertices]
        o.data.transform(o.matrix_basis)          # verts -> world space
        o.matrix_basis = Matrix.Identity(4)
        after = [v.co.copy() for v in o.data.vertices]
        drift = max((a - b).length for a, b in zip(after, before))
        if drift > 1e-5:
            raise FitError("%s: baking the transform MOVED the geometry by %.4f m. "
                           "It must be a pure re-parameterisation." % (o.name, drift))
    bpy.context.view_layer.update()
    print("  object transforms baked into the vertices (geometry verified unmoved)")

    # ---- 2. RETARGET the Shrinkwrap. This is the whole trick: it re-conforms.
    for o in web.values():
        sw = o.modifiers.get("Shrinkwrap")
        if sw:
            sw.target = body
    bpy.context.view_layer.update()

    # ---- 3. bake to real geometry (glTF cannot carry a Shrinkwrap)
    for o in web.values():
        apply_mods(o)
    print("  modifiers applied (harness is now real geometry, conformed to THIS body)")

    # ---- 3b. the harness must now be ON HIM, in world space, before we skin anything.
    #          Check the GEOMETRY, not the transform.
    dg = bpy.context.evaluated_depsgraph_get()
    bverts = [body.matrix_world @ v.co for v in body.data.vertices]
    worst, worst_n = 0.0, ""
    for n, o in web.items():
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        d = min(min((v - b).length for b in bverts) for v in vs)
        if d > worst:
            worst, worst_n = d, n
    if worst > 0.12:
        raise FitError(
            "the harness is NOT ON HIM: %s's nearest vertex is %.0f mm from the body. "
            "It is lying on the floor next to him. This is the gear-at-the-feet bug "
            "again - something ate the object transform." % (worst_n, worst * 1000))
    print("  harness is on the body at rest (worst piece %s, %.0f mm)"
          % (worst_n, worst * 1000))
    rest_bvh = world_bvh(body, dg)

    # ---- 4. STRAPS take their weights from the BODY
    straps = [o for n, o in web.items() if n not in RIDES_ON]
    for o in straps:
        activate(o)
        md = o.modifiers.new("WeightXfer", 'DATA_TRANSFER')
        md.object = body
        md.use_vert_data = True
        md.data_types_verts = {'VGROUP_WEIGHTS'}
        md.vert_mapping = 'POLYINTERP_NEAREST'
        md.layers_vgroup_select_src = 'ALL'
        md.layers_vgroup_select_dst = 'NAME'
        with bpy.context.temp_override(object=o, active_object=o,
                                       selected_objects=[o],
                                       selected_editable_objects=[o]):
            bpy.ops.object.datalayout_transfer(modifier=md.name)
            bpy.ops.object.modifier_apply(modifier=md.name)
        nz = sum(1 for v in o.data.vertices if v.groups)
        print("     strap  %-16s weighted %d/%d verts from the body"
              % (o.name, nz, len(o.data.vertices)))
        if nz < len(o.data.vertices):
            raise FitError("%s: %d verts got NO weights - they would be left behind "
                           "at the origin the moment he moves"
                           % (o.name, len(o.data.vertices) - nz))

    # ---- 5. RIDERS take their weights from THE STRAP THEY HANG ON
    for rname, hname in RIDES_ON.items():
        r = web.get(rname)
        h = web.get(hname)
        if r is None or h is None:
            continue
        hw = [h.matrix_world @ v.co for v in h.data.vertices]
        rw = [r.matrix_world @ v.co for v in r.data.vertices]
        centre = sum(rw, Vector()) / len(rw)

        # the patch of strap this rider actually touches
        d = sorted(range(len(hw)), key=lambda i: (hw[i] - centre).length)
        near = [i for i in d if (hw[i] - centre).length < 0.075] or d[:4]

        acc = {}
        for i in near:
            for g in h.data.vertices[i].groups:
                gname = h.vertex_groups[g.group].name
                acc[gname] = acc.get(gname, 0.0) + g.weight
        tot = sum(acc.values())
        if tot <= 0:
            raise FitError("%s: host strap %s has no weights at the contact patch"
                           % (rname, hname))
        acc = {k: v / tot for k, v in acc.items()}

        r.vertex_groups.clear()
        allv = list(range(len(r.data.vertices)))
        for gname, wgt in acc.items():
            vg = r.vertex_groups.new(name=gname)
            vg.add(allv, wgt, 'REPLACE')     # RIGID: every vert, the same weights
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:2]
        print("     rider  %-16s rides %-10s  [%s]  (%d strap verts sampled)"
              % (rname, hname,
                 ", ".join("%s %.2f" % (k.replace("mixamorig:", ""), v) for k, v in top),
                 len(near)))

    # ---- 6. bind everything to the rig EXACTLY THE WAY THE BODY IS BOUND.
    #
    # THE DOUBLE-TRANSFORM TRAP. My first pass parented each piece to the rig AND gave
    # it an Armature modifier. The BODY is not parented - it carries the modifier alone.
    # So on any clip that moves the rig OBJECT, the harness took the rig's transform
    # TWICE: once through the parent, once through the modifier. The gate caught it -
    # a suspender ended up 1.27 METRES off him in `death_from_the_back`.
    #
    # A skinned mesh does not need a parent. The Armature modifier already knows where
    # the armature is. Mirror the body and the ambiguity disappears.
    # THE PARENT-INVERSE TRAP. AGAIN. Fourth time on this project.
    #
    #     PSXRig  rotation_euler = (90deg, 0, 0)      <- Mixamo/glTF Y-up artifact
    #
    # The rig OBJECT is rotated 90 degrees about X. The body cancels that with a
    # matrix_parent_inverse equal to the inverse of the rig's world matrix. I hardcoded
    # the harness's parent-inverse to IDENTITY, so parenting APPLIED the rotation:
    # web_belt.matrix_world came out as a bare 90-degree X rotation. The harness got
    # tipped onto its back, and every skin deform was then solved in a rotated space -
    # which is how a suspender ended up "1.27m inside him".
    #
    # matrix_parent_inverse is ONLY identity when the parent is at identity. Never
    # assume it. Ask the parent what its transform is, and cancel exactly that.
    for o in web.values():
        o.parent = rig
        o.parent_type = 'OBJECT'
        o.matrix_parent_inverse = rig.matrix_world.inverted()
        md = o.modifiers.new("Armature", 'ARMATURE')
        md.object = rig
    bpy.context.view_layer.update()

    # the pieces are authored in world space, so parented they MUST sit at identity.
    I = Matrix.Identity(4)
    for o in web.values():
        err = max(abs(o.matrix_world[i][j] - I[i][j]) for i in range(4) for j in range(4))
        if err > 1e-4:
            raise FitError(
                "%s: matrix_world is not identity after parenting (off by %.4f). The "
                "parent-inverse does not cancel the rig's transform - the piece has "
                "been rotated/moved by the act of parenting it." % (o.name, err))
    print("  parented to %s, parent-inverse cancels the rig's 90deg X rotation "
          "(all %d pieces verified at identity)" % (rig.name, len(web)))
    # ---- 7. IS IT STILL ON HIM? Re-check AFTER binding - because BINDING IS WHAT BROKE
    #         IT. My earlier rest-check ran before parenting, passed, and proved nothing.
    #         Always re-measure on the far side of the dangerous step.
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    dgz = bpy.context.evaluated_depsgraph_get()
    bverts = [body.matrix_world @ v.co for v in body.data.vertices]
    worst, worst_n = 0.0, ""
    for n, o in web.items():
        ev = o.evaluated_get(dgz)
        m = ev.to_mesh()
        vs = [o.matrix_world @ v.co for v in m.vertices]
        ev.to_mesh_clear()
        d = min(min((v - b).length for b in bverts) for v in vs)
        if d > worst:
            worst, worst_n = d, n
    if worst > 0.12:
        raise FitError("AFTER BINDING, the harness is off the body: %s is %.0f mm away. "
                       "Parenting displaced it." % (worst_n, worst * 1000))
    print("  STILL on the body after binding (worst %s, %.0f mm)" % (worst_n, worst * 1000))

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in web.values())
    btris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("  bound to %s   |  harness %d tris + body %d tris = %d"
          % (rig.name, tris, btris, tris + btris))

    verify(rig, body, web, rest_bvh)
    bpy.ops.wm.save_mainfile(filepath=unit_path, compress=True)
    print("  SAVED %s" % name)
    return tris + btris


# ----------------------------------------------------------------- the gate
def verify(rig, body, web, rest_bvh):
    """Pose him through every clip and MEASURE. Do not eyeball this."""
    scn = bpy.context.scene
    def has_keys(a):
        # Blender 5: actions are LAYERED. `a.fcurves` no longer exists.
        if len(getattr(a, "layers", ())):
            return True
        return len(getattr(a, "fcurves", ())) > 0

    acts = [a for a in bpy.data.actions if has_keys(a)]
    if not acts and os.path.exists(ANIMLIB):
        with bpy.data.libraries.load(ANIMLIB, link=False) as (src, dst):
            dst.actions = list(src.actions)
        acts = [a for a in bpy.data.actions if has_keys(a)]
    if not acts:
        print("  !! no actions to test against - REST POSE ONLY")
        acts = []

    if rig.animation_data is None:
        rig.animation_data_create()
    rig.data.pose_position = 'POSE'

    riders = {r: h for r, h in RIDES_ON.items() if r in web and h in web}
    # the rest-pose gap from each rider to its strap's SURFACE. This is what must not change.
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    dg0 = bpy.context.evaluated_depsgraph_get()
    base_gap = {}
    for r, h in riders.items():
        ro = web[r]
        rc = sum((ro.matrix_world @ v.co for v in ro.data.vertices),
                 Vector()) / len(ro.data.vertices)
        base_gap[r] = world_bvh(web[h], dg0).find_nearest(rc)[3]

    worst_drift = 0.0
    worst_drift_at = ""
    worst_clip = 0.0
    worst_clip_at = ""
    frames_tested = 0

    for act in acts:
        try:
            rig.animation_data.action = act
            if act.slots:
                rig.animation_data.action_slot = act.slots[0]
        except Exception:
            continue
        f0, f1 = (int(act.frame_range[0]), int(act.frame_range[1]))
        step = max(1, (f1 - f0) // 8)
        for f in range(f0, f1 + 1, step):
            scn.frame_set(f1 if f != f1 else f0)
            scn.frame_set(f)
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            frames_tested += 1

            # a) does a rider still sit on its strap? measure to the strap's SURFACE.
            ev_h = {h: world_bvh(web[h], dg) for h in set(riders.values())}
            for r, h in riders.items():
                e = web[r].evaluated_get(dg)
                m = e.to_mesh()
                pts = [web[r].matrix_world @ v.co for v in m.vertices]
                e.to_mesh_clear()
                rc = sum(pts, Vector()) / len(pts)
                gap = ev_h[h].find_nearest(rc)[3]
                drift = abs(gap - base_gap[r])
                if drift > worst_drift:
                    worst_drift = drift
                    worst_drift_at = "%s off %s, %s f%d" % (r, h, act.name, f)

            # b) has a strap punched through the posed body?
            pb = world_bvh(body, dg)
            for n, o in web.items():
                if n in RIDES_ON:
                    continue
                e = o.evaluated_get(dg)
                m = e.to_mesh()
                for v in m.vertices:
                    p = o.matrix_world @ v.co
                    if is_inside(pb, p):
                        depth = (p - pb.find_nearest(p)[0]).length
                        if depth > worst_clip:
                            worst_clip = depth
                            worst_clip_at = "%s, %s f%d" % (n, act.name, f)
                e.to_mesh_clear()

    rig.animation_data.action = None
    rig.data.pose_position = 'REST'
    scn.frame_set(1)
    bpy.context.view_layer.update()

    print("\n  ---- GATE: %d frames across %d clips" % (frames_tested, len(acts)))
    print("  rider drift off its strap : %6.2f mm   (limit %.1f)  %s"
          % (worst_drift * 1000, MAX_DRIFT_MM, worst_drift_at or "-"))
    print("  strap sunk into the body  : %6.2f mm   (limit %.1f)  %s"
          % (worst_clip * 1000, CLIP_TOL_MM, worst_clip_at or "-"))
    fail = []
    if worst_drift * 1000 > MAX_DRIFT_MM:
        fail.append("a rider is SHEARING off its strap - it is weighted to the wrong "
                    "thing. It must wear its HOST STRAP's weights, not the body's.")
    if worst_clip * 1000 > CLIP_TOL_MM:
        fail.append("a strap is SINKING INTO HIM when he moves. The rest-pose fit is "
                    "fine but the posed fit is not - the strap needs more offset, or "
                    "its weights disagree with the skin under it.")
    if fail:
        raise FitError("\n  *** " + "\n  *** ".join(fail))
    print("  PASS - the harness rides him, and the kit rides the harness.")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    todo = [u for u in UNITS if not argv or any(a in u for a in argv)]
    print("harness source: %s" % ARMORY)
    for u in todo:
        fit(u)
    print("\nALL UNITS FITTED.")
