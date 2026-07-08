# STATE OF PROJECT — Vietnam Mission FPS

**Date:** 2026-07-07
**Goal:** Transform Hell of Duty (WW2 FPS) into a Vietnam War mission-based FPS: randomized insertion → 2–4 generated objectives → exfil. Hell Let Loose lethality, CoD mission pacing, RECON RPG rules backbone, TerrainEngine jungle maps, RealVietnamRTS asset library.

**Vision (refined 2026-07-07):** Deus Ex / Boiling Point / FNV *meets* CoD-2000-era / SOCOM / Vietcong / Men of Valor, with **Arma / Operation Flashpoint as a core inspiration** — a hardcore Vietnam War **tactical sandbox**. Explicitly NOT on-rails: missions are open AOs where objectives exist as places/things in the world and the player chooses route, order, and approach. RTCW/MoHAA lessons feed the *systems* (objective states, triggers, alert tiers), not corridor design; CoD/MoHAA contribute intensity/punch via the AI director, not scripts. OFP implications: squad ORDER interface from the first slice (follow/hold/move-to/engage/hold-fire), realistic engagement ranges (favor projectile ballistics for rifles — resurrect HoD's unused projectile pool), AO sizes that can flex up later, heli insertion is AI-piloted transport on a player-chosen route (eventually player-flyable, Arma-style — never a rail-shooter sequence). NOT a stealth game (stealth is one valid approach, never mandated; escalation instead of fail states). Structure: **persistent campaign province map** (strategic layer: evolving war state, firebase hub, squad management between ops — this is the minimal RPG) + **generated 1–1.5km mission AOs** (tactical layer). "Full-on war" is the top of the mission-intensity dial (firebase defense, major operations with artillery/air/waves), not a separate mode — same generator, different director settings. Priorities: (1) outstanding gunplay, (2) atmosphere (jungle, weather, night, audio), (3) minimal RPG = named persistent squadmates who improve/get wounded/die + light RECON skill/kit layer + province war state. No seamless roamable open world — hub-and-AO delivers the fantasy within perf budget.

**Sources surveyed:** `C:\Users\caleb\HellOfDuty` (this project), `C:\Users\caleb\TerrainEngine`, `C:\Users\caleb\RealVietnamRTS`.

---

## 1. Hell of Duty — what exists today

Godot 4.5 Forward+, strict-typed GDScript, ~5,400 lines / 28 scripts / 10 scenes. A playable vertical slice: move, shoot, get shot, bleed out, heal, grenade, kill 8 AI, "win" (signal fires, nothing listens). No git history yet (bd init just created the repo). Two autoloads: `GameManager`, `CombatManager`.

### Player (`scripts/player/player.gd`, 275 lines — ACTIVE)
- CharacterBody3D: walk 5.0 / sprint 8.0 / crouch 2.5 m/s, jump (bound to `ui_accept`), Q/E lean (±18° roll, move penalty), animated crouch. **No prone. No stamina.**
- Recoil model: view kick + recovery + random horizontal, capped 30°.
- Health (`health_system.gd`): 100 HP flat pool → damage triggers **bleed-out timer** (10–30s by remaining HP) → death unless healed. 3 medkits, 3s stationary channel, full heal. Signals drive HUD.
- ⚠ `fps_controller.gd` is a dead duplicate of player.gd — delete.

### Weapons (`weapon_holder.gd` 451 lines + `WeaponData` resources)
- Data-driven: `.tres` in `data/weapons/` + viewmodel scene + real low-poly GLTF. 5 defined: Thompson, M1911 (player), Kar98k, MP40 (enemy-only), M26 grenade.
- **Hitscan** raycast, spread cone, ADS lerp (FOV zoom deliberately disabled), timed reload consuming whole mags, dice-notation damage (e.g. Thompson 1d6+45).
- Fire modes SEMI/BOLT/BURST are all functionally semi — no burst logic, no bolt-cycle.
- No attachments, no loadout menu (Thompson+M1911 hardcoded).
- ⚠ Two competing weapon-switch systems (`weapon_holder` slots 1-2 vs `equipment_manager` slots 1-4) — likely bug source, consolidate.
- Standalone viewmodel editor tool (`scenes/weapons/viewmodel_editor.tscn`) for tuning hip/ADS transforms.

### Damage model (`combat/hitzone.gd`, `autoload/combat_manager.gd`)
- Hitzones: HEAD ×4.0, TORSO ×1.5, LIMB ×0.6 — procedurally attached (head sphere, torso capsule, 4 limb capsules) to player, enemies, allies.
- Lethality already in HLL territory: Thompson 2-shots torso, headshot one-shots, Kar98k always one-shots.
- CombatManager: bullet damage + Quake3 knockback, 8-point-visibility explosion damage, suppression-in-area, LOS raycasts, entity registries.
- ⚠ Hitbox/Hurtbox area-damage components and the full projectile/pool subsystem (`projectile_base/data/pool.gd`) are **complete but dead code** — nothing uses them.

### Enemy AI (`enemy_base.gd`, 901 lines — the most developed system)
- Goal-driven state machine, Quake3-bot style: think 6.7 Hz / execute per frame. Goals: ENGAGE, SEEK_COVER, SUPPRESS, FLANK, ADVANCE, RETREAT, INVESTIGATE, HOLD. Personality (aggressive/defensive/balanced) sets accuracy/reaction/aggression weights.
- Detection: LOS + last-seen-position + investigate + reaction-time delay before first shot. Suppression 0–1 blocks firing / forces hunker.
- Config via `EnemyData` resources (german_rifleman HP80, german_smg HP60).
- Ally AI (`ally_base.gd`, 474 lines) mirrors it: follow player, engage, seek cover.
- ⚠ **NavMesh is baked and every AI has a NavigationAgent3D, but no one ever queries it** — movement is direct steering; AI walks into walls. Biggest AI gap.
- ⚠ Cover points are generated by the map gen but AI never consumes them ("seek cover" = strafe).
- No squad coordination (REGROUP enum exists, unused).

### Character rendering
- **All NPCs are colored capsules.** No models, no Sprite3D/AnimatedSprite3D, no billboard code anywhere. The 8-directional CULTIC-style sprite pipeline must be built from scratch.

### Mission / level structure
- One level: `test_arena.tscn`. `WW2MapGenerator` (754 lines, @tool) is a genuinely elaborate 100×100 tile generator (12 passes: terrain, farmland, river, roads/bridges, town buildings, church, craters, trenches, wire, vegetation, wrecks) with seed control and JSON save/load. Tiles → simple 3D box/cylinder props at 2m/tile.
- **No objectives, no triggers, no scripted events, no briefing/debrief, no victory screen.** Win = kill-all-enemies signal into the void; lose = death screen.
- ⚠ 2D TileMap output path of the generator is orphaned (empty tilesets/, never assigned).

### UI / HUD
- Working: HP bar, ammo/mags, weapon name, grenade/medkit counts, slot indicator, healing bar, bleed-out flashing timer, crosshair, circular action-progress ring, death screen.
- Missing: compass, objective markers, hitmarkers (currently `print()`), main menu, pause menu UI, victory screen, briefing screen, minimap.

### Audio / VFX / other
- **Zero audio.** No players, no assets, no calls.
- VFX: bullet tracers work; muzzle flash, impacts, explosion visuals are TODO.
- Grenades complete (cook/throw/4s fuse/RigidBody, cook-in-hand kills you).
- No save system, no settings, no loadouts.

---

## 2. TerrainEngine — architecture & FPS gap analysis

Standalone Godot lab project (main scene `terrain_lab.tscn`); designed to be copied into consuming games. **Note doc-vs-code drift:** CLAUDE.md claims 2m cells / 129×129-vert chunks; the code actually runs **4m cells, 769×769 heightmap (~3km), 144 chunks of 256m, 65×65 verts per chunk.**

### What it does (end to end)
1. `TerrainEngine.generate(seed)` — domain-warped fBm + ridged multifractal mountains + cliff terracing + smoothing + optional hydraulic erosion. Presets: ROLLING_HILLS, STEEP_MOUNTAINS, RIVER_VALLEY, COASTAL_HILLS, PLATEAU, CUSTOM.
2. `HeightmapStorage` — O(1) bilinear height/normal world queries (non-physics movement API).
3. `RiverGenerator` — gradient-descent rivers, carved 1.8m into heightmap pre-meshing, near-water mask feeds rice-paddy placement.
4. `TerrainManager` — async chunk load (4/frame), Chebyshev-distance streaming, 8ms/frame budgeted rebuild queue (for damage/clearing edits).
5. `WaterSystem` — ponds/lakes/coastal/swamp meshes + wetness texture.
6. `VegetationManager` + `BillboardVegetation` — biome classification per 8m bundle (CLEAR → RICE_PADDY → GRASSLAND → LIGHT/MEDIUM/HEAVY_JUNGLE from height/slope/water/RNG); near-range procedural 3D palms + grass (MultiMesh, cached candidate placement, deterministic per chunk), mid-range 5-plane cross billboards (80–800m band). All data-driven density tables.
7. `DamageSystem` (craters via decals + heightmap deform) and `ClearingSystem` (progressive jungle clearing) autoloads.
8. `GameplayGrid` — 256×256 (12m cells) metadata grid: elevation, slope, terrain type, veg density, passability, movement cost, cover values, Bresenham LOS.

Seeding: heightmap fully seed-reproducible; rivers fixed-seed relative to heightmap; foliage deterministic per chunk coord (but NOT varied by terrain seed); default startup randomizes — needs a fixed-seed entry path for mission generation.

### RTS assumptions (what we must NOT depend on)
- Camera locked top-down/oblique (30–1500m zoom, 6m ground-follow floor). No eye-level mode.
- **No terrain mesh LOD at all** — every chunk full-res 65×65 always. The "LOD" is purely the vegetation ladder (3D <80–100m → billboards 80–800m → nothing).
- Terrain collision exists (trimesh per chunk) but is **layer 1 / mask 0 — raycast picking only, non-blocking.**
- **Foliage has zero collision.** Trees are visuals; RTS units path "through" jungle via grid movement cost.
- `bake_navigation()` is fully written per-chunk (agent radius 1, height 2, climb 0.5, slope 45°) but the call is **commented out** — grid pathfinding was chosen instead.
- Ground texture tiles at ~12m and **fades out above ~30–60% elevation** (hilltops rely on vertex color) — fine from 300m up, muddy at boot level.
- QualitySettings presets (POTATO→ULTRA, GPU auto-detect) define `near_tree_distance` / `billboard_distance` / `load_distance` — **computed but never consumed** by the vegetation/streaming systems.

### FPS conversion work (additive, per constraint — RTS keeps working)
| # | Gap | Work | Nature |
|---|-----|------|--------|
| 1 | Ground-level mesh detail | Near-camera terrain LOD tier (higher-res mesh or clipmap for nearest chunks); remove/replace elevation-based texture fade; detail-normal blending up close | New LOD system + shader profile — the largest single item |
| 2 | Walkable collision | Flip nearest-chunk trimesh to blocking layers; generate trunk capsules / obstacle bodies for 3D trees near the player only (bounded cost) | Additive, config-gated |
| 3 | Near-player jungle | Wire the existing-but-ignored QualitySettings distances into VegetationManager/BillboardVegetation; raise near-band density/candidate caps; undergrowth layer; billboards pushed further out | Mostly wiring + tables, some new assets |
| 4 | AI navigation | Un-comment and async-ify per-chunk `bake_navigation()` for chunks near AI; keep GameplayGrid for strategic layer (patrol routes, LOS) | Already written, needs enabling + perf pass |
| 5 | Camera/scale | Eye-height (1.7m) camera profile, FPS fog/draw distances, remove 6m follow floor | Small |
| 6 | Determinism | Fixed-seed generation path (mission seed); optionally key foliage RNG off terrain seed too | Small |

**Proposed mechanism:** a `TerrainProfile` config resource (RTS vs FPS) selecting cell size, LOD ladder, collision policy, veg distance tables, camera mode — additions only, RTS profile = current behavior. Note the useful two-tier precedent already in the codebase: GameplayGrid (strategic: patrols, alertness, LOS through jungle) vs navmesh (tactical: individual AI steering) maps perfectly onto mission-layer vs combat-layer AI.

⚠ **Fork alert:** RealVietnamRTS does NOT consume this project live — it embeds an evolved *copy* under its own `terrain/` folder (plus RTS-only fog-of-war and road-network additions). The two have already diverged. Decide the source of truth before adding an FPS profile (see Open Questions).

---

## 3. RealVietnamRTS — reusable asset & data inventory

Mature, content-rich RTS (Godot 4.6, Jolt). Data and 3D assets are highly portable; systems code is RTS-coupled.

### Highest-value carry-overs
1. **~90 PBR .glb structure models** (`assets/models/structures/`) — REUSE AS-IS
   - Firebase: hootch, sandbag/conex/ammo/commo bunkers, MG nest, mortar pit, observation tower, gate, modular trench, foxhole, concertina wire, TOC, quonset hut, supply depot…
   - Village: thatched hut, stilt house, communal house, rice storage, pagoda, bell tower, well.
   - **VC/NVA: hidden tunnel entrance, spider hole, punji traps, weapons cache, underground hospital** — ready-made FPS objective props.
   - Ruins (burned hut, bomb crater, rubble), colonial (plantation house, villa), infrastructure (bridges, dock, hangar, control tower).
   - Godot auto-generates LODs on import. Game-res with normal-map detail — huts/bunkers should hold at FP range; flat sandbag/wire textures may need close-up love.
   - ⚠ Some models carry ~100× (cm→m) import scale (e.g. gate_entrance collision box 264m) — normalize scale and re-author collision/interiors for first-person walkability.
2. **`battle_system/data/vietnam_weapon_data.gd`** (995 lines, 30+ weapons: M16, M14, M60, M79, M72 LAW, AK-47, SKS, RPD, RPG-7, DShK, mortars, …) — damage, ranges, RPM, reload, burst, mag size, projectile speed, accuracy falloff, suppression, AOE, tracer ratio, sound-profile IDs. **REUSE AS-IS as the data source** for FPS WeaponData — realism-tuned numbers, maps cleanly onto Hell of Duty's resource-driven weapon system.
3. **`battle_system/data/vietnam_unit_data.gd`** (421 lines) — US Army / ARVN / VC / NVA rosters with accuracy, sight range, move/stealth speed, morale, suppression resistance, weapon loadouts, special flags (recon, sapper, special ops). **Seed for FPS enemy archetypes** (feeds EnemyData resources).
4. **`firebase_system/building_data.gd`** (2,233 lines, 120 building types) — footprints, height, health, garrison capacity, sight range, cover value, flammable/explosive, destruction states (INTACT→…→CRATERED). Strip RTS cost fields → FPS destructible/enterable building metadata.
5. **`battle_system/ai/behavior_tree/`** — generic BT framework, engine-agnostic. Reusable as-is if we want BT anywhere.

### Also useful
- Vehicles/aircraft as props: UH-1 Huey, CH-47, M113, M35 truck, F-4, A-1 Skyraider + full ordnance set (Mk8x bombs, napalm, rocket pods). Scenery/objective props as-is; drivable = rework.
- Vegetation: tree/bamboo/bush billboard PNGs + jungle_light/medium/heavy .glb clusters — supplements TerrainEngine foliage.
- `ambush_manager.gd` (VC ambush sites, trigger radius, trap lines + `booby_trap.gd`), `ai_director.gd` (encounter pacing), VC/NVA controller doctrines — design seeds for the mission generator's encounter layer.
- `helicopter_system/` (insertion_manager, landing_zone, heli_mission) — RTS code, but the insertion/LZ/medevac loop is exactly our insert/exfil concept.
- Rigged infantry .glbs (US + VC) — too low-detail for FP inspection, but **usable as the 3D source models to render 8-directional sprite sheets from** (CULTIC pipeline input!).
- Campaign docs (GAME_BIBLE.md: Ia Drang, Khe Sanh, Tet-Hue, Hamburger Hill…) — mission flavor reference.

### Not reusable
- RTS command UI, construction/job systems, doctrine deck, fog of war, supply chain code, voice barks (RTS select/move acks). Audio overall is thin (28 files, mostly generic explosions) — **combat/ambience audio must be sourced fresh**; the weapon data's `sound_profile` IDs are a ready shopping list.

---

## 4. Keep / Port / Missing matrix

### KEEP (Hell of Duty, carries over with minor changes)
| System | Notes |
|---|---|
| Player controller (player.gd) | Add prone + stamina; delete fps_controller.gd |
| Hitzone damage model + dice damage | Already HLL-lethal; extend per RECON hit-location rules |
| WeaponData resource pipeline + viewmodel editor | Re-populate from vietnam_weapon_data.gd; fix fire modes (real bolt/burst) |
| Bleed-out / medkit loop | Very RECON-appropriate; tune |
| Goal-driven AI think/execute architecture | Wire NavigationAgent3D (finally query it); add alert-state tiers from Phase 2 research |
| Suppression system | Keep |
| Ally AI skeleton | Basis for optional squad |
| Grenades, equipment slots (consolidate the two switch systems) | Keep |
| HUD framework + bleed timer + action ring | Extend with compass/objectives |
| CombatManager services (LOS, explosion, registries) | Keep |

### PORT (from sibling projects)
| Asset/System | From | Effort |
|---|---|---|
| Terrain generation, streaming, biomes, rivers, water, veg systems | TerrainEngine | FPS profile: LOD tier, collision, near-veg, navmesh enable (§2 table) |
| ~90 structure .glb models | RealVietnamRTS | Scale normalization + FP collision/interiors |
| Vietnam weapon stats (30+) | RealVietnamRTS | Data mapping into WeaponData .tres |
| Faction/unit rosters → EnemyData | RealVietnamRTS | Data mapping |
| Building metadata (destruction states, garrison, cover) | RealVietnamRTS | Strip RTS fields |
| Ambush/director/patrol AI concepts | RealVietnamRTS | Design reference, re-implement |
| Rigged US/VC infantry models | RealVietnamRTS | Render source for sprite sheets |
| Vegetation billboards/3D clusters | RealVietnamRTS | Merge into TerrainEngine tables |

### MISSING (build new)
| System | Notes |
|---|---|
| **8-dir billboard sprite character pipeline** | Nothing exists anywhere. Blender render rig (8 angles × states) → sprite sheets → AnimatedSprite3D/shader with camera-angle frame select. AI already state-driven → maps cleanly to sprite states (idle/walk/aim/fire/hit/death) |
| **Mission generator** | RECON mission tables (Phase 3) + objective placement on generated terrain. No objective/trigger system exists at all |
| **Objective/trigger framework** | Trigger volumes, objective states, scripted sequences, fail states (Phase 2 research drives design) |
| **Insert/exfil flow** | LZ selection, insertion sequence, exfil call + extraction zone, mission end states |
| **Briefing/debrief + progression** | Menus, mission summary, RECON experience layer (Phase 3) |
| **AI alert-state model** | Current AI is binary see/attack. Need patrol → suspicious → alerted → combat tiers + noise events (Phase 2: RTCW/MoHAA) |
| **Stealth/detection** | Player visibility (stance, foliage, movement noise), AI perception checks (RECON alertness) |
| **Compass/objective HUD, main/pause/victory menus** | |
| **All audio** | Weapons, jungle ambience, radio chatter. sound_profile IDs = shopping list |
| **VFX** | Muzzle flash, impacts, explosions, foliage hit reactions |
| **Save/progression persistence** | Between-mission (RECON XP/skills) |

### DELETE / prune (Hell of Duty dead code)
`fps_controller.gd`; one of the two weapon-switch systems; projectile pool + Hitbox/Hurtbox (or park until needed — e.g. RPG-7/M79 want real projectiles, so maybe keep the pool); orphaned 2D TileMap pipeline; `WW2MapGenerator` becomes reference-only once TerrainEngine lands (its trench/building/crater placement passes are worth mining for the objective-site generator).

---

## 5. Risks & watch items
1. **Terrain fork divergence** — three terrain codebases risk (TerrainEngine, RTS's embedded copy, FPS copy). Needs a source-of-truth decision now.
2. **Performance ceiling** — dense near-player 3D jungle + collision + navmesh + AI on modest hardware (RTS already dropped external tree models for Intel UHD). FPS profile must be aggressively budgeted: collision/navmesh only near player, sprite enemies help a lot here.
3. **Structure model scale bug** (~100× on some .glb) — audit pass required before level population.
4. **AI never actually pathfinds today** — wiring NavigationAgent3D through jungle navmesh is foundational and must precede any stealth/patrol work.
5. **No audio at all** — stealth gameplay is audio-driven (footsteps, gunshot alerts); this is a design dependency, not polish.
6. **HoD has zero commits** — commit the current working state before any transformation begins.

---

## Decisions (Summoner, 2026-07-07 — end of Phase 1)
1. **Terrain source of truth: fork into HellOfDuty.** Copy TerrainEngine into HoD and evolve it there for FPS needs (same pattern the RTS used). Accepted tradeoff: three divergent copies; standalone TerrainEngine stays untouched for the RTS.
2. **AI fireteam from the start.** 2–4 AI teammates in every mission, RECON-style. Consequence: NavMesh pathfinding and squad AI are critical-path from the first slice; ally_base.gd is a live foundation, not optional.
3. **AO size: ~1–1.5km per mission** (generated or cut from the 3km system). Perf headroom for dense near-player jungle; tighter objective pacing.
**Phase 2 decisions (2026-07-07):**
- **Death/saves: fail-forward + MoH Pacific Assault-style medic system.** No quicksave; checkpoints at mission nodes; downed → squad drag + medic revive chain (limited charges, medic runs to you under fire); chain exhausted → mission lost, campaign continues with consequences. ABORT-to-emergency-exfil always available. **Iron Man permadeath hardmode** (campaign wipe on death) as an unlockable after finishing the game.
- **Detection UI: diegetic-first + minimal HUD.** Point man hand signals, squad barks, enemy voice lines, ambient cues primary; one subtle directional "being noticed" pip that RECON perception skill sharpens.
- **AI architecture: hybrid.** Enemies = extend HoD's goal-scoring FSM wrapped in the MoHAA situation-priority stack + personality maps. Squadmates = RealVietnamRTS behavior-tree framework (order handling + role logic benefit from BT composition).

4. **Insertion: live systems, not scripted events.** Player picks LZ/ingress route at briefing; the mission generator pre-places AA/MG sites as real world entities (partially revealed by intel quality). Flight is AI-piloted along the chosen route with the player in the door; AA fire is real weapon systems firing. Shoot-down = mission mutation: crash-site survival → escape-and-evasion → alternate exfil. RECON insertion-complication rules supply the AA-density/intel knobs. **First slice abstracts the flight** (briefing → fade in at LZ) but the mission generator treats insertion as a first-class phase from day one so the live flight bolts on without rework.
