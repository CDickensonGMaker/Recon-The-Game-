# SYNTHESIS — Tet / Hue / Operations (Arbiter's weave, 2026-08-18)

Session type: OPTIONS BOARD for the Summoner's talk, not a decree. Four analyses in
`analysis/`. Remarkable convergence; conflicts named below. No pillar is violated by the
recommended stack; two knowing amendments are required (7/28 fiction clause, ADR-028 one
clause, ADR-029 the amendment 7/28 already owes).

## Where all four voices converged

1. **The dial: "historical weather, fictional ground" (detent B).** It IS January 1968,
   the truce IS broken, Tet IS real, Hue burns on the radio 30 klicks away — but the
   player's firebase, unit, AO, and any walkable city are OURS (invented, seeded).
   Writer: the Men of Valor / Platoon register; the seeded tour survives because the
   offensive is the shared clock while the AO stays the private map. Devil's advocate
   adds the clincher: real Hue was a Marine/ARVN fight and our locked faction is Army —
   going historical-playable breaks faction coherence AND reopens real-dead taste ground
   the 7/28 decree deliberately closed. Fold-in C+: REAL operation names as radio
   wallpaper (umbrella ops) — free period smell. The line: any space the player shoots
   in stays fictional. Amendment required: 7/28's "no real dates" becomes "no real
   ground or dead"; dates are in.
2. **Maps: authored manifests through the ONE WorldBuilder, seeded dressing.** Systems
   found the lock is narrower than feared: plan_demo_world is ALREADY a hand-authored
   map as data through the same stamp pass (mission_generator.gd:697-874;
   game_flow.gd:627-629 is the only fork). Ops maps = authored plan + authored heightmap
   input + authored scene stamps (firebase_main precedent), with seeded dressing and
   map-seed split from force-seed so one authored map replays. Full hand-built .tscn
   maps are the parallel-world bug class that sank Catacombs — off the table. This
   honors the Summoner's "handcrafted consistent maps" as authored GEOGRAPHY, while the
   engine keeps one build path. Cost collapses from 20-32 art-days per city map to a
   reusable urban kit (~8-12 amortized).
3. **Rhythm: ordered-but-porous (R3).** The radio assigns ops with lead time; missing
   the bird is legal; the op happens without you and the world/ledger remembers.
   Orders deliver the soldier fantasy; consequences replace rails.
4. **Tet as THE CLOCK (T2 on a campaign_phase machine, 3B).** Campaign opens early
   January. PRE_TET: patrol intel (caches, documents, prisoners) foreshadows — bodies-
   give-intel finally load-bearing at campaign scale; the countryside goes eerily quiet;
   firecracker truce jams the player's threat-parsing ear (writer's five-act arc). THE
   NIGHT: everything erupts at once INCLUDING the home firebase's own siege — the demo's
   polished 30 minutes recontextualized as the campaign centerpiece (T5). EBB: February
   counteroffensive opens the operations faucet. Implementation: phase machine over
   SimClock.sim_day driving threat modifiers, siege chance/strength, ambient caps, air
   sortie rate — recoloring systems that exist.
5. **Helicopter: scripted ride, loading-hidden swap.** Real boarding/liftoff at home
   (SeatSystem/HeliLift/AirTraffic + six verified disembark clips exist), WarFacts
   screen mid-flight, real approach/landing into the op world. Postcard ride in +
   MIRROR ride home (extraction replays the inbound view transformed — the ledger as a
   view out a door). Hot-LZ divert regenerates approach freedom inside authored maps.
   Seamless streaming flight: off the table (ADR-028 residency). Door gunner: later
   showpiece.
6. **City fighting: single-story, rubble-heavy, sized under the 50-cap.** Block islands
   + street graph (RoadNetwork), defenders hold interiors / player clears, destructible
   breach-rebake is the system's best consumer. Sacrificed and named: upper-floor
   snipers, indoor maneuver AI. City clearing is the crown jewel and headline of a
   later update — never the first op built.
7. **Op menu, cost-tiered** (game_designer.md full table): CHEAP near-pure reuse — LZ
   hold, seek-and-destroy, bridge/canal, night ambush. MEDIUM — heli assault on camp,
   firebase construction, relief-of-surrounded-unit, counterattack recapture. EXPENSIVE
   (each carries an unproven system) — city block clearing, MEDCAP-gone-wrong, convoy
   escort, casevac litter run.

## Conflicts the Summoner should rule on

- **T2 clock vs T3 systemic surge:** a dated event is a soft rail inside a sandbox.
  Game-designer accepts the rail for the drama; purist alternative keeps Tet undated.
- **Vibe seam:** COD staging on the ride IN, HLL weight once boots touch ground. The
  four references silently import four unbuilt systems (rails, tickets/vehicles, VO
  layer, allied-AI-in-buildings — the hardest). The minimum honest version needs none.

## Drift guardrails (write into the ADR-029 amendment as prohibitions)

No objective marker/tracker in an op · no success/fail screen apart from ledger/AAR ·
no browsable ops board/menu · patrol AO never becomes a lobby · no op-chain unlocks.
An operation is a place-in-time: missable, walk-away-able, scored only by the ledger.

## Sequencing (Law: nothing pulls from the EA ship list; EA is ~19 days out)

Preconditions: demo ships · siege replay checklist · PLAYTEST R4 discharged (ops are a
second floor on an unwalked first floor) · gating FPS number set before city design.
**Cheapest probe, all four voices endorse: "THE RIDE-OUT"** — Huey lift from the home
pad to a seeded enemy camp inside the EXISTING AO, siege-shape fight, ride home. Zero
new art, code-only. It referees the whole direction: fun on random ground → handcrafting
is polish; not fun → no month of city art saves it.

## Sacrifices named (Law 2)

Authored op geography sacrifices per-op map surprise (recovered partly by force-seed
split). Detent B withholds the Citadel postcard battle. R3 porousness must be honestly
simulated or it is fake. T2's date is a soft rail accepted knowingly. City v1 sacrifices
verticality and indoor maneuver AI. All of it is post-EA roadmap by prior ruling.

**Awaiting the Summoner's rulings; no decree issued. Rulings to record in THE RECORD
phase: (1) dial detent, (2) Tet clock vs surge, (3) map pipeline hybrid + ADR-028
amendment, (4) rhythm R3, (5) greenlight The Ride-Out as first post-EA build.**
