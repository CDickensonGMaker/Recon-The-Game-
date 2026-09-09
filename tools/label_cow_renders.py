"""label_cow_renders.py - burn text labels into the comparison frames.

    python tools/label_cow_renders.py

Blender's compositor text is more trouble than it is worth headless, so the labels go on
with PIL afterwards. Pixel positions are DERIVED from the same camera numbers the render
used (ortho_scale over the larger image axis, camera centred on the measured bbox), not
eyeballed - see PX() below.
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


def label(src, dst, centre_x, ortho, entries, title, sz=26):
    im = Image.open(src).convert("RGB")
    W, H = im.size
    px_per_m = W / float(ortho) if W >= H else H / float(ortho)

    def PX(world_x):
        return int(W / 2 + (world_x - centre_x) * px_per_m)

    pad = 26 + (sz + 6) * max(len(e[1]) for e in entries) + 14
    out = Image.new("RGB", (W, H + pad), (34, 34, 36))
    out.paste(im, (0, 0))
    d = ImageDraw.Draw(out)
    ft, fh = font(sz), font(int(sz * 1.15))
    words, line, lines = title.split(" "), "", []
    for w in words:
        t = (line + " " + w).strip()
        if d.textlength(t, font=fh) > W - 44 and line:
            lines.append(line); line = w
        else:
            line = t
    lines.append(line)
    for i, ln in enumerate(lines):
        d.text((22, 12 + i * int(sz * 1.35)), ln, font=fh, fill=(255, 226, 120))
    for wx, lines, col in entries:
        x = PX(wx)
        d.line([(x, H - 26), (x, H + 12)], fill=col, width=3)
        for i, ln in enumerate(lines):
            w = d.textlength(ln, font=ft)
            tx = min(max(6.0, x - w / 2), W - w - 6.0)   # keep it inside the frame
            d.text((tx, H + 18 + i * (sz + 6)), ln, font=ft, fill=col)
    out.save(dst)
    print("wrote %s  (%dx%d, %.1f px/m)" % (dst, out.size[0], out.size[1], px_per_m))


# --- the stature question -------------------------------------------------------
# Camera numbers straight off the render log: bbox x[-0.806, 3.106] -> centre 1.150,
# ortho_scale 4.193, 1500x1250. Figures stand at world x = 0.00 / 1.15 / 2.30.
label(
    os.path.join(OUT, "cow_michael_STATURE_QUESTION_tpose.png"),
    os.path.join(OUT, "cow_michael_STATURE_QUESTION_labelled.png"),
    centre_x=1.150, ortho=4.193,
    title=("OPEN QUESTION for Caleb - how tall is Michael?   "
           "Draft card (Issue 1 p2): Height 6'2\", Weight 155 lbs.   "
           "All heights MEASURED off evaluated mesh bounds, bare body, no helmet."),
    entries=[
        (0.00, ["MICHAEL - armature scale 1.0", "1.8000 m  (5 ft 10.9 in)",
                "= the shared project body"], (150, 220, 255)),
        (1.15, ["MICHAEL - armature scale 1.0442", "1.8796 m  (6 ft 2 in) = the draft card",
                "+8.0 cm, +4.4%"], (255, 190, 90)),
        (2.30, ["STOCK US GRUNT (gus_arrival) - 1.0", "1.8000 m  (5 ft 10.9 in)",
                "the squad datum"], (170, 255, 170)),
    ])

# --- Gus, two states ------------------------------------------------------------
# bbox x[-1.235, 1.756] -> centre 0.2605, ortho_scale 2.250 (scale_override), 1600x1250.
for f, ortho in (("cow_gus_TWO_STATES_tpose.png", 2.250),
                 ("cow_gus_TWO_STATES_34_tpose.png", 2.450)):
    src = os.path.join(OUT, f)
    if not os.path.exists(src):
        continue
    label(src, os.path.join(OUT, f.replace(".png", "_labelled.png")),
          centre_x=0.2605, ortho=ortho,
          title=("EUGENE \"GUS\" - one body, two states.  Bible section 8: \"a squadmate whose "
                 "behaviour degrades over a campaign, visibly, on his model - a necklace that "
                 "appears, a bag he will not open.\""),
          entries=[
              (0.00, ["gus_arrival", "Issue 2 p4 - the new replacement",
                       "\"unassigned and floating\": no bandolier,", "one canteen. Nothing on him."],
               (170, 255, 170)),
              (0.95, ["gus_ears", "Issue 3 p9 - \"the ears have become a necklace",
                      "worn openly in camp\" + the bag he hides", "things in (I3 p10, I3 p19)"],
               (255, 150, 150)),
          ], sz=24)
