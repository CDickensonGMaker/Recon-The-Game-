# SYSTEMS-DESIGNER — AI Consolidation Plan Analysis
*War Room 2026-07-18 · lens: AI behavior architecture + preservation mapping · PLAN ONLY*

Sources read: briefing, SYNTHESIS.md, recon_survey.md, mohaa.md (RequireThink / tick-list
mechanism), and the live code: enemy_base.gd, ally_base.gd, enemy_squad.gd, world_sim.gd,
lazy_group.gd, sim_clock.gd, combat_manager.gd, ai_stress_arena.gd, mission_generator.gd
(_wire_systems), plus the tests/ roster.

---

## 1. THE TIER-AUTHORITY DECISION (B1)

**RECOMMENDATION: delete WorldSim's tiers; build the AIDirector tick-list (MoHAA shape:
dormant = not in the list).**

### The facts that decide it (all verified in live code)

**F1 — WorldSim's cell math cannot discriminate at AO scale.** `world_sim.gd:14-16`:
`CELL_SIZE = 1000.0`, `AO_RADIUS = 800.0`. The shipped map is `MAP_SIZE 1280`
(`world_config.gd:9`). The whole playfield is at most a 2×2 cell grid, and an 800 m live
radius around the player covers essentially the entire AO. Wired as-is, WorldSim would mark
*everything* live, *always* — it can never produce DORMANT for the far village 400 m away.
It was designed for a bigger world than the one ADR-013 ratified. To make it discriminate
you retune its constants AND its granularity model — i.e. redesign it.

**F2 — WorldSim's registry is a write-only mirror with no node back-links.**
`mission_generator.gd:189-200` registers enemies ONCE at mission start as
`{kind, position, velocity: Vector3.ZERO, faction, schedule}` dicts. There is no reference
to the `EnemyBase` node, so even a wired `update_player()` could flip `current_ao` flags
forever and nothing could translate that into `set_lod_live/abstract` calls on actual
soldiers. And it registers `director._live_enemies` at mission start — **before LazyGroup
has spawned anyone** (all but the nearest village is lazy, survey §1). The registry misses
the majority of the AO's men structurally, not incidentally.

**F3 — WorldSim is O(N)-scan shaped; the tick-list is not.** `update_player` (:70-82),
`materialize_near` (:86-95), `dematerialize_far` (:99-108) all iterate every entity/cell.
That is liability #7's shape (per-frame O(N) registry scans). MoHAA's answer — the thing
that made 40 actors free in 2002 — is that a dormant actor is *not in the tick list at all*
(mohaa.md §1: "remove from the tick list — not 'return early', don't call them"). The
AIDirector walks only HOT+LIVE entries; DORMANT and AGGREGATE cost one array membership.

**F4 — LazyGroup is already a proto-AGGREGATE, and it fits the director exactly.**
`lazy_group.gd` is a dormant Node3D polling player distance at 1 Hz (:44-57), holding a
`patrol_circuit` (:12), spawning through `FieldDirector.spawn_tracked_enemy` (:74). That IS
an AGGREGATE entry: `{group, pos, route, cursor}` advanced at 1 Hz by the director, with
materialize = the existing `force_spawn()` path (spawn plumbing, contact-ledger tracking,
file slots all unchanged). Bonus the briefing asks for: the aggregate dot can *walk its
patrol route* while dormant — today a lazy group stands frozen at its authored point until
the player closes, so distant patrols don't exist as moving things. WorldSim's
`_advance_abstract_cells` (:111-126) has velocity but no route-following, at a 60 s tick
(a patrol at 1.4 m/s teleports 84 m per tick — visible popping at the materialize boundary).

**F5 — Fossil-law cleanliness.** Branch B buries a complete zero-caller system: delete
`world_sim.gd` (142 lines), the `mission_generator._wire_systems` registration block
(:188-200), the `set_lod_live/abstract` stubs (`enemy_base.gd:118-124`), and the lying
comment at `enemy_base.gd:116` ("called by WorldSim" — nothing calls them). The fossil
baseline shrinks. Branch A "resurrects by rewrite": after adding node back-links, per-agent
think scheduling (WorldSim has none — it only flips flags), route-following aggregates, and
LazyGroup re-registration, almost no original line survives, but the name and doc comments
still describe the 2025 off-AO-strategic design. That is the exact camouflage ADR-023
exists to kill: a file that reads load-bearing about a design that is no longer there.

### What dies in each branch (Law 2 — named)

**Branch B (recommended — AIDirector):**
- `world_sim.gd` entirely + its registration block in mission_generator. **Sacrifice: the
  off-AO strategic-layer ambition (convoys/aircraft as abstract cell entities) dies with
  it.** If the game ever needs an off-map strategic sim, it gets designed fresh. Convoy /
  AirTraffic scheduling via SimClock is untouched (they never used WorldSim).
- `enemy_base._update_think_lod` (:39-54) — folded into director-assigned think interval
  per tier (the director hands each entry its `next_think_ms`).
- `set_lod_live/abstract` stubs — superseded by ONE `set_tier()` entry point (ADR-025
  Phase 0, finally).
- `LazyGroup._physics_process` poll (:44-57) — folded into the director's 1 Hz aggregate
  walk (30 lazy groups × 1 Hz self-polls → one loop). LazyGroup keeps `force_spawn()`.
- `civilian.lod_tier` — staged fold (civilians register with the same director; can be a
  later wave, it is self-contained).
- `MAX_THINK_TIME` / `last_think_time` fossils — die when A3's global think budget lands
  in the director.
- `EnemySquad.tiering_enabled` as a floating static — the director owns the A/B switch.
  **Live latent bug found:** `ai_stress_arena.gd:229` sets `tiering_enabled = false` in
  mirror mode and NOTHING restores it — not `_exit_tree` (:1510-1513), not
  `EnemySquad.clear()` (:92-95). A mirror run followed by a campaign in the same session
  runs the campaign untiered. The director's config must reset per scene (MissionScope).

**Branch A (wire WorldSim — rejected):**
- The AIDirector concept dies; ADR-025's "one set_tier()" gets grafted onto a dict registry.
- Everything Branch B builds still has to be built (back-links, think scheduling, aggregate
  routes, LazyGroup absorption, hot-set interface) — inside a file shaped for a different
  problem, keeping its O(N) scan skeleton.
- Additional risk: WorldSim's `set_lod_abstract` = `set_physics_process(false) + visible =
  false` (`enemy_base.gd:123-124`) would be the demotion path — that kills the witness
  heartbeat *silently* (no think = no `_check_corpse_discovery`) with no beacon mechanism
  anywhere in its design. The AIDirector design puts wake-beacons (noise, corpse proximity,
  spider-trigger) at the center; WorldSim has no event path at all.

### The tier ladder the director owns (one authority, ADR-025 Phase 0 done)

| Tier | Who | Cost | Today's equivalent (absorbed) |
|------|-----|------|-------------------------------|
| HOT | COMBAT fighters in the `EnemySquad` hot-set (cap 12/16) | full think + body | hot-set (`enemy_squad.gd:37-96`) — **kept as-is, becomes the HOT-tier broker inside the director** |
| LIVE | spawned, player-relevant, not in hot-set | tiered think (0.15/0.3/0.6 s), gated body (A2) | `_update_think_lod` bands (:49-54) |
| DORMANT | spawned but no player relevance for 60 s | zero — not in tick list; wake via NoiseBus/damage/beacons | nothing (enemies never sleep today — liability #2) |
| AGGREGATE | unspawned LazyGroup / despawned far group | one dot advanced 1 Hz along its route | LazyGroup dormant node (:44-57) |

Keep `EnemySquad`'s hot-set request/release logic untouched in wave B1 — it is live,
probe-guarded (`test_activity_tiering.tscn`), and its promote-on-death timing is a shipped
behavior. The director *contains* it; it does not rewrite it.

---

## 2. PRESERVATION MAP (hard constraints → waves → risks → probes)

| Behavior (briefing item 1) | Code path (file:line) | Waves that touch it | Specific regression risk | Probe |
|---|---|---|---|---|
| **Witness rule ADR-005** | heartbeat before tier gate `enemy_base.gd:532-535`; `_witness_check` :715-742; `_check_corpse_discovery` :746-766; `_can_witness` :696-708; `unreported_corpses` :693 | **A1, A3, B1, D2** | budget starves corpse rays; stale vislist answers "did he see the kill"; DORMANT men never run corpse checks | `test_activity_tiering` (source-text order probe — **breaks by design under A1/B1, must be REWRITTEN behavioral, see below**), `test_detection`; **NEW `test_witness_rule`** |
| **2:1 fire discipline + hot-set** | `enemy_squad.gd:37-96` hot-set; gate `enemy_base.gd:541-546`; cheap brain :572-591; `count_engaging` :195-208 | B1, A3, D2 | director-tier membership changes promote-on-death timing → fights go quiet or everyone goes hot; `tiering_enabled` leak (above) | `test_activity_tiering`, `test_firefight_len`, `test_mirror_match` (depends on an A/B off-switch — B1 must preserve one), `test_ai_fairness` |
| **Roll/crouch + cover_to_stand** | enemy: :144-152, :489-494; ally: `ally_base.gd:151-175, 279-338, 713-745` | **A2**, D2 | body gate freezes AnimationTree mid one-shot clip (`_cover_exit_until_ms`, `_leap_until_ms` windows) → snap/T-pose on re-entering view. Rule: an open one-shot window is a gate-keeper condition (one ms-timestamp compare) | `test_low_posture` (32 checks), `test_ally_cover_roll` |
| **Patrol-mode + veg concealment** | `_sight_cap` :647-654 (veg max(observer,target) + weather/flare); posture caps :793-800 (prone ×0.4, crouch ×0.6); patrol :100-106 | **A1** (sight-cap math moves into the server funnel), B1 (aggregate resume) | server funnel drops the per-candidate posture multipliers or the two-ended veg rule → crouching in a bush stops beating the range gate (Pillar 3 violation); aggregate rematerialize resets `_patrol_index`/file slots | `test_veg_cover`, `probe_concealment`, `test_arena_patrol`, `test_detection` (posture ramp time); **NEW aggregate round-trip probe** |
| **Spider-holes + tunnel retreat** | :185-191, `_check_spider_hole` :600-615 (runs BEFORE perception in `_think` :527-531), `_check_tunnel_retreat` :619-641 | **B1**, A2 | a buried man demoted to DORMANT with no proximity beacon never pops his ambush; A2's on-screen gate never opens (he is invisible by design) — his 7 m trigger must live in director beacons, not his own think | none exists — **NEW `test_spider_tunnel`** |
| **Suppression** | decay `_update_decay` :498-500; `apply_suppression_in_area` `combat_manager.gd:240-251`; `_execute_suppressed` :1426 | A2, B2, D2 | body gate must not gate `_update_decay` (brain half) or off-screen men stay pinned forever; B2 radius/priority retune shifts suppression feel | `test_low_posture` (LOW_POSTURE_SUPPRESS band), arena 30 s telemetry (suppressed-seconds), night-arena bench |
| **Squad hunt net + covering fire** | `enemy_squad.gd:288-441` hunt; covering fire :162-180 | B1, D2 | tier authority demoting a hunting man below LIVE kills the net mid-sweep. Rule: `hunt_active` ⇒ LIVE floor (hunting IS player-relevance) | `test_squad`, `test_squad_break`; **NEW `test_hunt_net`** (sector fan + reanchor asserts) |
| **Open-patrol-sim decree** | `field_director.gd:474` wire gate, :546 AAR; `lazy_group.gd` whole | B1, D1 | LazyGroup absorption changing activation semantics (120-140 m, spawn-through-director tracking); A3 must de-phase the 4-7 aligned think timers a group spawn creates (`:69-89` spawns all in one frame, `think_timer = 0.0`) | `test_patrol_world`, `test_patrol_aar`, `test_fresh_tour`, dlox probe |
| **Gore / severed limbs** | `gib_system.gd`; `on_zone_hit` `bullet_system.gd:150-154`; corpse sync 6 Hz `enemy_base.gd:443-449` | C1, A2, D2 | FX pooling must not touch the GibSystem dismember contract; body gate must keep corpse hitzone sync ≥6 Hz (shooting bodies stays honest) | `test_gore_rig`, `test_head_burst`, `test_hitzones`, `test_downed_enemy` |
| **Flat damage ADR-016** | `bullet_system.gd` `_impact` path; fossil router `combat_manager.gd:74-98` | D3 only | deleting `apply_bullet_damage` must not touch the live `_impact` path; note its `damage_dealt`/`entity_killed` emits die with it (bullets never emit them — verify no listener) | `test_flat_damage`, `test_ballistics`, `test_bullet_flight` |
| **Fairness Law** | exposure clock `enemy_base.gd:995-1010` (3× drain), `d_exposure_ramp` :138, first-shot :881, `ai_marksmanship.gd` | **A1/A4**, D2 | exposure ramp becomes vislist-timestamp math — the 3×-drain and the "cold man never ramps" rule (:571) must survive the transfer verbatim | `test_ai_fairness` (named guard), `test_mirror_match`, `test_los_determinism` |

### Witness rule under a budgeted PerceptionServer — the exact design (special care)

The briefing demands "say exactly how." Four rules, all cheap:

1. **Corpse checks are their own budget class.** The server runs a `corpse` cursor separate
   from the `hostile`/`pair` cursors, with its own floor cadence (per-unit corpse ray at
   least every 2 s *when a corpse is within `CORPSE_NOTICE_RANGE` 22 m*). The funnel makes
   this nearly free: the dist² prefilter over `unreported_corpses` (a short static array)
   costs zero rays for the overwhelming majority of units, so hostile-detection load can
   never starve corpse discovery — they don't share a ray pool.
2. **The death-moment witness check is an EVENT, not a budget item.** `_witness_check` runs
   synchronously inside `_die()` with fresh rays, exactly as today (:715-742). It is already
   self-funneled (sight-cap distance + FOV + COMBAT early-out). It is *exempt from the
   vislist*: "did he see the kill happen" must never be answered from a cached timestamp —
   a stale `visible` stamp from before the player broke LOS would convict a clean kill, and
   a stale `not-visible` stamp would acquit a watched one. Kill-witnessing reads reality at
   the kill tick, always.
3. **Dead men's vislist entries are purged at death and never squad-shared.** Under A1 the
   squad shares timestamps within 15 m (D2/SYNTHESIS). Without the purge, a man who could
   not see the kill inherits the victim's own last-seen stamp and the alarm rings — the
   silent kill leaks through the cache. Purge-on-death is one dictionary erase.
4. **Corpse positions are DORMANT wake-beacons in the AIDirector.** A dormant/aggregate
   patrol whose dot passes within 22 m of an `unreported_corpses` entry is promoted to LIVE
   for one real check (eyes, veg cap, LOS — rule 1's class). Discovery cadence therefore
   survives dormancy: sleeping men can't see, but men *routed past a body* wake and look.
   Same beacon mechanism serves the spider-hole 7 m trigger and NoiseBus radii — one
   beacon list, three users, no polling.

**Probe:** NEW `test_witness_rule.tscn` (behavioral): (a) silent kill, no eligible witness
→ 60 s → zero tier changes anywhere in the AO; (b) kill in a squadmate's view → ALERT
within one think; (c) patrol routed past the corpse at 22 m/LOS → ALERT + hunt reanchor;
all three run with the server's ray budget forced to its floor (worst-case starvation) to
prove the class separation holds. This REPLACES `test_activity_tiering`'s
`_test_witness_before_branch` (:119-134), which greps `_think()`'s source text for call
order — a probe that cannot survive A1/B1 restructuring and would either false-fail or,
worse, be "fixed" by deletion. Rewrite it as behavior in the same wave that moves the code.

---

## 3. ARENA BRIDGE INVENTORY (`ai_stress_arena.gd`, 1819 lines)

Law 2 applied: nothing is killed before its replacement runs the arena scene in the same
change. Verdicts:

| Piece | Lines | Verdict | Reason |
|---|---|---|---|
| Scenario/force config exports (squads, reserves, hot_start, patrol_mode, bench_dressing, mirror_mode, hp/cone/reserve dials, rng_seed) | :95-144 | **KEEP** | This IS the thin-wrapper config ADR-028 Phase 3 wants — the arena's identity as a scenario |
| `hot_start` combat seeding | :1235-1261 | **KEEP** | Probe seam for headless behavior tests |
| Reinforcement waves (16+1d10, attrition-gated) | :1346-1393 | **KEEP** | Stress-driver the game deliberately lacks; arena capability, intact by mandate |
| Telemetry: HUD, 30 s summaries, state histograms, LOS/cover/suppression aggregates, kill wiring | :1548-1725, :1264-1316 | **KEEP** | The honest-measurement instrument; the fixed benchmark the whole decree is judged against |
| Debug vis (tier labels, LOS lines) + F5/F6 toggles | :317-339, :1728-1819 | **KEEP** | Harness; already toggleable out of measurements |
| Perf overlay wiring + CPU buckets | :263-298 | **KEEP** | The `ai/agents` bucket that produced the 25-192 ms diagnosis lives here |
| Mirror-mode tiering neutralization | :228-229 | **KEEP as config, RE-POINT** | Must target the AIDirector's A/B switch after B1, and must reset on scene exit (the leak found above) |
| **Patrol-contact injection** (`_update_patrol_contact` / `_spotted_us_for`) | :1396-1441 | **MIGRATE → then KILL** | It is a shim around the buddy rule (core perception exempts allies until COMBAT, :777-787, so AI-vs-AI patrols would never develop contact). Under A1 "who is a perceivable candidate" becomes server *policy*: arena scenario flips allies-perceivable on; game keeps the buddy rule (player stealth). The shim — an unbudgeted per-frame O(VC×US) raycast loop, the exact pattern A1 exists to kill — then dies. It is also the strongest argument that candidate policy belongs in the PerceptionServer, not in each agent |
| **Veg-density stamping** (`_stamp_veg_circle/_rect` + planters stamping) | :541-573, :816, :871, :879, :963, :980 | **MIGRATE** | The *contract* (eye sees jungle ⇒ sight cap drops, stamped where foliage is actually planted) is the hard-won arena→world bridge — a KEEP by Law 2. The *implementation* moves into the shared planting funcs so both worlds get density-where-planted from one code path; arena copies then die |
| **ArenaGrid** (centered-origin GameplayGrid) | :39-51 | **MIGRATE → KILL at Phase 3** | Exists only because the arena spans −100..+100 while the world grid is 0-based. Once the arena is a scenario placed in real world coordinates on the shared build path, the standard grid serves it and the subclass dies |
| World-build: floor/walls/firebase/village/ridge/tree lines/wrecked cover/cover clusters/vegetation/jungle/ground plants/campfires/navmesh/night env | :344-1096 | **MIGRATE** | The parallel 15th world (liability #5). Phase 3: express the arena layout as authored scenario data fed to the same `mission_generator`/`site_planner`/planting statics; `_build_night_env` folds into shared MissionWeather application (it already reads the shared TIMES preset — finish the job) |
| `TerrainManagerStub` / `FlatHeightmap` | :11-30 | **KILL at Phase 3** | True duplicates; the shared path provides real ones. Until then they are load-bearing — kill in the same change that lands the wrapper |
| `_place_ruin` / `_add_aabb_collider` / `_add_trunk_collider` | :1009-1078 | **MIGRATE** | Generic prop-placement duplicating site_planner's job; fold into shared placement helpers |
| `_spawn_player` + lab grenades + photo-mode-off | :1100-1126 | **MIGRATE (mostly)** | game_world spawns the player; `LAB_GRENADES` and `allow_photo_mode=false` stay as scenario config |
| Squad spawn helpers (`_spawn_us_squad`/`_spawn_vc_squad`/`_ring_offset`) | :1168-1232 | **KEEP shape, reroute** | Spawn *composition* is scenario config (KEEP); the spawn *call* should go through the same director path the game uses (`FieldDirector.spawn_tracked_enemy`) so B1's tier registration covers arena men identically |

---

## 4. ALLY/ENEMY MERGE (D2) RISK MAP

The survey's "~40 % duplicated" splits cleanly along the engines' seam (Q3: bots and
players share Pmove; brains differ). Merge the body, never the brain.

### SAFE TO SHARE (mechanically identical or one-parameter variants)

| Duplicated block | Enemy | Ally | Note |
|---|---|---|---|
| `_update_unstick` watchdog | :161-175 | :47-61 | Byte-identical except enemy multiplies `_suppression_move_mult()` — one speed-mult hook |
| `_physics_process` spine (hitzone sync, DEAD out, 66 ms cap, gravity, think accumulate, execute, unstick, crouch speed cap, move_and_slide) | :442-495 | :348-384 | Shared body base class. **Enemy's version wins on corpse sync**: enemy re-syncs corpses at 6 Hz (:443-449); ally syncs every corpse EVERY physics frame (:349-351) — merging fixes a live ally-side perf leak for free |
| Low-posture cap + cover-exit one-shot + debounce | :144-152, :489-494 | :151-158, :377-384 | Identical constants (CROUCH_SPEED_CAP 1.9, DEBOUNCE 1500) — the copy the survey flags |
| Cover claim broker | static `_cover_claims`/`_claim_cover`/`_crowding_cost` | ally reaches INTO EnemyBase statics (:759-780) | Extract a `CoverBroker` — removes the cross-class static reach; zero behavior change |
| Fire path (muzzle math, AIMarksmanship cone, muzzle-discipline lane check, BulletSystem.fire) | enemy equiv | :818-890 | Ally comment already declares "one cone path for both sides (Fossil Law)" — formalize it |
| Gore contract (`on_zone_hit`, dismember, death doctrine, take_damage flash/suppression bump) | enemy equiv | :909-987 | Same doctrine by design; share |
| Aim interpolation + strafe timers | enemy equiv | :512-525, :583-586 | Identical pattern |

### BEHAVIOR-DIVERGENT BY DESIGN (merging these is a regression, not a cleanup)

- **Perception/witness:** allies have NO alert tiers, NO awareness accumulator, NO FOV
  cone, NO witness ledger, NO corpse discovery. `_find_target` (:405-426) is a 60 m
  nearest-hostile scan with only an aim-settle beat. Deliberate: the ally squad is not a
  stealth system. Under A1 the server may *serve* allies distance-only candidates, but
  tiers/awareness/witness semantics stay enemy-only. Never give allies `unreported_corpses`.
- **Hold-fire discipline:** `weapons_free` / `_defend_until_ms` / `_may_engage` (:113-127)
  — squad-order layer with a self-defense window. Must never leak to enemies; conversely
  the enemy 2:1/hot-set must never touch AllyBase (`test_mirror_match`'s premise is that
  tiering touches only the VC side — arena comment :226-228 says so explicitly).
- **Squad layer:** EnemySquad static registry (hunt net, crumbs, covering fire, hot-set)
  vs SquadSystem node + OrderMode FOLLOW/HOLD/MOVE_TO + formation slots. Different by
  design; `break_state` (:109-112) is already the one shared pure function — the correct
  pattern for any future sharing.
- **Personality/goals:** ally courage/rally/cover-first gates (:451-494, presence rally
  :77-83) vs enemy full goal stack (retreat/flank/spider/tunnel/suppressed). Keep split.
- **LOD/tier:** allies are deliberately un-throttled (no `_update_think_lod`). Under B1
  they register with the director but are **pinned HOT** — they live next to the player by
  definition; throttling them changes squad-follow responsiveness, a shipped feel.

### D2 sequencing note

D2's first cut (perception extraction) rides A1 by definition — do not schedule it as a
separate wave. The body-base-class merge is its own wave, guarded by `test_low_posture`,
`test_ally_cover_roll`, `test_mirror_match`, `test_hitzones` all green before/after, plus
the night-arena bench (the merge must be frame-neutral or better).

---

## 5. NEW PROBES THIS PLAN REQUIRES (roll-up)

1. `test_witness_rule.tscn` — behavioral ADR-005 guard at minimum ray budget (§2).
   Replaces the source-text order probe inside `test_activity_tiering.gd:119-134`.
2. `test_spider_tunnel.tscn` — spider pop + tunnel retreat under dormancy/beacons
   (currently unguarded entirely).
3. `test_tier_authority.tscn` — structural: exactly ONE system assigns tiers (grep-proof
   that `_update_think_lod`/`lod_tier`/`set_lod_*` are gone); behavioral: aggregate
   round-trip (dematerialize → walk route → rematerialize with patrol index/file slots/
   tier intact).
4. `test_hunt_net.tscn` — sector fan, growth, reanchor; hunt ⇒ LIVE floor.
5. Raycasts/frame + thinks/frame counters in the perf overlay (SYNTHESIS wave-1 probes) —
   the A1/A3 acceptance numbers.
6. ADR-028 structural probe (arena instantiates shared builder) — becomes real at Phase 3,
   as the ADR already promises.

## 6. TRADEOFFS NAMED (Law 2, my lens)

- AIDirector over WorldSim sacrifices the off-AO strategic-layer skeleton; a future
  campaign-map sim starts from zero. Accepted: dead code is not a design asset.
- Dormancy means the AO's far side reacts only to what the beacon/event system broadcasts
  (SYNTHESIS's "event coverage must be honest") — the witness beacons in §2 are the
  mitigation, and `test_witness_rule` is the tripwire.
- Budgeted perception means staler sightings under load — bounded by the per-class floors;
  the corpse class guarantees ADR-005 cadence specifically.
- Rewriting the witness-order probe from source-text to behavioral briefly weakens the
  guard between waves — land the new probe in the SAME change that restructures `_think()`.
