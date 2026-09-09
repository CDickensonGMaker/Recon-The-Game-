"""label_helmet_frames.py - labels for the two shipping-helmet frames.

    python tools/label_helmet_frames.py

Positions are DERIVED from the framing numbers the render wrote, and every string is
measured against the canvas before it is drawn.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = r"C:\Users\caleb\RECONgame\production\renders_conquest_of_worms"


def font(sz):
    for p in (r"C:\Windows\Fonts\seguisb.ttf", r"C:\Windows\Fonts\arialbd.ttf",
              r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def fitted(d, text, maxw, start):
    sz = start
    f = font(sz)
    while d.textlength(text, font=f) > maxw and sz > 10:
        sz -= 1
        f = font(sz)
    return f, sz


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


# ---------------------------------------------------------------- 1. the cast
IMG = os.path.join(OUT, "cow_LINEUP_shipping_helmets.png")
rows = open(os.path.join(OUT, "_helmet_lineup_frame.txt")).read().strip().splitlines()
cx, ortho, RX, RY = [float(v) for v in rows[0].split()]
figs = []
for r in rows[1:]:
    parts = r.split()
    figs.append((parts[0], float(parts[1]), float(parts[2]), float(parts[3]), parts[4]))

NAME = {"michael": "MICHAEL LEE CRAWFORD  (I1 p2)",
        "gus_arrival": "GUS - ARRIVAL  (I2 p4)",
        "gus_ears": "GUS - EARS  (I3 p9)",
        "sniper": "THE SKULL-FACED SNIPER  (I4 fya.23)"}
COL = {"michael": (150, 220, 255), "gus_arrival": (170, 255, 170),
       "gus_ears": (255, 150, 150), "sniper": (255, 190, 90)}

im = Image.open(IMG).convert("RGB")
W, H = im.size
ppm = W / ortho
TOP, BOT = 78, 128
out = Image.new("RGB", (W, H + TOP + BOT), (30, 30, 32))
out.paste(im, (0, TOP))
d = ImageDraw.Draw(out)
head = ("SHIPPING HELMETS - the stock `helmet_shell_worn` is HIDDEN (grunt_dresser.gd:270) and a "
        "prop from assets/us/props/helmets/ is hung on mixamorig:Head, placed off the stock's own "
        "rendered transform (grunt_dresser.gd:49-52). Loaded from the GLBs; the mottled cover is "
        "the runtime atlas helm_<id>.png, which grunt_dresser.gd:286-303 binds at load. T-POSE. "
        "Michael at armature scale 1.0. The sniper takes no US helmet.")
fh, _ = fitted(d, "x", W - 40, 21)
for i, ln in enumerate(wrap(d, head, fh, W - 40)[:3]):
    d.text((20, 8 + i * 24), ln, font=fh, fill=(255, 226, 120))

colw = W / float(len(figs)) - 24
bs = 23
while bs > 10:
    fb = font(bs)
    lines = [["%s   helmet: %s" % (NAME[t], hid if hid != "-" else "none - bareheaded"),
              "standing %.4f m   bare body %.4f m" % (h, bare)] for t, wx, h, bare, hid in figs]
    if max(d.textlength(l, font=fb) for g in lines for l in g) <= colw:
        break
    bs -= 1
fb = font(bs)
for t, wx, h, bare, hid in figs:
    x = int(W / 2 + (wx - cx) * ppm)
    col = COL[t]
    d.line([(x, TOP + H - 16), (x, TOP + H + 8)], fill=col, width=3)
    for i, ln in enumerate([NAME[t],
                            "helmet: %s" % (hid if hid != "-" else "none - bareheaded"),
                            "standing %.4f m    bare body %.4f m" % (h, bare)]):
        w = d.textlength(ln, font=fb)
        d.text((min(max(6.0, x - w / 2), W - w - 6.0), TOP + H + 14 + i * (bs + 5)),
               ln, font=fb, fill=col)
out.save(IMG)
print("labelled %s -> %dx%d (font %d)" % (IMG, out.size[0], out.size[1], bs))

# ---------------------------------------------------------------- 2. the library
IMG2 = os.path.join(OUT, "cow_HELMET_LIBRARY.png")
rows = open(os.path.join(OUT, "_helmet_library_frame.txt")).read().strip().splitlines()
cx, cz, ortho, RX, RY = [float(v) for v in rows[0].split()]
hel = []
for r in rows[1:]:
    hid, x, z, digest = r.split()
    hel.append((hid, float(x), float(z), digest))

im = Image.open(IMG2).convert("RGB")
W, H = im.size
ppm = W / ortho
TOP, BOT = 132, 40
out = Image.new("RGB", (W, H + TOP + BOT), (30, 30, 32))
out.paste(im, (0, TOP))
d = ImageDraw.Draw(out)

dupes = {}
for hid, x, z, dg in hel:
    dupes.setdefault(dg, []).append(hid)
shared = [v for v in dupes.values() if len(v) > 1]
facts = [
    "THE 15 SHIPPING HELMETS - rendered from assets/us/props/helmets/*.glb ONLY. Flat, even, frontal "
    "light, identical for all fifteen (one render, one lamp). Nothing here comes from a .blend.",
    "The pattern is NOT in the GLB. Every cover material in the GLB is a FLAT factor with no "
    "baseColorTexture - MitchellCamo [0.127,0.167,0.07], ERDLCamo [0.055,0.085,0.04]. What you see is "
    "the 256x256 runtime atlas assets/us/textures/helmets/helm_<id>.png, which grunt_dresser.gd:286-303 "
    "binds at load onto every UV-bearing surface. In a raw GLB viewer these are flat; in game they are not.",
    "MEASURED (md5): 15 named helmets share only SIX distinct cover images.  " +
    "   ".join("=".join(v) for v in shared),
    "* m1_erdl_short (marked red below) is named for a pattern it does not own - its cover is "
    "byte-identical to m1_ace and m1_rounds. The only genuinely per-variant art in the whole library "
    "is the three decals: playing card, cigarette pack, bug-juice bottle.",
]
ff, _ = fitted(d, "x", W - 40, 18)
y = 8
for para in facts:
    for ln in wrap(d, para, ff, W - 40):
        d.text((20, y), ln, font=ff, fill=(255, 226, 120))
        y += 21

fs = 19
fb = font(fs)
while max(d.textlength(h[0] + " *", font=fb) for h in hel) > (ppm * 0.34) - 6 and fs > 10:
    fs -= 1
    fb = font(fs)
for hid, x, z, dg in hel:
    px = int(W / 2 + (x - cx) * ppm)
    py = int(TOP + H / 2 - (z - cz) * ppm) + int(0.115 * ppm)
    txt = hid + (" *" if hid == "m1_erdl_short" else "")
    col = (255, 120, 120) if hid == "m1_erdl_short" else (235, 235, 235)
    ft = font(fs)
    w = d.textlength(txt, font=ft)
    d.text((min(max(4.0, px - w / 2), W - w - 4.0), min(py, TOP + H - fs - 2)),
           txt, font=ft, fill=col)
out.save(IMG2)
print("labelled %s -> %dx%d (font %d)" % (IMG2, out.size[0], out.size[1], fs))
