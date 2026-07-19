# TECHNICAL DIRECTOR — Playtest Polish Pass (Batches A/B/C)
Session 2026-07-19. Lens: performance, the probe harness, MEASURABILITY.

Everything below was read out of the code, not the plan. Line numbers are from the tree as of
this session.

---

## 0. THE HEADLINE

**Batch A's real risk is not the 11 Area3Ds. It is that civilians have no body gate, and the
gate they LOOK like they have does not gate the thing that costs money.**

`civilian.gd:336-361 _update_lod()` calls `set_physics_process(false)` at LOD_FAR (>300 m).
That reads like a gate. It is not one for hitzones, because **`HitzoneBuilder.build()` connects
`sync()` to `Skeleton3D.skeleton_updated`** (`hitzone_builder.gd:160-166`) — the sync fires off
the *animation*, not off `_physics_process`. And `model_actor.gd` has **no LOD-driven animation
pause** (grep: `_anim.pause()` appears only in the ragdoll/death paths, `:449` and `:460`).

So a civilian at 600 m with `set_physics_process(false)` keeps his AnimationPlayer running, keeps
his skeleton dirty, keeps emitting `skeleton_updated`, and keeps writing **11 Area3D global
transforms into the physics server every render frame** — while the code reads as "gated".

That is the frame-rate regression this pass could ship into a village, and it would ship looking
correct. Section 2 prices it and prescribes the gate.

---

## 1. F4 — THE HAT PROBE

### 1a. Can a headless Godot probe do this at all? YES, and the precedent is already in the repo.

`tools/probe_worn_gear.gd` already does every primitive the hat probe needs:

- loads a shipped model by unit id — `load(ModelActor.model_path(unit))`, `:11`
- walks to the `Skeleton3D` — `_find_skel()`, `:60-67`
- finds `*_worn` meshes and reads their `BoneAttachment3D` parent + `bone_name`, `:26-30`
- asserts they are RIGID (`mi.skin == null`), `:29`
- **proves bone tracking by moving the head bone 0.5 m and measuring the helmet's travel**,
  `:32-47`

So: yes, a headless probe can load the `.glb`, find `hat_conical_worn`, find `mixamorig_Head`, and
measure their relative placement. The capability question is settled. The design question is what
it measures and in what frame — and that is where a naive version becomes brittle and gets
regenerated into uselessness.

### 1b. THE TWO GODOT GOTCHAS THAT WILL BREAK A NAIVE VERSION

**(i) Stale global transforms.** `hitzone_builder.gd:64-70 _skel_world_scale()` exists *because of
this*, and says it in its own docstring: "the global transform is stale on the session's first
build (it reads 1.0 before ModelActor's rescale propagates) — local scales are always current."
A probe that instantiates a civ GLB and immediately reads `hat.global_position` reads a
pre-rescale, pre-BoneAttachment-update lie. It will produce a number, and the number will be
wrong, and it will be wrong *consistently*, so it will look like a measurement.

Mitigations, both required:
- `await process_frame` **twice** after `add_child`, and call
  `skel.force_update_all_bone_transforms()` before any read (BoneAttachment3D lands its transform
  off the skeleton's update, which in headless with no anim playing may never have fired).
- **Do not measure in world space at all.** Measure in HEAD-BONE REST space (1c). That removes
  ModelActor's k-rescale, the root yaw, and the world placement from the measurement entirely —
  the three things that make a geometry probe flaky.

**(ii) Per-unit scale.** The 8 adult civ units are exported at 1.7132 and the engine rescales each
to `ModelActor.UNIT_HEIGHT_M` — 1.50 to 1.65 (`model_actor.gd:52-55`). An absolute-centimetre
assertion is therefore unit-dependent and will need eight different numbers, which is eight things
to get wrong. Express every threshold as a **fraction of the skull span** (`mixamorig_Head` →
`mixamorig_HeadTop_End`), the exact measure `hitzone_builder.gd:114` already uses to size the HEAD
zone. Scale-invariant by construction, and it survives `civ_kid`'s `head=1.28` skull scaling for
free.

### 1c. THE PROBE — `tests/test_hat_seat.tscn`

**IN THE SUITE, NOT IN `tools/`.** This is the single most important sentence in this document.
`tools/probe_*.gd` are hand-run instruments; the hat regressed twice *while* `probe_worn_gear.gd`
sat in the repo perfectly capable of catching it. A probe nobody runs is not machinery, it is a
fossil with good intentions.

**What it loads.** For every unit in `Civilian.VILLAGERS` (`civilian.gd:58-63`) whose GLB actually
carries a `hat_*` mesh — discovered, not listed, so a new hatted unit is covered automatically and
`civ_kid` (hat=None, `make_civilians.py:121`) is skipped without a special case.

**What it measures.** Per hatted unit, in head-bone rest space:

```
S     = |Head → HeadTop_End|                    # skull span, the unit of measure
F     = skel.get_bone_global_rest(head)          # measurement frame
c_hat = F⁻¹ · (skel.global_transform⁻¹ · hat.global_transform · hat_aabb.center)
dy    = c_hat.y / S     # seat height above the head joint, in skulls
dz    = c_hat.z / S     # forward rake, in skulls
ov    = overlap(hat_aabb, head_region_aabb) / hat_aabb.volume
```

`head_region_aabb` is harvested with the same dominant-bone rule `HitzoneBuilder._harvest()` uses,
so "the skull" means the same thing to the probe as it does to the hurtbox. No second definition.

**The four assertions, each catching a different failure mode:**

| # | Assertion | Catches |
|---|---|---|
| 1 | `hat.skin == null` and parent is a `BoneAttachment3D` on `mixamorig_Head` | export flattened the hat into the body mesh |
| 2 | head bone displaced 0.5 m ⇒ hat moves > 0.4 m (probe_worn_gear's trick) | hat welded to the origin |
| 3 | `|dy − baseline.dy| ≤ 0.05 S` and `|dz − baseline.dz| ≤ 0.05 S` | **THE REGRESSION** — the seat moved |
| 4 | `0.15 ≤ ov ≤ 0.60` | hat floating above the skull, or swallowing the face |
| 5 | mesh name matches a `_GEAR_NAME_HINTS` entry (`hitzone_builder.gd:43`) | a renamed hat becoming a fatal-headshot hurtbox |

**Assertion 5 is not decoration.** `_GEAR_NAME_HINTS` catches on the substring `"hat"`. Rename the
mesh to `nonla_worn` in a future export and the rice hat is silently harvested into the HEAD hull —
you could kill a farmer by shooting the air above his head. That is a live one-word-away bug and
this probe is where it gets caught.

### 1d. WHY A BASELINE, AND WHY IT IS THE ONLY HONEST DESIGN

**A probe cannot know what looks right. It can know what CHANGED from the frame Caleb blessed.**

Caleb hand-placed the hat three times and was right three times (`make_civilians.py:154-165` — his
own numbers, folded back in). The machine has no eye. So the pass window is not derived from
anthropometry, it is derived from **his last blessed export**:

`tests/hat_seat_baseline.json` — `{unit: {dy, dz, ov, S}}`, written ONLY under an explicit
`-- --bless` cmdline flag, exactly the `test_fossils.gd:33` / `--write-baseline` discipline. And
carrying the same forbidden-move warning in its `_comment` field, verbatim in spirit:
**re-blessing to silence a red probe is the one forbidden move.** A fourth regression that gets
blessed is a fourth regression.

Difference from the fossil register, stated so nobody mis-copies the pattern: the fossil baseline
**only shrinks**; the hat baseline **only changes when Caleb has looked**. Enforce it socially in
the ADR and mechanically by making `--bless` print, per unit, the old and new values and the delta
in centimetres — so a silent bless is impossible to do without reading what you moved.

**Guard against a corrupt bless:** assertions 4 and 5 are ABSOLUTE, not baseline-relative. A
baseline blessed on a broken export still fails them. The baseline can drift the seat by taste; it
cannot bless a hat floating 30 cm over a skull.

### 1e. BRITTLENESS AUDIT (the honest part)

- **Axis sign.** Whether "forward" is `−Z` in head-rest space depends on the export's bone roll. Do
  not guess. **First run prints measured `dy/dz` per unit; the sign convention is read off that
  print and written into the docstring, once.** (Memory law: never guess in Blender — and never
  guess in a bone frame either.)
- **AABB centre vs. brim.** A conical hat's AABB centre is above its brim. That is fine — the
  baseline captures whatever convention is used, consistently. Do not "improve" the centre
  definition later without re-blessing; that would read as a regression.
- **`ov` and inflate.** Compute `ov` against the raw harvested head points, NOT the inflated hull
  (`DEFAULT_INFLATE` = 1 cm, `hitzone_builder.gd:24`), or a tuning change to inflate shows up as a
  hat regression. Different systems, different probes.
- **Runtime cost:** 8 GLB loads, no physics, no frames of simulation. Sub-second. It belongs in the
  standard suite and there is no argument for excluding it on time.

---

## 2. THE PERF COST OF BATCH A — THE RULING

### 2a. THE NUMBERS

**Spawn count (measured, not estimated):**
- `location_planner.gd:59` — **8 to 10 villages per AO**, ringed 350-500 m from the firebase.
- `mission_generator.gd:559-560` — the only live call site passes `civ_range = Vector2i(2, 4)`.
  (The `(3, 5)` default at `:622` has no caller.)
- ⇒ **2-4 civilians per village. 16-40 civilians per AO.**
- Plus 2-4 chickens per village (`:646`) — props, not actors, and they must stay out of scope.

**Cost of an 11-zone sync (measured, `production/PERF_LEDGER.md:273`):**

> W0 headless baseline, `tests/test_arena_perf.tscn`, 65-67 live units:
> **ai ms/physics-frame: hitzone sync = 10.43 / 9.87 ms**

⇒ **~160 µs per actor per physics tick, ~14.6 µs per zone.** This is the project's own measured
number on its own rig, and it is the second-largest line in a 38-40 ms AI wall.

### 2b. THE TWO SCENARIOS

**Scenario A — the village, gated correctly.** 4 civilians in `perceivable()` range:
`4 × 0.16 ms = 0.64 ms` per physics tick. Against a 16.6 ms 60 Hz budget: **~3.9%**. During a
firefight, this stacks on top of the squad and the VC already in view. Acceptable — it buys the
Pillar-1 thing (villagers are shootable) and it is bounded by how many people fit in a village.

**Scenario B — the village, ungated (the default if nobody thinks about it).** All 40 AO civilians
carry zones and all 40 keep syncing off `skeleton_updated` regardless of distance:
**40 × 0.16 ms = 6.4 ms per frame**, ~38% of a 60 Hz budget, **for actors the player cannot see**,
in a game whose measured patrol-world average is 28.8 fps (`PERF_LEDGER.md:250`). That is a
straight -20% to -30% fps hit in open patrol, arriving as "the game got slower after the civilian
pass" with no obvious cause, because the LOD code *looks* like it handles it.

**Scenario B is the default outcome**, because `Civilian.spawn()` builds everything eagerly at
`:66-109` and `_update_lod()` only touches `set_physics_process`.

**One more line item, not to be forgotten:** 40 civilians × 11 = **440 additional Area3Ds** in the
physics broadphase AO-wide, each with a ConvexPolygonShape3D, allocated at world-build time. Even
perfectly gated from syncing, that is a spawn-hitch and a memory cost. Hull *points* are cached per
unit type (`_hull_cache`, `hitzone_builder.gd:52` — 10 villager types, so harvesting is 10 one-time
walks, not 40), but the shapes and nodes are per instance.

### 2c. PRESCRIPTION — the gating civilians MUST use (non-negotiable)

Four parts. Parts 1 and 2 are the ones that matter; skipping either reproduces Scenario B.

**1. LAZY BUILD.** Do not build zones in `Civilian.spawn()`. Build on first entry to
`LOD_FULL`/`LOD_NEAR` in `_update_lod()`, and only then. A civilian in a village 700 m away that
the player never visits should never allocate a single Area3D. This alone converts the AO-wide 440
into the ~8-12 that are actually near the player, and removes the world-build hitch.

**2. DISCONNECT THE SKELETON CALLBACK AT LOD_FAR.** This is the part that will be missed.
`build()` stores the callable at `skel.set_meta("hz_sync_cb", cb)` (`hitzone_builder.gd:166`) —
the retirement path already exists and is already used for rebuilds (`:160-163`). Reuse it: on the
FULL/NEAR → FAR transition, `disconnect` the sync callback (and free the zones, per part 1's
inverse); on FAR → NEAR, rebuild. Do **not** rely on `set_physics_process(false)` to stop hitzone
work. It does not, and `model_actor.gd` never pauses the AnimationPlayer.

*Honesty note, because ADR-015 binds me too:* Godot 4 can skip skeleton updates for skeletons whose
meshes are culled, so the render-rate leak in Scenario B may be partially mitigated by the engine
in the windowed build. **I have not measured that, and I will not claim it.** The prescription is
correct either way, and the measurement is part 4.

**3. MIRROR `_body_hot`.** Civilians get the same gate shape as
`enemy_base.gd:523-538 _body_gate_open()` — hot when perceivable
(`CombatManager.perceivable()`, 150 m / 20 m near-radius, `combat_manager.gd:41-58`), hot when
moving, hot when FLEE/COWER, plus the de-phased 300 ms heartbeat so gated bodies never wake in
lockstep. **Do not invent a civilian-specific gate.** One gate shape, three actor types — this is
exactly the divergent-systems trap the world-build refactor was called to kill, and a fourth
parallel gate is how it comes back.

Gate correctness caveat: a civilian must be hot **while being shot at**, and civilians have no
`alert_tier`. Use `state != WANDER` (FLEE/COWER are the civilian's "in a fight") plus the
`velocity` and `perceivable` clauses. A cowering man 15 m away is inside `PERCEIVE_NEAR` and
therefore hot — the shootability the whole batch exists to deliver is preserved.

**4. THE ACCEPTANCE MEASUREMENT (ADR-015 — this does not close without it).**
Extend `tests/test_arena_perf` / the village harness to report `CombatManager.ai_usec_hitzone`
before and after, in a populated village with the player inside it and a firefight running.
**Gate: total hitzone sync ms/physics-frame must not rise by more than 1.0 ms** over the pre-batch
number on the same seed, and `CombatManager.bodies_gated` for civilians must be > 0 whenever any
civilian is beyond `PERCEIVE_RANGE`. A gate that never gates is `k77e` again.

### 2d. WHAT IS SACRIFICED

Lazy build means the first frame a civilian crosses into NEAR, he allocates 11 shapes. A player
sprinting into a village will hit a small build spike (10 units × harvest is cached; only shape
construction is per instance). That is the trade: a bounded, one-time, player-adjacent hitch in
exchange for never paying for the 30 civilians he cannot see. Take it, and de-phase the rebuilds
across frames if the spike measures above ~2 ms.

---

## 3. BATCH A ITEM 5 — THE RATCHETING ACTOR-TYPE PROBE

Requirement: *every spawnable actor type has hitzones AND gib registration, fails loudly if a new
actor type is added without them.* A hardcoded list does not ratchet. Correct.

### 3a. THE ENUMERATION PROBLEM

Adapting `test_fossils.gd`: its ratchet works because it **discovers** declarations by scanning
`SCAN_DIRS` and judges them against a **baseline that only shrinks**. The discovery is the ratchet;
the baseline is only the grandfather clause. Copy the discovery, invert the baseline's direction.

Note what "gib registration" means here, precisely: **`GibSystem` has no registration call.** It is
pure by-name node lookup at dismember time. So the contract to assert is the **donor contract on
the model** — `grunt_head`, `grunt_forearm_l/r`, `grunt_leg_l/r`, the `cap_*` set, `PSXRig` — not a
registry entry. A probe that looks for a registration function will find nothing and pass forever.

### 3b. TWO TIERS. NEITHER IS SUFFICIENT ALONE.

**TIER 1 — STATIC DISCOVERY (catches a new actor CLASS).**
Scan `res://scripts` for every `.gd` that declares `class_name` **and** contains either
`AgentRegistry.register(` or `add_to_group("enemies"|"allies"|"civilians")`. That is the definition
of "a thing the game treats as an actor", and it is discovered, not listed. Today it yields
`EnemyBase`, `AllyBase`, `Civilian` — and it will yield `VillageMilitia` on the day someone writes
it, without anyone remembering to update a list.

For each discovered class, require in that file or its `extends` chain:
- a `HitzoneBuilder.build(` call, and
- the layer argument ∈ the bullet mask `97 = 1|32|64` (`bullet_system.gd:80`, and the three shooter
  sites the briefing grounded). **Assert the layer numerically**, because
  `Hitzone._setup_groups()` (`hitzone.gd:44-55`) only branches on `player`/`enemies` and silently
  keeps whatever layer it was handed for anything else. A civilian built on layer 2 would pass a
  "has hitzones" check and still be bullet-transparent. That is precisely the bug this batch exists
  to fix; the probe must be able to catch its own recurrence.

Compare the discovered set against `tests/actor_type_baseline.json`. **Inverted direction from the
fossil register:** this is an ALLOWLIST of proven-compliant types, it only GROWS, and a name is
only added *after* the type passes Tier 2. A newly discovered class not in the allowlist **fails
the build with the same loud message shape** as the fossil probe — name the file, name the missing
call, and say what to do.

**TIER 2 — RUNTIME ROSTER (catches "it compiles but the zones aren't there").**
Boot the world builder headless (the `test_world_alive` / `test_patrol_world` pattern) across **8
fixed seeds** — one seed will not spawn every type; the informer→VC transform
(`civilian.gd:252-266`) and the rarer site kinds need several. Then enumerate from the **live
roster**: `AgentRegistry.enemies + allies + civilians`. That roster is the ground truth of what
actually exists in a running AO, and it cannot be fooled by a script that dodged the Tier-1 grep
(e.g. an actor spawned by a scene rather than a `class_name` script).

Per registered actor, assert:
1. ≥ 11 child `Area3D`s in group `"hitzone"`, covering all of `REGIONS_11`
   (`test_hitzones.gd:13-15` already names them — reuse the constant, do not retype it);
2. every zone's `collision_layer` is masked by 97;
3. **exactly ONE zone set** — no region name appears twice. *This catches F2's live player
   double-set today* (`player.gd:446` static bands + `:456 _setup_hitzones()`, 18 zones, same layer
   32) and it catches the next occurrence of it forever. Whether F2 is deleted or beaded this
   session is not my call — but this probe is the thing that makes the answer verifiable either
   way, and if F2 is beaded, this assertion is what stops the bead from rotting.
4. gib donor contract present on `ModelActor.instance_root()`: `grunt_head`, `grunt_forearm_l`,
   `grunt_forearm_r`, `grunt_leg_l`, `grunt_leg_r`, and a `PSXRig` skeleton with the `mixamorig`
   bone set — the exact names `gib_system.gd:103-338` looks up.

**Why both tiers.** Tier 1 catches a type that exists but does not spawn under the test seeds.
Tier 2 catches a type that spawns but whose script dodged the grep. Ship one and you have a probe
with a documented hole, which is worse than no probe because it is trusted.

### 3c. FAILING LOUDLY

Copy `test_fossils.gd:91-100` verbatim in structure: print the count, print each offender with
file and symbol, `push_error` with a one-line statement of the law, `get_tree().quit(1)`. The
message must say what to DO ("build hitzones on a bullet-masked layer for `X`"), not just what is
wrong. And it must name the forbidden move: **adding a type to the allowlist to make the probe
green is the forbidden move.**

---

## 4. F5 — STRAPS: RUNTIME TINT vs `.blend` RE-AUTHOR

### RULING: RE-AUTHOR IN THE `.blend`.

**Reason 1 — it is an authoring value, not a runtime state.** The webbing colour never changes
while the game runs. Paying a per-instance material to express a constant is the wrong side of the
trade in a project whose renderer ADR is a draw-call budget (ADR-026; the patrol-world row measures
**217 draws**, `PERF_LEDGER.md:250`).

**Reason 2 — the cost is a draw-call cost, not a memory cost, and it lands on the whole squad.**
`grunt_dresser.gd:180-193` duplicates then mutates; the alternative (`:14-16`, mutate in place)
tints every grunt on the map, so per-instance duplication is *mandatory* if you go runtime. In
Forward+, a unique material is a unique draw — a 6-man squad with 2 strap materials each is **up to
12 extra draws, ~5.5% on the measured 217**, permanently, for a colour that could have been baked.
Add the VC and the villagers and it grows with the cast.

**Reason 3 — the fossil law forbids it.** `GruntDresser.dress()` has **zero game call sites**
(bead 37mj). Implementing the strap tint there ships a second dead system *on arrival* — a fossil
born pre-buried, in the same session the council is enforcing ADR-023 elsewhere. That is not a
close call.

**Reason 4 — it makes F4 cheaper.** A `.blend` re-author goes down the same
bake → export → import path as the hat, so **one baseline probe covers both**: extend
`tests/test_hat_seat` to read the shipped GLB's `webbing_canvas` / `webbing_steel` albedo and
assert against a blessed colour within a tolerance. It is a material read — no skeleton, no frames,
microseconds. The straps get the same anti-regression machinery the hat gets, for almost nothing.

**WHAT IS SACRIFICED (no free lunches).** The `.blend` route costs a Blender round trip and
Caleb's eye; the runtime tint is ~20 lines and could land today. That is a real cost and I am
naming it, not waving it away.

**THE CONCESSION, if the owner wants it shipped today:** the only acceptable runtime form is a tint
applied ONCE per **unit type** into a material cached by unit id — the `_hull_cache` pattern
(`hitzone_builder.gd:52`) — so the map holds ~10 strap materials, not 40. **Never
`material_override` per instance, and never mutate the shared material in place.** And it carries a
bead to migrate into the `.blend` and delete the runtime path, because a shipped-today tint that
never migrates is the next fossil.

---

## 5. F6 — TRAPS (perf lens only, deferring the design call)

`punji_trap.gd` is a plain `Node3D` polling at 5 Hz within 1.4 m — no Area3D, no body, no health.
Making it destructible is **new collision geometry plus a health path plus a death/VFX path** on an
object that can exist in the dozens per site. From the perf chair: adding a shootable body to every
trap is another broadphase population with no gate designed for it, in a session that already has
one un-gated actor population to fix (§2). **Defer.** Batch A's civilian gate should ship, be
measured, and become the template the trap work reuses — not run in parallel with it.

---

## 6. THE ONE THING MOST LIKELY TO BE GOTTEN WRONG

Ranked, because the parent asked for one and I have to pick.

**#1. Someone builds civilian hitzones eagerly in `Civilian.spawn()`, sees
`set_physics_process(false)` in `_update_lod()`, and concludes the LOD gate covers it.** It does
not. `HitzoneBuilder.build()` connects `sync()` to `skeleton_updated`
(`hitzone_builder.gd:160-166`) and `ModelActor` never pauses the AnimationPlayer, so the sync keeps
firing off the animation for every civilian in the AO. The measured price is
**~0.16 ms per actor per tick × 40 civilians = ~6.4 ms/frame** on a game already at 28.8 fps — and
it ships looking gated. The disconnect in §2c part 2 is one line against existing machinery
(`hz_sync_cb` meta) and it is the difference between +4% and +38%.

**#2. The hat probe lands in `tools/` instead of `tests/`.** `probe_worn_gear.gd` was already
capable of catching both prior hat regressions and caught neither, because nobody ran it. Suite or
it does not exist.

**#3. Someone re-blesses `hat_seat_baseline.json` to turn the probe green.** That is a fourth
regression wearing a passing test. It is the fossil-law forbidden move in a new costume, and the
`--bless` path must print every delta in centimetres so it cannot be done blind.
