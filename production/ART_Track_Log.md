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
