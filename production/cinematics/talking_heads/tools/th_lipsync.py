"""th_lipsync.py - key a recorded line onto a talking head from Rhubarb Lip Sync mouth cues.

    "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b production/cinematics/talking_heads/talking_heads.blend ^
        --python production/cinematics/talking_heads/tools/th_lipsync.py -- --head michael --wav assets/audio/vo/john/squad_contact_front.wav --text "contact front"
    ... --python .../th_lipsync.py -- --all            # every entry in lines.json (the shipped proof lines)
    add --no-save to leave the .blend untouched (cues are still written to lipsync/).

Rhubarb (tools/rhubarb/Rhubarb-Lip-Sync-<ver>-Windows/rhubarb.exe, gitignored, 156 MB, from
github.com/DanielSWolf/rhubarb-lip-sync) runs with `-f json -r pocketSphinx` and, when --text is given, the spoken
text as `-d` so the recogniser has the words. Each mouth cue becomes a one-hot key: the cue's shape at 1.0 and the
other eight at 0.0 from the cue's first frame, with a 1-frame linear ramp from the previous cue (24 fps). X (rest)
covers silence. Humans (cs_head_*): shape keys A..H,X. Skulls (cs_skull_*): the `jaw` bone rotates about its hinge
axis by th_face.JAW_DEG[cue] (X/A 0, G 2, B 4, F 5, E 7, H 8, C 11, D 18 deg), same ramp. One blink is keyed on the
humans near 45% of the line; brows are left to the animator.

The head's rig gets a custom property `th_line` (wav, text, frame count, cues) that th_render.py reads, the wav is
laid on its own muted VSE channel for scrubbing, and the raw Rhubarb JSON is kept in lipsync/<head>_<wavstem>.json.
"""
import bpy, os, sys, json, glob, math, subprocess, shutil
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import th_face as F

R = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.dirname(HERE)
LIPSYNC = os.path.join(OUT_DIR, "lipsync")
os.makedirs(LIPSYNC, exist_ok=True)
FPS = 24
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(flag, default=None):
    return ARGS[ARGS.index(flag) + 1] if flag in ARGS else default


def find_rhubarb():
    hits = glob.glob(os.path.join(R, "tools", "rhubarb", "Rhubarb-Lip-Sync-*-Windows", "rhubarb.exe"))
    if not hits:
        raise SystemExit("rhubarb.exe not found under tools/rhubarb/ - download the Windows zip from "
                         "github.com/DanielSWolf/rhubarb-lip-sync/releases and unzip it there")
    return sorted(hits)[-1]


def run_rhubarb(wav, text, tag):
    exe = find_rhubarb()
    version = subprocess.run([exe, "--version"], capture_output=True, text=True).stdout.strip()
    stem = os.path.splitext(os.path.basename(wav))[0]
    out = os.path.join(LIPSYNC, f"{tag}_{stem}.json")
    cmd = [exe, "-f", "json", "-r", "pocketSphinx", "-o", out, "--quiet"]
    if text:
        txt = os.path.join(LIPSYNC, f"{tag}_{stem}.txt")
        with open(txt, "w", encoding="utf-8") as fh:
            fh.write(text.strip() + "\n")
        cmd += ["-d", txt]
    cmd.append(wav)
    subprocess.run(cmd, check=True)
    data = json.load(open(out))
    return data, version, out


def cues_to_frames(cues, duration):
    """[(viseme, f_start)] in ascending frames, zero-length cues dropped, consecutive repeats merged; and n frames."""
    n = int(math.ceil(duration * FPS))
    seq = []
    for c in cues:
        fs, fe = int(round(c["start"] * FPS)), int(round(c["end"] * FPS))
        if fe <= fs:
            continue
        if seq and seq[-1][0] == c["value"]:
            continue
        seq.append((c["value"], fs))
    if not seq or seq[0][1] > 0:
        seq.insert(0, ("X", 0))
    return seq, n


def fcurves_of(ad):
    """Blender 5 slotted actions: the F-curves live in the channelbag of the ID's slot (action.fcurves is gone)."""
    act, slot = ad.action, ad.action_slot
    cbs = []
    for layer in act.layers:
        for strip in layer.strips:
            cb = strip.channelbag(slot)
            if cb:
                cbs.append(cb)
    assert len(cbs) == 1, len(cbs)
    return cbs[0].fcurves


def set_linear(ad):
    for fc in fcurves_of(ad):
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR'


def key_human(obj, seq, n):
    key = obj.data.shape_keys
    kbs = key.key_blocks
    if key.animation_data and key.animation_data.action:
        old = key.animation_data.action
        key.animation_data.action = None
        bpy.data.actions.remove(old)
    for kb in kbs:
        if kb.name != "Basis":
            kb.value = 0.0

    def one_hot(vis, frame):
        for v in F.VISEMES:
            kbs[v].value = 1.0 if v == vis else 0.0
            kbs[v].keyframe_insert("value", frame=frame)
    for i, (vis, fs) in enumerate(seq):
        if i > 0:
            one_hot(seq[i - 1][0], fs - 1)
        one_hot(vis, fs)
    one_hot(seq[-1][0], n - 1)
    # one blink near 45% of the line (only on lines of a second or more)
    if n >= FPS:
        fb = int(round(0.45 * n))
        for f, val in ((fb - 2, 0.0), (fb, 1.0), (fb + 1, 1.0), (fb + 3, 0.0)):
            kbs["blink"].value = val
            kbs["blink"].keyframe_insert("value", frame=f)
    kbs["blink"].value = 0.0
    for v in F.VISEMES:
        kbs[v].value = 0.0
    act = key.animation_data.action
    act.name = f"line_{obj.name.replace('cs_head_', '')}"
    set_linear(key.animation_data)
    return act


def key_skull(rig, seq, n):
    pb = rig.pose.bones["jaw"]
    axis = Vector(rig["jaw_axis"])
    # the same formula th_build used: world +X in the bone's rest-local frame
    check = (rig.matrix_world @ rig.data.bones["jaw"].matrix_local).to_3x3().inverted() @ Vector((1, 0, 0))
    assert (check.normalized() - axis).length < 1e-3, (check, axis)
    act = rig.animation_data.action
    fcs = fcurves_of(rig.animation_data)
    for fc in list(fcs):
        if fc.data_path == 'pose.bones["jaw"].rotation_quaternion':
            fcs.remove(fc)
    pb.rotation_mode = 'QUATERNION'

    def key(vis, frame):
        pb.rotation_quaternion = Quaternion(axis, math.radians(F.JAW_DEG[vis]))
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    for i, (vis, fs) in enumerate(seq):
        if i > 0:
            key(seq[i - 1][0], fs - 1)
        key(vis, fs)
    key(seq[-1][0], n - 1)
    for fc in fcurves_of(rig.animation_data):
        if fc.data_path == 'pose.bones["jaw"].rotation_quaternion':
            for kp in fc.keyframe_points:
                kp.interpolation = 'LINEAR'
    return act


def wav_rms_per_frame(wav, n):
    """RMS of the 16-bit mono PCM per 24-fps frame (0..1), read with the stdlib: the proof that the mouth follows the sound."""
    import wave, struct
    with wave.open(wav, "rb") as w:
        sr, ch, sw, nfr = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(nfr)
    assert sw == 2, sw
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)[::ch]
    per = sr / FPS
    out = []
    for f in range(n):
        seg = samples[int(f * per):int((f + 1) * per)]
        out.append((sum(x * x for x in seg) / max(1, len(seg))) ** 0.5 / 32768.0 if seg else 0.0)
    return out


def verify_keys(tag, seq, n, wav):
    """Evaluate the scene at each cue's first frame and mid frame: the cue's shape must be the only one at 1.0 (humans)
    / the jaw must sit at its table angle (skulls). Then openness vs audio energy: the loudest quarter of the frames
    must be more open than the quietest quarter, or the sync is not following the sound."""
    sc = bpy.context.scene
    human = tag in ("michael", "gus")
    rig = bpy.data.objects[f"PSXRig_{tag}"]
    kbs = bpy.data.objects[f"cs_head_{tag}"].data.shape_keys.key_blocks if human else None
    axis = Vector(rig["jaw_axis"]) if not human else None

    def openness(frame):
        sc.frame_set(frame)
        if human:
            vals = {v: kbs[v].value for v in F.VISEMES}
            return sum(F.JAW_DEG[v] * vals[v] for v in vals), vals
        q = rig.pose.bones["jaw"].rotation_quaternion
        ang = math.degrees(2 * math.atan2(Vector((q.x, q.y, q.z)).length, q.w))
        return ang, {"jaw_deg": ang}
    bad = []
    for i, (vis, fs) in enumerate(seq):
        fe = seq[i + 1][1] if i + 1 < len(seq) else n
        for frame in {fs, (fs + fe - 1) // 2}:
            op, vals = openness(frame)
            if human:
                ok = abs(vals[vis] - 1.0) < 1e-4 and all(abs(vals[v]) < 1e-4 for v in vals if v != vis)
            else:
                ok = abs(op - F.JAW_DEG[vis]) < 0.05
            if not ok:
                bad.append((frame, vis, {k: round(v, 3) for k, v in vals.items()}))
    rms = wav_rms_per_frame(wav, n)
    ops = [openness(f)[0] for f in range(n)]
    order = sorted(range(n), key=lambda f: rms[f])
    q = max(1, n // 4)
    quiet, loud = order[:q], order[-q:]
    op_quiet = sum(ops[f] for f in quiet) / q
    op_loud = sum(ops[f] for f in loud) / q
    sc.frame_set(0)
    loud_frames = [f for f in range(n) if rms[f] > 0.3]
    shut_loud = [f for f in loud_frames if ops[f] <= 2.0]
    res = {"cue_frames_checked": 2 * len(seq), "cue_frames_wrong": len(bad), "wrong": bad[:6],
           "loud_frames_rms_gt_0.3": len(loud_frames), "loud_frames_with_mouth_shut": len(shut_loud), "shut_loud_frames": shut_loud[:12],
           "openness_deg_loudest_quarter": round(op_loud, 2), "openness_deg_quietest_quarter": round(op_quiet, 2),
           "rms_loudest_quarter": round(sum(rms[f] for f in loud) / q, 4), "rms_quietest_quarter": round(sum(rms[f] for f in quiet) / q, 4),
           "peak_rms_frame": max(range(n), key=lambda f: rms[f]), "openness_at_peak_deg": round(ops[max(range(n), key=lambda f: rms[f])], 2)}
    print(f"[TH-LIPSYNC] {tag} verify: {res}")
    assert not bad, bad
    assert op_loud > op_quiet, res
    if loud_frames and len(shut_loud) > 0.25 * len(loud_frames):
        print(f"[TH-LIPSYNC] WARNING {tag}: the mouth is shut on {len(shut_loud)} of {len(loud_frames)} loud frames - Rhubarb "
              f"mis-read this take (measured on ryan/squad_fall_back: 7 of 16). Pick another take or hand-fix those cues.")
    return res


def add_sound_strip(wav, tag, channel):
    sc = bpy.context.scene
    if not sc.sequence_editor:
        sc.sequence_editor_create()
    se = sc.sequence_editor
    strips = se.strips if hasattr(se, "strips") else se.sequences        # 4.4+ renamed sequences -> strips (an empty collection is falsy: test the attribute, not the value)
    for s in list(strips):
        if s.name == f"vo_{tag}":
            strips.remove(s)
    st = strips.new_sound(f"vo_{tag}", wav, channel, 0)
    st.mute = True
    return st


def sync(tag, wav, text, save):
    wav = os.path.abspath(os.path.join(R, wav)) if not os.path.isabs(wav) else wav
    assert os.path.exists(wav), wav
    rig = bpy.data.objects[f"PSXRig_{tag}"]
    data, version, cue_json = run_rhubarb(wav, text, tag)
    cues = data["mouthCues"]
    duration = data["metadata"]["duration"]
    seq, n = cues_to_frames(cues, duration)
    human = tag in ("michael", "gus")
    if human:
        act = key_human(bpy.data.objects[f"cs_head_{tag}"], seq, n)
    else:
        act = key_skull(rig, seq, n)
    channel = {"michael": 1, "gus": 2, "sniper": 3, "zombie": 4}[tag]
    add_sound_strip(wav, tag, channel)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    sc.frame_end = max(sc.frame_end, n - 1)
    sc.frame_set(0)
    verify = verify_keys(tag, seq, n, wav)
    meta = {"wav": wav, "text": text, "frames": n, "duration_s": duration, "cues": cues, "rhubarb": version,
            "cue_json": cue_json, "action": act.name, "sequence": seq, "verify": verify}
    rig["th_line"] = json.dumps(meta)
    kinds = {}
    for c in cues:
        kinds[c["value"]] = kinds.get(c["value"], 0) + 1
    print(f"[TH-LIPSYNC] {tag}: {os.path.basename(wav)} {duration:.2f}s -> {n} frames, {len(cues)} cues {kinds}, "
          f"{len(seq)} keyed transitions, action {act.name}, {version}")
    return meta


if "--all" in ARGS:
    manifest = json.load(open(os.path.join(OUT_DIR, "lines.json")))
    for tag, ent in manifest.items():
        sync(tag, ent["wav"], ent.get("text", ""), True)
else:
    sync(arg("--head"), arg("--wav"), arg("--text", ""), True)
if "--no-save" not in ARGS:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile(filepath=bpy.data.filepath)
    print("[TH-LIPSYNC] saved", bpy.data.filepath)
    # append to the build report so the shipped numbers live in one place
    rp = os.path.join(OUT_DIR, "build_report.json")
    report = json.load(open(rp)) if os.path.exists(rp) else {}
    report.setdefault("lipsync", {})
    for o in bpy.data.objects:
        if o.name.startswith("PSXRig_") and "th_line" in o:
            m = json.loads(o["th_line"])
            report["lipsync"][o.name.replace("PSXRig_", "")] = {k: m[k] for k in ("wav", "text", "frames", "duration_s", "rhubarb", "action", "verify")}
    with open(rp, "w") as fh:
        json.dump(report, fh, indent=1, default=str)
