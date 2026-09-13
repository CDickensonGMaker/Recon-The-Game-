"""Render the talking-head proofs from talking_heads.blend: one fixed MGS-style close-up per head, Eevee 640x480, 24 fps.

    "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python th_render.py [-- --visemes] [-- --lines] [-- --head michael]

  --match    renders/sniper_match.png   : his game portrait (production/renders_conquest_of_worms/sniper_portrait_front.png)
             beside the cutscene head rendered front-on, same framing - the "is it the same man" check
  --visemes  renders/<head>_visemes.png : the 9 Rhubarb shapes side by side (humans: shape keys; skulls: jaw angles)
  --lines    renders/<head>_line.mp4    : the line keyed by th_lipsync.py, audio muxed by ffmpeg, plus two labelled
             spot-check stills renders/<head>_line_f<N>_<cue>.png (loudest open cue, and a silent X cue)
No flag = both. Frame sequences are deleted after encoding.
"""
import bpy, math, os, sys, shutil, subprocess, json
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import th_face as F

OUT_DIR = os.path.dirname(HERE)
BLEND = os.environ.get("TH_BLEND") or os.path.join(OUT_DIR, "talking_heads.blend")      # TH_BLEND/TH_RENDERS: dry runs on a scratch copy
RENDERS = os.environ.get("TH_RENDERS") or os.path.join(OUT_DIR, "renders")
LIPSYNC = os.path.join(OUT_DIR, "lipsync")
os.makedirs(RENDERS, exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_MATCH = "--match" in ARGS
DO_VIS = "--visemes" in ARGS or ("--lines" not in ARGS and not DO_MATCH)
DO_LINES = "--lines" in ARGS or ("--visemes" not in ARGS and not DO_MATCH)
ONLY = ARGS[ARGS.index("--head") + 1] if "--head" in ARGS else None
FFMPEG = shutil.which("ffmpeg")
FACE_FRACTION = 0.65
HEADS = {
    "michael": ["cs_head_michael"],
    "gus": ["cs_head_gus"],
    "sniper": ["cs_skull_sniper", "cs_mandible_sniper"],
    "zombie": ["cs_skull_zombie", "cs_mandible_zombie", "cs_zombie_helmet_cover", "cs_zombie_helmet_band", "cs_zombie_helmet_card_ace"],
}

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.render.fps = 24
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 640, 480, 100
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGB'
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
sc.eevee.taa_render_samples = 16
world = sc.world or bpy.data.worlds.new("World"); sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.045, 0.045, 0.05, 1.0); bg.inputs[1].default_value = 1.0

cam_data = bpy.data.cameras.new("cs_cam"); cam_data.lens = 50; cam_data.sensor_fit = 'HORIZONTAL'; cam_data.sensor_width = 36
cam = bpy.data.objects.new("cs_cam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
vfov = 2 * math.atan((cam_data.sensor_width * 480 / 640 / 2) / cam_data.lens)


def light(name, kind, energy, size, colour=(1, 1, 1)):
    ld = bpy.data.lights.new(name, kind); ld.energy = energy; ld.color = colour
    if kind == 'AREA': ld.size = size
    lo = bpy.data.objects.new(name, ld); sc.collection.objects.link(lo)
    return lo


lights = [light("cs_key", 'AREA', 32, 0.6), light("cs_fill", 'AREA', 10, 1.0, (0.9, 0.95, 1.0)), light("cs_rim", 'AREA', 30, 0.5, (1.0, 0.95, 0.85))]


def bounds(objs, frame):
    sc.frame_set(frame)
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh()
        pts += [oe.matrix_world @ v.co for v in me.vertices]
        oe.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def frame_head(tag, fraction=FACE_FRACTION, aim_dz=0.0, yaw_deg=-8.0):
    objs = [bpy.data.objects[n] for n in HEADS[tag]]
    lo, hi = bounds(objs, 0)
    H = hi.z - lo.z
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2 + aim_dz))
    face_pt = Vector((centre.x, lo.y, centre.z))
    dist = H / (2 * math.tan(vfov / 2) * fraction)
    yaw = math.radians(yaw_deg)
    d = Vector((math.sin(yaw), -math.cos(yaw), 0.0))
    cam.location = face_pt + d * dist
    cam.rotation_euler = (face_pt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    key, fill, rim = lights
    right = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    for lo_, pos in ((key, face_pt + d * 0.9 - right * 0.55 + Vector((0, 0, 0.5))),
                     (fill, face_pt + d * 0.9 + right * 0.7 + Vector((0, 0, 0.1))),
                     (rim, face_pt - d * 0.6 + right * 0.4 + Vector((0, 0, 0.55)))):
        lo_.location = pos
        lo_.rotation_euler = (face_pt - pos).to_track_quat('-Z', 'Y').to_euler()
    shown = set(HEADS[tag])
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in shown
    return {"height_m": round(H, 4), "cam_dist_m": round(dist, 3)}


def render(path, frame):
    sc.frame_set(frame); sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


PY = shutil.which("python")          # system Python has PIL; Blender's does not


def label(png, text, sub=None):
    subprocess.run([PY, os.path.join(HERE, "th_sheet.py"), "label", png, text] + ([sub] if sub else []), check=True)


def tile(out, cols, paths):
    subprocess.run([PY, os.path.join(HERE, "th_sheet.py"), "tile", out, str(cols)] + list(paths), check=True)


def jaw_quat(rig, deg):
    axis = Vector(rig["jaw_axis"]) if "jaw_axis" in rig else Vector((1, 0, 0))
    return Quaternion(axis, math.radians(deg))


def viseme_sheet(tag):
    """9 shapes side by side. Any lipsync action is detached while the stills are taken and put back after."""
    objs = [bpy.data.objects[n] for n in HEADS[tag]]
    rig = bpy.data.objects[f"PSXRig_{tag}"]
    tmp = os.path.join(RENDERS, f"_vis_{tag}")
    os.makedirs(tmp, exist_ok=True)
    sc.render.resolution_x, sc.render.resolution_y = 320, 240
    human = tag in ("michael", "gus")
    frame_head(tag, fraction=1.25, aim_dz=-0.02)          # mouth close-up for the sheet; the line keeps the MGS framing
    saved = None
    if human:
        key = objs[0].data.shape_keys
        if key.animation_data and key.animation_data.action:
            saved = key.animation_data.action; key.animation_data.action = None
        kbs = key.key_blocks
    else:
        ad = rig.animation_data
        if ad and ad.action:
            saved = ad.action; ad.action = None
    tiles = []
    for vis in F.VISEMES:
        if human:
            for kb in kbs:
                if kb.name != "Basis":
                    kb.value = 1.0 if kb.name == vis else 0.0
        else:
            rig.pose.bones["jaw"].rotation_quaternion = jaw_quat(rig, F.JAW_DEG[vis])
        bpy.context.view_layer.update()
        p = os.path.join(tmp, f"{vis}.png")
        render(p, 0)
        label(p, f"{tag}  {vis}" + ("" if human else f"  jaw {F.JAW_DEG[vis]:.0f} deg"))
        tiles.append(p)
    eyes_out = None
    if human:
        eye_tiles = []
        for kname in F.EYE_KEYS:
            for kb in kbs:
                if kb.name != "Basis":
                    kb.value = 1.0 if kb.name == kname else 0.0
            bpy.context.view_layer.update()
            p = os.path.join(tmp, f"eye_{kname}.png")
            render(p, 0)
            label(p, f"{tag}  {kname}" + ("  (character's own side)" if kname in ("blink_L", "blink_R") else ""))
            eye_tiles.append(p)
        eyes_out = os.path.join(RENDERS, f"{tag}_eyes.png")
        tile(eyes_out, 5, eye_tiles)
        for kb in kbs:
            if kb.name != "Basis":
                kb.value = 0.0
        if saved:
            key.animation_data.action = saved
    else:
        rig.pose.bones["jaw"].rotation_quaternion = (1, 0, 0, 0)
        if saved:
            rig.animation_data.action = saved
    out = os.path.join(RENDERS, f"{tag}_visemes.png")
    tile(out, 3, tiles)
    shutil.rmtree(tmp)
    sc.render.resolution_x, sc.render.resolution_y = 640, 480
    frame_head(tag)
    return {"visemes": out, "eyes": eyes_out} if eyes_out else out


def line_render(tag):
    """The keyed line: every frame to an mp4 with the wav muxed, plus two labelled spot-check stills."""
    rig = bpy.data.objects[f"PSXRig_{tag}"]
    if "th_line" not in rig:
        print("[TH-RENDER]", tag, "has no keyed line (run th_lipsync.py first)")
        return None
    meta = json.loads(rig["th_line"])
    n = meta["frames"]
    seq = os.path.join(RENDERS, f"_seq_{tag}")
    os.makedirs(seq, exist_ok=True)
    for f in range(n):
        render(os.path.join(seq, f"{f:03d}.png"), f)
    mp4 = os.path.join(RENDERS, f"{tag}_line.mp4")
    subprocess.run([FFMPEG, "-v", "error", "-y", "-framerate", "24", "-i", os.path.join(seq, "%03d.png"), "-i", meta["wav"],
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-c:a", "aac", "-b:a", "128k", "-shortest", mp4], check=True)
    # spot checks straight off the sequence: the loudest open cue and a silent cue
    cues = meta["cues"]
    stills = {}
    for pick, cands in (("open", [c for c in cues if c["value"] in ("D", "C")] or [c for c in cues if c["value"] != "X"]),
                        ("silent", [c for c in cues if c["value"] == "X"])):
        if not cands:
            continue
        c = max(cands, key=lambda c: c["end"] - c["start"])
        f = min(n - 1, int(round(24 * 0.5 * (c["start"] + c["end"]))))
        dst = os.path.join(RENDERS, f"{tag}_line_f{f:03d}_{c['value']}.png")
        shutil.copy(os.path.join(seq, f"{f:03d}.png"), dst)
        label(dst, f"{tag}  frame {f}  t={f / 24:.2f}s  cue {c['value']} ({pick})", os.path.basename(meta["wav"]) + "  " + repr(meta.get("text", "")))
        stills[pick] = dst
    shutil.rmtree(seq)
    return {"mp4": mp4, "frames": n, "wav": meta["wav"], "stills": stills}


def match_render():
    """renders/sniper_match.png: the game portrait beside the cutscene head, both front-on, head ~70% of frame height."""
    portrait = os.path.join(os.path.dirname(os.path.dirname(OUT_DIR)), "renders_conquest_of_worms", "sniper_portrait_front.png")
    assert os.path.exists(portrait), portrait
    sc.render.resolution_x, sc.render.resolution_y = 450, 540
    vf = 2 * math.atan((cam_data.sensor_width * 540 / 450 / 2) / cam_data.lens)
    global vfov
    saved = vfov; vfov = vf
    frame_head("sniper", fraction=0.72, aim_dz=0.0, yaw_deg=0.0)
    vfov = saved
    tmp = os.path.join(RENDERS, "_match_sniper.png")
    render(tmp, 0)
    label(tmp, "cutscene head  cs_skull_sniper + cs_mandible_sniper  (his game head split on the painted mouth, jaw shut)")
    port = os.path.join(RENDERS, "_match_portrait.png")
    shutil.copy(portrait, port)
    label(port, "game portrait  sniper_portrait_front.png")
    out = os.path.join(RENDERS, "sniper_match.png")
    tile(out, 2, [port, tmp])
    os.remove(tmp); os.remove(port)
    sc.render.resolution_x, sc.render.resolution_y = 640, 480
    return out


info = {}
if DO_MATCH:
    info["sniper_match"] = match_render()
    print("[TH-RENDER] match", info["sniper_match"])
for tag in HEADS:
    if DO_MATCH and not (DO_VIS or DO_LINES):
        break
    if ONLY and tag != ONLY:
        continue
    info[tag] = frame_head(tag)
    if DO_VIS:
        info[tag]["visemes"] = viseme_sheet(tag)
    if DO_LINES and FFMPEG:
        info[tag]["line"] = line_render(tag)
    print("[TH-RENDER]", tag, info[tag])
with open(os.path.join(RENDERS, "_render_info.json"), "w") as fh:
    json.dump(info, fh, indent=1)
print("[TH-RENDER] done; ffmpeg =", FFMPEG)
