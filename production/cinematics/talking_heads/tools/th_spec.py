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
