# DEVIL'S ADVOCATE — Whole-Game FPS Deep Dive, 2026-07-26

**Lens:** kill the plan. Name what every lever sacrifices. Hunt unmeasured claims presented as fact.
**Method:** code and ledger read directly; no windowed run, no suite run, no headless GPU figure quoted.
Every assertion below carries a `file:line`. Where I state a judgement rather than a fact I write
**OPINION** on the line.

---

## 0. THE ONE-PARAGRAPH VERDICT

The canopy win is **real but narrower than the plan believes**. It is not the shadow artifact — I
checked the mechanism and it survives (§1.3). But it is a **one-pose number** measured at the one
place in the world where the near ring is empty (§1.4), and it is **the cost of the whole canopy**,
of which the atlas plan can only ever recover the *call* fraction — **a fraction nobody has measured**
(§1.5). The ambitious plan is therefore a week of one-way-door engineering on the protected world
foundation, sized against an unmeasured fraction of an 8-FPS ceiling. **The BUCKET bump is a trap and
must never ship** (§3). The firebase 9→5 atlas claim is not merely unmeasured — arithmetic from this
ledger's own numbers says it is **below the detectability floor**, i.e. unfalsifiable (§2.1, §5.3).
The honest plan is: fix the instrument, run one 30-minute experiment that prices calls-vs-fill, and
let *that* number decide whether the atlas is ever built (§4.4).

---

## 1. THE HISTORY OF BEING WRONG — what made the harness lie, and does it threaten the canopy?

### 1.1 The failure, stated precisely

Twice, in two harnesses, ten weeks apart, this project measured a ~10-12 unit "win" from disabling the
sun shadow, believed it, published it as the dominant term, and retracted it:

- Harness 1: `ai_stress_arena.gd:390` set `sun.shadow_enabled = true`. Retracted `ADR-026:137-144`,
  recorded at `PERF_LEDGER.md:626-635`.
- Harness 2: `tests/perf_probe.gd:123` read `sun.shadow_enabled = phase_name != "no_sun_shadow"`.
  Retracted at `PERF_LEDGER.md:393-402` and again at `:626-635`.
- Ship truth: `scripts/levels/game_world.gd:48` sets `shadow_enabled = false`.
- At ship parity the lever reads **−0.2 against a 1.4 floor** (`PERF_LEDGER.md:696`), and **+0.6 / +1.0
  inside floors of 1.1 / 2.8** on the two later runs (`:826`, `:844`).

**The mechanism of the lie, generalised:** *the instrument put the world into a state the ship never
renders, then measured its own removal of that state as a saving.* The baseline was not ship.
Formally the defect is not in the lever — it is in the **reference row**. That is exactly what
`tests/test_ship_parity.tscn` now guards (`PERF_LEDGER.md:765-771`, Rule A "no undeclared deviation",
Rule B "the reference row must exist").

**And the aggravating factor, which is the part that matters for today:** it reproduced **three times**
(+10.9 / +10.5 / +9.8, and −12.17ms in the other harness). The ledger's own confession is the sentence
this session must hold onto — `PERF_LEDGER.md:443`:

> **"Three consistent measurements of an artifact are still an artifact."**

Reproducibility measures the *stability of the setup*, not the *validity of the conclusion*. A/B/A
bracketing cannot catch it, because "a bracketed baseline that is uniformly wrong is uniformly wrong"
(`:443`).

There is a second, older instance of the same disease with a different mechanism — worth naming
because it is the one that threatens the canopy, not the shadow one. On 2026-07-16 the ledger
published *"Mobile … 40.9 fps … clears the gate at NATIVE"* (`:119`). Re-measured in a different scene
it read **25.5** (`:154`). The retraction at `:162-164` is precise: **"The +40% direction survives
(+36%); the 'clears the gate' conclusion does not. This is exactly the n=1 problem 5kr3 was filed to
catch."** *The direction generalised. The magnitude did not.*

### 1.2 So there are TWO artifact classes in this ledger's history, not one

| class | mechanism | what defends against it | who caught it |
|---|---|---|---|
| **A — non-ship baseline** | the harness adds a cost the ship does not pay, then refunds it | `tests/test_ship_parity.tscn` (`PERF_LEDGER.md:755-794`) | a ship-parity re-measure |
| **B — n=1 generalisation** | the number is true *where it was taken* and is then applied everywhere | **nothing. There is no guard for this.** | a second scene/pose, by luck |

**Class A is structurally defended. Class B is not defended at all, and class B is what threatens the
canopy finding.**

### 1.3 Is the canopy number class A? — I checked the mechanism. NO.

I tried to convict it and failed. Recording the attempt because the failed convictions matter:

**Suspicion 1 — the phase is a COMPOSITE lever.** `tests/perf_probe.gd:125` sets
`vg.patches_disabled = phase_name == "no_canopy"` *and* `:127-129` hides `TreeCoverLayer`. Two systems,
one number. Jungle patches are not a trivial system — the 2026-07-16 arena measured them at
**−12.26ms / −572,438 prims, the largest GPU item ever recorded here** (`PERF_LEDGER.md:172`,
verdict STANDS at `:232`).

**Refuted.** `terrain/vegetation/vegetation_manager.gd:115-124` builds `TreeCoverLayer` **or**
`JunglePatchLayer`, never both. `scripts/levels/game_world.gd:100-101` selects on
`WorldConfig.USE_TREE_COVER`, and `scripts/levels/world_config.gd:21` reads
`const USE_TREE_COVER: bool = true`. So in the shipped world `_patch_layer` is null, and the
`patches_disabled` read at `vegetation_manager.gd:169` is behind `if _patch_layer != null and
_patch_layer.enabled` — **a complete no-op in ship.** The `no_canopy` delta is `TreeCoverLayer` alone.
Clean.

**Suspicion 2 — the phase secretly removes the near-solid ring too.** It does (`visible=false` on the
parent hides both node families built at `tree_cover_layer.gd:132-135`). But the ledger's live census
says only **1 near node** falls inside its own `visibility_range` at the bench pose against ~1,670 far
(`PERF_LEDGER.md:912-914`), and the measured prim delta is only ~13.7k of ~158k (`:679` vs `:682`).
**Refuted at this pose** — though see §1.4, because *why* the near ring is empty is the whole problem.

**Suspicion 3 — the baseline is not ship.** No. `perf_probe.gd:53-58` captures the world's own shadow
config at `attach()` and `:160-161` restores it on every non-study phase. Guarded by
`tests/test_ship_parity.tscn`. Class A cannot recur here without turning the suite red.

**CONCLUSION: the canopy number is NOT the shadow artifact. The +6.3 / +7.8 / +8.0
(`PERF_LEDGER.md:875-878`) against floors of 1.4 / 1.1 / 2.8 is a real frame-time difference in the
shipped build.** I say so plainly so the council does not over-correct into paralysis. The lesson of
the shadow episode is not "distrust all numbers"; it is "distrust the *conclusion drawn from* a
number."

### 1.4 Is the canopy number class B? — YES, and severely. This is the finding.

**Every canopy measurement this project has ever taken is at ONE camera pose: stationary at the
`fsb_main` spawn**, and the ledger itself flags it — `PERF_LEDGER.md:524`: *"this pose faces the
firebase interior, not a jungle sightline."* Three seeds and two builds do not make three poses. They
make **one pose measured three times** — precisely the shape of the thing `:443` warns about.

And the pose is not merely unrepresentative; it is the **single most canopy-flattering spot in the
world**, and the ledger's own census proves it: **1 near solid node in range** (`:912-914`). One. The
player spawns inside a cleared firebase. There is no near jungle there.

Now read what the code says the frame looks like when he **walks out the wire** — the thing the game
is actually for:

- `terrain/vegetation/tree_cover_layer.gd:38-40`: *"Measured worst 70m-ring demand (seed 47225, whole
  AO, mission density boost applied): **919 candidates**. 1280 = ~40% headroom."*
- Those 919 are `COVER_TRUNK` species only (`:20-28`) — broadleaf, bamboo, banana, palm, deadfall —
  i.e. the **full 3D solid meshes** of the near ring (`:132`), not cards, plus 919 `StaticBody3D`
  colliders (`:235-246`).

So at a jungle pose the frame composition **inverts**: the near ring goes from ~1 node to hundreds of
solid-mesh nodes, the far cards get **occluded by the near solids in front of them**, and the
prim/fill/call mix bears no resemblance to the bench row. **The canopy's cost SHAPE at the place he
plays has never been measured.** It could be larger (more nodes) or the *call* component could be
smaller (occlusion, fewer buckets in the frustum under a closed canopy). **Nobody knows, and the whole
atlas plan is sized on the clearing.**

**This is the same error as "Mobile clears the gate at native" (`:119` → `:162`), one layer up:
the direction (canopy is the biggest single item) will survive; the magnitude and — critically —
the call-vs-fill *attribution* may not.**

**REQUIRED: any measurement batch this session produces MUST include a second pose out in the jungle,
bracketed A/B/A, or the session repeats 2026-07-16.** A pose is a free variable; adding one costs
minutes and it is the only defence class B has.

### 1.5 The third problem, and it kills the plan on its own: **+8.0 is a CEILING nobody can pull**

`no_canopy` is not a lever. **You cannot ship a game with no jungle** — RULE #1 (`briefing.md:94-96`).
What the +8.0 measures is *the entire canopy subsystem's frame cost*: draw-call/state-change overhead
**plus** the alpha-tested fill of ~1,670 cards **plus** ~12% of frame primitives (`:877`).

**The card atlas removes ONLY the call overhead.** Every card still draws. Every alpha-tested pixel is
still shaded. Every primitive is still submitted. So:

> **atlas win = 8.0 × (call-overhead fraction of the canopy's cost)**
>
> **and that fraction has never been measured.**

That single unmeasured fraction is the foundation of the entire ambitious plan, and this ledger holds
evidence pointing the *wrong* way: `PERF_LEDGER.md:98-100` — *"Cutting **99,500 prims (33%) and 77
draw calls moved FPS by ~0.** Geometry/draw-call count is not the jungle's limiter at this pose;
full-screen terrain/water fragment shading + the render pipeline is."* On this exact hardware, on one
occasion, removing calls bought **nothing**.

I do not claim that settles it — 77 calls is small and 1,000 is not, and `:407-408`/`:877` establish
the canopy is call-*correlated*. **OPINION:** but the burden is on whoever proposes a week of pipeline
engineering to show the fraction is large, and right now the fraction is a hope.

**A worked bound, using the ledger's own numbers, to show what is at stake.** If the atlas cuts
~1,000 canopy calls to ~94 (`PERF_LEDGER.md:927-928`) it captures ~91% of the calls but 0% of the fill.

| if call overhead is… | atlas win at the bench pose | verdict against the 2.8 floor (§5) |
|---|---|---|
| 100% of the canopy cost | ~+7.3 FPS | worth a week |
| 50% | ~+3.6 FPS | marginal; barely detectable |
| 25% | ~+1.8 FPS | **you build the pipeline and cannot prove it worked** |

**That is the whole session in one table, and the row we are on is unknown.**

---

## 2. THE UNMEASURED CLAIMS

Swept `production/` and `production/adr/`. Grouped by whether settling them is worth anything.

### 2.1 `firebase_kit_phase1_read.md:261-263` — "the real performance lever". **UNMEASURED, and I can bound it as UNMEASURABLE.**

> *"**The atlas rule is the real performance lever**… Every kit asset carries 9 material slots, so one
> placed asset can cost up to 9 draw calls. Collapsing 9 → 5 atlas families is measured-relevant in a
> way that shaving triangles is not."*

The 9 slots are real: `tools/gen_firebase.py:61-75` defines exactly nine (`fb_sandbag`, `fb_earth`,
`fb_timber`, `fb_psp`, `fb_canvas`, `fb_corrugated`, `fb_crate`, `fb_gunmetal`, `fb_olive`), indexed
fixed at `:76`. The *cost* claim is bare — no firebase draw-call count has ever been taken.

**The bound.** `PERF_LEDGER.md:896-898` measures **total calls 1,368–1,481, calls with canopy hidden
411–464**. That 411–464 is the **entire rest of the frame** — terrain chunks, water, firebase kit,
villages, temples, characters, sky, particles, UI. The firebase kit is one slice of it. The kit's
absolute ceiling, if it were the *whole* non-canopy frame and you deleted *all* of it, is 464 calls.
Collapsing 9→5 removes at most **4/9 ≈ 44%** of the kit's own slots — not the kit.

Priced at the canopy's own measured call-value (~1,000 calls ≈ 8 FPS at this pose, `:875-878`,
`:896-898`) — a ratio that **overstates** pure call removal, because the canopy delta also carried
fill and 12% of prims, so the bound is conservative in the right direction:

- deleting the **entire** non-canopy frame: ≤ ~3.7 FPS
- the firebase kit's plausible share (say 100–200 calls): ~0.8–1.6 FPS
- **the 9→5 collapse captures ≤44% of that: ~0.35–0.7 FPS**

**Against a noise floor of 1.1–2.8 FPS (§5), that is not a small win — it is an unmeasurable one.**
The claim cannot be proven true and cannot be proven false with the instrument that exists.

**What it would take to settle:** a per-subsystem call census at the spawn pose (one diagnostic that
walks the scene tree and sums `MeshInstance3D` surface counts by parent subsystem — cheap, headless,
no GPU figure needed, therefore legitimate). **Is it worth settling? The CENSUS yes — it is cheap and
it retires the claim permanently. The 9→5 REWORK, no.** Do it if and when it makes the kit *easier to
author*, and never write an FPS row for it. **NO DRIFT: `firebase_kit_phase1_read.md:261-263` should
be amended in this session to read "unproven; bounded below the instrument's noise floor."**

### 2.2 `ADR-026:121-123` — "+8.6 fps, the #1 PS2-budget win". **REFUTED BY THE LEDGER AND STILL LIVE IN A RATIFIED ADR.**

`PERF_LEDGER.md:611`, `:855`, `:867-868` measure it at **−0.5 / +0.2 FPS inside floors of 1.1 / 2.8**
and conclude *"ADR-026 Part A #1 is a CANON win, not a perf win."* The ADR still calls it the #1 win.
ADRs outrank CLAUDE.md (`CLAUDE.md`, CANON block) and are injected into every council brief — **this
is a live NO-DRIFT violation in binding law and it is six days old.** Cost to settle: **zero, it is
already settled.** Someone has to type the correction. **Highest value-per-minute item in this
session.**

### 2.3 `ADR-026:120-121` — "baseline 14.0 → 23.1 fps, +65%". **MEASURED ON A CONTAMINATED BENCH, NEVER RE-RUN.**

Taken 2026-07-16 on the arena, under the same class-A defect retracted for every other row of that
date (`PERF_LEDGER.md:397-398`, `:663-670`: *"the published baseline of 23–25 FPS was not the shipped
game's frame rate"*). Propagated verbatim into `OVERSEER_CHARTER.md:94` and `:149` as current truth —
including the conclusion *"the frame is in the AI… not jungle draw cuts"*, which is the exact opposite
of what ship parity later measured (`:875-878`). **Settle by deletion, not re-measurement:** strike
the number, keep the direction, cite the ledger. Cost: minutes.

### 2.4 `ADR-026:28-30` — "≤8 simultaneous real-time lights". **NEVER MEASURED.**

No light-count cost curve exists anywhere. `PERF_LEDGER.md:468-474` is a *census* of spawner sites,
not a cost. **Worth settling? NO.** It is a canon/discipline cap that is already structurally true
(zero non-exempt spawners, `:870-873`) and it costs nothing to keep. Label it a style rule, like the
tri budgets, and stop calling it perf.

### 2.5 `ADR-026:83` — "affordable hot-set ≈ 12 fighters (ceiling 16)". **"Council-sized" = a vote.**

No ms-per-fighter curve. And it is aimed at the wrong thing: `PERF_LEDGER.md:296-304` measured the AI
wall and found **perception + think are ~6% of it** — the wall is the body (hitzone ~10ms +
`move_and_slide` ~9ms + anim/execute ~18ms). A cap on *cognition* targets the 6%. **Worth settling:
YES, and cheaply** — it is a headless CPU measurement (legitimate; no GPU figure), and the harness
already exists (`tests/test_arena_perf.tscn`, `:281-295`).

### 2.6 The "98.7% tri cut" impostor claim. **HAS NO PARENT DOCUMENT.**

The figure appears exactly once repo-wide: in this session's own `briefing.md:63-64`, labelled
"claimed". There is no `ART_Track_Log.md` entry, no ledger row, no probe. **And it is the wrong
metric by this ledger's own law** — `PERF_LEDGER.md:98-100` (33% prims + 77 calls → ~0) and
`briefing.md:98-99` ("tri budgets are style, not perf"). **Worth settling: NO. Worth DELETING as a
perf claim: YES.** It is an art/memory win; say that and stop.

### 2.7 `ADR-031:12, :22` — "destruction is CHEAP", "the cheap default that reads". **BARE.**

To the ADR's credit `:30-32` gates on measurement and `:42-43` records the perf-proof as NOT BUILT.
But `:12` sits in the Decision section, which is what gets quoted downstream. **Worth settling: not
now** — nothing is being built on it this session. **Worth flagging: yes**, because
`DESTRUCTIBLE_JUNGLE_PLAN.md:182-184` proposes adding per-vertex shader work to
`vegetation_sway.gdshader` — **on the canopy, the only subsystem measured to matter.** That is a perf
*regression* risk dressed as a feature, and it is unpriced.

### 2.8 `GAME_GUIDE.md:133` — "last measured 19–25 FPS". **STALE BY ~9 FPS.**

Ship parity is ~34 (`PERF_LEDGER.md:679`, `:698`). The document of record is pessimistic enough to
justify panic work that is not needed. **NO DRIFT: correct in this session.** Cost: one line.

### 2.9 A landmine nobody has named: **13 unused cards on disk**

`assets/world/vegetation/cards/` holds **40** card GLBs (+40 PNGs, verified by listing), but
`terrain/vegetation/vegetation_manager.gd:48-55` `TYPE_SPECIES` names only **27** unique species
(the ledger's 27 is correct and current — good). The 13 idle ones are `elephant_grass_c`, `grass_fan`,
`grass_tuft_a/b/c`, `jungle_palm_a3`, `jungle_palm_b3`, `liana_b`, `palm_sapling_b`, `tall_grass_c`,
`trunk_vine_a/b`, `vine_b`.

**The far-card ring is `(buckets in range) × (species present per bucket)` ≈ 94 × ~17.6
(`PERF_LEDGER.md:916-917`), and species-per-bucket saturates at the POOL SIZE.** Adding those 13 to
`TYPE_SPECIES` — a two-line "use the art we made" change any future session would make without
thinking — scales the ring toward 27→40, i.e. **up to +48% canopy draw calls.**

> **That single innocuous edit would undo more than the entire BUCKET=128 win, and more than the
> firebase atlas twice over.** The art track is currently producing cards faster than the render path
> can afford them, and nothing in the repo says so. **This belongs in a comment at
> `vegetation_manager.gd:48` — it is a units/constraint contract, exactly the kind COMMENT DISCIPLINE
> permits.**

---

## 3. THE RULE #1 TRAP — is `BUCKET = 64 → 128` a trap? **YES. Plainly yes, as a ship change.**

### 3.1 The thing the biggest lever destroys is the thing the game is for

The canopy lever works by rendering **less jungle at distance**. Not less *detail* — less *jungle*.
RECON is an open patrol simulator whose stated RULE #1 is that the world must be FUN to walk and FEEL
like Vietnam, judged **by his eyes, not by engine counters** (`briefing.md:94-96`; user memory
`recongame-rule-one-fun-vietnam`).

A recon patrol's entire sensory life is the **100–350m band**: reading treelines, judging whether that
shape is canopy or a bunker, deciding where the ground stops being walkable. `tree_cover_layer.gd:46`
sets `view_distance = 350.0` and calls it "fog transmittance <=10%" — that band is not decoration,
**it is the subject matter.** Every FPS point available from the canopy is bought out of it.

### 3.2 The specific defect, from the code that already documents it

`terrain/vegetation/tree_cover_layer.gd:48-52`, written by whoever built the system:

> *"visibility_range is per-NODE against the transformed AABB (godot#79471 - the docs say origin and
> are wrong). Chunk-sized nodes quantize both rings by +/-181m - that WAS the invisible-jungle bug.
> 64m buckets bound the error to +/-45m without exploding the node count."*

`BUCKET = 128` doubles that bound to **±90m** against a **65m** near/far handoff (`:45`). Concretely,
per node, one of two things happens:

1. **The far card switches on too late** → a band of up to ~90m where the near solid has already
   ranged out and the card has not ranged in. **A hole in the jungle.** This is the invisible-jungle
   bug at half its historical severity — the same defect, not a new one.
2. **The far card switches on too early** → near solid *and* far card render together in the same
   band. **Double-rendered jungle**, which *adds* fill — partially cancelling the very win being
   chased — and reads as visibly doubled foliage.

And there is **no softening escape hatch.** `:315-318` disables the fade deliberately:
`VISIBILITY_RANGE_FADE_SELF` alpha-dithers across the margin and *"trees near the near/card LOD
boundaries render SEE-THROUGH"*. So the failure mode is a **hard PS2 pop of a 90m hole**, not a gentle
blend. `RANGE_MARGIN = 8.0` (`:53`) buys 8m of hysteresis against a ±90m error — it is not a mitigation.

### 3.3 The judgement

**Shipping `BUCKET = 128` trades the only measured FPS win for a defect class this project has already
shipped once and hated.** It is worse than a look cost: it is a *nondeterministic* look cost — the
error is per-node, so which patch of jungle vanishes depends on where the centroid landed
(`:122-127`), which depends on the seed. **He would find it by walking, not by reading a table**, and
under RULE #1 that is the only test that counts. **TRAP. Do not ship it. Rank it below every look-free
lever regardless of size** — which is what `briefing.md:94-96` already binds the Arbiter to do.

### 3.4 BUT — and this is the distinction the council must not blur

**`BUCKET = 128` as a MEASUREMENT-ONLY phase is not a trap. It is the single cheapest decisive
experiment available in this session.** See §4.4. Shipping it is a trap. Measuring with it is the
opposite of a trap — it is how you avoid a much bigger one.

### 3.5 A look-free hypothesis worth measuring instead — **OPINION, offered as a hypothesis, not a decree**

`BUCKET` is currently one constant serving two jobs: the grouping key (`:110`) and, through the
centroid AABB, the visibility quantum. It does not have to be uniform across species.

`tree_cover_layer.gd:20-28` already partitions the pool: `COVER_TRUNK` names the **cover-givers**
(broadleaf, bamboo, banana, palm, deadfall — the big silhouettes you read a treeline by); everything
else — bush, fern, grass, rice, liana, vine, sapling — is **concealment**. Of the 27 live species
(`vegetation_manager.gd:48-55`), roughly half are concealment.

**Hypothesis:** a ±90m handoff error on a *waist-high fern card at 150m* is invisible; the same error
on a *broadleaf crown* is a hole in the sky. So a **per-species bucket** — 64 for `COVER_TRUNK`
species, 256 for concealment — could cut a large share of the far-card ring **with no silhouette
change at distance.** That is ~20 lines at `:110` and `:52`.

**I am not proposing it be built.** I am proposing that if anyone builds a look-costing lever, this is
the one that costs the least look per call — and that it be *measured and shown to his eyes* before it
is anywhere near ship. **It is an opinion; I cannot verify a look claim, only he can.**

---

## 4. THE OPPORTUNITY COST — the case AGAINST the ambitious plan

I am asked to argue this honestly. Here is the argument, and I believe it.

### 4.1 What the ambitious plan actually is

Not "atlas the textures". `PERF_LEDGER.md:930-939` costs it truthfully:

> *"the card bake tool is not in the repo… Atlasing therefore means writing the bake pipeline from
> scratch, plus a unit-quad mesh with per-instance UV-rect custom data and a shader to read it, plus
> re-deriving each card's aspect into the instance transform. **That is a new far-card renderer path,
> not a batching tweak**."*

I re-verified today: `tools/` still has no card/impostor generator. The 40 cards on disk have **no
checked-in generator that produced them** — so the bake pipeline must be written from nothing, and
must reproduce art that already shipped and that he has already approved with his eyes.

### 4.2 Six reasons it is the wrong use of this window

**1. Its payoff is an unmeasured fraction of a one-pose ceiling** (§1.4, §1.5). Everything else follows
from this.

**2. It is a ONE-WAY DOOR.** The FOSSIL LAW (`CLAUDE.md`, ADR-023) requires the predecessor to be
deleted in the same change. There is no "build it, keep both, A/B them for a week" path. You replace
the shipped far-card renderer and delete the one he approved.

**3. It touches the PROTECTED foundation, in the worst possible place.** `briefing.md:100` — *"the
world foundation is PROTECTED — improve it, never rebuild or re-fragment it"* (user memory
`recon-world-foundation-locked`). A new far-card renderer path *is* a rebuild of how the jungle is
submitted. And if it goes subtly wrong — aspect ratios, UV bleed at mip boundaries, alpha-test
threshold shifts across an atlas — it goes wrong **on the jungle at distance**, i.e. on RULE #1's
sacred ground, in a way that reads as "the world looks worse now" without anyone knowing why.

**4. It cannot fix the half of the frame that is not GPU.** `PERF_LEDGER.md:200-201`: CPU 44.35ms vs
GPU 51.94ms at native — near balanced — *"so a pure fill fix cannot get past ~19→23 fps alone."* And
`:296-304`: at 65+ live units the AI physics wall is 38-40ms/tick, in the **body** not the brain. A
perfect atlas leaves all of that untouched.

**5. It is not what the window is for.** The standing decree of 2026-07-25 makes the **Blender→Godot FP
gun/arms pipeline the project's MAIN PRIORITY** (user memory `recongame-blender-godot-pipeline-priority`,
`recon-m16-rig-break-2026-07-25`). **PLAYTEST R4 is the standing session entry gate** and is discharged
only by his own verified playtest (`CLAUDE.md`, THE SESSION ENTRY GATE). He stood perf down himself on
2026-07-20 as *"final polish we'll do in a few weeks"* (`PERF_LEDGER.md:884`). Six days later he asked
a **question** — *"I want to deep dive overall in the game how to increase the fps"*
(`briefing.md:2`). **A question is not a mandate for a week of renderer engineering.** Answering it
with a plan he must now supervise, on the foundation, during his top-priority art window, spends his
attention — which is the scarcest resource in this project — on the wrong subsystem.

**6. The pattern this ledger keeps repeating is "believed a number, built on it, retracted it."**
Shadow twice. Mobile-clears-the-gate once. The +8.6 light win, still uncorrected in a ratified ADR.
**The correct lesson is not "measure more carefully"; it is "do not commit engineering until the
number that sizes it exists."** The atlas's sizing number does not exist.

### 4.3 The counter-argument, stated fairly

The canopy genuinely is the only lever above noise, at three configs (`:875-878`). It genuinely owns
~1,200 of ~1,400 calls (`:877`). If the call fraction is high, the atlas is a ~7 FPS win — a 20%+
frame improvement, the largest available, and it costs **zero look** (identical cards, identical
placement, identical silhouette). That is a real prize and I will not pretend otherwise. **If the
measurement in §4.4 comes back large, I withdraw this objection and support building it.**

### 4.4 What to do instead — the cheap experiment that decides it

**One const, one A/B/A cycle, ~30 minutes of his time, zero new systems, zero ship risk.**

Set `tree_cover_layer.gd:52` `BUCKET = 128.0` **as an instrument phase only**, run the existing
`-- --perf-probe --perf-cycle`, record, revert.

**Why this is the right experiment:** raising `BUCKET` cuts far-card **draw calls ~2.5×**
(`PERF_LEDGER.md:920-921`) while drawing **the same cards, at the same places, with the same fill and
the same primitives** (modulo quantization). It is the only available manipulation that moves calls
**without** moving fill. It therefore reads the call/fill split **directly** — the one number the
entire atlas decision rests on.

**And its error direction is conservative.** If the quantization double-renders, fill goes *up*, so
the measured win is *understated* — a small result is trustworthy. The probe prints prims and calls
per phase (`perf_probe.gd:213-217`), so a double-render is visible in the row and does not have to be
guessed at.

**How to read it, decided in advance so nobody rationalises afterwards:**

| BUCKET=128 result (bracketed A/B/A, vs that run's own floor) | ruling |
|---|---|
| **< the run's noise floor** | ~600 calls removed bought nothing. **The atlas is dead. Close it permanently and write the row.** |
| **floor … +3 FPS** | the atlas's ~906-call cut extrapolates to ~+4.5. **Marginal for a week of one-way-door work. OPINION: still decline.** |
| **> +4 FPS** | calls really are the frame. **The atlas is justified — come back and build it with a number in hand.** |

**One experiment either saves a week or earns the right to spend it. That is the whole devil's
advocate position.**

### 4.5 Two instrument fixes worth more than any single lever

**a) `perf_probe.gd` does not sample GPU-ms or CPU-ms.** `:109-114` reads only
`RenderingServer.get_rendering_info` (prims/calls/objs) and `Engine.get_frames_per_second()` at `:104`.
The `viewport_get_measured_render_time_gpu` figure — used by the 2026-07-16 overnight bench
(`PERF_LEDGER.md:141`) — is not read. **FPS averages carry all the CPU jitter; GPU-ms does not.**
Adding both to the row would materially *lower the detectability floor* (§5), which is worth more than
any lever because it makes small levers falsifiable at all. Cost: a few lines. **This is the highest-
leverage change in the whole session and it is not a lever, it is a ruler.**

**b) The canopy guard is defeated — the probe has the exact disease its own comment names.**
`perf_probe.gd:117-120` states: *"A phase that cannot find its system still prints a row, so an
unresolved system must be LOUD - a silent no-op row reads as 'this system costs nothing'."* But
`:124-126` sets `canopy_hit = true` merely because `vg != null`, and `:127-129` looks up
`TreeCoverLayer` with **no guard at all**. If the node is renamed, or `WorldConfig.USE_TREE_COVER`
(`scripts/levels/world_config.gd:21`) is ever flipped, the `no_canopy` row silently measures
`patches_disabled` on a null patch layer — **nothing** — and prints as though the canopy were free.
That is class A waiting to happen in the *other* direction. **One line: push_error when `tc` is null.**

---

## 5. THE MEASUREMENT TRAP — the smallest win this hardware can honestly detect

### 5.1 The floors on record

| run | floor | pointer |
|---|---:|---|
| ship-parity attribution cycle (seed 47225) | **1.4** | `PERF_LEDGER.md:689` |
| campfire re-measure A, shipped build (seed 12) | **1.1** | `:825` |
| campfire re-measure B, lights restored (seed 12) | **2.8** | `:843` |
| shadow study (5 phases, tightest ever) | 0.5 | `:715` |
| pre-fix runs (screenshot artifact inflating) | 0.9 / 2.2 / 3.4 | `:517`, `:554`, `:589` |
| night arena (escalating scene — not comparable) | ±3.3 | `:228` |

The floor is `_spread_of_baselines()` (`perf_probe.gd:250-262`) — the **widest gap between any two
baseline windows in the run**. The probe tags `|Δ| ≤ spread` as `INSIDE NOISE` (`:244`).

### 5.2 The honest floor

Three ship-parity A/B/A cycles produced **1.1, 1.4, 2.8**. You do not get to pick which one you draw,
and you do not know which you drew until the run finishes. **Therefore the smallest win this hardware
and instrument can honestly detect is ~3 FPS.** Anything smaller may land inside the floor of the very
run that measures it, and a result that depends on which run you happened to get is not a result.

At the ~34 FPS ship baseline (`:679`, `:698`) that is **~2.4 ms of frame time**
(34 fps = 29.4 ms; 37 fps = 27.0 ms). Round it and hold it:

> **DETECTABILITY FLOOR: ≈ 3 FPS ≈ 2.4 ms at the shipped baseline.
> A lever whose expected win is below that is UNFALSIFIABLE with the instrument that exists.
> It must not be shipped on faith, and no FPS row may ever be written for it.**

Three legitimate ways to get under the floor, none of which is "believe it anyway":
- **Improve the ruler** — sample GPU-ms/CPU-ms (§4.5a); GPU-ms excludes CPU jitter and resolves far finer.
- **Stack and measure the stack** — ship N sub-floor changes together and A/B/A the bundle. Honest, but
  the bundle is then one indivisible claim (and `ADR-026:180-195` shows how badly a bundle ages).
- **Ship it for a non-perf reason** — authoring ease, memory, canon — and make no FPS claim at all.
  This is usually the right answer.

### 5.3 Levers whose expected win is below the floor — **UNFALSIFIABLE. Do not ship on faith.**

| lever | expected win | evidence | ruling |
|---|---|---|---|
| **Firebase 9→5 material collapse** | ~0.35–0.7 FPS (bounded, §2.1) | `PERF_LEDGER.md:896-898`, `:875-878`, `gen_firebase.py:61-77` | **UNFALSIFIABLE.** Do it for authoring, never for FPS. |
| **Campfire lights** | −0.5 / +0.2 | `:850-851`, floors 1.1 / 2.8 | **MEASURED BELOW FLOOR TWICE.** Closed. |
| **Ground clutter / grass** | +0.8 / +0.6 / −0.0 / +0.2 / +0.3 / +0.5 | `:696`, `:826`, `:844`, `:511`, `:560`, `:590` | **BELOW FLOOR SIX TIMES.** Closed. |
| **Sun-shadow removal** | −0.2 / +0.6 / +1.0 | `:696`, `:826`, `:844` | **Measures nothing — already off** (`game_world.gd:48`). Closed. |
| **Near-field shadow cap (40/80m)** | identical within 0.5 | `:715-725` | Not a middle ground. Closed. |
| **Triangle shaving** | ~0 | `:98-100` (33% prims + 77 calls → ~0) | Style, not perf. Closed. |
| **Single-sided billboards** | ~0 | `:96` (identical row) | Keep for worst-case fill; claim nothing. |
| **Impostor "98.7% tri cut"** | unmeasured; wrong metric | `:98-100`; no parent doc (§2.6) | Art/memory win. Not a perf claim. |
| **Vegetation density ladder** | "buys little FPS" | `:110-113` | Fossil-discharge + memory lever. Not perf. |

---

## 6. WHAT IS NOT WORTH DOING — the definitive list

Written so this ledger stops re-litigating these. Each line carries the evidence that kills it.

1. **THE SUN SHADOW. IN EITHER DIRECTION. FOREVER.**
   Ship already runs `shadow_enabled = false` (`scripts/levels/game_world.gd:48`), so **turning it off
   is not a lever and cannot be one** — measured −0.2 / +0.6 / +1.0, all inside floor
   (`PERF_LEDGER.md:696`, `:826`, `:844`). Turning it **on** costs ~10.5 FPS (~30% of the frame) and
   the near-field cap is **not** a mitigation — 40m / 80m / uncapped are identical within 0.5
   (`:715-725`). Guarded by `tests/test_ship_parity.tscn` (`:755-794`). **Measured and believed twice,
   retracted twice (`:393-402`, `:626-635`). If a future session finds a sun-shadow win, the
   instrument is broken — check the harness before you believe the number.**

2. **CAMPFIRES / CAMPFIRE LIGHTS.** Seed 47225 rolls DAY and contains **zero** campfires
   (`:475-489`); `TIME_TABLE` makes half of all seeds campfire-free (`:488`). Re-measured at ship
   parity at the only seed where they exist: **−0.5 and +0.2, both inside floor** (`:846-861`).
   ADR-026 Part A #1 is a **CANON win, not a perf win** (`:867`). **The "+8.6 FPS" in `ADR-026:121-123`
   is refuted and must be struck** (§2.2).

3. **GROUND CLUTTER / GRASS DENSITY.** Inside noise in every run that ever measured it — six times
   (§5.3). Pulling it also costs Pillar-2 atmosphere (`:198`) and was already reverted once for
   exactly that (`:106-108`).

4. **TRIANGLE SHAVING, TRI BUDGETS, AND REBUILDING OVER-BUDGET ASSETS "FOR FPS".** Measured: cutting
   **99,500 prims (33%) and 77 draw calls moved FPS by ~0** (`:98-100`). `briefing.md:98-99` binds this.
   `firebase_kit_phase1_read.md:243-265` already gets this right — tri budgets are an **art rule** that
   forces silhouette-and-texture solutions, which is the 1999–2005 read. Keep them for that. Claim no
   frames.

5. **A RENDERER SWAP.** Forward+ is DECREED (ADR-026 Amendment A, `briefing.md:49-51`). Closed unless
   decisive new evidence appears, and then it is **his** question, never an assumption.

6. **SHIPPING `BUCKET = 128`.** §3. The code comment that documents why is at
   `tree_cover_layer.gd:48-52`, written before this council convened. Measuring with it: yes (§4.4).
   Shipping it: no.

7. **THE CARD ATLAS / NEW FAR-CARD RENDERER PATH — *NOT YET*, and not in this window.** §4. Not
   because it is wrong, but because **the number that sizes it does not exist**, it is a one-way door
   under the FOSSIL LAW, it lands on the protected foundation, and the standing priority is the FP
   arms pipeline with PLAYTEST R4 unresolved. **Gate it on §4.4.**

8. **THE FIREBASE 9→5 MATERIAL COLLAPSE, AS A PERF PROJECT.** Bounded at ~0.35–0.7 FPS against a
   ~3 FPS floor (§2.1, §5.3). Do it if it makes `tools/gen_firebase.py` easier to author. Never write
   an FPS row for it.

9. **ANY NEW FPS ROW WITHOUT A WINDOWED, SEEDED, SCALE-STATED, A/B/A MEASUREMENT.**
   `briefing.md:107`. Headless GPU figures are RendererDummy fiction (`:27-28`). A number without its
   scale, renderer and seed is not a number (`:18-24`).

10. **RE-DERIVING ANY OF ITEMS 1–5.** They are settled. The cost of re-litigating them is the real tax
    this ledger has been paying. **If a future session is about to re-measure a shadow or a campfire,
    that session has not read this file, and the correct action is to point at this line.**

---

## 7. WHAT I WOULD ACTUALLY DO WITH THIS WINDOW — ranked, with what each sacrifices

**OPINION throughout. The Summoner holds final authority.**

| # | action | cost | sacrifices |
|---|---|---|---|
| 1 | **Correct the drift**: `ADR-026:121-123` (+8.6), `ADR-026:120-121` (14→23.1), `OVERSEER_CHARTER.md:94,:149`, `GAME_GUIDE.md:133` (19–25 → ~34), `firebase_kit_phase1_read.md:261-263` (label unproven) | minutes | nothing. This is owed under NO DRIFT. |
| 2 | **Fix the ruler**: sample GPU-ms + CPU-ms in `perf_probe.gd`; `push_error` when `TreeCoverLayer` is not found (§4.5) | a few lines | nothing. Lowers the floor for every future question. |
| 3 | **Run ONE windowed batch**: the existing `--perf-probe --perf-cycle` at (a) the spawn pose and (b) **a jungle-sightline pose**, plus one `BUCKET=128` instrument phase, reverted after | ~30–40 min of his time | one sitting. Answers the class-B pose question AND the call/fill split. |
| 4 | **Comment the species-pool constraint** at `vegetation_manager.gd:48` (§2.9) | one comment | nothing. Prevents a +48% call regression. |
| 5 | **Take look-free freebies only if they are free in risk too**, and claim no FPS for any of them | small | none, provided nobody writes an FPS row. |
| 6 | **STOP. Go back to the FP arms pipeline and PLAYTEST R4.** | — | the atlas, deferred pending #3's number. |

**What #6 sacrifices, named plainly, because the law binds me too:** if the call fraction is in fact
high, we leave ~7 FPS on the table for some weeks. **I accept that trade.** The frame is ~34 FPS with
no ratified gate and his eyes as the judge (`PERF_LEDGER.md:6`). Seven speculative frames are worth
less than one week of his attention on the subsystem he himself named the main priority — and if #3
says the frames are real, they will still be there when we come back with a number in hand.

---

## 8. THE ONE SENTENCE THIS SESSION MUST NOT FORGET

`PERF_LEDGER.md:443` — **"Three consistent measurements of an artifact are still an artifact."**
The canopy has three consistent measurements **at one pose**, of **one lever nobody can pull**, sizing
**one project whose payoff fraction is unmeasured**. It is not an artifact. But it is not yet a plan.
