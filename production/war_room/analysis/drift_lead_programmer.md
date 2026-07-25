# DRIFT COUNCIL — LEAD PROGRAMMER / GODOT SPECIALIST

> **BANNER (corrected 2026-07-25, ghost-code audit):** The `STATE_OF_PROJECT.md` reference below is
> historical; that doc was deleted on purpose 2026-07-23. Do not seek or restore it. Canon is
> `production/GAME_GUIDE.md` + `production/adr/`.

**Charge:** Does the restructure hold? What did it silently break?
**Method:** Read the code, ran the suite, wrote a probe (`tools/probe_drift_scale.gd`). Never the commit message.

---

## 0. THE HEADLINE — WHAT THE BRIEFING AND THE COMMIT BOTH MISSED

The restructure's P0 (236 MB of *ignored* art swept **into** git) has a mirror image nobody has named:

> **The same walked-out-from-under `.gitignore` also swept the Blender working set *out* of existence.**
> `art_source/` is gone from disk. `gear_library.blend` (the locker) and `us_grunt_v2.blend` (the US
> lineage truth source) are **not on disk and not in HEAD**. Four exporters still read them as INPUTS.
> **The entire US grunt export pipeline is dead — and Caleb is remaking the US grunts right now.**

And the trap inside the trap:

`.gitignore:31-33` justifies not tracking `us_base_v3.blend` with: *"us_base_v3.blend is a pure function
of us_grunt_v2.blend + tools/make_base_v3.py."* **That sentence is now false.** `us_grunt_v2.blend` was
deleted in `53c903d` ("stale US lineage blends"). `make_base_v3.py:37` points `SRC` at a file that does
not exist. **us_base_v3.blend is no longer regenerable.**

It survives today for exactly one reason: the restructure *accidentally* swept it into git as a 117 MB
blob. That accident is the P0. **So the obvious P0 fix — `git rm --cached` the four big files and
re-point the ignore patterns — would untrack the last surviving copy of an unregenerable, unbacked-up
truth source.** Do that without restoring `us_grunt_v2.blend` first and one disk failure ends the project's
character art.

**Both destroyed sources ARE recoverable from history. Verified, blobs resolve:**

```bash
git show 53c903d^:art_source/characters/base_psx/us_grunt_v2.blend  > <restore>   # 94,079,010 bytes
git show d6ae7cd^:art_source/characters/base_psx/gear_library.blend > <restore>   # older generation
```

Caveat on the locker: `gear_library.blend` was tracked at `base_psx/`, deleted in `d6ae7cd`, then
re-created by `make_gear_library.py` at `.../locker/` — which `.gitignore:45` ignored. **The locker
generation (with all gear work since d6ae7cd) is gone for good.** Only the older `base_psx` copy survives.
It is regenerable from `make_gear_library.py` *once `us_grunt_v2.blend` is back*.

**Order of operations is non-negotiable: RESTORE `us_grunt_v2.blend` BEFORE touching `.gitignore`.**

---

## 1. THE RESOLVER — verdict: **MECHANISM SOUND, CLAIM OVERSTATED (FALSE AS WRITTEN)**

The commit claims:
> *"ModelActor.model_path() / all_units() are now the ONLY way to turn a unit_id into a .glb."*

**In the shipping game (`scripts/`, `scenes/`, `data/`, `tests/`): TRUE.** Swept every `.gd/.tscn/.tres`.
Zero hardcoded character `.glb` paths. Every resolution goes through `model_exists()` / `model_path()` /
`all_units()` (`ally_base.gd:210`, `enemy_base.gd:368-375`, `hitzone_editor.gd:114`, `test_model_scale.gd:24`,
`test_anim_library.gd:54`). The claim holds where it matters.

**As written — "the ONLY way" — FALSE.** Three tools bypass it with hardcoded literals:

| File:line | Hardcoded path |
|---|---|
| `tools/build_ragdoll_scene.gd:32` | `res://assets/us/characters/us_grunt_v2.glb` |
| `tools/diag_tracks.gd:4` | `res://assets/us/characters/us_grunt_v2.glb` |
| `tools/dump_anim_structure.gd:11-12` | `us_grunt_v2.glb`, `vc_guerilla_mosin.glb` |

These *run today* (the `.glb`s still exist — only the `.blend` was deleted), so they are LANDMINE, not
LIVE FIRE. But the commit's own warning applies verbatim: *"the next faction re-org breaks it silently."*
It already wrote the bug it warned about. Two-line fix: `load(ModelActor.model_path("us_grunt_v2"))`.

### Missing-model handling: **GOOD — this is the restructure's genuine strength**
`model_path()` returns `""` on miss (no crash). `setup()` returns `false`. Callers degrade
**ModelActor → SpriteActor → capsule** (`enemy_base.gd:375-392`). **No invisible soldier, no crash.**
`enemy_base.gd` even has an "ART-AHEAD" `sprite_unit_fallback` that warns loudly and dresses the unit in
a stand-in. This is well-built. Cost: `all_units()` does a `DirAccess` scan per call and `model_path()` a
linear `ResourceLoader.exists()` walk — negligible at 25 units, but it is called per-spawn. Not a problem today.

---

## 2. THE FULL STALE-PATH SWEEP

`art_source/` **does not exist**. `assets/models/` **does not exist**. Every row below references one of them.

### LIVE FIRE — the Blender pipeline is dead *right now*, on the exact work Caleb is doing

| File:line | Dead path | Why it burns |
|---|---|---|
| `tools/export_us_grunt_v2.py:15,229` + `tools/export_grunt.bat:5` | `art_source/characters/base_psx/us_grunt_v2.blend`, `.../variants/` | **THE GRUNT EXPORT. Input gone (deleted 53c903d), variants dir gone.** m14/m60/m79 variants unbuildable. |
| `tools/make_gear_armory.py:47` | `art_source/characters/locker/gear_library.blend` | LOCKER input gone. **`gear_armory.blend` is `M`odified in his tree right now.** |
| `tools/make_gear_library.py:28,29` | `BASE`=`us_grunt_v2.blend` (gone); `OUT_BLEND`=`art_source/.../locker/` | The script that would **rebuild the locker** is itself dead. Both ends broken. |
| `tools/make_base_v3.py:37` | `assets/us/characters/us_grunt_v2.blend` | **`us_base_v3.blend` is NOT regenerable.** Falsifies `.gitignore:31-33`. |
| `tools/make_rto.py:22,23` | `art_source/.../gear_library.blend`; OUT → `art_source/.../us_rto.blend` | Input gone; output would write outside the asset tree. |
| `tools/make_civilians.py:51,437` | `art_source/.../us_troops`, `.../locker/gear_library.blend` | Village pipeline dead. |
| `tools/make_civilian_anims.py:497` | `art_source/.../locker/gear_library.blend` | Civilian anim pipeline dead. |
| `tools/export_anim_library.bat:4`, `.py:15`, `sync_anim_library.py:10`, `bake_family_clip.py:5` | `art_source/characters/base_psx/anim_library.blend` | **The shared 100-clip library every character borrows from.** The `.blend` lives at `assets/shared/` now; the `.bat` still passes the dead path. |
| `tools/export_vc_guerilla.py:15,258` + `.bat:3` | `art_source/.../vc_guerilla_v2.blend`, `.../variants/` | `.blend` survived at `assets/nva_vc/characters/`; the `.bat` still passes the dead path. |
| `tools/make_soldier_lineup.py:11` | OUT → `art_source/characters/lineup_review.blend` | Writes outside the tree; would resurrect `art_source/`. |
| `tools/build_weapons_vc.py:259` | `art_source/characters/blends/weapons_vc.blend` | Dead. |
| `tools/fit_webbing.py:46`, `add_variants.py:14`, `fix_unit_files.py:6` | `art_source/characters` | Dead. |

*(Sprite-era tools — `assemble_sheets.py`, `build_sprite_stage.py`, `render_sprite_sheets.py`,
`catchup_farmer.ps1`, `finish_units.ps1`, `overnight_run.ps1` — also point at `art_source/`, but ADR-001
killed the sprite renderer. Classify as **DEAD TOOL**: delete, don't fix.)*

### LANDMINE

| File:line | Dead path | Why |
|---|---|---|
| **`assets/world/vegetation/patches/patches.json:7-9`** | `res://assets/models/vegetation/{felled_tree,felled_trunk,tree_stump}.glb` | **The briefing missed this one.** It looked for broken `ext_resource` in `.tscn`/`.tres` — this is a **JSON data file**, read at runtime by `terrain/vegetation/jungle_patch_layer.gd:21`. The dead paths are **already baked and committed**. Nothing reads `tree_ref.model` *yet* (destructible trees unimplemented — `en75`/`2v3t`), so it does not burn today. **But it is armed now, not "on next regeneration".** |
| `tools/make_jungle_patches.py:978-980` | same three | The generator. Fixing only this (as the briefing frames it) leaves the **already-poisoned `patches.json`** in place until someone pays for a full Blender jungle regen. **Fix BOTH — the `.json` is a 3-line edit that costs nothing.** |
| `tools/build_ragdoll_scene.gd:32`, `diag_tracks.gd:4`, `dump_anim_structure.gd:11-12` | hardcoded character `.glb` | Bypass the resolver (§1). |
| `.gitignore:34-45` | `art_source/...` (9 patterns) | Match nothing. **This is the P0 mechanism itself** — and the reason the locker was destroyed. |

### DEAD COMMENT (truth-law violations)

| File:line | Claim |
|---|---|
| `scripts/enemies/enemy_base.gd:366` | "`assets/models/characters/`" |
| `scripts/missions/insertion_ride.gd:57` | "sitting in `assets/models/characters/`" |
| `scripts/world/civilian.gd:23` | "sitting in `assets/models/characters/`" |
| **`production/bible/09_CHARACTERS_ART.md:13,15`** | **CANON.** Points the bible at `assets/models/characters/` + `assets/models/viewmodels/`. Worse than a code comment — this is the document that outranks CLAUDE.md. |
| `production/GAME_SCALE_STANDARD.md:58` | `assets/models/gore/` |
| `production/GORE_WORKFLOW.md:36` | "Export to `assets/models/gore/`" |
| `production/MODEL_SESSION_HANDOFF.md:9,44` | `art_source/characters/base_psx/us_base_v3.blend` = "V3 IS THE TRUTH SOURCE" |
| `production/DESTRUCTIBLE_JUNGLE_PLAN.md:12,53,55,56` | `assets/models/vegetation/` |
| `AUDIT_HANDOFF.md:56`, `STATE_OF_PROJECT.md:111`, `production/research/*.md`, `production/ART_MISSING_2026-07-11.md:67` | various |
| `tools/make_jungle_vegetation.py:17`, `tools/make_medic.py:14` | docstrings only — their actual `OUT_DIR`/`OUT` constants are **correct**. |

**`export_presets.cfg:11`** still excludes `art_source/*` — harmless, but now meaningless.

---

## 3. TEST SUITE — verbatim

`powershell -File run_all_tests.ps1` (Godot 4.7-stable, headless, 45 tests):

```
=== 31 PASS / 4 LEAK / 10 FAIL / 0 XFAIL (of 45) ===
leaks: test_bullet_flight, test_gore_rig, test_mission_state, test_squad
FAIL: test_anti_aa_sim, test_firebase_sim, test_full_loop, test_model_scale,
      test_rescue_sim, test_sprite_actor, test_sprite_enemy, test_sprite_manifest,
      test_village_sim, test_xp_spend
```

**The commit message says only `test_model_scale` is red. Ten are red.** That is itself a truth-law
violation — the commit reports one failure and ships ten.

**But NONE of the ten is a restructure regression.** Evidence, not assertion:
- The path-sensitive tests are **GREEN**: `test_asset_probe` PASS, `test_world_boot` PASS,
  `test_anim_library` PASS. Asset resolution survived the move intact.
- `615ddd0` touched **no gameplay logic** — only path-bearing files (viewmodel `.tscn` ext_resources,
  `model_actor.gd` MODEL_DIRS, `ground_clutter/claymore/jungle_patch_layer`, `tools/*`).
- The failures are logic, not paths: `test_xp_spend` → *"score math wrong / attribute purchase failed"*.
  4× *"Lambda capture at index 0 was freed"* (`firebase_sim`, `full_loop`, `rescue_sim`, `village_sim`).
  The 3 sprite tests fail on **deliberately deleted** sprite assets (removed in the *parent* commit
  `53c903d`) testing a renderer **ADR-001 declared dead** — they should be deleted, not fixed.
- `run_all_tests.ps1`'s `$KnownRed` list is **empty**. The scoreboard has a mechanism for expected reds
  and nobody is using it. Ten reds are just… red, indefinitely.

### The `test_model_scale` alibi: **ALIBI TRUE, DIAGNOSIS FALSE — the test is broken, not the art**

The commit's alibi ("red identically at the parent; pre-existing n2ij") is **structurally sound**:
`git show --stat 615ddd0` shows `{models => civilians}/characters/civ_elder.glb | Bin` — a **pure rename,
zero bytes changed**. The `test_model_scale.gd` diff is **path-only**. Same asset, same math → same number.
**Not a regression. Confirmed.**

**But there is no height bug.** I probed it (`tools/probe_drift_scale.gd`, ADR-015 evidence):

```
unit             target  TEST(all)  SKEL(rest)  gib_k
civ_elder        1.550     2.950      1.550     0.53
civ_kid          1.260     1.256      1.260     1.00
us_grunt_v3      1.713     3.464      1.713     0.49
us_rto           1.713     4.083      1.713     0.42
vc_guerilla      1.713     3.401      1.713     0.50
```

**Every single rig's skeleton rest-span lands EXACTLY on its target.** The normalizer is perfect.
`civ_elder` renders at **1.550 m**, precisely as `UNIT_HEIGHT_M` specifies. The 2.950 m is the
**bind-pose AABB** — and `gib_k` ≈ 0.53 gives 1.550 / 0.53 = 2.92. The arithmetic closes.

`test_model_scale` has **two independent defects**, both pre-existing:

1. **It measures `mi.get_aabb()`** — the bind-pose box, including all 23 hidden gib donors. `ModelActor`'s
   own comment at line 673 calls this exact measurement *"the speck-soldier bug (n2ij / ADR-002)"* and
   line 126 says the exports *"bake [it] ~2x larger"*. **The test carries the precise bug the code fixed.**
2. **Line 46: `var target: float = ModelActor.TARGET_HEIGHT_M`** — it compares *every* unit to 1.7132,
   ignoring `ModelActor.target_height(unit)`. It demands a 9-year-old `civ_kid` be 1.71 m tall. **It is
   fighting the `UNIT_HEIGHT_M` table that exists to prevent grunt-sized kids.**

**Consequences, and they are worse than a red test:**
- **`civ_elder` is NOT a 72% violation of ADR-002.** It is at 1.550 m, exactly on spec. The briefing's
  framing — and bead `n2ij` — are chasing a ghost. **Do not "fix" the art.** Touching those rigs to chase
  2.950 m would *introduce* the very bug the test claims to guard.
- **ADR-002 has no working guard.** Because it measures a bind box that is ~2x off and unit-independent,
  `test_model_scale` would not reliably catch a real scale regression. The contract is unenforced.
- **Fix: 2 lines.** Assert against `ModelActor.target_height(unit)`, and measure the **skeleton rest span**
  (the ruler `ModelActor` itself trusts), not the AABB. My probe already implements both.

---

## 4. THE x1bs CONTRACT

### What the code actually does
`ModelActor._apply_gib_rig_contract()` (line 296) hides meshes by a **name blacklist**:
`grunt_*`, `head_frag_*`, `cap_*`. Everything else renders. Probe of the live `us_grunt_v3` GLB:

```
VISIBLE (21):
  SKINNED us_grunt_joined            <- the body (correct)
  rigid   m16_world                  <- weapon (correct)
  rigid   helmet_shell_worn          }
  rigid   bandolier_worn             }  v3 bone-parented gear (correct)
  rigid   ruck_pack_worn             }
  rigid   pouch_belt_worn            }
  rigid   helmet_camo_shell   <-- SECOND HELMET
  rigid   helmet_bugjuice
  rigid   bandolier           <-- SECOND BANDOLIER
  rigid   bando_mag0/1/2
  rigid   ruck_bag, ruck_crossbar, ruck_rail_l, ruck_rail_r   <-- SECOND RUCK
  rigid   canteen_l_002 .. canteen_l_006   <-- FIVE CANTEENS
HIDDEN (23): grunt_*, cap_*, head_frag_*
```

### Three corrections to the bead
1. **The duplicates are NOT gib donors.** *All* gear — both sets — is **rigid / bone-parented** (`skin == null`).
   `us_grunt_v3` = `us_grunt_v2`'s mesh list **+ 4 new `_worn` meshes, with nothing deleted.** The v3 export
   *added* the bone-parented gear (commit `2f2aab9`, "the helmet and the ruck leave the hurtbox") and never
   removed the v2 gear it replaced. This is a **stale-export bug**, not a donor-hiding bug.
2. **`helmet_camo_shell` is load-bearing.** `GibSystem.REGIONS["HEAD"]["gear"] = ["helmet_camo_shell",
   "helmet_bugjuice"]` — it is the flying helmet money shot. **Deleting it in Blender without retargeting
   GibSystem silently kills the head-pop helmet.** Anyone "just cleaning up duplicates" will do exactly this.
3. **Five stacked canteens** (`canteen_l_002…006` — Blender `.00N` duplicate-suffix artifacts) are in **v2 as
   well as v3**. Not in the bead. Z-fighting on every grunt's hip since v2.

### Is the fix CODE or ART? **Both — and the code fix must land first.**
**Verified safe:** `GibSystem` spawns gore from `gm.mesh` + `gm.global_transform` and never re-shows the node
(`gib_system.gd:129-134`). It reads a **hidden** MeshInstance3D perfectly well — that is already how the 23
`grunt_*` donors work. **Therefore hiding the duplicate gear in code does NOT break the money shot.** The
helmet still flies. This is why the code fix is safe to ship today, alone, with zero art dependency.

### THE CONTRACT I WOULD BET THE PROJECT ON: **a fail-closed name WHITELIST by suffix**

> **In a contract rig, a mesh renders ONLY if its name ends in `_joined`, `_worn`, or `_world`.
> Everything else is hidden.**
>
> - `<unit>_joined` — the one skinned body. Exactly one.
> - `*_worn` — live rigid gear, bone-parented (`helmet_shell_worn`, `ruck_pack_worn`, `bandolier_worn`,
>   `pouch_belt_worn`, `canteen_worn`, `hat_conical_worn`, `rice_hat_worn`…). **One mesh per item. No `.00N`.**
> - `*_world` — the weapon in hand (`m16_world`, `ak47_world`).
> - Gib donors keep `grunt_<region>` / `cap_<region>` / `head_frag_NN` — **and need no code entry ever again.**
> - **No separate gear-donor meshes.** Rigid gear IS its own gib; retarget `GibSystem.REGIONS[*]["gear"]`
>   to the `_worn` names and delete the duplicates from the export.

**Why a whitelist and not a `gib_` blacklist — the load-bearing argument:**
A blacklist is **fail-OPEN**: anything the code does not recognize *renders*. **x1bs IS the blacklist
failing** — art added a gear category, the code's hide-list didn't know about it, and it double-rendered
for weeks without anyone noticing, because z-fighting is *subtle*. Every future donor category is another
silent double-render. A whitelist is **fail-CLOSED**: an unrecognized mesh *disappears* — loud, obvious,
caught in one playtest. **For a bug class that has already shipped and gone unnoticed, fail-closed is the
only defensible bet.** It also means the code never needs editing again when art adds a donor.

**Why the other three lose:**
- **`gib_` prefix on every donor** — still a blacklist (fail-open, same bug class). Also **more** art work:
  rename 23 donors × N rigs, versus renaming a handful of live gear meshes.
- **glTF `extras` / Blender custom properties** — **UNVERIFIED in this pipeline.** My probe dumped
  `get_meta_list()` on every mesh of every rig: **`meta=[]`, universally.** There is zero evidence
  `extras` survive Blender → glTF → Godot 4.7 here, and the project's own hard rule is *never guess in
  Blender — measure*. I will not bet the grunt remake on an unproven channel. (It *may* work; it needs a
  20-minute round-trip proof first. It is not ready to be a contract today.)
- **Dedicated Blender collection** — glTF has **no collection concept**. The exporter can only emit
  collections as extra empty parent nodes, which **perturbs the node hierarchy** — and `ModelActor:176-212`
  depends on an exact `PSXRig/Skeleton3D` path for the shared animation library to resolve. Breaking that
  path **T-poses the entire roster**. This option can silently destroy the anim system. Hard no.

**The winner rests on the one channel with 100% proof in THIS pipeline:** mesh **names** survive glTF
intact (my probe read `grunt_*`, `cap_*`, `_worn`, `_joined`, `_world` straight out of the imported GLB).
Blender viewport-hide provably does **not** survive. Names are the only reliable wire we have.

### Ship it in two steps (the whitelist cannot go in cold)
**Today (code only, zero art dependency — fixes the shipping P1):**
> On a rig that carries **any** `*_worn` mesh (= "this rig speaks the v3 contract"), hide every **rigid**
> (`skin == null`) mesh whose name does not end in `_worn` or `_world`. Leave the skinned `_joined` body
> alone. Keep the existing `grunt_*`/`cap_*`/`head_frag_*` rule for donors.

This is scoped by opt-in: `us_grunt_v3` is fixed; `us_grunt_v2`, VC and civilians (which have **no** `_worn`
mesh) are untouched and cannot regress. Gore still works (proven above).
**Named cost:** `helmet_bugjuice` has no `_worn` twin and would be hidden — the grunt loses his bug-juice
bottle until Caleb renames it `helmet_bugjuice_worn` in the remake **he is doing right now**. One small prop
detail, for one day, to kill the double-helmet. Worth it.

**When the remade grunts + a VC/civilian re-export land:** flip to the full whitelist and delete the
blacklist entirely.
**Named cost of the flip:** it **cannot ship before every rig is re-exported to the contract.** `vc_guerilla`
has a live `rice_hat`; `civ_kid_b` has `rice_bundle`; v2 has `bandolier`/`ruck_*`/`canteen_*` — none carry a
suffix. Flipping the whitelist today would trade a double-helmet for a **naked army**. Discipline required.

---

## 5. WHAT I AM SACRIFICING

- **Recommending fail-closed means art loses naming freedom.** Every live mesh MUST carry `_worn`/`_world`/
  `_joined`. A typo makes gear *vanish*. I accept that: an invisible helmet is caught in one playtest; a
  z-fighting helmet shipped for weeks. I trade a loud failure for a quiet one **on purpose**. Mitigation:
  `ModelActor` should `print()` the hidden list at load, so a typo names itself in the log.
- **I am telling Caleb his gib-donor art contract was never the problem, and that some of the art work
  implied by bead `x1bs` is wasted motion.** The bead's premise ("gear gib-donors render on top of live
  gear") is wrong: they are stale v2 gear, all rigid. If he is mid-surgery deleting "donors", he may delete
  `helmet_camo_shell` and silently kill the head-pop helmet. **That warning has to reach him before he
  saves.** I am spending his trust in the bead to buy a correct model.
- **I did not run the parent commit's suite.** Checking out `615ddd0^` would have required touching a working
  tree with **modified, unsaved `.blend` surgery** in it. The law says do not tell him to throw work away
  without paying for it; I extended that to *do not risk it*. I substituted structural evidence (pure-rename
  `Bin` diff, path-only test diff, no gameplay files touched, green asset probes) — strong, but *inferential*
  where a worktree run would have been *direct*. If the Arbiter wants certainty, `git worktree add` at
  `615ddd0^` is non-destructive and costs one disk-heavy checkout.
- **I left `tools/probe_drift_scale.gd` in the tree.** One new file, matching the project's `probe_*.gd`
  convention. It is the ADR-015 evidence for §3 and §4 and is re-runnable. Delete it if the Arbiter judges
  the tree should not grow during a drift council.
- **I did not audit the 4 LEAK tests or the "Lambda capture freed" bug.** They are real and they are not
  drift; I ruled them out of scope and left them for a bead. Someone must still pay for them.

---

## 6. THE SHORT LIST (ordered by what kills the project soonest)

1. **RESTORE `us_grunt_v2.blend` FROM HISTORY *BEFORE* ANYONE TOUCHES `.gitignore`.** The naive P0 fix
   untracks an unregenerable 117 MB truth source. This is the single most dangerous thing in the tree.
2. **Repoint every exporter off `art_source/`** — the grunt/gear/anim-library pipeline is dead, and Caleb
   is standing in it right now. Regenerate the locker (`make_gear_library.py`) once v2 is back.
3. **Ship the x1bs code fix** (fail-closed rigid-gear rule). Zero art dependency, gore-safe, verified.
4. **Hand Caleb the suffix contract** before he saves the remade grunts. Warn him: **do not delete
   `helmet_camo_shell` without retargeting `GibSystem`.**
5. **Fix `test_model_scale` (2 lines) and close `n2ij` as a phantom.** ADR-002 currently has no working guard.
6. **Fix `patches.json:7-9` AND `make_jungle_patches.py:978-980`** — both halves, the `.json` is free.
7. **Delete the 3 sprite tests** (ADR-001 killed the renderer) and **populate `$KnownRed`** — 10 reds with an
   empty known-red list means the scoreboard is lying.
