# Godot Specialist / Animation — prone posture wiring

War Room 2026-07-31. Every claim below is `file:line` or a number measured out of the glTF JSON +
BIN chunks of `assets/shared/anim_library.glb` this session. Where I could not measure, I say so.

---

## 1. How `clip_for()` actually works, and whether it can carry a POSTURE axis

### The signature and the chain

`scripts/visuals/sprite_state_map.gd:204`
```gdscript
static func clip_for(is_model: bool, weapon: String, intent: String) -> String:
```

It is **not** a `(weapon, intent)` matrix. It is a **one-dimensional intent lookup with a string
suffix stapled on**:

- `sprite_state_map.gd:207` — `model_clip_for(intent)` → a flat `Dictionary` lookup,
  `MODEL_CLIP` at `:127-147`, default `"idle_aiming"` (`:185`).
- `sprite_state_map.gd:208-210` — appends `"__" + family` from `WEAPON_FAMILY` (`:192-199`).
  The weapon axis is a **string decoration**, resolved by degradation in
  `model_actor.gd:890-896` (strip `__` suffix, fall back to base clip).

So there is exactly **one** real axis today: `intent`.

### The posture axis ALREADY EXISTS — and it is already an enum

Crouch is not a separate intent set. It is a **remap applied after the intent is chosen**:

- `sprite_state_map.gd:32-42` — `intent_for(..., low_posture: bool = false)`. If
  `low_posture and speed <= LOW_POSTURE_SPEED_MAX` (2.6 m/s, `:25`), the intent is rewritten by
- `sprite_state_map.gd:99-122` — `_to_crouch(intent, speed, lateral)`: a `match` that rewrites
  ~9 standing intents into `crouch_*` intents, and **passes everything else through untouched**
  (`:121-122`, the `_:` arm).
- Those `crouch_*` intents then land in the same flat `MODEL_CLIP` table at `:144-146`.

And the **decision** that sets `low_posture` is already a two-valued enum in a shared file:

`scripts/ai/combat_posture.gd:9`
```gdscript
enum Posture { STAND, CROUCH }
```
called identically by both factions — `enemy_base.gd:409` and `ally_base.gd:377`, both
`CombatPosture.decide(current_state, suppression_level, _near_cover()) == Posture.CROUCH`.

### Verdict: prone needs NO rewrite, and it is NOT the "register axis"

The handoff's warning (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:136-137`, `:216`) is about the
**variety register** — calm / concerned / alert / combat. That is a genuine War Room item because
it is a **cross product**: it multiplies *every* existing intent by 4 and every clip by 4.

Prone is a different shape entirely. It is a **third value on an axis that already exists**:

```
Posture { STAND, CROUCH }  ->  Posture { STAND, CROUCH, PRONE }
low_posture: bool          ->  posture: int
_to_crouch(...)            ->  + _to_prone(...)
```

Concretely, the change is:
1. `combat_posture.gd:9` — add `PRONE` to the enum; add the rule that elects it in `decide()`.
2. `sprite_state_map.gd:32-42` — widen the `low_posture: bool` parameter to `posture: int`
   (keep a default so no caller breaks), and dispatch to `_to_prone()` or `_to_crouch()`.
3. A new `_to_prone()` beside `_to_crouch()` — **deliberately narrow** (see §5).
4. ~4 new rows in `MODEL_CLIP` (`:127-147`).
5. Two call sites: `enemy_base.gd:457-459`, `ally_base.gd:446-451`.

Everything downstream — the weapon-family suffix, the 180 ms intent stability filter
(`enemy_base.gd:460-471`), the alias chain, the crossfade — works unchanged. **No rewrite.**

**What is sacrificed:** `_low_posture` is currently a `bool` read in five other places per faction
(`enemy_base.gd:626`, `:638`, `:2263`, `:2596`; `ally_base.gd:524`, `:536`, `:1451`) — footstep
audio, the speed cap, the stumble gate, the crouch retry. Widening it to an int means every one of
those `if _low_posture:` sites must be re-read and decided: does a prone man make crouch footsteps?
(he should make none). Does the prone speed cap equal the crouch cap? (it must not.) That is 10
call sites of judgment, not a mechanical find-and-replace. This is the real cost, and it is small
but it is not zero.

---

## 2. Measured clip facts

Method: parsed the glTF JSON chunk and the BIN chunk of `assets/shared/anim_library.glb` directly
in Python. Durations from the `input` accessor `min`/`max`; poses from the `output` accessors.
Library holds **163 animations**. All ten clips below carry **123 channels** (41 bones ×
translation/rotation/scale) — the full `PSXRig` set, consistent with
`SESSION_HANDOFF_2026-07-30_MIXAMO.md:33` ("41/41 bone names shared").

### Durations and key counts

| clip | first key (s) | last key (s) | length (s) | keys | frames @30fps |
|---|---|---|---|---|---|
| `crouch_to_prone` | 0.033 | 1.833 | 1.833 | 55 | 55 |
| `prone_to_crouch` | 0.033 | 1.833 | 1.833 | 55 | 55 |
| `prone_idle` | 0.033 | 4.967 | 4.967 | 149 | 149 |
| `prone_firing_rifle` | 0.033 | 0.867 | 0.867 | 26 | 26 |
| `wounded_crawl` | 0.033 | 2.367 | 2.367 | 71 | 71 |
| `idle_crouching` (reference) | 0.033 | 2.133 | 2.133 | 64 | 64 |
| `idle_crouching_aiming` (ref) | 0.033 | 2.033 | 2.033 | 61 | 61 |
| `walk_crouching_forward` (ref) | 0.033 | 1.033 | 1.033 | 31 | 31 |

All start at 0.033 s, not 0.0 — a one-frame offset from the 30 fps Mixamo bake. Harmless;
`AnimationPlayer.play()` starts at 0.0 and holds the first key.

### Root motion: ALL FOUR ARE IN-PLACE. Measured, not assumed.

Axis convention, established from the file rather than guessed: node `PSXRig` carries rotation
quaternion `[0.7071, 0, 0, 0.7071]` (= +90° about X, the Blender Z-up → glTF Y-up conversion).
Bone translation channels are authored in that node's local space, so **local −Z is world UP** and
local X / local Y are the two horizontal axes.

`mixamorig:Hips` translation, first key → last key:

| clip | X (horiz) | Y (horiz) | −Z (height, m) start → end | horizontal travel |
|---|---|---|---|---|
| `crouch_to_prone` | 0.000 → 0.000 | 0.0121 → 0.0121 | **0.460 → 0.149** | **0.0000 m** |
| `prone_to_crouch` | 0.000 → 0.000 | 0.0121 → 0.0121 | **0.149 → 0.460** | **0.0000 m** |
| `prone_idle` | constant | constant | 0.149 (flat) | 0.0000 m |
| `prone_firing_rifle` | constant | constant | 0.149 (flat) | 0.0000 m |
| `wounded_crawl` | constant | constant | **0.385** (flat) | 0.0000 m |
| `idle_crouching` | constant | constant | 0.462 (flat) | 0.0000 m |
| `walk_crouching_forward` | constant | constant | 0.734 (flat) | 0.0000 m |

**Every clip in the set is IN-PLACE with zero horizontal hip travel.** The transitions are a pure
**0.311 m vertical hip drop / rise** over 1.833 s. There is no root motion to strip and no
translation to compensate — the `CharacterBody3D` remains the sole owner of ground position, which
is what `_CLIP_SPEED` / `set_locomotion_speed()` (`model_actor.gd:943-966`) already assumes.

### Do the transitions actually meet the poses they claim to?

Measured as mean quaternion angular error across all 41 shared rotation channels, comparing the
LAST key of one clip to the FIRST key of the next.

| seam | mean rot error | worst joints |
|---|---|---|
| `crouch_to_prone` END → `prone_idle` START | **0.82°** | fingers only (RightHandIndex2 13.1°) |
| `crouch_to_prone` END → `prone_firing_rifle` START | **1.61°** | toes 19.9°/12.6°, fingers |
| `prone_idle` END → `prone_to_crouch` START | **1.54°** | toes 19.7°/12.6°, fingers |
| `prone_to_crouch` END → `idle_crouching` START | **22.97°** | LeftHand 97.6°, RightArm 88.3°, LeftForeArm 81.2° |
| `idle_crouching` END → `crouch_to_prone` START | **22.98°** | identical figures |
| `idle_crouching_aiming` END → `crouch_to_prone` START | **23.58°** | RightArm 106.2°, LeftForeArm 102.8°, Spine 46.4° |

**Finding — the PRONE end of both transitions is EXACT.** 0.82° / 1.54° mean, with the only real
error in fingers and toes. The hip height matches to three decimals (0.149 both sides). Entering
and leaving prone will not pop.

**Finding — the CROUCH end of both transitions is OFF BY ~23°, entirely in the ARMS.** The legs and
spine agree; the hands/forearms/upper arms are 80–106° apart. Reading the numbers: the crouch idles
hold a rifle in a shouldered/pointed pose, and the Mixamo prone transition starts from an
empty-handed crouch. This is a **real visible defect** — the man's arms will swing ~90° at the
moment he starts to go down and again at the moment he stands up.

Mitigation already in the engine: `model_actor.gd:914` plays every clip with a **0.18 s
crossfade**. 90° of forearm rotation over 0.18 s is a fast arm swing. It will read as a hurried
weapon transition rather than a teleport, but it is not clean, and it is worth a look by eye
before this ships. It is not a blocker.

`crouch_to_prone` START and `prone_to_crouch` END are **the same pose** (both 22.97/22.98° against
`idle_crouching`) — the two clips are a properly mirrored pair.

### Loop seams

`prone_idle`, `prone_firing_rifle` and `wounded_crawl` all measure **0.00° mean error between
their last key and their first key** — the first frame is duplicated as the last frame. Under
`LOOP_LINEAR` that costs one repeated frame per cycle (1 in 149 for `prone_idle`). Imperceptible;
noting it only so nobody "fixes" it later.

### What I could NOT measure

- **Whether the prone poses look right on OUR mesh.** I read bone transforms, not pixels. The
  0.149 m hip height is a number; whether the rifle intersects the chest, whether the elbows sink
  into the ground, whether the helmet clips — none of that is knowable from the glTF. Nothing here
  has been playtested (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:5`).
- **Ground clearance.** `_normalize_height()` (`model_actor.gd:182-215`) scales the rig off the
  standing REST skeleton, not off any clip. Whether a prone man's belly sits ON the collision floor
  or 5 cm above/below it is a runtime question. `ground_current_pose()` (`model_actor.gd:761-769`)
  exists and could correct it, but it is currently called only from the corpse path
  (`model_actor.gd:786`, `:793`) — I did **not** verify it is safe to call on a live man.
- **Whether the hitzone capsules follow the prone pose.** `Hitzone` areas are skeleton-parented or
  body-parented — I did not trace which. If they are on the body, a prone man is shot in the head
  by rounds passing 1.6 m over him. This is a combat-lens question, flagged for that architect.

---

## 3. Loop modes — and the good news is there is NOTHING TO DO

`model_actor.gd:357-374`, `_apply_loop_modes()`, runs at `setup()` (`model_actor.gd:130`) after
the shared library merge. It has two mechanisms and an explicit escape:

1. `:361-366` — exact-name match against `_LOOP_NAMES` → `LOOP_LINEAR`, then `continue`.
2. `:367-368` — `if nm.contains("turn") or nm.contains("_to_") or nm.contains("jump"): continue`
   — an explicit **do-not-loop** guard for transitions.
3. `:369-374` — prefix match against `_LOOP_PREFIXES` (`:332`).

Current state of the four clips, read off the source:

| clip | required | actual today | mechanism |
|---|---|---|---|
| `prone_idle` | **LOOP** | LOOP ✅ | listed in `_LOOP_NAMES`, `model_actor.gd:341` |
| `prone_firing_rifle` | **LOOP** | LOOP ✅ | listed in `_LOOP_NAMES`, `model_actor.gd:341` |
| `crouch_to_prone` | **ONE-SHOT** | one-shot ✅ | contains `_to_`, caught by `:367` |
| `prone_to_crouch` | **ONE-SHOT** | one-shot ✅ | contains `_to_`, caught by `:367` |
| `wounded_crawl` | **LOOP** | LOOP ✅ | listed in `_LOOP_NAMES`, `model_actor.gd:341` |

**All five are already correct.** The 7/30 wave fixed the two held poses
(`SESSION_HANDOFF_2026-07-30_MIXAMO.md:56-58` — the prefix heuristic missed `prone_idle` because it
does not begin with `idle`). The loop layer needs **zero changes** for this feature.

Note the subtlety that makes `prone_firing_rifle` load-bearing on the list: `_LOOP_PREFIXES`
contains `"firing"` (`:332`) but it is a `begins_with` test, and `prone_firing_rifle` does not
begin with `firing`. Only the `_LOOP_NAMES` entry saves it.

### Exact consequences of getting each one wrong

- **`prone_idle` or `prone_firing_rifle` left play-once.** glTF carries no loop flag
  (`model_actor.gd:328-331`), so an unlooped clip **freezes on its last frame**. A prone man would
  hold one frame forever. Because his last frame *is* a plausible prone pose, this does **not** read
  as a T-pose — it reads as a man lying perfectly still. It is the
  `recon-silent-freeze-bugs` class exactly: *looks alive because it played once*. He would keep
  shooting, keep being shot at, and never twitch. **This is the worst of the four failures because
  it is invisible.**
- **`crouch_to_prone` or `prone_to_crouch` set to LOOP.** The man drops to prone, snaps back to
  crouch, drops again — **flopping forever**, ~0.55 Hz. Loud and obvious, therefore cheap.
  The trap: `_LOOP_NAMES` is checked at `:361` **before** the `_to_` guard at `:367`, and the
  `_LOOP_NAMES` arm `continue`s. So adding either transition to `_LOOP_NAMES` silently defeats the
  guard that exists to protect them. **Do not add the transitions to `_LOOP_NAMES` for any reason.**
- **`wounded_crawl` left play-once.** Crippled men freeze mid-crawl and read as corpses that were
  never claimed. Already correct; listed for completeness.

---

## 4. The sequencing contract

### Does `ModelActor` expose a finished signal? — NO.

Grepped the whole `scripts/` tree for `animation_finished`. Every hit is on the **viewmodel** side:
`weapon_holder.gd:947-955`, `item_viewmodel.gd:116-171`, `viewmodel_editor.gd:360`. `ModelActor`
holds `_anim` as a **private** var (`model_actor.gd:105`) and forwards **no** signal. There is no
`finished` signal, no `queue()` wrapper, no completion callback.

**The house pattern for one-shots is a TIMED WINDOW sized from `clip_length()`.** The canonical
example is the cover-exit stand-up:

`enemy_base.gd:1853-1856`
```gdscript
var l: float = (sprite_actor as ModelActor).clip_length("cover_to_stand")
_cover_exit_until_ms = now + (l if l > 0.0 else 0.8) * 1000.0
```
consumed at the top of `_update_sprite()`:
`enemy_base.gd:428-430`
```gdscript
if _cover_exit_until_ms > float(Time.get_ticks_msec()) and sprite_actor is ModelActor:
    (sprite_actor as ModelActor).play("cover_to_stand")
    return
```
Mirrored on the ally side at `ally_base.gd:426-428` and `:1249`. `clip_length()` is
`model_actor.gd:929-939` and is alias-resolving, so it returns the real length of the clip that
will actually play.

**Prone must use exactly this pattern.** Adding an `animation_finished` signal to `ModelActor` for
this one feature would create a second completion mechanism beside a working one — a FOSSIL LAW
violation in advance (`CLAUDE.md:280-304`).

Measured window: **1833 ms** in each direction.

### The contract

State on the body: `_prone: bool` (the LATCH — where he is) and `_posture_change_until_ms: float`
(the WINDOW — a transition is playing).

**Entering prone**
1. `CombatPosture.decide()` returns `PRONE`.
2. Body sets `_prone = true`, `_posture_change_until_ms = now + clip_length("crouch_to_prone")*1000`
   (falls back to 1.833 if 0).
3. Body **hard-clamps planar speed to 0** for the window. The clip is in-place (measured §2) and any
   movement during it is a 1.8 s skate.
4. `_update_sprite()` override branch plays `crouch_to_prone` and `return`s.
5. Window expires → the state map now resolves through `_to_prone()` → `prone_idle` /
   `prone_firing_rifle`. The seam is 0.82°/1.61° — clean (§2).

**Leaving prone** — the mirror. `_prone = false` and the window are set together; `prone_to_crouch`
plays; on expiry he resolves as a crouching man.

**Placement of the override branch, in `_update_sprite()` order (`enemy_base.gd:420-483`)**

```
:424  DEAD / surrendered / downed          -> return           (must stay FIRST)
:428  _cover_exit_until_ms                 -> cover_to_stand
:432  _stumble_until_ms                    -> stumble_hit
      >>> PRONE TRANSITION WINDOW goes HERE <<<
:437  _throw_until_ms                      -> grenade_throw
:442  work_clip                            -> play_first(...)
:445  _play_camp_role()
```
Below stumble (a man hit hard drops the posture change), above the grenade throw and the work
clips (you cannot plant a charge or throw from mid-lower).

**Shot mid-transition.** Two different things:
- A non-lethal hit that only **flinches**: free, no work. `flinch()` (`model_actor.gd:72-84`) is a
  `FlinchModifier` on the `Skeleton3D`, **additive on top of whatever clip is playing**. The
  transition continues and gets a spine punch. Correct read.
- A hit heavy enough to **stumble** (`enemy_base.gd:2263-2264`, gated on `not _low_posture`): the
  stumble branch at `:432` outranks the prone branch and takes over. **The window must be zeroed AND
  `_prone` reverted to its pre-transition value in the same statement**, or when the stumble ends he
  resolves to `prone_idle` from a standing pose with only a 0.18 s crossfade over a 0.31 m hip drop.
  Note `:2263` currently gates stumble on `not _low_posture` — if `_low_posture` becomes an int this
  gate must be re-read (see §1's sacrifice).

**Dies mid-transition.** `enemy_base.gd:424` returns before every window, so the death path wins and
the transition is abandoned — **no extra code needed for the branch itself**. But the *result* is
wrong in one case: all death clips are STANDING deaths (`death_forward`, `death_from_right`,
`death_from_the_left`, `MODEL_CLIP:137-138`). A man 1.5 s into `crouch_to_prone` who plays
`death_forward` **pops back up to standing and then falls over**.
- The existing net catches the extreme: `settle_flat_corpse()` (`model_actor.gd:776-793`) measures
  `_pose_span_y()` and force-topples anything still spanning > `PRONE_SPAN_MAX` 1.2 m. That stops a
  standing corpse, it does not stop the pop.
- **Recommendation: while `_posture_change_until_ms` is live, prefer `start_ragdoll()` over the
  death clip.** `start_ragdoll()` (`model_actor.gd:687-745`) stops the clip and hands the *current
  pose* to the solver (`:717`), so a man killed halfway down simply collapses from where he is. This
  is the cheapest correct answer and it uses only existing machinery.

**Debounce.** Cover-exit already carries `COVER_EXIT_DEBOUNCE_MS` (`enemy_base.gd:1853`). Prone needs
its own, and a longer one: at 1.833 s each way, a posture flapping at the `CombatPosture` boundary
costs 3.7 s of a man doing push-ups in a firefight. The 180 ms intent stability filter
(`enemy_base.gd:460-471`) does **not** protect this — it filters the *intent*, and posture is
decided upstream at `:457` before `intent_for()` is called.

### THE ONE RULE THAT MUST NOT BE BROKEN

**`prone_idle` / `prone_firing_rifle` may only ever be reached through a completed
`crouch_to_prone`, and prone may only ever be left through `prone_to_crouch`.** The pose gap is
0.311 m of hip height and ~23° of full-body rotation; the only blend the engine applies is a 0.18 s
crossfade (`model_actor.gd:914`). Any code path that sets the prone latch without running the
window — a state-map fallback, a spawn-in-prone, a stumble that clears the window but not the latch,
an `arrive` beat, a camp role — teleports the man into or out of the dirt. Latch and window are one
thing and must be written in one statement, every time.

---

## 5. Is prone MOVEMENT just `wounded_crawl`? — NO. Measured, and it is not close.

`wounded_crawl` is wired to the `crippled` intent at `sprite_state_map.gd:135`, latched at
`enemy_base.gd:2352` and `:2512`, with an authored ground speed of 0.8 m/s at
`model_actor.gd:951`.

Measured against `prone_idle`:

| | hip height (m) | mean pose delta vs `prone_idle` |
|---|---|---|
| `prone_idle` | **0.149** | — |
| `wounded_crawl` | **0.385** | **36.03°**, hips 23.6 cm apart, LeftHand 129.4°, RightUpLeg 126.8°, RightHand 113.9° |

**`wounded_crawl` is not a prone clip.** Its hips ride 0.385 m off the deck — 23.6 cm higher than
`prone_idle`, and much nearer `idle_crouching` (0.462 m) than prone. A 127° `RightUpLeg` delta means
the knee is folded under him. **This is a hands-and-knees crawl, not a belly crawl.** The name is
honest about it: a *wounded* man dragging himself, not a soldier crawling to a firing position.

The two reads are different and both are correct for their own intent:
- **`wounded_crawl` = a casualty.** High hips, one arm reaching, weight lurching. He is trying to get
  out. He is not fighting.
- **Prone movement = a soldier.** Belly on the ground at ~0.15 m, rifle forward, elbows driving. He
  is trying to get *to* somewhere while staying alive, and he can shoot when he stops.

Using `wounded_crawl` for tactical prone movement would put a 23.6 cm hip pop between `prone_idle`
and moving, and read every prone soldier as wounded — which is exactly the defect the 7/30 wave
fixed at the camp (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:55-56`: the sleep role played
`laying_breathless`, so *every sleeping man read as a casualty*). Same mistake, different clip.

**And the library confirms the gap.** I listed all 163 clip names for `prone|crawl|lay|crouch`:
```
crouch_scan, crouch_to_prone, crouched_sneaking_left, crouched_sneaking_right,
crouching_turn_90_left, crouching_turn_90_right, death_crouching_headshot_front,
idle_crouching, idle_crouching__smg, idle_crouching_aiming, laying_breathless, laying_idle,
prone_firing_rifle, prone_idle, prone_to_crouch, rifle_crouch_idle_to_walk, sleeping_laying,
walk_crouching_backward, walk_crouching_backward_left, walk_crouching_backward_right,
walk_crouching_forward, walk_crouching_forward_left, walk_crouching_forward_right,
walk_crouching_left, walk_crouching_right, wounded_crawl
```
There is **no prone locomotion clip, no prone turn, no prone reload, no prone death** in the
library. Prone today is: get down, lie there, shoot, get up. Four clips, no verbs.

### Judgment

**Ship prone as a STATIONARY posture only, and make `_to_prone()` narrow by design.**

```
idle / aim          -> prone_idle
fire                -> prone_firing_rifle
everything else     -> fall through to _to_crouch(...)
```

A prone man who wants to move **stands up to crouch first** (`prone_to_crouch`) and crouch-walks.
That is a real tactical cost the player will feel — a pinned prone man is *committed*, and getting
him moving takes 1.833 s — and it is honest to what the art can express. It also matches the
existing `LOW_POSTURE_SPEED_MAX` idea (`sprite_state_map.gd:25`): the kinematic backstop that
already stops crouch leaking onto a fast push becomes `PRONE_SPEED_MAX = 0.0`.

**What is sacrificed by this judgment:**
- **No prone crawl to cover.** The most cinematic prone beat in the genre — a man low-crawling the
  last 5 m into a shell hole under fire — cannot be built until a `prone_crawl_forward` clip exists.
  It is one Mixamo pull ("Crawling", "Army Crawl") and the pipeline is ~5 minutes
  (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:35-36`, `:162-181`). I would take it. But it is ART work,
  which is gated behind his verification pass (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:41-44`,
  `:207-209`), so it must not block the engine work.
- **Prone men cannot turn in place convincingly.** `set_facing()` (`model_actor.gd:846-861`)
  yaws the whole node with a damped lerp. A prone man will **spin like a compass needle** around his
  hips. The crouch set has `crouching_turn_90_left/right`; prone has nothing. Options: accept the
  spin (it is a slow lerp, ~1/e per 83 ms), or clamp the yaw rate hard while prone. I recommend
  clamping — a spinning prone man is a distinctive, memorable bug.
- **No prone death.** A prone man killed plays a standing death clip. Route him to `start_ragdoll()`
  as in §4; the `settle_flat_corpse()` net (`model_actor.gd:776-793`) is the backstop.
- **`_CLIP_SPEED` gains nothing.** `set_locomotion_speed()` (`model_actor.gd:959-966`) finds no
  entry for `prone_idle`, so `ref = 0.0` and `speed_scale` resets to 1.0 — correct for a held pose,
  and correct *only because* prone does not move. The moment a prone crawl clip lands it needs a
  `_CLIP_SPEED` row or the man skates.

---

## 6. Summary of concrete work, in order

1. `combat_posture.gd:9` — `Posture { STAND, CROUCH, PRONE }` + the election rule in `decide()`.
   (WHEN a man goes prone is a game-design/AI call, not mine.)
2. `sprite_state_map.gd:32` — `low_posture: bool` → `posture: int`; dispatch to a new narrow
   `_to_prone()` beside `_to_crouch()` (`:99`).
3. `sprite_state_map.gd:127-147` — add `"prone_idle": "prone_idle"`,
   `"prone_fire": "prone_firing_rifle"` rows. Optionally alias-guard in `MODEL_ALIASES` (`:153`)
   with `"prone_idle": ["idle_crouching"]` — cheap insurance, though every rig gets all 163 clips
   via `_merge_shared_library()` (`model_actor.gd:280-310`) so no rig should miss them.
4. `enemy_base.gd` + `ally_base.gd` — the latch, the 1833 ms window sized by `clip_length()`, the
   override branch between `:432` and `:437`, the speed clamp, the debounce, the stumble-abort
   reset, the ragdoll-preference on death-in-window.
5. Re-read the ten `if _low_posture:` sites named in §1 and rule on each.
6. **Loop modes: NOTHING TO DO.** All five clips are already correct (§3).
7. **Do NOT add `crouch_to_prone` / `prone_to_crouch` to `_LOOP_NAMES`.** The `_LOOP_NAMES` arm at
   `model_actor.gd:361-366` `continue`s past the `_to_` guard at `:367` that is protecting them.

None of this is playtested. `SESSION_HANDOFF_2026-07-30_MIXAMO.md:5` — nothing in the 7/30 wave has
been judged by eye, and the ~23° arm discontinuity at the crouch seam (§2) is the first thing to
look at once it runs.
