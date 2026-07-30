"""One-command FP viewmodel export: the whole armory, identically, every time.

    python tools/export_all_viewmodels.py             # export + validate everything
    python tools/export_all_viewmodels.py m16 ak      # subset
    python tools/export_all_viewmodels.py handset     # a non-gun item works the same

Guns and `items` both run through here. An item differs in three ways only: its root key
is `item_root`, it has no `gun_prefix` (the root doubles as the prefix), and it carries no
`weapon_tres`, so the timer sync is skipped - an item's clip length is not a gameplay timer.

Per gun: blender -b <blend> -P export_viewmodel_clips.py -- <collection> <prefix> <out> --strict
(the strict pre-flight fails BEFORE writing a GLB if the rig contract is broken), then the
GLB validator runs on the output. First failure stops the run and names the gun.

Blender path: RECON_BLENDER env var, else the default install below.
NEVER run this against a .blend that is open in a live Blender session with unsaved work -
the disk file is what exports.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.environ.get("RECON_BLENDER",
                         r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe")
MANIFEST = os.path.join(ROOT, "tools", "viewmodel_manifest.json")


def main():
    if not os.path.exists(BLENDER):
        sys.exit(f"blender not found at {BLENDER} (set RECON_BLENDER)")
    man = json.load(open(MANIFEST))
    blend = os.path.join(ROOT, man["blend"])
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    ran = 0
    entries = [(k, v, False) for k, v in man["guns"].items()]         + [(k, v, True) for k, v in man.get("items", {}).items()]
    for gun, spec, is_item in entries:
        if only and gun not in only:
            continue
        print(f"=== EXPORT {gun} ===")
        root = spec.get("item_root", spec.get("gun_root", ""))
        prefix = spec.get("gun_prefix", root)
        cmd = [BLENDER, "-b", blend, "-P",
               os.path.join(ROOT, "tools", "export_viewmodel_clips.py"),
               "--", spec["collection"], prefix, gun, "--strict",
               f"--root={root}"]
        if spec.get("real_length_m"):
            cmd.append(f"--len={spec['real_length_m']}")
        if is_item:
            cmd.append("--item")
            cmd.append("--markers=" + ",".join(spec.get("markers", [])))
        r = subprocess.run(cmd, capture_output=True, text=True)
        tail = "\n".join((r.stdout + r.stderr).splitlines()[-25:])
        if r.returncode != 0 or "EXPORTED" not in r.stdout:
            print(tail)
            sys.exit(f"EXPORT FAILED: {gun} (blender exit {r.returncode})")
        for line in r.stdout.splitlines():
            if line.startswith(("===", "clips:", "parts to bake", "part max distance", "scale gate", "EXPORTED", "STRICT")):
                print("  ", line)
        v = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_viewmodel_glb.py"), gun],
                           capture_output=True, text=True)
        print(v.stdout.rstrip())
        if v.returncode != 0:
            sys.exit(f"VALIDATION FAILED: {gun}")
        # The gameplay timer follows the authored clip: weapon_holder stretches every
        # clip to fit it, so a stale .tres plays the animation at the wrong speed. An item
        # has no .tres - the gameplay clock owns its duration and ItemViewmodel stretches
        # the clip onto it, which is the same contract pointed the other way.
        if not is_item:
            s = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "sync_weapon_timers.py"), gun],
                               capture_output=True, text=True)
            print((s.stdout + s.stderr).rstrip())
            if s.returncode != 0:
                sys.exit(f"TIMER SYNC FAILED: {gun}")
        ran += 1
    if ran == 0:
        sys.exit(f"no manifest entry matched {only}")
    print(f"ALL GOOD: {ran} exported and validated. Reimport in Godot 4.7 to see them.")


if __name__ == "__main__":
    main()
