# DEVIL'S ADVOCATE — ON THE 10-STEP PLAN (attacked before it was written)

**Convened:** 2026-07-13 · **Seat:** Devil's Advocate · **Law obeyed:** read the code, never the plan.
**Charge:** attack the plan BEFORE the Arbiter writes it.

> ## THE HARDEST TRUTH, FIRST
>
> **A 10-step plan is the FIFTH consecutive act of planning, and it is the only thing in this project
> that has never failed — because it has never been tested.**
>
> Five syntheses in three days (`synthesis_cod2000_living_fight` 07-11 · `synthesis_living_war` 07-12 ·
> `synthesis_destructible_jungle` 07-12 · `synthesis_grunt_not_ghost` 07-13 · `synthesis.md` 07-13
> 20:49). **Twelve commits today: an aid bag, a medic, a folder restructure, a sprite purge.**
> **Zero minutes of the game played.** `ida9` — standing decree item **ZERO**, *"session entry gate;
> NOTHING NEW SHIPS UNTIL IT VERIFIES"* — was created **2026-07-10** and is **still OPEN**, and
> `bd show 97u3` lists it as a live blocker of the GATE.
>
> **The council's output is not game. It is beads.** Today's council alone minted four: `365s`, `v58s`,
> `atov`, `eaqv`. The graph now carries **16 open P0s** and it is growing faster than it is closing.
> **A tenth step will mint more.**

---

## 1 · PLAN OR PLAY?

### THE STEELMAN FOR *PLAY* — and I believe it

**(a) The machine already told us, and nobody was in the room.**
The decree's headline finding is *"THE RICE PADDIES DO NOT EXIST — 0 of 65,536 cells."* How was it
found? A war council, a booted world, and a cell census. **How could it have been found?** The boot log
has printed **`0 rice billboards` on every single run since it shipped.** It took a four-architect
council to discover a fact the game has been *shouting at an empty chair for weeks.*

**That is not an analysis gap. That is a nobody-is-looking-at-the-screen gap, and no plan fixes it.**

**(b) Both prose-fooling incidents are downstream of not playing.**
07-12 ordered a build against `logs[]` — **a `desc` string.** 07-13's briefing declared a P0 from **a
stale comment.** Both councils read *documents about the game* because **nobody has the game in their
hands.** A third document does not cure a document-reading disease. **§3 of this analysis contains the
THIRD instance, in the decree the Arbiter published tonight.**

**(c) The perf step and the playtest are the SAME SESSION.**
You cannot measure the frame time without booting the world, spawning the player, and standing in the
AO. **You will already be there, in the jungle, with a frame counter on.** To boot the game, stare at
one number, and quit without playing it is a *deliberate act of not looking at your own game.*

**(d) The plan is being ordered against zero evidence of what the game FEELS like.**
Ranking ten steps you have never experienced is how a project ends up with an **armorer's bench and a
nameplate** while **`r4bk` is open — F1–F4 do nothing, the player cannot command his squad, and
Pillar 4 is literally "THE SQUAD IS THE RPG."**

**(e) The Arbiter is comfortable here, and he is EXCELLENT at it.** That is precisely the danger. A bad
plan gets rejected on sight. **A brilliant plan is how you lose a month.** (The 07-12 decree wrote that
sentence about someone else.)

### THE STEELMAN FOR *PLAN* — stated fairly, because the law binds me

The process converts to code sometimes: the 07-12 decree's 0B density merge **shipped**
(`gameplay_grid.gd:172-178`), and its `clear_area()` bug fix **shipped** (`_rematerialize`). Two of the
findings in tonight's decree — the determinism poison and the riparian inversion — **could not have been
found by playing.** They are invisible from inside the game. That is real, and it is what code-reading
is *for*.

### ✅ THE VERDICT: **PLAY FIRST. THEN THE PLAN IS THREE STEPS, NOT TEN.**

**Step 0 is not "measure perf." Step 0 is RUN `ida9`** — with the FPS overlay on, at
`scaling_3d/scale = 1.0`, and with the renderer A/B done *in that same session*. One sitting. It is the
decree's item ZERO, it is four days late, it is a GATE blocker, and **it will REORDER the other nine
steps before they are written.**

Anything the council writes tonight past step 0 is a guess dressed as a sequence.

---

## 2 · THE GOLD-PLATING — item by item

### 🥇 THE PADDY FIELD-PASS IS THE WORST OFFENDER, AND IT IS NOT CLOSE

The decree wants a **seeded field pass**: flood-fill 3–12 tile polygons near the D8 network, **terrace
the heightmap**, **raise the bunds**, **drop the pans**, and **write water back into `water_map`.**

**THE ACTUAL BUG IS ONE COMPARISON AGAINST A NUMBER THAT IS BELOW THE FLOOR OF THE MAP.**

```gdscript
# gameplay_grid.gd:283-291   -- the map's lowest point is 87.9 m
if height < 5.0 and slope_val < 0.1:  return TerrainType.RICE_PADDY   # dead
if height < 50.0:                                                     # dead
    return TerrainType.RICE_PADDY if randf() < 0.3 else TerrainType.GRASSLAND
elif height < 150.0: return TerrainType.MEDIUM_JUNGLE                 # <-- EVERYTHING lands here
```

```gdscript
# vegetation_manager.gd:304  -- the second, independent classifier
if height < 30.0 and slope_dot > 0.93:   # dead by 58 metres
```

**THE 10-LINE FIX — verified against the code, shippable in an hour:**

1. `build_from_terrain()` **already fills `elevation[]`** (`:124`). One extra pass → `_h_min`, `_h_max`.
   **(4 lines.)**
2. `_determine_terrain_type()` bands on **normalised** `t = (h - _h_min) / (_h_max - _h_min)` instead of
   absolute metres. Paddy where `t < 0.08 and slope_val < 0.1`. **(3 lines changed.)**
   *This fixes it on EVERY SEED FOREVER, not just this one — an absolute-metre band was always a bug
   waiting for a different heightmap.*
3. `_apply_riparian_belt():213` — the skip list is `CLIFF or WATER`. **Add `or RICE_PADDY`.**
   **(ONE LINE.)** That is the entire "inversion" the decree found. **It is one line, not a field pass.**
4. `vegetation_manager.gd:304` — normalise, or **delete the whole second classifier** (ADR-023; the
   decree already orders this). **Zero new code.**

> **~10 lines and the paddies EXIST. Today. On every map.**
> His five paddy patches · the four-pan quad · `_paddy_open_side` · the wade drag · the ×2.2 noise wake
> · the leech timer — **all of it is already written, already tested, and has never once executed.**
> **The 10-line fix is not a compromise. It is the first time the Summoner ever SEES the thing he built.**

**The 2-day version makes paddies BEAUTIFUL. The 10-line version makes them EXIST. You do not know
whether you need the beautiful one, because nobody in the history of this project has stood in a paddy.**
Terracing a heightmap for a field that has never been walked is **designing for a screenshot.**

**The Arbiter's pre-emptive objection, and its answer:** *"the pan sits 5.5 cm above ground on slopes up
to 26° — dirt will punch through the water."* **Then gate the paddy on slope — WHICH THE CODE ALREADY
DOES** (`slope_val < 0.1`, `:283`). The 5.5 cm problem is a *symptom of the dead elevation gate*, not an
argument for terracing. Ship the 10 lines, walk into a paddy, and **if the dirt punches through, HE WILL
TELL YOU IN TEN SECONDS** — and then terracing becomes a *measured* decision instead of a pre-emptive
one.

### 🪤 THE FOSSIL-PROBE FIX IS A LANDMINE, NOT A CHORE

```gdscript
# tests/test_fossils.gd:6
const SCAN_DIRS: Array[String] = ["res://scripts"]
```

Adding `"res://terrain"` is **one array element.** And it will **instantly turn the build RED**, because
every fossil in `terrain/` becomes a **NEW** fossil — and the decree itself already names a pile of them:
`near_water_mask`, `VegetationManager._determine_terrain_type`, **11 dead water functions**,
`get_cover()`, `has_line_of_sight()`. The fossil law is explicit: **"A NEW fossil FAILS THE BUILD"** and
**"Regenerating the baseline to silence a failure is THE ONE FORBIDDEN MOVE."**

**So this one-line change has exactly two exits:**
- **(a)** delete every fossil in `terrain/` **in the same commit** — **unbounded**, and it is *all* of
  Phase 2's delete list plus whatever else the probe finds; or
- **(b)** run `--write-baseline`, which in the git log is **INDISTINGUISHABLE FROM THE FORBIDDEN MOVE.**

> **THE COUNCIL MUST RULE, IN THE PLAN, WHICH EXIT IT TAKES — and if it is (b), ADR-023 must be amended
> IN THE SAME BREATH to say that grandfathering a NEWLY-SCANNED TREE is legal.** Otherwise this step
> deadlocks the build, and the next agent takes the forbidden exit **because it is the only one that
> turns the suite green.** *A law that makes the honest move impossible teaches everyone to cheat.*

**Do not put this step in a 10-step plan without that ruling attached.**

### ✂️ THE COMMENT PURGE IS NOT A STEP — IT IS FIVE MINUTES

`37ob` is real; it has drawn blood twice. It is also **three lines in `jungle_patch_layer.gd` (10-11,
83)**. Giving it a step number converts a 5-minute action into a session. **Delete them inside the paddy
commit and never speak of it as a step.** Same for "dead-path fixes." **Steps are for things that can
fail.**

### ⚠️ TRUNK COLLIDERS — AND A FOSSIL IN THE BEAD GRAPH ITSELF

**There are TWO OPEN BEADS for trunk colliders, and they order CONTRADICTORY ARCHITECTURES:**

| Bead | Created | Its spec |
|---|---|---|
| **`2v3t`** | 07-12 (TD) | *"**ONE BODY PER SUBCELL** — **NOT** one per chunk. Jolt makes the one-body claim true in steady state but **WORSE on mutation**."* |
| **`eaqv`** | 07-13 (Godot Specialist) | *"**PhysicsServer3D chunk compounds** — 25 static body RIDs."* |

**The 07-13 council reversed the 07-12 council's spec and did not close the old bead.** Both are OPEN.
**The fossil law binds the bead graph too — a bead nobody will execute is a lie in the map.**

A 10-step plan that cites `2v3t` builds the 07-12 architecture. One that cites `eaqv` builds the 07-13
one. **Close one, with a reason, BEFORE the plan names its flagship step — or the plan is ambiguous on
the single most important thing in it.**

### ✅ WHAT SURVIVES (the game genuinely needs these)

- **The determinism fix** (`atov` / `5i8a`) — and note the DA-of-record finding the decree buried in a
  parenthesis: **`has_line_of_sight()` HAS ZERO CALLERS.** If it is dead, **DELETE IT** (ADR-023). That
  is **zero lines of new code**, one of the two `randf()`s vanishes, and a P0 GATE bead gets closer to
  green. **A deletion is a better fix than a fix.**
- **Trunk colliders** — the one decree-ordered, gate-exempt, unbuilt thing in this domain. But **only**
  after §4's ladder, and **only** after `2v3t` vs `eaqv` is resolved.
- **The perf measurement** — but as a **rider on the playtest**, and **only with §4's pre-committed
  decision rules.**

---

## 3 · THE STEP THAT WILL FAIL — AND IT FAILS ON THE FIRST LINE

### THE DECREE ORDERS A BOOT SEQUENCE THAT RUNS THE OTHER WAY

> **Decree Phase 2:** *"Run a **seeded field pass after `WaterSystem`, before chunk meshing**."*

**THAT SLOT DOES NOT EXIST. WATERSYSTEM RUNS *AFTER* CHUNK MESHING.** Verified on disk:

```
terrain_manager.generate_terrain():
  :124  terrain_generator.generate(seed)          <- the heightmap
  :140  _extract_and_carve_rivers()               <- A SECOND RIVER SYSTEM. It already CARVES the heightmap.
  :141  _build_water_proximity_mask()             <- near_water_mask (which the decree wants DELETED --
                                                     and it is the ONLY water knowledge that exists here)
  :146  await _load_initial_chunks_async()        <- *** ALL 25 CHUNKS ARE MESHED. RIGHT HERE. ***
                                                     mesh + collision + vegetation_manager.generate_for_chunk(:248)
                                                     + the patch layer + the billboards
  :151  _build_river_meshes()
  :155  terrain_ready.emit()

game_world._on_terrain_ready():
  :149  water_system.initialize(...)              <- *** WATERSYSTEM. AFTER EVERY CHUNK IS ALREADY BUILT. ***
  :152  water_system.generate_water_bodies()
  :162  gameplay_grid.build_from_terrain()        <- and the grid is LAST of all
```

**To do what the decree orders, you must:**
1. **Split `generate_terrain()`** into a heightmap phase and a chunk phase — but `_load_initial_chunks_async()`
   is `await`ed *inside* it, and **`terrain_ready` is the signal EVERYTHING hangs off**: `DamageSystem`,
   `ClearingSystem`, the shader textures, `GameplayGrid`, the player spawn, `GroundClutter`.
2. **Hoist `water_system.initialize/generate_water_bodies`** out of `_on_terrain_ready` and into the
   middle of `generate_terrain()`.
3. **Reconcile it with `_extract_and_carve_rivers()`** — *a second, independent river system that already
   mutates the heightmap.* The decree's ruling *"`WaterSystem` is the ONE water oracle"* is **not a
   ruling; it is a third water system's worth of work**, and the decree budgets zero for it.

### THE FAILURE MODE, PRECISELY

**You mutate the heightmap (terrace + bunds) AFTER the chunks are meshed.** At exactly the cells you
changed, the following are now **stale**:

- the **chunk mesh** (the ground you SEE is the old ground),
- the **chunk collision shape** (the ground you WALK ON is the old ground — **so the bunds are invisible
  ridges you walk straight through, and the terrace is a pit you cannot fall into**),
- the **navmesh islands**,
- and **every MultiMesh instance's Y** — trees, patches, billboards, clutter — because every one of them
  was placed by sampling `heightmap.sample_world()` **before the terrace existed**. **The paddy becomes a
  sunken basin with a grove of trees floating three metres in the air over it.**

**Then someone "fixes" it by forcing a full chunk rebuild after the stamp.** That re-runs the entire
vegetation pipeline, doubles the load-time budget, and drops you directly into the neighbourhood of the
`clear_area()` legacy-palm bug the 07-12 council just finished fixing.

### 🚨 THE TRIPWIRES — put these IN the plan, verbatim

> **STOP THE MOMENT ANYONE WRITES ONE OF THESE SENTENCES:**
> - *"we just need to rebuild the chunks after the paddy pass"*
> - *"let's hoist WaterSystem earlier"*
> - **any diff that touches `terrain_ready.emit()`**
>
> **That is not a step. That is the world's boot sequence, and it is a week, not two days.**

### AND THIS IS THE THIRD TIME IN TWO DAYS

| Date | The council ordered a build against… | …which was actually |
|---|---|---|
| 07-12 | `logs[]` *"already exists on disk"* | **a `desc` string** |
| 07-13 (briefing) | *"the paddy water parse is stale"* | **a stale comment; the parse works** |
| **07-13 (the decree itself)** | *"after `WaterSystem`, before chunk meshing"* | **a boot order that runs the OTHER WAY** |

**Three for three. The council keeps ordering builds against a codebase it has imagined.** The cure for
that is not a fourth document.

---

## 4 · PRE-COMMIT TO THE PERF NUMBER — OR THE MEASUREMENT IS THEATRE

**Verified:** `project.godot` contains **no `rendering_method` line at all** (grep returns only
`scaling_3d/mode=1`, `scaling_3d/scale=0.77`, `fsr_sharpness=0.3`). Default = **Forward+ on an Intel
UHD**, at **59.3 % of native pixels**.

**Measuring produces a NUMBER. A number produces a DECISION. The council has pre-committed to NOTHING —
which means whatever number comes back will be rationalised into permitting the plan that was already
written.** This project has already spent a P0 (`365s`) on believing a number it had not earned. **Do not
spend a second one.**

### THE LADDER — write this as the literal text of step 1, or do not run step 1

| Native FPS (`scale = 1.0`, on the WINNING renderer) | THE PRE-COMMITTED DECISION |
|---|---|
| **≥ 45** | Trunk colliders ship as specced. **And Charter §9's *"perf is the top systemic risk"* must be AMENDED** — the perf-first law loses its veto, and it has been vetoing things for a month. |
| **30 – 44** | Colliders ship, **but `2v3t`'s own asterisked warning is finally obeyed: MEASURE THE AI-PATHING COST BEFORE MERGE** (~95 % of the AO has no navmesh; the squad bee-lines on `move_and_slide()` through 16k cylinders). No new geometry until that number exists. |
| **20 – 29** | **FEATURE FREEZE ON THE JUNGLE.** Colliders are the LAST thing ever added to it. All further jungle work is **SUBTRACTIVE**: `plane_count` 5 → 3, fewer billboards, kill the far-LOD MMI. |
| **< 20** | **THE JUNGLE *IS* THE BUG. THE 10-STEP PLAN IS VOID.** Everything collapses into `365s`. No colliders, no paddies, no terracing, no destruction. **You do not decorate a burning house.** |
| **Compatibility beats Forward+ by > 30 %** | **Switch it, then RE-RUN THE WHOLE LADDER.** The decision is made on the winning renderer, never the current one. |

**And the honest one nobody wants to say out loud:** if native comes back at **14 FPS**, then **the paddy
step and the collider step BOTH DIE** — and the Arbiter will have spent an entire council designing two
features that the measurement kills. **That is the price of measuring LAST instead of FIRST, and it is
the whole argument for making the playtest step 0.**

**One further pre-commit — the format of the number itself:**

> **A perf number is invalid unless it states all four: (FPS, `scaling_3d/scale`, `rendering_method`,
> where-in-the-AO).** A number missing any of the four is exactly the lie that produced `365s`.

---

## 5 · THE BILL

*No free lunches. The law binds me too.*

| Step | Cost | What the GAME actually gets | Verdict |
|---|---|---|---|
| **RUN `ida9`** (FPS overlay on, scale 1.0, renderer A/B in the same sitting) | **1 session** | **The first evidence in four days.** Closes/reorders 2 GATE beads. Re-ranks every other step. | **STEP 0. NON-NEGOTIABLE.** |
| Perf ladder (§4) | **+30 min**, as a rider | The number, honestly labelled | **KEEP — with the pre-commit, or not at all** |
| Determinism (`atov` / `5i8a`) | **1–2 hrs — or ZERO if `has_line_of_sight()` is simply DELETED** | Closes the cheapest P0 in the graph | **KEEP** |
| **Paddies EXIST** (normalise the elevation band + 1-line riparian skip) | **~1 hr** | **The paddies. Today. On every seed. Every piece of authored paddy art runs for the first time ever.** | **KEEP — this IS the Summoner's ask** |
| **Paddy field-pass** (terrace / bund / stamp `water_map`) | **2 days on paper; a WEEK in reality — it is a boot-order rewrite (§3)** | Prettier paddies **nobody has ever stood in** | **CUT. Re-open the day after he plays one.** |
| Trunk colliders | ~2 days + an **unmeasured** AI-pathing risk | **The tree stops a bullet.** Pillar 1. | **KEEP — behind the ladder, and behind resolving `2v3t` vs `eaqv`** |
| Fossil-probe scan-dir | 1 line + **an unbounded delete-fest OR the forbidden move** | A probe that can see `terrain/` | **DEFER until ADR-023 rules on grandfathering** |
| Comment purge (`terrain/`) | **5 min** | Nothing visible; prevents false P0 #3 | **FOLD IN. NOT A STEP.** |
| Dead-path fixes | hours | Nothing visible | **FOLD IN. NOT STEPS.** |

### THE OPPORTUNITY COST OF ALL TEN — stated as bluntly as I know how

**Ten steps is one to two weeks.** At the end of it the project will:

- **still not have run `ida9`** (day 4 → day 18);
- **still have `r4bk` open — F1–F4 DO NOTHING. The player cannot command his squad. Pillar 4 is
  *"THE SQUAD IS THE RPG."***;
- **still have the witness rule unimplemented** — a silent kill still shouts *"YOU'VE BEEN MADE,"* which
  voids Pillar 3's entire stealth economy. Its bead, `o18o`, was **closed with the words "NOT FIXED."**
  The charter calls it **"the biggest single wound."** It is **decree item 1**, and it is **item 1 of
  NOTHING that has been worked on this week**;
- and will have minted **another four to eight P0s**, because **that is what a council does.** Today's
  produced four. **The graph holds 16 open P0s and it is growing.**

> **The Council is not building the game. It is building a magnificent, well-cited, internally-consistent
> MAP of the game — and it has never once looked out the window.**

### WHAT *MY* POSITION SACRIFICES

- **Playing first may burn a session confirming what we already knew from the code.** Accepted. And if
  the game is a miserable 14-FPS slideshow when he boots it — **THAT IS THE FINDING**, and it is worth
  more than a tenth step.
- **The 10-line paddy fix gives him UGLY PADDIES** — flat-ish cells, pans floating 5 cm proud, on a map
  that was never shaped for rice. Some will look wrong. **That is the cost, and it is the RIGHT cost** —
  because he can then *point at the ugly one and say what he actually wants*, instead of four architects
  guessing at a terracing algorithm for a field that has never existed.
- **Cutting the field-pass loses the best idea in the decree** — *"a paddy is not a cell type, it is a
  SITE, and it is the reason there is water there."* That is genuinely beautiful design. **It is not
  dead. It is BLOCKED — on twenty minutes of the Summoner standing in a rice paddy.**

---

## THE VERDICT

**DO NOT WRITE A 10-STEP PLAN. WRITE A 4-STEP ONE, AND MAKE STEP 0 THE THING THAT HAS BEEN OVERDUE FOR
FOUR DAYS.**

> **0. PLAY IT.** `ida9`, scale 1.0, renderer A/B, FPS overlay, §4's ladder pre-committed. One session.
> **1. MAKE THE PADDIES EXIST.** ~10 lines. Normalise the elevation band; add `RICE_PADDY` to the
>    riparian skip. Delete the three stale comments in the same commit.
> **2. KILL THE `randf()`s.** Or better — **delete `has_line_of_sight()`**, which nothing calls. A P0
>    GATE bead goes green for the price of a deletion.
> **3. TRUNK COLLIDERS** — *if and only if* the ladder permits, and *after* `2v3t` and `eaqv` stop
>    contradicting each other.
>
> **Everything else — the terracing, the bunds, the `water_map` stamp, the field pass, the probe
> rescoping — waits for a man who has actually stood in the field.**

*The Council advises. The Summoner decides.*
