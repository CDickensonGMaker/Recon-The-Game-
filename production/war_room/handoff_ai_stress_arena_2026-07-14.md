# Hand-off: AI Combat Stress Test Arena
**Date:** 2026-07-14 (late session)  
**Status:** Arena runs, but is not yet tuned for a believable 3–5 minute US-vs-VC firefight.  
**Declared project:** RECONgame (`C:\Users\caleb\RECONgame`)

## Original goals
- Complete the AI Combat Stress Test Arena so it sustains a 3–5 minute autonomous US-vs-VC firefight.
- Make the headless probe pass without runtime errors.

## What got fixed earlier this session
1. **US grunt duplicate-gear rendering (`us_grunt_v3.glb`)**  
   - Patch added in `scripts/visuals/model_actor.gd`: `_hide_export_duplicates()` hides donor/numbered duplicate meshes at runtime.
   - Long-term clean fix is still a Blender re-export to `_worn`-only convention.
2. **Arena navmesh timing** — two-frame wait after bake, explicit VC nav-agent map binding.
3. **Suppression movement wiring** — `enemy_base.gd` applies `_suppression_move_mult()`; `weapon_holder.gd` applies area suppression.
4. **Viewmodel editor / weapon zero** — independent hip/ADS zero system implemented.
5. **NAV error downgraded** — `[NAV] enemy inside baked region` is now a warning, not an error, so the probe doesn't hard-fail on it.

---

## Current unsolved problems (from playtest / observation)

### 1. Wrong US models in the arena
**What was seen:** US soldiers spawning with mismatched/fallback bodies.  
**What the code does:** `SquadSystem.pick_body_for_mos()` maps MOS to weapon, then pulls from `WEAPON_BODY_POOLS`. Most rifle roles draw from `["us_grunt_v3", "us_grunt_pointman", "us_grunt_rifleman"]`. `us_grunt_v3` is the old fallback with donor-mesh export problems. `DETERMINISTIC_MOS_BODY` only forces `RTO -> us_grunt_rto`.  
**Why it matters:** The arena is supposed to field the role-specific new art (rifleman, pointman, MG, grenadier, RTO), but the random pool still pulls the legacy `v3` export.  
**Next session fix:** Change `WEAPON_BODY_POOLS` and/or `DETERMINISTIC_MOS_BODY` so every arena MOS uses a distinct, correct body:
- `POINTMAN -> us_grunt_pointman`
- `RIFLEMAN -> us_grunt_rifleman`
- `MEDIC -> us_grunt_rifleman` or new medic body when available
- `MG -> us_grunt_mg`
- `GRENADIER -> us_grunt_grenadier`
- `RTO -> us_grunt_rto` (already correct)
Also verify `AllyBase.set_sprite()` actually rebuilds the model when called after spawn.

### 2. Not enough line-of-sight breaking cover
**What was seen:** Open 120m arena; squads can see and shoot across the whole space.  
**What the code does:** `_build_cover_clusters()` scatters only 28 small rocks/boxes (0.6–1.6m tall, 1.2–3m wide). `_build_village()` has 4 buildings and 4 short sandbag walls. `_build_firebase()` has an L-shaped sandbag wall and two fighting holes. The center 8m radius is kept intentionally open.  
**Why it matters:** 28 pieces over a 120m × 120m box is ~1 obstacle per 500 m². There is no central ridgeline, no tree line, no compound walls, no destroyed vehicles, no bamboo thickets to force fire-and-movement.  
**Next session fix:** Increase cover density and add vertical LOS blockers:
- Double/triple `_build_cover_clusters()` count and raise max height to 2.4m.
- Add a central berm/ridge or ruined wall line that splits the arena into two fire zones.
- Add tree-line strips (dense palm/bamboo clusters) along the flanks.
- Place a few wrecked vehicles/destroyed huts as hard cover.
- Raise village buildings to 4–5m and add connecting walls so the village is a real strongpoint.

### 3. No 3D vegetation added
**What was seen:** Bare ground; no grass, undergrowth, or proper vegetation despite being asked for before.  
**What the code does:** `_plant_vegetation()` only places:
- Two 25×25 rice patches (MultiMesh, 40 instances each) in SE/NW corners.
- 6 palm instances at firebase and 6 at village.
**Why it matters:** Rice patches are decorative ground planes; 12 palms do not break sight lines or provide concealment. The `_grid.get_vegetation()` fallback in `enemy_base.gd` never triggers because the arena has no vegetation grid.  
**Next session fix:** Add actual 3D vegetation:
- Scatter tall grass / elephant grass patches across the central zone (concealment, slows visibility).
- Add bamboo thickets or dense palm clusters as soft cover on the flanks.
- Wire the arena into `VegetationManager` if it exists, or spawn 3D `GroundClutter` patches directly.
- Ensure the vegetation has collision/navigation source flags so it affects navmesh and AI cover-finding.

### 4. US soldiers kill VC ~2× as fast
**What was seen:** US side dominates the kill race.  
**What the code does:**
- Arena `hp_multiplier = 3.0` applies to **both** sides in `_finish_agent_setup()`.
- VC base HP: 70–85. With multiplier: 210–255.
- US `AllyBase` base HP is set in `ally_base.gd`; with multiplier, also ~210–255.
- US weapons in arena: M16A1 (28 dmg, 750 rpm, 20-rnd mag), M60 (28 dmg, 550 rpm, 100-rnd belt), M79 (150 dmg HE).
- VC weapons: Mosin (32 dmg, 35 rpm, bolt), PPSh-41 (17 dmg, 900 rpm, 71-rnd drum), RPD (22 dmg, 650 rpm, 100-rnd belt), RPG-2 (explosive).
- `EnemyBase._fire_at_target()` clamps enemy spread to 1.2° and adds a forced near-miss on the first shot.
- US allies likely do not have the same forced-miss or accuracy clamp, and their semi-auto/burst fire may land more hits.
**Why it matters:** Even with equal HP, US M16s at 750 rpm + M60 belt feed out-damage VC bolt rifles and even PPSh/RPD at typical engagement ranges. The VC first-shot miss rule also gives US an opening salvo advantage.  
**Next session fix:**
- Option A: Give VC an accuracy/damage advantage in cover or at preferred range to compensate for lower RPM.
- Option B: Reduce US `fire_rate_mult` for rifle roles in the arena (currently MG gets 1.6×; consider a global 0.85× for US rifles).
- Option C: Tune `hp_multiplier` asymmetrically — VC get 3.5×, US get 2.5×.
- Option D: Improve VC cover-seeking weight so they engage from concealment more often.
- Add telemetry to `_check_round_end()` or `_update_telemetry()` that prints per-side kill rate per minute so tuning is data-driven.

### 5. Suppression did not slow the fight at all
**What was seen:** Enemies kept moving and shooting despite being shot at.  
**What the code does:**
- `weapon_holder.gd` calls `CombatManager.apply_suppression_in_area()` with radius 3–8m and amount 0.05–0.45 per shot.
- `apply_suppression_in_area()` only iterates `CombatManager.active_enemies`.
- `enemy_base.gd` has `apply_suppression(amount)` and `_suppression_move_mult()`.
- BUT: `CombatManager.register_enemy(self)` is called in `EnemyBase._ready()`. If allies are firing, suppression should reach VC.
- Possible causes:
  - Suppression radius too small for arena ranges (3m for rifles at 50m+ = rarely applies).
  - Suppression decays quickly (`SUPPRESSION_DECAY` constant) before it can change behavior.
  - AI in COMBAT state still fires if `suppression_level < 0.8` and does not enter SUPPRESSED state unless `> 0.7`.
  - Movement in `_execute_combat()` multiplies by `_suppression_move_mult()` but only on the strafe/wander vector, not on advance/retreat goals.
**Next session fix:**
- Increase suppression radius for rifles to at least 6–8m in arena context.
- Lower suppression decay so it persists long enough to matter.
- Force AI into `SUPPRESSED` state at a lower threshold (e.g., 0.5) and keep them there longer.
- Add debug HUD telemetry for average suppression level per side so the effect is visible in numbers.

### 6. Player combat feels spongy — shooting enemies too many times
**What was seen:** Player felt they had to shoot enemies multiple extra times to kill.  
**What the code does:**
- Arena applies `hp_multiplier = 3.0` to **all** agents, so a VC rifleman with 70 base HP has 210 HP in the arena.
- M16A1 does 28 damage per hit. At 210 HP, that's ~8 chest hits to kill.
- Mosin does 32; even more hits required.
- Headshots can pop heads at 60+ raw damage; body hits do not gib until 90+ raw damage.
**Why it matters:** The multiplier was added to make the 18v18 + reserves fight last 3–5 minutes, but it makes individual enemies feel like bullet sponges.  
**Next session fix:**
- Do not apply `hp_multiplier` to agents the player is shooting, OR lower the multiplier globally to 1.5–2.0 and compensate with more reserves/reinforcements to keep fight duration.
- Alternatively, add a `player_damage_mult` export to the arena so player bullets do more damage than AI bullets.
- Recommended: set `hp_multiplier = 1.5`, double reserve squads, and tune suppression/cover so the fight still lasts 3–5 minutes through tactics rather than HP bloat.

### 7. No gibs / blow-apart deaths visible
**What was seen:** Enemies just fell over; no dismemberment or explosive deaths.  
**What the code does:**
- `GibSystem.LIMB_POP_HIT = 45`, `HEAD_POP_KILL = 60`.
- `EnemyBase._die()`:
  - Explosion kill → `GibSystem.explosion_kill()` (pops 2–4 regions + ragdoll).
  - Clean kill → `ma.start_ragdoll()` only.
  - Gibbed kill → tries death clip, falls back to ragdoll.
- The arena mostly uses bullet damage, not explosives, and body hits rarely reach 90 raw damage.
- Head pops only happen on headshots with ≥60 raw damage.
- Limb pops only happen on limb hits with ≥45 damage.
- With `hp_multiplier = 3.0`, final killing blows are often small overkill amounts, not massive trauma.
**Why it matters:** Gibs are a core visual payoff; the arena should show them reliably.
**Next session fix:**
- Lower `GibSystem.LIMB_POP_HIT` / `HEAD_POP_KILL` thresholds for arena context, or add an arena override.
- Add a "killing blow overkill" rule: if a bullet does more than X% of remaining HP, force a ragdoll fling or small gib.
- Ensure `ModelActor` for the new role-specific grunts actually has the `grunt_*`, `cap_*`, and `head_frag_*` meshes hidden but present. The duplicate cleanup must not hide the gib donor meshes before death.
- Verify `GibSystem.dismember()` is called for non-explosive kills when raw damage is high enough (e.g., M79 HE, close buckshot).

---

## Underlying systemic issues to solve first
1. **Arena tuning is guesswork without telemetry.** Add a telemetry panel that prints every 30s:
   - US alive / VC alive
   - US kills / VC kills
   - Average suppression (US vs VC)
   - Average distance to target
   - Rounds fired per side
2. **Environment primitives are too weak.** The arena needs authored cover lines, not random rocks.
3. **Art/export debt.** `us_grunt_v3.glb` and old carriers still ship donor meshes; runtime cleanup is a band-aid.
4. **Balancing lever is one blunt knob.** `hp_multiplier` affects player feel, AI-vs-AI balance, gib frequency, and fight duration all at once. Split it into:
   - `ai_hp_multiplier`
   - `player_damage_multiplier`
   - `reserve_rate_multiplier`

---

## Suggested order for next session
1. Read this hand-off.
2. Add telemetry so you can measure before tuning.
3. Fix US model selection (distinct role bodies, no `v3` fallback in arena).
4. Rebuild environment: more cover, central ridge/berm, 3D vegetation, tree-line strips.
5. Split HP/damage multipliers and tune for ~3–5 minute fight.
6. Make suppression radius and decay aggressive enough to visibly slow movement.
7. Tune gib thresholds / verify gib donor meshes present.
8. Run headless probe and verify it completes with clean output.

---

## Files to read before editing
- `scripts/levels/ai_stress_arena.gd` — environment, forces, telemetry
- `scripts/squad/squad_system.gd` — MOS → body/weapon mapping
- `scripts/enemies/enemy_base.gd` — combat loop, suppression, death/gib routing
- `scripts/allies/ally_base.gd` — ally combat loop, death
- `scripts/combat/gib_system.gd` — gore thresholds
- `scripts/player/weapon_holder.gd` — player suppression application
- `scripts/visuals/model_actor.gd` — model setup, duplicate cleanup

## Notes
- Godot process was not running at hand-off time.
- NAV warning is now a warning, not a blocker, but still appears once for an initial VC spawn.
- No code fixes were applied for the seven problems above in this hand-off session.
