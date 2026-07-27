# WAR ROOM BRIEFING — Whole-Game FPS Deep Dive
**Convened:** 2026-07-26 · **Summoner query:** *"I want to deep dive overall in the game how to increase the fps."*
**Arbiter:** recon-overseer (Director)

This session supersedes the 2026-07-20 stand-down (`production/PERF_LEDGER.md:884`, "don't keep worrying
about the fps that'll be final polish we'll do in a few weeks"). The Summoner is opening that polish pass now.

---

## 1. Ground truth already established (from `production/PERF_LEDGER.md` — the honest record)

Do NOT re-derive these. VERIFY if you doubt them, and say so in your analysis if they have changed.

- **Shipped baseline ~34 FPS.** seed 47225, `scaling_3d/scale = 0.75`, forward_plus, Intel UHD,
  Godot 4.7.stable, stationary at `fsb_main` spawn. (`PERF_LEDGER.md:679, :698`)
- **THERE IS NO NUMERIC FPS GATE** (`:6`). His eyes decide. Do not invent one; do not report pass/fail.
- **CANOPY is the only lever measured above noise**, at three seeds/configs: **+6.3 / +7.8 / +8.0 FPS**
  against noise floors of 1.4 / 1.1 / 2.8 (`:875-878`). It is **call-bound**: drops ~1,200 of ~1,400
  draw calls while moving prims only ~12%.
- **The canopy mechanism is PINNED** (`:882-943`): MultiMesh already used correctly, materials already
  shared, no per-plant MeshInstance3D. The call count IS the node count.
  `terrain/vegetation/tree_cover_layer.gd:110` keys groups as `[species, bucket_x, bucket_z]`,
  `BUCKET = 64.0` (`:52`), and `:132` / `:135` emit TWO nodes per group (near solid + far card).
  **(Pointer correction, verified 2026-07-26: `PERF_LEDGER.md:909-911` cites `:94 / :47 / :115 / :118`
  and `:199` for `_extract_mesh` — ALL STALE. Live values are `:110 / :52 / :132 / :135` and `:323`.)**
  14,080 MMI nodes live; ~957–1,017 far cards survive culling and draw.
  Far-card ring ≈ (94 buckets in 350m) × (~17.6 species per bucket). The NEAR ring costs ~0.
- **Two named factors, both with named costs:**
  1. Raise `BUCKET` — ~2.5x call cut at 128, but it is a **LOOK change**. `tree_cover_layer.gd:48-51`
     records that `visibility_range` is evaluated per-NODE against the transformed AABB (godot#79471 —
     the docs say origin and are wrong), so coarser buckets quantise the 65m near/far handoff by ±90m:
     either double-rendered cards or a jungle gap (the historical invisible-jungle bug).
  2. **Atlas the 27 card materials** so a whole bucket is ONE MultiMesh ≈ 94 calls instead of ~1,000 —
     the real ~10x win. **Blocker:** the 27 card textures are NOT atlased (each its own PNG + own
     StandardMaterial3D), and the card bake tool is NOT in the repo. Atlasing means writing the bake
     pipeline, a unit-quad mesh with per-instance UV-rect custom data, a shader to read it, and
     re-deriving each card's aspect into the instance transform.
- **Sun shadow is NOT a lever.** Ship runs `shadow_enabled = false` (`scripts/levels/game_world.gd:52`;
  `:48` is the `DirectionalLight3D.new()` line — pointer corrected 2026-07-26).
  The +10.9 / +10.5 / +9.8 / −12.17ms "wins" were a bench artifact **measured and believed twice in two
  harnesses**, then retracted (`:393, :626, :653`). At ship parity it reads **−0.2, inside noise**.
  Guarded by `tests/test_ship_parity.tscn`. If shadows were ever turned ON they cost ~10.5 FPS and the
  near-field cap is NOT a mitigation (40m / 80m / uncapped identical within 0.5).
- **Campfires bank 0.0** at seed 47225 (DAY, zero campfires); unmeasurable even at seed 12 night with
  4 fires (`:846-861`). ADR-026 Part A #1 is a CANON win, not a perf win.
- **Clutter / grass: inside noise** every time.
- **CPU IS NOT FREE.** Arena at native: CPU 44.35ms vs GPU 51.94ms — near balanced, so a pure fill fix
  cannot get past ~19→23 alone (`:200-201`). At 65+ live units the AI physics wall is ~38–40ms/tick and
  **perception rays + think are only ~6% of it** (`:296-304`) — the wall is the BODY: hitzone sync ~10ms
  + `move_and_slide` ~9ms + execute/anim remainder ~18ms. The WA-A2 body gate shipped but its payoff
  class (stationary RELAXED unperceivable men) is only ~9.4% of population at hub start (`:353-367`).
- **Renderer:** Mobile measured +36–40% but **Forward+ is DECREED** (ADR-026 Amendment A, ratified
  2026-07-17). Claw FPS back WITHIN Forward+. The renderer is CLOSED unless decisive new evidence
  appears — and if it does, it is a Summoner question, never an assumption.
- **Measurement contract binds:** a number without its scale, renderer and seed is not a number.
  Headless instantiates RendererDummy and every GPU figure it reports is **FICTION**. A/B/A or nothing —
  single-pass A/B on this hardware is inside the noise floor.

## 2. What has likely changed since the ledger's last row (2026-07-20) — VERIFY, DO NOT ASSUME

Six days of art work landed. At minimum verify against code and assets:

1. **Impostor foliage** — ~40 leafy species + barbwire converted to alpha-card impostors (claimed 98.7%
   tri cut). Does this change the far-card ring, the species-per-bucket count, or the atlas blocker?
   **Is the card bake tool NOW in the repo?**
2. **Temple set** (`tools/gen_temples.py`, five Indochina families; box trees deleted for real jungle
   meshes) and **village set** (`tools/gen_village.py`, 26 generated enterable buildings replacing the
   RTS boxes) — new resident mesh / draw-call load in the AO.
3. **Firebase kit** — 23 assets, **9 fixed material slots on EVERY asset** (`tools/gen_firebase.py:61-77`),
   so one placed asset can cost up to 9 draw calls. `production/firebase_kit_phase1_read.md:261-263`
   asserts collapsing 9 → 5 atlas families is "the real performance lever".
   **THAT ASSERTION IS UNMEASURED — either measure it or label it unproven.**
4. Anything else that grew the frame: `fsb_main` was already 678 meshes / 1,116 bodies + 4 villages +
   3 camps resident (`PERF_LEDGER.md:263-264`).

## 3. What the council must produce

1. **A current draw-call and primitive CENSUS of the shipped patrol world**, attributed by subsystem —
   canopy far-cards vs firebase kit vs village/temple buildings vs characters vs terrain vs water.
   The ledger's attribution is six days stale and predates three asset waves. **Where you cannot measure
   without a windowed run, SAY SO** and put the question in the measurement batch rather than estimating.
2. **The atlas question, settled or explicitly labelled unproven** — both the canopy 27-card atlas
   (~10x call win, needs a new far-card renderer path) and the firebase 9→5 material collapse.
   Cost each in real work. Do not let the firebase claim stand as fact on assertion alone.
3. **The CPU half, which every prior pass under-served.** GPU levers cannot get the frame past ~23 in the
   arena on their own. What is the honest CPU plan — hitzone sync, `move_and_slide`, the anim/execute
   remainder, resident population tiering (DORMANT / AGGREGATE tiers, ADR-025)? Rank by measured ms.
4. **Cheap wins nobody has taken** — no look cost, no new system. Name each with a `file:line` pointer.
5. **What is NOT worth doing**, with the evidence that kills it, so this ledger stops re-litigating
   shadows and campfires.
6. **A MEASUREMENT BATCH the Summoner can run himself in one windowed sitting** — exact commands, exact
   phases, A/B/A bracketed, each with the question it answers. He runs windowed benches; agents cannot.
   Keep it short enough to actually get run.

## 4. Binding constraints (the Arbiter enforces these above any FPS number)

- **RULE #1 outranks every FPS number**: the world must be FUN to walk and FEEL like Vietnam, and he
  judges the LOOK by his EYES, not by engine counters. Any lever that costs the look must be **named as
  such and ranked BELOW look-free levers**, even if it is bigger. The `BUCKET` bump is exactly this case.
- **Forward+ is decreed.** Do not propose a renderer swap as a plan item.
- **Tri budgets are style, not perf** — measured: cutting 33% of prims and 77 draw calls moved FPS ~0.
  Do not propose triangle-shaving as an FPS fix.
- **The world foundation is PROTECTED** — improve it, never rebuild or re-fragment it.
- **POINTER LAW**: every assertion about code state cites `file:line` or names the probe. An assertion
  with no pointer is an opinion and must be labelled one.
- **NO DRIFT**: if you find a claim in a doc that is no longer true, correct it in the same change.
- **FOSSIL LAW**: if a lever means replacing a system, the predecessor gets deleted in the same change.
- Do NOT run windowed Godot on his desktop unsanctioned. Do NOT quote headless GPU numbers — fiction.
- Do NOT run the test suite; he runs it himself.
- **NO NEW FPS ROW may be written to `PERF_LEDGER.md` without a real windowed measurement.**

## 5. Council summoned

| Architect | Lens |
|---|---|
| technical-director | Frame budget ownership, CPU-vs-GPU split, what actually gates the frame |
| godot-specialist | Engine-level Godot 4.7 levers, MultiMesh/atlas/shader path, renderer internals |
| technical-artist | Asset-side census: firebase kit, village, temple, impostor cards, materials |
| gameplay-programmer | The CPU half: hitzone sync, move_and_slide, anim, AI tiering, population |
| devils-advocate | Kill the plan; name what every lever sacrifices; hunt unmeasured claims |
| measurement-engineer | Design the windowed batch the Summoner can actually run in one sitting |

Knowledge to load: `~/.claude/architect_knowledge/GodotPrompter/skills/godot-optimization/`,
`~/.claude/architect_knowledge/godot_4.7_features.md`, `~/.claude/architect_knowledge/godot_standards.md`.
