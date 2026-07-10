# RECONgame ADRs — the decisions of record

Ratified 2026-07-10 by War Room Full Game Audit #2 (six-architect council). Each ADR is law (CANON class,
see ADR-014): amended only by a new ADR or an explicit Summoner/War Room decision, never by drift.
Every citation was independently re-verified against source at writing time.

**Reading order for a new agent:** GAME_GUIDE.md first (`production/GAME_GUIDE.md`), then 014 → 015
(how docs and process work), then the system ADRs as needed.

| ADR | Title | Status note |
|---|---|---|
| [001](ADR-001-renderer-of-record.md) | Renderer of record: 3D PSX models; sprite matrix killed | beads 9xd/j8o closed |
| [002](ADR-002-character-scale-contract.md) | Character scale contract: 1.7132m + instance-space AABB | fix in DECREE#2-2 (mhfv) |
| [003](ADR-003-one-damage-grammar.md) | One damage grammar: RECON dice + locational overrides | dice core superseded by 016; locational model + one-grammar law survive |
| [004](ADR-004-ads-fov-policy.md) | ADS FOV policy: base 75, per-weapon ADS zoom | ratifies shipped code; amends old FOV-75 law |
| [005](ADR-005-detection-beacon-witness-rule.md) | Detection beacon + witnessed-contact rule | **NOT yet implemented** — DECREE#2-1 (pwu5) |
| [006](ADR-006-scoring-economy.md) | Mission scoring economy: avoidance pays | **NOT yet implemented** — DECREE#2-1 (pwu5) |
| [007](ADR-007-save-architecture.md) | Save architecture: tiers, slots, checkpoint economy | amendments in DECREE#2-3 (fy45) |
| [008](ADR-008-firebase-hub-spine.md) | Walkable firebase hub ratified — with conditions | conditions in DECREE#2-5 (4q4i) |
| [009](ADR-009-survival-v1-scope.md) | Survival v1 scope: hunger parked, condition kept | |
| [010](ADR-010-determinism-contract.md) | Per-mission determinism + MissionScope registry | |
| [011](ADR-011-fire-support-ladder.md) | Fire-support ladder: budgets, leash, danger-close | player-distance amendment pending |
| [012](ADR-012-input-doctrine.md) | Input doctrine: interact key, shared keys, squad orders | prompt fixes in DECREE#2-3 (fy45) |
| [013](ADR-013-world-streaming-policy.md) | World streaming policy: small maps load whole | fix in DECREE#2-2 (mhfv) |
| [014](ADR-014-doc-hierarchy.md) | Documentation hierarchy: CANON / LOG / DEAD | consolidation in DECREE#2-7 (e99w) |
| [015](ADR-015-verification-and-gate-law.md) | Verification law + mechanical gate | GATE epic = RECONgame-97u3 |
| [016](ADR-016-flat-damage-grammar.md) | Flat base damage × zone — the dice are retired | Summoner-decreed; shipped with probe `test_flat_damage` |

**Writing a new ADR:** next number, same template (Context / Decision / Consequences with the sacrifice
named / Evidence with verified file:line / Related). An ADR that changes a shipped behavior gets a bead.
