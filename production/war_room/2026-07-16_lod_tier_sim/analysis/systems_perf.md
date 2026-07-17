# Systems / Performance Architect — LOD-tier world sim (ADR-025)

Read from code this session. Files cited inline.

## 1. THE ARENA PREMISE — does node-LOD produce a measurable win in `test_arena_perf.gd`? NO.

Two independent code facts kill the arena win:

**(a) No player anchor.** `test_arena_perf.gd:29` sets `spawn_player=false`. Distance-to-player
node-LOD has no reference point. `enemy_base._update_think_lod` (enemy_base.gd:44-47) already handles
this: `player == null` → `_think_interval_current = 0.6` for **every** unit. So the probe is ALREADY
running all AI at the slowest think rate (0.6s, the T1/T2 floor). The think-rate LOD is maxed out
before any new code lands — there is no headroom there to demonstrate.

**(b) Everyone is T0 by geometry.** Even if we anchored on the firebase overlook `(-35,1,35)`
(player.gd spawn, ai_stress_arena.gd:829), `hot_start` bases sit US ~(-40,40) / VC ~(35,-35)
(ai_stress_arena.gd:856-857). Max unit-to-anchor distance ≈ 110m; the fight clusters <150m. With
band edges T0<100 / T1 100-500 / T2>500, essentially all ~50 live units fall in T0/near-T1. **No
unit ever reaches T2** (physics-off), which is where the real saving is. Worse: adding a per-frame
LOD scan + hysteresis bookkeeping across 50 clustered units is a **net LOSS** in this probe — pure
overhead with nothing to cull. Against the ~27 FPS floor (briefing L44) that is the wrong direction.

**Conclusion: the arena perf probe cannot honestly show a node-LOD win, and may regress.** Claiming
an arena win would be a canon violation of the "MEASURE" mandate.

### Where the win ACTUALLY appears
Real game: player present, enemies spread across the ≤2km AO (ADR-013), most far / idle / patrolling /
asleep. Those distant units get T2 (physics off + invisible) → their entire `_physics_process` stops.
That is the CPU the feature buys back. It is invisible in a 200m arena where every unit is in the
player's lap.

### Honest probe design (`test_lod_perf.gd`)
Do NOT bolt this onto the combat arena. Build a dedicated LOD probe:

1. **Reference anchor.** Either spawn a real player OR pass an anchor `Vector3` the LOD reads
   (dummy `GameManager.player` stand-in). The probe must fix the anchor at origin.
2. **Sized to the AO, not the arena.** Bands need ≥500m of spread; the 200m arena physically cannot
   place a T2 unit. Use a bare `Node3D` world (no arena environment) spanning ~1.2km.
3. **~200 units seeded across distance bands from the anchor**, in a NON-combat state (RELAXED /
   patrol) so LOD is legitimately allowed to fire (you never cull a unit fighting the player):
   - ~40 at 0–100m (T0, full sim)
   - ~60 at 100–500m (T1, think 0.15→0.45)
   - ~100 at 500–1200m (T2, physics off)
   Place them on a deterministic grid/ring from `rng_seed` (ADR-010, one seed).
4. **A/B by flag on identical positions + seed.** Run twice: `lod_enabled=false` (all units full sim)
   vs `lod_enabled=true`. Same warmup/sample window as the existing probe (WARMUP 4s / SAMPLE 12s,
   test_arena_perf.gd:9-10). Sample `Engine.get_frames_per_second()`, report avg + min for each.
5. **The number that matters is the delta** (FPS_on − FPS_off) and the T2 count. If on ≈ off, the
   feature is overhead, not a win — report that honestly and cut it.
6. Headless caveat stands (test_arena_perf.gd:2-4): logic-only, no render. That is correct here —
   we are measuring the AI/physics cost the cull removes, which is exactly the CPU side.

## 2. What per-frame cost does node-LOD actually remove?

`_physics_process` (enemy_base.gd:447-500) runs EVERY frame for a live unit. Ordered by cost:

- **`HitzoneBuilder.sync(...)` every frame** (enemy_base.gd:449-456). Live models re-sync ~16 hitzone
  areas onto skeleton bones each frame (`_hitzone_sync`, built with 64/16 at line 440). This is the
  single biggest per-frame cost and it runs whether or not the unit is thinking. **T2 kills it entirely.**
- **`move_and_slide()`** (enemy_base.gd:500) — CharacterBody3D kinematic collide-and-slide, every frame.
- `_execute(delta)` (enemy_base.gd:488, def 1188) — smooth aim lerp, strafe, fire cadence, nav
  `get_next_path_position` reads.
- gravity `is_on_floor` + `_update_decay` + `_update_unstick` — cheap.

**Think-rate cost (already LOD'd by interval), gated at `_think_interval_current`** in `_think`
(enemy_base.gd:531-551): the two **physics raycasts** are the expensive part —
`_update_perception` (enemy_base.gd:760, `CombatManager.has_line_of_sight` → `intersect_ray`,
combat_manager.gd:301-312) and `_update_line_of_sight` (enemy_base.gd:937, second raycast). Plus
`NavBaker.box_index_at`, `_find_best_target`, `_squad_sync`.

**T1 (0.15→0.45):** cuts think FREQUENCY ~3×, so the two LOS raycasts + perception + target scan drop
~66%. It does NOT touch the per-frame `HitzoneBuilder.sync` / `move_and_slide` — those still run every
frame. So T1 alone is a modest saving (raycast-bound units benefit most).

**T2 (`set_physics_process(false)` + `visible=false`)** (`set_lod_abstract`, enemy_base.gd:120-122):
removes EVERYTHING above — the per-frame sync, move_and_slide, AND all think work. This is the real win.

**Is `set_physics_process(false)` on a CharacterBody3D enough? YES.**
- `move_and_slide` / nav are only invoked from inside `_physics_process`; if the callback never fires,
  they cost zero. A CharacterBody3D is kinematic — it has NO autonomous engine-side physics tick (unlike
  a RigidBody). It just sits.
- `NavigationAgent3D` does not self-tick; path work happens on `get_next_path_position` calls, which
  live inside `_execute`. Physics off → zero nav cost.
- Remaining passive cost: the node still exists in the tree and its hurtbox/hitzone Area3Ds remain in
  the physics space (broadphase). If a T2 unit is truly out of the fight, also disabling its collision
  (`process_mode`/monitorable) would squeeze the last drops — but that risks the raycasts of OTHER
  units missing it. Leave collision on; the `_physics_process` cull is 95% of the win.
- **Biggest single AI cost in `_physics_process` = the every-frame `HitzoneBuilder.sync`, then
  `move_and_slide`.** The LOS raycasts are already think-gated, so they are the T1 target, not T2's.

## 3. Round-robin budget + hysteresis + min-dwell — concrete values

The walking unit is the thrash case. Speeds: normal walk ~1.5–2.5 m/s; `CROUCH_SPEED_CAP` 1.9
(enemy_base.gd:148). Civilian precedent: 5m hysteresis, 2s recompute, NO min-dwell
(civilian.gd:50-55, 329-354).

**The civilian 5m hysteresis is too thin.** At 2.5 m/s over a 2s recompute a unit moves 5m — equal to
the hysteresis band. A unit crossing a band edge roughly perpendicular can re-cross within one tick →
flap. Fix:

- **Band edges:** T0<100m / T1 100–500m / T2>500m (as ADR-025).
- **Hysteresis ≥ v_max × recompute × safety = 2.5 × 2.0 × ~2 = ~10m.** Use **12m** each side. That
  guarantees a unit cannot walk back across the same edge inside one recompute window.
- **Min-dwell 4.0s.** After any tier change, lock the tier for 4s before another change is allowed.
  This is the real anti-thrash guarantee (hysteresis alone fails a unit pacing a beat on the line);
  4s ≈ 2 recompute cycles.
- **Recompute 2.0s** (keep civilian cadence).
- **Round-robin ~1ms budget:** never scan all N units in one frame. Process a slice
  (`ceil(N / (recompute_s × fps_target))`) per frame so the LOD pass itself is flat and never spikes.
  A distance check is one `distance_squared_to` (use squared, skip the sqrt) + band compare per unit —
  cheap, but at 200+ units you still amortize it. **Use `distance_squared_to` against pre-squared band
  edges** to stay well inside 1ms.

**Tradeoff of these values:** larger hysteresis + 4s dwell + round-robin lag means a unit's tier
change trails its true position by up to ~1 dwell cycle. Practical effect: a unit that sprinted past
the player keeps full sim a few seconds longer than strictly needed (a few wasted frames), and a unit
entering render range can wake up to ~1 recompute + round-robin period late → mild pop-in risk. Tighter
values save marginally more CPU but reintroduce boundary flap, which itself burns the tier-change cost
(model show/hide, physics toggle) repeatedly — flap is more expensive than the frames it saves.

## 4. Named sacrifice (perf lens)

**Culling buys frames by lying about the off-AO world.** A T2 unit has `set_physics_process(false)` —
it does not move, shoot, seek cover, or close on the player. The world holds its breath behind you.
Concretely:
- A VC squad at 520m maneuvering to flank **freezes at the 500m line** until you re-close. Turn around
  and a frozen firefight snaps back to life — pop-in that reads as a glitch, not fog of war. This
  directly taxes Pillar 2 (atmosphere / living world) and Pillar 3 (freedom — enemies that should keep
  maneuvering while you reposition instead stand still).
- `WorldSim`'s 60s abstract tick (world_sim.gd:111-127) is the intended cover, but it only advances
  `position += velocity × 60s` — **no combat resolution, no perception, no cover.** It moves bodies in
  straight lines; it does not simulate the fight. So the statistical layer cannot fully mask the freeze.
- **And the tick is not free.** The LOD scan + hysteresis + dwell bookkeeping is a NEW per-frame cost.
  In any scene where units are clustered inside one band (the arena; a single objective assault), it is
  pure overhead with nothing to cull — a regression against the ~27 FPS floor. The feature only pays
  when units are genuinely spread across the AO with most of them far. **It must be measured to be
  believed, per band, not assumed.**

The trade in one line: **off-AO tactical fidelity and a few frames of clustered-scene overhead, in
exchange for real frames whenever the player fights a spread-out AO.** Legitimate — but only if the
honest probe (Q1) proves the T2 population is large enough to clear the tick's own cost.
