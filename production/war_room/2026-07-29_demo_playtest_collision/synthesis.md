# THE DECREE — 2026-07-29 demo playtest: collision, garrison, and the fight that never happened

Six complaints. **Three root causes.** One of them explains half the list.

## The judgment

| # | The Summoner saw | Root cause | Where |
|---|---|---|---|
| 1 | Two layers of collision | Terrain raised to a flat `seat+2.87`, GLB ships its own mound plate collider at `platform_z` (1.5–5.3 m) | site_planner.gd:659,667-681 · gen_firebase_v3.py:28,78-95,201,779 |
| 3 | Jumped up, floated on top, invisible wall | Same. He landed on the model plate standing proud of the terrain; its rim is the wall | as above |
| 5 | Mound alignment issues | Same. Structures are seated on `platform_z`; where it dips under 2.87 the raised terrain buries their feet | as above |
| 2 | Allies + garrison stuck at spawn | **No navmesh exists inside the firebase.** Excluded explicitly, and its site kind is not in the allow-list either | mission_generator.gd:816 · world_config.gd:35 vs site_planner.gd:940 |
| 4 | Nobody fought | Garrison are `Civilian` by design until stand-to promotes them; promoted defenders are `AllyBase` — and `AllyBase` has no navmesh here. **The nav defect masks the combat system** | mission_generator.gd:864-867 · field_director.gd:1228,858-859 · nav_router.gd:44-49 |
| 6 | Shoot out the fire slits | Not built yet. The parapet is a solid 9-course wall, and it exports a **box hull** that would seal a slit even if one were cut | gen_firebase_v3.py:249-280,779,799-816 |

**The Summoner's own diagnosis — "tighten up collision on all the models" — is declined.** The
colliders are doing their job. Men jam because nothing routes them around obstacles, and he
stood on air because there are two floors. Exactly one loose collider is real: the parapet's
box hull.

## Build order — binding

**P0-A. ONE GROUND.** The terrain reproduces the model's mound surface; the model's ground
plate collider is deleted (ADR-023: the replaced system goes, it is not left dark).
- Mound constants are EXPORTED from the generator to a JSON manifest beside the GLB and READ
  by `site_planner` — the same pattern as `temple_set.json`. **A hardcoded copy of
  `MOUND_H = 3.4` in GDScript is refused** (Devil's Advocate §4: that is a fresh
  divergent-systems seed in a project already scarred by them).
- Kills complaints 1, 3 and 5 together.
- Sacrificed: the authored craters become visual dishes, not holes you step into. Named.

**P0-B. NAVMESH OVER THE FIREBASE.** Three gates open, in this order:
1. Stop excluding `firebase_main` (mission_generator.gd:816) and add the kind to
   `WorldConfig.NAV_SITE_KINDS` — today it says `"firebase"`, the site says `"firebase_main"`.
2. The 70 m `HALF_MAX` clamp cannot hold a 300 m compound. The firebase gets its own box.
3. Source geometry comes from the REAL colliders
   (`parse_source_geometry_data`, `PARSED_GEOMETRY_STATIC_COLLIDERS`), not from the
   `nav_blockers` box list the firebase root was never in. Navmesh and physics must not
   disagree.
- Bake time is a LOAD cost and is **unmeasured**. Measure it, after P0-A, and put it in
  PERF_LEDGER.

**P1. RE-JUDGE THE FIGHT. Do not tune it first.** Every combat symptom is consistent with
correct combat code behind a movement failure. After P0-B, boot and look: did stand-to fire,
did the squad's weapons-free auto-flip arm, did the VC ever reach COMBAT tier. **This decree
promises the ability to SEE the fight, not that the fight will be good.** Anything tuned
before that measurement is tuned against a mask.

**P2. FIRE SLITS.** Blender work, after P0-A (the parapet's height derives from the same mound
surface that is about to change). Cut embrasures into ~1 in 3 parapet segments, move
`fb_sbg_seg_` to `COL_TRIMESH` so the slit is a real hole, add a firing step behind them, and
**verify** an embrasure is actually modelled in the bunker masters rather than assuming the
trimesh flag means it is shootable.

## THE RECORD — what was built and what was MEASURED (same session)

P0-A and P0-B are in. Booted `scenes/levels/demo_game.tscn` under Godot 4.7 twice.

**Measured, not claimed:**

- `[FSB] stripped 1 duplicate mound collider(s) - terrain is the ground` — the second ground
  existed exactly as diagnosed, and it is gone.
- `[NavBaker] bake done: box=(370,2000,370) verts=2730 polys=3192 geom=368 colliders` — the
  firebase has a navmesh for the first time, sourced from 368 of its real colliders.
- **First attempt at that bake returned 4 polygons.** `NavigationServer3D.parse_source_geometry_data()`
  discarded the terrain faces already in the source. Replaced with a hand-walk of the collision
  shapes (`NavBaker._add_colliders`). Recorded because "the API will do it" was wrong, and the
  first log looked plausible enough to have been believed.
- Two residual `[NAV] enemy ... no path - falling back to direct steering` warnings at 5-6 m.
  Agents standing off-mesh; direct steering is the intended behaviour there. Not chased.

**Files changed:** `site_planner.gd` (mound sculpt from manifest + collider strip),
`nav_baker.gd` (firebase box + collider sourcing), `world_config.gd` (`firebase_main` kind),
`mission_generator.gd` (stop excluding), `heightmap_storage.gd` (modifier gains world XZ) and
its three callers, `tools/gen_firebase_v3.py` (COL lists + manifest export),
`fsb_main_v3_mound.json` (new).

**NOT measured, and not claimed:**

- **The look.** Whether the mound now reads right is Rule #1 and is judged by the Summoner's
  eyes, not by a log line.
- **Perf.** Both boots settled at 4-5 FPS on the Intel UHD floor against a ledger figure of
  ~34 at the firebase pose. The broken 4-polygon boot ran at the same 4-7, so the navmesh
  region is not the cause — but no clean before/after was taken this session, so nothing is
  attributed. Take a baseline before P2 adds trimesh parapets.
- **The fight.** Untouched by design. P1 re-judges it now that the men can move.

**Blender-side work** is collected in `production/blender/FIREBASE_BLENDER_HANDOFF.md`, per the
Summoner's request: the collision-list mechanics, the fire-slit authoring, and a measured
open defect — a `fb_veg_felled_tree` collider sitting 12.5 m above the bunk spawn.

## ROUND 2 — the playtest that followed, and what it found

The first fix was real but incomplete, and the Summoner's next session found the rest. Recorded
because each one was invisible to a source read and obvious the moment he walked on it.

1. **THE FOUR INVISIBLE SLABS.** "I can still jump and get stuck above the firebase" — and
   crucially, *"I should not be able to jump ONCE"*. `scatter_veg` merges every instance of a
   card into ONE object spanning the 300m treeline ring, and the five solid ones (tree_stump
   ×90, fallen_log_a/b, felled_trunk, felled_tree ×16) were not on `COL_NONE`. Each exported as
   ONE axis-aligned box wrapping the whole ring. Stumps put a floor ~1m up — one jump — and
   felled trees put one at 12m. Stripped and re-meshed at load; fixed at source in the
   generator. **The one-jump detail is what identified it**: a 12m ceiling and a 1m ceiling are
   different objects.
2. **THE CLEAR RAN AFTER THE SCULPT.** "We were walking between the firebase model and the
   terrain… then I was stuck inside the mound." `clear_and_flatten` → ClearingSystem CLEARED
   flattens toward the mean of a 140m disc, and it ran AFTER the mound sculpt, averaging the
   authored mound back down while the model still drew it full height. Ordering fixed; the
   sculpt now has the last word. **This was self-inflicted in round 1** — the fix was written
   without checking what ran after it.
3. **THE NAVMESH WAS SHREDDED.** Feeding every collider into the bake put 90 merged stumps and
   the interior dressing into it, each ~0.4-0.8m — right at `agent_max_climb` — eroding ground
   around every one. Allies 5m from their post could not path to it. `fb_veg_`/`fb_int_` now
   excluded from the bake (still solid to walk into).
4. **SPOOKY WAS SHOOTING THE BASE.** AirTraffic's scheduled "spectre" sets its orbit centre to
   a random route midpoint, and SpectreGunship is not scenery — 60-damage Vulcan and
   120-damage Bofors into that point for 30s. A midpoint on the firebase means the ambient
   schedule strafes the player's own compound. Now pushed 420m clear of `fsb_center`.

**Measured after, same boot:**
- `[FSB] one ground: 129 samples, worst gap 0.09m - terrain matches the model mound`
- `[FSB] replaced 5 merged-vegetation box hull(s), 5 re-meshed as trimesh`
- floating-collider audit: 12.5m offender gone; **2 left, both hanging light bulbs at +4.4m**
- ally `no path` warnings: **8 → 0**; nav geom 368 → 185 colliders, 5944 → 5278 polys
- `[FSB] stand to: promoted 21 garrison civilian(s) to defenders` — the garrison was standing
  to all along; twenty-one men were jammed against geometry, not asleep
- FPS 29-44 at the firebase pose, against the ledger's ~34
- **Summoner confirmed the tower ladder works.**

**Instruments built, so none of this is hunted by jumping around again:**
`_audit_one_ground` (samples terrain against the mound manifest, warns on >0.6m) and
`_audit_floating_colliders` (names anything whose lowest point sits >3m off the ground).

**STILL OPEN, not done, not started:**
- **The fighting step.** You cannot see over your own parapet: measured 2.39m to the top
  against a 1.6m eye, and the berm crest is a knife edge with the wall on it. Spec with
  numbers in the Blender handoff §2b. Blender work.
- **Fire slits.** Generator lists are fixed; the embrasures still have to be modelled.
- **Ambient war audio.** "The fire rate should either be faster or a less occurring event…
  isn't there some better sounds." `_spawn_audio` fires ONE one-shot per event. A distant
  engagement should be a volley. Not touched.
- **The sapper has never been seen to blow anything up.** Unconfirmed. The siege is on the
  demo arc at 600s/720s, so nobody has watched it land.

## Standing law reaffirmed

Everything above is read off SOURCE. Under the Summoner's own law a source read is a claim,
not a measurement. The two claims most likely to be wrong — that the plate stands above the
terrain over most of the compound, and that the garrison ever stood to — are cheap to sample
in-engine and are measured BEFORE the fix is written, not after.
