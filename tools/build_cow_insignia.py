"""build_cow_insignia.py - the 64x64 subdued-insignia sheet the CoW rank decals sample.

    python tools/build_cow_insignia.py

Writes assets/us/characters/cow_insignia_64.png. Four 32x32 tiles, UV rects (u0,v0,u1,v1):
  SGT   (0.0, 0.5, 0.5, 1.0)  three chevrons point-up, subdued (black on OD)   - McCleary's sleeves
  LT    (0.5, 0.5, 1.0, 1.0)  one bar, subdued 1st Lt (black, thin edge)          - rank_champs
  CPL   (0.0, 0.0, 0.5, 0.5)  two chevrons point-up, subdued                      - rank_champs_cpl_ALT
  BLANK (0.5, 0.0, 1.0, 0.5)  plain OD patch
Vietnam-era subdued rank: chevrons black on OD green backing (pin-on/sew-on, 1966 on), the
1st Lt bar black, the 2nd Lt bar brown. The bible does not settle Lt vs Cpl (it flags the
drift) and does not say 1st or 2nd - the black bar is the pick, stated in blender_notes.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

ROOT = r"C:\Users\caleb\RECONgame"
OUT = os.path.join(ROOT, "assets", "us", "characters", "cow_insignia_64.png")
OD = (70, 78, 46)
INK = (18, 18, 16)
S = 32


def chevrons(dr, ox, oy, n):
    # point-up chevrons, 3 px thick, 22 px wide, stacked 5 px apart from the top
    for i in range(n):
        y = oy + 6 + i * 6
        pts = [(ox + 5, y + 8), (ox + 16, y), (ox + 27, y + 8), (ox + 27, y + 11), (ox + 16, y + 3), (ox + 5, y + 11)]
        dr.polygon(pts, fill=INK)


def build():
    im = Image.new("RGB", (64, 64), OD)
    dr = ImageDraw.Draw(im)
    chevrons(dr, 0, 0, 3)                     # SGT top-left  (PIL y down: top row = v 0.5..1.0)
    dr.rectangle([32 + 9, 12, 32 + 22, 19], fill=INK)      # LT bar top-right
    dr.rectangle([32 + 10, 13, 32 + 21, 18], outline=(90, 90, 84))
    chevrons(dr, 0, 32, 2)                    # CPL bottom-left
    im.save(OUT)
    a = np.array(im)
    ink = (a[..., 0] < 40).reshape(2, 32, 2, 32).sum(axis=(1, 3))
    print("wrote", OUT, "ink px per tile (rows top->bottom):", ink.tolist())
    assert ink[0][0] > ink[1][0] > 0 and ink[0][1] > 0 and ink[1][1] == 0, ink


if __name__ == "__main__":
    build()
