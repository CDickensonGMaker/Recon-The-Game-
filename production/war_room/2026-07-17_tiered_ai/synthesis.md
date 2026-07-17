# DECREE — ACTIVITY-TIERED AI (ps28) + SQUAD SURVIVAL (4utx)

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Sight:** two independent code-reading lenses
(enemy AI cost + witness; EnemySquad coordinator).

## FINDING 1 — ps28 (activity-tiered AI) IS ALREADY BUILT AND CORRECTLY GUARD-RAILED

The hot-set is implemented, not greenfield. Do not rebuild it (fossil law).
- **Roster:** `EnemySquad._hot` (static, instance_id-keyed), `HOT_CAP=12`, `HOT_CEILING=16`,
  `is_hot`/`request_hot`(claims a slot, capped)/`release_hot`/`_prune_hot`(drops dead/freed), plus the
  `tiering_enabled` A/B switch. (`enemy_squad.gd:37-94`)
- **Branch:** `enemy_base._think()` (`:546-551`) — in COMBAT, `is_hot(self) or request_hot(self)` →
  `_think_full_combat()` (target acq + LOS raycast + goals), else `_think_cheap_combat()` (shared-target
  dict read, no scan/raycast; disengages after 8s to free its slot).
- **Promote-on-death:** `release_hot` on die/downed/disengage; a cold fighter self-promotes the instant a
  slot frees. Pull-model, no per-frame squad tick.

**The three guard-rails are correctly placed (verified in code AND by the new probe):**
1. **Witness heartbeat (ADR-005)** — `_update_perception()` + `_check_corpse_discovery()` run at
   `_think():539-540`, BEFORE the tier branch; `_on_noise_heard` is signal-driven (tier-independent);
   `_witness_check` fires from `_die()`. A cold unit still sees the player and registers the 150m loud
   kill. **`set_lod_abstract`'s `set_physics_process(false)` is confirmed DORMANT (zero callers)** — the
   hot-set never sheds physics to save cost.
2. **Fairness exempt** — the muzzle-flash/tracer telegraph and first-shot-near-miss live in the
   tier-agnostic `_fire_at_target`/`_execute` path, not `_think_full_combat`. A cold shooter still
   telegraphs; cold units just never tighten their cone (exposure ramp needs the LOS clock the hot brain
   owns) — intended: they spray, they don't snipe.
3. **Scale uncapped** — tiering budgets cognition only; bodies all spawn/exist/animate.

**THE GAP WAS VERIFICATION.** Shipped `tests/test_activity_tiering` (commit `f205dbde`): a ratcheting
probe over the hot-set math (cap/ceiling/promote-on-death/release/AB — functional against live
EnemySquad) + the two structural guard-rails (witness-before-branch, telegraph tier-agnostic).
**Proven red** (corrupting the witness ordering fails the check), green on the real code. **ps28's build
is complete and now guarded.** The only remaining item — profiling the hot-set *size* (12 vs 16) for the
frame-time delta — is a **measurement, parked on a Blender-closed windowed bench** (today's contamination
lesson; couples with the parked jungle re-bench).

## FINDING 2 — 4utx (squad survival ~45%) IS GENUINELY NEW, AND HAS A PILLAR-4 FORK

Nothing to reuse: `EnemySquad` is a static knowledge registry with **no roster, no initial-strength, no
collective goal** (goals are per-man on `EnemyBase`). Allies are a **separate system** (`ally_base.gd`,
no `squad_id`, no EnemySquad). So 4utx is a real build, and "both sides" is two builds.

**Design (enemy side — safe, tactical realism, no pillar risk):**
- **Strength without a roster:** `EnemySquad.strength_ratio(squad_id)` = live-count ÷ peak-ever-seen
  (peak = initial, since it only falls). Compute per squad on a cached ~1s interval (scan `enemies` by
  `squad_id`, as `_local_force_ratio` already does) — never per-man-per-frame (that is the O(n²) the
  tiering exists to kill).
- **Collective SURVIVE flag:** the first per-squad goal field. Set when `strength_ratio < threshold`.
  Threshold = 0.45 baseline, modulated by squad courage/type (elite/NVA lower, green/Local Force earlier)
  — reuse `enemy_data.courage`, do not add a new stat.
- **Effect:** SURVIVE biases each member's goal toward RETREAT/break-contact/cover — **layered on the
  existing individual rout ladder in `take_damage` (`enemy_base:2136-2158`)**, not a competing morale
  authority (fossil law). Dovetails with the hot-set (a withdrawing man shifts to move/cover).
- **Probe:** strength_ratio math + threshold flip + courage modulation, headless.

**THE FORK (Pillar 4 — needs the Summoner):** "both sides" means the PLAYER'S allied squad also flips to
SURVIVE at 45% and withdraws. That is a game-FEEL decision — a squad that flees when you need it changes
"the squad is the RPG." Enemy squads withdrawing is pure atmosphere/tactics (build freely). **The player's
squad fleeing is a Pillar-4 call and the ally system is separate** — I will not autonomously make the
player's men break. **Decision needed:** do allies flee at 45% too, or hold (player-commanded), or flee
only when leaderless/routed?

## THE DECREE
1. **ps28 build: DONE + verified** (`f205dbde`). Hot-set-size perf profile parked on a clean windowed bench.
2. **4utx enemy-side: designed, ready to build** (safe, no pillar risk).
3. **4utx ally-side ("both sides"): FLAGGED as a Pillar-4 fork** — Summoner decides whether the player's
   squad flees before it's built.

## WHAT IS SACRIFICED
- Not rebuilding the hot-set (it exists) — we verify instead of duplicate, per the fossil law.
- 4utx not force-built this session: a Pillar-4 morale change across two systems at the tail of a long
  run is exactly the pillar-touching call the War Room exists to route to the Summoner, not to guess.
