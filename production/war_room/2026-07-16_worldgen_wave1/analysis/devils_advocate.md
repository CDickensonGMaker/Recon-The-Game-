# Devil's Advocate — WAVE-1 Worldgen Changes

Read the CODE, not the plan. Every claim below is cited to `file:line` as observed in the working
tree. **State warning first**, because it changes how you read everything after it.

---

## 0. THE WORKING TREE IS MUTATING UNDER US (read this before trusting any verdict)

Two files carry today's timestamp `Jul 16 19:55` and one of the five changes is **already applied**:

- `terrain/water/water_static.gdshader` — my FIRST read returned the OLD fresnel/specular/ripple shader;
  my SECOND read of the same path minutes later returned the **new PS2 murky version**
  (`flow_speed`, `murk_scale`, `world_uv_scale`, `flow_dir`, `shore_fade_m`; no fresnel/specular).
  The file changed on disk mid-session. **Change #3 is effectively DONE.**
- `terrain/water/water_static.gdshader.uid` and `hydrology_map.gd` also stamped `19:55`.

This is the exact "lie in the map" the FOSSIL LAW warns about: a parallel writer (another architect or
the overseer) is editing the same tree, or the wave was pre-applied. **Verdicts assume the last state I
observed.** If two agents write `hydrology_map.gd` and `water_static.gdshader` concurrently, one edit is
silently clobbered. **Serialize the writes or you will ship a half-applied wave.**

Ground truth I confirmed at end of pass:
- `hydrology_map.gd:45` — `min_lake_depth` STILL `6.0` (change #1 NOT yet applied).
- `water_static.gdshader` — ALREADY the new PS2 shader (change #3 applied).
- `water.gdshader` / `water_coastal.gdshader` — **do not exist anywhere** (change #2 is a no-op).

---

## Change #1 — `min_lake_depth = INF` (kill LAKE classification)

**VERDICT: GREEN.** This is not a risk, it is a *hardening* of an existing probe.

- There is a probe that **already demands zero standing water**: `tests/probe_water_channels.gd:71-73`
  fails on any `LAKE/POND/SWAMP/COASTAL` body, and `:79-80` fails if `get_stats().lakes/ponds/swamps != 0`
  (ADR-027: "channels only, fordable"). Today `min_lake_depth=6.0` still lets a >6 m basin through, and
  `water_system.gd:191-197` reclassifies it to POND (`area<15000`) or LAKE — which would turn that probe
  **red on any unlucky seed**. `INF` guarantees `_classify_cells()` (`hydrology_map.gd:351`) never sets a
  LAKE cell, so the probe is bulletproof, not broken.
- **Channels survive.** Creek/river cells come from flow accumulation (`_extract_rivers`,
  `hydrology_map.gd:431-463`, gated on `creek_threshold`), independent of `min_lake_depth`. Removing LAKE
  cells makes MORE cells eligible as channel candidates (`:441` skips LAKE/COASTAL), never fewer. The
  probe's `total_channels==0 → FAIL` guard (`probe_water_channels.gd:34-36`) stays satisfied.
- **`is_water()` still true on channels — CONFIRMED.** `_trace_channel` writes `CREEK`/`RIVER` into
  `water_type_full` (`hydrology_map.gd:504`); `water_system._build_water_map_from_hydrology` copies
  `water_type_full` into `water_map` (`:394-402`); `is_water()` returns `water_map>0` (`:424-431`). Chain
  intact.
- **Nothing depends on lakes existing.** No test asserts `lakes>0`. `test_world_alive.gd:61`,
  `test_world_minimap.gd:119`, `tools/probe_riparian.gd:119` mention lakes only in **comments**.
  `mission_generator` rejects water for placement but never requires a lake. `survive_waves.gd:110-117`
  and `find_site` only *avoid* water. `RICE_PADDY` is **independent** of standing water — it comes from
  `gameplay_grid._determine_terrain_type` height/slope rules (`:284-298`), not the hydrology basins. So
  paddies (and therefore villages) do NOT vanish with the lakes.
- `extract_static_bodies` (`water_system.gd:100`) simply returns an empty set; `_create_static_body`
  early-returns; the combined mesh becomes rivers-only. No crash.

**SACRIFICE:** All standing water is gone from the AO — no ponds/lakes as landmarks, cover-breaks, or
"water objective" flavor; and the **riparian gallery-forest belt shrinks** — `_apply_riparian_belt`
(`gameplay_grid.gd:184-227`) seeds concealment jungle from `TerrainType.WATER` cells, and there are now
fewer of them (channels only, no lake shorelines). Less dense-jungle concealment near former basins.
(Minor: the `height < 2.0` fallback at `gameplay_grid.gd:284` can still stamp a few WATER cells
independent of hydrology — rare on the 60 m COASTAL_HILLS AO.)

---

## Change #2 — delete `water.gdshader` + `water_coastal.gdshader` (+.uid)

**VERDICT: GREEN — but it is a NO-OP. The files do not exist.**

- `Glob **/water.gdshader` → none. `Glob **/water_coastal*` → none. `ls terrain/water/` shows only
  `hydrology_map.gd, pond_detector.gd, river_generator.gd, water_body_data.gd, water_common.gdshaderinc,
  water_static.gdshader, water_swamp.gdshader, water_system.gd` (+ their `.uid`). Neither target is
  present.
- Every hit for `water.gdshader|water_coastal` is a **document**: `briefing.md`, `.beads/issues.jsonl`,
  `2026-07-16_renderer_decision/.../technical_director.md`, `CODE_AUDIT.md`. Zero `.gd/.tscn/.tres/
  .gdshader/.import/.godot` references.
- The only two LIVE water shaders are `water_static.gdshader` (`water_system.gd:227`, CombinedWater) and
  `water_swamp.gdshader` (`jungle_patch_layer.gd:14`) — both kept.

**SACRIFICE:** None. But **update the docs that still name these files** (`CODE_AUDIT.md`, the briefing) or
they become fossils — a grep for a shader that "should exist" will send the next agent hunting a corpse.

---

## Change #3 — rewrite `water_static.gdshader` to PS2 murky scrolling-UV

**VERDICT: GREEN — and ALREADY APPLIED (see §0).** One compile-time thing to verify.

- **No code reads the old uniforms by name.** The CombinedWater material is built bare in
  `water_system.gd:262-264` (`ShaderMaterial.new(); mat.shader = WATER_SHADER`) with **zero
  `set_shader_parameter` calls**. Grep for `set_shader_parameter` across the project shows terrain,
  clutter, jungle, player-suppression, antenna — **never water**. So dropping `water_color`, `ripple_*`,
  `specular_strength`, `fresnel_*`, `shore_fade_distance` breaks no GDScript. No `.tres` saves this
  material (runtime-only). GREEN on the uniform-rename question the brief asked.
- **Vertex contract preserved.** The new shader reads `COLOR.g` (depth) and `COLOR.r`×10 (shore)
  (`water_static.gdshader:20-21`), matching what the mesh writes: static quads pack
  `Color(shore, depth, 0, 1)` (`water_system.gd:300`) and river strips pack `Color(1.0, 0.35, 0.0, 1.0)`
  (`:322`). Shore=1 on rivers → no fade, correct.
- **COMPILE RISK — verify the includes resolve.** The new shader calls `water_flow_uvs`, `water_fbm`,
  `water_color_creek`, `water_color_river_deep`, `water_shore_blend`. I confirmed **all five exist** in
  `water_common.gdshaderinc` (`water_fbm:29`, `water_color_creek:90`, `water_color_river_deep:85`,
  `water_shore_blend:127`, `water_flow_uvs:142`). So it compiles against the current include. **If any
  future edit trims `water_common.gdshaderinc`, this shader AND `water_swamp.gdshader` both break** — they
  share the include. Do not delete `water_common` functions on a "dead code" sweep.

**SACRIFICE:** No fresnel/specular/animated normals — no sky/moon glint on water. Correct for muddy
Vietnam creeks under canopy; wrong if anyone later wants an open reflective river. `render_mode` changed
`depth_draw_always` → `cull_back, depth_draw_always`; single-sided now, so a camera *under* the water
surface sees through it (fine — ADR-027 water is fordable, not swimmable).

---

## Change #4 — SitePlanner.stamp_village: 14 m min-separation over a larger footprint

**VERDICT: RED (as briefed) — the "keep no-structure-in-water" clause requires code that does NOT exist
today, and the test that "protects" you validates the wrong center.**

The sharp findings:

1. **Village huts currently have NO water check.** `stamp_village` (`site_planner.gd:188-195`) places
   huts on the 8–18 m ring with **no `is_water` guard** — only the punji traps (`:217`) check water.
   Today `test_site_stamp.gd:81` passes *only because the huts stay inside `find_site`'s dry-validated
   footprint*: `find_site(radius 26)` validates 16 ring points at r=26 + 8 at r≈14 as non-water/non-cliff
   (`_footprint_valid`, `:70-87`). Huts at r≤18 sit inside that dry disc. **Enlarge the footprint past
   ~26 m and huts land on unvalidated ground that may be water → `test_site_stamp.gd:81` goes RED**,
   because there is no rejection to "keep." The brief's "KEEPING no structure in water (is_water reject)"
   is therefore a **new check you must ADD**, with retry (not skip) so you don't drop below the count
   floor.

2. **Packing 7–10 structures at 14 m min-sep needs ~30–35 m radius** — larger than the 26 m find_site
   validated disc. That is the collision between the two requirements.

3. **The real game is WORSE than the test.** In-game, `stamp_village` is called with `site.center` =
   a **paddy anchor** (`mission_generator.gd:287,384`), which is a paddy centroid + 8–15 m offset onto
   the bund (`paddy_stamper._compute_anchor_offset`). That center is **never dry-validated** by
   `find_site`. A 30 m footprint from a bund reaches straight back into the paddy/creek water. **No probe
   stamps villages at anchors and checks water** — `test_site_stamp` uses `find_site`, so this failure is
   INVISIBLE to the suite. False confidence: green tests, wet huts.

4. **Node count floor is safe IF rejection retries.** `stamp_village` yields ≥ `hut_count(7-10)` + center
   + cache + tunnel = **≥10 nodes** before scatter/punji. `test_site_stamp.gd:62` needs ≥7. Keeping
   `hut_count≥7` clears it — **unless** a naive rejection-sampler *skips* rejected huts and drops the
   count. Use retry-until-placed or count-guarantee.

5. **nav_baker is fine at this scale, marginally.** `_box_for` sizes the region as
   `clampf(radius+25, 35, 70)` half-extent (`nav_baker.gd:110`). Village `radius` is
   `VILLAGE_RING_RADIUS_MAX+8 = 26` → half 51 m. A 30–35 m footprint stays inside 51 m, so
   `_add_structures`' `_xz_contains` gate (`:246`) still carves every hut. **But update the site dict's
   `radius`** (`site_planner.gd:227`) to the true footprint — if the spread ever exceeds ~45 m the
   `HALF_MAX=70` clamp leaves outer huts uncarved and enemies path through them.

6. **Civ/campfire/chicken still land.** `mission_generator` puts civilians at center+2–12 m (`:393`),
   campfire at center+(2,2) (`:402`), chickens at center+3–10 m (`:406`). A 14 m min-sep tends to leave
   the inner ~14 m as an empty plaza, so these land in open space — actually *cleaner*. Note: none of
   them check hut overlap, so a true fill-the-disc scatter (huts in the center too) could clip a civilian
   into a hut. Aesthetic, not a test break.

7. **WorkingPointResolver unaffected** *provided you keep the dict key.* It only reads
   `site.working_points` NodePaths (`working_point_resolver.gd:19-27`) and never touches hut positions.
   Keep `"working_points": working_points` in the returned dict (`site_planner.gd:228`) and it is inert.

8. **Floating check:** `test_site_stamp.gd:85-86` fails if a node is >4 m off `get_height_at`.
   `place_structure` seats every body at `get_height_at` (`:160-161`), so spread over rolling terrain is
   still seated. GREEN on floating.

9. **veg-clear over the footprint:** adding a `clear_and_flatten`/`clear_area` over a 30 m disc is safe
   API-wise, but recall the standing landmine — `VegetationManager.clear_area` converts authored jungle to
   procedural, and a too-large clear scrubs the gallery-forest concealment you just thinned in #1. Scope
   the clear to the hut footprints, not a blanket disc.

**SACRIFICE:** Tighter, denser hamlets become sprawling ones — worse CQB choke geometry, a bigger nav
region to bake, and (unless you add the missing water rejection + retry) **wet huts in-game that no probe
catches.** You are trading the test's dry-center guarantee for realism the test cannot see.

**REQUIRED to land green:** add per-hut `is_water` (and ideally slope/cliff) rejection with retry; cap
footprint radius ≤ ~40 m; update `site.radius`; scope veg-clear to footprints. Then add a probe that
stamps a village at a **paddy anchor** and asserts no hut in water — otherwise the real risk stays
untested.

---

## Change #5 — "paddies +50% bigger" in `paddy_stamper.gd`

**VERDICT: RED — MISDIRECTION. Paddy extent is NOT controllable in `paddy_stamper.gd`.**

- `paddy_stamper` is **read-only** on RICE_PADDY. `_flood_fill` walks cells where
  `grid.get_terrain_type_at(nx,nz) == RICE_PADDY` (`paddy_stamper.gd:57,59,109`). `_build_paddy_field`
  derives bounds/centroid purely from those existing cells (`:120-148`). The stamper **cannot mint a
  single RICE_PADDY cell.** Growing the flood-fill or scatter footprint 1.5× only spreads
  `_scatter_rice_props` (`:161-181`) **outside the actual paddy**, painting rice on dry hillside — the
  gameplay paddy (movement 1.8×, cover 0.1, the walkable flooded field) is byte-for-byte unchanged.
- **Paddy EXTENT is set UPSTREAM** in `gameplay_grid._determine_terrain_type`:
  `height<5 and slope<0.1 → RICE_PADDY` (`gameplay_grid.gd:287-288`) and the lowland roll
  `height<50 → 30% RICE_PADDY` (`:298`, deterministic via `hash([Vector2(wx,wz), mission_seed])`). **To
  make paddies 1.5× bigger you edit that classifier** (raise the 0.30, or widen the height band) — NOT
  the stamper.
- **And growing them upstream endangers the floor.** `paddy_stamper.gd:72-77` push_errors if
  `village_anchors < HARD_FLOOR_VILLAGES = 8`. More RICE_PADDY cells → larger *contiguous* flood-fill
  clusters → potentially **fewer distinct `paddy_fields`** (adjacent paddies merge into one), and anchors
  are grouped from paddy_fields (`_group_into_village_anchors`, `:184-237`). Fewer, bigger paddies can
  drop the anchor count and trip the floor (stamper error) and/or `test_paddy_stamper.gd:53-54` (`≥4`).
  It could also go the other way (new cells seed new clusters). **Indeterminate without running all 5
  seeds `[1,7,42,99,256]`** — must re-validate the floor after any classifier change.
- **Determinism holds regardless.** The test compares two `stamp()` calls on the **same already-built
  grid** with the same seed (`test_paddy_stamper.gd:32-44`); `rng.seed = mission_seed+1009` (`:43`) and
  the grid classifier is `hash`-seeded per mission — no Time/OS entropy. So whatever you change, two runs
  match. GREEN on determinism. (Note the test's own bar is `≥4`, but the stamper's live floor is `8` —
  don't be fooled into thinking `≥4` is the contract.)

**SACRIFICE / correction:** If you "grow" it in the stamper you get **rice props floating on dry land and
zero change to the actual paddies** — pure waste + a visual bug. If you grow it correctly in
`gameplay_grid._determine_terrain_type`, you risk **fewer village anchors → HARD_FLOOR_VILLAGES=8
push_error / test red**, and denser lowland paddy also means more 1.8× slow-movement mud and less cover
(paddy cover 0.1) across the AO. **Point the change at `gameplay_grid`, not `paddy_stamper`, and re-run
`test_paddy_stamper` on all five seeds.**

---

## ONE-LINE VERDICTS

| # | Change | Verdict | Sacrifice / one-line |
|---|--------|---------|----------------------|
| 1 | `min_lake_depth = INF` | **GREEN** | Hardens `probe_water_channels`; costs all standing water + a thinner riparian jungle belt. |
| 2 | delete `water.gdshader` / `water_coastal.gdshader` | **GREEN (NO-OP)** | Files already absent; only docs still name them — scrub the docs or they're fossils. |
| 3 | rewrite `water_static.gdshader` (PS2 murky) | **GREEN (ALREADY DONE)** | No code reads the old uniforms; loses all water reflection/glint; shares `water_common` — don't trim it. |
| 4 | village 14 m min-sep, larger footprint | **RED** | "No hut in water" needs a rejection that doesn't exist today; real risk is at paddy anchors and is UNTESTED. |
| 5 | paddies +50% in `paddy_stamper.gd` | **RED (MISDIRECTION)** | Stamper only reads RICE_PADDY; extent lives in `gameplay_grid._determine_terrain_type`; growing it there threatens the 8-village floor. |

**Cross-cutting:** the tree is being written concurrently (§0) — serialize `hydrology_map.gd` and
`water_static.gdshader` edits, and re-`ls` before each write, or one change silently eats another.
