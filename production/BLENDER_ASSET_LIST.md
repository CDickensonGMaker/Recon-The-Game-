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
- ⬜ **M60** + **RPD** viewmodels (LMG hold — support hand on barrel/carry-handle)
- ⬜ **PPSh** viewmodel (SMG — support hand on drum)
- ⬜ **RPG-2** viewmodel (over-shoulder)
- ⬜ **FP radio handset** — the handset prop raised in first-person for the "on the net" state (reuse the RTO handset)
- ⬜ **Per-gun idle animations** — idle/fidget/check/inspect per weapon (see `IDLE_ANIM_SPEC.md` + `IK_ANIMATION_WORKFLOW.md`)
- ✅ done: M14, M16, AK, Mosin viewmodels (+ MuzzlePoints); semi-auto rifle pose

## WEAPONS / PROPS
- 🔴 **Claymore** model — placeholder green box (`claymore.gd:19`) + a "clack" detonation sound
- 🔴 **Combat knife (Ka-Bar)** — the current one is wrong color/shape; needs a proper Marine Ka-Bar
- ✅ punji_trap.glb exists (now wired to gameplay)

## VEHICLES / AIRCRAFT
- 🔴 **F-4 Phantom** (jet) — Skyraider is the stand-in for the fast flyby (`mission_director.gd:291`)
- 🔴 **C-47 "Spooky" gunship** — stretched-box placeholder (`spooky_gunship.gd:29`)
- 🔴 **ZPU / DShK AA gun** — mg_nest GLB placeholder (`site_planner.gd:233`)
- ⬜ **Driveable vehicle variants** — jeep/truck/APC (currently destructible props: M151, M113, Chinook exist as props)
- ⬜ **Helipad** model — currently just flattened dirt + a parked Chinook

## WORLD / STRUCTURES
- ⬜ **Rubble/debris** models — destroyed structures just vanish now; need a rubble+scorch remnant
- 🔴 **POW cage / rice-storage crib** — box placeholder (`rescue_objective.gd:17`)
- 🔴 **MG nest** — placeholder
- ⬜ **Tunnel interior kit** (interior-mode) — entrance, rooms, ladders, props; `tunnel_room.gd` uses box placeholders now
- ⬜ **Building interiors** (interior-mode CQB) — current building models are solid exterior props
- ⬜ **Barbwire hazard variant** — concertina structure exists; a damaged/tangle piece for the hazard
- ⬜ **Roads** — muddy laterite road strip material + tire-track decal textures (mostly textures, not models)

## SPRITES (parallel pipeline)
- 🟡 **Sprite render matrix** — 8-dir sprites for VC/NVA units × weapons × anims, rendered from the 3D models (partly done; consumer code + dedup owed)

## FX (mostly procedural — listed so we don't re-model them)
- ✅ Explosion visual (procedural flash+fireball+smoke), muzzle flash — no models needed
- 🟡 Fire VFX — placeholder cylinder; real `terrain_vfx NAPALM_FIRE` exists but unwired (code, not art)

---
**Suggested Blender order when the MCP is back up:** slimmer base mesh → radioman + handset → M60/RPD/PPSh/RPG
viewmodels → claymore + Ka-Bar → civilians → F-4 + C-47 → per-gun idle anims → interior/tunnel kit.
