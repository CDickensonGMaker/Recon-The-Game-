# OVERNIGHT AUTONOMOUS RUN — 23-STAGE PLAN (rev B)
**Drafted:** 2026-07-16 · **Revised:** 2026-07-16 under the **windowed-Godot grant**
**Author:** recon-overseer (Director)
**Status:** PROPOSAL — plan-only, **NOT executed**, awaiting Summoner approval

> **REV B — THE GRANT.** Summoner: *"i have my sound turned off so if you need to run any windows to
> help test over the night feel free."* Windowed Godot is permitted **tonight only**, sound pre-cleared.
> This is **not** a repeal of the no-spam law: runs stay **purposeful, serialized, and short**, and the
> desktop is left **clean** — no orphaned Godot processes, no windows open.
>
> **What the grant changes:** rev A could not produce an FPS number and said so. It can now. `365s` gets
> a **real measured profile**, `5kr3` becomes live, `g2vb` comes off the cut list. Three of the four
> "needs your eyes" cuts were cut *for blindness alone* — all re-examined in §4.
>
> **What the grant does NOT change:** Stage 2 (unblock the push) stays first among the work. A shiny
> bench does not jump the queue ahead of getting 19 commits off a single disk. And **no trunk colliders
> before the profile** — the grant *gives* me the profile, it does not reverse the reasoning.

---

## 0. STATE OF THE GRAPH AS MEASURED TONIGHT (not remembered)

| Fact | Measurement |
|---|---|
| Branch | `audit-fixes`, **19 commits ahead of `origin/audit-fixes`** |
| **Push is BLOCKED** | 4 blobs >100MB in the unpushed range: `_backups/gear_armory_BROKEN_STATE.blend` (217MB), `_backups/gear_armory_BEFORE_civsplit.blend` (217MB), `assets/us/characters/us_base_v3.blend` (129MB), `assets/reference/review/lineup_review.blend` (119MB) |
| LFS | `git-lfs 3.7.1` installed, **no `.gitattributes` — never configured** |
| Suite runner | `run_all_tests.ps1` |
| Fossil probe | `SCAN_DIRS = ["res://scripts"]` — **`res://terrain` absent** |

### 0.1 THREE DISCOVERIES THAT REWROTE THIS REVISION

**(a) `365s`'s own bead comment is now STALE — `rendering_method` IS set.**
`project.godot:298` reads `renderer/rendering_method="forward_plus"`. The bead says *"rendering_method
still UNSET — deliberately NOT set (real architecture call for Summoner)."* The unpushed render/PS2 wave
(`d79321e`, `f14552f`) set it. **Forward+ is now the renderer of record by decision, not by default.**
Tonight's A/B therefore proposes a *change*, not a *choice*. Corrected in Stage 3.

**(b) The render scale is no longer a lie — it is now an unratified aesthetic.**
`project.godot:301-303`: `scaling_3d/mode=5` (nearest), `scaling_3d/scale=0.75`. This is **not** the old
0.77 FSR upscale that "hid the truth" — it is ADR-026's deliberate **PS2 nearest-neighbour look**. The
disease changed shape: the number is no longer *hidden*, it is *governed by a DRAFT ADR nobody ratified*
(`mok6`). **The rule survives intact: never report an FPS number without the scale beside it.** Tonight
reports **both** — native 1.0 **and** shipped 0.75/mode5 — side by side, always.

**(c) The attribution instrument ALREADY EXISTS — rev A's "static model" was a workaround for a tool I
did not know I had.** `scripts/levels/arena_perf_overlay.gd` (239 lines, shipped in `5ddabb1`) carries
real RenderingServer GPU render-time, per-system CPU buckets, and **F1–F6 attribution toggles: F1 jungle
patches · F2 grass/clutter · F3 lights · F4 characters · F5 debug-vis · F6 sun shadows.** That is exactly
the toggle-diff `t5mo` Phase 0 specifies. **The per-system attribution `365s` has owed since it was filed
is one bench run away.** Rev A's static model is **deleted from this plan** — an inferior substitute for
an instrument already in the tree.

### 0.2 THE SUMMONER'S STATUS REPORT — LEADS, NOT FACTS

Recorded as **unmeasured owner claims** and routed to the stage that tests each. None is true until a
probe says so (truth law).

| His claim | Status | Tested by |
|---|---|---|
| "squad AI further fixed" | **unverified** | Stage 1 baseline suite (`test_ai_*`, `test_arena_*`) |
| "3D trees now in AI stress test, **looks amazing**" | **unverified** | **Stage 4 benches THAT** — it is the real content |
| "night jungle looks good" | **unverified** | Stage 4 (adversarial night is 5kr3's whole case) |
| "FPS ramped up a bit but still more work" | **unverified** | **Stage 3 measures it** |
| "moved toward PS2 design markers for perf" | **= the 0.75/mode5 config above — set by a DRAFT ADR** | → bless #3 |
| "world-loading/streaming was being worked" | **unverified** | `cp3s`, below |

**`cp3s` (streaming seed sweep) — does the world-load work change any stage's assumptions? Two
interlocks, both real:**
1. `cp3s` names **5 RNG bugs**; bug #5 is *"`gameplay_grid.gd` bare `randf()` — the heavy_jungle LOS
   check rolls fresh dice every call... the SMOKING GUN for the 'feels like it streams' perception."*
   **Stage 10 (`zpw2`) deletes `gameplay_grid.has_line_of_sight()` — the zero-caller function that holds
   that exact randf. Stage 10 kills one of cp3s's 5 bugs for free, as a side effect of a fossil sweep.**
   Stage 10's verify records it so `cp3s` can be updated with proof.
2. `cp3s` **depends on `xo7i` + ao-preset-table** — you must know a cell's preset before seeding its
   foliage. **Stage 19 (`xo7i`) unblocks half**; ao-preset-table remains. **`cp3s` is a tomorrow bead,
   not a tonight stage** — but tonight moves it from *doubly blocked* to *singly blocked*.

**No stage's assumptions are invalidated by the world-load work.** The unpushed range touches
`project.godot` rendering (folded into Stage 3) and worldgen wave 1 (accounted in Stage 19).

### 0.3 GATE CHECK (ADR-015, bead 97u3)

Every stage is one of the four exempt classes: **bug fix · presentation for an already-shipped system ·
standing-decree item · evidence-gathering probe.** No feature epic is touched. **The grant does not widen
the gate — it widens *verification*, which is exempt by name.**

**Contradiction found and flagged, not silently amended:** `bd dep` records `xo7i` as **depending on**
`v58s`. The bead text says the reverse — `xo7i` is v58s's *root cause* and *supersedes* its fix (*"would
have painted a rice paddy onto a 90-METRE HILLSIDE. Cut."*). Stage 19 fixes the edge.

---

# 1. THE 23 STAGES

**Honest time math: ~11 hours of work for an ~8 hour night.** I will not pretend 23 stages fit. Value
lands early; the **cut order in §2 names exactly what I expect to drop.** Stages 21–22 are **STRETCH**
and I expect to lose at least one.

Every stage has a **FAIL RULE**: one attempt, revert its own changes, one honest paragraph to the bead,
jump to the named stage. **No stage improvises a second strategy at 3am.**

**Windowed-run discipline (Stages 3, 4, 20, 21):** one window at a time, serialized, never concurrent
with another Godot; each run bounded by an explicit duration; `taskkill` sweep + assert zero `Godot*`
processes after every stage; desktop left clean.

---

## PHASE A — MAKE THE WORK SURVIVE (Stages 1–2)

### Stage 1 — Baseline capture (the "before" number)
**Beads:** none (instrument for all others)
**Do:** Tag `overnight-base-2026-07-16`. Full suite + clean headless boot →
`production/war_room/overnight_2026-07-16/00_baseline/`. Record pass/fail/leak per test, fossil count vs
baseline (j3ke says 97 vs 79), boot SCRIPT ERROR count. Also record what the suite says about his
**"squad AI further fixed"** claim.
**Verify:** `godot --headless --path . --quit-after 300 2>&1 | grep "SCRIPT ERROR"` + suite output persisted.
**Time:** 20 min · **Risk:** none
**FAIL RULE:** If the suite runner won't run, **abort the night** and report. A night with no baseline
proves nothing. The only stage whose failure stops everything.

### Stage 2 — `yu8b`: unblock AND execute the push ★ FIRST AMONG THE WORK
**Beads:** `RECONgame-yu8b` (P0)
**Do:** Nineteen commits — arena waves, damage flatten, PS2 budget, worldgen wave 1, identity dressing —
exist **on one disk**. Safety branch `backup/pre-lfs-2026-07-16` first. `.gitattributes` tracking the 4
offenders via LFS. The blobs are baked into 19 local commits, so LFS must reach **only the unpushed
range**: `git lfs migrate import --include-ref=refs/heads/audit-fixes --above=100Mb` rewrites **pushed**
history and is **FORBIDDEN**. Instead: soft-reset to `origin/audit-fixes`, commit `.gitattributes` first,
replay the 19 commits preserving message+author (`git cherry-pick -n` per commit). Per the bead,
**`git rm --cached` none of the 4 — they are last copies.** Restore `satchel_m3.blend` +
`helmet_v3_fitted.blend` (currently `D`; `s14j` proves they were deleted on a **false empty-file
signal**) and do not commit those deletions. `git gc`.
**Verify:** zero blobs >100MB in `origin/audit-fixes..HEAD`; `git push --dry-run` clean; **real push**;
`git log --oneline @{u}..HEAD` empty.
**Time:** 45–90 min (~670MB LFS upload — slow, not risky) · **Risk:** MEDIUM-HIGH (history replay)
**FAIL RULE:** If replay diverges or push rejects **once**: `git reset --hard backup/pre-lfs-2026-07-16`,
leave the tree as found, **skip to Stage 3**. No second strategy. Never touch pushed history. Never
delete a blend to make it fit. → bless #5.
**Downstream:** Stages 5, 6, and Stage 23's push. If it fails the night still runs — the work stays local
and Stage 23 becomes commit-only.

---

## PHASE B — THE MEASUREMENT THE GRANT UNLOCKED (Stages 3–4)

> **Why here and not later:** `365s` demands the profile of the world **as shipped**. Stage 19 (`xo7i`)
> changes the terrain presets — benching after it would measure a world that did not exist when the bead
> was filed. Bench first = the honest discharge, it lands while I am freshest, and it cannot be starved
> by an overrunning cleanup stage. **It does not jump Stage 2.**

### Stage 3 — `365s`: THE FIRST HONEST PER-SYSTEM JUNGLE PROFILE ★ TAKES THE GATE OFF THE BLESS LIST
**Beads:** `RECONgame-365s` (**P0**), discharges `t5mo` Phase 0
**Do:** *"The jungle has NEVER been profiled."* Tonight it is. Windowed, serialized, via the **existing**
`arena_perf_overlay` (§0.1c) — **F1–F6 toggle-diff attribution**, real RenderingServer GPU render-time,
per-system CPU buckets. **Jungle actually loaded** — dense jungle, player standing in it, not an
open-ground spawn (an open-ground daytime spawn is Mobile's best case, and it is exactly the n=1 evidence
`5kr3` exists to distrust). **Run the full matrix, recording the scale beside every single number:**

| | scale **1.0** (native) | scale **0.75 / mode5** (shipped) |
|---|---|---|
| all systems on | | |
| F1 jungle patches off | | |
| F2 grass/clutter off | | |
| F3 lights off | | |
| F4 characters off | | |
| F6 sun shadows off | | |

Correct `365s`'s stale comment (§0.1a). Test his *"FPS ramped up a bit"* claim against the number.
**Propose** the gating FPS number.
**Verify:** `production/PERF_LEDGER.md` gains an entry in **the same honest format as prior entries** —
hardware, renderer, scale, seed, scene, method, every number scale-tagged. Deltas must sum coherently;
**if the toggles don't add up, say so — an incoherent attribution is a finding, not a failure.**
**Time:** 60 min · **Risk:** LOW-MEDIUM (the instrument exists; this is running it)
**Bless-list effect:** **item #2 (the gating number) drops from an open question to a one-word ratify.**
I **propose** a number with evidence. I **do not set it** — *"perf first, a gating FPS number beats any
feature"* is a **project law**, and I do not author law at 3am. That distinction is why the bless list exists.
**FAIL RULE:** If the overlay's GPU timing reads implausible (the known FPS=1 screenshot-stall artifact),
record raw + note it — **do not sand the data.** If the arena won't boot windowed, skip to Stage 5 and
**the bench stays on the bless list.** Never fake a number to clear an item.

### Stage 4 — `5kr3`: the adversarial night A/B — Mobile vs Forward+ ★ EVIDENCE, NOT A QUESTION
**Beads:** `RECONgame-5kr3` (P1) · **depends on Stage 3** (its `bd dep` already says so)
**Do:** Mobile was chosen on **n=1** — one daytime open-ground zero-dynamic-light spawn, **Mobile's best
case**. The game's hardest renderer scene is a **night firefight by a burning ville**: `illum_flare.gd`
omnis (3.5/42m drifting), `gun_fx.gd` muzzle (3.0/7m) + explosion (8.0/16m), `mission_generator.gd`
village fires (1.8), `tunnel_room.gd` mouths. **Mobile caps ~8 omni/spot per mesh and silently DROPS
clustered lights past the cap.** That is not an atmosphere bug — **a dropped muzzle flash is a
Fairness-Law breach** (flash must *always* telegraph). **Pillar 1, not Pillar 2.**
Bench the **real content** he flagged: **3D trees in the stress arena** + night jungle, full arena, flares
+ muzzle + fire. A/B Mobile vs Forward+ at **both scales**.
**The Pillar-1 check is not an FPS number and must never be reported as one:** stand in the arena, fire,
and **observe whether muzzle flash and tracers still telegraph** under the light cap. Screenshot it.
Fold in **`wz58`** free while windowed: the PS2 wave made billboards single-sided (`CULL_DISABLED`→
`CULL_BACK`) — screenshot foliage from both sides to answer *does single-sided foliage leave holes?*
**Evidence only; the aesthetic verdict is his** ("Caleb's eyes" is in the bead title).
**Verify:** A/B table in PERF_LEDGER (scale-tagged, both renderers); screenshots →
`.../04_renderer_ab/`; an explicit **written PASS/FAIL on light telegraphing under Mobile**.
**Time:** 60 min · **Risk:** MEDIUM
**FAIL RULE:** If Mobile drops telegraphing lights, **record it and do NOT flip the renderer** — that is
the decree's stated reversal condition and it is *his* to pull. If the A/B won't run, skip to Stage 5;
bless #1 stays a question.
**I do not flip `rendering_method` tonight under any outcome.** It is deliberately `forward_plus` today
(§0.1a); changing the renderer of record is an architecture call. → bless #1.

---

## PHASE C — MECHANIZE THE RULES (Stages 5–6)

### Stage 5 — `t6z9`: the machine that says NO
**Beads:** `RECONgame-t6z9` (P0) · **depends on Stage 2**
**Do:** (a) pre-commit hook rejecting any >100MB file **that is not LFS-tracked** (the exemption matters —
without it the hook rejects our own Stage-2 commits) and new `*_BACKUP*`/`*_BROKEN*`/`*_DUPLICATE*` paths.
Append **below** the beads marker in `.beads/hooks/pre-commit` — `core.hooksPath` is beads'. (b) the novel
one: assert **every `.gitignore` pattern still matches a real path** — a pattern matching nothing has been
walked out from under, which is literally what swallowed 1.66GB. (c) `bd dep add k77e 97u3` — the GATE
currently blocks nothing for `k77e`'s 12 children. *(This tightens the gate on the Living War work I most
want to build. That is the gate working.)*
**Verify:** synthesize a 101MB temp file → commit **rejected**; an LFS-tracked large file → **accepted**;
gitignore probe number recorded; `bd show 97u3` lists `k77e`.
**Time:** 45 min · **Risk:** LOW
**FAIL RULE:** If the hook fights beads' hooksPath, ship (b)+(c), bead (a), go to Stage 6.

### Stage 6 — `bgfq`: stop calling hand-authored truth "disposable output"
**Beads:** `RECONgame-bgfq` (P0) · **depends on Stage 5** (its probe is this stage's ruler)
**Do:** Mechanisms (2) and (3) only. `.gitignore:31-35` claims `us_base_v3.blend` is *"a pure function of
us_grunt_v2.blend"* — **false**: it is hand-authored truth (7 rigs, 361 meshes, SQUAD collection,
`_BAG_TEMPLATES`) and `us_grunt_v2.blend` is deleted. If that pattern ever matches again, one `git clean`
kills it. Correct bead `cn68`'s dead `art_source/` paths. **Keep mechanism (1) disarmed — do NOT restore
`us_grunt_v2.blend` to "fix" `make_base_v3.py`; that re-arms the gun.**
**Verify:** gitignore probe reports zero orphan patterns; `git check-ignore -v
assets/us/characters/us_base_v3.blend` returns **nothing**.
**Time:** 20 min · **Risk:** LOW · **FAIL RULE:** skip to Stage 7.

---

## PHASE D — FIX THE RULERS BEFORE TRUSTING ANY MEASUREMENT (Stages 7–15)

> Four of tonight's beads exist because **a probe lied**: `a662` (dead feature, green test), `lssl`
> (broken ruler holding the GATE), `zpw2` (blind spot), `8vtl` (10 reds = 3 problems). Rulers first.

### Stage 7 — `x2za`: Blender 5.0.1 readiness audit ★ GATES ALL BLENDER STAGES
**Beads:** `RECONgame-x2za` (P1)
**Do:** **Read-only.** `blender -b <file> -P` over every `.blend` under `assets/` (the bead's own NOTES
already correct its `art_source/` scope — that path doesn't exist). Check the 5 checkpoints: bpy,
collections, Eevee Next, Asset Browser, **glTF exporter**. Contract: **APPEND/LINK only, never re-author,
never Save-As-older.** No file written. **No screenshots — the no-unprompted-Blender-screenshot law
survives the grant** (the grant covers *Godot* windows for verification, not Blender views).
**Verify:** artifact `.../07_blender_501_audit.md` — one row per blend:
objects/meshes/**scenes**/actions/warnings. `git status` on `assets/` unchanged.
**Time:** 40 min · **Risk:** LOW
**FAIL RULE:** If bpy rejects a blend or the **glTF exporter checkpoint fails**, record it and **SKIP
Stages 8 and 17 ENTIRELY.** Continue at Stage 9.

### Stage 8 — `s14j`: the tools write art invisible to humans ★ P0 ROOT CAUSE OF THE DRIFT
**Beads:** `RECONgame-s14j` (P0) · **depends on Stage 7**
**Do:** 5 blends have **objects but ZERO scenes** → Blender opens blank → a human deletes them as empty.
That is exactly what happened to `satchel_m3.blend` (8 objects, fully made, shipping in `us_medic.glb`).
Fix every `tools/*.py` that authors a blend to `bpy.context.scene.collection.objects.link(obj)`. Build
the **machine**: a probe that opens every tools-authored `.blend` and **FAILS on 0 scenes**.
**Verify:** probe must go **RED on the 5 known offenders** (`satchel_m3`, `helmet_v3_fitted`, `m16a1`,
`helmet_v2`, `helmet_v1`), then **GREEN after regenerating them**. *A probe that never went red proves
nothing.* Diff regenerated GLBs against shipped — cost must be zero.
**Time:** 60 min · **Risk:** MEDIUM
**FAIL RULE:** If regeneration changes any GLB's mesh content, **stop, revert, park.** Keep the tool fix +
probe if they pass. Skip to Stage 9.

### Stage 9 — `j3ke`: triage the 18 fossils ★ MUST PRECEDE Stage 10
**Beads:** `RECONgame-j3ke` (P1)
**Do:** **Ordering is load-bearing.** Stage 10 re-baselines the register; if it ran first it would
**launder j3ke's 18 real fossils into the grandfather list permanently.** Triage table for all 18:
**WIRE | CUT | DEFER** + reason. **Cut only the unambiguous.** **Do NOT regenerate the baseline** — CLAUDE.md
names it *"the one forbidden move... a debt register, not a snooze button."* **Do NOT cut the living-world
stubs** — Track F design calls → bless #6.
**Verify:** fossil count drops 97 → toward 79, every drop explained line-by-line. Baseline JSON unchanged.
**Time:** 50 min · **Risk:** MEDIUM
**FAIL RULE:** Any cut that reds the suite/boot → revert that cut, mark DEFER. >2 reds → ship the table
only, go to Stage 10.

### Stage 10 — `zpw2`: the blind spot is the size of the terrain engine ★ ALSO PAYS `cp3s`
**Beads:** `RECONgame-zpw2` (P1) · **depends on Stage 9** · **partially discharges `cp3s`**
**Do:** Add `res://terrain` to `SCAN_DIRS` (`REF_DIRS` already has it — declarations were never scanned,
so ~7,000 lines of vendored TerrainEngine has never been held to ADR-023). Re-baseline **once, honestly**
— it **will GROW**, and that growth is debt **admitted**, not created. Tag terrain entries distinctly so
they can never be confused with the 79 grandfathered. Take the free kills:
`gameplay_grid.has_line_of_sight()` (**zero callers, and it holds the determinism-poisoning `randf` —
this is `cp3s` bug #5, his "world randomly streams" smoking gun**), `gameplay_grid.get_cover()` (read by
nothing), `poisson_sampler.gd` (124 lines, dead).
**Verify:** assert `SCAN_DIRS.size() == 2`; terrain additions tagged; `has_line_of_sight` +
`poisson_sampler.gd` gone; boot clean. **Record the `cp3s` bug-#5 kill on that bead with proof.**
**Time:** 45 min · **Risk:** MEDIUM
**FAIL RULE:** If deleting `has_line_of_sight` breaks anything, revert the delete, **keep the SCAN_DIRS
extension + honest re-baseline** — that is the deliverable. Skip to Stage 11.

### Stage 11 — `lssl`: the GATE is partly held by a FALSE ALARM ★ HIGH VALUE
**Beads:** `RECONgame-lssl` (P1), touches `n2ij` (**GATE holder**)
**Do:** `test_model_scale` measures the **bind-pose AABB** — the exact ruler ModelActor's own comment
calls "the speck-soldier bug" — and demands **every** unit be 1.7132m, **including a 9-year-old child**.
`civ_elder` renders 1.550m **on spec**. The test is wrong; the art is fine. Rewrite to measure rendered
height **per-unit against that unit's own spec**, giving ADR-002 a guard that actually guards (it has
none today). **DO NOT RESCALE ANY ART.**
**Verify:** GREEN with zero art touched; **then prove the ruler works** — perturb one unit's spec, confirm
RED, revert. *A green test that cannot go red is the disease.*
**Time:** 40 min · **Risk:** LOW · **FAIL RULE:** skip to Stage 12.

### Stage 12 — `8vtl-a`: 3 tests guarding a renderer ADR-001 killed
**Beads:** `RECONgame-8vtl` (1/3)
**Do:** `test_sprite_actor` / `test_sprite_enemy` / `test_sprite_manifest` → delete or rewrite against
ModelActor. `test_sprite_enemy` references deleted `german_rifleman.tres` and **self-skips its assertion
block when absent** — it would go green because the check is *absent*. **Do NOT delete
`scripts/visuals/sprite_actor.gd`** — ADR-001 killed the sprite **matrix**, not the fallback; 6 scripts use it.
**Verify:** red count −3; `grep -r sprite_actor scripts/ | wc -l` still 6.
**Time:** 30 min · **Risk:** LOW · **FAIL RULE:** skip to Stage 13.

### Stage 13 — `8vtl-b`: one root cause, four red lights
**Beads:** `RECONgame-8vtl` (2/3)
**Do:** Chase the single AUDIT-12 cause — *"Lambda capture at index 0 was freed"* — behind
`test_firebase_sim`, `test_full_loop`, `test_rescue_sim`, `test_village_sim`. Fix the capture lifetime,
not the four tests.
**Verify:** all four green **from one change**. **If it takes four changes it was not the root cause —
stop and report that**, because the bead's central claim would then be wrong.
**Time:** 60 min **HARD TIME-BOX** · **Risk:** MEDIUM-HIGH
**FAIL RULE:** On expiry, write what was learned, skip to Stage 14. **The likeliest stage to eat the
night — do not let it.**

### Stage 14 — `8vtl-c`: the two genuinely distinct reds
**Beads:** `RECONgame-8vtl` (3/3) — `test_anti_aa_sim`, `test_xp_spend`
**Do:** Fix if mechanical. If either is a **balance/design** question (XP spend is Pillar-3-adjacent —
loud play must never be the optimal XP strategy), **do not decide it** → bless #9.
**Verify:** green, or diagnosed in writing with the design question named.
**Time:** 40 min · **Risk:** MEDIUM · **FAIL RULE:** skip to Stage 15. Close `8vtl` only if 10→0.

### Stage 15 — `6d1s`: let the ENGINE be the machine
**Beads:** `RECONgame-6d1s` (P1) · **depends on Stages 9, 10**
**Do:** Godot has printed the fossil list on **every boot for months** — ~60 warnings drowned in ~25
integer-division ones, so the stream reads as noise. Fix the 11 real sites (5 unused_signal · 2
unused_private_class_variable · 1 unreachable_code · 3 unused_variable), then promote those four classes
to **errors** in `project.godot [debug]`. The engine then refuses to run on a fossil — instantly.
**Defer the noisy classes** (integer_division, shadowed_variable_base_class, unused_parameter — those want
an underscore, not a deletion).
**Verify:** headless boot **clean** with the four at `=2`; **prove the trap** — reintroduce one unused
signal, confirm boot **fails**, revert.
**Time:** 45 min · **Risk:** MEDIUM
**FAIL RULE:** Boot red and cause not obvious in 15 min → **revert the `[debug]` block only**, keep the 11
fixes, skip to Stage 16. *A red build at 3am with nobody awake is worse than a fossil.*

---

## PHASE E — THE ART/ENGINE P0s (Stages 16–18)

### Stage 16 — `eq6n` + `x1bs`: make ModelActor FAIL-CLOSED ★ BEST VALUE/RISK TONIGHT
**Beads:** `RECONgame-eq6n`, `RECONgame-x1bs` (P1)
**Do:** **Zero art cost, engine-side, immunises every future model.** Today `Base_Human` (402-tri skinned
body) renders **inside every new grunt**, and every grunt wears **2 helmets, 2 rucks, 2 bandoliers** —
**876 tris = 18.8% of every rendered US soldier is a duplicate z-fighting with the real thing**, shipping
since v2. You authored it right (`hide_render=True`); **the exporter erases your intent**
(`hide_set(False)` on everything) and ModelActor's contract is a **blacklist** that has never heard of
`Base_Human`. Flip to a **whitelist**: only live body (`*_joined`, `grunt_*`), worn gear (`*_worn`),
weapon (`*_world`) render; everything else hidden by default; GruntDresser turns ON what the man carries.
**WARNING (load-bearing):** `helmet_camo_shell` drives GibSystem's flying-helmet shot. **Delete it as a
"duplicate" and gore dies silently.** The fix is not deletion — it is stopping the live body rendering donors.
**Verify:** in-engine probe — exactly ONE visible helmet/ruck/bandolier per grunt; `Base_Human` not
visible; **`helmet_camo_shell` still present in the node tree** (hidden, not deleted); GibSystem resolves
every `REGIONS` donor. *(A windowed eyeball is now available as bonus confirmation — the probe is still
the proof.)*
**Time:** 60 min · **Risk:** MEDIUM
**FAIL RULE:** Revert cleanly, **skip Stage 17** (its contract is downstream of this naming), go to Stage 18.

### Stage 17 — `qnth` + `a662`/`3qj7`: the donor contract + head gibs
**Beads:** `RECONgame-qnth` (P1), `RECONgame-a662` (**P0**), `RECONgame-3qj7` (P1)
**Depends on Stage 7 (glTF checkpoint) AND Stage 16.**
**Do:** **Read `3qj7` before touching `a662` — a662's stated fix is superseded and would waste the
night.** a662 says "merge head_frag meshes into the lineup blend"; `3qj7` proves frags are **not stored in
any blend** — they are **generated at export** by `make_head_frags.build_head_frags()`, and
`export_us_squad.py` **never called it**. Second bug: frags are created **hidden**, and `select_set()`
**silently no-ops on a hidden object** — the exporter printed *"head frags: 7"* and shipped **zero**.
Fix the exporter (`qnth`: stop `hide_set(False)` erasing donor intent; call `build_head_frags()` after the
rename, before the height normalize), re-export headlessly. **Then re-point the gib test at a NEW model so
it can never go green on dead art again** — it currently points at `us_grunt_v2`, which still has frags.
*That re-pointing is the actual bead.*
**Verify:** glTF **node table** (not the exporter's own print) shows **7 `head_frag_*` per soldier**;
`dismember_head_burst()` returns **true** on a **new** grunt; the re-pointed test **RED before / GREEN after**.
**Time:** 75 min · **Risk:** HIGH (Blender write + 5.0.1 exporter + every US model)
**FAIL RULE:** **If Stage 7 flagged the glTF checkpoint, DO NOT RUN THIS AT ALL.** If any GLB's mesh/tri
count moves beyond the added frags, **revert all GLBs from git and park.** Skip to Stage 18.

### Stage 18 — `2whe` + `bhu9`: two gib/dressing bugs, engine-side
**Beads:** `RECONgame-2whe`, `RECONgame-bhu9` (P1)
**Do:** `2whe`: `_spawn_gib` clones the Mesh and loses surface OVERRIDE materials — a popped head **reverts
to the atlas default cell**, so a man's face changes as he dies. `bhu9`: `set_sprite` never rebuilds
hitzones — stale bone indices/hulls sync against the **new** skeleton after a body swap, so shots land on
wrong zones (**Pillar 1**, not cosmetic).
**Verify:** headless probe — gib a dressed head, assert override material matches source cell; body-swap,
assert bone indices resolve against the new skeleton and zone AABBs moved.
**Time:** 50 min · **Risk:** MEDIUM · **FAIL RULE:** ship whichever passes, bead the other, go to Stage 19.

---

## PHASE F — THE WORLDGEN ROOT CAUSE (Stage 19)

### Stage 19 — `xo7i`: the game has only EVER generated ONE terrain preset ★ P0 ROOT CAUSE
**Beads:** `RECONgame-xo7i` (P0), unblocks `v58s` (P0) + **half of `cp3s`**
**Do:** `terrain_engine.gd::_ready()` hardcodes `set_preset(ROLLING_HILLS)` **forever**. `set_preset()` is
called from **exactly one place in the codebase — `terrain_lab.gd`, the dev tool.** `game_world.gd` and
`mission_generator.gd` contain **zero** TerrainEngine references. Five presets exist; the game has run
**one**. That is why the floor is **87.9m**, and why **0 of 65,536 cells** are rice paddy — every paddy
branch gates on `height < 5.0` / `< 50` / `< 30`. **The paddy code was never broken; the generator has
never made low ground.**
Fix: derive the AO archetype **from the operation seed** (ADR-010 — deterministic by construction), call
`set_preset()` before `terrain_generator.generate(seed)` at `terrain_manager.gd:124`. Make
`height_scale = 280.0` **per-preset** (global today in `heightmap_storage.gd:11` + `terrain_engine.gd:19` —
even a flat preset gets a 280m range). Fix the backwards `bd dep` edge (§0.3).
**Scope discipline:** preset selection **only**. The **paddy stamper stays PARKED** — it needs **ADR-027,
UNRATIFIED** (`9f52`). **I do not build against a draft ADR.**
**Verify:** probe over ~8 seeds — **>1 distinct preset**; a `COASTAL_HILLS` seed yields **floor < 5m** (the
band that has never existed); **same seed → bit-identical heightmap across two runs** (ADR-010 — a
seed-chosen preset must never break determinism). Then boot and read the line the log has printed on every
run since it shipped and nobody read: **"N rice billboards"** — expect **N > 0 for the first time in
project history**. **Re-bench (Stage 3's matrix, all-systems row only) to record the terrain change's FPS delta.**
**Time:** 60 min · **Risk:** MEDIUM-HIGH (worldgen blast radius)
**FAIL RULE:** Determinism assert fails → **revert immediately.** A non-deterministic province breaks
ADR-010 and `5i8a` — worse than one preset. Skip to Stage 20.
**Note:** even on success **`v58s` does NOT close** — `_apply_riparian_belt()` still overwrites any cell
within 22m of water below 0.55 density, and **paddy density is 0.2**, so every paddy near water becomes
jungle. *"A paddy could only survive where it could never be irrigated."* Say so; claim no win.

---

## PHASE G — WHAT THE GRANT GAVE BACK (Stages 20–21)

### Stage 20 — `a2qb` + `n2ij`: evidence on two GATE HOLDERS ★ NEW — grant-enabled
**Beads:** `RECONgame-a2qb` (P1, **GATE holder**), `RECONgame-n2ij` (P1, **GATE holder**) · after Stages 11 & 19
**Do:** **The grant's biggest strategic gift is not the bench — it is that two of the six P1s holding the
GATE are objectively visual and were cut for blindness alone.**
`a2qb`: *"player still not seated inside the Huey; two heli models visible (green + white)."* **Two models
rendering is an objective fact, not a taste question.** Look, find the second heli, fix it, fix the seat
transform. A **bug** → gate-exempt.
`n2ij`: Stage 11 retires its false-alarm ruler half. Of the rest, **"terrain chunk pop" is objectively
observable** — walk the world windowed and record whether pop occurs (ADR-013: **≤2km maps never stream**,
and audit #2 traced the pop to *a 3km streamer inside a fully-loaded 1280m map*). **Stage 19 just changed
the terrain, so the pop may have moved.** *"Jungle too tame" is aesthetic — evidence only.*
**Verify:** `a2qb` — probe asserting exactly ONE heli in the scene tree + player parented to the seat, plus
a screenshot. `n2ij` — recorded walk + screenshots; a written statement on whether pop reproduces post-Stage-19.
**Time:** 60 min · **Risk:** MEDIUM
**FAIL RULE:** Ship `a2qb`'s fix if the second heli is obvious; otherwise **evidence only**. Skip to Stage 21.
**Ceiling, stated plainly:** **neither bead closes tonight.** `ida9` (PLAYTEST R3) is the standing session
entry gate and **only he can discharge it.** Tonight converts two GATE holders from *unexamined* to
*fixed-with-evidence, awaiting his playtest.* → bless #7, #8.

### Stage 21 — `g2vb`: the weapon-condition HUD ★ UN-CUT by the grant · **STRETCH**
**Beads:** `RECONgame-g2vb` (P1)
**Do:** Rev A cut this reasoning *"a HUD I can't look at is a HUD I can't verify."* **The grant removes the
only objection.** The r4bk Law: **a feature with no visible HUD affordance DOES NOT EXIST.** Weapon
condition now **persists across missions** (the free firebase clean is gone) and drives jam chance, but the
player's only feedback is a toast at 60, a toast at 30, and **then it jams**. He cannot check his rifle —
so he cannot make the decision *"burn a kit now, or push to the bench?"*, **which is the entire decision
the system exists to create.** Until it ships, weapon condition is **a hidden punishment** — exactly what
r4bk forbids.
Build a readout near the ammo counter: **CLEAN / DIRTY / FOULED / SEIZING — not a number** (matches
ADR-018's "never a number" instinct). Surface `repair_kit_count` or he cannot plan.
Presentation for an already-shipped system → **gate-exempt**.
**Verify:** headless probe — node exists, updates on condition change, reads the 4 states at the right
thresholds. **Then look at it windowed** and screenshot all four states.
**Time:** 50 min · **Risk:** LOW-MEDIUM
**FAIL RULE:** Skip to Stage 22. **First stretch stage to drop** — it is the one that most wants his taste
on wording and placement anyway.

---

## PHASE H — CLEANUP & CLOSE (Stages 22–23)

### Stage 22 — `p9zy` + `37ob`: the stale-path sweep and the comment purge · **STRETCH**
**Beads:** `RECONgame-p9zy`, `RECONgame-37ob` (P1)
**Do:** `p9zy` — three architects counted three different numbers (27 / 22-of-44 / 3). **Produce ONE honest
number and record the three priors as what they were: estimates.** Fix the named **LANDMINE** first:
`tools/make_jungle_patches.py:978-980` still writes `res://assets/models/vegetation/{felled_tree,
felled_trunk,tree_stump}.glb`; the files live at `assets/world/vegetation/`. **The next jungle regeneration
bakes 3 dead paths into the destructible jungle** (`en75`, `2v3t`). Kill the md5-identical
`gear_armory.blend` duplicate (a sixth locker). Fix dead truth-law comments at `enemy_base.gd:366`,
`insertion_ride.gd:57`, `civilian.gd:23`.
`37ob` — 6,508 comment lines / 32,141 code = **20%**; **285 tombstones** narrating the past inside the
source. Top 6 offenders only (`enemy_base.gd` alone has 567 comment lines). **A tombstone camouflages a
fossil** — CLAUDE.md: *"comment discipline and the FOSSIL LAW are the same law."* This is probe-adjacent,
not cosmetics.
**Verify:** path probe **RED on the landmine first, then GREEN**; comment ratio re-measured; **boot clean +
suite no worse than Stage 1**.
**Time:** 60 min · **Risk:** MEDIUM
**FAIL RULE:** **First thing cut if the night runs long.** Ship `p9zy`'s landmine alone — a real bug with a
real cost. Skip to Stage 23.

### Stage 23 — Session close: beads with proof, commit, push, morning report
**Beads:** all touched · push depends on Stage 2
**Do:** Update/close every touched bead **with its named proof** — *"mitigated"/"likely fixed" close
nothing* (ADR-015). Any bead whose probe did not run stays **OPEN** with an honest note. Update
`PERF_LEDGER.md` "Still owed". Refresh charter §8's open-P1 list if Stages 11/20 moved it. **Assert zero
orphaned Godot processes; desktop clean.** `git add` my paths only; commit; **push**. Morning report.
**Verify:** `bd ready` reflects the new truth; `git log --oneline @{u}..HEAD` **empty**; final headless boot
clean; final suite diffed line-by-line against Stage 1 in the report; `tasklist | findstr Godot` **empty**.
**Time:** 40 min · **Risk:** LOW
**FAIL RULE:** If push fails (Stage 2 failed), **commit anyway** and make "19+N commits still local,
unpushed" **item #1** on the bless list.

---

# 2. DEPENDENCY MAP, CUT ORDER & FALLBACK CHAINS

```
 1 BASELINE ─────────► (hard-gates EVERYTHING; failure ABORTS the night)
     │
 2 yu8b PUSH ★ ──────► 5 t6z9 ──► 6 bgfq        [fail 2 ⇒ skip to 3; night runs, work stays local]
     │
 3 365s REAL BENCH ──► 4 5kr3 A/B               [3 is 4's bd dep; fail 3 ⇒ skip 4, both stay on bless]
     │                                           [3 measures the world AS SHIPPED — before Stage 19
     │                                            changes the terrain. Re-bench folded into 19.]
 7 x2za BLENDER ─────► 8 s14j                   [glTF checkpoint RED ⇒ SKIP 8 AND 17 ENTIRELY]
     └───────────────► 17 qnth/a662

 9 j3ke TRIAGE ──────► 10 zpw2 RE-BASELINE      [ORDER LOAD-BEARING: 10-before-9 launders j3ke's 18
     │                     │                      fossils into the grandfather list forever]
     │                     └─► also kills cp3s bug #5 (the LOS randf) for free
     └─────────────────────┴──► 15 6d1s         [fix violations before arming the trap]

11 lssl ──► retires half of n2ij ──► 20 a2qb/n2ij
16 eq6n/x1bs ───────► 17 qnth/a662              [fail 16 ⇒ SKIP 17, go to 18]
19 xo7i ────────────► unblocks v58s + half of cp3s ──► 20 (pop may have moved)
```

**Hard blockers:** Stage 1 → the night. Stage 2 → 5, 6, 23's push. Stage 3 → 4. Stage 7 → 8, 17.
Stage 9 → 10's honesty. Stage 16 → 17.

**Honest time budget: ~11h of work, ~8h of night. CUT ORDER when behind:**
**22 (cleanup) → 21 (g2vb) → 14 (8vtl-c) → 18 (2whe/bhu9) → 8 (s14j).**
**NEVER cut: 1, 2, 3, 23.** Stage 13 carries a hard 60-min box — the most likely to eat the night.

**The anti-thrash law:** one attempt per stage. Revert its own changes, one honest paragraph to the bead,
jump to the named stage. **No stage improvises a second strategy at 3am.**

---

# 3. THE MORNING BLESS LIST — decisions I must NOT make alone

> **The grant shrank this list from 11 open questions to 9, and converted the two biggest from *questions*
> into *ratifications with evidence attached*.**

| # | Decision | Status after the grant | My recommendation |
|---|---|---|---|
| 1 | **`rendering_method`: Forward+ vs Mobile** | **QUESTION → EVIDENCE.** Stage 4 hands you the adversarial night A/B. **Correction: it is already SET to `forward_plus`** (`project.godot:298`) — 365s's "still UNSET" comment is stale. This is a *change*, not a *choice*. **I flip nothing tonight under any outcome.** | Follow Stage 4's number **and** its Pillar-1 light-telegraph verdict. If Mobile drops a muzzle flash, the +40% is irrelevant — that is a Fairness-Law breach. |
| 2 | **The gating FPS number** | **LARGELY DISCHARGED.** Stage 3 measures it honestly, both scales, per-system. **Reduced to a one-word ratify of a proposed number.** I measure; **I do not set project law at 3am.** | Proposed after Stage 3, scale-tagged. |
| 3 | **RATIFY / reject ADR-026 (PS2 Budget)** — `mok6` | **NOW URGENT, and the grant is why I could see it.** `scaling_3d/scale=0.75` + `mode=5` (nearest) are **live in `project.godot` right now, set by an UNRATIFIED draft.** Your *"moved toward PS2 design markers"* = this. **The shipped game is currently configured by a document with no authority.** | Ratify or revert the config — but do not leave law and config disagreeing. |
| 4 | **RATIFY / reject ADR-027 (PS2 World Design)** — `9f52` | **BLOCKING.** `v58s`'s paddy stamper cannot be built against a draft. Stage 19 ships the root cause and stops at that line. | Ratify — Wave 1 already executed against it, itself a small process violation worth noting. |
| 5 | **Derived-vs-source: what belongs in git at all** | Unchanged. The two 217MB `_backups/gear_armory_*.blend` are *the newest surviving snapshots of the LOST locker*. **Tonight I LFS all four and delete nothing.** | Hand-authored sources → LFS; `_backups/*` → the RESCUE archive, out of git. |
| 6 | **j3ke's living-world stubs: wire or cut** | Unchanged. Cutting `world_sim.materialize_near` etc. is a **roadmap** decision, not a fossil cleanup. | Defer as a named exception **with an expiry**, not a silent grandfather. |
| 7 | **`n2ij`'s remainder** | **IMPROVED.** Stage 11 kills the false ruler; Stage 20 hands you a recorded walk + screenshots on chunk pop **after** Stage 19 changed the terrain. *"Jungle too tame"* stays yours. | Judge from Stage 20's evidence. |
| 8 | **`ida9` PLAYTEST R3 — the standing entry gate** | **Unchanged and unchangeable. Only you can discharge it.** Unrun for **95 commits**; it holds the GATE. Tonight changes much of what you would be testing. | Run it first thing. |
| 9 | **`8vtl-c`: XP-spend semantics, if design not mechanics** | Unchanged. Pillar 3: *loud play must never be the optimal XP strategy.* | Report-only tonight. |
| 10 | **`6yc3`: the 10×7 atlas CELL MAP** | Unchanged. **Only you have it.** | 5 minutes of your time unblocks a P2 epic. |
| 11 | **`wz58`: single-sided foliage** | **QUESTION → EVIDENCE.** Stage 4 screenshots both sides. The verdict is still yours ("Caleb's eyes" is in the bead title). | Judge from the screenshots. |
| — | ~~Stage 2 outcome~~ | Only appears if Stage 2 fails — then it is **#1**. | |

---

# 4. RE-EXAMINED: WHAT THE GRANT CHANGED, AND WHAT IT DIDN'T

**PROMOTED (cut in rev A for blindness alone):**
- `365s` per-system attribution → **Stage 3** (and the instrument already existed — §0.1c)
- `5kr3` → **Stage 4** · `wz58` → folded into Stage 4 · `g2vb` → **Stage 21**
- `a2qb` + `n2ij` chunk-pop → **Stage 20** — **the grant's biggest strategic gift: 2 of the 6 GATE holders
  were cut for blindness alone.**

**STILL CUT — the grant does not reach them:**
- **`eaqv` / `2v3t` (trunk colliders).** The grant *gives* me the profile; **it does not reverse the
  reasoning.** `365s`'s own words: *"the project is about to add physics colliders to the exact system most
  likely already causing the frame time."* Stage 3 produces the profile **tonight** — so this becomes a
  **tomorrow** bead **with evidence**, which is exactly right. Adding colliders the same night I first
  measure the jungle would discard the measurement's whole purpose.
- **`tfug` (perf landmines: interpolation teleports, O(n²) at 60Hz, corpses sync forever).** Real, but
  **Stage 3 tells us whether any of it matters.** Optimizing before attribution is the mistake `365s` was
  filed to stop. Tomorrow, aimed.
- **`ida9`, `e6qc`, `r4bk`, `zet2`** — need a human **playing**, not a human *looking*. **The grant gave me
  eyes, not his judgement.** `r4bk` (squad controls) additionally needs **his keyboard** — the charter notes
  squad keys were never verified on it.
- **`pa77`–`pa80`, `wzal`** (ADS passes) — **his bench, his eyes, his marker placement.** Explicitly his track.
- **`v58s`'s stamper** (ADR-027 unratified) · **`7bmc`** (inside unratified ADR-026) · **`3asc`**
  (Blender-gated on Stage 7 + a material judgement) · **`f0kv`** (needs re-export **and** a squad-wide
  dressing decision) · **`6yc3`** (needs the atlas map) · **`x1bs.1`** (blocked behind `x2za`).
- **`xdys`** — `bd` already shows it blocked on `365s`. **Correctly. Stage 3 may unblock it by morning.**
- **`z90e`** (save migration is a live no-op) — touches saves; a bad night costs campaign data.
- **`cp3s`** — §0.2: **doubly blocked → singly blocked** by Stages 10 + 19. Tomorrow.

**Gate-forbidden, unchanged by the grant:** `k77e` + all **LW-1…LW-12**, `m6g6`/`lhi7`, `5r4y`,
`2kcp`/`rw28` (FROZEN), `gfgr` (FROZEN), `u9md`, `8l06` (**its 3 amendments await your ratification**),
`4i60`, `ooel`, `91vy`. **Stage 5 tightens the gate on `k77e`'s 12 children — the work I most want to
build. That is the gate working.**

---

# 5. HONEST ACCOUNTING

**What tonight buys you if it all lands:** the push unblocked and 19 commits safe; **the first honest
per-system jungle profile in the project's life, at both scales, with the gating number reduced to a
one-word ratify**; the Mobile question answered with adversarial evidence including a Pillar-1 verdict on
light telegraphing; four guardrails that are **machines instead of documents**; the fossil probe seeing the
terrain engine for the first time (killing a `cp3s` streaming bug in passing); the suite going from **10
reds ≈ 3 problems** to something readable; **18.8% of every US soldier's triangles** ceasing to z-fight;
head gibs alive on the new art with a test that cannot lie; **more than one terrain preset for the first
time ever**, rice paddies finally possible; weapon condition made visible; two GATE holders moved from
unexamined to fixed-with-evidence.

**What tonight still does NOT buy you:** a discharged GATE (`ida9` needs *you*), a rice paddy you can wade
through (ADR-027), a renderer flip (yours), or a set gating number (yours to ratify — I hand you the
measurement, not the law).

**The pattern under half these beads, named plainly:** a signal that reads as meaningful and means nothing.
A GATE that gated nothing. A `.gitignore` matching nothing. A green gib test pointing at dead art. A ruler
demanding a 9-year-old be grunt-sized. An exporter printing *"head frags: 7"* while shipping zero. A boot
log printing *"0 rice billboards"* on **every run since it shipped**, that nobody read. **And tonight's own
discovery: an attribution instrument sitting finished in the tree while I planned a worse substitute for
it.** Same disease, my hands.

**Rev A said tonight is the night the instruments start telling the truth. Rev B says the same — the grant
just means one of them gets to say it out loud, in frames per second, with the render scale written next
to it.**

---

**Awaiting the Summoner's approval. Not one stage has been executed.**
