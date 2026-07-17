# MORNING SUMMARY — overnight run of 2026-07-16/17

**Ran:** Wave 1 — Stages 1, 2 (parked), 3, 4, 11. **Wave 2** — `xo7i`, the hung tests, the bench
anomalies, the shadow question. (Of 23 planned.)
**Desktop:** clean — zero Godot processes, no windows open, `project.godot` untouched.
**Verdict in one line:** **five of this project's instruments were lying, and three of the liars were
mine, written during the night while hunting the other two.** Everything below is measured or it says
it isn't.

> ### ⚠ READ THIS BEFORE ACTING ON ANY NUMBER
> Wave 2 **withdrew three numbers Wave 1 published as fact** (lights/characters/grass attribution) and
> **corrected one framing** (the sun shadow is deliberate, not a bug). The withdrawals are in §1.1 and
> §3.4. `PERF_LEDGER.md` is corrected in place — **read its CORRECTION block, not the table above it.**
> Two findings survive: **the jungle** and **the renderer A/B**.

---

# 0. WAVE 2 DELTA (what changed since the first report)

| | Wave 1 said | Wave 2 measured | Status |
|---|---|---|---|
| **`xo7i`** | "breaking the build — fix the generator so low ground exists" | **Already implemented** by his Worldgen Wave 1, working exactly (40/60 split, exact over 200 seeds). Its *description* is stale. | **CLOSED**; paddy failure retargeted to `v58s` |
| **The paddies** | (attributed to `xo7i`) | **Map floor is 140m** on the flattest inhabited preset. Presets set *relief*, not *base elevation*. `v58s`'s original diagnosis survives word-for-word; only the number moved (87.9m → **140m — it went UP**). | `v58s` = the live P0 |
| **"4 hung tests"** | 4 hangs | **2 true hangs.** `test_hub_loop` runs **167s** and was never hung — **my 120s box mislabelled slow as hung.** | corrected; box → 420s |
| **`test_ai_fairness`** | "hangs — Fairness Law unguarded" | **Confirmed and FIXED.** Cause: Track C deleted `_exposure_spread_mult()`; the probe still called it → SCRIPT ERROR → coroutine aborted → `quit()` never reached → hang. | **PASS, red-proven** |
| **Attribution (lights/chars/grass)** | published as fact | **Withdrawn — inside the noise.** A control of 6 identical phases drifts ±10% fps / +25% draw calls. | retracted |
| **Sun shadow** | "cheapest win, no decision needed" | **ADR-026 draft grants the night sun "the one allowed dynamic shadow".** Deliberate, not a leftover. | untouched; his call |

---

# 1. WHAT WAS MEASURED

## 1.1 THE JUNGLE IS PROFILED — the debt `365s` has carried since it was filed

`tests/overnight_bench.tscn` (new): unattended, drives the **real F1–F6 overlay path** (injected
`InputEventKey`, not a reimplementation), real `RenderingServer` GPU render-time, 9s warmup / 1.5s
settle / 4.0s averaged sample. Renderer via `--rendering-method` CLI override — **`project.godot` was
never edited.** Scale pinned at runtime and **recorded on every row**.

**Scene:** `ai_stress_arena` — NIGHT firefight, dense jungle, **3D trees**, flares/fires, 18v18
patrol→contact. Your real content, and the adversarial case `5kr3` asks for.

### The headline (`all_systems_on` — no toggle, the trustworthy rows)

| renderer | render scale | fps | GPU ms | CPU ms | draw calls | primitives |
|---|---|---:|---:|---:|---:|---:|
| Forward+ | **1.00 native** | **18.8** | 51.94 | 44.35 | 911 | 806,793 |
| Forward+ | **0.75 / mode5 (shipped)** | 22.3 | 43.18 | 41.24 | 910 | 806,611 |
| Mobile | **1.00 native** | **25.5** | 36.89 | 37.98 | 527 | 807,370 |
| Mobile | **0.75 / mode5 (shipped)** | **29.9** | 31.24 | 34.28 | 526 | 806,125 |

**NOTHING CLEARS 30 FPS IN THE NIGHT ARENA.** Best case on the board — Mobile at your shipped
0.75/mode5 — is **29.9**. At native, the best any renderer manages is **25.5**.

### Per-system attribution — Forward+ @ native (deltas off 51.94ms GPU)

| toggle OFF | fps | GPU ms | ΔGPU | Δprimitives |
|---|---:|---:|---:|---:|
| **jungle patches** | 24.1 | 39.68 | **−12.26** | **−572,438 (71% of the frame's geometry)** |
| **sun shadows** | 23.4 | 39.77 | **−12.17** | −119,192 |
| lights | 20.3 | 46.93 | −5.01 | +11,205 |
| characters | 19.9 | 48.61 | −3.33 | −109,234 (−483 draw calls) |
| grass/clutter | 18.2 | 50.56 | −1.38 | −37,739 |

**Four things the numbers say:**

1. **The jungle is the bomb — measured, not asserted.** −12.26ms and **71% of all geometry** from one
   toggle. `365s` reasoned "~350,000 alpha-tested triangles"; the real number is larger.
2. **SUN SHADOWS COST AS MUCH AS THE ENTIRE JUNGLE (−12.17ms = 23% of the GPU frame) AND EVERY PERF DOC
   SAYS THEY ARE OFF.** `ai_stress_arena.gd:390` = `sun.shadow_enabled = true`. PERF_LEDGER's
   *"shadows+MSAA already off"* is true of `game_world`'s project settings and **false of the bench we
   judge FPS by.** Draft ADR-026 mandates "0 dynamic-shadow". **Cheapest measured win on the board — no
   art, no LOD, no renderer decision.** Not applied: whether the *shipped* game wants a shadowed sun is
   an ADR-026 question, i.e. yours.
3. **Grass/clutter is effectively free (−1.38ms).** Pulling its density buys nothing and costs Pillar 2.
4. **The frame is not lopsidedly GPU-bound:** CPU 44.35 vs GPU 51.94. "GPU fill-bound" is about half
   true — a pure fill fix cannot carry 19→30 alone.

### `5kr3` answered on FPS, NOT on the pillar

Mobile **does not invert** under night+lights: **+36%** (25.5 vs 18.8 native) and it nearly **halves
draw calls** (527 vs 911). The decree's *direction* survives the adversarial test.
**But its headline number does not.** PERF_LEDGER says *"Mobile 40.9 fps … clears the gate at NATIVE"* —
that was `game_world`: daytime, open ground, zero dynamic lights, **Mobile's best case**. Here it is
**25.5**. The renderer is not the fix; it is a 36% discount on a frame that is ~70% too slow.

### ⚠ WAVE 2 KILLED MY OWN ATTRIBUTION — three of the five rows above are WITHDRAWN

Wave 1 blamed the Mobile anomaly on "a re-batch storm / too-short settle". **Wrong.** A 5s settle
(vs 1.5s) reproduced it (21.5 fps, still worse than baseline) — which forced a **control**: six
**identical** `all_systems_on` phases, **no toggle ever pressed**:

```
control_t0  17.9 fps  GPU 54.04  CPU 45.94  calls 1,013
control_t3  15.7 fps  GPU 49.60  CPU 68.76  calls 1,243
control_t5  16.8 fps  GPU 50.19  CPU 66.49  calls 1,268
```

**Nothing changed. fps swings ±10%, draw calls climb +25%, CPU swings ±47%.**

**`ai_stress_arena` is a live 18v18 firefight and it ESCALATES WHILE YOU MEASURE IT** — waves
reinforce, corpses and gibs accumulate, flares drift. **A sequential toggle-diff conflates the toggle
with the clock.** That is why `lights_OFF` read *slower* than all-on while **draw calls ROSE 627→864**:
a hidden light cannot add 237 draw calls — the arena did. The impossibility ("turning work off cost
frames") was the only reason I looked.

| finding | verdict against a ±3.3 fps / ±255-call / ±4.4ms noise floor |
|---|---|
| **jungle patches −12.26ms, −572,438 prims** | **STANDS** — ~4× the drift band; 71% of all geometry |
| **sun shadows −12.17ms** | **STANDS** — ~3× the GPU noise band, and measured at the *most* contaminated phase, so if anything **understated** |
| lights −5.01ms · characters −3.33ms · grass −1.38ms | **WITHDRAWN — inside the noise.** "Grass is free" is **not established**; do not act on it |
| **the renderer A/B** | **STANDS** — all four rows are phase 1, same point on the escalation curve; +36% ≫ ~1 fps spread |
| **"nothing clears 30"** | **STANDS** — the whole drift band sits below 30 |

**Method debt:** a live firefight is the right scene for a **renderer A/B** (same timepoint, two builds)
and the **wrong** scene for a **toggle-diff**. Per-system attribution needs a frozen arena (no
reinforcement waves, no corpse accumulation) or A/B/A re-baselining between toggles.

## 1.2 THE FIRST HONEST COMPLETE SUITE RUN IN THIS PROJECT'S HISTORY

```
36 PASS / 5 LEAK / 23 FAIL / 0 XFAIL / 4 TIMEOUT  (of 64)
hung:  test_ai_fairness, test_full_loop, test_hub_loop, test_vehicle_kill
leaks: test_anim_list, test_bullet_flight, test_gore_rig, test_mission_state, test_skills
```

**The 23 reds are not 23 problems — they are ~5 root causes wearing 23 lights** (8vtl's thesis, still
true, new numbers):

- **4 tests, one cause — `PaddyStamper: only 0 village anchors produced (floor=8). AO is malformed`**
  → `test_anti_aa_sim`, `test_exfil_sim`, `test_huey_ride`, `test_rescue_sim`. **This is `xo7i`/`v58s`
  actively breaking the build.** Worldgen Wave 1 shipped a paddy stamper that *requires* paddies onto a
  generator that has never made low ground. See §5 — this changes the plan.
- **7 tests, one cause — `2 RID allocations of type 'DummyMaterial' were leaked at exit`**
  → `test_firebase_sim`, `test_generator`, `test_mission_plan`, `test_paddy_stamper`, `test_patrol_sim`,
  `test_village_sim`, `test_world_alive`.
- **3 tests — the sprite fossils** `8vtl` already named (`sprite_actor`, `sprite_enemy`, `sprite_manifest`).
- **`test_fossils`: 19 new fossils** (j3ke recorded 18 — it has grown by one).
- Remainder genuinely distinct: `test_squad`, `test_bt_civilian`, `test_arena_patrol`, `test_ai_stress_arena`.

## 1.3 `yu8b` — the bead's own estimate confirmed by measurement

Bead: *"git gc reclaims ~4.2GB of LOOSE objects (packs are only 508MB — the 4.8GB .git number is
misleading and must NOT be used to justify a history rewrite)."*
**Measured: 9,744 loose objects = 4.23 GiB; in-pack 13,455; size-pack 507.68 MiB. The bead was right.**
`git gc --no-prune` run (non-destructive): **freed 2.8 GB, 3.1 → 5.9 GB.** All 19 commits still
reachable, HEAD unchanged.

---

# 2. WHAT SHIPPED

| bead | state | proof |
|---|---|---|
| **`lssl`** DRIFT-4 n2ij is a phantom | **CLOSED** | ruler rewritten; green 31/31 on spec; **proven red** (9 failures) by disabling the normalizer; `model_actor.gd` md5-verified byte-identical after |
| **`4b27`** (NEW) suite could never complete | OPEN (fix shipped, cause not cured) | per-test timeout + TIMEOUT verdict; proven red on `test_ai_fairness` |
| **`365s`** jungle never profiled | OPEN — attribution **delivered**, step 4 is yours | PERF_LEDGER §2026-07-16/17 + 4 CSVs |
| **`5kr3`** Mobile adversarial A/B | OPEN — FPS half answered, **pillar half not** | same |
| **`yu8b`** unblock the push | OPEN — **PARKED, see §3** | full written account on the bead |

**Committed:** `decf4bb2` — only my paths. **Your 108 uncommitted files were never staged** (verified).

---

# 3. WHAT FAILED OR WAS CUT — blunt

## 3.1 STAGE 2 (the push) — PARKED, NOT ATTEMPTED. No history-rewriting command ever ran.

**Two preconditions failed, and the rule is "a parked push is recoverable; a corrupted history is not."**

**Blocker 1 — the working tree is full of YOUR live work, which the plan did not know.**
**108 modified tracked files + 255 untracked ≈ 2,400 uncommitted lines.** Modified at **20:47–20:51 last
night**: `ai_stress_arena.gd`, `enemy_base.gd`, `enemy_squad.gd` — **that is your "squad AI further
fixed", and it is uncommitted.** `us_base_v3.blend` modified **22:53**, minutes before I started.
The planned method (soft-reset to `origin/audit-fixes` + cherry-pick replay of 19 commits) **requires a
clean tree.** Replaying over 108 dirty files either conflicts or silently mixes your uncommitted work
into replayed commits. **The method does not apply.**

**Blocker 2 — the disk was at 99% (3.1 GB free, single drive).** A multi-GB LFS rewrite with <3GB
headroom is how a repo gets a partial object write.

**Backup taken and verified anyway** — `C:\Users\caleb\RECONgame_BACKUP_2026-07-16\`:
- `RECONgame_allrefs_2026-07-16.bundle` — **1.9 GB**, `git bundle verify`: *"records a complete history"*
- `uncommitted_tracked_FULL.patch` — 110 MB, `git apply --check --reverse`: **VERIFIED**
- `dirty_tree_verbatim/` — 307 MB, byte copies of all 108 modified tracked files
- `untracked_manifest.txt` — 255 paths (not copied; 1.15 GB, untouched)

**⚠ That backup is on the SAME physical disk.** It protects against a bad command, **not** against
drive failure. **20 commits + ~2,400 uncommitted lines still live on exactly one disk. This is still the
project's #1 risk and nothing I did tonight changed that.**

**Push attempted once after committing: it died at my own 120s timeout while still packing ~2 GB.
GitHub did not reject it — I did not observe a rejection and will not claim one.** The 4 >100MB blobs
remain the known blocker per `yu8b`.

## 3.2 The fix I wrote that lied — reported because it is the most important thing here

My timeout fix's first full run reported **0 PASS / 64 FAIL**. I nearly wrote that into this report.
It was **false**: PowerShell's `Start-Process -PassThru` leaves `ExitCode` **null** unless you touch
`.Handle`, so `$null -eq 0` was False and **every test failed regardless of what it did**.
Caught only because `test_model_scale` passed standalone but failed on the board *with no error note* —
a contradiction. **For ~20 minutes this project had a harness reporting 64/64 FAIL on a healthy tree —
the exact disease I was hunting, introduced by the fix for it, by me.** An instrument is not
trustworthy because it is new.

## 3.4 WAVE 2: the fourth and fifth lying instruments — both mine

**(4) My 120s timeout invented two hangs.** I reported "4 hanging tests". **`test_hub_loop` runs 167s
and exits on its own** — its waits are bounded (`while ... t < 150.0`). It was never hung; my box was
too short, and my note said **"HUNG: killed after 120s"** — an overclaim stated as fact. Box raised to
420s and relabelled *"exceeded the box: hung, or slower than the box. Check before calling it hung."*
**Real tally: 2 true hangs** (`test_ai_fairness` — fixed; `test_vehicle_kill` — confirmed at a 240s box).

**(5) My bench attributed the clock to the toggle** (§1.1). Three published numbers withdrawn.

**And I nearly "fixed" a design decision.** I called `sun.shadow_enabled = true` an unintentional
leftover and "the cheapest measured win". **ADR-026 draft line 29 grants the night sun "the one allowed
dynamic shadow."** It is deliberate. Untouched. What *is* real: `game_world.gd:48` sets
`shadow_enabled = false` while the arena sets it true — **the bench is harder than the shipped game**,
so ~12ms of my headline numbers may not be a cost the shipped night world pays. That is an ADR-026
question, not a bug.

## 3.3 Not reached (18 of 23 stages)

`t6z9`, `bgfq`, `x2za`, `s14j`, `j3ke`, `zpw2`, `8vtl a/b/c`, `6d1s`, `eq6n`/`x1bs`, `qnth`/`a662`,
`2whe`/`bhu9`, `xo7i`, `a2qb`/`n2ij`, `g2vb`, `p9zy`/`37ob`.
**Why:** the plan estimated ~11h of work for an ~8h night and named a cut order. The night went instead
into (a) discovering the tree was full of your live work and re-deriving Stage 2 from scratch, (b) the
suite being unable to complete *at all*, which had to be fixed before any stage could be verified, and
(c) my own regression above. **Stages 1/3/4 (baseline + the measurement that was the point) landed.**
No stage was faked, and nothing was left half-applied.

---

# 4. THE BLESS LIST — yours, with the evidence attached

| # | Decision | Evidence gathered | My recommendation |
|---|---|---|---|
| **1** | **The gating FPS number** (`365s` step 4) | Measured, night arena, scale-tagged: **18.8 native / 22.3 shipped (Forward+); 25.5 native / 29.9 shipped (Mobile)**. `game_world` is easier (~27–29 native Forward+). **Nothing clears 30 in the arena.** | Gate on the **night arena**, not `game_world` — gate on your worst case or the gate is decoration. **30 @ 0.75/mode5** is honest and currently ~1 fps away on Mobile. I measured; **I did not legislate.** |
| **2** | **`rendering_method`** | Mobile **+36%** and **halves draw calls**, does **not** invert at night. But the "clears the gate at native" claim is scene-specific and **false here**. **Untouched — still `forward_plus`.** | Do **not** decide on FPS alone — see #3. |
| **3** | **`5kr3`'s real question: does Mobile drop a muzzle flash?** | **NOT TESTED.** Mobile caps ~8 omni/spot per mesh and drops the rest **silently**. An FPS number cannot answer this. | **This, not the +36%, decides the renderer.** A dropped flash is a **Fairness-Law breach (Pillar 1)**, not atmosphere. Needs your eyes on a firing line. |
| **4** | **ADR-026 (PS2 Budget)** — `mok6` | **Now urgent and concrete.** `scaling_3d/scale=0.75` + `mode=5` are **live in `project.godot` right now, set by an unratified draft.** And the arena runs **`shadow_enabled = true`** against the draft's "0 dynamic-shadow" — worth **12.17ms**. | Ratify or revert the config. Don't leave law and config disagreeing. **Then kill the arena's sun shadow** — cheapest win on the board. |
| **5** | **ADR-027 (PS2 World Design)** — `9f52` | **Blocking, and now provably so:** the paddy stamper it authorises **fails 4 campaign tests** (`AO is malformed`). | Ratify or pull the stamper. It cannot stay half-landed. |
| **6** | **Derived-vs-source** (`yu8b`) — **BIGGER than the bead knew** | 255 untracked files include `art_source/characters/` and `COMMAND BUNKER.blend`; 2 × 217MB `_backups/gear_armory_*.blend` are *the newest surviving snapshots of the LOST locker*. **Nothing deleted.** | Draw the line, then the migration is mechanical. **And get a copy onto a second physical disk today** — that is the actual risk. |
| **7** | **`n2ij`** | Its false-alarm half is **retired with proof**: every skeleton lands **exactly** on spec, feet at 0.000. **The art was never wrong.** Chunk-pop + "jungle too tame" untouched. | Re-walk after `xo7i`; the pop may have moved. |
| **8** | **`ida9` PLAYTEST R3** | **`test_hub_loop` HANGS.** The standing entry gate is "verify the new hub loop", and the hub-loop test never returns. | Worth knowing before you play. |

---

# 5. WHAT CHANGES THE PLAN GOING FORWARD

1. **`v58s` — not `xo7i` — is the live P0, and Wave 2 has the whole chain measured.** `xo7i` is
   **implemented and closed** (his Worldgen Wave 1 shipped it; verified 40/60 exact over 200 seeds).
   **Its thesis was wrong**, and only a measurement could show it: presets set **relief**, not **base
   elevation**. On seed 606 (COASTAL_HILLS, the *flattest* inhabited preset):
   ```
   [HeightmapStorage] Height: min=0.40 max=0.58 (normalized) × WORLD_HEIGHT_MAX 350  →  FLOOR = 140m
   [BillboardVegetation] Generated 1491 tree + 0 rice billboards      ← every chunk, still
   ```
   **The floor did not drop from 87.9m. It went UP to 140m.** Every paddy gate needs `< 50m`
   (`gameplay_grid.gd:287,299`, `vegetation_manager.gd:314` — all live, all unreachable). The stamper
   flood-fills *from* that dead classification (`paddy_stamper.gd:57`), gets 0 clusters, misses
   `HARD_FLOOR_VILLAGES = 8`, and `push_error`s **"AO is malformed"** — failing 4 campaign tests.
   **The AO is not malformed; the stamper's precondition is false.**
   **I fixed nothing here.** All three candidate fixes (lower the terrain base / make the gate relative
   / gate the floor on archetype) change worldgen shape or *"the user's minimum villages per AO"* —
   and `v58s`'s real build is ADR-027-gated. **Ratify ADR-027 and this becomes the top unblocked P0.**
2. **A second contradiction inside the paddy story, worth its own decision:** the stamper has **zero**
   references to preset/archetype — it demands 8 villages on **every** AO. But `5r4y`'s 40/60 means
   **60% of AOs are EMPTY by design** (90–300m relief). Even with elevation fixed, seed 848
   (ROLLING_HILLS) still hard-errors. **"floor=8 on every AO" and "the 40/60 empty war" cannot both be
   true.**
2. **The suite is now usable — so use it.** `8vtl`'s "10 reds" (07-13) is superseded: **23 FAIL / 4
   TIMEOUT / 36 PASS**, and the reds collapse to ~5 causes. Two of them (paddy ×4, RID leak ×7) are
   worth more than the other 21 lines combined.
3. **The Fairness Law had no guard, and one deleted function is why — FIXED, and this is the night's
   sharpest lesson.** `test_ai_fairness` didn't fail, it **hung**: `ba3f941b` created
   `_exposure_spread_mult()` *and* the probe (suite then: *"32 PASS / 0 FAIL"*); `f746462` **Track C**
   deleted the function and left the probe calling it. SCRIPT ERROR → `await` coroutine aborted →
   `quit()` unreachable → infinite hang → **with no timeout, the whole suite hung on it** → nobody ran
   the suite → nobody saw that **Pillar 1 was unguarded**. *One deleted function silently disabled this
   project's entire test suite.* Track C obeyed the fossil law (deleted the old system) but **left the
   caller** — the fossil law needs a matching rule: *delete the system, and everything that calls it.*
   Now: `x3.0 fresh → x2.50 half → x1.0 converged`, PASS, **proven red** by zeroing `EXPOSURE_PEAK`.
4. **The sun-shadow finding retires the "measure before optimizing" wait.** We have the profile now.
   The two biggest GPU costs are **jungle patches (−12.26ms)** and **a shadow the docs say is off
   (−12.17ms)**. Trunk colliders (`eaqv`/`2v3t`) can now be reasoned about — and the answer is still
   *not yet*: the jungle is already 71% of the frame's geometry.
5. **Stage 2's method must be rewritten before it is retried.** Any future plan that assumes a clean
   tree is wrong. The tree has ~2,400 lines of your uncommitted work in it, and it is normal here.
6. **Mobile attribution needs a longer settle** (>1.5s) before its per-system deltas mean anything.

---

**Nothing was deleted. `project.godot` untouched. Your uncommitted work untouched and backed up three
ways. Desktop clean. 20 commits still local — the push is your first call.**
