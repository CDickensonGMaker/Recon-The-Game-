# WAR ROOM BRIEFING — THE DESTRUCTIBLE JUNGLE

**Convened:** 2026-07-12 · **Summoner:** Caleb · **Arbiter:** recon-overseer
**Query:** *"look for the destructible jungle plan and do your part of the deal there — using the war room
to think it through."*

**The deal:** two windows in parallel. The **Blender window** owns `tools/make_jungle_*.py`, the GLB
exports, and `patches.json`. **This window owns all GDScript.** They meet at three contracts
(`DESTRUCTIBLE_JUNGLE_PLAN.md` §0).

---

## The plan under review

`production/DESTRUCTIBLE_JUNGLE_PLAN.md` — five phases:

| Phase | What |
|---|---|
| **0** | Verify the (unrun) paddy code · **0B: "the one-word bug"** · calibrate art vs sight-cap |
| **1** | **Trunk colliders** — "cover that lies": nothing in the game has collision on vegetation |
| **2** | **Destructible trees** via an `INSTANCE_CUSTOM` bitmask + a vertex shader that collapses dead trees (never touch geometry — a tree is welded into a merged 12m patch mesh drawn 40× per chunk) |
| **2b** | The **fall** (scripted hinge, kills what's under it) and the **permanent log** (hard cover the player BUILDS) |
| **3** | **Blow your own LZ** — fell the canopy, call the bird into the hole you made |
| **4** | **Destructible buildings** — authored pre-fractured swaps (BFBC2 was never procedural either) |

---

## THE ARBITER'S OWN FINDINGS, BEFORE THE COUNCIL SPOKE

The verification law binds the Arbiter too. Both of these were **measured, not assumed**:

### FINDING 1 — the bug is REAL, and worse than the plan states
- `get_density_at` **does not exist anywhere in the codebase.** The guards at
  `gameplay_grid.gd:154` and `:580` are **permanently false**.
- The real method is **`ClearingSystem.get_vegetation_density(world_pos: Vector3)`** — so it is **not a
  one-word rename. The call signature differs too** (the plan calls it "the one-word bug").
- **`mark_cleared()` — the only code that ever writes `TerrainType.CLEAR` and density 0.0 — is called by
  nothing.**
- `ClearingSystem` **is** live and wired (`game_world.gd:161`). So the breakage ships.

**Consequence, as the plan says:** every LZ is a lie. `stamp_lz()` deletes the plants visually while the
grid still reports jungle, so `enemy_base._sight_cap()` gives the AI **45m in a bald 16m clearing.**

### ⚠ FINDING 2 — **THE PLAN'S PRESCRIBED FIX IS A LANDMINE**

```gdscript
# clearing_system.gd:81
vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))  # Full vegetation
```

**`ClearingSystem`'s map is initialised to 1.0 EVERYWHERE and is only ever LOWERED by clearing zones
(`:242`). It is NEVER populated from the actual terrain.**

So the fix the plan prescribes — swap `get_density_at` for `get_vegetation_density` at 2 sites — would make
**every cell on the map return 1.0**:

- a **45m sight cap EVERYWHERE** — open paddy, grassland, river, bald clearing, all of it triple canopy
- the entire **biome variation erased**
- this morning's **gallery forest and roofed creeks silently overridden**

**The correct fix is a MERGE, not a replacement.** ClearingSystem only ever *subtracts* vegetation, so it is
a **minimum**, never a source of truth:

```gdscript
var d: float = _estimate_vegetation(ttype)                    # biome truth
if clearing_system and clearing_system.has_method("get_vegetation_density"):
    d = minf(d, clearing_system.get_vegetation_density(Vector3(world_x, 0.0, world_z)))
vegetation_density[idx] = d
```

Uncleared cells `min(biome, 1.0)` = **biome, untouched**. Cleared cells `min(biome, 0.0)` = **zero.**
**LZs become real without nuking the world.**

*The plan was written with confidence and it was wrong about the single fix it called highest-value. This is
the third time today that reading the code beat trusting a document — and the reason the verification law
exists.*

---

## THE QUESTIONS PUT TO THE COUNCIL

**Technical Director** — does the `INSTANCE_CUSTOM` bitmask actually work in Godot 4.7 (float32 precision,
shader access, `use_custom_data`)? Is one `StaticBody3D` per chunk with many `CylinderShape3D` children
really cheaper? Trunk colliders on layer 1 also block **AI line-of-sight rays** and **blast raycasts** — is
that all desirable? Is there a simpler approach? Biggest technical risk?

**Godot Specialist** — the plan makes **ten specific factual claims** about the codebase. Verify each against
source, TRUE/FALSE, with `file:line`. Which wrong claims **change the plan**?

**Game Designer** — **THE CRUX: destroying jungle destroys the player's own concealment.** Felling trees
lowers `vegetation_density`, which *raises* the enemy's sight cap. Is "the player can burn down his own
cover" a great tension or a trap — especially against the **HUNT** (a net that chases at 169m/min) and the
Summoner's stated fantasy (*"chased by 1000 men with 6 people in their squad. AND MAKING IT OUT ALIVE"*)?
What new verbs does this really give? What is decoration?

**Devil's Advocate** — **is this in scope at all?** GAME_GUIDE §6.0 declares THE SLICE and destructible
jungle is **not in it**. The Summoner's own diagnosis of the rival game was *"expanding the content too much
and not making a good game."* Make the strongest case for **cutting it entirely**. Then: what does blowing
your own LZ do to the heat-scaled exfil? Can a player wall himself in with logs? What happens when a falling
tree kills his own squadmate?

---

*Analyses land in `production/war_room/analysis/dj_*.md`. Synthesis to follow. The Summoner holds final
authority.*
