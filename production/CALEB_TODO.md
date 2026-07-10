# CALEB'S LIST — everything on YOUR plate (2026-07-10)

Everything code-side is built or beaded; this is the hands-on Blender/eyes work only you can do,
roughly in dependency order. Companion: `BLENDER_ASSET_LIST.md` (full asset detail).

## 1. CHARACTERS (the big one)
- [ ] **Finish the better-body remake for ALL units** — the slimmer base, then rebuild:
      us_grunt, us_grunt_black, us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy
- [ ] **Set weapon + arm models right on every unit** — gun attach nodes / hand alignment in the
      character rigs (your words: "align all the weapons up right")
- [ ] **Radioman (RTO)** — grunt + PRC-25 backpack + handset on a cord (the 10m radio leash +
      the FP handset raise both wait on this asset)
- [ ] Civilians (men/women/kids) — scripted events + village life need them
- [ ] Modular kit when ready: helmet/torso/arm variants for roster variety

## 2. HELICOPTER FLESH-OUT
- [ ] Interior: real seats, floor, door frames (walkable cabin)
- [ ] **Name the sockets in the glb**: `SeatDoorLeft`, `SeatDoorRight`, `SeatPilot`, `SeatCopilot` —
      code already looks for them and falls back to guessed offsets when missing
- [ ] Door-gunner position (M60 mount point)
- [ ] Confirm nose orientation after my 180° flip looks right in flight

## 3. FIRST-PERSON
- [ ] **Verify the arms placement** (my fix is a math guess — in-game eyes needed; tell me
      high/low/close and I nudge). Then: do the hands feel right at 75 FOV?
- [ ] Remaining viewmodels: **M60, RPD (LMG holds), PPSh (drum), RPG-2 (shoulder)** — new poses
- [ ] Per-gun idle/fidget/check animations — specs ready in `fp_arms/IDLE_ANIM_SPEC.md` +
      `IK_ANIMATION_WORKFLOW.md` (follow-the-recipe now)
- [ ] FP radio handset raise (reuses the RTO handset asset)

## 4. PROPS / VEHICLES (one Blender session each)
- [ ] **The gib set** — gib_arm/leg/head + 2-3 chunks + gore texture (unlocks dismemberment;
      everything else is already coded-ready per `GORE_WORKFLOW.md`)
- [ ] Claymore model (green box in-game) + Ka-Bar knife redo
- [ ] C-47 for Spooky (box placeholder) · ZPU/DShK AA gun (mg_nest stand-in)
- [ ] Optional: TOC interior dressing (map table, radios) — the HQ tent is now walk-up-and-brief

## 5. YOUR OTHER WINDOW'S BATCHES
- [ ] Review Batch 1 exports in-game (pow cage, ruins, ruinsets)
- [ ] Batch 2: tell me which models carry `-col` trimesh so I flag their collision entries

## 6. IN-GAME VERIFICATION PASSES (you play, I fix live via MCP)
- [ ] **The new loop**: NEW CAMPAIGN → pick operation → firebase → TOC briefing → board bird →
      mission → exfil → back at base → quit → CONTINUE puts you back at the base
- [ ] F5 quicksave / F9 quickload · rations [9] · weapon cleaning [0] when it fouls
- [ ] Tiny-units hunt: play near spawns, I read the [MODEL] prints
- [ ] Squad keys: F1-F4 vs the new C/H/X/N — which works on your keyboard?
- [ ] Feel checks: locational damage (head/gut/limb), blood (mist/splats/pools/wounds-on-allies),
      VO (Joe radio from the RTO's back, barks, VC shouts), F-4 napalm pass, rain squall fade
- [ ] Terrain chunk pop — reproduce while I watch the stream (bead filed)

## 7. DECISIONS ONLY YOU CAN MAKE
- [ ] Final squad voice assignments (Joe=radio locked; confirm John/Ryan/Norman roles felt right)
- [ ] Male vs female VC voices (pitch-shifted male sample was sent)
- [ ] Blood look sign-off (darker? chunkier? bigger?) — generator = one-line tweaks
- [ ] License-clear jungle ambience for release (current bed is a YouTube rip, dev-only)
