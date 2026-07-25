# DECREE — THE SUPPORT FIRE TEST ROOM (design + plan + audit)

**Session:** 2026-07-25 · Arbiter: recon-overseer · Status: PROPOSED — awaits Summoner. Deliverable is
DESIGN + PLAN + AUDIT. No destruction code built this session (spec-only, per the queued request).

## Council verdicts (full analyses in ./analysis/)
- **Systems:** build the thin bench, touch NO destruction code — the test room is ~90% already built inside
  `ai_stress_arena._wire_fire_support()` (`:1418-1462`). **Biggest surprise: the brief's founding gap is
  STALE** — `combat_manager.gd:178-185` already routes every blast through a shared `AgentRegistry.props`
  bus (tested; `DestructibleFortification` blows up TODAY). The job is REGISTRATION, not N new call-sites.
  The M79 hitscan bug is **already fixed** (`m79.tres:27`). WP/Willy Pete is the one true content gap.
- **Tech-director:** trees cheapest+affordable now — and the DESTRUCTIBLE_JUNGLE_PLAN **bitmask is partly
  obsolete**: `TreeCoverLayer` already instances each tree individually (`:159-195`), so felling = sink that
  one instance's transform. Buildings affordable ONLY batched (fold `DestructibleVehicle`→`Destructible`,
  rubble in one shared MultiMesh, area-level defers over frames). VFX = reuse `GunFX._spawn_explosion_visual`
  CPUParticles (`gun_fx.gd:163`), NOT gib RigidBody. **PROVE BEFORE SHIP: terrain deform** — `modify_terrain`
  rebuilds chunks on the MAIN THREAD; `MAX_DEFORMS=40` is per-MISSION, not a per-frame throttle.
- **Game:** CONDITIONAL YES — state-swap reads WELL in PSX. What sells it: mesh-swap under an occluding
  particle burst + screen shake (`player.gd:1394`) + permanence (drop one, illusion collapses). **Layer
  priority: TREES → TERRAIN(scar) → BUILDINGS.** Trees carry the "fell a treeline to build cover" verb (the
  most Pillar-3 idea in the plan); buildings add a perf tail + no new verb — last.
- **Devil:** two dangers — (1) worst perf spike = a napalm run mid-firefight (`field_director.gd:424` → 30m
  main-thread deform + veg-rematerialize + 66m scar, atop uncapped AC-47 + burning cards + an 18v18 already
  at the CPU wall); (2) "test room" is a Trojan horse for the 4-phase destruction epic before PLAYTEST R4.
  **MVP: player + RTO + a menu firing every support type, verify FX/crater/scar fire, trees stay standing
  (honest v1) — it doubles as the bench.** ADR-010: time-seeded fell/LZ scatter desyncs — needs a ruling.

## THE CORRECTED AUDIT (what is ACTUALLY in the tree — the plan aged out)
| System | State | Evidence |
|---|---|---|
| Fire-support roster | **BUILT** — bombs/napalm/arty/mortar/spectre/cbu on T/1-6; player M79/LAW/frag/claymore/satchel/smoke/flare | `field_director.gd` fire_support; arena `_wire_fire_support:1418` |
| Explosion → world-object damage | **BUILT** (brief's gap is STALE) — shared `AgentRegistry.props` blast bus; forts die today | `combat_manager.gd:178-185` |
| Terrain craters | **BUILT** — heightmap dig + scar decals, profiles + `MAX_DEFORMS=40`. Deform is MAIN-THREAD, per-mission cap only (the perf risk) | `damage_system.gd`; `terrain_manager.gd:281-283` |
| Tree cover + trunk colliders | **BUILT** per-instance (bitmask NOT needed) | `tree_cover_layer.gd:159-195` |
| Fall assets (felled_tree/trunk/stump) | **EXIST** on disk | `assets/world/vegetation/` |
| A working destructible (forts) | **BUILT** — a narrower `DestructibleFortification` that blows up now | (generalize per ADR-023) |
| Building-ruin art | **EXISTS** (burned_hut, ruin_*, rubble_*, bomb_crater) | `structures/ruins/` |
| Test-room rig | **~90% BUILT** in the arena | `ai_stress_arena._wire_fire_support:1418-1462` |
| M79 AOE | **FIXED** (plan's bug is stale) | `m79.tres:27` |
| TREE/BUILDING destruction state-machines | **NOT BUILT** — `destructible.gd`/`tree_registry.gd`/`falling_tree.gd` absent (but forts + props-bus are the precedent) | — |
| Content gaps | WP/Willy Pete smoke; the collision_table material-by-filename footgun still wants killing | — |
| Uncommitted | `ac47_spooky.*` (the AC-47/Spectre model) · `scripts/world/mg_emplacement.gd` (mannable MG, the top deferred feature) — audit incomplete, flag for Caleb | — |

**Headline:** the founding "the game can't damage world objects" premise of `DESTRUCTIBLE_JUNGLE_PLAN.md`
is obsolete — the damage BUS exists and works. Destruction is now REGISTRATION + state-swap COMPONENTS on a
proven bus, not a from-scratch engine. This roughly halves the perceived scope.

## THE TEST ROOM (design — the safe, near-term instrument)
A permanent benchmark modeled on the AI arena. Player + one RTO ally inside the 10m radio leash (net always
up), a live `FieldDirector` stocked unlimited per tier (bypasses the campaign grant), all six support tiers on
T/1-6 + player-carried ordnance, a toast readout, and a TARGET FIELD (existing tree/building GLBs +
`DestructibleFortification` segments that already blow up). New: `support_fire_range.gd` + `.tscn` + `.bat`.
**Fossil-law note (systems):** do NOT clone a second FieldDirector-on-inert-world rig — EXTRACT the arena's
`_wire_fire_support` into a shared `FireSupportBench` helper both scenes call (a small refactor of
`ai_stress_arena.gd`, a load-bearing file). Verifies (a) every effect FIRES (FX/crater/scar/telegraph) and,
once destruction lands, (b) it DESTROYS. v1 verifies effects with trees standing (honest) — it is already the bench.

## DESTRUCTION DESIGN (cheap, state-based, Forward+ / PSX / ADR-026)
- **TREES (priority 1, cheapest):** build on `TreeCoverLayer`'s per-instance model (NOT the merged-patch
  bitmask). Fell = sink the instance transform + disable its trunk body; a transient `falling_tree.gd`
  scripted hinge (never RigidBody) falls AWAY from the blast (aimable) and kills what it lands on; it leaves
  a permanent fallen-log MultiMesh instance = HARD cover you can go prone behind. **The verb: fell a treeline
  to build cover across open ground.** Register the tree area on the props bus for `damage_area`.
- **BUILDINGS (priority 3, batched only):** a general `Destructible : StaticBody3D` (hp / take_damage /
  destroy) that FOLDS IN `DestructibleFortification` (ADR-023). Destroy = mesh-swap intact→damaged→rubble +
  scatter rubble into ONE shared MultiMesh (never per-prop bodies) + reassign the cover group + a DamageSystem
  crater. HP/material live in `collision_table.gd` (authored data — kill the filename footgun). Area-leveling
  (napalm/CBU on a village) DEFERS destruction over frames.
- **TERRAIN (priority 2, but split):** the SCAR-DECAL + veg-clear is cheap and reads — that is the default.
  The real HEIGHTMAP HOLE is the main-thread spike (`MAX_DEFORMS` is per-mission, not per-frame) — down-tier
  most craters to scar-only; gate real holes behind a per-frame throttle, and PROVE the worst frame first.
- **VFX/feel (all layers):** mesh-swap hidden under an occluding `GunFX._spawn_explosion_visual` CPUParticle
  burst + distance-scaled screen shake (`player.gd:1394`) + permanence. Reuse — write no second debris spawner.

## PHASED PLAN (risk-ordered, each gated)
- **P1 — THE BENCH (SAFE to build; needs the shared-helper extraction).** `support_fire_range.{gd,tscn,bat}`
  + extract `FireSupportBench` from the arena. Verifies every support effect fires + telegraphs; trees stand.
  Add WP/Willy Pete. No destruction. *(Not built this session — see "what needs Caleb" — because the clean
  version refactors the load-bearing arena and can't be suite-verified tonight.)*
- **P2 — THE PERF PROOF (gate for everything below).** In the bench, measure the worst single-frame spike:
  a napalm run + AC-47 + a live firefight, ship config, on the Intel-UHD floor. This decides whether real
  heightmap holes ship at all, and the affordable simultaneous-destructible count.
- **P3 — TREE FELLING (needs Caleb's bless + P2).** `falling_tree.gd` + fallen-log MultiMesh on the
  TreeCoverLayer per-instance model + props-bus registration. The build-cover verb.
- **P4 — TERRAIN SCAR + throttled holes (needs P2).** Default scar-decal; throttle real deforms per-frame.
- **P5 — BUILDINGS (needs Caleb's bless + P2; last).** General `Destructible`, fold in forts, collision_table
  material/HP, batched rubble, deferred area-leveling. Kill the filename footgun.
The whole destruction track is subject to THE GATE (parked while PLAYTEST R4 is open) unless the Summoner
redirects. P1 the bench is exempt (it's an instrument/evidence-gatherer, like the AI arena).

## NEW ADR (PROPOSED)
**ADR-031 — The Destruction Doctrine:** state-swap, never fracture (ADR-001); all blast damage rides the ONE
`AgentRegistry.props` bus (no new call-sites, no second damage authority — ADR-023); terrain destruction is
scar-first, real holes throttled + perf-gated (ADR-026); permanence is sacred within the active firefight
radius and recycles only far behind the patrol; fell/rubble scatter seeds from position+op-seed, never Time
(ADR-010); `DestructibleFortification` folds into the general `Destructible`. PROPOSED; ratified on Caleb's bless.

## TRADEOFFS NAMED
Permanence (the whole payoff) vs a rising per-patrol perf tax on a 19-23fps frame — recycle far-field only ·
real heightmap holes may down-tier to scars (no hole) to protect the frame · buildings buy atmosphere but no
new verb and carry the perf tail · the bench's clean form refactors the load-bearing AI arena (fossil-law
care) · destruction before PLAYTEST R4 spends the frame and the calendar on the wrong thing if the perf proof fails.

## OPEN DECISIONS FOR THE SUMMONER (morning)
1. **Fire-support roster** — confirm the six tiers + player ordnance is the intended set; add WP/Willy Pete?
2. **Terrain-destruction depth** — scar-decal default with real holes throttled+gated (recommended), or real
   holes everywhere (rejected by perf), or scars-only (cheapest)?
3. **Does the perf budget allow BUILDING destruction at all** — pending the P2 proof; bless the proof-first gate?
4. **Permanence policy** — sacred-in-firefight-radius / recycle-far-field (recommended)?
5. **Build the P1 bench now?** — it's safe but refactors the arena and can't be suite-verified tonight; bless
   building it (with the FireSupportBench extraction) as the first move, or keep spec-only until you're at the keys.
6. **Determinism ruling** — seed fell/LZ/rubble scatter from position+op-seed, not Time (ADR-010).
7. Audit the uncommitted `ac47_spooky` + `mg_emplacement` — are they in-scope for the bench?
