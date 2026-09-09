# THE SECOND DECREE — the war at range may be abstracted, but not for the reason it was asked

**2026-09-09 · Arbiter: the Overseer · three lenses + the census agent**
**Briefing:** `briefing_distant_war.md` · **Analyses:** `analysis/distant_war_designer.md`,
`analysis/distant_war_devils_advocate.md`

---

## THE VERDICT

> ## **YES — abstract resolution is ratified in principle, with four conditions.**
> ## **NO — it is not a performance fix, it does not fix his stutter, and it is not demo work.**

**It is ratified as a WORLD-FIDELITY feature, and the council asks that it be described that way and
never as an optimisation.** The Devil's Advocate stated the argument he could not refute, and the
Arbiter adopts it verbatim as the justification of record:

> **`LazyGroup` already changes outcomes today, and abstraction is the only fix.** `activation_range =
> 140.0` — a group beyond 140 m of the player is not simulated cheaply, **it does not exist.** It
> cannot fight, die, be heard, leave a body, or write an evidence row. So the standing constraint
> *"the same men die whether or not the player watches"* **is already false in the shipped build, in
> the worst possible direction: absent, not degraded.** Two friendly patrols and three enemy groups
> can never meet, because at most one of them is real at any moment.
>
> **The prize is not frames. It is that the war can happen at all when he is not looking.**

## 1 · THE PERF NUMBER IS REAL, AND IT ARGUES FOR THE OTHER THING

The census priced it: **`ai.execute` + `ai.think` = 425.8 ms over 14 s (~30 ms per second of play),
14,600 calls, for TEN men fighting, with zero distance-gating.** That is the largest line in the
census, and at ten men it is already ~3% of wall-clock; a war of sixty men is 180 ms per second.

**But it is not an argument for abstracting DISTANT fights, and the council must not let the two be
merged.** Measured independently by the Devil's Advocate:

- `LazyGroup.activation_range = 140.0` — **no lazy body exists beyond 140 m of the player, ever.** In
  `plan_demo_world`, everything except `village_defenders_0` is lazy.
- Distant think is **already throttled 4× past 150 m** (`enemy_base.gd:41-56`: > 150 m → 0.6 s).
- **The demo has 3–4 distant bodies**, confirmed twice — code walk and the 2026-09-07 audit's
  *"one fixed 3-4 man group at 165-185 m plus 2-3 lazy patrols."*

> **So the 30 ms/s is being spent on men the player is FIGHTING, inside 140 m. Abstracting the distant
> war would save approximately nothing in the product that ships.**

**The census number is therefore an argument for DISTANCE-GRADED SIMULATION COST (LOD) for men who
exist — a different, cheaper, safer piece of work with no outcome risk — and only secondarily for
abstract resolution.** They are two projects:

| | what it is | outcome risk | demo value |
|---|---|---|---|
| **A · LOD** | men who exist cost less with distance — anim, physics, hitzone sync, not think | **none if presentation-only** | real, and it is what the census measured |
| **B · ABSTRACTION** | fights the player cannot reach resolve cheaply and are heard | **high — this decree's conditions** | ~none; the demo has 3–4 distant bodies |

**A is where the census points. B is where the world he wants lives.** Do A for frames. Do B for the
war. Never sell B as A.

## 2 · HIS STUTTER — ANSWERED, AND IT IS NOT AI

He generalised from an ambient napalm stutter: *"i think overall that might be a big performance issue,
were not optimizing some of these events as well."*

**The instinct is correct. The evidence he attached it to is not.** Both the Devil's Advocate and the
census converged:

- **`terrain.crater` = 122.2 ms of a 125.43 ms frame — 97% in one call**, because a napalm's 88 m
  radius always spans four chunks and the partial-update fast path never engaged.
- Fire, explosion and blast VFX together were **7.6 ms** for a nine-canister strike.
- The "ambient" napalm is **not ambient**: it is scripted at **T+35 s**, 210 m, *"SOMEBODY ELSE'S WAR"*
  — the first ordnance of the run. `AmbientWar` never drops napalm at all.
- The 2026-08-31 first-strike cache-warm defect **is fixed and verified live** (`GunFX.warm()` /
  `FireHazard.warm()` at `game_world.gd:56-57`).

> **THE EXPENSIVE THINGS ARE WORLD-STATE REBUILDS, NOT THE PRETTY THINGS.** *"Presentation degraded,
> outcome identical"* saves **7.6 ms** on VFX and **enormously** on simulation — which is exactly why
> the abstraction question is the one that matters and the one that is dangerous.

**And this closes a nine-day-old open question.** `PLAYTEST_FINDINGS:282-284` left the raid item open
with one closing condition: *"Call a napalm run in the demo and tell me whether the first strike still
hitches."* **He just ran that test and it came back positive.** His report is the answer to that
question, not evidence about distant AI. **Build abstract resolution and the stutter stays.**

## 3 · THE TRANSITION CASE — it is arithmetically impossible today, and it must stay that way

The coordinator asked the Devil's Advocate to press hardest here. The answer is better than expected:

- Nearest ambient spawn **400.0 m** ÷ player sprint **8.0 m/s** = **50.0 s of travel**.
- Maximum event lifetime: **40.0 s**.

**He can never reach a distant firefight.** And if that were broken: corpses self-free at **45 s
unconditionally**, so the dead are gone before he is a third of the way; wounds would be authored to
match bullets nobody fired; and the two parties are placed on a random bearing with **no terrain query
at all** — the near tier uses `_passable_near` + `_seat`, the far tier does not.

> ### THE DESIGN, AND IT IS ONE LINE
> **Simulate what he can reach. Sound what he cannot. Never place a live abstract fight in between —
> place its AFTERMATH.**

| band | treatment |
|---|---|
| **400–800 m** | sound only, unreachable, unchanged — **this is exactly what he asked for** |
| **200–400 m** | **currently EMPTY.** Give it *aftermaths*: resolved before placement, never live |
| **110–200 m** | fully simulated, unchanged |

**The aftermath minimum:** 2–4 searchable bodies + the weapons + a direction. **The weapons are already
free** — `WorldWeapon` persists 600 s, seeded. And an aftermath is **cheaper than simulating the
fight**, by ADR-035 §2's own ~94%-is-the-body number.

**This also preserves `bodies-give-intel-only`:** an aftermath yields searchable bodies, so the intel
economy is served without a single bullet being simulated.

**MY RULING ON THE MID-FIGHT TRANSITION: it is refused.** A firefight already in progress, with
accumulated dead, cannot be made coherent when it materialises — and the honest answer is to design so
the case never arises. **`MarchingCell` is not a counter-example**: a marching cell walks toward an
objective with nobody engaged and nothing dead yet. That is why its 80 m ring works and why the same
number will not carry a firefight.

## 4 · "OUTCOMES MAY NOT CHANGE" — a true law with, today, no referent

**The dangerous prize is not on the table.** A distant NPC-vs-NPC engagement **writes ZERO ledger rows
today.** The casualty ledger is the player's own butcher's bill only — `campaign_state.gd:50-75`, fed by
`result.squad_kia`, whose sole writer repo-wide is `squad_system.gd:809` (his five men).
`FriendlyPatrolGroup` banks nothing; the AAR kill book requires a player/squad killer.

**So "same casualties, same ledger rows" is a correct law with nothing to bind on for this class — and
that is a finding, not a loophole.** It means the constraint is cheap to honour now and must be
re-checked the moment the ledger grows a second writer.

**Where it WILL leak, named so the census agent's constraint can actually hold:**

1. **`EvidenceLedger` is fed by exactly one source, `NoiseBus`.** A silent fight writes no evidence, and
   `field_director.gd:169` states the consequence: *"With no evidence there is no lead and nobody is
   sent."* **But emitting noise is ALSO an outcome change** — `GUNSHOT` has a 150 m radius and wakes
   every AI inside it. **There is no neutral choice here; both directions change the world.**
2. **Suppression and morale are emergent from bullets and witnessing** and are **not derivable from a
   casualty count.**
3. **The butcher's bill needs physical bags and ward occupancy, not a counter** — his own 2026-07-30
   decree makes the medical tent the ledger.

## 5 · THE FOUR CONDITIONS

**C1 · THE UNREACHABILITY INVARIANT BECOMES A PROBED LAW.** `min_dist / SPRINT_SPEED > max_lifetime`,
asserted in the suite. The far tier is sound because it cannot be reached; if a tuning change ever
breaks that, the build goes red rather than the fiction.
**C2 · An abstract resolution may write only what no observer can contradict.**
**C3 · The Ambience Law is unchanged** (ADR-020 §4): the instant an outcome could cost the player, it
is an **offer**, never a silent loss.
**C4 · SEEDED.** The moment it writes an outcome it leaves `AmbientWar`'s documented unseeded exemption
and comes under ADR-010.

## 6 · WHAT THE COUNCIL FOUND ON THE WAY, WHICH IS WORTH MORE THAN THE VERDICT

**THE JUNGLE NEVER HUSHES FOR THE WAR.** `AMBIENT_WAR_HUSH_M = 400.0` (`game_world.gd:264`) is
**exactly** the ambient spawn floor (`ambient_war.gd:69`). **The hush can therefore never trigger** —
the war layers *under* the birdsong instead of interrupting it. **A one-number fix, and it is the most
likely reason the war does not feel present to him.**

**AND THE "IT ALMOST NEVER FIRES" HYPOTHESIS IS REFUTED — I raised it and it is wrong.** `DAY_RATIO` 38
→ one sim hour every 94.7 real s. A 30-minute demo = **16 `hour_advanced` emissions × ~2 events = ~32
distant war events, one every ~56 real seconds**, ~26 of them also spawning a 12.0-scale fake fireball.
**It is loud and frequent.** He is not hearing an absence; he is hearing a war that never interrupts the
birds, and cannot walk to any of it.

**Meanwhile the NEAR tier — the one with real men — caps `contact` at ONE per demo day** in a 584-second
eligible window. **He hears a war he can never touch, and can touch a war that almost never rolls.**
That inversion is the real defect, and it is cheaper to fix than anything in this decree.

**TWO CORRECTIONS OF RECORD (NO MORE DRIFT):**
- **The briefing's claim that `SimClock.advance()` has zero callers is FALSE** — `sim_clock.gd:27-34`
  winds it every frame, plus `game_flow.gd:108`. **The Arbiter carried that from ADR-025 without
  re-checking it.** The real determinism problem is one line down: `advance(delta)` integrates **real
  frame delta**, so `sim_hour` is frame-timing dependent. Hour crossings are safe; **anything
  integrating continuous `sim_hour` would violate ADR-010 invisibly.**
- **ADR-025's geometric kill-shot does not transfer.** It died because `CELL_SIZE`/`AO_RADIUS` could
  never produce DORMANT on a **1280 m** map. The demo is **512 m**. The *vehicle* (WorldSim) stays
  buried; the *idea* was blessed by him on 2026-07-18 as the AIDirector tick-list's **`AGGREGATE`**
  tier, and that is the name this work should carry.

**AND ONE SHIPPED NUMBER THAT SURVIVES ONLY BY LUCK.** `MarchingCell.MATERIALIZE_M = 80.0` was derived
against the **night** sight cap (56 m). **The DAY cap is `SIGHT_CAP_OPEN = 140.0`; dusk 105 m;
illum-lit 126 m. 80 m clears none of them.** It is not a shipped defect *only* because the demo assault
is a night action. **But `SightCap` governs AI acquisition, not the player's camera, and he carries
binoculars at 18.0 FOV (4.84×) and the M70 at 12.0 (7.30×).** A body popping at 80 m through the M70
has the angular size of a man at 11 m. **The derivation never considered the optic, and a daylight
ambient fight is exactly where it breaks.** Recorded now, before the tier is built on it.

## 7 · PRIORITY AND SCOPE

**Not demo work.** ADR-039 is ACCEPTED, POST-DEMO, BUILD NOTHING, under his own scope wall, and this is
its territory. Every world-abstraction design in this project's history is dead (ADR-025), frozen
(039/041/040/007-A) or forbidden (013) — **zero have ever shipped.** Ratifying the principle costs
nothing and stops the next council re-deriving it; **building it now would be the fourth attempt at a
thing that has never once survived contact with a ship date.**

**What IS authorised now, because each is a bug fix and gate-exempt:**
1. **`AMBIENT_WAR_HUSH_M`** — one number; the war becomes audible over the jungle.
2. **`terrain.crater`'s four-chunk fast-path miss** — 97% of a 125 ms frame; **this is his actual
   stutter**, and it belongs to the napalm agent already on that path.
3. **The near-tier `contact` cap** — he can touch almost nothing today.

## 8 · WHAT IS SACRIFICED — Law 2

**If we build it:** a battle resolved at range is coarser than lived combat, and will sometimes disagree
with what the player would have seen. **The aftermath design is an admission** — we are conceding that a
fight cannot be joined halfway, and buying coherence by making the fight unreachable. Some of *"the war
runs without you"* is bought with a stage set rather than a simulation, and **he should know that the
bodies he finds were never shot by anyone.**

**If we do not:** the world stays smaller than the promise. `LazyGroup` keeps deleting everything past
140 m, two patrols can never meet, and the ambient war remains a soundtrack rather than a war. **That is
the honest cost of the "no" and it is why the answer is yes-but-later rather than no.**

**And the Arbiter's own sacrifice, named:** I brought this council a hypothesis (the ambient war almost
never fires) and a stale fact (SimClock has no callers). **Both were refuted by architects I sent to
check them.** The process worked in the direction it is supposed to.
