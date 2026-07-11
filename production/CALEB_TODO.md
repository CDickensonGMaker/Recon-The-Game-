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
- [x] ~~Remaining viewmodels: M60, RPD, PPSh, RPG-2~~ **DONE 2026-07-10 night** — plus
      Ithaca 37, M70 sniper, Colt 45: ALL hand-set + exported (ppsh/m60/rpg2/rpd/ithaca/
      m70/colt45`_fp.glb`, rifle_idle + MuzzlePoint contract, pose jsons captured)
- [ ] **Tunnel rat viewmodel**: pistol + MX-991 flashlight two-prop export (flashlight modeled
      w/ lens LightOrigin; hold staged; needs exporter two-prop extension + Caleb final pose)
- [ ] **M26 grenade hold + export** (model done, imported to arms file with nodes)
- [ ] Engine wiring for the 7 new viewmodels: `*_arms_viewmodel.tscn` + tres (pattern = m16/ak/mosin);
      shotgun also needs `shotgun.tres` + pellet-damage decision vs ADR-016
- [ ] Per-gun idle/fidget/check animations — specs ready in `fp_arms/IDLE_ANIM_SPEC.md` +
      `IK_ANIMATION_WORKFLOW.md` (follow-the-recipe now)
- [ ] FP radio handset raise (reuses the RTO handset asset)

## 3b. MODELED 2026-07-10 NIGHT (weapons_us.blend — all saved/committed)
- M26 hand grenade (lemon body/spoon/ring, 106v) · Colt 45 M1911 (research-based, Caleb-refined,
  M60-steel finish, 176v) · M79 rebuilt from ref photos (belly stock/ladder sight/40mm tube, 206v) ·
  MX-991 angle-head flashlight (112v, in fp_arms file) · fixed M60 w/ tracer belt swapped into batch ·
  Ithaca 37 completed (Caleb stock transplant) · M70 sniper rebuilt lean (212v, Caleb) ·
  guns relabeled/joined one-object-each · grunt animation pass same day (fixed reload, 23 new clips,
  jump_loop deleted, shared anim_library.glb pipeline + .bat export buttons)

## 4. PROPS / VEHICLES (one Blender session each)
- [ ] **us_grunt_v2 source cleanup** (gib code VERIFIED working 2026-07-10; the export itself
      is FINE — engine now re-applies your viewport intent: joined body renders, grunt_* gib
      donors hidden. These are .blend-side items, confirmed by MCP scene inspection):
      1. `cap_leg_l` has **0 vertices in the .blend** (never modeled — cap_leg_r has its 4).
         Model the cap quad or the left-leg stump renders hollow. `test_gore_rig` WARNs until then.
      2. Stray `canteen_l.001` is unparented (the other five are bone-parented to Hips) —
         parent it or delete it.
      3. Height: exports at 1.88m (k=0.913). Author AT 1.7132 per GAME_SCALE_STANDARD =
         zero rescale, hitzones land exactly.
      4. File is 13.4MB (mostly embedded texture) → the ar5c crop/downscale pass, target <2MB.
- [ ] **The gib set** — gib_arm/leg/head + 2-3 chunks + gore texture (game-side gib-swap v1
      NOW SHIPPED — `gib_system.gd` + `scenes/levels/gore_lab.tscn` bench; these standalone
      chunks upgrade explosions/multi-gib per `GORE_WORKFLOW.md` Phase 2)
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
