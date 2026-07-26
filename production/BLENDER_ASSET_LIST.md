# Blender Asset List — models/anims to keep the pipelines fed (2026-07-09)

Every art asset we've identified, from code placeholders + design discussions. Status:
🔴 placeholder in game (box/capsule/stand-in) · 🟡 partial · ⬜ not started · ✅ done (listed for context).

## CHARACTERS
- ⬜ **Slimmer base soldier mesh** — fix the "chonky" proportions; the base every US unit rebuilds from (do FIRST, everything reuses it)
- ⬜ **US Army grunt modular kit** — helmet variants (M1 + covers, boonie, bare), torso variants (OG-107, flak vest, sleeves-rolled), arm variants → roster/appearance variety for the 100 bios
- ⬜ **Radioman (RTO)** — grunt + **PRC-25 radio backpack** + **handset on a cord** (the 10m-leash character; the handset reused in first-person)
- 🔴 **Civilians / villagers** — men, women, kids in farm dress (non-combatant); + a suicide-bomber-that-reads-as-civilian (scripted events). Enemies/units are capsules until modeled (`enemy_data.gd:33`)
- 🔴 **VC/NVA enemy models** — the enemy roster (capsule placeholders now) — feeds both 3D and the sprite pipeline
- ✅ done: us_grunt, us_grunt_black, us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy, Huey pilots
- ⬜ *(DLC, not launch)* Special Forces + Marines faction models

## FIRST-PERSON VIEWMODELS (arms + gun)
- ⬜ **FP radio handset** — the handset prop raised in first-person for the "on the net" state (reuse the RTO's PRC-25 handset) — this is how the player calls in airstrikes/support (bead RECONgame-i1vu)
- ⬜ **Per-gun idle animations** — idle/fidget/check/inspect per weapon (see `IDLE_ANIM_SPEC.md` + `IK_ANIMATION_WORKFLOW.md`)
- ✅ done: every weapon viewmodel ships — M14, M16, AK, Mosin, M60, RPD, PPSh, RPG-2, M70, Colt .45,
  Ithaca (+ the non-gun M26 grenade and medkit viewmodels); `scenes/weapons/*_arms_viewmodel.tscn`
  over `assets/player/viewmodels/*_fp.glb`. Semi-auto rifle pose done.

## WEAPONS / PROPS
- 🔴 **Claymore** model — placeholder green box (`claymore.gd:19`) + a "clack" detonation sound
- 🔴 **Combat knife (Ka-Bar)** — the current one is wrong color/shape; needs a proper Marine Ka-Bar
- ✅ punji_trap.glb exists (now wired to gameplay)

## VEHICLES / AIRCRAFT
- 🟡 **F-4 Phantom** — GLB already in project (`aircraft/f4_phantom.glb`); needs wiring into the flyby (`mission_director.gd:291`, bead RECONgame-qs6l)
- 🟡 **C-47 "Spooky" gunship** — `ac47_spooky.glb` now flies on `SpectreGunship` with props spinning (`spectre_gunship.gd:50`, 2026-07-25); still needs the side-firing minigun barrels modeled
- 🔴 **ZPU / DShK AA gun** — mg_nest GLB placeholder (`site_planner.gd:233`)
- 🟡 **Driveable vehicle variants** — GLBs copied from RTS 2026-07-09: m35_deuce_truck, us_jeep, uh1_huey, us_bulldozer (+ M151/M113/Chinook already here); driveable *code* is bead RECONgame-2kcp
- ✅ **Helipad** — copied from RTS 2026-07-09 (`converted/helipad.glb`, `airfield/psp_helipad.glb`); needs placement wiring
- ⬜ **Mountable M60 + pintle mount** — modular gun/mount for bunkers, jeep/APC ring, Huey door (Batch 2, bead RECONgame-4nkw; socket code bead RECONgame-izmf)

## WORLD / STRUCTURES  —  ⭐ MOSTLY COVERED BY RealVietnamRTS (copy-in, don't model)
The RTS has ~103 Vietnam structures. These fill our gaps directly (copy from
`RealVietnamRTS/assets/models/structures/`, never edit the RTS):
**→ FULL COPY DONE 2026-07-09**: all missing structure files (285) + vehicles (44) copied into
`assets/building models/` — every 🟢 below is now in-project; remaining work is wiring/placement.
- ✅ **Rubble/debris** → RTS ruins set COPIED IN 2026-07-09 (`ruins/rubble_pile.glb`, `burned_hut.glb`, `destroyed_bunker.glb`, `bomb_crater.glb`, `cham_temple_ruin.glb`) **+ 3 new FPS-scale pieces modeled**: `ruins/rubble_debris_small.glb`, `rubble_debris_large.glb`, `wall_remnant.glb` (pending review; destruction-swap code bead RECONgame-8tly)
- ✅ **POW cage** → proper bamboo cage MODELED 2026-07-09: `vc_nva/pow_cage.glb` (sized to the 2.2×1.8×2.2 placeholder; `village/rice_storage.glb` also available as alt) — pending review + wiring into `rescue_objective.gd:17`
- 🟢 **MG nest** → `firebase/mg_nest.glb`
- 🟢 **Helipad** → `converted/helipad.glb` / `airfield/psp_helipad.glb`
- 🟢 **Barbwire hazard** → `converted/barbed_wire.glb`, `firebase/barbed_wire_coil.glb`
- 🟢 **Tunnel entrance + an interior room** → `vc_nva/tunnel_entrance_hidden.glb`, `vc_nva/underground_hospital.glb`
- 🟢 **Firebase variety (~25)** → aid_station, ammo/commo/conex bunkers, toc, mess_hall, mortar_pit, quonset_hut, trench_modular, gate_entrance…
- 🟢 **Village variety (9)** → thatched_hut, stilt_house, three_room_house, communal_house, pagoda, bell_tower, well
- 🟢 **Colonial buildings** → plantation_house, villa, government_building (towns/rich villages)
- 🟢 **Airfield** → control_tower, hangar, radar_dome, runway_section (a US airbase install type)
- 🟢 **Bridges (4)** → wooden/stone/army (roads-over-rivers)
- 🟢 **Ordnance props** → 500lb bombs, Napalm BLU-27, rocket pods (hang under the F-4 / dropped props)
- ⬜ **Building INTERIORS** (interior-mode CQB) — RTS buildings are exterior shells; enterable interiors still need authoring
- ⬜ **Roads** — muddy laterite strip material + tire-track decal *textures* (not models)

## SPRITES — ☠️ DEAD PIPELINE (kept for context only, do not feed)
Killed by `adr/ADR-001-renderer-of-record.md` ("Renderer of record: 3D PSX models; sprite matrix
killed", Summoner-ratified). No sprite actor exists in `scripts/`; the only survivor is
`scripts/visuals/sprite_state_map.gd`, which is now the 3D clip-id map, not a sprite renderer
(`sprite_state_map.gd:201`). No sprite work is owed.
- ☠️ ~~**Sprite render matrix** — 8-dir sprites for VC/NVA units × weapons × anims, rendered from the 3D models~~

## FX (mostly procedural — listed so we don't re-model them)
- ✅ Explosion visual (procedural flash+fireball+smoke), muzzle flash — no models needed
- 🟡 Fire VFX — placeholder cylinder; real `terrain_vfx NAPALM_FIRE` exists but unwired (code, not art)

---
**Suggested Blender order when the MCP is back up:** slimmer base mesh → radioman + handset →
claymore + Ka-Bar → civilians → F-4 + C-47 → per-gun idle anims → interior/tunnel kit.
