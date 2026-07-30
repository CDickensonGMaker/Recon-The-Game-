"""Build the field dressing wrapper texture -> assets/player/arms/field_dressing_01.png

    python tools/make_field_dressing_texture.py

Sources Caleb's reference photo of a real FSN 6510-201-7455 dressing (Sherborne Division /
Lily White Sales). The photo is one packet in the corner of a sheet of paper, so this finds
the packet, crops it, and lays it into the exact UV islands the unwrap in fp_arms_rifle.blend
produced. Change an island there and you must change RECTS here.
"""
import os
from PIL import Image, ImageFilter

SIZE = 512
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\caleb\Desktop\recon game image ideas\bandage.png"
OUT = os.path.join(ROOT, "assets", "player", "arms", "field_dressing_01.png")

# UV islands in pixels, y from the top, straight off the Blender unwrap.
FRONT = (64, 10, 448, 277)
BACK = (17, 297, 311, 502)
SIDES = [(327, 302, 501, 348), (327, 394, 501, 440)]
CAPS = [(256, 250, 312, 274), (322, 250, 378, 274)]

src = Image.open(SRC).convert("RGB")
W, H = src.size

# Find the packet: the paper is a flat tan, the packet is not. Sample the bottom-right
# corner for the paper colour, then take the bbox of everything far enough from it.
px = src.load()
sx, sy = int(W * 0.75), int(H * 0.75)
paper = px[sx, sy]
mask = Image.new("L", (W, H), 0)
mp = mask.load()
for y in range(0, H, 2):
    for x in range(0, W, 2):
        r, g, b = px[x, y]
        if abs(r - paper[0]) + abs(g - paper[1]) + abs(b - paper[2]) > 52:
            mp[x, y] = 255
mask = mask.filter(ImageFilter.MaxFilter(5))
bbox = mask.getbbox()
if bbox is None:
    raise SystemExit("could not find the packet in the reference photo")
x0, y0, x1, y1 = bbox
pad = 4
crop = src.crop((max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)))
print("photo %dx%d, paper %s, packet bbox %s -> crop %dx%d" % (W, H, paper, bbox, crop.width, crop.height))

# average foil tone, for the faces the photo does not show
small = crop.resize((16, 16))
sp = small.load()
n = 16 * 16
foil = tuple(sum(sp[i % 16, i // 16][c] for i in range(n)) // n for c in range(3))
print("foil tone", foil)

img = Image.new("RGB", (SIZE, SIZE), foil)


def place(rect, im, cover=False):
    rx0, ry0, rx1, ry1 = rect
    rw, rh = rx1 - rx0, ry1 - ry0
    s = max(rw / im.width, rh / im.height) if cover else min(rw / im.width, rh / im.height)
    r = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    if cover:
        cx, cy = (r.width - rw) // 2, (r.height - rh) // 2
        r = r.crop((cx, cy, cx + rw, cy + rh))
        img.paste(r, (rx0, ry0))
    else:
        img.paste(r, (rx0 + (rw - r.width) // 2, ry0 + (rh - r.height) // 2))


# front = the printed face, fitted whole so no lettering is lost
place(FRONT, crop, cover=False)
# back and the thin faces: the same foil, no print, taken from a clean strip of the packet
clean = crop.crop((0, int(crop.height * 0.72), crop.width, crop.height))
place(BACK, clean, cover=True)
for r in SIDES:
    place(r, clean, cover=True)
for r in CAPS:
    place(r, clean, cover=True)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print("WROTE %s  %dx%d  %.1f KB" % (OUT, SIZE, SIZE, os.path.getsize(OUT) / 1024.0))
