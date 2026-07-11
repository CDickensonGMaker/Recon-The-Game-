# DEVIL'S ADVOCATE — AI Goal Doctrine (both factions)
War Room session 2026-07-10. Lens: attack everything, name every sacrifice, cap the knob count.

The Summoner's feedback is ground truth. My job is to say which of his six complaints are actually
GOAL problems, which are the render layer lying to him, which are the bench lying to all of us —
and to name the failure modes of every fix this council is about to fall in love with.

Headline: **two of the six complaints are render-layer bugs, not goal-layer doctrine gaps.** If this
council ships a beautiful commitment doctrine and leaves the facing/anim bugs in, the Summoner will
see almost no change. If it ships only the render fixes, half the complaint list improves. Sequence
accordingly.

---

## (a) Diagnosis per Summoner item — verified, file:line

### 1. "Squad overuses the STRAFE animation" — RENDER BUG, not doctrine
- `sprite_state_map.gd:66-71`: in `intent_for`, COMBAT + `speed > 0.3` → intent `"strafe"`.
  ANY movement in COMBAT — closing range, backing up, cover micro-shuffle, actual strafing — plays
  the strafe clip. 0.3 m/s is noise-level: the velocity lerps in `_execute_combat`
  (enemy_base.gd:1129-1133, ally_base.gd:469-473) keep speed above it almost continuously, and the
  strafe timers re-roll a nonzero lateral 50% (enemy :1091) / 67% (ally :435) of the time.
- Worse, on the v2 grunt rigs (ALL squadmates, `ally_base.gd:116`), `MODEL_ALIASES` maps
  `"strafe" → run_left` (`sprite_state_map.gd:110`) — a leftward run played regardless of which way
  the man is actually moving. The Summoner is watching men run sideways-left while walking forward.
- Verdict: the goal layer is barely implicated. The intent funnel has no concept of movement
  DIRECTION relative to facing, and the fallback alias turns "strafe" into a lie.

### 2. "Enemy model rotation is off a lot" — DOUBLE-YAW RENDER BUG, verified mechanism
- `enemy_base.gd:1034`: `_update_aim` calls `look_at(global_position + flat_aim)` on the
  **CharacterBody3D itself** — the parent body rotates to the aim.
- `model_actor.gd:246-251`: `set_facing` then sets the **child** ModelActor's local `rotation.y =
  atan2(facing.x, facing.z)` using a **world-space** direction. Child local yaw stacks on parent
  yaw → world model yaw = parent + child. The error varies with aim direction (a 2θ−π curve): the
  model is accidentally correct at one bearing and up to 180° wrong at others. That is exactly
  "off a lot" rather than "always backwards."
- The lab amplifies it: `gore_lab.gd:255` randomizes body `rotation.y` at spawn, so every idle
  enemy's model is off by a random constant before the first `look_at` even runs.
- Why it's new: `SpriteActor` was a billboard — parent rotation was invisible, `set_facing` just
  picked an 8-dir frame. The bug was born when models became the default renderer (ADR-001).
  Allies suffer it too (`ally_base.gd:390` look_at + `:196` set_facing); the Summoner just watched
  the enemies.
- TRAP to name now: any "add PI / flip the sign" patch will fix one bearing and break the rest.
  The fix is killing the double-write — ONE owner of yaw (body never rotates and the model owns
  world yaw, or set_facing subtracts parent yaw). Everything downstream that uses
  `transform.basis.x` for strafe vectors (enemy :1120, ally :449) must be audited with it.

### 3. "Squad seeks cover more than anything else" — REAL goal-layer defects, four of them
`ally_base.gd:333-357` `_evaluate_goals` is 3 branches at 6.7Hz with NO dwell and NO hysteresis, as
the briefing says. But the obsession is not one missing timer — it is four concrete defects:
1. **`_cover_fail_count` never resets.** Declared :93, incremented :523, reset NOWHERE (enemy
   resets on contact loss, enemy_base.gd:829; ally has no equivalent). Consequence is double-edged:
   the man who fails twice never uses cover again for the rest of his life, and until he fails
   twice the cover-first gate (:347) fires on every fresh contact forever.
2. **Drift-release re-seek loop.** In COMBAT the executor drags him off his point (range-keeping +
   strafe, :442-459); >2.5m → `_release_cover()` (:456-458) → `has_cover` false → next think the
   gate at :347 throws him back into SEEKING_COVER. Reach cover, drift, release, seek, leap,
   repeat — that IS "seeks cover more than anything else."
3. **Suppressed re-leap in place.** Branch 1 (:335-338) sends suppressed men to SEEK_COVER without
   checking `has_cover`, and ally `_execute_seeking_cover` (:496) lacks the enemy's `if not
   has_cover` guard (enemy_base.gd:1177). A suppressed man ALREADY in cover re-searches, re-claims
   his own cell (self-claim passes the broker, enemy_base.gd:1378), re-arrives, re-plays the leap
   clip. Cover use is not just frequent, it is VISUALLY LOUD.
4. **Zero DPS while seeking.** Ally `_execute_seeking_cover` (:496-538) contains no fire call
   (enemy's :1173-1216 likewise). Every re-seek cycle craters squad output, which makes the
   obsession read even worse.
Plus a stale-state bug: on target death → IDLE (:421-427) the claim and `has_cover` persist, and
`_anim_override` isn't cleared on the lost-LOS path (:487-493) — a man can jog after the player in
a crouch-hold clip holding a phantom claim, then SKIP cover-first next contact and scramble for
cover mid-fight instead. The mid-fight scramble is the worst possible read.

### 4. "Goals constantly switching because LOS changed" — REAL, and the hysteresis is undersized
- `enemy_base.gd:816-921`: dwell is 0.5s (:820) and incumbent bonus ×1.15 (:910). LOS flicker moves
  `engage_score` by ±0.3 (:848-849) and `flank_score` by ±0.3 (:878-879) — on typical scores of
  0.6-0.9 the hysteresis is worth 0.09-0.14. The LOS term is 2-3x the hysteresis, so a legal goal
  flip every 0.5s on pure LOS strobe is arithmetic, not bad luck.
- FLANK has no completion condition: `_execute_flanking` (:1219-1237) is a velocity, not a plan —
  sideways+forward forever until the goal changes. You cannot "commit" to a goal that has no end.
  ADVANCE (bounding, :1244-1314) is the one goal that already IS a plan — bound point, arrival,
  pause, next bound. The doctrine should generalize ADVANCE's shape, not invent a new one.
- Unit bug: `goal_timer += THINK_INTERVAL` (:817) but thinks stretch to 0.3/0.6s under LOD
  (:41-60), so the 0.5s dwell is silently 2-4x longer in real time at distance. `_contact_time`
  right below uses `_think_interval_current` (:837). Whatever dwell the council picks, fix the unit
  first or the tuning is noise.

### 5. Wave 2 spawns in the open — BENCH SCAFFOLDING, not doctrine
- `gore_lab.gd:237`: `pos = (rand -16..16, 1, rand -19..-12)` — no cover adjacency, pure RNG in the
  most exposed strip of the room. Also :256-259 spawns reinforcement waves ALERT with a fuzzed fix
  on the player. Fix the spawn placement, but do NOT let anyone generalize "reinforcement behavior"
  doctrine from this room — it's a lab convenience, not a design.

### 6. Squad bunched into one corner of cover — REAL, mechanism verified
- `_find_cover_point` (enemy_base.gd:1433-1449; ally copy :542-564) sorts candidates purely by
  `distance_squared_to(self)` and claims the closest. The broker (:1374-1382) blocks only the SAME
  2m cell (`COVER_CELL = 2.0`, :102). Allies spawn in a ~5m arc (gore_lab.gd:207), so five men have
  near-identical candidate rings and legally claim five ADJACENT cells of the same corner. The
  Summoner's diagnosis is exactly right.

---

## (b) The doctrine piece I own: the INTERRUPT CONTRACT and the KNOB BUDGET

Commitment-based AI has three canonical corpses: the man who finishes his rush into a grenade, the
cover-committed man who ignores the flanker at 3m, and the squad that feels scripted because dwell
timers made it slow. Commitment is only shippable if the interrupt set is right. I also own the
treadmill: every number this council adds is a number the Summoner must feel-test on the bench,
forever. So the doctrine below is deliberately built from ONE structural rule + a bounded set of
interrupts + SIX new numbers total.

**Rule 1 — Plan commitment (replaces every per-goal dwell knob):**
- A goal WITH a point (cover point, bound point, flank point) is LOCKED: no re-evaluation until
  arrival or a mandatory interrupt. No timer at all — the plan's length IS the dwell.
- FLANK must acquire a flank point (same search machinery as `_find_bound_point`, offsets biased
  perpendicular) or it is denied a slot in scoring. A goal without an end is not a goal.
- A goal WITHOUT a point (ENGAGE from position, HOLD, INVESTIGATE) re-evaluates on a **1.0s**
  cadence (up from 0.5) with incumbent bonus **×1.25** (up from 1.15).
- Cap plan length: reject cover/bound/flank points farther than **12m** from current position
  (current offset rings max ~6m, so this is a guard rail, not a behavior change).

**Rule 2 — LOS debounce, goal-eval ONLY:**
- `los_stable`: flips TRUE after raw LOS held **0.3s** continuous; flips FALSE after raw LOS lost
  **0.6s** continuous (asymmetric: acquire fast, lose slow — foliage blinks don't reshuffle plans).
- **Superman guard (non-negotiable):** raw LOS keeps gating firing (:1094, :1137), the exposure
  ramp (:773-779), and spread. NOTHING that aims or shoots may ever consume the debounced signal or
  any "contact confidence" scalar. The exposure ramp's 3x drain (:779) stays untouched — slow that
  drain to smooth goals and you have rebuilt the superman who fights a man he cannot see. The
  Fairness Law outranks smoothness.

**Rule 3 — Mandatory interrupts (override any lock, checked every think, in priority order):**
- **I1 Took damage** — already slams COMBAT tier (enemy_base.gd:1714); extend to clear the plan lock.
- **I2 Point-blank contact**: hostile with raw LOS inside **8.0m** → force retarget + ENGAGE,
  re-trigger capped at once per 1.5s. This is the anti-"ignore the flanker at 3m" clause; the
  perception layer already feels contacts inside 10m (`CLOSE_SENSE_RANGE`, :81,600), but the 2s
  retarget interval (:682) + a goal lock would let a covered man die aiming the wrong way.
- **I3 Grenade inside 8.0m** → break perpendicular ~5m. NOTHING in either brain reads live grenade
  positions today (verified by absence in enemy_base.gd / ally_base.gd — grenades are only thrown,
  :1616-1645). Without I3, commitment doctrine turns "finishes his rush" into "finishes his rush
  onto the grenade." Implementation stays inside perf law: a static list of live Grenades, distance
  check at think rate (6.7Hz), zero new rays.
- **I4 Target died** → immediate re-eval (already exists, :714-715, :752).
- **I5 Suppression crossing 0.7** → SUPPRESSED state (already exists, :948).
- Everything else — LOS flicker, retarget cadence, threat drift, a better-scored goal appearing —
  WAITS for arrival or the 1.0s cadence. That is what commitment means.

**Rule 4 — Dispersion, one knob:**
- A claim is REJECTED if any live claim sits within **4.0m** (broker scan; the claims dict is tiny,
  this is arithmetic, not rays) — UNLESS no candidate survives the spacing test, in which case the
  closest LOS-blocking candidate wins anyway. **Stacked beats dead.** No per-man sectors, no
  crowding penalty weights, no cover-quality scoring rework. Those are three extra knobs to buy a
  behavior this one rule already produces.

**Rule 5 — Animation intent (kills Summoner #1):**
- DELETE the `"strafe"` intent from the COMBAT branch of `intent_for`. Locomotion is picked by
  body-space velocity: speed < **0.8 m/s** → `aim` (0.3 was lerp-jitter); else angle between
  velocity and facing: <45° `run_forward`, >135° `run_backward`, sides `run_left`/`run_right`. The
  v2 directional run clips exist precisely for this; today they're being misused as a blanket alias.
- Sacrifice named: there is no authored aim-walk clip on the v2 rig (walk aliases to run_forward,
  sprite_state_map.gd:93,123). "Aiming and moving" will read as directional runs until an aim-walk
  clip is authored. Say so in the decree rather than pretending a threshold can conjure a clip.

**The knob budget: SIX new numbers.** 1.0s cadence, ×1.25 incumbent, 0.3/0.6s debounce, 8m
interrupt bubble, 4m claim spacing, 0.8 m/s anim floor. Any architect proposing a seventh number
must name which of these six it replaces. Dwell tables, confidence-decay taus, sector counts,
crowding weights, per-goal hysteresis — all rejected above by construction.

---

## (c) What to CUT / simplify

1. **Cut the second brain.** Ally `_evaluate_goals` is not a smaller enemy brain; it is a
   different, buggier machine (fail-count leak, missing has_cover guard, no dwell, stale claims).
   Either the ally adopts the enemy goal evaluator with ally-flavored inputs (no FLANK, FOLLOW as
   the no-contact goal), or the council accepts that every knob it tunes is two knobs forever. If
   the full merge is too big for one decree, the minimum patch set is: reset `_cover_fail_count`
   on contact end, add the `has_cover` guard to `_execute_seeking_cover`, release cover + clear
   `_anim_override` on every COMBAT exit. But say out loud that the patch route leaves two brains.
2. **Cut the `"strafe"` intent** (Rule 5). Half the felt complaint dies with it.
3. **Cut SUPPRESS_TARGET as a separate goal.** It maps to the same state as ENGAGE (:954-955) and
   a near-identical execution path; goal churn between ENGAGE↔SUPPRESS is invisible on screen but
   still resets goal_timer and burns hysteresis. Make suppression a fire-discipline flag on ENGAGE.
   Sacrifice named: the MG-suppression identity — re-add it when an MG doctrine actually exists.
4. **Freeze `threat_level`** (:784-803). It is a soup (suppression + recent damage + hp + cover)
   feeding a 0.3 multiplier — nearly untunable and it double-counts inputs the scores already use.
   Don't rework it this pass; just forbid tuning through it.
5. **Do NOT add:** contact-confidence decay scalar (superman risk, see Rule 2), per-goal dwell
   table, sector assignment, crowding weights, cover quality scores. Each is a treadmill.
6. **Sequencing is the real simplification:** fix #2 (double-yaw) and #1 (anim mapping) FIRST —
   both are pure render fixes — then re-bench before tuning a single goal number. A meaningful
   share of "cover obsession" is cover use being visually loud (leap clip, crouch loop, re-leap
   bug, wrong facing). Judge the goal layer only after the render layer stops lying about it.

Small bugs found while verifying, for the programmer's list: ally `state_timer` double-increment
(:362 and :491); `goal_timer` unit mismatch under think-LOD (:817 vs :837); `_bound_fail_count`
never resets on new contact (:813, :1291); ally `_anim_override` not cleared on lost-LOS /
target-death exits (:421-428, :487-493) — the moonwalking crouch slide.

---

## (d) Risks — no free lunches

**Of the commitment doctrine itself:**
- Locked rush into a grenade: mandatory I3, or accept the corpses knowingly. There is no third option.
- Covered man ignoring a 3m flanker: mandatory I2. Cost named: a sprinting player can farm I2
  re-triggers to keep a squad permanently interrupted — hence the 1.5s re-trigger cap, which is
  itself a small exploit window. Accepted.
- Feeling SLOW/scripted: the danger is dwell timers, which is why the doctrine has none — plans
  end at arrival, pointless goals re-eval at 1.0s. If the bench still reads slow, the culprit will
  be the acquire chain, not the locks: 0.3s debounce + reaction (0.25×(2−char_reaction), :1083) +
  first-shot near-miss (:1511) + ally aim settle 0.45-0.9s (:309) stacks to ~2s first effective
  shot. If squad DPS feels dead, cut the debounce on the ACQUIRE side (0.3→0.15), never the loss side.
- LOS-loss debounce means a man holds ENGAGE up to 0.6s at a wall. Fire still gates on raw LOS, so
  he holds his sights on the last position instead of instantly re-planning — that reads as
  covering a doorway, which is a feature. But name it: he is NOT seeking cover during that 0.6s.

**Of dispersion:**
- 4m spacing can exile man #5 past usable cover into the open. The stacked-beats-dead waiver is
  not optional; without it this rule kills more squadmates than bunching ever did. And spacing
  breaks differently by geometry: right along a berm line, wrong inside a bunker. Lab-provisional.

**Of the cut list:**
- Merging the brains is the largest regression risk in this council. The Summoner's first words
  were "combat feels fun and fast — keep that." Do not bet the fun on architectural purity in one
  decree; stage it (patch set now, merge as its own bead).

**Of the bench itself — what this room CANNOT tell you (do not tune against it):**
- The lab is a 44×44 kill room with zero vegetation: `_grid` is null, so sight cap is the OPEN
  140m everywhere (enemy_base.gd:522-530) and the jungle path — 45m cap, vegetation-as-soft-cover
  (:1198-1205) — has NEVER run on this bench. In jungle, concealment is everywhere: `has_cover`
  flips true from a bush, and the cover-first pressure this council is busy damping may nearly
  vanish. Conversely the "two dry searches" escape hatch, rare in a room with 26 boxes, becomes
  the MAIN path in elephant grass. Tuning cover doctrine in this room is tuning for the one
  terrain type the game is not about.
- No navmesh here (direct steering; `_nav_box = -1`). Cover selection ignores path cost — the "3m
  away" candidate in a village may be through a hut wall. Point selection tuned here will need a
  path-sanity pass on real sites.
- Wave-ALERT spawns with a player fix (:256-259) and random body yaw at spawn (:255) are lab
  scaffolding. The latter actively corrupts every facing observation made in this room until the
  double-yaw fix lands.
- Engagement ranges here are 10-30m with instant mutual LOS at spawn. Aim settle, exposure drain,
  reaction stacking were all felt-tested under conditions the real game (10-25m jungle sightlines,
  140m paddy sightlines) will not reproduce.
- DECREE REQUIREMENT: all six numbers ship marked **lab-provisional**, and a jungle-terrain
  session (real site, vegetation grid live, nav baked) is a blocking bead before any of them is
  written into ADR canon.

*Tradeoffs named. The council advises; the Summoner decides.*
