# Huey v3 — session close-out, 2026-08-05

Written at end of session after the Blender crash. **Nothing was lost.** Both files saved
clean at 20:18 and were verified headlessly afterwards. Pick up here tomorrow.

## Gate status: ruling #1 IS MET on disk

The decree's build order was space → contents → **his gate** → people/animations → exterior.
Interior and markers exist and measure correctly. **The next event is Caleb's eyes, not more
building.**

## What is in each file (verified headlessly, do not re-derive)

### `assets/us/vehicles/huey_v3.blend` — 108 objects, ~43.3k tris total

Airframe reshaped to the `Bell Huey.fbx` study: length 12.77, half-width 1.310, lowest
z = 0.000, nose +Y. Airframe alone measured 3,360 tris.

- **Rotors** — `New_Blade_1` (empty, 0, 2.550, 4.280) and `New_TailBlade_2_002`
  (empty, 0, -6.535, 1.321). Named to `scripts/vehicles/helicopter.gd`'s literal
  `find_child()` defaults, so `huey.tscn` needs no export-string change. Never bake a spin
  AnimationPlayer — code rotates these every frame.
- **Cockpit** — pilot + copilot seat pan/back/frame/armor l+r, cyclic, collective +
  post + throttle, pedals 0/1, center console.
- **Cabin** — `floor_cabin`, `floor_cockpit`, `transmission_bulkhead`, `transmission_hump`,
  `Center Bench`, `rack_bar`/`rack_tray`/`rack_m16_1..3`/`rack_m79`, `webbing_strap_1..3`,
  `cargo_ammo_stack`, `cargo_medcrate_1/2`, gunner stools + pads l/r.
- **Skids** — rails l/r, crosstubes fwd/aft, struts l/r fwd/aft.
- **Markers** — `seat_pilot_l/r`, `seat_pax_1..8`, `seat_gunner_l/r`, `door_sill_l/r`,
  `grip_cyclic_l/r`, `grip_collective_l/r`.
- **M60 door guns** — `pintle_l`/`pintle_r` at (±1.300, 3.165, 0.710), each with
  `_traverse` → `_GunPivot` → `_m60` + `_mount`, plus `_GunnerPos` and `_MuzzlePoint`.
  **MuzzlePoint local y = +0.678** — the backwards `-Y` defect carried by the shipped
  `m60_door_mount.glb` / `m60_ring_mount.glb` is CORRECTED here. Full traverse/elevate
  hierarchy per ruling #4; no combat code wired, as ruled.
- **Study overlays** — `REF_Bell_Huey`, `REF_Top_Rotor`, `REF_Back_Rotor`, `REF_Inside1`.
  WIRE, hide_render. **`REF_Inside1` has drifted to x = -12.000** (parked beside, not
  overlaid) — the known silent-drift failure noted in `blender_notes.md`. Harmless
  (reference only, never ships) but re-align it before using it to measure anything.
- Only two actions in the file, both from the study import:
  `Back_Rotor|Take 001|BaseLayer`, `Top_Rotor|Take 001|BaseLayer`. No armatures.

### `assets/us/vehicles/huey_v3_transport.blend` — 88 objects

Same airframe, cockpit, cabin, racks, skids, pax markers. **Differs in both directions.**

## OPEN #1 — the two files have DIVERGED. Neither is a superset.

| Only in `huey_v3.blend` | Only in `huey_v3_transport.blend` |
|---|---|
| `pintle_l/r` + full M60 hierarchy | `door_l`, `door_r` (slide aft) |
| `pintle_*_GunnerPos` / `_GunPivot` / `_MuzzlePoint` | `door_rail_l`, `door_rail_r` |
| `gunner_stool_l/r_pad`, `_post` | `door_l_socket`, `door_r_socket` |
| `gunner_pad_l/r`, `seat_gunner_l/r` | |
| `REF_*` study overlays | |

**This must be resolved before ANY animation derives from either file**, or it reproduces
the unit-version drift that has cost this project before. Caleb's ruling needed: is `v3`
the trunk (merge doors in), or is `transport` the trunk (merge guns in)? My read: `v3` is
the trunk — it holds the harder-won work (corrected M60 facing, gunner stations, the study
overlays used to derive the airframe), and doors are four objects to bring across.

## OPEN #2 — `Cube` and `Cube.001`

Two unnamed, material-less 8-vert boxes, 0.075 × 1.015 × 1.153, standing vertically at
x ≈ ±0.72–0.79, y 1.97–2.98, z 0.70–1.85. Present in **both** files. Deliberately placed —
they read as aft cabin side panels — but they carry generic names and no material, so they
will be invisible to any by-prefix strip or export filter. **Untouched.** Needs a name and
a material, or deletion, once Caleb says what they are.

## What was explicitly NOT done, by decree

- **Exterior detailing** — parked at the gate, ruling #1.
- **Re-staging the four `heli_*.glb` clips / four `huey_*_staging.blend` files** — ruling #2,
  v3 first, re-stage after. Those blends bake v1 geometry (`Huey_Copy`, `New_Rotor_Hub`,
  `New_Skid_L`), ~180 MB, 126–137 actions each. Do not touch them yet.
- **Pilot and gunner animations** — ruling #3, blocked on the gate and on OPEN #1.
  Reference pack already gathered at
  `production/research/huey_pilot_motion/NOTES.md` (64 KB).
- **Pax animations** — ruling #3, skipped on purpose. Pax stay on the existing clips.
- **Origin fix on the shipped `huey.glb`** — still ~7.8 m off the airframe, still
  band-aided at runtime by `scripts/vehicles/helicopter.gd:71-80`. When v3 replaces it,
  that band-aid gets deleted.

## Resume procedure (read this first tomorrow)

1. **Caleb opens the file himself.** Never `bpy.ops.wm.open_mainfile` over the MCP bridge —
   that is what crashed Blender on 8/5. It appears to succeed, then kills the session a few
   calls later. Same class as the `region_3d` write hang.
2. Confirm `bpy.data.filepath`, `is_dirty`, and `bpy.context.mode == 'OBJECT'` before
   writing anything.
3. Walk the interior for the gate. Then take his ruling on OPEN #1 and OPEN #2.
4. Only after the gate: merge the files, then pilot + gunner animations, then exterior.
