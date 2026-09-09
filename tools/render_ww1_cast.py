"""render_ww1_cast.py - the Conquest of Worms WW1 cast, rendered FROM THE SHIPPED GLBs.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --factory-startup --python tools/render_ww1_cast.py -- [lineup|sheets|all]

RENDERS FROM THE EXPORT, NEVER FROM THE SOURCE. This file contains no call to
`wm.open_mainfile` or `wm.open` - every figure arrives through `import_scene.gltf`, so
what is photographed is the bytes the engine will load. Three renders lied on this project
earlier tonight because they came from a .blend with a live procedural material that glTF
cannot carry; a render of the source is a render of a different asset.

FAILURE MODE 9 (psx-npc-pipeline): a GLB round-trip turns every gib donor back ON.
The joined body is the visible man; grunt_* / cap_* / head_frag_* / Base_Human are donors
and must be hidden or each figure reads as a broken model with severed parts at his feet.
The glTF importer also spawns stray `Icosphere` bone-display furniture. Counts are printed
before anything renders.

EXPOSURE IS MEASURED, NOT EYEBALLED. After the front frame of each man the script samples
the rendered pixels inside his silhouette and reports them against the RGB the uniform was
authored at, plus the fraction of clipped pixels. Feldgrau that renders as pale green, or
horizon blue blown to white, shows up as a number here before anybody looks at a picture.
"""
import bpy
import os
import sys
import math
import json
import numpy as np
from mathutils import Vector

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "ww1", "characters")
OUTDIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")
os.makedirs(OUTDIR, exist_ok=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
WHAT = [a for a in argv if not a.startswith("--")] or ["all"]

# label, year, kit line, and the RGB the uniform coat was authored at (for the probe)
FIGURES = [
    ("louie_1915", "LOUIE - 17", "April-May 1915",
     "kepi over the cerveliere era | capote M1914 Poiret (single-breasted) | Lebel",
     (150, 161, 171)),
    ("poilu_a", "POILU, LINE (older man)", "May 1915",
     "bare kepi, red band | capote M1877 (DOUBLE-breasted) | pantalon garance | Berthier",
     (58, 66, 84)),
    ("poilu_b", "POILU, LINE (young)", "May 1915",
     "kepi + cerveliere worn ON TOP | capote M1914, dark 'English' cloth | Berthier",
     (101, 110, 122)),
    ("louie_adrian", "LOUIE", "September 1915",
     "casque Adrian M15 | capote M1914 Poiret, UNCHANGED | Lebel",
     (150, 161, 171)),
    ("poilu_1916", "POILU, LINE", "1916",
     "casque Adrian M15 | capote M1915 (DOUBLE-breasted) | Berthier",
     (133, 145, 153)),
    ("german_boy", "THE YOUNG GERMAN (spared)", "1915",
     "Pickelhaube + Ueberzug, GREEN number | M1907/10 Feldrock | Gewehr 98 | SCARRED CHEEK",
     (100, 104, 86)),
    ("german_line", "GERMAN INFANTRYMAN", "1915",
     "Pickelhaube + Ueberzug, NO number | M1907/10 Feldrock | steingrau | Gewehr 98",
     (95, 99, 82)),
]
SPACING = 1.05
DONOR_PREFIX = ("grunt_", "cap_", "head_frag_", "Base_Human", "Icosphere")

bpy.ops.wm.read_factory_settings(use_empty=True)
# Bind the scene AFTER the factory reset: holding a reference across it leaves a stale
# StructRNA and the next attribute write dies with "Scene has been removed".
SC = bpy.context.scene
D = bpy.data


def is_donor(o):
    return any(o.name.split(".")[0].startswith(p) for p in DONOR_PREFIX)


def wbb(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


def setup_render():
    try:
        SC.render.engine = 'BLENDER_EEVEE_NEXT'
    except TypeError:
        SC.render.engine = 'BLENDER_EEVEE'
    SC.render.image_settings.file_format = 'PNG'
    SC.render.film_transparent = False
    SC.view_settings.view_transform = 'Standard'
    SC.view_settings.look = 'None'
    SC.view_settings.exposure = 0.0
    SC.view_settings.gamma = 1.0
    try:
        SC.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    wd = D.worlds.new("studio_grey")
    wd.use_nodes = True
    wd.node_tree.nodes["Background"].inputs[0].default_value = (0.235, 0.235, 0.245, 1.0)
    wd.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    SC.world = wd


LIGHTS = []


def light_rig(centre, radius):
    for o in LIGHTS:
        D.objects.remove(o, do_unlink=True)
    LIGHTS[:] = []
    r = max(radius, 1.2)
    # Energies deliberately below the US-cast rig. That rig was tuned against olive drab;
    # horizon blue is a much lighter cloth (authored up to RGB 150,161,171) and the same
    # key blew it to near-white in the first test. The probe below is what settled these.
    for name, off, energy, size, rot in (
            ("key", (-1.6, -1.9, 1.5), 150, 3.0, (52, 0, -40)),
            ("fill", (2.0, -1.6, 0.5), 62, 4.0, (78, 0, 52)),
            ("rim", (0.4, 2.4, 1.8), 78, 3.0, (-58, 0, 178)),
            ("bounce", (0.0, -1.0, -1.6), 40, 4.0, (-90, 0, 0))):
        ld = D.lights.new(name, 'AREA')
        ld.energy = energy * r * r
        ld.size = size * r
        ld.color = (1.0, 0.985, 0.96)
        o = D.objects.new(name, ld)
        SC.collection.objects.link(o)
        o.location = centre + Vector(off) * r
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        LIGHTS.append(o)


cam_data = D.cameras.new("cam")
cam_data.type = 'ORTHO'
cam = D.objects.new("cam", cam_data)
SC.collection.objects.link(cam)
SC.camera = cam


def shoot(path, focus, ortho, theta_deg, elev_deg, res, span_hint=4.0):
    th, el = math.radians(theta_deg), math.radians(elev_deg)
    dist = max(span_hint, 2.0) * 3.0
    cam.location = focus + Vector((math.sin(th) * math.cos(el),
                                   -math.cos(th) * math.cos(el),
                                   math.sin(el))) * dist
    cam.rotation_euler = (math.radians(90) - el, 0.0, th)
    cam_data.ortho_scale = ortho
    cam_data.clip_start = 0.05
    cam_data.clip_end = dist * 4.0
    SC.render.resolution_x, SC.render.resolution_y = res
    SC.render.resolution_percentage = 100
    SC.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def exposure_probe(path, target_rgb, label):
    """Measure the rendered frame instead of trusting the light rig.

    Samples every pixel that is not the flat studio background, reports the median RGB
    against the colour the cloth was authored at, and counts blown pixels. A render that
    looks fine and is two stops hot reads as a number here.
    """
    # Read the PNG back through Blender, not PIL: under --factory-startup the extension
    # site-packages is not on sys.path and `import PIL` dies. Colour space is forced to
    # Non-Color so `pixels` returns the STORED values rather than a linearised copy -
    # otherwise the probe compares a linear float against an sRGB byte and reports
    # nonsense with total confidence.
    img = D.images.load(path)
    img.colorspace_settings.name = 'Non-Color'
    w, h = img.size
    buf = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(buf)
    a = (buf.reshape(h, w, img.channels)[..., :3] * 255.0).astype(np.float32)
    D.images.remove(img)
    bg = np.array([0.235, 0.235, 0.245]) ** (1 / 2.2) * 255.0
    d = np.abs(a - bg[None, None, :]).sum(axis=2)
    m = d > 26
    if m.sum() < 500:
        print("      exposure probe: only %d subject pixels - probe not meaningful"
              % int(m.sum()), flush=True)
        return
    sub = a[m]
    med = np.median(sub, axis=0)
    blown = float((sub.max(axis=1) >= 250).mean())
    crushed = float((sub.max(axis=1) <= 6).mean())
    tgt = np.array(target_rgb, dtype=np.float32)
    ratio = float(np.median(sub.mean(axis=1)) / max(tgt.mean(), 1.0))
    print("      exposure probe %-11s subject %6d px | median RGB %5.1f %5.1f %5.1f | "
          "coat authored %3d %3d %3d | lit/authored %.2f | blown %.2f%% | crushed %.2f%%"
          % (label, int(m.sum()), med[0], med[1], med[2],
             target_rgb[0], target_rgb[1], target_rgb[2], ratio,
             100 * blown, 100 * crushed), flush=True)
    if blown > 0.02:
        print("      !! %.1f%% of the subject is clipped white - the frame is over-exposed"
              % (100 * blown), flush=True)


def load(tag):
    path = os.path.join(CHAR, "ww1_%s.glb" % tag)
    if not os.path.exists(path):
        raise SystemExit("ABORT: missing %s" % path)
    before = set(D.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in D.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    rigs = [o for o in new if o.type == 'ARMATURE']
    donors = [o for o in meshes if is_donor(o)]
    visible = [o for o in meshes if not is_donor(o)]
    joined = [o for o in visible if "_joined" in o.name]
    for o in new:
        o.hide_render = False
        o.hide_viewport = False
    for o in donors:
        o.hide_render = True
        o.hide_viewport = True
    bpy.context.view_layer.update()
    if len(joined) != 1:
        raise SystemExit("ABORT %s: %d joined bodies, expected 1 (%s)"
                         % (tag, len(joined), [o.name for o in joined]))
    print("VISIBILITY %-13s joined %d/1 | donors hidden %2d (grunt_ %d, cap_ %d, "
          "head_frag_ %d, Base_Human %d, Icosphere %d) | drawn %2d | rig %s scale %s"
          % (tag, len(joined), len(donors),
             sum(1 for o in donors if o.name.startswith("grunt_")),
             sum(1 for o in donors if o.name.startswith("cap_")),
             sum(1 for o in donors if o.name.startswith("head_frag_")),
             sum(1 for o in donors if o.name.startswith("Base_Human")),
             sum(1 for o in donors if o.name.startswith("Icosphere")),
             len(visible), rigs[0].name if rigs else "-",
             tuple(round(v, 4) for v in rigs[0].scale) if rigs else "-"), flush=True)
    return new, visible, joined[0], [o for o in new if o.parent is None]


def hide_all():
    for o in D.objects:
        if o.type == 'MESH':
            o.hide_render = True


setup_render()


# ---------------------------------------------------------------------------
# THE LINEUP - one camera, one light rig, one ground line, TRUE RELATIVE SCALE
# ---------------------------------------------------------------------------
def lineup():
    for o in list(D.objects):
        if o.type in ('MESH', 'ARMATURE', 'EMPTY'):
            D.objects.remove(o, do_unlink=True)
    shown, rows = [], []
    for i, (tag, name, year, kit, coat) in enumerate(FIGURES):
        new, visible, body, roots = load(tag)
        mn, mx = wbb(visible)
        bmn, bmx = wbb([body])
        # measure as imported, move only in X, drop each man's own feet to z=0.
        # NEVER rescale to match: the whole point of a lineup is relative stature.
        dx = i * SPACING - (bmn.x + bmx.x) * 0.5
        for r in roots:
            r.location.x += dx
            r.location.z -= mn.z
        bpy.context.view_layer.update()
        mn2, mx2 = wbb(visible)
        b2, b2x = wbb([body])
        rows.append((tag, i * SPACING, mx2.z - mn2.z, b2x.z - b2.z, mn2.z))
        shown += visible
        print("   %-13s placed at x=%.3f | overall %.4f m | bare body %.4f m | feet z=%.5f"
              % (tag, i * SPACING, mx2.z - mn2.z, b2x.z - b2.z, mn2.z), flush=True)

    mn, mx = wbb(shown)
    print("LINEUP bbox x[%.3f,%.3f] z[%.4f,%.4f] | feet spread %.5f m (should be ~0)"
          % (mn.x, mx.x, mn.z, mx.z, mn.z), flush=True)
    c = (mn + mx) * 0.5
    light_rig(c, (mx.z - mn.z) * 0.75)

    # FIT THE CANVAS TO THE GROUP. Seven T-posed men on one ground line are ~8 m wide and
    # 1.75 m tall; rendered 4:3 they would fill a fifth of the frame height.
    span = mx - mn
    RES_X, RES_Y = 2800, 900
    A = RES_X / float(RES_Y)
    ortho = max(span.x + 0.35, ((mx.z - mn.z) / 0.84) * A)
    focus = Vector((c.x, c.y, mn.z + (mx.z - mn.z) * 0.5))
    p = os.path.join(OUTDIR, "ww1_LINEUP_all_seven.png")
    shoot(p, focus, ortho, 0.0, 3.0, (RES_X, RES_Y), span_hint=span.length)
    print("RENDERED %s ortho=%.3f %dx%d (men fill %.0f%% of frame height)"
          % (p, ortho, RES_X, RES_Y, 100.0 * (mx.z - mn.z) / (ortho / A)), flush=True)
    with open(os.path.join(OUTDIR, "_ww1_lineup_frame.txt"), "w") as f:
        json.dump(dict(cx=c.x, ortho=ortho, rx=RES_X, ry=RES_Y,
                       figs=[dict(tag=t, wx=wx, h=h, bare=b) for t, wx, h, b, _ in rows]), f)
    return p


# ---------------------------------------------------------------------------
# PER MAN - front, three-quarter, portrait
# ---------------------------------------------------------------------------
def sheets():
    made = []
    for tag, name, year, kit, coat in FIGURES:
        for o in list(D.objects):
            if o.type in ('MESH', 'ARMATURE', 'EMPTY'):
                D.objects.remove(o, do_unlink=True)
        new, visible, body, roots = load(tag)
        mn, mx = wbb(visible)
        for r in roots:
            r.location.z -= mn.z
        bpy.context.view_layer.update()
        # frame on the BODY, not on the whole set: a T-pose rifle sticks a metre out to
        # one side and centring on the full bbox shrinks the man to nothing.
        bmn, bmx = wbb([body])
        c = (bmn + bmx) * 0.5
        h = bmx.z - bmn.z
        light_rig(c, h * 0.5)
        focus = Vector((c.x, c.y, bmn.z + h * 0.5))
        ortho = h * 1.14
        for lbl, th in (("front", 0.0), ("threequarter", -38.0)):
            p = shoot(os.path.join(OUTDIR, "ww1_%s_%s_tpose.png" % (tag, lbl)),
                      focus, ortho, th, 3.0, (900, 1400), span_hint=h)
            made.append(p)
            if lbl == "front":
                exposure_probe(p, coat, tag)
        # portrait: framed on the MEASURED head, including whatever is on it
        head = [o for o in visible
                if o.name.startswith(("kepi", "cerveliere", "helmet_"))] or [body]
        hmn, hmx = wbb(head)
        pf = Vector(((bmn.x + bmx.x) * 0.5, c.y, (hmn.z + hmx.z) * 0.5 - 0.035))
        light_rig(pf, 0.30)
        p = shoot(os.path.join(OUTDIR, "ww1_%s_portrait_tpose.png" % tag),
                  pf, 0.46, -22.0, 2.0, (900, 1100), span_hint=1.0)
        made.append(p)
        print("   %-13s sheet: body %.4f m, headgear top z=%.4f, portrait focus z=%.4f"
              % (tag, h, hmx.z, pf.z), flush=True)
    return made


print("=== rendering the WW1 cast FROM THE SHIPPED GLBs ===", flush=True)
if "all" in WHAT or "lineup" in WHAT:
    lineup()
if "all" in WHAT or "sheets" in WHAT:
    sheets()
print("RENDERS -> %s" % OUTDIR, flush=True)
