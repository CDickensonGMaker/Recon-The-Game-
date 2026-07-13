"""GEAR LIBRARY (batch 1) - modular kit any v2 character can wear.

Gear is SEPARATE bone-attached geometry, never baked into the body mesh and never
painted into a texture. That is not a style choice, it is the engine contract:

  * HitzoneBuilder._GEAR_NAME_HINTS excludes gear from hurtbox harvesting by NAME.
    A painted-on bandolier would BE part of the hurtbox. Name every piece with a
    hint word or the player can shoot a man's antenna and hurt him.
  * GibSystem.REGIONS carries a `gear` list per region - the helmet flies off with
    the head. That only works because the helmet is its own mesh.
  * At PSX poly counts silhouette IS the read. A painted bandolier is invisible at
    30m; a 20-triangle geometric one is not, and 20 triangles is free.
  * Modularity: author the kit ONCE, wear it on grunt / RTO / pilot / civilian.

Attachment follows the existing grunt contract exactly: parent_type='BONE',
parent_bone=<mixamorig bone>, NO armature modifier, NO vertex groups (rigid).

Everything shares ONE palette-atlas material (1 texel per colour, UVs point at
them) -> one draw call for a man's entire kit. Same trick as the jungle patches.

    blender -b -P tools/make_gear_library.py

Writes art_source/characters/base_psx/gear_library.blend + per-piece GLBs.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

BASE = r"C:\Users\caleb\RECONgame\assets\us\characters\us_grunt_v2.blend"
OUT_BLEND = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_library.blend"
OUT_GLB = r"C:\Users\caleb\RECONgame\assets\us\props"
RIG = "PSXRig"

# ---------------------------------------------------------------- palette
PALETTE = {
    "od_green":   (0.055, 0.070, 0.038),   # olive drab - radio, pouches
    "od_light":   (0.095, 0.105, 0.058),   # sun-faded OD
    "canvas":     (0.130, 0.120, 0.075),   # webbing / straps
    "canvas_drk": (0.075, 0.068, 0.045),
    "leather":    (0.070, 0.045, 0.028),
    "steel":      (0.055, 0.058, 0.062),   # antenna, shovel blade
    "black_rub":  (0.020, 0.020, 0.022),   # handset, cord
    "straw":      (0.230, 0.185, 0.090),   # conical hat
    "brass":      (0.170, 0.130, 0.050),
    # village tools
    "bamboo":     (0.205, 0.180, 0.075),   # split bamboo - poles, basket rims
    "wood":       (0.085, 0.050, 0.026),   # a worn tool haft
    "rice":       (0.260, 0.235, 0.135),   # cut stalks, threshed grain
}
PAL = list(PALETTE.keys())
PIDX = {n: i for i, n in enumerate(PAL)}
_atlas = [None]


def _srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def palette_mat():
    m = bpy.data.materials.get("gear_atlas")
    if m:
        return m
    img = bpy.data.images.new("gear_palette", len(PAL), 1, alpha=True)
    img.colorspace_settings.name = 'sRGB'
    px = []
    for n in PAL:
        r, g, b = PALETTE[n]
        px += [_srgb(r), _srgb(g), _srgb(b), 1.0]
    img.pixels = px
    img.pack()
    _atlas[0] = img
    m = bpy.data.materials.new("gear_atlas")
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = 0.9
    tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return m


def save_palette_png():
    os.makedirs(OUT_GLB, exist_ok=True)
    palette_mat()
    p = os.path.join(OUT_GLB, "gear_palette.png")
    _atlas[0].filepath_raw = p
    _atlas[0].file_format = 'PNG'
    _atlas[0].save()
    return p


# ------------------------------------------------------------------ canvas
class Part:
    def __init__(self, name, bone):
        self.name = name
        self.bone = bone
        self.verts, self.faces, self.mats = [], [], []

    def add(self, verts, faces, col):
        b = len(self.verts)
        ci = PIDX[col]
        self.verts += [tuple(v) for v in verts]
        for f in faces:
            self.faces.append([b + i for i in f])
            self.mats.append(ci)

    def box(self, c, s, col):
        """centre c, half-size s"""
        cx, cy, cz = c
        sx, sy, sz = s
        v = [(cx-sx, cy-sy, cz-sz), (cx+sx, cy-sy, cz-sz), (cx+sx, cy+sy, cz-sz), (cx-sx, cy+sy, cz-sz),
             (cx-sx, cy-sy, cz+sz), (cx+sx, cy-sy, cz+sz), (cx+sx, cy+sy, cz+sz), (cx-sx, cy+sy, cz+sz)]
        f = [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
        self.add(v, f, col)

    def tube(self, p0, p1, r0, r1, col, sides=6):
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0)
        if d.length < 1e-6:
            return
        z = d.normalized()
        up = Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))
        x = z.cross(up).normalized()
        y = z.cross(x).normalized()
        v, f = [], []
        for i in range(sides):
            a = math.tau * i / sides
            v.append(tuple(p0 + x * (r0 * math.cos(a)) + y * (r0 * math.sin(a))))
        for i in range(sides):
            a = math.tau * i / sides
            v.append(tuple(p1 + x * (r1 * math.cos(a)) + y * (r1 * math.sin(a))))
        for i in range(sides):
            j = (i + 1) % sides
            f.append([i, j, sides + j, sides + i])
        f.append(list(range(sides))[::-1])
        f.append([sides + i for i in range(sides)])
        self.add(v, f, col)

    def bake(self, rig):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        me.update()
        me.materials.append(palette_mat())
        uv = me.uv_layers.new(name="UVMap")
        n = float(len(PAL))
        for poly, pal in zip(me.polygons, self.mats):
            poly.material_index = 0
            poly.use_smooth = False
            u = (pal + 0.5) / n
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        # Rigid bone attach - exactly how the grunt's helmet/ruck/canteens ride.
        #
        # The verts are already authored in WORLD/REST space, so the finished
        # object must sit at IDENTITY. Get there by parenting FIRST and setting
        # matrix_world AFTERWARDS, letting Blender solve the basis. Hand-rolling
        # the parent inverse does not work: bone parenting adds a bone-LENGTH tail
        # offset that (rig.matrix_world @ pose.matrix).inverted() does not account
        # for, and the whole kit slides off the man and onto the floor. That bug
        # shipped in this file once - the radio was 1.5m out in front of him with
        # its verts still saying "on his back".
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = self.bone
        ob.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        ob.matrix_world = Matrix.Identity(4)   # built in world/rest space already
        bpy.context.view_layer.update()
        return ob


# ================================================================= THE KIT
# All coordinates are WORLD/REST space on the v2 rig:
#   +Y = BEHIND the man (the ruck sits at y 0.10..0.25)
#   soles z=0, hips z=1.045, Spine2 z=1.364, head z=1.616, head top ~1.74
def build_all(rig):
    parts = []

    # ---- AN/PRC-25: 15.5 x 3.75 x 12in = 0.28w x 0.10d x 0.31h. The Vietnam
    # radio. Rides the back where the ruck rides.
    p = Part("prc25_radio_pack", "mixamorig:Spine2")
    p.box((0.0, 0.175, 1.375), (0.140, 0.055, 0.155), "od_green")     # body
    p.box((0.0, 0.117, 1.375), (0.128, 0.004, 0.140), "od_light")     # faceplate
    for kx in (-0.075, 0.075):                                         # tuning knobs
        p.tube((kx, 0.112, 1.470), (kx, 0.095, 1.470), 0.022, 0.020, "od_light")
    p.box((0.0, 0.112, 1.300), (0.060, 0.006, 0.022), "black_rub")    # dial face
    p.box((0.0, 0.175, 1.222), (0.140, 0.055, 0.018), "canvas_drk")   # battery box lip
    for sx in (-0.115, 0.115):                                         # shoulder straps
        p.tube((sx, 0.130, 1.520), (sx * 0.55, -0.055, 1.470), 0.016, 0.016, "canvas")
    parts.append(p)

    # ---- whip antenna: long tape antenna, arcs up and back
    p = Part("prc25_antenna", "mixamorig:Spine2")
    # The AT-892 tape antenna is a long springy whip - in every RTO photo it
    # BOWS hard backward like a fishing rod under its own weight. A dead-straight
    # mast reads as a flagpole and kills the silhouette.
    base = Vector((0.105, 0.150, 1.535))
    segs = 9
    prev, r = base, 0.011
    for i in range(1, segs + 1):
        t = i / segs
        nxt = base + Vector((0.05 * t * t,                 # drifts outboard
                             0.62 * (t ** 1.7),            # the bow
                             1.30 * t * (1.0 - 0.18 * t)))  # height, easing off
        rr = 0.011 * (1.0 - 0.75 * t)
        p.tube(prev, nxt, r, rr, "steel", sides=4)
        prev, r = nxt, rr
    parts.append(p)

    # ---- H-189 handset + coiled cord (clipped at the left shoulder strap).
    # Reused as the player's FIRST-PERSON prop for calling support.
    p = Part("prc25_handset", "mixamorig:Spine2")
    p.box((0.115, 0.045, 1.455), (0.028, 0.030, 0.065), "black_rub")  # body
    p.box((0.115, 0.012, 1.500), (0.030, 0.014, 0.022), "black_rub")  # earpiece
    p.box((0.115, 0.012, 1.410), (0.030, 0.014, 0.022), "black_rub")  # mouthpiece
    p.box((0.145, 0.045, 1.455), (0.006, 0.010, 0.030), "od_light")   # push-to-talk
    parts.append(p)

    p = Part("prc25_cord", "mixamorig:Spine2")
    a = Vector((0.115, 0.070, 1.395))                                  # handset base
    b = Vector((0.075, 0.150, 1.500))                                  # into the set
    coils, prev = 9, a
    for i in range(1, coils + 1):
        t = i / coils
        ang = t * math.tau * 2.2
        mid = a.lerp(b, t) + Vector((math.cos(ang) * 0.022,
                                     math.sin(ang) * 0.012,
                                     -0.030 * math.sin(math.pi * t)))
        p.tube(prev, mid, 0.006, 0.006, "black_rub", sides=4)
        prev = mid
    parts.append(p)

    # ---- HEADGEAR ------------------------------------------------------
    p = Part("boonie_hat", "mixamorig:Head")
    p.tube((0, -0.012, 1.680), (0, -0.012, 1.742), 0.098, 0.086, "od_light", sides=8)
    p.tube((0, -0.012, 1.676), (0, -0.012, 1.686), 0.168, 0.168, "od_light", sides=8)  # floppy brim
    parts.append(p)

    p = Part("pith_helmet", "mixamorig:Head")                          # NVA
    p.tube((0, -0.012, 1.672), (0, -0.012, 1.752), 0.100, 0.070, "od_green", sides=8)
    p.tube((0, -0.012, 1.668), (0, -0.012, 1.680), 0.142, 0.142, "od_green", sides=8)
    p.tube((0, -0.012, 1.700), (0, -0.012, 1.706), 0.103, 0.103, "canvas_drk", sides=8)  # band
    parts.append(p)

    p = Part("usmc_utility_cover", "mixamorig:Head")
    p.box((0.0, -0.012, 1.706), (0.092, 0.106, 0.038), "od_light")     # soft cap
    p.box((0.0, -0.128, 1.690), (0.086, 0.036, 0.008), "od_light")     # short bill
    parts.append(p)

    # ---- LOAD-BEARING --------------------------------------------------
    p = Part("webbing_rig", "mixamorig:Spine1")                        # H-harness + belt
    for sx in (-0.095, 0.095):
        p.tube((sx, -0.085, 1.470), (sx * 0.8, 0.105, 1.470), 0.017, 0.017, "canvas")
        p.tube((sx * 0.8, 0.105, 1.470), (sx * 0.9, 0.075, 1.130), 0.016, 0.016, "canvas")
        p.tube((sx, -0.085, 1.470), (sx * 0.9, -0.085, 1.130), 0.016, 0.016, "canvas")
    p.tube((-0.145, 0.0, 1.120), (0.145, 0.0, 1.120), 0.020, 0.020, "canvas_drk", sides=4)
    p.box((0.0, -0.098, 1.120), (0.030, 0.014, 0.026), "brass")        # buckle
    parts.append(p)

    p = Part("ammo_pouch_l", "mixamorig:Hips")
    p.box((0.135, -0.060, 1.075), (0.050, 0.042, 0.062), "od_green")
    p.box((0.135, -0.100, 1.108), (0.050, 0.008, 0.030), "canvas")     # flap
    parts.append(p)

    p = Part("ammo_pouch_r", "mixamorig:Hips")
    p.box((-0.135, -0.060, 1.075), (0.050, 0.042, 0.062), "od_green")
    p.box((-0.135, -0.100, 1.108), (0.050, 0.008, 0.030), "canvas")
    parts.append(p)

    p = Part("satchel_bag", "mixamorig:Spine")                         # VC shoulder bag
    p.box((0.150, 0.020, 1.020), (0.070, 0.045, 0.080), "canvas_drk")
    p.box((0.150, -0.028, 1.075), (0.070, 0.010, 0.030), "canvas")     # flap
    p.tube((0.150, 0.020, 1.098), (-0.060, 0.010, 1.470), 0.012, 0.012, "canvas", sides=4)  # sling
    parts.append(p)

    p = Part("entrench_shovel", "mixamorig:Hips")
    p.tube((-0.155, 0.115, 1.150), (-0.155, 0.115, 0.980), 0.014, 0.014, "leather", sides=4)
    p.box((-0.155, 0.115, 0.935), (0.048, 0.010, 0.055), "steel")
    parts.append(p)

    # ============================================================ VILLAGE TOOLS
    # A civilian standing empty-handed in a paddy is a target. A civilian with a
    # SICKLE in his fist and a basket on his hip is a person doing a job, and the
    # player has to decide about him. These are the props that make a village read
    # as inhabited instead of populated.
    #
    # They obey the same contract as everything else in this locker: rigid,
    # bone-parented, unskinned, and named with a word HitzoneBuilder knows, so they
    # ride the man and contribute ZERO hitbox. You can hang them on any model on the
    # standard rig - farmer, elder, or a VC pretending to be one.
    hand_r = rig.matrix_world @ rig.pose.bones["mixamorig:RightHand"].head
    hand_l = rig.matrix_world @ rig.pose.bones["mixamorig:LeftHand"].head

    # ---- rice basket, worn on the back (a gio, woven split bamboo)
    p = Part("rice_basket_back", "mixamorig:Spine2")
    cz, cy = 1.290, 0.190
    for i, (r, z) in enumerate([(0.075, 1.120), (0.135, 1.230), (0.150, 1.330),
                                (0.130, 1.430)]):
        p.tube((0.0, cy, z), (0.0, cy, z + 0.001), r, r, "straw", sides=10)
    p.tube((0.0, cy, 1.115), (0.0, cy, 1.440), 0.150, 0.128, "straw", sides=10)
    p.tube((0.0, cy, 1.435), (0.0, cy, 1.455), 0.132, 0.140, "bamboo", sides=10)  # rim
    for sx in (-0.105, 0.105):                                        # shoulder cords
        p.tube((sx, 0.150, 1.470), (sx * 0.5, -0.060, 1.470), 0.010, 0.010, "canvas")
    parts.append(p)

    # ---- rice sickle (LIEM). RESEARCHED REBUILD.
    #
    # v1 was a 10mm tube and it VANISHED at PSX range. v2 was a constant-width crescent
    # slab with a stick crossing it - it read as a "C" and a toothpick, and the handle
    # did not even JOIN the blade, it passed through the hollow.
    #
    # What a real liem is (sickle refs: blade 15-30cm, curvature radius ~15cm, single-
    # bevelled and SHARPENED ON THE CONCAVE inner edge, tapering to a point that starts
    # the cut at soil level, short wooden handle):
    #   * the blade GROWS OUT OF the handle - it is one line, haft into tang into blade,
    #     not two objects crossing
    #   * it TAPERS. Wide at the tang, needle at the tip. A constant-width band is a
    #     croissant, not a tool.
    #   * the cutting edge is the INSIDE of the hook. So the blade is thick along its
    #     back (the arc) and thin at the inner edge - a wedge in cross-section.
    #   * it HOOKS: ~195 degrees, so the tip curls back toward the hand. That hook is
    #     what gathers the stalks, and it is the whole silhouette.
    p = Part("rice_sickle", "mixamorig:RightHand")

    R = 0.078                      # 26cm of blade along the arc - dead centre of the refs
    SWEEP = math.radians(195.0)
    N = 10
    W_TANG, W_TIP = 0.046, 0.006   # blade width: broad at the tang, needle at the tip
    T_BACK, T_EDGE = 0.0040, 0.0012  # thick at the spine, thin at the cutting edge

    # Local frame, then dropped into his fist: handle runs along Y (that is how a fist
    # holds a tool when the arm is out), blade curves in the YZ plane so it hooks up and
    # back toward him.
    grip = hand_r + Vector((0.0, 0.0, -0.012))
    base = grip + Vector((0.0, -0.075, 0.0))       # where the blade leaves the handle
    C = base + Vector((0.0, 0.0, R))               # centre of the blade's arc

    # handle: tapered, and it ENDS at the tang. Butt is fatter - that is what stops it
    # sliding out of a wet hand.
    p.tube(tuple(grip + Vector((0.0, 0.062, 0.0))), tuple(base), 0.020, 0.015,
           "wood", sides=6)
    # ferrule: the metal band that holds the tang. Small, but it is the join, and
    # without it the blade looks stuck on.
    p.tube(tuple(base + Vector((0.0, 0.016, 0.0))), tuple(base + Vector((0.0, -0.004, 0.0))),
           0.0165, 0.0155, "brass", sides=6)

    v, f = [], []
    for i in range(N + 1):
        t = i / N
        a = math.radians(-90.0) - SWEEP * t        # sweeps FORWARD out of the fist
        ca, sa = math.cos(a), math.sin(a)
        out = Vector((0.0, ca, sa))                # radially outward from the arc centre
        spine = C + out * R                        # the BACK of the blade (the arc)
        w = W_TANG + (W_TIP - W_TANG) * (t ** 0.75)   # taper, biased so it stays broad
        edge = C + out * (R - w)                   # the CONCAVE cutting edge
        th_b = T_BACK * (1.0 - 0.55 * t)           # and it thins toward the tip too
        th_e = T_EDGE * (1.0 - 0.55 * t)
        for pt, th in ((spine, th_b), (edge, th_e)):
            for tx in (-th, th):
                v.append((pt.x + tx, pt.y, pt.z))
    # per ring: 0 spine-, 1 spine+, 2 edge-, 3 edge+
    for i in range(N):
        b0, b1 = i * 4, (i + 1) * 4
        f.append([b0 + 0, b1 + 0, b1 + 1, b0 + 1])   # the spine (blunt back)
        f.append([b0 + 2, b0 + 3, b1 + 3, b1 + 2])   # the cutting edge
        f.append([b0 + 1, b1 + 1, b1 + 3, b0 + 3])   # one face
        f.append([b0 + 0, b0 + 2, b1 + 2, b1 + 0])   # the other
    f.append([0, 1, 3, 2])                           # cap the tang end
    p.add(v, f, "steel")
    parts.append(p)

    # ---- don ganh: the shoulder pole, with a basket swinging off each end. The
    # single most recognisable silhouette on a paddy dyke.
    p = Part("carry_pole", "mixamorig:Spine2")
    p.tube((-0.780, 0.020, 1.545), (0.780, 0.020, 1.545), 0.017, 0.017, "bamboo", sides=6)
    for sx in (-0.640, 0.640):
        for cx in (sx - 0.075, sx + 0.075):     # the two cords per end
            p.tube((cx, 0.020, 1.535), (cx, 0.020, 1.195), 0.005, 0.005, "canvas_drk",
                   sides=4)
        p.tube((sx, 0.020, 1.190), (sx, 0.020, 1.075), 0.155, 0.115, "straw", sides=10)
        p.tube((sx, 0.020, 1.185), (sx, 0.020, 1.196), 0.158, 0.150, "bamboo", sides=10)
        p.tube((sx, 0.020, 1.170), (sx, 0.020, 1.176), 0.140, 0.140, "rice", sides=10)
    parts.append(p)

    # ---- a sheaf of cut rice, carried in the off hand
    p = Part("rice_bundle", "mixamorig:LeftHand")
    g = hand_l + Vector((-0.02, 0.0, 0.0))
    p.tube(tuple(g + Vector((0, 0, -0.030))), tuple(g + Vector((0, 0, 0.030))),
           0.040, 0.045, "canvas_drk", sides=6)                   # the tie
    for i in range(7):                                            # the stalks, splayed
        a = math.tau * i / 7.0
        tip = g + Vector((0.055 * math.cos(a), 0.055 * math.sin(a), 0.240))
        p.tube(tuple(g + Vector((0, 0, 0.020))), tuple(tip), 0.012, 0.006, "rice",
               sides=4)
    parts.append(p)

    return parts


def export_each(objs, rig):
    os.makedirs(OUT_GLB, exist_ok=True)
    for o in objs:
        for x in bpy.data.objects:
            x.select_set(False)
        o.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        kw = dict(filepath=os.path.join(OUT_GLB, o.name + ".glb"),
                  export_format='GLB', use_selection=True, export_apply=True,
                  export_animations=False, export_skins=False, export_morph=False,
                  export_cameras=False, export_lights=False, export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})


def main():
    # start from the grunt so the rig + its rest pose are the real thing
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    # strip the character - we want a rig + gear library, nothing else
    for o in list(bpy.data.objects):
        if o is not rig and o.type in ('MESH', 'EMPTY'):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)

    save_palette_png()
    parts = build_all(rig)
    objs = [p.bake(rig) for p in parts]
    bpy.context.view_layer.update()

    print("\n%-22s %-22s %6s %6s" % ("piece", "bone", "verts", "tris"))
    for p, o in zip(parts, objs):
        tris = sum(max(0, len(f) - 2) for f in p.faces)
        print("%-22s %-22s %6d %6d" % (o.name, p.bone.replace("mixamorig:", ""),
                                       len(p.verts), tris))
    total = sum(sum(max(0, len(f) - 2) for f in p.faces) for p in parts)
    print("\n%d pieces, %d tris total (whole kit = ONE draw call: shared atlas)" % (len(parts), total))

    export_each(objs, rig)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("saved:", OUT_BLEND)
    print("GLBs ->", OUT_GLB)


if __name__ == "__main__":
    main()
