# Audit Handoff — read this before the next full audit

Written 2026-07-08 at the end of the sprite/model + 10-step remediation session,
for a full game audit to run after a context clear.

## Where the code is
- Branch: `audit/remediation` — merged into `master` and pushed to `origin`
  (`https://github.com/CDickensonGMaker/Recon-The-Game-.git`); it is in sync with
  `origin/audit/remediation` and contains nothing `master` lacks. This repo HAS a
  remote — CLAUDE.md's mandatory `git push` session-completion step applies.
- Suite: `powershell -File run_all_tests.ps1` → **27 PASS / 4 LEAK / 0 FAIL / 0 XFAIL**
  (31 tests). LEAK = an audio player outliving a headless quit; harmless, tracked
  as AUDIT-12, freed for real in-game by `MissionScope.reset()`.
- The harness is trustworthy now: it captures stderr and FAILs on `ERROR:` /
  `previously freed` / `[NAV]`. It was verified by positive control, twice — do
  not assume a green suite without checking the harness still fires.

## Two prior audits already on disk — do not re-derive
- `CODE_AUDIT.md` — the first two-pass audit (AUDIT-01..13). Most are CLOSED now.
- `SPRITE_INTEGRATION_PLAN.md`, `purpose-a-10-step-lively-island.md` (in
  ~/.claude/plans/) — the plans that were executed this session.

## What got fixed this session (verify these HELD, don't re-report as open)
1. Test harness + save isolation (`--test-save` → campaign_test.cfg).
2. `MissionScope.reset()` — cross-mission state leaks (fire-menu softlock,
   crater persistence, sting, wave coroutine, cover claims, sprite/nav caches).
3. Determinism: R88 seed replay, seeded shuffle, per-mission global-rng seed,
   campaign-conditional AA on its own stream.
4. Save integrity: version key + `.bak` + commit-on-debrief.
5. **Navmesh (was the R16 no-op): `scripts/world/nav_baker.gd`** bakes per-site.
   `test_nav_path` proves a real enemy paths around a hut. This is the headline.
6. Skills: Barracks 2+4 split — player skills vs role skills read off the roster.
7. EnemyData: 10 dead exports now differentiate archetypes.
8. Sprites: `scripts/visuals/` (manifest/library/actor/state_map). Every NPC is
   an 8-dir billboard; capsule fallback for unrendered units.
9. RPG-2: the dormant projectile pool finally has a caller (`nva_rpg`).
10. Deleted: test_arena subgraph + 5 orphan terrain/water files.
11. Huey: solo animated model, rotors spin in code.
12. Combat Lab (`scenes/levels/combat_lab.tscn`): SPRITE/MODEL/CAPSULE A/B.

## KNOWN-STILL-OPEN — the audit should CONFIRM and PRIORITISE these, not rediscover
- **Projectile PLAYER path**: only enemies fire the pool today. weapon_holder is
  still hitscan. Player M79/LAW/RPG want the same treatment.
- **Inert signals** still emitted-into-void: `downed_started`, the grenade
  cook/throw set, `ads_changed`/`reload_cancelled` (declared, never emitted).
- **Perf**: measured ~20 FPS steady-state on Intel UHD (NOT the 35.6 in
  WAVE3_REPORT). `squad_system` per-frame O(n²) group scans, `gun_fx` per-shot
  allocations while a 50-node projectile pool sits idle. This is the biggest
  real debt. Use the combat lab's draws/prims/fps readout.
- **AUDIT-05**: no damage falloff by range — effective_range still never read.
- **AUDIT-06**: GameEnums autoload + data/vietnam tables (~1400 lines) still
  loaded every boot, referenced by nothing live.

## NEW since the last audit — verify these, they may not be fully wired
- `scripts/autoload/audio_manager.gd` — NEW autoload (Caleb added). The old
  ambience was a non-positional 2D loop (the "constant chirp"); check whether
  audio_manager replaces it and whether it is positional per the feedback.
- `scripts/autoload/game_settings.gd` — check it is still consistent.
- 8 rigged 3D models in `assets/models/characters/` (us_grunt, us_grunt_black,
  us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy). Mixamo
  28-bone skeleton, 21 clips each. Lab MODEL mode drives them. NOT in the
  shipped game yet — EnemyBase always builds a SpriteActor.
- weapon_holder.gd has NEW recoil fields (recoil_climb_per_shot,
  recoil_first_shot_mult, recoil_climb_max, recoil_recovery) + `_resolve_hit()`
  + `damage_multiplier_at()` — Caleb was editing this live. Confirm it compiles
  and the falloff there is consistent with AUDIT-05.

## Design epics filed, gated on a War Room (hard content) — NOT bugs
Battle Director, Ride-or-Walk, Capture (POW: escape/bribe/rescue/suicide/wait),
RPG money loop. The Capture epic depends on ragdoll + wounded-drag, which the
models now make possible (PhysicalBone3D off the Mixamo skeleton).

## The one meta-lesson for the auditor
This codebase's failure mode is the SILENT NO-OP: a feature written, tested,
committed, reported shipped, that does nothing at runtime (R16 navmesh; the
Barracks; seed replay; dead projectile pool; muzzle=0-poly; enemy AOE hitting
only enemies; the crippled accuracy penalty wiped every frame). Every one had a
green light on it. When auditing, do not trust that a system RUNS just because it
EXISTS — trace it to an observable effect, and be skeptical of your own checks
(two detector bugs this session would have made a green suite meaningless).
