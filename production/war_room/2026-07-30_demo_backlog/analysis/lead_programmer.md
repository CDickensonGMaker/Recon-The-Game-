# LEAD PROGRAMMER — ITEM 2 (Spooky's vulcan) and ITEM 5 (convoys)

**Lens:** implementation correctness and cost. Every claim below carries a `file:line`.
**Measured facts used:** `project.godot:304` `common/physics_ticks_per_second=30` · `project.godot:23`
`run/max_fps=120` · `data/weapons/aircraft_20mm.tres:28` `projectile_speed = 1030.0` ·
`bullet_system.gd:32-36` caps · `gun_fx.gd:66-69` FX caps · `PERF_LEDGER.md` W0 row (ray counters).

---

# ITEM 2 — THE VULCAN

## 2.0 What the code actually says (three corrections to the brief)

1. **The brief's pointer is right.** `spectre_gunship.gd:156-165` `_fire_vulcan` picks a ground point
   (`_zone_point(1.0)`, `:147-153`), paints 3 `BulletTracer`s at it (`:159-161`), then applies
   `CombatManager.apply_explosion_damage(impact, 60, 20, 4.0, null, 0.2)` (`:163`). Confirmed fake.

2. **The brief understates the fossil.** `spectre_gunship.gd:161` is the **only caller of
   `BulletTracer.spawn_tracer` repo-wide** (grep: hits are `bullet_tracer.gd:2`, `:99`, `:100` — its
   own definition — and this one line). Deleting the decorative tracers makes the entire file
   `scripts/combat/bullet_tracer.gd` dead. ADR-023 makes deleting it part of this change, not later.

3. **The brief calls `cas_airplane.gd:238-258` "the pattern to copy". It is the pattern to copy AND
   it carries three live defects of its own.** Copying it verbatim propagates them:
   - `cas_airplane.gd:64-66` — the mask comment is **wrong about the project's own mask law.** It says
     `1 | 32 | 64 | 512` is "world, enemy bodies, enemy hitzones and civilians". `weapon_holder.gd:494-499`
     and `ally_base.gd:1315-1321` both state the law: body capsule layers (ally 2, enemy 3) are OUT on
     purpose, `32` is the **ally hurtbox** and `64` the enemy hurtbox. The *value* is correct and
     identical to an ally rifle's; the *comment describes a mask the project forbids.* Correct on contact.
   - `cas_airplane.gd:256` passes `show_tracer = true` **unconditionally**, ignoring
     `aircraft_20mm.tres:30 tracer_ratio = 2`. At 3 rounds / 0.08 s = 37 rounds/s the strafe alone
     claims tracer visuals from a pool of `MAX_TRACERS = 48` (`bullet_system.gd:33`) and starves the
     firefight's rifle tracers.
   - **The real strafe suppresses NOBODY.** `bullet_system.gd:136-205` `_impact` never touches
     suppression. The only suppressors repo-wide are `combat_manager.gd:212`
     (inside `apply_explosion_damage`), `weapon_holder.gd:527`, and `enemy_base.gd:2599-2606` (a
     shooter's own near-miss channel). So the 2026-07-29 conversion of the CAS gun to real rounds
     **silently deleted its suppression**, exactly the defect `combat_manager.gd:207-211` was written to
     complain about. This is a LIVE regression at HEAD, and item 2 will reproduce it unless handled.

4. **`exclude: [self]` is a no-op for both airframes.** `bullet_system.gd:68-71` only appends RIDs for
   `CollisionObject3D`. `CASAirplane` and `SpectreGunship` both `extends Node3D`. Harmless (the muzzle
   is 130 m up), but it reads as protection that does not exist. Pass `[]`.

## 2.1 The correct conversion — muzzle, aim solution, mask

### Muzzle: the port battery, derived from the basis, never hardcoded

The orbit math already puts the gun side inward, and I verified it rather than trusting the comment.
`spectre_gunship.gd:129-133`:

- position offset from target is `(cosθ, ALT, sinθ)`
- `look_at` forward `f = (sinθ, 0, −cosθ)`, so `basis.z = −f = (−sinθ, 0, cosθ)`
- `basis.x = basis.y × basis.z = (cosθ, 0, sinθ)` — **exactly the radial-OUTWARD vector**

So local **`+X` points away from the orbit centre** and **`−basis.x` is the port side pointing at the
target**. The comment at `:127-128` holds. And because `rotate_object_local(Z, BANK_LEFT_RAD)`
(`:133`) runs before we read the basis, `−basis.x` already carries the 15° pylon bank — the muzzle
axis tilts down into the zone for free. **Do not add a manual downward fudge; the bank IS the fudge.**

```gdscript
## Port battery muzzle. Read from the basis so the pylon bank (`:133`) tilts the gun
## axis into the zone without a second fudge term.
func _port_muzzle() -> Vector3:
	var b: Basis = global_transform.basis
	return global_position - b.x * 3.2 - b.y * 0.9
```

### Aim solution: none needed beyond the ground point. The numbers say so.

- slant range = `sqrt(ORBIT_RADIUS² + ORBIT_ALT²)` = `sqrt(160² + 130²)` = `sqrt(42500)` = **206.2 m**
  (185–228 m across the 25 m beaten disc, `fire_plan.gd:34`)
- flight time = `206.2 / 1030` = **0.2002 s** (`aircraft_20mm.tres:28`)
- **gravity drop over that flight = `0.5 × 9.8 × 0.2002²` = 0.196 m.** Under 20 cm at 206 m, against a
  25 m radius beaten zone. **No drop compensation. No lead.** Aim straight at the ground point.
- the aircraft's tangential speed is `0.35 rad/s × 160 m` = 56 m/s, so the muzzle moves 11.2 m during
  the round's flight — **irrelevant**, the round is ballistic from its release point. This is exactly
  why a side-firing orbiter is *easier* than the CAS jet: `cas_airplane.gd:249` needs
  `STRAFE_LEAD_M = 160.0` to walk its impacts up a run line; an orbiter's beaten zone is stationary,
  so the zone point IS the aim solution and `_zone_point()` (`:147-153`) is already correct.
- each round gets **its own** `_zone_point(1.0)` plus a small dispersion, so the sheet saturates the
  disc instead of converging on one spot.

### Mask: the universal one, unchanged. `1 | 32 | 64 | 512`

Identical to `ally_base.gd:1321`, `weapon_holder.gd:499` and `cas_airplane.gd:66`. World + ally
hurtbox + enemy hurtbox + civilian; body capsules deliberately OUT. **Do not invent a fourth mask.**
(See §2.5 — including `32` has a lethality consequence that needs a ruling.)

## 2.2 THE COST QUESTION — the number is **3 rounds per physics tick = 90 rounds/s**

**The brief asks the cost question against the wrong budget.** `MAX_BULLETS = 500` is nowhere near
binding. The binding budgets are `MAX_TRACERS = 48` (`bullet_system.gd:33`) and
`MAX_DECALS = 48` (`gun_fx.gd:69`).

### The arithmetic

| quantity | value | source |
|---|---|---|
| physics tick | **30 Hz** (0.03333 s) | `project.godot:304` |
| slant range, aircraft → beaten zone | **206.2 m** | `sqrt(160²+130²)`, `spectre_gunship.gd:16-17` |
| projectile speed | **1030 m/s** | `aircraft_20mm.tres:28` |
| **flight time** | **0.2002 s** | 206.2 / 1030 |
| **ticks alive per round** | **6.0** | 0.2002 × 30 |
| distance covered per tick | 34.3 m | 1030 / 30 |
| **rounds in flight at 90/s** | **18.0** | 90 × 0.2002 |
| raycasts added per tick, gun hot | **18** | 1 segment ray per live round per tick (`bullet_system.gd:106-110`) |
| raycasts/s, gun hot | **540** | 90 rounds × 6 ticks |

### Why 90/s and not 30/s or 300/s — the tracer rope is what decides it

`bullet_system.gd:264` `streak = clampf(speed * 0.016, …)` → at 1030 m/s each tracer visual is
**16.5 m long**. With `tracer_ratio = 2` (`aircraft_20mm.tres:30`), tracers in flight =
`rate × 0.5 × 0.2002`:

| rate | rounds in flight | tracers in flight | lit metres of the 206 m line | reads as |
|---|---|---|---|---|
| 30/s | 6.0 | 3.0 | 50 m | three separate tracers — **fails** |
| **90/s** | **18.0** | **9.0** | **148 m of 206 m** | **the minigun rope. This is the look.** |
| 300/s (3 SUU-11s) | 60 | 30 | saturates | 30 of 48 tracer visuals — starves rifle tracers |

**90 rounds/s is one SUU-11 minigun at 90% of its 6000 rpm cadence** — historically honest for an
AC-47, and it is the smallest rate that produces a continuous rope rather than discrete streaks.

### VULCAN_INTERVAL must die, not be retuned

**A 0.35 s interval cannot carry this rate.** 90/s at 0.35 s means spawning **32 rounds in ONE tick**,
which then all arrive within the same tick 6 ticks later — a clump, plus 32 simultaneous `_impact`
calls slamming `MAX_IMPACTS = 12` (`gun_fx.gd:67`). **Fire every physics tick while hot.** Delete
`VULCAN_INTERVAL` (`:23`), `VULCAN_ROUNDS_PER_BURST` (`:24`) and `_vulcan_timer` (`:39`).

### Duty cycle — hot 2.0 s / cold 2.5 s (44%)

A gunner fires bursts. Over the 30 s pass (`DURATION`, `:21`):
`30 × 0.444 × 90` = **~1200 real rounds**, against the old **257 decorative tracers**
(`30 / 0.35 × 3`). Mean rounds in flight ≈ 8, peak 18.

### Headroom check against every cap

| cap | value | Spooky's draw | verdict |
|---|---|---|---|
| `MAX_BULLETS` | 500 | 18 (3.6%) | **not binding.** Even reserving 400 slots allows 400/0.2002 = **1998 rounds/s** |
| `MAX_TRACERS` | 48 | 9 (19%) | fine at ratio 2; **binding above ~250 rounds/s** |
| `MAX_DECALS` | 48, **destructive FIFO** (`gun_fx.gd:753`) | 90/s recycles the whole budget every **0.53 s** | **BINDING. Must be gated — see below** |
| `MAX_IMPACTS` | 12 concurrent, **graceful skip** (`gun_fx.gd:492`) | saturates | self-limiting, acceptable |
| rays/tick | — | +18 | ledger W0 row measures the **whole level** at 2.6 rays/physics-frame and 152–161 rays/s at 65 units, with rays+think ~6% of a 38–40 ms AI wall. 18/tick is ~7× the level's current ray load and **still microseconds.** Not the risk. |

### The one API change this needs: gate the decal, not the round

`bullet_system.gd:197` calls `GunFX.bullet_hole` on every world hit, and `gun_fx.gd:753` FIFO-frees
the oldest to hold 48. At 90 rounds/s **every bullet hole the player made vanishes within half a
second while Spooky fires.** One default parameter fixes it and leaves all four existing call sites
source-compatible:

```gdscript
## `mark_surface` false = the round still impacts, sparks and puffs, but leaves no
## decal. An aircraft gun at 90 rounds/s would otherwise recycle the whole 48-hole
## FIFO twice a second and erase every hole the firefight made.
func fire(wd: WeaponData, shooter: Node, from: Vector3, dir: Vector3,
		mask: int, exclude: Array, show_tracer: bool,
		mark_surface: bool = true) -> void:
```

store `"mark": mark_surface` in the round dict (`bullet_system.gd:72-85`), then at `:197`:

```gdscript
			if bool(b.mark):
				GunFX.bullet_hole(scene, hit.position, hit.normal)
```

**`cas_airplane.gd:256` must pass `false` too** — it has the same defect at 37 rounds/s today.

## 2.3 What is LOST, and what must be kept

Losing the explosion is the point: `combat_manager.gd:230-261` `_can_damage_multipoint` returns true
if **any of 8 points** is visible, so a man behind the berm was killed by a visibility *guess*. Real
rounds mean the berm stops them. Pillar 1 win. But **four things rode on the explosion call**, and
three of them are not free:

| lost | where it came from | must be kept? | how |
|---|---|---|---|
| **SUPPRESSION** | `combat_manager.gd:212` inside `apply_explosion_damage`. `clampf(60/190, .15, 1)` = **0.316** at `4.0 × 2.5` = **10 m**. `bullet_system.gd` suppresses NOBODY. | **YES — this is the whole reason Spooky is terrifying.** Without it, 30 s of gunship fire changes nobody's behaviour unless it kills them, which is the exact sentence `combat_manager.gd:207-211` was written to retire. | one explicit `apply_suppression_in_area(target, 45.0, 0.55)` on a **0.25 s beat** (not per tick — it loops `AgentRegistry.enemies` + `allies`). 45 m is wider and 0.55 stronger than the 10 m/0.316 it replaces: the whole beaten zone should be pinned, not a 10 m dot. |
| **NOISE** | `spectre_gunship.gd:165` `NoiseBus.emit_noise(GUNSHOT, impact, 0, 80.0)` per burst | **YES.** With real rounds there is no single impact point. | emit at `target` (the zone centre) on the same 0.25 s beat, radius **120 m**. This is what `cas_airplane.gd:258` already does. |
| **THE GUN REPORT** | `_play_gun(VULCAN_SFX, 4.0)` (`:158`), once per 0.35 s burst | **YES, AND ON ITS OWN CLOCK.** `_play_gun` (`:62-68`) reassigns `.stream` and calls `.play()` on **one** `AudioStreamPlayer3D` (`:54`). Calling it 30×/s restarts the same voice every tick — the sound would *stop existing*. **The rate-of-fire audio MUST be decoupled from the round spawn rate.** | keep a 0.35 s audio beat while hot. Header `:49-50` already says the report from the aircraft "is the whole reason Spooky is frightening from the ground" — that stays literally true. |
| the 4 m explosion at a chosen point | `:163` | **NO. Delete.** That is the lie. | — |

Everything ambient survives untouched: the T56 prop drone (`:105-115`), the `VIS_END_M = 1200`
airframe cull (`:88-93`), the pylon-turn bank (`:133`), the 30 s station time and the egress
(`:120-126`). **From the ground the aircraft reads exactly as it does today, plus a rope of tracer
that now actually kills, plus a wider suppression footprint.** It gets *more* frightening, not less.

## 2.4 ADR-023 — what dies when this ships

| corpse | pointer | disposition |
|---|---|---|
| `scripts/combat/bullet_tracer.gd` **(the whole file)** + `.uid` | `spectre_gunship.gd:161` is its **only caller repo-wide** | **DELETE.** Verify no `.tscn` references first. |
| `const VULCAN_DAMAGE: int = 60` | `spectre_gunship.gd:25` | DELETE — damage comes from `aircraft_20mm.tres:17` (`base_damage = 87`) |
| `const VULCAN_INTERVAL` / `VULCAN_ROUNDS_PER_BURST` / `var _vulcan_timer` | `:23`, `:24`, `:39` | DELETE — replaced by the per-tick duty cycle |
| `FirePlan.SPECTRE_VULCAN_KILL_M = 4.0` | `fire_plan.gd:35` | **CANNOT simply be deleted** — `fire_plan.gd:58` uses it for the map ring. Left alone it becomes a fossil: a "kill radius" constant with no kill radius behind it. **Rename to `SPECTRE_DISPERSION_M = 3.0`** and have `footprint("spectre")` read the beaten radius + the sheet's real dispersion, so the ring the player draws still comes from the numbers that do the killing (`fire_plan.gd:1-10`). |
| the class header's factual claims | `spectre_gunship.gd:1-7` | **REWRITE.** It says *"Individual rounds are not modelled; a burst lands as one small blast"* — false the moment this ships — and calls the aircraft an **AC-130 "Spectre"** while `AIRFRAME_SCENE` is `ac47_spooky.glb` (`:11`) and the radio VO is `radio_spooky.wav` (`field_director.gd:508`). Both are drift; NO-MORE-DRIFT says correct on contact. |
| `[self]` in the `exclude` arg | `:new code`, `cas_airplane.gd:256` | pass `[]` — see §2.0.4 |

## 2.5 THE RISK THAT NEEDS THE ARBITER, NOT THE PROGRAMMER

`combat_manager.gd:146-150`: **`apply_explosion_damage` with `attacker == null` — which is what
`:163` passes — does only 0.4× to allies and the player.** "Asymmetric danger-close: INDIRECT fire
does ~0.4x to your own men, so a called strike threatens without deleting your squad."

**`BulletSystem` has no such attenuation.** So the conversion silently deletes it:

- old fake Vulcan on a friendly: `60 × 0.4` = **24 max**, minus falloff.
- real round on a friendly: `87 × 2.5` (TORSO, ADR-016) = **217**, HEAD = fatal by law, at 206 m with
  `min_damage_mult = 0.85` and `effective_range = 900` so falloff ≈ **1.0**. **One round, one man.**

Player HP is 100 (CLAUDE.md). **The player calling Spooky onto a treeline 40 m from his own squad
would delete the squad and himself.** And `air_traffic.gd:250-267` flies Spooky *ambiently* — the
keep-out only pushes the orbit off the **firebase**, not off a patrol in the field. **This is already
true of the CAS gun run at HEAD** (`cas_airplane.gd:256`) and nobody has reported it because the
Ordnance.GUNS path may not have been flown at a friendly yet.

Cheapest fix that invents no second number — reuse `combat_manager.gd:150`'s own 0.4:

```gdscript
## `friendly_mult` mirrors the asymmetric danger-close already ruled for indirect fire
## (combat_manager.gd:146-150): a called air gun threatens the squad without deleting it.
func fire(wd: WeaponData, shooter: Node, from: Vector3, dir: Vector3,
		mask: int, exclude: Array, show_tracer: bool,
		mark_surface: bool = true, friendly_mult: float = 1.0) -> void:
```

applied in `_impact` when the struck `target` is in `"allies"` or `"player"`. **Both aircraft pass
0.4.** Whether air guns get the indirect-fire discount at all is a Pillar-1-vs-Pillar-5 call and
belongs to the Arbiter; I will not choose it. But shipping item 2 **without** choosing it means
shipping full 20 mm lethality onto the player's own squad from an *ambient* aircraft.

## 2.6 Proposed implementation, strict-typing clean

```gdscript
const VULCAN_WEAPON: String = "res://data/weapons/aircraft_20mm.tres"
## Rounds per PHYSICS TICK while hot. 3 x 30 Hz = 90 rounds/s = one SUU-11 at 90% of
## 6000 rpm, and the smallest rate whose tracers read as a rope rather than as streaks
## (16.5m per visual, 9 in flight, 148m of a 206m slant line lit).
const VULCAN_ROUNDS_PER_TICK: int = 3
const VULCAN_BURST_S: float = 2.0
const VULCAN_PAUSE_S: float = 2.5
const VULCAN_TRACER_EVERY: int = 2         ## == aircraft_20mm.tres tracer_ratio
const VULCAN_DISPERSION_M: float = 3.0
const VULCAN_MASK: int = 1 | 32 | 64 | 512
const VULCAN_FRIENDLY_MULT: float = 0.4    ## combat_manager.gd:150 parity
## Suppression, noise and the gun report each run on their OWN clock. The report in
## particular MUST NOT follow the round rate: _play_gun reuses one voice, so calling it
## every tick would restart the sample 30x/s and silence the aircraft.
const VULCAN_BEAT_S: float = 0.25
const VULCAN_AUDIO_BEAT_S: float = 0.35
const VULCAN_SUPPRESS_M: float = 45.0
const VULCAN_SUPPRESS_AMOUNT: float = 0.55
const VULCAN_NOISE_M: float = 120.0

static var _vulcan_wd: WeaponData = null
var _vulcan_hot: bool = true
var _vulcan_phase: float = VULCAN_BURST_S
var _vulcan_shots: int = 0
var _vulcan_beat: float = 0.0
var _vulcan_audio: float = 0.0


## Port battery muzzle. Read from the basis so the pylon bank (`:133`) tilts the gun
## axis into the zone without a second fudge term.
func _port_muzzle() -> Vector3:
	var b: Basis = global_transform.basis
	return global_position - b.x * 3.2 - b.y * 0.9


## One physics tick of the side battery. Rounds are REAL: spawned at the port muzzle,
## flown under gravity, resolved by BulletSystem - the berm stops them, not a guess.
func _fire_vulcan_tick(delta: float) -> void:
	_vulcan_phase -= delta
	if _vulcan_phase <= 0.0:
		_vulcan_hot = not _vulcan_hot
		_vulcan_phase = VULCAN_BURST_S if _vulcan_hot else VULCAN_PAUSE_S
	if not _vulcan_hot or CombatManager.bullets == null:
		return
	if _vulcan_wd == null:
		_vulcan_wd = load(VULCAN_WEAPON) as WeaponData
	if _vulcan_wd == null:
		push_warning("[SPOOKY] %s missing - the side battery fires nothing" % VULCAN_WEAPON)
		return
	var muzzle: Vector3 = _port_muzzle()
	var no_exclude: Array = []
	for i in range(VULCAN_ROUNDS_PER_TICK):
		var aim: Vector3 = _zone_point(1.0)
		aim.x += randf_range(-VULCAN_DISPERSION_M, VULCAN_DISPERSION_M)
		aim.z += randf_range(-VULCAN_DISPERSION_M, VULCAN_DISPERSION_M)
		var dir: Vector3 = (aim - muzzle).normalized()
		_vulcan_shots += 1
		var tracer: bool = (_vulcan_shots % VULCAN_TRACER_EVERY) == 0
		CombatManager.bullets.fire(_vulcan_wd, self, muzzle, dir, VULCAN_MASK,
			no_exclude, tracer, false, VULCAN_FRIENDLY_MULT)
	_vulcan_audio -= delta
	if _vulcan_audio <= 0.0:
		_vulcan_audio = VULCAN_AUDIO_BEAT_S
		_play_gun(VULCAN_SFX, 4.0)
	_vulcan_beat -= delta
	if _vulcan_beat <= 0.0:
		_vulcan_beat = VULCAN_BEAT_S
		CombatManager.apply_suppression_in_area(target, VULCAN_SUPPRESS_M, VULCAN_SUPPRESS_AMOUNT)
		NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, target, 0, VULCAN_NOISE_M)
```

`_physics_process` (`:135-138`) becomes `_fire_vulcan_tick(delta)` with no timer. `_fire_bofors`
(`:168-179`) is untouched — real arcing shells were already correct, and after this the airframe holds
**one** idea of what a round is.

## 2.7 What item 2 SACRIFICES

1. **The berm now protects, both ways.** Enemies in the parapet, the bunkers and any trench survive a
   Spooky pass they used to die in. That is the intent — and it means **Spooky is no longer a reliable
   way to break a dug-in siege element.** The fire mission gets weaker against exactly the enemy the
   player calls it on. The C3 overrun push (item 1) inherits that.
2. **48 bullet-hole decals go missing near the player during a pass** unless `mark_surface` ships with
   it. With it: the beaten zone leaves dust and sparks but **no permanent pockmarking** — the ground
   Spooky worked over looks untouched afterwards.
3. **`MAX_IMPACTS = 12` saturates**, so rifle impact puffs in the player's own firefight get skipped
   for the 2 s the gun is hot. Graceful (`gun_fx.gd:492`) but visible.
4. **The map ring becomes an approximation.** Today `footprint("spectre")` is a lethality radius; after
   this it is a *sheet dispersion* radius with soft edges. The circle no longer means "everything here
   dies."
5. **A new coupling:** the gunship's read now depends on `BulletSystem`'s tracer pool, decal FIFO and
   impact cap. Retuning any of those three retunes Spooky's look without touching Spooky.
6. **+18 raycasts/tick and ~1200 round-dictionary lifetimes per pass.** Not measurable per the ledger,
   but it is not zero, and it stacks with the siege.

---

# ITEM 5 — CONVOYS

## 5.1 Is the "the fix is ROUTING, not collision" ruling right? **Half right — and the brief describes a road that does not exist.**

**The ruling's premise is right and already implemented.** `mission_generator.gd:337-342` builds the
route from `world.road_network.longest_route()` (`road_network.gd:266-276`) and **refuses to spawn a
convoy at all** if there is no road: `return  # no road, no convoy - a truck does not drive through
jungle` (`:342`). `convoy.gd:3-5` says the same. **Routing is not missing.** A convoy today already
drives a real A*-solved, terrain-seated polyline.

**But the brief's picture — "a real road route from the map edge to the firebase gate" — does not
exist as data.** `road_network.build(gate_pos, village_centers)` (`road_network.gd:71-82`, called at
`mission_generator.gd:592-593` and `:713-714`) makes **the gate the hub and the villages the spokes.
There is no map-edge road and nothing routes to one.** So `longest_route()` returns a
**gate → village** polyline, `route[0]` **is the gate**, and the convoy drives **outward from the
firebase into a village** — the opposite of the demo picture. **The code contradicts the brief here,
and this is the load-bearing contradiction of item 5.**

## 5.2 So what is actually broken — four defects, in order of how visible they are

1. **THE COLUMN SPAWNS INSIDE THE FIREBASE.** `convoy_spawner.gd:86-87`:
   `back = -heading.normalized() * (i * 6.0)`, then `DestructibleVehicle.create(cv, …, start + back, …)`.
   `start` is `route[0]` = `gate_pos`, and `-heading` points **into the compound**. With
   `CONVOY_MAX = 6` (`mission_generator.gd:358`) that puts vehicles 2–6 up to **30 m inside the wire**,
   dropped by absolute position on top of the berm, the parapet and whatever `fsb_main_v3` has there.
   **This, not the routing, is the "convoys drive through buildings" the player sees.**
2. **THE TRUCKS NEVER TURN.** `convoy_spawner.gd:80-81` sets `yaw` **once** at spawn.
   `convoy.gd:76-93` assigns only `.x/.y/.z` — **`rotation` is never touched again.** On a polyline
   resampled every 10 m (`road_network.gd:34`) around A* bends the whole column **crabs sideways and
   drives backwards.** One line of missing code, and it is more visible than any building.
3. **THE ROUTE ENDS IN THE MIDDLE OF A VILLAGE.** `_route(gate, dest)` terminates at the village
   *centre*, where the huts are stamped.
4. **THE ROAD ROUTER IS STRUCTURALLY BLIND TO BUILDINGS, AND CANNOT BE FIXED CHEAPLY.**
   `road_network.gd:155-171` `_cell_cost` reads **only** `get_terrain_type_at` and `get_slope`.
   `terrain/core/gameplay_grid.gd:50-54` carries elevation / slope / terrain_type / vegetation /
   is_passable — **no structures at all**, and `is_passable` is written only from CLIFF and WATER
   (`:136-137`). Worse, `cell_size_meters = 12.0` (`gameplay_grid.gd:11`): **a hut is smaller than one
   grid cell.** No amount of cost tuning can make this router miss a hut. It is not a bug in
   `road_network.gd`; it is a resolution floor.

Note also `convoy_spawner.gd:93` deliberately `remove_from_group("nav_blockers")` because the navmesh
was baked at world build (`nav_baker.gd:9-21`). Correct, and it confirms **nothing intends convoy
vehicles to interact with navigation or collision** — `destructible_vehicle.gd:12-13` sets
`collision_layer = 1, collision_mask = 0`. The trucks are moving scenery by design.

## 5.3 Cheapest implementation that makes a convoy visibly drive a road and through the gate

**Honest answer: driving a road is a DEMO-SCALE fix. Driving *through the gate* is NOT.**

The compound interior is a GLB parsed as `-colonly` trimeshes (`nav_baker.gd:30-46`) at 185 m half-
extent. A 12 m grid cannot route between its bunkers, and there is no motor-pool destination marker in
the road data. Routing a truck *inside* the wire to a parking spot is a multi-session job: it needs an
interior route source (station markers, per `recon-station-architecture`), a gate-gap datum, and
vehicle-scale clearance the infantry navmesh does not model. **Do not attempt it for the demo.**

### The smallest slice worth shipping — "THE SUPPLY RUN COMES IN AND HALTS AT THE WIRE"

A convoy appears at the map edge, drives a real road inbound, **faces the way it is going**, stops
just outside the gate, dwells, and is gone. Five changes, ~60 lines, three files, one session.

**(a) Give the network a road to come FROM.** One extra A* run at world build, behind the loading
screen — `road_network.gd:95` already says "Runs once, behind the loading screen."

```gdscript
## The supply route: the wire gate to the nearest map edge. A convoy needs a place to
## come FROM, and the village spokes only ever run outward. Index 0 is the GATE end.
var gate_route: PackedVector3Array = PackedVector3Array()

func build(gate_pos: Vector3, village_centers: Array, map_size: float = 0.0) -> void:
func _nearest_edge_point(from_pos: Vector3, map_size: float) -> Vector3:
```

Built **after** the village spokes so `BRAID_DISCOUNT` (`:46`) makes it merge onto an existing road
where it can, which is the behaviour that already produces junctions with no junction code.

**(b) Drive it INBOUND.** `mission_generator.gd:337-340` reads `gate_route` reversed instead of
`longest_route()`. Keep `longest_route()` — `topo_map.gd:162` and `AmbushPlanner` still consume
`segments`, so nothing dies here.

**(c) HEADING — the single most visible line in item 5.**

```gdscript
## Face the way you are going. Without this the column crabs sideways round every
## A*-bend, which reads as broken long before anyone notices a clipped hut.
const TURN_RATE: float = 2.5

func _steer(v: Node3D, dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want: float = atan2(dir.x, dir.z)
	v.rotation.y = lerp_angle(v.rotation.y, want, minf(1.0, TURN_RATE * delta))
```

called for the lead with its travel `dir` and for each trailer with `-back.normalized()`.

**(d) HALT SHORT of the wire, do not drive into it.**

```gdscript
## Stop this far short of the final waypoint and hold. The road ends AT the wire gate;
## nothing routes inside the compound, so nothing may drive in.
var halt_short_m: float = 0.0
```

checked against `route[route.size() - 1]` in `_physics_process`; on arrival emit `route_finished` after
a dwell. `convoy_spawner.gd:112-114` already frees the convoy on `route_finished`.

**(e) STRING THE COLUMN ALONG THE POLYLINE, not along a straight `-heading`.** This is the fix for
defect 1, and it is what stops vehicles materialising inside buildings:

```gdscript
## Walk `dist` metres backward along the route from its start, so a 6-vehicle column
## strings out ON THE ROAD instead of being translated straight back off it - which is
## how trailing trucks ended up 30m inside the firebase wire.
static func _point_back_along(route: Array, dist: float) -> Vector3:
```

## 5.4 What item 5 SACRIFICES

1. **Nothing drives inside the base.** No motor-pool arrival, no unloading spectacle at the wire —
   the trucks halt outside and despawn. Straight cost against the ship gate's "supplies unloading",
   which stays a Huey-only beat.
2. **Huts on the *village* spokes are still clipped.** Fixing that needs structure awareness the
   12 m grid cannot express (§5.2.4). The slice only guarantees the **gate route**.
3. **Trucks still collide with nothing** (`destructible_vehicle.gd:12-13`, `convoy.gd:80`
   `global_position` assignment). A felled tree, a crater, a player standing on the road: passed
   straight through. Ruling accepted — routing, not collision.
4. **No suspension, no pitch, no roll.** `_ground_y` (`:114-117`) seats Y only; a truck stays
   perfectly flat climbing a hill. Only heading is fixed.
5. **One more A* run per world build** (~256² grid). Behind the loading screen, unmeasured but of the
   same order as the existing per-village runs.
6. **`longest_route()` stops being what convoys use**, so it becomes a query with one remaining
   consumer. Watch it for fossilhood rather than deleting it — `topo_map.gd` and `AmbushPlanner` read
   `segments` directly, not this.

---

## Ledger note

Neither item is a draw-call change, which is the dimension `PERF_LEDGER.md` says this project is bound
by (canopy +6.3 FPS / ~70% of draw calls is the only lever above noise at ship parity). Item 2 spends
**physics-tick raycasts and FX-pool slots**; item 5 spends **one load-time A***. Neither belongs in the
FPS ledger. Item 2's costs belong in `bullet_system`'s own `_peak_bullets` / `_cap_hits`
instrumentation (`:42-43`), which should be read **after** the first siege-plus-Spooky run — that is
the measured number `MAX_BULLETS` should be set from, and the file already says so (`:41`).
