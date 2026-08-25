"""Shrink the shared master texture sheets embedded in RECONgame GLBs.

One upstream fix applied identically everywhere (recon-texture-bloat-is-one-sheet):
finds images named better_textures / better textures / recovered_ref_factions,
downscales them 50%, re-encodes optimized PNG, and rebuilds the GLB BIN chunk.
Never touches geometry, rigs, or any other image. Dry-run by default.

Usage: python shrink_master_sheets.py [--apply] [--root PATH]
"""
import argparse, hashlib, io, json, os, struct, sys
from PIL import Image

TARGET_NAMES = {"better_textures", "better textures", "recovered_ref_factions"}
SCALE = 0.5
MAGIC = 0x46546C67  # 'glTF'


def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != MAGIC or version != 2:
        raise ValueError("not a glTF2 GLB")
    offset = 12
    gltf_json = None
    bin_chunk = b""
    while offset < length:
        clen, ctype = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8: offset + 8 + clen]
        if ctype == 0x4E4F534A:  # JSON
            gltf_json = json.loads(payload.decode("utf-8"))
        elif ctype == 0x004E4942:  # BIN
            bin_chunk = payload
        offset += 8 + clen
    return gltf_json, bin_chunk


def save_glb(path, gltf, bin_chunk):
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_chunk += b"\x00" * ((4 - len(bin_chunk) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_chunk)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", MAGIC, 2, total))
        f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_chunk), 0x004E4942))
        f.write(bin_chunk)


shrunk_cache = {}  # sha1 of original bytes -> shrunk png bytes


def shrink_png(raw):
    key = hashlib.sha1(raw).hexdigest()
    if key not in shrunk_cache:
        img = Image.open(io.BytesIO(raw))
        new_size = (max(1, round(img.width * SCALE)), max(1, round(img.height * SCALE)))
        img = img.convert("RGBA" if img.mode in ("RGBA", "LA", "P") else "RGB")
        img = img.resize(new_size, Image.LANCZOS)
        out = io.BytesIO()
        img.save(out, format="PNG", optimize=True)
        shrunk_cache[key] = out.getvalue()
    return shrunk_cache[key]


def process(path, apply):
    gltf, bin_chunk = load_glb(path)
    if gltf is None or not bin_chunk:
        return None
    images = gltf.get("images", [])
    views = gltf.get("bufferViews", [])
    hits = [i for i, im in enumerate(images)
            if im.get("name") in TARGET_NAMES and "bufferView" in im]
    if not hits:
        return None
    hit_views = {images[i]["bufferView"] for i in hits}

    # Rebuild BIN preserving every bufferView, swapping only the target images.
    new_bin = bytearray()
    replaced = []
    for vi, view in enumerate(views):
        start = view.get("byteOffset", 0)
        raw = bytes(bin_chunk[start: start + view["byteLength"]])
        if vi in hit_views:
            new_raw = shrink_png(raw)
            replaced.append((len(raw), len(new_raw)))
            raw = new_raw
        new_bin += b"\x00" * ((4 - len(new_bin) % 4) % 4)
        view["byteOffset"] = len(new_bin)
        view["byteLength"] = len(raw)
        new_bin += raw
    gltf["buffers"][0]["byteLength"] = len(new_bin)

    before = os.path.getsize(path)
    if apply:
        save_glb(path, gltf, bytes(new_bin))
        # sanity: reload
        g2, b2 = load_glb(path)
        assert len(g2.get("bufferViews", [])) == len(views)
    after = os.path.getsize(path) if apply else None
    return before, after, replaced


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--root", default=r"C:\Users\caleb\RECONgame\assets")
    args = ap.parse_args()
    total_before = total_after = count = 0
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
            total_before += before
            if after is not None:
                total_after += after
            rep = ", ".join(f"{o/1e6:.1f}->{n/1e6:.1f}MB" for o, n in replaced)
            rel = os.path.relpath(p, args.root)
            print(f"{'APPLIED' if args.apply else 'DRYRUN'} {rel}: {rep}"
                  + (f"  file {before/1e6:.1f}->{after/1e6:.1f}MB" if after else ""))
    print(f"\n{count} glbs with master sheets; total before {total_before/1e6:.1f}MB"
          + (f", after {total_after/1e6:.1f}MB" if args.apply else " (dry run)"))


if __name__ == "__main__":
    main()
