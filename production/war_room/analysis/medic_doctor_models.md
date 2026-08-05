# US Medic & Aid-Station Doctor — reconnaissance and recommendation

> **ADDENDUM 2026-08-03 23:05 — HANDED OFF MID-RECON.** Caleb took
> `us_base_v3.blend` into the live session to build the medical units and pilots
> himself. I stopped, wrote nothing to `assets/`, and deleted all working copies.
> Sections 9–11 below were added at handoff and **supersede section 1a's
> conclusion**: Caleb's memory of "a medic that used a cloth satchel bag" is
> CORRECT — the fabric satchel was really built, and its geometry has since been
> lost. See section 9.

**Date:** 2026-08-03 · **Agent:** blender-modeler · **Mode:** HEADLESS
(`blender -b --factory-startup -P`, Blender 5.0.1). The live session, the firebase
`.blend` and BlenderMCP were never touched. Nothing was written into `assets/`.
All build tests wrote to the session scratchpad and were deleted.

**Status: NO GEOMETRY COMMITTED.** This is reconnaissance plus one decision gate.

---

## 1. The brief's premise was wrong in two places — measured

### 1a. `us_medic_better textures.png` is NOT a bespoke medic skin

The brief said a medic texture exists "with no model on it — it may be the intended
skin." It is not. Measured by hash:

```
d9c1bfad1580aa27629d524e79d88d37  us/characters/us_medic_better textures.png
d9c1bfad1580aa27629d524e79d88d37  us/characters/us_grunt_grenadier_better textures.png
d9c1bfad1580aa27629d524e79d88d37  nva_vc/characters/nva_medic_better textures.png

e3f4be4cc8808f1daaf18cfe4c996264  us/characters/us_medic_usarmybitmap.png
e3f4be4cc8808f1daaf18cfe4c996264  us/characters/us_grunt_m14_usarmybitmap.png
```

Byte-identical across three different units and two factions. `..._better textures.png`
is a shared reference/atlas page that got copied out once per unit at export time. It
carries no medic-specific art.

The `us_medic_*` texture set is a **legacy orphan**, from the same era as these other
prefixes that also have no `.glb` on disk:

```
us_grunt_m14   us_grunt_m60   us_grunt_m79   us_grunt_v2   us_rto   us_medic
```

Only `us_medic_face_atlas_v3.png` is unique (`3f7a2775…` vs the grenadier's `955fa8b5…`),
and a face atlas is per-unit by construction — it says a `us_medic.glb` was exported
once, not that a medic skin was ever painted.

**Consequence: there is no existing medic art to follow. Nothing is being overridden by
designing fresh.**

### 1b. The NVA/VC medics are not a "medic variant pattern" — they have no medic at all

The brief said to study `nva_medic.glb` / `vc_medic.glb` as the established pattern.
Measured by importing both and diffing every mesh object (name, vert count, tri count,
material set):

```
===== nva_medic.glb  vs  nva_rifleman.glb =====
  only in nva_medic.glb:   []
  only in nva_rifleman.glb: []
  shared-but-different (0)

===== vc_medic.glb  vs  vc_guerilla.glb =====
  only in vc_medic.glb:    ['ppsh_world']
  only in vc_guerilla.glb: ['ak47_world']
  shared-but-different (0)
```

`nva_medic` is **geometrically identical to `nva_rifleman`** — zero differing objects.
`vc_medic` differs from `vc_guerilla` **only in which gun is in his hand**. Neither
carries an aid bag, a marking, or a single distinguishing polygon. Their material sets
are the plain uniform/skin sets (`NVA_Uniform`, `Skin_VC`, `BlackPajama`).

**Do not copy this pattern.** It is a `unit_id` with no visual behind it. Copying it
produces an invisible medic and we would not find out until a playtest.

---

## 2. What already exists, with pointers

### `tools/make_medic.py` — a complete, WORKING field-medic pipeline

This is the important find. It builds `us_medic.glb` from the shipped `us_grunt_v3.glb`
plus a procedurally-authored M5-class aid bag (7 parts, 152 verts) bone-parented to
`mixamorig:Spine`.

**I ran it headless with `OUT` and `BASE` redirected to the scratchpad. It succeeds today:**

```
[MEDIC] base: us_base_v3, rig PSXRig (41 bones)
[MEDIC] skel scale 1.09  |  hips z=0.98  spine z=1.07  |  left flank x=0.20
[MEDIC] built the aid bag: satchel_body / satchel_flap / satchel_buckle_a /
        satchel_buckle_b / satchel_cross / satchel_strap_up / satchel_strap_lo
[MEDIC] gear contract: 7 parts - rigid, bone-parented, name-hinted, at identity.
[MEDIC] bag: 7 parts, 152 verts, ~158 faces
[MEDIC] WROTE …TEST_us_medic.glb (13.0 MB)
```

Verified on the produced GLB:

| Check | Result |
|---|---|
| Tris / verts | **5,724 tris**, 10,730 verts, 52 meshes |
| Height (file units) | 2.6927 m — same as `us_grunt_v3.glb`; engine normalises to 1.7132 |
| Bones | 41, `PSXRig`, `mixamorig:*` — matches every other unit |
| Stock-helmet contract (`helmet_shell_worn`) | **PRESENT** → `GruntRandomizer` can swap all 15 authored helmets |
| Bag skinned? | **No** — all 7 parts rigid, bone-parented to `mixamorig:Spine` |
| Hurtbox exclusion | All 7 named `satchel_*`, which `_GEAR_NAME_HINTS` excludes |

5,724 tris sits squarely inside the shipped US role band (measured below), and the
gear contract that `us_grunt_v3` exists to enforce is intact.

**Note:** `make_medic.py`'s own docstring claims *"squad_system.MOS_BODY already names
`us_medic`"*. **That is stale** (a POINTER LAW / drift case). Measured today,
`scripts/squad/squad_system.gd:125-127`:

```gdscript
const DETERMINISTIC_MOS_BODY: Dictionary = { "RTO": "us_grunt_rto" }
```

`us_medic` appears **nowhere** in `scripts/`, `data/` or `tools/` outside `make_medic.py`
itself. `MEDIC` currently resolves through `MOS_WEAPON["MEDIC"] = "m16a1"` →
`WEAPON_BODY_POOLS["m16a1"]` = a random `us_grunt_v3` / `pointman` / `rifleman`. So
exporting the file alone will **not** put it on anyone — one line of GDScript is needed,
and that is the owner's/overseer's call, not mine (I wrote no Godot code).

### `tools/export_medic_gltf.py` — dead, do not use

It opens `unit_us_medic.blend` (`blender -b unit_us_medic.blend -P …`). **That file does
not exist anywhere on disk.** It also references `M14_Rifle`, `med_bottle`,
`US_Grunt_Rigged` and exports 21 animations into the character GLB — which contradicts
the current contract that character exports are mesh-only and `anim_library.glb` carries
every clip once (`model_actor.gd:133`). This is a fossil from the pre-v3 era. It should
be deleted, not followed.

### Shipped US cast — measured tri budget

| Unit | Meshes | Verts | Tris | Mats | Height (file) |
|---|---|---|---|---|---|
| `us_grunt_grenadier` | 52 | 5,821 | **3,810** | 20 | 2.7241 |
| `us_grunt_mg` | 52 | 7,135 | **4,490** | 23 | 2.7241 |
| `us_grunt_pointman` | 52 | 8,499 | **5,146** | 23 | 2.7241 |
| `us_grunt_v3` | 45 | 9,597 | **5,456** | 20 | 2.6927 |
| `us_grunt_rifleman` | 62 | 10,493 | **6,150** | 23 | 2.7241 |
| `us_grunt_marksman` | 62 | 10,579 | **6,206** | 26 | 2.7241 |
| `us_grunt_rto` | 55 | 10,621 | **6,230** | 24 | 3.4557 (whip antenna) |
| `us_pilot_white` | 27 | 1,599 | 1,376 | 7 | 2.7255 |
| `nva_medic` | 26 | 7,020 | 3,813 | 13 | 2.8186 |
| `vc_medic` | 26 | 4,409 | 2,807 | 10 | 2.7997 |

All 41 bones, all single `UVMap`. **Target band for any new US body: 3,800–6,200 tris.**
Per the project's "tri budgets are style, not perf" ruling I would match the band, not
undercut it. The pilot at 1,376 shows a stripped-gear body naturally lands low — a
doctor with no web gear and no rifle will come in near the bottom of the band, around
2,500–3,500, and that is correct rather than something to pad.

---

## 3. The aid station is ALREADY LIVE and wearing the wrong bodies

This is the strongest argument in this document, and it is what makes the job worth
doing now rather than later.

Every layer of aid-station behaviour is built and running. Only the **body** is missing.

| Layer | Pointer | State |
|---|---|---|
| Work markers | `tools/gen_firebase_v3.py:629` — `"fb_aid_station": [("medic", 3, 2.6, 3.8)]` | 3 slots stamped |
| Post seeding | `scripts/world/site_planner.gd:969-978` | Seeds exactly **1 `medic` + 1 `patient`**, plus a conditional 3-man `litter` team (`:985-990`) |
| Animation | `scripts/world/civilian.gd:452-465` | `medic` → `medic_treat_give` / `kneeling_idle`; `patient` → `medic_treat_receive` / `laying_idle` / `sleeping_laying` |
| Daily schedule | `scripts/ai/civilian_schedules.gd:186-200` | Medic works the morning sick call and stays on through patrol return; the station never shuts |
| Body pool | `scripts/world/civilian.gd:149-152` | `GARRISON_MEN` = the seven `us_grunt_*` **rifleman** bodies |

So what is on screen in the medical tent **right now**:

- a fully armed rifleman **in a steel helmet and web gear** kneeling and miming surgery,
- over a second fully armed rifleman **in a helmet, with a rifle**, lying on the cot as
  the patient,
- and, when the ward is above its floor, **three armed riflemen carrying a fourth armed
  rifleman** on a stretcher.

The site planner's own comment says the station is seeded because *"an aid station with
nobody in it is the fresh-player failure."* The station is no longer empty — it is
staffed by seven identical infantrymen. That is the fresh-player failure one step later,
and it is exactly what Caleb is reacting to with *"maybe it would be worth making some
medical doctor models."*

**A patient on a cot wearing a helmet and carrying a rifle is the single worst read in
the tent** — worse than the doctor, because a man lying down in full battle order does
not read as wounded at all.

---

## 4. Reference gathered

Multi-angle, from archival motion footage (YouTube is a sanctioned source; frames pulled
with `yt-dlp` + `ffmpeg`, source videos deleted after tiling — disk discipline).

**Sheets retained** (session scratchpad, ~5.4 MB total; say the word and I will move them
into `production/` reference, otherwise they expire with the session):
- `…\scratchpad\sheet_medic_01.png`, `sheet_medic_02.png` — *Combat Medics in Vietnam*
  (`youtube.com/watch?v=fG9ocDMcs8k`)
- `…\scratchpad\sheet_hosp_01.png` — *The Gentle Hand*, US Navy medical film
  (`youtube.com/watch?v=oqmd6WLUubE`)

### What the FIELD MEDIC footage gave me

- Medics working casualties are **visually indistinguishable from riflemen**: same
  helmet with camo band, same OD jungle fatigues, same web gear. No brassard, no helmet
  cross, no armband, on any man in any frame.
- The red cross appears **only on vehicles and aircraft** — a clear cross on an
  ambulance panel, and the big white square with red cross on the DUSTOFF Hueys.
- The actual visual signature of a medic at work is the **bright white/tan gauze
  dressing** against olive drab — high value contrast, reads instantly at distance.
- Sleeves are often rolled; several men work bare-headed once out of contact.

This is corroborated by the documentary record: US medics in Vietnam deliberately
stripped their identifying marks because the NVA/VC targeted them, and the Army had
stopped requiring the red cross by then. ([Combat medic — Wikipedia](https://en.wikipedia.org/wiki/Combat_medic),
[Unsung Heroes: combat medic photos](https://allthatsinteresting.com/combat-medics-historical-photos),
[Medics & corpsmen in Vietnam — AF Medicine](https://www.airforcemedicine.af.mil/News/Photos/igphoto/2001864917/))

**This directly contradicts `make_medic.py`, which builds a `satchel_cross` red cross
onto the aid bag flap** ("two quads laid PROUD of the flap… it reads from 50m"). The
script's instinct is good game design and bad history. **That conflict is the first
thing on the decision gate below** — I have not resolved it myself because it is a
pillar call (Atmosphere/authenticity vs. readability), not a modelling call.

### What the AID-STATION footage gave me

Three distinct real looks, all bare-headed and all with no web gear:

1. **Surgeon in scrubs** — teal/blue-green short-sleeve scrub top, matching scrub cap,
   surgical mask, gloves. The most visually distinct silhouette by a wide margin; nothing
   else in this game is that colour.
2. **Corpsman / ward hand** — plain blue-green short-sleeve shirt, bare forearms, no
   cap, working over a man on a cot. Same palette as (1) minus cap and mask.
3. **Physician in khakis** — light tan/khaki short-sleeve uniform shirt with chest
   pockets, glasses. Reads as an officer, not a surgeon.
4. Triage handlers in **white gowns** over fatigues also appear (medic sheet 02, row 2).

Patients on cots are **bare-chested or in light trousers**, no helmet, no gear, often
with a visible white dressing.

Bag reference: the Vietnam-era **M5 Combat Medical Bag** is a rectangular OD canvas
rucksack with a full wrap-around zipper, three flat outer pockets, carry handle and
shoulder straps; medics commonly lashed extra canteens to its sides
([modernforces.com](https://www.modernforces.com/fieldgear_medic_M5.htm),
[Omega Militaria](https://omegamilitaria.com/products/60s-vintage-us-military-m5-first-aid-bag)).
No published dimension sheet turned up; `make_medic.py` builds it at 30 × 20 × 12 cm,
which is consistent with the surviving examples and which I would keep. (The script calls
it an "M3" in a comment — the M3 is the WWII/Korea bag, the M5 is the Vietnam one. Cosmetic
comment error, correct object.)

---

## 5. A MEASURED DEFECT in the existing bag — it intersects the body

Before recommending "just run the script", I measured the fit. Per-vertex sign test in
**object space** (`body.closest_point_on_mesh` via `matrix_world.inverted()`, never
`scene.ray_cast`), with a 0.35 m proximity filter so a vertex near a different body part
is not miscounted:

```
  satchel_body         inside  36 / covered  96 / total  96   deepest 4.9 cm
  satchel_buckle_a     inside   0 / covered  96 / total  96   deepest 0.0 cm
  satchel_buckle_b     inside   0 / covered  96 / total  96   deepest 0.0 cm
  satchel_cross        inside   0 / covered   8 / total   8   deepest 0.0 cm
  satchel_flap         inside  32 / covered  96 / total  96   deepest 3.3 cm
  satchel_strap_lo     inside  48 / covered  96 / total  96   deepest 5.5 cm
  satchel_strap_up     inside  92 / covered  96 / total  96   deepest 6.2 cm
TOTAL bag verts inside the torso: 208 / 584 covered (of 584)  deepest 6.2 cm
```

**`satchel_strap_up` is 92 of 96 verts inside the man** — the shoulder strap is drawn as
a straight box from `RightShoulder` to the bag and therefore passes *through* his chest
instead of lying over it. The bag body itself is buried 4.9 cm into the hip.

Root cause, from reading the code: `build_bag()` places the bag centre at
`bx = flank + D*0.42` — it offsets by the bag's **depth** (D = 12 cm) but the box is
built `(W, D, H)`, so the **width** (30 cm) is the axis pointing at the man. Half the
width, 15 cm, is greater than the 5 cm offset, so the bag sits half inside him.

This matters more than usual here: **"elbows must never intersect" is the owner's
standing #1 complaint and a permanent ruling.** Shipping this bag as-is walks straight
into it. The fix is small and I can do it — reorient the box axes so the thin dimension
faces the body, and build the strap as two segments that clear the chest surface, then
re-run this same penetration probe as the gate. But it is a fix, not a no-op, so it does
not belong on the far side of a decision gate I have not passed.

---

## 6. Recommendation

**Build the TENT DOCTOR, and treat the field medic as a small repair rather than a new model.**

Reasoning:

1. **The field medic is ~90% done.** `make_medic.py` runs today and produces a
   contract-clean 5,724-tri body. The remaining work is the bag intersection fix
   (section 5) and one line of GDScript. It is not a modelling project.
2. **The field medic has the least visual payoff per hour.** The reference is
   unambiguous: a Vietnam field medic *looked like every other grunt*. Building him a
   distinct silhouette would be inventing history. He is correctly a rifleman with a bag.
3. **The tent doctor has the most.** He is bare-headed, in a teal scrub top, with no web
   gear and no rifle — nothing else in the cast reads remotely like that. He is
   identifiable at a glance from across the compound, which is the entire point Caleb
   raised.
4. **The behaviour is already waiting for him.** Markers, posts, schedules and clips are
   all live (section 3). This is the rare case where the art is the only missing piece
   and the moment it lands the tent works.
5. **He is cheap.** No helmet, no web gear, no weapon, no bandolier: strip those from the
   `us_grunt_v3` base and the body lands ~2,500–3,500 tris, below every combat body,
   which suits an NPC that only ever kneels and stands.

**And I would add a third model the brief did not ask for, which I think outranks the
field medic:** a **WOUNDED PATIENT** body — bare-chested or undershirt, no helmet, no
gear, a white dressing on one limb. The `patient` occupation is live and seeded on every
firebase (`site_planner.gd:976`), and today it is a helmeted rifleman lying on a cot. It
is the same strip-down operation as the doctor, from the same base, and it can reuse the
doctor's export path. Two bodies out of one afternoon.

### Proposed build order (pending the gate)

| # | Asset | Base | Est. tris | Why |
|---|---|---|---|---|
| 1 | `us_doctor` | `us_grunt_v3.glb`, gear stripped, scrub top + cap | ~2,500–3,500 | Highest visual payoff; behaviour already live |
| 2 | `us_patient` | same strip, undershirt + dressing | ~2,000–3,000 | Fixes the worst read in the tent; shares the pipeline |
| 3 | `us_medic` | fix `make_medic.py` bag axes + strap, re-run | 5,724 | Repair, not a build |

All three follow the existing contract: `mixamorig` 41-bone `PSXRig`, single `UVMap`,
mesh-only (no animations — `anim_library.glb` carries every clip once), exported to
`assets/us/characters/<unit_id>.glb` so `ModelActor.model_path()` resolves them with no
code change (`scripts/visuals/model_actor.gd:22-29`).

---

## 7. DECISION GATE — I need these before I cut geometry

**Q1 — the red cross. The one that actually matters.**
Historical record says Vietnam medics stripped every marking because it made them
targets; the red cross lived on the Hueys and the ambulances, not the man. The existing
`make_medic.py` puts a red cross on the aid bag anyway, for 50 m readability.

Which do you want?
- **(a) Authentic** — no cross anywhere on any man. Medic reads by his aid bag and by the
  white dressings he applies. Doctor reads by the scrub top. *Costs: the field medic is
  near-invisible as a medic at distance.*
- **(b) Readable** — keep the red cross on the aid bag (and optionally a small one on the
  doctor's apron). *Costs: a knowledgeable player clocks it as wrong; it is the one
  detail Vietnam veterans mention unprompted.*
- **(c) Split** — no cross on the field medic (he's outside the wire, where it got men
  killed); cross on the aid-station tent and on the doctor, inside the wire, where it is
  both historical and useful. **This is my recommendation** — it is accurate *and* it
  puts the readability exactly where the player needs it.

**Q2 — the doctor's palette.** Three real options from the footage:
- **(a) teal/blue-green scrub top + scrub cap** (± surgical mask) — most distinct,
  reads instantly, slightly "hospital" for a firebase aid tent
- **(b) plain blue-green short-sleeve shirt**, bare forearms, no cap — the corpsman look,
  distinct but grounded
- **(c) khaki short-sleeve uniform shirt** — the physician/officer look, most subdued,
  weakest silhouette read

My pick is **(b) for the working medic in the tent and (a) reserved if you ever want a
surgery beat**, but this is squarely your taste call.

**Q3 — do you want the `us_patient` body?** It is not in your original ask, but it fixes
what I think is the worst-looking thing in the tent (an armed helmeted rifleman lying on
a cot as the "wounded" man), and it costs roughly half a model because it shares the
doctor's strip-down and export path.

**Q4 — mask on or off?** A surgical mask hides the face atlas entirely, which kills the
face/skin variation the `GruntRandomizer` provides (`grunt_randomizer.gd:96-97` —
`is_dressable` returns true for anything `us_*`, so a `us_doctor` will be fed through the
dresser). If you want masks I will need to either exclude the doctor from dressing or
accept every doctor having a hidden face.

### One thing you do NOT need to rule on, but should know

`GruntRandomizer.dress_actor` is **capability-gated**, not list-gated
(`grunt_randomizer.gd:66-80`): it only swaps a helmet if the body carries a
`helmet_shell_worn` mesh. A bare-headed doctor exported without that mesh will correctly
keep his bare head — but it will `push_warning` once per unit that it cannot dress him.
Harmless, and I will note it rather than silence it, since that warning exists because
fifteen helmet variants once sat unused for weeks behind a silent failure.

---

## 8. Housekeeping / drift found while reading

Flagging per the NO MORE DRIFT law; I did not act on any of these because they are
outside a modelling agent's remit:

1. `tools/export_medic_gltf.py` is a **fossil** — its input `unit_us_medic.blend` does
   not exist, and its 21-animations-in-the-character-GLB approach contradicts the
   current mesh-only contract. Candidate for deletion.
2. `tools/make_medic.py:12-15` and `:326` assert *"squad_system.MOS_BODY already names
   `us_medic`"*. **False as of today** — `DETERMINISTIC_MOS_BODY` holds only `RTO`
   (`squad_system.gd:125-127`). Anyone running that script will believe the medic is
   wired when he is not.
3. `make_medic.py:33-42` calls `us_base_v3.blend` a "broken WIP … textured with REFERENCE
   PHOTOS" and builds from `us_grunt_v3.glb` instead. **The task brief I was given calls
   `us_base_v3.blend` the truth source.** These disagree. I did not open the 133 MB blend
   to adjudicate, because the GLB path demonstrably produces a correct asset and there
   was no need to. Worth resolving before anyone builds from the blend.
4. The `us_medic_*`, `us_grunt_m14_*`, `us_grunt_m60_*`, `us_grunt_m79_*`,
   `us_grunt_v2_*`, `us_rto_*` texture sets are orphans with no matching `.glb`.
   Several individual pages are 9 MB and byte-identical to other units' copies.
   **Measured total: 64 MB** (`us_medic` 12 · `us_grunt_m60` 11 · `us_grunt_m79` 11 ·
   `us_grunt_v2` 11 · `us_rto` 11 · `us_grunt_m14` 3), reclaimable on a disk that is
   reportedly near full. Caveat before anyone deletes: `us_rto_gear_palette.png` is a
   *different* file from the `us_rto_*` orphan set and `us_grunt_rto.glb` does ship —
   check each name against `ModelActor.all_units()` first, not against the prefix.

---

## 9. THE CLOTH SATCHEL — Caleb's memory is correct, and the geometry is LOST

He remembers "a medic that used a cloth satchel bag." It was real. Git history:

```
6b795253  THE AID BAG, built with the fabric tool (make_satchel.py) - and in the armory
          Caleb: "take that basic block satchel bag and make one using the fabric tool,
          just like we did the webbing belt." Then: "once you make that new satchel save
          it in the gear armory so we have it for next time."
```

`tools/make_satchel.py` builds it with the **fabric-tool contract** from
`tools/fit_webbing.py` (the same technique as the M1956 harness):

- `sat_sling` is a STRAP — a ribbon of quads with a **live SHRINKWRAP** onto the body
  plus SOLIDIFY, taking its skin weights from the body by Data Transfer. This is what
  makes it read as webbing rather than a plank, and it re-conforms to any soldier.
- `sat_body` RIDES `sat_sling` (samples its host rigidly, not the body — sampling the
  body makes sling and bag shear apart mid-stride).
- `sat_flap` rides the bag; `sat_buckle_a` / `sat_buckle_b` / `sat_cross` ride the flap.
- Shape: canvas box ~30 × 20 × 12 cm, slung over the **right** shoulder, bag on the
  **left** hip so it never fouls the rifle.

**Where it went.** It was saved to `assets/us/characters/satchel_m3.blend` (71 MB). Git
then records a rename: `satchel_m3.blend => props/gear_armory.blend`, and the file
**shrank 71 MB → 53 MB**. I opened copies of both armories headless:

```
assets/us/props/gear_armory.blend        SOLDIER_satchel  objs=0   *** EMPTY ***
assets/us/characters/gear_armory.blend   SOLDIER_satchel  objs=0   *** EMPTY ***
```

The `SOLDIER_satchel` collection survives as a **named, empty slot in both files**. No
`sat_*` object exists in either. `satchel_m3.blend` is gone from disk, is not in git
HEAD, and a filesystem-wide `find` for `satchel*.blend` returns nothing.

This is the **same failure mode as "export ate the medical complex"**: a merge/export
kept the collection names and dropped their contents.

**THE RECOVERY IS CHEAP AND IT IS THE POINT OF THE PIPELINE-IS-THE-ARTEFACT LAW.**
`tools/make_satchel.py` still exists and still reads `US_BASE_V3`, which is the file he
is opening. Re-running it rebuilds the fabric bag from source. **Do not hand-model a new
satchel in the live session before trying it** — one headless run should bring back the
exact bag he remembers, and it will be better than the blocky one, because:

Two different satchels exist in the history and they must not be confused:
| | verts | technique | where |
|---|---|---|---|
| **Blocky bag** | 152 (7 parts) | hand-placed cubes + CAST/BEVEL, built inline | `tools/make_medic.py`, still runs |
| **Fabric bag** | — | shrinkwrap ribbon sling + riders, the harness contract | `tools/make_satchel.py`, output LOST |

`make_medic.py` builds the **blocky** one, and I measured it intersecting the torso by up
to 6.2 cm with the shoulder strap 92/96 verts inside the chest (section 5). The fabric
sling would not do that — shrinkwrap conforms it to the body by construction. **The
fabric bag is the right answer and the fix for section 5 at the same time.**

## 10. MAP OF `us_base_v3.blend` — the file he is opening

Read from a copy, headless, never saved. 477 objects · 443 meshes · 79 materials ·
29 images · **245 actions**.

### Collections (5)

| Collection | Objs | Tris | Contents |
|---|---|---|---|
| `Collection` | 78 | 4,632 | The unsuffixed BASE man + loose gear (`ruck_*`, `prc25_*`, `splay_*`, `officer_cap_black`, `web_belt`) |
| `SQUAD` | 359 | 21,902 | **The seven role variants**, fully built |
| `_BAG_TEMPLATES` | 13 | 624 | PRC-25 (antenna/handset/pack) + ruck (body/flap/frame/buckles/3 pockets). **NO SATCHEL** |
| `_GUN_TEMPLATES` | 4 | 1,948 | `Ithaca37_Shotgun` 160v · `M60_MG` 644v · `M70sniper` 212v · `M79_Launcher` 206v |
| `_OFFICER_PARTS` | **0** | 0 | **EMPTY** — same stripped-collection symptom as `SOLDIER_satchel` |

### Armatures (10) — every one a 41-bone `PSXRig`

- In `Collection`: `PSXRig`, `PSXRig.002`, `PSXRig.003` (base + two dupes)
- In `SQUAD`: `PSXRig_rifleman`, `PSXRig_pointman`, `PSXRig_mg`, `PSXRig_grenadier`,
  `PSXRig_marksman`, `PSXRig_rto`, **`PSXRig_pilot`**

**There is NO `PSXRig_medic`.** Seven role rigs; medic is not among them. The medic was
never built as a role variant in this file — which is exactly the gap.

### How the six exported GLBs were derived — the pattern to copy

Each role is a **full duplicate of the entire hierarchy, suffixed `_<role>`**:

```
Base_Human_rifleman · PSXRig_rifleman · cap_head_rifleman · cap_torso_rifleman ·
cap_forearm_l/r_rifleman · cap_leg_l/r_rifleman · canteen_l.002…006_rifleman ·
web_pouch_l_rifleman · web_pouch_r_rifleman · pouch_belt_worn_rifleman ·
web_belt_rifleman · target_handguard_rifleman (EMPTY)
```

So a medic follows the same road: duplicate the whole set, suffix `_medic`, swap the
gear. **Append/duplicate the WHOLE hierarchy, never a lone mesh** (the PSX import trap).
The `cap_*` meshes are the gore caps and the `splay_*` are their splay targets — they
must come along or the body cannot be dismembered.

### The pilots — YES, they come from this file

`PSXRig_pilot` + `Base_Human_pilot` + a complete `*_pilot` gear set live in `SQUAD`
alongside the six infantry roles. `us_pilot_black.glb` / `us_pilot_white.glb`
(1,376 tris, 7 materials, 41 bones, heights 2.7255) are the same rig and the same
derivation. The two pilots differ only by skin/cloth material
(`us_pilot_white_skin` / `_cloth` / `_boot`), so a black/white pair is a **material
swap on one body**, not two models.

### Officer parts — present but homeless

`_OFFICER_PARTS` is empty, yet the props exist loose in the scene:
`officer_cap_black` (24 v) and `officer_cigar` (26 v), each duplicated as `.003`, plus
`officer_cigar_ember_light` (a LIGHT — it will not export to glTF and should not be
relied on in-engine). **There is no officer BODY or officer rig** — only a cap and a
cigar waiting for one.

## 11. `tools/export_medic_gltf.py` — what it actually does

- **Reads `unit_us_medic.blend`** (`blender -b unit_us_medic.blend -P export_medic_gltf.py`).
  **That file does not exist anywhere on disk.** The script is unrunnable as written.
- Joins all armature-skinned meshes into one `Medic_Body`; bone-parents `M14_Rifle` to
  `RightHand` and `med_bottle` + `med_bottle_cap` to `Head`; renames the muzzle empty to
  `MuzzlePoint` and re-parents it to the M14.
- Creates sockets `HandR` / `HandL` / `Head` / `Chest` as empties.
- Normalises feet-to-origin at exactly **1.7132 m**.
- **Exports 21 animations into the character GLB** — which directly contradicts the
  current contract (`model_actor.gd:133`: `anim_library.glb` carries every clip once,
  character exports go mesh-only). `make_medic.py` sets `export_animations=False` for
  exactly this reason.
- It also expects meshes named `US_Grunt_Rigged`, `M14_Rifle`, `med_bottle` — none of
  which are the current names.

**Verdict: a pre-v3 fossil. Do not follow it, do not run it. Recommend deletion.**
The live medic export path is `tools/make_medic.py` (verified running today).
