# THE ARBITER'S OWN SIGHT — five things no architect was assigned

Written during INDIVIDUAL SIGHT, before the debate. Everything here is verified by direct read this
session. Where I could not measure I say so.

---

## 1 · THE KIT HE IS ASKING FOR WAS ALREADY DESIGNED, AS DATA, ON 2026-07-26

`assets/world/building models/structures/firebase/kit/firebase_set.json` — 6,846 bytes, **23 parts**,
each carrying `tris`, `size`, `solid`, `enterable`, and a **`markers` array whose entries carry
`work_type`, `prop_class`, `door_width`, `face` and local `pos`.**

His ask, verbatim: *"individual model builds with the work points and animations saved to those
locations."* **The work points half already exists in exactly that shape.** Measured:

| part | tris | solid | enterable | markers | work_type | prop_class |
|---|---:|---|---|---:|---|---|
| `fb_aid_station` | 3,516 | yes | yes | 2 | `medic` | — |
| `fb_berm_arc` | 72 | yes | no | 0 | — | — |
| `fb_bunker_fighting` | 2,884 | yes | yes | 1 | — | — |
| `fb_bunker_mg` | 3,800 | yes | yes | 3 | `mg` | — |
| `fb_burn_barrel` | 48 | no | no | 0 | — | — |
| `fb_claymore` | 36 | no | no | 0 | — | — |
| `fb_gate_gap` | 2,606 | yes | no | 3 (`SOCKET_A/B`, `FACE_OUT`) | — | — |
| `fb_gp_tent` | 888 | no | yes | 2 | — | `sleep` |
| `fb_gun_pit` | 4,860 | yes | no | 1 | `gun` | — |
| `fb_helipad` | 192 | yes | no | 1 | — | — |
| `fb_hootch` | 2,644 | yes | yes | 2 | — | `sleep` |
| `fb_howitzer` | 288 | yes | no | 0 | — | — |
| `fb_latrine` | 132 | yes | no | 0 | — | — |
| `fb_mess` | 528 | yes | yes | 2 | `cook` | — |
| `fb_mortar_pit` | 1,944 | yes | no | 1 | `gun` | — |
| `fb_sandbag_stack` | 240 | yes | no | 0 | — | — |
| `fb_sleeping_bunker` | 3,002 | yes | yes | 2 | — | `sleep` |
| `fb_supply_dump` | 3,152 | yes | no | 1 | `carry` | — |
| `fb_toc` | 4,780 | yes | yes | 3 | `radio` | `furniture` |
| `fb_tower` | 4,348 | yes | no | 1 | — | — |
| **`fb_trench_run`** | **240** | yes | no | 0 | — | — |
| `fb_water_point` | 48 | yes | no | 1 | `water` | — |
| `fb_wire_belt` | 144 | no | no | 0 | — | — |

**`fb_trench_run` exists.** `FIREBASE_REWORK_INTENT.md` names the trench module as *"what is genuinely
missing."* That is **half wrong** — a trench RUN part exists at 240 tris. What is missing is the
revetment/duckboard/firestep dressing and a way to lay a run along a drawn line. Correct the intent doc.

**NOTHING READS THIS FILE.** Repo-wide grep for `firebase_set`: exactly one hit,
`tools/gen_firebase.py:932`, which **writes** it. It is a fossil manifest — and it is the schema of
the thing he just asked for.

## 2 · THE KIT WAS REFUSED IN JULY FOR A REASON THAT THE PIVOT REMOVES

`tools/gen_firebase.py:1-13`, verbatim:

> *"the kit GLBs it can write are a REVIEW artefact, not a shipped asset set — nothing in the game
> places a firebase piece individually (`site_layouts.gd` has no firebase entries and `stamp_firebase`
> died with `fsb_main`), so shipping 24 kit GLBs would be **24 files with one consumer, which ADR-023
> would correctly come for**."*

**The kit was killed by the fossil law because it had no consumer.** The pivot supplies the consumer.
This is the strongest canon-grounded argument FOR the pivot in the whole project, and it is the
project's own words, not an advocate's. It also means the reverse is still true: **authorise the
consumer or the kit is a fossil again.** Parts without a placer are 23 files ADR-023 comes for.

Seven kit GLBs are already exported and imported: `fb_bunker_fighting.glb` (142 KB),
`fb_bunker_mg.glb` (684 KB), `fb_gate_assembly.glb` (38 KB), `fb_sandbag_heavy.glb` (23 KB),
`fb_sandbag_light.glb` (27 KB), `fb_FoxholeSandbags.glb` (22 KB), `fb_emplacement_m101.glb` (14.6 MB).

## 3 · THE STRANGLER MECHANISM IS ALREADY IN PRODUCTION — ONCE, AND IT WORKS

`SitePlanner._wire_m101_rigs()` (`scripts/world/site_planner.gd:846-866`) does **exactly** what a
part-by-part migration needs, and it shipped:

1. finds the baked node in the monolith by name (`find_children("m101_emplacement*")`),
2. **hides it, never frees it** — *"its `-colonly` colliders are scene-root siblings that stay live,
   and the chunk carries visuals only,"*
3. instances a **separate kit GLB** and sets `inst.global_transform = baked.global_transform`,
4. hides the chunk's own baked crew so the real garrison plan seats men at the markers,
5. `push_warning` if zero nodes matched — *"export drift"*.

**Generalise this one function and you have the migration.** `_swap_kit_part(family, kit_path)` is
`_wire_m101_rigs` with the family as a parameter. The demo stays playable at every step by
construction, because a part that has not been migrated is simply not hidden.

**The honest limit, stated so nobody oversells it:** this swaps **visuals only**. The bake's colliders
stay live, so it does NOT by itself fix a collision defect, a collider-shaped stuck spot, or the
82 cm floating fixtures. Replacing collision too means freeing the baked `-colonly` siblings in the
same pass, which is the harder half and where the risk lives.

## 4 · THE DOCKING POINT ALREADY EXISTS AND IS ALREADY ON THE ONE BLESSED PATH

`const FSB_MAIN_PATH := "res://scenes/world/firebase_main.tscn"` (`site_planner.gd:946`). The game
does **not** load the GLB directly — it loads a 13-line scene that instances the GLB and carries
hand-placed `Marker3D` siblings. The file's own comment (`site_planner.gd:935-945`) records the
2026-07-29 ruling and the crucial property:

> *"those markers live in the SCENE, not in the GLB, so re-exporting `fsb_main_v3.glb` from Blender
> can never delete them. **Anything hand-placed in the compound belongs in that scene for the same
> reason.** ... One world-build path (ADR-028) is untouched: the build instances this scene exactly
> where it used to instance the GLB."*

**A kit part added as a sibling in `firebase_main.tscn` needs no new placement path.** ADR-028 is not
an obstacle to the pivot; it is already satisfied by the shape that shipped in July.

## 5 · THE DIRT ROADS ARE INVISIBLE BY DESIGN, AND THE CHEAPEST FIX IS A `match` ARM

**Verified, and it contradicts a canon claim.** `GAME_GUIDE.md:388` says `plan_demo_world` stamps
*"paddy fields, a road net and 2–3 landmark craters."* A road net is **planned** — but:

`scripts/missions/mission_generator.gd:910-915`, verbatim comment:

> *"The only write a road performs: vegetation bundles thinned along the corridor — **never height,
> never terrain_type, never water.**"*

So `RoadNetwork` (`scripts/world/road_network.gd`) builds a real graph, routes gate → villages
(`:646-653`), the convoy drives `longest_route()` (`mission_generator.gd:339-351`, with
*"no road, no convoy — a truck does not drive through jungle"*), and its **entire visual manifestation
is a gap in the trees.** He has never seen a dirt road because **there is no dirt, only an absence of
jungle.** Classification: **content that was never built** — the routing exists, the surface does not.

**And the surface is nearly free, because the terrain is already vertex-coloured by terrain type.**
`terrain/core/terrain_chunk.gd:263-279`, `_get_terrain_color()`, is a `match` on a per-bundle type byte
with exactly two special cases today:

```gdscript
match terrain_type:
    1:  # RICE_PADDY
        return Color(0.42, 0.58, 0.22)
    5:  # HEAVY_JUNGLE
        return Color(0.10, 0.22, 0.07)
# UNIFORM BASE GREEN - no height variation
return Color(0.18, 0.35, 0.12)
```

A `DIRT_ROAD` type written along the corridor `clear_corridor` already walks
(`road_network.gd:383`) gets a visible track through the existing colour path — **no mesh, no splat
map, no texture, no draw call.** And because the convoy drives the same graph, **the road appears
exactly where the traffic is**, which is the atmospheric win; a road that goes nowhere is worse than
none.

> **BLOCKED TONIGHT, ON PURPOSE.** The type enum lives in **two** places —
> `terrain/core/gameplay_grid.gd:15` and `terrain/vegetation/vegetation_manager.gd:6` — and
> `vegetation_manager.gd` is **owned by a live agent tonight**. This is phased, not built. It is also
> a two-enum drift worth naming under NO MORE DRIFT.

> ## CORRECTION TO §5, MADE BY THE ARBITER AGAINST HIMSELF, SAME SESSION
>
> **Everything above about "the cheapest fix is a `match` arm" is WRONG, and it was wrong in a way I
> would have shipped.** Two facts I had not read when I wrote it:
>
> **(a) The road ALREADY paints dirt, and has since 2026-08-12.** `road_network.gd:383-405`
> `_stamp_dust()` tints `ROAD_DUST = Color(0.42,0.35,0.24)` at strength 0.72 in a 10 m band into the
> `ClearingSystem` ground overlay, which `terrain.gdshader:104-106` already mixes per pixel
> (`color = mix(color, clearing.rgb, clearing.a)`). Commit `85ab41cf`, *"STEP 29: roads wear dust into
> the ground, using the splat that already existed."* **And it ran today** —
> `[ROADS] dust stamped on 163 segment line(s)` in `recon2026-09-09T13.39.43.log`. So the
> classification is **BUG NEEDING INVESTIGATION**, not content never built. I had read a stale comment
> and stopped.
>
> **(b) `TerrainType.ROAD` was already proposed and REFUSED, with two hard blockers named.**
> `road_network.gd:18-22`, which I should have read before proposing it:
> *"NO `TerrainType.ROAD`. The enum has two hard blockers: `TerrainZoning.configure()` runs at
> world-build step 2, but the sites a road connects do not exist until step 7 — the mask would be
> empty at classify time — and a road member in `GameplayGrid`'s enum alone fails
> `tests/test_one_classifier.gd` against `VegetationManager`'s parallel 6-member enum."*
>
> **The two-enum drift I flagged as a NO MORE DRIFT find is not drift — it is a guarded invariant with
> a probe holding it** (`tests/test_one_classifier.gd`). Withdraw that finding too.
>
> **The lesson, recorded because I am subject to my own law:** I found a real defect, then invented a
> fix for it out of a `match` statement without reading the module header of the file I proposed to
> change. The header answered me in advance, in the negative, with reasons. **Two of my three §5
> conclusions were wrong and the story they told was cleaner than the truth — which is the exact
> failure mode "publish only what I checked" names.** What survives is the finding that he has never
> seen a road and that this is a real, open, investigable defect. That was worth having. The fix I
> attached to it was not mine to invent.
>
> The two stale comments this exposed are now corrected at `mission_generator.gd:911-915` and
> `road_network.gd:26-38`.

**UNVERIFIED:** whether the road corridor is wide enough to read as a track at player eye height, and
whether `vegetation_terrain` is sampled per bundle at a resolution that can express a ~4 m corridor —
`bundle_meters = chunk_size / bundles_per_chunk` (`terrain_chunk.gd:265`) must be measured before
anyone promises this. **If a bundle is wider than the road, the road will be a stripe of the wrong
width or will not appear at all.** Measure before building.

## 6 · A SCOPE CONFLICT ONLY HE CAN RESOLVE

**He asked for convoy work tonight. His own ruling PARKED it.**
`GAME_GUIDE.md:326` PARKED list: *"convoy that forms up and drives out (his ruling 2026-08-28)"*, and
`PLAYTEST_FINDINGS_2026-08-28.md:338`: *"35. [PARKED - POST DEMO] Real convoy that forms up and drives
out. **Your ruling 2026-08-28: 'and same with the convoy.'** Build nothing."*

But `scripts/vehicles/convoy.gd` and `convoy_spawner.gd` **exist and run today**. So there are two
different things wearing one word, and the council must not merge them:

- **the PARKED thing** — a convoy that forms up at the base and drives out as a set piece;
- **the LIVE thing** — the ambient convoy already driving `road_network.longest_route()`, which is
  what he actually just watched and disliked.

**Polishing the ambient convoy is a bug fix and is GATE-EXEMPT. Building the form-up convoy is a
thawed epic and is not.** This is his call and it must be put to him in exactly those words.

## 7 · ONE MORE CANON CORRECTION ON CONTACT (NO MORE DRIFT)

`GAME_GUIDE.md:388` lists a "road net" among what `plan_demo_world` stamps, in a sentence whose point
is *"The AO is NOT bare."* A routing graph that only thins trees is not what a reader takes from that
line. **The line is not false, but it reads as a promise the world does not keep**, and it is exactly
how observation 5 stayed invisible for a month. Annotate it in the same change that records this
council.
