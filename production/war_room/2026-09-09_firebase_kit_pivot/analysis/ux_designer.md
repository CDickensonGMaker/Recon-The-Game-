# UX DESIGNER — the five things he saw, ranked by what the PLAYER feels

**Council:** 2026-09-09 firebase kit pivot · **Lens:** player experience, the r4bk Law
(*a feature without a visible HUD affordance does not exist* — ADR-012 Decision §3).
**Read:** briefing · ADR-030 (deferred, non-blocking) · ADR-012 · ADR-040 · code as cited.
Caleb is IN the build (pid 13196). Nothing was run. Every claim below is a read or a measurement;
where I could not measure I say **UNVERIFIED**.

---

## 0 · THE HEADLINE

**The ladder is the only interactive object in this game that seizes the player without asking,
tells him once in a message that fades, gives him no way to abort, and then teleports him to a
point nobody checked for solid matter.** Four separate agency failures stacked on one prop. The
collision fix is the smallest of the five things wrong with it.

And the second headline, for §6: **the "dropped on a map" feeling is not the base model's fault.
It is the STAMP.** The firebase sits at the centre of a **perfect 280 m-diameter cleared circle**
(`scripts/world/site_planner.gd:1061-1063`) inside a **perfect 342 m-diameter flattened circle**
(`:1686-1688`, `FSB_FLATTEN_RADIUS 215.0`) on a **512 m map**. Two concentric circles covering
two thirds of the world's width. That silhouette is the game-asset read, and it lives in two
constants — not in `fsb_main_v3.glb`.

---

## 1 · THE LADDER — a player-agency failure with a collision bug at the end of it

### 1.1 · Every point at which the player is not told what will happen

The game already has a rigorous prompt system. `player.gd:606-656`, `field_interact_prompt()`,
is the whole verb vocabulary — fourteen verbs, each naming the key its own listener checks, polled
every 0.2 s into a persistent bottom-centre label (`player.gd:1619-1625` → `ui/hud.gd:43-47`):

> `[F] MAN THE GUN` · `[F] DISMOUNT` · `[F] CLIMB OUT` (tunnel) · `[F] SEARCH THE CACHE` ·
> `[F] GO DOWN THE HOLE` · `[F] SECURE THE PRISONER` · `[K] SILENT TAKEDOWN` …

The doctrine is applied with real care elsewhere. `sleep_station.gd:91-104` refuses to show a
prompt at all when the verb is dormant — *"a prompt that only ever refuses would be a promise of a
feature that is not in this build (r4bk cuts both ways)"* — and states the consequence inside the
string: `[HOLD F] SACK OUT - ENDS THE PATROL`.

**The tower ladder is not in that list. Not one entry.** Here is what the player gets instead:

| # | Moment | What the player is told | Evidence |
|---|--------|------------------------|----------|
| 1 | **Approach** | **Nothing.** No prompt, no [F]. An `Area3D` catches him and the climb *starts on body-entry* | `world/ladder.gd:104-112`, trigger built `:86-101` |
| 2 | **Mount** | One toast: `"CLIMBING - [S] TO DROP OFF"` | `player.gd:1414` |
| 3 | **…which expires** | 3.5 s hold, 1.0 s fade, then gone. A tall climb outlives the only instruction | `ui/mission_hud.gd:358-365` |
| 4 | **…and is half true** | It names **[S]** only. `_tick_climbing` reads `move_forward - move_backward` (`player.gd:1441-1442`); **W climbs and is never mentioned.** The one thing the player must do to get up the ladder is undocumented | `player.gd:1441` vs `:1414` |
| 5 | **Mid-climb** | Nothing. The persistent prompt line keeps polling while climbing (the poll at `:1619` runs *before* the `is_climbing` early-return at `:1645`) — **it just has nothing to say** | `player.gd:1619-1625, 1645` |
| 6 | **Abort** | **There is none.** `stop_climbing()` has **zero external callers** — only `player.gd:1439` (ladder freed), `:1451` (reached bottom), `:1457` (reached top). No jump-off, no [F] to let go | grep: `stop_climbing` appears at `player.gd:1417,1439,1451,1457` and nowhere else in the repo |
| 7 | **Where you exit at the top** | Nothing. The exit point is `_top − face·0.95`, `y +0.30` — computed, never shown, and **on the opposite side of the rail from the side he climbed** | `world/ladder.gd:133-136`, consts `:22-23` |
| 8 | **The dismount itself** | The player does not act. Passing `top − 0.1 m` while holding W **teleports him**, unconditionally | `player.gd:1454-1457` |

**Compare the MG emplacement, three lines above in the same function:** `[F] MAN THE GUN` to get
on, `[F] DISMOUNT` to get off (`player.gd:613-617`). The ladder is the MG's twin — a third
movement state that takes the body off the solver (`player.gd:1397-1400`) — and it shipped with
neither half of the affordance.

**Classification: (b) bug, needs investigation → now (a) bug, known cause.** Named below.

### 1.2 · The trap, from the player's side

```
player.gd:1454-1457
    if climb > 0.1 and new_y >= top - 0.1:
        global_position = _ladder.call("dismount_point")   # ← no shape cast, no test, no fallback
        reset_physics_interpolation()
        stop_climbing()
```

`dismount_point()` (`ladder.gd:133-136`) is **pure arithmetic on two Blender empties.** It is never
tested against the world. **Any collider standing within `DISMOUNT_IN` = 0.95 m inboard of a
`ladder_top` marker receives the player's body.** Sandbags on a tower deck are exactly that.

Then the escape closes:

- The climb trigger is centred at `mid + face·0.55` (`ladder.gd:99`, `FACE_OFFSET 0.55`).
- The dismount point is at `top − face·0.95`.
- **They are on opposite sides of the rail, ~1.5 m apart.** So the wedge is *outside* the only
  volume that can put him back on the ladder, and `_on_body_entered` is the only entry point to
  the climb state (`ladder.gd:104-112`).

**There is no way back onto the ladder from the place the ladder puts you.** That is the whole
trap, and it is authored in eleven lines of code.

*(The exact sandbag geometry at a `ladder_top` on `fsb_main_v3.glb` is **UNVERIFIED** — that is the
programmer's/geometry lane. The code condition that produces the trap is proven above and is
geometry-independent: it fires wherever a collider sits in that 0.95 m.)*

### 1.3 · **DOES THE GAME OWE THE PLAYER AN UNSTICK AFFORDANCE?**

**YES — and the argument that settles it is not a design opinion, it is a double standard already
shipped in this codebase.**

> **Every AI in this game has an unstick watchdog. The player does not.**
>
> - Allies: `allies/ally_base.gd:56-83` (`_update_unstick`), ticked every frame at `:864` —
>   1 s pinned while wanting to move → 0.6 s sidestep, alternating sides, and after 3 flips a
>   further escalation.
> - Enemies: `enemies/enemy_base.gd:206-233`, ticked at `:860` — the same code, with the comment
>   *"alternate sides so corners release"* (`:225`).
> - Player: **`scripts/player/player.gd` contains zero occurrences of `stuck` or `unstick`.**
>   (Measured: `grep -c` = 0.)
>
> We built a corner-release for the men who cannot file a bug report and withheld it from the man
> who can.

**Against Pillar 5 (fail forward).** Pillar 5 is *escalation, not fail-states; death matters, but
this is not a sadism simulator.* Being wedged is **not a fail-state — it is worse.** A fail-state
still moves the story: you die, `BodySwapSystem` hands you another man, the world carries on. A
wedge produces **no state transition at all.** The player is alive, unhurt, un-targeted, and the
simulation has nothing further to say to him. There is no escalation available, so there is
nothing to fail *forward* into. It is the one outcome Pillar 5 has no vocabulary for.

**Against ADR-040.** ADR-040's central measurement is that the DOWN state *"already exists and is
already about thirty tense seconds. It simply has zero verbs… He is spending thirty seconds as
furniture."* The ruling was **restore agency, not time.**

**A wedge is the down state with the timer removed.** Zero verbs, indefinitely, and — unlike the
down state — **nobody is coming.** ADR-040 §5 records that out on patrol *"the down state IS the
entire safety net."* A wedge falls straight through that net: the player is not downed, so no
medic is routed, no swap fires, no clock runs out. If thirty seconds of furniture was judged the
defect worth writing an ADR about, unbounded furniture is not defensible on the same page.

**A hardcore sim may legitimately refuse an unstick — but only if it never wedges you.** The
refusal is honest when the trap is the player's fault (he jumped into a hole, he walked into the
minefield). It is not honest when **the game moved his body there without asking**
(`player.gd:1455`). The player did not put himself in the sandbags. The dismount teleport did.

**And the current escape hatch does not exist for the player who most needs it:**

- The only bound recovery key is **F9 → quickload, `QUICK_SLOT` 0** (`save_manager.gd:68-77`).
  It does nothing unless he had already pressed **F5**.
- On **HARDCORE**, `can_manual_save()` returns `context == "hub"` only (`save_manager.gd:76-82`) —
  **no field save at all.** A wedged hardcore player has *no in-game recovery whatsoever.* Quit to
  desktop is the mechanic.
- Autosave (slot 8, 30 s) has **no bound load key** and will itself capture the wedged state
  within 30 s (`save_manager.gd:23, 60-66`).

**So "reload" is not merely unpleasant — on the difficulty the game is proudest of, it is not
offered.** That is the reload-and-memorise failure Pillar 5 exists to forbid, arrived at from the
one direction nobody was watching.

**What I recommend, and what it costs.**

- **The affordance, tier 1 — free, and it is the r4bk fix regardless of the collision work.**
  Four lines in `field_interact_prompt()`: while `is_climbing`, return
  `"[W] UP   [S] DOWN"` (and at the top of the rail, `"[W] STEP OFF"`); on approach, a
  `[F] CLIMB` gate instead of the auto-seize. The prompt already polls during the climb. **The
  ladder is the only movement state in the game with no line in that function; putting one there
  is the cheapest r4bk debt in the repo.**
- **The abort — small.** Give `stop_climbing()` its first external caller: `jump` or `interact`
  while `is_climbing` drops you off the rail at your current height with velocity zeroed. Costs
  nothing, and it is what every player's hands already expect.
- **The dismount — the real fix.** Shape-cast the player's capsule at `dismount_point()` before
  writing it. On a hit, **do not dismount** — hold him on the rail and say so
  (`"BLOCKED - CLIMB DOWN"`). Refusing to move him is strictly better than moving him into a wall,
  and it needs no new recovery verb.
- **The unstick, last.** With the above three, the ladder stops manufacturing wedges. I would
  still ship a floor-of-last-resort — a held key that re-seats the player on the nearest navmesh
  point after N seconds of zero displacement with movement input held, exactly the ally watchdog's
  own trigger condition (`ally_base.gd:70-83`) — but it is the **fourth** priority, not the first.

**TRADEOFF, named.** An unstick verb is a teleport, and a teleport is an exploit surface: it can
walk a player out of a bunker he was pinned in by fire, out of a minefield, off a tower he climbed
to be trapped on deliberately. It also tells the player *"this game gets stuck"* every time he sees
the prompt. The gating (movement held, zero displacement, seconds of it) is what keeps it honest,
and gating it is fiddlier than the verb. **The cheaper trade is to make the shape-cast good enough
that the unstick never has to exist** — which is why I rank it fourth.

---

## 2 · NPC STACKING — an atmosphere failure, and the worst of the four *seen* items

Three men occupying one body is not a graphical glitch the eye forgives. **It is the single clearest
"this is unfinished software" signal a 3D game can emit**, and it emits it continuously, from any
distance, with no action required from the player. Pillar 2 is atmosphere; a stacked NPC does not
degrade atmosphere, it **cancels** it — for as long as it is on screen, the player is looking at a
bug, not at a firebase.

Three properties make it the worst of the seen four:

1. **Persistence.** A bad Huey dropoff is a four-second beat. Stacking is a *state*; it sits there.
2. **Proximity.** It happens at work points, and work points are inside the compound — where the
   player boots (`demo_game.gd`: seated on the bunk inside `fsb_main`) and spends the first ten
   minutes.
3. **It reads as the engine failing, not the world being poor.** A missing dirt road reads as "not
   built yet." Two men inside each other reads as "this does not work."

The cause is the systems architect's lane; I note only that the exclusivity machinery is real and
is being *worked around* rather than enforced — `heli_lift.gd:310-337` walks a golden-angle spiral
up to 12 times to find a bunk that is `_point_unclaimed()` and off a pad, citing *"his ruling
2026-08-24: one man per work point; the live `firebase_garrison` group IS the claim ledger."* **A
claim ledger that each caller re-implements as a retry loop is a convention, not an invariant.**
That is the shape of a regression that will keep coming back.

---

## 3 · THE HUEY DROPOFF — this is a **first-impressions** moment. It lands at **T+14 SECONDS.**

**Measured, not assumed.** The demo flies its own opening on the arc clock:

```
scripts/levels/demo_game.gd:266-273   AIR_OPENING
    [ 3.0, "huey",    "transit"]     # a pack crosses low
    [14.0, "huey",    "lz_cycle"]    # ← one peels off and PUTS DOWN ON THE PAD
    [26.0, "f4",      "transit"]
    [48.0, "huey",    "transit"]
    [70.0, "skyraider","transit"]
    [95.0, "chinook", "lz_cycle"]    # ← the heavy brings a load in
```

`lz_cycle` → `air_traffic.gd:808-839` → `HeliLift.attach(...)` at `:834`, whose header states the
contract: *"A LANDING SHIP CARRIES SOMETHING… a Huey used to land on the pad, idle out its ground
seconds and leave empty — the ship-gate clause 'Huey landings with troops disembarking' was
scenery."* Ground time is 35 s (`air_traffic.gd:66`), doors open on touchdown as *"the reveal"*
(`heli_lift.gd:277-279`).

**So the dropoff is not a mid-game flourish. It is the SECOND thing that happens in the demo, and
the first thing that happens at ground level near the player.** The comment on the beat table says
it outright: *"The first is at 3 s: the player is still finding his feet on the cot and the sky is
already working."* A second one lands at T+95 s.

**That moves it from "polish" to "the opening shot."** A fresh player's verdict on production
quality is formed in the first ninety seconds, and this is what is in them.

*(**UNVERIFIED:** whether the pad is in the player's line of sight from the bunk at T+14 s. He
boots seated indoors; he may hear it and see it only if he gets outside quickly. That is worth ten
minutes of his eye, because it decides whether this is the opening shot or a missable one.)*

**And I can name one concrete reason it will not match the Blender review, in code:**

```
seat_system.gd:613-636   unseat_all()
    for i in bodies.size():
        ... unseat(bodies[i], _exit_ground(origin + dir * radius))   # ← all in ONE frame
```

Every passenger is unseated in **the same frame**, teleported onto his fan position (up to 7 m out
for a Huey, 11 m for a Chinook), and only *then* plays a disembark clip **in place**
(`heli_lift.gd:336-347`). The men do not walk out of the ship; they **appear** on the apron and
perform a step-off where they already stand.

**The asymmetry proves it was known and only solved on one side:** the same file's `board_squad()`
staggers allies by `BOARD_STAGGER_S = 0.6 s` (`seat_system.gd:158, 641-669`). **Boarding is
staggered. Disembarking is not.** That is very likely the whole of "not as perfect as it was in the
Blender scenes" — in Blender the clips played sequentially out of a door; here six men bloom
outward simultaneously.

*(This compounds the standing `recon-staged-scenes-are-not-clip-banks` trap — the staged Huey
passengers were 5 fcurves each, object transform only, zero bone channels. What he remembers may
partly be a scene that never contained the animation he thinks it did. Both can be true; the
one-frame bloom is measurable in the shipped code today and is fixable independently.)*

---

## 4 · CONVOYS AND ROADS — and the sharpest UX inversion in the build

### The roads are REAL. They have no SURFACE.

`scripts/world/road_network.gd:1` — *"THE ONE ROAD AUTHORITY."* It routes, it seats every point on
the terrain (`:276-277, 304`), it feeds ambush siting (`ambush_planner.gd:52-98`), it feeds the
convoy route (`mission_generator.gd:341-360`), it feeds the player's own field-mark verb
(`player.gd:284-291`), **and it draws itself on the topo map** (`ui/topo_map.gd:155-162`).

And then:

```
road_network.gd:26-28
    The only thing a road writes to the world is VEGETATION: the corridor is thinned…
mission_generator.gd:911-915
    # The only write a road performs: vegetation bundles thinned along the
    # corridor - never height, never terrain_type, never water.
```

**A road in this game is a place where there are fewer trees.** No laterite, no ruts, no ground
texture change, no track.

**Which produces this:** the player opens his topo sheet and sees a road. He walks to where the
road is. He is standing on it. **He cannot see it.** The map is telling him about a feature the
world does not render. That is a *worse* failure than "no roads were built" — an absent feature is
a gap; a mapped feature that vanishes underfoot **teaches the player his instruments lie**, and
this game asks him to navigate by those instruments (ADR-029, no objective counter, no rails).

**r4bk, exactly:** the road system is shipped, wired into five consumers, and **has no visible
affordance in the world.** By the law, it does not exist — and he has just confirmed the law
empirically by playing for weeks and reporting *"i still ahvent seen any like dirt roads."*

**Classification: (c) content never built — but only the SURFACE. The system is (a) shipped.**
This is the cheapest large win in the whole list: one ground-decal / terrain-material strip along
`road_network.segments`, which already exist as seated polylines. No routing work, no new system.

**And in the demo it is one single road.** `plan_demo_world` sets `village_centers` to exactly one
village (`mission_generator.gd:750-752`), and `RoadNetwork.build(gate_pos, village_centers)` runs
at `:646-653` — hub = the wire gate, one spoke. **So the demo's only road runs from the firebase
gate to the one village, ~185 m out** (`mission_generator.gd:743`). Surfacing *that one segment*
would simultaneously (a) give him his dirt road, (b) give the base a visible connection to
somewhere — see §6 — and (c) give the convoy something legible to drive on.

### Convoys

One convoy is scheduled per world, **2 sim-hours out**, on `road_network.longest_route()`
(`mission_generator.gd:259, 338-360`). In the demo that is the gate→village road — the only road
there is — and the schedule fires ~2.4 real minutes in (DAWN sets sim 06:00 at
`mission_generator.gd:247-255`; `DAY_RATIO` 38× at `demo_game.gd:47`). It bails silently if the
route is under two points (`:350-351`).

**UNVERIFIED, and not my lane:** whether vehicles actually instantiate and move. The standing
decision-queue entry *"Convoys spawn with an empty vehicle array, so none has ever moved"* is
exactly this question and should be answered by the systems/programmer lens, not by me.

**My UX judgement on convoys as ambient value per hour of work: LOW, and it is gated behind roads
anyway.** A truck column driving across bare jungle floor reads *worse* than no convoy — it is a
vehicle with no reason to be where it is. **Roads first; convoys are the payoff that makes the road
worth having, not a parallel item.** That ordering is free and nobody has stated it.

---

## 5 · THE RANKING

Player-facing severity. My axis is: **how badly does this damage the player's belief in the
build, weighted by how certain he is to meet it.**

| # | Item | Severity | One line |
|---|------|----------|----------|
| **1** | **Ladder trap** | **RUN-ENDING** | It is the only defect here that **takes the game away from him** — and on hardcore the game offers no recovery at all (`save_manager.gd:76-82`). Everything else is something he *watches*; this is something that *happens to him*. |
| **2** | **NPC stacking** | **CRITICAL — atmosphere** | Persistent, indoors, in the first ten minutes, and it reads as the engine failing rather than the world being sparse. Pillar 2 does not degrade under this — it cancels. |
| **3** | **Huey dropoff** | **HIGH — first impression** | It is the **second beat of the demo, T+14 s** (`demo_game.gd:268`). Six men bloom onto the apron in one frame because `unseat_all` has no stagger while `board_squad` does (`seat_system.gd:613-636` vs `:641-669`). Opening shots are worth triple. |
| **4** | **No dirt roads** | **MEDIUM-HIGH — and cheapest** | The system is shipped and on his map; only the surface is missing (`road_network.gd:26-28`). A mapped feature that is invisible underfoot teaches him his instruments lie. Best value-per-hour on the board. |
| **5** | **Convoys** | **LOW — and gated** | Ambient payoff that is meaningless without §4, and a truck on bare jungle floor is worse than no truck. Do it after roads or not this cycle. |

### What a FRESH PLAYER meets in the first ten minutes

The fresh-player testing law says the dev's memory is a lie about the new player. Ranked by
certainty of contact:

| Certain | Item | When |
|---|---|---|
| ✅ **CERTAIN** | **Huey dropoff** | **T+14 s** — before he is off the bunk. Second beat of the game. |
| ✅ **CERTAIN** | **NPC stacking** | The compound is populated at boot and he wakes inside it. Work points are indoors and on the gun line. |
| ✅ **CERTAIN** | **No road at the gate** | The squad moves out at T+10 s (`demo_game.gd:444`, `"SQUAD MOVING OUT"`); he follows them out of the wire onto undifferentiated ground. |
| ⚠️ **LIKELY** | **The ladder** | Towers are the most legible verticality in a firebase and a new player climbs things. He has no reason to expect the ladder is one-way — **nothing tells him it is** (§1.1). |
| ❌ **UNLIKELY** | **Convoy** | Fires ~T+2.4 min on one road ~185 m out, on a bearing he may not be facing. |

**Four of five in ten minutes.** Note what that means for the pivot debate in §6: **none of the
four is a firebase-geometry problem.** Three are presentation, one is a teleport with no shape cast.

---

## 6 · THE PIVOT, UX LENS — **"it'll look more integrated into the world"**

### Is the kit pivot the cheapest way to buy that feeling? **No. And the reason is measurable.**

He is describing a **silhouette** problem — the base reads as an object placed *on* a world rather
than a place *in* one. So I went looking for the seam he is seeing. **The seam he would have named
is already fixed:**

- The terrain is sculpted to the base's **own mound surface**, point for point, from a manifest the
  exporter writes (`site_planner.gd:962-975`, `FSB_MOUND_MANIFEST`).
- The GLB's own ground plate collider is **deleted**, so the base stands on **one ground**
  (`:1669-1687`, `_audit_one_ground` at `:1690`).
- The authored skirt walks up from **every bearing** at ~5.7° (`:1665-1667`).
- The plateau blends out through a 65 m smoothstep shoulder (`:1655-1657`, `FSB_PLATEAU_FALLOFF`).

**Terrain blending at the base perimeter is not the missing 20%. It shipped, and it took several
passes to get right.** So a kit rebuild would be paying full price for a feeling whose most
obvious cause has already been eliminated.

**What is left, and it is right there in two constants:**

```
site_planner.gd:1061-1063     FSB_CLEAR_DISCS = [ [Vector3.ZERO, 140.0] ]     ← ONE perfect circle
site_planner.gd:1686-1688     modify_terrain(center, 215.0, smoothstep…)      ← ONE perfect circle
```

A **280 m-diameter perfectly circular clearing** inside a **342 m-diameter perfectly circular
flatten**, on a **512 m map**. The base is the bullseye of two concentric discs that cover two
thirds of the world's width. **Nothing in nature or in war produces that shape.** The eye does not
read "a firebase carved out of jungle" — it reads a *stamp*, because it is one. And the treeline
that draws the circle is the base model's own authored cut-over out to ~149 m
(`site_planner.gd:1057-1060`), which means **the circle is drawn twice, in perfect register.**

**That is the "game asset dropped on a map" feeling, and rebuilding the base as a kit does not
touch it.** A kit-built firebase inside the same two circles will read exactly the same way.

### THE 20% THAT BUYS 80% OF "INTEGRATED INTO THE WORLD"

Ordered by feeling-bought per hour. **None of these is a kit, an ADR-041 thaw, or a frozen file.**

**① BREAK THE CIRCLE — lobe the vegetation clear.** *(`site_planner.gd:1061-1063` — the single
highest-value change on this whole board.)* `FSB_CLEAR_DISCS` is a list of `[offset, radius]` pairs
and already supports multiple entries — v1 used five discs, per its own comment at `:1057`. Replace
the one centred 140 m disc with an **asymmetric cluster** — a long lobe out along the gate/approach
bearing (they cleared fields of fire down the road), shallower on the reverse slope, a couple of
offset bites where a fire lane was cut. Same total area, no new art, no heightmap risk. **The
treeline stops being a compass-drawn circle and starts being a shape somebody made for a reason.**

**② SURFACE THE ROAD AT THE GATE.** *(§4.)* The single most powerful "this base belongs here" cue
in the reference photography is the **road running out of the wire.** The road already exists as a
seated polyline from the gate (`mission_generator.gd:646-653`, `road_network.gd:65`). Give the
first 60–100 m of it a laterite ground surface. **A base with a road leading away from it is a
place; a base with no road is a prop.** This also cashes his stated complaint and the convoy in the
same change.

**③ LEAVE THE SILHOUETTE ALONE, DRESS THE TOE.** The mound seam is already correct; what makes a
correct seam still read as CG is that it is *clean*. Spoil piles, stumps left standing inside the
clear, a few fallen logs, tyre ruts and junk scattered across the toe of the mound — **noise on the
line** — is what the eye takes as evidence of work having happened there. Scatter, not geometry;
it rides existing placement systems and needs no export.

**④ BREAK THE PERIMETER'S UNIFORMITY.** One continuous, evenly-treated berm ring is the second
strongest asset tell after the circle. A couple of collapsed/sandbagged/repaired sections and one
over-reinforced corner say "this base has a history." **This one alone is worth a kit conversation
— but it is worth it POST-DEMO**, and ① + ② + ③ buy most of the same feeling first.

**Honest weighting:** ① and ② together are, in my judgement, **the majority of the feeling he is
asking for**, and neither touches `fsb_main_v3.glb`, ADR-041's frozen files, or the demo's pacing
contract. **③ is nearly free. ④ is the only one that genuinely wants the kit — which is exactly
where ADR-041 already put it: post-demo.**

**TRADEOFF, named.** ① risks the sculpt. `FSB_FLATTEN_RADIUS` and `FSB_PLATEAU_FALLOFF` are
load-bearing — the full-seat radius (~171 m) is sized to cover the crater-free guarantee rect whose
corners reach 169 m, and the spawn ring reaches ~252 m (`site_planner.gd:1655-1660, 1686-1688`).
**Therefore: lobe the VEGETATION disc, do NOT lobe the HEIGHTMAP disc.** The eye reads the
*treeline*, not the contour; the contour is where the "two grounds" defect lives and it cost this
project multiple passes to kill. That distinction is the whole safety of the recommendation, and
it is worth stating in the decree in those words.

---

## 7 · TRADEOFFS — what the PLAYER loses if we rebuild the base he has learned by heart

**The pivot's stated benefits are all things the player would *see*. Every cost below is something
the player would *feel* — which is why they are easy to leave out of a plan.**

1. **He loses a base he can navigate without thinking, and this is the biggest one.** Everything
   good in this game happens when the player's attention is on the fight, the squad and the
   treeline. Spatial familiarity is what frees that attention. Playtesting has been buying it for
   weeks — at the cost of the very defects being triaged in this council — and a rebuild spends the
   whole balance on day one. He would come back to the build a tourist in his own firebase.

2. **He loses the pacing contract.** *"All patrol density bands measure from GATE_POS, not the AABB
   center — walking distance is the pacing contract"* (`site_planner.gd:926`). The demo's
   authored sites are bearing-locked off the gate at 185 m / 170 m and the ruins at 140–175 m
   (`mission_generator.gd:735-780`), specifically because *"he woke inside a village hut"* on
   07-29. **Move the gate and every distance in the demo re-rolls at once.** The 30-minute arc is
   tuned against those walks.

3. **He loses the siege's measured geometry.** *"The authored treeline runs out to ~149 m and the
   siege rallies at 150 m"* (`demo_game.gd:296-299`) — the napalm strip at 210 m is placed against
   those exact numbers. A rebuilt perimeter re-rolls the treeline and every figure that was
   measured against it. **This matters doubly given the standing finding that the siege already
   forms up off the 512 m map.**

4. **He loses hand-authored siblings that the current architecture exists to protect.**
   `scenes/world/firebase_main.tscn` was created precisely so hand-placed markers *"live in the
   SCENE, not in the GLB, so re-exporting fsb_main_v3.glb can never delete them"*
   (`site_planner.gd:934-943`) — his own ruling, 2026-07-29: *"give me spawn markers that i can
   place."* **A kit rebuild is the one operation that scene cannot protect against.**

5. **He loses working invariants that took repeated passes to establish**, and each is a defect
   waiting to come back: the mound manifest / ONE GROUND contract (`:962-975`), the measured AABB
   consts asserted by `tools/diag_fsb_seat` (`:928`), `_repair_glb_colliders`, parapet
   destructibles, claymore wiring, siren and ladder marker discovery (`:1700-1712`), and the
   destructible naming contract (ADR-042) that ships a mesh **invulnerable and bulletproof with no
   error** when a prefix is missed. **A kit multiplies the number of meshes that must each get that
   contract right.**

6. **And the cost that decides it: a dead demo in the middle.** ADR-015's gate is an open demo
   playthrough. During a rebuild the base is neither the old one nor the new one, and **the
   playtest — the only instrument that produced these five observations — cannot run.** The five
   things he saw were found by playing. A plan whose first act is to stop him playing is a plan
   that turns off the sensor.

**What the pivot genuinely buys that nothing else does:** per-part work points, animations and NPC
spawn rules travelling with each building — which is the *real* structural answer to §2's stacking,
and to men falling through berms. **That is a good argument and it should be recorded as won.** It
is an argument for building the kit **after** the demo ships, with the demo's base frozen as the
reference the kit must reproduce.

---

## 8 · WHAT I ASK THE COUNCIL FOR

1. **Fix the ladder tonight, and fix all three halves:** the shape-cast before the dismount
   teleport (the trap), the prompt entries in `field_interact_prompt()` (the r4bk debt), and an
   abort key giving `stop_climbing()` its first external caller. **The prompt is not polish here —
   `[S]` is documented and `[W]` is not, so the game currently withholds the key that gets you up
   the ladder.**
2. **Rule on the unstick.** My verdict is **the game owes one**, but as the *fourth* priority
   behind the three fixes above — because the honest version of a hardcore refusal is *"we never
   wedge you,"* not *"we wedge you and you may reload,"* and on HARDCORE he cannot reload
   (`save_manager.gd:76-82`).
3. **Stagger `unseat_all` the way `board_squad` is already staggered.** One timer, opening-shot
   value, `seat_system.gd:613-636`.
4. **Surface the demo's one road.** Highest value-per-hour on the board and it closes an r4bk
   violation that has been shipping for weeks.
5. **Put ① and ② from §6 in front of the kit** — and if the council ratifies the kit in principle
   (it should; §7's last paragraph is right), ratify it **post-demo, with the current base frozen
   as the reference**, exactly where ADR-041 already put it.

**Law 2 — what I am sacrificing.** My whole recommendation trades **structural correctness for
shipping**. Every one of my cheap wins is a *dressing* — lobed discs, a road surface, scatter, a
shape-cast, a prompt line. **None of them fixes the reason men fall through berms or stack on work
points**, and the kit does. If the council takes my ordering, it is accepting that the demo ships
on a firebase whose parts still do not carry their own data — and that the pivot's real bill comes
due later, in full, with interest. **I think that is the right trade because the demo is the
instrument that finds these defects at all. But it is a trade, and it should be spoken.**
