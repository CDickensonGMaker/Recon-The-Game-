"""Write radio_manifest.json: track lengths for the field radio's virtual timeline.

The radio prop needs every track's duration up front to walk its timeline, but loading
the broadcasts to ask them costs ~96 MB of ogg at world load. The manifest is that
arithmetic without the load. Regenerate whenever a track is added or replaced;
tests/test_radio_timeline.gd fails if it disagrees with the files on disk.

    python tools/gen_radio_manifest.py
"""
import json
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "audio", "Radio Vietnam")
MANIFEST = os.path.join(ROOT, "radio_manifest.json")


def duration(path: str) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("ffprobe failed on %s: %s" % (path, out.stderr[:200]))
    return round(float(out.stdout.strip()), 3)


def scan(folder: str) -> dict:
    if not os.path.isdir(folder):
        return {}
    return {f: duration(os.path.join(folder, f))
            for f in sorted(os.listdir(folder)) if f.lower().endswith(".ogg")}


def main() -> int:
    data = {"broadcast": scan(ROOT), "music": scan(os.path.join(ROOT, "music"))}
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")
    for kind in ("broadcast", "music"):
        total = sum(data[kind].values())
        print("%-10s %2d tracks  %6.1f min" % (kind, len(data[kind]), total / 60.0))
    print("wrote %s" % MANIFEST)
    return 0


if __name__ == "__main__":
    sys.exit(main())
