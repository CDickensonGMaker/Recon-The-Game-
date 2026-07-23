# DEVIL'S ADVOCATE — VC INDIRECT FIRE — 2026-07-21

All pointers below verified by reading the file. Where I say "verified" I mean I opened it today.

---

## 0. POINTER AUDIT (the briefing said a wrong pointer goes at the top)

**The briefing's pointers are unusually clean. All eight verified CORRECT:**

| Briefing claim | Verdict |
|---|---|
| `combat_manager.gd:245-256` `apply_suppression_in_area` walks `AgentRegistry.enemies` only | ✅ exact |
| only callers `weapon_holder.gd:444`, `cas_airplane.gd:188` | ✅ exact — repo-wide grep returns only these two |
| `field_director.gd:590 _fire_shell` | ✅ exact |
| `field_director.gd:567 _run_mortar_mission` | ✅ exact |
| `field_director.gd:714 SAPPER_CHANCE` tiers | ✅ exact |
| `site_planner.gd:664 stamp_vc_camp` | ✅ exact |
| `ai_stress_arena.gd:1455` fire-support host | ✅ the comment is at :1454-1456, `_wire_fire_support()` at :1417 |
| `GAME_GUIDE.md:184` canon lies | ✅ **:184 reads "enemy mortars use the same system. Verified genuinely fixed."** — a false claim that carries the word *Verified*. `:138` "walking mortars on last-known" is likewise unbuilt. |

**The one pointer that is materially misleading is `mission_hud.gd:195` (A5).** The function is
`show_damage_direction(rel_angle)` at `:196`, and its **only** caller is `player.gd:1177-1178`, inside
`player.gd:1168 take_damage()`. **It is a damage-direction wedge, not an incoming-fire wedge.** It cannot
fire on a spot round, because a spot round that lands 15 m away deals the player no damage. A5 as written
reuses an indicator that is structurally incapable of doing the job.

---

## 1. THE PREMISE — I verified it, and it HOLDS, with one important qualifier

I ran my own sweeps across `scripts/`, `terrain/`, `scenes/`, `data/` for `mortar|artillery|barrage|
indirect|shell`. **There is no enemy indirect-fire implementation, complete or partial.** The seventeen
`.gd` files that mention mortars are the player's chain (`field_director`, `fire_plan`, `ballistics`,
`cas_airplane`, `mission_hud`), the probes, the collision table, and the crater profiles. `scripts/enemies/`
contains **zero** hits. The premise survives contact.

**But there IS a system the session has not accounted for, and it will poison A5:**

`scripts/ai/ambient_war.gd:11` —
```gdscript
const KINDS: Array = ["artillery", "mortar", "tracers", "burning", "gunship_attack"]
```
`_roll_events()` (`:25-45`) fires **1–3 events every in-game hour**, each positioned **200–800 m from the
player**, and `_spawn_audio` (`:50-65`) plays `explosion.wav` at `unit_size 220 / max_distance 1200`
for the `artillery` and `mortar` kinds.

This is not a competing *system* — it does no damage, spawns no projectile, has no faction. But it is a
competing **SIGNAL**, and that is worse for this decree specifically. **The game has spent its entire
runtime training the player that a distant explosion at 200–800 m is scenery.** A5 proposes that the
VC spot round *is* the warning. It will land in the same distance band, from a random bearing, playing
the same `explosion.wav`. The player will not read it as a warning. He will read it as the ambient war,
because it has been the ambient war every hour of every operation he has played.

**This is the most important thing I found on the premise question**, and it is invisible to a grep for
"enemy indirect fire" because `ambient_war.gd` is filed under `scripts/ai/`, not `scripts/enemies/`.

---

## 2. A1 IS A P0 THE COUNCIL ALREADY KILLED ONCE — DO NOT SHIP IT AS WRITTEN

This is my single most important finding overall.

`weapon_holder.gd:441-444`:
```gdscript
var suppress_radius: float = _calc_suppress_radius()
var suppress_amount: float = _calc_suppress_amount()
if suppress_radius > 0.0 and suppress_amount > 0.0:
    CombatManager.apply_suppression_in_area(muzzle_pos, suppress_radius, suppress_amount, controller)
```

Three facts, all verified:

1. The centre is **`muzzle_pos`** — the player's own muzzle, not an impact point (`:429`).
2. `exclude` is **`controller`** — the player only. **Allies are not excluded.**
3. The radii (`weapon_holder.gd:855-863`) are **3.0 m rifle · 6.0 m buckshot · 8.0 m launcher**, and the
   amounts (`:868-881`) are **0.08/shot full-auto · 0.12 burst · 0.05 single**.

Now the receiving side (`ally_base.gd`, all verified):
- `:212` `SUPPRESSION_DECAY = 0.4` per second.
- `:829` an ally fires only `if can_fire and suppression_level < 0.5` — **hard fire gate.**
- `:625-628` `supp_gate` 0.6 (0.35 if already seeking cover) → forced `SEEK_COVER`.
- `:234/:368` `LOW_POSTURE_SUPPRESS = 0.6` → forced crouch.

**Do the arithmetic.** An M16 on full auto is ~11–12 rounds/second. 11.7 × 0.08 = **0.94/s applied**
against **0.4/s decay** = net **+0.54/s**. Every friendly within **3 m of the player's muzzle**:
- crosses the **0.5 fire gate in ~0.93 s** — he stops shooting,
- crosses the **0.6 cover/crouch gate in ~1.11 s** — he breaks for cover and goes prone-ish,

**...because the player fired his own rifle.** A fireteam stack, a wire line, a treeline halt, a man
covering the player's back — all of these routinely put an ally inside 3 m. A LAW gunner (8 m radius,
0.45/shot) saturates the entire squad to 1.0 in a single shot.

**This is the exact failure the War Room killed on 2026-07-16** (Wave 4 crouch locomotion — the
"suppression-0.35 aggression-killer P0"). A1 as written resurrects it, from a different direction, and
the probe `kfoz` proposes ("an ally inside the radius takes suppression") **would go GREEN on the broken
behaviour.** The probe proves the wire, not the game.

**What must be true before A1 ships:** faction-blindness must be a property of the *terminal*, not of
`apply_suppression_in_area`. Indirect terminals suppress everyone; a rifle muzzle does not suppress the
shooter's own side. If the method is made blind, `weapon_holder.gd:444` **must** pass a friendly-exclusion
(team id, or `AgentRegistry.allies` skipped for team-0 sources) in the same commit. There is no version of
"make it blind and call it from everywhere" that survives one minute of play.

**Named cost of the fix I am demanding:** you lose the clean one-line change. `apply_suppression_in_area`
grows a faction/source parameter, which means every caller is touched, which is more surface. I accept
that cost. The alternative is a squad that cowers whenever the player pulls a trigger.

---

## 3. A1's SECOND DEFECT — "radii from FirePlan" HAS NO RADII TO READ

`scripts/gameplay/fire_plan.gd` — verified in full. It contains **exactly one** suppression constant:
`BOMB_SUPPRESS_M = 40.0` (`:23`). There is **no** `MORTAR_SUPPRESS_M` and no `ARTY_SUPPRESS_M`.

What FirePlan *does* expose per-kind is `footprint()` (`:49-76`), and the mortar footprint is
`MORTAR_SHEAF_M * scat + MORTAR_BLAST_M` = **14.4 m at fo 8, 18 m at fo 0** (`:53`). That is the **kill**
ring, not a suppression ring.

So A1's "radii from `FirePlan` so they cannot drift from the drawn footprint" resolves, if taken
literally, to: **a mortar suppresses out to 14–18 m while a Snake Eye suppresses to 40 m against a 16 m
blast.** `kfoz`'s own description names the bomb as "the existing precedent... suppression reaches well
past the kill" — and then A1 picks the one number that does the opposite.

The implementer must add `MORTAR_SUPPRESS_M` / `ARTY_SUPPRESS_M` to FirePlan. And the moment he does,
**`tests/test_fire_mission.gd:258` is at risk**:
```gdscript
_ok(is_equal_approx(green, FirePlan.MORTAR_SHEAF_M + FirePlan.MORTAR_BLAST_M),
    "the mortar ring is sheaf + blast, not a decorative radius")
```
That assertion locks the *drawn* ring to sheaf+blast. If anyone "unifies" the drawn ring with the new
suppression radius, this probe goes red — correctly. **Do not green it by widening the footprint.** The
player's placed ring must keep meaning *where the rounds land*, or ADR-011's placement contract dies.

---

## 4. A2 WILL BREAK TWO PROBES AND THE ARENA — the gun origin is a BEARING, not a position

`field_director.gd:590-602`:
```gdscript
var azimuth: Vector3 = ground - fsb_center
if fsb_center == Vector3.ZERO:
    azimuth = Vector3(0.6, 0.0, -0.8)
var from: Vector3 = Ballistics.firing_point(ground, azimuth, SHELL_APEX_M, SHELL_STANDOFF_M)
```
and `ballistics.gd:51-56`:
```gdscript
static func firing_point(impact, azimuth, height, offset) -> Vector3:
    var flat := Vector3(azimuth.x, 0.0, azimuth.z)
    ...
    return impact - flat.normalized() * offset + Vector3.UP * height
```

**`firing_point` NORMALISES the azimuth.** The gun's real distance is discarded. The shell always spawns
at a fixed **300 m back (`SHELL_STANDOFF_M`, `:243`) and 260 m up (`SHELL_APEX_M`, `:242`)**, on a
bearing. `fsb_center` is not a gun position; it is a compass needle.

Three consequences, in ascending severity:

**(a) Two probes and the arena all run on the ZERO fallback.**
- `tests/test_fire_mission.gd:99` calls `r.director.setup(r.world)` and **never** `setup_patrol()`.
- `ai_stress_arena.gd:1451` calls `d.setup(fw)` and **never** `setup_patrol()`.
- `fsb_center` is only assigned in `setup_patrol()` (`field_director.gd:767`).

So in **every headless probe and in the entire AI arena**, `fsb_center == Vector3.ZERO` and the only
thing keeping shells in the air is the hardcoded `Vector3(0.6, 0.0, -0.8)` at `:600`. A2 says
"generalising the gun origin off the hardcoded `fsb_center`". **If that generalisation makes the origin a
required argument and drops the zero-fallback, `tests/test_fire_mission.gd` and `tests/test_arena_sandbox.gd`
both go red on the same commit** — `test_arena_sandbox.gd:81-90` drives `request_fire_support()` across
all six tiers, and `test_playtest_bundle.gd:245-252` drives the mortar dispatch.

**(b) The tube you must go kill will never be where the shells come from.**
This is a design hole, not a bug. Ruling 2 is KILL THE TUBE. For that to be findable in an ADR-029 world
with **no floating markers and no objective counters**, the *only* diegetic breadcrumb the player has is
the sound and the trajectory. But `firing_point` puts every round 300 m out and 260 m up from where it
lands — a near-vertical drop carrying **zero directional information about the tube**. A tube 700 m east
produces a round that materialises 300 m east at 260 m altitude, in the air, out of nothing.

That is a **Fairness Law** problem on its face ("nothing may appear from nothing" — `field_director.gd:862`,
`sapper_charge.gd:8`), and it is a **hunt-design** problem underneath: the player is told to go destroy
something and given no honest way to locate it. He will wander. Then he will conclude the tube does not
exist. **Ruling 2 cannot be implemented on `firing_point` as it stands.** Either the enemy shell spawns
AT the tube and flies a real arc (which means `SHELL_FLIGHT_S = 4.0` at `:241` is wrong for a 400 m tube
and right for a 3 km one — the flight time is currently a constant), or the tube gets a muzzle report
audible from the impact area, or both.

**(c) The FOSSIL LAW makes this all-or-nothing.** A2 says DELETE the originals. `_run_mortar_mission` is
live at `:430`; `_fire_shell` is live at `:428`, `:578`, `:584`. Extraction is fine — but ADR-023 means
the extraction and the deletion and the arena/probe fixes are ONE commit. There is no safe half-landing.
If the wave runs out of time mid-flight, the project ends the day with **two** indirect paths — the exact
disease the decree exists to prevent.

---

## 5. THE THIRD CALL SITE — and the ratified refactor that is about to eat it

The task asked whether the arena is a third firing path. **It is not** — `ai_stress_arena.gd:1448`
constructs a real `FieldDirector.new()` and reuses the one chain. That is good news, and it is the one
place this codebase already did the right thing.

But it is a third **call site with a hand-built environment**, and the environment is the part that breaks:
`ArenaFlatTerrain` (`:66`), `ArenaFireWorld` (`:54-57`), a frozen `SquadSystem` with
`set_physics_process(false)` (`:1441-1442`), `_hunter_pool = 0` (`:1459`), and `fsb_center` left at ZERO.
**A3 stamps the tube via `SitePlanner.stamp_vc_camp` — and the arena has no SitePlanner and no site
generation** (`:56` says "generation disabled"). **The project's primary AI testbed therefore cannot
exercise the new enemy weapon at all.** Every behavioural question about the VC mortar — does the squad
react, does the walk-on look right, does the tube get found — has to be answered in the full generated
world, which is slower and less deterministic.

Worse: bead **`b6lr` is RATIFIED** — *"one world one bench: arena becomes a thin wrapper, terrain_lab dies."*
Whatever the implementer hand-wires into `_wire_fire_support()` this week is scheduled to be deleted.
That is wasted work by ratified decree.

---

## 6. A4 RIDES A ROLL THAT FIRES AT MOST ONCE PER OPERATION, AT NIGHT, AND MOSTLY WHEN THE PLAYER IS NOT THERE

`_maybe_launch_sappers()` (`field_director.gd:957-968`) verified:
- `:958` returns unless `MissionWeather.is_night`,
- `:961` `_sapper_launched` — **one launch per operation, ever**,
- `:961` `_sapper_rolled_night` — one roll per night,
- `:963` requires `patrol_count >= 1` and `fsb_center != ZERO`,
- `:966` `SAPPER_CHANCE` (`:714`) = **LOW 0.0** · MODERATE 0.2 · HIGH 0.45 · CRITICAL 0.7.

So a FSB barrage riding this roll:
- **never fires at LOW threat** — which is where a new player lives,
- fires **at most once per operation**,
- fires **only at night**,
- and — the part nobody has said out loud — **the sapper roll is not gated on the player being at the
  firebase.** `_poll_firebase_threat` (`:884-885`) requires `patrol_out`; the sapper roll does not. A
  night barrage on the FSB is therefore just as likely to happen while the player is 900 m out in the
  jungle, where he will hear it as... one more `explosion.wav` from `ambient_war`.

**The Summoner asked for stand-off barrage on the firebase. Riding SAPPER_CHANCE delivers a thing he will
witness perhaps once every three operations.** If the intent is "the base feels besieged", this wiring
cannot produce that feeling. It needs its own roll, its own cadence, and a presence check.

The field walk-on half (A4) is gated "observed + static + live tube in range". **"Static" is the trap.**
Punishing a static player is correct doctrine and it is also the mechanic that punishes the player who
is doing the thing the game most wants him to do: stop, look, listen, glass a treeline. ADR-029 is an
open patrol simulator; observation is the verb. A mortar that punishes standing still teaches the player
to never stand still, which flattens the exact behaviour Pillar 2 (atmosphere) and Pillar 1 (believable
firefights) depend on. **Named sacrifice: the walk-on buys tension at the price of the halt.** It needs a
generous timer and a clear escape, or it will quietly delete patrolling-by-observation from the game.

---

## 7. THE ART TRAP — CONFIRMED, AND WORSE THAN THE BRIEF SUGGESTS

Verified by `find assets -iname "*mortar*" -o -iname "*artil*"` across the whole tree. **Complete results:**
```
assets/audio/vo/joe the radio man voice/radio_mortar_mission.wav
assets/building models/structures/converted/artillery_pit.glb
assets/building models/structures/converted/mortar_pit_FRAInfantry.png
```
**`mortar_pit.glb` does not exist. Only its texture does.**

And yet `scripts/world/collision_table.gd` declares it **twice**:
```gdscript
:87   "mortar_pit": {"box": Vector3(1.9, 1.5, 2.0), "y_offset": 0.51, "footprint": Vector2(3.0, 3.5), "scale": 1.0},
:179  "mg_nest": Mat.EARTH, "mg_nest_sandbag": Mat.EARTH, "mortar_pit": Mat.EARTH,
```
**These are two live FOSSILS in the collision table for a model that is not on disk** — and they are
string dictionary keys, so `tests/test_fossils.tscn` (which hunts symbols) will never see them. This is
the FOSSIL LAW's stated failure mode: *a lie in the map that survives every grep.* Correct it or bead it
in this same change (NO MORE DRIFT). Note also that `war_room/2026-07-18_fsb_root_cause/analysis/
technical_director.md:39,:78` discusses a `mortar_pit_002-col` mesh with a recessed pit floor — a doc
asserting the state of an asset that is not there. Third drift artefact on the same phantom.

**If the implementer substitutes `artillery_pit.glb`, the scale is catastrophic.** `collision_table.gd:56`:
```gdscript
"artillery_pit": {"box": Vector3(40.0, 9.9, 55.1), ..., "footprint": Vector2(41.0, 56.5)}
```
**40 m × 9.9 m × 55.1 m.** Against `GAME_SCALE_STANDARD.md:8` — **character height 1.7132 m**. That is a
structure **32 soldiers long, 23 wide, and 5.8 tall**, standing in for a VC 82 mm tube that in reality is
three men, a baseplate and a hole. It would be the largest single object in the AO, it would dwarf the
firebase bunkers, and it would need a `SitePlanner.clear_and_flatten` footprint bigger than the VC camp
itself (`site_planner.gd:676` gives the camp `radius: 16.0` — the pit is 3.5× the camp).

`collision_table.gd:87`'s **1.9 × 1.5 × 2.0** is the honest number for a mortar pit. **The art does not
exist. This decree has an unbudgeted art dependency**, and the two P0 art-debt beads (`imue`, `lpib`) say
the art pipeline is the thing least able to absorb it. A dirt-berm-and-tube built from primitives is the
only honest stopgap, and it should be named as one, not shipped as final.

---

## 8. THE TEST TRAP — the specific assertions at risk

| File:line | Assertion | Risk |
|---|---|---|
| `test_fire_mission.gd:258` | mortar ring == `MORTAR_SHEAF_M + MORTAR_BLAST_M` | **HIGH** — dies if FirePlan suppression radii get folded into `footprint()` |
| `test_fire_mission.gd:250-255` | fo 8 draws tighter than fo 0, mortar and arty | **MED** — a VC gun has no `fo_fac`; if `sheaf_scale` grows a "no-RTO" branch this shifts |
| `test_fire_mission.gd:286,302` | loads `mortar_81mm.tres`, asserts `projectile_data.id == "mortar_81mm"` | **MED** — if the VC 82 mm reuses this `.tres` the identity test still passes but the fossil question opens; if a new `mortar_82mm.tres` appears, nothing covers it |
| `test_fire_mission.gd:263-280` | `Ballistics.solve_velocity` lands < 0.25 m | **HIGH if A2 changes flight time** — the VC tube needs a range-dependent flight time; these three fixed cases assume the constant |
| `test_fire_mission.gd:96-102` (`_make_rig`) | `setup()` only, `fsb_center == ZERO` | **CRITICAL** — the whole probe runs on the `:599-600` zero-fallback A2 proposes to generalise away |
| `test_arena_sandbox.gd:81-90` | all six tiers dispatch and decrement | **CRITICAL** — same zero-fallback dependency |
| `test_playtest_bundle.gd:245-252` | `request_fire_support("mortar")` decrements | **CRITICAL** — same |
| `test_playtest_bundle.gd:229-230` | mortar stock >= 3 after grant | **MED** — any change to `_grant_fire_support` for enemy-tube interplay |
| `test_fire_support_grant.gd:96-97` | mortar == 3 with no RTO across every tier | **MED** — same |
| `test_firebase_defense.gd:246-261` | `launch_sapper_assault` produces exactly `SAPPER_COUNT` in group `sapper_assault` + a separate loud element | **HIGH** — A4 rides this exact function. Adding a barrage inside `launch_sapper_assault` or `_maybe_launch_sappers` risks the group counts and the `_sapper_launched` latch |
| `test_firebase_defense.gd:291-312` | breach docks live mortars to 0 and shorts the next allotment | **MED** — `on_firebase_breach` (`field_director.gd:943-951`) hard-sets `fire_support["mortar"] = 0`. If IndirectFire is shared, verify the enemy tube's ammo is not accidentally routed through `fire_support` |
| `test_fire_mission.gd:311-313` | `spooky_gunship.gd` absent from disk, `SpookyGunship` not in ClassDB | **PATTERN** — this is the shape the fossil test for the deleted `_fire_shell`/`_run_mortar_mission` must copy. A2 is not done until this probe has its twin. |

**Suppression has no probe today.** Grep confirms `apply_suppression_in_area` appears in **zero** test
files. A1 is a change to a system with no regression coverage whatsoever, in a codebase whose standing law
is that a decree item closes on a probe. The suppression probe must land *before* the faction change,
not with it, or there is no baseline to regress against.

---

## 9. WHAT THE PLAYER LOSES — every element, no free lunches

**The faction-blind suppression change:**
- His squad's aggression, if §2 is not fixed. That is the whole game.
- **Learned balance.** He has played the current game and knows his men push. `ally_base.gd:362-364`'s
  own comment says allies "default to the aggressive stand-and-push the Summoner liked" and that low
  posture is deliberately "a HIGH bar." Making them suppressible from a new direction lowers that bar
  without anyone deciding to.
- **His own screen.** `player.gd:1250 add_suppression` drives a shader overlay, camera shake, and a
  **Master-bus lowpass filter** (`player.gd:1240-1247`). Player suppression is not a stat, it is a
  sensory takeover. Under a barrage he goes deaf and blurry — which is correct and terrifying, and
  which also means he cannot hear the ambient/real distinction §1 already broke, and cannot hear his
  squad. Named cost: **fear is bought with information.**

**The field walk-on:** costs him the halt. See §6.

**KILL THE TUBE:** costs him the counter-battery loop `8xo3` itself proposed ("a counter-battery call on
the net would make the RTO the answer") — a loop that would have made the RTO more valuable, which is
Pillar 4 (the squad is the RPG). The ruling is settled; the cost is real and should be recorded: the RTO
gains nothing from this feature, and the answer to the enemy's best weapon is the player's boots, not his
squad. That is a Pillar-4 debit, paid for a Pillar-3 credit (freedom: go find it yourself).

**The FSB barrage:** costs him the safety of home. That is the point. But it also costs the firebase its
role as the *recovery* beat in the loop — ADR-029's rhythm is walk out, take contact, come home, bank the
AAR at the gate (`field_director.gd:602-614`). Shelling the recovery beat removes the only lull in the
game. **Pillar 5 (fail forward) is about escalation, not attrition without respite.**

---

## 10. THE CASE AGAINST DOING THIS WORK NOW — made as strongly as I honestly can

Measured today: **123 rows from `bd list --limit 0`**, five P0.

1. **`RECONgame-qqor` is OPEN, P1: "PLAYTEST: the placed fire mission and the new warheads (Summoner's
   eyes)."** The **player's** indirect-fire system — the one A2 proposes to gut and re-extract — **has
   never been seen by the Summoner.** We are about to refactor, generalise, and build a second consumer
   on top of a system whose *first* consumer is unverified. If the placed fire mission turns out to feel
   wrong in his hands, the extraction was performed on the wrong shape and the enemy tube inherits the
   flaw. **This is the strongest argument in this document.** `x4qr` (also open, P1) says the same thing
   in different words: *"AWAITING SUMMONER PLAYTEST of the new AAR, not engineering."*

2. **`qrg6` (PLAYTEST R4) is open and undischarged**, and it is the SESSION ENTRY GATE. Its checklist
   asks whether the player can boot, walk out, find a site unguided, take fair contact, and bank at the
   gate. **We do not currently know if the core loop works.** Adding an enemy weapon that fires at the
   player during that loop makes the R4 playtest *harder to interpret* — when he reports "contact felt
   unfair," nobody will know whether that is the AI, the spawn, or the new mortar.

3. **Two P0s (`imue`, `lpib`) are art debt, and §7 proves this decree has an unbudgeted art dependency.**
   We would be adding a new art requirement to a pipeline already flagged P0-broken, and the fallback
   asset is off by a factor of twenty in every dimension.

4. **`p7wx` (P0, IN_PROGRESS) is the terrain relief bug**, paused mid-fix with four named remaining items.
   Indirect fire seats every impact through `terrain_manager.get_height_at()` (`field_director.gd:597`)
   and deforms terrain via `DamageSystem.apply_damage` (`:562`). **Building a new terrain-deforming
   weapon on top of a half-fixed terrain height system is stacking on sand.**

5. **`b6lr` is RATIFIED and will delete the arena wiring** this work must touch (§5).

6. **The gate has a hole and this work is walking through it.** ADR-015 §1 (`ADR-015:17`) blocks *feature
   epics* at creation, by a **manual** `bd dep add`. `8xo3` is typed **`task`**, so it appears in
   `bd ready` today, unlinked — I confirmed it in the listing. A whole new enemy weapon system entered
   the ready queue without ever meeting the gate. That is not a rule being broken; it is the rule's
   known shape. ADR-015's own history section (`:5`) records a markdown law with a **two-hour half-life**.
   This is the same failure with a bead type instead of a file.

**Honest counter-argument, since I owe one:** `kfoz` is a genuine defect fix and genuinely exempt, and it
is small, well-understood, and its fix (with §2's correction) improves the game whether or not the VC ever
get a tube. **The suppression work should go now. The enemy weapon should not.**

---

## 11. RULING ON THE GATE QUESTION

**`kfoz` — EXEMPT. Proceed.** It is a defect: a method that claims to suppress "in an area" and silently
serves one faction, with two of seven ordnance types wired. ADR-015 `:18` exempts bug fixes without
qualification. **Condition: it does not ship without the friendly-exclusion of §2 and a probe that
asserts the player's own rifle does NOT pin his own squad.** A green probe on the broken behaviour is
exactly the "recorded-but-unreal work" ADR-015 `:7` was written to stop.

**`8xo3` — NOT EXEMPT. It must carry a gate link.** My reasoning:

The briefing offers "decree item" as the escape hatch, on the grounds that the Summoner directed it this
session. **I reject that reading, and I think the ADR does too.** ADR-015 `:18` exempts *"items explicitly
ordered by a **standing** decree"* — the word is *standing*, and the standing decree is enumerated in
`GAME_GUIDE.md:118-124`, item 0 of which is **PLAYTEST R4 itself**. A decree issued in the same session
that then exempts itself from the gate is not an exemption; **it is the gate deleting itself.** Under that
logic no feature could ever be gated, because every feature is built in a session where the Summoner
asked for it. The 2-hour half-life in ADR-015's own history is what that looks like in practice.

Note also `GAME_GUIDE.md:167`: *"a task that governs the GATE by law may not be mechanically linked to it"* —
the gate machinery has known edges, and the response to a known edge is to wire it deliberately, not to
walk through it.

**The concrete ruling:**
1. Promote `8xo3` to `epic` and `bd dep add 8xo3 97u3`. It is a new enemy weapon system with new art, new
   AI behaviour, new spawn integration and a system extraction. Nothing about it is a bug fix.
2. **Ask the Summoner to run R4 first.** He is the only one who can discharge it; it is a single playtest;
   and it is the cheapest possible unblock. Put it to him glossed, per the decision-queue law.
3. If he wants the mortar built before R4, **he can say so and the gate opens by his authority** — Law 3,
   the Summoner holds final authority. But he should be *asked*, not routed around by a definition. A gate
   that an agent can reason its way past is `k77e` again: a gate that blocked nothing, for ninety-five
   commits.

**What is sacrificed by my own ruling:** the session's momentum. The council convenes, produces a plan,
and I am telling it to stop and go ask. That is a real cost and I am naming it. It is smaller than the
cost of refactoring an unplaytested fire-support chain into a shape the Summoner has not yet approved of
in his hands.

---

## 12. IF IT IS BUILT ANYWAY — the minimum bar

1. `apply_suppression_in_area` gains a source/faction parameter; `weapon_holder.gd:444` excludes friendlies
   **in the same commit**; probe asserts a 30-round burst leaves squad `suppression_level` at 0.
2. `_fire_shell`'s zero-origin fallback (`:599-600`) **survives extraction**, or `test_fire_mission.gd`,
   `test_arena_sandbox.gd` and `test_playtest_bundle.gd` are fixed in the same commit.
3. The enemy shell **originates at the tube**, or the tube gets an audible muzzle report from the impact
   zone. Otherwise ruling 2 has no breadcrumb and the Fairness Law is broken.
4. The warning is **not** `show_damage_direction` (it only fires on damage) and **not** the ambient
   explosion sound (it is already scenery). It needs a distinct, close, unmistakable audio event.
5. `MORTAR_SUPPRESS_M` / `ARTY_SUPPRESS_M` added to FirePlan, **separate from `footprint()`**;
   `test_fire_mission.gd:258` stays green untouched.
6. `collision_table.gd:87` and `:179` fossil entries for the non-existent `mortar_pit.glb` corrected or
   beaded in the same change. `GAME_GUIDE.md:184` and `:138` corrected — they currently assert, with the
   word *Verified*, a system that does not exist.
7. A twin of `test_fire_mission.gd:309-313` proving `_fire_shell` and `_run_mortar_mission` are gone from
   `field_director.gd`. ADR-023 is not satisfied by intent.
