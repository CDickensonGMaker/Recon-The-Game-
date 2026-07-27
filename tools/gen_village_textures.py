"""Write the village material set: seven 256x256 indexed PNGs, ~60 KB each.

    python tools/gen_village_textures.py

Procedural rather than photographic on purpose. At PSX texel density with
interpolation='Closest' a photo map is mostly wasted bytes, and the art-storage rule
says a shared small map beats a per-model photo atlas - the nine RTS village models
this set replaces carried 1024x1024 maps at ~900 KB, the same one duplicated four times.

Every map is authored to tile seamlessly under gen_village.py's box projection.
"""
from PIL import Image, ImageDraw
import random, os, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "world",
                   "building models", "structures", "village", "tex")
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


def thatch(rng):
    """Layered straw courses - horizontal bands of downward-hanging stalks."""
    base = (150, 124, 74)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    course = 38
    for cy in range(-course, N + course, course):
        d.rectangle([0, cy, N, cy + 4], fill=tint(base, 0.62))   # shadow under the course
        for _ in range(420):
            x = rng.randrange(0, N)
            y = cy + rng.randint(2, course)
            ln = rng.randint(8, course - 2)
            f = rng.uniform(0.72, 1.22)
            d.line([(x, y), (x + rng.randint(-2, 2), y + ln)], fill=tint(base, f))
    noise(im, 9, rng)
    return im


def bamboo(rng):
    """Vertical culms with node bands - the hedge and the pole frames."""
    base = (134, 142, 84)
    im = Image.new("RGB", (N, N), tint(base, 0.55))
    d = ImageDraw.Draw(im)
    x = 0
    while x < N:
        w = rng.randint(20, 30)
        f0 = rng.uniform(0.82, 1.12)
        for i in range(w):                                  # round the culm with a gradient
            t = abs((i / float(w)) - 0.5) * 2.0
            d.line([(x + i, 0), (x + i, N)], fill=tint(base, f0 * (1.10 - 0.45 * t * t)))
        node = rng.randrange(0, 64)
        while node < N:                                     # node collars
            d.rectangle([x, node, x + w - 1, node + 3], fill=tint(base, f0 * 0.68))
            d.rectangle([x, node + 3, x + w - 1, node + 5], fill=tint(base, f0 * 1.18))
            node += rng.randint(58, 76)
        d.line([(x + w - 1, 0), (x + w - 1, N)], fill=tint(base, 0.42))
        x += w
    noise(im, 7, rng)
    return im


def wattle(rng):
    """Mud-over-woven-bamboo wall - mottled earth with the weave showing through."""
    base = (146, 122, 96)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for _ in range(150):                                    # daub patches
        cx, cy = rng.randrange(N), rng.randrange(N)
        r = rng.randint(10, 34)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tint(base, rng.uniform(0.86, 1.14)))
    for y in range(0, N, 11):                               # weave rows, faint
        d.line([(0, y), (N, y)], fill=tint(base, 0.90))
    for _ in range(26):                                     # exposed lath where the daub broke
        x, y = rng.randrange(N), rng.randrange(N)
        d.line([(x, y), (x + rng.randint(12, 40), y + rng.randint(-3, 3))],
               fill=tint((120, 100, 62), rng.uniform(0.7, 1.0)))
    noise(im, 11, rng)
    return im


def timber(rng):
    """Hewn post and beam - vertical grain, warm and dark."""
    base = (104, 78, 50)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for _ in range(260):
        x = rng.randrange(N)
        d.line([(x, 0), (x + rng.randint(-4, 4), N)], fill=tint(base, rng.uniform(0.74, 1.24)))
    for _ in range(9):                                      # knots
        cx, cy = rng.randrange(N), rng.randrange(N)
        r = rng.randint(3, 7)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tint(base, 0.6))
    noise(im, 8, rng)
    return im


def tile(rng):
    """Fired-clay barrel tile - what separates a nha ruong or dinh from a thatch hut."""
    base = (138, 82, 60)
    im = Image.new("RGB", (N, N), tint(base, 0.7))
    d = ImageDraw.Draw(im)
    row = 32
    for ry in range(0, N + row, row):
        off = (ry // row % 2) * 11
        for tx in range(-22, N + 22, 22):
            x0 = tx + off
            f = rng.uniform(0.86, 1.14)
            d.rounded_rectangle([x0, ry, x0 + 19, ry + row - 3], radius=7, fill=tint(base, f))
            d.line([(x0 + 3, ry + 2), (x0 + 3, ry + row - 5)], fill=tint(base, f * 1.22))
            d.line([(x0 + 16, ry + 2), (x0 + 16, ry + row - 5)], fill=tint(base, f * 0.66))
        d.line([(0, ry), (N, ry)], fill=tint(base, 0.5))    # course shadow
    noise(im, 7, rng)
    return im


def masonry(rng):
    """Laterite footing and tomb work - porous, red-brown, coursed."""
    base = (128, 92, 70)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    course = 30
    for cy in range(0, N, course):
        off = (cy // course % 2) * 26
        for bx in range(-52, N + 52, 52):
            x0 = bx + off
            d.rectangle([x0, cy, x0 + 49, cy + course - 3],
                        fill=tint(base, rng.uniform(0.84, 1.16)))
    for _ in range(900):                                    # laterite is full of holes
        x, y = rng.randrange(N), rng.randrange(N)
        r = rng.randint(1, 3)
        d.ellipse([x, y, x + r, y + r], fill=tint(base, rng.uniform(0.55, 0.78)))
    noise(im, 10, rng)
    return im


def char(rng):
    """Burned-out timber - the third condition tier. Black, not brown."""
    base = (44, 38, 35)
    im = Image.new("RGB", (N, N), base)
    d = ImageDraw.Draw(im)
    for _ in range(300):
        x = rng.randrange(N)
        d.line([(x, 0), (x + rng.randint(-5, 5), N)], fill=tint(base, rng.uniform(0.55, 1.5)))
    for _ in range(70):                                     # ash and pale checking
        x, y = rng.randrange(N), rng.randrange(N)
        d.line([(x, y), (x + rng.randint(4, 18), y + rng.randint(-2, 2))],
               fill=tint((132, 126, 120), rng.uniform(0.6, 1.0)))
    noise(im, 12, rng)
    return im


MAPS = {"vil_thatch": thatch, "vil_bamboo": bamboo, "vil_wattle": wattle,
        "vil_timber": timber, "vil_tile": tile, "vil_masonry": masonry, "vil_char": char}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for i, (name, fn) in enumerate(sorted(MAPS.items())):
        im = fn(random.Random(4400 + i * 31))
        # 256-colour indexed, no dither: the art-storage rule, ~7x off truecolour.
        q = im.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
        p = os.path.join(OUT, name + ".png")
        q.save(p, optimize=True)
        kb = os.path.getsize(p) / 1024.0
        total += kb
        print(f"{name:14s} 256x256 indexed  {kb:6.1f} KB")
    print(f"\n{len(MAPS)} maps, {total:.0f} KB total -> {os.path.normpath(OUT)}")


main()
