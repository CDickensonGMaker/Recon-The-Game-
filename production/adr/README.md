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
| [005](ADR-005-detection-beacon-witness-rule.md) | Detection beacon + witnessed-contact rule | **SHIPPED** — witness rule live (`enemy_base.gd` `_can_witness`/`_witness_check`; guard `tests/test_witness_rule.gd`) |
| [006](ADR-006-scoring-economy.md) | Mission scoring economy: avoidance pays | **SHIPPED** — scoring on the debrief screen (`scripts/ui/screens/debrief.gd`, per ADR-019) |
| [007](ADR-007-save-architecture.md) | Save architecture: tiers, slots, checkpoint economy | amendments in DECREE#2-3 (fy45) |
| [008](ADR-008-firebase-hub-spine.md) | Walkable firebase hub ratified — with conditions | conditions in DECREE#2-5 (4q4i) |
| [009](ADR-009-survival-v1-scope.md) | Survival v1 scope: hunger parked, condition kept | |
| [010](ADR-010-determinism-contract.md) | Per-mission determinism + MissionScope registry | |
| [011](ADR-011-fire-support-ladder.md) | Fire-support ladder: budgets, leash, danger-close | player-distance amendment pending |
| [012](ADR-012-input-doctrine.md) | Input doctrine: interact key, shared keys, squad orders | prompt fixes in DECREE#2-3 (fy45) |
| [013](ADR-013-world-streaming-policy.md) | World streaming policy: small maps load whole | fix in DECREE#2-2 (mhfv) |
| [014](ADR-014-doc-hierarchy.md) | Documentation hierarchy: CANON / LOG / DEAD | consolidation in DECREE#2-7 (e99w) |
| [017](ADR-017-persistent-province.md) | **The Persistent Province + the AO Window** | **THE LIVING WAR decree, 2026-07-12. Amends 008/010. The loop changed.** |
| [018](ADR-018-progression-rank-not-stats.md) | **Progression: rank gates AUTHORITY, never ABILITY** | **Player stats KILLED. Squad XP goes silent/behavioral.** |
| [019](ADR-019-hearts-and-minds.md) | **Hearts & Minds: allegiance drives VC manpower** | **The mechanical answer to "the war is the story."** |
| [020](ADR-020-authored-threshold.md) | **The Authored Threshold: guarantees, not rails + the Ambience Law** | **The test every set-piece must pass.** |
| [021](ADR-021-patrols.md) | **Patrols: routes that rotate, and the promotion that is the tutorial** | **Closes 0623 gap #1. Rank's flagship: FOLLOW -> LEAD.** |
| [022](ADR-022-the-map-is-your-memory.md) | **The map is the player's memory** | **You mark what you THINK, and may be WRONG.** + Amendment A (the intel verb; 4 nouns, area-circle, persist) **ACCEPTED 2026-07-25** |
| [015](ADR-015-verification-and-gate-law.md) | Verification law + mechanical gate | GATE epic = RECONgame-97u3 |
| [016](ADR-016-flat-damage-grammar.md) | Flat base damage × zone — the dice are retired | Summoner-decreed; shipped with probe `test_flat_damage` |
| [023](ADR-023-the-fossil-law.md) | **The Fossil Law: delete the old system when you replace it** | enforced by a ratcheting probe in the suite |
| [023-A](ADR-023-amendment-A-delete-the-callers.md) | **Amendment A: delete the system AND every caller** | **RATIFIED 2026-07-20** |
| [025](ADR-025-lod-tier-simulation.md) | LOD-tier world simulation (4 tiers) | **SUPERSEDED 2026-07-20** — never ratified; tier authority = `production/war_room/2026-07-18_ai_consolidation_plan/synthesis.md:12-16` |
| [026](ADR-026-ps2-graphics-budget.md) | **The PS2 Budget: graphics-only discipline, uncapped fighters** | **RATIFIED 2026-07-20** |
| [028](ADR-028-one-world-build-path.md) | One deterministic world-build path | phased; epic `x0r1` |
| [029](ADR-029-open-patrol-simulator.md) | **The open patrol simulator** | + amendments 008-006, B (world verbs), **C (the patrol contract) ACCEPTED 2026-07-25** |
| [030](ADR-030-hud-buffer-doctrine.md) | The period HUD buffer doctrine | **PROPOSED — DEFERRED to final polish (2026-07-25), non-blocking** |
| [031](ADR-031-destruction-doctrine.md) | **The Destruction Doctrine: state-swap, one blast bus, perf-gated terrain** | **ACCEPTED 2026-07-25** |
| [035](ADR-035-the-siege.md) | **The Siege: the night assault on the firebase** | **DRAFT rev.2 2026-07-28** — revised after War Room review; awaiting Summoner ratification. Amends ADR-020 (Ambience Law) and ADR-026 (light budget) |
| [036](ADR-036-the-fall-of-the-firebase.md) | **The Fall of the Firebase: objectives, respawn stake, lethality** | **DRAFT — BLOCKED 2026-07-28.** Summoner's rulings recorded; 9 dependencies do not exist (the firebase is one baked GLB node). Split out of ADR-035 rev.1 |
| [037](ADR-037-the-route-the-pencil-and-the-hunters.md) | **The route is an order, the pencil is yours, and the enemy hunts what you left** | **Accepted 2026-07-28.** *Was a second file numbered 035* — **renumbered to 037 on 2026-09-06**, closing a collision open since 2026-07-28 (AUDIT_2026-07-28 §P1, AUDIT_2026-08-06 X-1). Citations meaning the hunters/route (`DEMO_PERF_PLAN.md`, `DEMO_SHIP_BACKLOG.md`) were repointed; every surviving `ADR-035` reference means **the siege** |

| [038](ADR-038-the-firebase-factions.md) | **The Firebase Factions — four camps inside the wire, and the readout for Hearts & Minds** | **ACCEPTED 2026-09-06** (Summoner decree, THE RPG PIVOT). Amends ADR-019 §4. Demo ships **dressing only** — the readout is unbuildable until ADR-019's ledger exists, and may not be claimed. Carries the **imprecision law** (§2a) and the launch ruling on the racial element (§3a: placement ships, the verbal layer is cut) |
| [039](ADR-039-zones-not-streaming.md) | **Zones, not streaming — one builder, many places; you BOARD the bird, you never select it** | **ACCEPTED 2026-09-06 as canon; POST-DEMO, BUILD NOTHING.** Amends ADR-013 (map-size gate), ADR-017 §4 (load-mask claim corrected), ADR-028. Six enforceable clauses + a FROZEN FILES section |
| [040](ADR-040-the-down-state.md) | **Lethality is not negotiable — the DOWN state gets verbs, not the health pool more points** | **ACCEPTED 2026-09-06 as canon; POST-DEMO, BUILD NOTHING.** Reaffirms Pillar 1 and ADR-016 against a sympathetic attack. §4 records the Fairness-Law near-miss as **verified FIRING**, with one real hole |
| [006-B](ADR-006-amendment-B-the-score-is-re-hosted.md) | **Amendment B: the mission score is RE-HOSTED, not repealed. HQ is the faucet** | **ACCEPTED 2026-09-06.** The scalar dies, the sensor lives. *Body count may move HQ's WORDS; never HQ's GRANT* |
| [007-A](ADR-007-amendment-A-save-anywhere.md) | **Amendment A: save anywhere is POST-DEMO, and here is the bill** | **ACCEPTED 2026-09-06 as canon; BUILD NOTHING.** Six workstreams — the largest item in the decree. Both old save defects confirmed CLOSED |

**Deleted 2026-07-20 by the Summoner (never built against):** ADR-024 (cinematic direction),
ADR-027 (PS2 world design). A citation to either is drift — correct it on contact.

**Numbering collision CLOSED 2026-09-06:** two files were numbered ADR-035 from 2026-07-28 (flagged by
AUDIT_2026-07-28 §P1 and AUDIT_2026-08-06 X-1, unfixed for 40 days). The route/hunters ADR is now
**ADR-037**; every surviving `ADR-035` citation means **the siege**.

**Writing a new ADR:** next number, same template (Context / Decision / Consequences with the sacrifice
named / Evidence with verified file:line / Related). An ADR that changes a shipped behavior gets a bead.
