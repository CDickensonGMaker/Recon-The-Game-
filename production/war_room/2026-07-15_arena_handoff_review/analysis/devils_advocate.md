# Devil's Advocate Analysis — AI Stress Arena Hand-off Review

## Challenging the framing
The hand-off treats the arena as a broken 3–5 minute battle that must be fixed. Before the Council commits to 7 work items, here are the hard questions:

### 1. Is the 3–5 minute target right?
The arena is a *stress test*, not a player mission. A 1–2 minute probe that exercises combat states, suppression, and gib routing might be more useful for iteration. Fixing for 5 minutes could optimize the wrong thing. The Summoner should confirm the target or let telemetry decide.

### 2. Is `hp_multiplier` the real cause of sponginess?
The hand-off says VC have 210 HP. With ADR-016 Amendment D, M16 torso damage is 28 × 2.5 = 70. That is 3 torso hits to kill, not 8. The "8 chest hits" math in the hand-off uses the old TORSO ×2.0 multiplier. If Amendment D is live, the problem may already be smaller than described. Measure first.

### 3. Will more cover and vegetation hide AI bugs?
Adding LOS blockers will slow the fight, but it may also mask pathfinding/cover-selection bugs. If agents cannot path around a berm or palm cluster, the probe could look better while the underlying system remains broken.

### 4. Is fixing a dev arena a good use of time while ida9 is open?
PLAYTEST R3 (ida9) is the standing session entry gate and it is still open. Arena work exercises core systems, so it is not wasted, but the Council must be honest: this is not the campaign loop. Every hour spent on arena vegetation is an hour not spent on the hub/mission flow.

### 5. Model selection fix vs. re-export
We can patch `WEAPON_BODY_POOLS` to avoid `us_grunt_v3` in the arena, but bead x1bs.1 tracks the real fix: re-exporting the grunts to `_worn`-only. If the re-export is coming soon, the arena patch is throwaway work. If it is far off, the patch is justified.

### 6. Three knobs vs. one
More tunable variables increase the search space. Without telemetry and a target curve, we risk chasing our tails. The split is correct *if and only if* we also add measurement and commit to deleting the old path.

## What would make me wrong
- Telemetry showing the actual current TTK is still 8+ hits (then sponginess is real).
- A headless probe proving the arena crashes or errors without these fixes.
- The Summoner confirming the arena is a first-class deliverable, not just a probe.

## What I still agree with
The problems are real, the one-knob system is bad design, and telemetry must come first. My dissent is only about priority and target assumptions.
