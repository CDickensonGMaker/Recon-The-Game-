"""Dress the chow hall workbench with real US grunt v3 bodies running the chow clips.

    blender -b "<firebase>.blend" -P tools/gen_chowhall_crew.py -- [--save]

Replaces the proxy_body_* placeholders in WORKBENCH_chowhall_rigs with the grunt v3
body parts, seats extra men at the new work_eat markers, and assigns each man the
station clip authored in tools/make_chowhall_anims.py.

OFF DUTY MEN CARRY NOTHING. Summoner's spec, same as the M101 crew: no helmet, no
webbing, no ruck, no rifle. Those meshes exist in us_base_v3 and are simply never
appended - there is nothing to strip afterwards.

BODIES ARE LINKED DUPLICATES. Eight men x 16 meshes is 128 objects; duplicating with
linked=True shares the mesh data so the .blend grows by transforms, not geometry.
The disk this repo lives on is near full.
"""
import bpy, os, sys, math, re
from mathutils import Vector, Matrix, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ASSETS, US_BASE_V3

CLIP_BLEND = os.path.join(ASSETS, "shared", "chow_anim_workbench.blend")
RIG_COLL = "WORKBENCH_chowhall_rigs"
CHOW_COLL = "WORKBENCH_chowhall"
DONOR = "rifleman"

BODY = ('grunt_torso', 'grunt_head', 'grunt_leg_l', 'grunt_leg_r',
        'grunt_forearm_l', 'grunt_forearm_r', 'grunt_uparm_l', 'grunt_uparm_r',
        'cap_torso', 'cap_head', 'cap_leg_l', 'cap_leg_r',
        'cap_forearm_l', 'cap_forearm_r', 'cap_uparm_l', 'cap_uparm_r')

# existing station rig -> the clip it runs
STATION_CLIP = {
    "cook": "chow_cook_stir",
    "server": "chow_serve_ladle",
    "traystack": "chow_tray_hold",
    "midline": "chow_tray_hold",
    "trayreturn": "chow_tray_dump",
}
CLIPS = sorted(set(STATION_CLIP.values()) | {"chow_eat_seated"})
N_EATERS = 8
M = "mixamorig:"
BENCH_TOP = 0.46                  # measured off fb_bench in the workbench
SEAT_HIP_RISE = 0.09              # hip joint sits this far above the seat surface


def append_clips():
    d = CLIP_BLEND + os.sep + "Action" + os.sep
    got = []
    for name in CLIPS:
        if bpy.data.actions.get(name):
            got.append(name)
            continue
        try:
            bpy.ops.wm.append(directory=d, filename=name)
        except RuntimeError as ex:
            print("  clip append failed %s: %s" % (name, ex))
            continue
        a = bpy.data.actions.get(name)
        if a:
            a.use_fake_user = True
            got.append(name)
    return got


def append_body():
    """Append one donor body. Returns the meshes; the donor rig is discarded."""
    d = US_BASE_V3 + os.sep + "Object" + os.sep
    before = set(bpy.data.objects)
    parts = []
    for base in BODY:
        nm = "%s_%s" % (base, DONOR)
        try:
            bpy.ops.wm.append(directory=d, filename=nm)
        except RuntimeError as ex:
            print("  body append failed %s: %s" % (nm, ex))
            continue
        o = bpy.data.objects.get(nm)
        if o and o.type == 'MESH':
            parts.append(o)
    strays = [o for o in set(bpy.data.objects) - before
              if o.type == 'ARMATURE']
    return parts, strays


def bind(parts, rig, coll, tag):
    """Linked-duplicate the donor body onto one rig."""
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.duplicate(linked=True)
    made = [o for o in bpy.context.selected_objects if o.type == 'MESH']
    for o in made:
        o.name = o.name.split('.')[0].replace("_%s" % DONOR, "") + "_" + tag
        o.parent = rig
        o.matrix_parent_inverse = Matrix.Identity(4)
        bound = False
        for m in o.modifiers:
            if m.type == 'ARMATURE':
                m.object = rig
                bound = True
        if not bound:
            m = o.modifiers.new("Armature", 'ARMATURE')
            m.object = rig
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
    return made


def play(rig, clip_name):
    """Assign a clip - and put every pose bone back into QUATERNION mode.

    THIS IS THE WHOLE BUG. These rigs came out of hand-posing with their bones in
    XYZ euler mode, and a pose bone in EULER mode IGNORES its quaternion channels.
    The clips key quaternions, so every key was dead on arrival and the arms sat in
    whatever leftover euler was last set - hands over their heads. Measured: the
    LeftArm quaternion was byte-identical in both files, (0.8591, 0.3184, 0.1393,
    0.3758), and the hand was at z 0.868 in the workbench and z 1.610 here.
    Same lesson as make_civilian_anims.py's arm bake."""
    act = bpy.data.actions.get(clip_name)
    if act is None:
        return False
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    return True


def stand_up(rig):
    """Rotate the object until the MAN is upright, whatever the clip's convention.

    These clips do not agree on an up axis. Measured, hips-relative, in armature
    space: chow_eat_seated (from sitting_idle_b) puts the head at +0.518 in Y and the
    toes at -0.567 in Y - it is Y-up, and the authoring rig stands it up with an
    object rotation_euler.x of +90 deg. The idle-derived standing clips do not need
    it. A rig created at rotation zero therefore lies on its back with its feet in
    the air, which is exactly what the eaters were doing.

    So: measure the head-over-hips direction and rotate it onto +Z. Hardcoding the
    90 would break the moment a clip is re-sourced from a differently-imported take.
    """
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    hips = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
    head = rig.matrix_world @ rig.pose.bones[M + "Head"].head
    up = (head - hips)
    if up.length < 1e-6:
        return False
    up.normalize()
    if up.z > 0.85:
        return False
    # SNAP TO A RIGHT ANGLE, do not align exactly. The mismatch is a 90 deg
    # convention difference, but head-over-hips also carries the man's forward LEAN -
    # aligning that vector onto +Z rotated an eating man an extra 19 deg and left him
    # tipped back with his feet 0.19 m off the floor. Only quarter turns about X are
    # ever the right answer here.
    best, best_z = 0.0, up.z
    for deg in (90.0, 180.0, 270.0):
        q = Quaternion((1.0, 0.0, 0.0), math.radians(deg))
        z = (q @ up).z
        if z > best_z:
            best, best_z = deg, z
    if not best:
        return False
    q = Quaternion((1.0, 0.0, 0.0), math.radians(best))
    rig.rotation_euler = (q @ rig.rotation_euler.to_quaternion()).to_euler()
    bpy.context.view_layer.update()
    return True


def dephase(rig, act, offset):
    """Start this man at a different point in his loop.

    Eight men on one clip all key off scene frame 1 and move in perfect lockstep,
    which reads as a row of copies rather than a mess hall. An NLA strip started at a
    negative frame puts each man at his own phase without duplicating the action.
    """
    ad = rig.animation_data
    span = int(act.frame_range[1] - act.frame_range[0]) + 1
    off = offset % span
    if not off:
        return 0
    ad.action = None
    tr = ad.nla_tracks.new()
    tr.name = "chow"
    st = tr.strips.new(act.name, 1, act)
    st.frame_start_ui = 1 - off
    st.repeat = 4.0
    st.extrapolation = 'HOLD'
    # strips.new() can leave an EMPTY sibling strip behind. A strip with action=None
    # animates nothing but reads as animation in the NLA editor - drop it.
    for t in list(ad.nla_tracks):
        for s in list(t.strips):
            if s.action is None:
                t.strips.remove(s)
        if not len(t.strips):
            ad.nla_tracks.remove(t)
    bpy.context.view_layer.update()
    return off


def body_yaw(rig):
    """The body's actual world facing, measured off the shoulder line."""
    l = rig.matrix_world @ rig.pose.bones[M + "LeftArm"].head
    r = rig.matrix_world @ rig.pose.bones[M + "RightArm"].head
    side = (l - r)
    fwd = Vector((side.y, -side.x, 0.0))     # shoulder line rotated -90 about Z
    if fwd.length < 1e-6:
        return 0.0
    fwd.normalize()
    return math.atan2(fwd.y, fwd.x)


def plant(rig, want_yaw, want_hip_z=None, want_feet=False, want_xy=None):
    """Aim and seat a man by MEASUREMENT, not by assuming his rig's forward axis.

    Set the yaw, read where the body actually points, correct by the difference;
    then read the hips (or the toes) and correct the height. A clip carries its own
    hip offset - setting obj.location puts the ORIGIN there while the body stands
    somewhere else."""
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    rig.rotation_euler.z += want_yaw - body_yaw(rig)
    bpy.context.view_layer.update()
    if want_xy is not None:
        # PLACE BY THE BODY, NOT THE ORIGIN. The seated clip carries its own hip
        # offset, so setting rig.location to the marker put the ORIGIN on the bench
        # while the man sat half a metre off it - which is what the 0.26 m spacing
        # failure was measuring.
        hips = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
        rig.location.x += want_xy[0] - hips.x
        rig.location.y += want_xy[1] - hips.y
        bpy.context.view_layer.update()
    if want_hip_z is not None:
        hips = (rig.matrix_world @ rig.pose.bones[M + "Hips"].head).z
        rig.location.z += want_hip_z - hips
    elif want_feet:
        toe = min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                  for s in ("Left", "Right"))
        rig.location.z -= toe
    bpy.context.view_layer.update()


def dedupe_images():
    """Collapse image datablocks that differ only by a `.NNN` suffix.

    Appending from us_base_v3.blend drags in its PACKED images, and Blender makes a
    fresh copy every time instead of reusing the one already in the file. Six runs of
    this script left 42 copies of `ref_factions` - a 3600x5700 sheet at 9.1 MB - and
    took the truth source from 9 MB to 398 MB. An orphan purge does not fix it:
    28 of the 42 were referenced by duplicate materials.

    Scoped to numeric-suffix families of matching dimensions. Never a blanket purge.
    """
    fam = {}
    for img in bpy.data.images:
        fam.setdefault(re.sub(r"\.\d+$", "", img.name), []).append(img)

    def image_nodes():
        trees = [m.node_tree for m in bpy.data.materials if m.node_tree]
        trees += [w.node_tree for w in bpy.data.worlds if w.node_tree]
        trees += [g for g in bpy.data.node_groups]
        for t in trees:
            for n in t.nodes:
                if getattr(n, "image", None) is not None:
                    yield n

    merged = 0
    for imgs in fam.values():
        if len(imgs) < 2:
            continue
        imgs.sort(key=lambda i: (len(i.name), i.name))
        keep = imgs[0]
        drop = {o for o in imgs[1:] if tuple(o.size) == tuple(keep.size)}
        if not drop:
            continue
        for node in image_nodes():
            if node.image in drop:
                node.image = keep
        for d in drop:
            bpy.data.images.remove(d)
            merged += 1
    for i in [x for x in bpy.data.images if x.users == 0]:
        bpy.data.images.remove(i)
    packed = sum(i.packed_file.size for i in bpy.data.images if i.packed_file)
    print("  images deduped: merged %d, now %d (%.0f MB packed)"
          % (merged, len(bpy.data.images), packed / 1e6))
    return merged


def purge_previous():
    """Clear anything a previous run of THIS script made.

    Scoped to an explicit name list of data this tool creates - never a blanket
    orphan purge on a shared file. That rule was bought the hard way on 8/2.
    """
    tags = set(STATION_CLIP) | {"eater%d" % i for i in range(64)}
    dead = []
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.rsplit("_", 1)[-1].split(".")[0] in tags \
                and o.name.startswith(("grunt_", "cap_")):
            dead.append(o)
        elif o.type == 'ARMATURE' and o.name.startswith("PSXRig_eater"):
            dead.append(o)
        elif o.name.startswith(("%s_" % DONOR, "grunt_", "cap_")) and o.name.endswith("_" + DONOR):
            dead.append(o)
    for o in dead:
        bpy.data.objects.remove(o, do_unlink=True)
    # AND THE ACTIONS. append_clips() skips any name already present, so leaving a
    # previous run's copy in the file silently pins the OLD clip and every re-author
    # upstream is ignored - the eaters kept a broken pose through a full rebuild.
    for name in CLIPS:
        a = bpy.data.actions.get(name)
        if a:
            bpy.data.actions.remove(a)
    # DEAD NLA STRIPS. PSXRig_cook carried 163 tracks whose strips all had
    # action=None - the wreckage of the 8/2 orphan purge, which removed the actions
    # and left the strips pointing at nothing. They animate nothing and read as a
    # full animation stack in the NLA editor. Fossil law: delete the corpse.
    tracks = strips = 0
    for o in bpy.data.objects:
        if o.type != 'ARMATURE' or not o.name.startswith("PSXRig_"):
            continue
        ad = o.animation_data
        if ad is None:
            continue
        for t in list(ad.nla_tracks):
            for s in list(t.strips):
                if s.action is None:
                    t.strips.remove(s)
                    strips += 1
            if not len(t.strips):
                ad.nla_tracks.remove(t)
                tracks += 1
    if tracks or strips:
        print("  dead NLA cleared: %d strips, %d empty tracks" % (strips, tracks))
    return len(dead)


def main():
    n = purge_previous()
    print("  cleared from a previous run: %d objects" % n)
    got = append_clips()
    print("  clips available: %s" % ", ".join(got))

    rigcoll = bpy.data.collections[RIG_COLL]
    chow = bpy.data.collections[CHOW_COLL]
    parts, strays = append_body()
    print("  donor body parts: %d / %d" % (len(parts), len(BODY)))
    if not parts:
        print("  !! no body appended - aborting")
        return

    made = []

    # 1. the five existing station rigs. Caleb placed these, so their xy and their
    #    facing are his - only the height is corrected, and only onto the ground.
    for tag, clip in STATION_CLIP.items():
        rig = bpy.data.objects.get("PSXRig_%s" % tag)
        if rig is None:
            print("  !! missing PSXRig_%s" % tag)
            continue
        meshes = bind(parts, rig, rigcoll, tag)
        ok = play(rig, clip)
        if ok:
            # Dephase BEFORE planting: the plant measures frame 1, so it has to
            # measure the phase the man will actually be standing at.
            dephase(rig, bpy.data.actions[clip], 23 * len(made))
            stand_up(rig)
            plant(rig, body_yaw(rig), want_feet=True)
        made.append((tag, rig, len(meshes), clip if ok else "NO CLIP"))

    # 2. men eating at the new tables. Seat markers carry the facing (+X axis).
    seats = sorted([o for o in chow.all_objects if o.name.startswith("work_eat")],
                   key=lambda o: o.name)
    # The markers are authored table by table, six per table: three along the south
    # bench then three along the north. Taking every Nth put both men at each table on
    # the SAME bench, staring at an empty seat. Pick one from each bench instead, so
    # they face each other across the table the way men actually eat.
    per_table = 6
    chosen = []
    for t in range(len(seats) // per_table):
        base = t * per_table
        for k in (0, per_table // 2 + 1):
            if base + k < len(seats):
                chosen.append(seats[base + k])
    chosen = chosen[:N_EATERS]
    for i, s in enumerate(chosen):
        arm = bpy.data.armatures.get("PSXRig")
        rig = bpy.data.objects.new("PSXRig_eater%d" % i, arm)
        rigcoll.objects.link(rig)
        w = s.matrix_world
        rig.location = w.translation.copy()
        meshes = bind(parts, rig, rigcoll, "eater%d" % i)
        ok = play(rig, "chow_eat_seated")
        if ok:
            dephase(rig, bpy.data.actions["chow_eat_seated"], 1 + i * 17)
            stand_up(rig)
            # The seat marker's +X axis is the facing (measured off the existing
            # cook/server/queue markers), and the man's hips go one thigh above the
            # bench top - not at the marker's z, which is on the ground.
            face = (w.to_3x3() @ Vector((1.0, 0.0, 0.0)))
            plant(rig, math.atan2(face.y, face.x),
                  want_hip_z=BENCH_TOP + SEAT_HIP_RISE,
                  want_xy=(w.translation.x, w.translation.y))
        made.append(("eater%d @ %s" % (i, s.name), rig, len(meshes),
                     "chow_eat_seated" if ok else "NO CLIP"))

    # 3. the donor and the proxies are both dead now
    for o in parts:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in strays:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except ReferenceError:
            pass
    proxies = [o for o in bpy.data.objects if o.name.startswith("proxy_body")]
    for o in proxies:
        bpy.data.objects.remove(o, do_unlink=True)
    print("  proxy_body placeholders removed: %d" % len(proxies))

    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()

    # ---- verify: numbers before pictures ------------------------------------
    fails = []
    sc = bpy.context.scene
    print("\n%-22s %-13s %-6s %-7s %-7s %-6s %s"
          % ("man", "at", "meshes", "hips z", "toe z", "euler", "clip"))
    hips_xy = []
    for tag, rig, n, clip in made:
        sc.frame_set(1)
        bpy.context.view_layer.update()
        hips = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
        toe = min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                  for s in ("Left", "Right"))
        eul = sum(1 for pb in rig.pose.bones if pb.rotation_mode != 'QUATERNION')
        hips_xy.append((tag, hips))
        print("%-22s %-13s %-6d %7.3f %7.3f %6d %s"
              % (tag, "%.1f,%.1f" % (hips.x, hips.y), n, hips.z, toe, eul, clip))
        head = (rig.matrix_world @ rig.pose.bones[M + "Head"].head).z
        if head < hips.z + 0.25:
            fails.append("%s: head %.3f is not above hips %.3f - man is not upright"
                         % (tag, head, hips.z))
        if toe > hips.z:
            fails.append("%s: feet %.3f above hips %.3f" % (tag, toe, hips.z))
        if eul:
            fails.append("%s: %d pose bones still in euler mode" % (tag, eul))
        if toe < -0.05:
            fails.append("%s: feet %.3f m through the floor" % (tag, toe))
        if tag.startswith("eater") and abs(hips.z - (BENCH_TOP + SEAT_HIP_RISE)) > 0.05:
            fails.append("%s: seated hips %.3f, wanted %.3f"
                         % (tag, hips.z, BENCH_TOP + SEAT_HIP_RISE))
    for i in range(len(hips_xy)):
        for j in range(i + 1, len(hips_xy)):
            d = (hips_xy[i][1] - hips_xy[j][1]).length
            if d < 0.42:
                fails.append("%s/%s only %.2f m apart"
                             % (hips_xy[i][0], hips_xy[j][0], d))
    print("\n  %s" % ("CREW GATES PASS" if not fails else "CREW GATE FAILURES:"))
    for f in fails:
        print("    !!", f)

    tris = sum(sum(len(pl.vertices) - 2 for pl in o.data.polygons)
               for o in rigcoll.all_objects if o.type == 'MESH')
    print("\n  %s: %d objects, %d tris (linked dupes share mesh data)"
          % (RIG_COLL, len(rigcoll.all_objects), tris))

    dedupe_images()

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED", bpy.data.filepath)
    else:
        print("  dry run (pass --save to write)")


main()
