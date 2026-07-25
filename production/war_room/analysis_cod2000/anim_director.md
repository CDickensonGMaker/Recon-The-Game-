# ANIM DIRECTOR — CoD-2000 "Living Fight" Deep Dive: Animation as Battle Theater

> **BANNER (corrected 2026-07-25, ghost-code audit):** References to `MISSION_DESIGN_RESEARCH.md`
> below are historical; that doc was deleted on purpose 2026-07-23. Do not seek or restore it. Canon
> is `production/GAME_GUIDE.md` + `production/adr/`.

**Architect:** anim_director (animation / technical direction lens)
**Date:** 2026-07-11
**Query:** How CoD 1/UO/2 (and the MoHAA/RTCW lineage) used ANIMATION to build the sense of a
living fight — and what transplants into RECONgame's open, finite-enemy AOs.
**Builds on:** `production/MISSION_DESIGN_RESEARCH.md` (RTCW/MoHAA systems architecture, pain-quota
stagger §5.6, sprite/anim mapping §6.1) and `production/war_room/synthesis_ai_goals.md` (anim intent
policy, 0.25s debounce, movement-owns-the-legs). Nothing there is re-derived here.
**Ground truth inspected:** the actual 91-clip inventory of `assets/models/characters/anim_library.glb`
(extracted from the glb JSON chunk), `scripts/visuals/model_actor.gd`, `scripts/visuals/sprite_state_map.gd`,
`scripts/enemies/enemy_base.gd` (take_damage/_die/apply_stagger), `scripts/allies/ally_base.gd`,
`scripts/visuals/severed_bones_modifier.gd`.

---

## 1. What CoD-2000 actually did

### 1.1 The engine substrate: fast blends over a big library, not clever blending tech

- **Quake 3-lineage models were split into independently animating parts** (legs / torso / head),
  so legs could run while the torso fired or flinched — that split, not any additive math, was the
  era's "layering." Sources: [polycount Quake 3 Model Manual](http://wiki.polycount.com/wiki/OldSiteResourcesQuake3ModelManual),
  [id Tech 3 overview](https://wolfenstein.fandom.com/wiki/Id_Tech_3).
- **MoHAA moved to skeletal animation (.skd/.skc formats) on the same engine**
  ([format evidence](https://reshax.com/topic/17998-medal-of-honor-allied-assault-skdskc/),
  [Blender plugin thread](https://blenderartists.org/t/medal-of-honor-allied-assault-skd-plugin/482341));
  the OpenMoHAA actor code MISSION_DESIGN_RESEARCH already drew on confirms torso/legs blend on a
  skeleton. *Internals of MoHAA's blend weighting: not verified in this pass — treat as inference.*
- **CoD's animation "brain" was GSC animscripts** — a scripted selection layer over a large clip
  library, with ~0.1s blend times. The documented artifact I could fully verify is the CoD4 stock
  animscript set ([promod/CoD-Stock-Scripts](https://github.com/promod/CoD-Stock-Scripts/blob/master/animscripts/death.gsc));
  the animscript architecture descends directly through CoD1/UO/CoD2 (same studio lineage from
  MoHAA; CoD2 mod tools expose the same structure —
  [CoD modding wiki](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4:_SP_-_Using_Animations)).
  **Caveat, marked:** exact variant counts below are CoD4-documented; CoD1/2 were smaller, earlier
  iterations of the same selector. Directionally identical, numerically unverified for 2003/2005.

**The load-bearing insight:** the CoD-era's tech class is *exactly* what ModelActor already is —
one clip at a time, fast crossfade (theirs ~0.1s, ours 0.18s), a large shared library, and ALL the
perceived sophistication living in the **selection logic**. They did not have additive layers or
blend trees as we think of them. Chasing modern layered blending to "reach CoD feel" would be
solving the wrong problem.

### 1.2 Death selection (verified from `animscripts/death.gsc`)

The death picker is a **matrix, not a list**:

- **Stance:** `self.anim_pose` branches — "stand", "crouch", "prone", "wounded", "back".
- **Direction:** `self.damageyaw` quadrantized into front (135°..−135°), right, back, left.
- **Hit location:** `self.damageLocation` (head, helmet, neck, torso_upper, limbs…) picks
  thematically matching deaths; headshots randomize between ~3 options; `popHelmet()` knocks the
  helmet off as a separate physical flourish.
- **Movement:** dedicated **run-death** logic with directional branching; `anim.lastDeathRun`
  cycles through 6 run-death variants — an explicit **no-immediate-repeat** mechanism.
- **Special cases:** high explosive damage → air-launch (`animMode("nogravity")`); balcony/fall
  prediction → authored tumbles (`%balcony_tumble_railing36_forward`); corner-cover deaths.
- **Scale:** 40+ named death animations referenced in one script.
- **Pain-before-death:** `PlayHitAnimation()` can precede the death anim.

*Marked recollection, not verified:* CoD1/UO/CoD2 deaths were fully authored — no ragdoll physics
in those titles; ragdoll entered the series later. That's WHY their deaths read so characterfully
(a man clutches, spins, crumples — authored acting) and also why they fought on mostly flat,
authored spaces where canned falls land clean.

### 1.3 Hit reactions / flinch (verified from `animscripts/pain.gsc`)

- **Directional quadrant flinches** (`QuadrantAnimWeights()`, clips like `%minorpain_chest_front`,
  `%minorpain_head_back`) selected from `damageYaw` — same matrix shape as deaths.
- **Stance-aware:** standing men may crouch or fall; crouchers play `%crouch_pain_fallToGround`;
  prone plays `%prone_painA_holdchest`.
- **Intensity scaling:** minor flinch weight = `(damageTaken+50)/250`, capped at 1.0 — flinch
  amplitude proportional to damage.
- **Movement survives pain:** pain plays *with* movement states (`painmovement` stop/walk/run
  persists after the reaction) — the man doesn't become a statue to flinch.
- **Wounded behavior emerges from health:** a runner shot mid-sprint may **stumble or drop to a
  crawl** depending on `shotsTillIDie` — the crawl is a hit reaction, not a separate "state" the
  designer placed.
- **Anti-stunlock is explicit:** `waitSetStop()` forces recovery after ~0.2s; wound memory times
  out at 5000ms; blends ~0.1s. AI cannot be flinch-locked. (Our doctrine's pain-quota, §5.6 of
  MISSION_DESIGN_RESEARCH, is the same idea from the RTCW side.)

### 1.4 Why it read as a LIVING fight

Four animation properties did the theater work (chatter/tracers belong to other architects):

1. **No two deaths in a row looked the same** — the matrix + no-repeat cycling means the player's
   eye never catches the loop.
2. **Every hit visibly landed** — directional flinch = the world acknowledges your bullet even on
   non-kills. This is Pillar-1 feedback, not decoration.
3. **Men reacted in transit** — stumbles, dives, run-deaths. Movement wasn't interrupted by
   reactions; reactions were *flavored by* movement.
4. **Context-specific flourishes** (helmet pops, balcony tumbles, corner-cover slumps) fired
   rarely enough to stay remarkable.

---

## 2. What transplants systemically

| CoD-2000 technique | RECONgame transplant | Existing hook |
|---|---|---|
| Death matrix (stance × direction × zone × variant cycle) | Extend `_die()`'s 2-way pick to the full matrix — **the clips already exist** | `last_hit_dir` captured; `take_damage()` receives `zone`; 6 death clips in anim_library |
| No-repeat variant cycling (`lastDeathRun`) | Static last-played-death memory, reroll once on repeat | trivial static var |
| Damage-scaled directional flinch | Pain layer with amplitude = f(damage/max_hp), direction from `last_hit_dir` | pain-quota stagger already triggers at ≥⅓ max HP; flinch is currently invisible (a fire-rate stall only — sprite_state_map.gd header says so itself) |
| Anti-stunlock recovery timers | min-interval + amplitude cap on the flinch layer | doctrine already has the quota concept |
| Runner stumble / wounded crawl by remaining HP | non-lethal solid hit while moving fast → stumble one-shot; crippled → crawl loop | `is_crippled` exists (borrows `injured_walk_backwards`); `falling_to_roll`, `hard_landing`, `laying_breathless` exist |
| Pain-before-death, authored death acting | keep first 0.3–0.5s of authored death clip, then hand off to ragdoll for terrain truth | `start_ragdoll()` Mode A stops the clip by design; currently only wired in the gore lab (`gore_dummy.gd`), NOT in `_die()` |
| Helmet pop | boonie/helmet knock-off prop on headshot | gib system precedent |
| Fast-blend + big-library + smart-selector architecture | **already shipped** — 0.18s crossfade AnimationPlayer + 91-clip shared library + intent funnel | ModelActor as-is |

**The 91-clip inventory, audited against the CoD checklist** (extracted from anim_library.glb):

- **Deaths — 6, already partly directional:** `death_from_the_front`, `death_from_the_back`,
  `death_from_right`, `death_from_front_headshot`, `death_from_back_headshot`,
  `death_crouching_headshot_front`. Missing: **death_from_left**, any run-death, gut-clutch death.
- **Flinch/pain — ZERO clips.** The single biggest library gap vs the CoD kit.
- **Stumble/dive raw material exists:** `falling_to_roll`, `hard_landing`, `jump_away`, `jump_down`.
- **Wounded: no crawl loop.** `laying_breathless` (down, breathing) + `injured_walk_backwards` only.
- **Cover theater is rich:** `stand_to_cover` ×3, `cover_to_stand` ×2, `cover_sneak_l/r`,
  `crouched_sneaking_l/r`, full crouch-walk 8-dir set, `idle_crouching(_aiming)`.
- **Locomotion glue exists unused:** `turn_90_left/right`, `crouching_turn_90_l/r`, `run_to_stop`,
  `start_walking`, `stop_walking_with_rifle`.
- **Ambient life set exists unused:** `idle_unarmed` ×5, `sitting`, `walking_unarmed`,
  `running_unarmed`, `jumping_jacks`, `swimming`, cockpit set, `brutal_assassination`.
- **No blind-fire, no prone combat set.**

---

## 3. What to reject

1. **The respawn-faucet stage.** CoD's animation system dressed an *infinite-density* corridor —
   variety mattered because 60 men died per block. Our rejection of that structure INVERTS the
   priority, it does not lower it: in a finite 6-man ambush the player **watches every single
   death clearly**. Repetition is MORE visible in our game, with fewer clips of slack. Death
   variety is therefore a higher-leverage buy for us than it was for them, per corpse.
2. **Authored contextual death setpieces** (balcony tumbles, window deaths). Those are
   geometry-married clips for hand-built levels. Our systemic replacement is the
   **death-clip→ragdoll handoff**: authored acting for the first beats, physics for the fall, so
   slopes, dikes, paddy water, and hootch edges all resolve truthfully without authored variants.
3. **Modern layered-procedural hit reactions** (MW2019-style per-bone physics blends). Wrong era,
   wrong art direction (PSX), and it fights the just-shipped intent funnel. Our flinch should be
   one cheap skeleton-level punch, not a simulation.
4. **AnimationTree wholesale migration.** Rejected as a *prerequisite* (see §4.9 for the narrow
   future case). The CoD-2000 feel demonstrably does not require it, and ModelActor's
   AnimationPlayer+crossfade IS the era-correct architecture.
5. **Flinch-interrupts-everything.** CoD kept movement alive through pain and force-recovered in
   0.2s. Any flinch we add must never stall the bounding-advance doctrine or re-trigger the goal
   debounce — skeleton-layer flinch (below) bypasses the intent funnel entirely, which is why it
   is the safe choice.

---

## 4. Concrete proposals (prioritized)

**P1 — One-shot latch plumbing** *(S — enabler, do first)* — Pillars 1, 2
`ModelActor.play_one_shot(clip)` + a `_oneshot_until_ms` latch in `_update_sprite()` (both
`enemy_base.gd` and `ally_base.gd`): while latched, the intent funnel is suppressed; release on
`AnimationPlayer.animation_finished` (or clip length minus fade). Death/surrender latches always
override the one-shot latch (`DEAD` check already precedes the funnel — keep that ordering).
**Godot technique:** existing AnimationPlayer, existing 0.18s crossfade in; crossfade out happens
naturally when the funnel resumes and plays the next intent clip. No new nodes.
This is ~30 lines and unlocks P4, P5, P6.

**P2 — Death selection matrix v2** *(S — highest feel-per-line in the project right now)* — Pillars 1, 2
Extend `_die()`'s two-way pick to the CoD matrix, using clips that are **already in the library**:
- Quadrantize `last_hit_dir` vs `basis`: front / back / right (left → fall back to
  `death_from_the_front` until a `death_from_left` clip lands — do NOT mirror-map left onto
  `death_from_right`; falling *into* the shot reads wrong).
- Zone: `take_damage()` already receives `zone` — stash `last_hit_zone`; HEAD →
  `death_from_front_headshot` / `death_from_back_headshot`.
- Stance: if current intent was cover/crouch family → `death_crouching_headshot_front` (it reads
  fine for non-headshots at PSX fidelity; rename intent `death_crouch`).
- **No-repeat cycling:** static `_last_death_clip`; if the matrix lands on it, reroll once among
  valid alternates (CoD's `lastDeathRun` rule).
New intents in `SpriteStateMap.MODEL_CLIP` (+ sprite `CHAINS` fallbacks chaining to
`death_forward` so billboards never break): `death_back`, `death_headshot_front`,
`death_headshot_back`, `death_crouch`.

**P3 — Flinch layer, procedural (SkeletonModifier3D spine-punch)** *(S/M)* — Pillar 1
The library has zero pain clips, but we don't need one to ship the feel: a ~40-line
`FlinchModifier extends SkeletonModifier3D` in the skeleton's modifier stack (BEFORE
`SeveredBonesModifier`, which ModelActor already keeps last) applies a decaying rotational offset
to Spine2 + head, axis derived from `last_hit_dir`, amplitude = CoD's rule transplanted
(`clampf((dmg/max_hp)+0.2, 0.2, 1.0)` × ~10–14°), exponential decay over ~0.2s.
- **Truly additive over ANY base clip** — running men flinch while running (CoD's
  pain-with-movement), zero delta-authoring, zero AnimationTree, zero interaction with the 0.25s
  intent debounce (it never touches the funnel).
- **Anti-stunlock:** min interval 0.3s, amplitude cap, disabled at `DEAD`/ragdoll (the sim
  rewrites poses anyway).
- Precedent in-project: `severed_bones_modifier.gd` — this follows the exact same pattern.
- The existing ≥⅓-HP stagger keeps its SUPPRESSED-state behavior; the modifier makes the *other*
  ~80% of hits — currently an invisible fire-rate stall — visibly land.
Later (clip wishlist): 2–4 directional standing hit-reaction clips upgrade big hits to full-body
one-shots via P1. Modifier stays for small hits forever.

**P4 — Death-clip→ragdoll handoff** *(M)* — Pillars 1, 2
Play the P2-selected death clip for its first 0.3–0.5s (the authored acting: the clutch, the
spin), then `start_ragdoll(last_hit_dir, force)` — Mode A already stops the clip, so the handoff
is one timer. Physics owns the fall: slopes, dike edges, doorways, and paddy water all resolve
truthfully in an open AO where canned falls would clip (the problem CoD-2000 never had to solve
because its spaces were flat and authored).
- **Keep occasional full authored deaths** — headshots-while-standing and crouch deaths play the
  whole clip (the dramatic reads), matching CoD's rare-flourish rationing.
- `MAX_ACTIVE_RAGDOLLS = 8` already provides the graceful degrade: over budget = full clip, which
  is today's behavior. Explosion kills keep the existing straight-to-gib/ragdoll path (CoD's
  air-launch equivalent).
- Wire into `_die()` for both factions; currently `start_ragdoll` is gore-lab-only.

**P5 — Stumble & wounded crawl** *(M)* — Pillars 5, 2
- **Stumble:** non-lethal solid hit (the existing ≥⅓-HP threshold) while `speed > 3.2` →
  `falling_to_roll` one-shot via P1, resume locomotion after — CoD's shot-runner stumble, and the
  single strongest "alive under fire" read available from existing clips.
- **Crawl:** `is_crippled` currently borrows `injured_walk_backwards` (a walking clip — reads
  wrong). Wishlist clip: a proper crawl loop (Mixamo stocks several). Until it lands: crippled +
  moving → keep current; crippled + stationary → `laying_breathless` (down, breathing, alive —
  already the sprite chain's second choice, never reached for models). Wounded men dragging
  themselves after a firefight is Vietnam-atmosphere gold and feeds the morale/surrender theater.

**P6 — Grenade-dive & cover-arrival theater** *(S)* — Pillars 1, 2
Two one-shots via P1, all clips existing: GRENADE-NEARBY situation → `jump_away`; arrival at a
claimed cover point *while under fire* (`incoming_fire_timer` fresh) → `falling_to_roll` settling
into `idle_crouching` — reads as diving into cover. Rate-limit per-man (once per ~10s) so it stays
a flourish. Also wire the unused `stand_to_cover`×3 / `cover_to_stand`×2 as peek/unpeek
transitions on the cover state changes — the clips are sitting there.

**P7 — Ambient-life clip set for the quiet** *(S)* — Pillars 2, 3
Our anti-CoD structure makes the quiet a feature — so dress BOTH quiets:
- **Pre-contact:** unalerted camps/villages rotate `idle_unarmed` 1–5, `sitting`,
  `walking_unarmed` per-man (seeded variant so each man keeps his habit). This is what the player
  studies through binos before choosing the ambush — animation as recon gameplay (Pillar 3), and
  it makes the kill-them-all silence afterward land harder by contrast.
- **Post-fight:** allies drop to a weapon-low unarmed idle + occasional `turn_90` treeline scans
  during the eerie lull (pairs with the bark system's post-fight muttering — audio architect's
  lane).
Implementation: a RELAXED-tier intent extension in `intent_for()` + per-man idle variant index.

**P8 — Locomotion glue: turns and stops** *(M — polish, after P1–P6)* — Pillar 2
`turn_90_left/right` when stationary and facing delta >60°, `run_to_stop` on arrivals,
`start_walking` on patrol starts. CAUTION: turn-in-place must respect the one-yaw-owner decree —
play the clip, then snap `set_facing` at completion; never let root motion fight
`global_rotation.y`. Cheap-looking wins but each touches the facing contract; that is why it is M
and sequenced last of the feel work.

**P9 — v2 tech track: runtime-built AnimationTree layer** *(L — DEFERRED, explicit non-goal now)*
Only if authored partial-body layering becomes necessary (upper-body flinch clips over sprint,
blind-fire pose over crouch-walk): build in code a BlendTree — `AnimA`/`AnimB`
(AnimationNodeAnimation) → `Blend2` (manual 0.18s crossfade tween) → `OneShot` reaction layer —
preserving ModelActor's exact `play(clip)` API.
**Godot 4.7 technique notes (researched):**
- `AnimationNodeOneShot`: fire via `parameters/OneShot/request = ONE_SHOT_REQUEST_FIRE`,
  `fadein_time`/`fadeout_time`, completion via `parameters/OneShot/active`
  ([docs](https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html)).
- `mix_mode = MIX_MODE_ADD` exists, **but Godot does not extract additive deltas** — an absolute
  Mixamo clip in ADD mode double-transforms. The practical partial-layer recipe is
  `MIX_MODE_BLEND` + per-bone track **filters** (filter the OneShot to spine/arms/head tracks) —
  the Quake-3 torso/legs split reborn ([AnimationTree tutorial, filters](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)).
- If blend spaces ever enter: 4.7 replaced BlendSpace `sync` bool with a `sync_mode` enum
  (migration note GH-117275) — set per space.
Until a concrete need appears, P3's SkeletonModifier delivers the additive effect with none of
this machinery.

**Clip wishlist for Caleb (Mixamo pulls, in value order):** death_from_left · 2–4 directional
standing hit-reactions · crawl loop (forward, weapon dragged) · gut-clutch death · run-death
(sprint crumple) · crouched blind-fire · prone fire/idle pair.

---

## 5. Tradeoffs named (Law 2)

- **P2/P4 make deaths longer to read** — a handoff ragdoll takes ~1s more to settle than a snap
  clip. At HLL lethality that is atmosphere, not noise, but corpse/ragdoll budgets must hold
  (both budgets already exist: 8 ragdolls, 45s corpse timer).
- **P3's procedural flinch is not authored acting** — it will read as a jolt, not a performance.
  Accepted: at PSX fidelity + 0.18s crossfades, a 0.2s spine punch reads shockingly well, and it
  buys the feel a full clip-authoring cycle earlier.
- **P7 spends clips on men the player may never fight** — that is the point (Pillars 2/3), but it
  adds RELAXED-tier intent surface to test.
- **Every one-shot (P1) is a window where the funnel is deaf** — kept safe by: death/surrender
  precedence, ≤0.7s clip lengths for reactions, and Class-A interrupts (took damage → new flinch
  direction just re-punches the modifier, no funnel involvement).

## 6. Sources

- [promod/CoD-Stock-Scripts — animscripts/death.gsc](https://github.com/promod/CoD-Stock-Scripts/blob/master/animscripts/death.gsc) (death matrix, verified)
- [promod/CoD-Stock-Scripts — animscripts/pain.gsc](https://github.com/promod/CoD-Stock-Scripts/blob/master/animscripts/pain.gsc) (flinch system, verified)
- [CoD Modding Wiki — SP Using Animations](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4:_SP_-_Using_Animations) · [CoD5 SP Script Structure](https://wiki.zeroy.com/index.php/Call_of_Duty_5:_SP_Script_Structure)
- [polycount — Quake 3 Model Manual](http://wiki.polycount.com/wiki/OldSiteResourcesQuake3ModelManual) · [id Tech 3](https://wolfenstein.fandom.com/wiki/Id_Tech_3)
- [MoHAA .skd/.skc format threads](https://reshax.com/topic/17998-medal-of-honor-allied-assault-skdskc/) · [Blender SKD plugin](https://blenderartists.org/t/medal-of-honor-allied-assault-skd-plugin/482341)
- [Godot — AnimationNodeOneShot](https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html) · [Using AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)
- GodotPrompter knowledge: `animation-system` skill + 2026-07-05 Godot 4.7 deltas note (BlendSpace `sync_mode`, `LookAtModifier3D.relative` default flip)
- In-repo primary sources: anim_library.glb clip dump (91 clips), model_actor.gd, sprite_state_map.gd, enemy_base.gd, ally_base.gd, severed_bones_modifier.gd, gore_dummy.gd
