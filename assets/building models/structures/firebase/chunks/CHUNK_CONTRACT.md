# Firebase Chunk Contract

Modular prefab sections for procedural firebases. Each `.glb` here contains **markers only — zero geometry**.
Source of truth: `production/props_workshop/firebase_chunks.blend` (re-export: run its `export_chunks.py` text block).

## Node types (imported into Godot as Node3D, names preserved)

| Node name | Meaning |
|---|---|
| `INST_<prop>_<nn>` | Spawn the prop scene (table below) at this node's **global transform**. |
| `SOCKET_A` / `SOCKET_B` | Perimeter chain ends. Forward = node's **-Z** (Godot). A is the "entry", B the "exit". |
| `FACE_OUT` | Arrow toward the enemy side of the section. Spawn hook for claymores / firing positions / extra wire. |
| `FOOTPRINT` | Interior pad center; **scale = half-extents in meters** for overlap tests. Pads have no sockets. |
| `GUN_POINT` | Center of a gun pit — future howitzer model spawns here (no howitzer asset exists yet). |
| `APPROACH` | Helipad approach corridor direction (LZ doctrine: lanes 2 rotor-dia wide, clear 150 ft). Point it over the perimeter. |

## Chain rule

Place next chunk so `next.SOCKET_A` lands on `prev.SOCKET_B` with opposed forwards:
yaw next chunk by `(prev_B_yaw − next_A_yaw + 180°)`, then translate so socket positions coincide.
**Everything is marker-relative — never assume a chunk's file origin.** Corners turn CCW
(interior on the left of travel direction). A **road gap** is a legal chain element: advance
the cursor straight along its forward by the gap length without spawning a chunk — that IS
the historical FSB gate (a dirt road through berm and wire).

Ring recipes (see `recipe_fsb_*.json`, positions relative to ring start, yaw-only):
- **Octagon** (historical circle, compressed): 8 × 45° corners; each side = 1–2 walls.
  2 walls/side = 72.7 m across flats (battery FSB); 1 wall/side = 46.7 m (company NDP).
  `fb_gate_01` replaces exactly 2 consecutive walls on one side; or leave one wall slot
  empty as a road gap. Chain closure verified: <1 mm / <0.001°.
- **Rectangle**: 4 × 90° corners + n walls per side (legacy shape, still valid).

Spans: wall = **10.75 m**, 90° corner legs = **4.3 m**, 45° corner A→B = **7.945 m**, gate = **21.5 m**.

Recipe JSON: `{"placements":[{"chunk","x","y","yaw_deg"} | {"gap": m} | {"wire_ring": {cx,cy,
radius, prop, spacing_m, road_gap_toward_deg, gap_half_angle_deg}}]}` — wire rings are spawned
by the generator, not baked into chunks: place `prop` every `spacing_m` along the arc, yaw
tangent, skipping the road-gap arc. Historical basis: `assets/reference/references/reference_firebase_layout.md`.

## Chunks

| File | Contents |
|---|---|
| `fb_wall_01..03` | 5×sandbag run + concertina; 02 +foxhole/wire coils; 03 damaged (gap, tipped bags) |
| `fb_corner_01..03` | L-corner; 02 +observation tower; 03 +MG nest facing out-diagonal |
| `fb_gate_01` | gate_entrance prop (has `GateOpen_Left/Right` anims + own `-col` collision + fire/LOS/trigger points) + claymore line out front |
| `fb_pad_helipad_01..02` | PSP helipad; 02 +conex bunker |
| `fb_pad_supply_01..02` | supply depot; 02 +ammo bunker |
| `fb_pad_hooch_01..03` | hootch clusters; 02 +tent; 03 +aid station |

## INST prop map (`res://assets/building models/structures/`)

| INST stem | Prop file |
|---|---|
| sandbag_heavy, sandbag_light, triple_concertina, barbed_wire_coil, foxhole_sandbags, observation_tower, mg_nest, gate_entrance, conex_bunker, supply_depot, ammo_bunker, hootch, aid_station | `firebase/<stem>.glb` |
| psp_helipad | `airfield/psp_helipad.glb` |
| tent | `converted/tent.glb` |
| claymore_line | `converted/claymore_line.glb` |

Unused-but-imported palette (available for future variants): quonset_hut, mess_hall.

Note: `converted/tent.glb` carries a +3.8 m internal offset; its markers are pre-compensated
(z −3.8) so spawning the prop scene at the marker transform grounds it correctly. Do not "fix"
one side without the other.
