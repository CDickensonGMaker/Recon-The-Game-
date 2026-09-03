"""Game-wide pass: shrink EVERY embedded GLB texture over 1MB by 50%.

Extends shrink_master_sheets.py per Caleb's 8/18 ruling ("optimize all the
models"). Same identical shrink everywhere; master sheets already done in
pass one are EXCLUDED (pending in-game eyeball, no double-halving).
PNG stays PNG (optimized), JPEG stays JPEG (q=87). Dry-run by default.

Usage: python shrink_oversized_textures.py [--apply] [--root PATH]
"""
import argparse, hashlib, io, os
from PIL import Image
from shrink_master_sheets import load_glb, save_glb, TARGET_NAMES

THRESHOLD = 1_000_000
SCALE = 0.5

cache = {}  # sha1 -> shrunk bytes


def shrink_image(raw, mime):
    key = hashlib.sha1(raw).hexdigest()
    if key not in cache:
        img = Image.open(io.BytesIO(raw))
        new_size = (max(1, round(img.width * SCALE)), max(1, round(img.height * SCALE)))
        out = io.BytesIO()
        if mime == "image/jpeg":
            img = img.convert("RGB").resize(new_size, Image.LANCZOS)
            img.save(out, format="JPEG", quality=87)
        else:
            img = img.convert("RGBA" if img.mode in ("RGBA", "LA", "P") else "RGB")
            img = img.resize(new_size, Image.LANCZOS)
            img.save(out, format="PNG", optimize=True)
        cache[key] = out.getvalue()
    return cache[key]


def process(path, apply):
    gltf, bin_chunk = load_glb(path)
    if gltf is None or not bin_chunk:
        return None
    images = gltf.get("images", [])
    views = gltf.get("bufferViews", [])
    hit_views = {}  # view index -> mime
    for im in images:
        if "bufferView" not in im or im.get("name") in TARGET_NAMES:
            continue
        if views[im["bufferView"]]["byteLength"] > THRESHOLD:
            hit_views[im["bufferView"]] = im.get("mimeType", "image/png")
    if not hit_views:
        return None

    new_bin = bytearray()
    replaced = []
    for vi, view in enumerate(views):
        start = view.get("byteOffset", 0)
        raw = bytes(bin_chunk[start: start + view["byteLength"]])
        if vi in hit_views:
            new_raw = shrink_image(raw, hit_views[vi])
            if len(new_raw) < len(raw):  # never grow a file
                replaced.append((len(raw), len(new_raw)))
                raw = new_raw
        new_bin += b"\x00" * ((4 - len(new_bin) % 4) % 4)
        view["byteOffset"] = len(new_bin)
        view["byteLength"] = len(raw)
        new_bin += raw
    if not replaced:
        return None
    gltf["buffers"][0]["byteLength"] = len(new_bin)

    before = os.path.getsize(path)
    if apply:
        save_glb(path, gltf, bytes(new_bin))
        g2, _ = load_glb(path)
        assert len(g2.get("bufferViews", [])) == len(views)
    after = os.path.getsize(path) if apply else None
    return before, after, replaced


def main():
    global SCALE
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--scale", type=float, default=0.5,
                    help="linear resize factor (0.25 = quarter width/height)")
    ap.add_argument("--root", default=r"C:\Users\caleb\RECONgame\assets")
    args = ap.parse_args()
    SCALE = args.scale
    print(f"scale = {SCALE}")
    total_saved = count = 0
    for dirpath, _dirs, files in os.walk(args.root):
        for fn in files:
            if not fn.lower().endswith(".glb"):
                continue
            p = os.path.join(dirpath, fn)
            try:
                res = process(p, args.apply)
            except Exception as e:
                print(f"ERROR {p}: {e}")
                continue
            if res is None:
                continue
            before, after, replaced = res
            count += 1
            saved = sum(o - n for o, n in replaced)
            total_saved += saved
            rel = os.path.relpath(p, args.root)
            rep = ", ".join(f"{o/1e6:.1f}->{n/1e6:.1f}MB" for o, n in replaced)
            print(f"{'APPLIED' if args.apply else 'DRYRUN'} {rel}: {rep}")
    print(f"\n{count} glbs, {total_saved/1e6:.1f}MB saved"
          + ("" if args.apply else " (dry run)"))


if __name__ == "__main__":
    main()
