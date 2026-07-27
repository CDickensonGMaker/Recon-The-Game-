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

> **SUMMONER DECREE 2026-07-25 — MAIN PRIORITY: the Blender→Godot gun/arms PIPELINE.** Automate the
> animate→export→working-in-Godot loop. HUD is pushed to background/later (ADR-030 deferral
> re-confirmed). Pipeline build starts once you bless the M16-rig diagnosis + fix path (see the
> landmine note below). Your #1 below (the animation pass itself) rides on this pipeline being trusted.

The ordered queue for the next working session. #1 is the big-difference item.

> **RESOLVED 2026-07-26 (headless, blessed fix path):** the M16 rig contract is RESTORED in
> `fp_arms_rifle.blend` (`tools/fix_m16_rig_contract.py` — CHILD_OF hold_R→hand.R, fittings re-seated
> as gun children at their last-good offsets, mag hand_handoff re-inversed at the grab frame, the
> gun's non-uniform scale baked out) and m16/ak/m14 `_fp.glb` re-exported + structurally validated
> (markers byte-match last-good, sight radius 0.5964). **YOUR GODOT STEPS: open the project in 4.7
> (or run `godot --headless --import`) so the three GLBs reimport, then viewmodel editor → M16 →
> press V — the ADS align should now frame real sights.** Known debt: the M14's fittings sit
> root-level in the .blend (works by name-lookup; the pipeline validator flags it).

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
squad cohesion ever needs it. ~~**Temple/shrine art gap**~~ — CLOSED 2026-07-26: the generated prasat
set ships, `stamp_temple_shrine()` places it, and the temple root joins `temple_shrines`
(`scripts/world/site_planner.gd:809-832`).

---

## FOR THE NEXT AUDIT PASS — wire up the nine unplaced temple statues (noted 2026-07-26)

**Verdict class: UNFINISHED, not FOSSIL (ADR-023) — do NOT delete these models.** They are built,
exported, and collision-tabled; the shrine stamp just never grew past the stair group.

`tools/gen_temples.py` ships **14 statues** and all 14 have `collision_table.gd` entries (`"mesh":
true`). `scripts/world/site_planner.gd` is the only placer in the project, and its statue block
(`:834-852`) names **five**: `guardian_01`, `guardian_02`, `naga`, `seated`, `lingam`.

**Nine have zero placement callers repo-wide:** `altar`, `apsara_01`, `apsara_02`, `garuda`,
`singha_01`, `singha_02`, `stele`, `stupa`, `naga_rail`.

Roster proposed to Caleb, unruled — he picks before anything is built:
- **singha** pair as an alternate stair guard, rolled against the dvarapalas so not every shrine
  reads the same
- **apsara** relief slabs set flat against the non-entrance wall faces (they are wall panels, not
  free-standing figures — placement must respect that)
- **naga_rail** flanking the approach as a balustrade run, seated off the same `fwd`/`side` basis
  the guardians already use
- **stele · altar · stupa · garuda** scattered in the courtyard inside the 14m site radius

The `fwd`/`side`/`reach` basis at `:838-842` already does the hard part — anything added should reuse
it rather than re-deriving the door direction. Reach is manifest-driven, so it scales with the
temple's footprint for free.

---

## FP VIEWMODEL ANIMATIONS — measured defect list (2026-07-26)

Full report: `production/research/viewmodel_anim_defects_2026-07-26.md`.
Data: `production/research/viewmodel_rig_audit.json`. Re-run the probe with
`blender -b assets/player/arms/fp_arms_rifle.blend -P tools/audit_viewmodel_rigs.py --`.

### Mine, next session (headless, no animation authoring)
1. ~~**PPSh retime**~~ — **DONE 2026-07-26.** You ruled the timer follows the animation and that the
   export should write it. Shipped as **ADR-034 Amendment A**: `tools/sync_weapon_timers.py` reads
   each clip's length from the exported GLB and writes `reload_time` / `empty_reload_time` /
   `jam_clear_time` into the .tres; the export driver runs it every time; the validator now FAILS on
   drift. All four guns measure exactly 1.00× — the PPSh was 0.76× / 1.30× / 3.30×.
   **You accepted the balance change: PPSh jam clear 1.1s → 3.63s** (reload 3.4 → 2.6s, empty → 4.43s).
   Worth feeling in a playtest — it is a long time to be defenceless.
2. Fold the **frozen-hand** check into `tests/test_viewmodel_contract` so a dead limb fails the build
   instead of waiting for a playtest. (The clip-vs-timer half is now covered by the validator.)
3. Marker parenting: manifest says `markers_under_gun: true` for all four, but AK's markers parent to
   `AK47` and M14's to `M14_gun` (the mesh, not the root). Correct the claim or the parenting.

### Caleb's, in Blender (animation quality is his hands — standing ruling 2026-07-26)
1. **AK broken reload** — `ak_mag_handoff` is a 132f action mounted under BOTH the 78f `reload` and
   the 133f `reload_empty`. Authored for the long hand path, so the mag rides a hand that isn't there
   during the short reload.
2. **Frozen hands** — `hand.R` measures 0.00 mm/frame for the ENTIRE clip in M16 reload,
   reload_empty and jam, and in AK reload and M14 reload; `hand.L` is dead through M14 jam and
   charge_handle. Biggest single cause of "robotic".
3. **M16 modeling / sights / ADS markers.** One measured lead: `M16A1_gun` is the only gun root with
   a non-identity object rotation — (2.642°, −0.021°, 89.893°).
4. **M16 leftovers from 2026-07-26**: 4 single-face floaters (3 facing down), 2 open sheets in the
   join, and the old hand height still present in the reload/reload_empty/jam gripping segments
   (only `m16_fp_idle` was shifted).
5. **PPSh**: prototype clips to re-author; the bolt was never split off the gun so it is static in
   every clip; hand-in-gun penetration is worst on this gun by a wide margin (140mm vs the M16's 23).

### Two things NOT to do
- **Do not blame the export.** We ship glTF, not FBX. `bake_anim_simplify_factor` / `bake_anim_step` /
  `add_leaf_bones` are FBX-only. `export_viewmodel_clips.py:324-332` already forces sampling, disables
  animation-size optimisation and bakes every part frame-by-frame. Nothing simplifies a curve.
- **Never run "apply all transforms + set origins to the 3D cursor"** on `fp_arms_rifle.blend`. It
  destroys the PPSh's 27 authored non-uniform-proportion children, `M16A1_ch_rail`'s slider origin,
  and the parent-inverses on guns already blessed.

**Still unproven for every gun:** the clips have only ever been watched on the bench. Nobody has
confirmed they play correctly in-game through `weapon_holder`'s reload path.
