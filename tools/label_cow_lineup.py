"""label_cow_lineup.py - burn the labels into cow_LINEUP_all_four.png, in place.

    python tools/label_cow_lineup.py

Reads the framing numbers the render wrote (_lineup_frame.txt) so pixel positions are
DERIVED from the camera, never eyeballed. Every string is measured against the canvas and
shrunk until it fits - the previous labelled frame ran off both edges.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = r"C:\Users\caleb\RECONgame\production\renders_conquest_of_worms"
IMG = os.path.join(OUT, "cow_LINEUP_all_four.png")

CAPTION = {
    "michael": ("MICHAEL LEE CRAWFORD", "Issue 1 p2 - draft card", "M79 \"Thumper\" + ruck + journal",
                (150, 220, 255)),
    "gus_arrival": ("GUS (EUGENE) - ARRIVAL", "Issue 2 p4", "new replacement, stripped kit",
                    (170, 255, 170)),
    "gus_ears": ("GUS (EUGENE) - EARS", "Issue 3 p9", "ear necklace + the bag",
                 (255, 150, 150)),
    "sniper": ("THE SKULL-FACED SNIPER", "Issue 4 fya.23", "VC/NVA faction",
               (255, 190, 90)),
}
HEAD = ("ALL FOUR AT TRUE RELATIVE SCALE - one camera, one light rig, one ground line.  "
        "T-POSE (the studio/export stance).  Michael is at armature scale 1.0.  "
        "Heights are measured off the SHIPPED GLBs.")


def font(sz):
    for p in (r"C:\Windows\Fonts\seguisb.ttf", r"C:\Windows\Fonts\arialbd.ttf",
              r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


rows = open(os.path.join(OUT, "_lineup_frame.txt")).read().strip().splitlines()
cx, ortho, RX, RY = [float(v) for v in rows[0].split()]
RX, RY = int(RX), int(RY)
figs = []
for r in rows[1:]:
    t, wx, h, bare = r.split()
    figs.append((t, float(wx), float(h), float(bare)))

im = Image.open(IMG).convert("RGB")
W, H = im.size
px_per_m = W / ortho if W >= H else H / ortho

TOP, BOT = 46, 132
out = Image.new("RGB", (W, H + TOP + BOT), (30, 30, 32))
out.paste(im, (0, TOP))
d = ImageDraw.Draw(out)

sz = 25
f = font(sz)
while d.textlength(HEAD, font=f) > W - 40 and sz > 11:      # measure, then shrink
    sz -= 1
    f = font(sz)
d.text((20, (TOP - sz) // 2), HEAD, font=f, fill=(255, 226, 120))

def caption_lines(tag, h, bare):
    name, src, note, col = CAPTION[tag]
    return [name, "%s - %s" % (src, note),
            "head/helmet %.4f m   bare body %.4f m" % (h, bare)], col


# Measure the strings ACTUALLY DRAWN, not a different list built for the check. Measuring
# five short lines and then drawing three long ones is why the last pass overlapped.
bs = 23
COLW = (W / float(len(figs))) - 24
while bs > 10:
    fb = font(bs)
    widest = max(d.textlength(l, font=fb)
                 for t, wx, h, bare in figs for l in caption_lines(t, h, bare)[0])
    if widest <= COLW:
        break
    bs -= 1
fb = font(bs)
print("   column %.0f px, widest caption %.0f px at font %d" % (COLW, widest, bs))
for tag, wx, h, bare in figs:
    x = int(W / 2 + (wx - cx) * px_per_m)
    lines, col = caption_lines(tag, h, bare)
    d.line([(x, TOP + H - 18), (x, TOP + H + 8)], fill=col, width=3)
    for i, ln in enumerate(lines):
        w = d.textlength(ln, font=fb)
        tx = min(max(6.0, x - w / 2), W - w - 6.0)
        d.text((tx, TOP + H + 16 + i * (bs + 6)), ln, font=fb, fill=col)

out.save(IMG)
print("labelled %s -> %dx%d (%.1f px/m, body font %d, header font %d)"
      % (IMG, out.size[0], out.size[1], px_per_m, bs, sz))
