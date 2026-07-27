"""Write the firebase material set: seven 256x256 indexed PNGs, ~60 KB each.

    python tools/gen_firebase_textures.py

Replaces a material set that carried `fsb_main_FRAInfantry.png` - a Spring 1944 FRENCH
faction atlas - and in which 65 of 97 materials had no baseColorTexture at all, which is
why the old base read gray and untextured.

Procedural, not photographic, per the art-storage rule: at PSX texel density with
interpolation='Closest' a photo map is mostly wasted bytes, and one small shared map beats
a per-model atlas.

NOT generated here, reused instead:
  wire - assets/us/props/emplacements/barbwire_card.glb carries the canonical
         barbwire impostor at 2.88 m tiling. It is THE only wire (war room 2026-07-17).
         gen_firebase.py imports that GLB; nothing here draws barbed wire.
"""
from PIL import Image, ImageDraw
import random, os, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "world",
                   "building models", "structures", "firebase", "tex")
N = 256


def clamp(v):
    return max(0, min(255, int(v)))


def tint(base, f):
    return tuple(clamp(c * f) for c in base)


def noise(im, amt, rng):
    px = im.load()
    for y in range(N):
        for x in range(N):
            n = rng.uniform(-amt, amt)
            r, g, b = px[x, y]
            px[x, y] = (clamp(r + n), clamp(g + n), clamp(b + n))


def sandbag(rng):
    """The dominant firebase material: courses of filled bags, staggered like brick."""
    base = (138, 126, 96)
    im = Image.new("RGB", (N, N), tint(base, 0.7))
    d = ImageDraw.Draw(im)
    course = 30
    for cy in range(-course, N + course, course):
        off = (abs(cy) // course % 2) * 26
        for bx in range(-56, N + 56, 52):
            x0 = bx + off
            f = rng.uniform(0.84, 1.16)
            # a bag is a rounded pillow, not a brick - the silhouette is the read
            d.rounded_rectangle([x0, cy, x0 + 48, cy + course - 3], radius=11,
                                fill=tint(base, f))
            d.arc([x0 + 3, cy + 2, x0 + 45, cy + course - 6], 190, 350,
                  fill=tint(base, f * 1.22), width=2)
            d.line([(x0 + 24, cy + 3), (x0 + 24, cy + course - 7)],
                   fill=tint(base, f * 0.82))       # the seam up the middle
    noise(im, 9, rng)
    return im


def earth(rng):
    """Berm and parapet spoil - freshly turned laterite, still damp in the shade."""
    base = (122, 88, 62)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for _ in range(240):                              # clods
        cx, cy = rng.randrange(N), rng.randrange(N)
        r = rng.randint(4, 20)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tint(base, rng.uniform(0.82, 1.18)))
    for _ in range(90):                               # stones and root ends
        x, y = rng.randrange(N), rng.randrange(N)
        r = rng.randint(1, 4)
        d.ellipse([x, y, x + r, y + r], fill=tint(base, rng.uniform(0.6, 0.78)))
    noise(im, 12, rng)
    return im


def timber(rng):
    """Rough-sawn beams and revetment stakes - engineer lumber, not furniture."""
    base = (108, 84, 56)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for _ in range(280):
        x = rng.randrange(N)
        d.line([(x, 0), (x + rng.randint(-4, 4), N)], fill=tint(base, rng.uniform(0.74, 1.24)))
    for _ in range(11):                               # saw kerf across the grain
        y = rng.randrange(N)
        d.line([(0, y), (N, y + rng.randint(-3, 3))], fill=tint(base, 0.68))
    noise(im, 8, rng)
    return im


def psp(rng):
    """Pierced steel planking - the perforated mat the pads and some floors are laid on.

    The hole grid IS the identity; get the spacing wrong and it reads as plate steel.
    """
    base = (96, 100, 92)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for px_ in range(0, N, 64):                       # plank seams
        d.rectangle([px_, 0, px_ + 3, N], fill=tint(base, 0.72))
    for gy in range(10, N, 22):
        for gx in range(10, N, 22):
            j = rng.randint(-1, 1)
            d.ellipse([gx + j, gy + j, gx + 11 + j, gy + 11 + j], fill=tint(base, 0.55))
            d.arc([gx + j, gy + j, gx + 11 + j, gy + 11 + j], 200, 340,
                  fill=tint(base, 1.25), width=1)
    for _ in range(70):                               # rust bloom at the edges
        x, y = rng.randrange(N), rng.randrange(N)
        r = rng.randint(2, 7)
        d.ellipse([x, y, x + r, y + r], fill=(clamp(120 + rng.randint(-20, 20)),
                                              clamp(74 + rng.randint(-14, 14)), 46))
    noise(im, 7, rng)
    return im


def canvas(rng):
    """Tent canvas - olive drab duck, sun-bleached along the ridge, woven not smooth."""
    base = (104, 106, 78)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for y in range(0, N, 3):                          # weave
        d.line([(0, y), (N, y)], fill=tint(base, rng.uniform(0.93, 1.07)))
    for x in range(0, N, 3):
        d.line([(x, 0), (x, N)], fill=tint(base, rng.uniform(0.95, 1.05)))
    for _ in range(26):                               # stains and patches
        cx, cy = rng.randrange(N), rng.randrange(N)
        r = rng.randint(8, 26)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tint(base, rng.uniform(0.86, 1.12)))
    for _ in range(5):                                # seams
        y = rng.randrange(N)
        d.line([(0, y), (N, y)], fill=tint(base, 0.76), width=2)
    noise(im, 6, rng)
    return im


def corrugated(rng):
    """Corrugated tin - bunker overhead, hootch roofs. Vertical flutes, rusting."""
    base = (112, 112, 106)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    pitch = 16
    for x in range(0, N + pitch, pitch):
        for i in range(pitch):
            t = abs((i / float(pitch)) - 0.5) * 2.0
            d.line([(x + i, 0), (x + i, N)], fill=tint(base, 1.16 - 0.5 * t * t))
    for _ in range(90):                               # rust runs
        x, y = rng.randrange(N), rng.randrange(N)
        h = rng.randint(10, 46)
        d.line([(x, y), (x + rng.randint(-1, 1), y + h)],
               fill=(clamp(126 + rng.randint(-18, 18)), clamp(72 + rng.randint(-12, 12)), 44))
    noise(im, 8, rng)
    return im


def crate(rng):
    """Ammo crate / dunnage - olive drab boards with stencil marks."""
    base = (86, 92, 62)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for by in range(0, N, 26):                        # boards
        d.rectangle([0, by, N, by + 23], fill=tint(base, rng.uniform(0.88, 1.12)))
        d.line([(0, by + 24), (N, by + 24)], fill=tint(base, 0.66))
    for _ in range(9):                                # stencil blocks, unreadable on purpose
        x, y = rng.randrange(N - 60), rng.randrange(N - 14)
        for k in range(rng.randint(3, 6)):
            d.rectangle([x + k * 10, y, x + k * 10 + 6, y + 11], fill=tint(base, 1.5))
    noise(im, 7, rng)
    return im


MAPS = {"fb_sandbag": sandbag, "fb_earth": earth, "fb_timber": timber, "fb_psp": psp,
        "fb_canvas": canvas, "fb_corrugated": corrugated, "fb_crate": crate}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for i, (name, fn) in enumerate(sorted(MAPS.items())):
        im = fn(random.Random(9100 + i * 47))
        q = im.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
        p = os.path.join(OUT, name + ".png")
        q.save(p, optimize=True)
        kb = os.path.getsize(p) / 1024.0
        total += kb
        print(f"{name:16s} 256x256 indexed  {kb:6.1f} KB")
    print(f"\n{len(MAPS)} maps, {total:.0f} KB total -> {os.path.normpath(OUT)}")


main()
