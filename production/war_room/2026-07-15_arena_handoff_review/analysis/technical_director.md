# Technical Director Analysis — AI Stress Arena Hand-off Review

## Risk assessment by fix area

### 1. US model selection (low risk)
Change `SquadSystem.WEAPON_BODY_POOLS` and/or `DETERMINISTIC_MOS_BODY` so the arena uses deterministic role bodies. Best path: add an arena-specific body lookup or pass an explicit body name from `_spawn_us_squad()` instead of relying on the campaign `pick_body_for_mos()` random pool.

**Watch point:** `AllyBase.set_sprite()` must actually rebuild the model when called after spawn. Verify it calls `_setup_visual()` or equivalent and does not cache the first body.

### 2. Telemetry (low risk)
Extend `_update_telemetry()` to print every 30s and/or write to stdout. No external dependencies. Must not spam the log in headless mode.

### 3. Environment: cover + vegetation (medium risk)
- Navmesh uses `nav_source` group; new cover must add itself to that group.
- Vegetation with collision must also be nav sources or the navmesh will carve around them.
- Central ridge/berm must not block all sight lines (keep 8m radius open per existing design).
- More geometry = more draw calls; this is a probe scene, but watch FPS.

### 4. HP/damage split (low/medium risk)
- Rename/remove `hp_multiplier` export.
- Update `_finish_agent_setup()` to use `ai_hp_multiplier`.
- Player damage multiplier needs a clean injection point in `weapon_holder.gd` or `projectile_base.gd` that applies only to player-owned damage.
- Do not break the campaign path; campaign agents should never see arena multipliers.

### 5. Suppression (medium/high risk)
- `weapon_holder.gd` calls `CombatManager.apply_suppression_in_area()` with radius 3–8m.
- `enemy_base.gd` has `apply_suppression()`, `_suppression_move_mult()`, and state thresholds.
- Changes affect AI state machine; need a probe measuring time spent in SUPPRESSED state and average suppression per side.

### 6. Gibs (low risk)
- `GibSystem.LIMB_POP_HIT` / `HEAD_POP_KILL` thresholds are constants.
- Verify new role-specific bodies still carry hidden `grunt_*`, `cap_*`, `head_frag_*` meshes after `model_actor.gd` duplicate cleanup.
- M79 / buckshot already reach thresholds; rifle body hits do not. Lowering thresholds for arena context is acceptable if it stays within ADR-016 (deterministic, no randomness).

## Verification gates (ADR-015)
After every change block, run:
```
godot --headless --path . --quit-after 300
```
Grep output for `SCRIPT ERROR`. Any red line is a hard failure.

## Recommendation
Start with telemetry + model selection (low risk, builds confidence). Then environment, then balance/suppression in small, measured iterations.
