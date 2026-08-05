"""Build the zombie face atlas from Caleb's reference sheet.

    python tools/make_zombie_atlas.py

OUTPUT: assets/zombies/characters/zombie_face_atlas_v1.png, 960x896.

THE CONTRACT THIS MUST MATCH. GruntDresser slides ONE material's `uv1_offset` by
one cell to change a man's face AND his skin tone together (they are the same
pixels, so they can never mismatch). ZombieDresser does the identical thing, so
this atlas MUST be laid out exactly like the shipped ones:

    960 x 896  =  10 cols x 7 rows  of  96 x 128 cells,  full-bleed portrait per cell

Verified against assets/civilians/characters/civ_farmer_m_face_atlas_v3.png
(960x896, cell 96x128) on 2026-08-05.

THE SOURCE GRID IS MEASURED, NOT LABELLED. The sheet's own caption reads
"7. ZOMBIE FACE REFERENCE (8 x 5)". It is not 8 wide. Measured off the pixels it
is 10 x 5 = 50 faces, tiles 105.4 x 108.0 px, inside x 16..1070 / y 850..1390.
Trusting the caption would have sliced every face in half.

ROWS 5-6 ARE NOT IN THE SOURCE. 10x7 is 70 cells and he supplied 50, so the last
20 are ADVANCED DECAY recolours derived from a spread of the first 50 - matching
his row 6 ("DAMAGED / ADVANCED DECAY VARIANTS"). That gives the rotted undead type
a visually distinct head pool instead of reusing the walkers' faces.
"""
import os
import sys

from PIL import Image, ImageEnhance

SHEET = (r"C:\Users\caleb\Desktop\recon game image ideas\ideas or trexture maps"
         r"\zombie mini game off split.png")
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "assets", "zombies", "characters")
OUT = os.path.normpath(os.path.join(OUT_DIR, "zombie_face_atlas_v1.png"))

# --- the shipped atlas contract (do not change without changing ZombieDresser) ---
ATLAS_COLS, ATLAS_ROWS = 10, 7
CELL_W, CELL_H = 96, 128

# --- the measured source grid ---
SRC_X0, SRC_X1 = 16, 1070
SRC_Y0, SRC_Y1 = 850, 1390
SRC_COLS, SRC_ROWS = 10, 5
# The tile boundaries land ON the sheet's separator lines, so each crop is pulled
# in by this much or every face carries a bright frame down two of its edges.
INSET = 4

# How far into the decay the recoloured rows sit. Necrosis pulls green-grey and
# drops saturation; the flesh does not simply get darker, it stops being flesh.
DECAY_TINT = (0.74, 0.82, 0.70)
DECAY_SATURATION = 0.45
DECAY_BRIGHTNESS = 0.80


def _source_faces(sheet):
    """The 50 faces off the reference sheet, each already at cell size."""
    tw = (SRC_X1 - SRC_X0) / SRC_COLS
    th = (SRC_Y1 - SRC_Y0) / SRC_ROWS
    out = []
    for r in range(SRC_ROWS):
        for c in range(SRC_COLS):
            box = (round(SRC_X0 + c * tw) + INSET,
                   round(SRC_Y0 + r * th) + INSET,
                   round(SRC_X0 + (c + 1) * tw) - INSET,
                   round(SRC_Y0 + (r + 1) * th) - INSET)
            out.append(sheet.crop(box).resize((CELL_W, CELL_H), Image.LANCZOS))
    return out


def _decayed(face):
    """One face, taken further into rot. Desaturate, cool toward green-grey, darken."""
    img = ImageEnhance.Color(face).enhance(DECAY_SATURATION)
    img = ImageEnhance.Brightness(img).enhance(DECAY_BRIGHTNESS)
    r, g, b = img.split()
    r = r.point(lambda v: int(v * DECAY_TINT[0]))
    g = g.point(lambda v: int(v * DECAY_TINT[1]))
    b = b.point(lambda v: int(v * DECAY_TINT[2]))
    return Image.merge("RGB", (r, g, b))


def main():
    if not os.path.exists(SHEET):
        sys.exit("reference sheet not found: %s" % SHEET)
    sheet = Image.open(SHEET).convert("RGB")
    if sheet.size != (1086, 1448):
        # The grid constants above are measured against this exact sheet. A
        # different size means a different sheet, and silently slicing it on
        # these numbers would produce 70 half-faces that look deliberate.
        sys.exit("sheet is %dx%d, expected 1086x1448 - re-measure the grid"
                 % sheet.size)

    faces = _source_faces(sheet)
    total = ATLAS_COLS * ATLAS_ROWS
    # The decay rows walk the source pool on a stride, so the 20 rotted heads are
    # spread across all five source rows instead of being the last 20 again.
    stride = max(1, len(faces) // (total - len(faces)))
    extra = [_decayed(faces[(i * stride) % len(faces)])
             for i in range(total - len(faces))]
    cells = faces + extra

    atlas = Image.new("RGB", (ATLAS_COLS * CELL_W, ATLAS_ROWS * CELL_H), (0, 0, 0))
    for i, cell in enumerate(cells):
        atlas.paste(cell, ((i % ATLAS_COLS) * CELL_W, (i // ATLAS_COLS) * CELL_H))

    os.makedirs(OUT_DIR, exist_ok=True)
    atlas.save(OUT)
    print("wrote %s  %dx%d  (%d source faces + %d decay variants = %d cells)"
          % (OUT, atlas.width, atlas.height, len(faces), len(extra), total))


if __name__ == "__main__":
    main()
