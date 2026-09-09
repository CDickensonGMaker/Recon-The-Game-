"""build_ww1_face_cells.py - the donor face cells for the Conquest of Worms WW1 cast.

    python tools/build_ww1_face_cells.py

Writes assets/ww1/characters/ww1_<tag>_face_cell.png, one per man.

THIS SCRIPT ONLY EMITS THE DONOR CELL. It does NOT decide where the cell goes on the
sheet - tools/build_ww1_cast.py measures that per mesh, in Blender. Two traps, both
measured 2026-09-09 and each of which cost a render pass on the US cast:
  1. the VISIBLE joined body and the HIDDEN grunt_head gib donor sample DIFFERENT cells
     (us_grunt_joined u[0.0136,0.0904] v[0.6019,0.6976]; grunt_head v[0.0050,0.1435])
  2. every variant samples its OWN cell
so a cell measured off one man, or off the gib donor, paints a tile nothing looks at.

Landmark fractions of a cell, read off a luminance map of face_atlas_v5 at 129x162 px
(tools/build_cow_face_atlases.py). Every face on this sheet is generated from the same
aligned template, so the fractions hold for any cell:
    hair y 0.00-0.26   forehead y 0.26-0.41   eye line y 0.46
    nose tip y 0.63    mouth y 0.80           chin y 0.90
    cheeks x 0.29-0.39 and 0.57-0.67, y 0.55-0.65
"""
import os
import numpy as np
from PIL import Image

ROOT = r"C:\Users\caleb\RECONgame"
SRC = os.path.join(ROOT, "assets", "us", "characters", "face_source", "face_atlas_v5.png")
OUT = os.path.join(ROOT, "assets", "ww1", "characters")
COLS, ROWS = 10, 7

# (row_from_top, col) on face_atlas_v5. Rows 0-1 are the dark-skin band, rows 2-3 the
# light/European band, rows 4-6 East Asian. These are EUROPEAN soldiers and one American,
# so every pick is from rows 2-3. Which face within the band is an art choice, stated as
# such; what is NOT an art choice is the band.
CAST = {
    # Louie: seventeen in April 1915, and Caleb has ruled him a Louisiana man who spoke
    # French and went to fight - an AMERICAN face in poilu kit. Clean-shaven and young.
    # Deliberately NOT Michael's cell (2,9): the bible is explicit that Michael and Louie
    # "are not built as echoes of each other".
    "louie_1915":   dict(cell=(3, 1), scar=False),
    "louie_adrian": dict(cell=(3, 1), scar=False),
    # "Poilu" means the hairy one. The older line soldier carries the moustache.
    "poilu_a":      dict(cell=(3, 2), scar=False),
    "poilu_b":      dict(cell=(2, 3), scar=False),
    "poilu_1916":   dict(cell=(2, 4), scar=False),
    # THE YOUNG GERMAN LOUIE SPARES. Bible section 2: "The German boy is drawn with a
    # large, deliberate scar down one cheek - a mark of identity applied in the panel
    # where he is spared." Young, like Louie.
    "german_boy":   dict(cell=(2, 6), scar=True),
    "german_line":  dict(cell=(3, 7), scar=False),
}

# Scar path in cell fractions: from just below the outer corner of the character's LEFT
# eye (viewer's right) down across the cheekbone to the jaw line.
#
# THE LOWER END WAS MEASURED BY LOOKING, NOT BY THE LANDMARK LADDER. The first pass ran
# to y 0.812 on the strength of build_cow_face_atlases' "chin y 0.90" figure and came out
# ON THE NECK, below the jaw. Two width-profile instruments were tried to find the jaw
# automatically and BOTH were broken: a lit-pixel row width reports 99% of the cell at
# every y from 0.60 to 0.80, because the ears and the lit background are inside the
# threshold. So the jaw was read off a 4x render of the actual cell: chin bottom ~0.77,
# jaw corner ~0.735. Do not "restore" the 0.90 figure - it is the sheet's chin, not this
# cell's, and the render is the evidence.
SCAR_A = (0.665, 0.448)
SCAR_B = (0.622, 0.735)
SCAR_W = 3.2                    # px at the native 129x162 cell, at mid-length


def cell_rect(w, h, row, col):
    cw, ch = w / COLS, h / ROWS
    return (int(round(col * cw)), int(round(row * ch)),
            int(round((col + 1) * cw)), int(round((row + 1) * ch)))


def scar(a):
    """A LINE, not a stipple.

    The freckle lesson from the US cast was that a 1-2 px dot on a ~25 px cheek is below
    resolution and reads as a rash or as nothing. A scar is a different shape of mark: a
    LINE roughly 58 px long on a 162 px cell survives every downsample this sheet takes,
    and the bible calls it "large, deliberate". So it is drawn, and its readability is
    measured below rather than hoped for.
    """
    out = a.astype(np.float32).copy()
    h, w, _ = out.shape
    x0, y0 = SCAR_A[0] * w, SCAR_A[1] * h
    x1, y1 = SCAR_B[0] * w, SCAR_B[1] * h
    length = float(np.hypot(x1 - x0, y1 - y0))
    half = SCAR_W * (w / 129.0) * 0.5

    # GATE: the path has to lie on lit skin. If the landmarks are wrong we would be
    # drawing a scar through hair or through the eye and it would look like damage to
    # the texture, not to the boy. Same assertion the freckle pass carries.
    lum = out.mean(axis=2)
    samples = []
    for t in np.linspace(0.15, 0.85, 12):
        px, py = int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t))
        samples.append(float(lum[py, px]))
    m = float(np.mean(samples))
    if m < 110.0:
        raise SystemExit("ABORT scar: mean luminance %.1f along the path - that is not "
                         "lit skin, the landmarks are wrong. samples=%s"
                         % (m, [round(s) for s in samples]))
    print("   scar path mean luminance %.1f (min %.1f) over %d samples - lit skin, OK"
          % (m, min(samples), len(samples)))

    # Healed scar tissue: darker and redder at the edges, a paler raised core. Painted as
    # a distance field so it survives resampling as a soft line instead of a dotted one.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    d = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
    # TAPER. A constant-width line reads as a stick laid on the cheek; a real scar is
    # widest at its middle and closes to a point. Half-width is modulated along t.
    taper = 0.35 + 0.65 * np.sin(np.pi * np.clip(t, 0.0, 1.0)) ** 0.6
    hw = half * taper
    core = np.clip(1.0 - d / hw, 0.0, 1.0)
    edge = np.clip(1.0 - (d - hw) / (hw * 1.6), 0.0, 1.0) * (d >= hw)
    dark = np.array([0.58, 0.40, 0.38], dtype=np.float32)      # shadowed groove
    pale = np.array([1.14, 1.02, 1.00], dtype=np.float32)      # raised scar tissue
    out *= (1.0 + (pale - 1.0) * core[..., None])
    out *= (1.0 + (dark - 1.0) * edge[..., None])
    out = np.clip(out, 0, 255)

    # MEASURE the mark we just made, do not assume it landed.
    before = a.astype(np.float32)
    diff = np.abs(out - before).max(axis=2)
    n = int((diff > 6).sum())
    print("   scar drawn: %.1f px long, %.1f px wide, %d pixels changed on a %dx%d cell "
          "(%.2f%% of it)" % (length, 2 * half, n, w, h, 100.0 * n / (w * h)))
    if n < 100:
        raise SystemExit("ABORT scar: only %d pixels changed - it will not read." % n)
    return out.astype(np.uint8)


def build(tag, spec):
    src = Image.open(SRC).convert("RGB")
    W, H = src.size
    a = np.array(src)
    r, c = spec["cell"]
    x0, y0, x1, y1 = cell_rect(W, H, r, c)
    cell = a[y0:y1, x0:x1].copy()
    print("%-13s <- face_atlas_v5 cell row %d col %d, rect x%d-%d y%d-%d (%dx%d)"
          % (tag, r, c, x0, x1, y0, y1, x1 - x0, y1 - y0))
    if spec["scar"]:
        cell = scar(cell)
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, "ww1_%s_face_cell.png" % tag)
    Image.fromarray(cell).save(p)
    print("   wrote %s  %dx%d  %.0f KB"
          % (os.path.basename(p), cell.shape[1], cell.shape[0], os.path.getsize(p) / 1024.0))
    return p


if __name__ == "__main__":
    if not os.path.exists(SRC):
        raise SystemExit("ABORT: missing %s" % SRC)
    for tag, spec in CAST.items():
        build(tag, spec)
    print("done - %d face cells in %s" % (len(CAST), OUT))
