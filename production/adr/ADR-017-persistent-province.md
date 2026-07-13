# ADR-017: The Persistent Province and the AO Window
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Amends:** ADR-008 (hub is a separate scene), ADR-010 (determinism scope), GAME_GUIDE §3 (the loop), §4.6 (flat 2–4 objectives)

## Context

The shipped loop is a **lobby with legs**: `game_flow.gd:102-121` (`_teardown_world`) frees the world on
every transition, and hub and mission are two different world loads with two different seeds — the hub
builds with `world.mission_seed = op_seed` (`game_flow.gd:409-410`) while a mission builds with
`int(offer.world_seed)` (`game_flow.gd:228`). **Nothing exists between missions.** Mission 1 and mission
20 are the same mission; the offer labels the generator rolls ("ENEMY: HEAVY") are never read (bead ybf7).

The Summoner's fantasy (deep-dive 2026-07-12, `war_room/synthesis_living_war.md`) is a **PS2-era open
world**: you live in a province, patrol out of a firebase that runs its own day, and the VC live out
there whether you go or not. He explicitly rejected the alternative when offered it: *"i dont wanna a
super memorized map that i spent tons of time on crafting but its easy to 'beat'."*

Two architectures were on the table:
- **(A) One world, always resident.** True open world; the firebase sits in it and you never see a load.
- **(B) Persistent as DATA; the scene is rebuilt on demand.** The player cannot tell the difference — if
  and only if generation is bit-identical.

The project already has the prerequisite for (B): one seed per operation and a determinism contract
(ADR-010). (A) would re-open streaming (killed by ADR-013 for good reasons) and set the perf budget for
every other system on a project whose measured baseline was 19–25 FPS.

## Decision

**The province persists as DATA. The AO is a 1.5km window rendered into it, on demand.**

```
generate(province_seed)   -> the province: districts, villages, VC base sites, trails, the firebase
apply(province_ledger)    -> what the player did to it
render_window(district)   -> the ONE 1.5km AO actually walked in
```

1. **The province is a map, not a level.** Districts, villages, VC base sites, trail networks, firebase
   siting, regional VC manpower. It is small, saved, and it is the only thing that persists.
2. **The province is generated ONCE, at New Campaign, from a single `province_seed`, and never again.**
   **Random per campaign; fixed and learnable within it.** No memorization exploit across playthroughs;
   thirty hours of learning your own ground within one. (Learning the ground is half the fantasy, and it
   only works if the ground holds still while you learn it.)
3. **Only ONE AO window is ever in memory.** ADR-013 stands unamended: 1.5km ≤ 2km, so it loads whole.
4. **The firebase lives INSIDE the AO.** ADR-008's separate-hub-scene is amended away. A **PATROL** is a
   mission whose window contains the firebase: **you walk out the wire.** No load, no ride, no cutscene.
   The Huey ride remains — and remains the load mask — for windows elsewhere in the province.
5. **Mission length is geography, not a dial.** Objective count scales by type, amending GAME_GUIDE §4.6's
   flat 2–4:

   | Type | Window | Insertion | Objectives | Minutes |
   |---|---|---|---|---|
   | PATROL | contains the firebase | walk out the wire | 1–2 | 20–30 |
   | VILLAGE RAID | a few klicks out | ride or walk (player's call) | 2–3 | 30–45 |
   | AIR ASSAULT | across the province | Huey (the load mask) | 3–4 | 45–60 |

   Ratified target: **20–60 min average, player-paced** (Summoner: *"its really up to the player and how
   they play for that length"*).

### THE DETERMINISM BILL (binding — persistence is a LIE without it)

6. **World generation gets its own `RandomNumberGenerator`. It MUST NOT draw from the global RNG.**
   Known live leak: `game_flow.gd:184` seeds the *global* stream and `:198` immediately draws from it
   (`LOADING_TIPS[randi() % ...]`), advancing it before the world builds. Any generation reading global
   `randf()`/`randi()` is non-reproducible by construction.
7. **Every persistable world object carries a deterministic generator index** — `district/kind/n`, derived
   from generation order, never a node name or a position hash. Get this wrong and the player returns to
   find the wrong hut burned.
8. **GATE (ADR-015 verification law):** a probe generates the province twice from one seed, hashes every
   object's `(id, type, transform)`, and asserts identical. **If that probe is not green, the province does
   not ship.** "Looks the same" does not close this.

### The ledger

9. `ProvinceState` (saved, versioned — see Consequences) holds: per-district VC strength and manpower, per-
   village allegiance (ADR-019), destroyed/rebuilt world objects, caches found, AA threat, calendar day.
10. **Destruction is TEMPORARY; attrition is PERMANENT** (ADR-019 owns the economics). Bases, bunkers,
    caches and tunnel mouths **rebuild or relocate**. A province whose destruction is permanent sterilizes
    itself into a checklist — the seek-and-destroy treadmill this design exists to avoid.

## Consequences

**Bought:** the whole open-world fantasy at a fraction of the engineering — the player cannot distinguish
"stayed resident" from "rebuilt exactly." Walking out the wire on patrol (the most evocative mission type
the Summoner named) becomes nearly free, because the hub, the world, and the Huey ride are all already
built. The campaign stops being flat (bead ybf7) because the province is now a thing that *changes*.
Only one 1.5km world is ever resident, so ADR-013 survives and the perf envelope does not move.

**Sacrificed (no free lunches):**
- **You cannot walk 10km without a load.** Crossing the province means the board at HQ and a ride. The
  seamless-Arma dream is formally deferred; re-opening it means re-opening streaming, which means paying
  ADR-013's threading bill first.
- **The firebase is now inside a live 1.5km world's perf budget.** It used to be cheap and alone. It is not
  anymore, and the 24/7 ambience (ADR-020 / the Ambience Law) will be priced against a jungle AO.
- **Determinism becomes load-bearing rather than aspirational.** It will find bugs, and they will be the
  worst kind — a province that comes back *subtly* wrong ("wasn't there a tree here?") is worse than no
  province at all. The two-generation hash probe is not optional and not cheap.
- **The save format breaks.** SaveData grows a province (ADR-007). The migration path is currently a live
  no-op (bead z90e); this decree forces it to become real.

**Work created:** determinism probe (the gate) · world-gen RNG isolation · stable generator-indexed object
IDs · `ProvinceState` + save migration · firebase-into-AO · patrol-out-the-wire insertion path · objective
count by mission type. Beaded under the LIVING WAR epic.

## Evidence

Verified against source 2026-07-12:
- `scripts/main/game_flow.gd:102-121` — `_teardown_world()` frees the world on every transition
- `scripts/main/game_flow.gd:409-410` vs `:228` — hub and mission build from **different seeds**
- `scripts/main/game_flow.gd:184, 198` — global `seed()` then a global `randi()` draw before world build
  (**the determinism leak**)
- `scripts/main/game_flow.gd:242-280` — the mission build path; `plan.start_pad` gates the Huey ride
- `scripts/levels/world_config.gd:7-11` — `MAP_SIZE=1280` (≤2km ⇒ ADR-013 loads whole)
- Beads: **ybf7** (campaign is flat), **z90e** (save migration is a no-op)
- Decree: `production/war_room/synthesis_living_war.md` §2

## Related

- **ADR-008** — amended: the hub is no longer a separate scene/seed; it is a place in the province
- **ADR-010** — strengthened: determinism moves from "generation and spawn" to "the world itself, forever"
- **ADR-013** — survives intact: one 1.5km window ⇒ still no streaming
- **ADR-007** — forced: the save format must actually migrate now
- **ADR-019** (hearts & minds) — the ledger's most important column
- Pillars served: **3. Freedom** (an open province, no rails), **2. Atmosphere** (a world that remembers),
  **5. Fail forward** (what you did is still there when you come back)
