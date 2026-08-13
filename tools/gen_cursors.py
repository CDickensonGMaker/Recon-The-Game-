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

from PIL import Image

SRC = r"C:/Users/caleb/Desktop/Projects/RECON Vietnam/recon game image ideas/menu assets/cursors.png"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "cursors")
SIZES = (64, 32)
COLS, ROWS = 4, 3

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


def _tight_box(img):
    """Bounding box of everything meaningfully opaque."""
    a = img.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0)
    return a.getbbox()


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
    sw, sh = sheet.size
    cw, ch = sw / COLS, sh / ROWS
    meta = {}

    for i, name in enumerate(NAMES):
        col, row = i % COLS, i // COLS
        cell = sheet.crop((int(col * cw), int(row * ch),
                           int((col + 1) * cw), int((row + 1) * ch)))
        box = _tight_box(cell)
        if box is None:
            print("  %-9s EMPTY CELL - skipped" % name)
            continue
        art = cell.crop(box)

        for size in SIZES:
            # Fit inside the square, never crop: a cursor that loses its own tip to a
            # square canvas is a cursor that points at nothing.
            scale = min(size / art.width, size / art.height)
            w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
            small = art.resize((w, h), Image.LANCZOS)
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            ox, oy = (size - w) // 2, (size - h) // 2
            canvas.paste(small, (ox, oy))
            canvas.save(os.path.join(out_dir, "%s_%d.png" % (name, size)))

            if size == SIZES[0]:
                if name in POINTED:
                    tx, ty = _tip_xy(small)
                    hot = [ox + tx, oy + ty]
                else:
                    hot = [size // 2, size // 2]
                # Stored NORMALISED so one number serves every output size.
                meta[name] = {"hotspot": [hot[0] / size, hot[1] / size],
                              "pointed": name in POINTED}
        print("  %-9s art %3dx%-3d  hotspot %.2f,%.2f" % (
            name, art.width, art.height, *meta[name]["hotspot"]))

    with open(os.path.join(out_dir, "cursors.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    print("wrote %d cursors x %d sizes to %s" % (len(meta), len(SIZES), out_dir))


if __name__ == "__main__":
    main()
