# DEVIL'S ADVOCATE — the prone posture (2026-07-31)

Ruling under challenge: add a third value to `CombatPosture.Posture`, driving
`prone_idle` / `prone_firing_rifle` / `crouch_to_prone` / `prone_to_crouch`.

Every claim below carries a `file:line`. Where I could not find a pointer, I say so — per the
POINTER LAW that absence is itself the finding.

---

## 0 · WHAT I AM *NOT* OBJECTING TO

- **The clips are real and on disk.** `assets/shared/mixamo_clips/` contains `prone_idle.fbx`,
  `prone_firing_rifle.fbx`, `crouch_to_prone.fbx`, `prone_to_crouch.fbx` (Mixamo ids at
  `production/ANIM_WISHLIST.md:33-36`). No fabrication there.
- **The loop-mode trap is already closed.** `prone_idle` and `prone_firing_rifle` are both in
  `_LOOP_NAMES` (`scripts/visuals/model_actor.gd:341`), and the two transitions are excluded from
  looping by the `_to_` guard (`model_actor.gd:367`). That specific freeze is pre-solved.
- **There is no half-built AI prone to trip over.** Repo-wide grep for `prone|crawl|belly`: the only
  live prone code is the **player's** (`scripts/player/player.gd:44,64-65,1553-1554,1694-1695`,
  read by `scripts/player/weapon_holder.gd:457,576`, bound in `project.godot:216`) and one
  unrelated cover-height comment (`scripts/levels/gore_lab.gd:285`) plus felled-log geometry
  (`scripts/world/fellable_tree.gd:116,136`). **No AI prone fossil exists.** Good news, and it means
  the FOSSIL-LAW deletion bill for this feature is small (see §5).

So this is not a "the art isn't there" objection. My objections are that **the posture axis is the
wrong half of the problem**, and that **three load-bearing systems are hardcoded to a standing man.**

---

## 1 · IS THIS COMPOUNDING RISK ON UNVERIFIED CLIPS?

**Partly yes — but this is my weakest objection, and I will not lean on it.**

Evidence FOR the risk:
- `production/SESSION_HANDOFF_2026-07-30_MIXAMO.md:5` — *"NOTHING HERE IS PLAYTESTED. 39 clips and
  ~16 wiring changes, none judged by eye."*
- The same file, `:207-209`, states the standing instruction: **"Do not add more clips before his
  verification pass."** Building an engine system on top is not "adding clips", but it *does*
  consume the same verification budget and makes the eventual pass harder to attribute.
- His gate list (`:44-51`) does **not include prone**. The four highest-value looks are sapper
  planting, a camp at rest, a village at work, and taking a hit. **Prone is not on his own gate.**

Evidence AGAINST the risk (honest reporting):
- `probe_mixamo_fit.py` measured 41/41 bone names shared, scale 1.0 both sides, 0 unmatched
  (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:32-36`). Retarget is genuinely not a step.
- The library exporter strips only Hips X/Z and **keeps Hips Y**
  (`tools/export_anim_library.py:11,62`) — which is what a going-to-ground clip needs.

**Verdict on 1:** the clips will almost certainly *play*. Whether `crouch_to_prone` **reads** on a
PSXRig grunt — a Mixamo clip authored on a full-height humanoid with no rifle — **has been confirmed
by nobody, and there is no probe that could confirm it.** `tools/probe_anim_audit.gd:44-59` only
reports whether a clip resolves, never whether it looks right. Two of the three scan clips already
have this exact defect recorded: *"the scan clips are unarmed. On a man holding a rifle the weapon
follows his hand but hangs at an odd angle"* (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:76-78`).
**`prone_idle` (Mixamo 113000901) and `prone_firing_rifle` (112990901) are from the same unarmed /
generic-rifle pull.** A prone man with a rifle floating at his hip is the likeliest single outcome
of building this today, and it will not fail any test.

**Cost of the objection:** one 60-second look in the Godot editor discharges it. Do that first.

---

## 2 · THE SILENT FAILURES — where a prone man LOOKS alive and is broken

This is the strongest section. The project's recorded bug class is
"looks alive because something teleports or plays once"
(memory: *silent freeze bugs*). Prone has **four** of them, and three are hardcoded constants.

### 2.1 · HE SHOOTS FROM 1.35 m ABOVE THE GROUND — from thin air over his own back

```
scripts/visuals/model_actor.gd:985-986
func muzzle_ballistic(flat_aim: Vector3, forward_bias: float = 0.55) -> Vector3:
	return global_position + Vector3.UP * 1.35 + flat_aim * forward_bias
```
Both factions route their **ray origin** through it:
`scripts/enemies/enemy_base.gd:2164`, `scripts/allies/ally_base.gd:1288`, and the enemy override at
`enemy_base.gd:2166` re-adds the same `UP * 1.35`.

A man playing `prone_firing_rifle` behind a felled log (`fellable_tree.gd:136` — *"prone height
~0.5m"*) has his **visual muzzle at ~0.3 m and his bullet origin at 1.35 m.** He shoots straight
over the log he is hiding behind. The muzzle flash (`muzzle_visual`, `model_actor.gd:990`) is at the
same wrong height, so the flash and the bullet agree with each other and **disagree with the body.**
Nothing fails. It reads as "AI shoots through cover" — and it is the exact opposite of Pillar 1.

### 2.2 · NOBODY CAN SEE A PRONE MAN CORRECTLY — the LOS point is a metre of empty air

Every perception/LOS ray in both AI files is hardcoded eye 1.5 / target 1.0:
`enemy_base.gd:861-862, 892, 995-1003, 1182-1183, 1438-1439, 2741, 2747`;
`ally_base.gd:635-636, 842-843, 1095, 1220`.

Two consequences, both silent:
- **A prone man is targeted at a point ~1.0 m above his origin — above his own back.** Behind a 0.5 m
  log, that phantom torso is *visible* while the real body is not. Going prone therefore gives an AI
  **zero** survivability and can make him *easier* to acquire than the log implies.
- **His own eye stays at 1.5 m.** A prone man sees over the wall he is lying behind.

There is **no posture term anywhere in AI perception.** The only posture-aware sight code in the
repo keys on the **player's** flag: `enemy_base.gd:978` and `:1008` read
`if "is_prone" in player and player.is_prone`. **No pointer found for any AI-side equivalent — that
is the finding.** Prone as specified is a *pure animation*, with no perception, no cover, and no
ballistics consequence. It costs the AI speed and buys it nothing.

### 2.3 · THE STUCK WATCHDOG GOES BLIND BELOW 1.0 m/s — a prone man wedged on geometry never frees

```
scripts/enemies/enemy_base.gd:200-207   (byte-identical: scripts/allies/ally_base.gd:66-72)
	_stuck_t += delta
	if _stuck_t >= 1.0:
		var wants_move: bool = Vector2(velocity.x, velocity.z).length() > 1.0
		if wants_move and global_position.distance_to(_stuck_pos) < 0.3:
			_unstick_t = 0.6
```
`CROUCH_SPEED_CAP` is **1.9** (`enemy_base.gd:176`, `ally_base.gd:237`) — safely above the 1.0
threshold, which is *why crouch has never exposed this*. Any prone cap must be lower than the crouch
cap to mean anything; the only crawl reference the engine owns is `wounded_crawl: 0.8`
(`model_actor.gd:951`) and the player's `PRONE_SPEED: 1.0` (`player.gd:65`). **Both are at or below
the watchdog threshold.** A prone man commanded into a rock has `wants_move == false`, never
sidesteps, and lies there crawling in place forever — **animating perfectly.** That is the bug class
verbatim.

(Related pre-existing hole this feature would widen: `_suppression_move_mult()` returns **0.05** at
suppression ≥ 0.85 (`enemy_base.gd:1573`), so heavily-pinned men are *already* under the watchdog
threshold. Prone would put men in that band far more often and for longer.)

### 2.4 · THE TRANSITIONS ARE ONE-SHOT WINDOWS, AND THE EXISTING WINDOW PATTERN DROPS THE SPEED SCALE

The house pattern for a one-shot is a self-clearing ms window that **`return`s early from
`_update_sprite`**: `cover_to_stand` (`enemy_base.gd:426-430`), `stumble_hit` (`:431-434`),
`grenade_throw` (`:435-439`). Note what the early `return` skips: the tail of the function at
`enemy_base.gd:483-485`, i.e. **`sprite_actor.play(...)` AND `set_locomotion_speed(speed)`.**
`crouch_to_prone`/`prone_to_crouch` are ~1–2 s clips — an order of magnitude longer than the 500 ms
stumble window — during which the man's `_low_posture` speed cap is still applied by
`enemy_base.gd:626-631` but his playback rate is frozen at whatever the previous clip left. He
**glides while going down.**

Worse, the transitions are *not* protected by the death latch the way the state clips are:
`_update_sprite` returns early on DEAD/surrendered/downed at `enemy_base.gd:424-425`, but a man who
is **killed mid-`crouch_to_prone`** goes to `_die()` with the visual halfway to the floor. The
non-ragdoll path is guarded (`model_actor.gd:776-791`, `settle_flat_corpse` + the
`PRONE_SPAN_MAX = 1.2` check at `:678,791`) — but that guard **cannot distinguish a corpse from a
living prone man**: a prone body's Y-span is *already* under 1.2 m, so the "PROVE the man is down"
assertion at `model_actor.gd:787-791` silently becomes a no-op for the entire prone population.
The safety net stops netting exactly where the new posture lives.

### 2.5 · The body gate: mostly safe, and I will say so

`_body_gate_open()` (`enemy_base.gd:647-662`) returns true for `alert_tier > RELAXED` and for
`velocity.length_squared() > 0.01`, so a *fighting* prone man is always body-hot. The gated case is a
RELAXED, stationary prone man on a 300 ms heartbeat (`:657-661`) — pose staleness only.
**Not an objection.** I checked because the 7/18 council flagged this class
(`production/war_room/2026-07-18_ai_consolidation_plan/analysis/systems_designer.md:120`); prone does
not reopen it, *except* that `_cover_exit_until_ms` is explicitly pinned hot at `:650-651` and any
new prone-transition window would need the same pin or a gated man will freeze mid-transition. **That
line is the pattern to copy, and it is easy to miss.**

---

## 3 · DEAD ENDS — every route into prone with no route out

A prone man who cannot get up is a dead squad. Enumerated against `CombatPosture.decide`
(`scripts/ai/combat_posture.gd:15-26`) and the callers.

1. **The suppression trapdoor.** `decide` short-circuits on suppression *first*
   (`combat_posture.gd:16-17`). If prone keys on a suppression band, a man under sustained fire is
   prone; `_suppression_move_mult()` drops him to 0.05× (`enemy_base.gd:1573`); at that speed he
   cannot leave the beaten zone, so suppression never decays through displacement, so he stays
   prone. `_update_decay` does run ungated (`enemy_base.gd:607`, and the body-gate contract comment
   at `:602-604` confirms decay never gates), so this is a *slow* trap, not a permanent one — but
   the loop is real and it is invisible.
2. **RETREATING is a STAND state** (`combat_posture.gd:19-20`). Good — but the rout path sets
   `goal_timer = -3.0` for committed flight (`enemy_base.gd:2310`), i.e. **no re-plan for ~4 s.** A
   man who routs *from prone* must play `prone_to_crouch` before he can run, and nothing in the
   rout path waits for a transition. Expect a man to teleport upright and sprint. Bug class, again.
3. **The 180 ms stability filter is shorter than the transition** (`enemy_base.gd:460-469`). An
   intent must win for 180 ms to commit. A 1.5 s `crouch_to_prone` therefore commits, and can then be
   *re-decided against* four times before it finishes. Without an explicit "transition in flight"
   latch, a man on a suppression boundary will oscillate down/up/down. `_low_posture` never needed
   one because crouch is a single loop with no entry animation. **Prone is the first posture in this
   codebase with a transition cost, and the funnel has no concept of one.**
4. **`is_crippled` / `is_downed` collision.** `_intent_core` short-circuits on `is_crippled` before
   any posture logic (`sprite_state_map.gd:47-50`) and `_to_crouch` passes it through untouched
   (`:121-122`) — so crippled currently wins, correctly. **But `crippled` maps to `wounded_crawl`
   (`sprite_state_map.gd:135`), which IS a prone clip.** A crippled man and a prone man are now two
   systems producing the same silhouette with different speed rules
   (`_become_crippled` does `move_speed *= 0.25`, `enemy_base.gd:2347`). Whoever builds prone must
   decide which owns the ground, or the project acquires its 15th parallel live system.
5. **`is_downed`** short-circuits `_update_sprite` entirely (`enemy_base.gd:424-425`) and freezes AI
   (`enemy_base.gd:584-591`). A man downed *while prone* keeps the last clip. Probably fine, unverified.
6. **The medic drag.** `carry_wounded` / `being_carried` set `work_clip` on both parties
   (`ANIM_WISHLIST.md`, `enemy_base.gd:440-444`), and `work_clip` outranks the state map. A prone
   man being dragged plays the drag clip — fine — **but nothing clears a prone latch on the dragged
   man if prone is stored as state rather than derived per-frame.** `_low_posture` is safe here
   *because it is recomputed every frame* (`enemy_base.gd:457`). **Prone must be derived the same
   way and must never be a latched bool.** If the implementer adds `var _is_prone: bool` he has
   built the freeze.
7. **Ragdoll.** `start_ragdoll` (`model_actor.gd:687-745`) shoves the spine with
   `impulse_dir * force + Vector3.UP * 1.5` (`:734`) — tuned for a standing man. On a prone body
   that is a 1.5 m vertical launch from ground level. Expect corpses to hop. Untested; no pointer to
   any posture-aware impulse.

---

## 4 · WHAT GOES RED

Named files, with the assertions that break.

- **`tests/test_low_posture.gd` — GUARANTEED RED if prone keys on suppression.**
  `:58` asserts `decide(ADVANCING, 0.7, false) == CROUCH`. `:130` asserts the enemy caller
  `_is_low_posture(false) == true` at `suppression_level = 0.7`. `:162` asserts the same for allies.
  `CROUCH_SUPPRESS` is **0.6** and `SUPPRESS_PIN` is **0.7** (`combat_posture.gd:11-12`) — a heavy
  pin is *exactly* where a designer will want prone. **Any prone threshold at or below 0.7 turns
  three assertions in the project's own posture guard red.** These are not incidental: they are the
  contract the 7/23 faction merge exists to protect.
  Also `:52-59` (Part 0) treats `decide`'s return as a two-valued space throughout.
- **`tests/test_ally_states.gd:73,78,79,95`** — asserts `_is_low_posture()` false on the push and
  true on the pin, and that the closing speed exceeds `CROUCH_SPEED_CAP`. A prone cap below the
  crouch cap changes the second half of that contract.
- **`tests/test_fossils.tscn` — YES, IT CARES.** It scans `const`, `signal`, `func`
  (`tests/test_fossils.gd:240-245`) over `res://scripts` (`:8`). Every new
  `PRONE_SUPPRESS` / `PRONE_SPEED_CAP` / `PRONE_*` const that lands **before** its caller is a NEW
  fossil and **fails the build**. Enum *values* are not scanned, so `Posture.PRONE` itself is
  invisible to the probe — which is worse, not better: a prone enum value nothing ever returns is a
  fossil the machine cannot see.
  **DRIFT, correct on contact:** `CLAUDE.md:308` states the baseline is *"`ceiling` 19, `count` 19,
  as of 2026-07-24"*. `tests/fossil_baseline.json:3-4` actually reads **`ceiling: 3, count: 3`**.
  CLAUDE.md is injected into every session; this is precisely the drift-generator pattern the file
  itself documents at `:193-195`.
- **`tests/test_anim_library.gd`** — safe. It floors at 80 clips (`:30`) and the library is at 163.
- **`tools/probe_anim_audit.gd`** — will begin reporting the prone clips as *demanded*
  (`:48-56`) once they enter `MODEL_CLIP`. It reports, it does not fail. It **cannot** tell you the
  rifle is floating.
- **`tests/test_squad_invariants.gd:40-48`** — reads `PLAYER.CROUCH_SPEED` against the ally formation
  hysteresis band. Untouched by AI prone, but note the band exists: if anyone mirrors prone onto the
  **player's** existing `PRONE_SPEED = 1.0` (`player.gd:65`) and changes it, this test adjudicates it.

---

## 5 · FOSSIL LAW — what dies the same day

Prone **replaces nothing in code**. There is no half-built AI prone (§0). So the deletion bill is
prose, and under the DRIFT law (`CLAUDE.md:234-252`) it is due **in the same change**:

1. **`production/bible/04_AI_LOCOMOTION.md:83-84`** — *"True prone/crawl is DEFERRED (new art)…
   honor that later, do not fake it now."* Retired law that reads as binding. Must be rewritten, not
   left.
   **Its pointer is already dead:** it cites `enemy_base.gd:1564` for the "pins men to a crawl"
   claim; that text now lives at **`enemy_base.gd:1796-1797`**. Line 1564 is a strafe-vector
   calculation. Fix while you are in the file.
2. **`scripts/ai/combat_posture.gd:2-6`** — the class docstring asserts a two-valued contract
   (*"Crouch to hold, stand to push"*). It is the single most-read description of this system.
3. **`production/ANIM_WISHLIST.md:64`** and **`SESSION_HANDOFF_2026-07-30_MIXAMO.md:123-127`** — both
   say prone "needs a prone posture the state map can select". Both become false on ship.
4. **`README.md:56`** and **`CHANGELOG.md:17`** — describe "shared combat posture" as crouch/stand.
5. If prone subsumes the heavy-pin crouch, then **`CROUCH_SUPPRESS` (`combat_posture.gd:11`) either
   changes meaning or becomes dead** — and it has live readers at `ally_base.gd:769,1053` and
   `enemy_base.gd` (via `decide`). Do not leave two suppression posture thresholds standing. The
   project has already paid for exactly this once: `LOW_POSTURE_SUPPRESS` survived on `ally_base` for
   two days after its enemy twin was deleted
   (`production/GHOST_CODE_AUDIT_2026-07-25.md:146`).

---

## 6 · IS PRONE THE HIGHEST-VALUE ANIMATION WORK RIGHT NOW? **NO.**

Compared honestly against the handoff's own ranked list
(`SESSION_HANDOFF_2026-07-30_MIXAMO.md:62-158`):

| Candidate | Consumers today | What it buys | Verdict |
|---|---|---|---|
| **§2 The aid station ledger** | `campaign_state.ward_wounded` has **ZERO consumers outside `campaign_state.gd`** (measured, `:110-112`) | Turns a number that already tracks real casualties into a building full of men. Directly serves the *casualty-ledger-is-the-scoreboard* decree and the *interior-first* decree. Art is **already in the library** (`laying_idle`, `sleeping_laying`, `medic_treat_receive`, `medic_treat_give`) with one small gap (an officer at a desk, `:118-119`) | **BEATS PRONE** |
| **§4 register axis / PHASE variants** | none | `PHASE` is *"the cheapest variety win in the whole plan… no new motion at all"* (`ANIM_VARIETY_PLAN.md:48-50`). Five men on one walk currently march in lockstep — that is why the world reads samey (`ANIM_VARIETY_PLAN.md:21-24`) | PHASE beats prone; the register axis is comparable scope to prone and equally a War Room item |
| **§5 weapon families** | `__mg`/`__bolt`/`__launcher` all empty; `model_actor.gd:872-878` already warns | The RPD gunner and the RPG man hold their weapons like rifles **today, in every fight** | Deferred by the Summoner himself (`:142`) — respect that |
| **§3 prone** | none | A posture the player cannot order (Pillar 4), that no perception system reads (§2.2), that fires from the wrong height (§2.1) | **LAST of the four** |

**The asymmetry that decides it:** the aid station is *a working system with no eyes on it*. Prone is
*a new system with no gameplay behind it*. `ward_wounded` is already counting real casualties every
patrol and showing the player nothing. That is a strictly better ratio of reward to new surface area,
and it needs **no** change to `sprite_state_map.gd`, `combat_posture.gd`, `enemy_base.gd`,
`ally_base.gd`, or any test in the suite.

And the Summoner's own gate list (`:44-51`) names four looks. **Prone is not one of them.**

---

## 7 · WHAT IS SACRIFICED IF THE COUNCIL BUILDS PRONE ANYWAY

No decision is free. Building prone now costs:

- **The two-valued posture contract**, which is the *only* thing keeping `enemy_base` and `ally_base`
  honest with each other after the 7/23 merge (`combat_posture.gd:2-3`). It survived a two-day
  divergence once already (`ARCHITECTURE_COUPLING_READ_2026-07-26.md:314`). A third value doubles
  the surface where they can drift apart, and Part B of the merge is **still deferred**
  (`AI_LIVING_WORLD_ROADMAP.md:64-65`).
- **Three hardcoded height constants** (`1.35` ballistic, `1.5` eye, `1.0` target) that currently
  work because *every AI in this game is standing or kneeling*. Prone is the first thing that makes
  them wrong, and fixing them properly means touching **17 call sites across both AI files** — which
  is a bigger, riskier change than the posture itself.
- **The verification budget.** He said *"i shouldn't go super crazy"*
  (`SESSION_HANDOFF_2026-07-30_MIXAMO.md:43`). A prone build adds a fifth thing to judge before the
  first four have been judged once.

---

## 8 · IF IT IS BUILT — the minimum conditions

Not a recommendation to build. If the Arbiter overrules me, these are non-negotiable or the feature
ships as theatre:

1. **Look at `prone_idle` and `prone_firing_rifle` on `us_grunt_v3` in the editor first**, with a
   rifle. Sixty seconds. Same defect class as the scan clips is the likeliest outcome.
2. **Posture-aware muzzle and LOS, or prone does not ship.** `muzzle_ballistic` takes a height
   argument; the 1.0 target point becomes posture-derived. Without this, prone is a lie.
3. **Derive prone per frame** (mirror `enemy_base.gd:457`). **Never a latched bool.**
4. **Lower the unstick threshold** at `enemy_base.gd:202` / `ally_base.gd:67` below the prone speed
   cap, in **both** files, in the same commit, or accept permanently wedged men.
5. **A transition latch** longer than the 180 ms stability filter, pinned body-hot the way
   `_cover_exit_until_ms` is (`enemy_base.gd:650-651`).
6. **Extend `tests/test_low_posture.gd` in the same change** — Part 0, Part A, Part C, and a Part B
   entry proving the four prone clips play on a real rig (`:100-107` is the template).
7. **Delete §5's five prose fossils the same day.**

---

## VERDICT

Prone is **buildable and not fake**, but as ruled it is **an animation with no system behind it**,
and the three highest-value objections are all things no test will catch. **I do not concede it
should be built now.** The aid-station populator is a better use of the same day, and prone should
follow the perception/ballistics height work rather than precede it.
