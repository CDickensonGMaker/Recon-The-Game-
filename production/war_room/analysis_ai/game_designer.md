# GAME DESIGNER — AI Goal Doctrine (Feel Doctrine), 2026-07-10

Lens: decision rhythm, cover-read vs cowardice-read, animation reads, round-start choreography,
bench honesty. All line numbers verified against the working tree today.

---

## (a) DIAGNOSIS — per Summoner item, with file:line

### 1. "Squad overuses the STRAFE animation"
Three stacked causes — a mapping bug, an alias bug, and a behavior bug:

- **Mapping:** `sprite_state_map.gd:66-71` — in `COMBAT`, ANY horizontal speed > **0.3 m/s**
  that isn't inside the 0.12s firing window resolves to intent `"strafe"`. Direction of travel
  is never consulted. A man closing distance straight at the enemy (enemy_base.gd:1102-1104,
  ally_base.gd:442-443) plays the strafe clip while gliding forward.
- **Alias:** `sprite_state_map.gd:94` maps `"strafe"` → clip `strafe`; the v2 grunt rig has no
  `strafe` clip, so `MODEL_ALIASES` (`sprite_state_map.gd:110`) resolves it to **`run_left` —
  always left, regardless of actual movement direction**. Every moving squadmate in combat is a
  man running left while translating some other way. `strafe_1`/`run_right` exists in the table
  (`:111`) but no caller ever asks for it.
- **Behavior:** combat executors keep velocity perpetually in the 0.3-2.7 m/s band.
  Ally: `ally_base.gd:432-436` re-rolls `strafe_direction` from `[-1,0,1]` (2/3 nonzero) every
  1.5-3.0s and blends it at 0.4 (`:448-450`); combat move speed is 4.5×0.6 = 2.7 m/s. Enemy:
  `enemy_base.gd:1089-1092` rolls `[-1,0,0,1]` (1/2 nonzero) every 0.8-2.0s, blends 0.4
  (`:1118-1124`). The velocity lerps (`:469-473`, `:1129-1133`) leave long decay tails above the
  0.3 threshold, so even "stopping" men flicker into strafe.

Net: in a firefight the dominant on-screen read is crab-walking. The intent funnel has no
concept of "moving with weapon up, facing the threat" (aim-walk) at all — `MODEL_CLIP` maps
`walk` → `run_forward` (`sprite_state_map.gd:93`).

### 2. "Enemy model rotation is off a lot"
**Two writers own yaw and they compound.** `model_actor.gd:246-251` sets the ModelActor's
**local** `rotation.y = atan2(facing.x, facing.z)` — this points the node's **+Z** at the facing
vector (the comment claims the model is authored facing −Z; the math is the +Z convention —
comment and code disagree). Meanwhile the **parent body also rotates**: `enemy_base.gd:1034`
(`look_at(global_position + flat_aim)`) and `ally_base.gd:390` point the body's **−Z** at the aim.
Since ModelActor is a child, world yaw = parent yaw + local yaw. Work the math: parent yaw
θp = atan2(−fx,−fz), child local = atan2(fx,fz) = θp+π, total = **2·θp+π** — the model's facing
error equals the full world yaw of the aim direction. Aiming 30° east of −Z turns the model 60°.
This was invisible in the billboard-sprite era (a billboard doesn't visually rotate with its
parent; `set_facing` only picked the 8-dir frame) and became a real bug the day ADR-001 made
models the default renderer.

Secondary: `facing_dir` is written by two systems with no rate limit — aim (`enemy_base.gd:1035`,
LOS only) and movement (`:1361`) — so facing snaps hard when LOS toggles.

### 3. "Squad seeks cover more than anything else" — the ally 3-branch brain
`ally_base.gd:333-357` is the whole brain. Four thrash loops, all structural:

- **Cover-first re-triggers forever** (`:346-349`): in contact, `not has_cover` → SEEK_COVER —
  and `has_cover` keeps flipping false because combat movement invalidates it. `:456-458`
  releases the claim when the man drifts >2.5m, and `:442-443` actively pulls him off it (range
  closing at 2.7 m/s whenever dist > 14.4m). Loop: reach cover → fight → drift → seek again.
- **Suppression branch ignores existing cover** (`:335-338`): `suppression > 0.6` → SEEK_COVER
  even for a man ALREADY holding cover. `_find_cover_point` offsets start at 2.2m
  (`enemy_base.gd:103-107`), so he always picks a *different* rock — covered men relocate under
  fire. That is the exact "AI coward dance" read.
- **The 2s bail-out thrash** (`:536-538`): SEEKING_COVER times out to IDLE; the very next think
  (0.15s later) re-enters the contact branch → SEEK_COVER again. Search throttle is 1Hz
  (`:516-517`), so a man can ping IDLE↔SEEKING several times between real searches.
- **No dwell, no hysteresis, uniform brains:** the enemy has `goal_timer` 0.5s + 15% incumbent
  edge (`enemy_base.gd:816-821`, `:909-911`); the ally has neither, re-deciding at 6.7Hz. And all
  five allies run identical parameters, so they make the same flip on the same tick — thrash is
  synchronized, which reads 5× worse than one man dithering.

Diagnosis verdict: cover-seeking is the RIGHT read on fresh contact in the open (keep the
doctrine); it becomes the cowardly read when it can **re-trigger during an engagement** and when
**being suppressed in cover causes relocation**. The bug is re-entry, not the instinct.

### 4. "Models constantly switching goal because LOS changed"
Enemy goal scores consume the **instantaneous** LOS boolean: `enemy_base.gd:848` (+0.3 engage),
`:870` (+0.3 suppress), `:878` (+0.3 flank when NO LOS). A ±0.3 step on scores that live in the
0.5-1.0 band exceeds the 15% incumbent edge (`:910-911`) whenever a target strobes a cover edge
at 6.7Hz think — the 0.5s `goal_timer` only rate-limits the flip, it doesn't stop it. The
exposure clock already debounces LOS *for accuracy* (drain at 3×, `enemy_base.gd:773-779`); the
goal layer never got the same treatment. Allies: the `target_last_seen_time < 6.0` window
(`ally_base.gd:346`) is decent debounce, but the state machine thrashes for the reasons in #3.

### 5. "Wave 2 spawns in the wide open"
`gore_lab.gd:237` — `pos = (randf(-16,16), 1, randf(-19,-12))`, pure random, no cover-adjacency
test. Wave ≥2 arrives ALERT with a fuzzy last-known (`:256-259`) but stands on open ground while
its reaction/perception ladder wakes.

### 6. "Whole squad bunched into ONE corner of cover"
Both cover searches sort candidates by **distance-to-self only**: `ally_base.gd:559-560`,
`enemy_base.gd:1444-1445`. The claim broker blocks only the identical 2m cell
(`enemy_base.gd:1374-1382`, `COVER_CELL = 2.0`). Lab allies spawn 1.3m apart in an arc
(`gore_lab.gd:207`) and search from nearly the same origin with the same 12 offsets
(`COVER_SEARCH_OFFSETS`, max 6m) — so the nearest corner wins five times and five men take five
adjacent cells. There is no spacing, no sector, no crowding penalty anywhere in scoring.

---

## (b) FEEL DOCTRINE — commitment, cover, reads, choreography (concrete values)

### B1. Decision rhythm: COMMITMENT QUANTA
A soldier at HLL-real-but-smooth commits to a plan in **seconds**, and *finishes moves he starts*.
Goals may only be reconsidered when (dwell expired) AND (challenger beats incumbent by margin),
OR on a hard interrupt.

| Plan | Committed dwell (no voluntary re-eval) | Notes |
|---|---|---|
| ENGAGE from cover | 3.0s (jitter ±20% per man) | then re-eval window where FLANK/ADVANCE can win |
| ENGAGE in the open | 1.5s | open ground legitimately re-decides faster |
| SEEK_COVER (the rush) | **until arrival**, hard cap 6.0s | a man finishes his rush — never aborts for a better idea |
| ADVANCE (bound) | until bound point, cap 5.0s | keep the existing 0.8-1.6s pause (enemy_base.gd:1270) |
| FLANK | 5.0s | flanks must be visibly carried through |
| RETREAT | 3.0s | |
| INVESTIGATE | 4.0s | |

**Hard interrupts** (the ONLY things that pierce dwell): took damage · suppression crossing 0.7 ·
target dead/invalid · new threat inside 6m · (future) grenade landing nearby. Everything else
waits.

**Hysteresis:** raise the incumbent edge from ×1.15 to **×1.25**. Two gates (dwell + margin),
not one. Keep the 0.5s `goal_timer` as the global tick gate.

**Per-man desync:** allies get rolled `char_aggression` 0.35-0.75 and ±20% dwell jitter at spawn,
so five brains stop deciding in lockstep. Synchronized AI is the loudest tell there is.

### B2. LOS debounce at the goal layer
Goals never read `has_line_of_sight` directly. Replace with **contact confidence** derived from
the clock that already exists:

- `eyes_on   = target_last_seen_time < 1.0`  → use where scores currently add +0.3 for LOS
- `in_contact = target_last_seen_time < 4.0` → gates combat vs search behavior
- LOS regained within 1.5s of loss = same engagement; no state or goal change is permitted.

This mirrors the exposure-ramp philosophy (Fairness Law): brief blinks change nothing; ~1s of
true break changes the fight. Zero new raycasts — it is a re-read of an existing timer.

### B3. Cover doctrine — right read vs cowardly read
**Cover-seeking is HOW you engage, not an alternative to engaging.** The doctrine:

1. **Cover-first, once.** Fresh contact + in the open → one cover attempt inside the first 5s of
   `_contact_time`, max 2 dry searches (both already exist — keep). It does NOT re-trigger later
   in the same engagement.
2. **Arrival locks a HOLD phase:** min **4.0s** fighting from the claimed point before any
   voluntary relocation. Peek cycle while holding: 1.2-2.2s down / 0.8-1.4s up-and-firing (ally
   clip chains at ally_base.gd:99-100 already support this read).
3. **Suppressed + in cover = HUNKER, never relocate.** Fix ally branch 1 to check `has_cover`.
   Relocating under fire is the coward-dance; hunkering + a held peek is the veteran read.
4. **Leash instead of drift-release:** while holding cover, clamp combat movement to a **1.5m**
   radius around the claimed point (replace the >2.5m release at ally_base.gd:456-458 /
   enemy_base.gd:1112-1116). Combat wander must be unable to invalidate cover; release happens
   only on deliberate goal change or cover invalidation.
5. **Cover validity recheck** every 2.0s on the existing 1Hz search timer (1 ray, inside budget):
   if the claimed point no longer blocks LOS to the CURRENT threat (he flanked), cover is invalid
   → legitimate re-seek. This is the one honest re-trigger.
6. **Cowardice budget:** at most `ceil(0.4 × living squad)` members in SEEK_COVER simultaneously
   (broker counts seekers). The 3rd man who wants cover fights instead — bounding overwatch
   emerges for free.
7. **Seeking-cover failure exits to COMBAT, not IDLE** (kills the ally 2s→IDLE thrash at
   ally_base.gd:536-538). Duck-and-dodge fallback keeps its 2s, then he duels in the open.

### B4. Dispersion — the corner-pile fix
Replace the pure distance sort with a scored sort (no new raycasts; reads `_cover_claims` and
squadmate positions only):

```
eff_cost(candidate) = dist_to_self
                    + 6.0 × live_claims_within_4m(candidate)
                    + 3.0 × friendlies_within_3m(candidate)
```
Pick lowest cost among LOS-blocking candidates. Soft penalty, not hard rejection — on a starved
cover field men still stack rather than dance in the open (stacking is the lesser evil).
Minimum claim spacing this produces: ~**4.0m** between claimed points when alternatives exist.

### B5. Animation intent policy — which reads map to which movement
The funnel gains one intent (`aim_walk`) and direction-awareness. Let `v` = flat velocity,
`f` = flat facing, `fwd = v̂·f̂`, `speed = |v|`:

| Condition | Intent | Clip (v2 / v1) |
|---|---|---|
| speed < **0.5** (raised from 0.3 — kills lerp-tail flicker) | `aim` | idle_aiming / rifle_aiming_idle |
| speed ≥ 3.2 (any direction — nobody sprints sideways) | `run` | sprint_forward→run_forward |
| 0.5 ≤ speed < 3.2, `|fwd| ≥ 0.5` (±60° front cone), forward | **`aim_walk`** | run_forward @ **0.55 playback speed** until a real clip is derived (derive_actions.py splice per SPRITE_INTEGRATION_PLAN) |
| same band, backward | `retreat` | run_backward / injured_walk_backwards |
| 0.5 ≤ speed < 3.2, `|fwd| < 0.5` (lateral) | `strafe` — **left/right chosen by sign of `v·(f×UP)`** (run_left vs run_right; today it is always run_left) |

**Intent debounce:** a movement intent must persist **0.25s** before the clip switches
(fire/death/leap exempt). One state map serves both factions — ally passes its real state today
(ally_base.gd:206), keep that.

**Behavior side (matters as much as the mapping):** strafe becomes a *step*, not a gait —
combat lateral bursts fire with probability ≤ 1/3 per roll and last **0.5-0.9s** (~1-2 steps),
not 1.5-3s of crabbing; covered men never strafe (they peek, B3.2). Most of a firefight a man is
STILL — which is also his accuracy bonus (enemy_base.gd:1134), so read and function align.

**Target screen mix during a firefight:** aim ~45% · aim_walk ~25% · run ~15% · fire ~10% ·
strafe **≤5%**. This is the Summoner's verdict as numbers.

### B6. Facing doctrine
**Single-writer rule: exactly one node owns yaw.** Either the body never yaws and ModelActor
sets *world* yaw, or the body yaws and `set_facing` becomes a no-op for models — programmer's
pick, but the double-write at model_actor.gd:246-251 × enemy_base.gd:1034 / ally_base.gd:390 must
die. Feel requirements the fix must meet:
- Model forward == muzzle line whenever firing; error < **5°**. Tracers come from a man visibly
  pointed at you (Fairness Law: the telegraph must be honest).
- Turn rate cap: **540°/s** in COMBAT (snappy but embodied), **180°/s** relaxed — the sentry scan
  (enemy_base.gd:1049-1053) currently snaps facing per-frame; capped it reads as a man sweeping.
- In contact, face the aim even while moving laterally (that is what makes strafe read as
  strafe); out of contact, face the movement.
- Sprite far-LOD keeps its own frame-select convention — verify both renderers with the
  walk-a-circle test (SPRITE_INTEGRATION_PLAN.md:97 warned exactly this).

### B7. Round start — what five men SHOULD do in the first 5 seconds of contact
The beat sheet (this is choreography, enforced by B1-B4, not new systems):

- **0.0-0.4s — REACT.** Aim settle (0.45-0.9s, exists at ally_base.gd:308-309) runs; nobody moves.
- **0.4-1.2s — FACE AND FIGHT.** Face the threat, weapon up, men with LOS fire a first burst
  *standing*. The instant-scatter-on-contact is the corner-pile's twin: both read as insects.
- **1.0s+ — STAGGERED, DISPERSED BOUNDS.** Cover-seek starts are staggered **0.25-0.6s** per man
  (broker hands out slots); at most **2 movers per squad** at once (the rest are the base of
  fire); each rush goes to a dispersion-scored point (B4). A man already within 2m of a
  LOS-blocking point or in deep vegetation just crouches where he is — not every man runs.
- **By 5.0s —** the squad holds a **10-15m frontage arc**, 2-3 firing from cover, 1-2 finishing
  bounds, **no two men within 4m**. That picture IS the doctrine passing.

### B8. Bench doctrine — wave spawns + the real-terrain bench (his next ask)
**Wave spawn placement (`gore_lab.gd:237`):** a spawn candidate must have a LOS-blocking point
within **3.0m** (reuse the 12-offset test against the player's position, ≤6 resamples, then
accept open). Spawn as two fireteams (4+3) around two cover clusters ≥12m apart, 2-4m spacing
inside each, keep the 0.6s stagger. Waves ≥2 arrive with goal **ADVANCE** (bounding) toward
last-known — every 8s respawn becomes a live demonstration of fire-and-maneuver instead of a
shooting-gallery materialization.

**The real-terrain bench must include** (or it cannot test this doctrine honestly):
1. **Uneven ground** — slopes to ~20° + micro-relief: the cover test raycasts at fixed +1.3m
   (enemy_base.gd:1440) and every muzzle/eye height assumes flat ground; terrain is where these
   assumptions break first.
2. **Vegetation concealment cells** — the `_grid.get_vegetation` concealment fallback
   (enemy_base.gd:1200-1205) is live code that the flat lab never exercises.
3. **Engagement band 20-60m** (lab is a 44m box) — the exposure ramp, weapon falloff, and
   aim-walk-vs-run reads all change character past 30m.
4. **One asymmetric axis** — treeline vs open paddy: tests whether cover dispersion and bounding
   pick the honest side, and whether men cross open ground only with covering fire.
5. **Nav-baked obstacles** (2+ huts) — the `_move_toward` nav branch (enemy_base.gd:1349-1357)
   has never run in the lab.
6. **Masked spawn zones** behind terrain — no visible materialization.
7. **Doctrine instrumentation on the HUD** — measure, don't vibe:
   - goal switches / man / minute (target **< 6** in steady contact)
   - mean goal dwell (target **> 2.5s**)
   - % contact time in SEEK_COVER (target **15-25%**)
   - strafe-clip screen share (target **≤ 5%**)
   - PILE METER: max men within a 4m radius (target: never 3+ for > 3s)

---

## (c) WHAT TO CUT / SIMPLIFY

1. **Cut the ally's separate 3-branch brain.** One shared, committed goal evaluator (the enemy's,
   with B1-B3 installed), parameterized per faction. Two brains = two tuning surfaces that drift;
   the Summoner would tune every feel change twice. Minimum viable: allies adopt the enemy
   evaluator with `d_flanks=false`, `personality` rolled, follow as the no-contact goal.
2. **Cut continuous combat strafing as a fidget.** Strafe becomes a rare 1-2 step adjust (B5).
   Delete the always-on strafe blend from covered men entirely.
3. **Cut the ally SEEKING_COVER→IDLE 2s timeout** (thrash root). Commit-until-arrival, cap 6s,
   exit to COMBAT.
4. **Cut the drift-release** (>2.5m) in both files; replace with the 1.5m leash. One mechanism,
   no flip-flop.
5. **Do NOT build:** utility-AI rewrite, combat formations, per-ally personality UI, more than
   one derived clip (aim-walk), or any new per-frame raycasts. The doctrine above is timers,
   thresholds, and one scored sort — it fits the 6.7Hz think budget as-is.

---

## (d) RISKS

1. **Over-commitment reads as stupidity when it kills.** A man finishing a 6s rush into an open
   MG lane will die visibly. Accept — dying mid-rush reads human; dithering doesn't. Mitigation
   is already in the doctrine: damage is a hard interrupt, rush cap 6s.
2. **Passivity creep.** Dwell 3s + hysteresis 1.25 + cover-hold 4s could produce turret squads.
   The hold phase must EXPIRE into a re-eval where ADVANCE/FLANK can win, and the cowardice
   budget keeps ≥60% of the squad fighting. Watch the % SEEK_COVER metric; if > 25%, lower the
   hold, not the hysteresis.
3. **Dispersion on starved cover fields.** 5 men × 4m spacing needs ~15m of frontage; a
   one-rock map can't provide it. The soft penalty (B4) degrades to stacking, never to
   open-ground dancing — verify on the real-terrain bench's paddy side.
4. **Facing fix regression risk is high.** Two renderers (model world-yaw vs billboard
   frame-select), every AI path writes `facing_dir`. The walk-a-circle test on BOTH renderers is
   mandatory; the failure mode (men walking backwards) looks *almost* right.
5. **Aim-walk stand-in quality.** run_forward at 0.55 speed may read as wading. If it does, derive
   the clip (splice job, ~20 min per SPRITE_INTEGRATION_PLAN.md:299) before shipping the intent —
   a bad aim-walk everywhere would be worse than the strafe it replaces.
6. **Intent debounce (0.25s) can lag the first step of a rush.** Exempt the leap/rush overrides
   (`_anim_override` path already bypasses the funnel, ally_base.gd:203-205 — keep that).
