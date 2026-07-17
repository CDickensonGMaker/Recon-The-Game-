"""make_helmet_decals.py - graffiti atlas + playing card texture for the M1 helmets.

    python tools/make_helmet_decals.py

GRAFFITI ATLAS: a 4x4 grid of hand-marker slogans on a transparent background.
Same trick as the face atlas - one decal quad on the helmet dome, and a
`uv1_offset` in Godot picks which slogan it shows. 16 helmets from one 2-tri quad.

Slogans are real ones off Vietnam helmets (refs in assets/reference/helmet_refs/):
"HILL 937 / A SHAU VALLEY / THE SMELL OF DEATH" and "USMC / GOD COUNTRY" were
literally on the two covers Caleb pulled. "WAR IS HELL" is the Horst Faas photo.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = r"C:\Users\caleb\RECONgame\assets\us\textures"
os.makedirs(OUT, exist_ok=True)

# --- GRAFFITI ATLAS -------------------------------------------------------
COLS, ROWS = 4, 4
CW, CH = 256, 128          # 2x - the old 128x64 was mush at helmet scale
W, H = COLS * CW, ROWS * CH

SLOGANS = [
    "WAR IS HELL",   "BORN TO KILL",  "SHORT TIMER",  "USMC",
    "GOD\nCOUNTRY",  "HILL 937",      "FTA",          "13 MONTHS",
    "A SHAU",        "THE SMELL\nOF DEATH", "DEATH\nFROM ABOVE", "1 CAV",
    "SORRY\n'BOUT THAT", "PEACE",     "HOME",         "DEROS",
]

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# a fat black grease-pencil / marker. FULL alpha - at helmet scale, a translucent
# stroke just reads as dirt on the cover.
INK = (14, 12, 16, 255)

import random
random.seed(1968)


def font(sz):
    # A MEDIUM-weight block cap, not a heavy one. Arial Black + a fat stroke ate
    # its own counters and turned USMC into a blob. The stroke does the thickening;
    # the typeface just has to keep its shape. The hand comes from the JITTER
    # below, never from a "handwriting" font - those read as Comic Sans.
    for f in ("C:/Windows/Fonts/tahomabd.ttf", "C:/Windows/Fonts/arialbd.ttf",
              "C:/Windows/Fonts/verdanab.ttf", "C:/Windows/Fonts/ariblk.ttf"):
        try:
            return ImageFont.truetype(f, sz)
        except OSError:
            continue
    return ImageFont.load_default()


def stroke_for(sz):
    # thick enough to read as a grease pencil, thin enough that the holes in the
    # A, O, R survive. size//7 blobbed. size//16 holds.
    return max(2, sz // 16)


def hand_print(base, x, y, text, size, ink):
    """print each character on its own, with wobble. THIS is what sells it."""
    cur = x
    for ch in text:
        if ch == " ":
            cur += size * 0.32
            continue
        s = int(size * random.uniform(0.90, 1.10))       # no two letters the same
        f = font(s)
        stroke = stroke_for(s)
        bb = f.getbbox(ch)
        w = (bb[2] - bb[0]) if bb else s * 0.6
        h = (bb[3] - bb[1]) if bb else s

        pad = stroke * 3 + 8
        tile = Image.new("RGBA", (int(w + pad * 2), int(h + pad * 2)), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        td.text((pad - bb[0], pad - bb[1]), ch, font=f, fill=ink,
                stroke_width=stroke, stroke_fill=ink)
        tile = tile.rotate(random.uniform(-5.0, 5.0), resample=Image.BICUBIC,
                           expand=True)

        dy = random.uniform(-size * 0.07, size * 0.07)   # baseline wobble
        base.alpha_composite(tile, (int(cur - pad), int(y + dy - pad)))
        cur += w + stroke * 1.2 + size * random.uniform(0.02, 0.10)
    return cur - x


def measure(text, size):
    total = 0.0
    for ch in text:
        if ch == " ":
            total += size * 0.32
            continue
        f = font(size)
        bb = f.getbbox(ch)
        total += ((bb[2] - bb[0]) if bb else size * 0.6) + stroke_for(size) * 1.2 + size * 0.06
    return total


for i, text in enumerate(SLOGANS):
    cx, cy = (i % COLS) * CW, (i // COLS) * CH
    lines = text.split("\n")
    # start BIG and shrink to fit. a helmet decal is read at 3 m in a jungle -
    # timid text is invisible text.
    size = 76 if len(lines) == 1 else 50
    while size > 14:
        if (max(measure(ln, size) for ln in lines) <= CW - 18
                and len(lines) * (size + 10) <= CH - 8):
            break
        size -= 2

    total = len(lines) * (size + 10)
    y = cy + (CH - total) // 2
    for ln in lines:
        w = measure(ln, size)
        hand_print(img, cx + (CW - w) / 2, y, ln, size, INK)
        y += size + 10

img.save(os.path.join(OUT, "helmet_graffiti_atlas.png"))
print("wrote helmet_graffiti_atlas.png  %dx%d  (%d slogans, %dx%d grid)"
      % (W, H, len(SLOGANS), COLS, ROWS))
for r in range(ROWS):
    print("   " + " | ".join("%-16s" % SLOGANS[r*COLS + c].replace("\n", " ")
                             for c in range(COLS)))

# --- PLAYING CARD (Ace of Spades) ----------------------------------------
CW2, CH2 = 64, 96
card = Image.new("RGBA", (CW2, CH2), (0, 0, 0, 0))
c = ImageDraw.Draw(card)
c.rounded_rectangle([1, 1, CW2 - 2, CH2 - 2], radius=4,
                    fill=(232, 228, 216, 255), outline=(150, 145, 132, 255))
fA = font(16)
c.text((5, 3), "A", font=fA, fill=(20, 20, 20, 255))
# a fat spade - at 64px nobody is counting the curves
cxm, cym = CW2 // 2, CH2 // 2 + 4
c.polygon([(cxm, cym - 20), (cxm - 15, cym + 2), (cxm + 15, cym + 2)], fill=(20, 20, 20, 255))
c.ellipse([cxm - 15, cym - 8, cxm - 1, cym + 8], fill=(20, 20, 20, 255))
c.ellipse([cxm + 1, cym - 8, cxm + 15, cym + 8], fill=(20, 20, 20, 255))
c.rectangle([cxm - 2, cym + 2, cxm + 2, cym + 16], fill=(20, 20, 20, 255))
c.polygon([(cxm - 7, cym + 18), (cxm + 7, cym + 18), (cxm, cym + 12)], fill=(20, 20, 20, 255))
card.save(os.path.join(OUT, "helmet_card_ace.png"))
print("\nwrote helmet_card_ace.png  %dx%d  (Ace of Spades)" % (CW2, CH2))
