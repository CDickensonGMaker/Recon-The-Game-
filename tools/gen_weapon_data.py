"""gen_weapon_data.py - Regenerate data/weapons/*.tres from a real-world spec
table, PRESERVING the hand-tuned viewmodel positions/rotations/scale/model_path
already in each file. New weapons inherit a donor's viewmodel.

Run: python tools/gen_weapon_data.py

Sourcing: fire_rate (cyclic RPM, or practical cap for semi/bolt), magazine,
projectile_speed (muzzle velocity m/s), and supersonic status are the ballistics
research figures. RECON damage dice are the game's language and are preserved.
Ranges are gameplay-scaled but ordered to match real relative reach. Bolt guns:
fire_rate is the practical CYCLE rate (~1.5s), NOT the 15rpm aimed rate that
included human re-aiming -- the player does the aiming.
"""

from __future__ import annotations

import os
import re

WDIR = os.path.join(os.path.dirname(__file__), "..", "data", "weapons")

# firing_mode: 0 SEMI 1 FULL 2 BOLT 3 BURST     damage_type: 0 PHYS 1 EXPL 2 FIRE
# fields: mode, rpm, mag, reload, dmg(3), dtype, spread, ads_spread, rec_v, rec_h,
#         ads_fov, ads_move, eff, maxr, min_mult, mv, supersonic,
#         first, climb, climb_max, recovery, vol_db
S = dict  # alias
SPECS: dict[str, dict] = {
 "m16a1":  S(name="M16A1", mode=1, rpm=750, mag=20, reload=2.4, dmg=(5,10,0), dt=0,
            spread=1.6, adssp=0.25, recv=1.1, rech=0.5, fov=60, admv=0.6, eff=300, mx=460,
            minm=0.65, mv=948, sup=True, first=1.4, climb=0.05, cmax=1.7, rec=14, vol=0.0,
            desc="5.56mm assault rifle. The tumbling round - RECON rates it 5d10. A high, tinny crack."),
 "car15":  S(name="CAR-15 / XM177", mode=1, rpm=800, mag=20, reload=2.4, dmg=(5,10,0), dt=0,
            spread=2.0, adssp=0.30, recv=1.3, rech=0.7, fov=60, admv=0.65, eff=200, mx=350,
            minm=0.55, mv=838, sup=True, first=1.4, climb=0.06, cmax=1.7, rec=13, vol=1.5,
            desc="Cut-down carbine. Deafening, concussive, brutal up close. RECON 5d10."),
 "m60":    S(name="M60", mode=1, rpm=550, mag=100, reload=6.5, dmg=(5,10,0), dt=0,
            spread=2.6, adssp=0.40, recv=2.8, rech=1.0, fov=60, admv=0.40, eff=300, mx=500,
            minm=0.70, mv=853, sup=True, first=1.3, climb=0.045, cmax=1.7, rec=8, vol=2.0,
            desc="7.62 NATO belt-fed. The Pig. Deep, slow, and it flattens whatever it points at."),
 "sks":    S(name="SKS", mode=0, rpm=240, mag=10, reload=3.0, dmg=(4,10,0), dt=0,
            spread=1.4, adssp=0.20, recv=1.3, rech=0.4, fov=58, admv=0.6, eff=300, mx=450,
            minm=0.70, mv=735, sup=True, first=1.3, climb=0.0, cmax=1.0, rec=13, vol=0.0,
            desc="7.62x39 semi-auto carbine. Local Force standard. RECON 4d10."),
 "ak47":   S(name="AK-47", mode=1, rpm=600, mag=30, reload=2.6, dmg=(4,10,0), dt=0,
            spread=2.2, adssp=0.30, recv=1.5, rech=0.9, fov=62, admv=0.6, eff=250, mx=400,
            minm=0.60, mv=715, sup=True, first=1.5, climb=0.06, cmax=1.8, rec=11, vol=0.5,
            desc="7.62x39 assault rifle. A lower, rounder boom than the M16. Its crack does not give you away as American."),
 "rpd":    S(name="RPD", mode=1, rpm=650, mag=100, reload=7.0, dmg=(1,8,42), dt=0,
            spread=2.4, adssp=0.40, recv=2.2, rech=0.8, fov=60, admv=0.45, eff=200, mx=350,
            minm=0.60, mv=735, sup=True, first=1.3, climb=0.04, cmax=1.6, rec=9, vol=1.0,
            desc="7.62x39mm belt-fed. It does not stop, and it does not care what it is shooting through."),
 "ppsh41": S(name="PPSh-41", mode=1, rpm=900, mag=71, reload=3.4, dmg=(1,6,34), dt=0,
            spread=2.2, adssp=0.35, recv=1.4, rech=0.9, fov=58, admv=0.65, eff=80, mx=180,
            minm=0.40, mv=488, sup=True, first=1.2, climb=0.05, cmax=1.6, rec=11, vol=0.0,
            desc="7.62x25mm burp gun. A thin, tearing snap at 900rpm. Murderous up close, useless past the treeline."),
 "mosin":  S(name="Mosin-Nagant 91/30", mode=2, rpm=35, mag=5, reload=5.0, dmg=(1,10,68), dt=0,
            spread=0.6, adssp=0.1, recv=8.5, rech=0.6, fov=40, admv=0.5, eff=140, mx=300,
            minm=0.85, mv=865, sup=True, first=1.0, climb=0.0, cmax=1.0, rec=9, vol=2.0,
            desc="7.62x54mmR bolt rifle. The deepest, sharpest report in the valley. Slow, loud, and it only needs to work once."),
 "kar98k": S(name="Kar 98k", mode=2, rpm=40, mag=5, reload=4.5, dmg=(1,10,70), dt=0,
            spread=0.5, adssp=0.1, recv=8.0, rech=0.5, fov=40, admv=0.5, eff=150, mx=300,
            minm=0.85, mv=760, sup=True, first=1.0, climb=0.0, cmax=1.0, rec=10, vol=2.0,
            desc="7.92mm Mauser rifle. Work the bolt, one shot, one kill at any range."),
 "m1911":  S(name="M1911 Pistol", mode=0, rpm=300, mag=7, reload=2.2, dmg=(1,6,45), dt=0,
            spread=1.0, adssp=0.2, recv=5.0, rech=1.0, fov=65, admv=0.8, eff=30, mx=50,
            minm=0.30, mv=253, sup=False, first=1.2, climb=0.0, cmax=1.0, rec=10, vol=0.5,
            desc=".45 ACP pistol. A flat, subsonic boom - no crack. Same stopping power as the Thompson, fewer rounds."),
 "thompson": S(name="Thompson M1A1", mode=1, rpm=700, mag=30, reload=3.5, dmg=(1,6,45), dt=0,
            spread=1.8, adssp=0.30, recv=1.6, rech=0.7, fov=58, admv=0.6, eff=50, mx=120,
            minm=0.35, mv=285, sup=False, first=1.2, climb=0.05, cmax=1.5, rec=12, vol=0.5,
            desc=".45 ACP submachine gun. Heavy, soft-shooting, and the bolt clatters as loud as the report. Two rounds center mass will drop a man."),
 "mp40":   S(name="MP40", mode=1, rpm=500, mag=32, reload=3.2, dmg=(1,6,38), dt=0,
            spread=1.5, adssp=0.3, recv=1.8, rech=0.6, fov=55, admv=0.6, eff=60, mx=150,
            minm=0.40, mv=380, sup=False, first=1.2, climb=0.05, cmax=1.5, rec=12, vol=0.0,
            desc="9mm Parabellum SMG. A slow, deliberate chug. Slightly less stopping power than .45 ACP."),
 "m79":    S(name="M79 Grenade Launcher", mode=0, rpm=15, mag=1, reload=4.0, dmg=(8,10,0), dt=1,
            spread=1.0, adssp=0.5, recv=5.0, rech=1.0, fov=65, admv=0.6, eff=100, mx=150,
            minm=1.0, mv=76, sup=False, first=1.0, climb=0.0, cmax=1.0, rec=6, vol=1.0,
            desc="40mm break-open launcher. The Blooper. A hollow THOONK, then silence, then the ground opens up downrange."),
 "m72_law": S(name="M72 LAW", mode=0, rpm=12, mag=1, reload=0.0, dmg=(4,10,50), dt=1,
            spread=1.8, adssp=0.5, recv=6.0, rech=1.0, fov=60, admv=0.5, eff=150, mx=250,
            minm=1.0, mv=145, sup=False, first=1.0, climb=0.0, cmax=1.0, rec=6, vol=2.0,
            desc="66mm disposable rocket. A hissing roar and a backblast that names your position to the whole AO."),
 "rpg2":   S(name="RPG-2", mode=0, rpm=12, mag=1, reload=6.5, dmg=(4,10,40), dt=1,
            spread=1.8, adssp=0.5, recv=6.0, rech=1.0, fov=60, admv=0.5, eff=90, mx=150,
            minm=1.0, mv=84, sup=False, first=1.0, climb=0.0, cmax=1.0, rec=6, vol=1.5,
            desc="40mm rocket launcher. One shot, a long reload, and a smoke trail that tells everyone where you are."),
 "rpg7":   S(name="RPG-7", mode=0, rpm=10, mag=1, reload=8.0, dmg=(5,10,45), dt=1,
            spread=1.9, adssp=0.5, recv=6.5, rech=1.1, fov=60, admv=0.5, eff=200, mx=330,
            minm=1.0, mv=115, sup=False, first=1.0, climb=0.0, cmax=1.0, rec=6, vol=2.0,
            desc="Launch BANG, a beat, then the sustainer motor lights downrange with a roar. The one everyone fears."),
 "m26_grenade": S(name="M26 Frag Grenade", mode=0, rpm=30, mag=1, reload=0.0, dmg=(10,10,0), dt=1,
            spread=0.0, adssp=1.0, recv=0.0, rech=0.0, fov=75, admv=1.0, eff=5, mx=5,
            minm=1.0, mv=15, sup=False, first=1.0, climb=0.0, cmax=1.0, rec=12, vol=0.0,
            desc="American fragmentation grenade. Cook before throwing for airburst."),
}

# New weapons that have no existing .tres: (donor for viewmodel/positions, projectile_data)
NEW = {
 "car15":   ("m16a1", ""),
 "m60":     ("rpd", ""),
 "m79":     ("mp40", ""),
 "m72_law": ("rpg2", "res://data/projectiles/rpg2_rocket.tres"),
 "rpg7":    ("rpg2", "res://data/projectiles/rpg2_rocket.tres"),
}

POS_KEYS = ["model_path", "viewmodel_scale", "hip_position", "ads_position",
            "hip_rotation", "ads_rotation", "projectile_data_path"]
SCRIPT_UID = "uid://2eaahkhc4qim"


def parse_existing(wid: str) -> dict:
    path = os.path.join(WDIR, wid + ".tres")
    if not os.path.exists(path):
        return {}
    txt = open(path, encoding="utf-8").read()
    out = {}
    m = re.search(r'uid="(uid://[^"]+)"\]', txt.splitlines()[0])
    if m:
        out["_res_uid"] = m.group(1)
    for k in POS_KEYS:
        mm = re.search(rf"^{k} = (.+)$", txt, re.M)
        if mm:
            out[k] = mm.group(1).strip()
    return out


def build(wid: str, spec: dict, viz: dict) -> str:
    res_uid = viz.get("_res_uid", "")
    head = '[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3'
    if res_uid:
        head += f' uid="{res_uid}"'
    head += "]"

    model = viz.get("model_path", '""')
    scale = viz.get("viewmodel_scale", "1.0")
    hip_p = viz.get("hip_position", "Vector3(0.25, -0.3, -0.4)")
    ads_p = viz.get("ads_position", "Vector3(0, -0.246, -0.899)")
    hip_r = viz.get("hip_rotation", "Vector3(0, 0, 0)")
    ads_r = viz.get("ads_rotation", "Vector3(0.9, 0, 0.1)")
    proj = viz.get("projectile_data_path", '""')
    if wid in NEW:
        proj = f'"{NEW[wid][1]}"' if NEW[wid][1] else '""'

    d = spec["dmg"]
    lines = [
        head, "",
        f'[ext_resource type="Script" uid="{SCRIPT_UID}" path="res://scripts/weapons/weapon_data.gd" id="1"]',
        "", "[resource]", 'script = ExtResource("1")',
        f'id = "{wid}"',
        f'display_name = "{spec["name"]}"',
        f'description = "{spec["desc"]}"',
        f'firing_mode = {spec["mode"]}',
        f'fire_rate = {float(spec["rpm"])}',
        f'magazine_size = {spec["mag"]}',
        f'reload_time = {float(spec["reload"])}',
        f'base_damage = Array[int]([{d[0]}, {d[1]}, {d[2]}])',
        f'damage_type = {spec["dt"]}',
        f'base_spread = {spec["spread"]}',
        f'ads_spread_mult = {spec["adssp"]}',
        f'recoil_vertical = {float(spec["recv"])}',
        f'recoil_horizontal = {spec["rech"]}',
        f'ads_fov = {float(spec["fov"])}',
        f'ads_move_mult = {spec["admv"]}',
        f'effective_range = {float(spec["eff"])}',
        f'max_range = {float(spec["mx"])}',
        f'min_damage_mult = {spec["minm"]}',
        f'projectile_speed = {float(spec["mv"])}',
        f'projectile_data_path = {proj}',
        f'recoil_first_shot_mult = {spec["first"]}',
        f'recoil_climb_per_shot = {spec["climb"]}',
        f'recoil_climb_max = {spec["cmax"]}',
        f'recoil_recovery = {float(spec["rec"])}',
        f'fire_volume_db = {spec["vol"]}',
        'fire_pitch_variance = 0.04',
        'audio_max_distance = 350.0',
        'audio_unit_size = 16.0',
        f'is_supersonic = {"true" if spec["sup"] else "false"}',
        f'model_path = {model}',
        f'viewmodel_scale = {scale}',
        f'hip_position = {hip_p}',
        f'ads_position = {ads_p}',
        f'hip_rotation = {hip_r}',
        f'ads_rotation = {ads_r}',
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    for wid, spec in SPECS.items():
        if wid in NEW:
            viz = parse_existing(NEW[wid][0])
            viz.pop("_res_uid", None)  # new file mints its own uid on scan
        else:
            viz = parse_existing(wid)
        out = build(wid, spec, viz)
        path = os.path.join(WDIR, wid + ".tres")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(out)
        print(("NEW " if wid in NEW else "    ") + f"{wid}.tres")


if __name__ == "__main__":
    main()
