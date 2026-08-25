# HANDOFF — 2026-08-24 session (death loop · magazine ammo · AI doctrine · firebase sync)

Written at the Summoner's 95%-limit call. Next session: read this, then the war-room rulings it
points at. Everything below is UNCOMMITTED in the working tree unless marked otherwise.

## THE RULED BUILD QUEUE (his words, 2026-08-24)
body-swap → magazine ammo → AI Phases 1-2-3 → **THE SIEGE PLAYTEST verifies all of it**.
His machine is busy with Blender jobs — do NOT press for the playtest, do NOT run the Godot
suite until it frees up. The playtest is the acceptance gate for the whole stack.

## SHIPPED THIS SESSION (all uncommitted)
1. **Death body-swap** (rulings: `war_room/2026-08-22_player_death_lives/rulings.md`) —
   `scripts/player/body_swap_system.gd` new; `health_system.gd` swap_handler hook in
   force_death; `demo_game.gd` installs it + end-card KIA rows + "THE WIRE BROKE BEFORE DAWN".
   Pool = 4 men total, pre-picked from promoted garrison, no number ever rendered.
2. **Death camera lay-down** (his ruling: drop, lie still, fade AFTER death) — `player.gd`
   `_collapse_camera` rewritten (was a torque-kicked SPHERE = rolled forever; also fired on
   downed and revive never restored it). New `recover_from_collapse()` wired into revive +
   swap wake. Epitaph black now fades in 0.8s.
3. **Magazine ammo S1+S2 COMPLETE** (rulings: `war_room/2026-08-24_magazine_ammo/rulings.md`)
   — mag arrays in weapon_holder, partial retention, fullest-first reload, FeedType enum +
   .tres tags, save migration `mag_model=1`, HUD "MAGS # # = -" row, supply-crate verb killed
   (RTO bird drops FieldCache boxes), seeded partial-mag drops, gunner belt verb
   "[F] BELT FROM <name>" (8 belts, restocks from ammo box, corpse yields belts or they burn).
   Probe: `tests/test_magazine_ammo.gd` cases (a)-(g). NOT yet run.
4. **Firebase anim sync** — audit `production/AUDIT_2026-08-24_firebase_anim_sync.md`; fixed:
   VC camp sleep, US garrison sleep, burn-cower clip, baked aid-station cast animates,
   stale counts. `fsb_main_v3.glb` gained GUN_POINT_001 + APPROACH_002 (headless GLB surgery,
   backup in scratchpad, BIN chunk untouched — Godot reimports on next editor open). M101
   recoil wired: `site_planner.gd _wire_m101_rigs()` instances `fb_emplacement_m101.glb`
   (which carries the M101Rig clip) over the clip-less baked guns.
5. **AI doctrine specced + ruled** (`war_room/2026-08-24_ai_doctrine/` — synthesis + rulings):
   all 3 phases build before the siege test. Bounce diagnosis is measured fact in
   `analysis/systems_cartographer.md`; research shortlist in `analysis/research_advanced_ai.md`.

## IN FLIGHT AT HANDOFF (agents were running — VERIFY their work landed before trusting)
- **AI Phase 1 (de-bounce)**: interrupt debounce ~2.5s refractory, fight-scoped renewable
  cover commitment, suppression gate stability, goal hysteresis (margin + sustained),
  ally target stickiness. Files: enemy_base/ally_base/combat_goals/combat_posture. The siege
  assault_press must still press the wire — verify.
- **Work-point exclusivity** (his ruling, memory `recon-work-point-exclusivity-2026-08-24`):
  one man per work point (claim ledger both populations), DIG gated to berm/bunker-adjacent
  spots, shovel attach guarded on prop existence.
- **Shovel prop**: headless Blender build of a folded-out M-1943 e-tool
  (research-first, PSX budget, expected ~`assets/props/prop_etool_shovel.glb` — reconcile the
  const path in the work-point code with the actual export path).

## NOT YET DONE (next session's list, in order)
1. Verify the three in-flight builds landed sane (read their files, check the probe still
   parses; if an agent died mid-edit, `git diff` shows it).
2. **AI Phase 2**: per-side squad coordinator autoload — ONE suppressor slot per squad (gives
   SUPPRESS_TARGET an executor: fire at last-known cells, write area suppression), N exposure
   tokens gating leave-cover, cover-claim table folded in, token TTLs. 1-2 Hz squad tick,
   O(1) per man. Spec: synthesis Phase 2 + research doc technique #1.
3. **AI Phase 3**: two-element bounding overwatch on the coordinator (refusable orders,
   staggered moves). Spec: synthesis Phase 3.
4. **Doctrine layer**: US/NVA/VC .tres doctrine files over the Phase-1 constants;
   `assault_press` doctrine = tokens ≈ ∞ (the 7/30 siege ruling survives by data).
5. **Run the suite headless** (`run_all_tests.ps1`) ONCE his Blender jobs finish — before his
   playtest. Expect `test_magazine_ammo` new; watch the four ratchet probes (fossils,
   test-only liveness, doc pointers, ship parity).
6. **COMMIT + PUSH** — the tree also carries PRE-EXISTING uncommitted work from earlier
   sessions (CLAUDE.md, game_flow.gd, perf_probe.gd, ac47 .import, war_room 8/18+8/22 folders,
   WHEN_YOU_RETURN 8/15, texture work order + shrink tools). Commit today's work in clear
   commits; judge the stale files separately — do not silently sweep them in.
7. **THE SIEGE PLAYTEST** (his eye, ADR-015) — discharges the demo gate AND judges: body-swap
   feel, mag economy (1+6×20, gunner 8 belts), AI bounce, camera lay-down.

## AWAITING HIS EYE / HIS CALL (surface, don't nag)
- Howitzer recoil now instanced — worth a look in editor (baked guns hidden, chunk overlaid).
- 9 VC/NVA units still dead to the face dealer + face-atlas retry law (measure the UV island
  first) — `recon-vc-nva-face-atlas-fix-2026-08-18`.
- Texture work order #1 (one-command redo) still queued: `WORK_ORDER_2026-08-18_unit_texture_optimization.md`.
- Zombie GLBs gone from disk (12 files, .import stubs only) + claymore viewmodel missing —
  `wyrm-workshop\out\recon_assets_report.md`.

## LAWS THAT BIT TODAY (keep honoring)
Preload fresh scripts in demo_game (class_name not registered headless) · a build script
cannot verify its own output (fresh re-parse caught the GLB work) · his machine busy = no
Godot/Blender GUI, no suite, no perf-true playtest · comment discipline/fossil law on every
edit (zero-grep proof shipped with the ammo fossils).
