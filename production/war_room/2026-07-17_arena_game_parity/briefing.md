# BRIEFING — ARENA→GAME PARITY, DESTRUCTIBLE TREES, FPS BUDGET

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Summoner mission (via coordinator):**

> GOAL: get the actual GAME on the same page as the AI stress arena.
> 1. PARITY — port the arena's AI stack (patrol/ambush/camp/squad-leader directors, veg
>    cover/concealment, crouch locomotion) + 3D vegetation into the real game scenes.
> 2. DESTRUCTIBLE TERRAIN WITH THE TREES — trees shootable/blowable/knock-down, integrated with the
>    existing terrain damage_system. Headline feature for today.
> 3. SMOOTH FPS — hold the frame budget. Measure-first (ps2_perf_probe / bench). No windowed Godot on
>    the desktop.

## CONSTRAINTS THIS COUNCIL IS BOUND BY (canon, already read)

- **PERF FLOOR IS MEASURED AND BAD (MORNING_SUMMARY 2026-07-16/17).** Night arena, real content:
  **18.8 fps native Forward+ / 25.5 native Mobile**; shipped 0.75/mode5: 22.3 / 29.9. **Nothing clears
  30 in the night arena.** Noise floor ±3.3 fps.
- **THE JUNGLE IS 71% OF FRAME GEOMETRY** — one toggle drops −12.26 ms GPU and −572,438 primitives.
  The single biggest cost on the board, tied only by the sun shadow (−12.17 ms, but ADR-026 deliberate).
- **Prior "cheap wins" are WITHDRAWN.** lights (−5 ms), characters (−3.3 ms), grass (−1.4 ms) attributions
  were all killed by a control run — inside the noise. "Grass is free / lights are the next win" is NOT
  established. Measure-first is not optional; the last agent that trusted an unproven number shipped a
  lie five times in one night.
- **THE_PLAN's pre-committed FPS ladder (Summoner-framed):** ≥45 native → ship jungle features · 30–44 →
  trunk colliders ship, measure AI-path cost first · **20–29 → JUNGLE FEATURE FREEZE, all jungle work
  subtractive** · <20 → plan void, perf is the only project. **We are measured at 18.8 native / 25.5
  Mobile — i.e. at or below the freeze line.**
- **THE_PLAN, verbatim:** *"DESTRUCTION (the fall) IS NOT IN THIS PLAN. Cut by the 07-12 council; stays
  cut. Cover is the pillar; destruction is the luxury."* Bead `eaqv`: *"ship the COVER, defer the
  DESTRUCTION."* Bead `2v3t`/step-10: trunk colliders = a 32,000-node hazard, and *"the answer is still
  not yet: the jungle is already 71% of the frame's geometry."*
- **ADR-023 fossil law + Amendment A (draft):** deleting/replacing a system deletes its callers too.
- **ADR-025 (LOD-tier sim, DRAFT):** the arena AI directors (world_sim/sim_clock/convoy/ambush) are
  *built ahead of wiring* — parity wiring is partly the Phase-1/2 work this ADR already scoped.
- **GATE (97u3):** bug/test/doc/presentation-for-shipped work is exempt; feature epics blocked while
  playtest P1s open. Parity wiring of already-built systems is closer to integration than new-feature.

## THE CENTRAL TENSION (the fork this council exists to surface)

Missions 2 (destructible trees) and 3 (smooth FPS) are in **direct, measured contradiction** on today's
numbers. We are in the FEATURE-FREEZE band of the Summoner's own pre-committed ladder, the jungle is
already the frame's bomb, and destruction was explicitly cut and kept cut by two prior councils.
Building individually-destructible trees today spends frame budget we do not have, on the one system
already eating the frame, against a standing pre-commit. **This is not a routine call — it is a Summoner
bless.** The council's job: deliver the parity win (safe, valuable, mostly integration of built code),
design the destructible-tree approach honestly so it is *ready* when the budget exists, and name exactly
what must be true (an FPS number) before a single destructible tree ships.

## LENSES SUMMONED
- **lead-programmer / systems** — the arena↔game code delta and the integration surfaces (recon).
- **technical-director** — veg instancing, the damage_system, destructible feasibility, FPS levers (recon).
- **game-designer** — does parity serve the pillars; is destruction worth the frame at all.
- **devil's-advocate** — the ladder-vs-headline contradiction; what parity breaks; the 32k-node trap.
