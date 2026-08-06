"""VC ZOMBIES - the undead cast, built on the same v3 base as everyone else.

    blender -b -P tools/make_zombies.py

Twelve units in assets/zombies/characters/, each a clone of us_base_v3.blend
(the gear-cut grunt), six archetypes off Caleb's reference sheet:

    zed_patient    hospital gown, barefoot        sheet row 1
    zed_staff      scrubs / stained coat, clogs   sheet row 2
    zed_security   dark uniform, boots            sheet row 3
    zed_farmer     homespun / plaid, boots        sheet row 4
    zed_cult       hooded robe, barefoot          sheet row 5
    zed_rotted     torn everything, advanced rot  sheet row 6

WHAT EVERY UNIT INHERITS FROM THE CLONE - and none of it costs anything:
  * PSXRig, 41 bones -> the shared anim library drives them with no re-export
  * THE GIB CONTRACT: grunt_* donors, splay_* bind copies, cap_* wound caps.
    Zombies gib because the base gibs. Nothing here builds gibbing.
  * one skinned body mesh -> probe_silhouette parts == 1
  * gear as rigid bone-parented *_worn -> never enters the hurtbox

FACES. The head's UV island already sits inside cell (0,0) of a 10x7 atlas - that
is the whole basis of GruntDresser's one-offset trick. So a zombie needs NO UV
work at all: swap the ATLAS IMAGE for zombie_face_atlas_v1.png and ZombieDresser
slides uv1_offset by (col/10, row/7) exactly like GruntDresser does. The texture
keeps "face_atlas" in its filename on purpose - GruntDresser identifies skin by
TEXTURE PATH, not material name, and ZombieDresser inherits that test.

SKIN IS DELIBERATELY NOT ON THE ATLAS. For grunts, face and skin share one
material so a black face can never sit on a white body. Every zombie is the same
shade of dead, so hands and feet take one necrotic material instead and the
invariant is not needed. Stated here because it is a deviation from the grunt
contract, and a silent deviation is drift.

The per-unit face pool and decay tier are written to zombie_manifest.json, which
ZombieDresser READS. Neither side owns the list alone, so they cannot drift.
"""
import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import US_BASE_V3, ZOMBIE_DIR, ZOMBIE_FACE_ATLAS

# The pure texture/mesh helpers are make_civilians'. Importing them is the point:
# forked copies of fabric()/grime()/scale_region() would drift the moment either
# cast got a retune.
from make_civilians import (BARE_BOOTED, BARE_PEASANT, BOOT_BONES, assign_by_bone,
                            bone_head, cloth_mat, flat_mat, grime, repoint_slot,
                            scale_region, shirt_hem, skin_tex, skinned_meshes,
                            textured_mat)

BASE = US_BASE_V3
RIG = "PSXRig"
BODY = "us_grunt_joined"

US_KIT = [
    "helmet_shell_worn", "bandolier_worn", "ruck_pack_worn", "pouch_belt_worn",
    "helmet_camo_shell", "helmet_bugjuice", "ruck_bag", "ruck_crossbar",
    "ruck_rail_l", "ruck_rail_r", "bandolier", "bando_mag0", "bando_mag1",
    "bando_mag2", "m16_world", "Base_Human",
]

# WHOLE FAMILIES OF KIT, stripped by prefix. The exact-name list above cannot
# express "every piece of US load-bearing equipment": the harness is 15 separate
# objects (web_belt, web_susp_l, web_pouch_r, web_clip_f_l, ...) and naming them
# one by one is a list that goes stale the next time the base is re-rigged.
#
# Found by comparing exports: civ_farmer_m.glb carries ZERO web_* meshes and the
# first zombie build carried all 15 - a hospital patient in US webbing, with
# web_bandolier the only one loud enough to trip model_actor's default-white
# probe. The other 14 were textured, so they would have shipped silently.
US_KIT_PREFIXES = ["web_", "bando_", "ruck_", "helmet_"]

# Atlas rows 0-4 are the 50 faces off the sheet; rows 5-6 are the 20 advanced-decay
# recolours make_zombie_atlas.py derived. Cell index == row * 10 + col.
FRESH_FACES = list(range(0, 50))
ROTTED_FACES = list(range(50, 70))

# Necrotic flesh. Not "pale skin" - the green-grey is what stops it reading as a
# living man in bad light.
SKIN_DEAD = (0.30, 0.30, 0.25)
SKIN_ROTTED = (0.20, 0.21, 0.17)

# Silhouette per archetype: (legs, sleeves, torso, neck). A recoloured fatigue
# shape is still a soldier - the same complaint that drove the civilian tailoring.
# 1.0 leaves the grunt's fitted shape, which is correct for a uniformed guard.
SIL_LOOSE = (1.20, 1.18, 1.14, 0.80)     # gown / robe: hangs off the frame
SIL_WORK = (1.10, 1.10, 1.06, 0.86)      # scrubs, homespun
SIL_FITTED = (1.00, 1.00, 1.00, 1.00)    # uniform shirt, kept military

_ARCHETYPES = {
    "zed_patient": dict(bare=BARE_PEASANT, sil=SIL_LOOSE, hem=(0.16, 1.26),
                        faces=FRESH_FACES, skin=SKIN_DEAD, tier="walker"),
    "zed_staff": dict(bare=BARE_BOOTED, sil=SIL_WORK, hem=(0.10, 1.14),
                      faces=FRESH_FACES, skin=SKIN_DEAD, tier="walker"),
    "zed_security": dict(bare=BARE_BOOTED, sil=SIL_FITTED, hem=None,
                         faces=FRESH_FACES, skin=SKIN_DEAD, tier="walker"),
    "zed_farmer": dict(bare=BARE_PEASANT, sil=SIL_WORK, hem=(0.13, 1.22),
                       faces=FRESH_FACES, skin=SKIN_DEAD, tier="walker"),
    "zed_cult": dict(bare=BARE_PEASANT, sil=SIL_LOOSE, hem=(0.20, 1.30),
                     faces=FRESH_FACES, skin=SKIN_DEAD, tier="walker"),
    "zed_rotted": dict(bare=BARE_PEASANT, sil=SIL_WORK, hem=(0.08, 1.10),
                       faces=ROTTED_FACES, skin=SKIN_ROTTED, tier="rotted"),
}

# suffix -> cloth colour, LINEAR. Two dye lots each: a ward of identical gowns
# reads as a spawner, which is the same note the village got.
_VARIANTS = {
    "zed_patient": [("", (0.290, 0.320, 0.300)),        # washed hospital green
                    ("_b", (0.330, 0.330, 0.310))],     # grey-white, filthy
    "zed_staff": [("", (0.240, 0.300, 0.300)),          # surgical teal
                  ("_b", (0.360, 0.350, 0.330))],       # stained white coat
    "zed_security": [("", (0.030, 0.035, 0.055)),       # navy
                     ("_b", (0.045, 0.045, 0.042))],    # black fatigue
    "zed_farmer": [("", (0.070, 0.035, 0.030)),         # faded red plaid
                   ("_b", (0.030, 0.035, 0.055))],      # denim overalls
    "zed_cult": [("", (0.040, 0.035, 0.028)),           # dark earth robe
                 ("_b", (0.055, 0.050, 0.040))],        # sackcloth
    "zed_rotted": [("", (0.050, 0.048, 0.040)),         # colour long gone
                   ("_b", (0.038, 0.040, 0.035))],
}

UNITS = {}
for _a, _spec in _ARCHETYPES.items():
    for _sfx, _cloth in _VARIANTS[_a]:
        UNITS[_a + _sfx] = dict(_spec, cloth=_cloth, archetype=_a)


def swap_face_atlas(path):
    """Point every atlas-sampling material at the zombie sheet.

    Matched on the material NAME here because that is what the .blend carries;
    the ENGINE matches on texture path (GruntDresser._rides_face_atlas), which is
    why the file keeps "face_atlas" in its name. Both tests must pass or the
    dresser silently declines to slide the face.
    """
    if not os.path.exists(path):
        sys.exit("zombie atlas missing: %s\n  run: python tools/make_zombie_atlas.py"
                 % path)
    img = bpy.data.images.load(path, check_existing=True)
    img.pack()
    hit = 0
    for mat in bpy.data.materials:
        if not (mat.name.startswith("face_atlas")
                or mat.name.startswith("grunt_face_skin")):
            continue
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                node.image = img
                node.interpolation = 'Closest'
                hit += 1
    if hit == 0:
        sys.exit("no face-atlas material found in the base - the head would ship "
                 "with a living man's face")
    return hit


def rot(body):
    """Necrosis and dried blood, over the top of the civilian grime pass.

    COLOR_0 multiplies albedo in glTF and Godot honours it, so this is a second
    albedo channel we already own - the same trick the civilians use for paddy mud.
    Darkens downward from the chest, because what ran down a body pooled at the
    waist and stayed there.

    The FACE stays white. COLOR_0 hits every material on the mesh and a shadow
    baked into the cheekbones fights the atlas face underneath it.
    """
    me = body.data
    if not me.color_attributes:
        me.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
    col = me.color_attributes[0]
    mats = [s.material.name if s.material else "" for s in body.material_slots]
    face_slots = {i for i, m in enumerate(mats) if m.startswith("face_atlas")}

    ws = [body.matrix_world @ v.co for v in me.vertices]
    zmin = min(w.z for w in ws)
    zmax = max(w.z for w in ws)
    for p in me.polygons:
        if p.material_index in face_slots:
            continue
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            t = (ws[vi].z - zmin) / max(1e-6, zmax - zmin)
            stain = 1.0 - 0.30 * max(0.0, min(1.0, (0.70 - t) / 0.70))
            prev = col.data[li].color
            v = max(0.20, min(1.20, prev[0] * stain))
            col.data[li].color = (v, v * 0.97, v * 0.94, 1.0)
    me.update()


def reshape(rig, sil):
    legs, sleeves, torso, neck = sil
    L, R = "mixamorig:Left", "mixamorig:Right"
    for s in (L, R):
        scale_region((s + "UpLeg", s + "Leg"), legs,
                     bone_head(rig, s + "UpLeg"), axes=(0, 1))
        scale_region((s + "Arm", s + "ForeArm"), sleeves,
                     bone_head(rig, s + "Arm"), axes=(1, 2))
    scale_region(("Spine", "Spine1", "Spine2"), torso,
                 bone_head(rig, "mixamorig:Spine"), axes=(0, 1))
    scale_region(("Neck",), neck, bone_head(rig, "mixamorig:Neck"), axes=(0, 1))


def build(unit, spec):
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    gone = 0
    for n in US_KIT:
        for o in [x for x in bpy.data.objects
                  if x.name == n or x.name.startswith(n + ".")]:
            bpy.data.objects.remove(o, do_unlink=True)
            gone += 1
    for o in [x for x in bpy.data.objects
              if x.name.startswith("canteen_l")
              or any(x.name.startswith(p) for p in US_KIT_PREFIXES)]:
        bpy.data.objects.remove(o, do_unlink=True)
        gone += 1

    n_atlas = swap_face_atlas(ZOMBIE_FACE_ATLAS)
    cloth = cloth_mat(unit + "_cloth", spec["cloth"], seed=abs(hash(unit)) % 9973)
    repoint_slot("us_grunt_mat", cloth)

    skin = textured_mat(unit + "_skin",
                        skin_tex(unit + "_skin_tex", spec["skin"],
                                 seed=abs(hash(unit + "rot")) % 9973),
                        spec["skin"])
    boot = flat_mat(unit + "_boot", (0.02, 0.016, 0.012))
    faces = 0
    for ob in skinned_meshes():
        faces += assign_by_bone(ob, skin, spec["bare"])
        if spec["bare"] is BARE_BOOTED:
            assign_by_bone(ob, boot, BOOT_BONES)

    reshape(rig, spec["sil"])
    hem = 0
    if spec["hem"] is not None:
        drop, flare = spec["hem"]
        hem = shirt_hem(bpy.data.objects[BODY], drop=drop, flare=flare)
    grime(bpy.data.objects[BODY], rig)
    rot(bpy.data.objects[BODY])

    rig.data.pose_position = 'POSE'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.scene.frame_set(1)

    os.makedirs(ZOMBIE_DIR, exist_ok=True)
    path = os.path.join(ZOMBIE_DIR, unit + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print("  %-16s kit-stripped %2d | atlas nodes %d | skin faces %3d | hem %3d -> %s"
          % (unit, gone, n_atlas, faces, hem, os.path.basename(path)),
          flush=True)


def write_manifest():
    """The face pool and decay tier, for ZombieDresser to read.

    The engine must not carry its own copy of these lists. GruntDresser hardcodes
    US_FACES and that list has already had to be corrected once by hand; deriving
    it from the builder is the fix for the whole class of problem.
    """
    out = {
        "atlas": "zombie_face_atlas_v1.png",
        "atlas_cols": 10,
        "atlas_rows": 7,
        "units": {u: {"archetype": s["archetype"], "tier": s["tier"],
                      "faces": s["faces"]}
                  for u, s in UNITS.items()},
    }
    path = os.path.join(ZOMBIE_DIR, "zombie_manifest.json")
    os.makedirs(ZOMBIE_DIR, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2)
    print("manifest -> %s (%d units)" % (os.path.basename(path), len(UNITS)))


def main():
    print("=== VC ZOMBIES: %d units on the v3 gear-cut base ===" % len(UNITS),
          flush=True)
    for unit, spec in UNITS.items():
        build(unit, spec)
    write_manifest()
    print("\nnext: blender -b <unit>.blend -P tools/export_zombies.py")


if __name__ == "__main__":
    main()
