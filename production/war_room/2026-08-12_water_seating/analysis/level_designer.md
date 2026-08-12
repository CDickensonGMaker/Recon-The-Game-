# LEVEL DESIGNER — the water is the wrong SHAPE, not the wrong colour

**Council:** 2026-08-12 water seating · **Lens:** what water should BE in this AO, and whether the
world shape is right at all.

**Headline:** the render defect is real but downstream. The world we generate has ONE kind of water —
106 identical wide, deep, bare gullies — and there is no width in the distribution that a Vietnamese
creek would occupy. Fix the seating and you will have successfully rendered the wrong river 106 times.

---

## 1 · THE WIDTH DISTRIBUTION IS THE DEFECT. 40m is not the outlier — 7m is the FLOOR.

Widths are generated at `terrain/water/hydrology_map.gd:507-508`:

```
w = clampf(river_width_base + river_width_scale * sqrt(accum), river_width_base, river_width_max)
```

with `river_width_base = 2.0` (`:63`), `river_width_scale = 0.35` (`:62`), `river_width_max = 40.0`
(`:64`), and a channel only exists at all once `creek_threshold = 200.0` upstream cells
(`:59`) drain through it (`:451`).

**Do the arithmetic on the gate itself.** The first cell that qualifies as a channel already carries
accumulation 200, so its width is `2.0 + 0.35 * sqrt(200)` = **6.95m**. There is no such thing as a
narrower channel — `river_width_base = 2.0` is **unreachable**, a number the code can never produce.

Three consequences, all measurable:

1. **`Type.CREEK` is a fossil.** The creek/river split is `w < 6.0` at `hydrology_map.gd:513` and
   `avg_width < 6.0` at `terrain/water/water_system.gd:150`. The minimum producible width is 6.95m.
   **Not one cell and not one body in this AO is ever classified CREEK.** `body.depth = 1.0` for creeks
   (`water_system.gd:153`) is dead with it; every body takes the `2.5` river branch. The probe's
   "106 channels" are 106 RIVERS. The word "creek" survives in nine comments
   (`tools/probe_riparian.gd:5`, `gameplay_grid.gd:156`, `enemy_base.gd:1006`,
   `enemy_squad.gd:242` …) describing a body type the generator cannot emit — a textbook FOSSIL LAW
   violation (ADR-023): the docs describe creeks, the world ships rivers.

2. **The width is not hydrology, it is a look knob.** The AO is 1280m (`scripts/levels/world_config.gd:9`)
   at `CELL_SIZE = 4.0` (`:11`), and `_auto_downsample()` returns 1 at this size
   (`water_system.gd:129-133`, mirrored `terrain/core/terrain_manager.gd:369`), so a hydrology cell is
   4m × 4m = 16 m². Invert the formula:
   - the **7m minimum** channel drains 200 cells = **3,200 m²** — one third of a hectare. In life that
     is a rain rill you step over without noticing.
   - the **40m clamp** is hit at accum ≈ 11,790 cells = **18.9 ha**. A real watercourse draining 19 ha
     of hill country in I Corps is **1–3m wide**. 40m is the Perfume River; it drains ~2,800 km².
   The generator is off by roughly **two orders of magnitude of catchment**, in the direction of "make
   it big so you can see it."

3. **The demo — the thing that actually ships — is worse, not better.** EA ships the 512m slice
   (`scenes/levels/demo_game.tscn`, CLAUDE.md session gate). On a 512m map the whole world is 16,384
   hydrology cells, so the trunk channel's width computes to `2 + 0.35*128` = 46.8m and **clamps at
   40** (`hydrology_map.gd:508`). **A single watercourse can be 8% of the entire playable map wide,
   bank to bank.** That is not a stream in a jungle. That is a moat around the firebase.

### VERDICT 1 — YES. The real defect is that the channels are far too wide.

Everything the Arbiter's diagnosis names (`water_system.gd:337-340` sampling banks at ±20m,
`:340-341` clamping, the buried ribbon) is a **symptom of half-width being 20m** on terrain with 6m of
relief. Halve the width and the ±half_w bank samples land on the actual carved shoulder;
`_carve_riverbed`'s relative subtraction (`terrain_manager.gd:434`) stops mattering, because over 3m
of span there IS no local relief to preserve. **Narrowing the channels fixes the seating bug as a
side effect. Fixing the seating bug does not fix the width.**

### THE TRAP UNDER THE FIX — a 2–6m creek is BELOW THE TERRAIN'S RESOLUTION

Do not simply set `river_width_max = 6.0` and call it done. The heightmap cell is **4.0m**
(`world_config.gd:11` → `terrain_manager.gd:100` → `:62`), and `_carve_riverbed` floors the carve
radius at 2 cells:

```
terrain/core/terrain_manager.gd:416-418
  shoulder = maxf(half_w * 0.6, heightmap.cell_size)     # >= 4.0m
  carve_radius = clampi(int(ceil(reach / cell_size)), 2, 14)   # >= 2 cells = 8m
```

**A 3m creek still digs an 8m-wide trench, 1.2m deep** (`CHANNEL_CARVE_DEPTH`, `terrain_manager.gd:31`).
You cannot represent a 3m Vietnamese creek in a 4m heightmap. Two honest routes, and the council must
pick one:

- **(A) The creek stops being terrain.** Channels below ~6m are NOT carved at all; the water ribbon is
  laid on the natural surface with a small recess, and the bed is faked by the mesh + shader. Cost: no
  banks to take cover behind, no defilade in the creek — the E&E route loses its one piece of hard
  cover, and `WADE_DEPTH_M` loses its last excuse to exist.
- **(B) `CELL_SIZE` drops 4.0 → 2.0** (`world_config.gd:11`). Cost: the heightmap goes from 321² to
  641² — **4× the terrain memory and 4× the chunk mesh vertex count**, straight into the Intel-UHD
  floor (ADR-026), and every carve/crater/flatten loop is 4× the work. This is a performance decision,
  not a water decision, and it belongs to the technical director, not to me.

**My preference is (A) for creeks and keep the carve for one trunk river per AO.** It is the only route
that gets a 3m stream without a terrain-resolution bill.

### RECOMMENDED DISTRIBUTION (design side, not implementation)

| Class | Width | Population per 1280m AO | Role |
|---|---|---|---|
| creek | 2–5m | ~90% of channels | step across; the E&E capillaries; roofed by canopy |
| stream | 5–10m | ~10% | wade; a real crossing decision; ambush geometry |
| river | 20–30m | **at most ONE, named** | a landmark that orients you; crossed at fords |

Concretely that is `river_width_base 1.2` · `river_width_scale 0.10` · `river_width_max 10.0`, with the
single trunk promoted by a separate rule (highest-accumulation polyline only), not by the clamp.
**Sacrificed:** the map loses its big blue feature; players who liked the river as a landmark get one
river instead of a hundred, and finding it becomes a navigation event rather than a guarantee.

---

## 2 · WHAT WATER DOES THE PLAYER ACTUALLY ENCOUNTER? Exactly one thing, 106 times.

Every other water class in this codebase is switched off:

| Class | Status | Pointer |
|---|---|---|
| LAKE / POND | **impossible** — `min_lake_depth = INF` disables pooling | `hydrology_map.gd:45`, gate at `:358` |
| SWAMP | classified, then **discarded at mesh time and at body time** | `water_system.gd:28`, `:186`, `:254` |
| COASTAL | never seeded — `OCEAN_EDGES = 0b0000` | `world_config.gd:25` → `water_system.gd:99` |
| CREEK | **unreachable width** (see §1) | `hydrology_map.gd:513` vs `:507-508` |
| RIVER | the only survivor | 106 of 106 |

**And the flooded rice paddy — the single most iconic body of water in the Vietnam War — has NO WATER
IN IT in the shipped world.** This is the finding I want on the record.

- `TerrainZoning.classify()` does produce RICE_PADDY cells (`terrain/core/terrain_zoning.gd:74-77`),
  and `PaddyStamper` is genuinely live — called at `scripts/missions/mission_generator.gd:511` and
  `:679`.
- But `PaddyStamper` only scatters `rice_a`/`rice_b` MeshInstances
  (`scripts/world/paddy_stamper.gd:163-183`). It never creates a water surface.
- The flooded pans exist — `JunglePatchLayer` bakes a per-chunk water mesh for paddy tiles
  (`terrain/vegetation/jungle_patch_layer.gd:348-356`, pan mesh at `:385`), with real craft behind it:
  edge tiles turned to face out of the field (`:269-276`), terraced height quantisation so the sheet
  stays flat (`:302-307`).
- **`JunglePatchLayer` is never constructed in the real world.** `USE_TREE_COVER = true`
  (`world_config.gd:21`) routes the AO to TreeCover, and the ONLY `JunglePatchLayer.new()` in the repo
  is `scripts/levels/ai_stress_arena.gd:522` — the sterile test arena.
- `VegetationManager` would not fill the gap either: RICE_PADDY's density row is `[0.00, 0, 0]`
  (`terrain/vegetation/vegetation_manager.gd:63`).
- So a paddy in the shipped AO is: a **green ground tint** (`terrain/core/terrain_chunk.gd:205-206`),
  some rice props, and dry ground.

**The player's water vocabulary, complete:** 106 wide bare gullies, and a dry paddy that makes a
splashing noise when you walk on it (`scripts/player/player.gd:323-325`). Against Pillar 2
(ATMOSPHERE — `production/bible/BIBLE.md:86`) that is a failure of *variety* far larger than the
failure of *rendering* this council was convened about. Platoon, Hamburger Hill and Apocalypse Now —
the tonal north star at `BIBLE.md:100-102` — are films of **paddies, monsoon, and men chest-deep in
brown water**. We generate none of those three.

**RULING:** the paddy water pan is built, correct, and stranded in the arena. Porting it to the
TreeCover path is a **higher-value atmosphere win than the channel seating fix**, and it is the one
piece of water in this project that is finished art. Cost of porting: one more transparent draw call
per paddy chunk, and the paddy sheet must be reconciled with `PaddyStamper`'s rice props, which
currently sit at the terrain height, not at a quantised pan height
(`paddy_stamper.gd:171-173` vs `jungle_patch_layer.gd:307`) — port it naively and the rice grows
half-drowned or floating.

**DO NOT restore hydrology pooling to get ponds.** The briefing's warning is correct, and the reason is
mine to state: `HARD_FLOOR_VILLAGES = 4` (`paddy_stamper.gd:17`) is enforced by a `push_error` at
`:70-75`, villages are anchored on paddy clusters, and pooling would flood the lowland the paddy
classifier lives in (`terrain_zoning.gd:75`). Pooling eats paddies, paddies are villages, and the AO
raises. **Ponds must come from an authored stamp, not from the flood fill.**

---

## 3 · THE GALLERY FOREST — a 40m channel is a CANYON, and the roof code KNOWS it

`RIPARIAN_M = 22.0` (`terrain/core/gameplay_grid.gd:151`), `GALLERY_MIN 0.55` / `GALLERY_MAX 0.95`
(`:152-153`). The AO grid cell is 1280/256 = **5.0m** (`scripts/levels/game_world.gd:172`), so
`_apply_riparian_belt` reach = `ceil(22/5)` = 5 cells = 25m each side (`:181`).

**Corridor geometry as shipped:** 40m of open water + 25m of belt each side = a **90m corridor**, with
its floor **3.67m below grade** (probe). At 90m across and 3.7m down, the walls are at a ~4.7° angle.
That is not a tunnel. **That is a bowling alley with hedges.**

And the roofing code refuses to close it — correctly, by its own design:

```
gameplay_grid.gd:158-161   ROOF_SAMPLE_M 11.0 · ROOF_NARROW 0.72 · ROOF_WIDE 0.30
gameplay_grid.gd:236       r = round(11.0 / 5.0) = 2 cells  → a ±10m window
gameplay_grid.gd:258-259   if land == 0: continue           → NOT ROOFED AT ALL
```

At 40m wide, the centre cell's entire ±10m sample window is water: `land == 0`, the loop `continue`s,
and the cell keeps `_estimate_vegetation(WATER)` = **0.0** (`:290-292`). Even off-centre, `land_frac`
falls under `ROOF_WIDE 0.30` and `smoothstep` returns 0 (`:262`). The consequence, via
`scripts/ai/sight_cap.gd` and `enemy_base.gd:104-105`: **a sight cap of 140m standing in the middle of
the watercourse.**

**So the E&E route, as generated, is a 40m-wide open lane sunk 3.7m into the ground, where you can be
seen for 140m, walled on both sides by heavy jungle you must climb out through.** `probe_riparian.gd:12-13`
warns that water was "a DEATH TRAP, not an escape route." **It still is.** The probe fixed the banks
and the channel got wide enough to undo the fix.

**The roof mechanism is not broken — it is starved.** At 4–6m width the water occupies 1 cell of the
5m grid, `land_frac` ≈ 0.8–0.96, `smoothstep` saturates, `roof = 1.0`, and the channel inherits its
banks' 0.95 density × `ROOF_FACTOR 0.95` (`:161`) → density 0.90 → sight cap near the 45m jungle floor.
**Narrow the channels and the tunnel of green builds itself, with no code change to `gameplay_grid.gd`
at all.** That is the strongest single argument for §1.

**Sacrificed by narrowing:** far fewer WATER cells means far fewer riparian seeds
(`gameplay_grid.gd:187-192`), so total heavy-jungle acreage across the AO **drops**. Sight caps rise
map-wide, the AI sees further, and the game gets more lethal in a way nobody asked for. If we narrow
the channels, `RIPARIAN_M` should go **up** (22 → ~30) to hold the total green acreage roughly constant.
Name that trade explicitly or the water fix ships as a stealth difficulty increase.

---

## 4 · `WADE_DEPTH_M` — RULING: no water in this AO stops a man. Ever.

`WADE_DEPTH_M = 1.2` (`gameplay_grid.gd:154`) gates the only impassability water can create:

```
gameplay_grid.gd:136-139
  if ttype == TerrainType.WATER:
      impassable = get_water_depth(...) > WADE_DEPTH_M
```

It cannot fire. `get_water_depth()` quantises to `int(depth * 2.0)` (`water_system.gd:422, 506`) and the
channel surface is seated `CHANNEL_SURFACE_DROP = 0.65` below pre-carve grade against a 1.2m carve
(`hydrology_map.gd:53, 519`) — a nominal 0.55m, floored to 0.5 by quantisation. Even the *intended*
number is less than half the gate.

**The design ruling, and I want it ruled deliberately rather than left as an accident:**

**Water in this game SLOWS and EXPOSES. It never blocks.** Pillar 3 is FREEDOM — *"open AO; any route,
any order; nothing on rails"* (`BIBLE.md:87`). An impassable watercourse is a **rail made of terrain**:
it cuts the AO into halves and dictates where you may cross. On a 512m demo map, one 40m impassable
river is the single most restrictive object in the world, and no designer authored it — the clamp did.

What water should cost instead, and note the asymmetry we currently ship:

- **Speed.** A flooded paddy divides your speed by 1.8 (`player.gd:1707-1708`). **A channel divides it
  by nothing.** The dry thing slows you and the wet thing does not. That is exactly backwards, and it
  is a two-line fix in the same function.
- **Noise.** Already there and good — `STEP_WATER` at `player.gd:309-310` and
  `scripts/autoload/audio_manager.gd:132-133`.
- **Sign.** Already there — see §5.
- **Attrition.** Already there and it is the best water content in the build: linger 20 footsteps in
  water and you take 3 damage with a `"LEECHES. GODDAMN LEECHES."` toast (`player.gd:312-317`). That
  single feature does more for Pillar 2 than the shader rewrite.

**What this costs.** We give up "the river as a wall" — the tactical read where a squad is pinned
against water it cannot cross, which is a genuinely good firefight setup and a real Vietnam experience.
We also give up depth as an expressive axis: with nothing deep, water is a texture, not a hazard.
**The honest mitigation is ONE named trunk river per AO with authored fords** — deep in the middle,
crossable at 2–3 marked points. That preserves the wall *and* keeps freedom, because the crossings are
discoverable rather than absent.

**If the council declines the trunk river, then under ADR-023 `WADE_DEPTH_M` and the
`gameplay_grid.gd:136-139` branch are FOSSILS and must be DELETED in the same change** — a gate that
can never fire is precisely the lie-in-the-map the FOSSIL LAW exists to kill. Do not leave it there
"in case."

---

## 5 · DOES WATER DO ANYTHING? Yes — more than expected, and almost none of it is movement.

**LIVE wiring, with pointers:**

| Effect | Where | Reads |
|---|---|---|
| Footstep audio swaps to a wade | `scripts/player/player.gd:309-310`; `scripts/autoload/audio_manager.gd:129-139` | `grid.is_water()` |
| **Leeches** — 3 dmg + toast after ~20 wading steps | `player.gd:311-317` | `_wade_timer` |
| **Trail-breaking** — no breadcrumb laid while the target is in water | `scripts/enemies/enemy_base.gd:1006-1008` → `scripts/enemies/enemy_squad.gd:244-260` (early-out `:253-254`) | `grid.is_water(target.global_position)` |
| Gallery forest / concealment belt | `gameplay_grid.gd:177-226`, roofing `:232-267` | WATER cells as BFS seeds |
| Roads ford water at a cost premium instead of routing around | `scripts/world/road_network.gd:163-167` (`WATER_COST 24.0`, `:40`) | `MOVEMENT_COSTS` |
| Site placement rejects water | `scripts/world/site_planner.gd:102, 105, 483, 630, 646, 1190`; `scripts/missions/mission_generator.gd:144` | `is_water` / terrain type |
| Ground clutter suppressed on water | `scripts/world/ground_clutter.gd:202-206` | `is_water` |
| Topo map draws it blue | `scripts/ui/topo_map.gd:81-82` → `scripts/ui/topo_sheet.gd:109-110` | `is_water` callable |

**DEAD or missing:**

- **Movement.** `MOVEMENT_COSTS[WATER] = 99.0` (`gameplay_grid.gd:34`) is read by **exactly one
  caller in the repo** — `road_network.gd:163` — and that caller immediately overrides it to 24.0
  (`:165-167`). **No man, ally, enemy or player, is ever slowed by one centimetre of water.** The
  player's only water speed penalty is keyed to RICE_PADDY (`player.gd:1707`), the terrain type that
  has no water in it (§2).
- **Passability.** Never fires (§4). Water is universally passable.
- **Concealment while IN the water.** `COVER_VALUES[WATER] = 0.0` (`gameplay_grid.gd:46`) — and
  `COVER_VALUES` has **zero readers repo-wide**; concealment runs through `vegetation_density`, where
  water is 0.0 unless roofed (`:290-292`), and at shipped widths it is never roofed (§3). **Going prone
  in a stream gives you nothing.** In life, lying in a creek under overhang is the single best
  concealment a recon man has.
- **Trail-breaking is weaker than its comment claims.** `enemy_base.gd:1004` gates the whole block on
  `has_line_of_sight`. **Crumbs are only ever laid while an enemy already sees you** — so wading only
  denies sign during the moments you are already being observed. The E&E fantasy in
  `probe_riparian.gd:5-6` ("water breaks the enemy's breadcrumb trail") describes a stronger system
  than the one wired.
- **No wet state.** No visual soaking, no weapon-fouling, no scent/dog mechanic, no sound-masking of
  your own movement by running water — the last being the cheapest atmosphere win on the board and
  the one a Vietnamese stream is actually famous for.

---

## 6 · WHAT I WOULD DO, IN ORDER

1. **Re-tune the width distribution** (`hydrology_map.gd:62-64`) to 2–10m, and promote a single
   highest-accumulation trunk to 20–30m by a separate rule. This alone collapses the ±half_w bank
   sampling defect, un-starves the roofing code, and makes the E&E route real.
   *Sacrificed:* less total wetted area → fewer riparian seeds → less heavy jungle → higher sight caps
   map-wide. Compensate by raising `RIPARIAN_M` 22 → ~30.
2. **Resolve the carve-resolution trap** — creeks under ~6m are laid on the surface, not carved
   (route A, §1), or `CELL_SIZE` drops to 2.0 (route B, a 4× terrain bill that is the technical
   director's call, not mine).
   *Sacrificed under A:* creeks give no defilade, so the E&E route has concealment but no cover.
3. **Port the paddy water pan out of `JunglePatchLayer` into the TreeCover path.** It is finished art
   stranded in the arena and it is the most iconic water in the setting.
   *Sacrificed:* one transparent draw call per paddy chunk, and `PaddyStamper`'s rice props must be
   re-seated onto the quantised pan height or they will float / drown.
4. **Make water slow you** (mirror `player.gd:1707-1708` onto WATER at ~1.4×, gentler than the paddy's
   1.8), **and give the roofed creek a concealment floor** so prone-in-the-stream is worth something.
   *Sacrificed:* a small readability cost — the player will not always know why he slowed down.
5. **Rule on `WADE_DEPTH_M`.** Either it gets a trunk river deep enough to fire, or it is deleted with
   the `gameplay_grid.gd:136-139` branch under ADR-023. **It does not stay as-is.**
6. **Delete `Type.CREEK` or make it reachable.** As of today it is a body type that nine comments
   describe and the generator cannot emit.

---

## 7 · WHAT IS SACRIFICED, CONSOLIDATED

- **A smaller water footprint means a thinner jungle.** Every recommendation in §6.1 removes WATER
  cells, and WATER cells are the seeds for the densest vegetation in the AO. Unmitigated, this is a
  stealth nerf to concealment and a stealth buff to AI lethality. `RIPARIAN_M` must rise to pay for it.
- **Losing the wall.** No impassable water means no terrain-enforced chokepoint. Firefights lose one
  good geometry. The single trunk river with fords is the partial refund, and it costs authoring work
  the procedural generator does not currently do.
- **The trunk river re-introduces the very rail Pillar 3 dislikes**, only deliberately and only once
  per AO. That is a judgment call, and it is the Summoner's, not mine.
- **The paddy pan port costs draw calls** on the Intel-UHD floor (ADR-026), in the exact biome
  (lowland, near villages) where the most props already are.
- **All of this is generator re-tuning, so every seed changes.** Village siting reads the paddy
  classification (`paddy_stamper.gd:55`, floor asserted `:70-75`); firebase and site placement reject
  water (`site_planner.gd:102, 483, 630, 646, 1190`); roads route on the same grid
  (`road_network.gd:163-167`). **Existing seeds — including any the Summoner has playtested — will
  produce different worlds.** That is not a bug, but it must be said out loud before the change lands.
