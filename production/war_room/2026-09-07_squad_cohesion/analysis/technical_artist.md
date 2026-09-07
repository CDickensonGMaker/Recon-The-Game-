# TECHNICAL ARTIST / ANIMATION LEAD — Phase 3 analysis
**War Room 2026-09-07 · the Summoner's reshaped question**

> *"for the demo im not worried about the rotation effect of the squad AI. i just want realistic
> feeling and looking combat coming from both the allied npcs and the enemy npcs. right now its
> like 60 percent there, but not as smooth looking as a call of duty 1 or brothers in arms"*

He is not describing an AI defect. Phase 1 proved the decisions are real. He is describing the
**rendering of those decisions**. This analysis is a code and disk audit of what the bodies do.

---

## THE HEADLINE

**The animation system is not primitive. It is asymmetric and half-wired.**

`model_actor.gd` already does the things a naive build gets wrong: a 0.18 s crossfade on every
`play()` (`:1034`), cycle-phase preservation across loop-to-loop switches so feet stay on the beat
(`:1035-1039`), ground-speed-matched playback (`set_locomotion_speed`, `:1079`), and a damped
frame-rate-independent yaw at the single yaw owner (`set_facing`, `:966`). `enemy_base._update_sprite`
adds a 180 ms intent stability filter, a turn-rate intent, prone drop/rise one-shots, a cover-exit
one-shot, a grenade windup, a stumble, and a 450 ms arrival beat.

**None of that is the problem.** The problem is that this machinery is **wired on one side of the
fight and not the other**, and that the single most-played transition in the game crossfades between
two poses measured **76 degrees apart**.

Library on disk: `assets/shared/anim_library.glb`, **232 clips** (the docs still say 163/209).
Several of the clips the combat needs most are in there with **zero callers**.

---

## RANKED DEFECTS

### 1. The rifle-ready start poses are up to 76 degrees apart — REAL DEFECT — CLIPS — 1-2 art-days — MEASURED ALREADY
`ANIM_WISHLIST.md` B1 carries the measurement: `idle_aiming` is 37.6 deg off `idle`, **`firing_rifle`
is 76 deg off**, `reloading` 69 deg. `ModelActor.play()` crossfades these in 0.18 s. Every single shot
in the game is an `aim -> fire -> aim` round trip through a 76-degree upper-body swing, twice, blended
over about a tenth of a second. That is a **whip**, and it is the highest-traffic transition in the build.

This is the one that reads as "not CoD1". CoD1 and BiA both hold a canonical rifle stance and never
leave it; our men re-shoulder the weapon on every trigger pull.

Fix is clip surgery, not new motion: repose frames 1-3 of `idle_aiming`, `firing_rifle`, `reloading`
and the crouch/prone equivalents toward one shared stance. The worklist already exists.
**This is the single highest-value art day available.**

### 2. There is NO upper-body aim layer at all — REAL DEFECT — CODE — 0 art-days
Grep across `scripts/` for `SkeletonModifier3D`: **two hits, `flinch_modifier.gd` and gib bone-scaling.**
There is no look-at, no aim IK, no additive layer, no spine yaw.

Aiming is done by rotating the **whole actor** (`set_facing`, one global yaw). Legs, hips, torso and
weapon are one rigid unit. A man tracking a target across 90 degrees while standing plays `turn_left`
(and only if he is IDLE — see #12); while moving he simply pivots his entire body. There is no
separation between where his feet are going and where his gun is pointing. That is the exact thing
that separates a modern-reading soldier from a PS1 turret.

`FlinchModifier` **proves the pattern works on this rig**: it is a `SkeletonModifier3D` that finds
`mixamorig_Spine1` and adds a rotation over whatever clip is playing. An aim-yaw modifier is the same
50 lines with a different input and a clamp (about +/-45 deg, decaying to zero when the delta exceeds
it so the legs catch up). **Zero art-days. Biggest single visual return of any code item here.**

### 3. Allies never flinch and never stumble — REAL DEFECT — CODE — 0 art-days — FULLY BUILT, ONE SIDE UNWIRED
`enemy_base.gd:2653` calls `sprite_actor.flinch(last_hit_dir, ...)` and `:2660-2664` runs the
pain-quota `apply_stagger` plus a 500 ms `stumble_hit` window.

`ally_base.take_damage` (`:2185-2210`) does **none of it**. It sets `last_hit_zone`, computes
`last_hit_dir`, adds suppression, and returns. No flinch. No stagger. No stumble. An ally absorbs a
round with his aiming pose completely undisturbed.

Half the men on screen — and the half the player watches hardest, because they are his — take fire
like mannequins. `FlinchModifier` is built, capped, perceivability-gated and shipping. **This is six
lines.** Ally `_update_sprite` also has no `_stumble_until_ms` branch, so add that with it (~15 lines).

### 4. The suppression hunker is authored, and the code deletes it at the moment it is needed — REAL DEFECT — CODE — 0 art-days — HALF-BUILT
`SUPPRESSED` -> intent `"cover"` -> `MODEL_CLIP["cover"] = "kneeling_pointing"`. A pinned man plays a
**kneeling AIM pose**. He is not ducking, not hunkering, not covering his head. The number changes,
the body does not.

`cover_kneel_brace` and `cover_peek` **are in the library**. They are reachable only through
`ally_base.COVER_HOLD_CLIPS` / `COVER_PEEK_CLIPS` — and `_execute_suppressed` (`ally_base.gd:1712`)
**explicitly clears `_anim_override`** with the comment *"the pin hunker outranks any latched cover
pose"*, which is precisely backwards: it drops the brace and falls through to `kneeling_pointing`.

`ANIM_VARIETY_PLAN.md` calls `cower_under_fire` *"the one genuine gap with neither art nor code."*
**That is refuted.** The art exists. Only the wiring is missing.

Fix: `"cover"` resolves to `cover_kneel_brace` above `SUPPRESS_PIN`, and the peek chain drives the
return-fire beat. Both factions, in `sprite_state_map`. **Zero art-days.**

### 5. Cover entry is gated behind a wall raycast that fails in jungle — REAL DEFECT — CODE — 0 art-days — HALF-BUILT
`ally_base.gd:1746`:
```
_anim_override = _pick_cover_arrival_clip() if _wall_within(1.2) else ""
```
`_wall_within` raycasts **layer 1 world geometry only**. Vegetation cover, terrain cover
(`_terrain_cover01`), and the felled-log low cover that `CombatPosture` was specifically extended for
all return **false**. In a Vietnam firebase-and-treeline fight most cover is not a wall — so the
authored `stand_to_cover` / `_2` / `_3` variants and the rationed `falling_to_roll` dive are skipped
and the man **snaps from a sprint into a crouch in 0.18 s**.

The whole per-man variant table, the squad-wide roll window, the deterministic hash, the
clip-length-sized window — all of it built, all of it bypassed on the most common cover in the game.

### 6. Enemies have NO cover craft whatsoever — REAL DEFECT — CODE — 0 art-days
`STAND_COVER_CLIPS`, `COVER_HOLD_CLIPS`, `COVER_PEEK_CLIPS`, `_pick_cover_arrival_clip`, the dive-roll
and `_wall_within` **exist only in `ally_base.gd`**. `enemy_base.gd:1947-1948` reaches cover and does:
```
_moving_to_cover = false
has_cover = true
```
No arrival clip, no hold pose, no peek. The VC/NVA sprint to a rock and instantly become a crouching
statue that occasionally fires. The Summoner named the enemy NPCs explicitly. **This is the largest
single ally/enemy asymmetry in the build**, and the code to fix it is already written on the other side.

### 7. Allies have no arrival beat — REAL DEFECT — CODE — 0 art-days — HALF-BUILT
`_arrive_until_ms` and the `"arrive"` -> `run_to_stop` intent exist **only in `enemy_base.gd:682-690`**.
An ally decelerates from 4.2 m/s and plants into `idle_aiming` through one 0.18 s crossfade. The
`run_to_stop` clip is in the library, mapped in `MODEL_CLIP`, and has zero callers outside the enemy
path. ~10 lines, copied verbatim.

### 8. The exporters strip hip sway — every gait reads "on rails" — REAL DEFECT — EXPORTER + REBAKE — 1-2 days
`ANIM_WISHLIST.md` C2: the five exporters delete hips **lateral** motion along with root travel, to
make clips in-place. The weight shift goes with it. Thirty-one locomotion clips, all with dead-straight
hips — men glide along their path with no body roll. This is a large part of the "not smooth" read and
it is invisible in any single frame.

Fix is a detrend (subtract the travel component, keep the sway) plus a full library re-export and
re-verify. C1 (`export_anim_slide_to_zero=True`; every clip currently starts at t=0.033 s) rides along.

### 9. Speed matching has holes that make feet skate — REAL DEFECT — CODE — 0 art-days
`set_locomotion_speed` clamps to **0.6-1.4x**, and — the bigger problem — a clip **absent from
`_CLIP_SPEED` resets `speed_scale` to 1.0**, i.e. no matching at all. Missing from the table:
`sprint_backward/left/right` and all sprint diagonals, all four `walk_crouching_*_left/right`
diagonals, `run_to_stop`, and **every `__smg` weapon-family variant** (`run_forward__smg`,
`walk_forward__smg`, `sprint_forward__smg`). Every SMG carrier in the game — a large share of the VC —
runs with **zero speed matching**.

Also: a suppressed man is throttled to `move_speed x 0.05` (`_suppression_move_mult`). Against
`walk_crouching_forward`'s 1.3 m/s reference that wants 0.16x; the clamp holds it at 0.6x, so a pinned
man's legs churn nearly **four times** his ground speed. Fill the table, widen the low clamp to ~0.35.

### 10. NPCs never reload — REAL DEFECT — CODE — 0 art-days — CLIP ALREADY AUTHORED
`reloading` and `reloading__smg` are in the library. Grep for callers: **`scripts/levels/gore_dummy.gd`
only** — a test scene. No NPC on either side has an ammo count (`enemy_base.gd:2469`: *"round costs
cadence, not ammo"*), so no NPC ever reloads.

A firefight where nobody ever reloads has no breathing. In BiA and CoD1 the reload is the beat that
makes fire feel finite and gives the player his window. This does not need a magazine system — a
cosmetic reload window every N bursts, latched exactly like `_throw_until_ms`, buys the whole read.

### 11. `aim_walk` plays the patrol walk — REAL DEFECT — CLIPS — 1 art-day — BENCH FIRST
`MODEL_CLIP["aim_walk"] = "walk_forward"`, with the comment *"dedicated aimed-walk clip on the art
wishlist"*. The entire 0.5-3.2 m/s combat movement band — the advance, the bound, the reposition —
plays the relaxed patrol walk. Wishlist A6 says check in bench first, and that is correct advice: it
may read acceptably. If it does not, this is one clip.

### 12. Turn-in-place is IDLE-only; the 90-degree pivots stay unwired — REAL DEFECT — CODE — 0 art-days, real work
`sprite_state_map.intent_for`: `if intent == "idle" and absf(turn_rate) > TURN_RATE_MIN`. Deliberately
narrow, and the stated reasoning is sound (a man tracking a target should keep aiming, not shuffle).
But it means **a man in COMBAT who changes facing slides his feet**, and combat is where the camera is.
With an upper-body aim layer (#2) this mostly dissolves: the torso tracks, the legs step when the
delta exceeds the clamp.

`turn_90_left/right` and `crouching_turn_90_left/right` carry **-161.6 / -143.7 degrees of measured
ROOT yaw** and are correctly refused by the looping path. They want the one-shot latch mechanism the
prone drop/rise already implements. `NPC_ANIM_GAPS.md` ranks this #1 open and that ranking holds.

### 13. Mixed velocity authority — hard sets against lerps — REAL DEFECT — CODE — 0 art-days
`_move_toward` lerps velocity at `delta * 8.0` on both sides. But the duck-and-dodge and flank paths
**hard-set** it: `enemy_base.gd:1982-1983, 1997-1998` and `ally_base.gd:1785-1786` assign
`move_dir * move_speed` outright — 0 to 4.2 m/s in a single frame, with an instant direction reversal
when `strafe_direction` flips. The intent filter smooths the clip choice; nothing smooths the body.
Route these through `_move_toward`'s lerp.

### 14. No avoidance anywhere; enemies have no separation — REAL DEFECT — CODE — 0 art-days
`avoidance_enabled = false` at three explicit sites (`ally_base:2410`, `enemy_base:3175`,
`civilian:335`) — a deliberate frame-budget call, not an oversight. Allies get a soft 3 m separation
push (`_refresh_separation`, `COMBAT_SPACING_M`) that is combat-only. **Enemies get nothing**: they
interpenetrate, shoulder-check, and stack on the same cover approach. Mirroring `_refresh_separation`
onto the enemy costs one function and no RVO.

Muzzle discipline is **half-solved**: `muzzle_foul_distance` (`ally_base:2050`) checks world geometry
within 2.5 m and refuses the shot. There is **no check against friendly bodies** (it explicitly
excludes `CharacterBody3D` and `Hitzone`), so men fire through each other. With no aim layer, a man
tracking a target through a squadmate has his whole body pointed at the friendly.

### 15. Path following is corner-hugging, but not twitchy — MOSTLY FINE — CODE — small
`nav_router.step` returns `agent.get_next_path_position() - from` raw: no corner smoothing, no
lookahead, so men hug polygon corners rather than cutting them. But the **anti-twitch work is done**:
the restake threshold is 9 m^2 (the target must move 3 m before a repath), `path_desired_distance = 0.7`,
`target_desired_distance = 1.0`, every expensive query is cached, and there is a stuck watchdog with
flip counting. **This is not the source of the unsmooth read.** A two-point lookahead would help the
corners; it is polish, not a defect.

### 16. Surrender plays a combat pose — REAL DEFECT — CLIPS — 1 art-day — LOW DEMO PRIORITY
`MODEL_CLIP["surrender"] = "kneeling_pointing"`. A surrendering man kneels **pointing his rifle**.
Wishlist A3 already names it. Only matters if chieu hoi is in the demo.

### 17. Death and ragdoll — FINE, and genuinely good
Seven directional falls; `death_intent` picks on the **dominant** axis (front/back/left/right) with
headshot variants for both hemispheres and a crouch headshot; `MODEL_ALIASES` degrades along the axis
he was actually shot on, never to a T-pose and never to a fall in the wrong direction. Ragdoll binds
are **proved before the clip is paused**, so a bone-name mismatch aborts with the clip still running
rather than latching a corpse upright. Per-frame bone bake in ascending index order. Settle-and-sleep.

One gap: `death_crouching_headshot_front` is called (`ally_base:2359`, `enemy_base:3056`) but there is
**no crouching non-headshot death** — a crouched man shot in the body plays a standing fall.

### 18. Bark timing — FINE mechanically; the risk is silence, not lag
`VOManager` plays at the event, positional at the speaker, no delay, no await. The gates are
`MAX_CONCURRENT_FIELD = 2`, a 3 s per-speaker cooldown and a 4 s per-line cooldown, and a refused
non-urgent line **does not burn its own cooldown** (correctly ordered). Barks are never late — they
are **dropped**. In a heavy firefight that means a squad that goes quiet, which is a different
complaint from the Summoner's and should not be traded against it here.

---

## WHAT IS ALREADY HALF-BUILT (the cohesion finding, repeating)

Phase 1 found a mechanic shipping with no affordance. The same shape recurs seven times here:

| Thing | Built | Why it never shows |
|---|---|---|
| `FlinchModifier` | fully, capped, gated | **allies never call it** |
| `stumble_hit` | wired enemy-side | **allies never call it** |
| `cover_kneel_brace`, `cover_peek` | in the library, in the ally chains | **`_execute_suppressed` clears the override** |
| `stand_to_cover` x3 + dive-roll | full variant system, squad-rationed | **gated on a layer-1 wall ray that jungle cover fails** |
| all ally cover craft | complete | **enemy side has none of it** |
| `run_to_stop` arrival beat | wired enemy-side | **allies never call it** |
| `reloading`, `reloading__smg` | authored | **zero NPC callers, no ammo model** |
| `tools/make_ambient_variants.py` | written | **never run** (its own header says so) |

---

## SIZING, AGAINST THE MEASURED VELOCITY (~1 sequence or 1-2 models per day)

**CODE, zero art-days** — items 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 14, 15. Roughly one focused coding
week for the lot, and it is the majority of the visible gap.

**CLIPS** — item 1 (canonical stance, 1-2 days, highest art value), item 8 (exporter + rebake, 1-2
days), item 11 (aimed walk, 1 day, bench first), item 16 (surrender, 1 day), crouch body-death (1 day).

**Nothing proposed here needs motion the pipeline cannot make.** #1 and #8 are surgery on clips that
already exist. #11 and #16 are single Mixamo-derived sequences.

---

## THE ONE THING THAT IS GENUINELY A MONTH

**The emotional-register axis on the state map** (`ANIM_VARIETY_PLAN.md` item 3). Calm / concerned /
alert / combat as a second axis on every locomotion and standing intent, plus the SPLICE, PHASE and
RETIME variant generation to populate it. `make_ambient_variants.py` exists and has never been run;
the seam gate it enforces has never been measured against the library; the register input touches
`sprite_state_map`, both `_update_sprite` drivers, and every man in the game; and each register needs
its clips authored, verified and re-exported.

It is the right long-term answer to "the world reads samey." **It is not the answer to "combat is not
smooth,"** and it must not be started before items 1-7 ship. Those are days, this is a month, and they
buy more.

---

## GATE POSITION

Items 2-7, 9, 10, 12, 13, 14 are **presentation for shipped systems** and **bug fixes** — explicitly
exempt from THE GATE (ADR-015). Items 1 and 8 are art work on a shipped library, not a feature epic.
**Nothing in this analysis requires the gate to be discharged first.** The register axis does.

---

*Compiled 2026-09-07 by code and disk read. Every clip name checked against the 232 animations in
`assets/shared/anim_library.glb`. Every line reference verified. Nothing here is playtested — parse
and grep are not the eye, and the Summoner's eye is the instrument that opened this council.*
