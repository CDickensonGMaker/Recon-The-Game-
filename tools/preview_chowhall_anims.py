"""Render the chow hall clips on a REAL US grunt v3 body - no helmet, no gear, no weapon.

    blender -b -P tools/preview_chowhall_anims.py

Reads assets/shared/chow_anim_workbench.blend, dresses its PSXRig in the grunt v3
body parts appended from us_base_v3.blend, and renders every clip to PNGs under
_scratch/chow_preview/<clip>/. tools/preview_chowhall_anims.ps1 muxes them to mp4.

THE BODY IS THE TROOP PARTS, NOT Base_Human - same rule as gen_artillery_crew.py:
Base_Human is the underlying base body and using it puts a mannequin on screen with
the wrong UVs. Off-duty men eating carry nothing, so the gear meshes are simply
never appended.
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ASSETS, ROOT, US_BASE_V3

WORKBENCH = os.path.join(ASSETS, "shared", "chow_anim_workbench.blend")
OUTDIR = os.path.join(ROOT, "_scratch", "chow_preview")
DONOR = "rifleman"
RES, FPS = 720, 30

# the body, and nothing that is worn or carried
BODY = ('grunt_torso', 'grunt_head', 'grunt_leg_l', 'grunt_leg_r',
        'grunt_forearm_l', 'grunt_forearm_r', 'grunt_uparm_l', 'grunt_uparm_r',
        'cap_torso', 'cap_head', 'cap_leg_l', 'cap_leg_r',
        'cap_forearm_l', 'cap_forearm_r', 'cap_uparm_l', 'cap_uparm_r')

CLIPS = ["chow_cook_stir", "chow_serve_ladle", "chow_tray_hold",
         "chow_eat_seated", "chow_tray_dump"]


def append_body(rig):
    """Append the grunt v3 body parts and bind them to the clip rig."""
    d = US_BASE_V3 + os.sep + "Object" + os.sep
    before = set(bpy.data.objects)
    parts = []
    for base in BODY:
        nm = "%s_%s" % (base, DONOR)
        try:
            bpy.ops.wm.append(directory=d, filename=nm)
        except RuntimeError as ex:
            print("  append failed %s: %s" % (nm, ex))
            continue
        o = bpy.data.objects.get(nm)
        if o and o.type == 'MESH':
            parts.append(o)
    # Every appended mesh drags in its own copy of the donor rig. Bind the meshes to
    # the rig that carries the CLIPS, then delete every stray armature.
    for o in parts:
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
        bpy.context.scene.collection.objects.link(o)
    for o in set(bpy.data.objects) - before:
        if o.type == 'ARMATURE' and o is not rig:
            bpy.data.objects.remove(o, do_unlink=True)

    # Appended materials keep image paths stored RELATIVE to us_base_v3.blend, and
    # this file lives in a different folder - so every texture missed and the man
    # rendered with magenta legs and cyan patches. Re-anchor them and reload.
    wanted = {bpy.path.abspath(i.filepath).replace("\\", "/").rsplit("/", 1)[-1].lower()
              for i in bpy.data.images if i.source == 'FILE' and not i.has_data}
    found = {}
    if wanted:
        for root, _dirs, files in os.walk(os.path.join(ASSETS, "us")):
            for fn in files:
                if fn.lower() in wanted and fn.lower() not in found:
                    found[fn.lower()] = os.path.join(root, fn)
        if len(found) < len(wanted):
            for root, _dirs, files in os.walk(ASSETS):
                for fn in files:
                    if fn.lower() in wanted and fn.lower() not in found:
                        found[fn.lower()] = os.path.join(root, fn)
    fixed = missing = 0
    for img in bpy.data.images:
        if img.source != 'FILE' or img.has_data:
            continue
        key = bpy.path.abspath(img.filepath).replace("\\", "/").rsplit("/", 1)[-1].lower()
        cand = found.get(key)
        if cand:
            img.filepath = cand
            try:
                img.reload()
                fixed += 1
                continue
            except RuntimeError:
                pass
        missing += 1
        print("     missing texture: %s" % key)
    print("  textures re-anchored: %d, still missing: %d" % (fixed, missing))
    return parts


def setup_scene(rig):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.fps = FPS
    sc.render.image_settings.file_format = 'PNG'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.show_cavity = True

    for n in ("PreviewCam", "PreviewFloor"):
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 55
    cam = bpy.data.objects.new("PreviewCam", cam_d)
    sc.collection.objects.link(cam)
    # AIM WITH A CONSTRAINT, NOT WITH EULER MATHS. Hand-rolled aim maths put the
    # first pass' camera on the floor plane with the man completely out of frame.
    aim = bpy.data.objects.get("PreviewAim") or bpy.data.objects.new("PreviewAim", None)
    if aim.name not in sc.collection.objects:
        sc.collection.objects.link(aim)
    aim.location = Vector((0.0, 0.0, 1.05))
    # The rig faces -Y (measured off the rest pose), so the camera goes to -Y and
    # round to his left for a three-quarter view of the hands.
    cam.location = Vector((1.9, -2.6, 1.55))
    con = cam.constraints.new('TRACK_TO')
    con.target = aim
    con.track_axis = 'TRACK_NEGATIVE_Z'
    con.up_axis = 'UP_Y'
    sc.camera = cam

    me = bpy.data.meshes.new("PreviewFloor")
    me.from_pydata([(-4, -4, 0), (4, -4, 0), (4, 4, 0), (-4, 4, 0)], [], [(0, 1, 2, 3)])
    me.update()
    sc.collection.objects.link(bpy.data.objects.new("PreviewFloor", me))
    return cam


def append_clips():
    """Bring the chow clips INTO the donor file."""
    d = WORKBENCH + os.sep + "Action" + os.sep
    got = []
    for name in CLIPS:
        if bpy.data.actions.get(name):
            got.append(name)
            continue
        try:
            bpy.ops.wm.append(directory=d, filename=name)
        except RuntimeError as ex:
            print("  clip append failed %s: %s" % (name, ex))
            continue
        if bpy.data.actions.get(name):
            got.append(name)
    return got


def main():
    # RENDER FROM THE DONOR FILE, not into a workbench.
    # us_base_v3.blend PACKS its textures - 16 of the grunt's images have no filepath
    # at all, and two more ("better textures.png", "nonoverlapping.png") exist nowhere
    # on disk. Appending the body into another blend therefore rendered him with
    # magenta legs and cyan patches. Appending the ACTIONS into the donor keeps the
    # material setup that already works.
    bpy.ops.wm.open_mainfile(filepath=US_BASE_V3)
    got = append_clips()
    print("  clips appended: %s" % ", ".join(got))
    rig = bpy.data.objects["PSXRig_%s" % DONOR]

    keep = {"%s_%s" % (b, DONOR) for b in BODY}
    parts, hidden = [], 0
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        if o.name in keep:
            parts.append(o)
        else:
            o.hide_render = True
            hidden += 1
    print("  body parts: %d / %d, other meshes hidden: %d"
          % (len(parts), len(BODY), hidden))
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    cam = setup_scene(rig)

    # Frame check BEFORE burning a render: where is the body actually standing?
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
    if pts:
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        print("  body bounds x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f"
              % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
        # The donor stands in a lineup, not at the origin - aim at where he ACTUALLY
        # is, or the frame check reports 2 corners of 128 and renders empty floor.
        mid = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0))
        aim = bpy.data.objects["PreviewAim"]
        aim.location = mid + Vector((0.0, 0.0, 1.05))
        cam.location = mid + Vector((1.9, -2.6, 1.55))
        bpy.context.view_layer.update()
        from bpy_extras.object_utils import world_to_camera_view
        pts = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
        seen = [world_to_camera_view(bpy.context.scene, cam, p) for p in pts]
        inside = sum(1 for s in seen if 0.0 <= s.x <= 1.0 and 0.0 <= s.y <= 1.0 and s.z > 0)
        print("  body corners inside frame: %d / %d" % (inside, len(seen)))
        if inside == 0:
            print("  !! BODY IS OUT OF FRAME - not rendering")
            return

    if rig.animation_data is None:
        rig.animation_data_create()

    for name in CLIPS:
        act = bpy.data.actions.get(name)
        if act is None:
            print("  MISSING clip", name)
            continue
        rig.animation_data.action = act
        if len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        sc = bpy.context.scene
        sc.frame_start, sc.frame_end = f0, f1
        sc.render.filepath = os.path.join(OUTDIR, name, "f_")
        print("  rendering %-18s frames %d-%d -> %s" % (name, f0, f1, sc.render.filepath))
        bpy.ops.render.render(animation=True)

    print("\n  PNGs under", OUTDIR)


main()
