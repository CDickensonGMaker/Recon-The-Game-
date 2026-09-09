# BRIEFING II — MAY THE WAR AT RANGE BE RESOLVED ABSTRACTLY?

**Convened:** 2026-09-09, same session, seated as a full matter and not a footnote.
**Arbiter:** the Overseer. **Summoner:** Caleb, playing the build live (pid 13196) — never kill it,
open no window, freeze the save layer in any probe.

---

## THE QUERY — his words

He hit a bad stutter when ambient napalm landed, then generalised it himself:

> **"i think overall that might be a big performance issue, were not optimizing some of these events
> as well"**
> **"that way theres not things happening across the map thats lagging the game."**

And he gave the design target in the same breath:

> **"like at most just random battle sounds from time to time will sell this war at large effect more
> than anything else."**

**THE QUESTION PUT TO THIS COUNCIL:** may a distant engagement be resolved **abstractly** — a cheap
deterministic resolution yielding the same casualties and the same ledger rows — instead of being
simulated man-by-man, and presented to the player as **sound**?

A separate census agent is measuring and ranking every system that simulates at full fidelity
regardless of player distance. **It is forbidden to answer this question alone**, and it is under a
standing constraint this council must not weaken:

> **Presentation may degrade with distance. OUTCOMES MAY NOT CHANGE.** The same men die and the same
> ledger rows are written whether or not the player watches. A world that resolves differently
> depending on where he stands is not the world this game promises.

## THIS IS NOT A NEW MECHANISM. FOUR THINGS ALREADY EXIST — READ THEM BEFORE PROPOSING ANYTHING.

### 1 · `MarchingCell` is the ratified precedent, and it is already shipping
`scripts/enemies/marching_cell.gd` (245 lines), **ADR-035 §2**:

> *"A fireteam that walks as ONE node and becomes bodies only on contact ... AI think is ~1.2ms of a
> 38-40ms wall. The body — `move_and_slide`, hitzone sync, anim — is the other **~94%**. A hivemind
> that shares thinking banks nothing; one that shares **BODIES** banks everything."*

It already solves the two hardest parts of the question:
- **Outcome preservation:** `live_strength()` (`:56-66`) returns *full paper strength* while dormant —
  *"the siege ledger must count men who have not materialized yet, or the break ratio is computed
  against an assault that is still arriving."*
- **The transition case:** `MATERIALIZE_M = 80.0`, chosen to clear the night sight cap (56 m open ×
  0.4 night) *"or the player watches bodies appear out of nothing."* **A measured number, not a guess.**

It also holds the single spawn authority: *"spawns route through `FieldDirector.spawn_tracked_enemy`."*

### 2 · The "random battle sounds" he asked for ALREADY EXIST
`scripts/ai/ambient_war.gd` (239 lines) — distant war events on `SimClock.hour_advanced`, 1-3 per
hour, 200-800 m from the player, positional audio, with a real distant-firefight model: two parties
40 m apart answering each other on burst clocks (`BURST_MIN/MAX` 3-8, MG 6-14, `SHOT_GAP_S` 0.11,
lulls 2-6 s, `RAGGED_FRAC` 0.75 so an engagement goes ragged rather than stopping mid-burst), per-weapon
distant reports, and a 900 Hz cutoff because *"past 400m a rifle has no crack left, only a dull slap
off the treeline."*

**So his stated target is built.** The council must find out why he is not hearing it, or whether what
he is hearing is drowned by the thing that stuttered. **Do not propose building this.**

### 3 · The abstraction tier was BLESSED BY HIM, and the vehicle — not the idea — was killed
- **ADR-025** (LOD tiers) is **SUPERSEDED, instruction VOID**: *"Do not extend `WorldSim`, and do not
  wire `materialize_near`/`dematerialize_far`."* `world_sim.gd` is now **34 lines**, a flat registry.
- What superseded it: the 2026-07-18 AI-consolidation decree, **blessed by Caleb explicitly**, whose
  wave WB is *"AIDirector tick-list tiers **HOT/LIVE/DORMANT/AGGREGATE**, event-bus wake, WorldSim
  buried."* **`AGGREGATE` is his own blessed tier name.** The idea survived; only WorldSim died.
- Its stated kill-shot was geometric — WorldSim's `CELL_SIZE`/`AO_RADIUS` could never produce DORMANT
  on a **1280 m** map. **The demo map is 512 m.** Re-check whether that geometry argument still binds.

### 4 · The Ambience Law already constrains the answer
ADR-020 §4 / ADR-025 Phase 3: *"resolution never touches the player or player-assets directly — the
instant an outcome could cost the player, it has already become an **offer** surfaced through
`DynamicMissionFactory`, never a silent loss."*

## WHAT THE ANSWER MUST NOT BREAK

- **The casualty ledger IS the scoreboard** (his decree 2026-07-30). Medical-tent occupancy is the
  *real* casualty ledger, never a random number on a timer; the dead stack as body bags. A cumulative
  diegetic scoreboard of the player's own failure, with no UI.
- **Bodies give intel only** (his decree 2026-07-30). Searching a man yields intel points toward a
  stash of 3 marks, exactly 1 real.
- **ADR-010, one seed per operation.** Any abstract resolution is seeded or it is not deterministic.
- **Pillar 3, Freedom.** Off-AO events become offers, never rails.
- **Pillar 5, Fail forward.**
- **ADR-015.** Nothing closes without a probe or a measurement.

## THE THREE QUESTIONS THE COUNCIL OWES HIM

1. **May distant engagements resolve abstractly?** Yes/no/with-conditions, weighed against the pillars
   and every ruling above — not as a perf matter. **It is a design question with a perf prize
   attached, and the prize is exactly what makes it dangerous.**
2. **THE TRANSITION CASE — press hardest here.** The player deliberately walks toward a distant fight
   and watches it become simulated. What does he find? `MarchingCell` answers this for the siege at
   80 m with a measured cap; does that answer generalise to a firefight already in progress between
   two parties, where the abstract resolution has *already killed men* who now must exist as bodies in
   plausible positions with plausible wounds?
3. **Can an abstractly-resolved battle still produce bodies worth reading as intel, and an aftermath a
   player can walk into and find coherent?** If not, say so — that is a real cost and it must be named,
   not smoothed over.

## LAW 2 — NAME WHAT IS LOST

Whether *"the war runs without you"* survives being resolved by dice at range is the honest heart of
this. Say it plainly.
