# AUDIT — Firebase ⟷ Animation Sync

**Date: 2026-08-24.** Read-only audit; no repo file was modified. Method: every `.glb` under
`assets/` was opened by a scratchpad Python script that parses the glTF JSON chunk and lists
animation clip names (709 GLBs scanned, 48 carry animations); every clip-name string the code
requests was collected by grep over `scripts/` (play / play_first / has_animation / pose_end_of /
clip_length call sites plus clip-name const tables) and cross-checked against the GLB inventory.
Line numbers cited are as of this date. This is findings only — no fixes were applied.

Reference inventory used throughout:
- `assets/shared/anim_library.glb` — 232 clips (the shared bank; measured this audit).
- `assets/nva_vc/characters/vc_guerilla*.glb` — 73 baked clips each + library merge.
- Every other character GLB (US ×11, NVA/VC ×16, civilians ×10) — **0 baked clips, mesh-only**,
  dependent on the library merge.
- `assets/world/building models/structures/firebase/fsb_main_v3.glb` — 13 baked clips, 14 skins.

---

## VERIFIED IN SYNC

1. **PSXRig merge contract holds across the whole cast.** All 42 character GLBs under
   `assets/{us,nva_vc,civilians}/characters/` carry a node literally named `PSXRig` plus one skin
   (measured this audit), so the merge gate at `scripts/visuals/model_actor.gd:293`
   (`get_node_or_null("PSXRig/Skeleton3D")`) passes and every mesh-only character receives the
   232-clip library (`model_actor.gd:286-316`).

2. **Chow hall (welded-to-root law).** The chow hall lives inside `fsb_main_v3.glb` — its markers
   (`chow_diner`×4, `chow_server`×4, `eat`×24, `queue`×3, `chow_trigger`, `chow_exit`,
   `chow_tray_return`, `cook_range`, `traycollector`, `trayhandoff`; measured this audit) are all
   registered in `FSB_WORK_OCCUPATION` (`scripts/world/site_planner.gd:882-921`). Every chow clip
   the diner/servery code requests (`scripts/world/civilian.gd:603-692`: `chow_carry_walk`,
   `chow_tray_carry_walk`, `chow_carry_step`, `chow_queue_walk`, `chow_queue_step`,
   `chow_tray_wait`, `chow_tray_receive`, `chow_tray_dump`, `chow_stand_up`, `chow_eat_standing`,
   `chow_eat_seated`, `chow_sit_down`, `chow_talk_seated_a/b`, `chow_serve_ladle`,
   `chow_tray_hold`, `chow_cook_stir/prep/check`) exists in `anim_library.glb`. Users find them.

3. **Garrison/camp clip chains resolve.** Automated cross-check of every quoted clip name in
   `scripts/` against the GLB inventory found exactly the misses listed under BROKEN below —
   everything else lands. Spot-verified tables: `Civilian.VILLAGE_ACTION_CLIPS`
   (`civilian.gd:67-77`), `OFF_DUTY_CHAINS` (`civilian.gd:79-95`), `_play_garrison` chains
   (`civilian.gd:559-716` — medic, patient, detail, mess_cook, gun_crew_arty, mess_hall,
   quartermaster, armed posts), `EnemyBase.CAMP_ROLE_CLIPS` (`enemy_base.gd:663-675`),
   `AllyBase.COVER_HOLD/PEEK/RUSH/STAND_COVER` chains (`ally_base.gd:396-416`),
   `AllyBase.CREW_STATION_CLIPS` (`ally_base.gd:587-591` → `mortar_gunner/dropper/runner`),
   `SeatSystem` pilot/gunner/pax clips (`seat_system.gd:107-157`; `m60_gunner_*` + `_l/_r` side
   suffix from `seat_system.gd:398-406` — all six exist in the library),
   `HeliLift.DISEMBARK_CLIPS`/`BOARD_CLIPS` (`heli_lift.gd:38-51`),
   `LitterTeam` (`litter_team.gd:102-107`), `GunCrewPerformance` seat clips
   (`gun_crew_performance.gd:19-22`), zombie chains (`zombie_base.gd:31-36`, one dead entry noted
   under ORPHANS), `MeleeVerb.TAKEDOWN_CLIP = "brutal_assassination"` (`melee_verb.gd:32`),
   sapper `PLANT_CLIP = "plant_charge"` (`sapper_charge.gd:21`), casualty haul `carry_wounded` /
   `being_carried` / `laying_breathless` (`enemy_base.gd:2799-2838`).

4. **SpriteStateMap tables.** Every clip in `MODEL_CLIP` and the four `OCTANT_CLIPS` families
   (`scripts/visuals/sprite_state_map.gd:253-292, 343-358`) exists in the library.
   `"death_forward"` (map value at `sprite_state_map.gd:263`) is not itself a library clip but
   resolves through `MODEL_ALIASES["death_forward"] → death_from_the_front`
   (`sprite_state_map.gd:308`) inside `ModelActor.play` (`model_actor.gd:1017-1022`). Working as
   designed.

5. **Mortar pit.** `scenes/world/mortar_pit.tscn:19-27` carries `station_gunner/dropper/runner`
   matching `MortarPit.STATIONS` (`scripts/world/mortar_pit.gd:22`) and
   `AllyBase.CREW_STATION_CLIPS` keys; `GarrisonDefender._claim_mortar_station`
   (`scripts/allies/garrison_defender.gd:165-186`) stamps the meta the ally reads. The scene's
   `M29` instances `m29_mortar.glb`, whose one clip is exactly the `"MC_MORTARAction"` that
   `mortar_pit.gd:50-52` plays. A firebase MortarPit is spawned at
   `scripts/missions/mission_generator.gd:970` and the camp mortar at `:1178`.

6. **fsb station markers.** 45 of 46 `work_*` marker types measured in `fsb_main_v3.glb` (487
   markers total) are either mapped in `FSB_WORK_OCCUPATION` (`site_planner.gd:882-929`) or are
   the deliberately-absent gun/mortar arty types clustered by `_arty_pits()`
   (`site_planner.gd:988-1000`). 14 of the 16 `FSB_MARKER_KEYS` (`site_planner.gd:830-838`)
   resolve (the two misses are BROKEN #2). Curated-post markers `SOCKET_A/B_001`,
   `mg_fire_point_001`, `bunker_los_point_001`, `tower_los_point_001`, `USSupplyDepot_001/007`,
   `FOOTPRINT_001-007`, `APPROACH_001` all present.

7. **Demo arc beats (`scripts/levels/demo_game.gd`).** Boot on bunk: authored `spawn_bunk_01/02`
   markers exist (`scenes/world/firebase_main.tscn:9-15`) and win by design
   (`scripts/main/game_flow.gd:152-186`). T+10 gate order: `patrol_gate_pos` derives from
   `SOCKET_A/B_001` + `FACE_OUT_001` (`site_planner.gd:1206-1222`), all present. AirTraffic and
   AmbientWar are built under exactly the names `demo_game.gd:152-159` and `:318` look up
   (`mission_generator.gd:263-268`). Siege beats reference `CASAirplane.Ordnance` and
   `AirTraffic.launch` profiles (`transit`/`lz_cycle`/`gun_orbit`) all handled at
   `scripts/ai/air_traffic.gd:231-241`. Aircraft prop clips: `SPIN_CLIPS`
   (`scripts/vehicles/rotor_spin.gd:19-20`) match `a1_skyraider.glb` (`A1_PropellerAction.001`)
   and `ac47_spooky_v2.glb` (`prop_spin`); the Huey/Chinook rotors are hand-spun by node name with
   loud warnings on a miss (`scripts/vehicles/helicopter.gd:56-69`).

8. **model_path() law.** No character `.glb` path is hardcoded anywhere outside
   `scripts/visuals/model_actor.gd` (grep of every `.glb` literal in `scripts/`; the other hits
   are props/vehicles/vegetation). The garrison, squad, siege and civilian spawners all resolve
   through `ModelActor.model_path()` / `setup()`. Law respected.

---

## BROKEN (referenced-but-missing / will no-op at runtime)

1. **`"crouching"` does not exist in any GLB.** `scripts/combat/burning.gd:36`
   (`const CLIP_COWER := "crouching"`), returned at `burning.gd:101`. No clip of that name in
   `anim_library.glb` or any character GLB (measured). Every COWER-style burning man fails the
   play and drops to `clip_alt()` = `stumble_hit` (`burning.gd:107-108`) via the callers'
   two-step (`scripts/allies/ally_base.gd:626-627`, `scripts/enemies/enemy_base.gd:573-574`,
   `scripts/world/civilian.gd:467-468`, `scripts/levels/burn_lab.gd:179-180`). The authored
   "folds up and takes it" beat has never rendered; one of three burn styles silently plays the
   stagger instead.

2. **Two curated garrison posts are dead — their markers are not in the GLB.**
   `GUN_POINT_001` and `APPROACH_002` are named in `FSB_MARKER_KEYS`
   (`site_planner.gd:833,837`) and in `FSB_GARRISON_POSTS` (`site_planner.gd:852,856`) but do not
   exist anywhere in `fsb_main_v3.glb` (all 3,000+ node names scanned) nor in
   `scenes/world/firebase_main.tscn` (only SpawnMarkers added). `fsb_garrison_plan` skips a
   missing marker silently (`site_planner.gd:1085-1088`), so: the 2-man `gun_crew` post never
   spawns and its mannable M60 (`mission_generator.gd:1044-1046`) is never placed, and the
   `mess_cook` post at APPROACH_002 never spawns. No warning is printed anywhere on this path.

3. **The VC camp never sleeps — `CAMP_ROLE_CLIPS["sleep"]` is unreachable.** The schedule enters
   role `sleep` 22:00-05:00 (`scripts/enemies/camp_director.gd:25`), but
   `_stations_for_role("sleep")` returns `[]` (`camp_director.gd:136-146` — only cook/talk/rest
   return stations), so every sleeper gets `work_pos = Vector3.ZERO`
   (`camp_director.gd:126-127`), and `_play_camp_role` refuses on a zero `work_pos`
   (`enemy_base.gd:718`). The chain `["sleeping_laying", "laying_idle", "sleeping_sitting",
   "sitting"]` (`enemy_base.gd:674`) can never fire: VC camps stand at the rifle idle all night.
   The comment at `camp_director.gd:135` ("Patrol/sleep/guard keep their posts") describes intent
   the code contradicts — sleep men are zeroed, not kept.

4. **fsb_main_v3.glb's baked aid-station/office cast never animates.** The GLB carries 14 skins —
   10 of them full 41-joint men (`OFF0/1/2_officer`, `PSXRig_med_or_patient`,
   `PSXRig_med_tend_medic0-2`, `PSXRig_med_work_medofficer_0-2`; measured this audit) — and 13
   baked clips targeting their `mixamorig:*` bones (`BEDA/BEDB/BEDC_attendantAction`,
   `med_officer_desk_o0/o1/o2`, `med_or_support_high/low`, `med_rounds_glance`,
   `med_wounded_idle`, `office_smoke`, `office_write`, `MC_MORTARAction.001`). **No code plays
   any of them**: the firebase build (`site_planner.gd:1324-1358`) never touches the GLB's
   AnimationPlayer, `_play_idle` is only called on stamped props and animals
   (`site_planner.gd:399,538`), and repo-wide grep for the clip names hits nothing. The baked
   surgeons/attendants render frozen in their export pose, and the GLB's baked mortar tubes
   (`US_MC_MORTAR`, driven by `MC_MORTARAction.001` — note the `.001` suffix, which
   `mortar_pit.gd:50`'s exact-match `"MC_MORTARAction"` would miss even if it looked here) never
   recoil. (The one *spawned* MortarPit is fine — see VERIFIED #5.)

5. **The howitzers never recoil: `M101Rig` has a rig but no clip, and its animated export is
   never instanced.** `GunCrewPerformance._bind_piece` searches for an AnimationPlayer carrying
   `"M101Rig"` (`gun_crew_performance.gd:43,240-250`). `fsb_main_v3.glb` ships four `M101Rig`
   *skins* but **zero** `M101Rig` *animation* (its 13 clips are listed in #4), so the bind fails
   at every pit — the crew mimes at a static gun. The export that carries the clip —
   `assets/world/building models/structures/firebase/kit/fb_emplacement_m101.glb` (14 clips:
   `M101Rig`, `MC_shell_carry/load`, `MC_casing_1-5`, `PSXRig_gunner/loader/agunner/ammo`…) and
   its twin `assets/us/artillery/us_artillery_m101.glb` — is referenced by **no script and no
   scene** (repo-wide grep). `gun_crew_performance.gd:40-42` admits this state and points at
   ART_GAPS_2026-08-07; still true on 2026-08-24.

---

## SUSPECT (needs the owner's eye or a runtime check)

1. **The US garrison never lies down either — a sleeping GI plays the loafing set.** Garrison
   schedules return `ACTION_SLEEP` (`scripts/ai/civilian_schedules.gd:110-112,131,138-140,
   174-176,247-249,263-265`), `_animate` maps `sleep` → want `"seated"`
   (`civilian.gd:485`), and the `is_garrison` branch (`civilian.gd:493-494`) exits into
   `_play_garrison` **before** the `VILLAGE_ACTION_CLIPS` branch (`civilian.gd:509`) — the only
   place `sleeping_laying`/`sleeping_sitting` are wired. An off-duty man on one of the **88**
   `work_hooch_sleep` markers at 02:00 plays `OFF_DUTY_CHAINS` (`civilian.gd:564-568` →
   smoking/arguing/jumping_jacks). May be half-intended ("A FIREBASE DOES NOT GO TO BED",
   `civilian_schedules.gd:102-107`) — but the schedule *does* issue SLEEP and the pose never
   matches it. Owner call.

2. **Zombie source GLBs are gone — only `.import` stubs remain.**
   `assets/zombies/characters/` holds `zed_cult.glb.import` and `zed_cult_b.glb.import` with **no
   `.glb` beside them** (listed this audit; consistent with the flash-drive move in project
   memory). `ModelActor.MODEL_DIRS` includes the folder (`model_actor.gd:17`) and
   `zombie_randomizer.gd:13` discovers `zed_*` from the filesystem — in an editor run the units
   will not resolve and the zombie cast falls to capsules/absence. Runtime check needed
   (`vc_zombies.bat`).

3. **A `work_med_root` marker falls through to off_duty.** One marker of type `med_root` exists
   in `fsb_main_v3.glb` (measured) and is absent from `FSB_WORK_OCCUPATION`
   (`site_planner.gd:882-929`), so it seats a loafer inside the aid station — the exact accident
   the hooch comment warns about (`site_planner.gd:920-924`). Probably an export-side root/anchor
   empty that should not be a station at all.

4. **Weapon-family holds exist only for SMG.** The library carries the `__smg` set alone
   (9 clips, measured); `WEAPON_FAMILY` also routes mg/bolt/launcher/pistol
   (`sprite_state_map.gd:390-397`), which all fall back to rifle holds via the strip at
   `model_actor.gd:1010-1014`, reported once per family (`model_actor.gd:985-998`). Known art
   gap, self-logging — listed so the RPD/M60/RPG carriers' rifle-grip is not re-diagnosed.

5. **Doc drift in load-bearing measurements.** `site_planner.gd:963` claims "fsb_main_v3.glb
   carries 191 work markers (measured)" — this audit measures **487**; the stride math still
   works but the comment is a stale pointer. `gun_crew_performance.gd:40` claims the fsb ships
   "STATIC howitzers (0 animations)" — true for `M101Rig` clips, but the GLB now carries four
   M101Rig *skins* and 13 other clips (see BROKEN #4/#5).

6. **`spider_hole.glb` lid clips never play.** The GLB carries `LidAction.002` and
   `DarkSlitAction`; the pop at `enemy_base.gd:958-974` only flips visibility/collision — no
   caller for either clip repo-wide. The lid never opens when the ambusher appears.
   (`punji_trap.gd:118-126` does play its door clips, exact names matched — the contrast case.)

---

## ORPHANS (exists, nothing references it — noted only, fossil triage is not this audit's)

- **Library clips with no play-path (literal scan, comments included):**
  `action_idle_to_standing_idle`, `cover_reposition`, `disembark_heli_FINAL`,
  `hop_off_heli`, `hop_off_heli_stumble`, `jump_away`, `jump_up`, `jump_up_2`,
  `mount_skid_step_FINAL`, `med_bearer_front/rear`, `med_officer_desk`, `med_or_support_high/low`,
  `med_rounds_glance`, `med_surgeon_table`, `med_tend_medic`, `med_tend_patient`,
  `med_wounded_idle`, `office_desk_transition`, `office_smoke`, `office_write`,
  `rifle_crouch_idle_to_walk`, `rifle_turn`, `salute`, `stop_walking_with_rifle`, `strafe_2`,
  `swimming`, `zombie_agonizing`, `zombie_death`, `zombie_dying`, `zombie_turn`.
  The med bay set is notable: the aid-station *markers* are wired (`site_planner.gd:912-914`) but
  the men on them play the generic medic/patient chains (`civilian.gd:578-585`), never the
  purpose-built `med_*` staging clips.
- **Hooch clips vs hooch markers:** `hooch_locker`, `hooch_poker`, `hooch_radio` exist in the
  library; the same-named markers map to `off_duty` (`site_planner.gd:923-924`) whose chains
  (`civilian.gd:79-95`) never include them. Authored hooch performances never play.
- **Deliberate non-wires (documented in place, not defects):** `cockpit_dead`
  (`seat_system.gd:105-107`), `pilot_flips_switches` (`seat_system.gd:109-111`),
  `signal_move_up` (`model_actor.gd:360-361`), `turn_90_left/right` + crouching turns
  (`sprite_state_map.gd:52-56`).
- **Orphan animated GLBs:** `fb_emplacement_m101.glb` / `us_artillery_m101.glb` (see BROKEN #5),
  `zpu_crewed_nva.glb` (25 clips incl. `PSXRig_zgunner/zloader`; `zpu_gun.gd:16` uses the
  unmanned `zpu_aa_gun.glb` instead), `us/characters/camp_clips/stretcher_carry.glb` and
  `stretcher_load_casualty.glb` (LitterTeam uses library clips + `fb_litter.glb`,
  `litter_team.gd:18,102-107`), `us/vehicles/heli_approach_land/heli_casualty_load/heli_liftoff/
  heli_troops_disembark.glb` (64-clip staged scenes; no script/scene reference found —
  consistent with the staged-scenes-are-not-clip-banks ruling, left to triage),
  `ac47_spooky.glb` `prop_stall_*` clips (spectre preloads `_v2`,
  `spectre_gunship.gd:11`), `us/vehicles/archive/huey_v1_ORIGINAL.glb` (archive).
- **Orphan scene marker:** `station_handoff` in `scenes/world/mortar_pit.tscn:28` — not in
  `MortarPit.STATIONS` (`mortar_pit.gd:22`) and not in `CREW_STATION_CLIPS`
  (`ally_base.gd:587-591`); no man can claim it and no clip is keyed to it.
- **Dead chain entry:** `"zombie_punching"` (`zombie_base.gd:34`) exists in no GLB; harmless —
  `zombie_attack` sits ahead of it in the chain.
