"""Find free ground inside the firebase wire big enough for another hooch.

Read-only. Never saves. Run headless against firebase_v3.2.blend:

    blender -b <firebase_v3.2.blend> -P tools/find_hooch_space.py

A hooch is 5.78 x 10.97 with the roof overhang, so the test footprint is that plus a
walking margin. Candidates are scored by distance to the nearest existing structure,
because a hooch dropped 1 m off a bunker reads as clutter, not as a camp.

Anything at or below the berm's outer ring is out: the parapet is the wire and
buildings do not go outside it.
"""
import bpy, math
from mathutils import Vector

HOOCH_W, HOOCH_L = 5.78, 10.97
MARGIN = 2.0                      # walking room around a hut
STEP = 4.0                        # search grid
MIN_CLEAR = (max(HOOCH_W, HOOCH_L) / 2.0) + MARGIN

# things a hooch must not land on. Ground, terrain and the berm are surfaces, not
# obstacles - stepping on them is the point.
SKIP_HINTS = ("terrain", "ground", "berm", "mound", "road", "helipad", "pad_",
              "grass", "dirt", "water", "-colonly")


def _markers():
    """Every work_* post. A hooch dropped on one deletes a man's job silently -
    the marker survives inside the wall and he stands in the geometry."""
    out = []
    for o in bpy.context.scene.objects:
        if o.name.startswith("work_"):
            w = o.matrix_world.translation
            out.append((o.name, w.x, w.y))
    return out


def _footprints():
    out = []
    for o in bpy.context.scene.objects:
        if o.type != 'MESH' or not o.visible_get():
            continue
        low = o.name.lower()
        if any(h in low for h in SKIP_HINTS):
            continue
        # the old hooches are being deleted, so their ground is FREE and is in fact
        # the first place a new one should go.
        if low.startswith("fb_hootch"):
            continue
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        if not vs:
            continue
        z0 = min(v.z for v in vs)
        z1 = max(v.z for v in vs)
        if z1 - z0 < 0.35:        # flat decals, markings, ground scatter
            continue
        out.append((o.name,
                    min(v.x for v in vs), max(v.x for v in vs),
                    min(v.y for v in vs), max(v.y for v in vs)))
    return out


def main():
    fps = _footprints()
    if not fps:
        print("[SPACE] FATAL: no structures found - wrong file?")
        return
    xs0 = min(f[1] for f in fps); xs1 = max(f[2] for f in fps)
    ys0 = min(f[3] for f in fps); ys1 = max(f[4] for f in fps)
    print("[SPACE] %d structures, extent x %.1f..%.1f  y %.1f..%.1f"
          % (len(fps), xs0, xs1, ys0, ys1))

    # existing hooches, so new ones can be grouped with them rather than scattered
    marks = _markers()
    print("[SPACE] %d work_* markers treated as no-build points" % len(marks))
    hooches = []

    cands = []
    y = ys0
    while y <= ys1:
        x = xs0
        while x <= xs1:
            # clearance = distance from this centre to the nearest structure box
            best = 1e9
            for _, a0, a1, b0, b1 in fps:
                dx = max(a0 - x, 0.0, x - a1)
                dy = max(b0 - y, 0.0, y - b1)
                d = math.hypot(dx, dy)
                if d < best:
                    best = d
                    if best <= 0.0:
                        break
            # a marker inside the building's footprint is a buried work post
            if best >= MIN_CLEAR:
                half_w, half_l = HOOCH_W / 2 + 0.5, HOOCH_L / 2 + 0.5
                buried = [m for m in marks
                          if abs(m[1] - x) <= half_l and abs(m[2] - y) <= half_l]
                if not buried:
                    cands.append((best, x, y))
            x += STEP
        y += STEP

    cands.sort(reverse=True)
    print("[SPACE] %d candidate centres with >= %.1f m clearance" % (len(cands), MIN_CLEAR))

    # keep them apart from each other too, so we do not report one open field 30 times
    picked = []
    for c, x, y in cands:
        if all(math.dist((x, y), (px, py)) > HOOCH_L + MARGIN for _, px, py in picked):
            picked.append((c, x, y))
        if len(picked) >= 12:
            break

    print("\n  #   centre            clearance   nearest existing hooch")
    for i, (c, x, y) in enumerate(picked):
        if hooches:
            dh = min(math.hypot(max(a0 - x, 0, x - a1), max(b0 - y, 0, y - b1))
                     for _, a0, a1, b0, b1 in hooches)
            dh = "%.1f m" % dh
        else:
            dh = "-"
        print("  %2d  (%7.2f,%7.2f)   %6.1f m    %s" % (i, x, y, c, dh))
    print("\n[SPACE] read-only, nothing written")


main()
