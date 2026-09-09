"""render_cow_lineup.py - all four Conquest of Worms characters, ONE camera, ONE ground line.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --factory-startup --python tools/render_cow_lineup.py

Built from the SHIPPED GLBs so what he sees is what the engine gets. Touches no .blend.

THE POINT OF A LINEUP IS SCALE: one camera, one light rig, feet on a common ground line,
true relative scale. No per-figure framing, no compositing of separate renders.

FAILURE MODE 9 (psx-npc-pipeline): a GLB round-trip turns every gib donor back ON. The
joined body is the visible man; grunt_* / cap_* / head_frag_* / Base_Human are donors and
must be hidden or the lineup reads as four broken models with severed parts at their feet.
The glTF importer also spawns stray `Icosphere` bone-display furniture - hide that too.
Counts are printed before anything renders.
"""
import bpy
import os
import math
from mathutils import Vector

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
OUTDIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")
OUT = os.path.join(OUTDIR, "cow_LINEUP_all_four.png")
os.makedirs(OUTDIR, exist_ok=True)

FIGURES = [
    ("michael", os.path.join(ROOT, "assets", "us", "characters", "cow_michael_crawford.glb")),
    ("gus_arrival", os.path.join(ROOT, "assets", "us", "characters", "cow_gus_arrival.glb")),
    ("gus_ears", os.path.join(ROOT, "assets", "us", "characters", "cow_gus_ears.glb")),
    ("sniper", os.path.join(ROOT, "assets", "nva_vc", "characters", "cow_sniper.glb")),
]
SPACING = 1.15
DONOR_PREFIX = ("grunt_", "cap_", "head_frag_", "Base_Human", "Icosphere",
                "helmet_camo_shell", "helmet_bugjuice")

bpy.ops.wm.read_factory_settings(use_empty=True)
# Bind the scene AFTER the factory reset. Holding a reference across it leaves a stale
# StructRNA and the next attribute write dies with "Scene has been removed".
SC = bpy.context.scene


def is_donor(o):
    return any(o.name.split(".")[0].startswith(p) for p in DONOR_PREFIX)


def wbb(objs):
    dg = bpy.context.evaluated_depsgraph_get()
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


shown = []
heights = []
for i, (tag, path) in enumerate(FIGURES):
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
    for o in donors:
        o.hide_render = True
        o.hide_viewport = True
    bpy.context.view_layer.update()

    if len(joined) != 1:
        raise SystemExit("ABORT %s: %d joined bodies, expected 1 (%s)"
                         % (tag, len(joined), [o.name for o in joined]))
    print("VISIBILITY %-12s joined %d/1 | donors hidden %d (grunt_ %d, cap_ %d, "
          "head_frag_ %d, Base_Human %d, Icosphere %d) | drawn meshes %d"
          % (tag, len(joined), len(donors),
             sum(1 for o in donors if o.name.startswith("grunt_")),
             sum(1 for o in donors if o.name.startswith("cap_")),
             sum(1 for o in donors if o.name.startswith("head_frag_")),
             sum(1 for o in donors if o.name.startswith("Base_Human")),
             sum(1 for o in donors if o.name.startswith("Icosphere")),
             len(visible)), flush=True)

    # TRUE RELATIVE SCALE: measure as imported, move only in X, and drop each man's own
    # feet to z=0 so all four stand on ONE ground line. Never rescale to match.
    mn, mx = wbb(visible)
    h = mx.z - mn.z
    body = joined[0]
    bmn, bmx = wbb([body])
    roots = [o for o in new if o.parent is None]
    # Anchor on the BODY, not the whole visible set: a T-pose weapon sticks a metre out
    # to one side and centring on it staggers the men down the line.
    dx = i * SPACING - (bmn.x + bmx.x) * 0.5
    for r in roots:
        r.location.x += dx
        r.location.z -= mn.z
    bpy.context.view_layer.update()
    mn2, mx2 = wbb(visible)
    b2mn, b2mx = wbb([body])
    print("   %-12s placed: body centre x=%.3f (want %.3f), full x[%.3f,%.3f] z[%.4f,%.4f]"
          % (tag, (b2mn.x + b2mx.x) * 0.5, i * SPACING, mn2.x, mx2.x, mn2.z, mx2.z),
          flush=True)
    # STRAY-MESH FILTER. cow_sniper.glb carries TWO coordinate frames: its joined body
    # and hair sit Z-up at world x=-8 (the studio lineup offset, baked in at export -
    # `vc_guerilla_joined` lives at x=-8 in the donor file), while its gib donors and
    # `sniper_beard` sit Y-UP at the origin. Anything that far from its own body would
    # drag the lineup frame out to 13 m of ortho and shrink all four men to nothing.
    # Hide it here and REPORT it - it is a defect in that file, not in the framing.
    bc = (b2mn.x + b2mx.x) * 0.5
    kept = []
    for o in visible:
        omn, omx = wbb([o])
        off = abs((omn.x + omx.x) * 0.5 - bc)
        if off > 1.0:
            o.hide_render = True
            o.hide_viewport = True
            print("   STRAY  %-12s %-24s centre is %.3f m from the body in X - HIDDEN "
                  "(different coordinate frame in the source GLB)" % (tag, o.name, off),
                  flush=True)
        else:
            kept.append(o)
    visible = kept
    bpy.context.view_layer.update()
    rigscale = tuple(round(v, 5) for v in rigs[0].scale) if rigs else None
    print("   %-12s imported height (with helmet) %.4f m | bare body %.4f m | rig scale %s"
          % (tag, h, bmx.z - bmn.z, rigscale), flush=True)
    heights.append((tag, h, bmx.z - bmn.z, rigscale))
    shown += visible

mn, mx = wbb(shown)
print("LINEUP bbox x[%.3f,%.3f] z[%.4f,%.4f]  feet spread %.5f m (should be ~0)"
      % (mn.x, mx.x, mn.z, mx.z, mn.z), flush=True)

# --- lighting: the exact rig that lit cow_michael_STATURE_QUESTION -------------------
try:
    SC.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    SC.render.engine = 'BLENDER_EEVEE'
SC.render.image_settings.file_format = 'PNG'
SC.render.film_transparent = False
SC.view_settings.view_transform = 'Standard'
SC.view_settings.look = 'None'
try:
    SC.eevee.taa_render_samples = 32
except AttributeError:
    pass
wd = D.worlds.new("studio_grey")
wd.use_nodes = True
wd.node_tree.nodes["Background"].inputs[0].default_value = (0.24, 0.24, 0.25, 1.0)
wd.node_tree.nodes["Background"].inputs[1].default_value = 0.45
SC.world = wd

c = (mn + mx) * 0.5
r = max((mx.z - mn.z) * 0.75, 1.2)
for name, off, energy, size, rot in (
        ("key", (-1.6, -1.9, 1.5), 240, 3.0, (52, 0, -40)),
        ("fill", (2.0, -1.6, 0.5), 95, 4.0, (78, 0, 52)),
        ("rim", (0.4, 2.4, 1.8), 130, 3.0, (-58, 0, 178)),
        ("bounce", (0.0, -1.0, -1.6), 62, 4.0, (-90, 0, 0))):
    ld = D.lights.new(name, 'AREA')
    ld.energy = energy * r * r
    ld.size = size * r
    ld.color = (1.0, 0.98, 0.95)
    o = D.objects.new(name, ld)
    SC.collection.objects.link(o)
    o.location = c + Vector(off) * r
    o.rotation_euler = tuple(math.radians(a) for a in rot)

cam_data = D.cameras.new("cam")
cam_data.type = 'ORTHO'
cam = D.objects.new("cam", cam_data)
SC.collection.objects.link(cam)
SC.camera = cam

# FIT THE CANVAS TO THE GROUP, not the group to a 4:3 canvas. Four T-posed men on one
# ground line are ~5.3 m wide and 1.73 m tall - an aspect of ~3:1. Rendered 4:3 they fill
# 39% of the frame height and the rest is empty grey, which is exactly the complaint.
span = mx - mn
group_w, group_h = span.x, mx.z - mn.z
RES_X = 2600
RES_Y = 1000
A = RES_X / float(RES_Y)
need_w = group_w + 0.40                     # side margin
need_h = group_h / 0.80                     # men fill ~80% of frame height
ortho = max(need_w, need_h * A)
print("FRAMING group %.3f x %.3f m -> canvas %dx%d, ortho %.3f, men fill %.0f%% of height"
      % (group_w, group_h, RES_X, RES_Y, ortho, 100.0 * group_h / (ortho / A)), flush=True)
th, el = 0.0, math.radians(3.0)
dist = max(span.length, 2.0) * 3.0
focus = Vector((c.x, c.y, mn.z + (mx.z - mn.z) * 0.5))
cam.location = focus + Vector((0.0, -math.cos(el), math.sin(el))) * dist
cam.rotation_euler = (math.radians(90) - el, 0.0, th)
cam_data.ortho_scale = ortho
cam_data.clip_start = 0.05
cam_data.clip_end = dist * 4.0
SC.render.resolution_x, SC.render.resolution_y = RES_X, RES_Y
SC.render.resolution_percentage = 100
SC.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED %s  ortho=%.3f  %dx%d" % (OUT, ortho, RES_X, RES_Y), flush=True)

# framing numbers the label pass needs, so it never has to guess
with open(os.path.join(OUTDIR, "_lineup_frame.txt"), "w") as f:
    f.write("%f %f %d %d\n" % (c.x, ortho, RES_X, RES_Y))
    for i, (tag, h, bare, s) in enumerate(heights):
        f.write("%s %f %f %f\n" % (tag, i * SPACING, h, bare))
print("HEIGHTS (evaluated mesh bounds, as imported, no rescaling):", flush=True)
for tag, h, bare, s in heights:
    print("   %-12s helmet-top %.4f m | bare body %.4f m | rig scale %s"
          % (tag, h, bare, s), flush=True)
