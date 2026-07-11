# WAR ROOM BRIEFING — AI GOALS & BEHAVIOR DOCTRINE, both factions (2026-07-10)

## The Summoner's verdict from the live combat bench (verbatim intent)
"Combat feels fun and fast" — keep that. But:
1. **Squad overuses the STRAFE animation** — "running or aiming and moving should be the go-to."
2. **Enemy model rotation is off a lot** — they visibly face the wrong way from where they look/shoot.
3. **His squad seeks cover more than anything else** — "a classic staple of AI problems."
4. **The core ask:** "work more on the goals of the AI... combat has to feel real but also SMOOTH.
   We can't have models constantly switching their goal because the LOS changed with enemies."
5. Bench observation: wave 2 spawns in the wide open (spawn placement not cover-adjacent; room size).
6. **Round start: the whole squad bunched into ONE corner of cover — "since it was the closest."**
   The cover search optimizes purely for distance; the claim broker only blocks the same 2m cell, so
   five men stack in adjacent cells of one corner. The doctrine needs cover DISPERSION (spacing
   between claimed points, per-man sectors, or a crowding penalty in candidate scoring).

## What this council decides
A unified GOAL/BEHAVIOR DOCTRINE for BOTH EnemyBase and AllyBase: how a soldier COMMITS to a plan
(dwell times, interrupts, hysteresis), how LOS flicker is debounced, when cover-seeking is allowed to
preempt fighting, and how goals map to animations and facing. Real + smooth. Deliver concrete
formulas/values, not vibes.

## Code ground truth (verify at these sites)
- `scripts/enemies/enemy_base.gd` — `_evaluate_goals()` (~:800+): 0.5s goal_timer + 15% incumbent
  hysteresis + cover-first doctrine (`_contact_time`, `_cover_fail_count`), exposure ramp
  (`_exposure_spread_mult`, LOS-loss drains at 3x), honest attention (`_target_score`, 2s retarget),
  bounding ADVANCE, EnemySquad brokers (covering fire, engagement census, grenades).
- `scripts/allies/ally_base.gd` — SIMPLER brain: `_evaluate_goals()` = 3 branches (suppressed->cover,
  contact(<6s seen)->cover-first-then-combat, else follow). NO dwell time, NO hysteresis: candidate
  cause of the ally cover obsession + thrash. Cover system newly grafted (same claim broker as enemies,
  `_execute_seeking_cover`, leap/hold/peek anim overrides `_anim_override`). Aim-settle 0.45-0.9s.
  Formation slots `_follow_offset`.
- `scripts/visuals/sprite_state_map.gd` — `intent_for(state, ..., firing, speed)` collapses AI state to
  an intent string; `MODEL_CLIP` maps intent->clip; `MODEL_ALIASES` bridges v1/v2 clip generations.
  SUSPECT for #1: which intents fire while moving in COMBAT ("strafe" vs "run"/"aim")?
- `scripts/visuals/model_actor.gd` — `set_facing(dir)`: `rotation.y = atan2(facing.x, facing.z)` for a
  model authored facing -Z. SUSPECT for #2: verify the convention (is this 180° off? who calls
  set_facing with what — aim dir vs velocity? enemy `_update_sprite` equivalent at enemy_base ~:330-344).
- Lab: `scripts/levels/gore_lab.gd` `_spawn_wave` (random open positions z -19..-12) — #5.

## Constraints
- Pillars 1 (gunplay) + Fairness Law (exposure ramp, telegraphs) are law (ADR canon).
- Perf: think 6.7Hz LOD'd; no new per-frame raycasts. Changes stay in enemy_base/ally_base/
  sprite_state_map/model_actor + lab spawn code.
- The doctrine must produce: cover used WELL (not obsessively), visible maneuver (bounds, flanks),
  commitment (a man finishes his rush; goals persist seconds), smooth animation reads (run/aim-walk
  dominant, strafe rare), correct facing.

## Deliverable per architect -> production/war_room/analysis_ai/<role>.md
(a) diagnosis of each Summoner item with file:line evidence; (b) the doctrine piece you own with
CONCRETE formulas/values; (c) what you'd cut/simplify; (d) risks. Compact return summary for the Arbiter.
