"""Dress the medical complex with real US grunt v3 bodies running the med clips.

    blender -b "<firebase>.blend" -P tools/gen_medical_crew.py -- [--save]

Truth source: firebase_v3.1_RECOVERED_medical.blend, object `medical_complex`
(BUILDINGS/bld_medical_complex), 40 markers Caleb hand-placed. NEVER regenerate
or "fix" his marker positions - measure and use them as given.

Same donor-swap architecture as tools/gen_chowhall_crew.py: BODY parts are
linked duplicates of a donor's grunt_*/cap_* meshes, no gear appended unless
the role needs it. Three donors this time (all already exist in
us_base_v3.blend, none built for this job):
    rifleman - generic, unarmed, for the wounded and for logistics roles
    medic    - grunt_*_medic set + medic_brassard/satchel, for anyone
               identifiably medical staff (rounds, desk, tend, bearers)
    surgeon  - grunt_*_surgeon set + apron_front/mask_face/scrub_cap, for the
               OR table and its immediate support (already gowned in the source
               file - built for exactly this scene, never used before)

MARKER FACING. Measured three ways on the chow hall (never assumed): here the
convention is the SAME (+X local -> world facing) but the marker's own +X
varies per marker depending which way the station faces, exactly like chow
hall's cook/server stations. Confirmed by inspection during the inventory
pass, not re-derived here.

FLOOR IS NOT AT WORLD Z=0. The medical complex sits on a raised mound: every
marker reads z=4.251 (the mound-top floor) or z=4.771 for the stretcher
markers (raised 0.52 m on trestles) - unlike chow hall's WORKBENCH which was
built directly on the world floor. plant() here takes an explicit floor_z per
call; do not reuse chow hall's grounding math unmodified (it hardcodes 0).
"""
import bpy, os, sys, math, re
from mathutils import Vector, Matrix, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ASSETS, US_BASE_V3

CLIP_BLEND = os.path.join(ASSETS, "shared", "med_anim_workbench.blend")
MED_OBJ = "medical_complex"
DONOR_RIFLEMAN = "rifleman"
DONOR_MEDIC = "medic"
DONOR_SURGEON = "surgeon"
M = "mixamorig:"

BODY = ('grunt_torso', 'grunt_head', 'grunt_leg_l', 'grunt_leg_r',
        'grunt_forearm_l', 'grunt_forearm_r', 'grunt_uparm_l', 'grunt_uparm_r',
        'cap_torso', 'cap_head', 'cap_leg_l', 'cap_leg_r',
        'cap_forearm_l', 'cap_forearm_r', 'cap_uparm_l', 'cap_uparm_r')
# surgeon donor also wears these - identifies him as OR staff at a glance.
SURGEON_EXTRA = ('apron_front', 'mask_face', 'scrub_cap')
MEDIC_EXTRA = ('medic_brassard',)

CLIPS_NEEDED = ["med_rounds_glance", "med_officer_desk", "med_surgeon_table",
                "med_or_support_high", "med_or_support_low", "med_wounded_idle",
                "med_tend_medic", "med_tend_patient", "med_bearer_front",
                "med_bearer_rear"]

# station marker -> (clip, donor, extra-gear tuple, dephase step)
# grouped exactly as measured in the inventory pass (ART_Track_Log / this session)
STANDING_STATIONS = {
    "work_ward_round_0": ("med_rounds_glance", DONOR_MEDIC, MEDIC_EXTRA),
    "work_ward_round_1": ("med_rounds_glance", DONOR_MEDIC, MEDIC_EXTRA),
    "work_ward_round_2": ("med_rounds_glance", DONOR_MEDIC, MEDIC_EXTRA),
    "work_ward_round_3": ("med_rounds_glance", DONOR_MEDIC, MEDIC_EXTRA),
    "work_triage":       ("med_rounds_glance", DONOR_MEDIC, MEDIC_EXTRA),
    "work_surgeon_N":    ("med_surgeon_table", DONOR_SURGEON, SURGEON_EXTRA),
    "work_surgeon_S":    ("med_surgeon_table", DONOR_SURGEON, SURGEON_EXTRA),
    "work_scrubnurse_N": ("med_or_support_high", DONOR_SURGEON, SURGEON_EXTRA),
    "work_scrubnurse_S": ("med_or_support_high", DONOR_SURGEON, SURGEON_EXTRA),
    "work_scrub":        ("med_or_support_high", DONOR_MEDIC, MEDIC_EXTRA),
    "work_wash.009":     ("med_or_support_high", DONOR_MEDIC, MEDIC_EXTRA),
    "work_anesthetist_2": ("med_or_support_low", DONOR_SURGEON, SURGEON_EXTRA),
    "work_anesthetist_5": ("med_or_support_low", DONOR_SURGEON, SURGEON_EXTRA),
    "work_sterilizer_7": ("med_or_support_low", DONOR_SURGEON, SURGEON_EXTRA),
    "work_supply_N":     ("med_or_support_low", DONOR_RIFLEMAN, ()),
    "work_supply_S":     ("med_or_support_low", DONOR_RIFLEMAN, ()),
    "work_litter_rack":  ("med_or_support_low", DONOR_RIFLEMAN, ()),
}
SEATED_STATIONS = {
    "work_medofficer_0": ("med_officer_desk", DONOR_MEDIC, MEDIC_EXTRA),
    "work_medofficer_1": ("med_officer_desk", DONOR_MEDIC, MEDIC_EXTRA),
    "work_medofficer_2": ("med_officer_desk", DONOR_MEDIC, MEDIC_EXTRA),
}
SEATED_HIP_Z_ABOVE_FLOOR = 0.56   # sitting_idle_b's own natural seated hip height

# two of the sixteen stretchers get the active tend vignette; the rest get the
# plain breathing idle. One per row (row1 y ~-2, row2 y ~-12), picked by index.
TEND_STRETCHERS = ("prop_wounded_00", "prop_wounded_08")
WOUNDED_HIP_LOCAL_Z = 0.116   # med_wounded_idle's own hips.z, frame 1, rot=0
# Measured after first dressing pass: hips placed exactly at the stretcher
# marker sinks the RESTING right elbow ~0.05 m into the trestle/canvas on
# every one of the 14 plain-idle men (systematic, not per-man noise - all 14
# read 0.045-0.054 m) and both hands of the 2 active tend-patients ~0.02-0.05
# m. Lifting the whole body clears it without touching the clip.
WOUNDED_HIP_CLEARANCE = 0.09
# Re-measured at 0.06 m: right elbow cleared (0.001-0.005 m residual) but the
# left elbow, untouched at clearance=0, picked up a NEW 0.011-0.026 m
# penetration - the resting arms are not clipping a flat canvas, they are
# clipping the trestle's raised side rail, which is not level across X.
# 0.09 m is the best single uniform lift for both sides; a residual is
# reported below rather than chased further with a per-man correction.

BEARER_MARKER = "med_bearer_formup"
BEARER_SPACING = 1.9   # measured litter footprint (medical_complex verts near a
                        # prop_wounded marker span ~2.3 m; 1.9 m between the two
                        # bearers' own hip positions leaves room front/rear).


def append_clips():
    d = CLIP_BLEND + os.sep + "Action" + os.sep
    got = []
    for name in CLIPS_NEEDED:
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


def append_body(donor, extra=()):
    """Append one donor's body (+ any identifying extras). Donor rig discarded."""
    d = US_BASE_V3 + os.sep + "Object" + os.sep
    before = set(bpy.data.objects)
    parts = []
    for base in BODY + extra:
        nm = "%s_%s" % (base, donor)
        try:
            bpy.ops.wm.append(directory=d, filename=nm)
        except RuntimeError as ex:
            print("  body append failed %s: %s" % (nm, ex))
            continue
        o = bpy.data.objects.get(nm)
        if o and o.type == 'MESH':
            parts.append(o)
    strays = [o for o in set(bpy.data.objects) - before if o.type == 'ARMATURE']
    return parts, strays


def bind(parts, rig, coll, tag):
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.duplicate(linked=True)
    made = [o for o in bpy.context.selected_objects if o.type == 'MESH']
    for o in made:
        base = o.name.split('.')[0]
        for suf in ("_rifleman", "_medic", "_surgeon"):
            base = base[:-len(suf)] if base.endswith(suf) else base
        o.name = base + "_" + tag
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
    """QUATERNION mode on every pose bone before assigning - see gen_chowhall_
    crew.py's play() for the measured bug this prevents."""
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
    """Quarter-turn stand-up, unchanged from gen_chowhall_crew.py. Only call
    this for STANDING/SEATED clips (up axis convention differs per source
    clip, snapped to a right angle rather than aligned exactly - see that
    file's comment). Never call it for med_wounded_idle or the tend pair -
    those clips are meant to stay lying down; see lie_align() instead."""
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
    ad = rig.animation_data
    span = int(act.frame_range[1] - act.frame_range[0]) + 1
    off = offset % span
    if not off:
        return 0
    ad.action = None
    tr = ad.nla_tracks.new()
    tr.name = "med"
    st = tr.strips.new(act.name, 1, act)
    st.frame_start_ui = 1 - off
    st.repeat = 4.0
    st.extrapolation = 'HOLD'
    for t in list(ad.nla_tracks):
        for s in list(t.strips):
            if s.action is None:
                t.strips.remove(s)
        if not len(t.strips):
            ad.nla_tracks.remove(t)
    bpy.context.view_layer.update()
    return off


def body_yaw(rig):
    """Standing-body facing, off the shoulder line. Unchanged from chow hall."""
    l = rig.matrix_world @ rig.pose.bones[M + "LeftArm"].head
    r = rig.matrix_world @ rig.pose.bones[M + "RightArm"].head
    side = (l - r)
    fwd = Vector((side.y, -side.x, 0.0))
    if fwd.length < 1e-6:
        return 0.0
    fwd.normalize()
    return math.atan2(fwd.y, fwd.x)


def lie_yaw(rig):
    """A LYING body's facing: the hips-to-head direction projected to the
    ground plane, not the shoulder line (which is nearly vertical/undefined
    when a man is on his back)."""
    hips = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
    head = rig.matrix_world @ rig.pose.bones[M + "Head"].head
    d = Vector((head.x - hips.x, head.y - hips.y, 0.0))
    if d.length < 1e-6:
        return 0.0
    d.normalize()
    return math.atan2(d.y, d.x)


def plant(rig, want_yaw, floor_z, want_hip_z=None, want_feet=False, want_xy=None,
          yaw_fn=body_yaw):
    """Same recipe as gen_chowhall_crew.plant(), generalised: takes an
    explicit floor_z (the medical complex sits at z ~4.25-4.77, not on the
    world floor) and an optional yaw_fn (lie_yaw for a supine body)."""
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    rig.rotation_euler.z += want_yaw - yaw_fn(rig)
    bpy.context.view_layer.update()
    if want_xy is not None:
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
        rig.location.z += floor_z - toe
    bpy.context.view_layer.update()


def facing_yaw(marker):
    w = marker.matrix_world
    f = w.to_3x3() @ Vector((1.0, 0.0, 0.0))
    return math.atan2(f.y, f.x)


def dedupe_images():
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
    """Scoped to an explicit tag list this tool creates - never a blanket
    orphan purge on a shared file."""
    tags = (set(STANDING_STATIONS) | set(SEATED_STATIONS)
            | {"wounded%d" % i for i in range(20)}
            | {"tend_medic0", "tend_medic1", "bearer_front", "bearer_rear"})
    dead = []
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.rsplit("_", 1)[-1] in tags \
                and o.name.startswith(("grunt_", "cap_", "apron_", "mask_",
                                       "scrub_", "medic_brassard")):
            dead.append(o)
        elif o.type == 'ARMATURE' and o.name.startswith("PSXRig_med"):
            dead.append(o)
        elif o.name.startswith(("rifleman_", "medic_", "surgeon_")) and \
                o.name.split(".")[0].rsplit("_", 1)[-1] in ("rifleman", "medic", "surgeon"):
            dead.append(o)
    for o in dead:
        bpy.data.objects.remove(o, do_unlink=True)
    for name in CLIPS_NEEDED:
        a = bpy.data.actions.get(name)
        if a:
            bpy.data.actions.remove(a)
    tracks = strips = 0
    for o in bpy.data.objects:
        if o.type != 'ARMATURE' or not o.name.startswith("PSXRig_med"):
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
    return len(dead)


_ARM_DATA = [None]


def rig_armature_data():
    """The truth-source firebase file has no PSXRig armature of its own (chow
    hall's gen_chowhall_crew.py could rely on bpy.data.armatures.get("PSXRig")
    only because some earlier append already left one in that file). Import
    the armature data once from the clip workbench and keep it alive with a
    fake user, then every station rig shares that one data-block."""
    if _ARM_DATA[0] is not None:
        return _ARM_DATA[0]
    d = CLIP_BLEND + os.sep + "Object" + os.sep
    before = set(bpy.data.objects)
    bpy.ops.wm.append(directory=d, filename="PSXRig")
    made = [o for o in bpy.data.objects if o not in before]
    src = next((o for o in made if o.type == 'ARMATURE'), None)
    if src is None:
        raise RuntimeError("PSXRig object not found in %s" % CLIP_BLEND)
    arm = src.data
    arm.use_fake_user = True
    bpy.data.objects.remove(src, do_unlink=True)
    _ARM_DATA[0] = arm
    return arm


RIG_BASELINE_X = math.radians(90.0)
# EVERY med_* clip on this rig needs the SAME +90 deg X object rotation, not a
# per-clip search. Measured directly (diag_lie2.py, this session) across six
# clip families with a rig freshly created at rotation=0: hips.z read ~0 for
# ALL of them at X=0 (a standing man's hips at the origin, i.e. lying on his
# side) and the correct standing/seated/lying height only appears at X=90
# (hips.z 0.46-0.97 matching each clip's real hip height; the two lying
# clips' hip/toe/head Z SPREAD also minimises at X=90, 0.228 m vs 1.623 m at
# X=0). This is a property of med_anim_workbench.blend's saved PSXRig object
# (which itself carried rotation_euler (90,0,0) at save time - inherited from
# anim_library.blend's shared authoring rig, not tied to any one clip), not
# of the armature DATA, so a freshly-created object must reapply it.
#
# stand_up()'s pose-dependent "maximise up.z" search is NOT used for this -
# it false-triggered on med_or_support_low's own ~70 deg forward lean at the
# loop's deep-lean phase (two dephased instances flipped onto their backs:
# hips.z crashed to floor+0.27 against every sibling's floor+0.97). A fixed,
# measured constant is the correct tool when the whole rig family shares one
# convention; a per-frame heuristic is not.


def new_rig(name, rigcoll):
    arm = rig_armature_data()
    rig = bpy.data.objects.new(name, arm)
    rigcoll.objects.link(rig)
    rig.rotation_euler = (RIG_BASELINE_X, 0.0, 0.0)
    bpy.context.view_layer.update()
    return rig


PREVIEW_DIR = os.path.join(os.path.dirname(ASSETS), "_scratch", "med_preview", "scene")


def render_previews(made):
    """Numbers already passed; these stills are for Caleb's eye, not a gate."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scn = bpy.context.scene
    scn.render.resolution_x = 1400
    scn.render.resolution_y = 900
    try:
        scn.render.engine = 'BLENDER_EEVEE_NEXT'
    except Exception:
        pass

    # This is a tent interior with a working roof mesh - a shadow-casting sun
    # leaves it pitch black (first pass: every render came back solid black).
    # use_shadow=False is a review-only compromise, not a lighting pass.
    sun = bpy.data.objects.get("MedPreviewSun")
    if sun is None:
        light = bpy.data.lights.new("MedPreviewSun", 'SUN')
        light.energy = 2.5
        light.use_shadow = False
        sun = bpy.data.objects.new("MedPreviewSun", light)
        bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (0.9, 0, 0.7)
    fill = bpy.data.objects.get("MedPreviewFill")
    if fill is None:
        fdata = bpy.data.lights.new("MedPreviewFill", 'SUN')
        fdata.energy = 1.2
        fdata.use_shadow = False
        fill = bpy.data.objects.new("MedPreviewFill", fdata)
        bpy.context.collection.objects.link(fill)
    fill.rotation_euler = (-1.0, 0.3, -1.4)

    cam_data = bpy.data.cameras.get("MedPreviewCam")
    if cam_data is None:
        cam_data = bpy.data.cameras.new("MedPreviewCam")
    cam = bpy.data.objects.get("MedPreviewCam")
    if cam is None:
        cam = bpy.data.objects.new("MedPreviewCam", cam_data)
        bpy.context.collection.objects.link(cam)
    scn.camera = cam

    target = bpy.data.objects.get("MedPreviewTarget")
    if target is None:
        target = bpy.data.objects.new("MedPreviewTarget", None)
        bpy.context.collection.objects.link(target)
        con = cam.constraints.new('TRACK_TO')
        con.target = target
        con.track_axis = 'TRACK_NEGATIVE_Z'
        con.up_axis = 'UP_Y'

    shots = [
        ("ward_row1", (67.0, -2.5, 5.6), (63.0, -2.5, 4.9)),
        ("ward_tend", (68.5, -1.0, 6.0), (67.5, -1.5, 4.9)),
        ("or_table", (76.0, -6.5, 6.2), (75.0, -6.0, 5.0)),
        ("med_officer", (56.5, 3.0, 5.6), (54.5, 4.2, 4.8)),
        ("bearers", (58.0, -10.0, 6.2), (56.5, -7.9, 5.0)),
    ]
    for name, cam_pos, tgt_pos in shots:
        cam.location = cam_pos
        target.location = tgt_pos
        bpy.context.view_layer.update()
        scn.render.filepath = os.path.join(PREVIEW_DIR, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("  rendered", scn.render.filepath)


def main():
    n = purge_previous()
    print("  cleared from a previous run: %d objects" % n)
    got = append_clips()
    print("  clips available: %s" % ", ".join(got))

    med = bpy.data.objects.get(MED_OBJ)
    if med is None:
        print("  !! medical_complex not found - aborting")
        return
    floor_z = med.matrix_world.translation.z
    print("  medical_complex floor z: %.3f" % floor_z)

    scn = bpy.context.scene
    rigcoll = bpy.data.collections.get("WORKBENCH_medical_tent")
    if rigcoll is None:
        rigcoll = bpy.data.collections.new("WORKBENCH_medical_tent")
        scn.collection.children.link(rigcoll)

    def marker(name):
        return bpy.data.objects.get(name)

    donors_cache = {}

    def get_body(donor, extra):
        key = (donor, extra)
        if key not in donors_cache:
            donors_cache[key] = append_body(donor, extra)
        return donors_cache[key]

    made = []
    phase = 0

    # ---- 1. standing stations -------------------------------------------
    for mk_name, (clip, donor, extra) in STANDING_STATIONS.items():
        mk = marker(mk_name)
        if mk is None:
            print("  !! missing marker %s" % mk_name)
            continue
        parts, strays = get_body(donor, extra)
        if not parts:
            continue
        rig = new_rig("PSXRig_med_%s" % mk_name.replace(".", "_"), rigcoll)
        meshes = bind(parts, rig, rigcoll, mk_name.replace(".", "_"))
        ok = play(rig, clip)
        if ok:
            dephase(rig, bpy.data.actions[clip], 19 * phase)
            phase += 1
            # NO stand_up() here: unlike chow hall's chow_eat_seated (a genuine
            # Y-up source-clip convention), all 5 med station clips are built
            # already Z-up on THIS rig. stand_up()'s up.z<0.85 heuristic
            # false-triggers on med_or_support_low's own ~70 deg forward lean at
            # its loop peak and flips the man onto his back - measured: hips.z
            # crashed to 4.520 (floor+0.27) against every sibling's 5.22
            # (floor+0.97) at the SAME station type, phase-dependent only.
            plant(rig, facing_yaw(mk), floor_z, want_feet=True,
                  want_xy=(mk.matrix_world.translation.x, mk.matrix_world.translation.y))
        made.append((mk_name, rig, len(meshes), clip if ok else "NO CLIP"))

    # ---- 2. seated med officers -------------------------------------------
    for mk_name, (clip, donor, extra) in SEATED_STATIONS.items():
        mk = marker(mk_name)
        if mk is None:
            print("  !! missing marker %s" % mk_name)
            continue
        parts, strays = get_body(donor, extra)
        if not parts:
            continue
        rig = new_rig("PSXRig_med_%s" % mk_name, rigcoll)
        meshes = bind(parts, rig, rigcoll, mk_name)
        ok = play(rig, clip)
        if ok:
            dephase(rig, bpy.data.actions[clip], 13 * phase)
            phase += 1
            plant(rig, facing_yaw(mk), floor_z,
                  want_hip_z=floor_z + SEATED_HIP_Z_ABOVE_FLOOR,
                  want_xy=(mk.matrix_world.translation.x, mk.matrix_world.translation.y))
        made.append((mk_name, rig, len(meshes), clip if ok else "NO CLIP"))

    # ---- 3. sixteen stretchers: 14 plain idle + 2 active tend --------------
    wounded_parts, _ = get_body(DONOR_RIFLEMAN, ())
    medic_parts, _ = get_body(DONOR_MEDIC, MEDIC_EXTRA)
    tend_i = 0
    for i in range(16):
        mk_name = "prop_wounded_%02d" % i
        mk = marker(mk_name)
        if mk is None:
            print("  !! missing marker %s" % mk_name)
            continue
        wx, wy, wz = mk.matrix_world.translation

        if mk_name in TEND_STRETCHERS:
            # patient: med_tend_patient, aligned lying-down like the plain idle
            prig = new_rig("PSXRig_med_tend_patient%d" % tend_i, rigcoll)
            meshes = bind(wounded_parts, prig, rigcoll, "tend_patient%d" % tend_i)
            ok = play(prig, "med_tend_patient")
            if ok:
                bpy.context.scene.frame_set(1)
                bpy.context.view_layer.update()
                plant(prig, facing_yaw(mk), floor_z,
                      want_hip_z=wz + WOUNDED_HIP_CLEARANCE, want_xy=(wx, wy),
                      yaw_fn=lie_yaw)
            made.append((mk_name + " (patient)", prig, len(meshes),
                         "med_tend_patient" if ok else "NO CLIP"))

            # medic: med_tend_medic. medic_treat_give/receive were captured
            # TOGETHER sharing one authoring origin (both at object loc=0,
            # X90 baseline, no yaw) - giver hips (0.358,0.277,0.46) vs
            # receiver hips (0.83,-0.39,0.069) at frame 1 IS their correct
            # relative arrangement already. Solving for where the medic's
            # OBJECT ORIGIN must sit (target_world_hips = obj.location +
            # Rz(yaw)@local_hips) and expanding shows obj.location must equal
            # prig.location exactly, for ANY yaw - the two pose-local hip
            # vectors and the delta between them cancel algebraically. An
            # earlier version of this rotated a hand-measured delta onto
            # prig.location and double-counted the medic's own local hip
            # offset, floating him 0.4 m above a standing man's own hip
            # height (5.552 against floor+0.97 - a kneeling medic cannot be
            # taller than a standing one). Fixed: same location, same yaw.
            yaw = prig.rotation_euler.z
            mrig = new_rig("PSXRig_med_tend_medic%d" % tend_i, rigcoll)
            meshes2 = bind(medic_parts, mrig, rigcoll, "tend_medic%d" % tend_i)
            ok2 = play(mrig, "med_tend_medic")
            if ok2:
                mrig.rotation_euler.z = yaw
                mrig.location = prig.location.copy()
                bpy.context.view_layer.update()
            made.append((mk_name + " (medic)", mrig, len(meshes2),
                        "med_tend_medic" if ok2 else "NO CLIP"))
            tend_i += 1
        else:
            rig = new_rig("PSXRig_med_wounded%d" % i, rigcoll)
            meshes = bind(wounded_parts, rig, rigcoll, "wounded%d" % i)
            ok = play(rig, "med_wounded_idle")
            if ok:
                dephase(rig, bpy.data.actions["med_wounded_idle"], 41 * i)
                plant(rig, facing_yaw(mk), floor_z,
                      want_hip_z=wz + WOUNDED_HIP_CLEARANCE, want_xy=(wx, wy),
                      yaw_fn=lie_yaw)
            made.append((mk_name, rig, len(meshes), "med_wounded_idle" if ok else "NO CLIP"))

    # ---- 4. stretcher-bearer pair, forming up (lift/stand-by, not the walk) -
    bmk = marker(BEARER_MARKER)
    if bmk is not None:
        fwd = (bmk.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0)))
        fwd.z = 0.0
        fwd.normalize()
        byaw = math.atan2(fwd.y, fwd.x)
        bx, by, bz = bmk.matrix_world.translation
        bearer_parts, _ = get_body(DONOR_MEDIC, MEDIC_EXTRA)

        front = new_rig("PSXRig_med_bearer_front", rigcoll)
        meshes = bind(bearer_parts, front, rigcoll, "bearer_front")
        ok = play(front, "med_bearer_front")
        if ok:
            plant(front, byaw, floor_z, want_feet=True, want_xy=(bx, by))
        made.append((BEARER_MARKER + " (front)", front, len(meshes),
                    "med_bearer_front" if ok else "NO CLIP"))

        rear = new_rig("PSXRig_med_bearer_rear", rigcoll)
        meshes2 = bind(bearer_parts, rear, rigcoll, "bearer_rear")
        ok2 = play(rear, "med_bearer_rear")
        if ok2:
            rx = bx - fwd.x * BEARER_SPACING
            ry = by - fwd.y * BEARER_SPACING
            plant(rear, byaw, floor_z, want_feet=True, want_xy=(rx, ry))
        made.append((BEARER_MARKER + " (rear)", rear, len(meshes2),
                    "med_bearer_rear" if ok2 else "NO CLIP"))
    else:
        print("  !! missing marker %s" % BEARER_MARKER)

    # ---- cleanup: donors and any stray armatures ---------------------------
    for (parts, strays) in donors_cache.values():
        for o in parts:
            bpy.data.objects.remove(o, do_unlink=True)
        for o in strays:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except ReferenceError:
                pass

    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()

    # ---- verify: numbers before pictures ------------------------------------
    fails = []
    print("\n%-30s %-16s %-6s %-7s %-7s %s"
          % ("man", "at", "meshes", "hips z", "toe z", "clip"))
    hips_xy = []
    for tag, rig, nmesh, clip in made:
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        hips = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
        toe = min((rig.matrix_world @ rig.pose.bones[M + s + "ToeBase"].head).z
                  for s in ("Left", "Right"))
        eul = sum(1 for pb in rig.pose.bones if pb.rotation_mode != 'QUATERNION')
        hips_xy.append((tag, hips))
        print("%-30s %-16s %-6d %7.3f %7.3f  %s"
              % (tag, "%.1f,%.1f" % (hips.x, hips.y), nmesh, hips.z, toe, clip))
        if eul:
            fails.append("%s: %d pose bones still in euler mode" % (tag, eul))
        if clip == "NO CLIP":
            fails.append("%s: clip failed to assign" % tag)

    # ---- elbow-vs-scene-geometry: permanent law, checked against the REAL
    # mesh now that the men are dressed at the real markers (the authoring
    # gate in make_medical_anims.py only checked elbow-vs-own-torso).
    #
    # Ray-parity against `medical_complex` is the WRONG tool here: it is one
    # mesh covering the whole tent shell (walls+roof+floor+furniture), so a
    # ray-parity "inside" test returns True for every man standing inside the
    # building - not a collision, just "in the room". First pass flagged 45
    # of 49 men on exactly that false positive. closest_point_on_mesh + a
    # normal-side check (is the elbow BEHIND the nearest surface, from a
    # short capture radius) tells embedded-in-a-solid apart from
    # standing-in-a-room; distance alone cannot.
    med_inv = med.matrix_world.inverted()

    def elbow_embedded(pt, capture=0.06):
        local = med_inv @ pt
        ok_h, loc, nrm, idx = med.closest_point_on_mesh(local)
        if not ok_h:
            return False, 9.9
        d = (loc - local).length
        if d > capture:
            return False, d
        behind = (local - loc).dot(nrm) < 0.0
        return behind, d

    elbow_fails = []
    for tag, rig, nmesh, clip in made:
        if clip == "NO CLIP":
            continue
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        for s in ("Left", "Right"):
            try:
                elbow = rig.matrix_world @ rig.pose.bones[M + s + "ForeArm"].head
            except KeyError:
                continue
            embedded, dist = elbow_embedded(elbow)
            if embedded:
                elbow_fails.append("%s: %s elbow %.3f m inside medical_complex surface"
                                   % (tag, s, dist))
    if elbow_fails:
        fails.extend(elbow_fails)
    print("  elbow-vs-geometry: %d flagged / %d checked"
          % (len(elbow_fails), 2 * sum(1 for _, _, _, c in made if c != "NO CLIP")))

    print("\n  %s" % ("CREW GATES PASS" if not fails else "CREW GATE FAILURES:"))
    for f in fails:
        print("    !!", f)

    # ---- preview renders ----------------------------------------------------
    if "--preview" in sys.argv:
        render_previews(made)

    dedupe_images()

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED", bpy.data.filepath)
    else:
        print("  dry run (pass --save to write)")


main()
