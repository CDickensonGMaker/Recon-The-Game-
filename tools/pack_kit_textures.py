"""Give a kit GLB the textures its own material names already ask for.

WHY THIS EXISTS, and it is measured, not assumed. Rendered at eye height on 2026-09-09, both
bunkers in the stamped firebase are WHITE BOXES - the exact defect the 2026-09-07 demo audit
flagged as "white surfaces on the walked path", one kit part over. Parsing the GLBs says why:

    fb_bunker_fighting.glb   images: 0   materials: fb_earth, fb_timber, fb_psp,
                                                    fb_sandbag_wall   - none with a texture
    fb_bunker_mg.glb         images: 0   materials: the same four plus fb_crate

No baseColorTexture AND no baseColorFactor, so the renderer draws them at the white default.
And every one of those material names is the exact basename of a PNG that has been sitting in
assets/.../firebase/tex/ since July - fb_earth.png, fb_timber.png, fb_psp.png,
fb_sandbag_wall.png, fb_crate.png - the same atlas set the monolith and the M101 emplacement
draw with. The meshes carry TEXCOORD_0 on every one of those material slots. Nothing was
missing but the pack step of a July REVIEW export.

So this does the one missing thing, in the glTF, the way tools/add_kit_colliders.py does: it
embeds the PNG bytes in the BIN chunk and points each material's baseColorTexture at it.

WHAT IT DOES NOT DO. It never touches geometry, UVs, node transforms or names. A material
that already has a texture is left alone, which makes it idempotent. A material whose name
has no PNG beside it is REPORTED, never guessed at - naming your way into a material is the
CollisionTable defect (a bunker shipped as soft cover because its name contained "rack") and
it is not repeated here.

THE REAL FIX IS HIS RE-EXPORT. When the better bunker comes out of Blender with its textures
packed, this tool has nothing to do and stops being needed. Until then a proof-of-concept
firebase should not be made of white boxes.

Usage:
    python tools/pack_kit_textures.py            # audit only, writes nothing
    python tools/pack_kit_textures.py --apply
"""

from __future__ import annotations

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.normpath(os.path.join(HERE, "..", "assets", "world", "building models",
                                    "structures", "firebase", "kit"))
TEX = os.path.normpath(os.path.join(HERE, "..", "assets", "world", "building models",
                                    "structures", "firebase", "tex"))

GLB_MAGIC = b"glTF"
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
# His law, 2026-08-18: no embedded image in a shipped GLB over 1 MB.
MAX_IMAGE_BYTES = 1024 * 1024

TARGETS = ["fb_bunker_fighting.glb", "fb_bunker_mg.glb"]


def read_glb(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:4] != GLB_MAGIC:
        raise SystemExit("%s is not a GLB" % path)
    off = 12
    js = None
    chunks = []
    while off < len(raw):
        length, ctype = struct.unpack("<II", raw[off:off + 8])
        off += 8
        data = raw[off:off + length]
        off += length
        if ctype == CHUNK_JSON:
            js = json.loads(data.decode("utf-8"))
        else:
            chunks.append((ctype, data))
    return js, chunks


def write_glb(path, js, chunks):
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    out = [struct.pack("<II", len(js_bytes), CHUNK_JSON), js_bytes]
    for ctype, data in chunks:
        pad = b"\x00" if ctype == CHUNK_BIN else b" "
        data = data + pad * ((4 - len(data) % 4) % 4)
        out.append(struct.pack("<II", len(data), ctype))
        out.append(data)
    body = b"".join(out)
    header = struct.pack("<4sII", GLB_MAGIC, 2, 12 + len(body))
    with open(path, "wb") as f:
        f.write(header + body)


def has_uvs(js, material_index):
    """True when every primitive drawn with this material carries TEXCOORD_0.

    A baseColorTexture on a primitive with no UVs samples texel 0,0 across the whole
    surface - a flat colour that looks like a bug and reads like a texture. Refuse it.
    """
    seen = False
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if prim.get("material") != material_index:
                continue
            seen = True
            if "TEXCOORD_0" not in prim.get("attributes", {}):
                return False
    return seen


def process(path, apply_changes):
    js, chunks = read_glb(path)
    name = os.path.basename(path)
    bin_index = None
    for i, (ctype, _data) in enumerate(chunks):
        if ctype == CHUNK_BIN:
            bin_index = i
            break
    if bin_index is None:
        print("  %s has no BIN chunk - skipped" % name)
        return False

    blob = bytearray(chunks[bin_index][1])
    js.setdefault("images", [])
    js.setdefault("textures", [])
    js.setdefault("samplers", [])
    js.setdefault("bufferViews", [])
    if not js["samplers"]:
        js["samplers"].append({"magFilter": 9729, "minFilter": 9987,
                               "wrapS": 10497, "wrapT": 10497})
    sampler = 0

    by_name = {}       # png basename -> texture index, so one atlas is embedded once
    changed = 0
    for mi, mat in enumerate(js.get("materials", [])):
        mat_name = str(mat.get("name", ""))
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        if pbr.get("baseColorTexture") is not None:
            continue
        png = os.path.join(TEX, mat_name + ".png")
        if not os.path.exists(png):
            if mat.get("pbrMetallicRoughness", {}).get("baseColorFactor") is None:
                print("  %-22s material '%s': NO %s.png and NO baseColorFactor - it will "
                      "draw WHITE" % (name, mat_name, mat_name))
            continue
        if not has_uvs(js, mi):
            print("  %-22s material '%s': no TEXCOORD_0 on its primitives - refused"
                  % (name, mat_name))
            continue
        if mat_name not in by_name:
            data = open(png, "rb").read()
            if len(data) > MAX_IMAGE_BYTES:
                print("  %-22s %s.png is %.2f MB, over the 1 MB law - refused"
                      % (name, mat_name, len(data) / 1048576.0))
                continue
            while len(blob) % 4:
                blob.append(0)
            offset = len(blob)
            blob += data
            js["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                      "byteLength": len(data)})
            js["images"].append({"name": mat_name, "mimeType": "image/png",
                                 "bufferView": len(js["bufferViews"]) - 1})
            js["textures"].append({"sampler": sampler,
                                   "source": len(js["images"]) - 1})
            by_name[mat_name] = len(js["textures"]) - 1
        pbr["baseColorTexture"] = {"index": by_name[mat_name], "texCoord": 0}
        # Metal/rough left where the export put them; only the albedo was missing.
        changed += 1
        print("  %-22s material '%s' <- tex/%s.png" % (name, mat_name, mat_name))

    if changed == 0:
        print("  %-22s nothing to do" % name)
        return False
    while len(blob) % 4:
        blob.append(0)
    js["buffers"][0]["byteLength"] = len(blob)
    chunks[bin_index] = (CHUNK_BIN, bytes(blob))
    if apply_changes:
        write_glb(path, js, chunks)
        print("  %-22s WROTE %d material(s), %d image(s), %.0f KB"
              % (name, changed, len(by_name), os.path.getsize(path) / 1024.0))
    else:
        print("  %-22s would write %d material(s), %d image(s)"
              % (name, changed, len(by_name)))
    return True


def main():
    apply_changes = "--apply" in sys.argv
    print("[TEX] %s" % ("APPLY" if apply_changes else "audit only (pass --apply to write)"))
    for fn in TARGETS:
        p = os.path.join(KIT, fn)
        if not os.path.exists(p):
            print("  %s missing" % fn)
            continue
        process(p, apply_changes)


if __name__ == "__main__":
    main()
