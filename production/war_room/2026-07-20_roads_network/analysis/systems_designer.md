# SYSTEMS DESIGNER — Q3: does the ambush economy actually IMPROVE by adding roads?

**Council:** 2026-07-20 roads network · **Architect:** systems-designer
**Method:** read the code, not the plan. Every claim below carries a `file:line`.

---

## VERDICT IN ONE LINE

**A road network does not improve the ambush economy — and a hard `ROAD_NEAR_M` gate against one
would make it measurably WORSE, by construction, not by bad luck.** The fix is not to build the road
the constant is waiting for. It is to recognise that `ROAD_NEAR_M` was always asking the wrong
question: an ambush wants to be **near a line that things move along**. A road is one such line. A VC
patrol circuit is another, and in this AO it is the more common and more Vietnamese one. Generalise
the constant, make it a **score term with a guaranteed fallback**, and the road becomes an
improvement instead of a rejection filter.

---

## 1 · THE TRAP, QUANTIFIED — and it is structural, not probabilistic

### 1.1 What the planner does today

`ambush_planner.gd:37-63` samples `CANDIDATES = 16` points in a **40–200 m annulus around a VC camp**
(`:39-40`, `SEARCH_RADIUS = 200.0` at `:24`). Each candidate faces three hard rejects — firebase
keep-out (`:43`), paddy within 30 m (`:46`), cover below `GOOD_COVER_MIN = 0.35` (`:51`) — then is
scored `cover*0.6 + los*0.4` (`:54`). `ROAD_NEAR_M = 80.0` (`:15`) is declared and never read. The
briefing is right that this is a live truth-law violation. It is also, right now, **harmless**: the
planner returns sites.

### 1.2 Where the camps actually are

`mission_generator.gd:530-542` — three camps, `planner.find_site(rng, 14.0, 120.0, [], gate, 400.0, cap)`
with `cap = 480.0` for the first and `540.0` for the rest. **Band: 400–540 m from the gate, at
arbitrary bearing.** No quadrant constraint. Fallback `_outward_site(...440.0, 70.0...)` (`:537-539`)
pushes even further out.

Villages: `:492-528` — one per quadrant, **240–470 m from the gate** (`:505`), or 280–450 m on the
`find_site` path (`:513`), fallback ring at 360 m (`:524`).

`WorldConfig.MAP_SIZE = 1280.0` (`world_config.gd:9`); the FSB sits near mid-map, so a map edge is
~600 m from the gate. **Camps at 400–540 m are already in the outer third of the AO.**

### 1.3 The structural mismatch — this is the finding

A road network's job is to connect **the places friendlies go**: firebase, villages, the outside
world. Its terminal nodes are the villages, at **240–470 m**. The camps sit at **400–540 m** —
*outside the road network's own terminus band, by construction.* The generator was written that way
deliberately: villages are the near ring you walk to, camps are the deeper ring you go find.

So a road that ends at a village is, in the median case, **~115 m radially short of the camp band and
in the tail case 300 m short** (village 240, camp 540). Angular coverage can be bought — more spokes —
but **radial reach cannot**, because extending the road past the village to reach the camp means
paving a road to a VC base camp, which is both nonsense historically and a Pillar 3 problem (it draws
a line straight at the thing the player is supposed to *find*).

### 1.4 The numbers

For the planner to return anything under a hard gate, the road must pass within
`SEARCH_RADIUS + ROAD_NEAR_M = 280 m` of the camp centre. Below that it is not "unlikely" — it is a
**guaranteed empty dictionary**, because the road corridor does not intersect the candidate annulus at
all. No amount of re-rolling the 16 candidates helps.

| Road topology | P(road within 280 m of a given camp) | Notes |
|---|---|---|
| Single straight MSR through the gate | **~40 %** | for a camp at r=470: (2/π)·asin(280/470) |
| Single MSR, gate to one map edge only | ~20 % | half the through-line |
| 4 village spokes + MSR, **ignoring radial shortfall** | ~90 %+ | 6 rays × ±36.5° over-covers 360° |
| 4 village spokes + MSR, **with the real radial shortfall** | **~50–65 %** | spokes die at the village; camp is 115–300 m further out |

And a camp that clears the 280 m test is not home free. Even with the road passing directly through
the camp, the 160 m-wide corridor covers only ~42 % of the annulus area, and that fraction must then
survive the paddy, keep-out and `cover >= 0.35` rejects that already thin the 16 candidates. At the
280 m margin the corridor covers ~10–15 % of the annulus and a shutout becomes likely on candidate
count alone.

**Expected outcome of a naive hard gate: roughly one of the three camps loses its ambush entirely,
every seed, and it will occasionally be two.** Today that number is approximately zero.

### 1.5 What a lost ambush actually costs

`mission_generator.gd:576-593` — the ambush party is **not additive**. One garrison roll of 6–9 men
(`:579`) is *split*: 4–6 men move to the ambush site (`:585-589`), the rest stay at the camp (`:591`).
The comment at `:574-575` states the contract exactly: *"the AO does not gain men, it moves them onto
chosen ground."*

So a rejected ambush does not remove men from the world. It **returns them to the camp**. The failure
mode is therefore invisible in any headcount probe and silent at runtime — the AO simply gets **duller**:
a fatter static camp garrison and one fewer piece of chosen ground between the wire and the objective.
That is precisely the "set of ambush boxes waiting for the player" state that ADR-021 was written to
end (`ADR-021-patrols.md:8-9`).

**A hard `ROAD_NEAR_M` gate is a regression that no existing probe would catch.** That alone should
settle it.

---

## 2 · RULING ON BEAD ld0y — road, patrol circuit, or both?

**Both. And the constant should be renamed to say so.**

The intent behind `ROAD_NEAR_M` is not "roads exist." Read the header (`ambush_planner.gd:1-10`)
against the rest of the constraint list — cover within 30 m, LOS *to the trail* blocked by jungle, no
paddy silhouette. Every one of those constraints is written **relative to a line of travel**. The
constant is a proxy for one thing: *ambush the ground your enemy must cross.* The Vietnamese-ness is
in the line, not in the pavement. The VC did not ambush roads because roads are special; they ambushed
roads because that is where Americans were, on a schedule.

ADR-021 already ratified this substrate and says so almost verbatim: nodes anchor to
*"a cache, a ville, a trail junction, a river ford, high ground"* and *"a route that connects things is
a route a player can learn, predict, and exploit — which is the entire point"* (`ADR-021:34-36`). The
decree's spine — **PATROL TO LEARN THE GROUND. USE THE GROUND TO KILL THEM** (`:62`) — is a statement
about *lines of travel*, and the only line-of-travel object it names as authored is the patrol route.

**Retargeting at circuits alone is also wrong**, though, for the same reason: it swaps one constant
for another. The correct abstraction is a **traffic-line registry** — a list of polylines the AO knows
things move along:

| Line class | Source in code today | Who uses it | Traffic weight |
|---|---|---|---|
| Road / MSR | to be built | US convoys, ARVN, civilians | high, scheduled, wheeled |
| Ambient VC patrol circuit | `mission_generator.gd:637-638`, `EnemyBase.make_patrol_circuit` (`enemy_base.gd:1830`) | 2–4 VC, looping | medium |
| Camp patrol beat | `camp_director.gd:79-81`, `PatrolGenerator.generate` | camp garrison | medium |
| Gate→village walking corridor | implied by `mission_generator.gd:626-628` | player + squad, every patrol | **high — this is the player's own line** |

That last row is the one nobody has named and it is the most valuable. The gate→village legs are the
ground **the player** crosses, every single time he walks out. A VC ambush sited on the player's own
habitual corridor is the ADR-021 loop running *in reverse* against him — and it needs no road at all.
It is also the only line class guaranteed to exist in every seed.

**Ruling:** rename `ROAD_NEAR_M` → `TRAFFIC_LINE_NEAR_M`, keep 80.0, and feed the planner a
`traffic_lines: Array[PackedVector3Array]` built from all four classes. **One registry, one authority.**
This satisfies the truth-law violation without the road existing at all, which means it can ship
BEFORE the road and de-risks the whole road decision.

---

## 3 · RULING — hard reject or score term?

**Score term. Multiplicative, floored, with a two-pass fallback.** Never a reject.

Design reasoning: cover and LOS are **survival** constraints — a man in the open dies to the
counter-volley (`ambush_planner.gd:48-49`), so those stay hard. Proximity to traffic is an
**opportunity** constraint. An ambush 200 m off the trail is not invalid; it is merely a worse
ambush that waits longer. Hard-gating an opportunity term is the classic mistake, and here it converts
a graceful degradation into a total failure.

### Recommended shape

```
traffic t:   d <= 80          → t = 1.0
             80 < d <= 300    → t = 1.0 - (d - 80) / 220
             d > 300          → t = 0.0

score = (cover*0.6 + los*0.4) * (0.55 + 0.45 * t)
```

Why multiplicative rather than a fourth additive weight:
- **It cannot zero a site.** Floor is 0.55×. Worst case a roadless site scores 55 % of its cover
  value, which is still a returned site.
- **Cover stays the substance.** A traffic line can never promote a grass-field site over a jungle
  site — the multiplier spans 1.8×, while cover already spans a hard reject at 0.35. Traffic breaks
  ties among *already-good* sites, which is exactly its epistemic status.
- **It is monotone in the right direction.** Adding a road strictly increases the score of sites near
  it and leaves every other site unchanged. Adding roads can therefore only *move* ambushes onto
  better ground, never delete them. That is the precise property the hard gate lacks, and it is the
  property the Summoner is actually buying.

### The fallback pass is non-negotiable

Even with a floor, add the explicit guarantee:

> `plan()` returns non-empty whenever it would have returned non-empty before this change.

Cheapest way: score all 16 candidates once; if the traffic-weighted best is empty for any reason,
return the unweighted best. Assert it in a probe: **same seed, same camp, `traffic_lines = []` vs
populated → both non-empty.** That probe is the whole defence against the §1 regression, and it is
about ten lines.

### The improvement roads DO buy — and it is not the constant

Right now `_los_blocked` (`:89-103`) samples **four arbitrary compass bearings** and rewards jungle in
any of them. The header (`:7`) claims the requirement is *"line-of-sight from the kill zone to the
trail is BLOCKED by jungle"* — but with no trail in the data, the function cannot be directional, so
it degenerates into "is this spot generally bushy." **That is the real bug the missing line causes,
and it is worse than the unread constant.**

With a traffic line in hand:
- `los` becomes **directional** — sample the corridor between the site and the nearest point on the
  line, which is what the doc always claimed.
- The returned dictionary (`:57-62`) can carry `kill_zone` (nearest point on the line) and `face_dir`.
  Today `trigger_pos` is a bare point with **no facing and no kill zone**; the 4–6 men spawned from it
  (`mission_generator.gd:588-589`) stand in a `spread: 8.0` blob facing nowhere.
- An L-shape or linear formation along the line becomes expressible.

**That** is the ambush-economy improvement. It is unlocked by *lines*, not by *roads*, which is one
more reason to build the registry first and let the road be one late entry in it.

---

## 4 · CONVOY ROUTES — what should a route BE?

### What it is today

`mission_generator.gd:326-342`: `origin = insertion_lz` (the FSB spawn seat), `dest = origin + (rand
200–400, 0, rand ±200)`. A two-point leg into noise. It connects nothing, respects no terrain, and
`insertion_lz` is `gm.spawn_pos` (`:485`) — **inside the wire, on the 215 m flatten disc**
(`site_planner.gd:473`). Today's convoy therefore drives out of the player's own spawn point into a
random bush.

### What it should be

Convoys in this AO have exactly two honest jobs, and both are already implied by the existing world:

1. **RESUPPLY (the MSR run).** Comes from **off-map** — the rear, regiment, the world beyond the AO —
   and terminates at the **FSB gate**. Route: `[map-edge entry] → (MSR polyline) → gate_out staging →
   gate_pos`. This is the one that matters, because it makes the road *the player's own lifeline*.
   An ambushed resupply convoy is a crisis he has standing reason to answer, and
   `DynamicMissionFactory.location_for` already mints `ambushed_convoy` for it (`:20-21`).
2. **CIVIC / CAP RUN.** `gate → nearest village → back`. Short, daytime, on the same MSR spur.
   Optional; cut it in v1.

Both are **out-and-back on ONE authored polyline**, which is the minimum-scope answer: a convoy route
is not a route generator, it is *a sub-path of the road*. If the road exists, the route is free. If it
does not, there is no honest route to invent — which is exactly why `convoy.gd:1-3` was parked, and
the parking decision was correct.

**Design payoff, stated plainly:** the MSR is what converts the road from scenery into an economy.
The player's resupply arrives on it; the VC know that; therefore the road is *worth ambushing* and
*worth patrolling*. That is a two-sided loop with the player in the middle, and it is the single
strongest systems argument for building the road at all. Without the convoy, a road is a texture.

**Direction of travel matters for the fiction:** convoys should arrive **inbound at dawn** and the
ambush risk should be highest on the outer half of the MSR — the half beyond the villages, nearest the
camp band. That, incidentally, is the one place where roads and camps *do* naturally come within
280 m of each other, and it is where the road should be routed if we route it deliberately (see §6).

---

## 5 · `convoy_spawner.gd:60` — `cv.setup(route, [])`. In scope?

**In scope to DIAGNOSE and BEAD. Out of scope to FIX in the roads decree** — because it is not one
break, it is **four**, and the empty array is the least of them. Fixing line 62 alone (it is `:62` in
the current file; `:60` in the briefing is off by two) produces a convoy that is *more* broken than
today's silent no-op, because today's empty-vehicle convoy exits `_physics_process` immediately at
`convoy.gd:45`.

The chain, verified:

| # | Break | Pointer | Effect if the array is filled |
|---|---|---|---|
| 1 | `vehicle_models` never forwarded | `convoy_spawner.gd:62` | convoy is an empty shell; `_physics_process` returns at `convoy.gd:45` — **currently a silent, harmless no-op** |
| 2 | **Nothing anywhere calls `Convoy.report_contact`** | grep: only the declaration at `convoy.gd:85`. Every other `report_contact` hit is `EnemySquad`/`FieldDirector`/`EnemyBase`, a different signature | `ambushed` **still never fires**. `DynamicMissionFactory._on_convoy_ambushed` (`:52`) remains unreachable **even with vehicles**. Fixing the array does NOT unblock the dynamic-event producer. |
| 3 | Convoy never seats to terrain | `convoy.gd:67-70` writes `x` and `z` only; `y` is whatever the spawn set | vehicles fly through hills / sink into ridges. Purely cosmetic today because there are no vehicles. |
| 4 | `DestructibleVehicle` is a `StaticBody3D` in group `nav_blockers` | `destructible_vehicle.gd:4, :27` | a moving convoy **drags nav-blocking static bodies through the world**; `NavBaker` carves the navmesh at their spawn positions. Teleporting a `StaticBody3D` every physics frame is also the wrong body type — no interpolation, unreliable contacts. |

There is also no despawn path: `route_finished` (`:14`) is emitted at `:53` and connected by nobody,
so convoys accumulate.

**Recommendation:** bead all four together under one title the Summoner can rule on without opening it
— *"Convoys spawn with no vehicles, never report contact, don't follow terrain, and block navmesh"* —
and **sequence it AFTER the road ships**. The correct order is: traffic-line registry → MSR polyline →
convoy vehicle wiring (all four fixes as one change) → contact reporting → `DynamicMissionFactory`
finally reachable. Doing #1 in the roads wave buys nothing, because #2 gates the payoff.

**Fossil-law note:** `resume()` (`:95`) and `waypoint_reached` (`:12`) are correctly parked per the
header. But `report_contact` having zero callers is not "parked pending roads" — it is a **missing
caller in the vehicle's own damage path**, and roads will not supply it. That should be said plainly
in the bead so nobody assumes roads discharge it.

---

## 6 · SCOPE — what I would cut (Q5, from the systems lens)

**BUILD:**
1. **The traffic-line registry.** `Array[PackedVector3Array]` on the plan dict, populated from patrol
   circuits + gate→village corridors. Costs nothing, needs no terrain writes, discharges the
   `ROAD_NEAR_M` truth-law violation, and improves `_los_blocked` immediately. **Ship this even if the
   road is cancelled.**
2. **ONE road: the MSR.** A single polyline, map edge → FSB gate, routed to pass near one or two
   villages and — deliberately — to run its outer leg **within ~250 m of at least one camp**. That
   last constraint is cheap to enforce at plan time and it converts the §1 geometry problem from an
   accident into a design parameter. One road, one authority, appended to the registry.
3. The traffic **score term with the fallback pass and its probe**.

**CUT:**
- **Junctions.** One polyline has none.
- **Bridges.** Route the MSR to cross rivers at a **ford** instead — cheaper than a bridge, it does
  not touch the just-fixed hydrology, and ADR-021 already names *"a river ford"* as a first-class
  patrol anchor (`:35`). A ford is a better ambush site than a bridge and costs a height sample.
- **Road-following vegetation clearing** in v1. If the road is a shader-mask corridor, the existing
  clearing mask machinery is the only thing that should touch vegetation, and it should touch it once.
- **The civic/CAP convoy.** One convoy kind.
- **Roads to camps.** Never. See §2.
- **Any second world-gen pass.** The MSR must be planned inside `plan_patrol_world` alongside the
  villages and camps and stamped inside `build_patrol_world`, using the same `p` dict, in the same
  order (`game_flow.gd:284-285`). If it needs its own pass, it is out of scope.

---

## 7 · WHAT IS SACRIFICED (the law binds me too)

- **The traffic multiplier makes ambush placement less predictable to reason about.** Two soft terms
  now interact; a bad tuning shows up as "ambushes drifted onto the road and off the good cover." The
  0.55 floor and the 0.45 span are guesses and will need playtest.
- **Deliberately routing the MSR near a camp is a designer's thumb on the scale.** It is the smallest
  version of the rail Q2 is worried about. I accept it because the *player* is never told where the
  road goes relative to the camps, and he can walk anywhere — but it is a thumb, and it should be
  named in the ADR rather than buried in a plan function.
- **Adding the player's own gate→village corridor as a traffic line means the VC will start ambushing
  the walk the player habitually takes.** That is correct and Vietnamese and it will feel unfair the
  first time. It is also the single strongest reason to vary your route — a Pillar 3 lesson taught by
  the world instead of by text. But it will read as "the game cheats" unless the intel loop
  (ADR-021 §3) gives him a way to have seen it coming.
- **The registry is a new shared object.** That is one more thing that can disagree with the world. It
  is a read-only list of polylines derived from data that already exists, which is the cheapest
  possible version — but this project's worst failure mode is parallel authorities, and I am proposing
  one. It must be built in `plan_patrol_world` and owned by the plan dict, never assembled
  independently by a consumer.

---

## 8 · ANSWERS, COMPRESSED

- **Does the ambush economy improve by adding roads?** Not by itself, and a hard gate makes it worse
  — ~1 of 3 camps loses its ambush every seed, silently, with the men reabsorbed into a fatter static
  garrison. The improvement roads *can* buy is a **directional kill zone**, and that is unlocked by
  having a line, not by having pavement.
- **ld0y — roads or circuits?** Both. `ROAD_NEAR_M` → `TRAFFIC_LINE_NEAR_M`, fed by a registry of
  roads + VC patrol circuits + camp beats + the player's own gate→village corridors. Ship the registry
  first; it discharges the violation with no world-gen risk.
- **Hard reject or score?** Score. `(cover*0.6 + los*0.4) * (0.55 + 0.45*t)`, `t` full inside 80 m and
  linear to zero at 300 m, plus an unweighted fallback pass and a probe asserting *never worse than
  today*.
- **Convoy route?** An out-and-back sub-path of the one MSR: off-map edge → FSB gate. Convoys carry the
  player's resupply; that is what makes the road an economy rather than a texture.
- **`cv.setup(route, [])`?** Diagnose and bead now, fix after the road. It is four breaks, and the one
  that actually gates `DynamicMissionFactory` is that **`Convoy.report_contact` has zero callers** —
  a fact roads will not change.
