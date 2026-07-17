# Game Designer Analysis — AI Stress Arena Hand-off Review

## What the arena is for
The AI Stress Arena is a dev/probe environment that must sustain a believable 3–5 minute autonomous US-vs-VC firefight. Its job is to validate the core combat loop (AI state machine, suppression, cover-seeking, reinforcement pacing, gib/die presentation) outside the campaign generation noise.

## Verdict on the 7 problems
All 7 problems are real and worth fixing, but they are not equal:
- **P0 (Pillar 1 blockers):** player sponginess (#6) and US 2× kill rate (#4). These violate "death comes from situation, never bullet sponges."
- **P1 (presentation/blockers):** wrong models (#1) — hurts Pillar 2/Atmosphere and makes the arena look like a test scene, not a battle.
- **P1 (environment):** cover (#2) and vegetation (#3) — these are the *situation* the pillar demands; without them, firefights devolve into open-field DPS races.
- **P1 (systems):** suppression (#5) and gibs (#7) — both are payoff systems that must read clearly to the player.

## On splitting `hp_multiplier`
The hand-off is correct: one blunt knob controlling AI-vs-AI balance, player feel, gib frequency, and fight duration is a design failure. The proposed three-knob split is the smallest systemic fix that separates concerns:
- `ai_hp_multiplier` — how long the AI-vs-AI fight lasts.
- `player_damage_multiplier` — how the player's gun feels against the same enemies.
- `reserve_rate_multiplier` — how reinforcements pace the overall battle.

**Tradeoff:** more tunable levers also means more ways to tune badly. Telemetry is non-negotiable before any knob is moved. Without it, we are swapping one guess for three guesses.

## Recommended priority
1. Telemetry first (we cannot judge balance without measurement).
2. Player damage feel and model selection (low-risk, high-pillar impact).
3. Cover and vegetation (environment = situation).
4. Suppression and gib tuning (payoff systems, verified by telemetry).
5. End-to-end 3–5 minute probe gate.

## Open question for the Summoner
Is the 3–5 minute target sacred, or would a faster 1–2 minute probe be more useful for iteration? My recommendation is to keep 3–5 minutes for now because it matches the target mission engagement cadence, but measure first.
