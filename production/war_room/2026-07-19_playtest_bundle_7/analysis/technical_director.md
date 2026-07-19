# TECHNICAL DIRECTOR + LEAD PROGRAMMER — playtest bundle 7 (2026-07-19)

Lens: buildability, probe honesty, perf budget, fossil law. I read the code, not the plan.
Briefing recon facts taken as given (not re-derived).

Knowledge loaded and what I took from it:
- `godot_standards.md` — strict typing, typed signals, methods <30 lines, **"Groups judiciously —
  prefer direct references for frequent single-node access"** (this decides Item 6's shape) and
  **"Signals for loose coupling"** (this kills the flag-mailbox).
- `godot_4.7_features.md` — 4.6 `IKModifier3D`/`SkeletonModifier3D` framework is real and stable in
  4.7; **`LookAtModifier3D.relative` default flipped true→false in 4.7** (relevant if anyone reaches
  for a stock modifier for Item 4 — write our own, don't inherit that default).
- GodotPrompter `godot-testing/SKILL.md` — **"What NOT to Test: Visual/rendering output — pixel-level
  rendering results are brittle; test the data driving the visuals instead."** and **"Flaky async
  tests use explicit timeouts, not arbitrary sleep durations."** Both are load-bearing below.
- GodotPrompter `hud-system/SKILL.md` — checklist item: *"Interaction prompt converts the
  interactable's world position **each frame** — not cached at spawn time"* and *"Damage number
  positions are converted from world space to screen space"*. The nameplate violates the first rule
  outright: it never converts at all.
- GodotPrompter `godot-optimization/SKILL.md` — measure before claiming; the budget lives where the
  profiler says, not where intuition says. Applied to Item 4 below.
- `ADR-023` (fossil law), `ADR-015` (verification law: *"mitigated / investigated / likely fixed"
  NEVER close a bead*).

---

## A) PROBE STRATEGY — the most important output

House pattern (from `tests/test_mission_state.gd`, `tests/test_squad.gd`): a `.tscn` + `.gd`, run
`godot --headless --path . res://tests/test_X.tscn`, world harness is
`while not world.is_world_ready and elapsed < 180.0`, print `PASS: ...` / `FAIL: ...`,
`get_tree().quit(0/1)`. Failures are counted, not early-returned, so one run reports everything.

**Verdict table.**

| # | Item | Honestly probeable headless? |
|---|---|---|
| 1 | Fire-support budgets | **YES — fully.** Pure data. |
| 2 | Completion verb | **YES for the mechanism, NO for legibility.** |
| 3 | Patrols static at range | **YES — fully.** Strongest probe of the seven. |
| 4 | Flinch / death theater | **PARTIAL.** Intent+modifier+clip-selection yes; *does it read as a flinch* NO. |
| 5 | Punji traps destructible | **YES — fully.** |
| 6 | Informer LOS + handler | **YES — fully.** |
| 7 | Squad nameplate | **YES, with a stated caveat** (assert relative geometry, never literal pixels). |

Nothing in this bundle requires a rendered frame **except** the aesthetic judgement in Items 4 and 7,
and those two judgements are named as unverified below. Do not let them be smuggled into a green run.

---

### Item 1 — fire-support budgets. `tests/test_fire_support_budget.gd`

Fully headless: `director.fire_support` is a `Dictionary`, `request_fire_support` is a plain method,
`toast` is a signal. No rendering, no camera.

Assertions that FAIL today and PASS after the fix:
1. Generate a plan through `mission_generator`, run `director.setup(world)` + whatever injection the
   decree chooses. Assert `director.fire_support` is **not** identical to the hardcoded literal at
   `field_director.gd:194` (`{"bombs":0,"napalm":0,"arty":0,"mortar":2,"spooky":0,"cbu":0}`).
2. Assert `var verbs_with_stock := 0; for k in director.fire_support: if int(...)>0: verbs_with_stock+=1`
   → `verbs_with_stock >= 3`. **Today this is 1.** This is the assertion that reproduces the owner's
   complaint ("five of six answer NONE AVAILABLE") as a number.
3. Provenance, not just presence: build a plan with a deliberately weird budget
   (`{"arty": 7}`), assert `director.fire_support["arty"] == 7`. This is what proves the budget came
   **from the plan** and is not a second hardcoded default. Without this assertion the fix could be
   "change the literal at :194" and the probe would go green on a non-fix.
4. Keycode collision (secondary defect, mechanical): assert no two of `cbu_strike` /
   `place_claymore` share a physical keycode —
   `InputMap.action_get_events(a)` → compare `(e as InputEventKey).physical_keycode`. Fails today
   (both 54, `project.godot:146-149` vs `:191-194`).

**Negative control:** revert the injection line → assertions 1, 2, 3 all fail. Verified by running
the probe on the pre-fix tree *before* writing the fix (RED first — `godot-testing` SKILL.md:
"don't skip RED").

---

### Item 2 — completion verb. `tests/test_area_cleared_signal.gd`

Probeability depends on which route the council picks, but **both routes are headless-provable**:
- *Diegetic route* (toast + world state, no `mission_state`): connect `director.toast`, kill/clear
  the site's garrison, assert the signal fires **exactly once** with a non-empty string, and assert a
  re-trigger does not fire it a second time (one-shot). Assert no `mission_state.register_objective`
  call happened (ADR-029 compliance is itself assertable: `s.objectives_total == 0`).
- *`mission_state` route*: assert `register_objective` / `complete_objective` now have a caller
  outside `tests/`, and `is_exfil_unlocked()` flips.

**What is NOT probeable:** whether the player *understands* he finished the area. That is a playtest
observation under ADR-015, not a probe. Report it as such.

**Note for the Arbiter:** whichever route wins, the loser must be deleted in the same change
(ADR-023). If diegetic wins, `mission_state.register_objective`/`complete_objective` become
test-only-caller fossils and belong in the fossil register or the bin.

---

### Item 3 — patrols static at range. `tests/test_garrison_life.gd`

Fully headless and the best-shaped probe in the bundle, because the defect is *positional data over
time* — exactly the "test the data driving the visuals" rule from `godot-testing`.

Harness: real `game_world.tscn` with a fixed `mission_seed` (determinism, ADR-010), the
`is_world_ready` await loop.

Assertions:
1. **Existence.** Move the player to within `activation_range` of a known village
   (`mission_generator.gd:654-663`), await, assert `get_tree().get_nodes_in_group("enemies")` inside
   that village radius `>= 4` (headcount floor, `mission_generator.gd:538`).
2. **Intent.** For each garrison man, assert he has a movement intent —
   `patrol_route.size() > 0 or work_pos != Vector3.ZERO`. **Fails today for every garrison man**
   (`lazy_group.gd:63-89` only hands routes to `ambient_patrol*`; `camp_director.gd:100-101` writes
   `Vector3.ZERO` for patrol/sleep/guard roles).
3. **Motion (the real assertion).** Snapshot every garrison man's `global_position`, await a fixed
   sim window, re-snapshot. Assert `moved_count / total >= 0.5` with `moved > 1.0m`.
   **Today this is ~0.** Use SimClock, not wall time — the wall-ms harness was RETIRED.
4. **Body-gate self-heal (the perf claim, made honest).** Assert that a moving garrison man's
   `_body_gate_open()` is true on a frame where `CombatManager.perceivable(him)` is false. This is
   the assertion that *proves the cheap lever works* — velocity re-opens the gate at
   `enemy_base.gd:528` without any range concession.
5. **Perf ceiling (the tradeoff, made mechanical).** Assert live unit count `<= CEILING` and that
   `CombatManager.ai_usec_move + ai_usec_anim` per frame stays under the ledger's measured band
   (`PERF_LEDGER.md:265-284`). If the council raises `activation_range`, this assertion is the thing
   that bites. **Insist on it.** Item 3 is the only item in the bundle that can make the frame worse,
   and a probe that only proves "they move now" is a probe that hides the cost.

**Negative control:** revert the `work_pos` / `patrol_route` assignment → assertions 2 and 3 fail.

---

### Item 4 — flinch / death theater. `tests/test_flinch_reaction.gd` — **PARTIAL**

**Assertable (build these):**
1. A flinch **intent is emitted / a modifier is installed.** After
   `enemy.take_damage(20, PHYSICAL, player, "ARM_L")` on a non-fatal hit, assert the flinch
   modifier node exists under `actor.skeleton()` and its `influence > 0.0`. Fails today — nothing
   emits "flinch" at all.
2. **It decays.** Await the flinch duration, assert `influence` back to `0.0` and (per the
   architecture below) the modifier is gone / inactive. Catches a stuck-pose bug, which is the real
   risk of a procedural reaction.
3. **It is bounded.** Damage 20 units in one frame, assert concurrent flinchers `<= MAX_CONCURRENT_FLINCH`.
4. **It does not eat the fire stall or the stagger.** Assert the existing 0.25s stall
   (`enemy_base.gd:2159-2161`) and `apply_stagger` (:2279) still behave — a presentation change must
   not silently retune combat. This is a regression guard, and it is the assertion most likely to
   catch a real bug.
5. **Death clip selection is hitzone-aware.** Assert the selector is a *pure function*:
   `_pick_death_clip("HEAD", dir)` != `_pick_death_clip("LEG_L", dir)`. Testing the selector directly
   is honest; testing that the ragdoll "looks right" is not.

**NOT assertable — report as unverified:**
- Whether the spine-punch reads as a hit reaction, whether the magnitude is right, whether it looks
  like a twitch or a seizure. **Pure visual judgement.** No headless assertion substitutes.
  Under ADR-015 this closes on a *verified playtest observation*, nothing weaker. Do not write
  "flinch verified" in the closing comment on the strength of assertions 1-5. They prove the
  machine runs; they prove nothing about the theater.

---

### Item 5 — punji traps. `tests/test_trap_destructible.gd` — YES, fully

Assertions:
1. `PunjiTrap.place(...)` then `trap.has_method("take_damage")` → true (false today).
2. **Gunfire.** Fire a real round through `BulletSystem` at the trap; assert the trap is freed /
   `_sprung == true`. *(See §D for why this requires a Hitzone — a plain body will not do it.)*
3. **Blast.** `CombatManager.apply_explosion_damage(trap.global_position, 190, 40, 8.0, null)`
   (M26 values of record), assert the trap is destroyed. **Fails today** — the router iterates four
   registries (`combat_manager.gd:138-220`) and a trap is in none of them.
4. **A destroyed trap cannot spring.** Destroy it, then teleport the player onto it, await >0.2s
   (the 5Hz scan at `punji_trap.gd:42-57`), assert the player took no damage. This is the assertion
   that catches the lazy fix (hide the model, leave the scanner alive).
5. **Enemies still cannot trigger it.** Walk an `EnemyBase` over an intact trap, assert no damage.
   Preserves the design contract in the file header.

**Negative control:** revert the Hitzone + hp → assertions 1-4 fail.

---

### Item 6 — informer. `tests/test_informer.gd` — YES, fully

The single cleanest probe in the bundle. Two independent halves:

**LOS half** (`civilian.gd:159-165`):
1. Place an informer 10m from the player with a `StaticBody3D` wall (layer 1) between. Await >1s.
   Assert `civ._inform_clock < 0.0` — **the clock must not have started.** Fails today (distance
   alone).
2. Remove the wall, await, assert `_inform_clock >= 0.0`. Proves the gate is a gate and not a
   blanket disable — without this, "delete the whole feature" would pass assertion 1.

**Handler half:**
3. Force the escape (`civ._inform_clock = 26.0` and tick, or call the escape path directly). Assert
   an enemy appears within ~10m of the informer's last position, via
   `director.live_enemy_count("informer") > 0`. Fails today — nothing reads either flag
   (`mission_state.gd:18` flags are write-only debrief data copied by `build_result` :93-97).
4. **One-shot.** Tick the director again, assert `live_enemy_count("informer")` is unchanged. This is
   the assertion that catches the classic flag-polling bug: a flag that is read but never consumed
   spawns a hunter every frame forever.
5. Assert the debrief still records the event (`build_result` contains the informer record) — the
   consumption must not erase the history.

---

### Item 7 — squad nameplate. `tests/test_nameplate_projection.gd` — YES, with a caveat

**Direct answers to the questions asked:**

**Does `get_viewport().get_camera_3d()` work headless in Godot 4.7? — YES.**
Camera registration is a *scene-tree* operation, not a renderer operation: `Camera3D` registers
itself with its `Viewport` on tree-enter and the first camera to enter with no other current camera
becomes current. `scenes/player/player.tscn:25` declares `Head/Camera3D` with no explicit
`current = true`, so it becomes current by that default rule. This does not touch the rasterizer and
is unaffected by `--headless`.
*Caveat worth a line in the probe:* because it is current *by default* rather than by declaration, a
second `Camera3D` entering the test scene first would silently steal it. The probe should assert
`get_viewport().get_camera_3d() == world.player.get_node("Head/Camera3D")` before asserting anything
else — a cheap guard that turns a confusing failure into a named one.

**Is `unproject_position` valid without a rendered frame? — YES.**
It is pure math: the camera's projection matrix (fov/near/far, all script-side properties) applied to
the inverse camera transform, scaled by `get_viewport().get_visible_rect().size`. In headless the
visible rect is the configured viewport, `project.godot:56-57` → **1280x720**. Nothing is read back
from the GPU. Two things to know:
- It requires the camera to be `is_inside_tree()`. The harness satisfies this.
- **`scaling_3d/scale = 0.75` (`project.godot:303`) does NOT affect it.** `unproject_position` uses
  the *visible rect*, not the 3D render target. That is precisely why the marker pattern at
  `mission_hud.gd:280-283` can feed the result straight into `label.position` and be correct on
  screen. Same guarantee applies to the nameplate.

**The caveat — and it is the one that keeps this probe honest.** Do not assert literal pixel
coordinates. `godot-testing/SKILL.md` is explicit: pixel-level results are brittle. Viewport size,
FOV (75 base, per-weapon `ads_fov` — ADR-004), and any future resolution change all move the number
while the behaviour stays correct. **Assert relative geometry, computed against
`get_viewport().get_visible_rect().size` read at runtime, never against the literal 1280.**

Assertions that FAIL today and PASS after the fix:
1. **Not at the origin.** Position the player 3m from a squadmate, aim straight at him, await 2
   frames. Assert the nameplate's drawn rect `.position.length() > 50.0`.
   **This is the whole bug.** Today it is `(0, 48)`.
2. **Centred on the man.** With the ally dead-ahead, assert
   `abs(plate.x - vp.size.x * 0.5) < vp.size.x * 0.08`.
3. **It tracks.** Move the ally 1m to the camera's right (still inside the 12° cone). Assert the new
   `plate.x` is **strictly greater** than the old. Monotonic tracking is unfakeable by a static
   offset — this is the assertion that distinguishes a real projection from a hardcoded
   "centre-ish" nudge.
4. **Head anchor, not feet.** Assert `unproject(ally.global_position).y - plate_anchor_y > 20.0`
   px — i.e. the plate is *above* where the feet project. This proves `TARGET_HEIGHT_M` is actually
   in the maths (ADR-002 compliance, asserted rather than commented).
5. **Behind-camera guard.** Rotate the camera 180°. Assert the plate is hidden
   (`modulate.a == 0.0` / `visible == false`) and — importantly — that no `unproject_position` result
   was used. Behind the camera, `unproject_position` returns a mirrored on-screen point; without the
   `is_position_behind` guard you get a ghost nameplate at a plausible-looking coordinate. That is
   the exact failure the marker pattern's guard (`mission_hud.gd:277`) exists to prevent, and it will
   not show up in any of assertions 1-4.
6. **The LOCKED constants are still locked.** Assert `SquadNameplate.LOOK_RANGE == 5.0` and
   `LOOK_CONE_DEG == 12.0`, and behaviourally: an ally at 6m acquires nothing; an ally at 4m and 20°
   off-axis acquires nothing. The Summoner narrowed this mid-session; a probe is how it stays
   narrowed after we all forget. Cheap, and it makes the lock mechanical rather than remembered.
7. **Allies only** (Pillar 3). Put an `EnemyBase` dead-ahead at 3m, assert no plate. Also cheap, also
   permanent.

**Negative control:** restore `set_anchors_preset(Control.PRESET_CENTER)` + `box.position =
Vector2(0, 48)` and delete the per-frame projection → assertions 1-5 fail.

**One honest discrepancy I must report.** Reading `set_anchors_preset(PRESET_CENTER, keep_offsets =
false)` from the engine's semantics, I would predict the zero-size Control lands at **screen
centre**, not upper-left; the observed symptom is upper-left. The most likely reconciling mechanism
is that `_ready()` resolves anchors while the parent area size is not yet the viewport (the nameplate
is `add_child`-ed inside `setup()` at `mission_hud.gd:31`), so the centre anchor resolves against
`(0,0)` and lands at the origin. **I am not re-deriving the root cause** — the briefing measured the
symptom and I take it. I raise it because it does not change the fix by one line, and because the
proposed fix removes the dependence on layout timing *entirely*, which is the stronger reason to
prefer it. Have the probe **print the pre-fix position** as a diagnostic line. That converts an
architects' disagreement into a measurement, which is what ADR-015 is for.

---

## B) ITEM 7 — implementation

### Node structure — yes, it needs a real rect

Make `SquadNameplate` itself the full-rect container. It is already a `Control`; it is simply never
given a size. This is exactly `_marker_box` (`mission_hud.gd:35-38`), which is the house pattern the
briefing points at, and the nameplate is the only HUD child not following it.

```
MissionHUD (CanvasLayer)
└── SquadNameplate (Control)          PRESET_FULL_RECT, MOUSE_FILTER_IGNORE
    └── VBoxContainer                 NO preset, NO static position — positioned per-frame
        ├── Label  name (20px)
        └── Label  role (14px)
```

In `_ready()`:
- `set_anchors_preset(Control.PRESET_FULL_RECT)` on `self` (was `PRESET_CENTER`).
- **Delete** `box.set_anchors_preset(Control.PRESET_CENTER)` (`squad_nameplate.gd:26`) and
  **delete** `box.position = Vector2(0, 48)` (`:28`). Both are the bug. A per-frame-positioned node
  must not carry a static offset; the next reader will not be able to tell which one is authoritative
  — that is ADR-023's failure mode in miniature.
- Keep `box.alignment = ALIGNMENT_CENTER` and `MOUSE_FILTER_IGNORE` on both.

### Where the projection goes

In `_process`, and **fetch the camera once**. Today `_process` (:51) and `_find_looked_at` (:68) are
two separate lookups; if the projection adds a third, the cone test and the draw could resolve to
*different cameras* (photo mode, a cutscene cam). Fix the shape while fixing the bug:

```gdscript
func _process(delta: float) -> void:
    var cam: Camera3D = get_viewport().get_camera_3d()
    _target = _find_looked_at(cam) if cam != null else null
    var want: float = 0.0
    if _target != null:
        _fill_labels(_target as AllyBase)
        var head: Vector3 = _head_point(_target as AllyBase)
        if not cam.is_position_behind(head):
            var screen: Vector2 = cam.unproject_position(head)
            var box_size: Vector2 = _box.get_combined_minimum_size()
            _box.position = screen - Vector2(box_size.x * 0.5, box_size.y)
            want = 1.0
    modulate.a = move_toward(modulate.a, want, FADE_SPEED * delta)
```

Three deliberate choices:
- **`is_position_behind` gates the fade, not just the draw.** If the man is behind the camera the
  plate must fade out, not freeze at its last screen position. Handled by leaving `want = 0.0`.
  (Strictly, at 5m inside a 12° cone he can never be behind — but the guard costs one branch and the
  contract should not depend on the constants staying 5.0/12.0 forever.)
- **`get_combined_minimum_size()`, not `.size`.** A `VBoxContainer`'s `.size` is only valid after a
  layout sort; on the acquisition frame it is stale, so the first frame of every plate would be
  mis-centred by the label width. `get_combined_minimum_size()` is computed on demand and is correct
  headless with no draw — which also makes assertion 2 above stable.
- **`- Vector2(..., box_size.y)`** puts the plate's *bottom* on the anchor, so the text sits above
  the head rather than through it.

### Head anchor

`AllyBase.global_position` is FEET. `ModelActor.TARGET_HEIGHT_M = 1.7132` (`model_actor.gd:18`) is
feet-to-head-top. There is no head marker node, so compute it:

```gdscript
const HEAD_CLEARANCE: float = 0.25   ## metres above head-top; the plate must not sit on the helmet

func _head_point(ally: AllyBase) -> Vector3:
    var h: float = ModelActor.TARGET_HEIGHT_M
    if ally.actor != null and is_instance_valid(ally.actor):
        h = ModelActor.height_for(str(ally.member.get("unit_id", "")))
    return ally.global_position + Vector3.UP * (h + HEAD_CLEARANCE)
```

**Do not hardcode `1.7132` in the HUD.** `model_actor.gd:65` already resolves per-unit height from
`UNIT_HEIGHT_M` with `TARGET_HEIGHT_M` as fallback; duplicating the literal would create a second
source of truth for the ADR-002 scale contract — a fossil-in-waiting the moment ADR-002 is amended.
Read it from `ModelActor`, always.

`TORSO_OFFSET = 1.35` (`:13`) stays as-is: it is the *chest* point for the cone/LOS test ("aiming at
the feet or over the helmet should not identify a man"), and it is correct for that job. Two
different anchors for two different jobs is right here — but the constant's docstring should say
which job it serves, since a head anchor now lives beside it.

### Is the shared CanvasLayer parenting a latent bug for the other children?

**No — they are genuinely safe, but safe by construction, not by luck, and there is one subtlety
worth recording.**

A `Control` whose parent is a `CanvasLayer` (not another `Control`) is a layout root: Godot resolves
its anchors against the viewport rect. So `PRESET_CENTER_TOP` on the compass panel
(`mission_hud.gd:41`) genuinely means "top-centre of the screen". The parenting is correct and
matches the `hud-system` skill's rule that all HUD nodes live under a `CanvasLayer` with `layer >= 1`.

Every sibling then writes an explicit `.position` immediately after the preset (compass :42, toasts
:51, slot slider :59, fire panel :85, squad panel :189). Those are *offsets from a resolved anchor* —
the intended idiom, correct, and not a latent bug. **No change to any of them. Out of scope.**

The nameplate is not a variant of that pattern; it is a different animal that was written as if it
were one. It is the only HUD child whose position is a **function of a world-space point**, which
means it belongs in the `_marker_box` family (full-rect parent + per-frame `unproject_position`), not
the anchored-panel family. That is the actual ruling: **the bug is a category error, not a missing
`.position` line.** Adding a static `.position` would make it wrong in a new place; the fix must be
per-frame projection.

One genuine sharp edge, recorded for the next reader rather than fixed here: the nameplate resolves
its camera via `get_viewport().get_camera_3d()` while `mission_hud._update_markers` resolves via
`world.player.get_node_or_null("Head/Camera3D")` (`:239`). Two HUD elements, two camera sources.
They agree today. They will disagree the first time a cutscene or photo-mode camera goes current.
Not this bundle's problem, but worth a bead.

---

## C) ITEM 4 — architecture

### Is procedural (SkeletonModifier3D) the right call? — **YES, with a mandatory qualifier.**

The design intent (`ANIM_WISHLIST.md:16,57`) is right and I back it, for reasons independent of the
art debt:
- Clip-based flinch needs one clip *per direction per stance* to not look wrong, and
  `death_from_the_left` does not even exist yet (`ANIM_WISHLIST.md:12`). The clip route is a
  standing art commitment with no end.
- A clip flinch **fights** the existing systems. Non-fatal hits already drive a 0.25s fire stall
  (`enemy_base.gd:2159-2161`) and an optional forced SUPPRESSED crouch (`:2163-2167`). Playing a
  full-body flinch clip means blending against the crouch and the aim pose — an AnimationTree state
  explosion. A spine-only additive punch composes with all of them for free. That is the real
  argument, and it is the architectural one.
- `SkeletonModifier3D` (4.6 framework, stable in 4.7) exists precisely to solve the ordering problem:
  it runs *after* the AnimationPlayer in the skeleton's modifier stack, so a direct
  `set_bone_pose_rotation` from `_execute` would be stomped every frame and a modifier will not be.
  There is no cheaper correct way to do this in-engine.

**The qualifier — and it is not optional.** Do **not** install a resident modifier on every unit.

`PERF_LEDGER.md:265-284` (65-67 live units): the **BODY is 95-97% of AI cost** — `move_and_slide`
8.8-9.1ms, hitzone sync 9.9-10.4ms, anim/execute 17.6-19.0ms; the brain is ~3% (1.2-1.28ms). A
`SkeletonModifier3D` is a node under `Skeleton3D` with a per-skeleton-update callback. It runs on the
**body side of the ledger — the 97%, the exact budget that is already the problem.** 65 resident
modifiers is a permanent tax to buy an effect that is active for ~0.25s at a time on a handful of men.

So:
- **Lazy instantiation.** Create the modifier on the first flinch, free it when it decays. One node
  churn per flinch event beats 65 permanent per-frame callbacks. Nothing at all in the common case.
- **Hard concurrency cap: `MAX_CONCURRENT_FLINCH = 8`.** The 9th simultaneous flinch is dropped.
  Bounded worst case is the only thing that makes a perf claim about this feature honest.
- **Spine bone only.** One bone, one quaternion slerp, per flinching unit, per frame, for ~0.25s.

**Honest cost statement:** ceiling is 8 units × 1 bone × ~0.25s. Against a body budget of ~28ms
across 65 units (~0.43ms/unit for full move+hitzone+anim), 8 single-bone rotations is comfortably
sub-0.1ms. **But that is an estimate, not a measurement**, and `godot-optimization` and ADR-015 both
say the same thing: it closes on a ledger entry, not on my arithmetic. **Require a
before/after `ps2_perf_probe` number in `PERF_LEDGER.md` before this bead closes.**

### Does it need to respect the body gate (`enemy_base.gd:523-538`)?

**It must respect `perceivable()`, and specifically NOT `_body_gate_open()`.** This distinction
matters and is easy to get backwards:

`_body_gate_open()` returns true at `:524` if `current_state == COMBAT or alert_tier > RELAXED`.
**A man who was just shot is always in COMBAT** (`take_damage` sets the tier). So gating flinch on
`_body_gate_open()` is a no-op — it is *always* open for exactly the population that flinches, and it
would read as a perf guard while guarding nothing. That is a fossil-shaped lie in new code.

The correct gate is `CombatManager.perceivable(self)` (`combat_manager.gd:45-58`,
`PERCEIVE_RANGE = 150.0`) — the same predicate the body gate itself consults at `:530`. A man shot at
200m outside the player's perception cannot be seen to flinch; skip creating the modifier entirely.
Free, correct, and it is the *reason* the body gate uses that predicate in the first place.

Second-order note: `_update_sprite` is skipped when the gate is closed (`:1298-1299`). Since the gate
is open for any shot man, the flinch will drive. No interaction bug. But if the modifier is ever made
resident, it would keep animating men whose pose the gate deliberately froze — another reason lazy
instantiation is the right shape.

### Death clips — scope warning

Hitzone-aware *selection among clips that exist* (`death_forward`, `death_from_right`) is a small,
honest change and it belongs in this bundle. Full directional death theatre needs
`death_from_the_left` and a stance-aware set that **do not exist**, and it is Blender work, which the
briefing puts out of scope. **Flag: full death theater is bigger than one session.** Ship
procedural flinch + selection-among-existing, and say so plainly in the closing comment. Do not let
"death theater" close on a flinch.

### `sprite_state_map.gd:138` — `"flinch"` → `rifle_aiming_idle`

**Fossil. Delete it in this bundle.** Three reasons:
1. Nothing emits the `"flinch"` intent (briefing, measured), so the entry is unreachable — it has
   been dead since it was written.
2. Item 4 *replaces* the concept with a procedural reaction. ADR-023: *"a system's replacement is not
   shipped until its predecessor is deleted."* This is the predecessor, and it is one line.
3. It is actively hazardous, not merely dead. It maps a flinch to an **aiming idle**. If anyone ever
   wires a `"flinch"` intent — which Item 4 makes a live temptation — a shot man snaps to a
   *weapon-raised aim pose*. That is the "next reader cannot tell a corpse from live code, and will
   use the wrong one" failure ADR-023 was written about, with a combat-legibility bug attached.

`test_fossils.gd` scans const/func/signal **declarations**; a dictionary key is invisible to it. So
this entry will never be caught by the machine — **which is the argument for deleting it now**, not
against. No `fossil_baseline.json` change is needed (it is not a `file|kind|symbol` entry).

---

## D) ITEMS 5 + 6 — wiring

### Item 5 — traps: the exact node structure

**Direct answer to the briefing's question 5 ("does a destructible trap need hitzones at all, or is a
single body + health enough?"): it needs exactly ONE Hitzone. A body + health is NOT enough, and I
can cite why.**

`bullet_system.gd:112-133` is the single arrival path for every shooter in the game. A round reaches
`take_damage` by exactly two routes:
- `col is Hitzone` → `target = hz.owner_entity` (`:119-122`), or
- `col is Node` **and** it (or its parent) is in group `enemies` / `player` / `allies` (`:125-132`).

A trap in group `punji_traps` matches **neither**. A `StaticBody3D` with a `take_damage` method is
never consulted — `target` stays `null` and the round dies silently against it. **Give it a Hitzone
or it is not shootable.** This is the sort of thing that ships as "destructible" and is discovered by
a player emptying a magazine into a trap.

```
PunjiTrap (Node3D)                      # class kept, place() kept, group "punji_traps" kept
├── Hitzone (Area3D)                    # zone_type TORSO, meta region "BODY",
│   └── CollisionShape3D                #   set_owner_entity(trap)
│        BoxShape3D ~1.4 x 0.4 x 1.4    #   collision_layer = 512, collision_mask = 0
└── <punji_trap.glb instance>
```

- **Layer 512** — reuse `Civilian.CIVILIAN_HURTBOX_LAYER` (`civilian.gd:22`), documented there as
  *"in the PLAYER's fire masks only — AI strays pass through."* That is exactly the behaviour we
  want: the player can shoot out a trap, a stray AK burst cannot. **The VC laid these; VC fire should
  not clear them.** The layer choice enforces the design contract for free, with no mask edits.
- **No `_build_static`.** `hitzone_builder._build_static` (`:559`) lays a 1.65m humanoid band set
  (HEAD at y=1.65, arms, legs). A trap is a hole in the ground. Build the one box inline in
  `PunjiTrap.place()` — ~10 lines, no builder change, and it does not teach the builder a shape it
  should not know.
- **No second damage router.** On `PunjiTrap`: `var current_hp: int = 15` and
  `func take_damage(amount: int, _type: int, _attacker: Node, _region: String = "BODY") -> void`
  matching the house signature. `_destroy()` sets `_sprung = true` **first** (so the 5Hz scanner at
  `:42-57` can never fire during teardown), `remove_from_group("punji_traps")` (so the pointman's
  `detect_ambush` stops flagging a dead trap), FX, `queue_free()`.

**Blast.** `apply_explosion_damage` (`combat_manager.gd:138-220`) iterates player + allies +
civilians + enemies. Two options:
- *(a) Register traps in `AgentRegistry`* — **reject.** Those arrays are iterated by AI code
  (`combat_manager.gd:161,190,201`, targeting, threat scans). A trap in `AgentRegistry.enemies` is a
  thing the AI can try to shoot at, walk to, and take cover from. That is a whole class of bugs for
  one convenience.
- *(b) Add a fifth loop over `get_tree().get_nodes_in_group("punji_traps")`* — **recommended.**
  ~8 lines inside the existing function, reusing `_explosion_damage_at`. **This is not a second
  router; it is the one router gaining a fifth client**, which is precisely what the briefing's "do
  not invent a second damage router" instruction protects. Skip `_can_damage_multipoint` here — it
  traces 8 points around a *humanoid* bound; for a flat ground object a plain radius check is both
  cheaper and more correct.

### Item 6 — informer: LOS gate and handler

**LOS gate** (`civilian.gd:159-165`) — the canonical helper, per the briefing and per
`enemy_base._can_witness` (:740-754), `ally_base.gd:491`, `mission_trigger.gd:187`:

```gdscript
if is_informer and player and _inform_clock < 0.0:
    _inform_poll += delta
    if _inform_poll >= 0.25:
        _inform_poll = 0.0
        if global_position.distance_to(player.global_position) < 15.0 \
                and CombatManager.has_line_of_sight(
                    global_position + Vector3.UP * 1.5,
                    player.global_position + Vector3.UP * 1.5, self):
            _inform_clock = 0.0
            _saw_player_at = player.global_position
            state = CivState.FLEE
```

Two things that are not decoration:
- **Distance first, raycast second.** `has_line_of_sight` is a physics query; the current check runs
  every physics frame for every non-LOD_FAR civilian (`civilian.gd:148-165`). A village is 4-7
  villagers plus wanderers; adding an unconditional per-frame raycast each is a real, avoidable cost
  on the same body-side budget Item 3 is already spending. The 0.25s poll plus the `_inform_clock < 0.0`
  guard means **zero raycasts** once the clock has started or for any non-informer.
- **Eye height on both ends.** `global_position` is feet (ADR-002). A feet-to-feet ray is occluded by
  every rock and berm and would make informers nearly blind — a plausible-looking fix that quietly
  deletes the feature. `+1.5` on both ends is the eye line.

**Handler.** The briefing asks where the poll goes, copying `_check_detection()`
(`field_director.gd:70-77`). Both shapes work; I rule for the direct call, and give the poll as the
fallback.

**Ruled: direct call, delete the flag-mailbox.** `civilian.gd:328-330` writes
`director.state.flags["informer_transformed"]` with a comment claiming a director handler reads it.
Nothing does — `state.flags` (`mission_state.gd:18`) is write-only debrief data copied out by
`build_result` (:93-97). Under the **TRUTH LAW (ADR-015 §3)** that comment is a violation and must
die with the mechanism it describes. And `Civilian` **already holds `director`** (`civilian.gd:24`,
used one line earlier at `:171` to emit a toast). Passing a message through a dictionary to a poller
that reads the same object you already have a reference to is indirection with no payer.
`godot_standards.md`: *"prefer direct references for frequent single-node access."*

```gdscript
# civilian.gd — replaces the two flag writes at :328-330
if director:
    director.on_informer_escaped(global_position)

# field_director.gd — next to _check_detection()
func on_informer_escaped(last_pos: Vector3) -> void:
    if _ended or _informer_answered:
        return
    _informer_answered = true                       # one-shot, set BEFORE spawning
    state.flags["informer_talked"] = true           # debrief record survives
    state.flags["informer_last_pos"] = last_pos
    for i in range(randi_range(2, 3)):
        var jitter := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
        spawn_tracked_enemy(last_pos + jitter, "res://data/enemies/vc_rifleman.tres", "informer")
    toast.emit("THEY CAME LOOKING - CONTACT NEAR THE VILLE")
```

- **One-shot consumed before the spawn, not after.** If the spawn throws or re-enters, the guard is
  already set. Consume-then-act is the correct ordering for every one-shot in this codebase; the
  reverse is how you get a hunter spawned every frame forever, which is what probe assertion 4 in
  §A/Item 6 exists to catch.
- **The debrief keeps its record.** `informer_talked` stays in `state.flags` for `build_result`. The
  *mailbox* dies; the *history* does not. This is the distinction the current code conflates.
- Reuses `spawn_tracked_enemy` (`:30-44`), so kills count, the contact ledger registers the group
  (ADR-006, `:41-43`), and the `"informer"` group tag makes `live_enemy_count("informer")` a free
  probe handle.

*Fallback if the council wants director-owned timing:* keep the flag, add
`_check_informer()` called from `_process_escalation` immediately after `_check_detection()`
(`:80`), consuming the flag on read. Same assertions, one more moving part, and the lying comment
must still be rewritten either way.

---

## E) FOSSIL LAW AUDIT for this bundle (ADR-023)

**The trigger is *replacement*, not mere deadness.** ADR-023: *"a system's replacement is not shipped
until its predecessor is deleted."* Applying that test one item at a time:

| Corpse | In scope? | Ruling |
|---|---|---|
| `mission_generator.gd:437` `"fire_support": {"mortar": 1}` dead data | **YES — Item 1's direct predecessor** | **Make the fix READ it**, or delete it in the same change. |
| `"radio"` input action, key G, bound and never read (`project.godot`) | **YES — inside Item 1's blast radius** | **Delete the binding.** |
| `cbu_strike` / `place_claymore` both on physical keycode 54 | **YES — a live bug, Item 1** | **Rebind one.** Not a fossil; a collision. |
| `sprite_state_map.gd:138` `"flinch"` entry | **YES — Item 4's predecessor** | **Delete.** (See §C.) |
| `radio_handset.gd` / `radio_cord.gd` (6 baseline entries, `fossil_baseline.json:30-35`) | **NO — out of scope** | Leave. File a bead. |
| `mission_state.register_objective` / `complete_objective` | **Conditional on Item 2** | If the diegetic route wins, they become the predecessor → delete or register. |

Reasoning on the two that matter:

**`mission_generator.gd:437` — convert, don't delete.** This is the cheapest possible ADR-023
compliance in the bundle. The dict is dead *because nothing reads it*; Item 1's entire job is to give
`director.fire_support` a source. Have the fix do
`director.fire_support = plan.get("fire_support", DEFAULT)` and the fossil becomes live data in one
line. **If the council instead picks a different budget source, `:437` MUST be deleted in the same
change** — otherwise the bundle ships two plausible-looking fire-support budgets in the generator and
the director, which is verbatim the Summoner's stated reason for this law ("multiple things that
could accidentally be interpreted by you as the same thing"). Probe assertion 3 in §A/Item 1
(provenance) is what keeps this honest.

**`radio_handset.gd` / `radio_cord.gd` — grandfathered, and Item 1 does not replace them.** The live
radio is the RTO's baked-in PRC-25 (`model_actor.gd:319,329-330`) plus `_radio_check()`. The handset
scripts are ADR-023 **category 2 (UNFINISHED — built ahead of its wiring)**, bead `mywr`, and cutting
them is a separate decision. **But the `"radio"` action on key G is different**: Item 1 is literally
radio work, and an input action named `radio` that nothing reads is a live trap for the next agent
adding a radio verb — including the agent that implements this bundle. Delete the binding. Cost:
one line in `project.godot`.

### Baseline mechanics — read this before deleting anything

`tests/fossil_baseline.json` keys entries as `file|kind|symbol` and `test_fossils.gd` scans **const /
func / signal declarations**. Consequences for this bundle:
- The `"flinch"` dict key, the `"fire_support"` dict key, and the `"radio"` input action are **not
  baseline entries** — deleting them requires **no baseline edit**. They also mean the machine will
  never catch them, which is why the council has to.
- If any item deletes a real `const` / `func` / `signal`, shrink the array **and decrement the
  `count` field** (currently `145`). A stale count is itself a failure mode.
- **Regenerating the baseline to silence a failure remains the one forbidden move.**

### One thing outside this bundle that the Arbiter should see

`fossil_baseline.json` reads `"count": 145`. ADR-023 grandfathered **79** and states plainly: *"the
register only shrinks."* It has grown by 66 entries. I am not proposing action in this bundle — that
is a session of its own and the briefing forbids sprawl. But **the ratchet has been running
backwards**, and the law's own health metric is the last number that should drift unnoticed. File a
bead.

---

## THINGS BIGGER THAN ONE SESSION (flagged, per instruction)

1. **Full death theater** (Item 4's other half). Needs `death_from_the_left` + a stance-aware set
   that do not exist. Blender work, out of scope. Ship procedural flinch + selection among existing
   clips; say so in the closing comment.
2. **Item 3's `activation_range`.** Making garrisons *move* is cheap and in scope. **Raising
   `activation_range` creates bodies, and bodies are 95-97% of AI cost.** That is a separate,
   measured decision gated on the §A/Item 3 assertion 5 perf ceiling. Do not let the two ride
   together — if they ship as one change and the frame drops, we will not know which one did it.
3. **`fossil_baseline.json` 79 → 145.** Its own session.
4. **The two-camera-source split** between `squad_nameplate` (`get_viewport().get_camera_3d()`) and
   `mission_hud._update_markers` (`world.player.get_node("Head/Camera3D")`, `:239`). Latent, not
   active. Bead it.
5. **`_danger_close_to_squad` never checks the PLAYER's own distance** (`field_director.gd:320-328`,
   ADR-011 amendment, still open). Adjacent to Item 1 and I noticed it again; still not this
   bundle's item. It means the player can call fire on himself with no confirm.

---

## SUMMARY OF RULINGS

1. **Six of seven probe honestly headless. Item 4 is PARTIAL** — the reaction's *appearance* is
   unverifiable and must be reported as such, never claimed green.
2. **`get_viewport().get_camera_3d()` and `unproject_position` both work headless in 4.7.** Camera
   registration and projection are scene-tree/matrix math, not renderer state. `scaling_3d/scale`
   does not affect `unproject_position` (it uses the visible rect). **But assert relative geometry —
   centring, monotonic tracking, above-the-feet — never literal pixels.**
3. **Item 7 is a category error, not a missing `.position`.** The nameplate belongs to the
   `_marker_box` family (full-rect root + per-frame `unproject_position`), not the anchored-panel
   family. Adding a static offset would be wrong in a new place.
4. **The other CanvasLayer children are genuinely safe.** Anchors resolve against the viewport for a
   Control parented to a CanvasLayer, and every sibling re-stamps `.position` after its preset. No
   change. Out of scope.
5. **Procedural flinch is the right call — but lazily instantiated, spine-only, capped at 8
   concurrent, gated on `perceivable()` and explicitly NOT on `_body_gate_open()`** (which is always
   open for a man who was just shot, and would be a guard that guards nothing). Closes on a measured
   `PERF_LEDGER` entry, not on my arithmetic.
6. **A trap needs exactly ONE Hitzone on layer 512.** A body + hp is provably not enough:
   `bullet_system.gd:112-133` only resolves damage through a `Hitzone` or through group membership in
   enemies/player/allies. Blast gets a fifth loop in the existing router — a fifth client, not a
   second router.
7. **Informer: direct `director.on_informer_escaped(pos)` call, one-shot consumed before the spawn.**
   The flag-mailbox and its lying comment die together (TRUTH LAW); the debrief record survives.
8. **Delete in this bundle:** `sprite_state_map.gd:138` `"flinch"`, the `"radio"` key-G binding, the
   keycode-54 collision; and either read or delete `mission_generator.gd:437`. **Leave:**
   `radio_handset.gd` / `radio_cord.gd` (grandfathered, not replaced by anything here). **None of
   the deletions require a `fossil_baseline.json` edit** — none are `file|kind|symbol` entries.
