# SYSTEMS DESIGNER — Sapper charges at the wire
**Date:** 2026-07-20 · Lens: mechanics, damage, consequence · All claims carry `file:line`.

---

## 0 · CORRECTION TO THE BRIEF (read this first)

**The Arbiter's premise "the charge currently harms NOTHING" is FALSE.**
`CombatManager.apply_explosion_damage` damages **five** rosters, not one:

| Roster | Line |
|---|---|
| player | `combat_manager.gd:118-133` |
| allies | `:137-157` |
| **civilians** | `:160-169` |
| props (traps) | `:173-180` |
| enemies | `:183-200` |

Garrison men **are** `Civilian` instances and **are** registered `Kind.CIVILIAN`
(`civilian.gd:162`; `is_garrison` is just a flag on the same class, `:56`, `:116`).

So the orphan is **not a firework — it is a massacre.** `Civilian._hp = 20`
(`civilian.gd:28`). The charge does 180 max / 60 min over a 10m radius
(`sapper_charge.gd:31`). Every garrison man inside 10m with line of sight dies
instantly, and:

- **nothing scores it** — `_record_noncombatant_death()` is intentionally empty
  (`civilian.gd:385`);
- **nobody reacts** — `_on_noise()` hard-returns for garrison (`civilian.gd:174`),
  so the survivors do not flee, cower, or even flinch. They stand their posts in
  armed idle poses (`_play_garrison`, `:312`) beside the dead;
- **nobody replaces them** — `_build_firebase_garrison` (`mission_generator.gd:744`)
  runs once at world build. Across a persistent province (ADR-017) the firebase
  depopulates permanently.

The design danger here is the opposite of the one stated in the brief.

---

## 1 · How do you actually drive an enemy to a fixed point in THIS codebase?

### What exists

Two fixed-point drivers, and **both live UNDER the combat brain, not over it**:

- `work_pos` — `enemy_base.gd:113`, consumed at `:1345-1347`. Guarded by
  `target == null and alert_tier <= AlertTier.SUSPICIOUS`. One bullet ends it.
  (Set by `camp_director.gd:129-132`.)
- `patrol_route` — `enemy_base.gd:100`, `_execute_patrol` at `:1885-1913`.
  Reached only from `_execute_idle` (`:1342`), so likewise dies on contact.
  (Set by `camp_director.gd:86`, `lazy_group.gd:93`, `ai_stress_arena.gd:1240`.)

`last_known_target_pos` is **not** a drive input. It is a perception crumb,
rewritten on contact (`:653`, `:1037`), on being hit (`:2146`), on a squadmate's
death (`:769-772`, `:794`), and from the squad's shared trail (`:616`, `:707`).
It is only *read* as a destination inside `_execute_alert` (`:1363`), and there
`EnemySquad.hunt_point` overrides it whenever `squad_id >= 0` (`:1367-1369`).
**The orphan's core assumption (`sapper_charge.gd:24`) is wrong, and a fresh
sapper with no target falls to `HOLD_POSITION` (`:1115`) and stands still.**

### What does not exist

There is **no goal-override / scripted-move mechanism.** `_evaluate_goals`
(`:1080`) rebuilds the decision from scratch on every think. The *only* reserved
clause in the whole function is the SEEK_COVER rush-completion at `:1090-1091`.

### Recommendation — copy `:1090`, do not invent a parallel brain

Minimum honest addition, four touch points, no new subsystem:

1. `var objective_pos: Vector3 = Vector3.ZERO` beside `work_pos` (`:113`).
2. An early-return at the **top** of `_evaluate_goals` (before the
   `not target` branch at `:1096`), shaped exactly like `:1090`:
   *if `objective_pos != Vector3.ZERO` and not arrived → `_set_goal(ASSAULT_POINT)`, return.*
3. One new `Enums.AIGoal` + `Enums.AIState`, and one arm in the `_execute`
   match (`:1294-1310`) calling `_execute_objective`.
4. `_execute_objective` calls the **existing** `_move_toward(objective_pos, delta, 1.0)`
   (`:1656`) — that function already owns the `NavigationAgent3D` (`:1667-1690`),
   so pathing, avoidance and re-staking are free.

The behaviour node then sets `objective_pos` **once in `setup()`**, never per
frame. This is reuse-maximal: no new movement code, no second nav path, and the
override is visible in the goal enum where the fairness probe can see it.

Two further corrections to the orphan's shape:

- Spawn the sapper with `squad_id = -1`, or `hunt_point` (`:1367`) can steer him
  the moment anything pushes him to ALERT.
- The node runs `_physics_process` every frame (`sapper_charge.gd:18`). The AI is
  think/execute at ~6.7 Hz by project pattern (CLAUDE.md, `THINK_INTERVAL`). A
  distance check per sapper per frame is the wrong cadence; put it on the think
  tick or a 0.2s timer.

---

## 2 · WHAT DOES THE CHARGE DESTROY?

### Ruling out

- **The wire.** Thematically the right answer and the most expensive. Barbwire is
  `barbwire_card` — an alpha-card impostor with no `take_damage` and no breach
  contract. There is **no destructible-structure class in this game at all**:
  `func take_damage` exists in exactly seven files, all of them people plus
  `punji_trap.gd`. Blowing a gap in the wire is a new system. Not this wave.
- **Garrison wipe.** Mechanically live today and design-poisonous: 17 unreactive
  noncombatants deleted from a persistent province, unscored, unreplaced,
  unmourned. It is not drama, it is set-dressing removal.

### The target that makes this MEAN something

**Primary: the ARMORER'S BENCH.** `scripts/levels/armorers_bench.gd`
(`class_name ArmorersBench`, `:7`), spawned at `mission_generator.gd:664-669` at
`spawn_pos - gate_out * 10.0` — a **fixed, known point just inside the wire**,
which is precisely where a sapper is going. It is the player's rack and cleaning
station (ADR-018, `RACK` at `:16`, `BENCH_SECONDS` at `:10`). Losing it is:

- **legible** — you walk back through the wire and your bench is a crater;
- **a real cost** — no re-arm, no clean; the next patrol goes out on what you carry;
- **reversible** — ADR-019 §1 is explicit that *destruction is temporary,
  attrition is permanent*. The bench is rebuilt in a day or two of sim time;
- **cheap** — it is a `Node3D` with a script and a lifecycle already. Register it
  `AgentRegistry.Kind.PROP` exactly like `punji_trap.gd:39` and it is inside the
  existing blast loop (`combat_manager.gd:173-180`) with **zero** new damage code.

**Secondary: the fire-support allotment.** `FieldDirector.fire_support` is a plain
dict written at `:572-575`. A charge inside the wire zeroes `mortar` and `arty`
for the **next** walk-out ("the pit took a satchel; battalion has nothing for us").
Pure dict edit, no new class, and it hits the player where a firebase attack
should: in what he can call for tomorrow.

**Tertiary, bounded: garrison casualties.** A few men die — that is the human
weight. But the blast must **break the deafness**: `civilian.gd:174` must become
"garrison ignores *distant gunfire*", not "garrison ignores explosions inside its
own wire". Survivors must FLEE/COWER. A firebase where a satchel goes off and the
mannequins keep standing their posts is worse than no sapper at all.

---

## 3 · The number

ADR-016's table of record (`ADR-016:178-183`): M26 **190** @ radius **10m**,
kill plateau inside 40% of radius · M79 **150** · LAW **250** · RPG-2 **250**
@ 8m · RPG-7 **290**.

The orphan's `180 / 60 / 10.0` is **a slightly weaker hand grenade**. A đặc công
satchel is 10–20 lb of TNT placed by hand.

**Proposal: max 300 · min 70 · radius 14.0m · `DamageType.MEDIUM_EXPLOSION`.**

- **300** clears RPG-7's 290 by the smallest legible step. The satchel is then the
  most lethal single device in the game — correct, since it is bought with the
  carrier's life.
- **14m** is the real differentiator. It is a *demolition* charge, not a shrapnel
  weapon; it wins on size, not on damage number. Compare RPG-2's 8m.
- `MEDIUM_EXPLOSION` for the crater is already right — 3 cells / 2.0m depth
  (`terrain/systems/damage_system.gd:29-36`), the artillery-shell profile.

**Binding condition:** this value goes **into ADR-016's explosive table by
amendment and into `tests/test_flat_damage.tscn`.** A damage constant living
only in a behaviour script is exactly the off-canon drift this project keeps
paying for.

Two call-site notes:

- The call passes `attacker = enemy`, i.e. non-null, so friendlies take **full**
  damage rather than the 0.4× indirect discount (`combat_manager.gd:148-149`).
  Correct for an enemy-placed charge — but `combat_manager.gd:146` names
  "placed charges" as indirect. **The comment is now wrong; correct it in the
  same change** (NO MORE DRIFT).
- `enemy.take_damage(9999, ...)` (`sapper_charge.gd:35`) fires *after* the blast,
  so he already ate his own explosion. Harmless, but redundant — and it attributes
  the kill to himself. Keep the order, drop the double.

---

## 4 · Distinct spawn, or acquired behaviour?

**Distinct spawn. Do not overload `vc_sapper.tres`.**

That resource is a lie already: `display_name = "VC Sapper"` with
`description = "Main Force machine gunner. Belt-fed, aggressive, hard to suppress."`,
`weapon_path = rpd.tres`, `aggression = 0.7` (`data/enemies/vc_sapper.tres:8-19`).
It is an RPD gunner wearing a sapper's name, and it spawns live in four places
(`mission_generator.gd:36`, `lazy_group.gd:25`, `ai_stress_arena.gd:86`,
`gore_lab.gd:13-14`). Retasking it silently changes every one of them.

**Add `data/enemies/vc_dac_cong.tres`:** `aggression 0.90` · `courage 0.95` ·
`uses_cover = false` · `retreats_when_hurt = false` · `max_hp 65` ·
`move_speed 5.0` · light sidearm. Aggression above **0.85** is already
doctrine-exempt and the fairness probe already blesses it *by name*:
`tests/test_ai_fairness.gd:103` — *"aggression 0.85 must be doctrine-exempt
(sappers push)"*. The doctrine we need was written for this unit before the unit
existed.

Attached **only** by the firebase-assault path. Never by ambient
`LazyGroup` spawns — a sapper wandering the AO with no objective is the
`HOLD_POSITION` statue again.

**Under fire he PUSHES.** The `objective_pos` early-return sits above the whole
scoring block, so suppression, cover and retreat can never take him. His only
concession is firing on the move via the existing `_fire_at_target`. He must
remain fully killable — **that is the entire counterplay**, and it is why the
run must be announced.

**Fix the announcement.** `_warned` fires at `dist < 40.0` **from the objective**
(`sapper_charge.gd:26`) — it triggers whether or not the player is anywhere near
the firebase. A man 800m out on patrol gets "SAPPER IN THE WIRE!" and can do
nothing about it. That is a fairness violation and it is also the wrong channel:
ADR-029 is a no-briefing-UI loop. Route it through the path that already exists —
`FieldDirector._poll_firebase_threat` (`:626-641`) already detects enemies massing
near `fsb_center` and emits `friendly_firebase_under_attack` into
`DynamicMissionFactory`, and `raise_crisis` (`:605-621`) gates on
`_radio_check()` (`:612`) so the word only reaches you if you have the net. Off
the net, you come home to the crater. That is the game.

---

## 5 · Negative conditions — what a probe must PROVE cannot happen

The detonation must **not** fire when:

1. **`target_pos == Vector3.ZERO`** (never `setup()`, or the firebase is not
   built). Today `target_pos` defaults to ZERO (`sapper_charge.gd:8`) and the
   distance check runs unconditionally — **a sapper spawning near world origin
   detonates on frame one.** Hard bug. Probe: an un-setup sapper never detonates,
   ever.
2. **The carrier is dead** — `is_dead()` guard must hold for the frame in which
   he dies, and the node must stop, not merely skip.
3. **Out of range** — including the slope case: `distance_to` is 3D and the
   objective Y comes from a terrain-seated marker; assert a sapper 9m away in XZ
   but 20m below does not blow the bench.
4. **Twice.** Exactly one `apply_explosion_damage` and one crater per carrier.
   (`set_physics_process(false)` at `:36` covers it — the probe must lock it.)
5. **After the patrol has banked / `FieldDirector.is_ended()`** (`:715`) — no
   post-AAR blast landing on a closed ledger.
6. **Detached / reparented** — `get_parent() as EnemyBase` null path must exit
   cleanly (already handled at `:19-22`; keep it under test).
7. **Non-determinism.** ADR-010: same op seed → same sapper, same route, same
   crater position. No `randf()` may enter this path.
8. **Warning without agency** — probe that the toast/radio only reaches a player
   who can act on it (§4).

And one positive assertion the audit already asked for
(`GAME_AUDIT_2026-07-19.md:168`): a `probe_behaviour_attached` check that this
class is `add_child`-ed somewhere in production, or it goes straight back to being
a fossil that reads as a feature.

---

## 6 · WHAT IS SACRIFICED

- **The combat brain's honesty.** Adding `objective_pos` is adding a *sanctioned
  bypass* around `_evaluate_goals`. Every future "just make him walk there" will
  reach for it, and the AI's tactical integrity erodes one exemption at a time.
  Mitigation: it is data-driven, it appears in the goal enum, and exactly ONE
  archetype may set it until a decree adds a second.
- **The firebase stops being safe.** A 300/14m charge inside the wire kills the
  player outright if he is home. That is the intended lethality — but it means
  the base is now a place you can die standing still, and the only warning is a
  toast. **If we cannot afford the VO/audio warning, we cannot afford the charge.**
- **Scope creep into the ROE ledger.** The moment garrison deaths are made to
  matter, `_record_noncombatant_death` (`civilian.gd:385`) — deliberately empty,
  deliberately out of scope — is in play, and ADR-019's hearts-and-minds
  accounting was written for *villagers*, not for friendly noncombatants. That is
  a decree, not an implementation detail.
- **A resupply the player depends on can be taken from him** (Pillar 5, fail
  forward). Acceptable only because ADR-019 §1 makes destruction temporary — the
  bench MUST come back. A permanently dead bench is a fail-state wearing a
  consequence costume.
- **The "36-line behaviour" is a lie about cost.** Honestly scoped this is:
  an `enemy_base` goal/state pair · a new `EnemyData` · a destructible bench ·
  an ADR-016 amendment + `test_flat_damage` entry · a garrison-reaction fix ·
  a crisis-channel rewire · a probe. Anyone who budgets it at 36 lines will ship
  the massacre version, because the massacre version is the one that already
  compiles.
