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
