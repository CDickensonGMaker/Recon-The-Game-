"""render_cow_cast.py - turnaround + portrait reference sheets for the CoW cast.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
      "assets/us/characters/conquest_of_worms_us_cast.blend" --python tools/render_cow_cast.py ^
      -- michael|gus_arrival|gus_ears|stature|all [--rest] [--tag=X]

SHIPPING STATE ONLY. The engine draws the joined body and hides every gib donor
(model_actor.gd:501-548), so the render hides Base_Human / grunt_* / cap_* /
head_frag_* and the two coplanar spare helmet shells. hide_render is set explicitly:
the source file carries its hidden state in the VIEW LAYER only, and hide_render is
False on all of it, so a naive render draws every donor at once (FAILURE MODE 9).
"""
import bpy
import os
import sys
import math
from mathutils import Vector, Matrix

D = bpy.data
SC = bpy.context.scene
ROOT = r"C:\Users\caleb\RECONgame"
OUTDIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")
os.makedirs(OUTDIR, exist_ok=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
WHO = [a for a in argv if not a.startswith("--")] or ["all"]
USE_POSE = "--pose" in argv   # DEFAULT IS REST/T-POSE - see the note at the top
TAG = next((a.split("=", 1)[1] for a in argv if a.startswith("--tag=")), "")

HIDE_PREFIX = ("Base_Human", "grunt_", "cap_", "head_frag_",
               "helmet_camo_shell", "helmet_bugjuice")
TAGS = ["michael", "gus_arrival", "gus_ears"]


def family(tag):
    return [o for o in D.objects if o.type == 'MESH' and o.name.endswith("_" + tag)]


def is_donor(o):
    return any(o.name.startswith(p) for p in HIDE_PREFIX)


def export_set(tag):
    return [o for o in family(tag) if not is_donor(o)]


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


# ---------------------------------------------------------------------------
# scene setup
# ---------------------------------------------------------------------------
for o in list(D.objects):
    if o.type in ('CAMERA', 'LIGHT'):
        D.objects.remove(o, do_unlink=True)

for t in TAGS:
    rig = D.objects["PSXRig_" + t]
    rig.data.pose_position = 'POSE' if USE_POSE else 'REST'
bpy.context.view_layer.update()

# every donor off in the RENDER, not just the viewport
for o in D.objects:
    if o.type == 'MESH':
        o.hide_render = is_donor(o) or o.hide_get()

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

wd = D.worlds.new("studio_grey") if "studio_grey" not in D.worlds else D.worlds["studio_grey"]
wd.use_nodes = True
bg = wd.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.24, 0.24, 0.25, 1.0)
bg.inputs[1].default_value = 0.45
SC.world = wd


def add_light(name, loc, energy, size, rot):
    ld = D.lights.new(name, 'AREA')
    ld.energy = energy
    ld.size = size
    ld.color = (1.0, 0.98, 0.95)
    o = D.objects.new(name, ld)
    SC.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return o


cam_data = D.cameras.new("cam")
cam_data.type = 'ORTHO'
cam = D.objects.new("cam", cam_data)
SC.collection.objects.link(cam)
SC.camera = cam

LIGHTS = []


def light_rig(centre, radius):
    for o in LIGHTS:
        D.objects.remove(o, do_unlink=True)
    LIGHTS[:] = []
    r = max(radius, 1.2)
    LIGHTS.append(add_light("key", centre + Vector((-1.6 * r, -1.9 * r, 1.5 * r)),
                            240 * r * r, 3.0 * r, (math.radians(52), 0, math.radians(-40))))
    LIGHTS.append(add_light("fill", centre + Vector((2.0 * r, -1.6 * r, 0.5 * r)),
                            95 * r * r, 4.0 * r, (math.radians(78), 0, math.radians(52))))
    LIGHTS.append(add_light("rim", centre + Vector((0.4 * r, 2.4 * r, 1.8 * r)),
                            130 * r * r, 3.0 * r, (math.radians(-58), 0, math.radians(178))))
    LIGHTS.append(add_light("bounce", centre + Vector((0, -1.0 * r, -1.6 * r)),
                            62 * r * r, 4.0 * r, (math.radians(-90), 0, 0)))


def shoot(objs, theta_deg, elev_deg, path, pad=1.12, res=(900, 1400), focus=None,
          scale_override=None):
    mn, mx = wbb(objs)
    c = focus if focus is not None else (mn + mx) * 0.5
    span = mx - mn
    th = math.radians(theta_deg)
    el = math.radians(elev_deg)
    dist = max(span.length, 1.0) * 3.0
    cam.location = c + Vector((math.sin(th) * math.cos(el),
                               -math.cos(th) * math.cos(el),
                               math.sin(el))) * dist
    cam.rotation_euler = (math.radians(90) - el, 0.0, th)
    if scale_override is not None:
        s = scale_override
    else:
        w = math.hypot(span.x, span.y)
        s = max(span.z, w) * pad
    cam_data.ortho_scale = s
    cam_data.clip_start = 0.05
    cam_data.clip_end = dist * 4.0
    SC.render.resolution_x, SC.render.resolution_y = res
    SC.render.resolution_percentage = 100
    SC.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("   RENDER %-58s ortho=%.3f  bbox z[%.3f,%.3f] x[%.3f,%.3f]"
          % (os.path.basename(path), s, mn.z, mx.z, mn.x, mx.x), flush=True)
    return mn, mx


def sheet(tag):
    objs = export_set(tag)
    for o in D.objects:
        o.hide_render = True if o.type == 'MESH' else o.hide_render
    for o in objs:
        o.hide_render = False
    mn, mx = wbb(objs)
    c = (mn + mx) * 0.5
    tris = 0
    for o in objs:
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("%s: %d visible meshes, %d tris, world bbox x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f] "
          "-> height %.4f m"
          % (tag, len(objs), tris, mn.x, mx.x, mn.y, mx.y, mn.z, mx.z, mx.z - mn.z), flush=True)
    light_rig(c, (mx.z - mn.z) * 0.5)
    sfx = ("_" + TAG) if TAG else ""
    stance = "pose" if USE_POSE else "tpose"
    for nm, th in (("front", 0), ("threequarter", -40), ("side", -90), ("back", 180)):
        shoot(objs, th, 4, os.path.join(OUTDIR, "cow_%s_%s_%s%s.png" % (tag, nm, stance, sfx)))
    # head-and-shoulders: framed on the actual measured head bounds
    head = D.objects["grunt_head_" + tag]
    hmn, hmx = wbb([head])
    focus = Vector(((hmn.x + hmx.x) * 0.5, (hmn.y + hmx.y) * 0.5, hmx.z - 0.16))
    light_rig(focus, 0.30)
    for nm, th in (("portrait", 0), ("portrait34", -35)):
        shoot(objs, th, 3, os.path.join(OUTDIR, "cow_%s_%s_%s%s.png" % (tag, nm, stance, sfx)),
              res=(900, 1100), focus=focus, scale_override=0.46)
    return mn, mx


def stature_frame():
    """Michael's draft card says 6'2". The project body does not. Render the question,
    do not answer it."""
    tag = "michael"
    objs = export_set(tag)
    rig = D.objects["PSXRig_" + tag]
    body = D.objects["us_grunt_joined_" + tag]
    hel = D.objects["helmet_shell_worn_" + tag]
    bmn, bmx = wbb([body])
    hmn, hmx = wbb([body, hel])
    bare = bmx.z - bmn.z
    withhelm = hmx.z - hmn.z
    K = 1.8796 / bare
    print("STATURE: bare body %.4f m, body+helmet %.4f m at armature scale 1.0" % (bare, withhelm))
    print("STATURE: draft card 6'2\" = 1.8796 m -> armature scale %.4f" % K)

    copies = []
    for o in objs + [rig]:
        n = o.copy()          # shares mesh data on purpose - a variant costs nothing
        SC.collection.objects.link(n)
        copies.append((o, n))
    m = dict(copies)
    rig2 = m[rig]
    rig2.name = "PSXRig_michael_TALL"
    for o, n in copies:
        if o is rig:
            continue
        n.parent = rig2 if o.parent is rig else m.get(o.parent, n.parent)
        n.parent_type = o.parent_type
        n.parent_bone = o.parent_bone
        n.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        n.matrix_basis = o.matrix_basis.copy()
        for mod in n.modifiers:
            if mod.type == 'ARMATURE':
                mod.object = rig2
        n.hide_render = False
    rig2.delta_location = Vector((1.15, 0, 0))
    rig2.scale = (K, K, K)
    bpy.context.view_layer.update()

    gus = export_set("gus_arrival")
    for o in D.objects:
        if o.type == 'MESH':
            o.hide_render = True
    shown = objs + [n for o, n in copies if o.type == 'MESH'] + gus
    # A height comparison must not have three different weapons in it - drop them all.
    shown = [o for o in shown if "_world" not in o.name]
    for o in shown:
        o.hide_render = False
    # line them up: michael 1.0 at x=0, michael K at x=1.15, gus datum at x=2.30
    D.objects["PSXRig_gus_arrival"].delta_location = Vector((-3.0 + 2.30, 0, 0))
    bpy.context.view_layer.update()

    mn, mx = wbb(shown)
    c = (mn + mx) * 0.5
    light_rig(c, (mx.z - mn.z) * 0.75)
    def meas(group):
        bo = [o for o in group if o.name.startswith("us_grunt_joined")]
        he = [o for o in group if o.name.startswith("helmet_shell_worn")]
        b0, b1 = wbb(bo)
        h0, h1 = wbb(bo + he)
        return b1.z - b0.z, h1.z - h0.z
    g1 = [o for o in shown if o.name.endswith("_michael") and "TALL" not in o.name]
    g2 = [n for o, n in copies if o.type == 'MESH' and "_world" not in n.name]
    g3 = [o for o in shown if o.name.endswith("_gus_arrival")]
    for lbl, grp in (("michael scale 1.0", g1), ("michael scale %.4f" % K, g2),
                     ("stock grunt (gus_arrival) 1.0", g3)):
        bare_m, helm_m = meas(grp)
        print("STATURE MEASURED  %-32s bare body %.4f m | top of helmet %.4f m"
              % (lbl, bare_m, helm_m), flush=True)
    stance = "pose" if USE_POSE else "tpose"
    shoot(shown, 0, 3, os.path.join(OUTDIR, "cow_michael_STATURE_QUESTION_%s.png" % stance),
          res=(1500, 1250), pad=1.06)



def two_states():
    """gus_arrival beside gus_ears, one camera, one light rig. The whole value of this
    character is that the decline is visible ON THE MODEL (bible section 8), so the two
    states have to read as different men in the same body."""
    a = export_set("gus_arrival")
    b = export_set("gus_ears")
    D.objects["PSXRig_gus_arrival"].delta_location = Vector((-3.0, 0, 0))
    D.objects["PSXRig_gus_ears"].delta_location = Vector((-6.0 + 0.95, 0, 0))
    bpy.context.view_layer.update()
    for o in D.objects:
        if o.type == 'MESH':
            o.hide_render = True
    for o in a + b:
        o.hide_render = False
    mn, mx = wbb(a + b)
    c = (mn + mx) * 0.5
    light_rig(c, (mx.z - mn.z) * 0.6)
    stance = "pose" if USE_POSE else "tpose"
    # framed on the TORSOS - the T-pose arms are 1.6 m of empty span either side and
    # framing on the full bbox shrinks both men to nothing.
    focus = Vector((c.x, c.y, mn.z + (mx.z - mn.z) * 0.5))
    print("TWO STATES: bbox x[%.3f,%.3f] z[%.3f,%.3f]" % (mn.x, mx.x, mn.z, mx.z), flush=True)
    shoot(a + b, 0, 3, os.path.join(OUTDIR, "cow_gus_TWO_STATES_%s.png" % stance),
          res=(1600, 1250), focus=focus, scale_override=2.25)
    shoot(a + b, -38, 3, os.path.join(OUTDIR, "cow_gus_TWO_STATES_34_%s.png" % stance),
          res=(1600, 1250), focus=focus, scale_override=2.45)
    D.objects["PSXRig_gus_arrival"].delta_location = Vector((0, 0, 0))
    D.objects["PSXRig_gus_ears"].delta_location = Vector((0, 0, 0))
    bpy.context.view_layer.update()


for w in (TAGS if "all" in WHO else WHO):
    if w in ("stature", "twostates"):
        continue
    sheet(w)
if "all" in WHO or "twostates" in WHO:
    two_states()
if "all" in WHO or "stature" in WHO:
    stature_frame()
print("RENDERS -> %s" % OUTDIR, flush=True)
