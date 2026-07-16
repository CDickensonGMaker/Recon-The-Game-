# War Room Briefing — Track C: AI Accuracy Unify + Firefight-Length Lever

## The query
The arena's US allies kill VC ~2:1. Damage was flattened even in wave 2 (all base guns 27),
so the remaining 2:1 is an ACCURACY/PERCEPTION asymmetry. Two jobs:
- **C1** — root-cause it, then unify BOTH sides onto ONE shared symmetric spread model with ONE
  tunable dial, so a mirror match trends ~1:1. Fossil Law: delete the superseded duplicate.
- **C2** — add a "Star Wars trooper" dial that WIDENS AI-vs-AI miss (longer firefights) WITHOUT
  touching AI-vs-player lethality (Fairness Law: first shot at unaware player is a near-miss;
  flash/tracers always telegraph).

## Confirmed mechanism (Arbiter's pre-read — code, not plan)
Both fire paths cap the cone at 1.2°, so steady-state cone WIDTH is ~symmetric. The 2:1 comes from
enemy-only handicaps that survive the cap:
1. **`aim_error`** — enemy_base.gd:1200-1204 builds a persistent ±(1-char_accuracy)*0.1 rad wobble
   (≈±1.7° at char_accuracy 0.7), added to aim at :1789 (`current_aim_dir + aim_error`). The enemy's
   capped 1.2° cone is thus centered up to ~1.7° OFF target. **Allies (ally_base.gd:741,
   `final_aim = current_aim_dir`) have NO aim_error — cone dead-centered.** Biggest driver.
2. **First-shot near-miss** — enemy_base.gd:1824-1831, guaranteed 5-9° miss on each new engagement.
   Allies: none.
3. **Exposure ramp** — enemy_base.gd:1795 `_exposure_spread_mult()` = up to 3× cone early; only bites
   for sub-cap guns (Mosin 0.6°, M70 0.4°). Allies: none.
4. **Two separate formulas** — enemy_base.gd:1791-1799 vs ally_base.gd:745-755 (different terms:
   enemy `*(2.0-char_accuracy)` + exposure + GameSettings.enemy_spread_mult; ally `*(1.6-skill*0.8)`
   + SquadRoster small_arms, which is inert in the arena — no roster → sa=0).
5. **Arena `base_accuracy_modifier *= 2.5`** — ai_stress_arena.gd:743, enemy-only. NOTE: this is a
   spread WIDENER (higher = worse aim; see enemy_base.gd:71 doc), so it's a one-sided enemy NERF,
   INERT at the 1.2° cap. **The plan's framing of 2.5× as an enemy advantage is BACKWARDS.**

## Constraints (binding)
- Pillars 1 (outstanding gunplay) + Fairness Law. ADR-016 damage untouched (wave 2 done).
- Fossil Law: extract shared model → DELETE the duplicated inline math. No two spread paths.
- Comment Discipline: constraints only, no history. Strict typed GDScript. ADR-015 probes.
- The Fairness terms (first-shot near-miss, exposure ramp) exist to protect the PLAYER. Question for
  the council: should they apply AI-vs-AI at all, or be gated player-only?
- ONE clearly-named dial Caleb can turn without breaking other systems.
