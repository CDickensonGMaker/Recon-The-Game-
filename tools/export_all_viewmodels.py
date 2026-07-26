"""One-command FP viewmodel export: the whole armory, identically, every time.

    python tools/export_all_viewmodels.py             # export + validate every manifest gun
    python tools/export_all_viewmodels.py m16 ak      # subset

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
    for gun, spec in man["guns"].items():
        if only and gun not in only:
            continue
        print(f"=== EXPORT {gun} ===")
        r = subprocess.run([BLENDER, "-b", blend, "-P",
                            os.path.join(ROOT, "tools", "export_viewmodel_clips.py"),
                            "--", spec["collection"], spec["gun_prefix"], gun, "--strict"],
                           capture_output=True, text=True)
        tail = "\n".join((r.stdout + r.stderr).splitlines()[-25:])
        if r.returncode != 0 or "EXPORTED" not in r.stdout:
            print(tail)
            sys.exit(f"EXPORT FAILED: {gun} (blender exit {r.returncode})")
        for line in r.stdout.splitlines():
            if line.startswith(("===", "clips:", "parts to bake", "part max distance", "EXPORTED", "STRICT")):
                print("  ", line)
        v = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_viewmodel_glb.py"), gun],
                           capture_output=True, text=True)
        print(v.stdout.rstrip())
        if v.returncode != 0:
            sys.exit(f"VALIDATION FAILED: {gun}")
        ran += 1
    if ran == 0:
        sys.exit(f"no manifest gun matched {only}")
    print(f"ALL GOOD: {ran} gun(s) exported and validated. Reimport in Godot 4.7 to see them.")


if __name__ == "__main__":
    main()
