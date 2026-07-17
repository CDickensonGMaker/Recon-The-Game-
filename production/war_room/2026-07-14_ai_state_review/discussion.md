# War Room Debate — State of AI

## Agreements

- **Enemy AI is the most complete system.** The state machine, goal scoring, squad coordination, and perception layers are implemented and observable in Gore Lab.
- **Gore Lab is the correct foundation** for the AI Combat Stress Test Arena. It already has navmesh, cover, waves, debug labels, and vegetation.
- **Ally AI is shallow.** It follows orders and shoots but lacks squad-level tactics. This is acceptable for an arena v1 focused on enemy behavior.
- **Observability is good enough to start.** Debug labels show state/goal/target/cover/suppression; we can build metrics on top.

## Disagreements / Tradeoffs

**Devils-Advocate:** We should fix determinism (`randf()` in LOS) before building the arena, or metrics will be meaningless.
**Lead-Programmer:** Agreed it is P0, but the arena can still be built with deterministic RNG isolation at the test boundary. The arena itself does not need to wait on the engine fix.
**Systems-Designer:** The ally side is not ready for a "squad stress test." The arena should be scoped as enemy-tactical stress test + ally presence, not squad-AI validation.
**Game-Designer:** Scope v1 to enemy archetype behavior. Use it to tune courage/determination/suppression values. Ally depth comes later.
**UX-Designer:** Keep the existing debug labels and add a telemetry panel. Do not replace labels with a dashboard — players/readers need spatial context.

## Resolved Position

Build the AI Combat Stress Test Arena on Gore Lab, focused on enemy archetype behavior and state transitions. Keep allies present but secondary. Add telemetry and assertions. Fix the LOS determinism bug as a parallel gate, not a prerequisite, because the arena will expose it faster if it exists.
