# FULL GAME AUDIT — 2026-07-12
**Asked:** *"where are the gaps in the general loop — empty folders, callouts for things that don't
exist, things without models, dead or unfinished systems?"*
**Method:** five parallel sweeps — dangling `res://` references, dead/unfinished systems, the core
loop traced end-to-end in code, engine/perf config vs Godot 4.7, and a raw filesystem sweep.

## HEADLINE
The **combat** is the most finished thing in this project. The **loop around it** has three canon
stages that are *built, tested, and unreachable* — and one player-facing hole that makes the
campaign impossible to actually play through. The engine is running on defaults that leave real
performance on the table (including **not using Jolt**). Almost nothing is missing *art* — the
gaps are wiring, not content.

---

# 1. THE LOOP — where it actually breaks

Traced: `main.tscn → game_flow.gd` (menu → operation → hub → TOC → bird → mission → exfil →
debrief → hub). **The loop does close.** But:

### L1 🔴 You cannot leave a campaign, or spend XP, without Alt-F4
`game_manager.gd:24-26` — Esc pauses the tree and shows **no UI**. There is **no pause menu and no
quit-to-menu anywhere in the project.** And **Barracks (where XP is spent) is reachable only from
the main menu** (`game_flow.gd:54`). So: enter a campaign → earn XP → *there is no way to spend it
without killing the process.* Every system for it exists (`skill_catalog.gd:55-70`,
`barracks.gd:78-87`). This is the single biggest blocker to a playable campaign, and it is pure UI
wiring.

### L2 🔴 The Huey insertion ride is DEAD on the only reachable path (ADR-008 condition 2)
`InsertionRide` is fully built — boarding, flight, AA rolls, shoot-down, crash E&E, dismount
(`insertion_ride.gd:92-233`). But `game_flow.gd:166-167` erases `start_pad` when `from_hub` is
true, the ride only spawns `if plan.has("start_pad")` (`:195-199`), and **every reachable launch
sets `from_hub = true`** (`:309`). A test (`test_hub_loop.gd:89-95`) *asserts it must not spawn*.
The AA-threat economy's only consumer never runs.

### L3 🔴 The 7-element TOC briefing is unreachable (ADR-008 condition 1)
`main_menu.gd:6` declares `signal start_pressed`; `game_flow.gd:51` connects it — **nothing ever
emits it.** So `MissionSelectScreen → BriefingScreen` (the real RECON briefing) is dead code. The
hub uses a 3-card summary (`hub_briefing.gd:32-48`) instead.

### L4 🔴 ADR-006 scoring was never implemented — **loud is still the optimal XP strategy**
`debrief.gd:21-31` scores `objectives×100 + kills×10 − damage + time`. The canon
(`GAME_GUIDE.md:117`) is **+25/contact avoided, −25/detected, replacing kills×10**. Grep for
`contacts_avoided|contacts_detected`: **zero hits project-wide.** `MissionState.build_result()`
has no contact fields. This directly contradicts **Pillar 3** — the game currently *pays you to
be loud*.
**Bonus bug:** `debrief.gd:68-69` prints "THE PILOT DIDN'T MAKE IT: −100" but `compute_score()`
never subtracts it. The AAR lies.

### L5 🟠 The campaign is flat
`MissionOffers.roll()` produces `terrain_hint` and `strength` (LIGHT/MODERATE/HEAVY) and the hub
card prints them — but `MissionGenerator.plan()` takes only `(world, seed, type)`
(`mission_generator.gd:89`) and **reads neither**. `missions_played` scales nothing. The card is
decorative.

### L6 🟠 Two mission types ship 1 objective, not the canon 2–4
`_plan_rescue` → 1 (`mission_generator.gd:129`), `_plan_firebase` → 1 (`:246`).
(PATROL 4–5, VILLAGE_RAID 2, ANTI_AA 2–3 are in band.)

### ✅ What IS wired end-to-end (don't rebuild these)
Menu, operation select, hub + walk-up prompts, mission generation, **all six objective sensors with
real completion logic**, exfil (LZ compromise, wave-off, fallback LZ), KIA/downed → debrief → hub,
XP award + persistence, squad roster with learn-by-doing, save/load with REGULAR/HARD/IRONMAN tiers
and a wheels-down checkpoint.

---

# 2. DEAD & UNFINISHED SYSTEMS

| # | Finding | Evidence |
|---|---|---|
| D1 🔴 | **Save migration is a live no-op.** `_migrate()` is *called for real* on old saves and its whole body is a `push_warning`. Old saves "migrate" by doing nothing. | `campaign_state.gd:202`, called at `:183` |
| D2 🟠 | **`data/vietnam/` — 2,136 lines of dead RTS port** (`VietnamWeaponData` 994, `VietnamUnitData` 420) with **zero references**, plus `GameEnums` — a **dead autoload parsed at every boot** whose only consumers are those two orphans. | `project.godot:26` |
| D3 🟠 | **`terrain_lab` subgraph (~2,456 lines) unreachable from the game.** Includes `engineering_system.gd` (606 lines: clear jungle, dig trench, build road, berms, foxholes) — instantiated **only** by the lab. `quality_settings.gd` never applies to the real game. | `terrain/scenes/terrain_lab.gd:111` |
| D4 🟠 | **47 emit-only signals.** Notably `CombatManager.damage_dealt` / `entity_killed` — the combat singleton broadcasts every hit and kill and **nothing subscribes** (no kill feed, no stats, no VO hook). Also `health_system.downed_started`, `game_manager.level_complete`. | `combat_manager.gd:5,6` |
| D5 🟠 | **Scripted events are test-only.** `ScriptedSequence` / `MissionTrigger` have no production consumer; no generated mission uses them. Their VO path is an explicit stub. | `scripted_sequence.gd:35,41-43` |
| D6 🟢 | `model_actor.set_base_modulate()` is `pass` — enemy state tinting silently does nothing on the renderer of record. | `model_actor.gd:607` |

**Notably clean:** exactly **one** `TODO` in 210 scripts; **zero** orphan scenes; no dead autoloads
besides `GameEnums`.

---

# 3. MISSING CONTENT & DANGLING REFERENCES

### Audio (the biggest content gap)
- 🔴 **`enemy_pain.wav` does not exist in any of the 3 VC voice banks** — but
  `enemy_base.gd:465,2114` calls `VOManager.play_enemy("pain")`. Every enemy pain grunt is silent.
- 🟠 **No weapon audio for `m14`, `m70`, `shotgun`** (they fall back to generic class banks). All
  three are in live rosters.
- 🟠 **~35 orphan .wav sets on disk** for RETIRED weapons (`car15`, `kar98k`, `mp40`, `sks`,
  `thompson`).
- 🟠 **MEDIC voice bank (`norman/`) is 17 of 25 lines** — missing `squad_frag_out`,
  `squad_contact_front`, `squad_weapons_free`, etc. (silent no-ops).

### Dangling paths
- 🟠 `terrain/vegetation/models/` **does not exist**, but `vegetation_manager.gd:204,216` references
  `palm_tree.blend` and `grass_patch.fbx` (a `.blend` could never load at runtime anyway).
- 🟢 `data/enemies/german_rifleman.tres` — WW2 holdover referenced by `test_sprite_enemy.gd:7`.
- 🟢 **Every sprite-manifest path is dangling** for all current units (`assets/NPCs/<faction>/…`) —
  harmless *only* because `ModelActor` always wins the fallback chain. It is dead code that would
  fail if a `.glb` were ever removed.

### Authored-but-unwired art
- `scenes/weapons/m26_grenade_viewmodel.tscn` and `medkit_viewmodel.tscn` **exist but no `.tres`
  points at them.** `flashlight_fp.glb` likewise.
- `m79`, `m72_law`, `rpg7` have **no FP arms** (correct — NPC-only per Amendment C).

### Empty folders
`addons/` · `art_source/characters/enemies/` · `art_source/characters/textures/` ·
`assets/NPCs/models/` · `data/hitzones/` (correct — tuning was retired after the rendered-truth fix)
· `tools/tts/piper/pkgconfig/`

---

# 4. ENGINE & PERFORMANCE (Godot 4.7)

**Context that governs everything:** `game_world.gd:47` targets **Intel UHD-class hardware** — no
dynamic shadows. That correctly rules out SDFGI/VoxelGI/TAA/MSAA, and makes the items below *more*
valuable.

### Misconfigurations (one-line fixes in `project.godot`)
| # | Setting | Now | Should be | Why |
|---|---|---|---|---|
| E1 🔴 | `physics/3d/physics_engine` | *unset* → **Godot Physics** | **`"Jolt Physics"`** | Built in since 4.4. Ragdolls + gibs + fireteam AI is Jolt's exact win case — typically **2–5× faster** on character-heavy scenes. *Needs a re-tune pass on step height / unstick.* |
| E2 🟠 | `scaling_3d/mode` | *unset* → **bilinear** | FSR2 (or FSR1) | You already pay the 0.77 render-scale cost and take the **worst** image for it. FSR2 also gives free temporal AA (you have none). **Benchmark on the iGPU** — if FSR2 loses, FSR1 is nearly free. |
| E3 🟠 | `mesh_lod/lod_change/threshold_pixels` | **1.0** | 2.0–4.0 | All 266 GLBs import with `generate_lods=true`… and then **LODs never engage**. Free win, zero code. |
| E4 🟢 | `run/max_fps` | uncapped | 120 | Pins iGPU thermals for nothing; makes perf probes noisy. |
| E5 🟢 | `use_debanding` | off | on | Near-free; fog + procedural sky will band at 0.77 scale. |
| E6 🟡 | occlusion culling | off | *later* | Only pays **after** you bake `OccluderInstance3D` on structures/ridgelines. Jungle canopy is a terrible occluder — don't just flip the flag. |

### Perf landmines in code
- 🔴 **`physics_interpolation=true` with almost no `reset_physics_interpolation()` calls.** Every
  teleport streaks the object across the map for a frame: `player.gd:210,240,498,545,580`,
  `enemy_base.gd:2264`, `insertion_ride.gd:38,156`. *This is a correctness bug the setting
  introduced.*
- 🔴 **O(n²) enemy scan at 60 Hz** — `squad_system.gd:230-250` `_grenadier_tick()` has no timer gate
  (the fix pattern sits one function above it at `:184-189`).
- 🟠 **Corpses sync hitzones forever.** `enemy_base.gd:451-454` runs `HitzoneBuilder.sync()` *before*
  the DEAD early-return, and corpses persist as lootable. Unbounded, monotonically growing cost.
- 🟠 **Muzzle-flash/tracer churn.** `gun_fx.gd:218,234-266` allocates ~8 nodes **and 2 fresh
  materials** per shot; `bullet_tracer.gd:100` allocates a node + material + mesh per shot. Caps
  bound the concurrent count, not the churn. *5-minute fix: hoist the flash material to a `static
  var`.*
- 🟠 **`load()` in the AI firing path** (`enemy_base.gd:1710,1734` — my own hold-over code) and in
  `projectile_base.gd:122`. Cache on the WeaponData.
- 🟠 **Hand-rolled CPU frustum cull** duplicating the engine's, chunk-granular (causes popping):
  `vegetation_manager.gd:115-195`. Replace with `visibility_range` + `FADE_SELF` (which
  `jungle_patch_layer.gd:269` already does correctly).
- 🟢 **No RVO avoidance** on `NavigationAgent3D` — already beaded (`kw1w`).
- 🟢 **`GameSettings` has zero graphics options** — no render scale, vegetation density, or shadow
  toggle. Blocks shipping shadows on dGPU while keeping the iGPU floor.

**Already good (don't touch):** MultiMesh vegetation, AI think-LOD by distance, FX caps, GPU-particle
and audio pooling, threaded heightmap, async per-site nav baking, auto-LOD on import.

---

# 5. RECOMMENDED ORDER
1. **L1 — pause menu + quit-to-menu + Barracks from the hub.** Without it the campaign is
   unplayable as an *experience*, even though every system works.
2. **L4 — ADR-006 contact scoring** (+ the `pow_lost` bug). The game currently rewards the opposite
   of its own Pillar 3.
3. **L2/L3 — unblock the Huey ride and the 7-element briefing.** Both are *built*; both are one
   wiring change. Two ADR-008 conditions clear at once.
4. **E1 Jolt + E2/E3/E4/E5** — behind a perf-probe bead; measure each.
5. **C1/C2/C3 perf landmines** (interpolation resets, the O(n²) gate, corpse sync).
6. **D1 save migration** — write it before you ship a save format change, not after.
7. **Audio content pass** — `enemy_pain.wav` first (every enemy is silent when hit).
8. **D2/D3 purge** — delete `data/vietnam/` + the `GameEnums` autoload; decide whether
   `engineering_system` (dig trenches, build roads) is a *feature you want* or 606 lines to cut.
