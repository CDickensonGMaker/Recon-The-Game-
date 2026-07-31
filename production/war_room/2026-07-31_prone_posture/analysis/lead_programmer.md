# LEAD PROGRAMMER / TECHNICAL DIRECTOR — PRONE as a third `CombatPosture.Posture`

Read 2026-07-31 against the working tree. Every claim below carries `file:line` or says
"no pointer found — that is the finding" (POINTER LAW).

---

## 0. What `decide()` is today

`scripts/ai/combat_posture.gd:9` — `enum Posture { STAND, CROUCH }`, two values.
`:15-26` — `decide(state, suppression, near_cover) -> int`, five arms and a `_` default,
every arm returning one of the two.

**It is not a posture system. It is a boolean wearing an enum.** That is the whole finding
of section 1, and everything else follows from it.

---

## 1. THE CALL-SITE BLAST RADIUS

### 1a. Direct callers of `decide()` — there are exactly TWO, and BOTH collapse to bool

| # | site | code | what a third value does |
|---|------|------|------|
| 1 | `scripts/enemies/enemy_base.gd:409` | `return CombatPosture.decide(current_state, suppression_level, _near_cover()) == CombatPosture.Posture.CROUCH` | `PRONE != CROUCH` → returns **false** → the man is treated as **STANDING**. No error. No warning. |
| 2 | `scripts/allies/ally_base.gd:378` | identical line | identical: **false → STANDING** |

Both are `func _is_low_posture(_firing: bool) -> bool`. **The return type is `bool`. There is
nowhere for a third value to go.** A prone man does not "fail to be prone" — he is
affirmatively classified as *upright*, which is the worst of the three answers.

**Nothing errors. Nothing warns. The suite stays green.** (Section 7 covers the one test that
would go red, and it is red for a different reason.)

### 1b. Constant-only readers of `CombatPosture` — safe, listed for completeness

These read `CROUCH_SUPPRESS` / `SUPPRESS_PIN` / `COVER_CROUCH_RANGE` and never call `decide()`:
`enemy_base.gd:414`, `enemy_base.gd:1359`, `ally_base.gd:408`, `ally_base.gd:670`,
`ally_base.gd:769`, `ally_base.gd:1053`, `tests/test_low_posture.gd:49-59`,
`tests/test_ally_states.gd:90,131,136,139`. A third enum value does not touch any of them.

### 1c. THE REAL BLAST RADIUS — the eleven `_low_posture` consumers

`decide()` has two callers; **its ANSWER has eleven**, and each one silently does the standing
thing for a prone man:

| site | consumer | what a mis-classified prone man does |
|---|---|---|
| `enemy_base.gd:457` | `_low_posture = _is_low_posture(firing)` | flag set false |
| `enemy_base.gd:459` | `SpriteStateMap.intent_for(..., _low_posture)` | plays **standing** clips (`idle_aiming`, `walk_forward`) — a prone man standing up on screen |
| `enemy_base.gd:626-631` | `CROUCH_SPEED_CAP` gate | **no speed cap** — he crawls at 4.0–4.4 m/s |
| `enemy_base.gd:638` | `AudioManager.play_step_3d(pos, _low_posture)` | **loud** footsteps from a man on his belly |
| `enemy_base.gd:2263` | `if not _low_posture: _stumble_until_ms = ...` | fires `stumble_hit`. The comment at `:2261-2262` says exactly why this is wrong: *"a man already crouched or crawling has nowhere to fall, and the clip would launch him upright."* **The guard that exists to prevent this is the guard PRONE defeats.** |
| `enemy_base.gd:2596` | `if ... and _low_posture: play("death_crouching_headshot_front")` | skipped — a prone man plays a **standing** death and the `settle_flat_corpse` span check (`model_actor.gd:791`) then topples him with a random-yaw `_lay_flat()` |
| `ally_base.gd:446` | flag | false |
| `ally_base.gd:451` | intent funnel | standing clips |
| `ally_base.gd:524-529` | speed cap | none |
| `ally_base.gd:536` | footstep volume | loud |
| `ally_base.gd:1451` | crouch-death pick | skipped |

**Which ones silently do the WRONG thing rather than erroring: ALL ELEVEN.** Not one of them
raises, logs, or degrades visibly. The failure signature is "a prone man behaves exactly like a
standing man, at 4 m/s, loudly" — which reads to a playtester as "prone isn't implemented yet"
rather than "prone is implemented and broken." That is a debugging cost, not a bug.

### 1d. The funnel below is also two-valued

`SpriteStateMap.intent_for(...)` takes `low_posture: bool` (`sprite_state_map.gd:34`) and
branches once (`:40`). `_to_crouch()` (`:99-122`) maps every standing intent to a crouch clip.
**There is no `_to_prone`, and `MODEL_CLIP` (`:127-147`) contains no prone entry.** So even if
`_is_low_posture` were widened to return the enum, the intent funnel would still need a third
branch and a sixth-through-tenth `MODEL_CLIP` row. `SpriteStateMap.LOW_POSTURE_SPEED_MAX = 2.6`
(`:25`) is the kinematic backstop; a prone speed band would need its own, far lower.

### VERDICT ON SECTION 1
The API surface to change is small (2 functions) and the behavioural surface is large (11 sites
+ the whole intent funnel). **The correct move is to change the RETURN TYPE, not add a value to
the enum.** `_is_low_posture() -> bool` must become `_posture() -> int`, and every one of the
eleven sites must be re-read as a three-way. If we add `PRONE` to the enum and leave the two
`== Posture.CROUCH` comparisons standing, we have shipped a lie in the map (FOSSIL LAW, ADR-023):
an enum value that reads as load-bearing and is discarded at both call sites.

---

## 2. COLLISION / CAPSULE — does crouch change the body shape today?

**NO. Not for AI. Not at all.**

`scripts/enemies/enemy_base.gd:2695-2701`:
```
var col := CollisionShape3D.new()
var shape := CapsuleShape3D.new()
shape.radius = 0.4
shape.height = 1.8
col.shape = shape
col.position.y = 0.9
```
Built once in `spawn_enemy()`. `grep Capsule|Collision|shape` over the whole 2,700-line file
returns **only** `:391` (a debug `CapsuleMesh`) and `:2695-2699`. **Nothing mutates it, ever.**
`ally_base.gd` has no `CollisionShape3D` construction at all — no pointer found for an ally body
capsule in script; that is a finding of its own (allies get their shape from a scene, unverified
here).

**So a crouching AI today is already a 1.8m collider in a 1.1m pose.** Prone would make him a
1.8m collider in a 0.35m pose — a man lying down who still blocks a doorway at head height,
still stops a bullet at 1.6m, and still shoulders his neighbours aside through `move_and_slide`.

**The player DOES do it** — `scripts/player/player.gd:1689-1704`, `STAND_HEIGHT 1.8`
(`:19`) / `CROUCH_HEIGHT 0.9` (`:20`) / `PRONE_HEIGHT 0.5` (`:64`), lerped every frame at
`:1701` with `collision_shape.position.y = capsule.height / 2.0` at `:1702`. **So the mechanism
exists and is proven — on ONE body.**

### The trap in copying it
`player.gd:1701` mutates a `CapsuleShape3D` **resource** every physics frame. For one player that
is invisible. For 70 AI bodies it is 70 physics-server shape updates per frame landing in the
`ai_usec_move` bucket, which `PERF_LEDGER.md:296` already measures at **9.06 ms/physics-frame**
— the second-largest AI cost in the game. Do NOT lerp AI capsules. Set the height **once** on
posture entry and **once** on exit (two writes per transition, not 120/second).

Second trap: `player.gd:1690-1692` lets crouch and prone fight each other and resolves it with
two mutually-clobbering assignments in three lines. That is a two-flag state machine, and it is
already the reason `is_crouching`/`is_prone` need `not is_prone` guards at `:1690`, `:1624` and
`:1671`. **Do not reproduce a flag pair on the AI. One `int` posture, one owner.**

---

## 3. HITZONES — bone-driven or hardcoded?

**Two answers, and the split is the finding.**

### AI with a model rig: BONE-DRIVEN. Prone is free.
`scripts/combat/hitzone_builder.gd:197-234` (`sync`) positions every zone from
`skel.get_bone_global_pose(bi).origin` (`:217`, `:221`) and orients it down the live
joint-to-joint line (`:225-232`). Hull points are harvested once against **rest** bones
(`_rest_frames`, `:456-486`) and cached per unit (`:242-291`), so the cache is pose-independent
and correct in any pose.

**A prone man's head zone follows his head to knee height automatically. No work required.**
This is the one part of the system that already handles prone correctly, and it handles it
because it was built to ride bones rather than offsets.

Two riders:
- `hitzone_builder.gd:168-173` — the `skeleton_updated` re-sync is **distance-gated at 40m**
  (`1600.0` squared). Past 40m zones update only on the physics tick, and only when
  `_body_hot` (`enemy_base.gd:578-579`). A prone man past 40m in a **gated** body
  (`_body_gate_open()`, `:647-662`) re-syncs at the **300 ms heartbeat** — his zones can be up
  to 300 ms stale. Standing, that is centimetres. Going prone, the pose delta is ~1.4 m of head
  travel, so for up to 300 ms his head zone is **in the air where he used to be**. Fire at a man
  the instant he drops and you hit a ghost head. This is a real, new, silent hazard.
- Nothing in the hitzone path reads posture, so **no code change is needed here** — which means
  nobody will look at it, which is precisely why the staleness above needs writing down.

### Player and rigless units: HARDCODED OFFSETS, and this is a LIVE BUG TODAY
`scripts/player/player.gd:1179` — `HitzoneBuilder._build_static(self, 32, 16, ["hitzone"], true)`.
`hitzone_builder.gd:580-615` — hardcoded bands: `HEAD` at `Vector3(0, 1.65, 0)` (`:582`),
`BODY` at `1.3` (`:589`), `GUT` at `0.85` (`:590`), legs at `0.4` (`:585-586`). `col.position`
is set once at `:609` and **never re-read**.

**The player already goes prone** (`player.gd:1553-1554`, capsule to 0.5m at `:1695`) **and his
hitzones stay at standing height.** His head hurtbox floats at 1.65 m over a body lying at 0.35 m.
`Hitzone.zone_name_is_fatal` (`hitzone.gd:92-93`) makes HEAD an instant kill for everyone
(the 2026-07-27 faction-blind ruling), so this is a fatal zone sitting in empty air —
and a prone player's real skull sits inside the *LEG* band. `civilian.gd:205` has the same
static build; civilians do not go prone, so they are unaffected.

**This is not caused by the proposed change. It is a pre-existing defect the proposed change
will get blamed for**, and under the drift law ("correct it on contact") it should be named in
the same decree.

---

## 4. THE TRANSITION CLIPS — sequencing, and what happens when he is shot mid-transition

### 4a. Loop flags: the four clips already resolve correctly, by luck and by list
`model_actor.gd:336-355` `_LOOP_NAMES` already contains **`"prone_idle"` and
`"prone_firing_rifle"`** (`:341`), with the comment at `:339` naming exactly why
(`"prone_idle" does not start with "idle"`). So those two loop.

`crouch_to_prone` and `prone_to_crouch` are **not** in `_LOOP_NAMES`, and
`_apply_loop_modes():367` skips any clip containing `"_to_"`:
```
if nm.contains("turn") or nm.contains("_to_") or nm.contains("jump"):
    continue
```
So both transitions stay **play-once**, correctly, with no code change. **Do not add them to
`_LOOP_NAMES`** — a looping `crouch_to_prone` is a man doing push-ups forever.

glTF ships no loop flag (`:328-331`), so a one-shot **freezes on its last frame**. That is the
whole hazard: an over-long window leaves a statue, an under-long window snaps.

### 4b. The sequencing contract — copy `cover_to_stand`, it is the proven pattern
The codebase already solved this exact problem once, for the crouch↔stand transition. The
pattern, in full:

- **Window, not state.** `enemy_base.gd:1855` / `ally_base.gd:1249`:
  `_cover_exit_until_ms = now + (clip_length("cover_to_stand") or 0.8) * 1000.0`.
  The window is sized from `ModelActor.clip_length()` (`model_actor.gd:929-939`, alias-resolved),
  so it can never outlive the clip and can never freeze a statue.
- **Self-clearing, and the comment says why.** `enemy_base.gd:427`:
  *"Self-clearing window - no `_anim_override`, so no 'frozen crouch statue' leak."* A latched
  `_anim_override` (the ally cover path, `ally_base.gd:230,440-443`) is the failure mode being
  avoided.
- **Highest priority in `_update_sprite`, early-return.** `enemy_base.gd:428-430` — it runs
  before stumble, throw, work-clip, camp-role and the whole state map.
- **Replayed every frame without `restart`.** `play("cover_to_stand")` with `restart=false`;
  `ModelActor.play():887-888` no-ops when the clip is already current, so the every-frame call is
  free and the clip runs to its natural end.
- **Debounced.** `COVER_EXIT_DEBOUNCE_MS = 1500.0` (`enemy_base.gd:177`) + `_last_cover_exit_ms`
  (`:171`), so posture thrash cannot stutter a perpetual half-rise.
- **Body pinned hot.** `_body_gate_open():650-651` returns true during the window — otherwise the
  body gate would sleep a man mid-transition and freeze him at whatever frame he was on.

### 4c. THE PRESCRIBED SEQUENCE

```
GOING DOWN
  posture flips STAND/CROUCH -> PRONE
  _prone_enter_until_ms = now + clip_length("crouch_to_prone")*1000   (fallback 1.1s)
  _update_sprite: window open -> play("crouch_to_prone"); return      (above stumble/throw/state map)
  _body_gate_open(): return true while the window is open             <-- MANDATORY
  velocity hard-zeroed while the window is open                       <-- MANDATORY, see below
  collision capsule height set ONCE, at window CLOSE, not at open     (see 4e)

HOLDING
  posture == PRONE, no window -> play("prone_idle") / ("prone_firing_rifle" when firing)
  both already loop (model_actor.gd:341). No further work.

GETTING UP
  posture flips PRONE -> CROUCH/STAND
  _prone_exit_until_ms = now + clip_length("prone_to_crouch")*1000    (fallback 1.1s)
  same treatment; capsule restored at window OPEN (grow early, shrink late — never
  spawn a man inside geometry)
  debounce >= 1500ms shared with the cover-exit debounce, or a man at the CROUCH_SUPPRESS
  boundary (combat_posture.gd:11, 0.6) oscillates prone/crouch at the think rate
```

**The mandatory velocity zero has no precedent in the codebase and that is the point.**
`cover_to_stand` does **not** zero velocity — a man can slide while playing it, and that is an
accepted artifact because a stand-up is 0.8s and roughly vertical. `crouch_to_prone` is a body
falling forward ~1.4 m; a man sliding at 4 m/s through it is a torpedo. And the existing
`CROUCH_SPEED_CAP` machinery cannot help: it is applied **only** `if _low_posture`
(`enemy_base.gd:626`, `ally_base.gd:524`), which is exactly the flag PRONE fails to set
(section 1c).

### 4d. SHOT MID-TRANSITION — three concrete failures

1. **Stumble stomps the transition.** `enemy_base.gd:432-434` runs the `stumble_hit` window,
   but it sits **below** the cover-exit early-return at `:428-430`. A prone-entry window placed
   at the same priority means stumble never plays — acceptable. Placed *below* stumble means
   `crouch_to_prone` is interrupted at frame N and `stumble_hit` plays from a half-fallen pose:
   the **action-bleed teleport** class. `_update_sprite`'s `play()` uses a `0.18s` crossfade
   (`model_actor.gd:914`) and the phase-preservation seek at `:915-918` applies **only when both
   clips loop** — a one-shot→one-shot switch starts at frame 0, so the blend is from
   half-prone to standing-stumble-frame-0 and the man visibly snaps upright and back.
   **Put the prone windows at the SAME priority as cover-exit (above stumble), and gate the
   stumble on posture too** — the guard at `:2263` (`if not _low_posture`) already encodes the
   intent and must be widened to `if posture == STAND`.
2. **Death mid-transition strands the pose.** `_die()` (`enemy_base.gd:2570-2613`) tries ragdoll
   first (`:2578-2580`). `ModelActor.start_ragdoll()` calls `stop_anim()` **only after** proving
   the bones bind (`:713-717`) — that guard is sound. But if the ragdoll slot is unavailable
   or bones do not bind, it falls through to a **standing** death clip (`:2586-2599`), because
   the `_low_posture` crouch-death branch at `:2596` is false (section 1c). Then the 1.5s
   `settle_flat_corpse` timer (`:2609-2613`) measures `_pose_span_y()` and, seeing a corpse
   already flat, **skips** `_lay_flat()` — so a man killed mid-`crouch_to_prone` freezes at the
   frame he died on, at whatever angle, because a play-once clip holds its last frame and
   `settle_flat_corpse` thinks the job is done. **Silent, and it looks like a physics bug.**
3. **The window outlives the man.** Nothing clears `_cover_exit_until_ms` on death today; it is
   harmless because `_update_sprite` early-returns on `DEAD` at `:424-425`. Prone windows must
   sit **below** that same DEAD/surrendered/downed guard. If they are placed above it, a corpse
   stands up and lies down again.

### 4e. Why the capsule is resized at the *end* of the fall and the *start* of the rise
Shrinking early drops him through nothing (he is already on the floor); growing late spawns a
1.8m capsule inside whatever he crawled under. Asymmetric on purpose. `is_on_floor()` gravity
(`enemy_base.gd:605-606`) is unaffected either way.

---

## 5. NAVIGATION — can a NavigationAgent-driven body move while prone?

### The actual mechanism
`NavRouter.step(from, to)` (`scripts/ai/nav_router.gd:57-122`) returns an **unnormalised
direction vector only** — `agent.get_next_path_position() - from` (`:92`) or the direct vector
(`:63`). It owns no speed: the header states it outright (`:7-8`), *"Locomotion stays with the
caller: speed, suppression, facing and the velocity lerp differ per class."*
Speed is applied by the caller — `enemy_base.gd:1785-1791` (`_move_toward`), and the per-state
`velocity.x = move_dir.x * move_speed * _suppression_move_mult()` lines at `:1646-1647`,
`:1661-1662`, `:1730-1731`, `:1773-1775`.

**So yes — a prone body can move, trivially, by scaling that multiplier.** Nav does not object;
nav does not know.

### What breaks when speed is capped near zero — three things, all silent

1. **THERE IS NO PRONE LOCOMOTION CLIP.** The four named clips are `prone_idle`,
   `prone_firing_rifle`, `crouch_to_prone`, `prone_to_crouch`. **None is a crawl cycle.**
   `ModelActor._CLIP_SPEED` (`model_actor.gd:943-954`) lists authored ground speeds for every
   locomotion loop; no prone entry exists, so `set_locomotion_speed()` (`:959-966`) takes the
   `else` branch and sets `speed_scale = 1.0`. **A prone man moving at any speed plays a
   stationary clip and ICE-SKATES on his belly** — the exact defect the crouch work was created
   to fix (`enemy_base.gd:172-176`). `wounded_crawl` exists at 0.8 m/s (`:951`) but it is the
   **crippled** clip (`sprite_state_map.gd:135`) and stealing it makes every prone man read as
   wounded.
   **Therefore: PRONE MUST BE A STATIONARY POSTURE.** Not a design preference — an art
   constraint the code cannot paper over.
2. **The stuck watchdog goes blind.** `enemy_base.gd:200-207`: `wants_move` requires
   `Vector2(velocity.x, velocity.z).length() > 1.0`. A prone man capped below 1.0 m/s **never
   trips the watchdog**, so a prone man wedged in geometry is stuck forever with no sidestep and
   no log. Add an explicit "prone men do not path" rule rather than relying on a threshold that
   was tuned for walking men.
3. **The nav agent's own dimensions are an INVARIANT — do not touch them.**
   `enemy_base.gd:2706-2709` states it in the source:
   *"INVARIANT: these must match NavBaker's AGENT_RADIUS / AGENT_HEIGHT, or the agent walks
   corridors the navmesh never carved."* Lowering `nav.height` for a prone man makes him path
   through gaps the navmesh was never baked for, and he will walk into a wall — the same class
   of failure the 2026-07-29 garrison freeze came from (`nav_router.gd:96-101`). **Prone buys
   ZERO new traversal.** Anyone who proposes prone-crawling under wire is proposing a re-bake.

---

## 6. PERFORMANCE — does a third posture cost anything per frame?

### Where the money is (measured, `production/PERF_LEDGER.md:295-303`, 65+ live units)
| bucket | ms/physics-frame |
|---|---:|
| think | 1.28 |
| move_and_slide | 9.06 |
| hitzone sync | 10.43 |
| **anim / execute remainder** | **19.04** |
| SUM | **39.8** |

*"perception rays + think are ~6% of it ... The wall is the BODY."* The body is ~**94%**.

### The decision itself: free
`decide()` is a `match` with five arms and no allocation. Adding a sixth arm is nanoseconds.
It is called once per body per frame from `_update_sprite` (`enemy_base.gd:457`), which runs
from `_execute` (`:1386-1387`) only when `_body_hot`. **Zero measurable cost. Do not let anyone
argue the enum is the perf question.**

### What ACTUALLY costs, in the most expensive bucket in the game
1. **Every new branch in `_update_sprite` lands in the 19.04 ms anim bucket.** Two new window
   checks (`_prone_enter_until_ms`, `_prone_exit_until_ms`) are two `float` compares per body per
   frame — negligible **if** they are compares. If anyone reaches for `has_animation()`,
   `clip_length()` or a `play_first([...])` array literal per frame, they have allocated in the
   hot loop. `clip_length()` walks `MODEL_ALIASES` (`model_actor.gd:929-939`) — **call it once,
   at window open, exactly as `enemy_base.gd:1854` already does.**
2. **A per-frame capsule lerp would land in the 9.06 ms move bucket** (section 2). One write per
   transition, not 120 per second.
3. **The body gate must pin prone-transitioning men hot** (`_body_gate_open`), which by
   construction *removes* them from the gated population. `PERF_LEDGER.md:364-371` measures the
   gate's payoff at **9.4% gated** at hub start — small already. Pinning is correct and it is a
   real, if small, cost. Name it.
4. **The 300 ms hitzone staleness of section 3** is a *consequence* of the body gate, and the
   only honest mitigation (pin prone men hot) costs exactly what item 3 costs.

**No new per-frame cost is required. Every plausible way to implement this badly adds cost to
the two most expensive buckets in the game.**

---

## 7. TESTS — what turns red, and what stays green when it should not

- `tests/test_low_posture.gd:49-59` asserts the module contract directly. Rows `:52-57` and
  `:59` survive a third value **unchanged** (they pass `suppression = 0.0`). **Row `:58`,
  `decide(ADVANCING, 0.7, false) == CROUCH`, goes RED the moment a `PRONE_SUPPRESS` threshold is
  introduced at or below 0.7.** That is the correct behaviour of a good test and it is the
  cheapest early warning we have — do not "fix" it by moving the threshold.
- `tests/test_low_posture.gd:144` and the ally rows at `:147-151` assert `_is_low_posture()`
  returns a **bool**. Changing that signature to `-> int` turns them red **at compile**, which is
  the loud failure we want and the reason to change the signature rather than the enum alone.
- `tests/test_ally_states.gd` touches only `SUPPRESS_PIN` — unaffected.
- **`tests/test_fossils.gd` will NOT catch an unused `PRONE`.** `_check_file` (`:240-245`)
  compiles regexes for `const`, `signal` and `func` only — **enum members are not scanned.** So
  a `Posture.PRONE` that both call sites discard is invisible to the fossil probe. It *will*
  catch a new unused `const PRONE_SUPPRESS`. **The machine that exists to stop exactly this
  class of lie has a hole precisely where this change lands** — no pointer found for any
  enum-member fossil check; that is the finding.

---

## 8. WHAT IS SACRIFICED (no free lunches)

- **The two-value guarantee.** `_is_low_posture() -> bool` is a contract eleven sites rely on. It
  becomes a three-way, and every one of those eleven becomes a place a future fourth posture can
  be silently dropped. We are trading a provably-total boolean for an enum that needs discipline
  at every consumer.
- **A shared crouch/prone contract, or a forked one.** `combat_posture.gd:2-3` exists so
  *"the contract can never drift between"* factions. Three postures × two factions × eleven
  consumers is where that drift will start, and the file's own reason for existing is the
  warning.
- **AI mobility.** Section 5 makes prone stationary. A prone squad is a squad that cannot
  manoeuvre — Pillar 1 ("AI that fights like soldiers") cuts both ways: soldiers do go prone, and
  soldiers do get up and move. We are buying the first half only.
- **Body-gate savings on every prone man**, for the whole transition window, and arguably for the
  whole prone hold if we want honest hitzones.
- **Player parity is now overdue, not optional.** Section 3 exposes that the player's prone
  hitzones are wrong today. Ship AI prone and the asymmetry ("the AI goes prone properly, I go
  prone and get headshot through my knees") becomes a Fairness-Law complaint.

---

## 9. THE MINIMUM HONEST CHANGE SET

1. `combat_posture.gd` — add `PRONE` to the enum **and** the threshold that produces it.
2. `enemy_base.gd:408-409` + `ally_base.gd:377-378` — `_is_low_posture() -> bool` **DELETED**,
   replaced by `_posture() -> int`. Deleting it is FOSSIL LAW (ADR-023), not tidiness: leaving a
   bool helper beside an int one is the two-things-that-look-the-same failure the law names.
3. All eleven `_low_posture` consumers (section 1c) re-read as three-way, `enemy_base.gd:2263`
   and `:2596` / `ally_base.gd:1451` first — they already encode "he is low" intent.
4. `sprite_state_map.gd` — a `_to_prone()` beside `_to_crouch()` (`:99`), prone rows in
   `MODEL_CLIP` (`:127`), and a prone speed backstop beside `LOW_POSTURE_SPEED_MAX` (`:25`).
5. Two windows + two debounces + two body-gate pins, modelled line-for-line on the cover-exit
   pattern (`enemy_base.gd:168,171,177,428-430,650-651,1849-1856`).
6. Capsule height set **once per transition**, never lerped (section 2).
7. `hitzone_builder.gd:582-590` static bands — **out of scope for AI, in scope for the drift
   law.** Name the player defect in the decree even if it is not fixed in this change.
