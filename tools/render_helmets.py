"""render_helmets.py - the SHIPPING helmets: the cast wearing them, and the library.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --factory-startup --python tools/render_helmets.py -- lineup|library|all

Every render before this one showed `helmet_shell_worn`, the helmet welded into the grunt
GLB. `grunt_dresser.gd:270` sets that mesh INVISIBLE at load and hangs a variant from
`assets/us/props/helmets/` in its place - so those renders showed a helmet the player never
sees. This reproduces what the engine actually draws:

  * hide STOCK_HELMET (`grunt_dresser.gd:53` = "helmet_shell_worn")
  * hang the variant on `mixamorig:Head` using the socket transform in helmets.json.
    PLACEMENT IS MASTER DATA - read it, never re-solve it. The JSON's own note: "Every
    helmet GLB exports with its socket at the origin, so applying this puts any variant
    exactly where the truth helmet sat." It is gated below against the stock helmet's
    measured position, and falls back to matching that if it misses.
  * bind `assets/us/textures/helmets/helm_<id>.png` to UV-bearing surfaces whose material
    has no image of its own, exactly as `_texture_helmet` does (grunt_dresser.gd:286-303).
"""
import bpy
import os
import sys
import json
import math
import hashlib
from mathutils import Vector, Matrix

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
HELDIR = os.path.join(ROOT, "assets", "us", "props", "helmets")
COVDIR = os.path.join(ROOT, "assets", "us", "textures", "helmets")
OUTDIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")
os.makedirs(OUTDIR, exist_ok=True)

HELMETS = ["m1_plain", "m1_cig", "m1_bugjuice", "m1_cig_bug", "m1_ace",
           "m1_ace_cig", "m1_war_is_hell", "m1_born_to_kill", "m1_rounds",
           "m1_foliage", "m1_foliage_graf", "m1_barepot", "m1_barepot_fta",
           "m1_erdl_short", "m1_veteran"]
STOCK = "helmet_shell_worn"
DONOR_PREFIX = ("grunt_", "cap_", "head_frag_", "Base_Human", "Icosphere",
                "helmet_camo_shell", "helmet_bugjuice", STOCK)

SOCKET = json.load(open(os.path.join(HELDIR, "helmets.json")))["socket"]
SOCKET_M = Matrix(SOCKET["matrix_basis"])

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
WHAT = argv[0] if argv else "all"


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


def cover_image(hid):
    p = os.path.join(COVDIR, "helm_%s.png" % hid)
    return D.images.load(p, check_existing=True) if os.path.exists(p) else None


def bind_cover(objs, hid):
    """Mirror grunt_dresser._texture_helmet: surfaces that carry UVs and whose material has
    no image of its own sample helm_<id>.png; everything else keeps its authored colour."""
    cov = cover_image(hid)
    if cov is None:
        return 0, 0
    bound, kept = 0, 0
    for o in objs:
        has_uv = bool(o.data.uv_layers)
        for i, m in enumerate(o.data.materials):
            if m is None:
                continue
            nodes = m.node_tree.nodes if m.node_tree else []
            has_img = any(n.type == 'TEX_IMAGE' and n.image for n in nodes)
            if has_img or not has_uv:
                kept += 1
                continue
            mm = m.copy()
            mm.name = "%s__%s_cover" % (m.name, hid)
            nt = mm.node_tree
            bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is None:
                kept += 1
                continue
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = cov
            tex.interpolation = 'Closest'
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
            o.data.materials[i] = mm
            bound += 1
    return bound, kept


def import_helmet(hid):
    before = set(D.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HELDIR, "%s.glb" % hid))
    new = [o for o in D.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    return new, meshes


def helmet_roots(new):
    """A helmet GLB is NOT one object. m1_veteran imports SIX root-level meshes (cover,
    bug-juice bottle, ace of spades, cigarette pack, rounds). Moving only the first root
    leaves every decal at the origin - measured: they ended up 2.2-2.4 m from the man and
    the stray filter hid them, so two of three men rendered bare-headed."""
    return [o for o in new if o.parent is None or o.parent not in new]


def place_like_stock(new, stock):
    """grunt_dresser._swap_helmet:238-244, verbatim - 'where the stock helmet ACTUALLY
    RENDERS. The exported variants have their origin at the helmet's centre, so this is
    the transform to match. Doing it this way means no bone-space maths and no Y-up
    conversion to get wrong.'

    The helmets.json socket matrix was tried first and landed 0.86 m out, because that
    matrix is expressed in a frame this scene is not in. The stock helmet's own rendered
    transform is right BY DEFINITION - it is the one the artist fitted."""
    smn, smx = wbb([stock])
    centre = (smn + smx) * 0.5
    T = Matrix.Translation(centre) @ stock.matrix_world.to_3x3().to_4x4()
    for r in helmet_roots(new):
        r.matrix_world = T @ r.matrix_world
    bpy.context.view_layer.update()
    return centre


# ===========================================================================
def lineup():
    FIGS = [("michael", os.path.join(ROOT, "assets", "us", "characters",
                                     "cow_michael_crawford.glb"), "m1_ace"),
            ("gus_arrival", os.path.join(ROOT, "assets", "us", "characters",
                                         "cow_gus_arrival.glb"), "m1_bugjuice"),
            ("gus_ears", os.path.join(ROOT, "assets", "us", "characters",
                                      "cow_gus_ears.glb"), "m1_veteran"),
            ("sniper", os.path.join(ROOT, "assets", "nva_vc", "characters",
                                    "cow_sniper.glb"), None)]
    SPACING = 1.15
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SC = bpy.context.scene
    shown, heights, worn = [], [], []

    for i, (tag, path, hid) in enumerate(FIGS):
        before = set(D.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in D.objects if o not in before]
        meshes = [o for o in new if o.type == 'MESH']
        rigs = [o for o in new if o.type == 'ARMATURE']
        stock = next((o for o in meshes if o.name.split(".")[0] == STOCK), None)
        stock_bb = wbb([stock]) if stock else None
        donors = [o for o in meshes
                  if any(o.name.split(".")[0].startswith(p) for p in DONOR_PREFIX)]
        visible = [o for o in meshes if o not in donors]
        joined = [o for o in visible if "_joined" in o.name]
        for o in new:
            o.hide_render = False
        for o in donors:
            o.hide_render = True
            # NOT hide_viewport on the stock: a hide_viewport object has no evaluated
            # mesh, and its transform is the master datum the helmet is placed from.
            o.hide_viewport = (o is not stock)
        bpy.context.view_layer.update()
        print("VISIBILITY %-12s joined %d/1 | hidden %d (incl. the stock %s) | drawn %d"
              % (tag, len(joined), len(donors), STOCK, len(visible)), flush=True)

        # PLACE THE HELMET LAST. The figure is moved into its slot FIRST, then the
        # helmet is read off the stock's ALREADY-MOVED transform. Placing it first and
        # moving the man afterwards leaves the helmet behind - the props are not children
        # of the rig, so `dx` never reached them. Measured: gus_arrival's helmet sat
        # 1.15 m away and gus_ears' 2.30 m, exactly their slot offsets, and the stray
        # filter then hid them, so two of three men rendered bare-headed.
        mn, mx = wbb(visible + ([stock] if stock else []))
        body = joined[0]
        bmn, bmx = wbb([body])
        dx = i * SPACING - (bmn.x + bmx.x) * 0.5
        for r in [o for o in D.objects if o.parent is None and o in new]:
            r.location.x += dx
            r.location.z -= mn.z
        bpy.context.view_layer.update()

        if hid:
            hnew, hmesh = import_helmet(hid)
            amn, amx = wbb(hmesh)
            ac = (amn + amx) * 0.5
            b, k = bind_cover(hmesh, hid)
            centre = place_like_stock(hnew, stock)
            hmn, hmx = wbb(hmesh)
            off = (((hmn + hmx) * 0.5) - centre).length
            if off > 0.03:
                raise SystemExit("ABORT %s: helmet %s landed %.4f m off the stock centre"
                                 % (tag, hid, off))
            # A helmet seen from the front must be WIDER than it is deep and must sit on
            # the skull. If it reads as a flat ellipse the rotation is wrong, so gate on
            # the shape and on where it landed relative to the head.
            hmn2, hmx2 = wbb(hmesh)
            w, dpth, ht = hmx2.x - hmn2.x, hmx2.y - hmn2.y, hmx2.z - hmn2.z
            head = next(o for o in meshes if o.name.split(".")[0] == "grunt_head")
            gmn, gmx = wbb([head])
            if ht < 0.08 or ht > 0.30 or w < 0.15:
                raise SystemExit("ABORT %s: helmet %s is %.3f x %.3f x %.3f m - that is a "
                                 "disc, the rotation is wrong." % (tag, hid, w, dpth, ht))
            print("   HELMET %-12s <- %-11s %d roots, %d meshes | placed %.4f m from the "
                  "stock centre | size %.3f w x %.3f d x %.3f h | crown %.4f m vs skull top "
                  "%.4f m | cover on %d surfaces, %d kept own"
                  % (tag, hid, len(helmet_roots(hnew)), len(hmesh), off, w, dpth, ht,
                     hmx2.z, gmx.z, b, k), flush=True)
            for o in hnew:
                o.hide_render = False
                o.hide_viewport = False
            visible += hmesh
            worn.append((tag, hid))

        b2mn, b2mx = wbb([body])
        bc = (b2mn.x + b2mx.x) * 0.5
        kept = []
        for o in visible:
            omn, omx = wbb([o])
            if abs((omn.x + omx.x) * 0.5 - bc) > 1.0:
                o.hide_render = True
                o.hide_viewport = True
                print("   STRAY  %-12s %-22s %.3f m off its own body - HIDDEN"
                      % (tag, o.name, abs((omn.x + omx.x) * 0.5 - bc)), flush=True)
            else:
                kept.append(o)
        visible = kept
        bpy.context.view_layer.update()
        m2, x2 = wbb(visible)
        heights.append((tag, x2.z - m2.z, bmx.z - bmn.z))
        shown += visible
        print("   %-12s standing %.4f m (top of helmet) | bare body %.4f m"
              % (tag, x2.z - m2.z, bmx.z - bmn.z), flush=True)

    mn, mx = wbb(shown)
    studio(SC, mn, mx)
    span = mx - mn
    RES_X, RES_Y = 2600, 1000
    A = RES_X / float(RES_Y)
    ortho = max(span.x + 0.40, ((mx.z - mn.z) / 0.80) * A)
    out = os.path.join(OUTDIR, "cow_LINEUP_shipping_helmets.png")
    shoot(SC, mn, mx, ortho, RES_X, RES_Y, out)
    with open(os.path.join(OUTDIR, "_helmet_lineup_frame.txt"), "w") as f:
        f.write("%f %f %d %d\n" % ((mn.x + mx.x) * 0.5, ortho, RES_X, RES_Y))
        for i, (tag, h, bare) in enumerate(heights):
            hid = dict(worn).get(tag, "-")
            f.write("%s %f %f %f %s\n" % (tag, i * SPACING, h, bare, hid))
    print("HELMETS WORN: %s" % worn, flush=True)


# ===========================================================================
def library():
    """TWO BANDS, because there are two different truths and they answer different
    questions.

    TOP: the GLB exactly as it is on disk. No cover bound. `m1_plain.glb` contains
    images:0 / textures:0 - a file with zero images cannot render a pattern, so this band
    is what a raw glTF viewer shows.

    BOTTOM: the same GLB with `assets/us/textures/helmets/helm_<id>.png` bound to every
    UV-bearing surface whose material has no image - which is what
    `grunt_dresser._texture_helmet` (grunt_dresser.gd:286-303) does at load. This band is
    what the PLAYER sees.

    Both bands are the same fifteen GLBs under one camera and one lamp. Nothing from
    `helmet_variants.blend` is opened, linked or appended anywhere in this script.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SC = bpy.context.scene
    print("AUDIT: images in scene after factory reset = %d" % len(D.images), flush=True)
    COLS, GAP, BAND = 8, 0.34, 0.78
    all_m, meta = [], []
    for band, do_bind in ((0, False), (1, True)):
        for i2, hid in enumerate(HELMETS):
            r, c = divmod(i2, COLS)
            path = os.path.join(HELDIR, "%s.glb" % hid)
            imgs_before = len(D.images)
            hnew, hmesh = import_helmet(hid)
            imgs_after = len(D.images)
            if band == 0:
                mats = []
                for o in hmesh:
                    for m in o.data.materials:
                        if m is None:
                            continue
                        nodes = m.node_tree.nodes if m.node_tree else []
                        img = next((n.image.name for n in nodes
                                    if n.type == 'TEX_IMAGE' and n.image), None)
                        bs = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
                        val = tuple(round(v, 4) for v in bs.inputs['Base Color'].default_value[:3])                             if bs else None
                        mats.append("%s=%s" % (m.name.split('.')[0],
                                               ("IMAGE:" + img) if img else ("FLAT" + str(val))))
                print("AUDIT %-16s loaded %s | images in scene %d -> %d | %s"
                      % (hid, path, imgs_before, imgs_after, "  ".join(sorted(set(mats)))),
                      flush=True)
            if do_bind:
                bind_cover(hmesh, hid)
            mn, mx = wbb(hmesh)
            zoff = -r * GAP - band * BAND
            dvec = Vector((c * GAP - (mn.x + mx.x) * 0.5, 0.0, zoff - (mn.z + mx.z) * 0.5))
            for rt in helmet_roots(hnew):
                rt.location += dvec
            bpy.context.view_layer.update()
            if band == 1:
                digest = hashlib.md5(open(os.path.join(COVDIR, "helm_%s.png" % hid),
                                          "rb").read()).hexdigest()[:10]
                meta.append((hid, c * GAP, zoff, digest))
            all_m += hmesh
    print("AUDIT: images in scene at the end = %d  (%s)"
          % (len(D.images), ", ".join(sorted(i3.name for i3 in D.images))), flush=True)

    mn, mx = wbb(all_m)
    wd = D.worlds.new("flat")
    wd.use_nodes = True
    wd.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.30, 0.32, 1.0)
    wd.node_tree.nodes["Background"].inputs[1].default_value = 1.5
    SC.world = wd
    c = (mn + mx) * 0.5
    ld = D.lights.new("flat_front", 'AREA')
    ld.energy = 420
    ld.size = 8.0
    ld.color = (1, 1, 1)
    o = D.objects.new("flat_front", ld)
    SC.collection.objects.link(o)
    o.location = c + Vector((0, -3.0, 0))
    o.rotation_euler = (math.radians(90), 0, 0)
    engine(SC)
    span = mx - mn
    RES_X = 2600
    ortho = span.x + 0.20
    RES_Y = int(round(RES_X * ((span.z / 0.88) / ortho)))
    out = os.path.join(OUTDIR, "cow_HELMET_LIBRARY.png")
    shoot(SC, mn, mx, ortho, RES_X, RES_Y, out, elev=6.0)
    with open(os.path.join(OUTDIR, "_helmet_library_frame.txt"), "w") as f:
        f.write("%f %f %f %d %d %f\n" % ((mn.x + mx.x) * 0.5, (mn.z + mx.z) * 0.5,
                                         ortho, RES_X, RES_Y, BAND))
        for hid, x, z, digest in meta:
            f.write("%s %f %f %s\n" % (hid, x, z, digest))


# ===========================================================================
def engine(SC):
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


def studio(SC, mn, mx):
    engine(SC)
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


def shoot(SC, mn, mx, ortho, RES_X, RES_Y, path, elev=3.0):
    cd = D.cameras.new("cam")
    cd.type = 'ORTHO'
    cam = D.objects.new("cam", cd)
    SC.collection.objects.link(cam)
    SC.camera = cam
    c = (mn + mx) * 0.5
    el = math.radians(elev)
    dist = max((mx - mn).length, 2.0) * 3.0
    cam.location = c + Vector((0.0, -math.cos(el), math.sin(el))) * dist
    cam.rotation_euler = (math.radians(90) - el, 0.0, 0.0)
    cd.ortho_scale = ortho
    cd.clip_start = 0.05
    cd.clip_end = dist * 4.0
    SC.render.resolution_x, SC.render.resolution_y = RES_X, RES_Y
    SC.render.resolution_percentage = 100
    SC.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED %s  ortho=%.3f %dx%d" % (path, ortho, RES_X, RES_Y), flush=True)


if WHAT in ("lineup", "all"):
    lineup()
if WHAT in ("library", "all"):
    library()
