# ADR-035 REVIEW — TECHNICAL DIRECTOR (adversarial)

**Date:** 2026-07-28 · **Scope:** DRAFT `production/adr/ADR-035-the-siege.md`.
Summoner rulings (any night · 3 nights · d50 · 2d6 · cells of 3–6 · one axis · installations-as-objectives ·
break at 40–50% · the respawn stake) are LAW and are not touched here. Everything else is fair game.

Every pointer below was opened and read on 2026-07-28. Verdict at the bottom.

---

## PART 1 — POINTER AUDIT

23 pointers spot-checked. The ADR's pointer hygiene is **above the house average** — the load-bearing
code citations are almost all exact. The failures are concentrated in derived NUMBERS and in one
misdescription of shipped state.

### 1.1 WRONG

| Claim | Cited | Actual | Severity |
|---|---|---|---|
| "the 56 m open-ground / 18 m jungle caps" | `sight_cap.gd:12` | `:12` is `DARKNESS_BY_PERIOD = [1.0,1.0,0.75,0.4]`. The caps are `EnemyBase.SIGHT_CAP_OPEN = 140.0` / `SIGHT_CAP_JUNGLE = 45.0` (`enemy_base.gd:80-81`), sourced through `sight_cap.gd:15-20`. | **HIGH — load-bearing** |
| "`WeaponData` carries exactly one `projectile_data_path` (`m79.tres:31`)" | `m79.tres:31` | `:31` is `recoil_climb_max = 1.0`. `projectile_data_path` is `:28`. | MED |
| "M79 range is 100 m (`:26`)" | `m79.tres:26` | `:26` is `min_damage_mult = 1.0`. `effective_range = 100.0` is `:24`. | MED |
| "fire support is granted crossing the wire outbound (`field_director.gd:946`)" — cited twice, §10 and Open | `:946` | `:946` is a `##` doc-comment. The call is `_grant_fire_support()` at `:939`; the function is `:957`. | MED |
| "threat cools on clean patrols (`:951-956`)" | `:951-956` | All six lines are doc-comment prose. | LOW |
| "the shipped `CampaignState.depot_loss` path … must become a set of destructible objectives, **not the current single boolean**" | §4 | `depot_loss` is **already a `Dictionary`** (`campaign_state.gd:47`) with a migration (`:53`) and full save/load coverage (`:226, :265, :294, :312`). The boolean is `_firebase_breached` (`field_director.gd:805`), a one-breach-per-op **latch**. | **HIGH — the ADR misnames the thing it orders changed** |
| "static HOLD-order soldiers on **8 m** leashes (`ally_base.gd:855`)" | `:855` | `:855` is the leash CHECK. `post_leash: float = 8.0` is `ally_base.gd:147`. | LOW |
| "AI think is 1.2 ms of a 38–40 ms wall — **3%**" | `PERF_LEDGER.md:295-304` | The ledger's own sentence at `:301-303` says **"perception rays + think are ~6% of it."** The ADR silently halves its own source's figure by dropping rays. | LOW (direction unchanged) |

### 1.2 THE SIGHT-CAP ERROR IS NOT COSMETIC

Contract 1 (§2) is the whole safety argument for the marching cell: *"Materialize radius > sight cap.
80 m against the 56 m open-ground / 18 m jungle caps."*

- 56 and 18 are **night-derived**: 140 × 0.4 and 45 × 0.4, using `DARKNESS_BY_PERIOD[NIGHT]`. The ADR
  never says so, so a reader cannot re-derive them, and the number it cites the line for is not on it.
- **DUSK is 0.75** (`period_at:56-63` puts 17:00–19:00 in DUSK). Open-ground sight at dusk = **105 m > 80 m.**
  The ADR permits a siege "on any night" and never constrains the start hour.
- Worse: `sight_cap.gd:34` reads `IllumFlare.is_lit(look_pos)` and **restores sight under a flare.** §7
  then makes mortar illum the player's "strategic verb… at 300–500 m approach ranges."
- **Net: the player's own §7 verb breaks §2's contract 1.** Pop illum down the axis at dusk-adjacent hours
  and the sight cap climbs above the 80 m materialize radius, and men appear out of nothing — the exact
  failure contract 1 exists to prevent. §2 and §7 were written without reading each other.

### 1.3 CORRECT — verified exact, credit where due

`PERF_LEDGER.md:295-304` (the 1.2 ms / 9 / 10 / 19 ms split, W0, 65 units) · `enemy_squad.gd:103`
(`BREAK_RATIO = 0.45`), `:109-112` (`break_state`, `ratio = live/peak`, `broken = ratio < threshold`) —
**the ADR has the direction of the ratio RIGHT**, 0.45 does mean broken after 55% killed, and the courage
term does *lower* the threshold for high-courage men · `enemy_squad.gd:303-304` (`HUNT_ADVANCE_MAX = 130.0`),
`:332-341` (`hunt_anchor_now`, the `minf` clamp at `:340`) · `enemy_base.gd:1042-1045` (the `if not target:`
early return; `target_last_seen_time` is incremented at **`:1061` only**, downstream of it — the freeze is
real), `:1131` (the INVESTIGATE branch), `:902` (`_set_tier(AlertTier.ALERT)  # never back to RELAXED`),
`:534-536` (`_body_gate_open` returns true on `alert_tier > RELAXED` — the pin is real), `:1317-1319`
(the `assault_objective` override sits ABOVE the `match current_state`), `:1644-1676` (`_execute_retreating`
— no destination, no stop distance, no timeout, no clamp: **confirmed verbatim**), `:5` (`signal died(enemy)`
carries no killer) · `combat_manager.gd:149-150` (the `attacker == null` → `×0.4`) · `lazy_group.gd:88`
(**exactly** `director.spawn_tracked_enemy(...)`) · `garrison_defender.gd:42-48` (**exactly** the
`queue_free` teardown block) · `site_planner.gd:726` (`FSB_GARRISON_MAX_MEN: int = 24`) ·
`illum_flare.gd:8-9, 14-18` · `field_director.gd:63, 65, 255, 579, 656, 668(→ mission_generator), 726,
783, 802, 941-943, 957, 1009, 1010, 1027, 1067, 1085, 1152, 1213` · `mission_generator.gd:668-673`
(armorer's bench) and `:784` (`_place_firebase_mg`) — and `_sapper_aim` is indeed the bench
(`field_director.gd:912`) · `sapper_charge.gd:42-51` · `claymore.gd:58` · `campaign_state.gd:208-229, :281`
(no `sim_day` in the save — confirmed) · `save_data.gd:15-17` (`mission: Dictionary = {}`, "live enemies"
reserved, never written) · `health_system.gd:233-246` · `game_manager.gd:51` ·
`test_sapper_assault.gd:198-199` (asserts **exactly** the `patrol_out` silence being removed) ·
`ADR-025:3-19` (SUPERSEDED — the ADR is right to fence it off) · `firebase_interior_wiring.md:188`
(340 markers / 191 `work_*` / 86 `prop_*` / 16-of-16 garrison keys).

### 1.4 THE SIM-CLOCK ARITHMETIC — CHECKED, AND IT HOLDS

`advance()` computes `sim_hour += delta * real_to_sim_ratio / 3600.0` with `real_to_sim_ratio = 60.0`
(`sim_clock.gd:17`) → 60 sim-seconds per real second → 1 real second = 1 sim minute. `period_at:56-63`
puts NIGHT at ≥19:00 or <5:00 = 10 sim hours = 600 sim minutes = **600 real seconds. The ADR's number is
correct, and `period_at:56-63` is line-exact.**

**But the invariant built on it is not.** "A siege never runs to dawn undecided" is asserted from a 480 s
break-off inside a 600 s night. That only holds if the siege *starts* in the first 120 s of night. §1 says
it may fire "on any night" and constrains nothing about the hour. A roll at 02:00 gives 180 real seconds
of night and the 480 s break-off fires in daylight, with 40 attackers standing in the open at a 140 m
sight cap. **§1 needs a trigger-window clause it does not have.**

---

## PART 2 — ENGINEERING

### 2.1 The marching cell moves the spike; the "diegetic ceiling" bounds nothing

The premise is sound and well-sourced: think is ~1.2 ms of a 38–40 ms wall, the body is the cost, and
deferring the spawn defers the body. `LazyGroup` is the right precedent and routing through
`FieldDirector.spawn_tracked_enemy` genuinely preserves the single spawn authority (`lazy_group.gd:88`).
The design is also correctly distinguished from the condemned `WorldSim` tiers: cells never *dematerialize*
a live node, so ADR-025's second-spawn-authority kill-shot does not reach it.

**The ceiling does not exist.** §3 sends the whole assault up **one 60° sector** at **one** installation
cluster. Every cell is walking the same axis to the same point. They therefore cross the same 80 m ring
within a window set only by their column spacing — call it 30–60 s at 2–3 m/s. At the end of that window
you have the full d50 live, exactly as if there were no cells. §2's own "Honest limit" admits this
("a ceiling on simultaneous live men is still required") and then declines to name one, substituting the
phrase *"it is now diegetic (only what is in contact is real)."*

**That sentence is hand-waving and should be struck.** "In contact" is not a bound; in a converging
one-axis assault, *everyone* is in contact within a minute. A ceiling is a NUMBER (max simultaneous
materialized attackers, with a queue and a rule for what happens when a cell wants in and the ceiling is
full). The ADR must either name it or admit the cell buys stagger, not headroom.

Scale check against ratified canon: ADR-026 targets **30v30 ≈ 60 units** and MEASURES ~19 fps at 36 men
(`ADR-026:12, :76`); PERF_LEDGER W0 shows a 38–40 ms AI wall at 65 units — already 2.3× over a 16.6 ms
physics tick. d50 (50) + garrison (24, `site_planner.gd:726`) + squad (~6) = **80+ units, a third past the
documented target, at the one moment the frame is also paying mortar impacts, destruction and flares.**
Consequences §1 ("the most expensive combat event in the game") understates this by a wide margin.

**And §7 is an attack on §2.** Contract 2 forces materialization under `IllumFlare.is_lit`. §7 hands the
player a mortar illum round explicitly sized "higher, wider, longer" than the 30 m hand flare and aims it
at 300–500 m. **The player's strategic verb is a button that materializes the assault all at once.** That
is either the best-timed frame spike in the game or a mandatory interaction between the two sections that
neither one mentions.

**Unhandled case:** the player is 2 km out on patrol when the siege fires (§1 explicitly removes the
`patrol_out` gate, but only reasons about the player being *home*). Either the cells never materialize —
and 24 garrison civilians-turned-defenders fight nobody — or they materialize at full cost with zero
visual payoff. The ADR must pick, and if the answer is "resolve abstractly," that is a second combat
resolver and the divergent-systems law applies.

### 2.2 THE REAP (§5) — step 1 destroys step 2. Traced.

**Step 2 is correct, and I want that on the record.** `enemy_base.gd:1317-1319` places the
`assault_objective` override in `_execute`, *above* `match current_state`. Goal scoring runs in `_think`
and cannot reach the legs. A driven man's movement is `_execute_assault` → `_move_toward(assault_objective,
delta, 1.15)` (`:1370-1371`) and nothing else. **Goal scoring does NOT override it.** §5's central
mechanical claim survives.

**Step 1 does not survive.** `SapperCharge._detonate` (`sapper_charge.gd:60-72`) does three things the ADR
does not account for:

1. `enemy.assault_objective = Vector3.ZERO` (`:69`) — **the detonation CANCELS the rally drive.** The man
   drops straight back into the FSM at `AlertTier.ALERT` (pinned there by `enemy_base.gd:902`), where
   `_execute_alert` follows `EnemySquad.hunt_point` — whose anchor slides **toward and past `fsb_center`**
   (`enemy_squad.gd:332-341`). **A "withdrawing" sapper whose charge goes off turns around and walks back
   into the firebase.** That is the ghost the REAP exists to prevent, re-created by the REAP's own step 1.
2. `enemy.take_damage(9999, …, enemy)` (`:70`) — **the satchel kills its carrier.** There is no
   "withdrawing sapper who detonates on the way out"; there is a suicide charge. §5 step 1 describes a
   survivor the code does not produce.
3. `on_firebase_breach(pos)` (`:66-68`) — **the depot is lost.** So a siege that has ALREADY BROKEN can
   still take the depot on the way out. §4 sells objective loss as the consequence of being overrun;
   this makes it a consequence of *winning*.

And the geometry of the stated benefit is backwards regardless: `_physics_process` fires the charge when
the sapper is within `DETONATE_RANGE` of `target_pos` (`sapper_charge.gd:50-51`). A man ordered to a rally
**350 m in the opposite direction** is moving *away* from `target_pos` from frame one. "Detonates on the
way out" happens only for a sapper who was already on top of his aim point when the break fired.

**Step 2 also cannot walk 350 m.** `_move_toward` uses navigation **only when both endpoints sit inside the
same baked `NavBaker` box** (`enemy_base.gd:~1345-1355`: `use_nav = WorldConfig.NAV_ENABLED and _nav_box >= 0
and NavBaker.box_contains(_nav_box, pos)`). A rally 350 m outside the firebase box fails that test →
**direct steering, no path, for 350 m.** And because `assault_objective` short-circuits the FSM, the man
does not get `_execute_retreating`'s wall-slide either (`enemy_base.gd:1665-1674`) — that is the one piece
of obstacle handling in the retreat path and the REAP routes around it. He will jam on the berm, a bunker,
or the treeline, at 1.15× speed, at full body cost.

**Conclusion: only step 3 (the 90 s / 600 m despawn) actually works.** It is doing all the load-bearing
work while steps 1 and 2 are decoration that, as written, actively fights it. Required amendments:
(a) set `assault_objective` **after** disarming, and make disarm mean `_armed = false` + `set_physics_process(false)`,
never `_detonate()`; (b) either give the withdrawal a nav-legal rally *inside* a baked box or drop the
rally and reap on timer + distance alone; (c) gate `on_firebase_breach` on the siege not being broken.

### 2.3 §2 contract 3 vs §5 — the contradiction is REAL, and worse than suspected

`_strength(id)` (`enemy_squad.gd:115-136`) does exactly what was suspected and one thing more:

```gdscript
for n: Node in tree.get_nodes_in_group("enemies"):
    if e != null and e.squad_id == id and not e.is_dead():
        live += 1
var peak: int = maxi(int(s.get("peak", 0)), live)
```

- `live` counts **live nodes in the `enemies` group.** A dormant cell has none.
- `peak` is a **running maximum of observed simultaneous live nodes** — it is *not* the roll, and there is
  no way to seed it. It can only ever learn the largest number of bodies that were on the field at once.
- Therefore a **dormant cell reads `live = 0, peak = 0` → `ratio = 0/maxi(1,0) = 0.0` → `broken = true`.**
  **`EnemySquad.is_broken(cell_id)` returns TRUE for a cell that has not yet fought.** Any consumer of
  `is_broken`/`strength_ratio` on a cell id — and `EnemyBase` already consults squad strength — reads a
  full-strength dormant cell as combat-ineffective.
- And the §2 contract-3 failure is exactly as the ADR fears, but through `peak`, not `live`: with 15 men
  ever simultaneously real, `peak` latches 15; kill 8 and `ratio = 7/15 = 0.47 < 0.575` → **the 43-man siege
  breaks on its first echelon.** The ADR names the failure and then names a function that causes it.

**The 0.575 threshold cannot come out of the function §5 names as "the single authority."**
`break_state(live, peak, avg_courage)` has **no threshold parameter**. Its threshold is
`clampf(0.45 + (0.5 - avg_courage) * 0.4, 0.20, 0.65)`. Solving for 0.575 gives **`avg_courage = 0.1875`** —
i.e. the only way to get the siege threshold through the shipped signature is to **lie about the courage of
NVA regulars**, which then also corrupts every other consumer of courage. Getting 0.575 honestly requires
adding an override parameter to a static function used by both sides — a global API change, which is the
precise thing §5 says it is avoiding by not moving `BREAK_RATIO`.

**So §5's "the mechanism already exists" is FALSE.** What exists is `ratio < threshold` arithmetic. What
does not exist and is not specified anywhere in the ADR:
- an owner for the assault-scope ledger,
- a `peak` seeded from the d50 roll rather than observed,
- a `live` that sums *dormant cell strength integers + materialized node count*,
- the decrement path (`_on_enemy_died` at `field_director.gd:63` fires per node; a cell wiped while dormant
  never emits `died` at all),
- a threshold override in `break_state`.

That is a **new bookkeeping system** — modest, but real, and it must be scoped and named in §5 instead of
being hidden behind "no second morale system is built." The honest sentence is: *the break FORMULA is
reused; the strength LEDGER is new.*

### 2.4 Is `break_state` reusable at two scopes? — Yes, but `_strength` is not, and the ADR conflates them

`break_state` is genuinely pure and genuinely reusable — feed it any `(live, peak, courage)` and it
answers. That part of §5 is fine.

The lie is by association. The ADR cites `enemy_squad.gd:109-112` and calls it "the mechanism," which a
reader will implement as `EnemySquad.is_broken(id)` — and `is_broken` (`:147-149`) goes through
`_strength` → `_s(id)`, a static, **squad-id-keyed, 1 s-TTL, group-scanning** cache that:
- cannot be addressed by an "assault" id that owns no nodes (it returns live = 0 → broken),
- silently latches `peak` from observation,
- is shared global state, so a siege id and a cell id are entries in the same dictionary with the same TTL.

**Amendment required:** §5 must say explicitly *"call the pure `break_state` directly with the siege's own
counts; do NOT call `is_broken`/`strength_ratio`/`_strength` at assault scope, and do not call them on a
dormant cell."* Without that sentence the next agent will call `is_broken` — it is the obvious API — and get
a siege that is broken before it starts.

### 2.5 The gate is not verifiable per ADR-015

ADR-015 law 3(b) requires **"a gating FPS number — a measured baseline below which the suite fails."**
ADR-035's gate says:

> "worst single-frame spike with a materialized assault at the high end of d50, plus mortar impacts and
> destruction, on the ADR-026 floor."

There is **no number, no pass/fail predicate, and no named probe.** "The ADR-026 floor" is not a defined
quantity — ADR-026 carries a measured *baseline* (~19 fps 18v18, `:12`), a hard **draw-distance** floor
(`:53`), and ratification *targets*, but no frame-time floor a probe could assert. As written, the gate is
a **measurement obligation, not a gate**: it can be discharged by running the arena and writing a number in
the ledger, whatever the number is. That is precisely the "mitigated / investigated" failure ADR-015 law 2
outlaws.

It is also self-undermining: the gate says "before **the roll is uncapped**," which presupposes an interim
cap the ADR never states. Name it — e.g. "d50 is clamped to N attackers until the perf proof lands."

**Amendments:** (a) a frame-time predicate ("no physics frame > X ms and no rendered frame > Y ms during a
60 s peak-materialization sample"); (b) a named probe scene and the harness caveat already correctly noted
(ADR-028 Phase 3: arena tuning must be re-confirmed in the real world build); (c) the interim d50 clamp.

By contrast the **REAP gate is good** — "no siege ships before THE REAP exists and is probed" is a real,
binary, blocking condition. Keep it, and add "…and the probe asserts zero surviving attacker nodes 120 s
after break," which is checkable.

### 2.6 Things the ADR treats as cheap that are not

1. **"No second morale system is built" (§5)** — false as shown in 2.3. New ledger, new owner, new
   `break_state` parameter.
2. **"Objectives register on the existing blast bus … No new damage authority" (§4)** — the *bus* is free
   and the claim about `AgentRegistry.props` / `take_damage` is correct. The **consequences are not.**
   "Commo bunker → no fire missions, no net, no radio VO" needs a consumer in `_grant_fire_support`
   (`field_director.gd:957`), in `_radio_check`, and in the VO path. "MG bunkers → that sector of wire
   opens" needs a sector concept that does not exist. "Depot → a set of destructible objectives" needs
   `_firebase_breached` (`:805`) unlatched, `on_firebase_breach` (`:1085`) made re-entrant, and
   `depot_loss`'s existing Dictionary schema extended and migrated (`campaign_state.gd:53`). Four
   subsystems, not a registration.
3. **"340 markers … the firebase export already carries the anchors" (§4)** — the count is right
   (`firebase_interior_wiring.md:188`) but a marker is a transform, not an objective. The four wiring gaps
   that make those markers inert are known and unlisted here.
4. **Mortar illum "missing only the wiring" (§7)** — this one **checks out.** `_fire_shell(shell_path,
   impact, terminal: Callable)` (`field_director.gd:648`) already takes a terminal callback; `fire_support`
   at `:255` genuinely has no `illum`/`wp` key; the grant is `:957`; the input block is `:180-195`. Cheapest
   real item in the ADR. Fix only the two wrong `m79.tres` line numbers.
5. **Stand-down (§8)** — correctly identified as mandatory and correctly evidenced
   (`garrison_defender.gd:42-48` really does `queue_free` the Civilian). But "revert to Civilians at their
   posts" is a **respawn of a destroyed node with restored occupation, work point, actor unit and schedule** —
   the promote path snapshots all four (`:36-39`) precisely because they cannot be recovered otherwise.
   That is a new inverse-of-promote function plus save serialization of who is dead. Not a dawn callback.

### 2.7 Two smaller corrections the drift law requires

- **The §"Live defects" justification for `enemy_base.gd:1042-1045` is causally wrong.** The ADR says
  *"`target == null` is the NORMAL state of a man approaching in the dark who has acquired nobody."* But the
  runaway is at `:1131`, which requires **`last_known_target_pos != Vector3.ZERO`**. A man who has acquired
  nobody has `last_known_target_pos == Vector3.ZERO` and never takes that branch. The bug bites men who
  **acquired and then lost** — `target_last_seen_time` is zeroed at `:1059` on the last good LOS and then
  frozen forever because `:1061` is unreachable with a null target. The defect is real; the stated cause is
  not, and a fix aimed at the stated cause will miss.
- **§7's OmniLight waiver is an unrecorded amendment to a RATIFIED ADR.** ADR-026 Part A rule 1 is binding:
  *"Hard cap: ≤8 simultaneous real-time lights on screen, 0 shadow-casting dynamic lights."* §10 is
  scrupulous about labelling a damage change "an amendment to ADR-016"; §7 waives an ADR-026 hard cap in one
  sentence, and **ADR-026 is not even in the Related list.** The Summoner's ruling stands; the bookkeeping
  must match §10's own standard, or the next reader finds two live contradictory light budgets — a fossil in
  canon rather than code.

### 2.8 Where the ADR is strongest — do not lose these in revision

The withdrawal/despawn finding (§5) is correct in every particular and is the most valuable thing in the
document. `_execute_retreating` really has no destination, no stop distance, no timeout and no map clamp;
`EnemyBase` really has no despawn path; `enemy_base.gd:902` really pins ALERT forever and really holds
`_body_gate_open()` open at `:534-536`. The three live defects under the drift law — the `patrol_out` crisis
banking a `firebase_attack` patrol location *before* the guard (`field_director.gd:1009` vs `:1010`), the
unbanked-kill scoring asymmetry (`:941-943` vs `:44`), and the unserialized `sim_day` (`campaign_state.gd:208-229`)
plus `save_data.gd:15-17`'s empty mission section — are all real, all correctly pointed, and all worth the
ADR on their own. The fossil-law list is specific and the `test_sapper_assault.gd:198-199` call-out is exact.

---

## VERDICT

**SEND BACK — one revision pass, then RATIFY.**

Not because the design is wrong. The pillars are served, the withdrawal finding is excellent, and the
pointer discipline is better than most documents in this repo. It goes back because **three of its load-
bearing engineering claims are false against the code it cites**, and an ADR is the artifact the next agent
builds from without re-reading source:

1. §5's REAP step 1 **cancels** step 2 (`sapper_charge.gd:69`), kills the man it calls a survivor (`:70`),
   and loses the depot for a siege that already broke (`:66-68`).
2. §5's "the mechanism already exists" is false: `_strength`/`peak` (`enemy_squad.gd:115-136`) makes a
   dormant cell read `broken = true`, latches `peak` from observation, and cannot express 0.575 without
   either a new parameter or a falsified courage value.
3. §2 contract 1's inequality is false at DUSK and false under the flare that §7 makes a core verb —
   and it is built on a number that is not on the line cited.

Fix those three, replace the "diegetic ceiling" with a number, give the perf gate an ADR-015 predicate,
correct the eight pointers in 1.1, and label the ADR-026 light waiver as the amendment it is. Nothing here
requires re-opening a single Summoner ruling.
