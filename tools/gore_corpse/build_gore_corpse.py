"""Gore corpse - ONE whole man, gutted, as a static world prop (Caleb 2026-09-12: "the gore piles
arent quite what i was thinking. lets make just one person gored out with their guts and maggots").

    blender -b --factory-startup --python tools/gore_corpse/build_gore_corpse.py -- [--norender] [--stop=pose|viscera] [--faction=us]

Stage A  append the READ-ONLY donor (US: us_base_v3.blend PSXRig + us_grunt_joined; the M1 from
         helmet_variants.blend), pose the death on the BONES (world-axis rotations about each bone
         head, the rig's own X+90 never touched), every contact solved by measurement against the
         ground plane, then bake the evaluated mesh to a static one. v2 (Caleb's review of v1:
         "the leg in the air doesnt look right ... make sure youre not twisting the arms so they
         make weird spun up elbows"): both legs FLAT (thigh, calf, boot each gated within 5 mm of
         the ground), arms posed by shoulder rotation + a hinge bend only - the forearm's roll
         about its own axis is measured from matrix_basis and gated <= 15 deg, the elbow bend
         0..60 deg, and the elbow point must face down/out (never up).
Stage B  open the belly (sternum -> pelvis) on the static mesh: rim, torn-cloth flaps, a costal
         (rib) strip on the pale bone disc, a dark pocket; ONE continuous small intestine (12
         sides, smooth, r 16 mm, its own painted 128^2 viscera strip: pink-grey, a crease every
         40 mm, a wet stripe on top, blood only at the two torn ends) laid in tight hairpin loops
         on the cavity floor, over the -X flap, down the flank and into more loops on the ground;
         dark-red mesentery fans inside each hairpin; the liver under the costal wall; blood pool
         + drag smear; the wound ring on the cloth edge; the slack jaw + dark mouth.
Stage C  helmet fallen beside the head (settle + tilt_settle from the piles), maggots as GEOMETRY
         (an 8-tri grub instanced ~150x in clumps: the two gut tears, the cavity rim, the mouth,
         the eye corner, the pool edge) over two small 2-frame decal patches, all on one
         `maggot_mass` node, fx anchors, join, clean, bake uniform/skin/helmet/viscera into ONE
         atlas (gore stays on the shared 128^2 gore sheet = second material), convex-hull
         collider, GLB, manifest, renders, studio .blend.

Faction re-dress: FACTIONS[...] names the donor file, rig, body object(s) and headgear; the pose,
belly cut, viscera and export are body-agnostic (they work on the baked world-space mesh by
geometric band). NVA/VC entries are declared but only "us" is built here.

Writes:  assets/world/props/gore_corpse.blend
         assets/world/props/gore_corpse/gore_corpse_<faction>.glb
         assets/world/props/gore_corpse/gore_corpse_<faction>_atlas.png
         assets/world/props/gore_corpse/maggots_a.png / maggots_b.png (the piles' writer)
         assets/world/props/gore_corpse/gore_corpse_manifest.json
         assets/world/props/gore_corpse/gore_corpse_viscera.png (source strip; baked into the atlas)
         production/renders_conquest_of_worms/gore_corpse_<faction>_{4m,1p5m,top,face,guts,maggots}.png
Never touches the donor files. Never opens a window.
"""
import bpy, bmesh, math, os, sys, json, random
from mathutils import Vector, Matrix, Euler, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "gore_piles"))
import donors
import build_gore_piles as gp

ROOT = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.join(ROOT, "assets", "world", "props", "gore_corpse")
BLEND_OUT = os.path.join(ROOT, "assets", "world", "props", "gore_corpse.blend")
RENDER_DIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NORENDER = "--norender" in ARGS
STOP = None
FACTION = "us"
for a in ARGS:
    if a.startswith("--stop="):
        STOP = a.split("=", 1)[1]
    if a.startswith("--faction="):
        FACTION = a.split("=", 1)[1]

BUDGET = 2200
GUT_R = 0.016          # small intestine ~2.5-3 cm across (Cleveland Clinic: jejunum ~2.5 cm)
GUT_SIDES = 12
RING_STEP = 0.036
GUT_PITCH = 0.038      # centre-to-centre of adjacent hairpin runs (tube 32 mm + a 6 mm mesentery gap)
HAIRPIN_R = 0.019
RING_TURN_DEG = 22.0   # a ring wherever the centreline has turned this much, else every RING_STEP
ATLAS_RES = 1024
random.seed(19)

FACTIONS = {
    # body: object(s) to append and (if several) join; rig: armature; hat: (file, object)
    "us":  {"file": donors.US_BLEND, "rig": "PSXRig", "body": ["us_grunt_joined"], "gore_carrier": "cap_torso",
            "hat": (donors.HELM_BLEND, "helm_cover"), "hat_ratio": 0.45, "face_mat": "face_atlas_mat"},
    # declared, not built: same mixamorig family, rig scale 0.952 baked into the world matrix
    "nva": {"file": donors.NVA_BLEND, "rig": "PSXRig", "body": ["grunt_" + p for p in donors.PIECES], "gore_carrier": "cap_head",
            "hat": (donors.NVA_BLEND, "pith_helmet_worn"), "hat_ratio": 1.0, "face_mat": "Skin_VC"},
    "vc":  {"file": donors.NVA_BLEND, "rig": "vc_sapper_PSXRig", "body": ["vc_sapper_joined"], "gore_carrier": "cap_head",
            "hat": (donors.NVA_BLEND, "rice_hat"), "hat_ratio": 1.0, "face_mat": "Skin_VC"},
}

GROUND = 0.0


def log(*a):
    print("[corpse]", *a, flush=True)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(obj):
    return gp.bounds(obj)


# ------------------------------------------------------------------ Stage A: pose on the bones
def bone(rig, short):
    return donors._bone(rig, short)


def rot_world(rig, short, axis_w, deg):
    """Rotate a pose bone about a WORLD axis through its own head. Children follow (their
    matrix_basis is untouched). The rig object's transform is never written."""
    pb = bone(rig, short)
    bpy.context.view_layer.update()
    Mw = rig.matrix_world
    head_w = Mw @ pb.head
    R = Matrix.Rotation(math.radians(deg), 4, Vector(axis_w).normalized())
    T = Matrix.Translation(head_w)
    new_w = T @ R @ T.inverted() @ (Mw @ pb.matrix)
    pb.matrix = Mw.inverted() @ new_w
    bpy.context.view_layer.update()


def eval_world_verts(body):
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    m = eo.to_mesh()
    M = body.matrix_world
    out = [(M @ v.co).copy() for v in m.vertices]
    eo.to_mesh_clear()
    return out


def vert_regions(body):
    gn = {g.index: g.name.split(":")[-1] for g in body.vertex_groups}
    out = []
    for v in body.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda g: g.weight)
            out.append(gn[g.group])
        else:
            out.append("")
    return out


def region_min_z(verts, vreg, groups):
    best = None
    for i, z in enumerate(v.z for v in verts):
        if vreg[i] in groups and (best is None or z < best[0]):
            best = (z, i)
    return best


def solve_drop(rig, body, vreg, short, axis_w, groups, target_z, lo=-60.0, hi=60.0, tol=0.0015):
    """Bisection: rotate `short` about `axis_w` until the lowest vertex of `groups` sits at
    target_z (+- tol). The caller picks an axis over which the lowest point is monotone."""
    def low_at(deg):
        rot_world(rig, short, axis_w, deg)
        z = region_min_z(eval_world_verts(body), vreg, groups)[0]
        rot_world(rig, short, axis_w, -deg)
        return z
    zlo, zhi = low_at(lo), low_at(hi)
    if (zlo - target_z) * (zhi - target_z) > 0:
        for a in range(int(lo), int(hi) + 1, 10):
            log("   sweep %s %+d -> %.4f" % (short, a, low_at(a)))
        raise RuntimeError("solve_drop %s: no sign change lo=%.3f hi=%.3f target=%.3f" % (short, zlo, zhi, target_z))
    mid = (lo + hi) / 2
    for _ in range(24):
        mid = (lo + hi) / 2
        zm = low_at(mid)
        if abs(zm - target_z) < tol:
            break
        if (zm - target_z) * (zlo - target_z) > 0:
            lo, zlo = mid, zm
        else:
            hi, zhi = mid, zm
    rot_world(rig, short, axis_w, mid)
    return mid


def surface_z_under(body, x, y, z_from=3.0, vreg=None, skip_groups=()):
    """World z of the posed body's top surface under (x, y): object-space ray_cast on the
    EVALUATED (deformed) mesh from above, skipping faces that belong to `skip_groups` (a hand
    resting on the belly must not measure its own back), or None."""
    dg = bpy.context.evaluated_depsgraph_get()
    Mi = body.matrix_world.inverted()
    d = (Mi.to_3x3() @ Vector((0, 0, -1))).normalized()
    z = z_from
    for _ in range(12):
        o = Mi @ Vector((x, y, z))
        hit, loc, nrm, idx = body.ray_cast(o, d, depsgraph=dg)
        if not hit:
            return None
        wz = (body.matrix_world @ loc).z
        if vreg is not None and skip_groups:
            poly = body.data.polygons[idx]
            if any(vreg[vi] in skip_groups for vi in poly.vertices):
                z = wz - 0.003
                continue
        return wz
    return None


def solve_rest_on_body(rig, body, vreg, short, axis_w, groups, gap=0.01, lo=-70.0, hi=70.0, tol=0.0015, ground=0.0):
    """Bisection like solve_drop, but the target is the TOP surface under the region's lowest
    vertex (cast from above, the region's own faces skipped - a sunk hand would otherwise
    measure the inside of the back), or the ground when nothing is under it."""
    def f(deg):
        rot_world(rig, short, axis_w, deg)
        verts = eval_world_verts(body)
        z, i = region_min_z(verts, vreg, groups)
        sz = surface_z_under(body, verts[i].x, verts[i].y, vreg=vreg, skip_groups=groups)
        rot_world(rig, short, axis_w, -deg)
        if sz is None:
            sz = ground
        return z - (sz + gap)
    flo, fhi = f(lo), f(hi)
    if flo * fhi > 0:
        for a in range(int(lo), int(hi) + 1, 5):
            log("   sweep %s %+d -> %.4f" % (short, a, f(a)))
        raise RuntimeError("solve_rest_on_body %s: no bracket (%.4f, %.4f)" % (short, flo, fhi))
    mid = (lo + hi) / 2
    for _ in range(24):
        mid = (lo + hi) / 2
        fm = f(mid)
        if abs(fm) < tol:
            break
        if fm * flo > 0:
            lo, flo = mid, fm
        else:
            hi, fhi = mid, fm
    rot_world(rig, short, axis_w, mid)
    return mid


def _fingers(side):
    return ["%sHand%s%d" % (side, f, i) for f in ("Thumb", "Index") for i in (1, 2, 3, 4)]


REGIONS = {
    "head":      ["Head", "HeadTop_End", "Neck"],
    "arm_r":     ["RightArm", "RightForeArm", "RightHand"] + _fingers("Right"),
    "arm_l":     ["LeftArm", "LeftForeArm", "LeftHand"] + _fingers("Left"),
    "hand_r":    ["RightHand"] + _fingers("Right"),
    "hand_l":    ["LeftHand"] + _fingers("Left"),
    "forearm_r": ["RightForeArm"],
    "forearm_l": ["LeftForeArm"],
    "uparm_r":   ["RightArm"],
    "uparm_l":   ["LeftArm"],
    "leg_r":     ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "RightToe_End"],
    "leg_l":     ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End"],
    "foot_l":    ["LeftFoot", "LeftToeBase", "LeftToe_End"],
    "foot_r":    ["RightFoot", "RightToeBase", "RightToe_End"],
    "shin_l":    ["LeftLeg"],
    "shin_r":    ["RightLeg"],
    "thigh_l":   ["LeftUpLeg"],
    "thigh_r":   ["RightUpLeg"],
    "torso":     ["Hips", "Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder"],
}
LEG_PARTS = ("thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r")


def bone_dir(rig, short):
    pb = bone(rig, short)
    return (rig.matrix_world @ pb.tail - rig.matrix_world @ pb.head).normalized()


def aim_bone(rig, short, target):
    """Rotate the bone (children follow) so its head->tail direction becomes `target` (world)."""
    cur = bone_dir(rig, short)
    t = Vector(target).normalized()
    axis = cur.cross(t)
    if axis.length < 1e-6:
        return
    ang = math.degrees(math.acos(max(-1.0, min(1.0, cur.dot(t)))))
    rot_world(rig, short, axis, ang)


def twist_swing(rig, short):
    """The bone's own pose offset (matrix_basis = relative to REST and to its parent) split
    into a TWIST about its own axis (bone local Y) and a SWING. Degrees, twist signed."""
    q = bone(rig, short).matrix_basis.to_quaternion()
    tw = Quaternion((q.w, 0.0, q.y, 0.0))
    if tw.magnitude < 1e-9:
        return 180.0, math.degrees(q.angle)
    tw.normalize()
    twist = math.degrees(2.0 * math.atan2(tw.y, tw.w))
    twist = (twist + 180.0) % 360.0 - 180.0
    sw = q @ tw.inverted()
    return round(twist, 1), round(math.degrees(sw.angle), 1)


def region_centroid(verts, vreg, groups):
    ps = [verts[i] for i in range(len(verts)) if vreg[i] in groups]
    return sum(ps, Vector()) / len(ps)


def palm_normal(rig, body, vreg, side):
    """Measured off the MESH: thumb centroid vs palm centroid, perpendicular to the hand
    bone. Calibrated on the A-pose donor (thumbs forward, palms to the thighs): right palm =
    thumb x fingers, left palm = fingers x thumb."""
    verts = eval_world_verts(body)
    hand = region_centroid(verts, vreg, [side + "Hand"] + ["%sHandIndex%d" % (side, i) for i in (1, 2, 3, 4)])
    thumb = region_centroid(verts, vreg, ["%sHandThumb%d" % (side, i) for i in (1, 2, 3, 4)])
    fd = bone_dir(rig, side + "Hand")
    td = thumb - hand
    td -= fd * td.dot(fd)
    td.normalize()
    return (td.cross(fd) if side == "Right" else fd.cross(td)).normalized()


def roll_for_palm(rig, body, vreg, side, want, step=3.0):
    """Roll the UPPER arm about its own axis (a shoulder rotation - the forearm's own twist
    stays 0) until the measured palm normal best matches `want`. Exhaustive scan, no guess."""
    ua = bone_dir(rig, side + "Arm")
    best = (-2.0, 0.0)
    a = -180.0
    while a < 180.0:
        rot_world(rig, side + "Arm", ua, a)
        d = palm_normal(rig, body, vreg, side).dot(Vector(want).normalized())
        rot_world(rig, side + "Arm", ua, -a)
        if d > best[0]:
            best = (d, a)
        a += step
    rot_world(rig, side + "Arm", ua, best[1])
    return best[1], best[0]


def elbow_report(rig, body, vreg, side, hx):
    """Everything the arm gate needs, measured: the forearm's twist/swing from matrix_basis,
    the upper arm's, the hand's, the elbow angle between the bone directions, and where the
    elbow POINT faces (opposite the crease): its z (up is the spun-elbow tell) and its
    outward component (away from the body midline)."""
    ua, fa = bone_dir(rig, side + "Arm"), bone_dir(rig, side + "ForeArm")
    ang = math.degrees(math.acos(max(-1.0, min(1.0, ua.dot(fa)))))
    crease = fa - ua * fa.dot(ua)
    out = Vector((1.0 if side == "Left" else -1.0, 0, 0))
    rep = {"elbow_deg": round(ang, 1)}
    rep["forearm_twist_deg"], rep["forearm_swing_deg"] = twist_swing(rig, side + "ForeArm")
    rep["uparm_twist_deg"], rep["uparm_swing_deg"] = twist_swing(rig, side + "Arm")
    rep["hand_twist_deg"], rep["hand_swing_deg"] = twist_swing(rig, side + "Hand")
    if crease.length > 1e-4 and ang > 3.0:
        crease.normalize()
        ep = -crease
        rep["elbow_point"] = [round(v, 3) for v in ep]
        rep["elbow_point_z"] = round(ep.z, 3)
        rep["elbow_point_out"] = round(ep.dot(out), 3)
        rep["crease"] = [round(v, 3) for v in crease]
    else:
        rep["elbow_point_z"] = 0.0
        rep["elbow_point_out"] = 0.0
    pn = palm_normal(rig, body, vreg, side)
    rep["palm_normal"] = [round(v, 3) for v in pn]
    rep["ok"] = abs(rep["forearm_twist_deg"]) <= 15.0 and 0.0 <= rep["elbow_deg"] <= 60.0 and rep["elbow_point_z"] <= 0.35
    return rep


def land_leg(rig, body, vreg, side, tz):
    """Land the whole leg on its lowest point (hip swing about world X), then the boot's heel
    by the ankle, twice - the shared ankle verts make the two converge. Returns per-part min
    z above the datum. On this donor a straight leg's thigh ROOT sits 26-44 mm above the
    shoulder-blade datum (the low-poly thigh is inset behind the buttock; measured 2026-09-13)
    and no hip angle fixes that without burying the knee - flatten_undersides() presses the
    dead weight onto the ground on the static mesh instead."""
    S = side
    k = S[0].lower()
    leg, foot = REGIONS["leg_" + k], REGIONS["foot_" + k]
    for _ in range(2):
        solve_drop(rig, body, vreg, S + "UpLeg", (1, 0, 0), leg, tz, lo=-25, hi=25)
        sd = bone_dir(rig, S + "Leg")
        sd.z = 0
        sd.normalize()
        solve_drop(rig, body, vreg, S + "Foot", Vector((0, 0, 1)).cross(sd), foot, tz + 0.0005, lo=-45, hi=45)
    solve_drop(rig, body, vreg, S + "UpLeg", (1, 0, 0), leg, tz, lo=-15, hi=15)
    verts = eval_world_verts(body)
    return {p: round(region_min_z(verts, vreg, REGIONS[p])[0] - tz, 4) for p in LEG_PARTS if p.endswith(k)}


def flatten_undersides(static, vreg, parts=("thigh_l", "shin_l", "thigh_r", "shin_r"), reach=0.05, rest=0.002):
    """Dead weight: on the STATIC (baked, ground-shifted) mesh, every vertex of the named leg
    parts whose normal faces down and that sits within `reach` of the ground is pressed to
    `rest` above it. The top silhouette is untouched. Returns per-part min z after."""
    me = static.data
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    groups = {p: set(REGIONS[p]) for p in parts}
    moved = {p: 0 for p in parts}
    for v in me.vertices:
        if v.index >= len(vreg):
            continue
        for p, gs in groups.items():
            if vreg[v.index] in gs and v.normal.z < -0.25 and 0.0 < v.co.z - GROUND < reach:
                v.co.z = GROUND + rest
                moved[p] += 1
    me.update()
    out = {}
    for p in parts:
        zs = [me.vertices[i].co.z for i in range(min(len(vreg), len(me.vertices))) if vreg[i] in groups[p]]
        out[p] = {"min_mm": round(min(zs) * 1000, 1), "moved": moved[p]}
    log("  flatten undersides: %s" % out)
    return out


def pose_death(rig, body, facing):
    """The death: on his back, head toward +Y, feet toward -Y, face up. Right arm (-X) flung
    out past the shoulder toward the head, lying on its edge with a 30 deg bend IN the ground
    plane (crease toward the head, elbow point out); left upper arm on the ground beside him,
    forearm folded up onto the belly flank (the wound hand), back of the hand on the cloth;
    both legs FLAT, a little apart, the left knee bent ~12 deg in the ground plane, both
    boots fallen outward; head rolled to his left (+X); mouth slack (jaw handled on the static
    mesh). No forearm roll anywhere: every arm move is a shoulder rotation or a hinge bend,
    and the residual is MEASURED (twist_swing) and gated. Every contact is SOLVED."""
    vreg = vert_regions(body)
    donors.zero_pose(rig)
    bpy.context.view_layer.update()
    ang = math.degrees(math.atan2(facing.x, -facing.y))   # yaw that maps facing onto -Y
    if abs(ang) > 0.01:
        rot_world(rig, "Hips", (0, 0, 1), -ang)
    rot_world(rig, "Hips", (1, 0, 0), -90)
    verts = eval_world_verts(body)
    tz = region_min_z(verts, vreg, REGIONS["torso"])[0]
    hx = (rig.matrix_world @ bone(rig, "Hips").head).x
    log("lying: torso lowest z %.4f (ground datum)" % tz)

    # 1. head rolled to his left (+X) about the spine axis (world Y); then rest the skull.
    rot_world(rig, "Neck", (0, 1, 0), 22)
    rot_world(rig, "Head", (0, 1, 0), 30)
    solve_drop(rig, body, vreg, "Neck", (1, 0, 0), REGIONS["head"], tz, lo=-40, hi=40)

    # 2. right arm (-X): shoulder swing out past the shoulder toward the head; shoulder ROLL
    #    so the crease faces the head side in the ground plane (the arm lies on its ulnar
    #    edge, thumb up); a 30 deg hinge bend toward the palm (in-plane, so the forearm stays
    #    on the ground); then land the elbow and the hand.
    aim_bone(rig, "RightArm", (-0.82, 0.55, -0.15))
    ua = bone_dir(rig, "RightArm")
    ua_flat = Vector((ua.x, ua.y, 0)).normalized()
    crease_want = ua_flat.cross(Vector((0, 0, 1)))       # in-plane, toward the head/body side
    if crease_want.y < 0:
        crease_want = -crease_want
    roll, fit = roll_for_palm(rig, body, vreg, "Right", crease_want)
    log("  right shoulder roll %+.0f deg (palm fit %.2f)" % (roll, fit))
    pn = palm_normal(rig, body, vreg, "Right")
    fa = bone_dir(rig, "RightForeArm")
    rot_world(rig, "RightForeArm", fa.cross(pn), 30)     # hinge: toward the palm
    d = ua_flat
    perp = Vector((0, 0, 1)).cross(d)
    solve_drop(rig, body, vreg, "RightArm", perp, REGIONS["uparm_r"] + REGIONS["forearm_r"], tz, lo=-60, hi=60)
    fa = bone_dir(rig, "RightForeArm")
    fa.z = 0
    fa.normalize()
    solve_drop(rig, body, vreg, "RightForeArm", Vector((0, 0, 1)).cross(fa), REGIONS["hand_r"], tz, lo=-60, hi=60)

    # 3. left arm (+X): upper arm out ~30 deg from the flank, sloping to the ground; shoulder
    #    roll so the crease faces up-and-in; a hinge bend folds the forearm up onto the belly
    #    flank. The elbow is solved onto the ground; the BEND is solved so the hand's lowest
    #    vertex rests 9 mm proud of whatever is under it (the flank cloth or the wound edge).
    aim_bone(rig, "LeftArm", (0.28, -0.94, -0.18))
    ua = bone_dir(rig, "LeftArm")
    want = Vector((-0.75, 0.0, 0.66))
    want -= ua * want.dot(ua)
    roll, fit = roll_for_palm(rig, body, vreg, "Left", want)
    log("  left shoulder roll %+.0f deg (palm fit %.2f)" % (roll, fit))
    pn = palm_normal(rig, body, vreg, "Left")
    fa = bone_dir(rig, "LeftForeArm")
    hinge = fa.cross(pn).normalized()
    rot_world(rig, "LeftForeArm", hinge, 45)
    d = Vector((ua.x, ua.y, 0)).normalized()
    solve_drop(rig, body, vreg, "LeftArm", Vector((0, 0, 1)).cross(d), REGIONS["uparm_l"], tz, lo=-45, hi=45)
    try:
        extra = solve_rest_on_body(rig, body, vreg, "LeftForeArm", hinge, REGIONS["hand_l"], gap=0.009, lo=-15, hi=15, ground=tz)
        log("  left hinge solved %+.1f deg beyond 45" % extra)
    except RuntimeError as ex:
        log("  left hinge: %s (kept 45 deg)" % ex)
    hip = rig.matrix_world @ bone(rig, "Hips").head
    log("  left arm: shoulder %s elbow %s hand tip %s | hips head %s" % tuple(
        tuple(round(v, 3) for v in q) for q in (rig.matrix_world @ bone(rig, "LeftArm").head, rig.matrix_world @ bone(rig, "LeftForeArm").head, rig.matrix_world @ bone(rig, "LeftHand").tail, hip)))

    # 4. legs FLAT. Right (-X) straight, splayed 10 deg, boot fallen outward; left (+X) splayed
    #    12 deg with the knee bent 12 deg IN the ground plane (shin back toward the midline),
    #    boot fallen outward. Each leg landed on its lowest point, the boot's heel by the
    #    ankle; thigh / calf / boot reported separately (gate: each within 5 mm).
    aim_bone(rig, "RightUpLeg", (-0.17, -0.985, -0.01))
    aim_bone(rig, "RightFoot", (-0.35, -0.22, 0.91))
    aim_bone(rig, "LeftUpLeg", (0.21, -0.978, -0.01))
    aim_bone(rig, "LeftLeg", (0.0, -1.0, -0.01))
    aim_bone(rig, "LeftFoot", (0.35, -0.22, 0.91))
    legs = {}
    legs.update(land_leg(rig, body, vreg, "Right", tz))
    legs.update(land_leg(rig, body, vreg, "Left", tz))
    bpy.context.view_layer.update()
    gates = {"legs_mm_above_ground": {k: round(v * 1000, 1) for k, v in legs.items()},
             "legs_ok": all(v <= 0.005 for v in legs.values()),
             "arm_r": elbow_report(rig, body, vreg, "Right", hx),
             "arm_l": elbow_report(rig, body, vreg, "Left", hx)}
    ka, kb = bone_dir(rig, "LeftUpLeg"), bone_dir(rig, "LeftLeg")
    gates["knee_l_deg"] = round(math.degrees(math.acos(max(-1.0, min(1.0, ka.dot(kb))))), 1)
    ka, kb = bone_dir(rig, "RightUpLeg"), bone_dir(rig, "RightLeg")
    gates["knee_r_deg"] = round(math.degrees(math.acos(max(-1.0, min(1.0, ka.dot(kb))))), 1)
    for k, v in gates.items():
        log("  gate %s: %s" % (k, v))
    return tz, vreg, gates


def slack_jaw(body, F, drop=0.016, back=0.005):
    """On the DONOR mesh (in-memory copy, T-pose, facing -Y after the yaw), let the jaw fall:
    the under-jaw ring drops `drop` and slides `back`; a dark mouth quad on the gore sheet's
    field is set 3 mm proud of the face at the painted lip line, weighted 100% to Head so it
    rides the roll. Rows are found by MEANING: Head-dominated verts, forward of the skull
    centre, in the lowest 8 mm of the face band."""
    me = body.data
    M = body.matrix_world
    Mi = M.inverted()
    gn = {g.index: g.name.split(":")[-1] for g in body.vertex_groups}
    head_idx = [v.index for v in me.vertices if v.groups and gn[max(v.groups, key=lambda g: g.weight).group] == "Head"]
    if not head_idx:
        raise RuntimeError("no Head-dominated verts")
    W = {i: M @ me.vertices[i].co for i in head_idx}
    zs = sorted(v.z for v in W.values())
    zlo, zhi = zs[0], zs[-1]
    fwd = Vector((0, -1, 0))
    cy = sum(v.y for v in W.values()) / len(W)
    # the face band: forward of the skull centre; the under-jaw ring = its lowest 12 mm
    face = {i: v for i, v in W.items() if (v - Vector((0, cy, 0))).dot(fwd) > 0.04}
    fz = sorted(v.z for v in face.values())
    jaw = [i for i, v in face.items() if v.z < fz[0] + 0.014]
    lip_row = [i for i, v in face.items() if fz[0] + 0.05 < v.z < fz[0] + 0.08]
    if len(jaw) < 4:
        raise RuntimeError("jaw ring too small: %d" % len(jaw))
    for i in jaw:
        w = W[i] + Vector((0, back, -drop))
        me.vertices[i].co = Mi @ w
    # mouth quad: centred on the face midline at the painted lip height (lip line sits between
    # the lower-lip row and the jaw row; 0.42 of the way down from the lip row after the drop)
    lip_z = sum(W[i].z for i in lip_row) / max(1, len(lip_row))
    jaw_z = fz[0] - drop
    mz = lip_z - 0.42 * (lip_z - jaw_z)
    front_y = min(v.y for v in face.values())   # most forward point of the face (the chin/lips)
    my = front_y - 0.003
    gm = bpy.data.materials.get("gore_cap_mat")
    if gm.name not in [m.name for m in me.materials if m]:
        me.materials.append(gm)
    gi = [i for i, m in enumerate(me.materials) if m and m.name == gm.name][0]
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_lay = bm.loops.layers.uv.verify()
    dl = bm.verts.layers.deform.verify()
    hg = [g.index for g in body.vertex_groups if g.name.split(":")[-1] == "Head"][0]
    w, h = 0.015, 0.011
    quad = []
    for (dx, dz) in ((-w, -h), (w, -h), (w, h), (-w, h)):
        v = bm.verts.new(Mi @ Vector((dx, my, mz + dz)))
        v[dl][hg] = 1.0
        quad.append(v)
    f = bm.faces.new(quad)
    f.material_index = gi
    if (M.to_3x3() @ f.normal).dot(fwd) < 0:
        f.normal_flip()
    cell = gp.FIELD_UV
    for l in f.loops:
        l[uv_lay].uv = (cell.x + random.uniform(-0.01, 0.01), cell.y + random.uniform(-0.01, 0.01))
    bm.to_mesh(me)
    bm.free()
    me.update()
    body["mouth_local"] = list(Mi @ Vector((0, my, mz)))
    log("slack jaw: %d jaw verts dropped %.0f mm, mouth quad at z %.3f (lip row %.3f)" % (len(jaw), drop * 1000, mz, lip_z))


def bake_posed(body, name, vreg):
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    m = eo.to_mesh()
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bm.from_mesh(m)
    bm.transform(body.matrix_world)
    bm.to_mesh(me)
    bm.free()
    for mt in body.data.materials:
        me.materials.append(mt.original if mt else None)
    eo.to_mesh_clear()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    # the dominant bone per vertex rides along so later stages find the belly / jaw / hands
    # by MEANING, not by coordinates alone
    o["vert_bone"] = json.dumps(vreg)
    return o


def report_contacts(obj, vreg):
    """Per region: lowest z and how many verts within 6 mm of the ground."""
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    rep = {}
    for r, groups in REGIONS.items():
        zs = [vs[i].z for i in range(len(vs)) if vreg[i] in groups]
        if zs:
            rep[r] = {"min_z": round(min(zs), 4), "touching": sum(1 for z in zs if z <= GROUND + 0.006)}
    return rep


def stage_a(F):
    donors.clear_scene()
    objs = donors.append(F["file"], [F["rig"]] + F["body"] + [F["gore_carrier"]])
    rig = objs[F["rig"]]
    # the shared gore sheet rides in on a cap object; keep the material, drop the object
    bpy.data.objects.remove(objs[F["gore_carrier"]], do_unlink=True)
    bodies = [objs[n] for n in F["body"]]
    body = bodies[0]
    if len(bodies) > 1:
        for o in bpy.context.scene.objects:
            o.select_set(False)
        for o in bodies:
            o.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
        body = bpy.context.view_layer.objects.active
    bpy.context.view_layer.update()
    # facing from the HEAD's face-material polys only (hands share the skin material)
    me = body.data
    fi = [i for i, mt in enumerate(me.materials) if mt and mt.name.startswith(F["face_mat"])]
    M3 = body.matrix_world.to_3x3()
    ztop = max((body.matrix_world @ v.co).z for v in me.vertices)
    acc = Vector((0, 0, 0))
    for p in me.polygons:
        c = body.matrix_world @ p.center
        if p.material_index in fi and c.z > ztop - 0.25:
            acc += M3 @ p.normal
    acc.z = 0
    facing = acc.normalized()
    log("facing measured", tuple(round(v, 3) for v in facing))
    slack_jaw(body, F)
    tz, vreg, gates = pose_death(rig, body, facing)
    # key the pose so it is not volatile, then bake
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_quaternion" if pb.rotation_mode == 'QUATERNION' else "rotation_euler", frame=1)
        pb.keyframe_insert("location", frame=1)
    bpy.context.view_layer.update()
    static = bake_posed(body, "corpse_body", vreg)
    static.data.transform(Matrix.Translation((0, 0, -tz)))
    static.data.update()
    gates["legs_flattened_mm"] = flatten_undersides(static, vreg)
    # world-space landmarks for the later stages (already shifted onto the ground)
    static["hips_xy"] = list((rig.matrix_world @ bone(rig, "Hips").head).xy)
    # mouth position: the gore-material quad's centre on the static mesh (it rode the Head bone)
    mi = [i for i, m in enumerate(static.data.materials) if m and m.name == "gore_cap_mat"]
    mc = [p.center for p in static.data.polygons if p.material_index in mi]
    static["mouth_w"] = list(sum(mc, Vector()) / len(mc)) if mc else [0, 0, 0]
    static["head_c"] = list(sum((static.data.vertices[i].co for i in range(len(vreg)) if vreg[i] == "Head"), Vector()) / max(1, vreg.count("Head")))
    rep = report_contacts(static, vreg)
    for r, d in rep.items():
        log("  contact %-10s min_z %+.4f touching %d" % (r, d["min_z"], d["touching"]))
    rep["_gates"] = gates
    # park the rig + donor body (kept in the studio file for re-posing; never exported)
    rig.location = (0, 6.0, 0)
    body.hide_render = True
    rig.hide_render = True
    return static, rig, body, rep


def quick_render(objs, tag, cam_pos, look, lens=35, res=(900, 700)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sc.display.render_aa = 'FXAA'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.35, 0.36, 0.30)
    ground = bpy.data.objects.get("_render_ground")
    if ground is None:
        me = bpy.data.meshes.new("_render_ground")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6.0)
        bm.to_mesh(me)
        bm.free()
        ground = bpy.data.objects.new("_render_ground", me)
        gmat = bpy.data.materials.new("_ground_mat")
        gmat.diffuse_color = (0.30, 0.24, 0.16, 1)
        me.materials.append(gmat)
        bpy.context.scene.collection.objects.link(ground)
    ground.hide_render = False
    ground.hide_viewport = False
    ground.location = (0, 0, -0.001)
    for o in sc.objects:
        o.hide_render = not (o in objs or o is ground)
    cam = bpy.data.objects.get("_render_cam")
    if cam is None:
        cam = bpy.data.objects.new("_render_cam", bpy.data.cameras.new("_render_cam"))
        bpy.context.scene.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = lens
    cam.location = Vector(cam_pos)
    cam.rotation_euler = (Vector(look) - Vector(cam_pos)).to_track_quat('-Z', 'Y').to_euler()
    path = os.path.join(RENDER_DIR, "gore_corpse_%s.png" % tag)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    ground.hide_render = True
    ground.hide_viewport = True
    return path


# ------------------------------------------------------------------ Stage B: the gutting
def open_belly(static, vreg, depth=0.055):
    """Sternum -> pelvis on the lying man: delete the belly-up faces of the abdomen column,
    extrude the rim down into a pocket (scaled toward the hole centre), floor it. The
    head-end wall gets the pale bone disc (the costal margin), the other walls red meat, the
    floor dark. Returns (hole_centre_world, floor_z, rim_vert_indices, hole_y_range)."""
    me = static.data
    gm = bpy.data.materials.get("gore_cap_mat")
    if gm.name not in [m.name for m in me.materials if m]:
        me.materials.append(gm)
    gi = [i for i, m in enumerate(me.materials) if m and m.name == gm.name][0]
    hx, hy = static["hips_xy"]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    uv_lay = bm.loops.layers.uv.verify()
    belly_groups = ("Hips", "Spine", "Spine1")
    doomed = []
    for f in bm.faces:
        if not all(vreg[v.index] in belly_groups for v in f.verts if v.index < len(vreg)):
            continue
        c = f.calc_center_median()
        if f.normal.z > 0.35 and abs(c.x - hx) < 0.10 and (hy - 0.13) < c.y < (hy + 0.27):
            doomed.append(f)
    log("belly faces to open: %d" % len(doomed))
    if not 4 <= len(doomed) <= 8:
        raise RuntimeError("open_belly expected 4-8 abdomen faces, found %d" % len(doomed))
    rim_edges = set()
    for f in doomed:
        for e in f.edges:
            if all((g in doomed) for g in e.link_faces):
                continue
            rim_edges.add(e)
    bmesh.ops.delete(bm, geom=doomed, context='FACES_ONLY')
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if e.is_wire], context='EDGES')
    rim = [e for e in rim_edges if e.is_valid]
    rim_verts = set(v for e in rim for v in e.verts)
    hole_c = sum((v.co for v in rim_verts), Vector()) / len(rim_verts)
    ext = bmesh.ops.extrude_edge_only(bm, edges=rim)
    new_verts = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    floor_z = hole_c.z - depth
    for v in new_verts:
        d = v.co - hole_c
        d.z = 0
        v.co = Vector((hole_c.x + d.x * 0.74, hole_c.y + d.y * 0.78, floor_z))
    wall = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMFace)]
    inner = [e for e in bm.edges if e.is_boundary and e.verts[0] in new_verts and e.verts[1] in new_verts]
    before = set(bm.faces)
    bmesh.ops.holes_fill(bm, edges=inner, sides=0)
    floor = [f for f in bm.faces if f not in before]
    bm.normal_update()
    for f in wall + floor:
        f.material_index = gi
    for f in floor:
        if f.normal.z < 0:
            f.normal_flip()
    for f in wall:
        cc = f.calc_center_median()
        toward = Vector((hole_c.x, hole_c.y, floor_z + depth * 0.5)) - cc
        toward.z = 0
        if f.normal.dot(toward) < 0:
            f.normal_flip()
    head_wall = [f for f in wall if f.calc_center_median().y > hole_c.y + 0.06]
    side_wall = [f for f in wall if f not in head_wall]
    gp.planar_uv_to_disc(bm, floor, uv_lay, gp.disc_uv(1, 3), gp.DISC_R)      # dark cavity
    gp.planar_uv_to_disc(bm, side_wall, uv_lay, gp.disc_uv(0, 2), gp.DISC_R)  # red meat
    gp.planar_uv_to_disc(bm, head_wall, uv_lay, gp.disc_uv(2, 1), gp.DISC_R)  # pale: the rib edge
    rim_idx = [v.index for v in rim_verts]
    # ---- torn cloth: the two long (+-X) sides of the rim lift as peeled flaps, uniform material
    flap_src = [e for e in rim if abs(e.verts[0].co.x - hx) > 0.05 and abs(e.verts[1].co.x - hx) > 0.05
                and (e.verts[0].co.x - hx) * (e.verts[1].co.x - hx) > 0]
    cloth_idx = None
    for e in flap_src:
        for f in e.link_faces:
            if f.material_index != gi:
                cloth_idx = f.material_index
                break
        if cloth_idx is not None:
            break
    fext = bmesh.ops.extrude_edge_only(bm, edges=flap_src)
    fverts = [g for g in fext["geom"] if isinstance(g, bmesh.types.BMVert)]
    ffaces = [g for g in fext["geom"] if isinstance(g, bmesh.types.BMFace)]
    for v in fverts:
        sgn = 1.0 if v.co.x > hx else -1.0
        v.co = v.co + Vector((sgn * 0.045, 0.0, 0.030))
    bm.normal_update()
    for f in ffaces:
        f.material_index = cloth_idx if cloth_idx is not None else 0
        if f.normal.z < 0:
            f.normal_flip()
        for l in f.loops:
            src = l.vert
            if l.vert in fverts:
                src = None
                for e in l.vert.link_edges:
                    o = e.other_vert(l.vert)
                    if o in rim_verts:
                        src = o
                        break
            if src is None:
                continue
            for l2 in src.link_loops:
                if l2.face not in ffaces and l2.face.material_index == f.material_index:
                    l[uv_lay].uv = l2[uv_lay].uv
                    break
    # ---- wound ring: a 6 mm-proud collar of gore-field quads around the rim (blood soak on cloth)
    ring_faces = []
    rim_loop = sorted(rim_verts, key=lambda v: math.atan2(v.co.y - hole_c.y, v.co.x - hole_c.x))
    outer = []
    for v in rim_loop:
        d = v.co - hole_c
        d.z = 0
        d.normalize()
        outer.append(bm.verts.new(v.co + d * 0.035 + Vector((0, 0, 0.006))))
    inner_ring = [bm.verts.new(v.co + Vector((0, 0, 0.006))) for v in rim_loop]
    n = len(rim_loop)
    for k in range(n):
        try:
            f = bm.faces.new((inner_ring[k], inner_ring[(k + 1) % n], outer[(k + 1) % n], outer[k]))
        except ValueError:
            continue
        f.material_index = gi
        ring_faces.append(f)
    bm.normal_update()
    for f in ring_faces:
        if f.normal.z < 0:
            f.normal_flip()
        for l in f.loops:
            l[uv_lay].uv = (gp.FIELD_UV.x + random.uniform(-0.012, 0.012), gp.FIELD_UV.y + random.uniform(-0.012, 0.012))
    floor_co = [v.co.copy() for v in new_verts]
    bm.to_mesh(me)
    bm.free()
    me.update()
    ys = [me.vertices[i].co.y for i in rim_idx]
    static["floor_ext"] = [round(min(v.x for v in floor_co), 4), round(max(v.x for v in floor_co), 4),
                           round(min(v.y for v in floor_co), 4), round(max(v.y for v in floor_co), 4)]
    static["rim_x"] = [round(min(me.vertices[i].co.x for i in rim_idx), 4), round(max(me.vertices[i].co.x for i in rim_idx), 4)]
    static["rim_z"] = round(sum(me.vertices[i].co.z for i in rim_idx) / len(rim_idx), 4)
    return Vector((hole_c.x, hole_c.y, floor_z)), floor_z, rim_idx, (min(ys), max(ys))


VISCERA_TEX = os.path.join(OUT_DIR, "gore_corpse_viscera.png")


def _noise(rnd, x, y, k=0.12):
    return 1.0 + rnd.uniform(-k, k)


def write_viscera_texture(path=VISCERA_TEX, N=128):
    """The corpse's own 128^2 viscera strip (baked into the atlas, never shipped as-is).
    v 0.00-0.25  intestine, tiles along u (one crease per 40 mm = 32 px): pink-grey base, a
                 dark crease line every 32 px, a wet highlight band at v 0.125 (the ring's
                 top), the underside darker.
    v 0.25-0.50  mesentery: dark red with darker vessel streaks.
    v 0.50-0.75  liver: dark red-brown, mottled.
    v 0.75-1.00  u<0.5 blood (the torn ends); u>=0.5 pale fat."""
    rnd = random.Random(23)
    img = bpy.data.images.new("viscera_src", N, N, alpha=False)
    buf = [0.0] * (N * N * 4)
    for y in range(N):
        v = (y + 0.5) / N
        for x in range(N):
            u = (x + 0.5) / N
            if v < 0.25:
                ring = (v / 0.25)                       # 0 bottom .. 0.5 top .. 1 bottom
                top = math.cos((ring - 0.5) * 2 * math.pi) * 0.5 + 0.5    # 1 at the top
                base = Vector((0.82, 0.40, 0.38))
                shade = 0.55 + 0.45 * top
                c = base * shade * _noise(rnd, x, y, 0.06)
                if abs(ring - 0.5) < 0.06:
                    c = Vector((0.95, 0.64, 0.60)) * _noise(rnd, x, y, 0.04)   # wet stripe
                cr = x % 32
                if cr in (0, 31):
                    c = c * 0.50                        # the segment crease
                elif cr in (1, 30):
                    c = c * 0.76
                if (x // 32) % 2 == 1 and abs(ring - 0.5) >= 0.06:
                    c = c * 0.94                        # alternate segments a shade darker
            elif v < 0.5:
                c = Vector((0.36, 0.06, 0.07)) * _noise(rnd, x, y, 0.18)
                if (x * 7 + y * 3) % 23 < 2 or (x * 3 - y * 5) % 29 < 2:
                    c = c * 0.55                        # vessels
            elif v < 0.75:
                c = Vector((0.33, 0.11, 0.08)) * _noise(rnd, x, y, 0.16)
                if (x * 5 + y * 11) % 17 < 1:
                    c = c * 1.3
            else:
                if u < 0.5:
                    c = Vector((0.52, 0.04, 0.05)) * _noise(rnd, x, y, 0.22)
                    if rnd.random() < 0.08:
                        c = Vector((0.80, 0.12, 0.10))  # wet glints
                else:
                    c = Vector((0.90, 0.80, 0.62)) * _noise(rnd, x, y, 0.08)
            i = (y * N + x) * 4
            buf[i:i + 3] = (min(1.0, c.x), min(1.0, c.y), min(1.0, c.z))
            buf[i + 3] = 1.0
    img.pixels = buf
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save_render(path)
    bpy.data.images.remove(img)
    return path


def viscera_material():
    m = bpy.data.materials.get("gore_viscera_mat")
    if m:
        return m
    m = bpy.data.materials.new("gore_viscera_mat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(VISCERA_TEX, check_existing=True)
    tex.interpolation = 'Closest'
    tex.extension = 'REPEAT'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


UV_BLOOD = (0.05, 0.45, 0.78, 0.98)
UV_FAT = (0.55, 0.95, 0.78, 0.98)
UV_MES = (0.05, 0.95, 0.27, 0.48)
UV_LIVER = Vector((0.5, 0.625))


def serpentine(x0, x1, ys, r_hair, start_dir=1):
    """A hairpin path: straight runs along X between x0..x1 at each y in `ys`, joined by
    half-circle turns of radius r_hair. Returns (points, hairpins) where hairpins are
    (centre_xy, run_a_y, run_b_y, side_sign)."""
    pts = []
    hair = []
    d = start_dir
    for i, y in enumerate(ys):
        xa, xb = (x0, x1) if d > 0 else (x1, x0)
        n = max(2, int(abs(xb - xa) / 0.01))
        for k in range(n + 1):
            pts.append(Vector((xa + (xb - xa) * k / n, y, 0.0)))
        if i + 1 < len(ys):
            y2 = ys[i + 1]
            cx_, cy_ = xb, (y + y2) * 0.5
            rr = abs(y2 - y) * 0.5
            steps = 8
            for k in range(1, steps):
                a = math.pi * k / steps
                # from run y toward run y2, bulging outward past xb
                pts.append(Vector((cx_ + d * math.sin(a) * rr, cy_ - math.cos(a) * (y2 - y) * 0.5, 0.0)))
            hair.append(((cx_, cy_), y, y2, d))
            d = -d
    return pts, hair


def resample(pts, step):
    out = [pts[0].copy()]
    acc = 0.0
    for i in range(1, len(pts)):
        seg = pts[i] - pts[i - 1]
        L = seg.length
        if L < 1e-9:
            continue
        while acc + L >= step:
            t = (step - acc) / L
            out.append(pts[i - 1] + seg * t)
            pts[i - 1] = out[-1]
            seg = pts[i] - pts[i - 1]
            L = seg.length
            acc = 0.0
        acc += L
    if (pts[-1] - out[-1]).length > step * 0.4:
        out.append(pts[-1].copy())
    return out


def decimate_path(pts, turn_deg, max_len):
    """Keep a ring wherever the centreline has turned `turn_deg` since the last kept ring, or
    every `max_len` on a straight. Hairpins get 4-5 rings, runs 2-3."""
    keep = [pts[0]]
    last_dir = None
    acc = 0.0
    for i in range(1, len(pts)):
        d = pts[i] - pts[i - 1]
        acc += d.length
        if d.length < 1e-9:
            continue
        d.normalize()
        if last_dir is None:
            last_dir = d
        turned = math.degrees(math.acos(max(-1.0, min(1.0, last_dir.dot(d)))))
        if turned >= turn_deg or acc >= max_len or i == len(pts) - 1:
            keep.append(pts[i])
            last_dir = d
            acc = 0.0
    return keep


def lift_on_supports(pts, supports, r, clear=0.003, ground=GROUND):
    """z for every centreline point: the highest support under the point OR under any of 4
    points r away (a tube on a slope needs more than the point under its axis), + r + clear;
    then a 3-wide max filter and a 3-tap mean so consecutive rings never see a step."""
    zs = []
    for q in pts:
        best = ground
        for dx, dy in ((0, 0), (r, 0), (-r, 0), (0, r), (0, -r)):
            best = max(best, gp.support_z_under(Vector((q.x + dx, q.y + dy, 3.0)), supports, ground))
        zs.append(best + r + clear)
    n = len(zs)
    mx = [max(zs[max(0, i - 1):i + 2]) for i in range(n)]
    sm = [sum(mx[max(0, i - 1):i + 2]) / len(mx[max(0, i - 1):i + 2]) for i in range(n)]
    # the mean undercuts the clearance where the support drops away (seen 2026-09-13: 49 mm
    # into the flap's outer edge) - never go below what the cast demanded
    sm = [max(a, b) for a, b in zip(sm, zs)]
    return [Vector((q.x, q.y, z)) for q, z in zip(pts, sm)]


def make_gut_tube(name, path, r, sides, mat, blood_len=0.04):
    """ONE continuous tube (rings of `sides`, smooth) with its ring frame pinned to world up,
    so v = 0.125 (the wet stripe) always sits on top. u = arc length / 0.16 m (the strip
    tiles: one crease per 40 mm). The first and last `blood_len` taper to half radius and
    take the blood cell; the caps too."""
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    rings = []
    ss = [0.0]
    for i in range(1, len(path)):
        ss.append(ss[-1] + (path[i] - path[i - 1]).length)
    total = ss[-1]
    prev_n = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1))
        n = up - t * up.dot(t)
        if n.length < 0.2 and prev_n is not None:
            n = prev_n - t * prev_n.dot(t)
        n.normalize()
        prev_n = n
        bvec = t.cross(n).normalized()
        rr = r
        edge = min(ss[i], total - ss[i])
        if edge < blood_len:
            rr = r * (0.5 + 0.5 * edge / blood_len)
        ring = [bm.verts.new(p + n * math.cos(2 * math.pi * k / sides) * rr + bvec * math.sin(2 * math.pi * k / sides) * rr) for k in range(sides)]
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        blood = min(ss[i], ss[i + 1], total - ss[i], total - ss[i + 1]) < blood_len
        u0, u1 = ss[i] / 0.16, ss[i + 1] / 0.16
        for k in range(sides):
            v0, v1 = rings[i][k], rings[i][(k + 1) % sides]
            v2, v3 = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            f = bm.faces.new((v0, v1, v2, v3))
            f.smooth = True
            vlo = 0.25 * ((k / sides + 0.5) % 1.0)
            vhi = vlo + 0.25 / sides
            if blood:
                bu0, bu1, bv0, bv1 = UV_BLOOD
                uvs = ((bu0 + (bu1 - bu0) * ((i * 0.37) % 1.0), bv0 + (bv1 - bv0) * (k / sides)),
                       (bu0 + (bu1 - bu0) * ((i * 0.37) % 1.0), bv0 + (bv1 - bv0) * ((k + 1) / sides)),
                       (bu0 + (bu1 - bu0) * (((i + 1) * 0.37) % 1.0), bv0 + (bv1 - bv0) * ((k + 1) / sides)),
                       (bu0 + (bu1 - bu0) * (((i + 1) * 0.37) % 1.0), bv0 + (bv1 - bv0) * (k / sides)))
            else:
                uvs = ((u0, vlo), (u0, vhi), (u1, vhi), (u1, vlo))
            for l, uv in zip(f.loops, uvs):
                l[uv_lay].uv = uv
            faces.append(f)
    for ring in (rings[0], rings[-1][::-1]):
        f = bm.faces.new(ring)
        f.smooth = True
        for l in f.loops:
            l[uv_lay].uv = ((UV_BLOOD[0] + UV_BLOOD[1]) * 0.5 + random.uniform(-0.1, 0.1), (UV_BLOOD[2] + UV_BLOOD[3]) * 0.5 + random.uniform(-0.05, 0.05))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o, total


def make_mesentery(name, hairpins, supports, r, mat, along=0.05):
    """One flat dark-red 6-gon per hairpin, 4 mm above what it lies on, filling the inside of
    the U and the gap between its two runs (the tube hides the rest)."""
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    faces = []
    for (cx_, cy_), ya, yb, d in hairpins:
        w = abs(yb - ya) * 0.5 + 0.004
        rr = abs(yb - ya) * 0.5 + r * 0.35
        pts = [(cx_ - d * along, cy_ - w), (cx_, cy_ - w), (cx_ + d * rr * 0.8, cy_ - w * 0.5),
               (cx_ + d * rr * 0.8, cy_ + w * 0.5), (cx_, cy_ + w), (cx_ - d * along, cy_ + w)]
        vs = []
        for (x, y) in pts:
            z = gp.support_z_under(Vector((x, y, 3.0)), supports, GROUND) + r * 0.9
            vs.append(bm.verts.new((x, y, z)))
        f = bm.faces.new(vs)
        for l in f.loops:
            l[uv_lay].uv = (random.uniform(UV_MES[0], UV_MES[1]), random.uniform(UV_MES[2], UV_MES[3]))
        faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in faces:
        if f.normal.z < 0:
            f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def spill_guts(static, hole_c, floor_z, hy):
    """ONE small intestine (r = GUT_R, GUT_SIDES, smooth), continuous: torn end #1 on the
    cavity floor at the head end, hairpin runs across the floor toward the pelvis end, out
    over the -X rim and its peeled flap, down the flank, hairpin runs on the ground beside the
    hip, torn end #2. Mesentery 6-gons inside every hairpin; the liver under the costal wall.
    Every z comes from support_z_under (floor / flap / flank / ground)."""
    vm = viscera_material()
    r = GUT_R
    cx, cy = hole_c.x, hole_c.y
    fx0, fx1, fy0, fy1 = static["floor_ext"]
    rim_x0, rim_x1 = static["rim_x"]
    # cavity runs: along X inside the floor, pitch GUT_PITCH in Y, from the head end down.
    # The floor is measured; the runs get what fits (the tube must clear the wall by 4 mm).
    y_top = fy1 - r - 0.022            # leave the head end for the liver
    ys = []
    y = y_top - 0.02
    while y - r > fy0 + 0.004 and len(ys) < 4:
        ys.append(y)
        y -= GUT_PITCH

    def floor_half_x(yy):
        """Flat floor width at this y, probed by ray: first x outward whose support is more
        than 5 mm above the floor is the wall."""
        out = []
        for sgn in (1, -1):
            x = cx
            while abs(x - cx) < 0.15 and gp.support_z_under(Vector((x, yy, 3.0)), [static], GROUND) < floor_z + 0.005:
                x += sgn * 0.004
            out.append(abs(x - cx) - 0.004)
        return min(out)
    probe_ys = list(ys) + [(ys[i] + ys[i + 1]) * 0.5 for i in range(len(ys) - 1)]
    half = min([0.046] + [floor_half_x(yy) - HAIRPIN_R - r - 0.004 for yy in probe_ys])
    log("gut: floor half-width probed %s -> run half %.3f" % ([round(floor_half_x(yy), 3) for yy in probe_ys], half))
    if len(ys) % 2 == 1:              # an odd count exits at the -X side...
        start_dir = 1
    else:
        start_dir = -1                # ...an even count must start toward +X
    cav_pts, cav_hair = serpentine(cx - half, cx + half, ys, HAIRPIN_R, start_dir=start_dir)
    # exit over the -X rim: from the last run's -X end, straight out over the flap and down
    # the flank to the ground beside the hip
    y_exit = ys[-1]
    x_end = cav_pts[-1].x
    # find where the flank meets the ground at this y (first x outward whose support is ground)
    x_edge = rim_x0 - 0.03
    while x_edge > rim_x0 - 0.40 and gp.support_z_under(Vector((x_edge, y_exit, 3.0)), [static], GROUND) > 0.012:
        x_edge -= 0.01
    x_g0 = x_edge - 0.02 - r
    trans = []
    n = int((x_end - x_g0) / 0.012) + 1
    for k in range(1, n + 1):
        trans.append(Vector((x_end + (x_g0 - x_end) * k / n, y_exit, 0.0)))
    # ground runs: along X outward from the flank, pitch GUT_PITCH in Y toward the head
    g_len = 0.14
    gys = [y_exit, y_exit + GUT_PITCH, y_exit + GUT_PITCH * 2]
    gnd_pts, gnd_hair = serpentine(x_g0 - g_len, x_g0, gys, HAIRPIN_R, start_dir=-1)
    raw = cav_pts + trans + gnd_pts[1:]
    # organic: a slow sine wobble on every point so no two runs are parallel or dead straight
    for i, q in enumerate(raw):
        q.x += 0.006 * math.sin(i * 0.31 + q.y * 40.0)
        q.y += 0.005 * math.sin(i * 0.23 + q.x * 37.0)
    xy = resample(raw, 0.010)
    supports = [static]
    path = lift_on_supports(xy, supports, r)
    path = decimate_path(resample(path, 0.010), RING_TURN_DEG, RING_STEP)   # rings where it turns, sparse where straight
    gut, length = make_gut_tube("gore_gut", path, r, GUT_SIDES, vm)
    for v in gut.data.vertices:
        if v.co.z < 0.003:
            v.co.z = 0.003
    mes = make_mesentery("gore_mesentery", cav_hair + gnd_hair, [static], r, vm)
    liver = gp.make_lump("gore_liver", (cx + 0.005, y_top + 0.035, floor_z + 0.030), (0.10, 0.062, 0.042), vm, UV_LIVER, seed=4)
    tear_a = path[0].copy()
    tear_b = path[-1].copy()
    dir_a = (path[0] - path[1])
    dir_a.z = 0
    dir_a.normalize()
    dir_b = (path[-1] - path[-2])
    dir_b.z = 0
    dir_b.normalize()
    coil_c = Vector((x_g0 - g_len * 0.5, gys[1], 0.0))
    info = {"loops": len(cav_hair) + len(gnd_hair), "loops_cavity": len(cav_hair), "loops_ground": len(gnd_hair),
            "tube_dia_mm": round(2 * r * 1000, 1), "sides": GUT_SIDES, "rings": len(path), "length_m": round(length, 3),
            "tris_tube": tri_count(gut), "tris_mesentery": tri_count(mes), "tris_liver": tri_count(liver),
            "tear_cavity": [round(v, 3) for v in tear_a], "tear_ground": [round(v, 3) for v in tear_b],
            "cavity_runs_y": [round(v, 3) for v in ys], "floor_ext": list(static["floor_ext"]), "flank_edge_x": round(x_edge, 3)}
    log("gut: %s" % info)
    return gut, mes, liver, coil_c, info, (tear_a, tear_b, dir_a, dir_b)


def make_smear(name, a, b, width, mat):
    """A flat 6-gon on the ground between two points (the drag from the hip to the coil)."""
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    d = (b - a)
    d.z = 0
    d.normalize()
    n = Vector((-d.y, d.x, 0)) * width * 0.5
    mid = (a + b) * 0.5
    pts = [a - n, mid - n * 1.25, b - n * 0.8, b + n * 0.8, mid + n * 1.25, a + n]
    vs = [bm.verts.new((p.x, p.y, 0.005)) for p in pts]
    f = bm.faces.new(vs)
    for l in f.loops:
        l[uv_lay].uv = (gp.FIELD_UV.x + random.uniform(-0.015, 0.015), gp.FIELD_UV.y + random.uniform(-0.015, 0.015))
    bm.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def make_pool_on_sheet(name, centre, rx, ry, mat, seed=3):
    """The piles' pool, on the shared gore sheet directly (no gore_pool_mat copy) and on the
    sheet's dark FIELD, not a disc: a disc stretched over a metre is 3 cm texels of pink."""
    o = gp.make_pool(name, centre, rx, ry, mat, seed=seed)
    o.data.materials.clear()
    o.data.materials.append(mat)
    uv = o.data.uv_layers[0].data
    rnd = random.Random(seed)
    for l in uv:
        l.uv = (gp.FIELD_UV.x + rnd.uniform(-0.02, 0.02), gp.FIELD_UV.y + rnd.uniform(-0.02, 0.02))
    pm = bpy.data.materials.get("gore_pool_mat")
    if pm is not None and pm.users == 0:
        bpy.data.materials.remove(pm)
    return o


def stage_b(static):
    vreg = json.loads(static["vert_bone"])
    hx, hy = static["hips_xy"]
    hole_c, floor_z, rim_idx, (y0, y1) = open_belly(static, vreg)
    log("belly open: centre %s floor z %.3f hole y %.3f..%.3f (%.0f mm long) floor ext %s rim x %s" % (
        tuple(round(v, 3) for v in hole_c), floor_z, y0, y1, (y1 - y0) * 1000, list(static["floor_ext"]), list(static["rim_x"])))
    write_viscera_texture()
    gut, mes, liver, coil_c, ginfo, tears = spill_guts(static, hole_c, floor_z, hy)
    gm = bpy.data.materials.get("gore_cap_mat")
    pool = make_pool_on_sheet("gore_pool", (hx - 0.14, hy + 0.04), 0.36, 0.30, gm, seed=5)
    smear = make_smear("gore_smear", Vector((hx - 0.20, hy - 0.06, 0)), Vector((coil_c.x + 0.04, coil_c.y + 0.02, 0)), 0.16, gm)
    return {"hole": hole_c, "floor_z": floor_z, "rim_idx": rim_idx, "guts": [gut, mes], "loop": None,
            "liver": liver, "pool": pool, "smear": smear, "coil": coil_c, "gut_info": ginfo, "tears": tears}


# ------------------------------------------------------------------ Stage C: helmet, maggots, anchors, export
def helmet_beside_head(F, static, supports):
    """The M1 fallen beside the head, upturned, settled and tilted by measurement (the piles'
    settle / tilt_settle). Decimated by collapse to the faction's ratio."""
    path, name = F["hat"]
    objs = donors.append(path, [name])
    hat = objs[name]
    if F["hat_ratio"] < 1.0:
        md = hat.modifiers.new("dec", 'DECIMATE')
        md.decimate_type = 'COLLAPSE'
        md.ratio = F["hat_ratio"]
        md.use_collapse_triangulate = True
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        hm = hat.evaluated_get(dg).to_mesh()
        nm = bpy.data.meshes.new("helmet_dec")
        hb = bmesh.new()
        hb.from_mesh(hm)
        hb.to_mesh(nm)
        hb.free()
        for mt in hat.data.materials:
            nm.materials.append(mt.original if mt else None)
        hat.evaluated_get(dg).to_mesh_clear()
        hat.modifiers.remove(md)
        old = hat.data
        hat.data = nm
        bpy.data.meshes.remove(old)
    hat.name = "gore_helmet"
    hc = Vector(static["head_c"])
    hat.rotation_euler = Euler((math.radians(160), math.radians(10), math.radians(35)), 'XYZ')
    hat.location = Vector((hc.x - 0.30, hc.y + 0.12, 0.6))
    bpy.context.view_layer.update()
    gp.settle(hat, supports, GROUND)
    deg = gp.tilt_settle(hat, supports, GROUND, max_deg=22.0)
    gp.settle(hat, supports, GROUND)
    mn, mx = bounds(hat)
    log("helmet: %d tris, tilted %.1f deg, lowest z %+.4f, contacts %d" % (tri_count(hat), deg, mn.z, len(gp.contacts(hat, supports, GROUND))))
    return hat


GRUB_BLOCK = (57, 63)     # px rows/cols of the cream block painted into both maggot frames
GRUB_UV = (0.905, 0.985)  # the block in UV (inside 57/64 .. 63/64)


def write_maggot_frames_corpse():
    """The piles' two 64^2 frames, plus a cream 7x7 block in the top-right corner of BOTH
    (identical, so the engine's a/b flip animates the decal and not the grubs). The decal
    patches use UV 0..0.875 and never see the block."""
    outs = gp.write_maggot_frames()
    lo, hi = GRUB_BLOCK
    for path in outs:
        img = bpy.data.images.load(path, check_existing=False)
        w, h = img.size
        px = list(img.pixels)
        for y in range(lo, hi + 1):
            for x in range(lo, hi + 1):
                i = (y * w + x) * 4
                t = (x - lo) / (hi - lo)                # darker toward the head end (low u)
                c = (0.93 - 0.18 * (1 - t), 0.86 - 0.22 * (1 - t), 0.70 - 0.22 * (1 - t))
                px[i:i + 3] = c
        img.pixels = px
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save_render(path)
        bpy.data.images.remove(img)
    return outs


def grub_template(L=0.009, w=0.0034, h=0.0028, bend=0.0006):
    """One maggot: an octahedron stretched along +X (6 verts, 8 tris), the mid ring lifted
    so it bows; the head (+X tip) takes the darker end of the cream block."""
    tip0 = Vector((-L / 2, 0, -bend))
    tip1 = Vector((L / 2, 0, -bend))
    ring = [Vector((0, w / 2, 0)), Vector((0, 0, h / 2)), Vector((0, -w / 2, 0)), Vector((0, 0, -h / 2 * 0.6))]
    verts = [tip0, tip1] + ring
    faces = []
    for k in range(4):
        faces.append((0, 2 + (k + 1) % 4, 2 + k))
        faces.append((1, 2 + k, 2 + (k + 1) % 4))
    u0, u1 = GRUB_UV
    uv_of = [ (u0 + 0.02, (u0 + u1) * 0.5), (u1 - 0.01, (u0 + u1) * 0.5) ] + [((u0 + u1) * 0.5, u0 + 0.01 + 0.06 * k) for k in range(4)]
    return verts, faces, uv_of


def scatter_grubs(name, clumps, supports, seed=41):
    """`clumps` = [(label, centre, radius, count)]. Each grub: a random point in the disc,
    z = the top support under it (ray cast on body + viscera + patches) + 1 mm, random yaw,
    pitch +-12 deg, scale 0.8 / 1.0 / 1.25. All one mesh, one material (the maggot sheet)."""
    rnd = random.Random(seed)
    verts, faces, uv_of = grub_template()
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    placed = []
    for label, centre, radius, count in clumps:
        cx, cy = centre[0], centre[1]
        n_ok = 0
        for _ in range(count):
            for _try in range(6):
                ang = rnd.uniform(0, 2 * math.pi)
                rad = radius * math.sqrt(rnd.random())
                x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
                sz = gp.support_z_under(Vector((x, y, 3.0)), supports, GROUND)
                if label.startswith("ground") or sz > 0.002 or _try == 5:
                    break
            sc = rnd.choice((0.8, 1.0, 1.25))
            yaw = rnd.uniform(0, 2 * math.pi)
            pitch = math.radians(rnd.uniform(-12, 12))
            R = Matrix.Rotation(yaw, 3, 'Z') @ Matrix.Rotation(pitch, 3, 'Y')
            base = Vector((x, y, sz + 0.0011 * sc))
            vs = [bm.verts.new(base + R @ (v * sc)) for v in verts]
            for (i0, i1, i2) in faces:
                f = bm.faces.new((vs[i0], vs[i1], vs[i2]))
                for l, idx in zip(f.loops, (i0, i1, i2)):
                    l[uv_lay].uv = uv_of[idx]
            placed.append((label, round(x, 3), round(y, 3), round(base.z, 4)))
            n_ok += 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(gp.maggot_material())
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o, placed


def maggot_patches(static, supports, tears, mouth_w, pool_c, rim_idx):
    """Two SMALL 2-frame decal patches (under the two gut tears, 4 mm proud, UV 0..0.875)
    and ~150 grubs in clumps: the two tears, the cavity rim, the mouth, the eye corner, the
    ground gut loops, the pool edge. One `maggot_mass` node."""
    ta, tb, da, db = tears        # the two torn ends and the direction each tube end points
    # the patches lie BEYOND each torn end (4 cm past it, on the floor / ground), not on the tube
    pa = ta + da * 0.045
    pb = tb + db * 0.045
    za = gp.support_z_under(Vector((pa.x, pa.y, 3.0)), supports, GROUND)
    zb = gp.support_z_under(Vector((pb.x, pb.y, 3.0)), supports, GROUND)
    a = gp.make_maggot_patch("maggot_tear_cavity", (pa.x, pa.y, za + 0.004), (0.06, 0.045))
    b = gp.make_maggot_patch("maggot_tear_ground", (pb.x, pb.y, zb + 0.004), (0.07, 0.05))
    bpy.context.view_layer.update()
    for o in (a, b):
        gp.apply_xform(o)
        for l in o.data.uv_layers[0].data:
            l.uv = (l.uv.x * 0.875, l.uv.y * 0.875)
    # the eye corner: 45 mm up the face from the mouth, 25 mm toward the -X (upper, since the
    # head rolled to +X) eye, dropped onto the face by the support cast
    eye = (mouth_w[0] - 0.025, mouth_w[1] + 0.045)
    me = static.data
    rim_pts = [me.vertices[i].co for i in rim_idx]
    hx, hy = static["hips_xy"]
    clumps = [("tear_cavity", (ta.x + da.x * 0.02, ta.y + da.y * 0.02), 0.035, 42),
              ("tear_ground", (tb.x + db.x * 0.02, tb.y + db.y * 0.02), 0.035, 34),
              ("mouth", (mouth_w[0], mouth_w[1]), 0.014, 12),
              ("eye", eye, 0.010, 6),
              ("ground_pool_edge_a", (pool_c[0] - 0.24, pool_c[1] + 0.12), 0.03, 5),
              ("ground_pool_edge_b", (pool_c[0] - 0.10, pool_c[1] - 0.22), 0.03, 5),
              ("ground_loops", (tb.x + 0.06, tb.y - 0.03), 0.045, 16)]
    rnd = random.Random(7)
    for k in range(10):
        q = rnd.choice(rim_pts)
        d = Vector((q.x - hx, q.y - hy, 0)).normalized()
        clumps.append(("rim_%d" % k, (q.x + d.x * 0.012, q.y + d.y * 0.012), 0.012, 3))
    grubs, placed = scatter_grubs("maggot_grubs", clumps, supports + [a, b])
    m = gp.join_objects([a, b, grubs], "maggot_mass")
    per = {}
    for lab, x, y, z in placed:
        key = lab.split("_")[0]
        per[key] = per.get(key, 0) + 1
    info = {"grubs": len(placed), "per_clump": per, "tris_grubs": len(placed) * 8, "decal_patches": 2,
            "patch_z": [round(za + 0.004, 3), round(zb + 0.004, 3)], "eye_xy": [round(v, 3) for v in eye]}
    log("maggots: %s" % info)
    return m, info


def anchors_for(hole_c, floor_z, coil_c, mouth_w, tears):
    out = []
    ta, tb = tears
    spots = [("fx_maggots_01", Vector((ta.x, ta.y, ta.z + 0.02))),
             ("fx_maggots_02", Vector((tb.x, tb.y, tb.z + 0.02))),
             ("fx_maggots_03", Vector(mouth_w) + Vector((0, 0, 0.01))),
             ("fx_flies_01", Vector((hole_c.x, hole_c.y, floor_z + 0.30)))]
    for n, p in spots:
        e = bpy.data.objects.new(n, None)
        e.empty_display_type = 'SPHERE'
        e.empty_display_size = 0.04
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        out.append(e)
    return out


def bake_body_atlas(obj, key, res):
    """Bake uniform + face + helmet into one atlas over a fresh UV layer; gore faces keep
    their gore-sheet UVs in the SAME layer and stay on gore_cap_mat. Two materials out."""
    me = obj.data
    gore_names = {"gore_cap_mat"}
    gore_slots = {i for i, m in enumerate(me.materials) if m and m.name in gore_names}
    src_uv = me.uv_layers[0]
    src_uv.name = "donor_uv"
    atlas_uv = me.uv_layers.new(name="atlas_uv")
    src_uv.active_render = True
    me.uv_layers.active_index = me.uv_layers.find("atlas_uv")
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for p in me.polygons:
        p.select = p.material_index not in gore_slots
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.010, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.008)
    except Exception as ex:
        print("[corpse] pack_islands skipped:", ex)
    bpy.ops.object.mode_set(mode='OBJECT')
    auv = me.uv_layers["atlas_uv"].data
    duv = me.uv_layers["donor_uv"].data
    for p in me.polygons:
        for li in p.loop_indices:
            if p.material_index in gore_slots:
                auv[li].uv = (0.995, 0.995)
        p.select = False
    img = bpy.data.images.new("%s_atlas" % key, res, res, alpha=False)
    img.generated_color = (0.2, 0.16, 0.10, 1)
    nodes_added = []
    for slot in obj.material_slots:
        m = slot.material
        if m is None:
            continue
        if not m.use_nodes:
            m.use_nodes = True
        nt = m.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.name = "BAKE_TARGET"
        nt.nodes.active = tex
        nodes_added.append((nt, tex))
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 16
    sc.cycles.use_denoising = False
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 6
    sc.render.bake.use_clear = True
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=False, margin=6)
    path = os.path.join(OUT_DIR, "%s_atlas.png" % key)
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    for nt, tex in nodes_added:
        nt.nodes.remove(tex)
    # PSX palette: 256 colours, no dither. Keeps the 1024^2 face detail and lands the sheet
    # well under Caleb's 1 MB embedded-image law (the 24-bit bake was 1.04 MB).
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        im.save(path, optimize=True)
        log("atlas quantised to 256 colours: %d KB" % (os.path.getsize(path) // 1024))
    except Exception as ex:
        log("atlas quantise skipped:", ex)
    for p in me.polygons:
        if p.material_index in gore_slots:
            for li in p.loop_indices:
                auv[li].uv = duv[li].uv
    mat = bpy.data.materials.new("%s_mat" % key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    img2 = bpy.data.images.load(path, check_existing=False)
    img2.name = "%s_atlas_disk" % key
    tex.image = img2
    tex.interpolation = 'Closest'
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    gm = bpy.data.materials.get("gore_cap_mat")
    old_idx = [p.material_index for p in me.polygons]
    me.materials.clear()
    me.materials.append(mat)
    me.materials.append(gm)
    for p, oi in zip(me.polygons, old_idx):
        p.material_index = 1 if oi in gore_slots else 0
    me.uv_layers.remove(me.uv_layers["donor_uv"])
    me.uv_layers["atlas_uv"].active_render = True
    bpy.data.images.remove(img)
    return path


def render_corpse(key, objs, hips_xy, mouth_w, hole=None, tear_ground=None):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = False
    sc.display.render_aa = 'FXAA'
    sc.render.resolution_x = 900
    sc.render.resolution_y = 700
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.35, 0.36, 0.30)
    ground = bpy.data.objects.get("_render_ground")
    if ground is None:
        me = bpy.data.meshes.new("_render_ground")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6.0)
        bm.to_mesh(me)
        bm.free()
        ground = bpy.data.objects.new("_render_ground", me)
        gmat = bpy.data.materials.new("_ground_mat")
        gmat.diffuse_color = (0.30, 0.24, 0.16, 1)
        me.materials.append(gmat)
        bpy.context.scene.collection.objects.link(ground)
    ground.hide_render = False
    ground.hide_viewport = False
    ground.location = (0, 0, -0.001)
    for o in sc.objects:
        o.hide_render = not (o in objs or o is ground)
    cam = bpy.data.objects.get("_render_cam")
    if cam is None:
        cam = bpy.data.objects.new("_render_cam", bpy.data.cameras.new("_render_cam"))
        bpy.context.scene.collection.objects.link(cam)
    sc.camera = cam
    cx, cy = hips_xy
    look = Vector((cx, cy, 0.12))
    m = Vector(mouth_w)
    views = {
        "4m":   (Vector((cx - 2.6, cy - 2.9, 1.6)), look, 40),
        "1p5m": (Vector((cx - 1.15, cy - 0.95, 1.6)), look, 32),
        "top":  (Vector((cx + 0.01, cy - 0.01, 3.0)), Vector((cx, cy, 0.0)), 30),
        "face": (Vector((m.x + 0.75, m.y + 0.75, 1.6)), Vector((m.x, m.y, m.z)), 60),
    }
    if hole is not None:
        h = Vector(hole)
        views["guts"] = (h + Vector((-0.38, -0.26, 0.66)), h + Vector((0, 0, 0.04)), 40)       # 0.80 m into the cavity
    if tear_ground is not None:
        t = Vector(tear_ground)
        views["maggots"] = (t + Vector((-0.22, -0.20, 0.26)), t, 50)                          # 0.40 m onto the clump
    outs = []
    for tag, (pos, at, lens) in views.items():
        cam.location = pos
        cam.data.lens = lens
        fwd = (at - pos).normalized()
        upw = Vector((0, 1, 0)) if tag == "top" else Vector((0, 0, 1))
        right = fwd.cross(upw).normalized()
        up = right.cross(fwd).normalized()
        R = Matrix((right, up, -fwd)).transposed()   # camera looks down its -Z, +Y is up
        cam.rotation_euler = R.to_euler()
        path = os.path.join(RENDER_DIR, "%s_%s.png" % (key, tag))
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        outs.append(path)
    for o in sc.objects:
        o.hide_render = False
    ground.hide_render = True
    ground.hide_viewport = True
    return outs


def export_corpse(name, mesh_obj, maggots, hull, anchors):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    sel = [mesh_obj, maggots, hull] + anchors
    for o in sel:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj
    path = os.path.join(OUT_DIR, "%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT',
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_image_format='AUTO', export_texcoords=True, export_normals=True,
                              export_extras=False)
    for o in sel:
        o.select_set(False)
    return path


def save_blend():
    bpy.context.preferences.filepaths.save_version = 0
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True, copy=False)
    b1 = BLEND_OUT + "1"
    if os.path.exists(b1):
        os.remove(b1)


def stage_c(F, static, B):
    NAME = "gore_corpse_%s" % FACTION
    hips_xy = list(static["hips_xy"])
    mouth_w = list(static["mouth_w"])
    hat = helmet_beside_head(F, static, [static])
    viscera = B["guts"] + [B["liver"]]
    pool_c = (hips_xy[0] - 0.14, hips_xy[1] + 0.04)
    mag, minfo = maggot_patches(static, [static] + viscera, B["tears"], mouth_w, pool_c, B["rim_idx"])
    tears = B["tears"][:2]
    anchors = anchors_for(B["hole"], B["floor_z"], B["coil"], mouth_w, tears)
    parts = [static] + viscera + [B["pool"], B["smear"], hat]
    ground_gate = []
    for o in parts:
        mn, mx = bounds(o)
        ground_gate.append((o.name, round(mn.z, 4)))
    pen = gp.penetration_report([static] + viscera + [hat])
    pen["gut_in_body"] = inside_detail(B["guts"][0], static)
    log("gut verts inside the body: %s" % pen["gut_in_body"])
    mesh = gp.join_objects(parts, NAME)
    gp.clean_mesh(mesh)
    clean_maggots(mag)
    shift = Vector((-hips_xy[0], -hips_xy[1], 0.0))
    mesh.data.transform(Matrix.Translation(shift))
    mesh.data.update()
    mag.data.transform(Matrix.Translation(shift))
    mag.data.update()
    for a in anchors:
        a.location += shift
    mouth_w = list(Vector(mouth_w) + shift)
    hole = Vector(B["hole"]) + shift
    coil = Vector(B["coil"]) + shift
    tears_s = [list(Vector(t) + shift) for t in tears]
    bpy.context.view_layer.update()
    tris = tri_count(mesh)
    hull = gp.make_hull(mesh, "%s_000-colonly" % NAME)
    atlas = bake_body_atlas(mesh, NAME, ATLAS_RES)
    mn, mx = bounds(mesh)
    rep = {"tris": tris, "budget": BUDGET, "ok": tris <= BUDGET and mn.z >= -0.002,
           "tris_maggots": tri_count(mag), "tris_collider": tri_count(hull),
           "footprint_m": [round(mx.x - mn.x, 3), round(mx.y - mn.y, 3)], "height_m": round(mx.z - mn.z, 3),
           "bbox_min": [round(v, 3) for v in mn], "bbox_max": [round(v, 3) for v in mx],
           "origin": "ground contact under the pelvis (Hips bone head XY), z = 0",
           "ground_gate": ground_gate, "penetration": pen,
           "anchors": {a.name: [round(v, 3) for v in a.location] for a in anchors},
           "cavity": [round(v, 3) for v in hole], "coil": [round(v, 3) for v in coil],
           "tears": [[round(v, 3) for v in t] for t in tears_s],
           "mouth": [round(v, 3) for v in mouth_w],
           "guts": B["gut_info"], "maggots": minfo,
           "atlas": os.path.basename(atlas), "atlas_res": ATLAS_RES,
           "materials": [m.name for m in mesh.data.materials] + [m.name for m in mag.data.materials],
           "nodes": [mesh.name, mag.name, hull.name] + [a.name for a in anchors]}
    glb = export_corpse(NAME, mesh, mag, hull, anchors)
    rep["glb"] = os.path.relpath(glb, ROOT).replace("\\", "/")
    rep["glb_bytes"] = os.path.getsize(glb)
    if not NORENDER:
        rep["renders"] = [os.path.relpath(p, ROOT).replace("\\", "/") for p in render_corpse(NAME, [mesh, mag], (0.0, 0.0), mouth_w, hole, tears_s[1])]
    return rep, mesh, mag, hull, anchors


def inside_detail(a, b, thresh=-0.008, n=6):
    """Vertices of `a` the closest-point test calls inside `b`, then PROVED or acquitted: a ray
    cast straight down from the vertex that first hits one of b's faces from BEHIND (normal
    pointing away from the ray origin) is truly inside; a front face or nothing under it means
    the vertex is under an overhang (the peeled cloth flap is a single-sided sheet, and
    'below its top' is air, not body). Reports both counts and the worst positions."""
    Mi = b.matrix_world.inverted()
    M3 = b.matrix_world.to_3x3()
    Mn = M3.inverted().transposed()
    d_loc = (Mi.to_3x3() @ Vector((0, 0, -1))).normalized()
    flagged, proven = [], []
    for v in a.data.vertices:
        p = a.matrix_world @ v.co
        hit, loc, nrm, idx = b.closest_point_on_mesh(Mi @ p)
        if not hit:
            continue
        d = (p - (b.matrix_world @ loc)).dot((Mn @ nrm).normalized())
        if d >= thresh:
            continue
        rec = (round(d, 3), [round(c, 3) for c in p])
        flagged.append(rec)
        h2, loc2, nrm2, idx2 = b.ray_cast(Mi @ p, d_loc)
        if h2 and (Mn @ nrm2).normalized().z < 0:      # face seen from behind: inside
            proven.append(rec)
    flagged.sort()
    proven.sort()
    return {"flagged_by_closest_point": len(flagged), "proven_inside_by_ray": len(proven),
            "worst_flagged": flagged[:n], "worst_proven": proven[:n]}


def clean_maggots(obj):
    """Triangulate only - remove_doubles would weld the tips of touching grubs together."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    zero = [f for f in bm.faces if f.calc_area() < 1e-9]
    bmesh.ops.delete(bm, geom=zero, context='FACES')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def write_manifest(rep):
    man = {"contract": {
        "ballistics": "Placed by place_structure: CollisionTable.is_soft(<glb basename>) decides. Owed row: "
                      "scripts/world/collision_table.gd MATERIALS[\"gore_corpse_us\"] = Mat.THATCH (soft) and a "
                      "STRUCTURES row {box, y_offset, footprint, scale 1.0, mesh: true} from footprint_m/bbox.",
        "destruction": "Owed rows: {\"prefix\": \"gore_corpse_\", \"kind\": \"gore_corpse\"} in site_planner.FSB_STRUCTURE_KINDS "
                       "and \"gore_corpse\": <hp> in Destructible.HP_FOR. Until they exist the prop is loud-warned and HARD.",
        "collider": "<name>_000-colonly: convex hull trimesh of the body + viscera + helmet (pool, smear and maggots excluded).",
        "maggots": "maggot_mass mesh = ~150 geometry grubs (8 tris each, UV pinned to the cream block in the sheet's "
                   "top-right 7x7 px) over two small decal patches (UV 0..0.875 of one 64x64 frame), material "
                   "gore_pile_maggots. Swap the albedo between maggots_a.png and maggots_b.png at ~6 Hz (the block is "
                   "identical in both, so only the patches crawl); both PNGs ship beside the GLB.",
        "anchors": "Empties fx_maggots_01 (gut tear in the cavity), fx_maggots_02 (gut tear on the ground), fx_maggots_03 (mouth), fx_flies_01 "
                   "(0.30 m above the cavity) - hang particle emitters here. Metres, Blender Z-up, origin under the pelvis.",
        "origin": "Ground contact z = 0 at the pelvis (Hips bone head XY). The footprint is NOT centred on the origin: "
                  "read bbox_min/bbox_max.",
        "materials": "Two on the corpse: <name>_mat (baked uniform + face + helmet + VISCERA atlas, Closest) and gore_cap_mat "
                     "(the shared 128^2 gore sheet: cavity walls, pool, smear, wound ring). maggot_mass carries gore_pile_maggots.",
        "guts": "One continuous intestine tube (see corpses.<f>.guts: loops, tube_dia_mm, tears). Painted on "
                "gore_corpse_viscera.png (source only; baked into the atlas).",
    }, "corpses": {FACTION: rep}}
    with open(os.path.join(OUT_DIR, "gore_corpse_manifest.json"), "w") as f:
        json.dump(man, f, indent=2)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    F = FACTIONS[FACTION]
    static, rig, body, rep_a = stage_a(F)
    save_blend()
    if STOP == "pose":
        quick_render([static], "_wip_pose_top", (0.01, 0.0, 3.2), (0, 0, 0.1), lens=30)
        quick_render([static], "_wip_pose_3q", (1.6, -2.4, 1.6), (0, 0, 0.1), lens=35)
        quick_render([static], "_wip_pose_side", (2.2, 0.3, 1.2), (0, 0.1, 0.15), lens=40)
        sys.exit(0)
    gp.OUT_DIR = OUT_DIR
    write_maggot_frames_corpse()
    B = stage_b(static)
    save_blend()
    if STOP == "viscera":
        objs = [static] + B["guts"] + [B["liver"], B["pool"], B["smear"]]
        quick_render(objs, "_wip_viscera_3q", (-1.3, -1.1, 1.3), (B["hole"].x - 0.1, B["hole"].y, 0.1), lens=40)
        quick_render(objs, "_wip_viscera_top", (0.01, 0.0, 2.6), (0, 0, 0.0), lens=30)
        h = B["hole"]
        quick_render(objs, "_wip_viscera_guts", (h.x - 0.38, h.y - 0.26, h.z + 0.66), (h.x, h.y, h.z + 0.04), lens=40)
        quick_render(objs, "_wip_viscera_1p5", (h.x - 1.15, h.y - 0.95, 1.6), (h.x, h.y, 0.12), lens=32)
        sys.exit(0)
    rep, mesh, mag, hull, anchors = stage_c(F, static, B)
    rep["pose_contacts"] = rep_a
    write_manifest(rep)
    rep["pose_gates"] = rep_a.pop("_gates", {})
    write_manifest(rep)
    log("RESULT tris %d/%d  maggots %d  hull %d  footprint %s  height %.3f  glb %.1f KB  ok=%s" % (
        rep["tris"], BUDGET, rep["tris_maggots"], rep["tris_collider"], rep["footprint_m"], rep["height_m"], rep["glb_bytes"] / 1024.0, rep["ok"]))
    log("pose gates", json.dumps(rep["pose_gates"]))
    log("penetration", rep["penetration"])
    for img in bpy.data.images:
        if img.size[0] > 2048 or img.size[1] > 2048:
            img.scale(img.size[0] // 4, img.size[1] // 4)
            img.pack()
    for o in list(bpy.data.objects):
        if o.name.startswith("_render"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    save_blend()
    log("saved", BLEND_OUT)
