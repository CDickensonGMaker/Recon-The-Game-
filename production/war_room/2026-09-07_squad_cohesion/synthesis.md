# THE DECREE — War Room 2026-09-07 · COMBAT LEGIBILITY (the squad-cohesion council, reframed)

**Arbiter:** the Overseer/Director · **Council:** game designer · systems designer · ux designer ·
programmer/technical director · technical artist · combat reference analyst · devil's advocate
(seven analyses in `analysis/`) · **Phases 1-2:** `briefing.md`, `code_inventory.md`,
`canon_conflict_note.md` · **Phases 3-4:** `weaving_phase4.md`

---

## 0 · THE SENTENCE THIS DECREE MUST OPEN WITH

**The demo playthrough gate (GAME_GUIDE §8.0) is still UNDISCHARGED.** The Summoner has still not
verified the arc end to end. Everything below is gate-exempt work — bug fixes and presentation for
shipped systems — and none of it discharges the gate.

**What this session produced: the first perf baseline ever taken on the demo, and four ally body
behaviours that existed on the enemy and did not exist on the player's own squad.**

---

## 1 · THE COUNCIL'S FINDING

The Summoner asked why combat reads at "60 percent." Seven architects answered independently and
converged: **the animation architecture is not the defect and is better than the reference games'.**
Verified in code — a 0.18 s crossfade with cycle-phase preservation, playback rate matched to authored
ground speed, 8-way octant locomotion, measured turn-in-place, a damped frame-rate-independent yaw, an
additive spine flinch that never steals the clip, five separate goal-churn dampers, and a 180 ms intent
stability filter **longer than the think interval**. Call of Duty 1 had none of it.

**Two mechanisms explain the gap.**

1. **THE PARITY GAP.** The enemy flinched, stumbled, planted his feet on arrival and wound up to throw.
   **The ally did none of those.** Every clip was already authored and already mapped; only the callers
   were missing. The player watches his own squad more than anything else in the game.
2. **THE CADENCE GAP.** `siege_director.gd:615-618` already condemns the pattern in the project's own
   words — *"a third of every squad walking while the men beside them held — which reads as indecision,
   not as fire and movement"* — and `doctrine_us.tres` still ships the squad fight that way.

And the reference finding that frames both: **Brothers in Arms and CoD1 look smooth because they moved
less.** Neither solved locomotion quality; they avoided the problem.

---

## 2 · THE SUMMONER'S RULINGS (binding)

| # | Ruling | Standing |
|---|---|---|
| 1 | **Perf baseline first, then build items 1-4 the same session** | **EXECUTED.** Number in §3 |
| 2 | **No art-days. Code only.** The 76° rifle-ready gap, the aimed-walk clip and the hip-sway rebake are **PARKED, not refused** | **HELD.** All three survive in §7 as named, sized, unbuilt items. His hands stay on the store page, capsule art and trailer |
| 3 | **Aim layer: scope it, do not build it.** Return a number, not an opinion | **EXECUTED, NOT BUILT.** §4 |
| 4 | **The six free misses: leave it.** Per-man near-miss stands | **DECIDED — no longer merely unruled.** Generous and atmospheric by ruling. Do not reopen |

---

## 3 · THE PERF BASELINE — the first one ever taken on the demo

Windowed run, `--perf-probe` on `demo_game.tscn`, render_scale 0.75, forward_plus, seed 29072026,
130 samples after a 5 s warm-up:

| | value |
|---|---|
| **FPS avg** | **27.9** |
| **FPS min** | **25.0** |
| **GPU ms avg / max** | **27.14 / 32.61** |
| **CPU ms avg / max** | **5.24 / 8.59** |
| primitives / draw calls / objects | 265,108 / 1,950 / 2,986 |

**THE GPU IS THE WALL, BY 5.2x.** This confirms the 2026-08-14 crucible and retires the July
"CPU-bound in the AI" verdict for the demo scene as well as the arena.

**Two consequences, both load-bearing:**

- **Adding animation CPU work is genuinely cheap here.** 5.24 ms of CPU against a 35.8 ms frame is
  enormous headroom. The perf objection to items 1-4 is answered with a measurement, not an argument.
- **The Devil's Advocate's warning is UPHELD by the same number.** At 27.9 FPS, frame pacing is a
  competing explanation for "not smooth," and no animation improvement can be judged cleanly until the
  GPU wall moves. **This baseline is a caveat on every visual verdict taken until it improves.**

**Scope limit, stated (ADR-015):** this is the quiet demo world. It is **not** the 45-man siege, and
`--perf-siege` was not run. THE WALK · ONE DIG · THE BARRAGE remain untaken.

---

## 4 · RULING 3 — THE AIM LAYER, SCOPED (NOT BUILT)

**Answer: NO, a bounded spine-only aim layer does NOT require the AnimationTree rewrite. It touches
ZERO of the ~30 `play()` call sites and ZERO of the 8 files in the fossil-law list.**

The precedent is already shipping. `FlinchModifier` (`scripts/visuals/flinch_modifier.gd`) is a
**52-line** `SkeletonModifier3D` that writes a spine bone pose *on top of* whatever the AnimationPlayer
is playing. Its entire integration is **2 lines** in `model_actor.gd` (`:69`, `:81`). It coexists with
direct `play()` calls today and has never needed a tree.

**Measured blast radius of an aim-yaw modifier built the same way:**

| | count |
|---|---|
| New files | **1** (~60-70 lines; flinch is 52, aim adds a clamp + smoothing) |
| Existing files touched | **1** (`model_actor.gd`) |
| Lines added to existing code | **~3** |
| `play()` call sites touched | **0** |
| Of the ~30 sites / 8 files in the fossil-law list | **0** |

**The programmer's leak test is satisfied and I ran it explicitly:** *does the change add a node that
owns the skeleton?* **No.** A `SkeletonModifier3D` post-processes the pose; it does not own it. Flinch
proves the coexistence.

**THE ONE REAL RISK, NAMED — and it is why this is scoped and not built.** Flinch is **transient**
(0.28 s decay), so pose conflicts are invisible. An aim layer is **persistent**. An always-on spine yaw
fights every clip that already rotates the spine — the cover lean, turn-in-place, prone. Resolving that
needs a per-clip suppression set or a blend-out, **and that is exactly where an innocent 60-line file
grows into something else.** Honest estimate: 1 day for the modifier, and an **unknown** for the
conflict set, which must be measured before it is promised.

**The programmer's leak warning is UPHELD as standing law:** if an AnimationTree ever lands it lands as
its own decreed change, never dressed as a blend-time tweak.

---

## 5 · WHAT WAS BUILT — four ally body behaviours, zero art-days

All four are **presentation for shipped systems**: every clip already existed, was already authored, and
was already mapped. Only the ally callers were missing.

| # | Built | Mechanism |
|---|---|---|
| 1 | **Ally flinch + stumble** | `take_damage` now calls the spine flinch and latches a 500 ms `stumble_hit` on a solid non-lethal hit. Enemy thresholds, enemy clips, enemy low-posture guard carried over verbatim; prone guard added |
| 2 | **Ally arrival plant** | `run`/`sprint` settling to `aim`/`idle`/`cover` rewrites the intent to `arrive` for 450 ms. Lifted from `enemy_base.gd:681-690`. Display-only — the latch state stays honest |
| 3 | **THE PIN HUNKER** | A pinned man now holds `cover_kneel_brace` instead of a kneeling *aim*. **This also discharges the truth-law violation:** the old line cleared the override under a comment claiming a hunker that did not exist. It is now an assignment, and the comment is true |
| 3b | **Its leak guard** | `_change_state` drops the hunker when leaving SUPPRESSED. Without it the brace survives SUPPRESSED→COMBAT (both are "still fighting", so `_release_cover` never runs) and the man fights on from a frozen crouch |
| 4 | **Cover-arrival ungated** | The dive/stand-to-cover set was gated on a layer-1 wall ray that vegetation, terrain and low log cover all fail, so it was skipped on the most common cover in a jungle map. Now `wall OR terrain_cover >= 0.3`. Deliberately **not** `cover01()`, which folds in `has_cover` (set true two lines above) and would fire on bare ground |

### VERIFICATION (ADR-015)

- **Headless boot: CLEAN.** `--headless --quit-after 300`, zero SCRIPT ERROR, zero parse errors.
- **`test_ally_states`: PASS**, 0 failures (11 checks, including the pin path).
- **`test_low_posture`: PASS**, 0 failures (11 checks, both factions).
- **`test_squad_break`: PASS**, both sides, one break authority intact.
- **`test_squad_invariants`: PASS.**
- **`test_squad_coordinator`: PASS** (after the revert in §6).

**What the probes do NOT prove: that it looks better.** Three architects conceded this independently and
it is the council's own closing rule. **A probe proves no regression; his eyes prove the feel.**

---

## 6 · THE TOKEN DIAL — BUILT, PROBE-REFUSED, REVERTED. HIS CALL.

The cadence half (`exposure_tokens` 3→2, `grant_stagger_ms` 600→900) was applied and **failed
`test_squad_coordinator`**:

```
FAIL: (g) US tokens 2 != 3
```

**The probe did exactly its job.** That block is headed *"doctrine data of record"* and exists to catch
an unruled change to these numbers. The dial was the Arbiter-coordinator's proposal, explicitly awaiting
the Summoner's eye — so it *is* an unruled change, and the guard caught it correctly.

**RULING: REVERTED to the shipped values. The guard test was NOT edited to permit it.** Editing a probe
so a tuning change can pass is pinning the bug in reverse, and this project has been burned before by
tests that pinned a defect.

**It remains a two-value edit in one data file, and the case for it is the strongest single item in the
council** — two architects reached it independently, and the siege code already condemns the pattern in
writing. **The siege is insulated:** `assault_press` is a separate doctrine file (999 tokens, 0 stagger)
and the same test guards it with *"the siege must never be strangled."*

**If he approves it, the change is:** `data/ai/doctrine_us.tres` → `exposure_tokens = 2`,
`grant_stagger_ms = 900`, **and** `tests/test_squad_coordinator.gd:55` updated **in the same commit** to
assert the new value of record. Never one without the other.

---

## 7 · PARKED BY RULING 2 — named, sized, unbuilt (he will want these when art-days exist)

| Item | Why it reads as unsmooth | Size |
|---|---|---|
| **Rifle-ready start poses 76° apart** — `firing_rifle` is 76° off `idle_aiming`, `reloading` 69°, `idle_aiming` 37.6° off `idle` (already measured, `ANIM_WISHLIST.md` B1). Crossfaded in 0.18 s, twice per shot, on **the most-played transition in the game** | a 76° upper-body whip every time a man fires | **1-2 art-days** |
| **`aim_walk` does not exist** and falls back to `walk_forward` | a man advancing under fire plays the patrol stroll | **1 art-day** |
| **Hip lateral sway stripped by the exporter** across 31 locomotion clips (`ANIM_WISHLIST.md` C2) | gaits read on rails | **1-2 days + full rebake** |
| **Emotional-register axis + SPLICE/PHASE/RETIME variant generation.** `tools/make_ambient_variants.py` is written and **has never been run** | the world reads samey | **the month.** Right answer to samey, wrong answer to unsmooth. Must not start before the rows above |

**The technical artist's clip claims stand on the record as CORRECT AND UNBUILT.** Ruling 2 parked them;
it did not refute them.

---

## 8 · REMAINING CODE ITEMS — ranked, gate-exempt, unbuilt this pass

1. **Enemies have zero cover craft.** Every cover clip and the arrival picker live ally-side only;
   `enemy_base` sets `has_cover = true` with no clip. The VC sprint to a rock and become crouching
   statues. **The fix is already written on the other side.** Largest remaining asymmetry.
2. **Ally grenade-throw windup** — the third enemy-only one-shot, not carried over this pass.
3. **Twenty recorded voice lines never play** — 12 of 25 squad, 7 of 15 radio, including the whole
   directional vocabulary and both reloading lines. **The contact moment fires a text toast with no
   voice under it.** No bark at token grant or element swap.
4. **No animation LOD anywhere** — no `callback_mode`, no `active` toggling, no distance gate; all 45 men
   at the climax animate at full rate. **Ships only with its bench** (programmer's condition).
5. **Per-transition blend times** — 0.18 s is one global constant. ~15 lines.
6. **Six deceleration paths** in `ally_base`, two of which hard-set velocity from 4.2 m/s to zero in one
   frame. Arguably a bug fix.
7. **Speed-match table holes** — a clip missing from `_CLIP_SPEED` silently resets `speed_scale` to 1.0.
   Missing: all sprint diagonals, all crouch diagonals, `run_to_stop`, **and every `__smg` variant**, so
   every SMG carrier skates.
8. **NPCs never reload** — clips authored, one test-scene caller, no ammo model on either side.
9. **The nav restake threshold** (3 m) — the one surviving stutter suspect, unmeasured.
10. **The three probes the council proposed:** the stillness census, `probe_anim_churn`, the resolver log.

**PARKED — needs an art asset, so ruling 2 binds:** the **flesh impact sample**. Shooting a man plays
`IMPACT_DIRT` under the comment *"placeholder wet tick until a flesh sample exists"*. **No flesh audio
exists anywhere on disk**, so this is an asset, not a wire-up. It is the cheapest *perceptual* win on the
board, and it is his own "I shoot them and they don't die" complaint reappearing in audio.

---

## 9 · STANDING RULINGS CARRIED

- **Rotation / DEROS: OUT OF DEMO SCOPE** by his speech. The individual-rotation-policy finding — the
  best historical surprise in the council, and the documented cause of real Vietnam cohesion failure —
  is **recorded and parked**, not planned. Pillar 4's own text still promises men who "rotate home," and
  no rotation clock exists in code.
- **Pillar 4's provisional anti-puppeteer clause: FORMALLY OPEN, PARKED.** Nobody is proposing a command
  layer; it has no urgency and was not forced. It remains his ruling to make from play.
- **No cohesion resource, no meter, no number, no fifth order key.** The readout is the soldiers
  themselves — his answer, and the one no architect offered.
- **The six free misses: DECIDED.** Per-man near-miss stands.
- **Drift corrected this session stays corrected** (§10).

---

## 10 · DRIFT CORRECTED (NO MORE DRIFT)

1. **`GAME_GUIDE.md` §8.1 item 3** claimed *"`EnemyBase` has no dresser call at all — every VC/NVA man is
   a clone in the 45-man climax."* **False.** `enemy_base.gd:470` invokes `_dress_visual`, which calls
   `VcNvaDresser.dress` (`:511-516`), seeded off the shared memberless-man walk so an operation seed
   rebuilds the same force (ADR-010). True on 2026-08-06, false now. **Corrected in place.** The open
   half — whether the variety *reads* — is a playtest question, never a code read.
2. **`production/research/squad_mechanics.md`** carried a "verified baseline" stale on four counts (order
   enum, squad size, the dual-bind law, formations claimed unbuilt when they ship). Notice added.
3. **A truth-law violation in shipping code: DISCHARGED BY BUILD**, not by comment edit. `ally_base.gd`
   cleared the animation override under the comment *"the pin hunker outranks any latched cover pose"*
   when no hunker existed. The hunker is now built and the comment is true.
4. **`ANIM_VARIETY_PLAN.md` is REFUTED** on its central claim that cower is *"the one genuine gap with
   neither art nor code."* The art existed; only the caller was missing, and it now exists.

---

## 11 · WHAT THIS DECREE DOES NOT CLAIM

It does not claim the combat looks better. **No probe run in this session can establish that**, and three
architects said so independently before the work started. It reports what changed and what the probes
say. **The Summoner decides whether it looks right** — and the 27.9 FPS baseline is a standing caveat on
that judgment until the GPU wall moves.
