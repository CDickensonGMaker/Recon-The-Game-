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
