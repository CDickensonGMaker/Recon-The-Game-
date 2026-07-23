# Changelog

All notable changes to RECON.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). RECON is pre-alpha with
no tagged releases and no public build, so entries are grouped by dated development milestone rather
than by version number. Every entry below is drawn from committed history.

---

## [Unreleased]

### Fixed
- Convoys never spawned — the mission clock was set after the convoy was scheduled, not before.

### Changed
- **Shared combat posture across all AI (Part A).** Crouch to hold ground, stand to push. Wall-lean
  is only permitted when a man is actually at a wall. Suppression now applies to every faction
  rather than a subset.

---

## 2026-07-20 — The living world

The AO stopped being scenery. This wave gave it traffic, residents, weather-aware AI, and events
that reach the player unprompted.

### Added
- **Roads as one derived authority**, with the traffic that drives them — convoys and civilian
  movement run on the derived network instead of ad-hoc paths.
- **A US garrison living inside the wire** — men on the firebase with posts and routines, plus
  ambient friendly patrols operating in the AO independently of the player.
- **Dynamic world events** that escalate into a live crisis and reach the player.
- **Fire missions with real warheads** and a footprint you place before you call it.
- **The RTO handset unified with the fire-support net** — one system instead of two parallel ones.
- **Firebase night-defense encounter**, including a sapper wire-assault driven by real satchel
  charges rather than a scripted orphan.
- **Armorer's bench** — click-to-select weapon rack with per-weapon fouling, the only full repair
  for weapon condition.
- **The whole air fleet flies**, and Hueys land at the firebase.
- **Villagers walk as households** to the paddy, and both villagers and garrison are already
  standing where the simulation clock says they should be at boot.
- HUD affordances for flares, claymores and satchels; the RTO's radio tether and the point man's
  scan became visible.

### Changed
- **Darkness lowers the shared AI sight cap; a flare lifts it locally**, both under SimClock
  authority.
- **Hydrology became the single authority** for where water goes; the satchel charge became a real
  world verb.
- Player squad breaks at ~45% strength, matching the enemy authority.
- Muzzle flash and explosion lighting converted to fake lights (ADR-026 graphics budget).
- Boot now lands directly in the patrol, and the performance probe measures the world the player
  actually walks.

### Removed
- Three unwired systems deleted outright, plus the dead objective counter and phantom anchor keys.
- ADR-025 marked superseded — it was pointing work at a condemned system.

### Fixed
- Gib despawn timers were calling into freed bodies.
- Agents queried the navigation map before it had synchronized.
- The flight schedule leaked across patrols.
- The debrief now reads its result dictionary defensively.

---

## 2026-07-19 — Canon truth pass, and the laws that hold it

A day spent making the documents agree with the code, and building machinery so they cannot drift
apart again silently.

### Added
- **The Pointer Law** — any document asserting the state of the code must cite `file:line` or name
  the probe that proves it. Enforced weakly by `tools/probe_doc_pointers.py`, which catches the
  shape rather than the truth.
- **The NO MORE DRIFT standing law** — when you touch a file and find a claim that is no longer
  true, you correct it in the same change. You never read past it.
- `probe_texture_coverage` — headless audit for untextured surfaces.
- Civilians work their schedules; camps keep the hour.

### Changed
- **One height authority:** `TerrainConfig.WORLD_HEIGHT_MAX`.
- Squad walks its own pace — faster gait, formation hysteresis, slot deadzone, world-honest sight.
- Every character carries its own gibs, not just the rifleman.
- Every launcher fires its own warhead.
- Patrol routes and crater edits obey the firebase keep-out.
- The fossil ratchet was made structurally incapable of growth.
- The US model truth source (`us_base_v3.blend`) moved into Git LFS rather than living untracked on
  a single disk.

### Fixed
- Civilians can be killed, and the village stopped posing like a firing line.
- `.gitignore` hardened against six oversized blobs that had blocked the push for 97 commits.
- The ally blooper fires the player's round.

### Removed
- `art_source/` retired — one pose survives, in `assets/shared/rigs`.
- A test that never parsed. ADR-026 stopped claiming a locked renderer.

---

## 2026-07-17 → 2026-07-18 — The open patrol pivot

The largest structural change in the project's life: the mission-and-briefing game was deleted and
replaced with a single continuous patrol.

### Added
- **ADR-029 — the open patrol simulator.** You boot seated at the firebase, walk out the wire gate
  on one diegetic pointer, find sites unguided, and come back. `"PATROL"` is the only mission type
  the generator produces.
- **ADR-028 — one world-build path.** The unified game world became the protected foundation:
  resident, deterministic, refined rather than rebuilt.
- `fsb_main` — the established firebase, realized from a live authored selection, with the wire as
  law (keep-out) and a faithful export pipeline.
- `TreeCoverLayer` — near-solid-collidable / far-card vegetation LOD, dense-jungle zoning, and a
  per-chunk collider cap.
- Village assault wave — 8-man squad ride, weapons-tight doctrine, market props, living camp.
- The activity-tiered AI body gate: the brain always ticks, the body follows perceivability.

### Changed
- **One terrain classifier** — AI concealment now matches the visible jungle instead of disagreeing
  with it.
- Crater profiles re-tuned to meters-authored real artillery scale.
- Forward+ ratified as the renderer of record (ADR-026), with sun-shadow truth recorded.
- Foliage view distance shipped at 80m, down from 128m.
- Crouching in vegetation conceals; camp fires are per-witness rather than instant death.

### Removed
- **The briefing / offer / mission-select layer, deleted.** No op to pick, no fly-in, no bird to
  reach.
- The old firebase buried under the fossil law. `BillboardVegetation` and `VillageSpawner` retired.

### Fixed
- **P0: the buried firebase**, plus the save-restore re-seat bug behind it — and the fresh-player
  law that came out of it (dev save data masks fresh-player bugs; probe from virgin saves).
- Tree opacity uses a hard PS2 LOD snap, not an alpha-dither fade.
- The fossil probe now scans `terrain/`, closing a blind spot.

---

## 2026-07-16 — The great flattening, and the frame budget

### Changed
- **ADR-016 Amendment H — damage flattened.** Base 27 for every rifle, SMG and pistol; MG class 42;
  sniper 87; buckshot 35 per pellet. Weapon identity moved entirely into accuracy, fire rate,
  handling and recoil. Explosives set at M26 190 / M79 150 / LAW 250 / RPG-2 250 / RPG-7 290.
- **Unified AI accuracy into one symmetric model** with a single firefight dial, replacing separate
  ally and enemy models.
- Worldgen wave 1: creeks and rivers only for water, spaced flat villages, larger paddies.

### Added
- **ADR-026 — the PS2 graphics budget.** Cheap GPU wins took the night-jungle bench from 14 to 23
  fps; fighters stayed uncapped and AI became activity-tiered.
- Night-jungle firefight bench with a live targeted profiling overlay: CPU/GPU split, draw calls,
  frame graph, spike catcher, per-system buckets, F1–F6 attribution toggles.
- Tactical crouch locomotion — `low_posture` flag and `cover_to_stand` transitions.
- Grunt Viewer bench, with skin tone and face guaranteed to stay a matched pair.

### Fixed
- Ally cover arrival staggered, killing the unison roll.

---

## 2026-07-13 → 2026-07-14 — The grunt, not the ghost

### Added
- **The medic is in the game** — `us_medic.glb` and the aid bag, both built through the fabric tool.
- Village and hideout procedural spawner foundation, then building-model variety and scatter props
  at RTS-like density.
- **Art-ahead wiring** — the attach socket is built before the art, so the art lands and works.

### Changed
- **Restructured to one asset tree, one folder per faction.**
- `us_grunt_v3` went live: the helmet and the ruck leave the hurtbox.

### Removed
- Dead `sprite_frames` and stale US lineage blends.

---

## 2026-07-10 → 2026-07-12 — Audit #2, and the process that followed

The audit found the project's worst drift was not in the code — strict typing held — but in the
documents governing it. Four competing roadmaps, a bible that was 10/12 unwritten, and a `CLAUDE.md`
teaching a dead renderer, a dead damage grammar and a dead FOV policy to every fresh session.

### Added
- **`production/GAME_GUIDE.md` and 15 ADRs**, establishing canon.
- **ADR-014 — the CANON / LOG / DEAD document hierarchy.**
- **ADR-015 — verification and gate law**, giving the process mechanical teeth.
- **ADR-023 — the fossil law:** a system's replacement is not shipped until its predecessor is
  deleted. Enforced by `tests/test_fossils.tscn` against a baseline whose ceiling can only ratchet
  down.
- **ADR-021 (patrols)** and **ADR-022 (the map is the player's memory, and he is allowed to be
  wrong)**.
- **The War Room as the default process** for any change, small fix included.
- **Real projectiles** — hitscan retired. `BulletSystem` simulates every small-arms round with
  muzzle spawn, gravity drop, segment-cast flight and arrival damage. Tracers *are* the bullet.
- **Hitzone 2.0** — mesh-hull zones harvested from body mesh vertices, limbs split upper/lower into
  11 regions, bone-synced per tick, with a mouse-driven tuning bench.
- Ragdoll v1 on a shared 13-bone physical skeleton, severed parts that survive the physics sim, and
  the gore lab bench.
- The patrol lab — a god's-eye view running real `EnemyBase` / `EnemySquad` code.
- The gun range, the viewmodel alignment bench with bore calibration, and the hitzone editor.
- Jungle rebuilt: 30 flora species, 19 authored patches, gallery-forest creeks, real lianas.
- Civilians as a full cast — faces, woven cloth, hats, tools, and seven behavioral clips.
- **The witness rule (ADR-005)** — a silent kill is finally silent.
- **AI goal doctrine** — commitment, personality spectrum, morale break ladder, full friendly fire
  and muzzle discipline on both factions.

### Changed
- **ADR-016 — the dice are retired.** Damage became flat base × zone, deterministic and pure.
- Concealment is not cover: rounds punch through thatch, bamboo and brush.
- Exposure-ramped AI accuracy, cover-first engagement, bounding advances under covering fire.
- The HP bar was removed in favor of a hurt vignette on the suppression shader.

### Fixed
- **The 3-shot headshot bug** — the movement capsule physically shadowed the smaller hitzones, so
  every round scored flat unmultiplied damage. The capsule is now bullet-invisible.
- Hitzone seams: 12.9% of frontal hits were landing on nothing.
- Sight zeroing, real dispersion and AI hold-over, from the ballistics audit.
- RPG fuze arming distance — the reason rockets never hit anything.
- Jungle palette shipping near-black (the atlas needed sRGB encoding).
- Jolt physics restored twice after a killed A/B benchmark left `project.godot` on Godot Physics.

---

## 2026-07-07 — Initial

- Project created as a merge of the Hell of Duty FPS core and the TerrainEngine project, with
  `res://` paths remapped and both source projects left untouched.
- M0 audit cleanup: dead code removed, weapon switching consolidated.
