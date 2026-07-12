# ART MISSING — master list from AUDIT #3 (2026-07-11)

Everything below is verified absent (or stand-in) as of audit #3. Ordered by impact within each
category. `[bead]` = tracked. Blender split per workflow: Caleb poses/models, Claude stages/exports.

## 1. CHARACTERS (the biggest gap — ~55%)
- ~~**Civilians / villagers**~~ — **DONE 2026-07-12** (commit 5949b50). `civ_farmer_m` 1.62 /
  `civ_farmer_f` 1.52 / `civ_elder` 1.55 / `civ_kid` 1.26, barefoot under conical hats, plus
  `us_pilot_white` / `us_pilot_black`. Built on the v3 gear-cut base by `tools/make_civilians.py`,
  so they inherit the 100-clip library and the gib contract. Villages no longer need capsules. [4o7e]
- **RTO + PRC-25 radio backpack** — needed twice: worn by the RTO ally AND the handset reused as the
  player's FP support-call viewmodel. [i1vu, w8ep]
- **Slim-base remake of the 8 v1-rig characters** (us_grunt, us_grunt_black, us_medic, vc1/2/3/5/6) —
  v1 rigs can NEVER receive the shared anim library or family clips; until remade they're frozen at
  21 clips. PIGMAN switch to us_grunt_m60 (lfdg) unblocks him sooner. [4fgb, 4o7e]
- **Headgear library** — pith helmet, boonie, straw conical (VC), USMC utility cover, bare-head hair
  variants. [qcsb]
- **US visual variety** — helmet/torso/arm variants so the fireteam isn't clones. [qrzf]
- **NVA gunner for ZPU #2** + finalized sights mirrored. [htxn]
- **Gore stump painting** on gore_tex (gib cells exist, cells unpainted). [yp0g]

## 2. WEAPONS — FP models still on stand-ins
- **SKS** — shows a Kar98k. Enemy-common weapon, worst offender (capture hands you a WW2 rifle).
- **M79** — shows an MP40. Model already built in weapons_us.blend, needs FP hold + export.
- **CAR-15** — shows a Thompson.
- **FP radio handset** — blocks Batch 6 close. [of80]
- **M26 FP hold finalize + export** (model done, staged). [rzlk]
- **MX-991 flashlight two-prop export** (tunnel rat). [awip]
- **MuzzlePoint verify per arms scene** — zero current viewmodels expose one in Godot. [vi32]
- Period models if ratified: BAR, Kar98k(return), Nagant. [ycib]

## 3. ANIMATIONS (Caleb posing queue — priority order)
1. **mg family** 8-clip set — unblocks vc_sapper + PIGMAN (two units rifle-holding LMGs)
2. **launcher family** 8-clip set — nva_rpg rifle-holds the tube, worst visual read in combat
3. **bolt family** 8-clip set — mosin/m70 carriers
4. **pistol family** 8-clip set — lowest (no AI carries one yet)
5. **Family reloads** where the motion differs most: mg belt / bolt cycle / launcher muzzle-load
6. **Missing base clips:** grenade_throw, surrender_idle (hands-up), wounded_crawl,
   death_from_the_left (deaths currently favor one side), stumble_hit, heli_board/heli_exit
7. **Per-gun FP idle/fidget/inspect** (HL1-style; specs in fp_arms/IDLE_ANIM_SPEC.md). [4uuu]

## 4. VEHICLES / AIRCRAFT
- **C-47 Spooky** — still a stretched-box placeholder in-game. [y8ho]
- **Ordnance mounting** — 8 bomb/napalm/rocket-pod props exist, none attached to the F-4 or dropped.
- a4_skyhawk unwired (modeled, no scene).

## 5. STRUCTURES / WORLD
- **Building interiors (CQB kit)** — 0%; every building is a shell. Gated epic.
- **Tunnel interior kit** — entrance+ladder, corridors, rooms, props. [u0e0]
- **Roads** — none generated; RTS road_network port beaded. [4kmn]
- ~64 modeled+measured structures sit unplaced (placement/wiring work, not art).

## 6. UI ART
- Topo paper texture, medal/ribbon icons, MACV-SOG patch PNG, offer-card thumbnails. [fmc8 adjacent]

## 7. AUDIO (the emptiest bucket — ~10%)
- **Every weapon SFX is procedural-synth placeholder** — real foley set needed (or the synth bank
  bead 9qp6 ships first as bridge).
- **VO barks** — Vietnamese + US callouts for the bark system (lngs); voice_studio.py pipeline ready.
- More ambience beds (only jungle_day.mp3 is real; night/rain/river missing).

## 8. TEXTURE OPTIMIZATION (the real 85MB)
- **ar5c**: crop/downscale the 3600×5700 faction sheets per-character in Blender, re-point UVs,
  re-export. NOTE (audit #3 proven): the loose `*_better textures.png` are LIVE external deps of the
  GLB imports — do not delete from disk; shrink them at the source.
- kar98 stand-in texture set (~40MB) dies automatically when the real SKS lands.
- `.blend1` backups in art_source/characters/variants/ (~300MB untracked) — safe local cleanup.
