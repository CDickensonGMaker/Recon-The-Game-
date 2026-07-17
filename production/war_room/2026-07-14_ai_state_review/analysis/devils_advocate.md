# Devil's Advocate — What Is Not Working

1. **Determinism is broken today.** `CombatManager.has_line_of_sight` calls `randf()` every frame. The entire AI perception and accuracy system is therefore non-deterministic. Any arena metrics will drift between runs until bead `RECONgame-atov` is fixed.

2. **Navigation is two systems pretending to be one.** Outside the lab, EnemyBase uses `NavBaker` box indexes but still steers directly. Inside the lab, `NavigationAgent3D` and `lab_navmesh` work. The arena will only be valid if it uses the lab path.

3. **Allies are not really squad AI.** They are individual shooters with orders. Calling the stress test a "squad AI" test risks false confidence. The arena should label what it actually tests: enemy tactical AI + allied individual AI.

4. **Cover is fake.** There is no raycast validation that a claimed cover position actually blocks LOS. Men can "take cover" behind thin air.

5. **Gore Lab is a shooting gallery, not a stress test.** Waves spawn predictably north, cover is randomly scattered, and there is no fail/pass condition. The new arena needs designed scenarios, not just more waves.

6. **No saved replays or assertions.** Without automated checks, the arena becomes a place to watch AI, not to catch regressions.

## Tradeoff We Must Name

A quick "Gore Lab + squad + metrics" arena can ship fast but will paper over the determinism and navigation blockers. A rigorous arena requires fixing those first. The Council must decide which gate the arena is meant to validate.
