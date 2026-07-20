# DEVIL'S ADVOCATE — Wiring `sapper_charge.gd`
**Date:** 2026-07-20 · **Method:** read the code, not the plan. Every claim below carries a `file:line`.

---

## 0. THE HEADLINE: `sapper_charge.gd` IS NOT A BEHAVIOUR. IT IS A HINT-WRITER AND A BOMB.

Its own docstring says *"sprints for the wire"* (`scripts/enemies/sapper_charge.gd:1-2`). Read the
body: it **never touches `velocity`, never sets a goal, never sets a speed, never sets an alert
tier.** The entire "rush" is one line:

```gdscript
enemy.last_known_target_pos = target_pos          # sapper_charge.gd:24
```

with the comment *"Drive toward the objective regardless of the combat brain."* **That comment is
false.** `last_known_target_pos` is a *search hint*, and the combat brain owns whether it is ever
walked to:

- **With a target** (player, ally, anything acquired): the goal FSM scores ENGAGE / SEEK_COVER
  (`enemy_base.gd:1119-1130`) and the sapper fights like any rifleman. The hint is only read at
  `:1463` (`_move_toward(last_known_target_pos)`) when LOS is *lost*, and `:1037` overwrites it with
  the live target's position every think. **The satchel man never advances.**
- **Without a target**: `_think` takes the no-target branch at `:1096`. It picks INVESTIGATE **only
  if** `last_known_target_pos != ZERO and (hunting or target_last_seen_time < 5.0)` (`:1110`);
  otherwise **HOLD_POSITION** (`:1115`). `target_last_seen_time` starts at 0.0 (`:58`) and climbs.
  So an unengaged sapper walks toward the firebase for **about five seconds** and then stands
  still in the jungle for the rest of the operation.
- Even inside INVESTIGATE the hint is **overridden**: `_execute_alert` replaces `goal_pos` with
  `EnemySquad.hunt_point()` / `search_point()` when `squad_id >= 0` (`enemy_base.gd:1363-1372`). A
  squadded sapper sweeps his assigned wedge, not the wire.

**And it corrupts the squad.** `enemy_base.gd:1101-1108` feeds `last_known_target_pos` into
`EnemySquad.begin_hunt()` as *where the player was last seen*. SapperCharge overwrites that value
every physics frame with the **firebase centre**. Wire this to a squadded sapper and **every man in
his squad starts hunting the firebase**, convinced the player is there. That is a cross-system
contamination bug that no probe currently in the suite would catch.

**Finding:** wiring this file as written ships a node whose docstring lies about what it does. Under
the POINTER LAW / COMMENT DISCIPLINE that is a drift generator on day one. Any honest version of this
feature is a *movement* implementation (a goal, a speed override, or a dedicated `AIGoal`), not a
36-line file. **The orphan is not "ready to wire." It is a stub someone mistook for a system.**

---

## 1. "WHILE HE IS AWAY" IS SELF-DEFEATING — ARGUE IT DOWN

The framing hands the player a **toast and a number**. Consider what he actually experiences:

1. He is 400m out in the elephant grass.
2. `raise_crisis` fires a line of text and retargets his sweep (`field_director.gd:605-621`).
3. He walks home for two minutes.
4. He arrives to… a crater (`DamageSystem.MEDIUM_EXPLOSION`) and, at best, some dead
   garrison bodies lying at 90° rotation (`civilian.gd:377`).

**No sight, no sound, no fight.** `NoiseBus.emit_noise(EXPLOSION, pos, 1)` (`sapper_charge.gd:34`)
and `GunFX.play_explosion_3d` are spatial — at 400m through jungle he gets **neither**. The
spectacular part happens in a room he is not in. What he is *given* is homework: walk back, look at
the aftermath, and take the game's word for what happened.

Compare against **Pillar 2 (Atmosphere)** and the project's own Fairness Law (`field_director.gd:600-604`:
*"No marker ever appears from nothing"*). A sapper attack he cannot witness is exactly the shape of
thing this codebase has repeatedly ruled against: **an event that exists only as a claim in the HUD.**

**The witnessable version is strictly better and cheaper:** a sapper probe **at the wire, at night,
while he is inside it** — he hears the wire, sees a low crawling silhouette, and gets a five-second
window to shoot the man before the satchel goes. That version:
- needs *no* crisis plumbing, no retarget, no toast (the event announces itself),
- reads as Vietnam in the way the reference doc describes the đặc công (`assets/reference/references/reference_vc_nva.md:100-106`),
- has a **fail state the player owns** (he missed the shot) rather than one the sim resolved offscreen,
- and produces the one thing the "away" version structurally cannot: **a memory of a thing he saw.**

**Recommendation:** build the witnessable probe first. If the away-version is still wanted afterward,
it is then a *reskin of a proven system* rather than a first version validated only by a log line.

---

## 2. THE GARRISON CANNOT FIGHT BACK — AND THE HONEST ANSWER IS "NOT AS FRAMED"

The garrison are `Civilian` instances with `is_garrison = true`
(`mission_generator.gd:744-771`, spawned via `Civilian.spawn(..., garrison=true)` at `:757`). What
that flag means, mechanically:

| Fact | Pointer |
|---|---|
| They are noncombatants by explicit design; *"NOT combatants and NOT squad members: they carry no EnemyBase/AllyBase"* | `mission_generator.gd:739-740` |
| They cannot call in their own attack — the director's threat poll exists *because* of this | `field_director.gd:624-625` |
| **They do not react to explosions at all** — `_on_noise` returns early on `is_garrison` | `civilian.gd:171-181` |
| They cannot be shot by AI at all — their hurtbox layer is in the **player's** fire masks only | `civilian.gd:19-22` |
| Their whole state machine is WANDER / FLEE / COWER / GONE | `civilian.gd:17` |
| HP 20 | `civilian.gd:28` |

Now run the feature: a satchel detonates for `180` max damage in a `10m` radius
(`sapper_charge.gd:31`). Civilians are damaged through `AgentRegistry.civilians`, which **bypasses
the layer masks entirely** (`combat_manager.gd:159-167`). So:

- Every garrison man within 10m — HP 20 against 180 — **dies instantly, without exception.**
- Every garrison man *outside* 10m **does not flinch, does not look up, does not cower, does not
  move**, because `is_garrison` short-circuits the noise listener (`civilian.gd:174-175`). They keep
  stooping over their jobs beside their friends' corpses.
- Their deaths route to `_record_noncombatant_death()`, which is **intentionally empty**
  (`civilian.gd:382-386`) and explicitly fenced: *"do not add scoring here without a decree."*

**So the honest description of the feature as framed is: the enemy walks into a compound where nobody
can shoot him, kills a fixed number of men who cannot react, and nothing anywhere records that it
happened.** It is not a massacre with drama; it is a **deletion event with a particle effect**.

**Is there an honest version that doesn't change what the garrison is?** One, and only one:
**the sapper must fail unless the player is there.** i.e. the attack is a *threat* the player
intercepts, not an outcome the sim resolves. Sappers spawn, they crawl, the player (inside the wire,
or racing back) is the ONLY thing that can stop them — and if he is not there, the design must
choose a consequence that is not "men die invisibly."

Anything else requires **changing what the garrison is** — giving them an armed combatant tier, a
reaction to blast, and an AI mask their bodies can be hit by. That is a genuine feature (a defended
firebase), it is *good*, and it is **not in scope for wiring a 36-line orphan.** Attempting the
sapper feature without it produces a firebase that is scenery being demolished, not a place being
defended.

**FINDING, stated plainly as requested: there is NO version of "sappers attack the firebase while he
is away" that is honest against the current garrison. The garrison is background life
(`civilian.gd:54-56`), and background life cannot be the loser of a battle.**

---

## 3. FOSSIL RISK — YES. THE CRISIS ALREADY EXISTS AND IS ALREADY PROBED.

**`friendly_firebase_under_attack` is fully built, wired, and covered by a test.**

- Threat poll: `field_director.gd:626-641`. Any **2 live enemies within 90m of `fsb_center`**
  (`FSB_THREAT_M = 90.0`, `FSB_THREAT_MEN = 2`, `:494-495`) while `patrol_out` raises it.
- Polled every 0.5s from `_process` (`field_director.gd:143-147`).
- Mapped to a `firebase_attack` location (`dynamic_mission_factory.gd:25-26`).
- Announced as **"SIX: THE FIREBASE IS IN CONTACT"** (`field_director.gd:500`).
- Probed with negative controls, including the exact garrison rationale
  (`tests/test_dynamic_events.gd:203-244`).

**So the "firebase under attack while you patrol" feature already SHIPS.** You can have it today by
spawning any two enemies near the compound. `SapperCharge` adds exactly two things the existing path
does not have: a bespoke toast, and a self-detonation.

Redundancy against existing behaviours, all already live on `EnemyBase`:

| Proposed sapper capability | Already exists |
|---|---|
| Close with an objective | `AIGoal.ADVANCE`, `INVESTIGATE` (`enemy_base.gd:1111`), `_move_toward` (`:1463`) |
| Throw explosives at a target | `_throw_grenade()` with squad/AO brokering (`enemy_base.gd:1454-1459`) |
| Coordinate an approach | `EnemySquad.begin_hunt` / `hunt_point` (`enemy_base.gd:1101-1108`, `:1363-1372`) |
| Alert the player to a firebase attack | `_poll_firebase_threat` → `raise_crisis` (above) |
| Blow a fixed structure | player-side satchel path (`player.gd:279-305`, `campaign_state.gd:269`) |

**The second-path risk is real and it is the toast.** `sapper_charge.gd:26-28` calls
`director.toast.emit(...)` **directly**, bypassing `raise_crisis` entirely — which means it bypasses
the radio check (`field_director.gd:612-613`), the `CRISIS_CALL` wording table (`:499-505`), and the
`_seen` dedupe (`dynamic_mission_factory.gd:39`). That is a **second information channel to the
player for the same world event**, and it violates the rule stated one line above it in the source
it bypasses: *"THE NET IS THE CHANNEL: off the net the word never reaches him"* (`:602-604`).

Under ADR-023 that is precisely a fossil-in-the-making: two systems that mean the same thing, one of
which the next agent will use by mistake.

---

## 4. DOUBLE-FIRE AND THE DEDUPE TRAPS — CONFIRMED, WITH A NASTY TWIST

**Double-fire: YES.** Two sappers within 90m of `fsb_center` (their whole purpose) satisfy
`FSB_THREAT_MEN = 2` (`field_director.gd:636`). The player therefore receives:

1. `"SIX: THE FIREBASE IS IN CONTACT — <bearing>, <dist>M"` (via the crisis, `:618-620`), then
2. `"SAPPER IN THE WIRE!"` at 40m (`sapper_charge.gd:26-28`), **once per sapper** — `_warned` is
   per-instance, so a 4-man sapper team emits **four identical toasts**, and
3. the crisis **retargets his sweep** to the firebase (`:614`) — which is also where the wire gate
   is, so the pointer sends him home mid-patrol.

**The twist — the dedupe key is a CONSTANT.** `_poll_firebase_threat` keys the event on
`hash(Vector2i(fsb_center.x, fsb_center.z))` (`field_director.gd:641`) — the same integer for the
entire operation. `emit_location` latches it in `_seen` forever (`dynamic_mission_factory.gd:39-41`),
and `_seen` is only cleared when the factory itself is rebuilt (`MissionGenerator.dynamic_factory_ref`
is a `static var`, `mission_generator.gd:269`, re-assigned at `:252`; `MissionScope.reset()`
—`scripts/main/mission_scope.gd:27`— does not clear `_seen`).

**Consequence: the firebase can be reported under attack exactly ONCE per operation.** Sapper wave #2
raises no crisis at all. So a probe asserting "a sapper wave raises a firebase crisis" will pass on
the first wave and the feature will be **silently dead for every subsequent wave** — and it will pass
whether or not `SapperCharge` exists, because `_poll_firebase_threat` already does it.

**THE TRAP NAMED EXPLICITLY (this is the one that burned two agents today):** *any* probe of the form
"spawn sappers near the firebase, assert a `firebase_attack` location reached the director" **passes
identically against the fix and against its total absence.** `_poll_firebase_threat` satisfies the
assertion by itself. If the probe wire-up spawns bodies via `spawn_tracked_enemy` (which files them
into `_live_enemies`, `field_director.gd:40`), the threat poll fires on geometry alone. **A green
probe here proves nothing about `SapperCharge`.**

---

## 5. PACING / CRISIS BUDGET — the "2 per operation" cap is not what it looks like

I searched for a global crisis cap and **found none.** What exists is a set of *per-source latches*
that together produce an effective ceiling — and this matters, because "raise the cap" and "add a
source" are not the same operation:

| Source | Latch | Effective budget |
|---|---|---|
| Friendly patrol pinned | `static pinned_holder` + `_reported` (`friendly_patrol_group.gd:134-141`) | **1 at a time, globally**; probed at `tests/test_friendly_patrols.gd:285` |
| Firebase under attack | `_seen[hash(fsb_center)]` (`field_director.gd:641`, `dynamic_mission_factory.gd:39`) | **1 per operation, ever** (§4) |
| Village aid | per-village hash (`civilian.gd:194`) + 150m gate (`dynamic_mission_factory.gd:63-69`) | 1 per village |
| Camp discovered | per-`CampDirector` id (`dynamic_mission_factory.gd:82`) | 1 per camp |
| Convoy ambushed | per-convoy instance id (`:52-57`) | 1 per convoy |

**Sappers do not bypass the cap — they are swallowed by it**, which is worse. They compound *nothing*
and add *nothing* on wave 2+. The pacing risk is not "too many crises"; it is the **retarget**:
`raise_crisis` sets `patrol_location = fsb_center` (`:614`) and appends it to `_visited_locations`
(`:616`), so a sapper event **cancels the walk the player chose** and points him back at the gate. Do
that on wave 1 of every operation and the open-patrol loop (ADR-029) acquires a rail: *go out, get
called back, go out again.* That is a direct hit on **Pillar 3 (Freedom)**.

Second-order: since `patrol_location` is now the firebase and the wire gate triggers on distance from
`patrol_gate_pos` (`:530-553`), walking to the crisis **banks the patrol** (`_bank_patrol()`, `:551-553`),
resetting `MissionState`. Responding to the crisis *ends the excursion it interrupted.*

---

## 6. `take_damage(9999)` SUICIDE — WHAT ACTUALLY BREAKS

Line: `enemy.take_damage(9999, Enums.DamageType.EXPLOSIVE, enemy)` (`sapper_charge.gd:35`), preceded
by `CombatManager.apply_explosion_damage(pos, 180, 60, 10.0, enemy)` at `:31`.

**a) THE PLAYER IS CREDITED WITH THE KILL.** `_on_enemy_died` calls `state.record_kill()`
**unconditionally, with no killer check** (`field_director.gd:54-56`). So a sapper who blew himself
up appears in the AAR line *"BACK INSIDE THE WIRE — PATROL %d LOGGED, %d KILLS"*
(`field_director.gd:697-698`). The player is told he killed a man he never saw. **Truth Law violation
(ADR-015).**

**b) ADR-006 saves the score, not the story.** `compute_score()` no longer pays for kills
(`debrief.gd:32-42` — contacts avoided/detected, damage, speed, ghost, POW). So the phantom kill
costs **zero XP**. But ADR-006:44 is explicit: *"Kills remain displayed on the AAR as information."*
The information is now **wrong**. ADR-006 does not save this; it makes the defect purely a lie
rather than an exploit.

**c) SELF-ATTACKER PATHOLOGIES.** `attacker == enemy == self`:
- `last_hit_dir = (global_position - global_position).normalized()` → **`Vector3.ZERO`**
  (`enemy_base.gd:2118`). That zero vector then picks the death clip
  (`_die`, `:2395-2397`: `to_attacker.dot(basis.x)`) and is passed to `GibSystem.explosion_kill`
  (`:2387`) and `start_ragdoll` (`:2389`). A zero impulse direction is undefined behaviour in the
  gore path — best case a limp drop, worst case a NaN normalize.
- `_last_attacker` is **not** set (it is gated to player/allies only, `:2120-2122`), so
  `_witness_check(null)` runs (`:2352-2356`). Good: the AO does not learn the player's position from
  a suicide. **This is the one thing that works correctly by accident** — and it means the sapper's
  death is *unwitnessed*, so it produces no escalation, no bark, no alert. Silent.
- `_credit_killer(enemy)` (`:2202`) → `attacker.get("member")` on an `EnemyBase` is `null`, not a
  Dictionary → early return (`:2239-2241`). No squad XP leak. Fine.

**d) DOUBLE-DAMAGE ON SELF.** `apply_explosion_damage` at `:31` runs *before* the suicide at `:35`.
That call damages the player, allies (`combat_manager.gd:137-157`) and civilians (`:159-167`) — but
note `attacker != null`, so the **danger-close 0.4× reduction for indirect fire does NOT apply**
(`combat_manager.gd:145-149`). Any ally near the blast takes the **full** 180. Whether it also
damages *other enemies* needs a read of the enemy branch below `:167`; if it does, one sapper
detonating in a wave kills his own team, and each of those deaths **also** calls `record_kill()`.
A 4-man sapper team could hand the player 4 unearned kills from one explosion.

**e) `EnemySquad` bookkeeping** is handled: `_die` calls `release_hot` and `AgentRegistry.unregister`
(`:2355`, `:2360`). **f) Loot:** the corpse joins `lootable_corpses` (`:2407`) — a man who
just detonated a satchel at point-blank leaves an intact lootable body for 45 seconds. Cosmetic, but
it reads as broken.

**g) The `is_downed` interaction.** If the blast at `:31` merely *downs* the sapper (down-not-dead
roll, `:2180-2187`) — it cannot, since `EXPLOSIVE` is excluded at `:2181` — fine. But if a **player
bullet** downs him first, `_physics_process` bails on `enemy.is_dead()` (`sapper_charge.gd:20`), and
`is_dead()` returns true while downed (`enemy_base.gd:2340`, `:2446-2448`). So **shooting a sapper
into the downed state permanently disarms the charge.** That is probably the desired outcome, but it
is accidental, undocumented, and one refactor of `is_dead()` away from a live satchel on a crawling man.

---

## 7. PRE-MORTEM: THE PROBES THAT WILL PASS AGAINST BOTH THE FIX AND ITS ABSENCE

This suite has been burned repeatedly (`GAME_AUDIT_2026-07-19.md:164`: *"a symbol referenced only by
its own test looks alive"*). Here are the specific false positives waiting for this feature.

**"Sappers spawn."**
`vc_sapper.tres` **already spawns today** — `mission_generator.gd:35`, `lazy_group.gd:25`,
`ai_stress_arena.gd:86`, `gore_lab.gd:13-14`. Any probe asserting a sapper exists in the world
**passes on the current, un-wired build.** The only honest assertion is
`enemy.get_node_or_null("SapperCharge") != null` **AND** `charge.target_pos != Vector3.ZERO`
(a `setup()` that was never called leaves it at ZERO — `sapper_charge.gd:8`).

**"They move toward the wire."**
The killer. `_move_toward(last_known_target_pos)` fires from the ordinary combat brain
(`enemy_base.gd:1463`), and any enemy that hears a shot or acquires a target moves *somewhere*.
A probe that asserts `distance_to(fsb) decreased over N ticks` will pass on ambient patrols,
on the hunt sweep, on a rout, and on wind. **Negative control required:** the identical scene with
the `SapperCharge` node **removed** must show the sapper *not* closing — and per §0 it very likely
will look the same, because the node does not implement movement. **If your negative control passes,
you have not found a bug in the probe; you have found that the feature does not exist.**

**"The charge detonates on the intended condition and NOT otherwise."**
Traps: (a) `DETONATE_RANGE = 9.0` is measured to `target_pos`, and if `setup()` was never called
that is `Vector3.ZERO` — the **world origin**. A sapper spawned near the origin detonates
immediately, and a probe rig that leaves positions at default `Vector3.ZERO` **detonates on tick one
and looks like success.** (b) The negative control must be a sapper *at 9.1m* and a sapper *dead*
and a sapper *downed* — and it must assert the explosion did **not** happen, by counting
`CombatManager` calls, not by reading a flag the same node sets.

**"Damage lands."**
Trap: `apply_explosion_damage` damages player/allies/civilians through `AgentRegistry`
(`combat_manager.gd:118-167`), which is populated by `Civilian.spawn` (`civilian.gd:162`). A headless
rig that adds `Civilian` nodes via `Civilian.new()` instead of `Civilian.spawn()` **registers
nothing**, and the probe will report "no damage" — a false *negative* that will be "fixed" by
weakening the assertion. Conversely a rig that puts a test civilian at the blast centre proves only
that `apply_explosion_damage` works — **which it already does**, exercised by `grenade.gd:101`,
`claymore.gd:58`, `projectile_base.gd:359`. **Assert the garrison-specific thing instead: that
survivors outside the radius react.** They will not (`civilian.gd:174-175`) — and *that* assertion is
the one that cannot pass by accident.

**"The player is informed."**
The worst trap in the set, and the exact shape of today's two incidents. `_poll_firebase_threat`
(`field_director.gd:626-641`) raises the crisis and its toast **from geometry alone**, with no sapper
behaviour whatsoever, and `tests/test_dynamic_events.gd:205-244` already proves it. **Any probe
asserting "a firebase_attack location reached the director" or "a toast was emitted" is satisfied by
a system that shipped weeks ago.** The only assertion that discriminates is the *bespoke string*
`"SAPPER IN THE WIRE!"` — which is itself the thing §3 argues should not exist. **If the only probe
that can prove the feature is a probe on a duplicate channel, that is the design telling you the
channel is wrong.**

**Bonus trap — the fossil probe will not protect you.** `SapperCharge` is **not** in
`tests/fossil_baseline.json` (24 entries, ceiling 24) despite being a zero-reference orphan, because
the register keys on `func`/`const`/`signal` symbols and `setup` / `_physics_process` /
`DETONATE_RANGE` are either engine callbacks or names that collide with live code elsewhere. The
audit already flagged this and proposed `probe_behaviour_attached`
(`production/GAME_AUDIT_2026-07-19.md:164,168`). **Until that probe exists, "the file is wired" has no
mechanical witness — and the fossil register will keep reporting a healthy 24 either way.**

---

## 8. WHAT THIS FEATURE SACRIFICES (the law binds me too)

If it is built as framed, here is the bill, named:

1. **Pillar 3 (Freedom):** the crisis retarget pulls the player off the walk he chose and points him
   home (`field_director.gd:614`), and arriving there **banks the patrol** (`:551-553`). The open
   loop grows a rail.
2. **Pillar 1 (Believable firefights):** the firebase fight is not a fight. One side cannot shoot,
   cannot flinch, and cannot flee (`civilian.gd:174-175`).
3. **Truth (ADR-015):** the AAR credits the player with kills he did not make
   (`field_director.gd:55`).
4. **ADR-023 (fossil law):** a second player-information channel beside `raise_crisis`
   (`sapper_charge.gd:28` vs `field_director.gd:605-621`).
5. **Verification (ADR-015):** as shown in §7, the natural probes for this feature are all
   pre-satisfied. Closing this on a green suite would be closing it on nothing.

---

## 9. WHAT I WOULD BUILD INSTEAD (if the Summoner's ruling stands that it goes in)

The ruling is his; my job is to name the cheapest honest shape.

- **Scope it to the witnessable probe.** Sappers crawl the wire **while the player is inside it** —
  night, or on return. He hears them, he shoots them, or the wire goes up in front of him. No crisis
  plumbing, no retarget, no toast, no `_seen` latch. The event **is** its own announcement.
- **Delete the bespoke toast** (`sapper_charge.gd:26-28`). If a message is ever needed, it goes
  through `raise_crisis` and the `CRISIS_CALL` table like every other crisis.
- **Make it a real movement behaviour** — a goal or an explicit velocity override — or admit the
  36-line file is a stub and write the thing it pretends to be. Do not ship the docstring at `:1-2`
  as-is under any circumstance.
- **Fix `record_kill` first** (`field_director.gd:54-56`) so a self-inflicted death is not the
  player's kill, or accept a known lie in the AAR.
- **Blocked-on:** whether the garrison ever becomes combatant is a **Summoner decision**, and the
  away-version of this feature should not be built until it is answered. Filing that as a `decision`
  bead is worth more than any code in this wave.

---

*Devil's Advocate, 2026-07-20. Every pointer above was read this session.*
