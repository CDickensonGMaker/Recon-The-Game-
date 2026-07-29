# DECREE — World-sim group sizes

**Date:** 2026-07-28 · **Status:** Summoner's numbers, measured against live code
**Summoner, verbatim:**

> *"convoys of vehicles roll in groups of 3 to 6, heuys fly in packs of 6 to 9 and jets fly in groups of
> 3 to 5 for the world sim. the villagers travel in packs of 3 to 6 on their routes between villages."*

---

## The four numbers vs. what the code does today

| Thing | Ordered | Today | Pointer |
|---|---|---|---|
| Convoy vehicles | **3–6** | **exactly 3, hardcoded** — two deuces and a gun jeep, every time | `mission_generator.gd:341-342` |
| Huey flights | **6–9** | **2–3**, and only 35% of the time — most Hueys fly SOLO | `air_traffic.gd:31-32` |
| Jet flights | **3–5** | **always 1.** `f4` and `skyhawk` are not in `FORMATION_SIZES`, and the contract says *"everything unlisted always transit solo"* | `air_traffic.gd:29-31` |
| Villager parties | **3–6** | **2–3**, and pairs off the remainder | `mission_generator.gd:841` |

Every one of the four is currently below the order. Jets have **never** flown in a group.

## What each change actually requires

**Convoys** — the model list is a literal. It needs a seeded roll of 3–6 with a composition rule
(a convoy is not six identical deuces; it wants a lead gun jeep, trucks, maybe a tail gun truck).
Model basenames must resolve to real `.glb` files under `ConvoySpawner.VEHICLE_MODEL_DIR` — asserted by
`tests/test_roads.gd`, so a typo turns the suite red rather than failing silently.

**Hueys** — two separate values, and only changing one gives the wrong result:
`FORMATION_SIZES["huey"] = [6, 9]` sets the pack size, but `FORMATION_CHANCE = 0.35` still means
two thirds of flights are a lone ship. "Hueys fly in packs" reads as *packs are the norm*, so the
chance wants to go up with the size. **Flagged for the Summoner: 0.35 → ?**

**Jets** — `f4` and `skyhawk` must be ADDED to `FORMATION_SIZES` at `[3, 5]`. Open question:
`skyraider` is currently `[2, 2]`, but an A-1 Skyraider is a prop, not a jet. Left at `[2, 2]` unless
ruled otherwise — the order said "jets."

**Villagers** — `mission_generator.gd:840-853` walks the civilian list forming parties. Two things break
if the range simply changes to 3–6: the loop guard is `>= 2`, and the remainder logic pairs leftovers.
It also needs enough civilians per village to form a party of 6 at all, or villages quietly fall back to
smaller groups and the number is a lie.

## The cost, named

**Huey 6–9 is the expensive one and must be MEASURED, not assumed.** Going from a typical 1 ship to
6–9 is up to a 9× multiplier on rotor meshes, animation and audio sources per flight, and FPS is this
project's top systemic risk (Forward+ decree, PS2-budget wave). A pack of nine over the firebase at
dawn is exactly the shot that sells the game and exactly the shot that tanks the frame.

Gate it: build it, then measure with the existing perf instrumentation before it counts as shipped.
If it costs too much, the honest lever is fewer concurrent FLIGHTS, not smaller packs — the pack size
is the thing the Summoner actually asked for.

**Jets 3–5 is cheap** by comparison: fixed-wing at 200–250 m/s crosses a 1,280 m AO in ~6 seconds.

## TUNE (Summoner)

- Huey `FORMATION_CHANCE`, currently 0.35 —
- Does `skyraider` count as a jet for the 3–5 rule —
- Convoy composition (what mix of jeeps/trucks/gun trucks) —
- Minimum civilians per village needed to guarantee a 6-party —
