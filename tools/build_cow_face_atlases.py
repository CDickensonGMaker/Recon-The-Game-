"""build_cow_face_atlases.py - the two Conquest of Worms face sidecars.

    python tools/build_cow_face_atlases.py

Writes assets/us/characters/cow_michael_face_atlas.png and cow_gus_face_atlas.png.

CONTRACT (measured, not assumed):
  grunt_dresser.gd:20-21   FACE_COLS = 10, FACE_ROWS = 7

THIS SCRIPT ONLY EMITS THE DONOR FACE CELL. It does NOT decide where the cell goes.
Two traps, both measured on 2026-09-09, each of which cost a render pass:
  1. THE VISIBLE BODY AND THE GIB HEAD SAMPLE DIFFERENT CELLS.
       us_grunt_joined_rifleman  u[0.0136,0.0904] v[0.6019,0.6976] -> col 0, row 2 from top
       grunt_head_rifleman       u[0.0043,0.0972] v[0.0050,0.1435] -> col 0, row 6 from top
     `grunt_head` is the HIDDEN dismemberment donor. Painting its cell puts the new face
     where nothing on the living man can see it.
  2. EVERY VARIANT SAMPLES ITS OWN CELL. That is how the squad has different faces at all
     (tools/bake_us_faces.py: "measure the face rect this variant actually samples").
     The grenadier's joined body does NOT sample the rifleman's cell, so a cell measured
     off one man and applied to another paints the wrong tile and the render comes back
     wearing the stock face.
So the destination is MEASURED PER MESH, in Blender, by tools/build_cow_cast.py. No UV is
touched; the head keeps the canonical wrap and GruntDresser's uv1_offset ladder still
works on the sheet.

Source sheet is resampled WHOLE (never cell by cell) - see the drift lesson in
tools/bake_us_faces.py.
"""
import os
import numpy as np
from PIL import Image

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC = os.path.join(CHAR, "face_source", "face_atlas_v5.png")
COLS, ROWS = 10, 7
OUT_W, OUT_H = 960, 896          # matches the shipped us_grunt_*_face_atlas_v3 sidecars

# (row_from_top, col, what samples it)
DEST_CELLS = [(2, 0, "us_grunt_joined - THE VISIBLE BODY"),
              (ROWS - 1, 0, "grunt_head - the gib donor")]

# Donor cells, (row_from_top, col), chosen by eye off the light-skin band:
MICHAEL_CELL = (2, 9)   # brown hair, clean shaven, youthful oval face
GUS_CELL = (2, 7)       # the narrowest / most hollow-cheeked light face on the sheet


def cell_rect(w, h, row, col):
    cw, ch = w / COLS, h / ROWS
    return (int(round(col * cw)), int(round(row * ch)),
            int(round((col + 1) * cw)), int(round((row + 1) * ch)))


# Landmark fractions of the cell, READ OFF a luminance map of face_atlas_v5 cell
# (row 2, col 7) at 129x162 px. Every face on this sheet is generated from the same
# aligned template, so these fractions hold for any cell:
#   hair       y 0.00-0.26      forehead   y 0.26-0.41
#   eye line   y 0.46           nose tip   y 0.63    mouth y 0.80    chin y 0.90
#   cheeks (brightest skin, either side of the nose shadow)
#              x 0.29-0.39 and 0.57-0.67,  y 0.55-0.65
# An auto-detector was tried first and put the eye line on the hairline; the dots
# landed on the brows. Fixed landmarks + a brightness assertion beat a clever guess.
CHEEK_L = (0.335, 0.600)
CHEEK_R = (0.665, 0.600)
NOSE_BRIDGE = (0.500, 0.520)


def freckle(a, seed=1967):
    """Dotted freckles across the cheekbones and the nose bridge (bible: Gus and Pierre
    are 'drawn young, gaunt, wide-eyed, with dotted freckles across the cheekbones')."""
    rng = np.random.default_rng(seed)
    h, w, _ = a.shape
    out = a.astype(np.float32).copy()
    lum = out.mean(axis=2)
    placed = 0
    patches = []
    # These counts and sigmas are THE VERSION CALEB APPROVED. A sparser, lower-contrast
    # variant exists in the history and was never put in front of him - do not quietly
    # substitute it. He ruled on what he saw.
    for (fx, fy), n, (sxf, syf) in ((CHEEK_L, 15, (0.045, 0.030)),
                                    (CHEEK_R, 15, (0.045, 0.030)),
                                    (NOSE_BRIDGE, 8, (0.030, 0.018))):
        cx, cy = fx * w, fy * h
        patch = lum[int(cy - syf * h * 2):int(cy + syf * h * 2),
                    int(cx - sxf * w * 2):int(cx + sxf * w * 2)]
        m = float(patch.mean())
        print("   patch centre (%.0f,%.0f) mean lum %.1f" % (cx, cy, m))
        if m < 110.0:
            raise SystemExit("ABORT: freckle patch at (%.0f,%.0f) has mean luminance %.1f "
                             "- that is not lit skin, the landmarks are wrong." % (cx, cy, m))
        patches.append((cx, cy, sxf * w, syf * h, n))
    # LOW CONTRAST ON PURPOSE. The bible keeps two motifs apart (section 5): freckles are
    # just a young face, POCKS are contamination. A high-contrast red stipple reads as
    # disease and inverts Gus's arc, which starts ordinary.
    tint = np.array([0.68, 0.56, 0.52], dtype=np.float32)
    for cx, cy, sx, sy, n in patches:
        for _ in range(n):
            px = int(round(cx + rng.normal(0.0, sx)))
            py = int(round(cy + rng.normal(0.0, sy)))
            if not (1 <= px < w - 2 and 1 <= py < h - 2):
                continue
            if out[py, px].mean() < 70:     # do not stipple hair, brows or the eye itself
                continue
            # 2x2 core so the dot survives the whole-sheet downsample to 960x896
            for oy in (0, 1):
                for ox in (0, 1):
                    q = out[py + oy, px + ox]
                    if q.mean() >= 70:
                        out[py + oy, px + ox] = q * tint
            placed += 1
    print("   freckles: %d dots placed on a %dx%d cell" % (placed, w, h))
    return np.clip(out, 0, 255).astype(np.uint8)


def pale(a, k=1.06):
    """Gaunt / bloodless: lift value slightly and pull a little red out of it."""
    out = a.astype(np.float32) * np.array([k * 0.99, k, k * 1.02], dtype=np.float32)
    return np.clip(out, 0, 255).astype(np.uint8)


def build(donor_cell, out_name, do_freckles):
    src = Image.open(SRC).convert("RGB")
    W, H = src.size
    a = np.array(src)
    r, c = donor_cell
    x0, y0, x1, y1 = cell_rect(W, H, r, c)
    cell = a[y0:y1, x0:x1].copy()
    print("%s <- donor cell row %d col %d, rect x%d-%d y%d-%d (%dx%d)"
          % (out_name, r, c, x0, x1, y0, y1, x1 - x0, y1 - y0))
    if do_freckles:
        cell = freckle(pale(cell))
    p = os.path.join(CHAR, out_name)
    Image.fromarray(cell).save(p)
    print("   wrote DONOR CELL %s  %dx%d  %.0f KB"
          % (p, cell.shape[1], cell.shape[0], os.path.getsize(p) / 1024.0))
    return p


if __name__ == "__main__":
    build(MICHAEL_CELL, "cow_michael_face_cell.png", False)
    build(GUS_CELL, "cow_gus_face_cell.png", True)    # FRECKLES ON - Caleb ruled, see the note below

# FRECKLES: REMOVED 2026-09-09, then REINSTATED the same day on CALEB'S RULING:
# "i felt like the older gus had freckles and it worked better."
#
# The measurement that argued for removal was CORRECT and still lost. The atlas cell is
# 130x162 px and the head samples ~89x124 of it, so a cheek is ~25 px across and a
# "freckle" is one or two pixels - it cannot be stippling at this density, and at portrait
# size it reads blotchy. That is a true statement about the texel budget. It is NOT an
# argument that the freckles should be absent.
#
# THE LESSON: a resolution argument tells you a thing is hard to draw, not that it should
# not be there. Bible section 2 names "dotted freckles across the cheekbones" as the only
# facial mark Gus and Pierre are given, and the author would rather have a coarse version
# of the mark that identifies the character than a clean face that does not.
#
# The canon risk is real and stays worth watching: bible section 5 keeps POCKS
# (contamination, they sit on the skin) and FRECKLES (just a young face) deliberately
# apart, and Gus must start ORDINARY. If a future pass makes him read as diseased on
# ARRIVAL, that is the thing to fix - by confining and softening the stipple, not by
# deleting it.
#
# The parameters above are exactly what he saw and approved. Do not "improve" them
# without putting the result in front of him.
