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
- **Slim-base remake of the 8 v1-rig characters** (us_grunt, us_grunt_black, us_medic, vc1/2/3/5/6)DONE. Us Grunt v3 is the source of truth for Us models as well as the workflow for making multiple variants of models. 
- **Headgear library** — pith helmet, boonie, straw conical (VC), USMC utility cover, bare-head hair
  variants. [qcsb] Half way done
- **US visual variety** — helmet/torso/arm variants so the fireteam isn't clones. [qrzf] Needs to be addressed
- **NVA gunner for ZPU #2** + finalized sights mirrored. [htxn] Not finished yet. Animation will apply for both factions as it will be mannable by everyone, as well as another gun the player can mount. 
- **Gore stump painting** on gore_tex (gib cells exist, cells unpainted). [yp0g] Gib exists, haven't seen it in too many playtests lately but its based on damage done and we haven't been going crazy with the damage yet. 

## 2. WEAPONS — FP models still on stand-ins
- **SKS** — shows a Kar98k. Enemy-common weapon, worst offender (capture hands you a WW2 rifle). Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **M79** — shows an MP40. Model already built in weapons_us.blend, needs FP hold + export. Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **CAR-15** — shows a Thompson. I think we have the v1 m16 model and the faux fps down the sights aiming. 
- **FP radio handset** — blocks Batch 6 close. [of80] Were mid wiring up the loop for this. I have a placeholder phone model when you grab the phone as I have to do the phone animation with the arm rigs. In the middle of confirming the radio support loop. I also made a AC 47 spooky gun ship thats almost done instead of the square block we have. 
- **M26 FP hold finalize + export** (model done, staged). [rzlk] Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **MX-991 flashlight two-prop export** (tunnel rat). [awip] I thought I had exported this? but theres going to be some animations i want to add too. 
- **MuzzlePoint verify per arms scene** — zero current viewmodels expose one in Godot. [vi32] Why is that? the models have them. 
- Period models if ratified: BAR, Kar98k(return), Nagant. [ycib]

## 3. ANIMATIONS (Caleb posing queue — priority order) I haven't worked on these animations too much but I think we can do them all soon. We also need to add a few more "seeking cover" animations or fix when the models switch from crouched to the leaning against the wall. I saw them taking cover a good 10m before they were actually to the building and than they slowly made their way to the wall. 
1. **mg family** 8-clip set — unblocks vc_sapper + PIGMAN (two units rifle-holding LMGs)
2. **launcher family** 8-clip set — nva_rpg rifle-holds the tube, worst visual read in combat
3. **bolt family** 8-clip set — mosin/m70 carriers
4. **pistol family** 8-clip set — lowest (no AI carries one yet)
5. **Family reloads** where the motion differs most: mg belt / bolt cycle / launcher muzzle-load
6. **Missing base clips:** grenade_throw, surrender_idle (hands-up), wounded_crawl,
   death_from_the_left (deaths currently favor one side), stumble_hit, heli_board/heli_exit
7. **Per-gun FP idle/fidget/inspect** (HL1-style; specs in fp_arms/IDLE_ANIM_SPEC.md). [4uuu]

## 4. VEHICLES / AIRCRAFT
- **C-47 Spooky** — model WIRED 2026-07-25: `ac47_spooky.glb` flies on `SpectreGunship` (`spectre_gunship.gd:50`), baked `prop_spin` clip looping in-game, left pylon turn so the port guns face the target. Still to do: model the guns that stick out of the left side. 
- **Ordnance mounting** — 8 bomb/napalm/rocket-pod props exist, none attached to the F-4 or dropped. Thats something well have to do during the dedicated vehicles. 
- a4_skyhawk unwired (modeled, no scene). It should be in the game we have it already. 

## 5. STRUCTURES / WORLD
- **Building interiors (CQB kit)** — 0%; every building is a shell. Gated epic.
- **Tunnel interior kit** — entrance+ladder, corridors, rooms, props. [u0e0]
- **Roads** — LIVE (as of 2026-07-24): `RoadNetwork.new(...)` builds the hub-and-spoke net (`scripts/missions/mission_generator.gd:562`) and carves the corridor through vegetation (`scripts/missions/mission_generator.gd:680`); guarded by `tests/test_roads.gd`.
- ~64 modeled+measured structures sit unplaced (placement/wiring work, not art). Alot of these models are old rips from the spring1944 opensource game we were using as holders or bad makes of things I had tried using those old models from a fwe months ago with the REALVIETNAMRTS project. Even our newer current firebase is okay but I need to spend like a full day making a more detailed firebase and I think I should do that too with the villages and make more finished buildings so they can be fleshed out. Also adding more geometry to the villages will be a win and allow some close quarters battles and more places for the players to have to clear out. 

## 6. UI ART
- Topo paper texture, medal/ribbon icons, MACV-SOG patch PNG, offer-card thumbnails. [fmc8 adjacent] There needs to be a whole day spent fixing and refining the whole UI/UX. its all total placeholder right now and worth something to spend our deep dive of a week learning more about the pros and cons of UI UX experiences in a deep research. 

## 7. AUDIO (the emptiest bucket — ~10%)
- ~~**Every weapon SFX is procedural-synth placeholder**~~ — **8 of 9 base guns now carry real
  recordings (2026-07-27)**, from Snake's Authentic Gun Sounds. m16a1 · ak47 · rpd · ppsh41 · m60 ·
  mosin · m70 · m14 have real near-report variants + distant reports; m70 and m14 had **no audio at
  all** before this and were falling through to the generic rifle bank. `m1911` deliberately KEEPS
  its synth render (no pistol stock in the pack; .45 is subsonic). Launchers (m79/m72_law/rpg2/rpg7)
  and `shotgun` are still synth — no source exists for them.
  Proof: `tests/test_audio_pack.tscn` (in-suite) + `tests/probe_audio_live.tscn` (real WASAPI driver,
  8/8 weapons resolved to their own render).
- **VO barks** — Vietnamese + US callouts for the bark system (lngs); voice_studio.py pipeline ready.
- More ambience beds (only jungle_day.mp3 is real; night/rain/river missing).
I just got a bunch more radio bits I edited with audacity mixing ai generated radio broadcasts and real broadcasts from the time mixed with radio ads and a radio hiss that covers the dead parts. 

## 8. TEXTURE OPTIMIZATION (the real 85MB)
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

**Needs CALEB (in rough order):**
1. Playtest the lens look (m16/ak/m14/ppsh re-exported; all guns render real-scale through the
   shader now). Poses will read slightly shifted — bench-tune per gun (Ctrl+S), starting with your
   mains. `ViewmodelLens.ENABLED = false` in viewmodel_lens.gd is the escape hatch if it's wrong.
2. The 5 grandfathered stub ADS poses (ak47, m1911, mosin, rpd, rpg2 share a copy-paste
   placeholder) — bench V-align + save, then shrink the test list.
3. Authoring gap measured in the staging file (`tools/probe_all_rigs.py`): colt45, ithaca, m60,
   m70, m79, m72_law, rpg2, rpg7, thompson rigs have NO clips staged (old GLBs are fossil-exporter
   output); mosin/rpd/sks armatures have no animation at all. Each needs at least a staged idle
   before it can join the strict manifest.
4. `STALE_muzzle_*` fossil empties in fp_arms_rifle.blend — delete when convenient.
5. `tools/gen_weapon_data.py` still emits pre-ADR-016 `base_damage = Array[int]` — stale
   generator, fix or retire before next use.

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

**LICENSING — read before you package a build:** the folk music is a commercial recording and this
repo is public, so `assets/audio/Radio Vietnam/music/*.ogg` is **gitignored**. A fresh clone gets a
broadcast-only radio and one `push_warning`, by design — it is not a bug. `radio_manifest.json` names
the tracks so the absence is legible rather than silent.

**Fossil law (ADR-023):** 64 placeholder wavs + sidecars deleted for the five weapons retired by
ADR-016 Amendment C (`car15`, `sks`, `thompson`, `kar98k`, `mp40`) — verified zero references outside
`tests/`. Also removed `fire_mosin_2/3` synth clones that would otherwise have round-robined against
the one real Mosin recording.

**Still open:** `m1911`, `shotgun` and all four launchers remain synth. `mosin`/`m70`/`m14` carry ONE
near-report variant because the pack holds exactly one genuine 7.62x54R take (measured: all six
candidate slices cross-correlate 0.99–1.00 — they are the same shot copy-pasted).
