# DEVIL'S ADVOCATE — Playtest bundle (7 items), 2026-07-19

Read: `briefing.md`, `2026-07-19_playtest_polish/synthesis.md`, ADR-029, ADR-015, ADR-023.
Everything below is measured in the code, not inferred from the briefing.

---

## 0. THE HEADLINE — I FOUND THE THIRD COLLAPSED PREMISE

The briefing collapsed items 1 and 3. **Item 3's replacement diagnosis is ALSO wrong**, and its
proposed lever cannot work on the units the owner complained about.

Briefing line 82: *"`CampDirector` writes `work_pos` (`camp_director.gd:85-120`), but patrol/sleep/
guard roles get `work_pos = Vector3.ZERO` (:100-101) so those men never walk."*

**That describes garrisons that HAVE a CampDirector. Village and camp garrisons do not have one.**

- `mission_generator.gd:260-268` — `_attach_camp_directors` iterates **`director._live_enemies`**.
- It is called at `mission_generator.gd:205`, inside `build_patrol_world`, at **world-build time**.
- Village defenders are `"lazy": villages[vi] != nearest` (`:538`) and **every** camp garrison is
  `"lazy": true` (`:542`). `_spawn_enemy_groups` (`:648-655`) turns those into `LazyGroup` nodes that
  spawn **on player proximity at runtime** — long after `_attach_camp_directors` has finished.
- `grep CampDirector scripts/` returns hits in `mission_generator.gd` and `ambush_planner.gd` only.
  **Nothing re-attaches a director when a LazyGroup fires.**

**Consequence:** exactly ONE village in the AO (the one nearest the gate) has a garrison with a
CampDirector, work stations, camp roles, and a generated patrol route (`:298-305`). **Every other
village and EVERY camp garrison spawns with `camp_role` unset, `work_pos = ZERO`, no work stations,
and no patrol route — forever.** They stand in a spawn ring facing outward (`lazy_group.gd:84-89`)
until they die.

The briefing's cause #2 ("garrisons spawn as SENTRIES by construction") is right about the symptom
and wrong about the mechanism, and the mechanism is what determines the fix. **The one-line
`work_pos` fix the briefing implies is a no-op for the affected units, because there is no
CampDirector to write `work_pos` in the first place.** A council that orders "give guard roles a
work_pos" will ship a change, pass a probe on the nearest village, and change nothing the owner saw.

Two more, free:
- `LazyGroup` never reads `group.spread`. `_spawn_enemy_groups:650-653` sets `enemy_count`,
  `group_tag`, `setup()` and position — the authored `spread: 20.0` (village) / `14.0` (camp) is
  **dropped on the floor**; every lazy group uses the `@export` default `12.0` (`lazy_group.gd:9`).
  Villages therefore spawn defenders in a 12m huddle instead of a 20m ring. That is a visible
  "clustered dudes standing in a clump" defect, and it is one line.
- **Nothing ever despawns a LazyGroup.** `_spawned` is never reset; `set_physics_process(false)`
  at `:90` is one-way. Every man the player has ever walked within 120m of stays in the world for
  the rest of the patrol. This is load-bearing for §5 (perf).

---

## 1. THE COLLAPSED PREMISES — is the new diagnosis SUFFICIENT?

### Item 1 — "I have NEVER been able to test fire missions"

The briefing's new cause (`fire_support` never assigned; 5 of 6 verbs read NONE AVAILABLE) is
**real but NOT sufficient**. It explains a bad menu. It does not explain *never*.

He still had **mortar x2 on key 4** (`field_director.gd:194`). If he had opened the net and pressed
4 with a ground target, a mission would have flown. "Never" means he never got a round out. So at
least one of the following is also true, and **the council must not close item 1 without ruling on
which**:

**(a) He does not know the verb exists.** This is the strongest hypothesis and it is an **r4bk-law
violation** (a feature with no affordance does not exist — ADR-023 line 98).
`mission_hud.gd:81-109` builds `_fire_panel` **lazily, inside `_on_fire_menu_changed`**. Before the
first T press there is no fire-support pixel on screen anywhere. Nothing in the compass strip
(`:40-47`), the squad strip (`:179-212`), the slot slider (`:117-149`) or the toasts mentions the
radio. `PLAYER_MANUAL.md:22` documents `T / Y`, but that manual **describes a game that no longer
exists** — `:6` "pick your op, fly in, do the work, get to the bird", `:70-75` briefings and exfil
birds, all deleted by ADR-029. A player reading it and finding the briefing gone has every reason to
assume the radio went with it.

**(b) The RTO leash.** `_radio_check` (`field_director.gd:294-301`) requires a living RTO within
`RTO_RADIO_RANGE = 10.0`. The **out-of-scope** squadmate-glue bead (akx8/WA) is the confounder here:
if squadmates lag, drift, or route around terrain on the way to a village, the player standing at
the treeline is >10m from his RTO and gets `TOO FAR FROM THE RADIO`. That toast is a **3.5-second
fade** (`mission_hud.gd:219-221`) and the net closes (`:207`). A player who pressed T twice, saw a
sentence vanish, and gave up would report exactly "I have never been able to use it."

**(c) `_cas_ground_target()` returns ZERO** → `NO TARGET - AIM AT THE GROUND` (`:216-218`). Unaudited
in the briefing. If it raycasts to a ground layer and the player is aiming at jungle canopy, foliage
cards, or sky, every press fails silently-ish. **This must be read before item 1 is called closed.**

**(d) The keycode collision is worse than "secondary".** `cbu_strike` and `place_claymore` both bind
physical keycode 54 (`project.godot:146-149` vs `:191-194`). Godot delivers the event to **both**
actions. `field_director._process:180` fires `request_fire_support("cbu")` on that key. So pressing
the claymore key while the net is open burns a CBU attempt AND plants a claymore, or vice versa.

**What distinguishes them:** instrument the failure. Every early-return in `request_fire_support`
(`:206-219`) already emits a distinct toast. Add a one-line counter per rejection reason to the
director and read it after a playtest. That is the honest way to find out which sentence he saw —
and it is cheaper than guessing.

**VERDICT ON ITEM 1: injecting budgets is necessary and NOT sufficient. Shipping only the budget
injection and closing the bead is the single most likely way this bundle ships something false.**

### Item 3 — "enemies stand around instead of patrolling"

Two owner sentences are being conflated:

1. *"enemies stand around instead of patrolling"* — units he can SEE. Beyond 150m
   (`PERCEIVE_RANGE`) they are unlit dots; beyond the LazyGroup range (120/140m) **they do not
   exist**. He cannot have been describing 200m units, because at 200m there is nothing rendered to
   describe. **He is describing the village/camp he walked into.** That is §0's no-CampDirector bug.
2. *"even when we shot the other vc they just kinda stood around"* — this is a **COMBAT REACTION**
   report and it is item 4's territory, but item 4 as scoped (a flinch pose) does not address it.

**The LazyGroup/activation_range theory does not match either sentence.** Raising
`activation_range` is the briefing's own named expensive lever (§5), and it would fix a complaint the
owner did not make. **Flag: if the decree raises `activation_range`, it is paying the highest perf
price in the bundle to solve a hypothetical.**

On sentence 2, the code offers a specific, un-recon'd suspect: **`_body_gate_open()`
(`enemy_base.gd:523-538`) uses `CombatManager.perceivable()`, and `perceivable()` is a FRUSTUM test,
not a distance test** (`combat_manager.gd:45-58`): past `PERCEIVE_NEAR = 20.0` it requires
`(-eye.basis.z).dot(to_actor) > 0.0` — **anything behind the camera is not perceivable**. A man
21m away, behind the player, who is stationary and below COMBAT tier, gets his pose refreshed on a
300ms heartbeat. Turn around fast and you see a snapped-into-place statue. Combined with the
`velocity > 0.01` re-open (`:528`), the visible artifact is *pop, freeze, pop*. That reads as
"standing around" and it is a **rendering** defect, not a behavior defect. **No item in this bundle
addresses it.**

**VERDICT ON ITEM 3: the diagnosis in the briefing would have us fix the wrong units with the most
expensive available lever. Fix §0 (attach CampDirectors to lazy garrisons) and leave
`activation_range` alone.**

---

## 2. SCOPE CREEP — which of the seven cannot honestly finish

**Item 2 (completion verb) — MULTI-SESSION EPIC IN A SMALL HAT. Do not attempt this session.**
It requires, in order: (i) a demo-charge *item* — `demolitions` (`skill_catalog.gd:10`) is a
purchasable levelled skill backing **zero code**; (ii) an inventory slot — the slot slider is
hard-coded to exactly four entries (`mission_hud.gd:128-134`, `range(4)`); (iii) a hold-to-act
charge verb; (iv) a HUD prompt that does not exist; (v) a resolution of the ADR-029 conflict (§3);
(vi) a destruction/collapse state on `TunnelRoom` that survives re-entry
(`player.gd:238-247` calls `TunnelRoom.get_or_create`, which would happily re-create a collapsed
tunnel). And (vii) an **input collision**: F is a single priority-ordered scan
(`player.gd:211-260`) where "tunnel entrance within 3.0m" already wins. A plant verb at the same
position on the same key is the keycode-54 bug again, in a different costume.
That is five to seven systems. It is not an item; it is an epic.

**Item 4 (flinch) — a slice of an epic whose amendments are UNRATIFIED.** The briefing itself
(`:106`) forbids opening barks/tracers/QRF because those amendments are pending. Fine. But note the
honest scope of the "procedural spine-punch": a `SkeletonModifier3D` per unit, and
`sprite_state_map.gd:138` already maps `"flinch"` → `rifle_aiming_idle` with **nothing emitting the
intent**, so the intent-emit path must also be built or the dead dict entry deleted (ADR-023).
Deliverable this session: *either* the modifier *or* the intent wiring, honestly probed. Not both,
and not "death theater" — `_die()` (`:2344, 2383-2398`) with its binary left/right test is a
separate piece of work and `death_from_the_left` **does not exist as an asset**
(`ANIM_WISHLIST.md:12`). **Any decree language containing "death theater" is ordering art that has
not been authored.**

**Item 5 (traps) — this morning's council deferred it UNANIMOUSLY and its reasoning still holds.**
`punji_trap.gd` is 68 lines of `Node3D` with no Area3D, no collision, no health, no `take_damage`
(`:1-67`). Making it destructible = a body + a health field + a fourth damage-receiver registry in
`apply_explosion_damage` (`combat_manager.gd:138-220` iterates exactly four hardcoded registries).
The morning council called that "a feature, not polish." **It was RIGHT, and today's decree has
not produced a new fact that changes it — only a new instruction.** The Summoner may of course
override; that is Law 3. But the record should say plainly: *the deferral was correct on the merits;
it was overturned by preference, not by evidence.*

**Honestly finishable this session: 1 (budget injection + affordance), 3 (CampDirector attach + the
`spread` one-liner), 6 (informer LOS), 7 (nameplate projection).**
**Not honestly finishable: 2 (epic), 5 (feature).** **Half-finishable: 4 (pick one half).**

---

## 3. THE CANON CONFLICT ON ITEM 2 — I will not paper over it

**The decree as written orders a pillar violation.** ADR-029 §4 is not ambiguous: *"No player-facing
mission tracking, ever… Objective tracking dies… Floating objective markers are forbidden."* Its
code is LIVE — `mission_hud.gd:251-253` and `_update_markers` (`:254-283`) implement exactly that
deletion, and the surviving squadmate markers carry a comment explicitly distinguishing themselves
from mission tracking. Wiring the tunnel into `MissionState.register_objective` /
`complete_objective` (`mission_state.gd:21-35`) re-animates the system ADR-029 condemned.

**Is there a reading where both hold?** Yes, exactly one, and it is narrow:

`MissionState` is **also** the debrief/AAR ledger — `kills`, `contacts_detected`,
`contacts_avoided`, `flags`, `build_result` (`:58-115`). ADR-029 §7 keeps that ("MissionDirector
survives headless as FieldDirector — toast bus, fire support, escalation, flags") and only kills
**objective tracking**. So: **recording that a tunnel was destroyed as an AAR line item is legal.
Registering it as an objective with a required_mask the player can see a counter for is not.**

The distinguishing test is mechanical and I would make it the probe:
> **`objective_titles` must stay empty in a patrol world, and `is_exfil_unlocked()` must never gate
> anything.** If the tunnel write goes through `flags` / a kill-count-shaped accumulator, ADR-029
> holds. If it goes through `register_objective`, ADR-029 is violated.

**If the Summoner wants a legible "the area is finished" signal, the honest route is diegetic** —
one toast at the moment of the blast, and world state (the hole is gone, the garrison is dead). That
is what ADR-029 §4 already permits. It costs him a persistent counter he can check; that is the
sacrifice, and it is the sacrifice ADR-029 was written to make.

**The framing for the Summoner, without softening:** you can have a completion *tracker*, or you can
have ADR-029. Not both. The tracker means the pivot you ordered on 2026-07-17 — *"an open simulator
with no mission tracking that the player needs to worry about"* — is partially rescinded, and
ADR-029 must be amended in writing before the code lands (ADR-015 §3: canon is amended by explicit
decision, never silently). **Building it first and amending later is precisely the drift ADR-015
exists to prevent.**

---

## 4. PROBE HONESTY — the dishonest probe for each item

ADR-015 §2: no close without a probe. Here is the probe that PASSES WITHOUT THE FEATURE WORKING, per
item. Every one of these is a probe I would expect a hurried agent to write.

| # | The dishonest probe | Why it passes falsely | The honest probe |
|---|---|---|---|
| 1 | `assert(director.fire_support["arty"] > 0)` | Asserts a dictionary literal was assigned. Proves nothing about a round leaving a tube. | Drive `request_fire_support("arty")` with a mocked RTO at 5m and a valid ground target; assert the budget **decremented** and a strike node entered the tree. Negative control: RTO at 11m must emit the leash toast and NOT decrement. |
| 1b | (no probe at all for the affordance) | The r4bk failure is invisible to headless probes by construction. | Assert `_fire_panel` exists and is reachable **before** any T press, or assert a persistent HUD element names the radio. If you cannot, **report item 1 as PARTIALLY UNVERIFIED** — do not claim the affordance. |
| 2 | `assert(state.is_objective_complete(0))` | Tests `mission_state.gd:38-39`, a pure bitmask, which `tests/test_mission_state.gd` **already** tests. It proves the bitmask works — which was never in doubt — not that a tunnel was destroyed. | Assert the tunnel node is gone from `tunnel_entrances` AND `TunnelRoom.get_or_create` does not resurrect it AND `objective_titles.is_empty()` (the ADR-029 guard from §3). |
| 3 | `assert(enemy.work_pos != Vector3.ZERO)` | **The type specimen.** `_execute_idle` (`enemy_base.gd:1353-1356`) only moves while `distance_to(work_pos) > 1.6`. A man assigned a work_pos 1m away never takes a step, and this probe is green. Worse — per §0 the units in question have no CampDirector, so a probe run against the *nearest* village (the only non-lazy one) passes while every lazy garrison stays frozen. | Force-spawn a **lazy** garrison, sample `global_position` at t=0 and t=20s, assert net displacement > 5m for ≥50% of the garrison. Negative control: revert the CampDirector attach → displacement 0. |
| 4 | `assert(sprite_state_map.has("flinch"))` | `sprite_state_map.gd:138` **already** has it. The dict entry is the fossil, not the feature. | Assert the intent is *emitted*: hit a unit non-fatally, assert the actor received a `"flinch"` intent (or that the modifier's influence became non-zero) within N frames. Negative control: revert → zero emissions. |
| 5 | `assert(trap.has_method("take_damage"))` | Method presence is not routing. This is **the exact failure mode this morning's council found in `civilian.gd`** — `has_method()` checked the name while the arity was wrong and there were zero callers. | Call `CombatManager.apply_explosion_damage` at the trap's position and assert the trap is `queue_free`d. Negative control: blast 30m away → trap survives. |
| 6 | `assert(civ._inform_timer > 0)` after moving the player within 15m | Reproduces today's bug (`civilian.gd:159-165` starts the clock on distance alone). | Place a wall between civilian and player, assert the clock does **not** start; remove wall, assert it does. AND assert something **reads** `informer_transformed` — today nothing does (`civilian.gd:312-330` writes a flag into write-only debrief data; the comment claiming a handler reads it is an ADR-015 §3 **truth-law violation** that must be deleted or made true in this change). |
| 7 | `assert(nameplate._target == ally)` or `assert(label.text.contains("RTO"))` | **Both are true TODAY, with the bug.** `squad_nameplate.gd:51-64` already finds the target and already writes the text — the defect is purely `position`. A probe on target-acquisition or text content passes against the broken build. | Place the camera, assert `label.global_position` is within N px of `cam.unproject_position(ally_head)`, and assert it **moves** when the ally moves. Negative control: restore `set_anchors_preset(PRESET_CENTER)` alone → the label sits at the origin and the assert fails. |

**The general law this table teaches:** for items 4 and 7 especially, *the state the naive probe
asserts is already correct in the broken build.* If a probe cannot be shown to go red on revert, it
is not a probe — it is a comment with a `passed` counter.

---

## 5. PERF — stacked, this bundle is not affordable as scoped

Baseline (`PERF_LEDGER.md:265-284`, 65-67 live units): think 1.2-1.28ms (~3%), `move_and_slide`
8.8-9.1ms (~23%), hitzone sync 9.9-10.4ms (~26%), anim/execute 17.6-19.0ms (~48%). **Body ≈ 95-97%.**
Game measured ~28.8fps against a **30fps gate (ADR-015 §3b)**. *We are already below the gate.*

Per item:

- **Item 3 — the real bill, and it is CUMULATIVE.** Every man made to move self-opens the body gate
  (`enemy_base.gd:528`) and buys `move_and_slide` + hitzone sync ≈ **135µs + 160µs ≈ 295µs/frame**,
  *permanently* — because **nothing despawns a LazyGroup** (§0). Walk past 4 villages and 3 camps
  and you have ~35 extra permanently-hot bodies ≈ **10.3ms/frame added**, on a frame that is already
  ~34.7ms. That is not a concession; that is roughly halving the framerate over the course of one
  patrol. **The briefing's "moving men need no perf concession at all" (line 80-81) is FALSE — it is
  true per-frame-of-motion and false in aggregate, because motion here is permanent.**
  Mitigation the decree must specify or the item must not ship: a duty cycle (walk 8s, stand 20s),
  or a hard cap on simultaneously-walking garrison men (the ADR-026 hot-set pattern applied to
  idlers), or a LazyGroup **de**activation at 1.5× activation_range.
- **Item 4 — a `SkeletonModifier3D` per unit** runs inside the skeleton update, i.e. inside the 48%
  anim/execute block, and `hitzone_builder.gd:160-166` connects `sync()` to `skeleton_updated`, so a
  modifier that dirties the skeleton **also re-triggers hitzone sync** — the 26% line. Even at 20µs
  per unit that is 1.3ms at 65 units, and it lands on the most expensive block we have.
  **Gate: the modifier must be attached ONLY to units passing `_body_gate_open()`.**
- **Item 5 — one collision body per trap.** Cheap individually. Unbounded in count: nothing in the
  briefing states how many traps a patrol world places. **Get that number before agreeing.**
- **Item 7 — one `unproject_position` per frame for at most one ally.** Negligible. `_find_looked_at`
  (`:76-89`) already iterates the `allies` group **every frame** and already raycasts. No new cost.
- **Item 1, 2, 6 — negligible.**

**RULING I WOULD ENFORCE:** ADR-015 §3b says the suite has a gating FPS number. We are *under* it.
**No item that adds per-frame body cost may ship without a before/after `ps2_perf_probe` number in
the closing comment.** That is items 3 and 4. If the number goes down, the item does not close —
ADR-015 §2 forbids "mitigated" and "likely fixed" as closing words.

---

## 6. WHAT BREAKS — regression risk per item

| # | Regression risk | Probe that catches it |
|---|---|---|
| 1 | Injecting budgets makes CAS/napalm/arty/spooky/CBU available in an **open patrol sim with no briefing** — the thing that used to justify a budget is deleted. A patrol that can call a B-52 is not a recon patrol (Pillar 1/3). Also: `_danger_close_to_squad` (`field_director.gd:320-328`) **never checks the PLAYER's own position** (known ADR-011 gap) — hand the player napalm and he will kill himself with no confirm prompt. | `test_cas_sim`. **No probe covers the player-danger-close hole.** I would make fixing `_danger_close_to_squad` a hard prerequisite of granting any air asset. |
| 2 | `MissionState` resurrection contradicts ADR-029; `TunnelRoom.get_or_create` re-creates destroyed tunnels; F-key priority collision starves "enter tunnel". | `test_mission_state` (will **pass** — that is the problem, see §4), `test_fossils` (wiring a dead function *shrinks* the register, so it goes green and gives false comfort). |
| 3 | Walking garrisons wander out of their site, break `ambush_planner` assumptions (`ambush_planner.gd:23-44` reads `camp.garrison`), and self-open the body gate en masse. Patrol routes crossing un-navmeshed ground → `_update_unstick` churn. | `test_body_gate` (contract: only the BODY sleeps — a change that pins bodies hot **violates its spirit while passing its letter**, since it only asserts brains keep ticking). `test_activity_tiering`, `test_arena_patrol`, `test_think_budget`. |
| 4 | A stagger/flinch that interrupts firing lengthens firefights and softens lethality — the exact aggression-killer the 2026-07-16 council killed at suppression 0.35. `apply_stagger` already forces SUPPRESSED crouch (`enemy_base.gd:2163-2167, 2279`); stacking a pose on top compounds it. | `test_firefight_len`, `test_ai_fairness`, `test_low_posture`, `test_flat_damage`. **`test_firefight_len` is the one that matters — if median firefight length rises, the flinch is a nerf wearing a costume.** |
| 5 | A trap with a collision body becomes a **bullet stopper** and an over-penetration target (`bullet_system.gd:163`) and can block AI navigation. A trap that takes explosion damage will be deleted by the player's own grenades wholesale. | `test_ballistics`, `test_nav_path`. Layer choice must repeat this morning's F1 ruling: a dedicated layer, not a borrowed one. |
| 6 | Adding LOS makes informers **strictly rarer** — a stealth-economy nerf nobody asked for. If the transform never fires, the feature reads as removed. | `test_detection`, `test_witness_rule`, `test_los_determinism`, `test_bt_civilian`. |
| 7 | The nameplate is a **separate node with its own `_process`** (`mission_hud.gd:31`), so it is NOT stripped by HARDCORE mode (`mission_hud.gd:232-237` returns early only for the HUD's own children). Today it is illegible garbage in the corner; fixed, it becomes a **legible world-space tag in HARDCORE**, which strips navigation aids by design. That is a new HARDCORE surface nobody voted on. Also: `_has_los` uses `collision_mask = 1` (world only), so the plate reads **through your own squadmates**. | `test_squad`. No probe covers HARDCORE stripping. **Decide explicitly: does the nameplate survive HARDCORE?** |

---

## 7. RANKING BY RISK OF SHIPPING SOMETHING FALSE

Ordered most-dangerous first. "False" = the bead closes, the probe is green, and the owner's
experience is unchanged.

1. **Item 3 — patrols.** Highest risk in the bundle. The briefing's mechanism is wrong (§0), the
   naive probe is green against the broken build (§4), the expensive lever solves a complaint he
   did not make, and the cheap lever's cost is unbounded and permanent (§5). This is the item most
   likely to consume the session and change nothing on screen.
2. **Item 1 — fire missions.** The new diagnosis is real but incomplete. Injecting budgets and
   closing is a textbook ADR-015 §2 violation — a bead recorded as done on work that does not
   deliver the reported outcome. The r4bk affordance gap is probably the actual cause and is the
   part headless probes cannot see.
3. **Item 4 — flinch.** The dict entry already exists, so the naive probe passes today; and the
   feature's real risk (longer, softer firefights) is invisible unless `test_firefight_len` is run
   before/after. Art debt (`death_from_the_left` does not exist) invites a "placeholder" that
   becomes permanent — the exact failure this morning's F3 named.
4. **Item 2 — completion verb.** Least likely to ship *falsely* (it will visibly not exist), most
   likely to ship as a **canon violation** or to swallow the session. Its risk is scope + pillar,
   not falsity.
5. **Item 5 — traps.** Moderate. `has_method` probes are the known trap and this morning's council
   already got burned by exactly that pattern in `civilian.gd`.
6. **Item 7 — nameplate.** Low risk, root cause genuinely found, negative control is trivial. The
   only live question is HARDCORE.
7. **Item 6 — informer.** Lowest. A one-function LOS insertion against a canonical helper
   (`CombatManager.has_line_of_sight`) with four existing precedents. **Note it also carries a
   mandatory ADR-015 §3 cleanup: the lying comment at `civilian.gd:312-330` must be deleted or made
   true in the same change.**

---

## 8. VETO FLAGS

**🚩 VETO-FLAG 1 — Item 2 as written orders an ADR-029 violation.** Do not write code against
`MissionState.register_objective` until ADR-029 §4 is amended in writing, or the design is moved to
the diegetic route. ADR-015 §3: canon is amended by explicit decision, never silently. *Build-then-
amend is the drift this project already paid for twice.*

**🚩 VETO-FLAG 2 — no fire-support budget may be granted while `_danger_close_to_squad`
(`field_director.gd:320-328`) ignores the player.** Handing the player napalm and CBU with a
confirm prompt that cannot see him is shipping a way to kill him with no warning. Fix the check or
grant mortar-only.

**🚩 VETO-FLAG 3 — no item that adds permanent per-frame body cost closes without a measured
before/after FPS number.** We are at ~28.8fps against a 30fps gate. Items 3 and 4 both qualify.
ADR-015 §2 forbids closing on "likely fixed."

**🚩 FLAG 4 — item 5's deferral this morning was CORRECT on the merits.** It is being reversed by
preference, not evidence. That is the Summoner's right (Law 3) and it should be recorded as such,
not retconned into a new finding.

---

## 9. WHAT IS SACRIFICED — if the council takes my advice

- **Item 2 does not ship this session.** The owner asked for a legible "the area is finished"
  signal and will not get one. That is a real, felt loss, and it is the cost of not violating the
  pivot he himself ordered 48 hours ago.
- **Item 5 ships thin or not at all**, and punji traps stay indestructible for another session.
- **Item 4 ships as one half** — either the modifier or the intent wiring — and the death theater
  stays as it is.
- **Item 3 fixes garrison behavior but does NOT make distant patrols visible.** Mid-range life at
  200m remains absent. That is deliberate: the body is 95-97% of AI cost and we are under the FPS
  gate. The owner should be told plainly that "life at 200m" is a perf project, not a bug fix.
- **Time is spent on diagnosis (the `_cas_ground_target` read, the rejection counter) that produces
  no visible feature.** That is the price of not closing item 1 on a guess.
