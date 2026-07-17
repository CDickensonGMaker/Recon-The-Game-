# War Room Synthesis — AI Stress Arena Hand-off Review
**Date:** 2026-07-15 · **Declared project:** RECONgame · **Authority update:** `UPDATE_FROM_SUMMONER.md`

## The Decree

The Council confirms the seven unsolved problems in the 2026-07-14 arena hand-off. The Summoner has clarified that the arena is the **lens for the final shipping world** — fixes made here reflect directly into the campaign. The systemic disease is broader than one variable: the AI currently fights too accurately and too aggressively, and lacks survival/break-contact behavior. The firefight must become longer and more believable through **inaccurate suppression-first shooting, terrain that validates LOS/flanking, and AI that wants to live**.

### Binding decisions

1. **Arena = shipping firefight laboratory.** Work in `AIStressArena` is not throwaway probe work. It validates the core combat loop that the campaign will use.

2. **Telemetry is the first ship requirement.** No balance, suppression, or AI behavior bead closes without measurement. The arena must emit a 30-second summary log with: US/VC alive, US/VC kills, average suppression per side, average distance to target, rounds fired per side, time-in-suppressed-state per side, break-contact/retreat events, and round-end duration/winner.

3. **AI accuracy must be a tunable dial.**
   - Add a global/arena `ai_accuracy_mult` (or `ai_spread_mult`) that scales the existing `base_accuracy_modifier` / `accuracy_modifier` chain in `EnemyBase` and `AllyBase`.
   - Default to "Star Wars trooper" accuracy: AI misses a lot, especially at range and on fresh contact.
   - Lethality comes from volume of fire, exposure time, and flanking — never from aimbot precision.
   - The dial must be exposed in `AIStressArena` exports so the Summoner can tune it live.

4. **Survival and breaking contact are core AI behaviors.**
   - The existing RETREAT goal, `retreats_when_hurt`, courage/morale pressure, and `d_flanks` hooks must be tuned so both sides break contact under pressure.
   - The arena must demonstrate withdrawal: outnumbered or heavily suppressed agents should stop pushing and fall back to cover or off-map.
   - VC/NVA should value survival over kills; US should use bounding overwatch and medic rescue.

5. **Terrain must validate LOS/flanking/hiding.**
   - Cover and vegetation are not cosmetic — they prove the hiding/sight-line systems work.
   - The arena needs a central ridgeline/berm, tree-line strips, wrecked cover, and 3D vegetation that create clear "hidden" vs. "exposed" zones.
   - Entrenched AI facing the wrong way should not detect a flanking player until they are very close or make noise.

6. **Split the HP/damage knob and delete the old one.**
   - Replace `AIStressArena.hp_multiplier` with:
     - `ai_hp_multiplier`
     - `player_damage_multiplier`
     - `reserve_rate_multiplier`
   - Apply `ai_hp_multiplier` in `_finish_agent_setup()`.
   - Apply `player_damage_multiplier` to player-owned damage only.
   - Apply `reserve_rate_multiplier` to reinforcement interval and/or reserve counts.
   - Remove the `hp_multiplier` export and all references (ADR-023, Fossil Law).

7. **Keep arena tuning inside `AIStressArena`.** These levers must not leak into `SquadSystem`, `EnemyBase`, `AllyBase`, or campaign systems unless deliberately promoted later.

8. **Fix US model selection.** Add an arena-specific deterministic MOS→body mapping so the arena never spawns `us_grunt_v3` for a role-specific MOS. Verify `AllyBase.set_sprite()` rebuilds the model after spawn.

8. **Tune suppression and gibs after telemetry.** Use the 30s summary to measure suppression effect and break-contact frequency before changing thresholds. Gib tuning must verify new role-specific bodies still carry hidden gib donor meshes after `model_actor.gd` duplicate cleanup.

### Revised order of work

**Phase A — See the truth (prerequisite for everything)**
1. Add 30s telemetry summary log (alive, kills, suppression, distance, rounds, time-in-suppressed, retreats).

**Phase B — Make the arena look and fight like the real game**
2. Fix US model selection.
3. Rebuild arena environment: central ridge/berm, tree lines, wrecked cover, 3D vegetation, nav_source group.

**Phase C — Tune the firefight feel**
4. Add AI accuracy tunable dial (`ai_accuracy_mult`) and default it to stormtrooper-level inaccuracy.
5. Split/replace `hp_multiplier` with `ai_hp_multiplier`, `player_damage_multiplier`, `reserve_rate_multiplier`.
6. Tune survival/break-contact behavior: retreat thresholds, courage/morale pressure, suppression-driven withdrawal.
7. Tune suppression radius/decay and gib thresholds.

**Phase D — Human verification**
8. Summoner playtests. Bead 0623.2 closes on user-observed 3–5 minute run with telemetry showing survival/suppression rather than sponginess.

**Phase D — Verify**
8. Run end-to-end headless probe and close 0623.2.

### Beads
- **0623.6** (telemetry summary) — step 0; in progress. Blocks all tuning beads.
- **0623.3** (wrong models) — in progress. Small safe fix.
- **0623.4** (cover + vegetation) — environment rebuild; parallel with Phase B/C.
- **0623.5** (rebalance) — split HP/damage multipliers; blocked by 0623.6.
- **0623.7** (AI accuracy dial) — add `ai_accuracy_mult` tunable dial for `EnemyBase`/`AllyBase` spread.
- **0623.8** (AI break-contact) — tune survival/retreat/break-contact so both sides withdraw under pressure.
- **0623.9** (LOS terrain) — ensure terrain proves LOS/flanking/hiding (linked to 0623.4).
- **0623.2** (verify 3–5m fight) — closes on Summoner playtest, after 0623.3, 0623.4, 0623.5, 0623.7, 0623.8, 0623.9.
- **x1bs.1** (Blender re-export us_grunt_v3) — separate art debt; arena patch is a stop-gap.
- **ida9** (PLAYTEST R3) — arena probe work is exempt, but any AI/combat change that could leak into the campaign must be verified against the campaign path when ida9 is exercised.

### Tradeoffs named
- **Accuracy dial vs. hardcoded spread:** a global dial is easier to tune but can mask per-archetype identity if set too bluntly. The council recommends it multiply the existing `base_accuracy_modifier` so archetype differences survive.
- **Survival-first AI vs. kill race:** making AI break contact will reduce kill rates and may make the arena feel less "action-packed." This is the intended tradeoff — the game is not an arena shooter.
- **Terrain as validation vs. environment art:** the rebuild must prioritize readable cover/LOS over visual fidelity. Visual polish can follow once the systems prove themselves.
- **Velocity vs. measurement:** telemetry and behavior beads add upfront work, but without them tuning is guesswork (ADR-015 cost).
- **Arena patch vs. art re-export:** fixing model selection in code is faster than waiting for x1bs.1, but it is a band-aid; the real fix remains in Blender.

### Canonical design inputs
- `production/war_room/handoff_ai_stress_arena_2026-07-14.md`
- `production/war_room/2026-07-15_arena_handoff_review/UPDATE_FROM_SUMMONER.md`
- The Summoner's Combat AI Design Document (GOAP survival/combat architecture), pasted into this session.
- `production/war_room/synthesis_ai_goals.md` (AI GOAL DOCTRINE)
- `RECONgame-0623` (AI NORTH STAR: smart enemies)

### Unresolved technical question
Where exactly should `ai_accuracy_mult` live? Options:
- `AIStressArena` export only (arena-local).
- `EnemyData`/`AllyData` per-archetype multiplier plus an arena override.
- A new autoload or `CombatManager` global.

The council recommends an arena export that multiplies into the existing per-agent `base_accuracy_modifier`, keeping the campaign untouched. The Summoner can confirm or redirect.
