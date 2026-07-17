# Phase 2b — Game/Level-Design lens: booting a populated mission AO for the "feels like Vietnam" look

Read code, not the plan. Files: `scripts/main/game_flow.gd`, `scripts/missions/mission_generator.gd`,
`terrain/core/terrain_manager.gd`, `terrain/core/terrain_zoning.gd`, `scripts/levels/ai_stress_arena.gd`,
plus the two existing benches `tests/test_generator.gd` / `tests/test_village_sim.gd`, and the seed wiring in
`scripts/missions/mission_offers.gd` / `scripts/ui/screens/mission_select.gd`.

## Seed model (the load-bearing fact)

`mission_offers.gd:29-30` and `mission_select.gd:38-39` set **`world_seed == mission_seed`** — "ONE seed
identifies ONE operation." So a single integer drives BOTH:
- **Terrain preset + relief + lowland ceiling**: `game_flow.gd:228` `world.mission_seed = offer.world_seed`
  → `game_world.gd:108 generate_terrain(mission_seed)` → `terrain_manager.gd:129 _derive_ao_preset(seed)` and
  `terrain_zoning.configure()` (lowland ceiling = mn + 0.18·relief).
- **Mission plan**: `game_flow.gd:242 MissionGenerator.plan(world, offer.mission_seed, type)`; PaddyStamper draws
  from `mission_seed+1009` (`paddy_stamper.gd:43`).

`_derive_ao_preset` (terrain_manager.gd:374): `seed%100 < 40` = INHABITED → `AO_INHABITED[seed%2]` =
COASTAL_HILLS(0) if even, RIVER_VALLEY(1) if odd. `>=40` = EMPTY highland jungle (ROLLING/STEEP/PLATEAU).
Relief per preset (`_preset_height_scale`, line 388): COASTAL_HILLS 25m (flat coastal plain, paddies),
RIVER_VALLEY 40m (low center, gentle ridges), ROLLING 90m, STEEP 300m, PLATEAU 160m.

## 1. WINDOWED LOOK PATH — dedicated bench scene, NOT GameFlow.start_mission

**Recommend the dedicated bench** (mirror `test_village_sim.gd` but windowed). `GameFlow.start_mission`
(game_flow.gd:172) is the wrong tool for a *look*:
- It seeds global rng, sets `SaveManager.context`, `CampaignState.begin_mission`, builds loading-screen UI and
  needs the `_swap_screen` app shell (game_flow.gd:184-203).
- Critically it builds an **InsertionRide** (game_flow.gd:275-279) because VILLAGE_RAID has a `start_pad` — you
  spawn ~450-750m away IN THE HELICOPTER (`_plan_village` line 286 `start_pad = _passable_near(...450,750)`),
  fly in, and only then touch ground. That is minutes of sky before you can walk the ville.

The bench gives direct spawn control, skips the ride, and is exactly the world-content path we're testing.
It's the same primitive the two shipped tests already use. Exact sequence:

```gdscript
extends Node
const SEED := 47225                                   # inhabited; see §2
const TYPE := MissionGenerator.MissionType.VILLAGE_RAID

func _ready() -> void:
    var world: GameWorld = load("res://scenes/levels/game_world.tscn").instantiate()
    world.mission_seed = SEED                          # drives terrain preset + zoning + paddy ceiling
    world.spawn_player_on_ready = false
    add_child(world)
    while not world.is_world_ready:
        await get_tree().create_timer(0.25).timeout

    var director := MissionDirector.new()
    world.add_child(director)
    director.setup(world)

    var plan: Dictionary = MissionGenerator.plan(world, SEED, TYPE)
    # Guard: if the AO came up paddy-poor, village_center is ZERO and the ville won't stamp.
    assert(plan.get("village_center", Vector3.ZERO) != Vector3.ZERO)  # else pick another inhabited seed
    var built: Dictionary = MissionGenerator.build(world, director, plan)

    # LOOK AT THE VILLE, not the far start_pad. Stand in the hamlet among civilians+paddies.
    world.spawn_player_at(plan.village_center + Vector3(6, 0, 6))
    # Optional: MissionHUD/SquadSystem if you want the full HUD; not required for the look.
```

Notes: `build()` calls `CampaignState.effective_threat()` / `roster_skill()` (autoload defaults are fine — at
threat 0 the opportunistic-AA block at build line 538 simply no-ops). No `begin_mission` needed for a look.
For "stuff going on" keep plan's rolled time, or force DAY so civilians work the paddies (NIGHT gives campfires
but idle-in-hut civilians). This is representative: real terrain, resident 3D veg (ADR-013 individual GLB trees),
paddies, village, civilians, enemies, and the living-world systems.

## 2. SEED + TYPE — inhabited, paddy country, VILLAGE_RAID

**Primary: SEED 47225, MissionType.VILLAGE_RAID.** 47225%100=25 (<40 → INHABITED), %2=1 → RIVER_VALLEY
(preset 1, 40m relief, low center + gentle ridges = paddy valley). Already measured (Phase-2 context): 82%
jungle / 5.5% paddy, so PaddyStamper reliably yields village anchors here → VILLAGE_RAID will not abort.

**Flatter alternative if Caleb wants maximal "flat land": a COASTAL_HILLS seed** (preset 0, 25m — the flat
coastal plain). Need `seed%100<40 AND seed%2==0`, e.g. **11020** (%100=20, even). COASTAL_HILLS reads flattest
and paddy-forward. BUT it is unverified for anchor density — the bench's `assert(village_center != ZERO)` guard
must be honored; if it trips, fall back to 47225. Cleanest robust bench: scan a short inhabited candidate list
`[47225, 11020, 30024, ...]`, `plan()` each, take the first with `village_center != ZERO` and non-empty
`paddy_fields`, then `build()` that one — guarantees a populated look every run.

What that seed+type should contain: a paddy-anchored hamlet (`_plan_village` line 268-289) with 6-10 defenders +
cache/APC target, 3-5 civilians (some an informer) working the paddies, chickens, contiguous rice fields with
grassy margins, dense MEDIUM jungle default, plus corridor ambient life (below).

## 3. Does build() actually PLACE it? Yes for VILLAGE_RAID — with a type-dependent gap

`build()` (mission_generator.gd:339) for VILLAGE_RAID stamps a genuinely populated AO:
- **Village + civilians**: site kind `"village"` → `planner.stamp_village` + 3-5 `Civilian.spawn` with occupations
  and working points + 2-4 chickens + campfire at night + cache→APC swap (build lines 380-414).
- **Defenders**: `village_defenders` group, count 6-10, **`lazy:false` → spawned immediately** (not dormant),
  plus 1-2 spider holes (lines 521-527).
- **Paddies**: stamped in `plan()` (PaddyStamper polygons + `TerrainZoning.classify` RICE_PADDY visual+AI grid),
  present on any inhabited seed independent of mission type.
- **Corridor ambient life** (lines 554-606, gated on `p.has("start_pad")`): 1-2 MORE ambient villages with
  2-3 civilians each and 50% a guard group, a 50% temple ruin, 2-4 B-52 craters (some with water), and 2-3 lazy
  ambient patrol circuits. VILLAGE_RAID has a start_pad, so ALL of this fires.
- **Living-world activity**: `_wire_systems` (line 633) → CampDirector (role-swapping garrisons), Convoy,
  AirTraffic, AmbientWar (distant gunfire/arty), WorldSim LOD.

**The gap — mission type matters:**
- **FIREBASE_DEFENSE has NO start_pad** (`_plan_firebase` line 327 sets insertion=firebase). The entire corridor
  ambient-life block (villages, temple, craters, ambient patrols) is skipped — only firebase + waves. Worst for a
  populated-village look.
- **PATROL** has start_pad → corridor ambient villages fire, but no *objective* village; fewer guaranteed ville.
- **RESCUE / ANTI_AA** have start_pad → corridor life fires, but the anchor site is a guard camp / AA battery,
  not a hamlet.
- **VILLAGE_RAID** is the only type that guarantees BOTH an objective hamlet AND corridor ambient villages. Pick it.

**What the bench must enable to be a fair test vs the arena.** The arena "feels right" because it hand-places
villages, contiguous rice patches, heavy per-clump veg stamps, tree lines, bamboo, elephant grass AND two live
squads fighting = constant motion. The mission AO matches everything EXCEPT that most enemies are LazyGroups that
sleep until the player closes to `activation_range` (~140m). So on first spawn the *combat* is quiet by design.
For an honest comparison the bench should:
1. Spawn AT the ville (`plan.village_center`), where defenders are non-lazy and already live, civilians are
   working, chickens moving — that is the arena-equivalent motion.
2. Use DAY time so civilians and paddy work read (the arena's activity is visual/constant).
3. Let `_wire_systems` run (it does, inside build) so AmbientWar/AirTraffic/Convoy give the distant-war layer the
   arena fakes with two squads. Optionally nudge `CampaignState` threat ≥0.5 before build if you want the
   opportunistic-AA sites too (build line 538) — not required.
The one thing the mission AO will NOT show at spawn is a rolling firefight; that is a Pillar-3 feature (escalation
on contact), not a defect. Judge atmosphere by the standing world (veg, paddies, ville, civilians, ambient war),
not by immediate combat.
```
```
