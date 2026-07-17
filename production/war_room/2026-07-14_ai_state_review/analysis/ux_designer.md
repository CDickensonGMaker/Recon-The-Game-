# UX Designer — AI Observability

## Existing Observability

- Gore Lab already renders debug labels above every enemy/ally: alert tier, state, goal, target, LOS, cover, suppression, exposure spread multiplier.
- It draws LOS lines (solid red = eyes on, faded orange = last known).
- `H` toggles hitzone wireframes.
- Top-right HUD shows wave, enemy count, squad count.

## Gaps

- No aggregate metrics: kill/death ratio by archetype, average time-to-first-shot, time-in-state histogram, cover-usage rate.
- No slow-motion or freeze-frame inspector.
- No way to force a state ("make this man suppressed") to verify transitions.
- Arena runs are not recorded; cannot replay an AI failure.

## Recommendation for Arena UX

Add a small telemetry panel (CanvasLayer) showing:
- Wave timer, alive count by archetype, average suppression.
- State histogram for current enemies.
- One-click buttons to force next wave, reset player, spawn specific archetype.

Keep the debug labels as the primary readability signal; they already solve the "what is this AI doing" problem.
