# -*- coding: utf-8 -*-
"""Emit assets/nva_vc/characters/vc_nva_manifest.json.

VcNvaDresser.faces_for() reads `face_pools`; everything else here is the
authored source that pool is derived from. Correct `FACES` below and re-run:

    python tools/make_vc_nva_manifest.py

FACE SHEET: assets/nva_vc/characters/nva_vc_soldiers_textures/
fixed_better_viet_faces.jpg, 1737x579 px, a 10 col x 3 row grid = 30 cells.
Cell 0 is TOP-LEFT and the index runs left to right, top to bottom - the same
convention GruntDresser's US_FACES uses on the 10x7 shared atlas.

SEX/AGE were read off the sheet by eye. They decide who may wear which face and
nothing else, so a wrong call costs one odd-looking man, never a crash.
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "nva_vc", "characters", "vc_nva_manifest.json")

ATLAS = "fixed_better_viet_faces.jpg"
ATLAS_COLS = 10
ATLAS_ROWS = 3

# cell -> (sex, age).  sex: "m" | "f".  age: "adult" | "elder".
FACES = {
    0: ("m", "adult"), 1: ("m", "adult"), 2: ("m", "adult"), 3: ("f", "adult"),
    4: ("m", "adult"), 5: ("f", "adult"), 6: ("m", "adult"), 7: ("m", "elder"),
    8: ("m", "adult"), 9: ("f", "adult"),
    10: ("f", "adult"), 11: ("m", "adult"), 12: ("m", "adult"), 13: ("m", "adult"),
    14: ("f", "adult"), 15: ("m", "adult"), 16: ("m", "adult"), 17: ("f", "adult"),
    18: ("m", "adult"), 19: ("m", "adult"),
    20: ("m", "adult"), 21: ("m", "adult"), 22: ("f", "adult"), 23: ("m", "elder"),
    24: ("m", "adult"), 25: ("f", "adult"), 26: ("m", "adult"), 27: ("m", "adult"),
    28: ("m", "adult"), 29: ("f", "adult"),
}

# Summoner ruling 2026-08-07: the NVA roles are MALE. The VC roles are a
# deliberate mix of women and men - the local cell is the village.
# Summoner ruling 2026-08-07: enemy VC never fields an RTO - irregulars have
# no radio net. The NVA RTO stays.
NVA_UNITS = [
    "nva_marksman", "nva_medic", "nva_mg", "nva_officer", "nva_regular",
    "nva_rifleman", "nva_rpg", "nva_rto", "nva_sapper",
    "nva_mortar_gunner", "nva_mortar_dropper", "nva_mortar_runner",
]
VC_UNITS = [
    "vc_guerilla", "vc_guerilla_m16", "vc_guerilla_mosin", "vc_guerilla_ppsh",
    "vc_guerilla_rpd", "vc_guerilla_rpg", "vc_medic", "vc_sapper",
    "vc_marksman", "vc_officer", "vc_rpg",
    "vc_mortar_gunner", "vc_mortar_dropper", "vc_mortar_runner",
]


def cells(pred):
    return sorted(i for i in range(ATLAS_COLS * ATLAS_ROWS) if pred(FACES[i]))


def main():
    male = cells(lambda f: f[0] == "m")
    mixed = cells(lambda f: True)

    pools = {"default": male}
    for u in NVA_UNITS:
        pools[u] = male
    for u in VC_UNITS:
        pools[u] = mixed

    doc = {
        "atlas": ATLAS,
        "atlas_cols": ATLAS_COLS,
        "atlas_rows": ATLAS_ROWS,
        "note": ("Emitted by tools/make_vc_nva_manifest.py - edit FACES there, not "
                 "here. Cell 0 is top-left; index runs left to right, top to bottom. "
                 "A unit with no entry in face_pools draws 'default'."),
        "faces": [
            {"cell": i, "row": i // ATLAS_COLS, "col": i % ATLAS_COLS,
             "sex": FACES[i][0], "age": FACES[i][1]}
            for i in range(ATLAS_COLS * ATLAS_ROWS)
        ],
        "face_pools": pools,
    }

    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print("wrote %s (%d male cells, %d mixed cells)" % (OUT, len(male), len(mixed)))


if __name__ == "__main__":
    main()
