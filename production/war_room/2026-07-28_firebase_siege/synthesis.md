# THE DECREE — THE SIEGE (firebase night assault v2)

**Arbiter's synthesis, 2026-07-28.** Council: systems_designer, game_designer, lead_programmer,
devils_advocate. Analyses in `analysis/`. Briefing in `briefing.md`.

The decree stands unamended in intent. What follows is HOW, what it COSTS, and the two places the
decree's arithmetic collides with shipped code.

---

## 0. THE ARBITER'S RULINGS ON COUNCIL CONFLICT

**CONFLICT 1 — does the 40–50% break already exist?** game_designer said yes (`enemy_squad.gd:103`
`BREAK_RATIO = 0.45`); systems_designer said it breaks at 55%. **Arbiter measured it: systems_designer
is right and game_designer misread the direction of the ratio.** `break_state` (`enemy_squad.gd:109-112`)
computes `ratio = live/peak` and breaks when `ratio < threshold`. `threshold = 0.45` means broken after
**55% killed**, and `clampf(BREAK_RATIO + (0.5 - avg_courage) * 0.4, 0.20, 0.65)` (`:111`) *lowers* the
threshold for high-courage NVA — they hold to ~63% losses.

**RULING:** the MECHANISM is correct and is the single break authority — no second morale system is
built (divergent-systems law). The NUMBER is out of band. The siege squad carries a siege threshold of
**0.575** (breaks at 42.5% killed, inside the decreed 40–50%), reached by giving the assault its own
`squad_id` and a siege-specific threshold override rather than by moving `BREAK_RATIO` for the whole
game — a global move would retune every ambush and camp fight in the build.

**CONFLICT 2 — does the current 4-man element stall at 300 m?** The Arbiter's own read said "unverified."
lead_programmer returned **NOT CONFIRMED — worse.** They close, but by accident: `_update_line_of_sight`
returns early at `enemy_base.gd:1042-1045` without incrementing `target_last_seen_time` when
`target == null`, so INVESTIGATE never expires; `_execute_alert` then follows `EnemySquad.hunt_point`,
whose anchor slides to `HUNT_ADVANCE_MAX = 130 m` **past** `fsb_center` (`enemy_squad.gd:303-304,
332-341`). **The element walks through the compound and loiters 130 m out the far side.** That is the
decree's own §7 lost-NPC failure, already shipping today. Correct my earlier reading in the record.

---

## 1. WHAT THE COUNCIL CONVERGED ON, UNANIMOUS

Three architects arrived independently at the same finding, from three different doors. Per the War
Room's own standard, that is the strongest signal this process produces.

**WITHDRAWAL DOES NOT EXIST IN THIS CODEBASE.** `_execute_retreating` (`enemy_base.gd:1644-1676`)
flees on a bearing computed away from the threat, slides along walls, and has **no destination, no
stop distance, no timeout, and no map clamp.** `EnemyBase` has **no despawn path** — `_live_enemies`
is erased only on death (`field_director.gd:65`), and `enemy_base.gd:902` holds a routed man at ALERT
forever, which pins `_body_gate_open()` (`:534-536`) open for the rest of the operation.

Over three nights of d50 that is **~40+ permanent full-cost ghosts** wandering the AO. The decree's
§7 — "so there isn't lost enemy NPCs the player cannot find" — is not a nice-to-have. **It is the
single largest piece of new engineering in this decree, and it does not exist in any form.**

---

## 2. THE SHAPE OF A SIEGE

Constraint the council surfaced and the design must obey: **night is 600 real seconds.**
`SimClock.real_to_sim_ratio = 60.0` (`sim_clock.gd:17`) × `period_at` (`:56-63`). Everything below
fits in ~8 minutes with a hard break-off at 480 s.

| Phase | t | What happens |
|---|---|---|
| **STAND-TO** | 0 s | First ranging round lands. Garrison promotes. Radio: contact. |
| **RANGING** | 0–60 s | Enemy 82 mm walks in. First rounds 45–60 m off, tightening. |
| **PROBE** | 60–120 s | Sappers move on the wire under the shelling. Assault echelon closes on the axis. |
| **ASSAULT** | 120–300 s | Mortars at max accuracy (12–18 m), the axis goes loud, breach attempts. |
| **DECISION** | 300–480 s | Break threshold crossed → withdrawal. Or the wire is breached. |
| **HARD BREAK-OFF** | 480 s | Dawn pressure: survivors withdraw regardless. A siege never runs forever. |

**Mortar walk-on** (reusing `_fire_shell` / `_mortar_impact`, `field_director.gd:648-730`): dispersion
50 m → 12 m over 180 s, 3-round volleys at 20–25 s. Two hard fixes required — `_fire_shell` computes
its azimuth from `fsb_center` (`field_director.gd:656`), so **an enemy shell currently arrives from
inside the compound**; and it must take a `from` bearing param.

---

## 3. THE BREAK, AND WHO GETS CREDIT

devils_advocate and lead_programmer independently found the same seam and it is decisive.

`_on_enemy_died` (`field_director.gd:63`) **discards the killer** — the signal (`enemy_base.gd:5`)
carries none. The only attributor, `_credit_killer` (`enemy_base.gd:2271-2274`), credits only nodes
with a `member` dict, and **ADR-032 structurally excludes the player.** The player's own mortars
(`:726`), arty (`:579`) and claymores (`claymore.gd:58`) all pass `attacker = null`. He can wipe
fifteen men and by every ledger have killed nobody.

And the trap: you cannot simply start passing the player as attacker, because
`combat_manager.gd:149-150` reads `attacker == null` as "indirect fire — 0.4× to your own men."
Fixing attribution makes the player's own steel **2.5× more lethal to his own squad.**

**ARBITER'S RULING: the break counts EVERY attacker death inside the siege, not player-attributed
kills.** The player is one rifle on the perimeter (Pillar 4 — he is IN the squad, not above it); the
garrison holding with him is the fantasy, not a solo kill-count. This is faithful to "holding off long
enough" and it dodges a rewrite of the friendly-fire discount that would ship a live regression.

**The one exclusion:** enemy mortars must not damage their own men, or the enemy's ranging rounds
break their own siege. Filter at the shell, not with a new attribution ledger.

**Sacrificed:** a player who hides in a bunker while a competent garrison does all the killing still
"wins" the siege. Accepted — the garrison can be killed, and a passive player loses defenders, MG
posts and the depot. The punishment is the degraded firebase, not a locked door.

---

## 4. THE AXIS AND THE REAP

**Axis = a 60° SECTOR, not a line** (game_designer's amendment, Arbiter accepts). Assault echelon
and the loud element share the sector. Sappers may enter on a *different vector inside the same
sector* — enough to prevent a shooting gallery, not enough to lose a man.

**THE REAP — the new work.** On break, the SiegeDirector takes every survivor:
1. Frees any `SapperCharge` child. `SapperCharge._physics_process` tests `target_pos`
   (`sapper_charge.gd:42-51`), so **a withdrawing sapper crossing his old aim point detonates on the
   way out.**
2. Sets `assault_objective` to a rally point 350 m back down the sector axis — `assault_objective`
   already drives legs through contact (`enemy_base.gd:1317`), which `_execute_retreating` cannot.
3. Reaps the man at the rally, or at a hard 600 m radius, or after 90 s — whichever first.

Note `enemy_base.gd:1317-1319`: the FSM never touches a driven man's legs, so a sapper cannot use the
retreat path at all. The rally-objective route is the only one that works for both.

---

## 5. PERF — THE HONEST NUMBER

lead_programmer, measured against `PERF_LEDGER.md:295-304, 338-339`: **0.22 ms/unit**, ~85 bodies
(50 attackers + garrison + squad) ≈ **17–19 ms per physics tick = 34–38 ms of AI per frame at 30 fps.**
The frame is already 38 ms. This does not fit.

The cited mitigations are inert: `HOT_CAP = 12` (`enemy_squad.gd:37`) gates only `_think_full_combat`,
which is 1.2 ms of a 38 ms wall — **a 50-man siege would be a 12-man firefight with 38 spectators.**
ALERT-tier men skip tiering entirely (`enemy_base.gd:596-601`), the WA-A2 body gate banks zero for
attackers by contract (`:535-536`), and ADR-025 reads `SUPERSEDED` at line 3.

### SUMMONER'S RULING, 2026-07-28 — THE MARCHING CELL

> *"we could group the enemies up as hivemind group thinks that operate more or less together until
> their unit is attacked and split up... if you link 3 to 6 units together at a time of similar type
> that would be the best way to do it"*

**The Arbiter measured the ruling before recording it, and it survives — but it must bind to the BODY,
not the BRAIN.** Per `PERF_LEDGER.md:295-304` (W0 headless, 65 units): think = 1.2 ms of a 38–40 ms
wall. Thinking is **3%**. move_and_slide (9 ms) + hitzone sync (10 ms) + anim/execute (19 ms) is 97%.
A hivemind that shares only *thoughts* banks nothing.

**A hivemind that shares BODIES banks everything** — and the pattern already ships: `LazyGroup`
(`lazy_group.gd`) is one `Node3D` with zero bodies that materializes men through
`director.spawn_tracked_enemy` (`:88`) on proximity, keeping the single spawn authority intact.

**THE SIEGE IS COMPOSED OF MARCHING CELLS.** A cell is **3–6 men of ONE type** (homogeneous: while
dormant a cell holds one `EnemyData` reference, not six). A d50 of 43 → ~9–10 cells; the 2d6 sappers
form their own cells. Each cell walks the sector axis as a single node, emitting `NoiseBus` noise,
carrying its strength as an int, and becomes real bodies at its own trigger. Load arrives staggered by
terrain and pace instead of in one spike.

**Cell = squad, so the break math is already written.** `EnemySquad.break_state`
(`enemy_squad.gd:109-112`) is a pure static function: call it at CELL scope (a cell breaks and runs)
and at ASSAULT scope with summed live/peak (the siege breaks). **One authority, two scopes** — the
divergent-systems law is satisfied without a second morale system.

**Four contracts this ruling creates:**
1. **Materialize radius > sight cap.** 80 m against the 56 m open-ground cap (`sight_cap.gd:12`) gives
   24 m of margin; the 18 m jungle cap gives plenty. Below the cap and the player watches men pop in.
2. **Materialize on ILLUMINATION, not only proximity.** A flare or illum round over a dormant cell at
   200 m must not reveal empty grass.
3. **The break counts against TOTAL strength, materialized or not.** Otherwise killing 8 of the 15
   currently real reads as 53% and a 43-man siege breaks on its first echelon.
4. **Dormant cells make noise.** An approaching company is heard before it is seen. Free dread.

**Honest limit, named as the law requires:** this DELAYS the body cost, it does not delete it.
Everything converging on one sector still arrives together. A ceiling on simultaneous live men is
still required — but it is now diegetic (only what is in contact is real) rather than an arbitrary
spawn cap, and it is the only mitigation available inside Forward+ (ADR-001 forbids the renderer swap).

---

## 6. THE THREE NIGHTS — AND WHAT THE DECREE COSTS

devils_advocate's finding, and the Arbiter rates it the most important thing in this document:

**`GarrisonDefender.promote` DESTROYS the Civilian** (`garrison_defender.gd:42-48`). After night 1 the
`firebase_garrison` group is **empty**, all 24 scheduled civilians (`site_planner.gd:726`) are gone
forever, and the player's home is a fort of static HOLD-order soldiers on 8 m leashes
(`ally_base.gd:855`). Un-latching `_garrison_stood_to` for night 2 loops over nothing.

**Pillar 2 (Atmosphere) pays for this decree, permanently, on the first night — and no design doc
mentions it.**

**RULING: STAND-DOWN IS PART OF THIS DECREE, NOT A FOLLOW-UP.** At dawn, surviving defenders revert to
Civilians at their posts. Dead men stay dead and are not replaced — *that* is what makes night 2 and
night 3 different from night 1, and it is the dramatic engine the three-night structure needs.

Also required for three nights: `SimClock.sim_day` is **not serialized** (`campaign_state.gd:208-229`,
`:281`), so F5/F9 resets the run to night 1; and `save_data.gd:15-17` serializes **zero live enemies**,
so saving mid-siege deletes it. `_firebase_breached` is once-per-op against a single `_sapper_aim`
(`field_director.gd:801`), so after night 1 up to 33 later satchels detonate 250 dmg / 14 m inside the
wire with **zero player-facing consequence** — the depot must become a set of destructible objectives
(ADR-031 already supports this) rather than one boolean.

---

## 7. FOSSIL LAW — WHAT DIES

Deleted in the same change: `SAPPER_DATA`, `SAPPER_COUNT`, `SAPPER_RING_MIN/MAX`, `SAPPER_CHANCE`,
`ASSAULT_DATA`, `ASSAULT_ELEMENT`, `_sapper_launched`, `_sapper_rolled_night`, `_maybe_launch_sappers`,
`launch_sapper_assault` (`field_director.gd:783-1146`). `tests/test_sapper_assault.gd:198-199` asserts
the exact `patrol_out` gate being removed and must be rewritten, not deleted.

## 8. OTHER LIVE DEFECTS SURFACED (fix on contact — drift law)

- `enemy_base.gd:1042-1045` — INVESTIGATE never expires when `target == null`. Root cause of the
  130 m overshoot. **Fixing this alone makes the current assault stall at 300 m** — do not fix it
  without the objective work.
- Removing the `patrol_out` gate (`field_director.gd:1027`): `raise_crisis` banks a `firebase_attack`
  patrol location (`:1009`, before the guard at `:1010`) that `_pick_patrol_location` takes first
  (`:1152-1159`) — **the next walk-out would task the player to sweep his own firebase.**
- The `"wp"` fire mission is UNFINISHED, not fossil: `_run_wp_mission` exists (`:610`) with no
  `fire_support` dict entry (`:255`), no grant (`:962-965`), no input key (`:180-195`). An ILLUM
  mission on `_fire_shell` (`:648`) is the siege's missing strategic verb — night sight caps at 56 m
  open / 18 m jungle (`sight_cap.gd:12`, probe-locked `test_night_sight.gd:58`) against attackers
  spawning at 300–500 m, with only 3 flares × 25 s (`player.gd:94`, `illum_flare.gd:8`).
- `_bank_patrol` fires only on crossing the wire inward (`:941-943`), so a siege fought at home banks
  no AAR — while `spawn_tracked_enemy` debits the ADR-006 ledger regardless (`:42-44`). **The player
  is currently scored DOWN for being attacked in his sleep.**

## 9. WHAT IS SACRIFICED — no free lunches

1. **Frame budget.** Even echeloned, this is the most expensive combat event in the game.
2. **The living firebase, unless stand-down ships with it** (§6).
3. **A passive player can still "win"** a siege the garrison fought (§3). Accepted.
4. **Scope.** This is a multi-session build — siege state machine, enemy indirect fire, the reap,
   garrison stand-down, save serialization, illum. Other work parks.

## 10. ILLUMINATION — SUMMONER'S RULING, 2026-07-28

> *"we do need illumination in the game — it can be a flare round fired from the m79 grenade
> launcher or from the mortar."*

**IN SCOPE. Two delivery systems, two different verbs, sequenced by what they cost.**

`scripts/combat/illum_flare.gd` already ships a drifting light that strips night concealment
(`DURATION 25.0`, `LIGHT_RADIUS 30.0`, `:8-9`) and exposes `IllumFlare.is_lit(pos)` (`:14-18`) —
**which is also the exact hook the marching cells need to materialize when lit** (§5 contract 2). No
rework; reuse whole.

**MORTAR ILLUM — ships WITH the siege.** `_fire_shell(MORTAR_SHELL, target, callback)`
(`field_director.gd:648`) already flies the shell and fires a callback on impact; illum is that same
shell with a callback that pops a flare instead of applying damage. The only missing pieces are the
same ones the WP round lacks: a `fire_support` dict entry (`:255`), a grant in `_grant_fire_support`
(`:957-965`), an input key (`:180-195`). This is the siege's strategic verb — deciding *when* to spend
light — and at 300–500 m approach ranges it is the only one that reaches.

**M79 ILLUM — DEFERRED behind an ammo system.** `WeaponData` carries exactly ONE
`projectile_data_path` (`m79.tres:31`); **there is no ammo-type concept in this game.** The Blooper's
illum round therefore requires either a duplicate armory entry (cheap and silly — two M79s) or real
ammo selection on the weapon system, which touches the FP viewmodel pipeline currently ruled top
priority. Ammo switching pays off well beyond illum (buckshot, WP, tracer belts) and should be built
for its own sake, not smuggled in under the siege. M79 range is 100 m (`m79.tres:26`) — a wire weapon,
not an approach weapon, so the siege does not need it.

**SCALE CORRECTION (required).** `LIGHT_RADIUS = 30.0` is correct for a hand-thrown pop flare and far
too small for a siege: a 30 m circle against a 60° sector at 300–500 m is a spotlight, not battlefield
illumination. The mortar round wants its own constants — higher, wider, longer-burning, slower drift
under a parachute. Same class, different numbers.

**LIGHT BUDGET: WAIVED BY THE SUMMONER, 2026-07-28** (*"i wouldnt worry about the budget itll work"*).
The `OmniLight3D` ceiling noted at `mission_generator.gd:351` is not to be treated as a blocker.
Failure mode if it ever bites is visible (flares dimming or popping out), not a framerate cliff.

---

## 11. STILL OPEN — the one call not yet made

**WHAT LOSING A SIEGE COSTS.** Discussed 2026-07-28, deliberately NOT ruled. The Summoner's read:

> *"I like the idea of trying to survive a battered firebase but it should be the player's option to
> choose to go on patrol or stay at the base and repair things with their resources if they even have
> enough. But then that's going down a whole other avenue of game style we're not ready for yet."*

The Arbiter's finding from that exchange, for whenever it resumes: **the economy that makes this work
already exists and already points the right way.** `_grant_fire_support` allots the patrol its steel
**as the player crosses the wire OUTBOUND** (`field_director.gd:946`), and the threat tier cools on
clean patrols and heats on loud ones (`:951-956`). So a day spent inside costs the allotment, costs
ground covered, and lets the province heat up while the base is at its weakest. **Turtling is already
punished by shipped code — no new system is needed to prevent it.**

The separable halves: the CHOICE (go out, or give the day to the base) is cheap and already has a home
at the wire gate. The REPAIR ECONOMY (pools, menus, timers) is the genre we are not buying. A version
exists that takes the first without the second — the player repairs nothing; the garrison Civilians do
it themselves at their existing work posts and hourly schedules, and the player's only input is whether
they get the day. The fork underneath is materiel (labor = time) vs men (replaced, not repaired —
and green under ADR-018, so a replacement is genuinely worse than the man who died).

**PARKED at the Summoner's direction. Do not build. Do not treat as ruled.**
