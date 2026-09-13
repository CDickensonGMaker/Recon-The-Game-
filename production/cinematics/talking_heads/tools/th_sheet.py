"""PIL helper for th_render.py (Blender's Python has no PIL): label a PNG, or tile PNGs into a contact sheet.
    python th_sheet.py label <png> <text> [<sub>]
    python th_sheet.py tile <out.png> <cols> <png1> <png2> ...
"""
import sys
from PIL import Image, ImageDraw


def label(png, text, sub=None):
    im = Image.open(png).convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, im.width, 30 if sub else 18), fill=(0, 0, 0))
    d.text((6, 3), text, fill=(255, 255, 255))
    if sub:
        d.text((6, 16), sub, fill=(200, 200, 200))
    im.save(png)


def tile(out, cols, paths):
    ims = [Image.open(p).convert("RGB") for p in paths]
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows))
    for i, im in enumerate(ims):
        if im.size != (w, h):
            im = im.resize((w, h), Image.LANCZOS)          # mixed sources (a game portrait beside a render) take the first tile's size
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(out)


if __name__ == "__main__":
    if sys.argv[1] == "label":
        label(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif sys.argv[1] == "tile":
        tile(sys.argv[2], int(sys.argv[3]), sys.argv[4:])
