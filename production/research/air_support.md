# Vietnam Close Air Support — Authenticity Tuning Reference

Research doc for tuning RECONgame's CAS system. Feeds two additions:
an **F-4 Phantom fast horizontal flyby** and a **CBU cluster-bomb ordnance
type**, both built to reuse the existing `CASAirplane` pattern
(`scripts/vehicles/cas_airplane.gd`) and the fire-support dispatch in
`scripts/missions/mission_director.gd`.

Nothing in project code was modified. This is a plan only.

---

## 1. Authentic Numbers Table

### Aircraft delivery profiles

| Parameter | A-1 Skyraider ("Spad/Sandy") | F-4 Phantom II | Notes for game |
|---|---|---|---|
| Role | CSAR escort, loiter CAS, dive-bomb | Fast-mover CAS, single-pass | A-1 = the current 4-phase dive; F-4 = new horizontal flyby |
| Top speed | ~320 mph / 515 km/h (~144 m/s) | Mach 2 / ~2,370 km/h (~660 m/s) | Never fly F-4 at real top speed — read below |
| **Napalm/low CAS run-in speed** | **250–275 KIAS (~130–140 m/s)** | **~450–500 kt (~230–260 m/s)** | Game `SPEED`: A-1 = 120, **F-4 = 240–260** |
| Roll-in altitude | 1,200 ft AGL (~365 m) | 1,200 ft AGL, then descend | Not simulated; start high, arrive low |
| **Napalm release altitude** | **level out 50–75 ft (15–23 m)** | same, 50–100 ft | Game F-4 run altitude **≈ 25–35 m** |
| Dive-bomb params | 30°–45° dive, pickle ~1,200 ft, recover 900–1,000 ft | shallow/level toss | Matches existing A-1 `DIVE`→`RELEASE`→`CLIMB` |
| Loiter | hours (piston, low fuel burn) | minutes (thirsty jet) | Flavor: A-1 lingers, F-4 is one loud pass and gone |

Sources: globalmilitary.net A-1 vs F-4 compare; NMUSAF "Dangerously Close"
CAS fact sheet (250–275 KIAS, pickle 1,200 ft); NASM Super Sabre (napalm:
roll in 1,200 ft, level 50–75 ft, hold heading, drop).

### Ordnance footprints

| Ordnance | Real payload | Ground footprint | Game mapping |
|---|---|---|---|
| **Napalm** (BLU-1 / BLU-27, ~130 gal) | tumbling canister of thickened gasoline | **270 ft × 75 ft = ~82 m long × 23 m wide**; single can ≈ 2,500 sq yd (~2,100 m²) | Current strip: 5 drops × 15 m = 60 m. Bump to ~80 m long, add lateral jitter for the 23 m width |
| **CBU-24 cluster** (SUU-30 dispenser) | **665 × BLU-26** "tennis ball" bomblets, ~300 steel balls + 85 g Cyclotol each, impact-fused | **opens at preset altitude, scatters over 120 ft × 200 ft = ~37 m × 61 m** | New `Ordnance.CBU`: many small blasts over a 60 m × 40 m ellipse, no fire, tiny craters |
| Snake Eye bomb (Mk-82 retarded) | 500 lb HE, fin-retarded for low drop | single large crater | Current `Ordnance.BOMB` (220 dmg, 16 m radius, 1 crater) |
| **Arc Light** (B-52 cell, 3 ship) | ~108 × 500/750 lb per cell | **box 1.2 mi × 0.6 mi ≈ 3,000 m × 500 m** | Out of scope but noted; if ever added: carpet of MEDIUM_EXPLOSION across a huge rectangle, no aircraft visible, pure sound + earth |
| **Spooky / "Puff"** (AC-47) | 3 × 7.62 mm miniguns, 6,000 rpm each (50–100 rps selectable) | left-hand pylon-turn orbit at **2,500–3,000 ft**; saturates a small area — ~1 round per sq yd over a football-field patch in a few sec | Already implemented as `SpookyGunship`. Confirmed authentic: keep tight orbit + dense stream |

Sources: Wikipedia Napalm (270×75 ft, 2,500 sq yd, 130 gal); Wikipedia
CBU-24 / globalsecurity (665 BLU-26, 120×200 ft); Wikipedia Operation Arc
Light (1.2×0.6 mi; 3 km×0.5 km); Wikipedia AC-47 Spooky (6,000 rpm, pylon
turn, 2,500–3,000 ft).

### Danger-close (for toast warnings / squad-safety checks)

| Weapon | Danger-close distance |
|---|---|
| CAS (general, air-delivered) | **100 m** to friendlies |
| Mk-77 napalm (0.1% incapacitation) | **150 m** |
| Artillery / mortar | 600 m |
| Naval gunfire | 750 m |
| Vietnam reality (desperate drops) | as close as **50 m** (165 ft) |

Source: MCWP 3-23.1 risk-estimate distances; Britannica/Wikipedia napalm.
Use these as the ranges at which the game should flash "DANGER CLOSE — GET
DOWN" and start hurting the player/squad if they're inside.

### Sound / visual signature of a fast jet pass

- **You see it before you hear it.** Sound is "retarded" — the noise
  arriving now was emitted from a point the jet already left. At ~250 m/s
  the jet covers real ground while its own roar lags behind.
- **Speed of sound ≈ 343 m/s.** A jet at 240–260 m/s is ~0.7–0.76 Mach:
  subsonic, so no sonic boom, but the engine roar still arrives **noticeably
  late** and swells suddenly as it passes.
- **Doppler:** pitch is higher on approach, drops sharply the instant it
  passes overhead, then trails off lower — the classic "NNNYYYEEEOOWWmmm."
- **Order of events for a low pass:** silent/near-silent shape grows fast →
  shadow/blur overhead → THEN the wall of engine noise hits → doppler
  down-shift → fading rumble as it climbs into the clouds.

Source: Univ. Virginia / Southampton Doppler notes; Lumen Learning "Doppler
Effect and Sonic Booms" (retardation effect, source outrunning its sound).

---

## 2. F-4 Horizontal Flyby — reusing `CASAirplane` structure

The existing A-1 does APPROACH → DIVE → RELEASE-inline → CLIMB → DONE with a
900 m offset spawn and a steep-ish descent. The F-4 wants a **flat, fast,
low run** that spawns ~200 m out, drops on the player-line, then climbs past
and vanishes. Same `Phase` enum vocabulary, same release helpers, new
constants and a flatter flight function.

### Constants (F-4 profile)

```gdscript
# F-4 fast-mover profile (contrast with A-1's SPEED=120, APPROACH_ALT=80)
const F4_SPEED: float          = 250.0   # ~485 kt, authentic low CAS run-in
const F4_RUN_ALT: float        = 30.0    # level ~25-35 m over target (real: 50-75 ft)
const F4_SPAWN_DIST: float     = 200.0   # spawn 200 m short of target (per design)
const F4_RELEASE_DIST: float   = 20.0    # pickle when within 20 m of target line
const F4_CLIMB_PAST: float     = 100.0   # keep flying 100 m+ past before climb-out
```

### call_strike variant — flat run, close spawn

Reuse the same signature/idea as `call_strike()` (lines 29–42) but skip the
dive geometry. The run direction should be **target → away from player** so
the jet screams *over* the player toward the target and out the far side
(current A-1 code already computes `run_dir = target - player.global_position`
in `_launch_cas`, mission_director:245 — reuse that unchanged).

```gdscript
func call_flyby(terrain_manager: TerrainManager, target: Vector3, ordnance: Ordnance, run_dir: Vector3) -> void:
    terrain = terrain_manager
    _target = target
    _target.y = terrain.get_height_at(target)
    _ordnance = ordnance
    _run_dir = run_dir
    _run_dir.y = 0.0
    _run_dir = _run_dir.normalized()
    # Spawn only 200 m short and already LOW/level (no 900 m dive run-up):
    global_position = _target - _run_dir * F4_SPAWN_DIST + Vector3(0, F4_RUN_ALT, 0)
    global_position.y = maxf(global_position.y, terrain.get_height_at(global_position) + F4_RUN_ALT)
    look_at(global_position + _run_dir, Vector3.UP)
    phase = Phase.APPROACH
```

### Flat flight in `_physics_process`

Add a branch that flies straight-and-level instead of `_fly_run()`'s descent.
Keep the existing `match phase` (line 46) shape:

```gdscript
Phase.APPROACH:               # F-4: flat fast run toward + over target
    _fly_flat(delta)
```

```gdscript
func _fly_flat(delta: float) -> void:
    var flat_dist: float = Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
    # hold altitude a fixed height over the terrain it's crossing (terrain-follow, loud + low)
    var ground_y: float = terrain.get_height_at(global_position) if terrain else _target.y
    global_position += _run_dir * F4_SPEED * delta
    global_position.y = lerpf(global_position.y, ground_y + F4_RUN_ALT, 3.0 * delta)
    if not _released and flat_dist < F4_RELEASE_DIST:
        _released = true
        _release_ordnance()      # SAME helper the A-1 uses (line 74)
        phase = Phase.CLIMB      # hand off to the climb-out below
```

`_release_ordnance()` (line 74) already dispatches on `_ordnance`, so the F-4
reuses `_drop_napalm_strip()` and gets `_drop_cbu()` (section 3) for free.
`apply_explosion_damage`, `DamageSystem.apply_damage`, and
`FireHazard.create_at` stay exactly as the A-1 calls them.

### Mission dispatch hook

In `mission_director.gd`, add a menu verb ("phantom" / slot key) alongside
`bombs`/`napalm` and a launcher twin of `_launch_cas` (line 240) that calls
`call_flyby` instead of `call_strike`:

```gdscript
func _launch_flyby(target: Vector3, ordnance: CASAirplane.Ordnance) -> void:
    var jet: CASAirplane = PHANTOM_SCENE.instantiate()   # or reuse SKYRAIDER_SCENE
    world.add_child(jet)
    var run_dir := Vector3.ZERO
    if world.player:
        run_dir = target - world.player.global_position  # over the player, toward target
    jet.call_flyby(world.terrain_manager, target, ordnance, run_dir)
```

Toast in keeping with existing style (line 224/227):
`toast.emit("FAST MOVER - PHANTOM ON THE DECK, GET DOWN (%d left)" % ...)`

---

## 3. Despawn-into-clouds climb-out

The A-1's `CLIMB` phase (lines 49–55) already flies `_run_dir * SPEED +
Vector3(0,30,0)` for 8 s then `queue_free()`. For the F-4, make the climb
**faster and gated on distance-past-target** so it clears the 100 m+ the
design calls out and disappears upward, not just after a timer.

```gdscript
Phase.CLIMB:
    # keep the horizontal speed, add a steep climb, bank away into the murk
    global_position += (_run_dir * F4_SPEED + Vector3(0, 60.0, 0)) * delta
    var past: float = Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
    # "into the clouds": despawn once 100 m+ past AND above a cloud deck height
    var cloud_deck: float = (terrain.get_height_at(global_position) if terrain else 0.0) + 180.0
    if past > F4_CLIMB_PAST and global_position.y > cloud_deck:
        phase = Phase.DONE
        run_complete.emit()
        queue_free()
```

Notes:
- 180 m is a placeholder "cloud base" — match it to the skybox / whatever
  fog or cloud-plane height the AO uses so the jet visibly enters the deck.
- If the map has an actual volumetric/cloud plane, fade the plane's mesh
  (`modulate.a`) over the last ~1 s of climb so it dissolves rather than pops.
- Keep the `run_complete` signal so `mission_director` budget/cooldown logic
  (the `_cas_cooldown`, line 220) is unaffected.

---

## 4. CBU cluster bomb — new `Ordnance` value

Add `CBU` to the enum (line 10) and a drop helper modeled on
`_drop_napalm_strip()` (line 91), but: **many small fragmentation blasts over
a 60 m × 40 m ellipse, NO fire, at most one small crater** (respects the
council crater cap — napalm center-only / bomb single-crater rule).

```gdscript
enum Ordnance { BOMB, NAPALM, CBU }   # was { BOMB, NAPALM }
```

Real CBU-24 = 665 BLU-26 over ~37 m × 61 m. Simulate with ~14–20 sampled
bomblet impacts (not 665 — perf) scattered over the footprint, each a small
anti-personnel blast. Reuse the exact same call trio the A-1 uses.

```gdscript
const CBU_BOMBLETS: int   = 16      # sampled, not the real 665
const CBU_LONG: float     = 60.0    # ~200 ft long axis (along run dir)
const CBU_WIDE: float     = 38.0    # ~120 ft cross axis
const CBU_STAGGER: float  = 0.05    # near-simultaneous "rippppp" of pops

func _drop_cbu() -> void:
    # canister "opens" in flight -> footprint centered on target, elongated along run_dir
    var cross: Vector3 = _run_dir.cross(Vector3.UP).normalized()
    for i in range(CBU_BOMBLETS):
        var along: float = randf_range(-0.5, 0.5) * CBU_LONG
        var side: float  = randf_range(-0.5, 0.5) * CBU_WIDE
        var pos: Vector3 = _target + _run_dir * along + cross * side
        var delay: float = 0.8 + float(i) * CBU_STAGGER
        var deform: bool = (i == 0)   # crater cap: only ONE bomblet scars terrain
        get_tree().create_timer(delay).timeout.connect(func() -> void:
            var ground := pos
            ground.y = terrain.get_height_at(pos) if terrain else pos.y
            # small AP frag blast: lower damage, tight radius, high min-damage core
            CombatManager.apply_explosion_damage(ground, 60, 25, 6.0, null)
            CombatManager.apply_suppression_in_area(ground, 12.0, 0.6)
            GunFX.play_explosion_3d(get_tree().current_scene, ground)
            NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)
            if deform:
                DamageSystem.apply_damage(ground, DamageSystem.DamageType.SMALL_EXPLOSION, 0.7))
```

Wire into `_release_ordnance()` (line 74):

```gdscript
func _release_ordnance() -> void:
    match _ordnance:
        Ordnance.BOMB:   _drop_bomb()
        Ordnance.NAPALM: _drop_napalm_strip()
        Ordnance.CBU:    _drop_cbu()
```

Mission menu: add a `"cluster"` verb in `request_fire_support` (line 221
match block) → `_launch_flyby(target, CASAirplane.Ordnance.CBU)` (CBU is a
fast-mover load, so the F-4 flyby suits it), with a budget entry in
`fire_support` (line 195) e.g. `"cluster": 0`.

Design contrast to lock in:
- **Napalm** = fire, area denial, `FireHazard.create_at`, ignites huts.
- **CBU** = shrapnel storm, no fire, high lethality vs troops in the open,
  near-zero terrain change. Different *feel*, same code spine.

---

## 5. Audio / cinematic cues

Reuse `GunFX.play_explosion_3d(scene, pos)` + `NoiseBus.emit_noise(EXPLOSION,
pos, 0)` for impacts (already the arty/mortar pattern). Add these for the jet
theatrics:

### Delayed boom (retardation effect)
Impacts already stagger via `create_timer(delay)`. For the *visual* flash vs
*audible* boom split, fire the muzzle/flash instantly but delay the sound by
`dist / 343.0` seconds (speed of sound). For a napalm strip 80 m out that's
~0.23 s — subtle but correct, and it reads strongly for a jet 200 m away
(~0.6 s). Sketch:

```gdscript
func _boom_with_delay(pos: Vector3) -> void:
    GunFX.play_explosion_3d(get_tree().current_scene, pos)      # flash now
    var listener: Vector3 = _player_pos()                        # player/camera
    var sound_delay: float = pos.distance_to(listener) / 343.0   # speed of sound
    get_tree().create_timer(sound_delay).timeout.connect(func() -> void:
        NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, pos, 0))
```

### Doppler engine pass
- Attach the jet-engine loop to the moving `CASAirplane` node as an
  `AudioStreamPlayer3D` — Godot applies **positional doppler automatically**
  when `doppler_tracking` is enabled on the player Camera3D
  (`Camera3D.doppler_tracking = DOPPLER_TRACKING_PHYSICS_STEP`). At F4_SPEED
  =250 m/s the built-in doppler gives the authentic approach-high / pass /
  drop-low sweep for free — no manual pitch code needed.
- Keep the roll-in engine quieter, swell to max as `flat_dist` shrinks past
  the player, cut to a fading rumble in `CLIMB`.

### Screen shake
No dedicated helper surfaced — hook into the camera. Trigger a shake impulse
on two events:
1. **Jet overhead** — when `flat_dist` crosses ~15 m of the player during the
   run (the pass itself), a short sharp shake.
2. **Ordnance impact** — scale shake by `1.0 - clamp(dist/danger_close, 0, 1)`
   so a 100 m CBU/napalm drop rattles hard and a distant one barely does.

```gdscript
# pseudo — route to whatever the player camera exposes
var intensity: float = 1.0 - clampf(impact.distance_to(_player_pos()) / 150.0, 0.0, 1.0)
if intensity > 0.0 and world.player:
    world.player.add_camera_shake(intensity * 0.8, 0.4)   # magnitude, duration
```

### Danger-close warning
Gate on the section-1 table: when the pending impact centroid is within
**100 m** (CBU/bomb) or **150 m** (napalm) of the player or a squad member,
`toast.emit("DANGER CLOSE - GET DOWN")` and apply real damage if they're
inside the footprint. This makes the fast, close F-4 pass a genuine risk,
matching the Vietnam reality of 50–150 m drops.

---

## Sources
- [A-1 Skyraider vs F-4 Phantom II compare](https://www.globalmilitary.net/compare/aircraft/a1-skyraider-vs-f4-phantom-ii/)
- [NMUSAF — Dangerously Close! USAF CAS in SE Asia](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/195673/dangerously-close-usaf-close-air-support-in-the-southeast-asia-war/)
- [NASM — Super Sabre's Service in South Vietnam (napalm run-in)](https://airandspace.si.edu/stories/editorial/tet-offensive-vietnam-super-sabre)
- [Wikipedia — Napalm (270×75 ft, 2,500 sq yd, 130 gal)](https://en.wikipedia.org/wiki/Napalm)
- [Wikipedia — CBU-24 (665 BLU-26, 120×200 ft)](https://en.wikipedia.org/wiki/CBU-24)
- [GlobalSecurity — BLU-26 / SUU-30 dispenser](https://ordnance.com/blu-26-submunition-sub-bomblet-cluster-bomb.html)
- [Wikipedia — Operation Arc Light (1.2×0.6 mi box)](https://en.wikipedia.org/wiki/Operation_Arc_Light)
- [Wikipedia — Douglas AC-47 Spooky (6,000 rpm, pylon turn, 2,500–3,000 ft)](https://en.wikipedia.org/wiki/Douglas_AC-47_Spooky)
- [MCWP 3-23.1 Appendix F — Risk-Estimate Distances](https://www.globalsecurity.org/military/library/policy/usmc/mcwp/3-23-1/appf.pdf)
- [Lumen Learning — Doppler Effect and Sonic Booms (retardation)](https://courses.lumenlearning.com/suny-physics/chapter/17-4-doppler-effect-and-sonic-booms/)
- [Univ. Virginia — Doppler Effect notes](https://galileo.phys.virginia.edu/classes/152.mf1i.spring02/DopplerEffect.htm)
