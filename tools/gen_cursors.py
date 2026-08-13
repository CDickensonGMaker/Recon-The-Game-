"""gen_cursors.py - slice the cursor sheet into hardware-sized cursors.

Godot takes ONE Texture2D per cursor shape, so an atlas has to be cut. The sheet stays the
source of truth and these regenerate from it.

SIZE IS NOT COSMETIC. Input.set_custom_mouse_cursor rejects anything over 256x256, and
above 128x128 Windows silently drops the HARDWARE cursor for a software one - which lags a
frame behind the mouse and reads as broken input. 32 is the safe shipping size; 64 is still
hardware and holds up on a 1440p/4K desktop.

Run: python tools/gen_cursors.py
Writes assets/ui/cursors/<name>_32.png, <name>_64.png and cursors.json (hotspots).
"""
import json
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = r"C:/Users/caleb/Desktop/Projects/RECON Vietnam/recon game image ideas/menu assets/cursors.png"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "cursors")
SIZES = (64, 32)
ROWS = 3
## Anything smaller than this is a speck, not an icon.
MIN_AREA = 400

# Reading order, left to right, top to bottom.
NAMES = [
    "bullet", "crossed", "knife", "bayonet",
    "grenade", "dogtags", "belt", "huey",
    "compass", "casing", "chevron", "kbar",
]

# A POINTED icon aims with its tip, and the tip is its topmost opaque pixel - so the
# hotspot is measured off the art, not guessed at. Everything else points from its middle.
POINTED = {"bullet", "knife", "bayonet", "kbar"}

# Alpha at or below this is background. The sheet's edges are feathered, so a hard 0 test
# would leave a halo of near-transparent pixels in the crop.
ALPHA_FLOOR = 8


def _components(mask):
    """Every connected blob of opaque pixels, 8-connected. The sheet is a GRID by eye but
    not by arithmetic - 376/3 is not an integer - so slicing on a grid clipped the tall
    icons and let a sliver of the one below into the crop. The art finds itself instead."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    n = 0
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or lab[y, x]:
                continue
            n += 1
            q = deque([(y, x)])
            lab[y, x] = n
            y0 = y1 = y
            x0 = x1 = x
            area = 0
            while q:
                cy, cx = q.popleft()
                area += 1
                y0, y1 = min(y0, cy), max(y1, cy)
                x0, x1 = min(x0, cx), max(x1, cx)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((ny, nx))
            if area >= MIN_AREA:
                out.append({"area": area, "box": (x0, y0, x1 + 1, y1 + 1)})
    return out


def _reading_order(comps, sheet_h):
    """Left to right, top to bottom - by the blob's own centre, not by a grid line."""
    band = sheet_h / ROWS
    def key(c):
        x0, y0, x1, y1 = c["box"]
        cy = (y0 + y1) * 0.5
        cx = (x0 + x1) * 0.5
        return (int(cy // band), cx)
    return sorted(comps, key=key)


def _tip_xy(img):
    """Topmost opaque pixel, and the horizontal centre of that row's opaque run."""
    a = img.getchannel("A")
    w, h = img.size
    px = a.load()
    for y in range(h):
        run = [x for x in range(w) if px[x, y] > ALPHA_FLOOR]
        if run:
            return (sum(run) // len(run), y)
    return (w // 2, 0)


def main():
    out_dir = os.path.abspath(OUT)
    os.makedirs(out_dir, exist_ok=True)
    sheet = Image.open(SRC).convert("RGBA")

    # HAND-PLACED HOTSPOTS SURVIVE. The slicer's automatic tip is a starting point; once a
    # human has put the point on the blade in the editor, regenerating the art must not
    # silently throw that away. A hotspot is only reset when its CROP moved, because a
    # normalised point means something different against a different box.
    prev = {}
    jpath = os.path.join(out_dir, "cursors.json")
    if os.path.exists(jpath):
        with open(jpath) as f:
            prev = json.load(f)

    mask = np.array(sheet.getchannel("A")) > ALPHA_FLOOR
    comps = _components(mask)
    if len(comps) != len(NAMES):
        print("EXPECTED %d icons, found %d - not slicing. Check the sheet." % (
            len(NAMES), len(comps)))
        return
    comps = _reading_order(comps, sheet.height)

    meta = {}
    kept = 0
    for name, comp in zip(NAMES, comps):
        art = sheet.crop(comp["box"])
        box = list(comp["box"])
        for size in SIZES:
            scale = min(size / art.width, size / art.height)
            w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
            small = art.resize((w, h), Image.LANCZOS)
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            ox, oy = (size - w) // 2, (size - h) // 2
            canvas.paste(small, (ox, oy))
            canvas.save(os.path.join(out_dir, "%s_%d.png" % (name, size)))
            if size != SIZES[0]:
                continue
            old_entry = prev.get(name, {})
            if old_entry.get("box") == box and "hotspot" in old_entry:
                hot_n = old_entry["hotspot"]
                kept += 1
                note = "kept"
            else:
                if name in POINTED:
                    tx, ty = _tip_xy(small)
                    hot = (ox + tx, oy + ty)
                else:
                    hot = (size // 2, size // 2)
                hot_n = [hot[0] / size, hot[1] / size]
                note = "AUTO (crop changed)" if name in prev else "auto"
            meta[name] = {"hotspot": hot_n, "pointed": name in POINTED, "box": box}
        print("  %-9s art %3dx%-3d  hotspot %.3f,%.3f  %s" % (
            name, art.width, art.height, meta[name]["hotspot"][0],
            meta[name]["hotspot"][1], note))

    with open(jpath, "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    print("wrote %d cursors x %d sizes; %d hand-placed hotspot(s) preserved" % (
        len(meta), len(SIZES), kept))


if __name__ == "__main__":
    main()
