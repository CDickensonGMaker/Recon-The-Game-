# SUITE TRIAGE — 2026-08-07, the 22 unexamined failures

Every test below was run STANDALONE with `-- --test-save`. Assertions are verbatim.
Suite context: 86 PASS / 35 FAIL / 16 LEAK / 0 TIMEOUT (`test_results/suite_2026-08-07_run3.log`).

**Read this first:** of the 12 failures examined earlier today, **10 were rotted probes and 2
were real code**. That prior is why this triage exists — guessing which of these 22 are real
would have been worse than measuring them.

---

## REAL DEFECTS — ranked by what they cost the demo

### 1. ~~SAPPERS DO NOT DETONATE~~ — **WRONG. I misread this. It is a STALE PROBE.**
```
test_sapper_assault : FAIL: a sapper AT the objective did not detonate   <- the TEST was wrong
test_arena_sandbox  : FAIL: sapper never detonated after reaching its objective
```
**Corrected 2026-08-07, same day. The breach chain works and the demo's climax was never at
risk.** I ranked this #1 on two probes agreeing, without reading the probe.

`test_sapper_assault:85` called `_physics_process(0.1)` **once** and then asserted
`at.is_dead()`. Both halves are the old design:
- The plant now takes `PLANT_SECONDS = 3.0` **deliberately** — `sapper_charge.gd:165`: *"Killing
  him DURING the three-second plant is the window that makes the timer matter."* One tick cannot
  reach the fuse.
- Death is no longer the success condition. `_detonate`'s comment: *"This used to detonate at the
  man's own feet and then kill him outright, so three sappers on one objective died in one blast
  — a suicide squad, not demolition men. The charge is a THING now (PlacedSatchel), which is what
  lets him live through his own work."* The probe asserted the suicide-bomber build that was
  explicitly replaced on his 2026-07-30 ruling.

Rewritten to run the fuse out and assert a `PlacedSatchel` exists **and the sapper survives**.
`test_sapper_assault: PASS`.

**The lesson is about me, not the code:** two probes agreeing is not evidence when both were
written against the same superseded design. `test_arena_sandbox` carries the identical stale
assumption and is parked with the rest of the arena.

### 2. KILLS ARE NOT COUNTED
```
test_mission_state : FAIL: kills=0 expected 3 (kill-count fix broken)
                     result dict: { "kills": 0, ... "contacts_detected": 2, "contacts_avoided": 1 }
```
`contacts_*` populate; `kills` stays 0. The AAR scores on kills, `_bank_patrol` reports
"PATROL %d LOGGED, %d KILLS", and ADR-006's economy prices avoidance *against* kills. A patrol
that reports zero kills reports the wrong story.

### 3. THE HANDSET IS RIPPED OUT OF HIS HAND
```
test_handset_fire_net : FAIL: handset ripped back to STOWED
                        FAIL: holding_handset cleared by the snap
                        FAIL: the fire menu CLOSED with the handset
```
His 2026-08-04 ruling was **"the cord NEVER rips the handset away"** — the snap was deleted,
`cord_snapped` removed, cord lengthened 3→8 m. The probe says a snap still fires. Either the
deletion missed a path or a second mechanism stows it. RTO fire support is the player's whole
relationship with the war.

### 4. THREE DISPATCH TARGETS ARE DEFINED NOWHERE
```
test_dispatch_contract : FAIL: dispatch target "on_atrocity_witnessed" is defined NOWHERE
                         FAIL: dispatch target "give_weapon" is defined NOWHERE
                         FAIL: dispatch target "has_weapon_path" is defined NOWHERE
```
`on_atrocity_witnessed` was found independently this morning (`player.gd:249` guards it with
`has_method`, so the branch is a permanent no-op). Two more of the same class.

### 5. THE CRISIS NET DOES NOT REACH THE PLAYER
```
test_dynamic_events   : FAIL: on the net, the crisis did not retarget the sweep
                        FAIL: on the net, the crisis did not set the location kind
                        FAIL: on the net, the crisis was never announced to the player
test_friendly_patrols : FAIL: the pinned call never reached the player - toasts were []
                        FAIL: the sweep was never retargeted onto the pinned element
```
Two probes, one subsystem. A friendly element gets pinned and the player is never told —
the r4bk law ("a feature without a visible affordance does not exist") applied to a whole system.

### 6. TWO WEAPONS SWING 0° ON ADS
```
test_weapon_projectile_contract : FAIL: aircraft_20mm declares no ads_rotation
                                  FAIL: car15 declares no ads_rotation
```
`car15` is post-launch and unreachable; `aircraft_20mm` is a mounted gun. Low player impact,
trivial data fix.

### 7. EXPOSURE RAMP DATA NOT PLUMBED
```
test_ai_fairness : FAIL: nva exposure_ramp 1.60 != 2.2 (data not plumbed)
                   FAIL: farmer exposure_ramp 2.60 != 3.5
```
Per-archetype ramp values in the `.tres` are not reaching the marksmanship model — every
archetype fires the default. The Fairness Law's ramp is Pillar 1 machinery.

### 8. THE ADVANCE LADDER
```
test_ally_states : FAIL goal ladder enters ADVANCING / FAIL goal is ADVANCE
                   FAIL still advancing with the gap open
```
**Check the defensive-zone work first**: `ally_base` gates ADVANCE/FLANK for any man with a
`defense_zone`, so a zoned ally in this probe would be *correctly* refused. May be stale rather
than real — needs one look at whether the probe's ally is zoned.

### 9. BALLISTICS
```
test_bullet_flight : FAIL: gravity drop wrong (19.93m)
                     FAIL: bullet never resolved against the HEAD hitzone
```
Undetermined without deeper work. Could be probe expectations or real drop math.

---

## STALE PROBES — the test moved, not the code

| Test | Assertion | Why it is stale |
|---|---|---|
| `test_squad_body_pool` | `MEDIC drew body us_medic, which is not in the m16a1 pool` | **Identical to the bug fixed in test_firebase_garrison this morning.** `civilian.gd:166` staffs medical roles deliberately; `models_for()` is the named authority. The probe checks a WEAPON pool instead. Same one-line fix. |
| `test_activity_tiering` | `20 granted, expected HOT_CAP=50` | Probe sized against a HOT_CAP it no longer matches. |
| `test_think_budget` | `no cold fighters with 14 men vs HOT_CAP 50 - probe vacuous` | **The probe says so itself** — 14 men against a cap of 50 can never produce a cold fighter. It proves nothing at the current cap. |
| `test_patrol_contract` | `field_director.gd tasking uses objective-pin vocabulary 'OBJECTIVE'` | ADR-029 vocabulary rule. Real but cosmetic — a string, not behaviour. |

## ART GAPS — recorded in `ART_GAPS_2026-08-07.md`, not blocking

| Test | Assertion |
|---|---|
| `test_bench_rack` | `expected 11 weapons with arms viewmodels, data says 12` · `a weapon with no arms viewmodel reached the rack` — this is **m72_law_fp.glb** |
| `test_seat_system` | `seat_pilot_l occupant playing 'cockpit_controls', wanted 'cockpit_idle'` |
| `test_actor_damage_contract` | `zombie_base.gd declares take_damage() but is NOT in ACTOR_CONTRACT` — a row, not art; trivial once zombie mode is ruled on |

## PROBES THAT ADMIT THEY PROVE NOTHING

| Test | Its own words |
|---|---|
| `test_hitzone_rebuild` | `us_grunt_rifleman and us_grunt_mg harvest identical hulls — the discriminator is DEAD, this probe proves nothing` |
| `test_group_contract` | `group "bench_sappers" / "hunters" / "zombie_mystery_box" written but NEVER READ — inert link that reads as live wiring` |

`hunters` is worth a second look: `field_director.gd:182` adds men to that group and `:181`'s
comment says `live_enemy_count("hunters")` reads it. Either the probe's reader-detection is
blind to that call, or the count really is unread.

## FLAKY

`test_squad` — **passes standalone**, fails in-suite. Third confirmation (see task #11).

---

## COUNTS

**8 real defects · 5 stale probes · 3 art gaps · 2 self-admitted vacuous probes · 1 flaky**

The prior held: examined-and-real is now 11 of 34 across the day, so roughly two thirds of this
suite's red was probe rot. But the third that is real contains **the sapper breach**, and that
one is the demo's climax.
