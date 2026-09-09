# The firebase should be a stamped kit, not one baked scene

**Summoner, 2026-09-09:** *"i also think i need to totally rework the whole firebase and make it less
a circle but a bunch of modular parts i can stanmp into the terrain itself to make more natural
feeling bases"*
and, immediately after: *"but weve proved alot of elemnts within the blender build"*

**POST-DEMO. Recorded as intent, not authorised.** Nothing starts without his word.

## He already ratified this idea three days ago — for villages

**ADR-041, 2026-09-06: "The scene is a PLAN, not a prefab."** Its own opening quotes him:

> *"would it be better to make the village and temple stamps in godot as scene and than in the map it
> makes a flat zone for the places? that way i can make sure the spawns are right etc?"*

Its context line: *"every expensive defect closed was a PLACEMENT defect — invisible in Blender,
obvious in Godot with a baked navmesh."* Status: ACCEPTED as canon, **POST-DEMO, BUILD NOTHING** — his
ruling mid-council, *"i guess this is post demo work."*

**This is the same ADR, extended from villages and temples to the firebase.** The title already states
the fix.

## THE KIT IS PROVEN. THE ASSEMBLY IS THE DEFECT.

His point stands and it is important: the Blender build proved the elements. The hooch is good, the
bunker is good, the parapet is good, the interiors are good. **Nothing below is an argument against
the parts.** Every one of them is an argument against baking 5,812 nodes into one flat scene.

**Tonight's evidence, all of it assembly-level:**

| Defect | Why it is an assembly defect |
|---|---|
| **The siege never breached** | 80 of 81 wall segments carry **no node transform** — geometry baked into vertices — so the loader seated every wall at the model root. Fourteen sappers all targeted 256,256. A stamped segment has its own transform by construction and this bug cannot exist. |
| **Load-time repair every boot** | 86 collider re-meshes, 1,985 winding flips, 545 visibility ranges, per-character mesh hides. The code says it itself: *"When the re-exported GLB lands both counts come back 0 and this whole function is deleted."* The game patches an export at runtime because it cannot fix one. |
| **229 unmatched ballistic families** | Names accreted from several generator tools into one bake. A stamped kit classifies once, per part. |
| **The chow hall is bulletproof** | Merged in later by `merge_chowhall_to_firebase.py` *"under names no contract knows."* |
| **`fb_aid_station` matches zero nodes** | The asset was renamed to `medical_complex` inside the bake and the prefix was left pointing at nothing. |
| **`fb_sbg_seg_046_001`** | A Blender `.001` duplicate, invulnerable among 80 destructible twins. |
| **`us_fb_ammo_crate_stack-colonly_P2`** | `-colonly` not at the end of the name, so it shipped as a visible mesh with a collider built for the collider. |
| **488 work markers, 23 staffed** | A compound authored for a garrison several times the size that fills it — a consequence of designing the whole base as one artefact. |
| **45% of draw calls for 4% of geometry** | 545 interior props, every one its own mesh in the monolith. |

**Every single one is a defect of assembling the base as ONE OBJECT. Not one is a defect of a part.**

## What "less a circle" buys, beyond the bugs

A stamped kit is not only cleaner, it is the thing that makes bases feel found rather than placed:
terrain-driven shapes instead of a ring, bases that differ from each other, a firebase that fits the
hill it is on. It also feeds **ADR-039** (zones, one builder) and **ADR-028** (one world build path).

## Does this waste the re-export running tonight?

**No.** The re-export swaps 14 baked card groups for real meshes inside the current monolith and it
serves the DEMO, which ships before any of this. When the kit rework happens the parts carry forward —
that is the point of his "we've proved a lot of elements." What gets thrown away is the bake, not the
work.

## Open questions for whenever this is authorised
1. Stamp granularity — per building, per wall segment, per emplacement?
2. Does the perimeter become procedural, or authored per site from a segment set?
3. Do work markers move onto the parts they belong to? That would make the 488/23 mismatch impossible
   by construction.
4. What happens to `gen_firebase_v3.py` — retired, or repurposed as the kit exporter?

---

# THE TOOL — and why it pays twice

**His, 2026-09-09, verbatim:**

> "like if i could have a tool with teh terrain engine that lets me morph and cut shit and than i can
> use the godot model placement after we make real working modualr parts like trenches and bunkers and
> re use the hooches and other things weve made as like building sets than i could make better
> firebases in the game world"

> "and we could use that to make ww1 battlefields too"

## The whole proposal, in his order

1. A **terrain morph/cut tool** wired into the terrain engine — shape the ground first.
2. **Godot's own model placement** on top of it — place, look, adjust, in the engine that renders it.
3. **Real modular parts**: trenches and bunkers built as modules, with the hooches and everything else
   already made reused as **building sets**.
4. Result: **better firebases, authored in the game world instead of baked in Blender.**
5. **And the same tool builds WW1 battlefields.**

## THE TERRAIN DEFORMATION ALREADY EXISTS. This is exposure, not invention.

This is the part worth knowing before anyone estimates it:

- **`DamageSystem.modify_terrain()` already edits the heightmap and rebuilds chunks.** It is what cuts
  craters at runtime. Measured tonight: the heightmap edit itself costs **0.1 ms**; the 80–94 ms is the
  chunk rebuild around it.
- **`ClearingSystem` already exists** — terrain clearing is a shipped system.
- **`TerrainEngine` is 691 lines** and owns the grid.

So "a tool that lets me morph and cut" is **surfacing machinery the game already runs every time a
shell lands.** And an authoring tool does not have to be fast — the 80–94 ms rebuild that is a defect
at runtime is irrelevant at edit time. **The expensive part of the crater system is free in an editor.**

What is genuinely missing is the **trench module**. A trench is cut ground plus revetment, duckboard
and firestep — the cut half already exists, the parts half does not.

## Why it pays twice — and this is the strongest argument for building it

A **WW1 battlefield is cut terrain plus trench modules and shell holes.** That is the same tool's
output with a different kit. Nothing else about it changes.

So one tool serves:
- the firebase rework (post-demo, ADR-041's "scene is a PLAN, not a prefab", extended)
- every future firebase and camp, authored in-engine where placement defects are visible
- **the WW1 battlefields the comic adaptation needs** — and per ADR-039, a WW1 zone is exactly what
  zones-with-loading-screens are for

A tool that only built firebases would be hard to justify before launch. A tool that builds firebases
**and** the second war is a different proposition.

## Why in-engine placement is the right call, in this project's own evidence

ADR-041's context line, from three days ago: *"every expensive defect closed was a PLACEMENT defect —
invisible in Blender, obvious in Godot with a baked navmesh."* Sixteen chow-hall work markers off the
navmesh so the cook could not stand at his own stove. Bunker markers at exactly the player capsule's
radius from their own wall. Furniture with no building around it.

**Placement is only true where the navmesh is.** That is the argument for authoring in Godot, and it
is his, already ratified.

## Still POST-DEMO. Recorded, not authorised.

Open questions when it is: does the tool run in the Godot editor or as an in-game dev mode; does a
stamped base bake down for ship or stay data; and do work markers ride on the parts (which would make
the 488-markers-23-staffed mismatch impossible by construction).
