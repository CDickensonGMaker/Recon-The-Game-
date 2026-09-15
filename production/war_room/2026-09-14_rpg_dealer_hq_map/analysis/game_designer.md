# GAME DESIGNER + LEVEL DESIGNER + UX — the 890 m AO, the beat system, the Observatory, the dealer as a place

**Lens:** one seat, three eyes: the loop (game), the ground (level), the affordance (UX). Independent
sight, no cross-talk. Every claim carries a `file:line` read today at the working tree, or is marked
PROPOSED. No game file was edited; no suite was run.

**Constraints I hold above my own preferences:** Pillar 3 (no rails; stealth an economy); ADR-041 (the
scene is a PLAN — and its FROZEN-files list, which this council must ask him to THAW by name, Law 3);
ADR-029 §3-4 (patrol is the only mission, the pointer is diegetic); ADR-005 (witness rule); ADR-038 §2a
(a line may name the subject, never quantity/rate/direction); ADR-013 (≤2 km loads whole); the 9/13
decree's clock (`demo_game.gd:53-80`: DAY 27x, NIGHT 12x, seam 1667 s, probe 1740, siege 1800,
backstop 3000); the r4bk law (no HUD affordance = does not exist).

---

## 0 · Three things the briefing assumes that the code says differently

1. **There is no "talk system."** `player.gd:604-652` is the whole verb list ([F] DISMOUNT · MAN THE
   GUN · SEARCH THE CACHE · TAKE HANDSET · SEARCH THE SHRINE · GO DOWN THE HOLE · BANDAGE FROM DOC ·
   BELT FROM · TAKE FROM · SECURE THE PRISONER · PICK UP). The only "talk" in the codebase is the
   civilian BT chatter between NPCs (`civilian.gd:1227`). **The dealer and HQ open with [F], the
   project's ONE interaction surface — there is no [E].** §4 is built on that fact.
2. **The Huey crash is a variant of a built chain, not a new one.** `pilot_recovery.gd` is Skyraider-
   only by asset (`WRECK_MODEL :12`) and ONE pilot by shape (`_pilot: AllyBase :38`); the roll he asked
   for (pilots 1-2, pax 1-4) makes `_pilot` a list. `huey_crashed.glb` exists
   (`assets/us/aircraft/huey_crashed.glb`). The follower verb exists: `AllyBase.OrderMode.FOLLOW`
   (`ally_base.gd:279`). The wreck lands `CRASH_AHEAD_M 220` ahead of the dying plane (`:18`) — which
   FIXES where the ZPU must stand relative to the crash site (§1, the east flank).
3. **The dealer already has a body and a corner.** `site_planner.gd:1217-1218` seats a `quartermaster`
   at `USSupplyDepot_001` and `_007`; `:1261` maps `"ammo"`/`"supply"` work to that occupation. The
   supply dump IS the dealer's corner; the quartermaster IS the dealer. Nothing new is placed.

Also: **ADR-041 is FROZEN with `plan_demo_world`'s site list named in the freeze**
(`ADR-041.md:315-332`). His 9/6 ruling was "post demo"; his 9/14 steer asks for focused authored
areas for the demo. Those are the same man's two rulings and only he reconciles them. **Decision for
him, glossed: "Thaw ADR-041 for the demo AO (village, crash site, ford marks) — yes or no?"** Everything
in §1 is written so it survives either answer (the places are still WHERE the planner puts them; the
authoring is marks and layout inside each footprint, Tier A/B).

---

## 1 · THE AUTHORED-PLACE SET on ~890 m

### 1.1 The map

Centre = firebase centre (0,0). Up = `out_v`, the gate bearing (the plan calls it +Z; on the sheet it
is "north"). All distances in metres; "from the gate" measures from `gate_pos` at (0,+112) — the
firebase half-extent along the gate axis is 111 m (`site_planner.gd:1048` `FSB_HALF`). Map edge at
±445. **Every placed object also sits inside ±384, so the layout survives a 768 m (3×256-chunk) ruling
by the TD with 55 m spare; ADR-013's whole-load holds at either size.**

```
                 -445                    0                    +445
          +445 ┌──────────────────────────────────────────────────┐
               │ (edge fence; siege NEVER forms up on the north)  │
               │                                                  │
          +360 │   [W]······[V]  ~~~F1~~~                         │
               │  way-stn   VILLE ~~~~~~~~~~~~~                   │
          +300 │  (band-    ▒▒▒▒▒ paddies ~~~~~~~~~~ [C] HUEY     │
               │   gated)   ▒▒▒▒▒ (S bank)    ~~~~~~   CRASH      │
               │            ▒▒▒▒▒               ~~F2~~ (N of S)   │
          +220 │              ▒▒▒                  ~~~~~~         │
               │                dyke path             ~~~~~~      │
          +112 │               ┌────G────┐  first-signs  ~~~~~~   │
               │               │   FSB   │ (craters)   [K] VC CAMP│
             0 │               │ [D] [HQ]│              + ZPU on  │
               │               │  dump TOC│    ~~F3~~    the ridge │
          -111 │               └─────────┘  ~~~~~~   (karst/cliff) │
               │                                 ~~~~~~           │
          -200 │          [T] temple / ruins (landmarks) ~~~~~~   │
               │                                          ~~~~   │
          -445 └──────────────────────────────────────────────────┘
                 ~~~ = THE STREAM (depth > 1.2 m = impassable by the grid)
                 F1/F2/F3 = the only crossings     ▒ = paddy (open, slow, no cover)
```

| Place | Centre (x,z) | From the gate | Bearing off `out_v` | Purpose in the loop |
|---|---|---|---|---|
| **FSB** (home; the HQ/TOC; the dealer's dump) | (0,0) | — | — | boot, the ask, the return, the assault |
| **G** the gate | (0,+112) | 0 | 0° | every band measures from here (ADR-029 §2) |
| **THE STREAM** | west edge (-445,+340) → (-150,+320) → (+40,+280) → (+150,+200) → (+300,+60) → east edge (+445,-20) | crosses the gate axis at z≈+300 | — | THE funnel; splits the AO into home / north bank / east flank |
| **F1** the village ford | (-120,+318) | 240 | 330° | the village's own crossing; log footbridge; the quiet way |
| **F2** the ambush ford | (+125,+220) | 165 | 49° | the SHORT way to the crash; the ambush wait (beat B4) |
| **F3** the VC monkey-bridge | (+270,+90) | 270 | 85° | the camp's own way in; one man at a time; satchel-able (tunnel-mouth verb, in scope) |
| **V** THE VILLE | (-200,+360) | 315 | 322° | seen twice: full paddy at 08:00, empty at 15:00 (decree C-V); the informer; the elder |
| **paddies** | (-160..-60, +230..+300) | 130-200 | — | the approach: open, flooded, exposed; the dyke is the path |
| **W** the way-station / cache | (-330,+300) | 380 | 300° | the VC's use of the village, BAND-GATED (below) |
| **C** THE HUEY CRASH | (+240,+280) | 295 | 55° | the outing; survivors by seeded roll; the escort home |
| **K** the VC camp + ZPU | (+330,+80) | 330 | 96° | the gun that downs the slick (220 m short of C on the S→N lane); the hunters' home; where presence lives |
| **T** temple + 2 ruins | (+180,-160) and two off the south bearings | 350 | 155° | landmarks; SEARCH THE SHRINE; the south is for the man who ignores the plan |
| **D** the dump | inside the wire, `USSupplyDepot_001` | — | — | the dealer (§4) |
| **HQ** the TOC | inside the wire, the bunker on his art list | — | — | the taskings (§4) |

**What 3x buys that 512 could not.** At 512 the village sat 185 m from the centre, the camp 300, the
crash 220 m ahead of the plane, and everything inside a ~230 m passable radius
(`mission_generator.gd:796-797`). GUNSHOT carries 150 m (`noise_bus.gd:23`); open sight cap 140 m
(`enemy_base.gd:258`). **Every place could hear every other place.** A shot at the village stood the
camp to; the smoke column stood in sight of the wire; the walk out was a courtyard. On this sheet:
V↔C 440 m, V↔K 600 m, C↔K 220 m (deliberate — the hunters come from there), G→V 315 m of jungle
before the first hut (2+ minutes at patrol pace of nothing but trees and the point man's hand signals).
**That is the difference between a level and a patrol.**

### 1.2 What is deliberately CLOSED, and how — natural funnels, not walls

- **The stream.** `gameplay_grid.gd:138` already marks a cell `impassable` when
  `get_water_depth > WADE_DEPTH_M` (1.2 m, `:154`). The stream is dug deeper than 1.2 m everywhere
  except the three crossings, where it is 0.5 m (a ford) or bridged. **Impassable water is geometry
  per the terrain/water decree** — the nav bake does not carve it, `find_site` refuses it
  (`site_planner.gd:104`), and no invisible wall exists. A player CAN find another shallow — if he
  reads the water; that is freedom.
- **The gallery forest.** `gameplay_grid.gd:145-156`: watercourses carry the densest vegetation
  (`GALLERY_MAX 0.95`) and a canopy roof. Both banks are 45 m sight-cap jungle
  (`SIGHT_CAP_JUNGLE`). You cannot see across the stream, you hear across it. The stream is a
  wall to the eye and a corridor to the ear — the audibility ask, in the ground itself.
- **The east ridge.** Karst above K: slope past the cliff threshold `find_site` rejects (`:33-34`).
  The ZPU's perch, and the reason C is reached along the bank, not over the top.
- **The paddies.** Not closed — OPEN. Flooded, slow, no cover, 120 m of it between the wire and F1.
  An open-ground funnel: you can go anywhere, but the dyke is the only dry line, and the dyke is
  where the elder sees you. Chickens on the dyke are noise traps (`mission_generator.gd:1326-1329`).
- **The map edge.** EdgeFence (shipped 9/14) — the one honest wall, and it is 445 m from anything.

**Nothing else is closed.** South of the firebase is open jungle with the temple and two ruins in it
— the man who walks the wrong way still has a day (§1.4).

### 1.3 The walk against the clock (27x day, seam at 1667 s)

Patrol pace with a squad in file ≈2.5 m/s real (walk 5.0, `player.gd:12`, halved by halts and the
point man); escort pace with a wounded follower ≈1.5 m/s.

| Real | Sim | Beat | Where |
|---|---|---|---|
| 0:00-1:00 | 06:30-06:57 | the cot; the resupply slick on the pad (B2, the replacement) | FSB |
| ~1:00 | 07:00 DAY snap | the shit-barrel detail lights (B3) | by the latrine, on the way to the gate |
| 1:00-4:30 | 07:00-08:35 | wire at 120 m (the sweep circle, 3 bombs) → dyke → F1 → the ville | 315 m |
| 4:30-8:30 | 08:35-10:20 | THE VILLE, first pass: paddy full, the elder on his bench, the informer's 15 m, chickens | V |
| ~8:30 | ~10:20 | **B1 THE SLICK GOES IN** — the Huey comes up the east lane, ZPU tracers over K, it trails fire 220 m and goes in at C; the column stands NE across the stream, seen from the ville | trigger: clock ≥ 480 s AND player > 250 m from the gate |
| 8:30-12:00 | 10:20-11:55 | ville → C along the north bank; one contact (treeline watchers / first hunters) | 430 m |
| 12:00-16:00 | 11:55-13:45 | THE CRASH: survivors by the roll, the picket, the hunters from K 220 m south | C |
| 16:00-22:00 | 13:45-16:30 | **the short way** C → F2 (the ambush wait, B4 return) → G, 295 m at escort pace | home ~22:00 |
| 16:00-24:00 | 13:45-17:20 | **the long way** C → V (the afternoon paddy, EMPTY if the ledger says wary) → F1 → dyke → G, 715 m | home ~24:00, DUSK light from 23:20 |
| 24:00-27:47 | 17:20-19:00 | the wire, the pilot to the ward, the faction line, PATROL 1 LOGGED | FSB |
| 27:47 | 19:00 NIGHT | seam; 29:00 probe; 30:00 the assault | FSB |

**The short/long fork is the design.** The decree's paddy reading is only seen on the long way;
the long way spends the whole dusk margin walking a wounded man through the ville. A player who
takes the short way keeps his margin and meets the ford. Neither is scored. Nobody tells him. The
ford is nearer and the ville is where he came from — a man will pick by his own read of the day.

### 1.4 The band-gated place, and freedom

**W, the way-station, exists in three states from the one ledger** (`hm_ledger.gd:45-54`
`band()` → quiet/wary/hostile, never a count):
- **quiet:** a lean-to and rice sacks in the gallery forest; nobody there; it reads as a woodcutter's
  shelter. The place exists, the men do not.
- **wary** (`informer/<v>/talked` or `fire/<v>/p<n>`): two men and a cache under the sacks; a
  `FieldCache` the [F] SEARCH THE CACHE verb already reads; the village path north has fresh
  footprints (the dust stamp `RoadNetwork._stamp_dust` on the woodlot path).
- **hostile** (`civ/<v>/<name>/killed`): the way-station is a picket of four with an ambush plan
  covering F1 — the village's own ford is now theirs.

This is "VC bases permitted by trust" made a PLACE, felt at 130 m from the ville, never announced.
The same reading powers the night warning (decree C-E) — one ledger, two consumers, no meter.

**A player who ignores the plan.** He walks south: temple, ruins, [F] SEARCH THE SHRINE, the
first-sign craters. The column still stands over C for `WRECK_BURN_S 1500` (`pilot_recovery.gd:19`)
— he can see it from any high ground and walk to it late or never; `WAIT_TIMEOUT_S 420` loses the
survivors (`:27`) and the card says so. The hunters still come (they hunt the SITE, not him). Night
still falls at 27:47; if he is out, the siege opens on the base and he walks home into it (ADR-035
§1; no teleport). **Every place is optional; the clock is not.** ADR-020's test — "can he turn around
and leave, right now?" — is yes at every row of §1.3.

### 1.5 Refused for the demo AO, and why

- **The kit "other firebase" (`fsb_kit_alpha`, 72 m pad, `mission_generator.gd:599-622`).** No. GAME
  GUIDE §6.0: *one firebase*. A second base on an 890 m sheet competes with the only word "home" the
  demo teaches, costs a 72 m flatten plus its garrison's think budget, and has no role in the 45
  minutes. It belongs to the patrol world's 420-600 m band, which this sheet does not have.
- **A rubber plantation.** Not this council — it is a Tier-B cluster (rows of trees + a planter's
  house) with no loop role; a good SECOND AO's identity, not this one's. Named so nobody claims it.
- **A second village.** The decree's H&M loop is one ledger, one village, seen twice. Two villages
  halve the reading.

**Sacrificed by §1 (Law 2):** the temple stops being on the outing's line (it was the 512 landmark
on the camp bearing) and becomes the reward for the wrong direction. The village's paddies moving to
the south bank means the elder's bench faces the ford, not the wire — the informer must SEE you at
15 m on the dyke, so the dyke is where fire discipline is judged; a player who wades the paddy off
the dyke is not seen and not judged — freedom, and a hole a sneaky player will find. The stream costs
the nav bake three off-mesh links (the crossings) and costs the siege its north and east approaches.

---

## 2 · THE SCRIPTED-EVENT SYSTEM — shape, not code

### 2.1 The one sentence

> **A BEAT is a trigger that borrows living actors, walks them to authored marks, plays their clips
> and one radio line, and gives them back — while the player keeps every control he had.**

Not a cutscene (those stay standalone FMV per memory). Not a spawner (actors are RESOLVED from the
cast that already exists — the F10-snapshot lesson: a fresh body is a new man with a cook's name).
Not a second AI: while leased, a body is in `SCRIPTED_PERFORMANCE` mode (the handoff's §5.5 lease,
`DEMO_40MIN_HANDOFF:549-558`) and every interrupt — alarm, damage, player fire within 60 m, the
player walking away past a radius — releases the lease and the man's own brain resumes with a
generation token (F07's callback guard).

### 2.2 The four trigger kinds, and what each composes with

| Trigger | Source (existing) | Example |
|---|---|---|
| **volume** | an `Area3D` at a site-relative mark; fires once per occurrence id | the F2 approach, the wreck's 40 m ring |
| **quest / ledger state** | `CampaignState.hearts.has(id)` (`hm_ledger.gd:38`), `director.state.flags[...]`, `_phase` | `pilot_recovered` → the ward-door stand-to (already the decree's C-A) |
| **clock** | `SimClock.sim_hour` window, or the arc's real `_clock` | 07:00 the barrel; ≥480 s the slick |
| **world event** | a FieldDirector / PilotRecovery / SiegeDirector signal | `siege_began`, the wire crossing, `AirTraffic` launch |

**Composition rules (so it never becomes a second director):**
- A beat CALLS existing verbs and never re-implements them: `director.authored_strike(...)`
  (`field_director.gd:765`), `director.night_warning()` (`:100`), `PilotRecovery.request_down`,
  `AllyBase.set_order(FOLLOW|HOLD)` (`ally_base.gd:328`), `director.toast.emit` (`:7`, the radio).
- A beat may NOT change the demo phase; `_open_siege` stays the one authority
  (`demo_game.gd:645`). A beat may be TRIGGERED by a phase edge.
- A beat borrows a civilian from his schedule slot exactly as the chow sitting does, and returns him
  to `place_for_current_hour` — the schedule is the truth, the beat is a detour.
- One beat per site at a time; a beat that cannot resolve its actors (dead, promoted, leased)
  DEGRADES to its radio line alone, and logs `[BEAT] <name> degraded: <reason>`. It never waits.
- Every beat has an occurrence id (`beat/<name>/<seed>/<day>`) and is idempotent — the `assault_id`
  shape from the 9/13 game-designer analysis §2.

### 2.3 Authoring

**A JSON per beat in `data/beats/<name>.json`, the shape `data/site_plans/*.json` already has**
(`SitePlan.load_from`, `site_plan.gd:82-108` — a parts list with ids and site-relative positions,
written by a tool scene). A beat file holds: `trigger` {kind, args}, `site` (which stamped site its
marks are relative to — it never knows its world position, ADR-041 §1's anti-creep), `roles`
[{role, resolve: "nearest garrison off_duty" | "the pilot" | "village elder" | "camp picket ×2"}],
`marks` [{role, pos (site-relative), face}], `steps` [{at_s, role, clip | line | verb}], `release`
{radius, timeout_s, on_alarm}. The marks are placed in `tools/kit_editor.tscn`'s sibling, a
`tools/beat_editor.tscn` that opens the demo world and lets him drag marks on the real bake — the
chow-hall lesson (ADR-041 §5: hand-placed ≠ correct; the fix was 16 markers MOVED after measuring
against the bake). **A mark that is not within agent clearance of a baked polygon fails the beat's
probe, not the playtest.**

Not a node in the site `.tscn`: a `.tscn` cannot carry a comment or a trigger without a script, and
a script on an authored site is exactly what `test_placement_paths.gd` and ADR-041 §2 police.

### 2.4 The headless gate

`--beat-probe=<name>|all`, attached by `game_flow.gd` the way `--npc-census` is (`:773-776`):
boots the demo world, `BeatDirector.fire(name)` bypasses the trigger, then asserts within the beat's
timeout: every role resolved to a living body (else the degraded line was emitted, and the probe says
which); every actor within `ARRIVED_M 0.7` (the census's own number, `probe_npc_census.gd:52`) of
its mark in XZ and 0.5 in Y; each clip was requested by name (a `[BEAT] clip` line); the line
emitted on `toast` exactly once; the lease released and the man's `scheduled_action` resumed; and
the negative — `fire(name)` a second time does nothing. Plus the mark-vs-navmesh assert for every
mark in every beat file (the ADR-041 §5 binding probe, made general). The whole file set runs in the
census's own settle windows; minutes, not an hour.

### 2.5 The four beats I would author first

| # | Beat | Comic side | Trigger → staging | Why first |
|---|---|---|---|---|
| **B1** | **THE SLICK GOES IN** | the Reboot cover: two Hueys and a man in the grass | clock ≥ 480 s AND player > 250 m from the gate → `AirTraffic` launches a Huey on the S→N resupply lane over K; the ZPU crew (`zpu_crew`, `mission_generator.gd:867-871`) fires; `request_down` GUARANTEED in demo mode; the bird trails fire 220 m and the wreck (`huey_crashed.glb`) + column stand at C; the seeded roll (`hash(op_seed, "huey")`: pilots 1-2, pax 1-4) spawns survivors at authored marks — one under the boom, one in the grass 12 m off, the rest against the tail; SIX relays the Mayday on `toast`; hunters from K by band. Survivors `FOLLOW` on wake at `WAKE_M 12`; arrival at 30 m banks `pilot_recovered` once for the whole group | his ruling; the chain is 80% built; it is the outing |
| **B2** | **THE REPLACEMENT** | Issue 1-2: Michael, the draft card | the opening slick on the pad (`AIR_OPENING` beats at 3/14/26/48 s, `demo_game.gd:337-344`) → one man off the bird with a duffel, a garrison man walks him from the pad to the bunk beside the player's; the sergeant's one line ("YOU'RE HIS. SHOW HIM THE WIRE."); he is stage 2's earned-companion candidate — the man who walks the day with you IS the replacement, and his card (name, hometown) is on the roster from the snapshot | it is the RPG premise shown in 40 s with zero new art; the comic's opening page |
| **B3** | **THE SHIT-BARREL DETAIL, 07:00** | the grunt-work register the comic lives in | the DAY snap (07:00 ≈ 60 s) → two off-duty men at the latrine marks (`fb_latrine` exists, `site_planner.gd:2321`; `"burn"`/`"latrine"` are already detail jobs, `:1312`) drag the cut-down drum out, diesel, light it; the smoke stands over the compound all morning. One bark ("DON'T BREATHE IT"). No line, no toast | it makes the firebase's clock VISIBLE, it teaches "a smoke column is a thing men made" 8 minutes before the crash's column means the opposite, and it is the cheapest beat on the list |
| **B4** | **THE FORD** | the squad under a sniper's ground — the wait, not the shot | player enters F2's approach volume with ≥2 squadmates, phase 0 → the point man halts at the bank mark; the squad goes to ground on its marks (`HOLD`); a 2-3 man picket from K's ambush plan (`AmbushPlanner`, `mission_generator.gd:692`) lies on the far bank at ITS marks, RELAXED, silent. Nothing happens for 20-40 s unless noise or LOS. Then the point man crosses. On the return with survivors the same volume finds the picket at whatever tier the crash hunt left them — if it went loud, the ambush fires here | it is the audibility ask staged: you hear them before you see them; and it is "scripted" only in the marks — the outcome is the AI's, so it never rails |

Named and NOT first: **THE BODY** (a K patrol finds the man you dropped at the ford → `_witness_check`
→ the camp stands to — the ADR-005 chain made legible; it is an Observatory demo more than a beat)
· **THE EARS** (Eugene — post-demo per `QUEST_STARTERS_VIETNAM.md` §1) · **THE DUSK WIRE** (the
faction man's unprompted line — already the decree's toast; not a beat).

**Sacrificed (Law 2):** B1 makes minute ~8:30 the same every run (the decree already accepted this
for the shoot-down). B3 costs two off-duty men their 07:00 schedule slot. B4 costs the ford a
guaranteed picket — a player who read the ground and expected an empty stream is wrong every time;
mitigated by the picket's tier being the AI's, not the file's. The beat editor is a tool nobody has
built; without it, marks get typed into JSON and the chow-hall defect returns.

---

## 3 · THE OBSERVATORY (UX lens)

**Status first, so it is never argued later: THE OBSERVATORY IS A DEV INSTRUMENT.** It exists only
under `OS.is_debug_build()` (the same gate as `_dev_keys`, `game_flow.gd:69`), never in an export.
The period-HUD decree (ADR-030, deferred) governs what the PLAYER sees; the r4bk law governs player
affordances; §2a governs faction lines. **The Observatory reads state the player is forbidden to
read, which is exactly why it must be impossible to ship** — a `--observatory` launch flag or [F9] in
a debug build, nothing else. It is exempt from all three laws by being outside the game.

### 3.1 Two doors, one instrument

- **[F9] in the running game** (debug build; F8/H/G/O/I/U are taken at `game_flow.gd:63-93`, F10 is
  the roster snapshot, F11 is `interior_prop_dial.gd:14`). Toggles the overlay onto the live world;
  the mouse is freed like the journal (`journal.gd:5-8`: a held object, the world runs).
- **`tools/observatory.tscn`** — a tool scene beside `tools/kit_editor.tscn` that boots the demo
  world through the SAME GameFlow demo path (never a second builder — ADR-028), with a free-fly
  camera, the overlay forced on, and the clock lenses (O/I/U) on buttons. This is where he watches
  the whole H&M system run at 600x with nobody shooting at him.

### 3.2 What is drawn in the 3D world

| Element | Drawn how | Reads from |
|---|---|---|
| **Per-NPC label** | pooled `Label3D` billboards, only inside 120 m of the camera + the selected + every member of an active chain | name/tag · **alert tier** colour (RELAXED grey · SUSPICIOUS yellow · ALERT orange · COMBAT red; `enemy_base.gd:250-251`) · **LOD tier** suffix N/F (`ai_lod.gd:42`) · civilians: WANDER white · FLEE cyan · COWER blue · GONE magenta · informer ★ (`civilian.gd:17, 24`) · allies: order mode |
| **Sight cone** | an `ImmediateMesh` wedge from `facing_dir` at the man's current sight cap (140 open / 45 jungle, `sight_cap.gd:16-20`), rebuilt at 10 Hz, selected man only + chain members | `facing_dir`, `_grid` |
| **Hearing** | drawn at the SOURCE, not the listener: every `NoiseBus.emit_noise` draws its radius ring for 2 s (FOOTSTEP 8 · SPRINT 16 · GUNSHOT 150 · SUPPRESSED 3, `noise_bus.gd:21-24`) with a line to each listener that received it — **the player's own steps and shots included**, which is the "same for you" half of his ask | `NoiseBus` signal |
| **Last-known marker** | an X at `last_known_target_pos` (`enemy_base.gd:207`) with a dashed line from the man; squad-shared ones (`EnemySquad.shared_last_known`, `:1330`) drawn once with the squad id | per NPC |
| **Witness chain** | arrows who-saw → who-told → the alarm carrier, held 5 s: written at `_witness_check` (`:1470-1498`) and `EnemySquad.begin_hunt` (`:1895`); the beacon stamp (ADR-005) flashes the carrier | `_witness_check`, `_set_tier` |
| **Patrol / hunt lines** | `patrol_circuit` polyline; the hunt vector; the nav target with the F08 status colour (valid / partial / blocked / off-mesh) | `nav_agent`, `NavRouter` |
| **Civilians** | schedule arrow to the working point; the village's band as a ring colour around `village_center` (quiet green · wary amber · hostile red); reaction state on the label | `scheduled_action`, `hearts.band` |
| **Beats** | trigger volumes as wire boxes (armed white · fired grey · degraded red); marks as pins with the role name | `BeatDirector` |

### 3.3 The side pane — the selected NPC's thought process

Top to bottom, 4 Hz refresh, plain monospace:

```
 VC rifleman  camp_garrison_0 #7        tier ALERT   lod NEAR   hp 71  supp 0.32
 STATE   HUNTING           goal FLANK_TARGET        since 11:52:10 (+38 s)
 BECAUSE tier SUSPICIOUS->ALERT  stimulus: NOISE GUNSHOT 92 m from (+212,+261)  at 11:51:32
 TARGET  player (lost 6.1 s)   last_known (+218,+270)   LOS no   awareness 0.61
 DEST    (+205,+266)  nav VALID  dist 14.2  path 3 pts  off-mesh none
 JOB     schedule: —   garrison station: —   gun crew: —   doctrine: vc_line_rifle.tres
 WAITING unstick 0.0 s · stand_to_held no · all-clear poll 4.0 s
 STUCK   —      (census vocab: ARRIVED / AWAY / WRONG-TARGET / STUCK / OFF-MESH / OVERLAP / ROOF)
 LOG (last 10, sim time)
  11:52:10  goal ENGAGE->FLANK       target lost 5 s, cover claimed (+205,+266)
  11:51:32  tier SUSPICIOUS->ALERT   noise GUNSHOT 92 m
  11:51:30  tier RELAXED->SUSPICIOUS awareness 0.45 (candidate seen 41 m)
  ...
```

The rolling log is a per-NPC ring buffer of 10 entries written by one static call,
`Observatory.note(who, transition, stimulus)`, at the four places a decision is made: `_set_tier`,
the goal switch, `set_order`, and the civilian `_bt_tick` action change. **When the Observatory is
off, `note` is `if not enabled: return` and the buffers are never allocated** — the cost is one
branch per decision, not per frame, and decisions already run at 6-7 Hz. Zero draw, zero nodes,
zero labels when off; when on, labels capped at 120 m and the mesh at 10 Hz.

**The STUCK line is the census made live.** `probe_npc_census.gd:11-16` already defines the vocabulary
(WRONG-TARGET / STUCK / OFF-MESH / OVERLAP / ROOF) with the numbers at `:27-33, 52`. Lift the
classification into a static the probe AND the pane both call, so they cannot disagree: **walk up
to a frozen gun crew and read "STUCK: nav target 0.4 m inside `fb_locker_03`; wanted 1.1 m/s, actual
0.0; unstick 4.2 s; puppet: none; stand_to_held: yes"** — the 9/13 batch's finding ("the stuck men
walk INTO COTS/LOCKERS") took a night of log-reading; the 9/14 playtest's "crews frozen by an alarm
stand-to" is one line here. A hotkey (F9 + Space) dumps the selected pane as one `[OBS]` log line, so
a headless probe greps the same text the human reads. **One vocabulary, two readers.**

### 3.4 The ledger pane and the map pane (follow-up)

- **Ledger pane:** `CampaignState.hearts` listed by place: every deed id, kind, sim_hour, and the
  band the place resolves to — with the CAUSE string (`informer/<v>/talked`, `fire/<v>/p1`,
  `civ/<v>/<name>/killed`). Numbers and counts are legal here and nowhere else; the pane says
  "DEV — not a readout" in its title so no screenshot of it is ever mistaken for the game.
- **Map pane (follow-up, its own gate):** a top-down `SubViewport` of the AO: village rings by band;
  enemy presence as a 32 m-cell heat from `AgentRegistry`; the way-station lit/unlit; patrol circuits
  and ambush sites (`AmbushPlanner` output); beat triggers armed/fired; the player's path as a trail.
  This is the "entire Hearts and Minds system at work" in one picture, and it is the thing he watches
  at 600x in the tool scene.

### 3.5 Selection

Click (a ray from the camera on the enemies/allies/civilians layers) or Tab / Shift-Tab to cycle by
distance; a pinned selection survives the LOD handoff (nothing resets across it, memory 9/09) and
the garrison promote/stand-down swap IF the F10 snapshot carries a stable id — which the handoff's
§5.1 `person_id` asks for anyway. Escape clears.

**Sacrificed (Law 2):** four `note()` calls in hot AI files; a pooled-label system nobody has written;
the map pane is a second week. And an honest one: **a tool that shows him the AI's reasoning will
show him every place the AI has none** — the far-tier man who "advances and fires" with no goal, the
civilian whose `talk` has no partner. That is the point, and it will generate a longer bug list than
the census did.

---

## 4 · THE DEALER + HQ as PLACES and as UX

### 4.1 Places

- **The dealer is the quartermaster at the dump.** `USSupplyDepot_001` / `_007` seat a `quartermaster`
  (`site_planner.gd:1217-1218`); `"ammo"` and `"supply"` work maps to him (`:1261`). His corner is
  the supply dump by the pad — conex, pallets, the water trailer. **The marker is diegetic:** a
  stencilled sign on the conex (`SUPPLY — SGT CHAPMAN` or whatever the roster names him — text on the
  GLB, not a floating marker: ADR-029 §4 forbids those) and the journal's MAP tab names the dump. A
  fresh player finds him the way he finds the aid station: by walking the compound.
- **HQ is the TOC** (his art list, the bunker first). The ops sergeant at the map table under the
  lantern; the radio is there (the handset verb already lives on the RTO). The tasking is spoken by
  SIX on `toast` — the radio is the voice — and WRITTEN in the journal.

### 4.2 Opening the trade — [F], the one surface

There is no talk system (§0.1). The dealer opens like the cache: look at him (`player.gd:436` —
"down the sights of your eyes, never proximity"), the prompt line reads `[F] TALK TO SGT CHAPMAN`,
[F] opens ONE page in the journal's paper style (`journal.gd`: the ruled sheet, ink, graphite,
pencil; no icons, no glow — the period decree's look even though the decree's blit pipeline is
deferred). The page is a ledger page in his hand: **left column what he has** (contraband —
never a weapon, everything consumable, never from corpses: ADR-038/006-B's three guards), **right
column what he wants** (the radio batteries off the bird; the door gun; a case off the ville;
"the elder's tea"). Take = one line struck through. It does not pause (the journal's law). HQ
is the same shape: `[F] REPORT TO THE TOC` opens the ORDERS page.

### 4.3 Chain state in the journal without numbers (r4bk, §2a)

The journal already has five tabs (`journal.gd:42`: GEAR · ORDERS · MISSION · LOG · MAP). No new
tab. The chains are NOTES in two hands on facing pages:

- **ORDERS (HQ's hand, grease pencil):** one line per tasking, as an order is written —
  `CHECK THE VILLE. REPORT.` · `RECOVER THE CREW.` · `HOLD THE WIRE.` An order never checks off
  (ADR-029 §4's law for the circle: "never updates; the next replaces it") — **it is struck through
  when the world says it is done**, and the strike is the only state. A struck line stays on the page.
- **MISSION (the dealer's asks, a different hand, in ink):** `Chapman — batteries off the bird, two
  cases. Says he'll square it.` Struck when delivered; **crossed out with a different stroke** if it
  can no longer happen (the bird burned).
- **The conflict shows as geometry:** HQ's `RECOVER THE CREW. NOTHING LEAVES THE WRECK.` on the left
  page and Chapman's `the M60 off the door` on the right, facing. Both cannot be struck. The player
  reads the conflict by looking at two lines; no state word, no flag, no number.
- **LOG (what happened, the ledger's deeds in prose):** `the ville sent a kid up the road` · `the
  pilot came home`. Written by the same producers the decree named; no line may carry a numeral or
  a direction word (§2a; `test_hearts_felt.gd` extends to journal strings).
- **What the player NEVER sees:** the band, the deed ids, standing with HQ as a value. HQ's standing
  is HQ's WORDS on the radio (ADR-006-B: body count moves the words, never the grant) and what the
  next order asks for.

**r4bk check:** every chain state has exactly one affordance — a line, struck or not, on a page he
already opens with [J]. If a chain state has no line, it does not exist, and that is the rule that
keeps the dealer chain from growing a quest log.

**Sacrificed:** a trade page is a menu with a face on it — the §2a corollary warns against exactly
this. The mitigation is the dealer's UNPROMPTED line at the wire (already in the decree's toast
channel) — the readout is what he says when you walk past, the page is only the transaction. And
the journal's ORDERS tab gains a written order from HQ, which ADR-029 §4 permits only as the diegetic
pointer — the line must read as a scrawl, never as a checklist.

---

## 5 · Decisions for him, glossed

1. **Thaw ADR-041 for the demo AO?** Its FROZEN list names `plan_demo_world`'s site list and any new
   site `.tscn`. §1 needs marks and a ford layout; nothing else in the freeze.
2. **768 or 1024 chunks?** He said ~890; the chunk is 256 m. §1's layout fits inside ±384 (768 m) with
   55 m spare and inside 1024 with room the siege can use. My preference: **768** — everything is
   already within reach, and the sheet stays whole-loaded at either size (ADR-013).
3. **The short way home vs the long way:** both stay legal (§1.3). If he wants the paddy reading
   GUARANTEED, the only honest lever is the escort's pace, not a closed ford — and I would not pull it.
4. **The kit base is out of the demo AO** (§1.5). Say so or overrule it.
5. **[F9] for the Observatory, debug builds only, never exported** (§3). Confirm the key.

## 6 · Pointers verified today

`demo_game.gd:53-80, 162, 337-344, 645` · `mission_generator.gd:599-622, 726-871, 954-962` ·
`site_planner.gd:33-34, 104, 1048-1049, 1217-1218, 1261, 1312, 2321` · `site_plan.gd:11-25, 82-108` ·
`pilot_recovery.gd:12-45` · `ally_base.gd:279, 328` · `enemy_base.gd:207, 250-258, 1330, 1450-1498,
1895` · `civilian.gd:17, 24, 1227, 1306-1311` · `ai_lod.gd:42-61` · `hm_ledger.gd:15-54` ·
`noise_bus.gd:12-24` · `sight_cap.gd:16-20` · `gameplay_grid.gd:138-156` · `field_director.gd:7,
95-104, 765` · `game_flow.gd:63-93, 773-776` · `player.gd:12, 436, 604-652` · `journal.gd:1-42` ·
`probe_npc_census.gd:1-52` · `interior_prop_dial.gd:14` · `assets/us/aircraft/huey_crashed.glb` ·
`data/site_plans/fsb_kit_alpha.json` · ADR-041 §1-5, §FROZEN · ADR-005 · ADR-013 · ADR-029 §2-4 ·
ADR-038 §2a · GAME_GUIDE §6.0-6.1 · the 9/13 decree and its game-designer analysis §0-2 ·
`CONQUEST_OF_WORMS_AUTHOR_SYNOPSIS.md:30-72` · `QUEST_STARTERS_VIETNAM.md` §1-5.
