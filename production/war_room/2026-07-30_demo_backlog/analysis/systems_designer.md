# SYSTEMS ARCHITECT — siege doctrine & AI systems

**Convened** 2026-07-30 · assigned items **#1 (C3 the VC overrun push)** and **#4 (A4 off-duty men)**.
Every assertion below carries a `file:line` read at HEAD on 2026-07-30 (POINTER LAW). Where the
briefing and the code disagree, the code wins and the disagreement is named.

---

# PART A — ITEM #1, THE VC OVERRUN PUSH

## A0. RULING IN ONE LINE

**The proposed `press_assault(to, drive_s)` must NOT be built.** It re-implements a bounding-rush
system this codebase already ships (`enemy_base.gd:1572-1643`), it mutes every man it touches, and its
countdown can cancel the ADR-035 reap. **The press belongs in the GOAL SCORER, not in the legs** — one
bool on `CombatGoals.Context` plus one additive term, and `_execute_advancing` (already built, already
fires on the move) does the rushing. **And C3's *breach* is blocked on art, not code** — see A6.

## A1. WHAT THE CORRECT BEHAVIOUR IS — the doctrine, named

The real thing is the PAVN/VC **three-element night attack** on a fortified position, executed under
**`nhất điểm lưỡng diện` — "one point, two sides"**: a single chosen penetration point, with supporting
pressure on the flanks so the defence cannot mass against it.

Three elements, and the order matters:

1. **The breach element — `đặc công` sappers.** Reconnoitred for days. Their job is not killing; it is
   the **obstacle belt**. They crawl the wire in the dark, and open **lanes** with satchel charges and
   bangalore-equivalents. A lane is marked (a stake, a strip of cloth) so the assault behind them can
   find it in the dark.
2. **The support element — mortars, RPG, MG.** It **fixes** the defence: mortars walk onto the interior
   to keep heads down and cut the crews off from their guns, RPG and MG fire directly onto the bunkers
   and towers covering the lane. It fires from OUTSIDE and never enters.
3. **The assault echelon.** It does not exist on the wire until the lane exists. On the signal (whistle,
   bugle, a flare, the breach itself) it goes **through the lane in files, in rushes of 2-5 men**,
   grenades ahead of itself, and **expands laterally along the trench line from inside** — it does not
   spread back out into the open. A follow-on echelon exploits to depth.

**What that must read like to a player standing on the berm.** Not a line of tracers at 80 m for eight
minutes. It reads as, in order: distant tubes, then rounds walking in tighter; a single **flat crack on
the wire** somewhere along one arc; the fire from that arc going *quiet* while the fire either side of
it doubles; whistles; then **men appearing at ONE place, close, in bursts of two and three, throwing
grenades**, while the fire from outside continues over their heads. The player's decision is not aiming
— it is *which way do my five men face* (Pillar 4, ADR-035 §3).

**Two properties of that picture are load-bearing and neither exists today:**
- **it is a LANE, not a perimeter** — the attack must have one place it comes through;
- **the men who rush must still be shooting.** A silent runner is the 2026-07-29 bug
  (`enemy_base.gd:66-72` records it in the source: *"the VC started running at the base and no one
  fought besides me"*).

## A2. WHY THE ASSAULT PARKS AT THE WIRE TODAY — the briefing names the wrong cause

The briefing (§1) attributes the stall to `enemy_base.gd:1305-1313`: the undriven man's objective "is
cleared forever," so he goes to COMBAT and trades shots. **That is true and it is not the cause.**
Clearing the objective hands his legs to the combat brain — and the combat brain *has* a press. It is
never chosen. Measured at source:

- `combat_goals.gd:92-105`, ADVANCE: `advance = aggression * 0.4`, `+0.25` if
  `dist > preferred_range*1.5`, `+0.15` if `threat<0.2 and dist<pref*2`, `+0.2` with covering fire,
  **`*= 0.45` if no covering fire and aggression < 0.7**, `+0.15` at force ratio ≥ 2.
- `nva_regular.tres:16` — `aggression = 0.65`. So the 0.45 penalty applies unless a squadmate is firing.
  At the wire (`dist` is short, `threat` is high in a firefight) the two distance terms are dead.
  **Realistic ceiling: 0.26 + 0.2 + 0.15 = 0.61.**
- `combat_goals.gd:52-64`, ENGAGE: `0.5 + 0.3` (eyes on) `+ 0.15` (has cover) = **0.95**, and
  `pick()` multiplies the incumbent by **1.25** (`:126`) → **1.19**.

**ADVANCE cannot beat ENGAGE at the wire by a factor of ~2. That is the stall, in numbers.** The
objective-clearing at `:1313` merely hands him to a scorer that has already decided he is a defender.

**And the rush is already built.** `_execute_advancing` (`enemy_base.gd:1572-1643`) is a full bounding
overwatch: `_find_bound_point` (`:1773`, ≤12 candidate offsets `:117-121`, throttled to 1 Hz `:1611`),
sprint at 1.3× (`:1601`), arrive → `_bound_pause = randf_range(0.8, 1.6)` (`:1598`), and **it fires on
the move at three separate sites** — `:1586` (at the bound), `:1605` (sprinting), `:1624`/`:1637`
(searching / straight advance). It claims cover points so men do not stack (`:1793`).

**Therefore: building `press_assault` would ship a SECOND bounding system beside a working one — the
exact ADR-023 failure, and the exact "~14 parallel live world-build systems" blindspot.**

## A3. JUDGING THE PROPOSED PRESS DESIGN — five ways it breaks

**(1) It mutes the men it presses. CONFIRMED — the other architect's conclusion is right, his pointer is
wrong.** `_fire_at_target()` has **six** callers, not one: `:1478` (`_execute_combat`), `:1567`
(`_execute_flanking`), `:1586`, `:1605`, `:1624`, `:1637` (all `_execute_advancing`), defined `:1927`.
The conclusion survives intact and is worse for it: `_execute` returns at `:1307`/`:1311` **before the
state dispatch at `:1322`**, so a driven man reaches *none* of the six. He is mute in every state, and
he is mute *because* the override is a leg-theft that bypasses the whole FSM.
**Arithmetic accepted: 0.40 × (4 / 9) ≈ 17.8% of the assault silent on a rolling basis, forever.**
**Verdict: yes — the press is the 2026-07-29 bug on a duty cycle.** It is milder than 100% mute, which
makes it worse, not better: a bug at 18% will not be found in a playtest, it will be *felt* as "the
attack has no weight" and misdiagnosed for a week.

**(2) It has no middle setting. CONFIRMED.** `:1309` gates the undriven march on
`alert_tier != AlertTier.COMBAT`. At the wire every attacker has acquired a defender, so every attacker
is COMBAT. Press-with-`assault_driven=true` therefore always steals from a man who is fighting (mute);
press-that-skips-COMBAT-men has an **empty eligible set exactly at the moment the feature exists for.**
There is no third option *inside the override*, because the override is defined as "the FSM does not
run." The proposal is trapped by its own placement.

**(3) The countdown can cancel the reap — the single biggest risk in the proposal.**
`MarchingCell.withdraw_to` sets `assault_objective = rally` and `assault_driven = true`
(`marching_cell.gd:155-156`) and `SiegeDirector._break_siege` frees the cell immediately after
(`siege_director.gd:355`). A `press_assault` countdown still running on that man fires ~4 s later,
clears `assault_driven` (and, per the design, the objective) — and **the withdrawal is cancelled**. He
is then a routed man with no destination: `_execute_retreating` (`enemy_base.gd:1645`) flees on a bearing
forever, `field_director.gd:902` pins him at ALERT, `_body_gate_open()` (`:534-536`) stays open, and the
reap never collects him because `_process_reap` (`siege_director.gd:382-384`) tests
`m.assault_objective` and distance to it. **That is precisely the permanent full-cost ghost accumulation
ADR-035 §10 gate 1 forbids shipping.** Two owners of one variable with no arbitration is the defect
class; a `_press_target` equality check would patch it, but the right answer is to never take the legs.

**(4) It fights the navmesh, and the navmesh wins.** `NavRouter.step` uses nav only when both endpoints
sit in the same baked box (`nav_router.gd:57-59`). The firebase box is `FSB_HALF = 185.0`
(`nav_baker.gd:46`) — **370 m across**, so a man at the wire and a bound point inside the compound are
both inside it and **nav is always on**. The firebase is the one site baked from its **real `-colonly`
trimeshes** (`nav_baker.gd:33-42`, `_add_colliders:292-317`), so every parapet run *and the wire ring*
are unwalkable geometry in the mesh. A bound aimed inside the wire therefore paths **to the gate** —
the only authored opening. Forty men, one gate, one file. That is not an overrun, it is a queue.

**(5) It does not break `test_ai_fairness.gd`.** Verified: that suite exercises `d_exposure_ramp` /
`AIMarksmanship` (`:33-49`), `_target_score` (`:60-70`), `_evaluate_goals` on a default Context
(`:74-103`) and the grenade broker (`:106-121`). It never touches `_execute`, `assault_objective` or
`assault_driven`. **A press implemented in the goal scorer is also safe** — provided it only *adds* to
ADVANCE. The suite asserts *"fresh contact in the open should SEEK_COVER"* (`:87`) and
*"aggression 0.85 must be doctrine-exempt"* (`:101`). **A press term that suppressed SEEK_COVER would
turn that red, and correctly so.** Bias upward, never suppress.

**Does it break the ADR-035 break/reap ledger?** The break ledger itself: **no.**
`SiegeDirector.live_strength()` sums `MarchingCell.live_strength()` (`marching_cell.gd:55-62`), which
counts dead men, not goals — `run_peak` is fixed at roll time (`siege_director.gd:149`) and
`killed_count()` is `peak - live` (`:224`). Goals and legs are invisible to it. **The reap: yes, see
(3).**

## A4. THE CHEAPEST CORRECT IMPLEMENTATION — the press is a GOAL, with numbers

Three edits, ~20 lines, no new class, no new override, no timer, and it composes with everything
already shipped.

**1. `scripts/ai/combat_goals.gd`.** Add one field to `Context` (default false, so no shipped fight
retunes — the same pattern ADR-035 §4 used for `break_state`'s optional `base_ratio`):

- `var assault_press: bool = false` in the "Doctrine gates" block (`:37-41`).
- In `score()`, at the ADVANCE block (`:92-105`): when `assault_press`, **`advance += 0.75`** and
  **skip the `*= 0.45` unsupported-crossing penalty** (`:101-102`).
- **Why 0.75, derived not guessed:** the incumbent ENGAGE is 1.19 (A2). Pressing NVA regular tops out
  at 0.61. `0.61 + 0.75 = 1.36 > 1.19` — it wins, and once ADVANCE is incumbent the same 1.25
  hysteresis holds it, so men do not flutter between rushing and hugging. `+0.60` gives 1.21 vs 1.19,
  a 2% margin that any tune to `aggression` would erase. **0.75 is the smallest number with margin.**
- Skipping the 0.45 penalty is doctrinally right, not a fudge: a besieging company **has** a support
  element by construction (§A1.2). The penalty models a lone man crossing open ground unsupported.

**2. `scripts/enemies/enemy_base.gd`.** One flag, one line of feed.
- `var siege_press: bool = false` beside `assault_driven` (`:76`).
- `c.assault_press = siege_press` in the Context fill (`:1189-1212`, next to `c.has_covering_fire` at
  `:1209`).
- **Nothing else in `enemy_base.gd` changes. `_execute` is not touched.** A pressing man is a normal
  COMBAT man whose brain wants ADVANCE, so he runs `_execute_advancing` — which bounds, pauses, and
  **fires at `:1586`/`:1605`/`:1624`/`:1637`. Zero mute men.**

**3. `scripts/missions/siege_director.gd`.** The rotation, on the existing 0.5 s poll (`:103-114`) —
no new `_physics_process`, no new node.
- `const PRESS_CYCLE_S: float = 8.0` — one cycle ≈ 3-4 bounds at `_bound_pause` 0.8-1.6 s plus ~5 m
  rushes, so a pressed man completes a recognisable rush-rush-rush before the flag moves on.
- `const PRESS_FRACTION: float = 0.35` — one man in three up, two in three shooting. That IS bounding
  overwatch, and it is the ratio the doctrine uses.
- `_press_phase: int`, advanced each cycle; a man is pressed when
  `(index + _press_phase) % 3 == 0` over the flat list of materialized non-sapper men. Deterministic,
  no RNG, ADR-010-clean.
- **Never press a man carrying a `SapperCharge`**: he is permanently `assault_driven`
  (`sapper_charge.gd:40`), his legs are already owned, and the flag would be inert on him.
- Clear the flag on every man in `_break_siege` before `withdraw_to` — **a flag is idempotent and
  order-free, which is exactly why it cannot corrupt the reap the way a countdown can.**

**4. The overrun signal.**
- `signal siege_overrun(inside: int)`, emitted **once per night**.
- `const OVERRUN_MEN: int = 3` (the briefing's number, accepted — three men inside is the moment the
  fight changes character, and it is small enough to fire in a demo).
- **"Inside" must be MEASURED, never a constant.** The ring is at radius **49.3-96.1 m, mean 75.5**
  (briefing's measurement of `firebase_v3_destructibles.json`, accepted) — a single radius would call
  a man at 60 m "inside" on one bearing and "outside" on another. Read the `fsb_parapet` group
  (`site_planner.gd:1266`, `:1311`) once at `open_siege`, cache `[bearing → radius]` in 36 × 10° bins,
  and test `man_radius < bin_radius - 6.0`. Cost: one pass over 80 nodes per night.

## A5. THE `fsb_parapet` GROUP IS READ BY NOTHING — a live drift, correct on contact

`grep` for `fsb_parapet` / `FSB_PARAPET_GROUP` repo-wide returns **three hits, all writers**:
`site_planner.gd:1266` (the const), `:1311` (`add_to_group`), and `destructible.gd:51` (a comment).
**Zero readers.**

Both comments assert a reader that does not exist:
- `destructible.gd:50-52` — *"SiegeDirector polls this on the `fsb_parapet` group to find its breach
  axis."*
- `site_planner.gd:1306-1308` — *"SiegeDirector measures the wire's radius from this group and reads a
  destroyed segment as its breach axis."*

`siege_director.gd` contains neither string. This is **UNFINISHED, not FOSSIL** (ADR-023 triage: built
ahead of its wiring) — but the comments are a **lie in the map** of exactly the kind CLAUDE.md's
NO-MORE-DRIFT law exists for: the next reader will believe the breach logic exists. Either the reader
lands in this change, or both comments must be corrected in it.

## A6. THE TWO BLOCKERS — the other architect is RIGHT ON BOTH, and C3's breach is an ART task

**(a) A blown parapet is not traversable. CONFIRMED, with the mechanism.**
- `Destructible._do_destroy` **disables the collider** (`destructible.gd:74-75`), so a dead segment IS
  physically passable. Good.
- Nothing re-bakes. `nav_baker.gd:16-18` states it as a design property — *"sites != chunks → a crater
  never triggers a re-bake"* — and there is no re-bake call anywhere on the destruction path
  (`_do_destroy:67-86` touches meshes, colliders, groups, rubble, terrain, FX, noise; no nav).
- So the mesh keeps the **closed** ring, and `NavRouter.step` (`nav_router.gd:57-92`) happily returns a
  valid path — **around the hole, to the gate.** It does not even fall back to direct steering, because
  a path *exists*. The breach is invisible to every attacker.
- **A full re-bake is not the fix**: the firebase box is 370 m at the map's 0.25 m cell
  (`nav_baker.gd:186-187`) with the whole compound's trimeshes parsed — a mid-siege hitch, and
  `_start_bake` runs one job at a time (`:169-176`).
- **The correct cheap fix, when a breach is wanted: one `NavigationLink3D` per lane** — start ~8 m
  outside, end ~8 m inside, bidirectional, created once when a segment reports `is_destroyed()`. Links
  join the same map with a sync, not a bake; cost is one node and one frame's map synchronisation.

**(b) The wire cannot be breached at all. CONFIRMED, and it is the harder half.**
Measured in `tools/gen_firebase_v3.py`:
- `wire()` (`:323-372`) merges **three offset rings at 20 m, 17 m and 8 m beyond the berm** — a card
  every 2.70 m — into **ONE bmesh, ONE object, `bwire_card_ring`** (`:363-368`).
- `bwire_card_ring` is in the **trimesh collision list** (`:856`), so it is a real solid collider.
- It is **not** in `NAV_IGNORE_PREFIXES` (`nav_baker.gd:288`, which lists only `fb_veg_` and `fb_int_`),
  so all three rings are baked into the navmesh as unwalkable.
- `in_gate(bearing_of(p0))` skips cards in the gate arc (`:344-345`) — **the gate is the only opening
  in the wire, on purpose.**
- `_wire_parapet_destructibles` (`site_planner.gd:1266-1311`) wires segments **by name from the
  manifest**; there is no wire entry and there cannot be one — you cannot destroy one span of a merged
  mesh.

**So: three impassable rings stand 8-20 m outside a parapet you just blew a hole in.** Blowing the
parapet without the wire produces a hole men cannot reach.

**RULING: C3's *breach-lane* overrun is BLOCKED on `tools/gen_firebase_v3.py` + a re-export** — the
wire must emit as per-sector spans (`bwire_seg_NN`, ~10° bins, the `fb_sbg_seg_` pattern) before a lane
can exist. And that re-export has a **draw-call price on a CALL-BOUND project** (`PERF_LEDGER.md`): 36
spans is 36 draw calls where there is 1, at the most-visited site in the game — the same tax ADR-036 §2
names for splitting the GLB. **Do not pay it for the demo.**

**THE DEMO-LEGAL OVERRUN, needing no re-export: come through the GATE.** It is the one opening in both
the wire and the parapet; it exists in physics and in the navmesh today; `fsb_gate_metrics`
(`site_planner.gd:940`) already publishes it; and it is **doctrinally correct** — a road/gate is a
standard breach objective. With A4's goal bias, men who acquire a defender near the gate bound *in*
through it, and the ones who acquire over the berm bound up to the parapet and fight from it. The
player sees men **inside the wire, at one place**, which is the gate clause. **Parapet destruction stays
in the demo as spectacle — "the base attack blows parts of the base up" — not as the traversal
mechanism.**

## A7. THE PROPOSED SUBSTITUTE — "move the objective forward on breach and reissue". IT FAILS, and the failure is instructive

The idea: on breach, walk `SiegeDirector.objective` to the breach and then inward, and re-write
`assault_objective` on the men, reusing the **undriven** march at `enemy_base.gd:1309-1311` — a man
marches while not in contact, fights when in contact, and re-marches when the objective is reissued.

**It does not survive `:1309`.** The undriven branch runs only while
`alert_tier != AlertTier.COMBAT`. Reissue an objective to a man at the wire and his very next
`_execute` — same frame or the next — takes the `else` path and **clears it at `:1313`** because he *is*
in COMBAT. Nothing moves. Re-issue on a 9 s cycle and you get 9 s of nothing, forever, at a cost of one
`Vector3` write per man per cycle.

It only "works" for a man who has **lost contact** — the one man who was already going to walk forward
on his own. **So it delivers zero mute men and zero movement:** it is the mirror image of defect (2) in
A3. The press-with-drive is trapped into being mute; the reissue-undriven is trapped into being inert.
**Both are trapped by the same fact: `assault_objective` is defined as "the FSM does not decide," and
the overrun needs the FSM to decide differently.**

That is the convergence point with the other architect's alternative, and I **agree with his
diagnosis and refine his prescription**: the press must live where a man both moves and shoots.
- **He proposes advance-while-firing inside `_execute_combat` (`:1436-1483`).** `_execute_combat`
  already contains a stunted version — `dist > preferred_range * 1.3` → `move_dir = toward * 0.5`
  (`:1441-1443`), damped to `*0.15` when `has_cover` (`:1452-1455`). It fires at `:1477-1478`. So
  advance-while-firing *is* reachable there.
- **But putting the press there is the wrong door.** It duplicates `_execute_advancing`, which already
  does bound selection, cover claiming, sprint speed, the pause, the accuracy penalty and the
  fire-on-the-move — **a strictly better rush than anything that would be added to `_execute_combat`,
  and it would become the second bounding system (ADR-023).** Editing `_execute_combat` also silently
  retunes *every* firefight in the game; a gated Context term retunes nothing (default false).
- **Ruled: bias the GOAL so ADVANCING is chosen. The advance-while-firing he correctly demands is
  already implemented, at `enemy_base.gd:1586/1605/1624/1637`.** One additive term buys all of it.

## A8. WHAT IT COSTS AT THE PERF FLOOR

Baseline of record, `PERF_LEDGER.md:290-304` (W0 headless, 65+ units): AI wall **37.5-39.8 ms** per
physics tick; rays **152-161/s level-wide** (cover rays **29-35/s**); think **1.20-1.28 ms**;
`move_and_slide` **8.78-9.06 ms**; hitzone sync **9.87-10.43 ms**; anim/execute remainder
**17.63-19.04 ms**. The ledger's own attribution: **perception rays + think are ~6% of the wall. The
wall is the BODY.**

- **New rays.** `_find_bound_point` is ≤12 candidates, geometrically filtered to the forward ~5-6
  (`:1781-1782`), at ≤1 Hz per advancing man (`:1611`). At `PRESS_FRACTION 0.35` of ~40 materialized men
  → ~14 searchers → **~84 rays/s, on a measured level-wide baseline of 152-161.** The cover-ray line
  roughly **triples** (29-35 → ~115). Per the ledger's own attribution that is **microseconds**. Honest,
  and cheap.
- **The real cost is the body.** ~14 men change from near-static shooters to sprinting shooters. That
  moves work into the two most expensive lines (`move_and_slide` ~9 ms, anim/execute ~18 ms). It does
  **not add bodies** — the press changes what existing men do, so it adds **zero draw calls and zero
  nodes** (the one exception being a `NavigationLink3D` per lane, if lanes are ever built).
- **The one superlinear term, and it is pre-existing.** `_crowding_cost` (`enemy_base.gd:1722-1729`)
  iterates **every** entry in the static `_cover_claims` dictionary, and it is called **inside a sort
  comparator** (`:1789-1791`) — O(candidates · claims · log candidates) per search. With
  `LIVE_CAP = 50` attackers plus 24 garrison all claiming, this is the only term in this design that
  grows with the square of the assault. Also pre-existing: `_local_force_ratio` (`:1219-1237`) walks the
  **entire** `enemies` group per man per think — at 50 attackers that is ~2,500 distance tests at 6.7 Hz,
  **shipping today.** Neither is caused by the press; both are *revealed* by it. **Measure, do not
  pre-optimise** — and note that ADR-035 §10 gate 2's perf predicate is still **unmeasured**, so this
  lands on an undischarged gate either way.
- **Code contradicts ADR on the cap.** `siege_director.gd:36` — `LIVE_CAP: int = 50`. ADR-035's own
  build-state note (`:253`) says the roll *"ships behind `LIVE_CAP = 18` on trust rather than proof."*
  **The code is 50.** 50 attackers + 24 garrison + 6 squad ≈ **80 bodies — above the 65-unit baseline
  that measured the 38-40 ms wall.** The ADR is stale on the single number that governs the frame.

## A9. WHAT IT SACRIFICES

1. **Volume of fire dips while men bound.** A bounding man fires 2-3 round bursts on the move
   (`:1605-1607`, capped at `burst_count < 2`) against 3 from a settled man. At 35% pressed the
   perimeter's outgoing fire drops a little. **This is correct and it is the doctrine** — but it means
   the press must never go much above 0.35, or the attack goes quiet as it advances.
2. **Congestion.** Men funnelled through one gate will pile against each other in `move_and_slide`.
   `_crowding_cost` spreads *cover claims*, not bodies in a corridor. Expect visible shoving.
3. **The garrison cannot give ground.** Promoted defenders sit on `OrderMode.HOLD` with
   `post_leash = 8.0` (ADR-036 §4 citing `ally_base.gd:147`). An overrun therefore **kills** the
   garrison in place rather than displacing it. That is ADR-036's problem, and the demo must not build
   anything that depends on losing.
4. **`on_firebase_breach` becomes a lie if sappers are ever re-aimed at the wire.** `sapper_charge.gd`
   detonates 250 dmg / 14 m radius (`:16-18`) and unconditionally calls
   `FieldDirector.on_firebase_breach` (`:76-78`), which zeroes mortars and toasts *"THE MUNITIONS DUMP
   IS GONE"* (`field_director.gd:1266-1276`). At 80 segments over a ~474 m ring (~5.9 m each) a single
   satchel on the wire destroys ~5 segments — **a ~28 m hole and a false "the dump is gone" message,
   with the player's mortars really gone.** If the aim point ever moves to the wire, that call must be
   gated on proximity to `USSupplyDepot_001/007` (`site_planner.gd:779`).
5. **The whole assault is ONE fireteam.** `spawn_tracked_enemy` sets `squad_id = hash(group_tag)`
   (`field_director.gd:51`) and `MarchingCell` passes only two tags — `"siege_sappers"` /
   `"siege_assault"` (`siege_director.gd:173-174`). So ~30 assault men share one `squad_id`. Consequence
   the grenade broker makes concrete: **5 s global + 12 s per squad** (`test_ai_fairness.gd:106-121`) →
   **one grenade per twelve seconds for the entire overrun.** Grenades are how a real assault echelon
   enters a trench. Per-cell tags would fix it (each cell becomes a real fireteam, `has_covering_fire`
   becomes local, `force_ratio` becomes meaningful) at the cost of registering ~10 ADR-006 contact
   groups instead of 2 (`field_director.gd:56`). **Arbiter's call** — this contradicts ADR-035 §2's
   framing of cells as fireteams, which the code does not deliver.

## A10. PILLARS

- **Serves Pillar 1 (believable firefights)** most directly, and serves it *by deletion*: the fix is a
  scoring term, so the men who press are the same men, with the same perception, weapons, suppression
  and cover — they simply want to close. **Serves Pillar 2** (the picture in A1).
- **Serves Pillar 4**: an attack that concentrates on one lane makes "where do my five men face" the
  decision, which is ADR-035 §3's stated Pillar-4 verb.
- **Strains Pillar 5.** An overrun with no specified successor state is ADR-036 §3/§5's unresolved
  question. The demo may **show** men inside the wire; **nothing may depend on losing the base.**

---

# PART B — ITEM #4, OFF-DUTY MEN HAVE NOWHERE TO BE

## B1. THE CODE CONTRADICTS THE BRIEFING — `off_duty` does not "sit and talk"

`civilian_schedules.gd:186-205` gives `off_duty` a full day: SLEEP (<6, ≥22) · WALK_FIRE · SIT · **WORK
(9.5-11.0)** · WALK_FIRE · TALK · REST · WALK_FIRE · TALK · SIT. Six distinct verbs. **The schedule is
not the defect.** (The briefing's observation is nonetheless *true as reported*, because the demo opens
at dusk — 18.5-20.5 is TALK and 20.5+ is SIT. He saw the two hours that really are sit-and-talk.)

## B2. THE ACTUAL DEFECT — twelve scheduled verbs, four behaviours

In `scripts/world/civilian.gd`, **seven leaves are byte-identical**: `_bt_work:710`, `_bt_rest:718`,
`_bt_cook:726`, `_bt_sleep:734`, `_bt_fish:742`, `_bt_sit:750`, `_bt_talk:756`. Every one is
`bb["speed"] = 0.0`, `_wander_target = global_position`, `velocity.x/z = 0`, `SUCCESS`. **Freeze where
you stand, under seven names.**

Twelve scheduled actions collapse to four real behaviours:
1. freeze (work, rest, cook, sleep, fish, sit, talk, idle),
2. walk to `home` (`_bt_walk_home:677`),
3. walk to the working point (`_bt_walk_working:685` — bound to **`walk_paddy` only**,
   `build_bt:468/481`),
4. walk to `home + (2, 0, 2)` (`_bt_walk_fire:693` — a hardcoded imaginary campfire).

**And `_resolve_target` (`:653-660`) only maps `walk_paddy` / `work` / `fish` to `working_point_pos`;
everything else returns `home ± 3 m`.** So the 191 authored work markers can only ever be reached by
one of twelve verbs.

## B3. THE CONSEQUENCE NOBODY HAS NAMED: `ACTION_WORK` DOES NOT WALK A MAN TO HIS POST

`civilian_schedules.gd:102-103` asserts, in the source:

> *"ACTION_WORK sends a man to his own working_point_pos - his post, his gun, his radio - so 'work' at
> night means STANDING THE WIRE, not farming."*

**That is FALSE at `civilian.gd:710-716`.** `_bt_work` sets `_wander_target = global_position`. It
freezes him wherever the previous action left him — and the previous actions (TALK, SIT, REST) resolve
to `home ± 3 m`. `_bt_tick` does compute `bb["target_pos"] = _resolve_target(picked)` at each hour
rollover (`:527`) — **and `_bt_work` never reads it.**

**This is the A3 garrison rewrite's real, unverified defect, and it is the same bug as A4.** The 7/29
rewrite built the entire night shift on `ACTION_WORK`: `sentry_night` (`:119-132`, WORK from 18:00 to
05:30), `gun_crew` (`:146-160`), `radioman` (`:161-169`), `quartermaster` (`:133-145`). **None of them
walks to his post.** They only *appear* correct because `place_for_current_hour()` (`:639-650`)
**teleports** a man to the resolved target at spawn and on LOD_FAR wake. So the base looks right the
instant it is built, and decays toward the hootches as the hours roll — which is exactly *"the other
NPC allies just stand there."*

## B4. WHAT IS ALREADY BUILT — the pipeline is complete except for the last three lines

Everything the briefing hopes for exists:
- **191 `work_*` markers** in `fsb_main_v3.glb`, harvested by prefix with full parent-chain transforms
  (`site_planner._ensure_fsb_markers:865-895`), type parsed from `work_<type>` with the glTF `_001`
  suffix stripped (`:884-889`), sorted deterministically (`:891-896`).
- **Sampling**: `fsb_garrison_plan` (`:900-935`) takes `FSB_GARRISON_MAX_MEN (24) - curated` capped at
  `FSB_WORK_POST_CAP (12)`, by a deterministic **stride** (ADR-010), maps `work_type → occupation`
  through `FSB_WORK_OCCUPATION` (`:820-826`), defaults unknown types to `off_duty` (`:922`), and
  alternates `sentry`/`sentry_night` so the wire is manned after dark (`:923-924`).
- **Homes**: `FSB_GARRISON_QUARTERS` (`:809-812`) round-robins four footprints, *explicitly* so
  *"the compound carries traffic between quarters and post instead of statues."* **The intent is already
  written down. The traffic never happens because `_bt_work` freezes.**
- **`WorkingPointResolver`** (`working_point_resolver.gd`) resolves village NodePaths → world positions
  and is the same contract.

## B5. THE SMALLEST CHANGE — one file, ~8 lines, no second system (ADR-023)

**1. Make `_bt_work` walk, then stand.** Read `bb["target_pos"]` (already populated at `:527`), walk at
~1.2 m/s until within **1.5 m** (the arrival radius every other walk leaf uses), then damp velocity and
return SUCCESS. This is `_bt_walk_working`'s shape with a stand at the end. **That single edit lights up
the entire pipeline in B4** — `sentry_night` goes to the wire at dusk, `gun_crew` to the pit,
`quartermaster` to the dump, `radioman` to the TOC footprint, and `off_duty` to his work marker at
09:30. It also repairs the false claim at `civilian_schedules.gd:102-103` (drift law: correct on
contact).

**2. Add ±1.5 m jitter to the work target,** the same `randf_range(-3.0, 3.0)` pattern `_resolve_target`
already uses for `home` (`:660`) — two men assigned near one marker must not co-locate.

**3. One two-word schedule edit for the demo's own hours.** `off_duty`'s `20.5 → 22.0` block is
`ACTION_SIT` (`civilian_schedules.gd:205`). Make it `ACTION_WORK`. The loafers are then hauling and
filling at a work marker during the exact minutes the player walks in at dusk — **the highest-value
single token in item #4.**

**Explicitly NOT doing** (gold-plating, and each is a second system): a new "chore" component; a
`work_*` marker list plumbed into `Civilian` so `walk_fire` can find a real cook fire; per-action
animations. `_bt_walk_fire`'s fake `home + (2,0,2)` campfire (`:696`) is left alone.

## B6. COST AT THE PERF FLOOR

**Effectively zero, and this is measurable rather than hopeful.**
- **No new nodes, no new draw calls, no new systems.** The bodies already exist and are already in the
  scene.
- `_step_toward` (`:368-381`) **already calls `_router.step` every physics tick** at `LOD_FULL` — with
  `target == global_position` today. The nav work is already being paid; it merely produces a zero
  vector.
- The only genuinely new work is **one `map_get_path` restake per man per schedule rollover**:
  `NavRouter` caches the clamp and restakes only when the target moves > 3 m
  (`nav_router.gd:84-90`), and `_bt_tick` re-picks only when `int(hour)` changes (`:521-527`).
  Bounded by `FSB_GARRISON_MAX_MEN = 24`.
- Bodies that were idling now walk → walk anim instead of idle anim. Same call count.
- **Measure the idle-in-base frame before/after anyway** — ADR-036 §2 establishes that the firebase is
  the densest site in the game (678 meshes / 1,116 bodies) and the most-visited frame.

## B7. THE RISK, AND ITS PROBE

The firebase navmesh is the one baked from real colliders (`nav_baker.gd:33-42`), and work markers come
from the GLB. A marker inside a bunker footprint or on ground the `AGENT_RADIUS` erosion ate is 5-8 m
off walkable mesh — the exact failure `nav_router.gd:74-79` documents from the 7/29 playtests. The 12 m
clamp (`CLAMP_MAX_M`, `:37`) repairs most; anything worse falls to direct steering **into a wall.**
**Expect 1-3 of the 12 stride-sampled markers to be bad posts, visible as a man grinding on geometry.**

**Probe (every rig ships with one that exercises it):** run the base across four sim hours and log any
`Civilian` whose distance to `bb["target_pos"]` **stops decreasing** for > 10 s while
`active_action == &"work"`. That names the bad markers by position, so the fix is a Blender marker move,
not a code guess. **Making the men walk is what makes bad posts visible** — today they are hidden by
`place_for_current_hour()`'s teleport, and that is a fossil-shaped concealment.

## B8. PILLAR

**Pillar 2 (atmosphere), served directly and cheaply.** Strains nothing. **Pillar 1 is served
incidentally and importantly**: `sentry_night` actually standing the wire at dusk is the difference
between a garrison that gets murdered asleep and one that fights — which is ADR-035 §6's premise.

---

# PART C — THE DEMO'S 40-MAN ASSAULT NEVER OPENS. CONFIRMED, WITH THE ARITHMETIC

`scripts/levels/demo_game.gd` (note: **`scripts/levels/`**, not `scripts/missions/`).

- `PROBE_AT_S = 600.0`, `SIEGE_AT_S = 720.0`, `DAWN_AT_S = 1080.0`, `PROBE_STRENGTH = 11`,
  `SIEGE_STRENGTH = 40` (`:26-30`).
- Phase 0 → `_open_siege(11, "PROBE ON THE WIRE")` at 600 s (`:171`) → `open_siege(11)` sets
  `run_strength = 11`, `run_peak = 11`, `nights_run = 1`, `active = true`, `is_probe = true`
  (`siege_director.gd:142-164`).
- Phase 1 → `_open_siege(40, "HERE THEY COME")` at 720 s (`:175`) → hits
  `if d.siege.active: toast + return` (`:197-203`).
- **The probe cannot have ended by then.** `MAX_DURATION_S = 480.0` (`siege_director.gd:40`), so the
  dawn break lands at 600 + 480 = **1080 s — exactly `DAWN_AT_S`.** The only earlier exits are
  `"wiped"` or `"broken"` (`:203-212`); an 11-man probe that the player wipes inside two minutes would
  set `nights_run = MAX_RUN_NIGHTS` (`:360-361`) and then the 720 s call opens a **fresh d50 roll**, not
  40 men, because `run_strength` was zeroed to survivors and `open_siege(40)` re-rolls only via
  `forced_strength` — which it does pass, so 40 would work in that one branch.
- **In the intended run — probe survives to 720 s — the 40-man assault never opens. `SIEGE_STRENGTH`
  is dead. The demo's headline ("the VC attempt to overrun the firebase") is currently a toast.**

## C1. THE CORRECT MINIMAL API — `reinforce`, not a second `open_siege`

Add to `SiegeDirector`:

**`func reinforce(extra: int) -> void`** — the *only* sanctioned way to escalate a running siege.

1. **Guard**: return unless `active` and `extra > 0`. Escalating a dead siege is `open_siege`'s job.
2. **`run_strength += extra`** and **`run_peak += extra`**. *Both.* Growing `run_peak` is what keeps the
   ledger honest: `killed_count()` is `run_peak - live_strength()` (`:224`), so men already dead stay
   counted (live dropped, peak grew by exactly the new bodies) and `break_state(live, run_peak, ...)`
   (`:210`) computes against the real total. Growing `run_strength` alone would leave `live > peak` and
   a ratio above 1.0 — an assault that can never break. Growing `run_peak` alone would credit the player
   with 29 kills he never made.
3. **`_build_cells_for(extra)`** — factor the cell loop so `_build_cells()` (`:170-174`) and
   `reinforce` share one path. Same `sector_bearing`, same 2d6-fraction sapper split, same
   `_spawn_cells_for`. **Nights 2-3 remember the axis (ADR-035 §3); so must a reinforcement — a second
   wave on a new bearing is a second siege.**
4. **`is_probe = run_strength <= PROBE_MAX`** — recompute. A probe reinforced to 40 is a siege, and if
   `is_probe` ever gates the press (A4) or the siren (`field_director.gd:1297-1305`), a stale `true`
   suppresses both at the moment they matter.
5. **Do NOT touch** `nights_run` (same night — bumping it burns one of the three and can end the run),
   `_elapsed` (see below), `_rolled_this_night`, `sector_bearing`, `_mortar_timer` (the walk should stay
   converged: the tubes have been ranging for two minutes and dispersion is *supposed* to be tight),
   or `_reaping` / `_reap_clock`.
6. **Emit `siege_began(run_strength, is_probe)` again** — `FieldDirector._on_siege_began` (`:1292`) is
   idempotent (`_garrison_stand_to` self-latches at `:1245-1247`) and it is what sounds the siren
   (`:1303`) for the escalation. That is the "HERE THEY COME" moment, diegetically.

**`_elapsed` deliberately not reset**, and the demo must accept the consequence: the 480 s stopwatch
runs from the probe's open, so the reinforcement fights the remaining 360 s. **For this demo that is
exactly right** — 600 + 480 = 1080 = `DAWN_AT_S`, so the dawn break and the demo's dawn card coincide.
Resetting `_elapsed` would push the break past the end card.

**Then in `demo_game._open_siege`, replace the toast-only branch (`:197-203`) with**
`d.siege.reinforce(strength - d.siege.run_strength)` when `active`. At 720 s that is
`reinforce(40 - 11) = 29` more men on the same axis — which is, correctly, *the probe was the
reconnaissance and the assault followed it in*. **That is better drama than two unrelated attacks, and
it is what the doctrine in A1 actually describes.**

**Probe for it** (ADR-035 §10.3 — every rig ships with one that exercises it): open at 11, kill 4,
`reinforce(29)`, and assert `run_peak == 40`, `killed_count() == 4`, `nights_run == 1`, `is_probe ==
false`, and that the reap still returns `_live_enemies` to its pre-siege count on break.

---

# SUMMARY OF CODE-vs-DOCUMENT CONTRADICTIONS FOUND

| # | Claim | Where asserted | Truth |
|---|---|---|---|
| 1 | "no doctrine presses in" because the objective clears | briefing §1 | Effect true; **cause** is `combat_goals.gd:92-105` (ADVANCE 0.61 vs ENGAGE 1.19). A bounding rush is already built at `enemy_base.gd:1572-1643`. |
| 2 | SiegeDirector reads `fsb_parapet` for its breach axis | `destructible.gd:50-52`, `site_planner.gd:1306-1308` | **Zero readers repo-wide.** Unfinished; the comments are a lie in the map. |
| 3 | The d50 ships behind `LIVE_CAP = 18` | `ADR-035:253` | Code is **50** (`siege_director.gd:36`) — ~80 bodies, above the 65-unit perf baseline. |
| 4 | `ACTION_WORK` sends a man to his post | `civilian_schedules.gd:102-103` | **False.** `_bt_work` (`civilian.gd:710-716`) freezes him in place. Breaks the whole 7/29 A3 night shift. |
| 5 | `off_duty` "sits and talks" | briefing §4 | Schedule has six verbs (`civilian_schedules.gd:186-205`); **seven BT leaves are byte-identical freezes.** True only for the dusk hours he played. |
| 6 | The demo runs a 40-man assault | `demo_game.gd:30` | **Never opens** — `:197-203` toasts and returns; the probe is still active at 720 s. |
| 7 | `_fire_at_target` has one caller | (council finding 1) | **Six** (`:1478, 1567, 1586, 1605, 1624, 1637`). His conclusion — a driven man is mute — is **right and stronger**: the override returns at `:1307`/`:1311` before the dispatch at `:1322`, so he reaches none of them. |
