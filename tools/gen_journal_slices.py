"""Slice Caleb's journal sheet into UI pieces.

The sheet is the source of truth; these PNGs regenerate from it (tools/gen_cursors.py
precedent). Never hand-edit the slices and never write into source_art/.

    python tools/gen_journal_slices.py

Alpha: background is keyed by flood-filling DARK pixels inward from the crop border, so
dark printed ink inside a piece stays opaque. Pieces with a real HOLE in them (the rubber
band's loop, the paperclip's gaps) get keep_interior=False and are keyed by threshold
alone - a border flood cannot reach an enclosed hole, and the band ships as a black blob
if you let it try. That is exactly what happened on the first cut.
"""
from PIL import Image
import numpy as np, os
from collections import deque

SRC = r'C:\Users\caleb\RECONgame\assets\ui\journal\source_art\journal_sheet_caleb.png'
OUT = r'C:\Users\caleb\RECONgame\assets\ui\journal'

# bbox = (x, y, w, h) measured by connected-component labelling of the sheet
# name: (x, y, w, h, mirror, keep_interior)
PIECES = {
    'cover':        (32,  20, 280, 420, False, True),
    'spread':       (348, 16, 556, 424, False, True),
    'tab_1':        (952, 28, 264,  72, True,  True),
    'tab_2':        (952,112, 264,  76, True,  True),
    'tab_3':        (952,200, 264,  72, True,  True),
    'tab_4':        (952,288, 264,  68, True,  True),
    'tab_5':        (952,372, 264,  72, True,  True),
    'pencil':       (1284,40,  40, 228, False, False),
    'paperclip':    (1432,76,  52, 172, False, False),
    'rubber_band':  (1264,276,252, 156, False, False),
    'map_topo':     (20, 464, 744, 524, False, True),
    'k_ration':     (792, 472,308, 236, False, True),
    'letter':       (788, 716,312, 268, False, True),
    'da_form_20':   (1128,464,388, 524, False, True),
}
PAD = 8
LO, HI = 30.0, 62.0   # max-channel alpha ramp (sheet background maxes at ~28)

im = Image.open(SRC).convert('RGB')
sheet = np.asarray(im).astype(np.float32)
H, W, _ = sheet.shape

def cut(name, box, flip, keep_interior):
    x, y, w, h = box
    x0, y0 = max(0, x - PAD), max(0, y - PAD)
    x1, y1 = min(W, x + w + PAD), min(H, y + h + PAD)
    rgb = sheet[y0:y1, x0:x1]
    mx = rgb.max(axis=2)
    ch, cw = mx.shape
    # background = dark pixels reachable from the crop border (keeps interior ink opaque)
    dark = mx < HI
    bg = np.zeros_like(dark)
    q = deque()
    for i in range(ch):
        for j in (0, cw - 1):
            if dark[i, j] and not bg[i, j]:
                bg[i, j] = True; q.append((i, j))
    for j in range(cw):
        for i in (0, ch - 1):
            if dark[i, j] and not bg[i, j]:
                bg[i, j] = True; q.append((i, j))
    while q:
        i, j = q.popleft()
        for di, dj in ((1,0),(-1,0),(0,1),(0,-1)):
            a, b = i + di, j + dj
            if 0 <= a < ch and 0 <= b < cw and dark[a, b] and not bg[a, b]:
                bg[a, b] = True; q.append((a, b))
    alpha = np.clip((mx - LO) / (HI - LO), 0.0, 1.0)
    if keep_interior:
        alpha = np.where(bg, alpha, 1.0)
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(out, 'RGBA')
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    p = os.path.join(OUT, name + '.png')
    img.save(p, optimize=True)
    return p, img.size, os.path.getsize(p)

os.makedirs(OUT, exist_ok=True)
total = 0
for n, (*box, flip, keep) in PIECES.items():
    p, size, b = cut(n, tuple(box), flip, keep)
    total += b
    print('%-12s %4dx%-4d %7d B  %s' % (n, size[0], size[1], b, 'mirrored' if flip else ''))
print('total %.0f KB' % (total / 1024.0))
