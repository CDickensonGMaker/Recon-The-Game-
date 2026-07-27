"""Write each gun's authored clip lengths into its WeaponData .tres.

    python tools/sync_weapon_timers.py            # sync every manifest gun
    python tools/sync_weapon_timers.py ppsh       # one gun
    python tools/sync_weapon_timers.py --check    # report drift, change nothing, exit 1 if any

THE CONTRACT THIS ENFORCES (Summoner's ruling, 2026-07-26): the gameplay timer matches the
animation's authored length. `weapon_holder.gd` stretches every viewmodel clip to fit its timer
(`speed_scale = clip_len / duration`, ADR-018 - the timer is authoritative, the clip is
presentation). When the two disagree the clip plays at the wrong speed, and nothing used to
notice: ppsh41.tres declared neither empty_reload_time nor jam_clear_time, silently inherited the
WeaponData defaults, and played its transplanted AK-length clips at 0.76x / 1.30x / 3.30x.

The GLB is the source of truth, not the .blend - it is what the game actually loads. Durations
come from each animation's input accessor max, so this reads the same numbers Godot will.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "viewmodel_manifest.json")

# clip name -> the WeaponData field whose timer must equal it
CLIP_FIELD = {
    "reload": "reload_time",
    "reload_empty": "empty_reload_time",
    "jam": "jam_clear_time",
}
FIELD_ORDER = ["reload_time", "empty_reload_time", "jam_clear_time"]
SANE_SECONDS = (0.2, 20.0)
TOLERANCE = 0.002          # 0.06 of a frame at 30fps


def clip_durations(glb_path):
    """{clip name: seconds} from the GLB's own animation samplers."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from validate_viewmodel_glb import parse_glb
    gltf = parse_glb(glb_path)
    accessors = gltf.get("accessors", [])
    out = {}
    for a in gltf.get("animations", []):
        end = 0.0
        for s in a.get("samplers", []):
            mx = accessors[s["input"]].get("max")
            if mx:
                end = max(end, float(mx[0]))
        out[a.get("name", "?")] = end
    return out


def fmt(v):
    s = f"{round(v, 4):g}"
    return s if "." in s or "e" in s else s + ".0"


def apply(text, field, value):
    """Set field = value, inserting it in canonical order if absent."""
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if ln.startswith(field + " ="):
            lines[i] = f"{field} = {fmt(value)}"
            return "\n".join(lines) + "\n"
    # not present - insert after the latest earlier field that IS present
    anchor = None
    for earlier in FIELD_ORDER[:FIELD_ORDER.index(field)][::-1]:
        anchor = next((i for i, ln in enumerate(lines) if ln.startswith(earlier + " =")), None)
        if anchor is not None:
            break
    if anchor is None:
        anchor = next((i for i, ln in enumerate(lines) if ln.startswith("script = ")), None)
    if anchor is None:
        raise SystemExit(f"cannot find an insertion point for {field}")
    lines.insert(anchor + 1, f"{field} = {fmt(value)}")
    return "\n".join(lines) + "\n"


def main():
    args = sys.argv[1:]
    check = "--check" in args
    only = [a for a in args if not a.startswith("-")]
    man = json.load(open(MANIFEST))
    drift = 0
    touched = 0
    for gun, spec in man["guns"].items():
        if only and gun not in only:
            continue
        tres_rel = spec.get("weapon_tres")
        if not tres_rel:
            print(f"[skip] {gun}: no weapon_tres in the manifest")
            continue
        glb = os.path.join(ROOT, man["output_dir"], f"{gun}_fp.glb")
        tres = os.path.join(ROOT, tres_rel)
        if not os.path.exists(glb):
            print(f"[skip] {gun}: {glb} missing - export first")
            continue
        if not os.path.exists(tres):
            print(f"[FAIL] {gun}: {tres_rel} missing")
            drift += 1
            continue
        durations = clip_durations(glb)
        text = open(tres, encoding="utf-8").read()
        changes = []
        for clip, field in CLIP_FIELD.items():
            if clip not in durations:
                continue
            want = round(durations[clip], 4)
            if not SANE_SECONDS[0] <= want <= SANE_SECONDS[1]:
                print(f"[FAIL] {gun}: clip {clip} is {want}s - outside sane range, refusing")
                drift += 1
                continue
            cur = None
            for ln in text.splitlines():
                if ln.startswith(field + " ="):
                    cur = float(ln.split("=", 1)[1].strip())
                    break
            if cur is not None and abs(cur - want) <= TOLERANCE:
                continue
            changes.append((field, cur, want, clip))
            text = apply(text, field, want)
        if not changes:
            print(f"[ok]   {gun}: timers already match its clips")
            continue
        drift += len(changes)
        for field, cur, want, clip in changes:
            was = "absent (inherited default)" if cur is None else f"{cur}"
            scale = (durations[clip] / cur) if cur else None
            note = f"  was playing at {scale:.2f}x" if scale and abs(scale - 1.0) > 0.01 else ""
            print(f"[{'DRIFT' if check else 'sync '}] {gun}.{field}: {was} -> {fmt(want)}"
                  f"  ({clip} = {durations[clip]:.4f}s){note}")
        if not check:
            open(tres, "w", encoding="utf-8", newline="\n").write(text)
            touched += 1
    if check and drift:
        sys.exit(f"TIMER DRIFT: {drift} field(s) disagree with their clips - "
                 f"run `python tools/sync_weapon_timers.py` to fix")
    if not check:
        print(f"synced {touched} weapon resource(s)")


if __name__ == "__main__":
    main()
