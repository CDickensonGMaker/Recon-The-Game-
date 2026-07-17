# Devil's Advocate — Grunt Viewer (bead bdn3)

**Read:** `scripts/visuals/grunt_dresser.gd`, `scripts/visuals/model_actor.gd`, bead eq6n, bead bdn3,
`tests/test_fossils.gd` + `tests/fossil_baseline.json`, ADR-015, OVERSEER_CHARTER §8, the helmet GLBs
on disk, and the working tree. **The code, not the plan.**

## 0. The plan is already half-built — analyze THAT, not the pitch

`git status` shows untracked: `scenes/tools/grunt_viewer.tscn`, `scripts/tools/grunt_viewer.gd`,
`scripts/tools/grunt_randomizer.gd`, `grunt_viewer.bat` (root, matching `hitzone_editor.bat`
convention). The probe half of bdn3 — `tests/test_grunt_dresser` — does **not** exist yet.
So this council is not blessing a blueprint; it is reviewing an in-flight build. Judge the files.

Verdict on the as-built code: it is honest in the three places I expected it to cheat (fresh actor
per randomize, no Base_Human band-aid, radio legality delegated to the dresser's own law). The traps
below are in what it *leans on* and what it *leaves unsaid*.

## 1. Zero call sites: the viewer will CURE the fossil without curing the game

Grep confirms: **nothing in the game calls `GruntDresser.dress()`.** The only non-comment references
outside `grunt_dresser.gd` are the new untracked tool files. Every squad the game spawns today is a
clone platoon — same face, same helmet, radios handled only by `_apply_optional_gear`'s blacklist.

Here is the trap nobody named: `test_fossils.gd` REF_DIRS = `res://scripts`, `res://scenes`,
`res://tests`, `res://tools`... The viewer lives in `scripts/tools/` and the probe in `tests/`.
**The moment this tool lands, `dress` gains reference counts and is permanently invisible to the
fossil probe — while the game still never dresses a grunt.** A dev bench becomes the sole consumer
of a player-facing variety system. That is ADR-023's "UNFINISHED" category wearing a green test as
camouflage. The 2026-07-14 war room already decreed "Phase 2 (bead) = GruntDresser variety once the
probe is green" — **no such bead exists** (`bd list` shows bdn3 only; nothing for
`AllyBase._setup_visual` / spawn-path wiring).

**DEMAND: the game-wiring bead (dress() in the real spawn path, seeded per squad member) is created
in THE RECORD, dep-linked after bdn3, before this session closes.** Without it the viewer is a
mirror in a room the player never enters, and the fossil law has been structurally defeated.

## 2. Base_Human: show the corpse. The viewer must not lie.

eq6n is OPEN. All six role GLBs ship a second 402-tri skinned body that nothing hides. The viewer
**will** render two interpenetrating men, every spawn.

The as-built viewer does the right thing: **nothing** — no local hide, no name-list. Keep it that
way. Three reasons:

1. **A bench that hides defects is a lying instrument** — the exact "blind green" ADR-015 §Context
   was written against. The viewer's highest value *today* is that it is the cheapest reproduction
   and, later, the cheapest verification of eq6n's fix.
2. `scripts/visuals/` is **owned by the other window** (eq6n note, restated in bdn3 and in
   grunt_randomizer.gd's own header). A viewer-side hide would fork the hide-contract decision that
   window is about to make.
3. That decision is genuinely contested: eq6n prescribes a fail-closed whitelist, while
   `AI_STRESS_ARENA_HANDOFF.md:119` says "Base_Human is the secondary gib body — IT STAYS" (hidden
   on the live man). The viewer must not vote by hiding.

**FORBID: any `Base_Human` handling in viewer/randomizer/probe beyond, at most, a printed count of
visible skinned bodies (evidence, not concealment).** And the probe must NOT assert "exactly one
body renders" today — that asserts eq6n fixed, which is the other window's close, not ours.

## 3. Invented dimensions: "uniform variants" do not exist. Helmets do — all 15.

Verified on disk and in code:
- **Faces:** 70 real cells (10×7 atlas, one `grunt_face_skin` offset). Real.
- **Helmets:** all 15 `HELMETS` entries exist as GLBs in `assets/us/props/helmets/` (checked by
  listing; names match the const 15/15). Real.
- **Gear:** `ruck` and `radio` toggles only. Real, mesh-gated.
- **Uniforms:** **NOTHING.** No uniform meshes, no dresser dimension, no material variant. Grep for
  `uniform` in scripts hits shaders and RNG comments only.

The as-built randomizer randomizes exactly face × helmet × ruck × radio. **FORBID any UI element,
loadout line, probe assertion, or bead text that mentions uniform/fatigue/camo variants.** If the
Summoner wants uniform variety, that is new art and a new dresser dimension — a separate bead, not
a dropdown that lies.

## 4. dress() is NOT re-entrant — confirmed from code; respawn is mandatory

`_swap_helmet` (grunt_dresser.gd:154-161) constructs a **new** `BoneAttachment3D` named
`HelmetSocket` + a new helmet instance on **every** call. Nothing removes prior sockets. Second
`dress()` on the same actor = stacked helmets; `helmet:false` after `helmet:true` hides only the
STOCK shell and leaves every hung variant. Worse than cosmetic: `GibSystem` locates **the**
`HELMET_SOCKET` by name to throw the worn helmet — duplicates corrupt the gib contract.

The as-built viewer `_randomize()` does `queue_free()` + fresh `ModelActor` + one `dress()`.
**Correct. Lock it in:** the probe must assert **exactly one** node named `HelmetSocket` after a
single dress on a fresh actor, and the viewer must never re-dress a live actor. Do NOT "fix"
re-entrancy in the dresser — not ours to edit. Note it on eq6n's owner instead.

## 5. GATE / scope: exempt, narrowly — and name the price

bdn3 is a task, not a feature epic, and was never dep-linked to 97u3. Honest reading of ADR-015's
exemptions: **"presentation for already-shipped systems" does NOT cover this** — GruntDresser is
unshipped (zero call sites; that is the whole point of §1). The claim that holds is
**"evidence-gathering probes/measurements"**: the bench is the reproduction instrument for eq6n
(open P1) and `test_grunt_dresser` is a pre-wiring probe, in the `patrol_lab`/`gun_range`/
`hitzone_editor` bench lineage. Exempt — as an instrument, not as a feature.

**What is sacrificed (the law demands it be spoken):** a session of attention while P0s sit open
(5i8a determinism GATE, clm4) and while eq6n — the bug this viewer will stare at all day — remains
unfixed in someone else's window. Player-visible payoff of this session: **zero.** The payoff only
exists if the §1 wiring bead is created and honored. A viewer without the wiring bead is spending
GATE-exempt hours to decorate a fossil.

## 6. Other landmines found in the code

- **(a) Silent bareheaded failure, fail-open ordering:** `_swap_helmet` sets
  `stock.visible = false` (line 137) **before** checking `ResourceLoader.exists(path)` (line 140).
  A missing/renamed helmet GLB = a bareheaded grunt with only a console warning. All 15 exist
  today; the ordering is still eq6n's disease (fail-open) in miniature. Can't edit — **note it to
  the scripts/visuals owner on eq6n/bdn3.** The probe should at least assert every `HELMETS` entry
  resolves on disk, so a deleted GLB fails the suite instead of undressing a soldier silently.
- **(b) Helmet variants dodge PSX filtering:** `ModelActor._apply_psx_filtering()` runs at
  `setup()`; the helmet instance is added later by `dress()`, and `_set_face` NEAREST-filters only
  the face material. Result: 15 helmet variants render BILINEAR — smeared — in viewer and,
  eventually, game. Consumer-side re-filter in the randomizer is legal (touches no owned file) but
  duplicates owned logic; better beaded to the dresser owner. Either way, name it — the first thing
  the Summoner will see in this viewer is a blurry helmet on a crisp face and he will file it as a
  viewer bug.
- **(c) Stale-transform risk in the probe:** `_swap_helmet` places the variant from
  `stock.global_transform`, and `model_actor.gd:126-131`'s own comment warns "the global transform
  is stale on the session's first build" — the reason `_normalize_height` refuses global
  transforms. The randomizer calls `setup()` then `dress()` in the same frame. Headless, that is
  exactly the first-build case. The probe should `await process_frame` before dress, or assert the
  helmet lands within the head's AABB, or a green probe may bless helmets floating at pre-scale
  height.
- **(d) `_set_face` can silently no-op:** it only touches surfaces whose material
  `resource_name.begins_with("grunt_face_skin")`. A future re-export that renames the material
  makes RANDOMIZE a face no-op with zero warnings. The probe must assert **at least one surface
  override was created** per dress — "all matching surfaces agree" passes vacuously on zero
  matches.
- **(e) Determinism probe is sound as coded** — `spawn()` consumes RNG in fixed order and gates
  optional draws on mesh presence (stable per role). Assert determinism per (seed, role), not
  across roles. Minor: the viewer generates seeds with `randi()` and displays them but offers no
  way to *enter* one — a replay box is the cheap feature that makes the displayed seed worth its
  pixels.
- **(f) The fossil baseline itself is untracked** (`?? tests/fossil_baseline.json`). The ratchet
  that ADR-023 calls "the machine" exists only on this disk. Someone's window must commit it; a
  fossil law whose register can vanish with a `git clean` is the next markdown law.

## Bottom line

Approve as an **instrument** (GATE-exempt as evidence-gathering), with binding conditions:
create the game-wiring bead (§1) or admit the viewer decorates a fossil; show Base_Human raw (§2);
no invented uniform dimension (§3); respawn-per-randomize is law, probe asserts one HelmetSocket
(§4); probe hardened per §6 a/c/d; findings a/b handed to the scripts/visuals owner, not fixed here.
