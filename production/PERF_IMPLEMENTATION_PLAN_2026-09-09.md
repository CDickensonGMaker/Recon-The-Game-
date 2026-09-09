# ReconGame: performance and quality implementation plan

September 9, 2026 · Target: `C:\Users\caleb\recongame` · Godot 4.7

> **PROVENANCE.** Written outside this project and supplied by Caleb on 2026-09-09 as an instruction
> to execute. Recorded here verbatim so agents read the same text. **Four corrections apply and
> override it — see CORRECTIONS at the foot of this file. Read them before acting on any phase.**

## Objective

Make ordinary patrols responsive and major firefights smooth while preserving the dense jungle, real 3D art, lethal combat, autonomous squad, persistent world, and consequential destruction. Performance is the primary scope of this plan. It does not propose replacing the game loop or adding unrelated features.

The preceding `RECON_PERFORMANCE_REVIEW.md` supplies the source findings and historical measurements. No new FPS gain has been measured. Several old bottlenecks already received fixes; implementation must compare the current checkout against those findings before repeating work.

This is a requested implementation design, not a second repository task tracker. During implementation, put actionable work and status in the project's existing beads system. The earlier `bd prime` attempt failed because the installed launcher referenced a missing module; diagnose that setup before relying on it. Do not migrate task history or change unrelated global configuration as a shortcut.

## Targets and boundaries

Use **60 FPS as the provisional primary target** on the intended minimum-spec machine. The saved runs used Intel UHD Graphics, but confirm the actual GPU, driver, display resolution, and target hardware. Do not assume a discrete GPU exists, or that those historical runs represent today's performance.

Proposed acceptance budgets, to be adopted or revised explicitly after the baseline:

| Scenario | Proposed gate |
|---|---|
| Warm normal patrol | Median frame time ≤16.7 ms; p95 ≤20 ms; p99 ≤25 ms |
| Warm 45-man night assault | Median ≤16.7 ms; p95 ≤25 ms; p99 ≤33.3 ms |
| Destruction/reinforcement events | No unexplained >100 ms frame; remove reproducible >50 ms avoidable work spikes |
| Background preparation | Start with a shared 2 ms main-thread allowance per rendered frame; split oversized jobs |
| Long session | Resource counts and memory settle after repeated equivalent events; no growing active-job backlog |
| Input | Test camera, aiming, firing, and squad commands during heavy events, not just while standing still |

These are goals, not promises or recovered hardware capabilities. If the chosen minimum hardware cannot reach them without unacceptable compromises, present measured options: a 30 FPS fallback profile, a revised hardware floor, or specific visual tradeoffs. Do not quietly lower targets or change simulation rules to obtain a green report.

GPU time and main-thread time can overlap; they are not numbers to add blindly. A 2 ms preparation budget is an allocation within the frame, not a guarantee that the rest of the game fits.

## Phase 0 — establish one trustworthy baseline

**Deliverable:** repeatable current measurements with a preserved source state.

Record Git HEAD, dirty-file hashes, launch flags, Godot binary, renderer, GPU/driver, display and internal resolution, time of day, seed, actor counts, and camera route. Preserve existing modifications and staged work. Use a scoped recovery checkpoint; do not reset, clean, or commit other people's changes.

Use these existing scenarios:

1. Firebase interior → parapet → treeline → jungle walk, using `perf_walk.bat` or its current equivalent.
2. Fixed player-eye jungle view with no deliberate new events, to isolate sustained rendering.
3. The 45-man night assault from `perf_stress.bat`, including reinforcement arrival.
4. A repeatable artillery/napalm event and tree-collapse sequence.
5. A 15–30 minute patrol with repeated destruction and returning to previously visited sites.

Warm up deliberately, record loading separately, and use at least three comparable trials for small changes. Capture 60–120 seconds of steady-state data where possible; use explicit event markers for burst tests. A drone benchmark is useful for a controlled lever comparison, but it is not a player-view acceptance result.

**Gate:** baseline runs can be repeated closely enough to distinguish a proposed gain from run-to-run variation. Relevant script errors fail the run. An isolated headless test cannot validate GPU performance or visual quality.

## Phase 1 — repair measurement before following its advice

**Code targets:** `scripts/levels/arena_perf_overlay.gd`, `scripts/dev/fps_printer.gd`, the existing StallLedger instrumentation.

The arena overlay currently adds process and physics monitor readings and labels CPU/GPU bound from that result. The newer FPS printer documents why those readings cannot be treated as simultaneous per-frame costs. Correct the overlay first.

Implementation:

- Graph actual frame deltas; retain timestamps and frame IDs rather than graphing the inverse of a smoothed FPS counter.
- Sample GPU/render-thread timings throughout the window and label their collection scope. Do not invent GPU time when unavailable.
- Keep engine monitor maxima separate from directly timed script work.
- Compute median/p95/p99 and a clearly defined low-FPS statistic over a sufficiently long window.
- Associate event markers with spawning, vegetation updates, navigation collection, terrain edits, and first-use resources.
- Report both inclusive and exclusive subsystem timings where nested spans exist. Do not add crater and its nested chunk rebuild as independent costs.
- Measure logger/overlay overhead with display disabled. Avoid per-frame console printing.

**Tests:** a known frame-delay injection appears in the graph; missing GPU timestamps read unavailable; nested test spans do not double-count; exported and development builds state their configuration.

**Gate:** the instrumentation describes what was measured without unsupported CPU/GPU verdicts. Keep raw measurements sufficient to independently recompute summaries.

## Phase 2 — reduce sustained rendering cost without changing the art identity

**Code/content targets:** `project.godot`, `scripts/autoload/psx_look.gd`, `scripts/autoload/game_settings.gd`, `terrain/vegetation/tree_cover_layer.gd`, active environment/material setup and imported vegetation meshes.

Historical tests recorded GPU samples above the 60 FPS budget and many draw submissions. Determine which passes and content dominate the current player view before choosing changes.

Run one-factor experiments at the same view: internal resolution; ground-cover radius; bush radius; mesh LOD; character rendering; local lights/material features. Existing F9/F10/F12 controls can help. The arena's character toggle can change simulation as well as rendering, so it is not a clean rendering-only control.

Prioritized implementation options:

1. Identify the most expensive visible species and material surfaces. Verify their actual imported LODs, not just whether an import flag is enabled.
2. Use simpler original 3D meshes for distant vegetation while preserving silhouettes and the no-billboard direction.
3. Compare existing 64 m vegetation buckets against a smaller size. Smaller batches improve culling but can increase submissions; choose by frame time and visual checks.
4. Consolidate compatible materials/surfaces where it measurably helps. Avoid unique material instances for identical immutable settings.
5. Separate close detail from distant silhouettes for static structures. Keep doors, destructibles, collision, and interactive props individually addressable.
6. Investigate expensive material effects only where pass timing points to them. Sun shadows are already disabled in the inspected shipping world; do not claim turning them off as a new gain.
7. Evaluate renderer alternatives in an isolated test configuration if needed. Check required features and shaders before switching; no renderer change is presumed beneficial.

Preserve meaningful cover, concealment, enemy visibility, muzzle flashes, and night readability. A diagnostic draw toggle is not automatically an acceptable shipping setting. PSX postprocessing changes several things and should not be used as an isolated resolution benchmark.

**Gate:** measurable improvement exceeds baseline variance in the same player view, with no objectionable popping, lost silhouettes, incorrect materials, or unfair visibility change. Recheck night and weather, not just a bright still frame.

## Phase 3 — make vegetation/destruction updates local and bounded

**Code targets:** `terrain/core/terrain_manager.gd`, `terrain/vegetation/vegetation_manager.gd`, `terrain/vegetation/tree_cover_layer.gd`, `scripts/world/tree_break_system.gd`.

The current one-chunk-per-frame queues can still dispatch a job larger than an entire frame budget. Two independently bounded queues can also spend their allowances in the same frame. The solution must reduce the work unit, not just move a long function to the next frame.

Design:

- Give plants stable identities independent of array indices. Keep per-bucket lookup tables for live plant records and render-instance mappings.
- Coalesce edits by affected region/bucket and generation. Repeated blasts should not schedule redundant full reconstruction.
- Represent changes as additions, removals, support-height updates, and replacement debris—not just an assumption that the list stays unchanged.
- Update only affected species/buckets. Consider slot reuse or compacted active ranges with a reverse map; do not let index changes corrupt gameplay references.
- Prepare plain data incrementally or on safe worker jobs. Apply scene/physics/render-resource changes on the appropriate thread with bounded commits.
- Share one preparation budget across the related queues, with priorities and maximum waiting time. Track backlog length and age.
- Publish coherent state generations so collision, bullets, concealment, and visible tree state agree under the existing staggered-fall policy.

Do not revive the previously rejected height-only re-seat path unchanged: explosions also remove plants. Keep the already implemented terrain patching, cache/coalescing improvements, and tree-fall behavior where they pass.

**Tests:** no removed tree reappears; repeated and overlapping blasts are deterministic; bullet cover matches standing/fallen state; terrain and collision agree; a burst drains without unbounded delay; moving away and returning produces the same settled world; save/load preserves destruction.

**Gate:** report worst individual job cost, maximum frame contribution, and backlog recovery under the same destruction event. A smoother average with seconds of incorrect cover or missing terrain is not success.

## Phase 4 — make a soldier cheap to instantiate

**Code targets:** `scripts/visuals/model_actor.gd`, `scripts/enemies/enemy_base.gd`, `scripts/enemies/marching_cell.gd`, character export/import tools and hitzone setup.

Historical individual spawns exceeded 100 ms. Current assembly still contains work that may be invariant across instances. Use the newly added subspans to locate the remaining cost.

Implementation sequence:

1. Measure resource load, scene instantiation, tree attachment, skeleton lookup, normalization, animation merge, gear cleanup, material setup, and hurtbox creation separately.
2. Move invariant cleanup into authored/imported resources: remove duplicate hidden gear, establish a validated skeleton height, and prepare animation mappings.
3. Cache immutable prepared resources by asset/configuration key. Keep mutable animation state, wounds, gear selection, and materials that change per character independent.
4. Prewarm the expected roster during loading. Distinguish disk cache, resource parsing, shader first use, and scene setup; "preloaded" does not mean all activation work disappeared.
5. Split remaining preparation into bounded steps and activate only fully valid actors. Preserve reinforcement timing and tactical fairness.
6. Add pooling only if it beats prepared instantiation within a measured memory budget. Reset registry membership, signals, timers, targets, wounds, ammo, animations, collisions, and persistence IDs.

The shared two-spawns-per-render-frame gate already exists. Earlier notes record a worse result with one; do not assume reducing that cap is the fix.

**Gate:** actor appearance and activation no longer create repeatable large spikes, every spawned actor is valid, and the 45-man assault's timing, composition, and behavior remain correct. Log one-spawn worst case as well as total reinforcement duration.

## Phase 5 — bound navigation preparation

**Code target:** `scripts/world/nav_baker.gd` and callers that invalidate sites after destruction.

The actual bake is asynchronous, but terrain/collider/structure collection happens before it. The main thread can still stall while preparing an async job.

Cache static source geometry per site, retain explicit versions, and collect only affected geometry after a local edit. Split traversal and data conversion into resumable batches. Worker jobs may transform immutable geometry arrays; do not move arbitrary live scene-tree access onto a worker.

Keep the old region until the replacement is valid, then publish coherently. Reject stale completed bakes if a newer destruction event superseded them. Preserve the existing obstacle coverage that prevents paths through structures.

**Tests:** multiple rapid breaches; destruction while baking; navigation over crater rims and stairs; agents using routes during replacement; returning to a site; teardown while a job is pending.

**Gate:** preparation is bounded, the latest requested state eventually becomes active, and agents do not traverse destroyed/stale geometry or acquire new wall-crossing paths.

## Phase 6 — optimize simulation only where current measurements justify it

**Targets:** enemy/ally controllers, perception and combat manager, agent registry, world simulation, civilian/ambient systems.

The cited 425.8 ms of AI work over 14 seconds is about 30.4 ms per second. It does not justify sacrificing distant engagements by itself. Measure actual busy fights and worst-case perception/path bursts.

Prefer caching stable references, spatial candidate filtering, staggered expensive decisions, bounded path requests, and elimination of redundant queries. Preserve near-combat response, telegraphs, suppression, squad autonomy, and deterministic damage.

Define relevance using combat participation, threat, audibility, visibility potential, squad membership, projectiles, and scripted obligations—not distance alone. Presentation can update less often when appropriate without changing authoritative outcomes. Any proposed abstraction of distant combat must specify what gameplay changes and be weighed separately from behavior-preserving optimization.

**Gate:** demonstrate a measured cost reduction alongside behavior comparisons for stealth, ambushes, reinforcement timing, civilian schedules, and autonomous squad combat. No "optimization" that simply stops meaningful simulation silently.

## Phase 7 — session stability and perceived responsiveness

Run repeated patrol/destruction/reinforcement cycles. Track live nodes, meshes/materials, memory, collision objects, active agents, jobs, and retained references after returning to equivalent states. Allow documented caches to warm and plateau; do not mistake every cache increase for a leak.

Exit-time leak messages from an interrupted historical run do not alone prove a growing gameplay leak. Reproduce with a clean exit and a long-running resource trend before assigning causes.

Test aiming, recoil, interaction, weapon changes, and audio during spikes. Check animation/movement at different frame rates, including terrain contact and stairs. A timestep cap can alter simulation behavior under sustained load; do not tune it as an FPS trick. Verify save/load, squad persistence, and repeated scene transitions after resource preparation or pooling changes.

**Gate:** no reproducible growth without ownership, no long-running queue starvation, and responsive controls throughout the benchmark route.

## Delivery and release policy

Implement one independently measurable change at a time, keeping its source diff, before/after traces, visual comparison, and relevant regression tests together. If a result falls within run variance, call it inconclusive. If it improves one case but harms another, record the tradeoff rather than burying it in averages.

The first work package is instrumentation plus current player-eye baseline. The second is whichever of rendering or world-update bursts the new baseline ranks highest; pursue both eventually. Character preparation and navigation follow their measured contribution. Broad AI redesign comes last unless new measurements materially change the order.

For each accepted change, record: problem; old/new behavior; measured scenario; hardware/configuration; frame distribution; affected gameplay checks; remaining uncertainty; and a scoped rollback route. Do not repeatedly rerun unrelated tests after a change is already verified, but do run the final combined patrol, assault, destruction, and persistence suite before calling the project improved.

A realistic completion claim is: "On this hardware and these declared settings, these scenarios meet these frame-time targets with these gameplay checks." Avoid "optimized," "2000s performance," or "60 FPS everywhere" without that evidence.

This plan preserves the live open-patrol implementation. The project guide explicitly notes that some older mission/exfil descriptions are pending amendments; do not restore an older loop as part of optimization. Read relevant ADRs before changing a constrained system. This external design does not amend project canon or authorize unrelated feature redesign.

---

# CORRECTIONS — these override the plan above

The plan was written outside this project. Four of its premises are wrong here.

## 1. DO NOT USE BEADS. This is a canon violation, not a setup problem.

The plan says to put work and status in "the project's existing beads system" and to diagnose why
`bd prime` failed. **Beads was RETIRED 2026-07-22** for accumulating false "done" claims. `CLAUDE.md`
says explicitly: do not resurrect `.beads/`, do not run `bd`. Track in
`production/CALEB_TODO_7_22_updated.md`, `production/PERF_LEDGER.md` and Claude memory. Ignore that
paragraph; do not "fix" the launcher.

## 2. Much of Phases 1 and 3 SHIPPED on 2026-09-08/09 — diff before building.

Landed after the plan was written, all verified in the tree:
- Both perf probes read the **live viewport** rather than `ProjectSettings` — the ratified 0.75 render
  scale had been overwritten to 1.0 at every boot for a month and both probes hid it.
- `--print-fps` states live scale, renderer and GPU ms per row.
- Terrain chunk **partial patching**: a 5 m hole re-derives 121 of 4,225 samples (2.9%); the chunk node,
  its mesh instance and its Jolt body are never destroyed.
- **`HeightMapShape3D`** collision (`terrain/core/terrain_chunk.gd:376-404`): shape build 4.4–8.4 ms →
  0.09 ms, proven identical to the old trimesh over 3,000 down-rays and 600 grazing lines, worst
  disagreement 1.5 mm, zero rays hitting one and missing the other.
- Scatter-cache **epoch fix** (`vegetation_manager.gd:413-444`) and crater double-rebuild dedupe:
  crater phase 723 → 454 ms, worst idle script step 175 → 130 ms.
- `TreeBreakSystem._consume` off the physics tick.
- **Staggered tree falls** with a silent >350 m band (`tree_break_system.gd:344`, `SILENT_FALL_M`),
  proven outcome-identical near and far.
- **The napalm stutter is solved**: it was `terrain.crater` at **122.2 ms of a 125.43 ms frame** (97% in
  one call), because a napalm's 88 m radius always spans four chunks and the partial-update fast path
  never armed. Now 125.43 → 54.86 ms. Fire, explosion and blast VFX together were **7.6 ms** for a
  nine-canister strike — the expensive things are world-state rebuilds, not the pretty things.

**Do not rebuild any of it.**

## 3. The 60 FPS target on Intel UHD is a trap — provisional, never a licence.

The Quadro P620 is dead (Code 31 → 43, bought used with the fault), so Intel UHD is the only bench and
it is **the punishment floor, not the design target** — Caleb's ruling. A number from it justifies no
atmosphere cut on its own. If the target cannot be met, the plan's own instruction applies: present
measured options, do not quietly cut.

**Three cuts are already REFUSED by him and must not be re-proposed:**
- **Single-sided foliage** — 0 of 40 impostor cards are double-modelled and 116 of 117 near-ring solids
  are open shells; back-culling would hole the jungle from half the compass.
- **Unshaded grass** — it glows at night and inverts the stealth economy (Pillar 2/3, ADR-005). Built as
  `vertex_lighting` instead.
- **Cutting the bushes** — he ruled 2026-09-09 that they draw to 350 m, uncut.

## 4. Phase 0 is windowed and he is at the machine.

Player-eye baselines cannot be taken headless — GPU ms reads 0. His standing law is that nothing appears
on his screen unprompted. **Do every headless-able thing first, then stop and name the exact runs
needed and how long each takes.** Do not open a window on your own initiative.

He has also ruled that a bench on a quiet scene *"isnt really gauging anything"* — the same bug class as
ADR-026's founding drone shot. **The baseline runs under real load, from a player-height camera.** A
drone benchmark is a lever comparison only, never an acceptance result.
