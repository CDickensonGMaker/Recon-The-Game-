# GAMEPLAY-PROGRAMMER — the CPU half

**War Room:** 2026-07-26 FPS deep dive · **Lens:** CPU. Where the milliseconds actually go in
`_physics_process`, the animation/skeleton path, and the resident population.

Everything below is labelled **MEASURED** (a ledger row, cited by line), **INFERRED** (read from code,
arithmetic on measured inputs), or **GUESSED** (neither — an opinion, ranked last). POINTER LAW: every
code claim carries `file:line`.

---

## 0. HEADLINE FINDINGS (four, in order of size)

1. **The physics tick rate is the multiplier on the entire AI wall, and `physics_interpolation` — the
   one feature that makes lowering it safe — is ALREADY ON and unexploited.** `project.godot:300`
   reads `common/physics_interpolation=true`; there is **no `physics_ticks_per_second` key in
   `project.godot`** (grep count 0), so the project runs the engine default **60 Hz**. Every measured
   AI millisecond in the ledger is *per physics tick*, and the tick is saturated
   (`PERF_LEDGER.md:288` — "720 physics frames in 12s window (8-step saturated)" = 60/s sustained).
   Halving the AI body rate halves think + move + hitzone + execute **together**.

2. **`HitzoneBuilder.sync` runs on TWO paths, and the WA-A2 body gate only closes ONE of them.**
   `hitzone_builder.gd:164-166` connects an ungated closure to `Skeleton3D.skeleton_updated`.
   The body gate lives only on the physics-tick call (`enemy_base.gd:463-464`,
   `ally_base.gd:447-448`). A gated man's AnimationPlayer keeps advancing, the skeleton keeps
   emitting, and his 11 hulls keep re-syncing on the render frame. **The gate leaks.**

3. **There is ZERO animation LOD in this project.** Grep across `scripts/visuals/`,
   `scripts/enemies/`, `scripts/allies/`, `scripts/world/civilian.gd` for
   `.active =` / `callback_mode` / `visibility_range` / `VisibleOnScreenNotifier` returns **no hits on
   any character**. Every character with a rig ticks a full Mixamo skeleton every render frame at every
   distance, forever. `ModelActor` holds `_anim` and `_skel` (`model_actor.gd:105-106`) and never
   throttles either.

4. **ADR-025's DORMANT/AGGREGATE tiers are FOSSIL — correctly and completely buried.**
   `scripts/autoload/world_sim.gd` is now **34 lines**: a flat id→dict registry with `register`,
   `count_live`, `clear_if_needed`. `update_player`, `materialize_near`, `dematerialize_far`,
   `_advance_abstract_cells` are **gone from the file**. ADR-025 itself is `SUPERSEDED` at its line 3.
   The burial was executed. **Do not resurrect it, and do not budget CPU savings against it.**
   What replaced it is `LazyGroup` (below), which is live.

---

## 1. WHERE THE CPU MS GO TODAY

### 1a. The measured four buckets — and what they DO NOT contain

| bucket | W0, 65-67 live (MEASURED `PERF_LEDGER.md:291-295`) | WA-A2 HEAD, 69 live (MEASURED `:334`) |
|---|---:|---:|
| think | 1.28 ms | 0.440 ms |
| move_and_slide | 9.06 ms | 3.182 ms |
| hitzone sync | 10.43 ms | 4.137 ms |
| "anim"/execute remainder | 19.04 ms | 7.259 ms |
| **SUM / physics tick** | **39.8 ms** | **15.0 ms** |

The two rows differ ~2.6× at the same population; the ledger says so itself and refuses to attribute
the delta (`PERF_LEDGER.md:348-351`). **Use the ratios, not the absolutes.** The ratios are stable
across both rows and both runs:

- **execute remainder ≈ 48%** of the wall
- **hitzone sync ≈ 26%**
- **move_and_slide ≈ 22%**
- **think ≈ 3%**

**NO-DRIFT CORRECTION #1 — the four buckets are NOT the AI's total CPU cost, and the ledger's
attribution language hides it.** `ai_stress_arena.gd:346-347` states the contract plainly: *"Physics-side
AI split ... the usec the agents accumulate on CombatManager inside `_physics_process`."* Therefore:

- The `skeleton_updated`-driven `sync()` (`hitzone_builder.gd:164-165`) is an **idle-frame callback**.
  Its cost lands in **no bucket at all**. `ai_usec_hitzone` under-reports true hitzone cost.
- The **AnimationPlayer advance and the Skeleton3D pose solve itself** — the actual skeletal animation
  engine — is also an idle-frame cost and is in **no bucket at all**. It has never been measured in
  this project.
- The bucket named `ai/anim` (`ai_stress_arena.gd:355`) **contains no animation engine time
  whatsoever.** It is computed as `(t_move - t_sync) - usec_think` (`enemy_base.gd:521`), i.e.
  `_update_decay` + `_update_think_lod` + `_execute` + `_update_unstick` + the low-posture clamp. It is
  the **AI behaviour execute**, and the name has been misleading every reader of this ledger. *(Recorded
  here as the correction; the ledger row itself is left as measured per ADR-014.)*

### 1b. Hitzone sync — the exact mechanism (INFERRED from code, arithmetic)

Per unit, `HitzoneBuilder.build` creates **11 `Hitzone` (Area3D) children** for enemies
(HEAD/BODY/GUT + 8 limb segments — `hitzone_builder.gd:115-156`, `with_gut=true` at
`enemy_base.gd:442`) and **10** for allies (`with_gut=false` at `ally_base.gd:436`, collapsing GUT into
BODY at `hitzone_builder.gd:134-139`).

`sync()` (`hitzone_builder.gd:188-225`) then, **per zone, per call**:
1. two `skel.get_bone_global_pose()` lookups and two `skel.global_transform *` multiplies (`:208`, `:212`)
2. a midpoint, a normalize, two cross products, a `Basis` construct and a `Basis` multiply (`:215-224`)
3. **`hz.global_transform = ...` (`:225`)** — this is the expensive line.

Line `:225` is not a store. `Node3D.set_global_transform` must convert world→local, which computes
**`get_parent().get_global_transform().affine_inverse()`**. Godot caches the parent's global transform
but **not the inverse** — so this is **one 3×4 matrix inversion per zone**, i.e. **11 inversions per
unit per sync**, where **one** would do. It then propagates the transform to `PhysicsServer3D`
(`area_set_transform`) → Jolt moves the area body → **broadphase re-insert**. The broadphase update is
the dominant term and is why hitzone sync is 26% of the wall while `think` is 3%.

**Call volume, INFERRED:**

| path | rate | gated by the body gate? |
|---|---|---|
| physics tick (`enemy_base.gd:463-464`) | **60/s per unit** | **YES** (`_body_hot`) |
| `skeleton_updated` (`hitzone_builder.gd:164-165`) | **~render fps per unit** (~20-34/s shipped) | **NO — ungated** |
| corpse re-sync (`enemy_base.gd:459-462`) | 6.25/s, and gated | YES |

At 13 live at hub start (MEASURED, `PERF_LEDGER.md:360`) that is ~143 zones × ~85 syncs/s ≈ **12,000
Area3D transform writes/second**. At the arena's 65-71 live it is **~60,000/second**. Each carrying a
redundant matrix inversion.

### 1c. The resident population and what tiers it (MEASURED + code)

- `fsb_main`: **678 meshes / 1,116 bodies + 4 villages + 3 camps resident** (MEASURED,
  `PERF_LEDGER.md:263`).
- **Live characters at hub start: 13 — 5 enemies, 8 allies** (MEASURED, `PERF_LEDGER.md:360`).
  This is the number that matters and it is *small*. The 1,116 bodies are overwhelmingly world props,
  not men.
- **`LazyGroup` is the live population tier**, and it is the ONE that shipped.
  `lazy_group.gd:49-61` polls player distance at 1 Hz and spawns at `activation_range` (default 120m,
  `:8`); `force_spawn` then calls `set_physics_process(false)` (`:69`) so a spawned group costs nothing
  further. Camps are seeded as `"lazy": true` (`mission_generator.gd:613-614`), ambient patrols at
  `:656-657`, friendlies at `:730`. **This is why hub-start population is 13 and not 200.**
- **Civilians have a real, live 3-tier LOD** — `civilian.gd:83` `lod_tier`, radii at `:81`
  (`LOD_FAR_RADIUS = 300.0`) with hysteresis `:82`, recomputed every 2s (`:87`), and a hard body skip
  at `civilian.gd:207-210`. Civilian hitzones use the **static-band** path
  (`civilian.gd:154` → `_build_static`), which returns **no sync entries** — so civilians cost **zero**
  per-tick hitzone sync. Civilians are already the cheap class.
- **Enemies have a think-rate LOD only** — `enemy_base.gd:37-52`: 0.15s inside 80m, 0.3s to 150m, 0.6s
  beyond, recomputed every 2s. It throttles **think**, which is 3% of the wall. It touches nothing else.
- **Allies have NO think LOD at all** — `ally_base.gd:473` tests `think_timer >= THINK_INTERVAL`, a bare
  constant. There is no `_update_think_lod` in `ally_base.gd`.
- The **WA-A2 body gate** (`enemy_base.gd:528-543`) opens on: downed, COMBAT, `alert_tier > RELAXED`,
  cover-exit window, `velocity² > 0.01`, `CombatManager.perceivable` (150m range / 20m near-bubble /
  camera-forward dot — `combat_manager.gd:42-55`), or a de-phased heartbeat. Gated share at hub start:
  **9.4%** (MEASURED, `PERF_LEDGER.md:360`).

### 1d. What is NOT in any bucket, and is therefore unmeasured (INFERRED it is non-trivial; size GUESSED)

Per character, per render frame, unmeasured today:
- AnimationPlayer track evaluation + the 0.18s crossfade blend (`model_actor.gd:737`)
- the **Skeleton3D pose solve** over a full Mixamo hierarchy
- the resulting `skeleton_updated` → 11 Area3D world-transform writes + broadphase re-inserts
- skinning upload

**This is the single largest unmeasured CPU item in the project.** It scales with *total rigged
characters resident*, not with *live AI*, and it is gated by nothing.

---

## 2. RANKED CPU LEVERS

Ranked by (expected ms) ÷ (work × risk), with RULE #1 — *the world must be FUN to walk and FEEL like
Vietnam* — as a veto, not a tiebreaker.

---

### L1 — Gate the `skeleton_updated` sync callback with the body gate
**Rank 1. Free. Zero gameplay cost. Half a day.**

**Mechanism.** `hitzone_builder.gd:164` installs `func() -> void: sync(model, entries)` with no
predicate. Give the callback the owner's `_body_hot` (both `enemy_base.gd:153` and `ally_base.gd`
already hold it) and return early when the body is gated.

**Correctness argument — why this cannot break a shot.** The gate is only closed when the man is
simultaneously: not downed, not in COMBAT, at or below RELAXED alert, **not moving**
(`enemy_base.gd:533`), and **not perceivable** (`:535`). A stationary unperceivable man's pose is not
changing, so re-syncing his hulls to it is a no-op that costs 11 matrix inversions and 11 broadphase
re-inserts. Staleness is already bounded for him by the `BODY_HEARTBEAT_MS` de-phase (`:537-542`).

**ms saved:** **INFERRED.** Removes the render-frame sync for the gated share. At hub start that share
is 9.4% (MEASURED `:360`) of ~26% of the wall on ~29% of sync calls → small today, **~0.3 ms**. It grows
with resident population exactly as A2 was banked to (`PERF_LEDGER.md:365-367`).

**Sacrifices:** nothing. **Risk:** low — one predicate, and `test_body_gate` already asserts the gate's
contract.

**Honest note:** this is a *correctness* fix to a shipped gate that leaks, not a big win on its own. It
is rank 1 because it is free and because L4 depends on the same seam.

---

### L2 — Kill the redundant per-zone matrix inversion in `sync()`
**Rank 2. Free. Zero gameplay cost. Zero behavioural change. Half a day.**

**Mechanism.** `hitzone_builder.gd:225` writes `hz.global_transform`, forcing Godot to compute the
parent's `affine_inverse()` **once per zone**. All 11 zones share one parent (the body — they are
added as its children, cf. `HitzoneBuilder.clear` iterating `body.get_children()` at `:174-180`).
Hoist the inverse out of the loop and write **`hz.transform = parent_inv * world_xf`**.

**ms saved:** **INFERRED** — removes 10 of 11 matrix inversions per unit per sync. This is roughly
**~20-30% of the CPU-side arithmetic in `sync`**, but *not* of the broadphase cost, which is untouched
and is the larger term. Against a 26%-of-wall bucket, call it **~0.5-1.0 ms at arena population**;
proportionally less at hub. Needs the L7 sub-bucket probe to size honestly.

**Sacrifices:** nothing — bit-identical transforms. **Risk:** very low. Guarded by
`test_actor_damage_contract` and the hitzone bench.

---

### L3 — Animation LOD: throttle the skeleton for distant/unperceivable characters
**Rank 3. THE BIGGEST UNCLAIMED CPU WIN. Named look cost, manageable. 2-4 days.**

**Mechanism.** There is no animation LOD anywhere (§0.3). Add one authority on `ModelActor` — it
already owns `_anim` and `_skel` (`model_actor.gd:105-106`) — driven off the same
`CombatManager.perceivable` oracle the body gate uses (`combat_manager.gd:42-55`), so there is ONE
perceivability authority and no new LOD notion (FOSSIL LAW: this must **replace**, not join, any
future anim-LOD idea).

Three bands, and the middle one is the important one:
- **near / perceivable** → untouched, full rate.
- **far but visible** → **rate-throttle**, do not stop: round-robin `AnimationMixer.active` so the
  mixer advances at ~15 Hz instead of every render frame. At 150m a man is a handful of pixels; a
  15 Hz pose is not resolvable. Effective ~50-75% cut in skeleton solves **and** in the
  `skeleton_updated` sync callbacks for that band.
- **unperceivable** (behind the camera, or beyond `PERCEIVE_RANGE`) → `active = false`. Nothing is
  being looked at.

**ms saved:** **GUESSED** — because the animation engine's cost has never been measured in this project
(§1d). It is the largest unmeasured item and it scales with *resident* characters. **This lever must
not be scheduled until L7 has measured it.** Naming a number here would be exactly the fabrication this
ledger exists to prevent.

**Sacrifices — RULE #1, named:**
- A frozen man is a **dead world**. `active = false` must fire only when genuinely unperceivable, or
  the jungle becomes a wax museum on every camera turn — the failure mode that makes a world *not fun
  to walk*.
- **Pop on re-entry.** A man whose mixer resumes after 2s of `active=false` resumes mid-clip at the
  wrong phase. `ModelActor.play` already preserves cycle phase across loop→loop switches
  (`model_actor.gd:730-741`); the resume path needs the same care or you get a visible snap.
- Hysteresis is mandatory. `civilian.gd:82` (`LOD_HYSTERESIS`) is the in-repo template; copy it.

**Risk:** **medium-high**, and it is a LOOK risk, which per the briefing ranks it below look-free
levers. The 15 Hz band is the safe half and should ship first and alone.

---

### L4 — De-phase the AI body to 30 Hz (the RULE #1-safe half of the tick-rate lever)
**Rank 4. Largest single measured win. Named AI-fidelity cost. 2-3 days.**

**Mechanism.** Do **not** change `physics_ticks_per_second` globally (see L4b). Instead run each AI's
BODY on alternating physics ticks, split even/odd by `get_instance_id()` — the same de-phasing trick
`enemy_base.gd:539` already uses for the heartbeat — and pass `capped_delta * 2` on the ticks that run.
The player keeps full 60 Hz. Gravity, `move_and_slide`, hitzone sync and `_execute` all halve.

**ms saved:** **INFERRED from measured inputs.** move + hitzone + execute = ~96% of the wall
(`PERF_LEDGER.md:291-295`). Halving their rate is **~45-48% of the AI wall**, i.e. **~18-19 ms/tick at
the W0 65-unit row**, **~7 ms at the WA-A2 HEAD row**. Amortised over wall-clock this is the single
largest number in this document. At hub-start population (13 live) it is proportionally much smaller —
**this lever pays off in firefights, not on the walk out.**

**Sacrifices — named:**
- **AI reaction granularity halves** (16.7 → 33 ms). Below human perception for a rifleman; Pillar 1
  ("AI that fights like soldiers") is not threatened by 33 ms.
- **`move_and_slide` resolution halves.** A 5.5 m/s sprinter (`model_actor.gd:770`) steps 18 cm per
  solve instead of 9 cm. Acceptable against 0.5m-scale collision geometry, but **thin colliders and
  doorways are the risk** — the 26 enterable village buildings are exactly where a tunnelling bug
  would show. `_update_unstick` (`enemy_base.gd:507`) is the existing mitigation and must be verified
  to still fire.
- **Doubling delta changes every accumulator.** `think_timer`, `_lod_timer`, `_downed_bleed_s`,
  suppression decay, `damage_decay_timer` all integrate `capped_delta`. Correct if the doubled delta is
  passed consistently; **silently wrong if one path is missed.** This is the real hazard, not the
  physics.
- The `minf(delta, 0.066)` cap (`enemy_base.gd:485`) will now **clip** a doubled 60 Hz delta
  (0.033 → fine) but interacts badly under frame spikes. Re-derive the cap.

**Risk:** **medium.** Broad blast radius across live AI. Ships behind a probe that walks a squad through
a village doorway.

---

### L4b — Global `physics_ticks_per_second = 30`
**Rank 4b — the one-line version of L4. NOT recommended as the first move; it is a Summoner question.**

**Mechanism.** Add `physics/common/physics_ticks_per_second=30` to `project.godot`.
**`common/physics_interpolation=true` is already set (`project.godot:300`)** — that is precisely the
feature that keeps 30 Hz physics rendering smoothly, and it is already paid for.

**ms saved:** **INFERRED** — halves *everything* on the physics tick, AI and world alike; strictly more
than L4.

**Sacrifices — and this is why it ranks below L4:** it halves the **player's** movement tick too.
Mouse-look is unaffected (it is input/idle-driven), but acceleration, jump, slope handling and
`move_and_slide` for the player all coarsen. **This is a FEEL change to the thing the Summoner's hands
are on**, and RULE #1 says his hands and eyes decide, not a millisecond count. It also silently
re-times any accumulator elsewhere in the project that assumes 60 Hz.

**Verdict:** do not ship this on an agent's judgement. **Put it to the Summoner as an A/B he walks**,
after L4 is measured. If he cannot feel it, it is the cheapest large win available anywhere in this
document.

---

### L5 — Collapse the far-distance hitzone set from 11 hulls to 4
**Rank 5. Real win, near-zero gameplay cost, but it is a new mechanism. 3-4 days.**

**Mechanism.** Beyond ~50m, swap the 11-zone set for 4: HEAD, BODY, GUT, and **one** LIMB zone.
**All of ADR-016's damage math survives intact** — HEAD fatal, TORSO ×2.5, GUT ×2.25, LIMB ×1.0
(`hitzone.gd:16-21`) — because `Hitzone` keys damage on `zone_type`, and the four *types* are all
preserved. What is lost is only **limb identity** (`zone_label_override`, `hitzone.gd:27-30`), which
`hitzone.gd:29` states outright is **"Lab-only ... live wound/damage logic keys on the four type
names and must never see region strings."**

**ms saved:** **INFERRED — 64% of hitzone sync cost for every unit beyond 50m**, both transform writes
and broadphase re-inserts. Against a 26%-of-wall bucket this is **~1.7 ms of the W0 39.8 ms row** if the
whole population is far, scaling down with the near share.

**Sacrifices:** limb-specific gore/cripple selection degrades beyond 50m — `HitzoneBuilder.base_region`
(`:57-58`) feeds the gib map, so a far-killed man's severed limb becomes generic. At 50m+ this is not
readable. **Named, but genuinely small.**

**Risk:** **medium** — a zone-set swap must retire the old set first or the man wears two overlapping
sets, one dead. `HitzoneBuilder.clear` (`:174-180`) exists for exactly this and its docstring
(`:170-173`) already warns of the failure. Hysteresis mandatory.

---

### L6 — `monitoring = false` on every Hitzone
**Rank 6 by size, but it is the cheapest line in this document. 1 hour.**

Covered in full in §4.1 (cheap wins). Placed here so the ranked list is complete.

---

### L7 — Sub-bucket the 48% "execute remainder"
**Not a lever. The PREREQUISITE for ranking L3 and confirming L4.**

`ai_usec_anim` is 48% of the wall and is a **black box** — it is `_update_decay` + `_update_think_lod` +
`_execute` + `_update_unstick` + the low-posture clamp (`enemy_base.gd:521`), and it contains no
animation. Add `Time.get_ticks_usec()` brackets around `_execute` vs the rest, and inside `_execute`
around `_update_sprite` (`enemy_base.gd:1303-1304`), then add a **fifth, idle-frame** counter for the
`skeleton_updated` sync path and the mixer advance so §1d stops being invisible.

Suspects inside `_execute`, all **INFERRED, none measured** — do not act on these without the probe:
- `SpriteStateMap.intent_for` runs **every tick per unit** (`enemy_base.gd:410`) with a string-compare
  chain and a 180 ms stability filter (`:411-422`).
- `ModelActor.play` early-outs correctly when the clip is unchanged (`model_actor.gd:711-712`) — likely
  **not** a suspect.
- `set_locomotion_speed` (`model_actor.gd:781-788`) runs unconditionally each tick: a Dictionary
  lookup + clamp + `speed_scale` write. Cheap, but ×N×60.
- The per-state `_execute_*` handlers (`enemy_base.gd:1364-1909`) — 10 of them, the real bulk.

---

## 3. THE HITZONE SYNC QUESTION (highest-value output)

**What it IS, mechanically:** eleven `Area3D` nodes per man, whose world transforms are recomputed from
live skeleton bone poses and written into the Jolt broadphase **60 times a second from the physics tick
and again on every render frame from a `skeleton_updated` signal**, each write paying a redundant
matrix inversion. The zones are bone-riding convex hulls, not capsules
(`hitzone_builder.gd:1-2`, `:94`).

`hitzone_builder.gd:9-12` states the design contract: *"Zones ride their bones on
`Skeleton3D.skeleton_updated` (wired by `build()`), but callers MUST ALSO call `sync()` every physics
tick — that covers parent motion the skeleton never sees."* **The contract is correct and the
double-path is deliberate.** `skeleton_updated` fires on pose change; it does not fire when the parent
body translates. Both paths are genuinely load-bearing **as written**.

**Why it is expensive:** not the vector math — the **broadphase**. Every `hz.global_transform =`
(`:225`) re-inserts an area into Jolt's broadphase. 143 areas at hub, ~715 in the arena, at
60 + render-fps writes each.

**The cheapest CORRECT fix, in order:**

1. **L1 — gate the `skeleton_updated` path with `_body_hot`.** Free, and it fixes a leak in an
   already-shipped gate rather than adding a mechanism. Do this first regardless of anything else in
   this document.
2. **L2 — hoist the parent inverse out of the zone loop.** Free, bit-identical, no behaviour change.
3. **L5 — 11→4 zones beyond 50m.** 64% cut with all four ADR-016 damage types intact.

**What I explicitly do NOT recommend, and why:** a *rate*-LOD on `sync` alone (e.g. "sync at 6 Hz past
60m"). It looks like the obvious fix and it is a **Pillar 1 violation**. At 6 Hz a man running 4 m/s
carries hulls up to **0.67 m** behind his rendered body. Bullets are raycasts against these areas
(`bullet_system.gd:80`, `enemy_base.gd:2014`, `ally_base.gd:1174`, `weapon_holder.gd:472`) — so a
well-aimed shot at a crossing runner at 80m would **pass through him**. "Weapons that kill like weapons"
is half of Pillar 1. **A perf fix that makes hits not register is not on the table.**

If a rate LOD is ever wanted, the correct form is **sync-on-demand**: force-sync the zones of units near
a ray immediately before the query, at the four raycast sites above. That is a new system and belongs
behind L1/L2/L5.

---

## 4. CHEAP WINS NOBODY HAS TAKEN

**4.1 — `Hitzone` monitors for overlaps that nothing consumes. `hitzone.gd:38`.**
`_ready()` sets `monitoring = true` **and** `monitorable = true`. A grep for
`area_entered|body_entered|area_shape_entered|get_overlapping` across `scripts/` finds **no consumer on
any Hitzone**: the hits are `grenade.gd:72`, `mission_trigger.gd:65`, `projectile_base.gd:60-61`,
`fire_hazard.gd:53` — none of them a `Hitzone`. **All damage into hitzones arrives by raycast**
(`bullet_system.gd:80`; `enemy_base.gd:2014`; `ally_base.gd:1174`; `weapon_holder.gd:472,604,650`;
`projectile_base.gd:247`).

- **`monitoring = false` is safe** — it controls only whether the zone generates its own overlap
  callbacks, which nothing reads. It removes ~143 areas at hub (~715 in the arena) from Jolt's
  per-step area-monitoring pass.
- **`monitorable` MUST STAY `true`** — `projectile_base.gd:60,279` is an `Area3D` that detects hitzones
  via `_on_area_entered`. Turning it off would silently stop grenades and rockets hurting men. *(Named
  because it is the trap next to the win.)*
- `hitzone.gd:54` sets `collision_mask = 8` (player_hitbox) on enemy zones — a layer no live shape was
  found on. With `monitoring = false` the mask becomes moot.

**ms saved: INFERRED, small-to-moderate, unmeasured.** Cost: **one line, one hour, zero gameplay
change.** Best effort-to-certainty ratio in this document.

**4.2 — Allies have no think LOD. `ally_base.gd:473`.**
Enemies throttle think by distance (`enemy_base.gd:37-52`); allies use the bare `THINK_INTERVAL`.
Porting `_update_think_lod` costs nothing and removes a divergence between two classes that a shipped
decree already merged in part (posture, `PERF_LEDGER`/AI-consolidation). **Small ms (think is 3% of the
wall) but it is FOSSIL-LAW hygiene**: two classes, one behaviour, one of them missing a feature, is the
divergence class already flagged as this project's recurring world-bug source.

**4.3 — `_update_think_lod` runs a `distance_to` every 2 s and never LODs anything but think
(`enemy_base.gd:37-52`).** It is already the distance oracle every unit computes. **Reuse its result**
as the input to L3/L5 instead of computing distance again in a new LOD system. Free, and it prevents a
second LOD authority being born — the exact ADR-023 hazard ADR-025 itself catalogued at its lines 35-48.

**4.4 — Jolt's `max_bodies` is 32768 (`project.godot:299`) against ~1,116 resident bodies
(`PERF_LEDGER.md:263`).** Jolt pre-allocates broadphase structures against this. **Opinion, unmeasured**
— I found no measurement either way, and I am not claiming a win. Worth one line in the measurement
batch (drop to 8192, A/B/A) because it is free to test and free to revert.

---

## 5. WHAT IS *NOT* WORTH DOING (with the evidence that kills it)

| Proposal | Killed by |
|---|---|
| **Optimise perception raycasts** | **MEASURED:** perception rays + think are **~6%** of the AI wall; rays run at **2.53-2.68 per physics frame level-wide** (`PERF_LEDGER.md:289-290, :298-299`). There is nothing here. Stop proposing it. |
| **Optimise `_think()` / the behaviour tree** | **MEASURED:** think = 1.28 ms of a 39.8 ms wall = **3.2%** (`PERF_LEDGER.md:291, :295`). A 50% think win is 0.6 ms. |
| **Tune / widen the WA-A2 body gate** | **MEASURED:** the gate closes on exactly its intended class; the payoff is 9.4% because that class is **9.4% of the population**, not because the gate is wrong (`PERF_LEDGER.md:360-364`). Widening it means gating *perceivable* men — visible freezing. **The mechanism is right; do not tune it. Fix its leak (L1) and move on.** |
| **Resurrect ADR-025 WorldSim DORMANT/AGGREGATE tiering** | ADR-025 is `SUPERSEDED` (`ADR-025:3`); `world_sim.gd` is a 34-line registry with the three tier functions **deleted**. ADR-025:12-14 records the geometric kill-shot (CELL_SIZE/AO_RADIUS can never produce DORMANT on a 1280m map) and that **only 2.8% of the AO is off-AO from spawn**. ADR-025:16-19 records that this ADR **already misdirected an agent into building the condemned consumer once.** The replacement, `LazyGroup`, is live and works. **This is the trap in this brief; do not walk into it.** |
| **Character triangle reduction** | Briefing §4: cutting 33% of prims and 77 draw calls moved FPS ~0. Tri budgets are style, not perf. |
| **Switch AnimationPlayer to `CALLBACK_MODE_PROCESS_PHYSICS`** | **Counter-intuitive and worth stating:** the game renders at ~20-34 fps while physics runs at 60 Hz (`project.godot` has no ticks key; `PERF_LEDGER.md:288` shows 60/s sustained). Moving the mixer to the physics callback would **raise** skeleton updates from ~25/s to 60/s — **2.4× worse**. IDLE mode is currently the cheaper one. Leave it. |

---

## 6. NO-DRIFT — doc claims found untrue

1. **`ai/anim` is not animation.** `ai_stress_arena.gd:355` names the bucket `ai/anim` and the ledger
   rows call it "anim/execute remainder" (`PERF_LEDGER.md:294, :300`). It is computed at
   `enemy_base.gd:521` as everything between the hitzone sync and `move_and_slide`, minus think — the
   **AI behaviour execute**. It contains **zero** animation-engine time. *(Ledger rows left as measured
   per ADR-014; correction recorded here and in the briefing's §3 answer.)*

2. **`ai_usec_hitzone` under-reports hitzone cost.** The counter brackets only the `_physics_process`
   call (`enemy_base.gd:450-466`, `ally_base.gd:440-450`), and `ai_stress_arena.gd:346-347` states the
   buckets are physics-side only. The `skeleton_updated` sync (`hitzone_builder.gd:164-165`) is an
   idle-frame callback and is **counted nowhere**. The true hitzone cost is **higher** than the
   MEASURED 10.43 ms (`PERF_LEDGER.md:293`).

3. **ADR-025's "Evidence" section is stale.** `ADR-025:106-108` cites `world_sim.gd` line numbers
   `:70/:86/:99/:111` for `update_player`/`materialize_near`/`dematerialize_far`/`_advance_abstract_cells`.
   **The file is 34 lines long and contains none of them.** The ADR's SUPERSEDED banner (`:3`) already
   voids the instruction, so this is a dead pointer inside a dead ADR — recorded, not "fixed", because
   ADR-014 keeps superseded ADRs as written.

4. **The briefing's own framing of ADR-025 needs correcting.** Briefing §3 line 84 asks whether the
   "DORMANT / AGGREGATE tiers (ADR-025)" are a live lever. They are neither live nor a fossil — they
   were **correctly deleted**, and the ADR is superseded. The live population lever is `LazyGroup`
   (`lazy_group.gd:49-69`) plus the civilian `lod_tier` (`civilian.gd:83, :207`). The council should
   budget against those, not against WorldSim.

---

## 7. MEASUREMENT — what I propose, and exactly what it does and does not prove

**One headless CPU probe, and no windowed claim from me.**

**Proposal:** extend the existing bucket instrumentation (L7) — sub-brackets inside `_execute`, plus a
**new idle-frame counter** wrapping the `skeleton_updated` sync callback and the mixer advance — then
re-run `tests/test_arena_perf.tscn` headless on the recipe that produced `PERF_LEDGER.md:291-295`.

**What this PROVES:** the *relative* split of CPU inside the AI — which of the ten `_execute_*` handlers
dominates, what `_update_sprite` really costs, and the first-ever number for the animation/skeleton
path. These are pure GDScript + physics-server costs and the ratios are real.

**What it does NOT prove — stated plainly:**
- **Not ship-parity, and not an FPS prediction.** Headless has no render thread to contend with and no
  GPU sync stall. A 5 ms CPU saving here can show as **0 FPS** on his Intel UHD if the frame is
  GPU-bound at that instant.
- **It will UNDER-count the idle-frame path by roughly 10×.** The headless arena ran at
  **2.2-2.3 fps** (MEASURED, `PERF_LEDGER.md:285`), so `skeleton_updated` fires ~2×/s per unit there
  versus ~25×/s in a windowed run. **Any number the probe reports for the anim/skeleton path is a
  FLOOR, not an estimate.** This is the single most important caveat and it must travel with the row.
- **Not a population-representative scene.** The arena is a 65-71-unit firefight
  (`PERF_LEDGER.md:330-335`); the shipped hub start is **13 live** (`:360`). The arena over-states every
  per-unit lever's importance to the walk-out and under-states nothing.
- **No GPU number, at all.** Per the measurement contract, headless GPU figures are fiction.

**The windowed question I hand to the measurement-engineer** (one A/B/A bracket, `bodies/f run/gated`
overlay line already exists per `PERF_LEDGER.md:322`): **does L6 (`monitoring = false`) move the frame
at fsb_main spawn?** It is one line, instantly revertible, and it is the only lever in this document
that can be A/B/A-tested without building anything first.

---

## 8. RECOMMENDED ORDER

1. **L1 + L2 + L6** — one small change-set. Free, look-free, gameplay-free. Ship together.
   *(L6 gets the windowed A/B/A; L1 and L2 need no measurement to justify.)*
2. **L7** — instrument. Nothing below this line should be scheduled before L7 reports.
3. **L4** — de-phased 30 Hz AI body. Largest measured win; ships behind a doorway/nav probe.
4. **L5** — 11→4 far zones.
5. **L3** — animation LOD, **15 Hz band only**, hysteresis mandatory. Ranked last of the real levers
   because it is the only one that can cost the LOOK, and RULE #1 ranks look-costing levers below
   look-free ones even when they are bigger.
6. **L4b** — global 30 Hz physics: **a Summoner question, walked, not an agent's call.**

**No new `PERF_LEDGER.md` row is written by this analysis.** Nothing here was measured windowed.
