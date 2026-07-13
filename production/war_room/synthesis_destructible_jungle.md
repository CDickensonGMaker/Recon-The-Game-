# DECREE — THE DESTRUCTIBLE JUNGLE

**Convened:** 2026-07-12 · **Summoner:** Caleb · **Arbiter:** recon-overseer
**Council:** Godot Specialist · Game Designer · Devil's Advocate · Technical Director *(all four reported)*
**Matter:** `production/DESTRUCTIBLE_JUNGLE_PLAN.md` (355 lines, 5 phases)

> ## THE DECREE, IN ONE LINE
> **BUILD THE BUG FIXES. CUT THE FEATURES. The subset that survives is composed *entirely* of bug fixes,
> and that is not a coincidence — it is the tell.**

---

## 1 · THE THREE ARCHITECTS CONVERGED WITHOUT CONFERRING

They were summoned in parallel with no cross-talk. They arrived at the same place from three different
doors, which is the strongest signal this process produces.

| Architect | Their door | Where they landed |
|---|---|---|
| **Devil's Advocate** | *procedure* | The plan is **mechanically FORBIDDEN**. Build only the bug fixes. |
| **Game Designer** | *fun* | The one thing worth building is **Phase 1, trunk colliders**. The rest is a trap **today**. |
| **Godot Specialist** | *the code* | The plan's own **highest-value fix is a LANDMINE**. |
| **Technical Director** | *the engine* | **REWORK.** Same landmine, found independently — **plus two live bugs and a wrong contract.** |

---

## 2 · THE KILL SHOT (Devil's Advocate) — and the Arbiter upholds it

**`RECONgame-97u3` — "GATE: playtest P1s block feature epics (ADR-015)" · P0 · OPEN.** Verified live this
session. Its own description:

> *"Exempt: **bug fixes**, presentation for shipped systems, decree items. Born from audit #2: the
> markdown-only gate law of 07-09 was violated **within ~2 hours**."*

**GAME_GUIDE §8, build-order item ZERO:** *"PLAYTEST R3 is the session entry point — nothing NEW ships
until it verifies a2qb/r4bk."*

Destructible jungle is a **feature epic**. The gate is **red**. The plan is 355 lines long and **cites the
canon zero times** — not one ADR, not a pillar, not THE SLICE.

The Devil's Advocate's sharpest sentence, and the Arbiter will not soften it:

> **"DESTRUCTIBLE JUNGLE IS BLOOD V2 IN A NEW COAT."** *ADR-015 exists because a beautiful system shipped
> straight through the last gate. The gate was made mechanical precisely so the next time would be caught.
> **This is the next time. The mechanism works. Let it work.**"

**And the opportunity cost, stated plainly:** four of the five open P0s **ARE THE SLICE** (`clm4`,
`p3f4`, `6mba`, `5i8a`). And **`r4bk` is open — F1–F4 do nothing. Pillar 4 is "the squad is the RPG,"
the player cannot command his squad, and we are debating a shader bitmask for felling trees.**

---

## 3 · ⚠ THE LANDMINE — the plan's own highest-value fix would have broken the game

*(Found independently by the Arbiter and confirmed by the Godot Specialist.)*

The plan calls 0B **"THE ONE-WORD BUG — the single highest-value fix in this document."** The bug is real.
**The prescribed fix is not.**

```gdscript
# clearing_system.gd:81
vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))  # Full vegetation
```

`ClearingSystem`'s map is initialised to **1.0 everywhere** and is only ever **lowered** inside a clearing
zone (`:242`). **It is a CLEARING MASK, not a density — it is never populated from the terrain.**

Do what the plan says — swap `get_density_at` → `get_vegetation_density` at 2 sites — and **every cell on
the map returns 1.0**:
- a **45m sight cap EVERYWHERE**: open paddy, grassland, river, bald clearing, all triple canopy
- **every biome erased**
- **this morning's gallery forest and roofed creeks silently overridden**

It is also **not a rename**: `get_vegetation_density(world_pos: **Vector3**)` takes one Vector3; the call
sites pass **two floats**. A literal rename is a runtime arity error, per cell.

### THE CORRECT FIX — a MERGE, not a replacement
Clearing only ever **subtracts**. It is a **minimum**, never a source of truth.

```gdscript
var d: float = _estimate_vegetation(ttype)                        # biome truth
if clearing_system and clearing_system.has_method("get_vegetation_density"):
    d = minf(d, clearing_system.get_vegetation_density(Vector3(world_x, 0.0, world_z)))
vegetation_density[idx] = d
```

Uncleared: `min(biome, 1.0)` = **biome, untouched.** Cleared: `min(biome, 0.0)` = **zero.**
**Every LZ becomes real without nuking the world.**

---

## 4 · THE CRUX (Game Designer) — and why it BLOCKS the feature, not just delays it

**Destroying jungle destroys the player's own concealment.** Felling trees lowers `vegetation_density`,
which *raises* the enemy sight cap. The Designer calls this *"the most on-theme thing anyone has proposed
for this game — your own HE is a defoliant"* — and then kills it, correctly:

> **The player has ZERO affordance for `vegetation_density`.** Every felling tool is a bang (M79/LAW/RPG),
> fired *at men, in firefights* — so destruction is overwhelmingly **incidental**, and he will **never once
> connect** *"I shot that bunker"* to *"I got seen at 110m forty seconds later."*
>
> **By the r4bk Law, concealment does not currently exist. And this plan lets him destroy it.**

**This binds 0B as well:** repairing LZ density makes the game harder *in a way the player cannot perceive.*
**It is still correct** — a lying grid is worse than a hard one — but the **concealment readout is now a
first-class debt**, and it is beaded.

---

## 5 · THE ARBITER'S CORRECTIONS TO HIS OWN COUNCIL

The verification law binds the council too. **Three of their claims are wrong**, and the Arbiter will not
enter a wrong finding into canon:

| Claim | Ruling |
|---|---|
| **DA + Specialist:** *"`m79.tres` base_damage 150 vs ADR-016's 44 — a canon violation."* | **FALSE.** **ADR-016 line 178** carries the Summoner's own **explosive-lethality amendment**: *"M79 HE **150** (44)."* 150 **is** canon. Line 32 is the superseded original table. **Do not "fix" it.** *(The empty `projectile_data_path` IS a real bug.)* |
| **The plan + DA:** *"`vc_hut_bunker.glb` is shootable through."* | **The file does not exist.** The example is invented. **The real victims, verified on disk:** `barracks_bunker.glb` and `french_barracks.glb` (match **"rack"**), `quonset_hut.glb` (matches **"hut"**), `bomb_crater.glb` (matches **"crate"**) — and **`us_halftrack.glb`, an ARMOURED VEHICLE, is soft cover because it contains "rack."** The footgun is real and **worse** than advertised. |
| **Game Designer:** *"Does the jungle regrow? Undecided — 40 missions of RPGs deforest the province."* | **Already law. ADR-019: "DESTRUCTION IS TEMPORARY. ATTRITION IS PERMANENT."** The jungle regrows on the campaign clock exactly as VC bases rebuild. The question is answered; it must simply be *obeyed* when Phase 2 ever thaws. |

### ⚠ THE TECHNICAL DIRECTOR'S THREE BLOCKS — all upheld, all found by reading the engine

**(a) A LIVE SHIPPING BUG NOBODY KNEW ABOUT — one grenade turns authored jungle into procedural palms.**
`vegetation_manager.gd:766-771` — `clear_area()` calls `clear_chunk_visuals()` (which kills the patch
MultiMeshes at `:870`) and then unconditionally runs `_materialize_vegetation()` — **the LEGACY procedural
palm path** — and **never re-runs `_patch_layer.generate_for_chunk()`.** So a single explosion converts a
**256m chunk of the authored jungle into procedural palms**, and it fires on **every `SitePlanner` stamp**
too (`site_planner.gd:87`). **This is a bug fix, it is GATE-EXEMPT, and it is now in the BUILD list.**
*(It also makes Phase 2 untestable: its registry keys on `instance_idx`, which every chunk rebuild
re-shuffles.)*

**(b) PHASE 1 IS NOT AS SIMPLE AS THE PLAN SAYS — and the plan would place the colliders WRONG.**
- **~14,000 cylinders** across the AO (measured ~570/chunk × 25). `_move_toward()` (`enemy_base.gd:1703`)
  only uses the navmesh **inside NavBaker's 70–140m site islands** — so across **~95% of the AO** enemies
  *and the player's own squad* bee-line on `move_and_slide()`. **14k cylinders will grind them.**
- **One body per CHUNK is wrong. One body per SUBCELL** (`jungle_patch_layer.gd:94`, already bucketed at
  `:315`). Jolt makes the one-body claim true in steady state but **worse on mutation** — a compound
  rebuild per tree death.
- **THE PLAN OMITS SCALE JITTER.** `jungle_patch_layer.gd:296` jitters each tile **0.92–1.10**, which
  offsets a collider by **up to 0.6m — wider than the tree itself.** Follow the plan literally and the
  colliders do not line up with the trunks.

**(c) THE §0 CONTRACT IS WRONG ON DISK — it would fell the wrong tree.** The plan says slot `0..23` and
`COLOR.b == (slot+1)/24`. **On disk:** `patches.json` has slot **1..5**, and `make_jungle_flora.py:213`
writes `b = slot / MAX_TREES` — **no `+1`.** Following the document literally checks **the wrong bit**.

**(d) THE SIMPLER APPROACH THE PLAN MISSED.** The standalone `felled_tree.glb` it already commissions
could be **its own per-subcell MultiMesh** — then **a tree is one instance**. No shader, no
`INSTANCE_CUSTOM`, no `COLOR.b` contract, no off-by-one — **and a dead tree's triangles actually
disappear** instead of being vertex-collapsed forever. *If Phase 2 ever thaws, start here.*

**A further finding, from the Specialist, is upheld and is a genuine save:** each patch is instanced
**TWICE** (near + far LOD, `jungle_patch_layer.gd:341,349`). Any future bitmask **must flip both MMIs** or
felled trees **pop back when the player backs off** — and `COLOR.b` must be verified to survive the far
mesh's decimation. That bug would have shipped.

---

## 6 · THE DECREE

### ✅ BUILD NOW — every item is GATE-EXEMPT as a bug fix

| # | Item | Why it is exempt |
|---|---|---|
| **0B** | **The density MERGE** (§3 — *not* the plan's replacement) + regression probe | The AI is **blind inside every LZ we ship** — `_sight_cap()` reports 45m in a bald 16m clearing. **Live Pillar 1 + Pillar 2 bug.** |
| **VEG** | **`clear_area()` must rebuild the PATCH layer, not fall back to procedural palms** (TD block (a)) | **LIVE BUG.** One grenade turns 256m of authored jungle into palms. Fires on every LZ stamp too. |
| **1** | **TRUNK COLLIDERS** — **but built to the TD's spec, not the plan's**: `broadleaf_tree` only (r ≥ 0.20); **one body per SUBCELL**, not per chunk; **and it MUST apply the 0.92–1.10 tile scale jitter** or the colliders miss the trunks by up to 0.6m. Bamboo and palm get **none** — correct ballistics for free. **Measure the AI-pathing cost before shipping: ~14k cylinders, and 95% of the AO has no navmesh.** | **THE MOST BROKEN THING IN THE PROJECT.** In a jungle game, **the tree you dive behind does not stop a bullet.** The jungle is a hologram. Recipe exists (`gore_lab.gd:203`); `trees[]` already landed. |
| **1b** | **`logs[]` from `patch_deadfall`** — it already exists on disk ("blowdown: crossed logs") with **zero collision** | The Designer's find. **Prone hard cover ships for one array**, and it tests Phase 2b's entire thesis *before* anyone builds Phase 2b. |
| **M79** | Real `projectile_data_path`. **LEAVE `base_damage` AT 150** (§5). | The player's grenade launcher currently fires a **hitscan bullet with no explosion and no crater.** |
| **4-DATA** | `collision_table.gd`: add `material`. Demote `_SOFT_NAME_HINTS` to a **`push_warning()` fallback**. | **A bunker is shootable through because its name contains "rack." A halftrack is soft cover.** Data table. Cheap. VILLAGE RAID is 1 of the 3 slice mission types — **this lives inside the slice.** |
| **0C** | Calibration: stand in `patch_tangle`, look 45m | Free. No code. Pillar 2. |

**Three days. Four real bugs. Two pillars repaired. Zero new systems. Not one ADR amended.**
**And afterward the jungle has cover that does not lie — which is 90% of what a player would have *felt*
from this entire document.**

### ❌ CUT — until THE SLICE is proven

| # | Item | The single reason |
|---|---|---|
| **2** | Destructible trees (bitmask + `TreeRegistry`) | Feature epic behind a **red P0 GATE**. Not in THE SLICE. |
| **2b** | The fall · **the killing tree** · the permanent log | **The AI cannot use the log** — `_find_cover_point()` raycasts at **1.3m**; the log is **0.6m**. It fails the test **forever**. And logs are `nav_blockers`: **fell four trees and you have built a 360° Alamo the AI cannot path into, cannot use, and cannot grenade.** Escalation that cannot reach you is not escalation — **Pillar 5, dead.** Plus a permanent immovable 9.4m capsule can land on a cache or a tunnel mouth: **unrecoverable soft-lock, unaddressed in 355 lines.** |
| **3** | **Player-made LZ** | **IT DELETES THE THIRD ACT OF EVERY MISSION.** Exfil is a *place*; the run back with all your heat behind you is the mission's payoff, and `exfil_zone.gd:161-193` (wave-off → `fallback_pos` → `_is_final`) is its teeth. A printable LZ voids all of it: finish the objective, step into the treeline, fire three M79 rounds, **the bird lands on the objective.** *"The most damaging idea in the document — and it is presented as the payoff."* |
| **4** | The `Destructible` component itself | Feature. Gated. **But see the thaw.** |

### 🔓 THE FIRST THAW, when the gate goes green: **HUTS, NOT TREES**

Judged by *atmosphere-per-hour* (Pillar 2, and the tonal north star of **Platoon**): a hooch that takes a
grenade and becomes `burned_hut` + rubble is worth more than every falling tree in this document, costs a
**fraction** of the machinery — no shader, no bitmask, no registry, no fall system, no navmesh churn — and
**the art already exists on disk** (`burned_hut`, `ruin_house_half`, `rubble_pile`, `destroyed_bunker`…).

> **The Zippo raid is the iconic image of this war. A tree falling over is not.**

---

## 7 · WHAT THIS DECREE SACRIFICES (no free lunches — the law binds the Arbiter)

- **We lose the best idea in the plan** — *"your own HE is a defoliant; you strip the jungle to find them,
  and then YOU are the one standing in the open."* That is the most on-theme mechanic anyone has proposed
  for this game, and the Arbiter is putting it on ice. It is **not dead. It is BLOCKED — on a concealment
  readout** (r4bk), and on the gate.
- **The Blender window's `trees[]` and `COLOR.b` work is delivered and will sit partly unused** until
  Phase 2 thaws. Phase 1 consumes `trees[]` immediately, so it is not wasted — but `COLOR.b` waits.
- **Enemy mortars defoliating the jungle you are hiding in** (`mission_director.gd:381` is the *shared*
  arty path) is *terrifying, perfect, and free* — and it is deferred with Phase 2. **It must be decided
  deliberately when that day comes, never arrive by accident.**
- **The plan is excellent engineering.** Cutting it is not a judgment on its quality — and that is exactly
  what makes it dangerous. **A bad plan gets rejected on sight. A brilliant plan for the wrong feature is
  how you lose a year.**

---

## 8 · THE RECORD

**Fix the four bugs. Give the trees collision. Then go build the game.**

*The Summoner holds final authority. The Arbiter holds the pillars.*
