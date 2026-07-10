# TECHNICAL DIRECTOR — DRIFT AUDIT #2 (2026-07-10)

Lens: engine, performance, architecture. Bound by `~/.claude/architect_knowledge/godot_standards.md`.
Standing directive: PERF FIRST ALWAYS. Last measured: 19–25 FPS (bead 8pbo, 2026-07-08).
Every claim below is grounded in file:line, git, beads, or the player's own log files.

---

## (a) DRIFT CATALOG

### A1. DECREE ITEM 4 (perf-spike day) — NOT EXECUTED. Zero rendering changes since the audit.
- **Decree says** (archive/2026-07-09_full_game_audit/synthesis.md, wound #3 + build order #4): "One measured
  perf-spike day → close 8pbo with measurements."
- **Code says:** `project.godot:277-281` — the entire `[rendering]` section is still just
  `textures/canvas_textures/default_texture_filter=0` and `scaling_3d/scale=0.77`. **`rendering_method` has
  STILL never been set** — Forward+ on Intel UHD. Git proves the 0.77 scale predates the audit (commit
  `c17c1fe`, the WAVE3 "35.6 avg" gate); `git log -S` shows no rendering-section change since.
- **Beads say:** 8pbo is **OPEN, P2, last updated 2026-07-09** — the update is my own prior audit note. No new
  measurement exists anywhere (no new probe log, no doc, no bead note) since probe_perf_decay on 07-08.
- **Which is right:** the decree. ~30 commits of features (BLOOD v2, campaign loop, survival, PSX art) shipped
  on top of a known 19–25 FPS floor, violating the Summoner's standing "perf first always."
- **Partial credit (drift in the good direction, unratified):** `scripts/combat/gun_fx.gd:59-61` now caps
  concurrent FX (`MAX_FLASHES=8`, `MAX_EXPLOSIONS=6`) — the audit's "uncapped OmniLight per muzzle flash" is
  half-addressed. But each flash still allocates a fresh `OmniLight3D` + `QuadMesh` + `StandardMaterial3D`
  (gun_fx.gd:195-219) — no pooling (godot_standards Performance Mandates: pool frequently spawned objects).
- **Still not done from the 8pbo checklist:** AI frame budget — `MAX_THINK_TIME` is *still* declared and never
  referenced (`scripts/enemies/enemy_base.gd:175`, sole occurrence in repo). Scar decals past the deform
  ceiling — see A6.
- **Update:** run the perf-spike day. It is now two decrees overdue.

### A2. STEALTH WITNESSED-CONTACT FIX — CLAIMED DONE, NOT DONE. Code comment lies.
- **Briefing says** ("what changed"): "Decree items executed: … stealth witnessed-contact fix (o18o — verify
  actually fixed)."
- **Beads say:** o18o is **OPEN, P1** ("take_damage unconditionally stamps COMBAT contact").
- **Code says:** `scripts/enemies/enemy_base.gd:1497` — `take_damage()` still calls
  `_set_tier(AlertTier.COMBAT)` unconditionally on every hit, including the killing blow;
  `_set_tier` stamps the global beacon `EnemyBase.last_combat_contact_ms` (enemy_base.gd:627); the director
  polls it and fires "YOU'VE BEEN MADE" (`scripts/missions/mission_director.gd:66-69`). A silent, unwitnessed
  one-shot kill still raises the AO alarm.
- **Worse:** the comment at enemy_base.gd:189-192 *claims the opposite*: "a silent, unwitnessed kill no longer
  summons the QRF (stealth becomes an economy, not a fail gate)." The beacon architecture was built
  (improvement over polling per-enemy state), but the witnessed-ness guard the bead demands was never written.
  This is the most dangerous drift class in the codebase: **documentation inside the code asserting a fix that
  does not exist.**
- **Which is right:** the bead. Fix: stamp the beacon from `take_damage` only if a *surviving* enemy witnessed
  (LOS/proximity/noise), or stamp on tier transitions driven by perception (line 613) and never from the
  damage path when the hit kills.

### A3. TERRAIN POP (playtest R2, ground truth) — mechanism diagnosed: binary chunk streaming visible inside a 1280m map; no LOD exists at all.
- **What the docs/design imply:** streamed terrain for "large maps (3km x 3km)" (`terrain/core/terrain_manager.gd:3`,
  `heightmap_storage.gd:4`).
- **What the code actually does:** the AO is **1280m** — `scripts/levels/world_config.gd:7-11`
  (`MAP_SIZE=1280, CHUNK_SIZE=256, CELL_SIZE=4.0, LOAD_DISTANCE=2, UNLOAD_DISTANCE=3`), wired at
  `scripts/levels/game_world.gd:78-82`. That is a **5×5 = 25-chunk world**.
  - There is **no terrain LOD**: `terrain_chunk.gd` builds one full-res mesh per chunk (64×64 quads at 4m
    cells), full stop. The "LOD swap" hypothesized in the bead does not exist; the pop is not an LOD seam.
  - The actual mechanism: `_stream_chunks_around_camera()` (terrain_manager.gd:231-238) runs every frame.
    Crossing a 256m chunk line does two things at once:
    1. **Unload pop:** `_unload_distant_chunks` frees every chunk beyond Chebyshev 3 (768m). On a 1280m open
       AO with hillside sightlines you can *see the whole map*, so far tiles of terrain + their vegetation
       visibly vanish/appear as whole 256m squares the instant you cross a boundary. That is exactly
       "terrain jumps crossing cell boundaries."
    2. **Load hitch:** `_load_chunks_around` (242-257) loads *every* newly-in-range chunk **synchronously in
       a single frame** — each one a SurfaceTool mesh build (terrain_chunk.gd:51-129), a
       `create_trimesh_shape()` collision cook (terrain_chunk.gd:236-252), *and*
       `vegetation_manager.generate_for_chunk` (terrain_manager.gd:278). The rebuild path has an 8ms/frame
       budget (`REBUILD_BUDGET_MS`, terrain_manager.gd:52, 84-95); **the streaming path has none.** At ~20
       FPS baseline the hitch reads as the world lurching.
- **Aggravator:** all 25 chunks are loaded up-front anyway (`_load_initial_chunks_async` loads the entire
  grid, terrain_manager.gd:209-227; bead 8pbo's probe confirms "chunks 25 — ALL FLAT" at steady state). So on
  the current map **streaming saves nothing and only causes the bug**: it unloads terrain the initial load
  paid for, then re-buys it with a main-thread hitch.
- **Which is right:** neither doc nor code — the *config* is right (1280m) and the *streaming policy* is a
  3km-era holdover. **Fix shape (cheap, measured):** for maps ≤ ~2km, disable streaming after initial load
  (skip `_stream_chunks_around_camera`, or set unload_distance ≥ chunks_per_side). 25 static chunks ≈ 200k
  terrain tris — the probe already proves the GPU holds them flat. Keep streaming code for a future 3km map
  behind the same time-budget as the rebuild queue plus threaded mesh builds. This is a ~5-line change and
  directly closes the Catacombs-class bug.

### A4. TINY UNITS (playtest R2, ground truth) — root cause found in the player's own logs: `ModelActor._aabb_of` measures raw mesh space, ignoring the transform chain. The scale goes wrong twice.
- **Doc says:** `production/GAME_SCALE_STANDARD.md:8-13` — engine auto-normalizes any character to 1.7132m
  "by AABB," so a 1.9m export "won't break."
- **Code says:** `scripts/visuals/model_actor.gd:138-152` — `_aabb_of()` merges `mi.get_aabb()` per
  MeshInstance3D and corrects **only** by `a.position += mi.position`. It ignores (1) the mesh instance's own
  basis/scale, (2) every intermediate node's transform — notably the **armature/skeleton node scale** that
  glTF exporters bake to compensate cm-scale rigs (Mixamo-style: vertices at ×100, armature scale 0.01).
- **Ground truth (Caleb's playtest logs, `%APPDATA%/Godot/app_userdata/RECONgame/logs/recon*.log`, the [MODEL]
  diagnostic added for bead n2ij):**
  ```
  [MODEL] vc2_mainforce aabb_h=87.20 k=0.020
  [MODEL] us_grunt      aabb_h=62.24 k=0.028
  [MODEL] vc3_sapper    aabb_h=61.37 k=0.028
  [MODEL] vc5_nva       aabb_h=37.39 k=0.046
  [MODEL] vc1_farmer    aabb_h=10.59 k=0.162
  [MODEL] vc6_heavy     aabb_h= 8.40 k=0.204
  ```
  The GLBs measure ~1.9m in Blender, but the *raw mesh AABBs* measure 8–87m. The exporter's compensating node
  scale renders them at ~1.9m — then `setup()` (model_actor.gd:45-50) divides by the raw 8–87m height and
  shrinks the already-correct model by 5–50×. **Two scale factors: the export compensation the AABB ignores,
  and the normalization applied on top of it.** k spread (0.020–0.204) shows every model was exported at a
  different internal unit scale — normalization *would* have hidden this if it measured correctly.
- **Fix shape:** measure in `_inst` space — transform each MeshInstance3D's AABB corners by
  `mi.global_transform` relative to `_inst.global_transform` (after `add_child`), not `mi.position`. One
  function. Then re-check logs for k ≈ 0.9 per the diagnostic's own hint (model_actor.gd:50).
  **Second-order risk to verify after the fix:** Mixamo clips sometimes key scale on hips/armature — if a unit
  is correct at spawn and shrinks when `play()` starts, the animation is re-applying export scale; strip scale
  tracks on import.
- **Capsules:** all 5 enemy .tres map to existing GLBs (`data/enemies/*.tres` sprite_unit vs
  `assets/models/characters/*.glb` — vc1/2/3/5/6 all present), so enemy capsules mean `setup()` *returned
  false* (loads fine but empty AABB) or a unit with empty `sprite_unit` (WW2 holdover data). The capsule path
  is the guarded fallback at enemy_base.gd:304-315 / ally_base.gd:126 working as designed; fixing A4's
  measurement likely fixes most capsule sightings too. Confirm against the same logs.

### A5. CLAUDE.md vs code — the technical law has drifted in both directions.
| CLAUDE.md claim | Code reality | Verdict |
|---|---|---|
| "8-directional billboard sprite characters (CULTIC-style)" (header) | 3D `ModelActor` is "the DEFAULT renderer … (Caleb, locked)" (model_actor.gd:1-6; enemy_base.gd:284-285) | **Code is right; doc headline is a full renderer generation behind. Update CLAUDE.md.** |
| Damage example "`[1, 6, 45]` = 1d6+45", "Enemy HP: 60-80" | RECON d10 grammar shipped: m16a1 `[5,10,0]`, ak47 `[4,10,0]` etc. (`data/weapons/*.tres:14`); M16 is the default primary (`scripts/player/weapon_holder.gd:135`) | **Code is right (decree item 6 executed). Doc teaches the dead grammar.** |
| Physics layers table (1-7, 9) | `project.godot:266-275` matches exactly, layer 8 gap and all | No drift ✓ |
| Timestep capping `minf(delta, 0.066)` | enemy_base.gd:380, ally_base.gd:218 | No drift ✓ |
| Think/execute 6-7 Hz | enemy_base.gd:391-394 — **improved**: distance-LOD throttles think to 0.6s past 150m (enemy_base.gd:319, 41, 60) | Code better than doc; ratify the LOD in the doc |
| Viewmodel: "Scale baked into viewmodel .tscn root (e.g. 0.03 for Thompson)" | fp_arms pipeline shipped (commits 6e2fc3d, 13fcf60); Thompson is no longer the reference weapon | Doc stale; harmless but seeds wrong prompts |
- Also: dead grammar leftovers the decree ordered killed still exist — `thompson.tres` `[1,6,45]`,
  `mp40.tres` `[1,6,38]`, `kar98k.tres` `[1,10,70]`, `mosin.tres` `[1,10,68]` — flat-modifier WW2 holdovers
  still loadable (thompson still referenced by `scripts/weapons/viewmodel_editor.gd:73`).

### A6. Decal ceiling — the audit's cap request was half-implemented.
- **Decree/8pbo note says:** FIFO-cap scar decals past the deform ceiling.
- **Code says:** `terrain/systems/damage_system.gd:68,143` caps *deforms* at `MAX_DEFORMS_PER_MISSION=40`, and
  the comment at 141-142 says "past the per-mission ceiling, skip the expensive dig but keep the cheap
  veg-clear + **scar** below" — i.e. **decals intentionally keep spawning unbounded**. `scar_decals` only ever
  appends (damage_system.gd:286) and is cleared solely on mission reset (306-309). A long firefight with
  mortars/CBU accumulates unlimited `Decal` nodes — each one costs per-pixel in clustered Forward+ on the very
  GPU that can't hold 25 FPS.
- **Update:** FIFO the array past ~48 decals (`pop_front().queue_free()` — 3 lines).

### A7. SAVE BACKBONE (PHASE A, commit 97260df) — solid schema, three real robustness gaps, one silent data loss.
The good (genuinely Catacombs-grade): versioned schema with per-field defaults (`scripts/data/save_data.gd:3,
99-121`), sequential migration hook (`save_manager.gd:267-272`), corrupt-file guard (159-171), metadata-only
slot browse (252-262), deferred apply so position never lands in a dead scene (176-224), tier gating derived
from existing settings (72-87), exit autosave wrapped so a failed save can't block quit (39-44), and a real
roundtrip test (tests/test_save_roundtrip.gd). This is the best-engineered new system since the last audit.
Gaps, ranked:
1. **Non-atomic writes** — `save_game()` (save_manager.gd:92-102) opens the slot file directly and writes. A
   crash/power-cut mid-write destroys the slot, and the 30s autosave means it's frequently mid-write. Fix:
   write `save_N.sav.tmp`, then rename over; keep the previous file as `.bak`. This is *the* classic save-file
   robustness gap and it's 6 lines.
2. **Future-version loads are not rejected** — `load_game` migrates `version < SCHEMA_VERSION` (165-166) but a
   v2 save loads silently into a v1 build (fields dropped, then re-saved as v1 = destructive downgrade).
   Guard: `if version > SCHEMA_VERSION: refuse`.
3. **Cumulative playtime is lost** — `meta.playtime_s` is *session* ticks (save_manager.gd:111), overwritten
   each save; total campaign playtime never accumulates (should be `loaded_playtime + session_delta`).
4. **Untyped duck-access throughout the collect/apply path** — `player.get("stamina")`,
   hardcoded `"Head/Camera3D/WeaponHolder"` NodePath (save_manager.gd:119-146, 189-223). Violates the strict
   typing law; a renamed node or property fails *silently* (defaults win). At minimum, `push_warning` when an
   expected property is missing. Also `(wh.get("primary_ammo") as Array).duplicate()` (139-140) hard-crashes
   if the property is ever absent — the only unguarded line in the file.
5. **What ISN'T saved that should be** (beyond the documented Phase E mission section, save_data.gd:15-17):
   squad member *live* state (ally HP/ammo/position — roster XP rides in campaign.data via
   `campaign_state.gd:208-219`, but a hub save after a bloody mission resurrects wounded allies at full
   health); mission-scoped world state (craters `damage_zones`, cleared vegetation, placed claymores) —
   acceptable as Phase E, but the HARD-tier "wheels-down checkpoint" (`HubSection.checkpoint_offer`)
   resumes a mission whose world damage is gone. Name that limitation in the doc before a player names it.
6. `CampaignSection` is a raw dict passthrough (save_data.gd:50-59) — deliberate ("cfg-era fields ride along"),
   but it means campaign fields bypass the typed-defaults discipline the rest of the schema enforces.
   Acceptable; note it in the ADR.

### A8. Autoload census — 12 autoloads, two of them dead weight, one misnamed layer.
`project.godot:26-39`: GameEnums, GameManager, NoiseBus, CampaignState, GameSettings, AudioManager,
CombatManager, TerrainEngine, DamageSystem, ClearingSystem, VOManager, SaveManager.
- **GameEnums (data/vietnam/game_enums.gd) is referenced by ZERO files.** All code uses the `Enums`
  *class_name* from `scripts/autoload/enums.gd:2` (which is *not* autoloaded — the `Enums.` prefix works via
  class_name, its own comment "Accessed globally via GameEnums autoload" at enums.gd:3 is wrong). Two parallel
  enum registries, one unused autoload, one lying comment — RTS copy-in residue. Kill the GameEnums autoload
  or merge.
- **TerrainEngine** has zero `TerrainEngine.` references; it's fetched by string path
  (`get_node_or_null("/root/TerrainEngine")`, terrain_manager.gd:65) — copy-in seam, works but invisible to
  refactors.
- **DamageSystem / ClearingSystem as autoloads** are mission-scoped world systems living as globals — they
  survive scene swaps and must be manually reset per mission (damage_system reset at 306-309). Works today
  because MissionScope resets are probe-proven, but it is the god-object growth medium.
- **Coupling breadth** (files referencing each): GameManager 24, CampaignState 18, NoiseBus 17, CombatManager
  15, DamageSystem 11. GameManager at 87 lines referenced by 24 files is fine (it's a locator). No autoload→
  autoload cycles found; SaveManager depends one-way on GameManager/CampaignState/GameSettings and reaches
  GameFlow via group lookup (save_manager.gd:287-289) — clean.
- **The real god-object is not an autoload: `scripts/enemies/enemy_base.gd` is 1,737 lines** — perception,
  tiers, goals, locational damage, gut bleed-out, crippling, surrender, spider holes, visual driving, nav.
  godot_standards "methods under 30 lines / composition over inheritance" is unenforceable in a file this
  size. `player.gd` (898) and `mission_director.gd` (484, doing detection+escalation+objectives+fire-support
  input at line 202) are next. This is exactly the "days of continuous building" signature.

### A9. Input map still carries the double-bound key 6 — now load-bearing via a code comment.
`project.godot:133,178` — `cbu_strike` and `place_claymore` both bind physical 54. The same-day audit fix
made the *code* disambiguate (player.gd:620-622 guards claymore placement against the on-the-net CBU state)
rather than rebinding. That is drift-as-improvised-fix: the input map remains a trap for the next action
added, and the guard comment is the only documentation. Rebind or ADR it.

### A10. Doc sprawl / dead claims (evidence for the Arbiter's consolidation case)
- WAVE3_REPORT's "35.6 avg FPS" is refuted by the measured 19–25 (bead 8pbo) — the number came from the NS04
  gate (commit c17c1fe) under different conditions and was never reconciled.
- TerrainManager/HeightmapStorage headers still say 3km×3km; shipping config is 1280m (A3).
- CLAUDE.md items in A5. Four roadmap docs. GAME_SCALE_STANDARD.md is *good* and current — promote it to the
  game guide as-is with the A4 correction.

---

## (b) TOP 5 STRENGTHS

1. **The test harness is real engineering** (`run_all_tests.ps1`). It boots each of 34 scenes headless (true
   script re-parse — the recongame lesson applied), scans stderr for `ERROR:`/`previously freed` instead of
   trusting exit codes (lines 32-55), has XFAIL/XPASS discipline that *breaks the build when a known-red test
   passes* (23-30, 86-92), a LEAK verdict that refuses to whitewash benign noise into PASS (46-55, 95), and
   redirects saves so the suite can't wipe the player's campaign (9-13, 62).
2. **Save backbone architecture** — versioned, defaulted, migration-ready, deferred-apply, tier-gated,
   tested (A7). Best new code since the audit.
3. **Terrain deferred-rebuild queue** — 8ms/frame budget with vegetation-cache preservation
   (terrain_manager.gd:50-52, 84-120, 377-385) — the explosion-rebuild path learned the exact lesson the
   streaming path still hasn't.
4. **AI think-LOD + timestep discipline** — CLAUDE.md's Quake-3 patterns are genuinely in the code and were
   *improved* (0.6s think past 150m; desynced scan phases enemy_base.gd:233).
5. **Diagnosability culture** — file logging on (`project.godot:41-45`), the `[MODEL]` k-diagnostic, the
   8pbo bead refuting its own hypotheses with measurements. This audit could ground-truth the tiny-units bug
   *from the player's own logs* because someone left the lights on.

## (c) TOP 5 WEAKNESSES / RISKS (ranked)

1. **Perf debt is now decree-defying** — 19–25 FPS, `rendering_method` unset, no measurement in 2 days of
   heavy feature commits; every new system (blood decals, survival ticks, hub world) lands on an unbudgeted
   frame (A1). Gates Pillar 1 directly.
2. **Claimed-fixed-but-isn't** — the stealth witnessed-contact fix (A2). Process risk bigger than the bug: if
   one "executed" decree item is fictional, every unverified checkmark is suspect.
3. **The two playtest P1s are both architectural** (A3 terrain streaming policy, A4 scale measurement) — they
   will not fix themselves with content, and both have small, precise fixes now that mechanisms are named.
4. **enemy_base.gd at 1,737 lines** — every AI/gore/stealth feature for days has landed in one file; merge
   conflicts with itself, untestable in units, standard-violating (A8).
5. **Save-file non-atomicity + future-version acceptance** (A7.1/7.2) — low probability, total-loss severity,
   6-line fix. Fail-forward (Pillar 5) dies with a corrupted slot.

## (d) PILLAR SCORECARD (technical lens)

| Pillar | Score | One line |
|---|---|---|
| 1. Outstanding gunplay | **2.5** | RECON dice unified + M16 default (real progress), but 19–25 FPS unaddressed for two decrees is a hard ceiling on feel. |
| 2. Atmosphere | **3.0** | VOManager shipped and wired (decree ONE BUILD done); jungle ambience beds in; but units render as specks and terrain pops — presentation credibility broken at the engine layer. |
| 3. Freedom | **3.0** | Open AO intact; escalation economy works; but the unwitnessed-kill alarm (A2) still converts stealth freedom into a fail-state. |
| 4. Squad is the RPG | **3.5** | Roster/XP persists through the new save backbone cleanly; live squad state not saved (A7.5) so squad wounds are cosmetically immortal. |
| 5. Fail forward | **3.5** | Save tiers (ironman/hard/regular) are a genuinely good fail-forward substrate; non-atomic writes are the one crack in it. |

## (e) THE ONE THING TO BUILD/FIX NEXT

**The measured perf-spike day, expanded to a "trust-restoration day": perf + the two playtest P1 mechanisms,
all with before/after numbers.** One day, four line-item fixes, all diagnosed above to file:line:
(1) test `rendering_method=mobile` + gpu compat vs Forward+ on the Intel UHD, pick by measurement;
(2) fix `ModelActor._aabb_of` to measure in instance space (A4 — the k values in the log are the acceptance
test: all ≈0.9 after);
(3) disable terrain streaming on ≤2km maps after initial full load (A3);
(4) FIFO scar decals + delete the unused `MAX_THINK_TIME` or implement it (A6/A1).
Close 8pbo and n2ij with numbers in the bead, not adjectives. Rationale: it is the standing directive, it is
decree item 4 twice over, and every pillar-1 improvement is invisible below 30 FPS. The stealth fix (A2) is
the day-after follow-up — it's a design-sensitive guard, not a mechanical one.

## (f) ADR CANDIDATES (living only in code/commits/beads)

1. **ADR: 3D ModelActor is the default character renderer; sprites are far-LOD/fallback; capsule is the
   guarded floor.** Decision in model_actor.gd:1-11 ("Caleb, locked") + enemy_base.gd:284-285. Matters: CLAUDE.md
   still teaches billboard sprites; the decree killed the sprite matrix; this is the renderer constitution.
2. **ADR: Character scale contract — author at 1.7132m, engine normalizes by *instance-space* AABB, [MODEL] k
   ≈ 0.9 is the acceptance band.** From GAME_SCALE_STANDARD.md + A4's fix. Matters: prevents the
   double-scale class permanently; gives artists a pass/fail number.
3. **ADR: World size is 1280m with 25 static chunks; terrain streaming is disabled below 2km.** From
   world_config.gd + A3 fix. Matters: kills the Catacombs bug class by policy, not by tuning; documents when
   streaming may return (3km maps, time-budgeted, threaded).
4. **ADR: Save architecture — versioned JSON slots, sequential migration, deferred apply, tier = derived not
   configured, campaign section is an untyped passthrough by design, mission section reserved for Phase E.**
   From commit 97260df + save_manager.gd/save_data.gd. Matters: this is the persistence constitution; Phase E
   must extend it, not fork it. Include the atomic-write + version-ceiling amendments (A7.1/7.2).
5. **ADR: Detection beacon — mission-level alarm keys off `EnemyBase.last_combat_contact_ms`, stamped only on
   *witnessed* COMBAT transitions (once A2 lands).** Matters: the whole ghost economy hangs on one static
   float; its stamping rules are game design, currently expressed as an unfixed comment.
6. **ADR: Test-suite law — every test is a real headless boot; error-pattern scan over exit codes; XPASS
   breaks the build; suite runs under --test-save.** From run_all_tests.ps1:1-13. Matters: this is the
   project's actual definition of "verified," and it lives in a script header.
7. **ADR: FX budget caps — MAX_FLASHES=8, MAX_EXPLOSIONS=6, MAX_DEFORMS_PER_MISSION=40, scar-decal FIFO cap
   (pending).** From gun_fx.gd:59-61 + damage_system.gd:68. Matters: these are the perf load-bearing walls;
   nobody ratified the numbers.
8. **ADR: Fire-support key-6 sharing — cbu_strike and place_claymore share physical 54, disambiguated by
   on-the-net state in player.gd:620-622.** Matters: it's a trap for the next input added unless declared
   deliberate (or rebound).
9. **ADR: Enums live in scripts/autoload/enums.gd via class_name; the GameEnums autoload is dead and should be
   removed.** Matters: two enum registries from the RTS copy-in will eventually disagree.
