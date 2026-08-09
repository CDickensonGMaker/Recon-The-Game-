# Huey v3 — merged, exported, wired. 2026-08-08

Supersedes the 2026-08-05 close-out. Both open items from that document are CLOSED.
Every number below was measured headlessly on 2026-08-08; nothing here is re-derived
from the 8/5 read.

## What is live

`scenes/vehicles/huey.tscn` now instances **`assets/us/vehicles/huey_v3.glb`**, Model
**unrotated**. `assets/us/vehicles/huey.glb` (v1) is untouched on disk and no longer
wired — the four shipped `heli_*.glb` staged clips still bake v1 geometry, so it stays.

Trunk blend: `assets/us/vehicles/huey_v3.blend`, **114 objects**.

## OPEN #1 — RESOLVED. v3 is the trunk; the doors came across.

Verified by full object-set + per-object transform diff of both files before merging:
the ONLY divergence was the object sets. **Zero common objects differed** in location,
rotation, scale, vertex/poly count, parent, world bounds or materials.

Merged in from `huey_v3_transport.blend` (six objects, not the four the 8/5 read
listed — the rails were missed):

| object | type | tris |
|---|---|---|
| `door_l`, `door_r` | MESH | 12 each |
| `door_rail_l`, `door_rail_r` | MESH | 12 each |
| `door_l_socket`, `door_r_socket` | EMPTY | — |

Four duplicate `huey_hull.00N` materials the append dragged in were remapped onto the
original `huey_hull` and removed.

**`huey_v3_transport.blend` is now a strict subset of the trunk and is DEAD.** Do not
author into it. It is left on disk only until Caleb says to delete it.

## OPEN #2 — the `Cube` / `Cube.001` panels were ALREADY renamed

They are **`cabin_panel_aft_l`** and **`cabin_panel_aft_r`** — same 0.075 × 1.015 × 1.153
boxes, same places (x 0.631–0.706 and −0.794–−0.718, y 1.968–2.983, z 0.699–1.852).
Some pass between 8/5 and now renamed them and the 8/5 doc went stale. They were still
material-less; they now carry `huey_hull`. **They still want Caleb's eye** — the name is
a measured guess from where they sit (aft cabin, inboard of the door frames, floor to
ceiling), not something he ruled.

`REF_Inside1` is **not** drifted either — it measures x −1.230…1.470, overlaid correctly.
That 8/5 warning is also stale.

## THE LANDMINE — defused, and it was bigger than diagnosed

`huey-backwards-run-diagnosis` landmine 3 said: huey.tscn mounts Model flipped 180°, so
real `seat_*` empties would invert every occupant. True, and there was a **second, worse**
fault in the blend itself.

**Convention under test** (name it or it drifts — this repo has three):
- *Vehicle asset law*: nose Blender +Y → Godot −Z, the same forward
  `helicopter.gd:_process_flying` steers with `atan2(-dir.x, -dir.z)`.
- *Seat socket*: occupant faces the socket's local **+Z**, up is local **+Y**
  (`scripts/vehicles/seat_system.gd:9-11`).

**Fault A — the scene flip.** v1's nose was Godot **+Z**, so `huey.tscn` carried
`Transform3D(-1,0,0, 0,1,0, 0,0,-1, …)` on Model to point it down −Z. v3's nose is already
−Z. The flip is **removed**; Model is identity. Left in, it would have negated the X and Z
of every socket basis and seated the whole load backwards.

**Fault B — the seat empties' own rotation, in the blend.** All twelve `seat_*` empties
were authored `rot_euler = (90°, 0, ±90/180)`. Measured empirically by exporting probe
empties to `.gltf` and reading the node quaternions: **an `rx=90` empty exports with Godot
local +Z = (0, −1, 0) — straight DOWN.** Every seated man would have faced the floor lying
on his side. Nothing in the 8/5 read caught this because nothing had exported the sockets
yet. Fix: **zero the X euler on all twelve.** The authored Z euler was already correct.

Proof, in-engine, `res://tools/probe_huey_frame.tscn` (rewritten from the v1-only probe):

```
[SeatSystem] Huey: all 10 seat_* sockets found in the model - fallback table retired
Model.transform = [X: (1,0,0), Y: (0,1,0), Z: (0,0,1), O: (0,0,0)]
fuselage_fwd centre z = -2.785 | fuselage_aft centre z = 3.600      <- nose is -Z
seat_pilot_l    pos=(0.55, 1.125, -5.185)   face=(0,0,-1) up=(0,1,0)
seat_gunner_l   pos=(0.96, 1.13, -2.384)    face=(1,0,0)  up=(0,1,0)
seat_gunner_r   pos=(-0.96, 1.13, -2.384)   face=(-1,0,0) up=(0,1,0)
seat_pax_1..4   face=(1,0,0)   seat_pax_5..7 face=(-1,0,0)
PASS: huey_v3 frame + seat socket contract OK
```

`FALLBACK_LAYOUT` (`seat_system.gd:37-49`) is now dead for the Huey — the probe prints
"fallback table retired". Its coordinates assume nose = −Z with `Door_Left = +X`, which
still describes v3, but nothing reads it any more.

## Measured export — `assets/us/vehicles/huey_v3.glb`, 1.16 MB

Parsed straight out of the GLB in the glTF/Godot frame (no Blender re-import, which would
re-apply the axis conversion and hide the truth): `verify_glb.py`, scratchpad.

| measure | v3 | target / v1 |
|---|---|---|
| nodes / meshes / materials | 110 / 73 / 23 | — |
| tris | 41,364 | v1 = 1,446 |
| baked animations | **0** | v1 shipped 6 rotor tracks |
| full bbox (rotor tip to rotor tip) | 14.630 × 4.410 × 14.215 | main rotor 14.63 ✔ |
| airframe bbox | 2.845 W × 3.003 H × **12.900** L | fuselage 12.77 + tail fin ✔ |
| fuselage alone, nose to tail | **12.770** | 12.77 ✔ exact |
| lowest point | **y = 0.000** | v1 = −0.12 (sunk) |
| origin | on the airframe (fuselage y-symmetric about 0) | v1 ~7.8 m off |
| `New_Blade_1` | FOUND, (0, 4.28, −2.55) | `helicopter.gd:18` |
| `New_TailBlade_2_002` | FOUND, (0, 1.321, 6.535) | `helicopter.gd:19` |
| `Huey_Copy` | **ABSENT — by design** | see below |
| meshes with no material | **none** | 47 were white before this pass |
| `REF_*` nodes | **none** | study overlays excluded from export |

**The recentre band-aid is now inert.** `helicopter.gd`'s `fuselage_node` export default
was `"Huey_Copy"`; it is now `""`, and the recentre block is guarded so an empty string
skips it. **The block is NOT deleted — `chinook.tscn:12` sets `fuselage_node = "Fuselage"`
and still needs it.** For the Huey it is dead.

**Destructible contract: nothing applies, deliberately.** The Huey is instanced from
`huey.tscn` by `air_traffic.gd:15`, never through `site_planner.place_structure`, so
neither `FSB_SOFT_PREFIXES` nor `FSB_STRUCTURE_KINDS` ever sees its mesh names. Giving any
part an `fb_*` prefix would buy nothing and would be a lie in the map.

## Probes run, all green

```
res://tools/probe_huey_frame.tscn   PASS: huey_v3 frame + seat socket contract OK
res://tests/test_seat_system.tscn   PASS: 11-socket contract, clips, stagger, restore
                                          (auto_generated=false — real sockets, first time)
res://tests/test_huey_sim.tscn      PASS: huey flight cycle OK
res://tests/test_air_fleet.tscn     PASS x4: materialises, parented, landed on the pad, departed
res://tests/test_asset_probe.tscn   huey_v3.glb largest=14.63m ok
```

`test_asset_probe` still reports 4 failures — the four `heli_*.glb` staged clips at 67.30 m.
**Pre-existing and out of scope**: those bake v1 geometry and re-staging is ruled to a later
pass (8/5 ruling 2). Untouched.

## STILL NEEDS CALEB — ranked

1. **41,364 tris, and 36,168 of them are guns.** `pintle_l_m60` + `pintle_r_m60` are
   **10,552 tris each** — that is the `m60_pintle.glb` donor the 8/5 decree explicitly
   REJECTED ("10× budget, wrong for an aircraft"); the decree ruled the door mount's
   1,012-tri M60. The 8/5 build used the heavy one and the handoff recorded it as the light
   one. Not silently swapped here: the heavy gun's `MuzzlePoint` is verified +Y-correct and
   re-transplanting risks reintroducing the backwards muzzle the shipped
   `m60_door_mount.glb` / `m60_ring_mount.glb` still carry. Plus `rack_m16_1..3` at 5,032
   tris each = 15,096 for three rifles in a wall rack.
   **His call: swap to the 1,012-tri gun (−19,080 tris) and decimate the rack rifles, or keep.**
2. **`_l` names are on the aircraft's RIGHT.** `pintle_l`, `seat_gunner_l`, `door_l`,
   `door_rail_l`, `door_sill_l` all sit at Godot **+X**, which is starboard when the nose is
   −Z. Internally consistent across the whole file, so nothing is broken today, and
   `seat_system.door_staging_pos()` just stages off that side. But "left door gunner" code
   written later will be wrong. **Rename, or write the inversion down as the convention?**
3. **Doors export CLOSED and nothing slides them.** `door_l`/`door_r` seal the cabin, which
   hides the interior he built. They are separate nodes; sliding aft = translate **Godot +Z**.
   Their sockets `door_l_socket`/`door_r_socket` are both at (0, 0.72, −2.003) — on the
   centreline, coincident, with nothing parented to them, so they are markers only.
   **Open by default, removed entirely (common in-theatre), or wire a slide?**
4. **`cabin_panel_aft_l/r`** — named from measurement, not from his intent. See OPEN #2.
5. **Interior materials.** 47 meshes (floor, both seat groups, skids, cyclics, collectives,
   pedals, console, bench, stools, rack, webbing) had NO material and would have shipped
   **default white**. All now carry `huey_hull` (0.16, 0.19, 0.13 — dark olive) so nothing
   ships white. A real pass wants olive floor / black cushions / canvas straps.
6. **`seat_pax_8` exists in the GLB but the code contract is `seat_pax_1..7`**
   (`seat_system.gd:19-25`). It is found by nothing and simply ignored. Add an 8th pax seat
   to the contract, or delete the empty?
7. **CollisionTable box is 0.5 m short at the tail.** `collision_table.gd:58` is
   `Vector3(3, 3, 12)`; v3 measures 2.845 × 3.003 × 12.90. Near-perfect otherwise (v1 at
   17.46 m badly overflowed it). Not changed — a collision edit needs a playtest.

## Explicitly NOT done

- **Pilot / gunner / pax animations** — 8/5 ruling 3, and they wait on his eye on the merge.
  Reference pack: `production/research/huey_pilot_motion/NOTES.md`.
- **Re-staging the four `heli_*.glb` clips / four `huey_*_staging.blend` files** — 8/5 ruling 2.
  Untouched. They still bake v1 geometry, which is the only reason `huey.glb` still exists.
- **Exterior detailing** — 8/5 ruling 1.
- **M60 combat wiring** — 8/5 ruling 4, geometry and hierarchy only.
