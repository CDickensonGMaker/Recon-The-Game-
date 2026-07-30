# DEMO SHIP BACKLOG — everything between here and a shippable demo

**Opened 2026-07-29** out of the day's playtests. Ordered by the Summoner's ruling:
**allies first, then the air spectacle, then everything else.**

The ship gate, his words: *"More Hueys and jets flying around. At least a few Huey landings
with troops disembarking or unloading supplies. The base attack has parts of the base blow up.
The VC attempt to overrun the firebase."* The demo's job is **scope and spectacle immediately**.

Legend: **[C]** code, I can do it · **[B]** Blender, needs him · **[?]** needs measurement first

---

## A. ALLIES AND THE GARRISON — first

**A1. [C] Ally path failures at 5-8m.** *(fix applied 7/29, unverified)*
`NavRouter` refused to clamp a target further than **4m** off the navmesh and handed the raw
unreachable point to the query - a guaranteed no-path. A garrison post inside a hootch
footprint sits further than that. Clamp limit raised to 12m with a named guard.
**Verify: the `[NAV] ally ... no path` count per boot. It was 8.**

**A2. [?] Whatever survives A1.** If failures persist they are navmesh ISLANDS, not clamping -
the compound fragmenting into disconnected patches. Diagnose with region connectivity, not by
raising numbers.

**A3. [C] Garrison work is invisible at demo open.** Schedules rewritten 7/29 so the night
shift is the busy one (sentry_night on the wire 18:00-05:30, gun crew on the guns, radioman on
the net, quartermaster moving ammo after dark). **Needs his eyes to confirm it reads as a
working base.**

**A4. [C] Off-duty men need somewhere to BE.** *(fixed 7/30, unverified — and it was FAR
bigger than "off-duty sits around")* Seven BT leaves in `civilian.gd`
(`:710/718/726/734/742/750/756`) were **byte-identical freezes**, so twelve scheduled actions
collapsed into four behaviours and only `walk_paddy` ever used a marker. **`ACTION_WORK` never
walked a man to his post — so the entire A3 night shift below never manned anything.** It only
looked right because `place_for_current_hour()` teleports everyone at spawn. `bb["target_pos"]`
was resolved from the 191 markers every sim hour and read by nothing.
`_bt_work` now walks there and holds, with a ±1.5m offset derived from the man's NAME so it is
identical every run (ADR-010). `off_duty`'s 20.5-22.0 block flipped SIT -> WORK: those are the
demo's own opening hours.
**Verify: do the sentries WALK to the wire at dusk, or are they just standing there?**

**A5. [?] Squad members stacking.** The 2-man post overlap is fixed (stations spread by index).
If he still sees two men in one skin it is the follow-slot convergence, not spawn.

---

## B. THE AIR SPECTACLE — the ship gate's biggest item

**B1. [C] AirTraffic schedules ONE transit per sim-hour** off a random kind list
(`_seed_default_schedule`). That is ambient weather, not an opening. Needs a demo-facing
cadence: several airframes up at once, continuous movement on the horizon.

**B2. [C] Huey landings with troops.** `lz_cycle` exists as a profile. He has just built the
landing + load/unload animations, so this becomes: fly in, flare, touch down, men out, lift.
**Ask him for the clip names before building - do not guess them.**

**B3. [C] Jet formations.** `CASAirplane` flies single. A pair or a vic crossing high is pure
silhouette work and cheap.

**B4. [C] Air must not fly through the firebase.** Same class as the convoy (D1): routes are
not aware of the compound.

**B5. [?] Perf ceiling for all of it.** PERF_LEDGER says this project is call-bound. Every
airframe is draw calls. Measure before committing to a count.

---

## C. THE BASE ATTACK — ship gate items 3 and 4

**C1. [?] Nobody has ever seen the sapper detonate.** His ask: a sterile stress room - just
him, three sappers, some wire and sandbags to blow. Answers reach, detonation and destruction
in one test. Parts exist: `ai_stress_arena` pattern, `SapperCharge`, `Destructible`,
`AgentRegistry.props`.

**C2. [C] Parts of the base must blow up.** ADR-031 destruction doctrine and the 80 authored
parapet segments with HP already exist; the wiring to the blast bus is the gap.

**C3. [C] The VC must attempt to OVERRUN, not probe.** *(SHIPPED 7/30, unverified — council
`war_room/2026-07-30_demo_backlog/`)* The stall was never the objective clearing, it was
arithmetic: `combat_goals.gd` scored ADVANCE at most **0.61** for an nva_regular against an
incumbent ENGAGE of **1.19**, so the assault reached the wire and traded shots forever.
Fixed by biasing the GOAL, never the legs — `Context.assault_press` + `PRESS_ADVANCE 0.75`,
rotated over 35% of the assault every 8s by `SiegeDirector._rotate_press`. A pressing man
still shoots, which a leg override cannot do (`assault_driven` returns before the combat
dispatch at `enemy_base.gd:1322` — that is the 7/29 "nobody fought" bug).
**THE LANE IS THE GATE, deliberately.** Nothing re-bakes the navmesh on destroy
(`nav_baker.gd:16-18`) and the barbwire is one merged `bwire_card_ring` of ~450 cards on
three rings (`gen_firebase_v3.py:323-372`), so three impassable rings stand outside any hole
you blow. The gate is the only opening through both, and one lane in 2-5 man rushes is the
doctrinally correct answer anyway. **Nothing in the overrun reads a breach**, so none of it
is blocked on art.
`siege_overrun` fires once at `OVERRUN_MEN 3` measured per-bearing in 36 bins (the parapet
runs 49.3-96.1m, so one mean radius would be wrong on two thirds of the compass) ->
"THEY'RE INSIDE THE WIRE" + siren.
**Verify: do they funnel at the gate and get inside, and does the call fire once?**

**C3b. [B/C] THE REAL BREACH** — replaces the gate-only lane. Split `bwire_card_ring` per
sector in `gen_firebase_v3.py`, re-export, and re-bake nav on `Destructible` death.
**Deletion condition: when this lands, the gate stops being the whole answer.** Costs 36
draw calls where there is 1, on a call-bound project — that is why it was not paid for the demo.

**C4. [C] Siege is on a 600s/720s arc** - too slow to test. A debug trigger exists on `[J]` but
only in debug builds.

**C6. [C] THE GARRISON LIGHTS ITS OWN WIRE.** *(shipped 7/30, unverified)* Illum had only ever
reached the world through the player's own allotment (`_run_illum_mission`, which bills his
stock) or a thrown hand flare. Night sight is **56m open** and the assault crosses from
190-235m, so **the entire overrun happened in the dark** - he would hear it and never see it,
and could not watch it crest or break. New `FieldDirector.garrison_illum(at)` pops a round from
the compound's own tube and **never touches `fire_support` stock**; `SiegeDirector._walk_illum`
puts one up `ILLUM_STANDOFF_M 140` out on the attack bearing, `ILLUM_FIRST_S 12` after
stand-to, then every `ILLUM_INTERVAL_S 70`. Burn is `GARRISON_ILLUM_BURN_S 55`, deliberately
SHORTER than the interval: the ~15s of darkness between rounds is where the dread lives, and a
permanently lit compound is a lit stage. Probes are never lit - holding off in the dark is what
makes a probe read as a probe. Feeds the already-scoped `_light_check()`.
**Verify: does the lit ground show them crossing, and does it go dark again between rounds?**

**C7. [?] ONE SHARED `squad_id` THROTTLES THE WHOLE ASSAULT.** *(found 7/30, NOT fixed - needs a
council ruling, do not improvise this)* `field_director.gd:51` sets
`enemy.squad_id = hash(group_tag)`, so all 45 `siege_assault` men are ONE squad.
`SQUAD_GRENADE_COOLDOWN_MS 12000` therefore allows **one grenade every 12s across the entire
assault**. The structurally correct fix is one squad per `MarchingCell` (the class docstring
already calls a cell a fireteam) - but `squad_id` is also read by
`EnemySquad.has_covering_fire` (every man currently always has it, worth +0.2 ADVANCE),
`force_ratio`, and `is_broken` (the whole assault currently breaks as one body, alongside
SiegeDirector's own separate ledger), and `spawn_tracked_enemy:56` has already registered the
contact ledger under that id. Changing it moves four systems at once.

**C5. [C] THE DEMO'S NIGHT ASSAULT HAD NEVER HAPPENED.** *(fixed 7/30, unverified)*
`demo_game.gd:29` declared `SIEGE_STRENGTH 40`, but at 720s `_open_siege` hit the
`if d.siege.active` guard (`:197-203`) and emitted a toast. The 600s probe was still active
**and always would be** — its `MAX_DURATION_S 480` expires at exactly `DAWN_AT_S 1080` — so
that branch was taken every single time. **Every demo night ever played was 11 men,
announced twice.** New `SiegeDirector.reinforce(extra)` grows `run_strength` AND `run_peak`
together (strength alone puts live/peak above 1.0 and the break can never fire; peak alone
credits kills the player never made). `SIEGE_STRENGTH` is now **45 TOTAL**, not an increment:
`LIVE_CAP` is 50 and an assault authored at the cap freezes its late cells at the ring, the
2026-07-28 trickle failure.
**Verify: `[Siege] reinforced +34 - the assault is now 45 men` at 720s.**

---

## D. WORLD AND VEHICLES

**D1. [C] Convoys drive through buildings.** *(two real defects fixed 7/30, unverified; the full
routing job DEFERRED - and this item's original diagnosis was WRONG)*
Routing already exists: `mission_generator.gd:337-342` uses `road_network.longest_route()` and
refuses to spawn without a road. But `build(gate, villages)` makes the **gate the hub and
villages the spokes**, so there is **no map-edge road** and a convoy drives OUTWARD from the base
into a village.
**Fixed 7/30 — the column was born in the buildings.** `convoy_spawner.gd` strung vehicles
2..N straight back along `-heading` from `route[0]`, a line through whatever happens to be
there: six vehicles at 6m reaches 30m behind the start, and when the start is the wire gate
those trucks stand INSIDE the compound. They now occupy the first stretch of their own route by
ARC LENGTH (`_seat_along_route`), lead furthest along, so every vehicle begins on the surveyed
line.
**Fixed 7/30 — the column crabbed.** `convoy.gd` never touched rotation after spawn, so every
vehicle held its spawn yaw through every bend. Now `_face_along` lerps yaw toward the direction
of travel at `TURN_RATE 3.0`, using the same `atan2(x, z)` the spawner seats with so spawning and
driving agree.
**Still open:** no map-edge road (routes end at a village centre), trucks collide with nothing,
`road_network.gd:155-171` reads only terrain type + slope on a **12m** grid cell so a hut is
smaller than one cell and this router can never miss a building. Driving a road properly is one
session; driving through the gate is multi-session (interior routing through `-colonly`
trimeshes + a motor-pool datum). Largely invisible in a 512m firebase-holdout slice.

**D2. [C] Spooky keep-out.** Done 7/29 - ambient gunship orbit pushed 420m off `fsb_center`
after it strafed the player's own compound. Verify it never recurs.

**D3. [C] Ambient war audio.** *(fixed 7/30, unverified)* Ruled **FASTER**; "less occurring"
rejected. `_spawn_audio` called `play()` ONCE per event and `lifetime_s` only decided when the
finished node was freed — **a whole distant engagement was one gunshot.** Now two parties
15-40m apart ANSWER each other, each retriggering its own voice: 3-8 rounds at 0.11s (MG 6-14
at 0.075s), then a 2-6s lull, going ragged in the last quarter. Low-passed at 900Hz — past
400m a rifle has no crack, only a slap off the treeline. Lifetime 5-30s -> 14-40s (5s cannot
hold a rhythm). `FIRE_CAP 2`, and a held engagement PRINTS that it was held.
Also adopted the 7/27 pack: it was still using the generic `shot_distant.wav` for every gun in
the war while a measured `fire_<id>_dist.wav` existed for all 17.

---

## B6-B7. THE AIR, 7/30

**B6. [C] Spooky's vulcan fires REAL ROUNDS.** *(shipped 7/30, unverified)* It used to pick a
ground point, paint three decorative tracers at it and apply a small explosion there — the
tracers carried no damage and a man behind the berm was spared by a visibility guess instead of
by the berm, while the same aircraft's Bofors fired real arcing shells. Now per PHYSICS TICK,
3 rounds = 90/s: slant range √(160²+130²) = 206m at 1030 m/s = 0.20s flight = ~18 rounds in
the air, so `MAX_BULLETS 500` is nowhere near binding. 90/s is for the ROPE — a streak is
speed×0.016 = 16.5m, at `tracer_ratio 2` that lights ~148m of the 206m line. Duty 2.0s hot /
2.5s cold. Dispersion preserved by re-aiming a fresh `_zone_point` each tick, NOT by weapon
spread: the fake 25m disc was 25× the area of a 1.4° cone at 206m and losing it would make the
gun read as broken. KEPT: suppression (BulletSystem suppresses nobody — the fake explosion was
this gun's only source) and the report on its own 0.35s clock (`_play_gun` reuses ONE voice).
**ADR-023, same change:** `scripts/combat/bullet_tracer.gd` DELETED (only caller repo-wide),
`VULCAN_DAMAGE`/`_INTERVAL`/`_ROUNDS_PER_BURST`/`_vulcan_timer` gone,
`FirePlan.SPECTRE_VULCAN_KILL_M` -> `SPECTRE_DISPERSION_M` (it could not just die,
`fire_plan.gd:58` draws the map ring from it). New `BulletSystem.fire(..., mark_surface := true)`
— `GunFX` recycles holes FIFO at `MAX_DECALS 48`, so 90/s would erase every player bullet hole
twice a second.

**B7. [C] AIR CAN KILL YOU — and never aims at you unless you ask.** *(shipped 7/30,
unverified)* **`STRAFE_MASK = 1|32|64|512` includes the PLAYER HURTBOX and every ALLY** (layer
32, proven at `projectile_base.gd:111` and `ally_base.gd:441-442`) while its own comment called
bit 32 "enemy bodies". 87 × TORSO 2.5 = **217 vs 100 HP — one round, instant death.** Shipped
7/29 and never playtested, with scripted demo gun runs at 2:40 and siege+60s.
**His ruling 2026-07-30:** *"i want to be able to be killed by the air but i dont need a
warning. but also dont deliberately gun run where the player is unless they call in a danger
close run."* So the mask STAYS lethal and there is NO warning. The discipline is in AIMING:
`authored_strike(..., danger_close)` requires a gun run's beaten path to miss him by
`GUN_STANDOFF_M 120`, rotating through 12 bearings, then dropping guns (keeping napalm) or
refusing the run. `[G]` passes `danger_close = true` — pressing it IS calling it in, and the
axis he chose must fly or the key is useless for tuning. `AirTraffic` now keeps ambient Spectre
orbits off **the player**, not just his base.

## E. ART AND MATERIALS — his side

**E1. [B] Ten materials on default white, no texture.** Named by the boot probe:
`Walnut`, `Walnut.001`, `.003`, `.004` (Ithaca 37 furniture, M79 stock, M70 sniper stock),
`MitchellCamo` + `Webbing` (helmet shell, EVERY body), `bandolier_tex`.
**The `.00N` duplicates are separate slots - fixing "Walnut" alone misses the sniper and shotgun.**

**E2. [B] Firebase re-export** picks up four already-fixed generator changes: mound plate
collision off, parapet to trimesh, five merged veg objects to trimesh, mound manifest.
See `production/blender/FIREBASE_BLENDER_HANDOFF.md`.

**E3. [B] Fire slits + bunker embrasures.** Handoff §2.

**E4. [B] The fighting step.** Parapet top is 2.39m against a 1.6m eye, and the berm crest is a
knife edge with the wall on it. Spec with numbers in handoff §2b. **This is the "stuck in the
dirt mounds" report.**

**E5. [B] `Base_Human` out of the US body export** (or renamed `grunt_base_human`). Patched in
code; the special case deletes itself once the export lands. Handoff §5.

**E6. [C] Skin/face mismatch.** Fixed 7/29 - the dresser now slides every surface that samples
the face atlas, matched by TEXTURE not by material name, so face and body can never diverge.
Warns loudly if a body carries skin that is not on the atlas. **Needs his eyes.**

---

## F. THE MAP

**F1. [C] M opened nothing.** Fixed - the control's rect was 0x0 so the bottom-right-anchored
sheet drew off-screen. Boot now warns if the rect is ever too small for the sheet.

**F2. [C] Only right-click places marks.** *(fixed 7/30, unverified — and the CODE corrected
the report)* Left-click was never fighting the order circle: off a circle it did **nothing**
(`topo_map.gd:376-380`). The map's main verb was simply on the button nobody reaches for first.
**LEFT is now the pencil** — a circle is a small hotspot and still takes a left click, so they
cannot compete for a pixel — and **RIGHT is the eraser**, which the sheet has NEVER had; marks
went on and stayed forever. New `MissionState.erase_pencil_mark_near`, 45m grab radius. The
grease-pencil law forbids the GAME erasing a mark; it says nothing about the player.

**F3. [?] The note verb is not intuitive.** His ask: **research how Arma does its map** and
learn from it before redesigning. Not started.

**F4. [?] Held-object map in the player's hand.** His design question - a flat plane in the
hand with the live sheet on it, versus the current screen-space corner draw. Deferred by him.

---

## THE INSTRUMENTS BUILT TODAY — keep them, they earn their keep

Each of these turned a playtest complaint into a named line in the log:

- `[FSB] one ground` - terrain vs the authored mound, warns past 0.6m
- `[FSB] N collider(s) floating >3m` - caught the four invisible veg slabs
- `[MODEL] renders N body-sized meshes` - caught `Base_Human` inside every soldier
- `[MODEL] N surface(s) left on DEFAULT WHITE` - named all ten white materials
- `[DRESSER]` stranded-skin and missing-stock-helmet warnings
- `[TOPO]` rect-too-small warning
- `[FSB] stand to: promoted N` - the garrison question, answered every boot
