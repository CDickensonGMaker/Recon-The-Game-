"""Generate the talking-head skull atlases (256x256) by SAMPLING Caleb's own art, never inventing a palette.
    python th_textures.py
The sniper has NO atlas here any more: his cutscene head is his own game head on his own sheet (th_skulls.py, 2026-09-12).
Zombie: assets/zombies/characters/zed_cult_b_zombie_face_atlas_v1.png + zed_rotted_recovered_gore_tex.png.
Also: helmet_card_ace_clubs.png (the comic's ace of CLUBS, Issue 1 back cover) and cs_mouth_interior.png."""
import os
import random
from PIL import Image, ImageDraw
import th_spec as S

R = r"C:\Users\caleb\RECONgame"
OUT = os.path.join(R, r"production\cinematics\talking_heads\textures")
os.makedirs(OUT, exist_ok=True)
A = S.ATLAS
random.seed(7)


def X(u):
    return int(round(u * A))


def Y(v):
    return int(round((1.0 - v) * A))


def row_v(name):
    return S.cr_ring_v([r[0] for r in S.CR_ROWS].index(name))


def tile(dst, patch, box):
    """Fill box with a pixel-art patch, tiled with random offsets (NEAREST). Keeps the source's own colours."""
    x0, y0, x1, y1 = box
    pw, ph = patch.size
    y = y0
    while y < y1:
        x = x0
        rowh = min(ph, y1 - y)
        oy = random.randint(0, ph - rowh)
        while x < x1:
            w = min(pw, x1 - x)
            ox = random.randint(0, pw - w)
            dst.paste(patch.crop((ox, oy, ox + w, oy + rowh)), (x, y))
            x += w
        y += rowh


def blob(dst, patch, cx, cy, rx, ry):
    """Paste a patch through an elliptical mask."""
    p = patch.resize((2 * rx, 2 * ry), Image.NEAREST)
    m = Image.new("L", p.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, p.width - 1, p.height - 1), fill=255)
    dst.paste(p, (cx - rx, cy - ry), m)


def sockets_and_nose(dst, dark, rim):
    """Orbits as ELLIPSES inset in the socket patch (the reference orbit is ~21% of skull width x 14% of height, not the
    whole 3x3 cage block), a darker rim ring, and a nasal triangle a little wider than the geometric hole."""
    d = ImageDraw.Draw(dst)
    c0, c1 = S.ORBIT["cols"]
    vt, vb = row_v("brow"), row_v("cheek")
    for sgn in (-1, 1):
        ua, ub = sorted((S.cr_u(sgn * c0), S.cr_u(sgn * c1)))
        x0, y0, x1, y1 = X(ua), Y(vt), X(ub), Y(vb)
        h = y1 - y0
        d.ellipse((x0 - 1, y0 + int(h * 0.12), x1 + 1, y1 - int(h * 0.10)), fill=rim)
        d.ellipse((x0 + 1, y0 + int(h * 0.20), x1 - 1, y1 - int(h * 0.16)), fill=dark)
    hw = S.NASAL["col_halfwidth"] + 4
    vt, vb = row_v("cheek"), row_v("alv")
    d.polygon([(X(0.5), Y(vt) + 3), (X(S.cr_u(-hw)), Y(vb) - 1), (X(S.cr_u(hw)), Y(vb) - 1)], fill=dark)


def bone_strip(dst, box, patch, gum, gum_at_top):
    """The alveolar bone band the teeth hang from / stand on: skull-coloured, with a 2 px dark gum line on the tooth
    side. The teeth themselves are GEOMETRY (th_skulls.py) - nothing tooth-shaped is painted here any more."""
    x0, y0, x1, y1 = box
    tile(dst, patch, box)
    d = ImageDraw.Draw(dst)
    d.rectangle((x0, y0, x1, y0 + 1) if gum_at_top else (x0, y1 - 2, x1, y1), fill=gum)


def tooth_patch(dst, box, ivory, gum, edge):
    """Crown texels for the tooth blocks: ivory with speckle, the root/gum rows dark at the top, the worn edge at the bottom."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(dst)
    d.rectangle(box, fill=ivory)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if random.random() < 0.3:
                k = random.randint(0, 30)
                dst.putpixel((x, y), tuple(max(0, c - k) for c in ivory))
    d.rectangle((x0, y0, x1, y0 + 2), fill=gum)
    d.rectangle((x0, y1 - 1, x1, y1), fill=edge)
    d.line((x0, y0, x0, y1), fill=gum); d.line((x1, y0, x1, y1), fill=gum)      # dark outline = the gap between teeth


def mandible_rows(dst, skin_patch, teeth_fn, inner_col, beard=None):
    v = S.MD_ROW_V
    u0, u1 = S.md_u(-S.TEETH_COL), S.md_u(S.TEETH_COL)
    tile(dst, skin_patch, (0, Y(v[0]) - 1, A, Y(v[4]) + 2))                    # whole strip skin first
    teeth_fn((X(u0), Y(v[0]), X(u1), Y(v[1])))                                  # outer_top..outer_mid = lower teeth
    ImageDraw.Draw(dst).rectangle((0, Y(v[2]), A, Y(v[4]) + 2), fill=inner_col)  # inner faces = gum/dark
    if beard is not None:
        blob(dst, beard, X(0.5), (Y(v[1]) + Y(v[2])) // 2 + 2, 22, (Y(v[2]) - Y(v[1])) // 2 + 2)


def build_zombie():
    z = Image.open(os.path.join(R, r"assets\zombies\characters\zed_cult_b_zombie_face_atlas_v1.png")).convert("RGB")
    gore = Image.open(os.path.join(R, r"assets\zombies\characters\zed_rotted_recovered_gore_tex.png")).convert("RGB")
    cw, ch = z.width // 10, z.height // 7

    def cell(c, r):
        return z.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
    fore = cell(6, 5).crop((5, 10, 40, 24)).point(lambda c: min(255, int(c * 1.45)))   # grey-green rotten forehead, lifted for the helmet shadow
    fore2 = cell(2, 4).crop((12, 8, 50, 22))        # warmer rotten skin for variation
    rot = cell(2, 4).crop((44, 38, 72, 62))         # blood-streaked cheek
    im = Image.new("RGB", (A, A))
    tile(im, fore, (0, 0, A, A))
    for i in range(14):
        blob(im, fore2, random.randint(0, A), random.randint(0, Y(S.MD_ROW_V[0])), random.randint(8, 18), random.randint(6, 12))
    tile(im, rot, (X(S.cr_u(-125)), Y(row_v("orbL")), X(S.cr_u(-55)), Y(row_v("alv"))))   # one rotted cheek/temple
    for (cx, cy, rx, ry) in ((X(S.cr_u(75)), Y(row_v("dome3")), 16, 12),
                             (X(S.cr_u(-100)), Y(row_v("dome1")), 20, 10),
                             (X(S.cr_u(35)), Y(row_v("nasal")), 10, 8)):
        blob(im, gore, cx, cy, rx, ry)                                             # open wounds off the shared gore sheet
    sockets_and_nose(im, dark=(8, 6, 6), rim=(40, 42, 30))
    gum = (58, 26, 24)
    bone_strip(im, (X(S.cr_u(-S.TEETH_COL)), Y(row_v("alv")), X(S.cr_u(S.TEETH_COL)), Y(row_v("tips")) + 1), fore, gum, gum_at_top=False)
    mandible_rows(im, fore, lambda box: bone_strip(im, box, fore, gum, gum_at_top=True), inner_col=(30, 10, 10))
    blob(im, gore, X(S.md_u(-45)), (Y(S.MD_ROW_V[1]) + Y(S.MD_ROW_V[2])) // 2, 12, 8)
    ImageDraw.Draw(im).rectangle((0, Y(row_v("tips")) + 1, A, Y(S.CR_V_BOT)), fill=(22, 8, 8))     # palate = dark
    tooth_patch(im, S.ZB_TOOTH_PATCH_PX, ivory=(160, 146, 106), gum=(52, 22, 20), edge=(126, 112, 78))   # rotted ivory
    im.save(os.path.join(OUT, "cs_skull_zombie_atlas.png"))
    return im


def build_card():
    src = Image.open(os.path.join(R, r"assets\us\textures\helmet_card_ace.png")).convert("RGBA")
    px = src.load()
    w, h = src.size
    inner = [px[x, y] for y in range(h // 4, 3 * h // 4) for x in range(w // 4, 3 * w // 4)]
    ink = min(inner, key=lambda c: sum(c[:3]))
    paper = max(inner, key=lambda c: sum(c[:3]))
    d = ImageDraw.Draw(src)
    d.rectangle((w // 5, h // 4, 4 * w // 5, 4 * h // 5), fill=paper)   # clear the spade, keep the "A"
    cx, cy, r = w // 2, int(h * 0.50), int(w * 0.16)
    for (dx, dy) in ((0, -r), (-r, r // 2), (r, r // 2)):
        d.ellipse((cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r), fill=ink)
    d.rectangle((cx - 2, cy, cx + 2, cy + int(r * 2.6)), fill=ink)
    d.rectangle((cx - r, cy + int(r * 2.3), cx + r, cy + int(r * 2.6)), fill=ink)
    src.save(os.path.join(OUT, "helmet_card_ace_clubs.png"))


def build_mouth():
    """64x32 cavity atlas for the human heads: top half = a 6-tooth strip (gum line at the top; the lower teeth sample it
    flipped), bottom-left = dark cavity, bottom-right = tongue. th_face.py owns the UV rects."""
    im = Image.new("RGB", (64, 32), (34, 12, 12))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 63, 15), fill=(222, 210, 178))
    d.rectangle((0, 0, 63, 1), fill=(120, 52, 48))
    for i in range(7):
        x = int(round(i * 63 / 6))
        d.line((x, 2, x, 15), fill=(96, 70, 58))
    d.rectangle((0, 13, 63, 15), fill=(190, 176, 146))
    d.rectangle((32, 16, 63, 31), fill=(158, 62, 74))
    d.rectangle((40, 18, 55, 25), fill=(178, 78, 90))
    im.save(os.path.join(OUT, "cs_mouth_interior.png"))


if __name__ == "__main__":
    b = build_zombie()
    build_card()
    build_mouth()
    b.resize((A * 2, A * 2), Image.NEAREST).save(os.path.join(OUT, "_preview_atlases.png"))
    print("wrote", sorted(os.listdir(OUT)))
