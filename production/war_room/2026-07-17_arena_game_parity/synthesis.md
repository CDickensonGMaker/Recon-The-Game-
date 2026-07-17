# DECREE — ARENA→GAME PARITY, DESTRUCTIBLE TREES, FPS BUDGET

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Sight:** three code-reading recon lenses (arena
wiring / game wiring / veg+damage+perf), each read the code not the plan. Baseline: headless boot clean
(0 SCRIPT ERROR).

---

## THE FINDING THAT REFRAMES THE MISSION

**The mission's premise — "the real game does NOT have the arena's AI stack + 3D veg" — is FALSE, and
the code says so plainly.** This is not a dodge; it is the most valuable thing this council produces,
because it saves a day of building things that already exist.

| "Arena advance" | Reality in the real game | Evidence |
|---|---|---|
| AI directors (Camp/Patrol/Ambush) | **Already wired in the game. The arena does NOT use them.** | `mission_generator.gd:723-774 _attach_camp_directors`; arena grep = zero |
| world_sim / sim_clock | **Already wired** (`_wire_systems` registers every enemy for region LOD, resets SimClock) | `mission_generator.gd:650-705` |
| Crouch / low-posture / cover-to-cover / suppression / concealment read | **Shared `enemy_base.gd`/`ally_base.gd` — same class in both** | `enemy_base.gd:370,491,1643,1713,811` |
| 3D jungle (JunglePatchLayer) | **Loads in real missions** (`use_jungle_patches=true`, chunk-streamed) | `vegetation_manager.gd:39,107,735` |
| BT AI | Drives **civilians**, not combat, in *both* — enemies are FSM by design | `civilian.gd build_bt`, `mission_generator.gd:400` |

**What the game GENUINELY lacks vs the arena is small, and only one item is a real defect:**

1. **CONCEALMENT DIVERGENCE — the real parity gap, Pillar-1 critical (the only true bug).**
   Two separate classifiers decide the jungle, and they do not share code:
   - `GameplayGrid._determine_terrain_type()` (deterministic, no RNG) → `vegetation_density` →
     `enemy_base._sight_cap()` (140m open → 45m dense). **This is what the AI can see through.**
   - `VegetationManager._determine_terrain_type(..., rng, ...)` (**RNG-driven**, `vegetation_manager.gd:304`)
     → which patch GLBs instance. **This is what the player sees.**
   Same world cell, two verdicts. The AI can glass a player standing in visibly-heavy canopy, or a
   unit can "hide" on visibly-open ground. The arena hides this by hand-stamping density to a uniform
   HEAVY canopy (`ai_stress_arena._stamp_veg_*`); the game has no such reconciliation. `gameplay_grid.gd:155`
   already confesses it: *"Four tables must agree or the jungle lies."* **They don't agree.** This is
   THE_PLAN Step 9 ("ONE CLASSIFIER"). It is a day of worldgen work touching ADR-010 determinism and the
   unratified ADR-027 re-order — **decree-level, not a routine autonomous fix.**

2. **Uniform dense canopy** — arena forces all-HEAVY; game uses mixed patch-noise per AO. **This is NOT
   a bug to "fix":** the 40/60 inhabited/empty-war archetype (ADR-027, `5r4y`) makes a mixed, mostly-not-
   uniform map *canon*. Making the game as uniformly dense as the arena would VIOLATE the archetype.
   A FORK, not a defect.

3. **`SquadLeader` fossil (`scripts/enemies/squad_leader.gd`)** — `preload`ed at `mission_generator.gd:14`,
   **never instantiated anywhere** (grep-confirmed, both game and arena). Formation logic lives in
   `EnemySquad.formation_positions()` instead. A textbook ADR-023 fossil — BUT it is *this branch's*
   recent, unpushed built-ahead-of-wiring work (`j3ke` triage verdict: CUT NOTHING without the owner's
   call). **Deletion is Caleb's call, not mine.**

4. Arena-only ruin/clutter *dressing* — a presentation choice, not a system gap.

---

## DESTRUCTIBLE TREES — THE FORK. DO NOT BUILD TODAY. (named plainly, no free lunch)

The headline request collides head-on with measured reality and two standing decrees:

- **Architecturally blocked.** A tree is not an object. Each 12m patch bakes to ONE merged mesh,
  MultiMesh-instanced ~40×/chunk, **twice** (near+far LOD). Zero collision on production veg. You cannot
  delete a tree's triangles without deleting every copy in the chunk. (`jungle_patch_layer.gd:1-2,422-443`)
- **Already CUT by a prior full council** (`synthesis_destructible_jungle.md`): destructible trees, the
  fall, and player-made LZ are feature epics behind red P0 gate `97u3`. *"Cover is the pillar; destruction
  is the luxury."* Bead `eaqv`: *"ship the COVER, defer the DESTRUCTION."*
- **We are in FEATURE FREEZE by the Summoner's own pre-committed ladder.** Measured: 18.8 fps native
  Forward+, 25.5 native Mobile, 29.9 Mobile shipped. **Nothing clears 30 in the night arena, and the
  jungle is already 71% of the frame's geometry.** THE_PLAN's ladder: *20–29 native → JUNGLE FEATURE
  FREEZE, all jungle work subtractive.* Even the trunk-collider *prerequisite* (`eaqv`/`2v3t`) is
  measured "not yet."
- **The data contract is half-built and wrong on disk.** `patches.json` authored 44 destructible trees;
  ZERO consuming code; the `COLOR.b` slot bit is off-by-one vs the plan. Following the doc literally fells
  the *neighbouring* tree. (`en75`, `synthesis_destructible_jungle.md:143-145`)

**The only FPS-honest path, when it thaws:** promote the existing `felled_tree.glb` into a per-subcell
MultiMesh so a tree is one instance — the one approach where a dead tree's triangles *leave* the GPU
(reducing the 71%), instead of the shader-bitmask collapse that keeps them forever. But that is Phase 2
of a frozen epic. **Building destructible trees today spends frame budget we do not have, on the system
already eating the frame, against two standing cuts. That decision is above this council — it is a
Summoner bless (see FORKS).**

---

## FPS — MEASURE-FIRST, AND THE TWO REAL LEVERS ARE BOTH YOUR ADR CALLS

- The two biggest measured wins touch nothing in vegetation: **sun shadow off (−12.17ms)** and **Mobile
  renderer (+36%, halves draw calls)**. Everything else (lights/characters/grass) was **withdrawn as
  inside the noise floor** — the "cheap GPU wins / lights next +8.6fps" line from prior memory is NOT
  established; do not act on it.
- Both levers are ADR-026 decisions reserved to the Summoner: the sun shadow is *deliberately granted*
  by the ADR-026 draft (the one allowed dynamic shadow); Mobile risks silently dropping the >8th
  omni/spot per mesh — **a dropped muzzle flash is a Fairness-Law breach (Pillar 1), not atmosphere.**
- **The perf probe cannot run today without windowing Godot on Caleb's desktop** (`ps2_perf_probe` reads
  GPU-ms=0 headless). Honoring "no windowed Godot," fresh perf numbers are blocked until Caleb runs a
  bench. The 2026-07-16/17 numbers stand as the number of record.

---

## THE DECREE

1. **PARITY IS ~90% ALREADY SHIPPED.** Do not port the AI directors or 3D veg — the game has them. The
   single real parity defect is the **classifier divergence** (concealment). Ship a **verification probe**
   that pins it (evidence, GATE-exempt), and bead the unification as the fix (decree-level, ADR-027-gated).
2. **DESTRUCTIBLE TREES STAY CUT** until an FPS number clears the ladder. Surfaced to the Summoner as a
   fork; not built. Trunk colliders (cover) remain the first shippable step and are themselves "not yet."
3. **FPS is measure-first and blocked on a windowed bench + two ADR-026 calls** that are the Summoner's.
4. **No push** (Summoner's standing instruction this session). Backups untouched.

## WHAT IS SACRIFICED
- The satisfying "port the arena into the game" day — because the code says it is already there. We trade
  motion for truth.
- The headline destructible-tree feature — deferred, because the frame cannot pay for it and two councils
  already cut it. Cover before destruction.
- A same-day FPS win — because the honest levers are the Summoner's ADR calls and the probe needs a window.

## FORKS FOR THE SUMMONER (do not guess — bless required)
- **F1 — Classifier unification (the real parity fix).** Unify the two `_determine_terrain_type` into one
  source so the AI's sight-cap matches the visible jungle. A day; changes worldgen determinism; entangled
  with ADR-027. Ratify the approach before build.
- **F2 — Destructible trees.** Override the FEATURE FREEZE + the two standing cuts, or hold. If override:
  fund it first (sun-shadow/Mobile FPS), then trunk colliders, then felled-tree-MultiMesh. Your call.
- **F3 — FPS levers (ADR-026).** Sun shadow in the shipped night world? Mobile renderer (test the muzzle
  flash first — Fairness Law)? Both are yours.
- **F4 — Delete `SquadLeader`?** Genuine fossil, but your recent unpushed work. Cut or wire.
