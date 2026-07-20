# Systems Designer — Ally Sight Parity (ally_base.gd:457-479 vs enemy_base.gd:686-694)

## Code read (pointers)
- `scripts\allies\ally_base.gd:457-479` `_find_target()` — flat `closest_dist = 60.0`, loops
  `AgentRegistry.enemies`, picks nearest, **no LOS check, no FOV, no weather/veg term**. LOS is
  evaluated separately in `_update_line_of_sight()` (481-497) *after* target is already locked,
  and only feeds `contact_conf`/goals — it does not gate acquisition.
- `scripts\enemies\enemy_base.gd:687-694` `_sight_cap(at)` — `MissionWeather.sight_mult` (static,
  `scripts\world\mission_weather.gd:8,92`) × `_grid.get_vegetation()` lerp between
  `SIGHT_CAP_OPEN=140.0`/`SIGHT_CAP_JUNGLE=45.0` (enemy_base.gd:72-73) × an `IllumFlare.is_lit`
  floor. `_grid` is fetched once in `_ready()` from the `"game_world"` group (285-287) — the exact
  same pattern already used by `scripts\player\player.gd:495-496` (`gw.gameplay_grid`), which I own.
  `MissionWeather` and `IllumFlare` are static-var/static-func classes (`static var sight_mult`,
  `static func is_lit`), callable from anywhere without an instance.
- `_sight_cap` is consumed by `_can_witness()` (736-750, corpse/witness checks) and by
  `_update_perception()` (810-893, the RELAXED→SUSPICIOUS→ALERT→COMBAT gain gate, with an FOV cone
  and a full LOS raycast). **Important wrinkle:** once a man is already in `AlertTier.COMBAT`,
  re-targeting in `_find_best_target()` (983-1026) filters on flat `aggro_range` (`alert_range *
  2.0`), NOT `_sight_cap` — so EnemyBase's own COMBAT-tier retarget sweep is *also* weather-blind.
  AllyBase has no alert tiers; a target-carrying ally is the behavioral equivalent of an
  already-COMBAT enemy, so the fair comparison for `_find_target` is really against
  `_update_perception`'s *initial-detection* gate (which IS weather/veg-capped), not against
  `_find_best_target`'s retarget sweep (which isn't). This is a pre-existing asymmetry inside
  EnemyBase itself, out of scope here, but the owning agent should know it before "fixing" ally to
  match a spec that enemy doesn't fully honor after first contact.

## 1. Least-bad shape given the ownership split

Take (a), with one refinement: the helper must not re-declare the tuning constants, it must **read
EnemyBase's own public consts by reference** (`EnemyBase.SIGHT_CAP_OPEN`,
`EnemyBase.SIGHT_CAP_JUNGLE` — reading a const across class boundaries is not "editing"
`enemy_base.gd`). New file `scripts/ai/sight_cap.gd`, `class_name SightCap`, one static function:

```
static func compute(grid: GameplayGrid, from_pos: Vector3, at: Vector3) -> float:
    var mult: float = MissionWeather.sight_mult
    if mult < 0.9 and IllumFlare.is_lit(at):
        mult = maxf(mult, 0.9)
    if grid == null:
        return EnemyBase.SIGHT_CAP_OPEN * mult
    var veg: float = maxf(grid.get_vegetation(from_pos), grid.get_vegetation(at))
    return lerpf(EnemyBase.SIGHT_CAP_OPEN, EnemyBase.SIGHT_CAP_JUNGLE, clampf(veg, 0.0, 1.0)) * mult
```

AllyBase gains a `_grid: GameplayGrid = null` field fetched once in `_ready()`, mirroring
`enemy_base.gd:285-287` / `player.gd:495-496` exactly (established pattern, zero invention), then
`_find_target()`'s `closest_dist` seed becomes `SightCap.compute(_grid, global_position, candidate_pos)`
per-candidate instead of a constant.

**Named risk (Fossil Law / competing-systems class):** for the window between this commit and the
owning agent's delegation, `enemy_base.gd:687-694` and `sight_cap.gd` are **two call sites computing
the same formula**, not two sources of truth — the tuning numbers stay singular because the helper
reads `EnemyBase`'s consts instead of copying them. The only thing actually duplicated is the
*shape* of the arithmetic (five lines), not the *values*. That is a tolerable, short-lived twin, not
a fossil — provided the bead handing EnemyBase the 2-line delegation (`return SightCap.compute(_grid,
global_position, at)`) is filed in the same commit and linked so it doesn't rot past `bd list`'s
50-row truncation. If that bead sits unclaimed and someone later hand-tunes
`SIGHT_CAP_JUNGLE` inside `sight_cap.gd` "for ally balance" without touching EnemyBase, THAT is the
moment it becomes a real fossil pair. Flag it, don't let it happen quietly.

## 2. Is 140m open-ground legitimate, or does it need a separate ally cap?

Legitimate — reject a fudge factor. Two supporting reads:

- The Fairness Law binds symmetry, not a ceiling. `_sight_cap` already lets an EnemyBase see the
  player up to 140m in open ground (gating `_update_perception`'s awareness gain, which is what the
  player already lives under during every current firefight). Capping the ally version below that
  would be the *actual* asymmetry — a player-side nerf disguised as a "balance" number, which is
  exactly the invented-multiplier drift the Pointer Law exists to catch. There is no ADR or pillar
  language that ceilings ally engagement range independent of the shared sight model.
- Allies never sit in RELAXED/SUSPICIOUS/ALERT — a targeted ally is always the behavioral analogue
  of an EnemyBase already in `AlertTier.COMBAT`, and EnemyBase's own combat-tier FOV is 360°
  (`_fov_deg()` line 726, `_:` case). So an ally acquiring omnidirectionally out to the *open-ground*
  sight cap is not a new capability — it is the same ceiling the player already contends with from
  the other side of the gun.

Do not add an ally-side multiplier under any name ("balance cap," "squad discipline range," etc.)
without a dated Arbiter ruling — that is precisely the kind of unpointered number ADR practice on
this project has already been burned by (the stale damage table, the fossil-count claim).

## 3. Downstream effects

**Perf — negligible, and better understood than it looks.** `_find_target()`'s loop over
`AgentRegistry.enemies` is a pure distance comparison per candidate today; swapping the constant
threshold for `SightCap.compute()` adds the same handful of float ops per candidate — no new
raycasts, no new physics queries. The only raycast in the ally think loop is the single
`_update_line_of_sight()` cast (line 490) for the *already-chosen* target, gated by `THINK_INTERVAL`
(6.7Hz) exactly as before — that call count does not change with acquisition radius, only the
`origin→target` ray gets longer in open ground, which is a cost EnemyBase already pays constantly at
the same 140m ceiling. `_grid.get_vegetation()` is called twice per candidate per think (self pos +
candidate pos) — cheap grid lookups, same cost class EnemyBase already carries in `_sight_cap` and
`_update_perception`. No pooling/allocation concerns.

**Behavior — the real thing to watch, not perf.** Allies in open rice-paddy terrain will now start
engaging contacts the player has not personally spotted yet, from well past their old 60m leash.
That is arguably a Pillar-4 win ("the squad is the RPG" — squadmates spotting for you reads as
competent soldiers) but it changes pacing: an ally opening up at 100m+ telegraphs an enemy position
to the player before the player has line of sight, which either (a) reads as good tactical support,
or (b) draws fire onto an exposed ally at a range the player can't yet support him at. That's a
game-designer/balance-reviewer call on `preferred_range` (12.0) and advance/retreat thresholds
staying sane at the new engagement envelope — not a blocker for this fix, but it should be played,
not just shipped and forgotten. Also note `weapon_data.max_range` on `m16a1.tres` needs to actually
reach 140m or the ally will "see" a target he then can't hit — worth a one-line check before playtest.

**No change to `weapons_free`/`_may_engage`** — that gate is orthogonal to acquisition and stays
exactly as strict as before; a weapons-tight ally now merely *notices* farther without being freed
to shoot any sooner.

## 4. What is sacrificed

- **Reliable close-support in bad weather.** A squadmate who used to backstop you at a flat 60m
  regardless of conditions can now go effectively blind at ~8-20m in night-monsoon jungle — same as
  an enemy would. Symmetric and pillar-correct, but it will *read* to the player as "my AI got
  worse," not "the weather got harder," unless the squad's own barks/behavior sell the degraded
  visibility (a UX note for the ux-designer, not a reason to soften the number).
- **Implementation purity, for one bead-cycle.** The ideal single-authority shape (EnemyBase
  delegates to the same helper it used to own outright) can't ship in this commit because of the
  ownership split — a short-lived, values-identical twin exists until the owning agent lands the
  2-line delegation. Named and bounded, not silent.
- **Any temptation to hand-tune ally range independently** is foreclosed on purpose — if playtesting
  later says 140m open-ground ally acquisition is too strong, that is a new Arbiter-blessed decision
  with a pointer, not a quiet multiplier slipped into `sight_cap.gd`.
