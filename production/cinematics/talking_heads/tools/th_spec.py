"""Shared layout constants for the talking-head skull build and its texture generator.
Reference frame = CDmir CC0 skull (C:/Users/caleb/_reference/skeleton_study/raw/skull_cdmir), Z up, face toward -Y,
skull 1.92 wide x 2.55 long x 2.85 tall (vertex to menton). Scaled to real by SKULL_SCALE in the build."""
# cranium cage: azimuth columns (deg, 0 = front, + = world +X), polar rows
CR_COLS = [-125, -95, -75, -60, -45, -34, -25, -16, -8, 0, 8, 16, 25, 34, 45, 60, 75, 95, 125, 180]
# rows: (name, kind, value). kind 'phi' = polar angle deg from +Z about CR_CENTRE; kind 'z' = front-surface target z (ref units)
CR_ROWS = [("dome1", "phi", 25.0), ("dome2", "phi", 48.0), ("dome3", "phi", 66.0),
           ("brow", "z", 0.02), ("orbU", "z", -0.15), ("orbL", "z", -0.35), ("cheek", "z", -0.50),
           ("nasal", "z", -0.68), ("alv", "z", -1.00), ("tips", "z", -1.22)]
CR_CENTRE = (0.0, 0.20, -0.20)      # ray target for the cranium projection
CR_FRONT_Y = -0.95                    # front surface y used to convert z targets to polar angles
CR_V_TOP, CR_V_BOT = 1.0, 0.30        # atlas v span of the cranium (top pole .. bottom pole)
# mandible cage
MD_COLS = [-78, -66, -52, -40, -25, -12, 0, 12, 25, 40, 52, 66, 78]
MD_AXIS = (0.0, 0.0, -1.30)           # horizontal ray target for the mandible projection
MD_ROWS = ["outer_top", "outer_mid", "outer_bot", "inner_bot", "inner_top"]
MD_ROW_V = [0.28, 0.20, 0.13, 0.08, 0.02]
MD_TOP_Z_BODY = -1.25                 # lower tooth tips: just under the upper tips (-1.22), no overbite -> no rest intersection
MD_TOP_Z = {52: -1.00, 66: -0.85, 78: -0.78}   # ramus columns: anterior border / notch / condyle
MD_THICK = 0.12                       # lingual offset toward the axis (ref units)
CONDYLE = (0.70, 0.16, -0.78)         # hinge, ref units (+-x)
ORBIT = {"cols": (8, 34), "rows": ("brow", "cheek")}
NASAL = {"col_halfwidth": 8, "rows": ("cheek", "alv")}
TEETH_COL = 40
ATLAS = 256


def cr_ring_v(i, n=len(CR_ROWS)):
    return CR_V_BOT + (CR_V_TOP - CR_V_BOT) * (1.0 - (i + 1) / (n + 1))


def cr_u(theta_deg):
    return 0.5 + theta_deg / 360.0


def md_u(theta_deg):
    return 0.5 + theta_deg / 180.0
# ---- teeth (th_skulls.py). The CDmir OBJ keeps every tooth as its own connected component; measured 2026-09-12 in
# ref units on the +x side (mirrored in the build). Labial line = tooth centre + half its buccolingual depth outward.
UP_MARGIN_Z = -1.093                  # maxillary alveolar margin at the front (cranium component min z, |x| < 0.12)
LO_CREST_Z = -1.303                   # mandibular alveolar crest at the front (mandible component max z, |x| < 0.12)
UP_LABIAL = [(0.000, -0.962), (0.061, -0.962), (0.169, -0.939), (0.259, -0.889), (0.308, -0.817),
             (0.356, -0.725), (0.393, -0.625), (0.427, -0.535), (0.440, -0.440)]   # midline -> I1 I2 C PM1 PM2 M1 M2 M3
# lower labial line = upper labial line inset by the upper anteriors's thickness at the overbite height + 0.4 mm (th_skulls.lower_inset)
OVERBITE_MM = 1.5                     # anterior lower tips rise this far above the upper incisal edges
# per side from the midline outward: (name, width, buccolingual depth, crown height, depth at the tip) in mm
UPPER_TEETH = [("I1", 8.5, 6.0, 11.0, 1.0), ("I2", 6.5, 6.0, 10.0, 1.0), ("C", 7.5, 6.5, 11.5, 1.0),
               ("PM1", 7.0, 8.0, 8.0, 6.5), ("PM2", 6.5, 8.0, 8.0, 6.5), ("M", 15.0, 10.0, 7.0, 8.5)]
LOWER_TEETH = [("i1", 5.5, 6.0, 0.0, 1.0), ("i2", 6.0, 6.0, 0.0, 1.0), ("c", 7.0, 7.0, 0.0, 1.0),
               ("pm1", 7.0, 8.0, 0.0, 6.5), ("pm2", 7.0, 8.0, 0.0, 6.5), ("m", 15.0, 10.0, 0.0, 8.5)]   # crowns set by the bite
TOOTH_GAP_MM = 1.0                    # 0.6 mm vanished at 320x240; the tips taper further so the gaps read as V notches
ZB_TOOTH_PATCH_PX = (2, 188, 14, 212)     # zombie atlas: ivory crown texels (x0, y0, x1, y1; y from the top), gum rows at y0
ZB_MISSING = {("upper", 1, 1), ("lower", -1, 3)}      # (arch, side, spec index): upper right I2, lower left pm1
ZB_BROKEN = {("upper", -1, 2): 0.45}                  # upper left canine snapped to 45% of its crown
# sniper: his own sheet (cow_sniper_sheet_1024.png), the painted mouth slit and his painted teeth patch
SN_MOUTH_PX = (140.7, 165.0)          # slit centre on the sheet (rows 164-166 are the dark line; centre column of the cell)
SN_MOUTH_HALF_PX = 24.0               # half-width used for the tooth band (the painted slit runs px 117-160)
SN_BAND_UP_MM, SN_BAND_DOWN_MM = 5.0, 6.0   # skin edges above / below the bite line (crowns: upper 7 incl. overbite, lower 6)
SN_TOOTH_CELLS_PX = [(843, 93, 855, 102), (859, 93, 871, 102), (826, 93, 838, 102)]   # his brightest painted crowns; row 104 is the gap line, excluded
SN_DARK_PX = (814, 111, 817, 114)     # darkest 3x3 of his teeth patch: the mouth cavity texel
SN_CAVITY_BACK_Y = -0.0625            # back wall = where the chin underside ends at the mouth corners (rig-local Z-up y; mouth skin -0.119, hinge -0.032)
