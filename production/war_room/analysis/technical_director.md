# TECHNICAL DIRECTOR — Full-Game Audit (2026-07-09, branch overnight-claude)

Lens: code health, architecture, performance, scalability. All claims grounded in file:line.

---

## (a) Top 5 Strengths

### 1. MissionScope: the single-process mission loop has a disciplined, proven reset pattern
`scripts/main/mission_scope.gd:1-47` is the best file in the codebase pound-for-pound. One place
undoes a mission; every static leak it clears is documented with the failure it caused AND the
probe that proved it (`tests/probe_smoke_all.gd` sections B/D). `game_flow.gd:29-43`
(`_teardown_world`) is the only caller and also owns the CampaignState commit boundary. The
GameFlow screen-swap (`game_flow.gd:21-26`) is a clean single-owner pattern — no scene-change
soup, no orphaned screens. This is exactly the right architecture for M6–M8: generator, insertion,
and campaign all hang off one process loop that already knows how to clean up after itself.

### 2. Test/verification posture is exceptional for a project this size
34 headless test scenes in `tests/` (world boot, full 3-mission loop, seed replay, sims for
patrol/village/firebase/rescue/exfil/CAS/AA, campaign state, XP spend, mission scope, sensors...).
`run_all_tests.ps1` is battle-scarred in the best way: it scans captured output for `ERROR:` /
`previously freed` / `[NAV]` instead of trusting exit codes (lines 4-11 document how R16 shipped
as a no-op behind a green suite), has XFAIL/XPASS discipline where a passing known-red test
*breaks* the build (lines 24-31), and isolates the player's real save via `-- --test-save`
(`campaign_state.gd:55-65`). `probe_smoke_all.gd` explicitly converts audit claims into executed
proof. TODO/FIXME density across `scripts/` + `terrain/`: **2 total**. Comments explain *why* and
document regressions in place (e.g. `enemy_base.gd:1151-1171` nav same-box rationale).

### 3. Performance engineering is already deliberate and measured, not vibes
- Think-LOD: distant brains tick at 0.3s/0.6s instead of 0.15s (`enemy_base.gd:45-60`).
- FX caps: `MAX_FLASHES 8 / MAX_IMPACTS 12 / MAX_EXPLOSIONS 6 / MAX_DECALS 48` FIFO-recycled
  (`gun_fx.gd:58-61, 288-305`).
- Per-mission crater ceiling `MAX_DEFORMS_PER_MISSION = 40` with graceful degradation — skips the
  expensive dig, keeps the cheap scar (`terrain/systems/damage_system.gd:68-69, 143-145`).
- Structure visibility ranges at 230m (`site_planner.gd:135-146`), grass cull at 60m + 10Hz
  frustum updates (`vegetation_manager.gd:95-151`), shadows disabled by decision
  (`game_world.gd:47-48`), render scale 0.77 (`project.godot:[rendering]`).
- Bead 8pbo itself is model perf hygiene: two plausible hypotheses (decay, chunk thrash) were
  REFUTED by measurement before concluding steady-state 19-25 FPS, nodes flat, orphans 0.

### 4. Save/persistence is genuinely robust
`campaign_state.gd`: versioned save with refuse-to-load-newer (`:177-181`), backup-on-corrupt
before overwrite (`:170-174`), a migration stub waiting for the next shape change (`:198-199`),
and — the standout — **all-or-nothing mid-mission commits** (`:26, 92-141`): writes between
`begin_mission()` and `commit_mission()` are held in memory so Alt-F4 at minute three can no
longer permanently kill Doc while banking nothing. Iron-man flag correctly survives a campaign
wipe as a player setting (`:212-214`). Test coverage exists (`test_campaign_state`, `test_xp_spend`,
`test_full_loop` runs three real missions to debrief).

### 5. Asset/collision pipeline has a source of truth
`scripts/world/collision_table.gd` — authored meter-scale boxes + 89 auto-measured GLB AABB
entries (bead f5yf), with a `mesh: true` flag so GLBs carrying `-col` trimeshes skip the box that
would block doorways (`site_planner.gd:116-123`). The 100x RTS scale bug is documented at the top
of the file so nobody re-trusts composed .tscn collisions. `.gitignore` correctly excludes the
700MB Piper TTS binary and regenerable VO wavs while keeping final sheets tracked.

---

## (b) Top 5 Risks — ranked by blast radius

### RISK 1 — The renderer itself is probably the frame budget, and nobody has tested the alternative
**Blast radius: the entire game on target hardware; pillars 1 & 2 directly.**
`project.godot` sets **no `rendering_method`** — the game runs Forward+ by default. Bead 8pbo
measured 19-25 FPS with **104 draw calls, 295k prims, 716 nodes flat, shadows off, 0.77 scale**.
That scene content is trivial; a scene this light at 20 FPS on Intel UHD points at base pipeline
cost (Forward+ clustered lighting/decals is known-heavy on iGPUs), per-pixel-lit alpha-scissor
vegetation overdraw (`ground_clutter.gd:38-42` uses `SHADING_MODE_PER_PIXEL` + `CULL_DISABLED`
on ~400 quads; billboard_vegetation adds more), and dynamic light spawning (below). The Mobile
renderer typically yields 1.5-2x on this GPU class. Nothing in the codebase depends hard on
Forward+ except `Decal` nodes (supported on Mobile since 4.x, with restrictions) — this is a
one-line experiment that has never been run. Every M6-M8 feature lands on top of this budget.

### RISK 2 — What's still uncapped or churning inside firefights (the exact moment gunplay needs headroom)
**Blast radius: worst FPS dips land during combat, the core pillar-1 moment.**
- **Scar decals are uncapped within a mission**: past the 40-deform ceiling, `apply_damage` skips
  the dig but still creates a new `Decal` per hit (`damage_system.gd:143-191`), and
  `apply_bombardment` loops it (`:290-297`). A CBU/arty mission can stack dozens of 10m-projection
  decals — clustered decal cost in Forward+ is per-pixel-in-volume. `scar_decals` has no
  MAX_DECALS-style FIFO like GunFX's bullet holes have.
- **An `OmniLight3D` per muzzle flash and per explosion** (`gun_fx.gd:117-121, 189-193`) — up to 8
  flash lights + 6 explosion lights (energy 8, range 16m) concurrently. Dynamic lights are the
  most expensive thing you can give an iGPU. The cap exists; the *cost of the capped thing* was
  never priced.
- **Node churn per shot**: every impact/blood/flash allocates 1-3 nodes plus an
  `AudioStreamPlayer3D` and frees them on timers (`gun_fx.gd:215-283`). AudioManager pools shot
  voices, but impacts/blood don't. In a firebase-defense wave (5-8 attackers × ~7Hz think ×
  bursts) this is hundreds of allocations/second. A `ProjectilePool` exists
  (`combat_manager.gd:14, 26-28`) — the pooling pattern is known, just not applied to FX.
- **Cover search**: each enemy in SEEK_COVER fires up to 12 raycasts/second (`enemy_base.gd:1209-1225`,
  timer at `:1065-1067`). Fine for 5 enemies, not for a 3-wave firebase assault.
- Dead constant: `MAX_THINK_TIME` (`enemy_base.gd:173`) is declared, referenced in comments as the
  Quake-3 200ms cap, and **never used** — there is no per-frame think *budget*; N enemies spawned
  the same frame all think on the same tick cadence (only distance-LOD desyncs them).

### RISK 3 — EnemyBase is a 1692-line god object and AllyBase is its drifting photocopy
**Blast radius: AI feature velocity + a whole bug class; pillar 4 ("squad is the RPG") ceiling.**
`enemy_base.gd` (1692 lines) mixes perception, alert tiers, goal FSM, cover broker (static),
squad sync, patrol, firing + FX, grenades, damage/death/surrender, spider holes, tunnel retreats,
and a spawn factory. `ally_base.gd` (624 lines) duplicates: think/execute loop
(`ally_base.gd:213-243` ≈ `enemy_base.gd:372-396`), hitzone setup (`:175-210` ≈ `:331-365`),
muzzle math (`:452-464` ≈ `:1420-1438`), the whole fire-raycast + flesh/impact FX block
(`:467-542` ≈ `:1260-1385`), damage/death (`:546-598` ≈ `:1445-1583`). And they've already
diverged where it hurts: **allies have no NavBaker routing** — `ally_base.gd:445-449` is a
straight-line beeline while enemies path around structures (`enemy_base.gd:1151-1177`); allies
have no perception tiers, no cover claims, no crippled state. Every AI improvement must now be
written twice or silently benefits only one faction. M6-M8 adds more actor archetypes; without an
extracted `ActorBase` / shared `FireControl` + `Perception` components, the copy count grows.

### RISK 4 — O(N·M) group scans and per-think physics work will not survive M6-scale encounters
**Blast radius: CPU frame spikes as encounter density rises with the mission generator.**
Per enemy per think: `get_nodes_in_group("allies")` scan when in COMBAT (`enemy_base.gd:546, 679`),
`get_nodes_in_group("tunnel_entrances")` for every crippled enemy (`:470`), LOS raycasts in both
`_update_perception` (`:573-575`) and `_update_line_of_sight` (`:704`), and on near-death a full
`get_nodes_in_group("enemies")` scan (`:1518`). `CombatManager` already maintains
`active_enemies`/`active_allies` arrays (`combat_manager.gd:9-10`) — the registry exists; the hot
paths just don't use it consistently (AllyBase._find_target does, `ally_base.gd:257`). Think-LOD
helps distance but not density: a village fight puts everyone inside 80m at full 0.15s cadence.

### RISK 5 — The campaign save schema is stringly-typed dictionaries heading into M8
**Blast radius: silent data corruption / migration pain exactly when campaign becomes the product.**
`roster` is a raw `Array` of untyped Dictionaries round-tripped through ConfigFile Variants
(`campaign_state.gd:32, 153, 187`); member shape is defined implicitly by whoever writes keys
(`squad_system.gd:30-40`, `enemy_base.gd:1531-1543` reaches into `attacker.get("member")`).
SAVE_VERSION is 1 with an empty `_migrate` — good scaffolding, but M8 (map state, bios, injuries,
threat history) will pile fields into these dicts with no schema check and no test that an old
save survives a new build. Related: MissionScope's reset list is *manual* — every future
`static var` is a cross-mission leak until someone remembers to add it (`mission_scope.gd:28-47`
covers the known six; `sprite_actor.gd:45`, `sprite_library.gd:15-17`, `nav_baker.gd:36`,
`enemy_squad.gd:25` are handled today). The probe only proves the leaks already found.

Minor (asset pipeline): some auto-measured collision entries look like composed-scene AABBs, e.g.
`artillery_pit` box `40 × 9.9 × 55.1` (`collision_table.gd`, auto-measured block) — as a nav carve
that's a 2200m² dead zone; worth a sanity pass over the f5yf batch for outliers.

---

## (c) The ONE thing to fix next

**Close bead 8pbo with a renderer + firefight-budget spike, before any M6 generator work.**
Concretely, one day of measured experiments on the exact 8pbo scene (seed 4242, windowed, 56s):
1. `rendering_method = "mobile"` — measure. (Decals render on Mobile; verify scar/bullet-hole look.)
2. Muzzle flash without `OmniLight3D` (emissive quad only, or one pooled light for the player's
   weapon) — measure during a scripted firefight, not idle.
3. Cap `scar_decals` with the same FIFO GunFX already uses (`gun_fx.gd:301-305`), ~24.
4. Ground-clutter/billboard material: `SHADING_MODE_UNSHADED` + vertex-color sun tint — measure.

Rationale: 19-25 FPS on the target GPU is a standing violation of pillar 1 (outstanding gunplay
does not exist at 20 FPS) and pillar 2 (the bush-density epic is explicitly blocked on this
budget). Every later system — generator density, insertion flyover, campaign map — prices against
this frame. The data says the scene is *light*; the pipeline is the suspect, and the experiment is
cheap. **Tradeoff named**: the EnemyBase/AllyBase extraction (Risk 3) is deferred — accepted,
because it costs feature velocity, not the shipped game feel, and refactoring AI while its perf
substrate is about to change (think budgets, FX pooling) would churn twice.

---

## (d) Pillar Scorecard — "can the tech deliver the pillars" (1-5)

| Pillar | Score | Technical rationale |
|---|---|---|
| 1. Outstanding gunplay | **3** | Hit logic, falloff, hitzones, suppression all solid and tested; muzzle-origin raycasts correct (`enemy_base.gd:1293`, R03). But 19-25 FPS on target hardware caps feel, and FX node churn dips frames mid-firefight — the worst possible place. |
| 2. Atmosphere | **3** | Weather/night/fog/ambience wired and mission-seeded (`game_flow.gd:170-174`). Shadows off and 0.77 scale are atmosphere taxes paid to a renderer that was never benchmarked against its alternative; vegetation density ambitions are perf-blocked. |
| 3. Freedom / escalation | **4** | Detection-beacon static (`enemy_base.gd:190`) makes stealth an economy not a fail gate; threat modifiers persist (`campaign_state.gd:86-115`); deterministic per-mission seeds (`game_flow.gd:91-103`) make the open AO debuggable. Per-site-only navmesh is a scoped, documented constraint (`enemy_base.gd:1151-1163`). |
| 4. The squad is the RPG | **3** | Roster persistence is the most robust subsystem (all-or-nothing commit, versioned save, learn-by-doing credit at `enemy_base.gd:1531-1543`). But AllyBase is the duplicated poor cousin — no nav, no perception, beeline movement — so squad *behavior* can't deepen without the Risk-3 refactor. |
| 5. Fail forward | **4** | Mission results commit atomically; iron-man wipe handled without nuking the setting; save backup + refuse-to-load-newer prevent corruption cascades. Docked one for the untyped roster schema heading into M8. |

**Overall architecture verdict for M6-M8**: sound. GameFlow + MissionScope + MissionGenerator
(static plan/build over a Dictionary plan) is the right chassis for a generator, insertion
already runs as a component (`insertion_ride.gd` attached in `game_flow.gd:183-187`), and the
campaign layer has a persistence spine. The two things that do NOT scale as-is are the frame
budget (Risks 1-2) and the duplicated actor AI (Risk 3). Fix the budget first; extract the actor
base before M6 adds its third copy.
