# CALEB'S LIST — everything on YOUR plate (2026-07-10)

Everything code-side is built or tracked here; this is the hands-on Blender/eyes work only you can do,
roughly in dependency order. Companion: `BLENDER_ASSET_LIST.md` (full asset detail).

## 1. CHARACTERS (the big one)
- [x Done but need NVA models and more US variety] **Finish the better-body remake for ALL units** — the slimmer base, then rebuild:
      us_grunt, us_grunt_black, us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy
- [WIP] **Set weapon + arm models right on every unit** — gun attach nodes / hand alignment in the
      character rigs (your words: "align all the weapons up right")
- [ x] **Radioman (RTO)** — grunt + PRC-25 backpack + handset on a cord (the 10m radio leash +
      the FP handset raise both wait on this asset)
- [x] Civilians (men/women/kids) — DONE 2026-07-12: civ_farmer_m/f, civ_elder, civ_kid + US pilots (black/white). `tools/make_civilians.py`
- [ Grunt Spawner Should be Made, we need to test this. I noticed that the custom helments I made havent been appearing.] Modular kit when ready: helmet/torso/arm variants for roster variety 

## 2. HELICOPTER FLESH-OUT (Need to spend a real day doing all of this.
- [ ] Interior: real seats, floor, door frames (walkable cabin)
- [ ] **Name the sockets in the glb**: `SeatDoorLeft`, `SeatDoorRight`, `SeatPilot`, `SeatCopilot` —
      code already looks for them and falls back to guessed offsets when missing
- [ ] Door-gunner position (M60 mount point)
- [ ] Confirm nose orientation after my 180° flip looks right in flight

## 3. FIRST-PERSON (in process of working on the movable weapon parts and the animations related to that)
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




## 6. IN-GAME VERIFICATION PASSES (you play, I fix live via MCP)
- [ ] **The patrol loop (ADR-029)**: NEW CAMPAIGN → seated at `fsb_main` → out the wire gate on one
      diegetic pointer → find a site unguided → fair contact → squad holds → AAR banks at the gate
      (`_bank_patrol`, `scripts/missions/field_director.gd:1066`) → quit → CONTINUE puts you back at the
      firebase. No briefing UI, no board-bird, no exfil step (ADR-029).
- [ ] F5 quicksave / F9 quickload · rations [9] · weapon cleaning [0] when it fouls
- [ ] **Field marks (NEW 7/25 — ADR-022 Amdt A)**: click [MIDDLE MOUSE] while aiming at an
      enemy / tunnel mouth / hut / trail (stand still; binos up if it's far) → toast fires →
      open [M]: a big blue pencil circle with the word on it. Marks must survive walking back
      in through the wire AND a quit/CONTINUE. Tell me: is the circle too big/small, does MMB
      feel right? (Your ruling: T or MMB — T is CAS, so MMB it is.)
- [ ] Tiny-units hunt: play near spawns, I read the [MODEL] prints
- [ ] Squad keys: F1-F4 vs the new C/H/X/N — which works on your keyboard?
- [ ] Feel checks: locational damage (head/gut/limb), blood (mist/splats/pools/wounds-on-allies),
      VO (Joe radio from the RTO's back, barks, VC shouts), F-4 napalm pass, rain squall fade
- [ ] Terrain chunk pop — reproduce while I watch the stream (bead filed)

## 7. DECISIONS ONLY YOU CAN MAKE
- [I haven't heard too many voices but I see the text that appears on the screen which is helpful. Well have to combine those two elements together ] Final squad voice assignments (Joe=radio locked; confirm John/Ryan/Norman roles felt right)
- [ ] Male vs female VC voices (pitch-shifted male sample was sent)
- [Would be cooler to have a more realistic blood effects when shooting people. It just kinda pools on people. I would like bodies to look bloodier and to have the bloodpools spray more and than spread more. ] Blood look sign-off (darker? chunkier? bigger?) — generator = one-line tweaks

---

## NEXT UP (Friday priority order — the strict list, no beads)

The ordered queue for the next working session. #1 is the big-difference item.

> **LANDMINE (2026-07-25 diagnosis): the working-tree `assets/player/viewmodels/m16_fp.glb` is a
> BROKEN export — do NOT commit it.** The M16's joined gun body (`M16A1_gun` in `fp_arms_rifle.blend`)
> lost its CHILD_OF→hand.R + NLA tracks + child markers when the 36→4 join replaced the old root, so
> the export ships a rifle detached from the hand at ruler coords (~+3.1m X). Last-good is HEAD's copy
> (`git checkout -- assets/player/viewmodels/m16_fp.glb`). Fix = restore the rig contract on M16A1_gun
> (copy the AK47_root pattern), re-export via `blender -b`, verify, THEN commit. AK/M14 rigs verified
> intact; their new clips just haven't been exported yet.

1. **WEAPON ANIMATION PASS** (the huge one). Do the movable gun parts + arm rig + animation in ONE
   pass per weapon (your workflow-saving strategy), then:
   - Make the gun PARTS that should move for animations move (bolt / charging handle / mag / trigger /
     cylinder per weapon — parts-level list to be mined from `assets/player/arms/IDLE_ANIM_SPEC.md`,
     `IK_ANIMATION_WORKFLOW.md`, `VIEWMODEL_ANIM_SPEC.md`, `production/WEAPON_ADS_WORKFLOW.md`).
   - **Restage / parent every weapon to the ARMS** ("align all the weapons up right").
   - **ADS lined up right** — verify arms placement in-game (you call high/low/close, I nudge); hands
     feel right at 75 FOV; ADS down the sights aligned per `ads_fov`.
   - **Export properly** — the `_fp.glb` + `rifle_idle` + MuzzlePoint contract (the DONE 7 are the
     pattern); then the engine wiring `*_arms_viewmodel.tscn` + `.tres` for the 7 new viewmodels.
   - (Detail already in §3 above + `ART_Track_Log.md §2`.)
2. **RADIOS PLAY CUSTOM RADIO SONGS** — wire the radio-support loop to your new Audacity broadcast
   mixes (AI + real period broadcasts + ads + hiss). FP handset raise reuses the RTO handset asset.
3. **HUEYS** — §2 above: name the sockets (`SeatDoorLeft/Right/Pilot/Copilot`), door-gunner M60 mount,
   walkable interior (seats/floor/frames), confirm nose orientation after the 180° flip.
4. **NVA VARIANTS** — `vc5_nva`, `vc6_heavy` models + finalized ZPU gunner (mannable by both factions).
5. **FLESHED-OUT VILLAGE BUILDINGS** — more geometry + interiors for CQB; clear-out playspaces.
6. **BETTER FIREBASE LAYOUT** — the "full day" detailed FSB pass.

---

## SALVAGED FROM BEADS (pre-retirement, 2026-07-22)

Beads is retired (it was closing work as "done" that wasn't). These were YOUR own feature specs that
lived only in the tracker — preserved here so they aren't lost. Corroborated live work already appears
in the sections above; this is the extra stuff. Rule on the flagged one when you get a moment.

- **Airfield location type** — a distinct location (max 1 per AO), far from the firebase, found under
  attack.
- **VC-execute-villagers scripted event** — on approach to the 3rd village, VC are executing villagers;
  the player may choose to intervene.
- **Rank progression** — rank unlocks weapons at the armory + a loadout/backpack menu.
- **Medic revive economy** — revive rules/limits for the medic.
- **NPCs trigger traps** — enemies/civilians can set off placed traps, not just the player.
- **Trap density / concealment** — how many traps, how hidden.
- **Pointman-leads order** — squad command to send the pointman ahead.
- **Squad competency: veteran vs cherry** — units differ in skill/nerve.
- **Squad morale: FIGHT → SURVIVE at 45%** — squad shifts from fighting to surviving below a strength
  threshold.
- **[RULE: keep or cut?] Prerendered-cinematic (Blender FMV) direction** — a four-cutscene FMV plan.
  Not mentioned in either current source-of-truth doc; flag it — is this still a direction you want, or
  is it dropped?


## Vehicle dash radio (Caleb, 2026-07-25)

A tiny in-cab version of the field radio inside drivable vehicles, playing music while
you drive. Implementation is nearly free — `scripts/props/radio_prop.gd` is already
drop-anywhere (folder-scanned tracks, positional player); the cab version is the same
prop with a small mesh, short hear_distance (~6m), and its own music tracks dir
(vs. the AFVN broadcast set). GATED ON: player-drivable vehicles, which the ADR-029
foot-only slice parks — build the radio the same wave driving ships. Music tracks
are an asset ask (period-legal music/AFVN-style music blocks) — separate from the
5 spoken broadcasts.

## From ghost-code audit 2026-07-25

**ANSWERED 2026-07-25 — the "what spends Team XP?" decision** (the audit's `buy_skill` stray,
`GHOST_CODE_AUDIT_2026-07-25.md:101`): nothing spends it, because it is no longer XP. The pool is
the player's HIDDEN reputation — never a number on screen; it surfaces as earned rank
(PVT→PFC→SP4→SGT→SSG) and as more weapons on the armorer's rack. `buy_skill` is deleted; allies
learn by doing only. Ruling + pointers: `production/adr/ADR-032-player-reputation-titles.md`.

Three roadmap seeds surfaced by the audit (corrected 2026-07-25, ghost-code audit). **Corpse-drag
mechanic** — the ragdoll half already exists (`model_actor.gd:674 ragdoll_bone`, `:682 wake_ragdoll`);
the grab mechanic that would use it was never built. Roadmap item, not cleanup. **Squad-regroup
behavior** — the `AIGoal.REGROUP` enum member was cut by ruling 7/25 (never scored, set, or matched),
but the behavior it named ("isolated soldier rejoins his squad") remains a valid future feature if
squad cohesion ever needs it. **Temple/shrine art gap** — the shrine-search intel feature is fully
coded player-side but no temple site is ever generated and no shrine model joins the `temple_shrines`
group; if the shrine-wiring agent reports an art gap (no temple/shrine model exists), that asset is
the missing third leg.
