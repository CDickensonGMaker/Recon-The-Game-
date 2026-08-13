# Devil's Advocate — audit of TODAY'S OWN WORK (f6b323a6 napalm scale, a5d077a7 nav-truth)

Date: 2026-08-13. Both diffs read in full; every finding below was verified against the
working tree at a5d077a7, pointers are file:line in that state. Severity ladder:
SHIP-BLOCKER / DEFECT / DRIFT / NOTE. **Nothing today is a ship-blocker for the demo
path; two DEFECTs are armed and will fire on the next export or the first crewed
Chinook.**

---

## DEFECT 1 — stray-parapet twin lookup searches a tree the twins have already left
`scripts/world/site_planner.gd:1718` (the stray pass), cause at `:1685` + `:1746-1793`

The manifest loop wires each segment via `_wire_parapet_segment`, which does
`_parent.add_child(d)` then `mi.reparent(d, true)` — the mesh leaves `root`'s subtree
(`d` is a SIBLING of root; root is added to `_parent` at `:1316`). The stray pass then
runs `root.find_child(base, true, false)` at `:1718` to find the stray's manifest twin.
**Every wired twin has already been reparented out of `root`, so `twin` is null for every
stray whose base is a manifest segment — which is the only kind of stray the pass was
built for.**

Consequences:
- The duplicate branch (`:1719-1725`, co-located → hide + disable colliders) is
  **unreachable dead logic**. A true export duplicate sitting on its twin will be
  ADOPTED instead: a second Destructible stacked at the same spot — doubled collider,
  z-fighting mesh, two entries in `FSB_PARAPET_GROUP` at one bearing. SiegeDirector
  reads breach state off that group: one dies, its stacked twin still stands, the
  breach never reads open there, and sappers spend a second satchel on a wall the
  player watched die. The exact failure the pass shipped to prevent.
- The adoption print at `:1731-1732` reports `manifest twin %s absent` when the twin
  exists but was reparented. Today's boot log for `fb_sbg_seg_046_001` therefore said
  "absent" for a twin that is present — **the verification printed today does not prove
  the branch logic; 046_001 landed on the right branch by accident** (it stands apart,
  so adoption was correct — but it got there because the lookup failed, not because
  the distance check measured it apart).

Fix shape: resolve the twin from the manifest (`seg_by_name.has(base)` + the segment's
recorded position), or snapshot mesh globals before the wiring loop, or search
`_parent`. Cheap either way.

Severity: **DEFECT** — latent for duplicates (today's export has none co-located),
live log-lie today.

## DEFECT 2 — CH-47 door guns aim out the NOSE: `_door_target` still hardcodes the Huey door axis
`scripts/vehicles/seat_system.gd:265-270`, wired live by today's `_layout()` refit
(`:261`, `:313`)

```gdscript
# The door's outward normal in world space: +X for the left seat, -X for the right.
var outward: Vector3 = body.global_transform.basis.x \
        * (1.0 if (entry[0] as Vector3).x > 0.0 else -1.0)
```

The outward normal is derived from the SIGN OF THE SEAT'S LOCAL X — the UH-1
convention (nose -Z, doors on ±X). The ch47 layout puts both gunners at x = -2.6,
z = ±0.70 (nose is **-X**, doors are on **±Z**, per probe_chinook_dims). So on a
Chinook **both** door guns compute `outward = -basis.x` — straight out the nose.
Both arcs collapse onto the cockpit axis; `GUN_ARC_DEG` gates targets against the
wrong bearing; muzzle POSITIONS are right (they come from the layout) while tracer
ARCS select nose targets. The seat yaw (`entry[1]`) already encodes the true facing
for every airframe — the fix is to rotate `basis` by the seat yaw instead of reading
the x-sign.

Armed-vs-live: `gunners_firing` is flipped by `air_traffic.gd:365-368` for gun-orbit
ships, and `_crew_gun_orbit` (air_traffic ~`:345`) currently crews only the gunship
Hueys — so no demo exposure TODAY. The first hot-LZ beat or crewed-Chinook feature
fires it. Also note `_tick_door_guns` (`:240-253`) has **no occupancy check** — the
gate is `gunners_firing` alone, so the moment that flag reaches a Chinook the bug is
visible without anyone ever seating a gunner.

Severity: **DEFECT** (armed, not demo-live). The `:265` comment is now false for ch47
— fix with the same edit.

## DRIFT 3 — the socket auto-generate print says "UH-1" for every airframe
`scripts/vehicles/seat_system.gd:454`

`"[SeatSystem] %s: auto-generated %d/%d UH-1 fallback sockets"` — a Chinook boot now
prints `auto-generated 18/18 UH-1 fallback sockets` while seating the ch47 layout.
This is the one log line a person checks to confirm today's fix landed, and it asserts
the pre-fix state. Print `String(fallback_key)` instead. (No-drift law, violated inside
the very feature that shipped today.)

## DRIFT 4 — probe_chinook_dims header describes the defect it fixed as live
`tools/probe_chinook_dims.gd:2-4` — "FALLBACK_LAYOUT is Huey-measured; the Chinook
inherits it and men unseat inside the fuselage." Both clauses are now history: the
const is `FALLBACK_LAYOUTS`, and the Chinook no longer inherits uh1. The measuring
instrument's own premise line reads as a live bug report. One-line reword.

---

## Attacks that came back CLEAN (each verified, pointers given)

**Correctness (brief item 1)**
- `_flip_faces` loop (`nav_baker.gd:551`): `range(0, size-2, 3)` covers exactly the
  triangle starts for any multiple-of-3 array; ConcavePolygonShape3D faces are always
  triangles, so the resize-then-fill cannot leave zero-vertex garbage. No off-by-one.
- `_cull_above_base` shared use (`nav_baker.gd:597-616`): base computed after the
  match check exactly as the pre-refactor `_cull_roof_faces` did; roof-listed families
  get identical results on original faces, and flipped faces of ALL non-ground
  families get the same rule — matches the commit's stated intent. The flip only ADDS
  faces, so nothing that walked before stops walking.
- Stray-adoption regex `^(.*)_[0-9]+$` (`site_planner.gd:1714`): greedy match strips
  exactly the last ordinal; a manifest-less bare segment (`fb_sbg_seg_081`) degrades
  to base `fb_sbg_seg` → `{}` → adopted with the same sandbag_wall/140 defaults the
  manifest loop uses. Acceptable. (The twin LOOKUP is Defect 1; the regex is fine.)
- CH-47 SEATING yaws vs measured axes (nose -X, walls z ±0.9): pilots yaw -90 →
  facing -X = nose ✓; pax/bench z=∓0.65 yaw 0/180 → facing across the bay ✓; gunners
  z=±0.70 facing outboard ✓. The layout is right; only the door-gun AIM math (Defect
  2) still speaks Huey.
- StringName keying: `FALLBACK_LAYOUTS`, `fallback_key`, `SEAT_NAMES`, and every
  lookup are uniformly StringName (and Godot 4 hashes String/StringName identically
  regardless). Both layouts carry all 18 `SEAT_NAMES` keys — `_layout()[seat_name]`
  at `:444` cannot KeyError.
- Napalm composition (brief item 4): cache keys `napalm_fire/core/ember/linger_proc`
  are kind-unique; each configurator lambda is created in the call that misses the
  cache, so the captured `is_napalm` always matches the key. `ring`/`ring_mat` are
  null-guarded before both tweens (`gun_fx.gd:554-556`); the tween always holds the
  quad+mat tweeners, so no empty-tween or null crash path. `_scorch` clamp (44m) now
  sits UNDER napalm's ~60m visual — footprint-honest.
- `MAX_LINGER 9 == FirePlan.NAPALM_DROPS` ✓ (`gun_fx.gd:315`, `fire_plan.gd:31`).
- support_fire_range input: keycode is modifier-free so SHIFT+1 still lands KEY_1;
  bracket steps are echo-gated (`:593`); `[`/`]` clamp 0.2–3.0.
- vfx_range: `_sign` exists (`:253`), broadleaf GLBs exist on disk, `_fire_run`'s
  int-division center offset matches `cas_airplane.gd:410` exactly, timer lambdas
  guard `is_instance_valid(self)`.

**Hidden consumers (brief item 2)**
- `SeatSystem.FALLBACK_LAYOUT` (old name): zero live code references remain — hits
  are production docs, `make_huey_interior.py` comments (values copied verbatim, not
  read), and the probe header (Drift 4). Nothing hard-crashes.
- `FellableTree`: comments only (`test_support_fire_bench.gd:70`,
  `tree_break_system.gd:322`). No parse-dead stragglers.
- `_KIND_SCALE` external readers: `probe_fire_parity.gd:48-51` (iterates, still
  valid) and an audio_manager comment. `rendered_width_m` read only by the ruling
  bench.
- backface ordering: `backface_collision` is written ONLY by
  `site_planner._force_backface_collision` (`:1420`, called `:1488` during the stamp
  at `:1320`) and read ONLY by the nav flip (`nav_baker.gd:525`). NavBaker exists
  only under mission_generator (`:972-980`) and bakes sites after stamping; benches
  never construct a NavBaker; probe_bunker_entry rides the real generator. The flag
  lives on the shape RESOURCE, so parapet reparenting (repair runs BEFORE wiring,
  `:1320` < `:1322`) and mid-siege breach re-bakes keep it. Every path ordered
  correctly.

**The knob (brief item 3)** — `bench_size_mult` reset verified: `reset_session()`
zeroes it (`gun_fx.gd:28` region), sole caller `MissionScope.reset()`
(`mission_scope.gd:29`) runs in `game_flow._teardown_world` (`game_flow.gd:411`) on
every mission end and menu return. The benches are standalone scenes with no in-game
route (no change_scene into them), so a bench process can never hand its multiplier
to a demo run. No leak path found.

**probe_fire_parity refit (brief item 5)** — `register_chunk` keys by
`layer.get_instance_id()|coord` (`tree_break_system.gd:69-70`): Vector2i.ZERO reuse
across rings cannot collide. `_consume` (`:244-258`) erases from `_chunks`
synchronously, so `registered_count()` deltas are honest at read time.
`unregister_layer` (`:111-122`) sweeps every key of the layer; the probe's plain
Node3D layer is safe (`has_method` guards at `:263`, `:268`). Rings sit 90m+ apart
vs NAPALM_BLAST_M 30 — no cross-ring felling, and each ring dies before the next
registers, so neither leftovers nor the fort can touch a later felled count.
Residual (pre-existing, NOT today's regression): `_count_fire_hazards` is global,
so napalm's `fires >= 9` check can be part-satisfied by WP leftovers from the prior
window; felled>0 + release-count remain the strong assertions. `quit(_failures)` as
exit code is quirky but correct.

**Claims vs proof (brief item 6)**
- "world-matched fog": verified — 0.0065 both (`support_fire_range.gd:196`,
  `game_world.gd:84`); honest caveat that MissionWeather diverges from CLEAR.
- "Hut deaths ride the napalm kind": confirmed `destructible.gd:42-44` BLAST_FOR.
- "capsule-blocked 19->4 / interior 30/5-of-35 identical to baseline": honestly
  stated as measurements, but note the instrument READS RED — probe_bunker_entry
  exits 1 while 5 interior off-mesh + 4 blocked remain (`probe_bunker_entry.gd`
  final quit). Correct behavior for an honesty instrument; anyone scripting the
  suite must not read that exit as a today-regression.
- "stray parapet HANDLED (duplicate->hidden, offset->adopted)": **half-proven.**
  Adoption is proven by the boot; the duplicate-hidden branch has never executed
  and cannot (Defect 1). The commit message over-claims the pass as handled.
- test_seat_system envelope: valid today because sockets are auto-generated at the
  vehicle root (`_scan_sockets` `:447-449`); if a future chinook GLB ships real
  `seat_*` empties deep in the Model subtree, `sock.position` becomes subtree-local
  and the root-space envelope comparison is meaningless. Guard when that export
  lands. Discriminator is trivially satisfied (uh1 pilot z -5.35) but does its job.

**NOTE — decree coverage gap, no regression.** Elevated floors (>1.9m over their
shape's base) of inward-wound non-ground shapes stay nav-invisible: their original
faces contribute nothing and `_cull_above_base` removes their flipped faces (tower
platforms are the visible case — `NAV_ROOF_CULL_PREFIXES` deliberately omits
fb_tower, but the flip cull catches it anyway). Towers move by ladder markers, so
no demo exposure; "the AI walks ALL the real geometry" is delivered up to the roof
line only.

**NOTE — nav source now ~doubles FSB geometry** (polys 4272→9557, 1970ms async
bake): breach re-bakes mid-siege pay the doubled cost. The new per-bake `ms=`
instrument is the right watch; no action until it says otherwise.

## Verdict for the Arbiter
Fix before end of day: Defect 1 (twin lookup — cheap, and the log currently lies),
Defect 2 + Drift 3/4 in one seat_system/probe touch-up. Everything else measured
clean or honestly caveated.
