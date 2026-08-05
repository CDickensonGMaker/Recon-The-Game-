"""THE GATE: no piece of gear may have a vertex inside the body.

    from probe_gear_fit import inside_report, assert_clear

"elbows must never intersect a body" is the owner's standing #1 ruling. It is not an
eyeball check. This is the numeric form of it, and every builder that hangs something on
a man must call assert_clear() before it exports.

THE TEST. For each gear vertex, take the body's CLOSEST SURFACE POINT and its normal,
both in the BODY'S OBJECT SPACE (obj.closest_point_on_mesh, never scene.ray_cast — a
scene ray answers a different question and will quietly agree with you). The vertex is
INSIDE when (v - hit) . normal < 0.

THE PROXIMITY FILTER IS NOT OPTIONAL. A vertex 40 cm from the surface it was matched
against is a different body part, and its normal is meaningless there. Anything beyond
`proximity` is reported as UNCOVERED and excluded from the verdict — so the denominator
is always visible and a clean answer can never come from an empty test.
"""
import bpy
from mathutils import Vector

# The REST pose is a T-pose, so the forearm hangs in the air at hip height and about
# 40 cm out from the flank - exactly where a slung bag lives. A gear vertex "inside the
# forearm" in REST is NOT a poke-through: in every clip the arms are down or on a
# rifle, and no bag is ever tested against a horizontal arm. Measuring against the whole
# rest body is a test that returns a confident answer to the wrong question, and it made
# the first fitted bag refuse to converge - it was fleeing the torso straight into the
# arm.  The torso, hips, legs, neck, head and SHOULDERS all stay in: a sling really must
# not sink into a shoulder.
ARM_BONES = ("LeftArm", "LeftForeArm", "LeftHand",
             "RightArm", "RightForeArm", "RightHand")


def limb_mask(body, words=ARM_BONES):
    """-> (vert_is_limb, poly_is_limb) by DOMINANT skin weight.

    Dominant weight, not "has any weight": a shoulder vertex carries a little LeftArm
    and would be thrown away by an any-weight test, taking the trapezius with it.
    """
    gi = {g.index: g.name for g in body.vertex_groups}
    bad = set(i for i, n in gi.items() if any(w in n for w in words))
    vmask = [False] * len(body.data.vertices)
    for v in body.data.vertices:
        best, bestw = None, -1.0
        for g in v.groups:
            if g.weight > bestw:
                best, bestw = g.group, g.weight
        vmask[v.index] = best in bad
    pmask = [False] * len(body.data.polygons)
    for p in body.data.polygons:
        n = sum(1 for i in p.vertices if vmask[i])
        pmask[p.index] = n * 2 > len(p.vertices)
    return vmask, pmask


def inside_report(body, gear, proximity=0.35, eps=0.0, pmask=None):
    """-> (rows, total_inside, total_covered, deepest). One row per gear object."""
    inv = body.matrix_world.inverted()
    if pmask is None:
        pmask = limb_mask(body)[1]
    rows = []
    t_in = t_cov = 0
    deepest = 0.0
    for ob in sorted(gear, key=lambda o: o.name):
        if ob.type != 'MESH':
            continue
        n_in = n_cov = 0
        worst = 0.0
        for v in ob.data.vertices:
            p = inv @ (ob.matrix_world @ v.co)
            ok, hit, nor, idx = body.closest_point_on_mesh(p)
            if not ok or (0 <= idx < len(pmask) and pmask[idx]):
                continue
            d = (p - hit).length
            if d > proximity:
                continue
            n_cov += 1
            if (p - hit).dot(nor) < -eps:
                n_in += 1
                worst = max(worst, d)
        rows.append((ob.name, n_in, n_cov, len(ob.data.vertices), worst))
        t_in += n_in
        t_cov += n_cov
        deepest = max(deepest, worst)
    return rows, t_in, t_cov, deepest


def print_report(tag, rows, t_in, t_cov, deepest):
    print("  [%s] gear-fit gate" % tag)
    for name, n_in, n_cov, n_tot, worst in rows:
        print("     %-24s inside %3d / covered %3d / total %3d   deepest %.1f cm"
              % (name, n_in, n_cov, n_tot, worst * 100.0))
    print("     TOTAL inside %d / covered %d   deepest %.1f cm"
          % (t_in, t_cov, deepest * 100.0))


def assert_clear(tag, body, gear, proximity=0.35, allow=0, pmask=None):
    """Raise unless ZERO gear verts are inside the body."""
    rows, t_in, t_cov, deepest = inside_report(body, gear, proximity, pmask=pmask)
    print_report(tag, rows, t_in, t_cov, deepest)
    if t_cov == 0:
        raise RuntimeError(
            "[%s] gear-fit gate covered ZERO vertices. A test that measures nothing "
            "returns a clean answer for the wrong reason." % tag)
    if t_in > allow:
        raise RuntimeError(
            "[%s] %d gear vertices are INSIDE the body (deepest %.1f cm). "
            "'Gear never intersects a body' is a standing ruling — fix the BUILDER."
            % (tag, t_in, deepest * 100.0))
    return t_in, t_cov
