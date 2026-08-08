# BUILD PLAN — the three ruled-in loops + destructible jungle (2026-08-07 night)

**His order: "drum up a plan to get all this done and loop until its finished."**
Scope = the 8/7 rulings: **S29 destructible jungle → S26-code camp stations → S27 mortar
harassment → S28 pilot recovery**, plus presenting the crashed A-1 renders when they land.
Claude works this plan autonomously (code is Claude's, costs Caleb zero art-days), reporting
after each phase. Anything requiring HIS eyes (renders, playtests) queues for him and does not
block the next code phase.

**Standing laws that bind every phase:** state-swap never RigidBody (ADR-031) · no standing
colliders in the jungle (his 8/7 ruling) · comment discipline · fossil law (retire what each
phase replaces, same change) · suite must not get redder (baseline: run 8's like-for-like
39 PASS / 5 FAIL over 50) · mortar timing RANDOM, never a fixed cadence · ONE airframe, ONE
event type for S28.

---

## PHASE A — rename the segment library ✅ DONE 8/7
60 GLBs renamed `_low/_mid/_high` → `_stump/_stem/_crown` (break bands, not LODs). Stale
`.import` sidecars deleted (Godot regenerates). The 5 read-only donor references in
`tools/build_nva_gear_foliage.py` + the `nva_vc_gear.json` note updated to `_stump` names.
**Trap recorded:** pre-existing `tree_stump.glb` also matches `*_stump.glb` — code must key on
full basenames (e.g. `broadleaf_a_stump`), never on the bare suffix.

## PHASE B — S29 destructible jungle (code, ~2–4 days of work compressed hard)
1. **Inventory + load probe**: a test that loads all 60 `_stump/_stem/_crown` GLBs, asserts
   3 parts per species, measures per-part bounds → writes `data/veg_break_bands.json`
   (species → part paths + band heights). This file is the single source of truth downstream.
2. **TreeBreakSystem** (new, `scripts/world/tree_break_system.gd`): registry of breakable tree
   instances sourced from the vegetation MultiMesh placements. NO colliders at rest. API:
   `query_ahead(from, dir, range)` (spatial hash lookup, not physics) and
   `promote(instance_id) -> BrokenTree`.
3. **Promotion**: hide the MultiMesh instance, spawn the 3-part segmented version in place
   (same transform), give parts cheap colliders. Idle promotion budget-capped per frame.
4. **Break logic**: blast calls `break_at(height)` → band nearest hit height; parts above hinge
   and fall (reuse FellableTree's scripted-hinge math), stump/below stays standing with a
   shortened collider. Fallen crown/stem register as cover.
5. **Wiring**: explosion path (combat_manager blast loop) + projectile ray-ahead for rockets/
   RPG/mortar shells. Bullets do NOT fell trees.
6. **Fossil burial**: refit `FellableTree` callers (`ai_stress_arena`, `support_fire_range`) onto
   the new system; delete the whole-tree hinge path in the same change.
7. **Verify**: new probe green, suite not redder, headless boot clean, and a support-fire-range
   smoke test: one blast → tree breaks at height, stump stands. THEN queue for his chamber
   verdict (his eyes required — ADR-015 spirit).

## PHASE C — S26-code + S27 mortar harassment (~1–2 days)
1. **Camp stations**: fix `mission_generator.gd:296` village-only gate; `stamp_vc_camp()` sets
   `work_stations`; align the `.001` suffix strip with the firebase path. VC mortar crew now
   lives in the demo camp (his ruling: resident of an existing camp ONLY).
2. **Harassment fire**: camp-sourced `fire_mortar_volley` at RANDOM intervals (wide seeded band,
   long silences, occasional double stonks — no pattern). Target = the firebase, never the
   player. Diegetic cue only: tube thump audio from the camp bearing + squad bark. Defaults
   standing unless he overrules: rare-but-real garrison wounds (casualty ledger) · no fire first
   ~10 min · crew dead OR tube destroyed = silence, no re-crew that day.
3. **Night link**: camp silenced before nightfall → SiegeDirector's ranging walk cancelled.
4. **Verify**: probe for the random scheduler (seeded, no fixed cadence), silence-on-kill, night
   link; suite not redder. Queue his playtest.

## PHASE D — S28 pilot recovery (~2–4 days)
1. **Crashed A-1 lands** (agent in flight): he judges renders → GLB blessed or redirected.
2. **Shoot-down event**: chance roll per air pass (seeded) → aircraft breaks formation, trails
   smoke, dives beyond treeline → swap to crash: explosion + persistent smoke column (the
   diegetic bearing marker). AA gun = silent kill (no crew anims).
3. **Wreck + pilot**: `_passable_near` placement; pilot spawns at wreck (needs the pilot
   bind/gib fixes — S18); ally-follow back to the wire → aid station → casualty ledger banks
   the save. One lazy VC group placed near the wreck at crash time.
4. **Verify**: event fires deterministically under a test seed, pilot follows and banks, no
   orphan smoke, suite not redder. Queue his playtest.

## LOOP DISCIPLINE
- Work phases in order; within a phase, delegate implementation to subagents where clean
  (model tiering law) and verify their output before moving on.
- After each phase: commit + push, update this file's checkboxes, update the ship-audit queue,
  note anything needing HIS ruling in the decision queue — never silently decide design.
- The loop ends when Phases B–D are code-complete and verified, with his-eyes items queued.
  His playtest verdicts are NOT loop-blockers; they're the exit criteria for the tasks, and
  they wait for him.

| Phase | State |
|---|---|
| A rename | ✅ done 8/7 |
| B destructible jungle | ⬜ not started |
| C camp stations + mortars | ⬜ not started |
| D pilot recovery | ⬜ waiting on crashed-A-1 renders + his blessing; code not started |
