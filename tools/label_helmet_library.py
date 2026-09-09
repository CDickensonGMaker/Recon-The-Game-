"""label_helmet_library.py - labels for the two-band helmet library frame.

    python tools/label_helmet_library.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = r"C:\Users\caleb\RECONgame\production\renders_conquest_of_worms"
IMG = os.path.join(OUT, "cow_HELMET_LIBRARY.png")


def font(sz):
    for p in (r"C:\Windows\Fonts\seguisb.ttf", r"C:\Windows\Fonts\arialbd.ttf",
              r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def wrap(d, text, f, maxw):
    out, line = [], ""
    for w in text.split(" "):
        t = (line + " " + w).strip()
        if d.textlength(t, font=f) > maxw and line:
            out.append(line)
            line = w
        else:
            line = t
    out.append(line)
    return out


rows = open(os.path.join(OUT, "_helmet_library_frame.txt")).read().strip().splitlines()
cx, cz, ortho, RX, RY, BAND = [float(v) for v in rows[0].split()]
hel = []
for r in rows[1:]:
    hid, x, z, dg = r.split()
    hel.append((hid, float(x), float(z), dg))

dupes = {}
for hid, x, z, dg in hel:
    dupes.setdefault(dg, []).append(hid)
shared = sorted((v for v in dupes.values() if len(v) > 1), key=len, reverse=True)

im = Image.open(IMG).convert("RGB")
W, H = im.size
ppm = W / ortho
TOP, BOT = 152, 46
out = Image.new("RGB", (W, H + TOP + BOT), (28, 28, 30))
out.paste(im, (0, TOP))
d = ImageDraw.Draw(out)

facts = [
    "ALL 15 SHIPPING HELMETS, loaded from assets/us/props/helmets/*.glb ONLY - nothing from "
    "helmet_variants.blend is opened, linked or appended. Flat, even, frontal light, one lamp, one "
    "camera, identical for all thirty.",
    "TOP BAND = THE GLB EXACTLY AS IT SHIPS. Audited on load: m1_plain.glb imports with ZERO image "
    "datablocks and MitchellCamo = FLAT(0.127, 0.1665, 0.07); ERDLCamo FLAT(0.055, 0.085, 0.04); "
    "MitchellReversed FLAT(0.220, 0.1705, 0.0955); CoverMuddy FLAT(0.1025, 0.099, 0.063); "
    "HelmSteelPot FLAT(0.09, 0.11, 0.07). The ONLY images in any of the 15 files are the three "
    "decals - playing card, cigarette pack, bug-juice bottle. This is what a raw glTF viewer shows.",
    "BOTTOM BAND = WHAT THE PLAYER SEES. grunt_dresser.gd:286-303 binds the 256x256 runtime atlas "
    "assets/us/textures/helmets/helm_<id>.png onto every UV-bearing surface at load. The pattern is "
    "real in game and absent from the file.",
    "MEASURED (md5 of the 15 cover atlases): 15 named helmets share only SIX distinct cover images - "
    + "   ".join("=".join(v) for v in shared),
    "* m1_erdl_short is named for a pattern it does not own: its cover file is byte-identical to "
    "m1_ace's and m1_rounds'.",
]
ff = font(18)
y = 8
for para in facts:
    for ln in wrap(d, para, ff, W - 40):
        d.text((20, y), ln, font=ff, fill=(255, 226, 120))
        y += 21

fb = font(20)
for label, zc, col in (("THE GLB AS IT SHIPS  (flat)", 0.0, (170, 210, 255)),
                       ("+ RUNTIME COVER ATLAS  (what the player sees)", -BAND, (170, 255, 190))):
    py = int(TOP + H / 2 - ((zc + 0.17) - cz) * ppm)
    d.text((16, max(TOP + 4, py)), label, font=fb, fill=col)

fs = 19
ft = font(fs)
while max(d.textlength(h[0] + " *", font=ft) for h in hel) > (ppm * 0.34) - 8 and fs > 10:
    fs -= 1
    ft = font(fs)
for hid, x, z, dg in hel:
    px = int(W / 2 + (x - cx) * ppm)
    py = int(TOP + H / 2 - (z - cz) * ppm) + int(0.115 * ppm)
    txt = hid + (" *" if hid == "m1_erdl_short" else "")
    col = (255, 130, 130) if hid == "m1_erdl_short" else (238, 238, 238)
    w = d.textlength(txt, font=ft)
    d.text((min(max(4.0, px - w / 2), W - w - 4.0), min(py, TOP + H - fs - 4)),
           txt, font=ft, fill=col)

out.save(IMG)
print("labelled %s -> %dx%d (name font %d, %d shared-cover groups)"
      % (IMG, out.size[0], out.size[1], fs, len(shared)))
