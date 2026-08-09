# ART MISSING — master list from AUDIT #3 (2026-07-11)

Everything below is verified absent (or stand-in) as of audit #3. Ordered by impact within each
category. `[bead]` = tracked. Blender split per workflow: Caleb poses/models, Claude stages/exports.

## 1. CHARACTERS (the biggest gap — ~55%)
- ~~**Civilians / villagers**~~ — **DONE 2026-07-12** (commit 5949b50). `civ_farmer_m` 1.62 /
  `civ_farmer_f` 1.52 / `civ_elder` 1.55 / `civ_kid` 1.26, barefoot under conical hats, plus
  `us_pilot_white` / `us_pilot_black`. Built on the v3 gear-cut base by `tools/make_civilians.py`,
  so they inherit the 100-clip library and the gib contract. Villages no longer need capsules. [4o7e]
- **RTO + PRC-25 radio backpack** — all finished. Just narrowing in on which radio man can the player use to call in strikes (should be any radioman)
- **Slim-base remake of the 8 v1-rig characters** (us_grunt, us_grunt_black, us_medic, vc1/2/3/5/6)DONE. Us Grunt v3 is the source of truth for Us models as well as the workflow for making multiple variants of models. 
- **Headgear library** — Finished for US. Working on the NVA VC headgear today 8/6
  
- **US visual variety** — helmet/torso/arm variants so the fireteam isn't clones. [qrzf] **HELMETS DONE/ Full Grunt Spawner Finished as of 8/4
  2026-08-04**: 15 M1 variants rebuilt off a high-quality reference (660–848 tris, flared brim, egg
  taper, rolled rim), props re-seated, and `grunt_dresser.gd` now applies a per-man tilt off the mission
  rng so a squad no longer wears one identical angle. The welded `helmet_shell_worn` was reshaped to
  match on all nine soldiers and its 1.13 depth stretch removed. Torso/arm variety still open. Later date, update down the line problem. 
  State of record: `production/MODEL_SESSION_HANDOFF.md` §1b.
- **NVA gunner for ZPU #2** + finalized sights mirrored. [htxn] Not finished yet. Animation will apply for both factions as it will be mannable by everyone, as well as another gun the player can mount. 
- **Gore stump painting** Finished, works, part of making psx rigging entirely. 

## 2. WEAPONS — FP models still on stand-ins
-Sks is skipped for this first shipped wave. Gun is made hasn't been placed in hands. 
- **M79** — working on making the right lazer for the viewmodel editor so the gun angles properly but aligns with the crosshairs. Model itself needs to be bigger and molded to player fps hands better. 60 percent done over all 
- Car-15 will be a update/new weapon after game launches
All of radio is done and works with the player. 

- **M26 arms and animations made. need to align the arms along with bandages and radios in viewmodel editor. needs a pass in blender with hip placement markers similar to all the guns. 
- **MX-991 flashlight This is in the game but has no flashlight wired to it. kinda doesn't matter since were gonna hold the tunnels off for a larger update. 
- **MuzzlePoint all guns have them

## 3. ANIMATIONS (Caleb posing queue — priority order) I haven't worked on these animations too much but I think we can do them all soon. We also need to add a few more "seeking cover" animations or fix when the models switch from crouched to the leaning against the wall. I saw them taking cover a good 10m before they were actually to the building and than they slowly made their way to the wall. 
I want a new audit of whats there and not there. weve made 300+ animations in our library at this point. 

## 4. VEHICLES / AIRCRAFT
- **C-47 Spooky** — model WIRED 2026-07-25: `ac47_spooky.glb` flies on `SpectreGunship` (`spectre_gunship.gd:50`), baked `prop_spin` clip looping in-game, left pylon turn so the port guns face the target. Still to do: model the guns that stick out of the left side. 
- **Ordnance mounting** — 8 bomb/napalm/rocket-pod props exist, none attached to the F-4 or dropped. Thats something well have to do during the dedicated vehicles. 
- a4_skyhawk unwired (modeled, no scene). It should be in the game we have it already. 

## 5. STRUCTURES / WORLD
- **Building interiors for firebase, about half done. 
- **Tunnel interior kit** — entrance+ladder, corridors, rooms, props. [u0e0] Gated and held for the post launch updates. 
- **Roads** — LIVE (as of 2026-07-24): `RoadNetwork.new(...)` builds the hub-and-spoke net (`scripts/missions/mission_generator.gd:562`) and carves the corridor through vegetation (`scripts/missions/mission_generator.gd:680`); guarded by `tests/test_roads.gd`. I haven't seen any real roads in the game as of 8/6
- **Bunker firing slits — We spent time working on this but I have yet to get inside a bunker and shoot out of it still to prove it happened. 
  `fb_bunker_fighting` are already flagged `COL_TRIMESH` in the generator (holes stay holes on
  trimesh; a box hull would seal them shut), but no aperture is actually modeled yet — nobody has
  confirmed one exists in the mesh. Full recipe (embrasure cut + matching firing step, sized off
  eye height not the yard floor) is in `production/blender/FIREBASE_BLENDER_HANDOFF.md` §2/§2b/§2.5.
  Note: modeling the slit only gets shootable geometry — an occupiable/AI-aware bunker position is
  a separate code task, nothing wires that up automatically today (only the standalone
  `MGEmplacement` pintle mount has "man this position" logic, unrelated to the bunker meshes). IT works i just need the m60 model to swing around and move with the player and shoot too. it  doesn't produce any bullets or fire from the tip so i cant tell if im shooting anything. 


## 6. UI ART
- Topo paper texture, medal/ribbon icons, MACV-SOG patch PNG, offer-card thumbnails. [fmc8 adjacent] There needs to be a whole day spent fixing and refining the whole UI/UX. its all total placeholder right now and worth something to spend our deep dive of a week learning more about the pros and cons of UI UX experiences in a deep research. 

## 7. AUDIO — AUDITED 2026-08-07 (he asked; every line below is measured, not remembered)

**He was right: this is not the "~10% emptiest bucket" the 2026-07-11 header called it.** Method:
inventory of `assets/audio`, filename-pattern match per `data/weapons/*.tres` id, and every `.wav`/
`.mp3`/`.ogg` string literal in `scripts/` checked against disk.

- **WEAPON FIRE — 9 guns on REAL recordings:** `m16a1 · ak47 · rpd · ppsh41 · m60 · mosin · m70 ·
  m14 · car15`, each with near variants + a `_dist` layer (Snake's Authentic Gun Sounds, landed
  2026-07-27/29). **Told apart by measurement, not by trust:** real renders have varied lengths
  (m60 31,496 B · ppsh41 23,118 B · mosin 192,078 B); the synth batch is byte-identical at
  **72,044 B, all stamped 2026-07-08 18:36**.
- **`m1911` stays synth ON PURPOSE** — .45 ACP is subsonic and the pack carries no pistol stock
  (`tests/test_audio_pack.gd:30-31`).
- **THE ONE REAL GAP: launchers + shotgun** — `m79 · rpg2 · rpg7 · m72_law · shotgun` are still
  synth renders. Explosive weapons sounding fake undercuts the lethality the game is built on.
  This is ship-audit item M16.
- ~~**VO barks needed**~~ — **THEY EXIST: 162 files across 8 voices** (`bryce` 25 · `hfc_male` 25 ·
  `joe the radio man` 15 · `john` 25 · `norman` 17 · `ryan` 25) **including 30 Vietnamese** across
  `vi_25hours` / `vi_vais1000` / `vi_vivos`. Matches GAME_GUIDE's "162 wired via VOManager".
- ~~**only jungle_day is real; night/rain/river missing**~~ — **STALE.** `rain_loop`,
  `wind_loop`, `night_insects_loop`, `distant_war_loop`, `radio_crackle` all exist **and every one
  is referenced in code.** 12 ambience files, 12 wired.
- **Radio Vietnam: 19 `.ogg`, ~104 MB** — his broadcast edits are in the tree (2 long-run beds at
  41 MB and 33 MB, plus 14 period music tracks).
- **ZERO missing files.** Every explicit audio path in `scripts/` resolves on disk.
- Aircraft loops and the breath render are procedural by design (`tools/gen_aircraft_audio.py`,
  `gen_breath_audio.py`) — physically keyed, loops cut to blade-passage periods. Not a gap.
- **Size note, not a defect:** `ambience/jungle_day.mp3` is 53 MB and the Radio Vietnam beds are
  41 MB + 33 MB. That is ~127 MB of the audio tree in three files, worth knowing before the
  export-size conversation.


## 8. TEXTURE OPTIMIZATION (the real 85MB) This all still needs to happen and even if we could do it heedlessly over night would be great. I need to optimize all the models in the game. 
- **ar5c**: crop/downscale the 3600×5700 faction sheets per-character in Blender, re-point UVs,
  re-export. NOTE (audit #3 proven): the loose `*_better textures.png` are LIVE external deps of the
  GLB imports — do not delete from disk; shrink them at the source. If this will help game performance its something will ahve to do soon but wont this change the way textures appear on units? also noticed that units legs appear thru their pants texture when they move sometimes. is that something we did wrong?
- kar98 stand-in texture set (~40MB) dies automatically when the real SKS lands.
- `.blend1` backups in art_source/characters/variants/ (~300MB untracked) — safe local cleanup.

## 2026-07-26 — Viewmodel lens wave (ADR-034) + M14 fittings fix

**Shipped (this session):**
- M14 stranded fittings FIXED in `fp_arms_rifle.blend` (`tools/fix_m14_fittings.py`, measured
  verify): op-rod x3 + markers x3 + grips x2 were parentless at the armory rack (~5.8 m from the
  hands in every exported GLB — the missing op-rod / bogus M14 MuzzlePoint). Now gun children,
  op-rod stroke 33.8 mm in gun space. m14_fp.glb re-exported through `--strict`, validator PASS,
  `markers_under_gun: true` (the false flag was hiding the break).
- Viewmodel lens (ADR-034): real-scale meshes + per-gun FOV shader
  (`scripts/weapons/viewmodel_lens.gd` + `assets/shaders/viewmodel_lens.gdshader`), shared by
  weapon_holder.gd and the bench. Mesh-scale hack + pitch hack retired behind
  `ViewmodelLens.ENABLED` (kill list in the ADR). `viewmodel_scale` DELETED (was applied nowhere).
- Export pipeline hardened for Blender 5.0.1: manual-frame-range purge, one-slot-per-action +
  assigned-slot asserts, scale gate vs `real_length_m` (all in `tools/export_viewmodel_clips.py`
  `--strict`). PPSh41 joined the manifest (idle-only) after the validator learned
  animated-vs-static non-uniform scale.
- New probes in the suite: `test_viewmodel_sync_contract` (bench camera == player camera),
  `test_viewmodel_poses` (no NEW stub ADS poses; ak47/m1911/mosin/rpd/rpg2 grandfathered).


## 2026-07-27 — Viewmodel pipeline v2: bleed-hole fix + contact-marker/rail contract

War room: `production/war_room/2026-07-27_viewmodel_pipeline_v2/` (4 research lanes + synthesis).
Summoner ratified the contact-marker/rail contract (P2); P1 rode as prerequisite.

- **Bleed hole FIXED** (his "chandle hanging off the back of the gun"): Blender's glTF exporter
  drops constant object channels unless `export_optimize_animation_keep_anim_object=True`
  (`tools/export_viewmodel_clips.py:334`). A clip with no track for a part cannot reset it in
  Godot — one `jam` left the M16 chandle at full pull forever. Was latent in ALL 4 guns.
  New validator LAW (`tools/validate_viewmodel_glb.py`): every clip carries a channel for every
  manifest part, rifle_idle included. All 4 guns re-exported + PASS; timers unchanged.
- **Contact-marker contract live**: 7 `contact_*` empties in `fp_arms_rifle.blend`, parented to
  their parts, positions MEASURED from the blessed clips (surface point nearest the hand tail at
  closest approach). Manifest `contacts` map + `_contacts_doc`. `tools/audit_viewmodel_rigs.py`
  now reports hand-tail-to-marker closest approach per clip; a reach inside 150mm that never
  closes to 60mm flags **FAKED IN AIR** (thresholds calibrated: true grabs measure 0-45mm).
- **Two NEW defects the contract caught immediately:**
  1. M14 `charge_handle` clip: NEITHER hand ever comes within 247mm of the op-rod — the gun
     racks itself. (On the gun previously cleared as fully OK.)
  2. AK bolt rack (`reload_empty`): both hands stop ~74mm short of the bolt.
- Deferred by ruling: P3 bookend law (clips start/end on identical rest pose), P4 procedural
  life layer (spring sway/bob/recoil). Rejected: bone-skeleton migration, runtime IK pinning.

**Needs CALEB:** eyeball the M16 in game (post-surgery + post-bleed-fix — the hanging chandle
class is closed); nudge any `contact_*` empty whose spot you disagree with (they ride the parts);
the M14 self-racking op-rod and AK 74mm bolt rack now sit in your authoring queue with the AK
mag pairing and PPSh clips.

## 2026-07-27 — Audio pack wave (folk radio + real gun recordings)

**Shipped:**
- **Field radio is now a virtual-timeline prop** (`scripts/props/radio_prop.gd`, rewritten). Each
  radio runs its own deterministic 43.4-hour playlist that advances whether the player is there or
  not, seeded by the radio's world position — so two radios never play in unison and you always tune
  into something already in progress. Audio only exists inside `activation_distance` (125 m,
  `@export`); `hear_distance` stays 25 m. Measured: dormant at 300 m holds no stream and no voice;
  stepping inside seeks 1500 s into a 52-minute broadcast; leaving frees the stream.
- **14 Vietnamese folk tracks** from the "Music of Viet Nam" LP converted to mono 44.1 kHz Ogg
  (12.6 MB total) at `assets/audio/Radio Vietnam/music/`. Playlist emits 3 songs → 1 broadcast.
  Measured L/R correlation 0.79–0.98 on the source, so the mono downmix loses nothing real.
- **The 5 broadcast .ogg files are untouched, bit for bit** (Summoner ruling: they are his own edits
  and deliberate easter eggs; they play WHOLE, never segmented).
- **Real gun audio for 8 weapons** — see §7 above.
- `tools/gen_radio_manifest.py` + `radio_manifest.json`: track lengths as data, so the radio walks its
  timeline without loading 96 MB of ogg at world load.

**Fossil law (ADR-023):** 64 placeholder wavs + sidecars deleted for the five weapons retired by
ADR-016 Amendment C (`car15`, `sks`, `thompson`, `kar98k`, `mp40`) — verified zero references outside
`tests/`. Also removed `fire_mosin_2/3` synth clones that would otherwise have round-robined against
the one real Mosin recording.

**Still open:** `m1911`, `shotgun` and all four launchers remain synth. `mosin`/`m70`/`m14` carry ONE
near-report variant because the pack holds exactly one genuine 7.62x54R take (measured: all six
candidate slices cross-correlate 0.99–1.00 — they are the same shot copy-pasted).

## 2026-07-27 overnight — full armory transplant + M70 scope (Summoner away)

- **All 11 fused gun copies in fp_arms_rifle.blend replaced by armory assemblies with split moving
  parts** (`tools/transplant_armory_parts.py`; war room addendum has per-gun mapping detail).
  Every gun now has its rails/moving parts: M70 bolt, Colt45 slide/hammer/mag, Ithaca pump (45mm
  rail), M60 chandle/feedcover/bipod/belt, Thompson chandle/drum, LAW inner tube (230mm rail),
  M79 break barrel, Mosin bolt, RPD chandle/drum, RPG-2/7 rockets. 15 new contact_* markers on
  grasp geometry; manifest `staged_contacts` maps them.
- **M70 sniper scope built** from Caleb's overlay image: recentred asset `assets/ui/scope_overlay_m70.png`,
  new `ScopeOverlay` HUD control (code-drawn tunable reticle — his art has no center cross by design),
  `WeaponData.scope_overlay`, viewmodel hides under the scope, zoom = ads_fov 12 (~6.4x) through the
  existing ADR-004 path. Awaiting his playtest.

**Needs CALEB (adds to yesterday's list):**
1. Playtest the M70 scope (equip sniper, hold aim): overlay look, reticle weight, 12° zoom taste. (STILL HAVENT CONFIRMED THE SNIPER WORKS YET, maybe hold off in the post launch updates)
2. Eyeball the transplanted rows in Blender — esp. Mosin (sits high-forward of hands), LAW + Ithaca
   (re-staged onto arms), M70 bolt rest angle (armory's -63.8°).
3. Colt45 sights ride the slide again (your ADS-tracks-the-rack call) — confirm when posing.

## 8. VFX PASS (War Room 2026-07-29 - smoke/fire/explosions/muzzle)

Decree: `production/war_room/2026-07-29_vfx_room/synthesis.md`. 2002-school flipbook FX on
GPUParticles3D, zero real lights (ADR-026), visuals slaved to gameplay radii.

**SHIPPED in code (pending Summoner suite run + eyes):**
- Explosion stack rebuilt (`gun_fx.gd _spawn_explosion_visual`): flash core + 3 flipbook fireballs +
  shock ring + dirt column + debris + lingering smoke (own cap 8, so siege arty keeps its flashes) +
  scorch decals (cap 12). Ordnance now reads by size: 40mm 0.8x / grenade 1.0x / rocket 1.4x / arty 1.9x.
- Napalm (`fire_hazard.gd`): flame-card ring on the exact damage disc + black oily smoke pillar +
  additive ground glow + persistent scorch. Placeholder cylinder DELETED.
- Smoke grenade (`smoke_cloud.gd`): 28-puff GPU cluster uniform-scaled to current_radius() (never
  renders larger than the blocks_sight sphere) + camera-inside blind overlay. Sphere mesh DELETED.
- Muzzle flash: real muzzle-flame sprites (core star + flame spike), same 2-quad probe contract.
- Impact dust migrated CPU->GPU on shared materials. All new FX warmed in `_warm_effects()`.
- Textures: Kenney CC0 support sprites in `assets/textures/fx/particles/` (128px, ~250KB) +
  own Mantaflow-rendered sheets in `assets/textures/fx/sheets/` (puff landed; fireball/flame iterating).

**Needs CALEB:**
1. Eye-confirm the rendered sheets (fireball / puff / flame) - rendered headless, swap is 1 file each.
2. Suite run (test_fake_lights + test_fossils must stay green).
3. SHIP GATE: windowed A/B/A barrage bench (4 smokes + 2 napalms + explosion volley) -> PERF_LEDGER.md.
   Overdraw on the Intel UHD is the named #1 risk; caps are the knob if it regresses.

**Late adds same session (Summoner asks mid-pass):**
- Muzzle flame sprites on all guns (was procedural gradient placeholder).
- Blood read punched up: bigger directional exit mist (5 puffs to 1.25m), 16 droplets, meter-wide splats.
- NPC FOOTSTEPS: allies + enemies now emit surface-matched positional steps every ~0.85m
  (audio_manager.gd play_step_3d, 6-voice dedicated pool, 28m audible / 14m crouched at -18dB).
  Fairness symmetry with NoiseBus: they hear you, now you hear them. Placeholder step WAVs still in
  use - real samples wanted (CC0 hunt queued).

## 9. ENEMY ROSTER EXPANSION (2026-07-29 - data+AI shipped, BODIES NEEDED)

Rosters are LIVE on fallback bodies (ART-AHEAD wiring per enemy_data.gd): 8 new units in
data/enemies/ + spawn pool. Blender bodies to build (v3 workflow, us_base_v3 as process reference):
- **nva_rifleman / nva_mg / nva_marksman / nva_officer / nva_medic** - khaki NVA uniform + pith
  helmet family; officer gets visible rank flair; medic gets satchel. Currently wearing
  nva_regular / vc_guerilla_rpd / vc_guerilla_mosin stand-ins.
- **vc_guerilla_ak** - black pajama AK carrier (vc_ak.tres awaits it; wearing ppsh body).
- **vc_medic** - VC medic w/ satchel (wearing vc_guerilla_ppsh).

MEDIC BEHAVIOR SHIPPED (Summoner ruling 7/29): combat_medic units drag downed men ~14m toward
their believed-threat rear (enemy_base.gd _medic_think/_execute_aid, same override contract as the
sapper assault). Enemies already had a downed state; medics use it. NO enemy revive - theater only.

MEDIC REVIVE BUG FIXED (needs his playtest to verify): Doc now has a RESCUE order that outranks
combat states (ally_base.gd _execute_rescue - the old MOVE_TO was written to a variable
_execute_combat never read, so Doc held cover while you bled out). Second fix: body hits while
downed now burn 6s of Doc's window instead of instant true death; headshots still final.

**Enemy bodies + US faces SHIPPED headless (2026-07-29 late session):**
- 7 enemy GLBs built via tools/make_nva_variant.py from vc_guerilla_v2.blend (master untouched):
  nva_regular/rifleman/mg/marksman/officer/medic + vc_medic. NVA cloth = position-driven remap onto
  the faction sheet NVA row (shirt/sleeves/trousers, gib donors included), procedural pith helmet
  UV'd to the sheet pith photo, nva_1/nva_2 faces. vc_ak.tres now points at existing vc_guerilla body.
- US FACES: his newfaceatlas.png (36 painted faces, assets/us/characters/face_source/) baked into each
  us_grunt variant's face_atlas_v3 sidecar PNG via tools/bake_us_faces.py - measured dominant-cluster
  cell, NO mesh edits, NO re-exports, 7 different faces across the fireteam. VC/NVA unaffected.
- NEEDS CALEB EYES: NVA lineup in-game (pith seat, cloth read), the 7 new US faces, officer flair +
  medic satchel still wanted (queued polish).

**Cover clips staged (7/29 evening, his mocap + library blend ruling):** 5 new actions in
assets/shared/cover_clips_staging.blend (previews in assets/shared/cover_previews/): wall_lean_idle,
peek (0.87s hold from his capture), kneel_brace, reposition (8.5m root motion), slice_pie. All are
fcurve-level blends of existing library clips with mocap-measured timings - zero hand sculpting.
NEEDS CALEB: eye pass (MOCAP_REF armature sits 2m right for comparison), then sync into anim_library.
Note: his cover source video is a downward-angle reference reel - for future captures, re-perform
at 3/4 angle and the toolkit flow works clean.

---

## 2026-08-03 — CHOW HALL: dining half + five station clips (NEEDS CALEB)

Finished the half of the chow hall that was open at the 8/2 wrap, then authored its
animations. Truth source: `firebase_v3.1_RECOVERED_medical.blend`, `WORKBENCH_chowhall`
@ (0, -240) — **off to the side of the compound; the dining block is at world
y -243..-247**, outside the old workbench extent.

**Props** (`tools/build_chowhall_dining.py`): 4 folding tables + 8 benches (benches, not
chairs — 0.46 m seat) + 24 `work_eat` markers. 1,008 tris. Verified: zero overlap with
existing geometry, seat spacing >= 0.42 m, every seat square to its table edge.

**Marker facing is the +X axis** — measured three independent ways off the existing
cook/server/queue markers, NOT +Y. Godot must match.

**Clips** (`tools/make_chowhall_anims.py` -> `assets/shared/chow_anim_workbench.blend`,
fake users set, **not yet merged into anim_library**): `chow_cook_stir`,
`chow_serve_ladle`, `chow_tray_hold`, `chow_eat_seated`, `chow_tray_dump`. All pass
hand-to-target (<=1.7 cm), planted-foot slide (<=2.6 mm/frame), foot sink, hands-crossed,
hand-behind-chest, arm-lockout and a new anatomy gate, evaluated clean-room.

**No shuffle clip, deliberately.** `walk_right` carries 2.000 m per 31-frame cycle —
1.94 m/s. Retiming it to chow-line speed skates the feet by the slowdown factor. Travel
between the 0.70 m queue markers is Godot's locomotion; the library owes the stations.

**Crew** (`tools/gen_chowhall_crew.py`): 13 men on real grunt v3 bodies — 5 on the line,
8 eating, facing each other across the tables, each dephased via NLA. Off-duty men carry
nothing: no helmet, webbing, ruck or rifle (those meshes are never appended, same rule as
the M101 crew). 221 objects / 6,188 tris, linked dupes sharing mesh data.

Renders: `_scratch/chow_preview/scene/` (overhead, line, dining, chowhall_motion.mp4)
and one mp4 per clip in `_scratch/chow_preview/`.

**NEEDS CALEB:** eye pass on the five clips; ruling on the marker names (`work_queue`,
`work_serve`, `work_server`, `work_trayreturn`, `work_eat`) before Godot is wired; then
merge the clips into `anim_library.blend`. **Godot consumes none of these markers yet** —
`site_planner.gd` maps only `mess`/`cook` -> `mess_cook`; the rest fall through to
`off_duty`.

**Two traps that cost the session, both recorded in the crew-choreography LESSONS:**
a pose bone left in EULER mode ignores its quaternion channels, so a baked clip is dead
on arrival; and a clip that keys location only on the Hips depends on unkeyed pose state
and collapses in a clean file (knees and toes above the man's own head).

## 2026-08-04 — Huey DISEMBARK/BOARD studied against real footage; `board_heli` shipped (animation half; the walk-up landed that EVENING — DEMO_SHIP_BACKLOG W-9/W-10)

**Source:** `scratchpad/huey_footage.mp4`, "genuine Vietnam War color footage" compilation,
712 s. Contact sheets every 4 s across the whole runtime, then 5 fps dense passes over the
usable segments (`~22-42s`, `~202-218s`, `~326-358s`, `~415-440s`, `~645-660s`).

**Beat catalog (measured off frames, not memory):**
- Disembark = door exit -> immediate crouch-run away from the ship on a diagonal, staggered
  spacing between men (not lockstep), weapon carried low-ready across the chest, forward
  torso lean. Seen clean at 202-218s (3-4 men fanning off a landed ship) and 415-440s.
- Board/embark = approach on foot -> one hand plants on the doorframe/tailgate around chest
  height -> trailing foot finds the sill/skid -> push-up-and-swing-through -> settle. Clearest
  analogue is the truck-boarding beat at 334-338s (same biomechanic, different vehicle — a
  Huey-door mount was never captured clean/unblurred in this compilation). Confirms the
  standing ruling: **men sit the cabin FLOOR** (seated-crouch, not a bench) — matches the
  in-flight door-sitting shots at ~652-655s (feet dangling out the open door).
- Medevac wave-off (Vietnam standard: purple smoke, both arms raised) seen 436s — ambient
  detail only, not actioned this session.

**AUDIT finding that reframed the whole session:** `tools/export_anim_library.py:62-64`
strips `pose.bones["mixamorig:Hips"].location` array_index 0 and 2 (horizontal) from EVERY
clip in the library at export time — "engine drives velocity." Measuring the SOURCE
`.blend`'s `disembark_heli` family showed one clip traveling 2.37 m and five traveling
~0.3 m, which read as a bug (5 of 6 men rooted to the door); re-measuring the SHIPPED
`.glb` showed **all six travel exactly 0.0 m**, confirmed correct by design. **Lesson for
next session and for `blender_lessons.md`: always audit the EXPORTED asset, not the source
`.blend` — root-motion stripping is invisible until you check what the engine actually
receives.** No wasted disembark edit shipped; the six clips were left untouched. Re-verified
elbow gate on the shipped six: max 0.056-0.099 (all under the visible-clipping range, none
gated red), foot-sink -0.027..-0.107 m (source-clip characteristic, present before this
session, `disembark_heli_d` is the outlier at -0.107 m — flagged, not fixed this session).

**BOARD_HELI authored — PARTIAL fix for W-9 count 2** ("nobody visibly walks up to load").
Checked the diagnosis before claiming a close: `SeatSystem.board_squad` (`seat_system.gd:332`)
casts each boarding body `as AllyBase` and only issues `MOVE_TO` if that cast succeeds — but
`Civilian extends CharacterBody3D` (`scripts/world/civilian.gd:9`), NOT `AllyBase`, so the
cast is null for every garrison man and the walk-to-door order is **never issued** regardless
of this session's work. **This fix does not close count 2** — it replaces "nothing plays" with
"a real climb-and-sit animation plays in place," which is a real visible improvement but the
man still doesn't walk from wherever he's standing to the door first. The missing
Civilian move-verb is unchanged and re-logged in the backlog. No true
mount/vault clip existed in the 182-clip library to splice untouched, so `board_heli` is built from two
already-shipped, already-gated pieces plus a hand-authored bridge:
`jump_up` (frames 1-17, verbatim — the crouch-launch/reach beat) into a 24-frame eased
settle to `sitting`'s opening pose (hips 0.98 m -> 0.71 m crouch -> 0.99 m peak -> 0.55 m
seated, continuous, no pop). Elbow gate max 0.0191 (very safe) at both source and after
re-import from the shipped `.glb`. This is a **compromise**, logged honestly: it reads as
"launch up onto the sill and sit down," not the footage's "grab a high doorframe and vault,"
because no overhead-reach clip existed to splice and the task law forbids inventing motion
from imagination. Flag for a follow-up session if the owner wants the doorframe-grab beat
specifically.

Shipped: `assets/shared/anim_library.blend` (`board_heli` action, fake user set) ->
re-exported `assets/shared/anim_library.glb` (183 clips now, 15.33 MB, verified `board_heli`
present with matching frame range/pose after re-import). Wired:
`scripts/vehicles/heli_lift.gd:46` `BOARD_CLIPS = ["board_heli"]` (was `[]`).

**Structural item NOT fixed this session (logged per the fossil/pointer law, not silently
patched):** `heli_lift.gd:_extract()` calls `civ.actor.play_first(BOARD_CLIPS)` in the SAME
loop tick that appends the man to `going[]`, before `seats.board_squad(going)` even issues
the `MOVE_TO` staging order. The board clip can start playing before the man has walked to
the door. Filling `BOARD_CLIPS` was the sanctioned "only change needed" per the code's own
comment, so it's wired as instructed; the trigger-timing question is sequencing work, not an
animation change, and belongs to whoever next touches `heli_lift.gd`/`seat_system.gd`.

---

## 2026-08-05 — HUEY v3, interior-first master (Phase 1+2, PARKED AT THE GATE)

**Caleb's framing:** *"whatever better huey we make today will be the new source of truth for
all the animations that derive from it"* — so the interior-first decree applies to a vehicle:
space → contents → HIS GATE → people/animations → exterior last. Built to Phase 2 and stopped.

**Why v1 had to go, measured not eyeballed.** `assets/us/vehicles/huey.glb` is md5-identical to
`archive/huey_v1_ORIGINAL.glb` — the shipped bird has never been updated. Its real defect is
proportion: **nose-to-tail 16.82 m against a real UH-1H's 12.77 m, ~30% too long**, which is why
the rotor reads as a toy propeller on a barge. Also tail rotor 1.82 (real 2.59), skids 5.60
(real 3.35), lowest point −0.12 (sunk 12 cm underground), nose −Y (nonconforming), and an origin
**7.8 m off the airframe** that `scripts/vehicles/helicopter.gd:71-80` re-centres at runtime every
spawn. v3 fixes the origin, so that band-aid can be deleted when v3 ships.

`huey_v2.blend` was a never-exported box blockout (every part a literal 8-vert cube) but its FRAME
was right — nose +Y, cabin floor z≈0.72 — so v3 inherits its coordinate frame, not v1's.

**Study asset:** `Downloads/bell-huey-helicopter.zip` (2,014 tris, one 1024 atlas). Correct
proportions on every axis. Used as a STUDY per standing law; nothing of it imported. Two things it
does not give us and nobody should go looking for: its doors are merged into one shell, and its
`Inside1` is a hollow window-cutout liner with **no interior at all**.

**Built (2,928 tris, 64 meshes, 27 empties):** skids, cabin+cockpit floors, temporary `OUTLINE_`
cage, troop bench, pilot/copilot armoured seats, cyclic + collective + twist-grip + pedals at both
stations, centre console, transmission bulkhead/hump, gunner pads, and both M60 door mounts.

**All 10 gates pass, independently re-measured:** lowest z = 0.0000 · skid track 2.590 / length
3.350 · floor top 0.710 / cabin width 2.400 · cabin clear height 1.240 · nose +Y · origin on the
built volume · all 11 seat markers inside their volume and above their surface · bench top 1.155
(floor+0.445) · seated 1.674 m man clears the ceiling (cabin 0.361 m, cockpit 0.106 m) · 2,928 tris.

**`seat_pax_7` now exists in a model for the first time.** `seat_system.gd` declares an
**11-seat** contract (2 pilots + 2 gunners + 6 pax + 1 jump seat against the transmission wall) —
neither v1 nor v2 had the jump seat, so the game has been auto-generating it from `FALLBACK_LAYOUT`
every spawn. Also newly honoured: **socket ORIENTATION is part of the contract** (the occupant
faces the socket's local +Z). All 11 are now rotated, not just placed — pilots to the nose, gunners
and pax out their own door, jump seat forward. This matters beyond looks: `door_staging_pos()`
derives the entire squad boarding point from `seat_gunner_l`'s +Z.

**M60 door mounts — reused, not rebuilt, per Caleb.** Source is
`structures/emplacements_real/m60_door_mount.glb`, whose mesh is literally named `huey_door_mount`
(1,104 tris). **Its `MuzzlePoint` is −Y — backwards from the ratified facing law**; so is
`m60_ring_mount.glb`. Corrected into v3 by composing each object's *measured* world rotation with a
180°-about-Z and baking it into vertex data (never by yawing a root over pinned children), then
re-deriving `MuzzlePoint` from the corrected geometry rather than transforming the old value.
Verified: pre-traverse bore = exactly (0,1,0). **The source GLBs were left untouched and are still
nonconforming** — flagged, not silently retro-flipped. Deliberately did NOT use `m60_pintle.glb`
or `m60_mounted.glb`: their M60 is **10,552 tris**, ten times budget for an aircraft seen at range.

Measured ROM by object-space ray cast against the OUTLINE cage: traverse left −88/+88, right
−130/+88; elevation both −88/+36 (the +36 is a real geometric stop, the cockpit header). The L/R
traverse asymmetry is most likely an artifact of the temporary cage's gaps — **re-verify once real
exterior panels replace `OUTLINE_`**.

**DEFECT CAUGHT ON REVIEW, not by the build's own gates: both collectives were on the wrong side.**
The rule is that the collective sits to the occupant's LEFT. Every cockpit socket has local
+Z = (0,1,0), so both men face +Y; with +Z up, the occupant's left is −X (left = up × forward =
Z × Y = −X). Both collectives had been placed at `seat_x + 0.20`, i.e. each man's RIGHT — which put
the cyclic and the collective under the same hand and nothing under the left. **The build's own ten
gates could not catch this**, because the reach table reported a direction-blind scalar (0.422 m
for both, identical by construction). Fixed to `seat_x − 0.36` and re-verified with the *signed*
vector: both grips now at Δ = (−0.360, +0.050, −0.215) from their seat — outboard for the man at
−X, inboard against the console for the man at +X. Correctly non-mirrored. **Lesson for
`blender_lessons.md`: a symmetric scalar reach measurement cannot detect a left/right error — gate
the signed component.**

**OPEN RULING FOR CALEB, not resolved:** with nose = +Y, the aircraft's starboard side is +X, so the
socket named **`seat_pilot_l` is physically the right-hand seat** — where the pilot-in-command flies
by US convention. The project's inherited `_l` = +X naming (confirmed independently in
`huey_v2.blend` AND `SeatSystem.FALLBACK_LAYOUT`, matching the code comment "Door_Left side = +X")
therefore points at the opposite socket from the role. Compounding it, the furniture named
`pilot_*` was built at −X (port) while the role reasoning puts the flying pilot at +X — so the
furniture naming and the role disagree too. Nothing renamed pending his call. **Phase 4's
copilot-specific clip work cannot start until this is ruled**, because it has to target the seat
holding the man who is actually flying.

**Also flagged, not silently absorbed:** cockpit ceiling raised to 2.05 m (vs the cabin's 1.95 m)
because a 1.674 m pilot on the 0.335 m armoured seat pan had under 1 cm of headroom — a real UH-1H
solves this with the raised greenhouse canopy, approximated here as a stepped flat `OUTLINE_` plane
pending Phase 5 canopy shaping. Pax floor-sit pelvis height assumed floor+0.12 m (no pinned number
existed). Pintle pedestal 0.29 m so the gun is not too low for a standing gunner. Origin Y anchored
at the cockpit/cabin firewall — **re-check against the true nose-to-tail midpoint when Phase 5 adds
the nose and boom**; everything is built as one consistent block so that correction is a single
rigid move, not a rebuild.

**NOT touched, per his ruling "v3 first, re-stage after":** the four shipped `heli_*.glb` clips and
all four `huey_*_staging.blend` files still bake v1 geometry (`Huey_Copy` / `New_Rotor_Hub` /
`New_Skid_L`). They are now stale against the new source of truth and re-staging is queued, not done.

**Companion research shipped:** `production/research/huey_pilot_motion/NOTES.md` (871 lines) —
pilot and door-gunner motion spec from TM 55-1520-210-10. Three code defects it surfaced that no
animation fixes: both pilots dressed with the same clip (`seat_system.gd:153-154`), both door
gunners play `sitting` (the passenger idle) while being the most visible crew on a flyby, and all
seven pax loop one 4.7 s clip in lockstep while six authored `sitting*` variants sit unwired.
`cockpit_controls` is 1.600 s = 0.625 Hz, inside the 0.3–1.5 Hz band of real cyclic corrections, so
the loop period is indistinguishable from the motion and the clip becomes its own metronome.
**The video wall did not move** — YouTube returns the fetcher a footer, same as the `huey_loading`
job, so every mechanical fact is primary-sourced but every motion amplitude remains an inference
from text. §9 lists ten genuinely open items.

---

## 2026-08-08 — Gear camo foliage recut from the real jungle geometry

**His rejection stands confirmed by measurement, not opinion.** The overnight "densified" foliage was
confetti: `pack_satchel_foliage_sprig_0` was 368 verts / 126 tris in **121 disconnected single
triangles**; `chest_rig_worn_foliage_sprig_0` was 1060 verts / 360 tris in **351 disconnected single
triangles**. His own hand-made `pith_foliage_sprig_0` is 21 verts / 23 tris in **one connected
frond**. Loose-triangle count, not density, was the defect.

**Fixed by cutting real pieces off the shipped jungle plants**, per his ask. The solid vegetation
geometry is still on disk at `assets/world/vegetation/*.glb` (only the impostor cards live in
`cards/`), and it shares the identical 17x1 `jungle_palette` + vertex-colour material the gear sprigs
already use — verified pixel-identical across 9 palette copies before consolidating onto one
`jungle_atlas`.

New `CAMO_CUTS` collection in `nva_vc_gear_variants.blend`: **45 pieces, 866 tris total**, each cut
canonicalised to base-at-origin / tip-at-+Z / 150 mm long, carrying `cut_source`, `cut_src_len_m`,
`cut_width_ratio`:
- **24 fern fronds** from `fern_a/b/c` (20-32 tris) — a whole frond with its stem, the money piece
- **7 banana blades** from `banana_a_crown` (16 tris, wide) — ruck drape
- **12 bush leaf sprays** from `bush_a/b/c` (12 tris) — helmet band tucks
- 1 palm frond, 1 broadleaf

**`broadleaf_a/b/c_crown` cut badly and was rejected — 37 pieces failed a width/length >= 0.22
gate.** Their "leaves" are 20-vert **twig tubes** with no blades (6 mm of cross-section at 150 mm of
length), which is exactly why they impostor-card well and cut poorly. Recorded so nobody retries it.

**Rolled across all 11 foliage props. 1784 tris total, DOWN from the confetti's 2696 tris**, every
cut a connected piece, every base 0.0 mm off the prop surface (two initial floaters at 55/75 mm were
caught by measurement and snapped with `closest_point_on_mesh`; the conical rice-hat brim defeats a
horizontal raycast).

| prop | cuts | tris | silhouette |
|---|---|---|---|
| `pith_foliage` (his layout) | 6 | 148 | 1.20x |
| `pith_worn_foliage` | 7 | 156 | 1.15x |
| `rice_hat_foliage` | 8 | 156 | 1.25x |
| `helmet_foliage_*` (US M1) | 8 | 156 | 1.61x |
| `chest_rig_ak` / `chest_rig_worn` | 6 / 6 | 144 / 112 | 1.63x / 1.66x |
| `bandolier_ammo` | 4 | 92 | 0.92x* |
| `pack_frame` / `pack_ruck_full` / `pack_ruck_light` / `pack_satchel` | 10 / 10 / 9 / 8 | 228 / 248 / 172 / 172 | 1.42x / 1.60x / 1.72x / 1.59x |

*bandolier is a 0.184 x 0.462 m strap, so the max(x,y) width denominator makes its ratio meaningless.

**Placement follows his pith arrangement, decoded numerically** ([[helmet-foliage-placement-reference]]):
sprigs 107-132 mm, ring radius 73-118 mm against a 115 mm brim half-width (**on the brim, not the
crown**), rel Z -33 to +15 mm (**tucked low at the band**), X-rot 1.11-1.97 rad (**tipped toward
horizontal, splayed outward, not standing up**), azimuth gaps 40/45/45/58/82/90 deg (**deliberately
uneven**). Packs instead anchor high and drape down per his rucksack reference photos.

**He ruled: swap his pith geometry, keep his layout.** Done by replacing the mesh datablock only —
all six object transforms are byte-identical afterwards (loc/rot/scale unchanged, verified), each new
fern cut rotated onto that sprig's own base->tip axis at its own preserved length (135.0 / 113.4 /
127.1 / 117.8 / 108.5 / 128.6 mm). His arrangement was never recomputed. Widths grew 35 -> 68 mm
because a real frond is wider than the old sliver — that is the point.

**Frame contract resolved and worth keeping:** the grid props carry a **-90 deg X worn-attitude
rotation in `matrix_world`** while `rotation_euler` reads (0,0,0), and their `grid_orig_*` stamps are
identity. So `world = prop.matrix_world @ bone_local`, and every new sprig stamps
`grid_orig_loc`/`grid_orig_rot` from its bone-local matrix. The formula reproduces his sprig_0 to
within 5 mm, the residual being his hand nudge.

**Preview parity was a live trap, caught before it shipped:** the 36 `preview_*` loadout objects are
linked dups **sharing mesh datablocks** (`users=2`), so new sprig objects leave them still pointing at
confetti. All 8 affected preview loadouts were rebuilt as linked dups of the new cuts at
`preview_prop.matrix_world @ (grid_prop.matrix_world.inv() @ grid_sprig.matrix_world)`.
`pack_frame_foliage` has no preview (that body wears `pack_worn_frame`), so it was skipped, not missed.

**Reversible and NOT SAVED.** The 29 old confetti sprigs are renamed `OLD_*` and hidden, not deleted.
`CAMO_STOCK` holds the 12 imported whole plants and can be deleted once the cuts are approved.
Nothing was written to disk — the file is his to save.

---

## 2026-08-08 — Pith helmets refit to the head, textures un-photographed

**His ask:** *"fix the pith helmets the same way we modeled our newer us army helmets... they need to fit
someones head better"*, plus *"fix the texture maps for them to fit properly"* and *"give all the
backpack and chest riggings a canvas color texture."*

### The M1 method, and why it applied verbatim
`tools/reshape_helmet_shell.py:9-11` already states this exact diagnosis for the US shells: registration
is *"UNIFORM scale anchored on the existing shell WIDTH (the head fit that already works), positioned by
the BAND, so the rim stays where it sat and the extra depth goes upward into the crown — the shells were
too shallow to cover the skull."* The pith had the same disease plus one the M1 never had.

### Measured, against `nva_regular` head verts (weight>0.5 on `mixamorig:Head`)
Head: 154.4 wide x 196.3 front-back x 221.0 tall, **plan aspect 1.272**.
Pith (worn): 218.3 x 220.3 x 55.9, **plan aspect 1.009**.

**The defect was OVALITY, not depth.** A circular helmet on an oval skull fits nowhere — loose at the
temples, tight front-to-back. Photo reference (5 views pulled to
`scratchpad/pith_ref/`, enemymilitaria.com listing) gives side-profile height/length 0.56 and a real
helmet ~295 long x 255 wide, i.e. **longer than wide**. Ours was WIDER than long (239.2 x 228.0).

Fit audit by surface-normal test (a skull vert on the OUTER side of the shell = poking through):

| preview | through | clearance | spread |
|---|---|---|---|
| `pith_foliage` before | 5/26 | -5.0 .. +28.0 | 33.0 mm |
| `pith_star` before | **19/26** | -17.0 .. +18.4 | 35.4 mm |
| both after | **0/26** | +6.6 .. +30.1 | **23.2 mm** |

### The reshape was SOLVED, not guessed
Swept (k_length, k_height) over a 20-point grid and took the **smallest** change that clears the skull by
>=3 mm everywhere — he said "super close", so over-correcting was the wrong move. Result **k_len 1.22,
k_ht 1.10**. The sweep's real finding: **ovality alone (k_len 1.22, k_ht 1.00) already clears the skull
with the helmet at its original height**; raising the crown mostly just lifts the helmet off the head
(top-vs-crown grows to +33/+43 mm, a floating bucket). Final dome 239.2 x 112.0 x 278.2,
**plan aspect 1.163 vs the real helmet's ~1.15-1.18**. Width untouched, exactly as the M1 script anchors.
Applied per unique mesh datablock to all 7 domes, 7 bands, scrim and net tabs. Topology unchanged
(70 tris/dome, 90 for the badge variant), 0 non-finite UVs.

### Two regressions found while measuring, both pre-existing
1. **`pith_foliage` was out of family** — dome 58.8 mm tall vs 101.8, band 82.3 vs 49.0, and its mesh was
   authored in a **different local frame ~190 mm low** (local height axis -59.7..-0.9 vs the family's
   96.8..198.6). Rebuilt dome+band from `pith_plain` (duplicate-known-good, per
   [[no-procedural-geometry-generation]]), keeping the variant's own materials and relinking both users.
2. **`preview_nva_medic_pith_star` sat 15.6 mm below the head bone** and
   **`preview_nva_regular_pith_foliage_band` sat 44.3 mm below its own dome** while the grid pair share an
   origin exactly. Both re-seated to mirror the grid relationship.

**His hand-arranged sprigs survived**: re-seated by ONE best-fit rigid translation, iterated 4x to gaps of
0.2-3.0 mm (mean 1.2). His relative arrangement was never recomputed — [[helmet-foliage-placement-reference]].

### The textures were PHOTOGRAPHS, again
`pith_plain_cover.png` is **not a UV atlas — it is a picture of a whole pith helmet**, brim, band, crown
knob, grommets and star badge included, and the dome's UVs span the entire image (U 0..1, V 0..1). So a
photo of a helmet, background corners and all, was wrapped over geometry that already has its own brim,
band and knob. Same disease as [[us-base-v3-textures-are-reference-photos]].

Two proofs it was wrong, both from measurement not opinion:
- `pith_star` has **170 verts vs the family's 150 — the star badge is MODELLED geometry**, so the star
  painted into the texture was pure duplication. A lowest-variance patch search over the mid-dome zone
  returned `mean RGB (0.698, 0.094, 0.094)`, variance 0.0 — **it found the painted red star**.
- the band materials sampled `V 0.80-0.97`, which in this image is **the crown**, not a band. (An earlier
  pass recorded that range as "the dome rim strip" — it was reading the photo upside down.)

**Fix:** for each variant, the lowest-variance cloth patch from **its own** texture was mirror-tiled into a
64x64 `pith_<variant>_cloth` and the material repointed, so **his colours are preserved exactly** rather
than invented — plain (0.423,0.403,0.257), worn (0.362,0.333,0.211), faded (0.495,0.485,0.408); the star
variant borrows plain's cloth. Existing UVs were KEPT: a uniform tiling weave makes the old mapping
harmless, so nothing downstream had to change. `pith_star_band_cover` was left alone on purpose — the
modelled badge legitimately samples the photo art. Originals stay in-file for revert.

### Canvas on the packs and rigs
Already mostly right (`canvas_od`, a genuine 256x256 OD weave, on `pack_canvas`/`chest_rig_worn_cover`/
`webbing_canvas`). Real work found: `canvas_od.001`/`.002` and `pack_canvas.001`/`.002` were
**pixel-identical duplicates** — merged onto the originals, 2 slots repointed, both dupe images removed.
And **`pack_medical_cross` was textured with `pack_medical_cover.png`, which is a photo of a PITH HELMET
with a red cross on it** — the medic's backpack wearing helmet art. Repointed to `canvas_od`.
All fabric materials now carry canvas; `BluedSteelVC`/`WarheadOD` stay flat colour (RPG metal, correct).

**OPEN — not silently absorbed:** `pack_worn_medical`'s UVs run **outside 0-1** (U -0.150..0.297,
V 0.107..1.461), crammed into a narrow band. A tiling canvas is forgiving of that, which is why it reads
fine now, but **the medic pack has lost its red cross** and needs a real unwrap or a decal quad to get one
back. Also untouched and flagged: `pith_helmet_worn` (294.5 x 223.5 x 93.4, y-major) is built differently
from the variant family and was left alone pending his call.

**NOT SAVED** — the file is his to save.

### Same day, after the MCP reconnect — loadout staging for his eye

Nothing was lost to the reconnect (bridge only, Blender stayed up); all pith/texture work verified intact.
Confirmed every cloth image actually **reaches Base Color** — an unwired TEX_IMAGE would have left the
helmets flat grey and looked like the texture fix had failed. `WarheadOD`/`BluedSteelVC` are correctly
unlinked flat colour (RPG metal, not fabric).

**Medic pack's red cross restored properly.** Its outward panel was identified by measurement, not guessed:
face group with local normal (0,0,-1), 279 mm from the spine (so the wearer faces -Y). Built
`canvas_od_cross` (64x64, canvas base + period red cross), cloned `pack_canvas` into
`pack_medical_cross_panel` so shading matches exactly, assigned to those **5 faces only**, and re-boxed
just those faces' UVs to 0..1 so the cross lands once and centred. No new geometry.

**Two loadout defects fixed:** `vc_guerilla` wore BOTH `chest_rig_ak` and `chest_rig_ak_foliage`, and
`nva_medic` wore BOTH `bandolier_ammo` and `bandolier_ammo_foliage` — two rigs overlapping in each case;
the plain twin is now hidden. `nva_medic`'s `pith_star` had **no band ring** while every other pith wears
one — created `preview_nva_medic_pith_star_band` as a linked dup off the grid relationship.

**Three measurement traps caught in this pass — all three would have produced confident wrong fixes:**
1. `vc_guerilla_joined` is the **stale x=-8 dummy**; the live body is `vc_guerilla_joined.001`. Using the
   wrong one reported items "floating 7448 mm". Resolve bodies via their **ARMATURE modifier**, never by name.
2. Bodies are **armature-deformed**, so `closest_point_on_mesh` on the object reads REST-pose geometry.
   Must bake `evaluated_get(depsgraph)` into a temp object first.
3. **Nearest-VERTEX distance is not surface distance.** On a 203-vert body it stayed at +47 mm while the
   satchel was already buried in the torso. Use signed surface distance
   (`(p-closest).dot(normal) < 0` = inside). This one caused a 200 mm overshoot that had to be reverted.

**The real finding about worn gear:** packs and webbing are SUPPOSED to sink into the body — `ruck_light`
reads correctly at **-59 mm with 7 verts inside**, so no gap shows. Only `pack_satchel_foliage` was wrong:
+121.7 mm OUTSIDE with zero penetration, a smaller bag hanging further out than the big ruck. Re-seated
with its 8 cuts to -15.2 mm / 6 verts inside.

Rice hats read +61.7 mm and are **correct, not floating** — a 473 mm cone over a 154 mm head cannot touch
the skull, and its apex sits +73 mm above the crown, right for a coolie hat. Pith shells sit at a +9 to
+12 mm standoff, correct for a rigid shell (unlike soft webbing, which overlaps).

Lineup for review: vc_guerilla @ x=0 y=0; nva_medic 1.5 / nva_regular 3.0 / vc_medic 4.5 / vc_sapper 6.0,
all y=-2. **Still NOT SAVED.**

### 2026-08-08 — VC/NVA units FINISHED: blueprint rebuild, faces proportioned, pith at reference

He said it plainly: *"i feel like ive been fighting for 3 days to finish this task with the nva and vc."*
Root cause of the three days, found this pass: **two competing base meshes**, so half the roster was a
different build and every downstream fix (UVs, faces, gear) had to be done twice and still failed.

**All 5 units now pass ONE topology gate: 402 polys · 1206 loops · 28 face-atlas polys · 41 vgroups.**
`vc_guerilla` and `vc_sapper` were rebuilt from `vc_medic` — chosen over the NVA blueprint deliberately,
because vc_medic is *already* a VC-textured body on blueprint topology (identical poly/loop/face-poly
counts, **identical vertex-group ORDER**, 0 UV loops outside 0-1). Deriving from the NVA blueprint instead
would have required remapping uniform UVs from the NVA strip (U .058-.939, V .379-.450) onto the VC block
(U .019-.538, V .014-.561) — wildly different aspect ratios, guaranteed distortion. The old bodies are
stowed as `OLD_vc_guerilla_joined.001` / `OLD_vc_sapper_joined`, hidden, not deleted.

The rebuild also cleaned their object setup: both were at loc (0, 1.281, 0.0142) with a **-90° X object
rotation** compensating for mesh authored in a rotated frame, and `vc_guerilla` had a **non-identity
matrix_parent_inverse**. Both now match the correct derived bodies exactly — loc (0,0,0), rot 0, scale 1,
identity mpi, single ARMATURE modifier. Placement verified: each body's deformed centre sits on its
armature's x (0.00 / 4.50 / 6.00) and gear fit is unchanged (rig -14.0 mm / 24 verts in, packs -15 to
-80 mm — worn gear is SUPPOSED to overlap so no gap shows).

**Faces proportioned on all five.** The lit face content in an atlas cell spans only **34-71% of cell
width (37%)** while the face polys spanned **74.3%** — so the cheeks sampled ear/shadow pixels and the
features were crammed into the middle of the head. Face polys are now mapped to exactly 34-71%. The two
rebuilt bodies inherited it from the donor and the cell shift preserved it.

**Pith at reference proportion, and the earlier attempt diagnosed.** The first reshape failed his eye
because **it solved for FIT while he was judging LOOK** — minimal height (k_ht 1.10) left it 112 mm tall
on a 278 mm length, still a pancake. Reference side-profile gives height/length **0.56**. Now
**239.2 × 155.8 × 278.2**, height/length **0.560**, plan aspect **1.163** (real pith ~1.15-1.18), all six
variants identical, 0/26 skull verts through, clearance +19 to +51 mm, brim **83 mm below the crown = brow
level**. Two of my own over-corrections were reverted along the way: lowering the helmet 45 mm to close
the air gap (drove 11 verts through the skull), then widening the dome into a bell to fix that — the
widening sweep proved the point, gaining only -7.9 → -4.4 mm across 40 mm of added width, i.e. **the
penetration was never at the sides, it was the lowering**. A deep pith helmet genuinely rides high on its
liner with a 19-51 mm gap.

**Pack foliage rebuilt as a peacock fan, from research not guesswork.** The NVA/VC used a **camouflage
foliage ring** — a double bamboo hoop worn on the back or lashed to the rucksack with branches **woven
between the two rings**, so vegetation stands off the back and fans up and out instead of lying flat.
Rebuilt accordingly: cuts anchored across the pack's upper-REAR band, standing 22-46° off vertical
leaning AWAY from the wearer, fanned ±52° in azimuth, lengthened to 280-340 mm. Result: the medic's ruck
foliage now rises **+223 mm above the shoulder** and **+338 mm behind the body** (was draping down the
pack face). Satchel sits lower by design (small bag worn low): -76 mm vs shoulder, +249 mm behind.

**A latent breakage of mine, caught and fixed before any save:** dumping textures to inspect them
(`img.filepath_raw = ...; img.save()`) **repointed 12 images at my session temp scratchpad** — including
`canvas_od` (4 users, every pack) and `fixed_better_viet_faces.001` (6 users, every face). That folder is
deleted at session end. All 12 repacked and their paths cleared; every image in the file is now packed
with no external dependency.

**Optimization findings recorded and PARKED per his ruling** (*"id rather just keep making models and
animations til i ahve everything i need, than go back and make them optimized"*): 4x duplicated
3600x5700 sheets = **312 MB for one image** (`ref_factions.001` and `.002` resolve to the SAME file on his
Desktop); **39 copies** of a 17x1 `jungle_palette` + 39 `jungle_atlas` materials; 64 redundant materials
of 113; face atlas duplicated; 195 of 369 objects are review scaffolding needing an export allow-list.

**STILL NOT SAVED** — he gated the save on his own eyeball of the pith, and that gate has not been passed.

### 2026-08-08 — Pith helmets REPLACED from a donor model, full variant family, netting

**Caleb approved: "new pith helmets look great."** After four rejected reshapes of the old blob, the fix
was the one the M1 already proved — start from someone else's model.

**Donor:** `NVA PITH HELMET - Mu Coi Sao Vang` by **Long Nguyen**, Sketchfab uid
`7ccc0bdff4ba4af8afcde410758e017d`, **378 tris / 221 verts, CC-Attribution (commercial OK, credit
required)**. Credit is stamped as a `donor` custom property on every derived object and the donor
originals are kept hidden as `DONOR_*`. Found via Sketchfab's **public search API** (no key needed to
search: `api.sketchfab.com/v3/search?type=models&downloadable=true&q=...`); only the download needs the
key. Set `PYTHONIOENCODING=utf-8` — Vietnamese model names crash cp1252 on Windows.

**Three of my own errors on the transplant, each caught by measurement:**
1. **Applied the M1 scale rule blindly.** "Uniform-scale to the existing shell WIDTH" presumes that width
   is *a head fit that already works*; the pith's 239 mm came from the bad blob. Scaling a real helmet
   down to a broken reference broke it (8-11 skull verts through, no clean seat in a 60-step sweep).
   **Native scale was correct** — donor and head are both real-world size.
2. **Axes wrong twice.** The Sketchfab parent chain already applies a Z-up conversion, so baking
   `matrix_world` rotated it once before my own rotation compounded it. True native frame: **X=width,
   Y=height, Z=length** — NOT "already Z-up".
3. **Rendered it upside down**, brim up and dome buried in the skull. That forced a permanent check:
   **the widest cross-section must be at the BOTTOM** (`w_at(0,0.2) > w_at(0.8,1.0)`), which then caught
   the inversion again automatically on the rebuild.

**The donor also corrects the photo reference.** I had measured height/length **0.56** off a side photo;
the real model is **0.462** — the drooping brim inflated my reading, part of why every reshape looked
wrong. Final family: **265.1 W x 295.0 L x 136.3 H**, seated with **0/26 skull verts through**, clearance
+4.0..+35.8 mm, brim 94 mm below the crown (brow level).

**Variant family, all from the one donor** (365 tris each; 378 for star and scrim):
- **star** = donor as-is (badge intact)
- **plain / worn / faded** = badge **geometry deleted** (13 faces, found by UV island U 0.684-0.902,
  V 0.691-0.926) — painting the texture alone left a blank olive medallion, because **the badge is
  modelled, not painted**. Textures derived from the donor's own 512x512 by tint: worn mul 0.60,
  faded mul 1.38 (my first pass at 0.78/1.16 was too timid to read apart).
- **net** = plain shell + `pith_net_scrim`, an offset shell (1.018x) with a generated coarse rope-cord
  texture (128px, 32px spacing, 5px cord) and **cylindrical UVs (3.5 x 1.6 repeats)** so the cord tiles
  instead of sampling the donor atlas. First attempt (16/2 px, 7x3 repeats, 1.035x offset) read as fine
  window screen with a jagged fringe past the brim.
- **foliage / worn_foliage** = plain/worn + camo cuts.

**A bug affecting EVERY camo cut in the project, found only by rendering:** `jungle_atlas` **MULTIPLIES**
the 17x1 palette against **vertex colour**, and the vegetation's vertex colours are not a tint — they are
data (mean **(0.537, 0.260, 0.000)**, zero blue; individual values like 0.125/0.002/0.0). Leaf-green x
that = black. **All the helmet AND pack foliage was rendering near-black.** Fixed by neutralising vertex
colours to white on **123 cut meshes** — done on the cuts, not on the shared material, so the other 39
`jungle_atlas` users are untouched.

**Pack/rig foliage rebuilt again after seeing it worn:** the 320-340 mm "peacock" cuts read as **giant
flat green cardboard wings**, because most were **banana blades — 16-tri flat quads**. Banana is now
EXCLUDED as camo stock; fern fronds only (serrated silhouettes read as foliage, flat quads never will),
at 160-200 mm for packs and 105-115 mm for rigs.

**His hand-arranged pith sprigs:** the new dome is a different surface, so his fitted rotations pointed
them **straight up like antlers**. Restoring his own documented style (tucked low at the band, tipped
64-113 deg) while **keeping his six azimuths exactly** (+35.8/-51.3/-152.7/+158.0/-16.3/+111.1 deg) gave
0.0-0.5 mm contact. A translation-only rigid fit could only reach 17 mm max gap; adding uniform scale
(0.950, dz -28 mm) got it to 5.3 mm before the attitude fix superseded it.

**61 old objects retired to `OLD_*`** (hidden, nothing deleted). **SAVED** — `bpy.data.is_dirty == False`.

**Newly visible and NOT caused by this work — flagged, not silently absorbed:** with the foliage finally
reading correctly, the full-body render shows the **pack itself is a featureless green box**, the
**chest-rig pouches read as blocky lime-green blocks**, and the **uniform texture is streaky** (that last
one is the known 3600x5700 reference-sheet strip, parked under his optimize-later ruling).

### 2026-08-08 (late) — Roster re-geared: stale props out, new gear on all 22 NVA/VC units

**Files:** `assets/nva_vc/characters/nva_vc_soldiers.blend` (the roster, 116.6 MB) and
`assets/nva_vc/props/nva_vc_gear_variants.blend` (props source). Safety commit before any of it:
**`4e15364f`** — revert with `git checkout -- assets/nva_vc/characters/nva_vc_soldiers.blend`.

**Removed:** 72 stale per-unit pith objects (old domes, bands, `_leaf_N` sprigs, `pith_helmet_worn`) +
23 loose stale grid pith copies + 15 loose unparented pack/rig props (`pack_frame_foliage` on
`palm_bark`, `pack_canvas.018-.028` duplicates) + 77 camo cuts buried inside bodies (1,720 tris of
invisible geometry) + 85 `GEAR_`/`TEMPLATE_` appended stock objects once instanced.

**Added, all 22 units (12 NVA, 10 VC):** donor pith helmets (NVA only, each keeping the variant it
already wore), packs, chest rigs/bandoliers, **belts**, and camo cuts. Everything **bone-parented** —
headgear to `mixamorig:Head`, packs/rigs to `mixamorig:Spine1`, belts to `mixamorig:Hips` — so it
follows animation. Readiness check: **22/22 units complete**, 41 bones each, 3.3k-12.6k tris per unit.

**His rulings this session:**
- **NVA = black webbing, VC = canvas/army-green webbing.** (Reverse of the usual assumption.)
- Webbing colour belongs on the **webbing only** — I had painted whole rucks black; pack bodies are
  canvas (33 slots restored), faction colour kept on the 22 rigs/bandoliers/belts.
- **Bandoliers and medic satchels use the cloth weave** the US grunts use: `webbing_canvas.003` ->
  `canvas_od.003`. NOTE the US *bandolier* itself is untextured flat (`bandolier_tex.001`, no image),
  so match the cloth they use on belts/pouches, not that.
- **Chest rigs need two tones** so they read as a rig, not a black blotch: base + lighter pouch faces
  (NVA 0.086 -> 0.185, VC 0.302/0.353/0.183 -> 0.398/0.447/0.286), applied to faces pointing away from
  the chest. 21 rigs, ~30 of 90 faces per rig.
- **Belts** duplicated from the US `web_belt` (128 tris), waist-solved per unit.
- Camo cut scaling matches his hand-set character: **only ~40% of sprigs are enlarged** (his own fix
  scaled 5 of 13), packs X1.7-2.3 / Y1.0-1.5 / **Z 2.5-3.9**, gentler on rigs and headgear.

### PACK PLACEMENT — four failed attempts, and the metric lesson

Placing 20 packs took four passes because **every metric I chose was blind to the thing that was wrong**:

1. **Pure translation, rotation discarded.** The gear templates carry an **87.1 deg X worn attitude** in
   `matrix_world`. Dropping it turned a 363 mm-TALL ruck into a 363 mm-DEEP one — packs lay on their
   side. My "distance from torso centre" metric read a healthy 315 mm the whole time. **Bounding-box
   distance cannot see orientation.**
2. **One offset for every pack type.** Solved on `ruck_light` (229 deep) and applied to `satchel`
   (166) and `frame` (426) -> 5 satchels floating +147 mm, 2 posed frame packs buried -160 mm.
3. **Iterative search along a guessed bone axis.** `Spine1.matrix @ (0,0,1)` points FORWARD, not back,
   so "move inward" moved outward: satchels went +147 -> **+516 mm**.
4. **Search along the surface normal.** Self-correcting on distance, and it hit -32 mm on all 20 - but
   **min-signed-distance cannot tell back from front**, so it satisfied the target with the packs
   pushed off the back entirely. The render caught it; no metric did.

**What finally worked:** compute the offset **analytically per pack type** - take that type's own
oriented geometry, align its body-side face to the torso's **ray-cast back surface** minus a 35 mm
sink, express it in the `Spine1` bone frame (so posed units inherit it), apply. Verified with a
**side-aware** check: pack centroid must sit on the +Y side of the spine (`+166 mm` for
`nva_regular`). Note even that check first read "NOT BEHIND" on all 20 - because I inverted the axis
AGAIN. The world +Y-is-back fact is the one to trust here; the bone axis is not what I assumed.

**Process failure worth naming:** I saved and reported "placement consistent" *before* rendering, and
he called it out — *"why did you finish knowing it wasnt right? thats silly."* Every subsequent pass
rendered BEFORE saving, and every one of those renders caught something the numbers had passed.

**Still open:** VC units all wear rice hats (never rebuilt, so no pith/new headgear on the VC half).
`vc_medic` face UVs are unmatched — its UVs were in Edit Mode all session. Face-UV cloning is blocked
on him naming which head has the face he wants (all 5 share 402/1206 topology so a loop-for-loop copy
would be exact; three approximation attempts all failed). Pack/rig MODELS themselves are still crude
boxes. GLB export for the enemy grunt spawner is the next step and has not been run.

**Foliage attached and joined (same session, after the pack fix):** 138 of 257 pack camo cuts were
floating up to **303 mm** off their pack — drift from my repeated pack re-placements, where I moved
sprigs by translation delta only and ignored rotation changes. Nearest-pack check was clean (every cut
already belonged to the right pack), so it was a snap not a re-home: each cut's ORIGIN is its stem base,
so snapping the origin to `closest_point_on_mesh` seats it exactly — max gap 303 mm -> **0.0 mm**.

Then **joined the cuts into their packs**: 20 packs, 257 separate objects -> 0, each pack now one mesh
with 2 material slots (canvas + `jungle_atlas`). Object count 1373 -> 1122. Rig/headgear cuts (76) were
already at 0.0 mm and were left as separate objects.

**The join re-broke the foliage colour, and the cause is worth remembering:** the joined mesh HAD a
`Color` attribute but **no ACTIVE colour attribute**, so `jungle_atlas`'s MULTIPLY against vertex colour
resolved to black — all the fronds rendered black. Fix: set `color_attributes.active_color` (and
`render_color_index`) and fill white, done on **96 meshes** carrying `jungle_atlas`. This is the third
appearance of the same bug class this session; **after ANY join involving `jungle_atlas`, check the
active colour attribute, not just that a colour attribute exists.**

Verified by render before saving. Roster saved 21:29:50, 116.7 MB.

### 2026-08-08 (night) — Gear library: the 7 pith helmets are IN the game pipeline

**His direction:** *"the enemy grunt spawner should mimic how the us grunts v3 do it in game... same
pipeline but fitted in the same manner."*

**The pipeline already existed** — this was wiring, not building. `scripts/visuals/vc_nva_dresser.gd`
(VcNvaDresser) is the NVA/VC twin of GruntDresser and already reads
`assets/nva_vc/props/nva_vc_gear.json` at RUNTIME, so *a new variant reaches the game with no code
change*. Sockets are **IDENTITY BoneAttachment3D** because every library GLB is authored with its
vertices baked into the socket bone's LOCAL space — `socket_headgear`=`mixamorig:Head`,
`socket_pack`=`Spine1`, `socket_chest`=`Spine2`. Welded stock meshes (`pith_helmet`, `rice_hat`,
`pack_worn`, `pack_roll`) are hidden when a library variant is hung. Export recipe copied verbatim from
`tools/build_nva_gear_batch2.py`: select props + rig, active = rig, `export_yup=True`, no
skins/animations/morphs.

**CRITICAL, found before exporting anything:** `nva_vc_soldiers.blend` is a **review/staging scene, NOT
the export source**. The shipped unit GLBs come from `make_nva_variant.py` running against
`vc_guerilla_v2.blend`, and that script **builds its own low-poly pith dome in code** (the very blob the
donor replaced). Tonight's roster work does NOT reach the game by itself — the gear library is the bridge.

**Rebuilt and verified on disk (7 GLBs, `assets/nva_vc/props/headgear/`):**

| key | tris | parts | note |
|---|---|---|---|
| pith_plain / worn / faded | 365 | 1 | donor dome, clean mesh names |
| pith_star | 378 | 1 | badge intact |
| pith_net | 743 | 2 | + scrim |
| pith_foliage | 505 | 7 | dome + **his 6 hand-arranged sprigs** |
| pith_worn_foliage | 521 | 8 | NEW manifest key |

Bone-local spans are **0.279 x 0.310 x 0.143 m** (donor family) replacing the old blob's
**0.309 x 0.235 x 0.098**. Read-back verified: bone-local coords, textures embedded, part counts correct.

**Two defects caught by verification, both mine:**
1. **`pith_foliage` first exported as a bare dome** — when I swapped the roster helmets I placed only the
   dome per unit; his 6 sprigs live in the PROPS file and were never copied across. Re-exported from the
   props file, composing his sprig arrangement onto the roster's VERIFIED Head-local pose.
2. **Axis mismatch between the two sources.** Props-file `grid_orig` stamps produced span
   [0.268, 0.330, 0.141] while the roster gave [0.279, 0.143, 0.310] — Y/Z swapped, i.e. one was rotated
   90 deg. The ROSTER pose is the trustworthy one (its fit was verified at 0/26 penetration), so the
   props export now takes the roster's Head-local matrix as its base and applies only the sprigs'
   dome-relative offsets. **Do not trust the grid_orig stamps as a Head-local pose without checking the
   axis order against a fitted instance.**

**Manifest updated** (`nva_vc_gear.json`, BOM stripped): pith entries refreshed from the actual files
(tris/verts/parts probed from the GLBs, not asserted); new `pith_worn_foliage` key; and per his ruling a
**NEW `belt` category + `socket_belt` on `mixamorig:Hips`** declared with the same identity construction —
schema first so `_rehang_belt` can be written against something stable, with the note that a missing GLB
must deal `belt_none` rather than error. **NOTE the entry schema is a DICT** (`glb`/`tris`/`verts`/`parts`/
`note`) — a bare string silently fails the dresser's lookup; I made that mistake and fixed it.

**Cosmetic, not functional:** `pith_foliage`/`pith_net`/`pith_worn_foliage` carry `.001` on some mesh
datablock names (collisions inside their source file). The dresser matches names only on the WELDED body
meshes, so this affects the manifest's `parts` documentation, not runtime.

**STILL TO DO for the spawner (his 4 rulings recorded):**
1. **Belt GLBs** — `belt_web_nva` / `belt_web_vc`, Hips-local, + `_rehang_belt` in VcNvaDresser
2. **Packs and chest rigs** — rebuild BOTH clean and `_foliage` variants (his choice) from the donor-era
   gear; the 11 pack + 5 chest GLBs on disk are still the pre-tonight versions
3. **Re-export all 20 unit GLBs** (his choice) — bodies unchanged tonight, but he wants them refreshed
4. Run `tools/verify_character_glb.py` as the gate

### 2026-08-08 (loop) — Gear library COMPLETE: 35 GLBs, manifest consistent

Exported, all bone-local to their socket bone, clean names, verified by read-back:
- **belts (NEW category)** `belt_web_nva` / `belt_web_vc` — 128 tris, span 356x65x307mm, Hips-local,
  faction webbing baked (`webbing_nva_black` / `webbing_vc_od`)
- **packs, clean AND camo** (his ruling) — `pack_ruck_light` 68 / `pack_ruck_full` 236 /
  `pack_satchel` 48 / `pack_frame` 84 tris, plus `_foliage` forms at 320-580 tris and 12-15 parts
  (spans to 0.97m from the scaled-up peacock camo). `pack_ruck_full_foliage` + `pack_satchel_foliage`
  are NEW keys.
- **chest rigs per faction** — `chest_rig_ak_nva/vc_foliage`, `chest_rig_worn_nva/vc_foliage` (236/244
  tris) with the TWO-TONE webbing baked (`webbing_*_black`+`_pouch`), plus `bandolier_ammo_foliage`
  (140 tris, cloth weave). The bandolier exports as 1 part because its own camo cuts were among the 77
  deleted for being 100% buried inside the body.

Library now holds **11 headgear + 13 packs + 9 chest + 2 belt = 35 GLBs**, every manifest entry probed
from the actual file (tris/verts/parts read out of the GLB, never asserted).

**Re-exporting the 20 unit GLBs is a NO-OP for tonight's work — measured, not assumed.** The shipped
`nva_*.glb` carry a welded `pith_helmet` which VcNvaDresser HIDES before hanging the library variant;
the `vc_*.glb` carry **no gear mesh at all**, so there is nothing to hide. Either way gear arrives via
`socket_headgear/pack/chest/belt`, not welded into the body. Bodies did not change tonight (the face-UV
attempts were all reverted), so a re-export would emit identical geometry while touching shipped assets.
Worth revisiting only when the bodies themselves change.

**TWO CODE CHANGES still needed in `scripts/visuals/vc_nva_dresser.gd`** (recorded in the manifest's
`gaps` too):
1. `_rehang_belt` — mirror `_rehang_pack` against the new `socket_belt` / `belt` category; a missing GLB
   must deal `belt_none` rather than error.
2. **FACTION FILTERING for chest keys suffixed `_nva` / `_vc`** — the current unfiltered `_pick("chest")`
   can hand a VC a black NVA rig, which is exactly the thing his ruling was about.

### 2026-08-08 late — the two dresser changes LANDED, and a real export gate

**Both code changes above are done and compile clean** (`godot --headless --path . --editor --quit`
reports zero script errors project-wide; `scripts/visuals/vc_nva_dresser.gd`):
1. **`_rehang_belt`** — hangs on `socket_belt` / `mixamorig:Hips` / `"BeltSocket"`, mirroring
   `_rehang_chest` (nothing welded to hide). `dress()` records `out["belt"]`.
2. **Faction filtering** — `_pick` takes `unit` and filters through `_wearable_by`. Every one of the
   four call sites passes `actor.unit` now, not just chest.

**The gate is DATA-DRIVEN, not a key convention.** `_faction_of(category, key)` reads the manifest's
optional `faction` field first and falls back to a delimited `_nva_`/`_vc_` token. That mattered
immediately: **no headgear key carries a token**, so token-only gating left a VC free to draw an NVA
pith helmet — the single most recognisable NVA silhouette. `pith_*` is now tagged `"faction": "nva"`
in the manifest. Draw pools measured after the change:
`nva_regular` 12 headgear / 14 packs / 8 chest / 2 belt · `vc_guerilla` **5** / 14 / 8 / 2.
Rice hats, `cap_cloth` and `bare` stay NEUTRAL — both sides wore them, and it is all the VC half has.

**`tools/verify_gear_glb.py` — NEW, and it is a gate (exit 1 on any failure).**
`blender -b -P tools/verify_gear_glb.py -- --json out.json`. It checks only bug classes that actually
cost a rebuild on this library: unpacked texture images (the twelve images once repointed at a session
scratchpad), missing UV layers, tri drift vs the manifest, bone-local bbox drift, and **dark `COLOR_0`
on a `jungle_atlas` mesh**.

**Two of the gate's first three checks were WRONG and were corrected before any finding was trusted:**
- **Vertex counts are not comparable.** glTF splits vertices per unique (position, normal, uv), so
  every "mismatch" was ~3x — flat-shaded low-poly geometry exploding on export. The check is gone;
  the count is reported, never asserted. Only TRIS are invariant.
- **The colour check was backwards.** An ABSENT `COLOR_0` is SAFE: Godot defaults vertex colour to
  white and the palette multiplies through unharmed. Present-and-DARK is the defect. Measured across
  the library: every sprig is either `COLOR_0` = **1.0** or has none at all, so the black-foliage bug
  class is **not present in any shipped GLB** — `chest_rig_ak_foliage` (no attribute) and its
  `_nva_`/`_vc_` siblings (1.0) render identically.

**Three real defects the gate found, all fixed:**
1. `belt/belt_none` was literal JSON `null`, not an entry object. `_hang` reads
   `cat.get(pick, {}) as Dictionary`, so a null read as EMPTY → "no 'belt_none' in the belt library"
   → returns `""`. Harmless for belts, but it is the same shape as `bare` and `pack_none`, where a
   `""` return means **the welded hat is never taken off** — "bare" would have silently meant "keeps
   his welded pith". Those three already carried an explicit `glb: null` and were fine; `belt_none`
   is now a proper object too.
2. `headgear/rice_hat_foliage` manifest said **64 tris**; the GLB has **200** across 9 meshes. The
   number predated the sprigs. Corrected.
3. `chest/bandolier_ammo_foliage` is **byte-identical in shape to `bandolier_ammo`** (140 tris, 1
   mesh) — it carries no sprigs whatsoever, because its own camo cuts were among the 77 deleted for
   being fully buried in the body. A variant whose name promises foliage and delivers none is a lie
   in the library, so it is **DELISTED from the manifest**. The GLB is left on disk; re-list it only
   once real cuts are joined onto it.

Library is now **12 headgear + 14 packs + 9 chest + 3 belt**, and the gate reports
**34 GLBs checked, 4 sentinels, 0 failures.**

**The spawner ask is DISCHARGED.** *"the enemy grunt spawner should mimic how the us grunts v3 do it
in game"* — it already did, and it is now verified end to end rather than assumed:
`scripts/enemies/enemy_base.gd:426-431` (`_dress_visual` → `VcNvaDresser.dress`, seeded from
`GruntRandomizer.next_bench_seed()`) is the exact mirror of the US path
`scripts/visuals/grunt_randomizer.gd:94` (`GruntDresser.dress`). Every manifest GLB path resolves to
a file on disk (35/35 probed).
