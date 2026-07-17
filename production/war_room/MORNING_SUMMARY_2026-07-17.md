# MORNING SUMMARY — overnight run of 2026-07-16/17

> # ⛔ READ THIS FIRST — THE ONE THING ONLY YOU CAN FIX
>
> **23 unpushed commits + ~2,400 lines of your uncommitted work live on ONE 98%-full drive.**
> Your `enemy_squad.gd` / `enemy_base.gd` / `ai_stress_arena.gd` edits from **20:47–20:51** —
> the "squad AI further fixed" work — **are not committed and not pushed.** `us_base_v3.blend`
> (22:53) likewise.
>
> **My backup is on that same physical disk.** `C:\Users\caleb\RECONgame_BACKUP_2026-07-16\`
> (1.9GB bundle, verified; 110MB patch, verified; 307MB verbatim copy of all 108 dirty files).
> **It protects you from a bad command. It does NOT protect you from that drive failing.**
>
> **This is the single largest exposure in the project, it is larger than every bug below, and
> nothing I did tonight reduced it.** Get a copy onto second physical media before anything else.
> The push is blocked behind a call only you can make (bless #5); a plain file copy is not.
>
> ### ⚠ AND: three numbers from my first report are WITHDRAWN
> **"grass/clutter is free" is NOT established. "lights cost 5ms" is NOT established.
> "characters cost 3.3ms" is NOT established.** All three were inside my own noise floor — killed by a
> control run (§1.1). Two findings survive: **the jungle** and **the renderer A/B**.

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

# 0b. WAVE 3 DELTA — a deliberately short wave

| item | result |
|---|---|
| **`j3ke` triage (19 fossils)** | **CUT NOTHING — and that is the finding.** 2 are *your live uncommitted work* (`HOT_CEILING` sits in a file you edited **20:48 tonight**; `get_bore_dir` is your bench track). 15 are Track F built-ahead-of-wiring (**roadmap call**). 2 are gated on unratified ADR-027. **None was mine to delete.** |
| **Register** | **Honestly SHRUNK 79 → 77.** Two `world_config` consts are genuinely wired now (the PS2 FPS ladder), so they left the register. **`--write-baseline` was never run** — it would have laundered all 19. Probe still red at 19. |
| **`zpw2` blind spot** | **MEASURED: 68 undeclared dead symbols in `terrain/`** (96 → 164 fossils when `res://terrain` joins SCAN_DIRS). Ruler reverted, md5-verified. **Confirmed:** `gameplay_grid.gd:385 get_cover` — declared, read by nothing, *which is why the paddy's `cover=0.1` does nothing.* |
| **`zpw2` shipped?** | **No — deliberately.** It is blocked on `j3ke`, and `j3ke` is blocked on you. Shipping it without a re-baseline drowns 19 real fossils in 68 old ones; shipping it *with* one launders them. Stopping was the correct move. |
| **ADR-023 Amendment A** | **DRAFTED** (`production/adr/ADR-023-amendment-A-DRAFT-delete-the-callers.md`), bead `6n0b`. *Delete the system AND every caller.* |

**The structural finding under `j3ke`** — the register has exactly two states: **grandfathered forever**
or **delete now**. All 19 are a third thing: *built ahead of its wiring, with an owner and a plan*. So
the probe must stay red forever **or someone launders 19 real symbols to green it**. *A probe that can
only go green by lying is the disease that probe exists to cure.* → **Needs a DEFERRED class with an
owner and an expiry** (bless #6).

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

# 4. THE BLESS LIST — six decisions, each with its evidence

*(Ordered by what unblocks the most. Everything here is yours; I gathered, I did not decide.)*

| # | Decision | Evidence I gathered | My recommendation |
|---|---|---|---|
| **1** | **THE DISK.** Get the repo onto second physical media. | 23 unpushed commits + ~2,400 uncommitted lines, one drive at 98%, my backup on that same drive. | **Do this first, today.** It needs no decision — just a copy. It is the only irreversible risk on this list. |
| **2** | **ADR-027 (PS2 World Design)** — `9f52` | **Blocking, provably.** The stamper it authorises **hard-fails 4 campaign tests**. Chain measured end-to-end: **floor 140m** → gates need `<50m` → **0 rice cells** → stamper flood-fills a dead classification → 0 anchors → `push_error "AO is malformed"`. **The AO is not malformed; the stamper's precondition is false.** | **Ratify or pull the stamper — it cannot stay half-landed.** Ratifying makes `v58s` the top unblocked P0 with the whole chain already mapped. **Also decide:** the stamper demands 8 villages on **every** AO while `5r4y` makes **60% empty by design** — those cannot both be true. |
| **3** | **`rendering_method`** — decided by **Pillar 1**, not the +36% | Mobile is **+36%** (25.5 vs 18.8 native) and **halves draw calls** (527 vs 911); it does **not** invert at night. **But the ledger's "Mobile 40.9, clears the gate at native" is scene-specific and false here** — that was daytime open-ground `game_world`. **Untouched: still `forward_plus`.** | **Do not decide on FPS.** Mobile caps ~8 omni/spot per mesh and **drops the rest silently**. **`5kr3`'s reversal condition — does a muzzle flash still telegraph? — WAS NOT TESTED.** A dropped flash is a **Fairness-Law breach (Pillar 1)**, not atmosphere. Needs your eyes on a firing line. That, and only that, decides it. |
| **4** | **ADR-026 (PS2 Budget)** — `mok6` | **`scaling_3d/scale=0.75` + `mode=5` are live in `project.godot` right now, set by an unratified draft.** Separately: the arena runs `sun.shadow_enabled = true` (**−12.17ms**) while `game_world.gd:48` sets it **false**. **⚠ Correction: that shadow is NOT a bug** — the draft grants the night sun *"the one allowed dynamic shadow"*. **Untouched.** | Ratify or revert the config — don't leave law and config disagreeing. **The real question:** the bench is **harder than the shipped game**, so ~12ms of my headline may be a cost the shipped night world never pays. That decides whether it belongs in the gate. |
| **5** | **The gating FPS number** (`365s` step 4) | Measured, scale-tagged, night arena: **18.8 native / 22.3 shipped (Forward+); 25.5 native / 29.9 shipped (Mobile)**. `game_world` is easier (~27–29). **Nothing clears 30 in the arena.** Noise floor ±3.3 fps (§1.1). | Gate on the **night arena**, not `game_world` — **gate on your worst case or the gate is decoration.** **30 @ 0.75/mode5** is honest and ~1 fps away on Mobile. Depends on #4 (the shadow). **I measured; I did not legislate.** |
| **6** | **The fossil register needs a third state** — `j3ke` / `6n0b` | 19 real fossils; **none deletable by me** (2 are your live work, 15 Track F, 2 ADR-027-gated). Register has only *grandfather forever* or *delete now*. **`zpw2` is blocked behind this; its blind spot is now measured at 68 symbols.** | Add a **DEFERRED class with an owner and an expiry** — never a silent grandfather. Then `zpw2` lands in one honest pass. **And ratify ADR-023 Amendment A** (`6n0b`, drafted) — plus decide whether to fund the call-site probe or accept deletion-time grep. |

**Also worth knowing before you play `ida9`:** `test_hub_loop` is **not** hung (my box was wrong) — it
runs **167s** and reports. But `test_vehicle_kill` **is** hung, same disease as the fairness probe.

**Retired, no decision needed:** `n2ij`'s false-alarm half — **proven**: every skeleton lands *exactly*
on spec, feet at 0.000. **The art was never wrong.** Chunk-pop and "jungle too tame" still want your eyes.

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

6. **The fossil law has a hole, and it is the sharpest structural lesson of the night.** ADR-023 says
   *delete the old system when you replace it.* Track C **obeyed it** — and still left a caller pointing
   at a corpse, which hung the suite, which silenced Pillar 1's only guard. **The law is silent on the
   direction that actually hurt us.** Draft amendment at
   `production/adr/ADR-023-amendment-A-DRAFT-delete-the-callers.md` (bead `6n0b`), with the incident as
   the worked example and an honest enforcement section: **static typing does NOT catch it** (measured —
   `spawn_enemy` is typed `-> EnemyBase` and the call was still only a runtime error), `test_fossils.gd`
   is structurally blind to it, and the only thing that catches it today is **the suite timeout I
   shipped** — which does not prevent the bug, it just makes it *visible*.

---

# 6. HOUSEKEEPING

**Nothing was deleted. `project.godot` untouched. `--write-baseline` never run.** Your 108 dirty files
are byte-identical to the backup (spot-verified). Desktop clean — zero Godot processes.
**Commits tonight:** `decf4bb2`, `c7c1bbf7`, `f45c17a4`, `f59ceb61` (+ this update). **All mine only —
none of your uncommitted work was ever staged.**

**The scoreboard, honestly:** 5 of 23 planned stages landed in Wave 1; Wave 2 spent itself on `xo7i`
(already done), the fairness hang, and auditing my own bad numbers; Wave 3 was deliberately short and
**shipped almost nothing — because almost nothing left is mine to decide.**

**Five lying instruments tonight. Three were mine** — the no-timeout suite (his), the ExitCode-null
harness (mine), the 120s box that invented two hangs (mine), the toggle-diff that measured the clock
(mine), and the fossil probe's terrain blind spot (his). **Every single one was caught by an
impossibility the data itself made visible** — a test passing standalone but failing on the board;
turning work *off* costing frames. **Not one was caught by being careful.** That is the actual lesson,
and it is why the retractions above are the most valuable thing in this document.
