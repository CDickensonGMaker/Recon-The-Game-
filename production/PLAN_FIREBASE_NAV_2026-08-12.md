# PLAN — firebase, navmesh and interiors, 2026-08-12

25 steps. Ordered by dependency, not by size. Sources: `HANDOFF_CODE_FIXES_2026-08-12.md`,
`war_room/analysis/technical_director_nav_2026-08-12.md`, and the measured shortfall below.

**The open defect this plan exists to close:** FIX 0 landed partially. Measured on
`demo_game`, firebase bake, before → after:

```
colliders  106 → 163      (+57; the criterion is +80)
verts     2600 → 2647
polys     3236 → 3409     (expected to FALL, not rise)
```

23 parapet segments still hand over no collider, and `[NAV] ally … 70.3m to target, no path`
persists in the demo boot. **Nothing in this plan may be recorded as verified on a reading —
each phase names the number that discharges it (ADR-015).**

---

## PHASE A — DISARM THE EXPORTER (nothing else is safe first)

Every phase below eventually implies a re-export. `tools/gen_firebase_v3.py:918-930` purges
every zero-user datablock and then `save_as_mainfile` **over the artist's source**. This is the
call that destroyed the medical complex on 2026-07-31.

1. **Back up the firebase kit** — `firebase_v3.2.blend` and the `_archive_2026-08-12/` folder,
   off the working disk. `recongame-single-disk-risk` applies; do this before touching the
   exporter, not after.
2. **Remove `save_as_mainfile` from the exporter** (`gen_firebase_v3.py:929`). The export does
   not need it. If the purge is genuinely wanted it runs on a **copy**, never the artist's file.
   *Gate: a full export leaves the source `.blend` byte-identical (hash before/after).*
3. **Grep for any other `save_as_mainfile` / `bpy.ops.wm.save` across `tools/`.** One disarmed
   exporter is not a disarmed pipeline.

## PHASE B — FINISH FIX 0 (the missing 23)

4. **Instrument `_wire_parapet_destructibles` and `_adopt_structure`** to print, per segment:
   mesh name, whether a child body was found, whether a sibling `-colonly` was found, and how
   many shapes were moved. Temporary — it comes out in step 8.
5. **Run the demo boot and read the table.** Three hypotheses, and the log distinguishes them:
   (a) the segment genuinely has no `-colonly` twin in the GLB; (b) the sibling name does not
   `begins_with(mesh name)` — export ordinals or a `.001` suffix; (c) the shape is dropped later
   by `_add_colliders`' `_xz_contains(box, …)` or the `NAV_IGNORE_PREFIXES` test.
6. **Fix the cause the log names.** If (a), it is an art gap and goes on the ART log, not here.
   If (b), match on a normalised stem instead of a raw prefix. If (c), widen the box test or
   correct the ignore contract.
7. **Re-measure.** *Gate: `[NavBaker] bake done … geom=186 colliders` — 106 + 80. Not 163.*
8. **Remove the instrumentation** and re-run once to confirm the number holds without it.
9. **Resolve the polygon anomaly.** `filter_walkable_low_height_spans = true` was meant to
   delete the buried layer under the mound and LOWER polys; they rose. Determine which:
   the layer is not there, the filter is not taking, or the new obstacles added more edges than
   it removed. Print `cell_height` and `agent_max_climb` at bake to confirm PHASE A's
   `[navigation]` section actually reached the server.
   *Gate: `agent_max_climb` prints 0.40, not 0.25.*
10. **FIX 3c — one ground.** Lift `_add_terrain`'s samples to the mound surface via
    `SitePlanner.fsb_mound_height()` (already a public static, `site_planner.gd:742`) so the
    baker stops being fed two grounds and `map_get_closest_point` has no wrong choice to make.
    *Gate: polys fall against step 7's number with reachability unchanged or better.*
11. **Re-run the `[NAV]` warning count on a full demo boot.**
    *Gate: `no path` warnings inside the compound reach zero. This is the real gate — the
    collider count is only its proxy.*

## PHASE C — INTERIORS (FIX 2)

12. **Confirm the double-seal** at `site_planner.gd:176-185` and `nav_baker.gd:441-469`: the
    model carries `-col` trimeshes that leave the doorway physically open, while the same model
    stays in `nav_blockers` with a full-footprint `nav_box`. Doorway open, navigationally sealed.
13. **Make enterable structures carve their doorway, not their footprint.** Enterable kinds
    stop contributing a `nav_box` and contribute their real trimesh instead — the same treatment
    the firebase itself already gets, and for the same stated reason.
14. **Verify a man walks in.** *Gate: an ally ordered to an interior point paths inside without
    falling back to direct steering; a probe asserts a navmesh polygon exists under the bunk.*

## PHASE D — STOP THE ROOF SPAWNS (FIX 3)

15. **`field_director.gd:46` ally seating → `floor_y`.** This is the squad, every mission.
16. **Review `game_flow.gd:232, 280, 689, 696` one at a time.** `:689` already carries the
    comment *"surface_y()'s top-down raycast misses the hootch"* — the fix was known and never
    propagated. **Do not blanket-replace:** `surface_y` is correct for open ground and exists to
    clear the mound.
17. **Review `demo_game.gd:262`** against the same rule: interior/authored → `floor_y`,
    arbitrary outdoor → `surface_y`.
18. **Add a spawn-height probe** that fails when any spawned man's feet are above a `-colonly`
    roof. *Gate: zero men on roofs across three seeds.*

## PHASE E — MAKE THE DEFAULTS LOUD

19. **`collision_table.gd:182` — `push_warning` on the `get_entry` fallback.** A 12m HQ tent
    currently gets a silent 3×2×3 nav carve and men path through canvas. Match `is_soft()`'s
    wording, which already warns.
20. **Add a test that fails when a model in `STRUCTURES` has no `MATERIALS` entry.** This is
    FIX 5's real answer — `"hooch"` substring-matching to SOFT is loud but a *"dug-in earth
    bunker hooch"* would still ship shootable-through.
21. **Sweep for the same shape elsewhere.** Four silent defaults were found in one day
    (`explosion_heavy` blast fallback, the silent-VO no-op, the any-point blast check,
    `agent_max_climb`). Grep `.get(` with a literal default across `scripts/` and triage.

## PHASE F — SCREEN DOOR (FIX 6)

Built and compiling: `scripts/world/screen_door.gd`, hung by `SitePlanner` after structures are
adopted, `door_` added to `NAV_IGNORE_PREFIXES`. **It hangs nothing today — the GLB has no
`door_*` nodes.** Blocked on art, and on PHASE C: a spring door on a sealed room is decoration.

22. **Author `door_*` leaves** on the hooch doorways in the firebase blend. Leaf is visual only:
    no collider, no `nav_blockers` membership. **Do this only after PHASE A** — before it, a
    re-export can eat the work.
23. **Re-export and confirm** `[FSB] screen doors: N hung`.
24. **Verify the ruling holds** — *"if the firebase ever gets over run you can hide in the hooch
    and enemies can come in."* *Gate: an enemy paths through the doorway with the leaf shut; the
    leaf never stops a bullet; the navmesh under the threshold is unchanged with the door
    present.*

## PHASE G — CLOSE IT

25. **Full demo playthrough by the Summoner** (ADR-015 — no probe discharges this), then the
    suite, then record the outcome in the tracking docs and Claude memory, then `git push`.
    *Gate: `git status` shows up to date with origin.*

---

## 26 — LOW COVER: make a downed tree usable *(added 2026-08-12, deferred to LAST by ruling)*

**Measured, not suspected.** `--fell-cover-probe` on the support fire range: 5 logs felled and
standing as `hard_surface` colliders inside the squad's cover reach, and **0 of 4 living men
claimed one**. Every claim landed 2.3–7.1m from the nearest log against a 2.5m blocker limit.

**The mechanism:** the log capsule sits at `y=0.5, radius ~0.35` (`tree_break_system.gd:450-463`)
— top ~0.85m. The ally cover search casts from `candidate + 1.3m` toward a threat at 1.0m
(`ally_base.gd _sweep_cover`), and that ray passes **over** the log. The timber is real, solid,
on layer 1 and in the right group; the search only knows how to be **standing**.

This is a DESIGN call, not a defect fix — whether men go prone behind low cover — and it touches
the cover geometry BOTH brains now share. **Deliberately last**: it changes posture, which
changes silhouette, exposure and the suppression exchange all at once, and none of that should
move while the nav work is still settling.

---

## 27 — ROADS ARE INVISIBLE *(added 2026-08-12 from his playthrough)*

*"convoys are rolling thru the jungle but theres no visible roads in the terrain being made"*

`mission_generator.gd:942` calls `road_network.clear_corridor(...)`, and the planner's own comment
at `:595-600` states the corridor clear is **the one write a road performs**. It removes
vegetation. **Nothing paints a surface** — no texture, no splat, no ruts, no verge. A convoy
therefore drives down a lane of missing jungle.

Note this collides with a known constraint: `terrain.gdshader` has **one tiled `jungle_floor` set
plus vertex colour, and no splat system** (found while chasing the riverbed texture — the same
reason a creek bed cannot be sanded). A road surface and a river bed want the same missing
machinery, so **cost them together, once.**

## 28 — THE ROUTE IS CHOSEN BEFORE THE BUILDINGS EXIST *(same playthrough)*

*"the route was thru a village and its buildings so that means the navigation routes need to be
built after all the worlds buildings and than geography is made"*

**He is right, and the code says so out loud.** `RoadNetwork.build(gate, villages)` runs at
`mission_generator.gd:604`, inside `plan_patrol_world`, which `:597-598` explicitly keeps
"side-effect free" — the stamps happen later in `build_patrol_world`. So the route is chosen
against **village CENTRES**, with no building footprint in existence yet to route around.

A road *reaching* a village is correct — the network is hub-and-spoke, gate to villages, by
design. A road *through the huts* is the defect.

Two candidate fixes, and they are not equivalent:
- **(a) Re-order** — plan the route after the stamps, so footprints exist to avoid. Cleanest
  conceptually and it is what he asked for, but it breaks the side-effect-free property that
  `plan_patrol_world` was deliberately built to have, and `ambush_planner` already consumes the
  traffic lines during planning (`:52,90,98`).
- **(b) Reserve, then stamp** — keep planning first, but have the stamp pass treat the corridor
  as a keep-out, the way `_fsb_keepout` already works for the firebase (`:113-115`,
  `FSB_SITE_CLEARANCE`). Huts move off the road instead of the road bending around huts.

**(b) is probably right** — the project already has exactly this pattern for the firebase, and it
preserves an architectural property that was chosen on purpose. But it changes village layout,
so it is HIS call. **Do not start this without a ruling on (a) vs (b).**

---

## 29 — THE DUST SPLAT ALREADY EXISTS *(added 2026-08-12; supersedes the "build a splat system" half of 27)*

**There is no splat system to build.** `clearing_system.gd:77` already keeps a full-map **RGBA8**
`Image`, writes colour AND alpha per pixel at `:216`, hands it to the shader at `:235`, and
`terrain.gdshader:99-100` applies it as `color = mix(color, clearing.rgb, clearing.a)`. The engine
can already paint any colour at any alpha anywhere on the map, and it is already doing it for
cleared jungle. That texture is sampled on every terrain pixel every frame whether it is used or
not, so a road costs **nothing new**: no sampler, no uniform, no material, no art.

And the road already knows where to paint. `road_network.clear_corridor()` is, by the planner's
own comment, "the one write a road performs" — it walks the corridor pulling vegetation. It simply
does not stamp the mask while it is there.

**Build the TINT version** — dust colour along the corridor, feathered at the edges. At PSX
fidelity a flat dustier band reads correctly, and it is hours, not days.
- *Not* a second ground tile set: three new textures and a blend to gain ~20% at this resolution.
- Traffic wear (the busiest spoke barer than a footpath) is a later refinement on the same
  mechanism — `longest_route()` already identifies it, and the topo map already draws it as an
  improved double line.

**The riverbed rides the same change.** Sand or silt in a creek bed was blocked on exactly this
missing capability, and it was never missing. `hydrology` knows where the channels are.

**KNOWN CAVEAT:** the mask is authored at `vegetation_size`, not terrain resolution. A 10m road may
render as a soft band rather than a crisp edge. Arguably correct at PSX fidelity — but look before
ruling.

---

## HIS RULINGS, 2026-08-12 (asked plainly, answered)

- **Roof markers → BLENDER.** He drops the `work_rest_*` / `work_supply_*` empties onto their
  floors in `firebase_v3.2.blend` and re-exports. **No code clamp** — the data gets fixed at
  source. PHASE A is done, so the re-export is safe. **PHASE D's gate stays open until he does.**
- **Temple statues → ART.** He authors `-colonly` twins for all 14, so the temple ruins become
  real cover rather than honest decoration. The `mesh: true` flag STAYS and becomes true.
- **Road routing → RE-ORDER (step 28).** Plan the route AFTER the stamps, so it bends around real
  footprints. He chose this over the keep-out. **I advised the keep-out and he ruled otherwise;
  that is his call and it is made.** The cost I named is now MY problem to solve: it breaks
  `plan_patrol_world`'s side-effect-free property, and `ambush_planner` reads traffic lines
  DURING planning (`:52,90,98`), so moving roads later would blind it. The fix is a dependency
  re-order, not a demotion: sites → stamps → roads → ambushes.
- **Silent defaults → AFTER THE PLAN.** The 15-item register stands as recorded debt in
  `SILENT_DEFAULTS_2026-08-12.md`. Do not detour into it.

---

## WHAT THIS PLAN DELIBERATELY DOES NOT DO

- **No Blender remodelling.** The nav architect's finding stands: the GLB is fine — 1,259 nodes,
  148k collision tris, correct `-colonly` twins. All five failures were runtime code.
- **No splitting the mound into a scene.** `NAV_IGNORE_PREFIXES` is a NAME contract; a rename
  silently re-admits 178 cots to the bake with no error.
- **No `ZombieDoor` pattern for the hooch.** It needs NPC open-door behaviour, which does not
  exist repo-wide: zero `AnimatableBody3D`, zero `doors` group, zero `door_open` in `scripts/`.
  Hold it for the officers' HQ tent.
- **`game_flow.gd:178` — 8 hootch visuals against 4 `-colonly` bodies** is an art defect and
  belongs on the ART log, not in this plan.
