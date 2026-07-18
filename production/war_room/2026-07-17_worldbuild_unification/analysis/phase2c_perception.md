# Phase 2C — AI-PERCEPTION architect: the "crouched-in-a-bush, whole camp instakilled me at 150m" bug

Read from CODE only (`scripts/enemies/enemy_base.gd`, `enemy_squad.gd`, `mission_director.gd`,
`mission_state.gd`, `terrain/core/gameplay_grid.gd`, `scripts/player/player.gd`, `noise_bus.gd`).

## TL;DR

The player-detection path DOES apply the vegetation sight-cap and DOES apply a crouch bonus. The bug
is not a missing check — it is that **the bush the player hid in does not exist in the field the AI
reads.** Concealment is a coarse 12 m biome grid; a decorative bush on grassland/clear ground registers
as ~0.0–0.3 density → sight cap **~111–140 m**, not 45 m. At ~150 m (likely nearer) a fully-exposed
target is inside the cap for *every* man in the camp with LOS, so they all lock nearly simultaneously,
and the shared-squad-target + cold-fighter-fires-without-own-LOS path turns that into camp-wide focus
fire. Detection is gradual, not binary — there is no instant-lock bug — but with zero real concealment
the accumulator ramps fast and N men ramp at once, which *feels* instant.

---

## 1. Does player-detection apply veg concealment + the sight cap? YES — but the field is too coarse.

- `_update_perception()` (enemy_base.gd:771-828) is the player-detection path. It computes
  `cap = _sight_cap(candidate.global_position)` (line 793) and **hard-gates on `best_dist <= cap`**
  (line 794). So the cap IS applied to AI-vs-PLAYER, not only AI-vs-AI. Good.
- `_sight_cap()` (enemy_base.gd:649-656): `lerpf(SIGHT_CAP_OPEN=140, SIGHT_CAP_JUNGLE=45, veg)` where
  `veg = max(grid.get_vegetation(self), grid.get_vegetation(target))`. Correct shape.
- **THE GAP:** `get_vegetation()` (gameplay_grid.gd:375-377) reads `vegetation_density`, a
  **12 m-cell** grid (`cell_size_meters = 12.0`, line 13/78) whose values come from the cell's
  *TerrainType* via `_estimate_vegetation()` (286-296): CLEAR 0.0, GRASSLAND 0.3, LIGHT_JUNGLE 0.5,
  MEDIUM 0.7, HEAVY 0.95. A **single decorative bush / ground-clutter prop is finer than 12 m and is
  NOT stamped into this field.** Crouch in a bush sitting on GRASSLAND and veg=0.3 → cap =
  lerp(140,45,0.3) ≈ **111 m**; on CLEAR ≈ **140 m**. The visual bush and the AI concealment field are
  two different worldbuild systems — this is the unification defect.
- Two more ways the cap silently opens to 140 m:
  - `_grid == null` (enemy_base.gd:653) → flat `SIGHT_CAP_OPEN * mult` = 140 m, zero veg. `_grid` is
    only wired if a `game_world` node exposes `gameplay_grid` (enemy_base.gd:290-292).
  - `world_to_grid()` **clamps** to grid bounds (gameplay_grid.gd:305-306). A player/camp near or past
    the built grid edge reads the edge cell — usually low-veg CLEAR → 140 m cap.

## 2. Does crouch/low_posture reduce detectability? YES — but only the RATE, never the cap.

- Player exposes `is_crouching`, `is_prone`, `is_moving()` (player.gd:42,44,779). `_update_perception`
  reads all three (enemy_base.gd:812-818): prone `gain *= 0.35`, crouch `gain *= 0.5`, then moving
  `*= 1.5` / still `*= 0.6`.
- **These scale the awareness accumulator's fill rate, not the hard `best_dist <= cap` gate.** So a
  crouched player whose cell veg is low is still *inside* the cap and still gets seen — just a bit
  slower. And a **creeping** crouch (velocity > 0.5, is_moving true) cancels most of the crouch bonus:
  crouch 0.5 × moving 1.5 = net 0.75. Crouch-walking through a bush is barely stealthier than standing
  still in the open.

## 3. Whole-camp propagation — the exact mechanism.

- **Every man in a camp shares ONE squad_id**: `mission_director.spawn_tracked_enemy()` sets
  `enemy.squad_id = hash(group_tag)` (mission_director.gd:42); the whole camp group spawns with the
  same tag (mission_generator.gd:504-518).
- A spotter with eyes-on writes the player as the squad's shared target: `_squad_sync()`
  (enemy_base.gd:660-678) → `EnemySquad.report_contact()` (enemy_squad.gd:233-249).
- Squadmates pull it in `_squad_sync` (enemy_base.gd:671-678) — **but that only raises them to ALERT,
  and only if within `SHARE_RANGE*2 = 60 m` of the PLAYER** (line 677). At 150 m the far camp is not
  woken by squad-share alone.
- `mission_director.report_contact()` (mission_director.gd:52-55 → mission_state.gd:73-78) is **only a
  scoring ledger** (contacts_detected for the debrief). It does NOT wake any enemy. Not the alarm.
- Gunfire noise is NOT the camp-waker here: enemy shots emit `GUNSHOT` with **source_team = 1**
  (enemy_base.gd:1912,1950), and `_on_noise_heard()` returns immediately on `source_team == 1`
  (enemy_base.gd:886). Enemies are deaf to their own side's fire. (The PLAYER's shot, team 0, radius
  150 m — noise_bus.gd:18 — would cascade the camp; but a crouching player who never fired triggers
  none of this.)
- **So with no player gunfire, the actual "camp-wide" mechanism is simply N independent sightings of
  an unconcealed target.** Because failure #1 leaves the cap at ~111–140 m, *every* camp member with
  LOS to the exposed player builds awareness at once and crosses to COMBAT within a few seconds of
  each other. The shared-target then concentrates them: once a man flips COMBAT, `_think_cheap_combat`
  sets `has_line_of_sight = target != null` (enemy_base.gd:589) — a **cold fighter fires at the shared
  target without his own LOS check**, so men who cannot actually see the player still pour rounds at
  his last-known. That is the focus-fire.

## 4. Gradual or binary? GRADUAL. No instant-lock bug.

- Detection is a 0..1 `awareness` accumulator across 4 tiers RELAXED→SUSPICIOUS→ALERT→COMBAT
  (enemy_base.gd:64-68, 822-834). First sighting does not lock; COMBAT needs `awareness >= 1.0`.
- Rate: `gain = clampf(1.5*(1 - d/cap) + 0.25, 0.2, 2.0)` (line 811), `awareness += gain *
  THINK_INTERVAL` (823). Point-blank (`< CLOSE_SENSE_RANGE = 10 m`) slams `gain = 3.0` (819-820) — a
  near-instant inner bubble, correct for <10 m, irrelevant at 150 m.
- Minor real bug (not the instakill): line 823/827 accumulate with the **constant** `THINK_INTERVAL`
  (0.15) even when the man is LOD-throttled to 0.3–0.6 s thinks (`_think_interval_current`,
  enemy_base.gd:39-54) — so accumulation is under-counted at range, i.e. it errs SAFE for the player.
- The "instant" feeling = failure #1 (cap too generous → target fully exposed) × failure #3 (N men
  ramp simultaneously + no-own-LOS cold fire), not a binary lock.

---

## The three failures — file:line + minimal fix (keeps tiered AI + witness guardrails)

### A. No concealment from the bush  — ROOT CAUSE, fix this first
- Where: `_sight_cap()` enemy_base.gd:649-656 reads the 12 m biome field
  `gameplay_grid.get_vegetation()` (gameplay_grid.gd:375-377); decorative bushes/clutter are not in
  it. Crouch bonus (enemy_base.gd:812-816) scales rate only, not the cap.
- Minimal fix (perception side, self-contained): in `_update_perception`, after `cap` is computed
  (line 793), when `candidate == player` and the player is stationary-crouched/prone, tighten the cap
  rather than only the rate — e.g. `if is_prone: cap *= 0.4` / `elif is_crouching and not is_moving():
  cap *= 0.6`. This puts a low-crouched player in a bush back outside a distant camp's cap without
  touching the accumulator math.
- Proper unification fix (the decree's real work): have the clutter/`VegetationManager` bush placement
  stamp a fine concealment value into `gameplay_grid` (a parallel higher-res mask sampled by
  `get_vegetation`), so "the jungle the AI reads is the jungle the player sees" (the grid's own stated
  goal, gameplay_grid.gd:154-157) holds at bush scale, not just biome scale. Also close the
  `_grid == null` (line 653) and out-of-bounds-clamp (gameplay_grid.gd:305-306) escape hatches — treat
  out-of-grid as OPEN only deliberately, and assert `_grid` is wired in real missions.

### B. Camp-wide detection / focus-fire
- Where: single squad_id per camp (mission_director.gd:42); cold combat fighter fires at the shared
  target with a forged LOS (`has_line_of_sight = target != null`, enemy_base.gd:589) via
  `EnemySquad.shared_target` (enemy_squad.gd:261-265).
- Minimal fix (keeps the witness/tier guardrails): in `_think_cheap_combat` do not grant blind precise
  LOS. Gate it: `has_line_of_sight = target != null and _can_witness(last_known_target_pos)`
  (reuse the existing witness test, enemy_base.gd:698-710). A cold man who genuinely can't see the
  last-known point should SUPPRESS/INVESTIGATE toward it, not precision-fire an unseen target at
  150 m. This preserves "a camp reacts to a real contact" while stopping men-behind-walls from
  focus-firing a target only one spotter can see.

### C. Instant lock
- No discrete instant-lock defect. If a belt-and-braces guard is wanted: make time-to-COMBAT scale
  with range so a first long-range sighting must dwell through SUSPICIOUS→ALERT before COMBAT (the
  ladder at enemy_base.gd:829-834 already exists; the fix is really A, which restores the range gate).
  Optionally fix the LOD accumulation mismatch (use `_think_interval_current` at lines 823/827) — but
  note it currently errs in the player's favour, so it is not urgent.

## What is sacrificed (no free lunch)
- Fix A (tighten cap on crouch) makes a stationary crouched player quite hard to see even in the open —
  arguably *too* forgiving on bare ground. The clutter-stamp version is the honest fix but is real
  worldbuild plumbing (fine mask + placement hook), not a one-liner.
- Fix B removes the "whole camp instantly walks fire onto you" drama; a camp will now take a beat to
  converge as men gain their own LOS. That is more correct but less immediately terrifying — tune the
  investigate aggression so it doesn't read as the camp ignoring a live contact.
