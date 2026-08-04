# DEMO SHIP BACKLOG — everything between here and a shippable demo

**Opened 2026-07-29** out of the day's playtests. Ordered by the Summoner's ruling:
**allies first, then the air spectacle, then everything else.**

The ship gate, his words: *"More Hueys and jets flying around. At least a few Huey landings
with troops disembarking or unloading supplies. The base attack has parts of the base blow up.
The VC attempt to overrun the firebase."* The demo's job is **scope and spectacle immediately**.

Legend: **[C]** code, I can do it · **[B]** Blender, needs him · **[?]** needs measurement first

---

## AUDIT 2026-07-31 — SIX ITEMS BELOW ARE ALREADY BUILT. READ THIS FIRST.

I came here to build the air spectacle and found it shipped. Every line below is verified against
code, not against this document. **Do not build these again** — that is the divergent-systems
failure, and this backlog is currently the thing causing it.

| Item | This doc claims | The code says |
|---|---|---|
| **B1** air cadence | "schedules ONE transit per sim-hour" | `TRANSITS_PER_HOUR = 3` (`air_traffic.gd:62`), across 18 daylight hours |
| **B3** jet formations | "`CASAirplane` flies single" | `FORMATION_SIZES` (`air_traffic.gd:39`) — 6-9 Hueys, 3-5 jets, 2 skyraiders |
| **B4** air over the firebase | "routes are not aware of the compound" | `TRANSIT_KEEP_OUT_M = 150` (`:284`, applied `:294-304`), `SPECTRE_KEEP_OUT_M = 420` (`:226`, applied `:416-419`) |
| **B2** Huey landings with troops | "becomes: fly in, flare, touch down, men out" | `HeliLift.attach(heli, _friendly_director())` at `air_traffic.gd:544`, with the full inbound/ground/climbout/outbound cycle at `:518-570` |
| **C1** sapper stress room | "his ask: a sterile stress room" | `scenes/levels/sapper_room.tscn` + `scripts/levels/sapper_room.gd` exist |
| **C2** base must blow up | "the wiring to the blast bus is the gap" | The bus is wired: `combat_manager.gd:178` sweeps `AgentRegistry.props` on every explosion, `game_flow.gd:208-254` picks a LIVE parapet segment off it, `sapper_charge.gd:86` the same |

**So the demo's remaining bottleneck is NOT code.** Nearly every item on this list is *built and
unverified*, and unverified is discharged only by HIS playtest (ADR-015) — never by a probe and
never by an agent's reading. The verify lines under each item below are the actual work.

**C7 IS BUILT — HE BUILT IT HIMSELF**, commit `09cd39bf` (2026-07-30 18:27, "Four squads that flank,
not one mass that doesn't"). `siege_director.gd:285-340`: `ASSAULT_SQUADS = 4`, each with its own
`siege_assault_%d` tag and therefore its own `squad_id`, spread over `SQUAD_SPREAD_DEG 150` of arc,
with squad 2 held back as a base of fire at `SUPPORT_STANDOFF_M 90`. The reinforce path splits too
(`_build_assault(extra)`), which is the path the demo actually takes to full strength. **Do not
build this. It is the SEVENTH item this document has claimed was open while it was already
shipped** — I asked him to rule on it and he had already coded it.

**Genuinely still open:** C3b (needs his Blender) · D1's remainder (no map-edge road) · C4 (the
siege trigger is `OS.is_debug_build()`-gated at `game_flow.gd:50`, so it does not exist in a shipped
demo build).

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

**C7. [C] ONE SHARED `squad_id` THROTTLES THE WHOLE ASSAULT.** *(found 7/30 — **HE HAS RULED,
2026-07-30, restated 7/31**: "there should be four squads with the enemy assault teams and they
should all be trying to flank and maneuver to get into the firebase and not just one large thought
bubble." The DECISION is closed; only the scope below was ever open. Do not re-ask it — this
document saying "needs a council ruling" is what caused it to be asked twice.)* `field_director.gd:51` sets
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

---

## 2026-07-31 WAR ROOM AUDIT POINTER
Full audit (demo vs full game, ship verdict) decreed at
`production/war_room/2026-07-31_demo_ship_audit/synthesis.md` (evidence + debate alongside).
Verdict: shippable by 8/9 IF export preset + playthrough #1 land by Mon 8/4.
Week plan: W1 export/launch → W2 death-path freeze → W3 end card → W4 boot gate → W5 M60 →
W6 furnish interiors → W7 garrison ceiling (measure once) → W8 SimClock air dedup → W9 M79.
His bench: S1 wire-ring split, S2 medical_complex export. All else WAIVED (costs named in discussion.md).
AMENDMENT 7/31: Summoner revoked the D8 waiver — bunkers must be shootable-through. Added as S3
(embrasures + fighting step, his Blender, recipe in blender/FIREBASE_BLENDER_HANDOFF.md §2/§2b/§2.5,
fold into the S1/S2 re-export). AI-manned bunker positions stay deferred.
UPDATE 7/31 (evening, Wyrm): W1-W9 DISCHARGED except two that closed differently.
- W1 SHIPPED: build/RECON_Demo.exe exists (first export in project history; templates were
  never installed). "Windows Demo" preset, custom feature "demo", run/main_scene.demo override.
  Smoke-verified in RELEASE: boot -> probe(11) -> 4-squad(45) -> unattended player KIA at 70s
  -> end card. Zero script errors.
- W2/W3 SHIPPED: KIA routes to a shared pausable end card (RESTART/QUIT, mouse freed);
  double-siren fixed (reinforce announces only probe->assault). ROOT FIX: world is now
  PROCESS_MODE_PAUSABLE - tree-pause NEVER froze the war before, in the full game either.
- W4 SHIPPED: no more double world-build on demo boot.
- W5 -> HIS BENCH: M60 reaches the demo via the MG emplacement (cannot pull); hip_position
  fix is a bench-eyes job. NEW PLAYTEST ROW: man the MG, check where rounds land.
- W6 CLOSED INVALID: interiors are NOT empty - 178 baked props confirmed in the release log
  ("[FSB] 178 interior prop(s) culled past 40m"). Furnishing would DOUBLE them (doc §5 was
  right; the audit scout was wrong). HeliLift also ran live: "[LIFT] delivered 4 - 28/28".
- W7 MEASURED AND SET: FSB_GARRISON_MAX_MEN 24->40, FSB_WORK_POST_CAP 12->24.
  A/B on the exported demo (--print-fps, 150s): mid-siege 48.0 FPS at BOTH values.
  TRADEOFF NAMED: 40 defenders vs 45 attackers may soften the overrun drama - if holding
  feels safe now, dial back toward 28-32. Playtest row.
- W8 SHIPPED: SimClock dedup key now per-entry (3 transits/hr were collapsing to 1) and
  air books day=-1 (the sky died at the first midnight rollover).
- W9 SHIPPED: m79_arms_viewmodel.tscn + model_path - the Blooper is a whole weapon now.
REMAINING FOR 8/9: his bench (S1 wire split, S2 medical export, S3 bunker slits), his
45-min playtest on build/RECON_Demo.exe, M60 bench row, playthrough #2 on the polished build.

---

# AMENDMENT 2026-08-03 â€” THE DAY RESCOPE (War Room decree)

**Decree:** `production/war_room/2026-08-03_demo_day_scope/synthesis.md`. Six architects, code only.
The Summoner rescoped the demo from the 7-minute night slice to a **~30-minute one-day arc ending
with the night attack**. His ten rulings are recorded in that session's `briefing.md` Â§0 and are
DECIDED â€” do not re-open them.

**READ BEFORE COSTING ANYTHING:** this backlog was spot-checked 5/5 HONEST by the Devil's Advocate
(C4 `game_flow.gd:50`, C3b `gen_firebase_v3.py:368`, A1 `nav_router.gd:37`, E5 `model_actor.gd:546`,
W7 `site_planner.gd:853`) â€” **but it stops at 7/31.** No chow hall, no tiered expansion, no rescope.
Every estimate drawn from it **UNDER-counts**.

## D-0. MEASUREMENTS FIRST â€” these gate the build, nobody has ever run them

| # | Measurement | Gates | Note |
|---|---|---|---|
| **M-1** | `tests/test_firebase_garrison.tscn` then print the occupation histogram from `fsb_garrison_plan`. **FAIL = a wall of `off_duty`.** GLB markers carry Blender's DOT suffix (`work_rest.001`); `site_planner.gd:905-909` strips only `_<int>`. If the dot survives import, **~185 of 198 markers are junk** and the aid-station seed (`:969-978`) + litter team have **never fired**. | every chow-hall and medical decision, and the whole marker convention | **HIGHEST-VALUE HOUR AVAILABLE. RUN IT FIRST.** |
| **M-2** | `build/RECON_Demo.exe --print-fps`, A/B/A at `SIEGE_STRENGTH` 45 â†’ 55 â†’ 45, 300s each. **FAIL if run B prints `[Siege] cell of N held at the ring` (`siege_director.gd:445-446`) at all, or ends with no `_break_siege`.** | D-1 and D-9 | prior: FPS moves ~0 |
| **M-3** | Run the exported demo **30 minutes** with `--print-fps`, watch draw calls | D-2 | nothing has EVER run 30 min |
| **M-4** | Count squad arrivals at the gate on a T+10 move order, 10 runs | D-4 | pathing risk |
| **M-5** | Time a Huey from launch-on-pad to clearing the compound | D-6 | no launch path exists |

## D-1 â€¦ D-2. THE TWO LANDMINES â€” defuse before anything ships

- **D-1 [C] THE ONE-WAY FREEZE LATCH â€” the 7/28 trickle failure, still loaded.**
  `_enforce_live_cap` calls `set_physics_process(false)` (`siege_director.gd:444`) and
  **`set_physics_process(true)` exists NOWHERE** in `marching_cell.gd` / `siege_director.gd`. A
  frozen cell never marches again but still reports full paper strength (`marching_cell.gd:56-57`),
  so `live/peak` never falls and **the assault can never break.** `SIEGE_STRENGTH = 45` is the only
  thing disarming it. **DECREED: the day may move night strength DOWN from 45 and NEVER up. The
  Arbiter's proposed 55 is STRUCK â€” it arms this on the worst-outcome branch.**
- **D-2 [C] DROPPED WEAPONS SPAWN FIRST-PERSON VIEWMODELS â€” the largest unbudgeted accumulator.**
  MEASURED: `ak47.tres:27` points at `ak_fp.glb` = **11 draw calls, 1 skin, 6 anims, `ArmsMesh`**,
  offset âˆ’1.81m (buried underground). `LIFETIME_S = 600` has **never once expired** in a 7-minute
  demo and **resets to 300s whenever the player is within 40m** (`world_weapon.gd:87-94`). 45
  attackers dying on the wire the player is standing on is **~495 immortal draw calls** against a
  ~1,350-call baseline. Secondary: `EnemyBase.unreported_corpses` is unbounded (`enemy_base.gd:961`,
  appended `:1011`), scanned by every unit every heartbeat (`:804-807`, `:1022-1031`), cleared only
  at world build. Decals, corpse meshes, evidence ledger and flight bookings are all **bounded â€” do
  not spend time there.**

## D-3 â€¦ D-10. THE ARC

- **D-3 [C] THE CLOCK: day 38x, night 20x. Start 06:30, NOT 07:00.**
  **0700 does not exist in code** â€” `mission_weather.gd:40` holds {5.5, 10.0, 17.5, 21.0} and wins
  over `mission_generator.gd:248-255` via `game_flow.gd:677-679`. **THE SUN DOES NOT MOVE**
  (`mission_weather.gd:20-25`, `:77-83`): lighting changes only on a period crossing, and DAY is one
  flat block 07:00â€“17:00. So the arc is sold as **four lighting events, one per act** â€” spawn in
  dawn, DAY snaps as you clear the gate, DUSK on the return, NIGHT at stand-to. **The night must run
  SLOW**: crossing midnight re-arms a second siege roll (`siege_director.gd:171-174`), unlatches the
  fire-support allotment (`field_director.gd:1240-1245`) and **raises the sun mid-attack**.
  Sacrificed: the DAWN end card, and `AmbientWar`'s hour-driven density (`ambient_war.gd:62`).
- **D-4 [C] THE OPENING: the squad walks out without you at T+10s.** There is no gate pointer in
  code. Use `OrderMode.MOVE_TO` (`ally_base.gd:160`, `:206`; `squad_system.gd:201-205`) to
  `patrol_gate_pos` (`field_director.gd:991`), rendered by the squadmate labels already exempt from
  the no-rails ruling (`mission_hud.gd:336-368`). **Respects the ADR-030 HUD deferral â€” no new UI.**
  The order MUST expire at the gate. Gated on M-4.
- **D-5 [C] THE AMBIENT CELL â€” ruling 9 is structurally impossible today.** The hunt net is
  double-gated: it needs a COMBAT contact (`field_director.gd:113-119`) AND a non-empty evidence
  ledger fed only by player gunfire (`:35-38`, `:143-145`), then waits 70â€“110s (`:118`). Ship ONE
  cell walking a road between village and camp, spawned at boot, crossing the player's front at
  ~2:45 â€” let-pass-or-shoot. **Three hard constraints:** the road must stay **>90m from
  `fsb_center`** or `_poll_firebase_threat` (`:1328`, `FSB_THREAT_MEN` 2) stands all 40 men to at
  07:05; `last_combat_contact_ms` is a **global static** (`enemy_base.gd:272`) so any enemy going
  loud fires a false "YOU'VE BEEN MADE"; tag it `"hunters"` so D-9 folds it in.
- **D-6 [B]+[C] MULTI-PAD: the code is built, THE PADS ARE NOT.** `_free_pad` already walks all pads
  at capacity 1 (`air_traffic.gd:467-515`). **MEASURED twice independently: the shipped GLB has ONE
  pad â€” all three pad-prefix nodes sit at the identical position (22.18, 4.01, âˆ’41.29).**
  `air_traffic.gd:54` ("three PSP pads") is **DRIFT â€” correct the comment.** Priced: Huey = **27
  draw calls**, Chinook = **84 calls / 12,028 tris**, baseline ~1,350 where 1,000 calls is ~6 FPS
  (`PERF_LEDGER.md:686,700`). **RULED: ONE new pad marker (two total), two concurrent cycles max,
  Chinook never concurrent.** **BUG:** `_dispatch` checks the ceiling once before the lead (`:328`)
  then adds 8 wingmen unchecked (`:343-349`) â€” up to 22 airframes, +44% calls. **AND no heli ever
  starts ON a pad** â€” every `lz_cycle` begins airborne ~280m out (`:536-540`), so his "birds lifting
  as he turns the corner" needs a launch path that does not exist. Gated on M-5.
  **The rescope's real frame cost is DAYLIGHT, not men:** `air_traffic.gd:93-108` books hours 6â€“23,
  so a day demo fires **~39 transits + all 4 LZ cycles versus today's ~18 + 1.**
- **D-7 [C] THE MIDDAY RETURN IS STRUCK. The chow hall moves to 21:30, before stand-to.** The return
  fires the after-action report the demo EXCLUDES (`field_director.gd:1564-1578` vs
  `demo_game.gd:20`) â€” debrief toasts and a possible FIELD PROMOTION â€” and `_bank_patrol` resets
  `state.start_time_ms` (`:1584`), **making the afternoon easier.** Sacrificed: the two-sortie
  structure.
- **D-8 [C] THE VILLAGE IS MOSTLY BUILT.** Civilians exist (`civilian.gd`, 38 KB, behaviour trees +
  SimClock schedules + households); the informer path is real (`civilian.gd:582-594` to
  `field_director.gd:627-641`). **The gap is a coin flip** â€” `mission_generator.gd:979` gives the
  demo village a ~50% chance of an informer existing at all. **RULED: force it to 100% in the
  demo.** Also **first-signs are TWO DISABLED LINES** â€” the planner already places them at 150â€“300m
  (`:496`, consumed `:765-769`); the demo ships zero (`:723-724`). And **the enemy camp is a PLAN
  EDIT** â€” the stamper is built (`site_planner.gd:1629`, dispatch `:761`), the demo just disables
  camps (`mission_generator.gd:740-741`).
  **THE DESTRUCTIBLE TUNNEL MOUTH IS ALREADY SHIPPED â€” ZERO ENGINEERING COST.** HOLD-interact
  satchel, grenadier-skill hold time, blast, nav re-bake, cross-patrol permanence
  (`player.gd:838-891`, `campaign_state.gd:478-490`, consumed `site_planner.gd:195-202`); **both
  stampers already place one** (`:258`, `:1632`). Only remaining: confirm the demo loadout carries a
  satchel (`player.gd:843`), and discoverability.
- **D-9 [C] DAY FEEDS NIGHT, DOWNWARD ONLY.** `night = 45 âˆ’ hunters_killed âˆ’ 8 (mouth blown)`,
  **clamped 28â€“45.** **Never price it off `state.kills`** â€” the bank wipes it
  (`field_director.gd:1584`). **Hunters are never reaped** (`siege_director.gd:712-716` walks only
  siege cells) â€” clear survivors with `despawn_tracked_enemy` (`:72`) at stand-to, **as a despawn,
  not a casualty.** **A BODY COUNT IS IMPERCEPTIBLE** (night sight 56m, the assault crosses
  190â€“235m, illum strobes 55s on / 15s off) â€” so express it in three places, none of them a number:
  the RTO's gate line (`field_director.gd:667-673`), a **BREACH or no breach** (the siren is already
  wired), and the end card (`demo_game.gd:331-359`). **IF ALL THREE ARE NOT BUILT, DO NOT BUILD THE
  LINK** (r4bk Law).
- **D-10 [C] TOP THE HUNT POOL TO 6 ON EACH OUTBOUND GATE CROSSING** (same seam as the fire-support
  grant, `field_director.gd:1221`). 12 men (`:106`) at 2â€“4 per wave (`:149`) is **~7.7 minutes of
  contact, then the AO is empty forever** â€” invisible at 7 minutes, arc-breaking at 30.
  **SACRIFICED: ADR-035's finite-pool promise, inside the demo only, by documented exception. The
  ADR is NOT amended.**
  **QUESTION D IS CLOSED â€” the Arbiter's premise was BACKWARDS.** `field_mult` multiplies the WAIT
  (`field_director.gd:148`, its own comment `:129`), so decay makes the AO HARDER; and it never runs
  at all because `state` resets at every wire crossing (`:132`, `:1584-1587`). **Do not invert it.
  Do not flatten it. Leave it.**

## D-11 â€¦ D-13. FIRE SUPPORT, ALLIES, FAIL-FORWARD

- **D-11 [C] THREE CALLS = THREE DIFFERENT VERBS: one bombing run, one artillery, one mortar.**
  "3" matches nothing shipped â€” the grant is **5â€“8** (`field_director.gd:1251-1255`: up to 3â€“4
  mortar + 1 bomb + 1 arty + 2â€“3 illum), and the demo actually runs the class default `mortar 2,
  illum 2` (`:304-305`) because `demo_game.gd` has **zero** fire-support references. **Three defects
  to fix alongside it:** **illumination has NO menu row** (`mission_hud.gd:97-104`) though key 7 is
  bound (`:243`) â€” **a shipped r4bk violation**; `_granted_day` (`:1243`) lets a post-midnight 120m
  step **re-arm mid-siege** (D-3's slow night prevents this incidentally â€” make it structural); and
  `p["fire_support"]` (`mission_generator.gd:509`, `:675`) is read by nothing, with ADR-011's
  pointers all stale.
- **D-12 [C] ALLY AI TO THE VIETCONG BAR â€” minimum set, in cost order.** The Arbiter's five verified
  pointers all HOLD (`ally_base.gd:78-117`, `:233-235`, `:395-409`, `:97`). **Scope correction: the
  squad is 8, not 5** (`squad_system.gd:19`).
  1. **~2 lines â€” feed `squad_broken` / `force_ratio` to the shared scorer.** Allies never do
     (`ally_base.gd:782-801`); the enemy does (`enemy_base.gd:1408-1409`). The squad-break toast is
     a cheque the AI does not cash. *Sacrificed: the squad will visibly leave you at the climax.*
  2. **~6 lines â€” MOS-weighted courage.** MOS is read **NOWHERE** in the AI (one hit, and it is a
     comment, `ally_base.gd:166`); courage is a flat `randf()` (`:296`), so **the RTO plays hero
     ~25% of the time** and skips the cover trip (`:109`). *Sacrificed: a 10m radio leash dragging
     the player backward.*
  3. **~12 lines + a look-check â€” A CONCEALMENT TERM. THIS IS THE VIETCONG GAP.**
     `_find_cover_point` accepts a position only if a physics ray is BLOCKED
     (`ally_base.gd:1298-1303`), and grass/fern/bush have **no collider by contract**
     (`tree_cover_layer.gd:17-19`). **But the simulation ALREADY rewards the grass** â€” vegetation
     cuts sight (`sight_cap.gd:32-39`) and heavy jungle blocks LOS 30% per cell
     (`gameplay_grid.gd:406-411`). **The AI cannot see a reward the sim is already paying. One O(1)
     grid read.** *Sacrificed: your own men vanish into grass â€” check the squadmate nameplates in
     the same session.*
  4. **~15 lines â€” make the grenadier's cluster thumper PLAYER-PLACED** via the existing
     `squad_move` aim. **THE VIETCONG INSIGHT, MEASURED:** the squad owns five verbs â€” trap-spot,
     call-for-fire, player-revive + bandages, sustained fire, cluster thumper â€” and **four of the
     five are AUTOMATIC**, which is precisely why only the radio's loss is ever felt. This converts
     one. *Sacrificed: an r4bk debt â€” a bound key with no HUD, taken knowingly.*
  **CUT FOR THE DEMO, ON THE RECORD (not dropped quietly):** downed allies (see Q9), and the 70m
  trunk-collider ring â€” colliders exist only within 70m of the **player**
  (`tree_cover_layer.gd:34-43`), so allies further out have **zero cover at all**.
  **LOGGED:** MARKSMAN has a weapon and a body but is absent from `MOS_ORDER` (`squad_roster.gd:64`)
  â€” **it never spawns.**
- **D-13 [C] FAIL-FORWARD ALREADY EXISTS AND IS COMPLETE** (`squad_system.gd:224-345`,
  `health_system.gd:248-286`, 6 bandages `:10`). **Ruling 7 needs no build.** Two contradictions sit
  inside it instead, both for the Summoner: `revive()` restores **FULL HP**
  (`health_system.gd:276-278`, his 7/18 decree) versus his 8/3 "come back degraded" (**Q3**); and
  **the headshot BYPASSES the revive window entirely** (`:203-208`) â€” one round at minute 22 costs
  22 minutes, and the only button is `reload_current_scene()` (`:362`). **Ruling 6 (no save) and
  ruling 7 (fail forward) collide at exactly this one code path** (**Q2**).
  **THE RTO QUESTION HE LISTED AS OPEN IS ALREADY ANSWERED BY THE CODE:** the calls stop totally and
  permanently â€” `member_by_mos` skips dead men (`squad_system.gd:168`), `_radio_check` needs a living
  RTO within 10m (`field_director.gd:654-663`), and the player is kicked off the net that frame
  (`:257-268`); with no downed state, "goes down" and "dies" are the same event. The real question
  is whether total deletion is the right punishment (**Q4**).

## D-14. CHOW HALL / FIREBASE EXPORT â€” the blocker is older and bigger than reported

The Arbiter's finding **STANDS**: `tools/gen_firebase_v3.py:912`'s default is **CORRECT â€” DO NOT
REPOINT IT**; `:1104` is **confirmed still stale**. **But that was never the real blocker.**
**MEASURED: `fsb_main_v3.glb` is dated Jul 26. It contains zero `WB_chowhall`, zero `work_eat` â€” and
ZERO `WB_medical`. The recovered medical complex has never once been in the running game.**
**TRAP:** exporting the chow hall as-is **silently steals garrison men** â€” 40 unknown `work_*` types
enter the fixed 23-man round-robin (`site_planner.gd:936`, `:992-1008`) as `off_duty` statues on the
mess benches. **Exclude the chow families from the garrison rotation before exporting.**
**Gated on M-1** â€” if the dot suffix survives import, the whole marker convention is the bug.

## D-15. THE DECISION QUEUE â€” blocked on the Summoner

Ten questions, glossed in plain words, at `synthesis.md Â§7`. **Q1** what the demo ends on now that a
true sunrise costs three exploits Â· **Q2** should the helmet save you once from a headshot Â· **Q3**
full health or degraded after a revive Â· **Q4** can the radio be picked up off the RTO's body Â·
**Q5** how many landing pads Â· **Q6** chow hall manned by rostered men or by fixtures Â· **Q7** how
many men eat at once Â· **Q8** lock the marker names as final Â· **Q9** confirm cutting wounded
squadmates Â· **Q10** confirm three calls means three different weapons.

**EVERYTHING SACRIFICED (Law 2, collected):** the DAWN end card Â· the full-day illusion Â· the midday
return and with it the two-sortie structure Â· ADR-035's finite hunt pool (demo-only exception) Â· the
busy flightline Â· part of Pillar 3's quiet-play promise (the ambient cell can find a blameless
player) Â· ADR-011's "the radio is a man" (if Q4 passes) Â· downed allies and the 70m cover ring Â·
squad legibility (if concealment ships without a nameplate check) Â· an r4bk debt on the thumper Â·
part of stealth's memory (if the corpse array gets a TTL) Â· `AmbientWar` density under a 38x day.


---

## 2026-08-04 — THE RESCOPE, WIRED (Wyrm, coding window)

Executes `war_room/2026-08-03_demo_day_scope/synthesis.md` including his §8 rulings.
Every item below is CODE WRITTEN AND PARSE-CHECKED, **NONE OF IT IS RUN.** The two
landmines in particular are discharged only by M-2 and M-3 on the exported build.

**THE TWO LANDMINES — DEFUSED**
- **Freeze latch.** `siege_director._enforce_live_cap` froze dormant cells and nothing
  anywhere called `set_physics_process(true)`, so a held cell never marched again while
  still reporting full paper strength - `live/peak` could never fall and the assault could
  never break. New `_thaw_held_cells` releases them as the dead make room, one at a time,
  only while a cell's own strength fits, behind `THAW_HEADROOM 6` so it cannot thrash.
- **Viewmodel accumulator.** Verified by reading the GLB: `ak_fp.glb` carries `ArmsMesh`,
  a skinned ~40-bone skeleton and 6 animations, and EVERY weapon `.tres` points
  `model_path` at its first-person viewmodel - so every dropped rifle instanced the whole
  rig, arms 1.81m underground. `world_weapon._bake_gun_only` now keeps the gun meshes as
  flat unskinned `MeshInstance3D`s at rest pose and drops the arms, skeleton and
  AnimationPlayer. Plus `MAX_WORLD_WEAPONS 24` FIFO (the GunFX pattern) and
  `MAX_REPRIEVES 3` - the old grace was granted for STANDING NEARBY, the default state at
  the wire. `EnemyBase.unreported_corpses` bounded at 48, oldest forgotten first, witness
  logic untouched.
- **NOT a bug, checked and cleared:** `_check_corpse_discovery`'s `remove_at(i)` inside
  `for i in range(size())` returns immediately after the removal. No index fault.

**THE ARC** — `demo_game.gd`: 06:30 start (`SimClock.set_time` after the build, because the
generator seeds its own hour and the weather table wins over it), day 38x, night 20x
switching once at the 1380s seam, probe 1395 / assault 1440 / end 1800. Dawn card gone;
`ENDING_PLAYER_SURVIVES` is the single flag for his Q1 delegation.

**THE OPENING** — `_tick_opening`: T+10 `MOVE_TO` on `patrol_gate_pos`, released on arrival
or by a 210s clock, whichever lands first, then everyone back to FOLLOW. The release line
prints `N/M arrived`, which is **M-4's measurement**. No new UI element (ADR-030 intact).

**THE WALK OUT** — `plan_demo_world` used to declare `no_signs` and `no_camps`. Both were
lies about the demo's own content: it now places 2-3 first-signs at 150-300m on the
outbound bearing, and **an enemy camp at ~300m on the opposite flank from the village**
(his rescope: "one village and one enemy camp"). Ambient walking patrols were ALREADY
built and already ship - `build_patrol_world` spawns 2-3 `LazyGroup` circuits between the
gate and the sites. Do not build a second ambient-cell system.

**THE FALSE ALARM** — `_check_detection` fired "YOU'VE BEEN MADE" off
`EnemyBase.last_combat_contact_ms`, a GLOBAL static that rises when any enemy anywhere goes
loud. The hunter spawn already refused to send anyone without an evidence fix, so the toast
was a promise the system would not keep - nearly unreachable in 7 minutes, routine across a
30-minute day with ambient cells walking. The alarm now requires what the hunters require.

**AIR** — `_dispatch` checked the ceiling once before the lead then added up to 8 wingmen
unchecked (22 airframes against a ceiling of 14, on a call-bound project); the check now
binds every ship and a truncated pack prints. `FSB_PAD_PREFIXES` comment said "measured:
three 15x15m PSP pads" - **drift**: three nodes match and all three sit at the same
position, so `_free_pad` would land three aircraft on one square metre. `_firebase_lzs`
now de-duplicates co-located markers past `PAD_DISTINCT_M 12`. A second REAL pad is his
Blender bench, and he has said the dual-pad firebase is built but unexported.

**FIRE SUPPORT / THE RADIO** — demo allotment is `bombs: 3` and zero of everything else
(his ruling, overruling the council's bomb/arty/mortar split). Napalm at the raid and the
daytime bursts are scripted spectacle billed to nobody, and `garrison_illum` never touched
this stock, so zeroing illum costs the player no light. **The radio is now an object**:
`SquadSystem._hand_off_radio` reassigns the RTO *MOS* to the nearest living man on the
radioman's death, so all eight downstream `member_by_mos("RTO")` call sites keep working
untouched and the heir carries it at full quality. Fire support dies with the SQUAD.
This supersedes ADR-011's "the radio is a man" for the squad net.

**CHOW HALL — HALF WIRED, AND THE HALF THAT IS BLOCKED IS NAMED.** Marker families now map
to occupations (`chow_server*` -> `mess_cook` as a post; `eat`/`queue`/`chow_diner` ->
a new `mess_hall` schedule) and are in the work priority. `civilian_schedules.action_for`
takes an optional `who` so a man's **sitting** is derived from his own node name - the same
ADR-010 identity the work offset uses. **THREE SITTINGS, deliberately:** filling all 24
seats at once against a 40-man ceiling leaves 16 men running the firebase in the hour
before stand-to - a full mess and an abandoned wire.
**NOT BUILT: the 19-clip queue/tray/seat chain**, because the chow markers are not in the
shipped GLB yet (his re-export) and because **M-1 gates every chow-hall decision** - if the
dot suffix does not survive import, ~185 of 198 markers are junk and this is built on sand.

**STILL OPEN**
- ~~The gunship ending flies the wrong shape.~~ **BUILT 2026-08-04.** New `gun_orbit`
  profile: a pair enters on its own bearing from `ORBIT_INBOUND_M 330`, crosses to the far
  side and walks a 12-waypoint circle at `ORBIT_RADIUS_M 130` / `ORBIT_ALTITUDE_M 45` for
  `ORBIT_SECONDS 75`, then runs out. Flown as WAYPOINTS rather than a parametric curve so it
  reuses Helicopter's existing speed ramp, altitude lerp and yaw lerp instead of adding a
  second movement model. **The reaper was the trap:** it deletes any flight within 20m of
  its destination, and an orbiting ship is within 20m of its waypoint by design - the
  gunships would have vanished one lap in. `orbit_in`/`orbit` are now in the `settled` list.
  Budget: ~90s of the 240s `MAX_FLIGHT_SECONDS` at the Huey's 50 m/s.
  **NO DOOR GUN, deliberately** - his ruling 2026-08-04 mid-build ("dont build the gun...
  im going to stage that in a heuy eventually. i just want that idea to be there"). The
  huey.tscn carries no gunner rig, so a firing gun today would be rounds leaving an empty
  doorway. The hook when his staged gunner lands is the `orbit` phase.
- **Every measurement M-1..M-5.** Nothing here has been run.
