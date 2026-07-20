# RECON — Whole-Game Audit, 2026-07-19

**Report only. Nothing was changed, deleted or fixed. Every item below is a proposal awaiting the Summoner's ruling.**

Scope: code, canon docs, and one headless runtime boot. Godot 4.7 headless only; no windowed run, therefore **no FPS number was measured** (see Runtime, §5).
Every claim carries `file:line`. Items already fixed earlier today are not re-reported; four previously-open items are marked CONFIRMED and ranked rather than presented as discoveries.

Counts: **41 findings** — 7 inert, 9 competing, 7 silent-lie, 12 doc-drift, 3 loose-file, 4 runtime-only (one runtime item is a brand-new defect).

---

## 1. THE SHORT LIST — top ten by cost

Ranked by what they actually cost the player or the next agent. One sentence each.

**1. Your squad literally cannot keep up with you walking, which is why they look fidgety and never composed.**
Allies move at 4.5 m/s (`scripts/allies/ally_base.gd:9`); the player WALKS at 5.0 and sprints at 8.0 (`scripts/player/player.gd:5-6`). Nothing ever reels them in — `move_speed` is only ever scaled *down* (`ally_base.gd:682-683`), and `max_follow_distance` is declared and never read, so the men live permanently in the chase branch (`ally_base.gd:606-607`) and never in the settle branch. One-number fix plus a catch-up band.

**2. The squad flips between two totally different formations at exactly crouch speed, with no hysteresis.**
Above 2.0 m/s the men target a staggered file up to 3.5×N metres behind you (`ally_base.gd:596,602-604`); below it they target a 2.5–4.5 m ring around you (`:591`). Crouch is 2.5 m/s (`player.gd:7`), so on a stealth patrol any slope or brush drag flips eight men through targets ~28 m apart, instantly, then flips them back.

**3. Weather, night and jungle blind the enemy and have zero effect on your own squad.**
Enemy sight folds weather × vegetation × flare (`scripts/enemies/enemy_base.gd:686-694`); allies use a flat hardcoded 60 m (`scripts/allies/ally_base.gd:459`). In night monsoon a VC in thick jungle acquires at ~8 m while your man acquires at 60 — atmosphere becomes a straight player buff, which inverts the point of Pillar 2.

**4. Enemy patrol routes are seeded with your own spawn point, so a patrol can walk onto you before you stand up.**
`insertion_lz` and `exfil_lz` are both written as `gm.spawn_pos` — the gate seat (`scripts/missions/mission_generator.gd:442-443`) — then appended into the patrol anchor pool twice (`:161-163`), and circuit building samples 5–8 waypoints from that pool with no keep-out filter (`:574-575` → `enemy_base.gd:1828-1836`). The existing `_fsb_keepout` (`:93`) gates where groups *spawn*, not where they *route*.

**5. NEW: a crater is stamped off the map edge, throws an engine error, and silently never digs.**
Runtime trace: `damage_system.gd:137` → `terrain_manager.gd:282` → `game_world.gd:409`, `Rect2 size is negative`. Root cause is `terrain/core/heightmap_storage.gd:131-134,144` returning `max_z - min_z` unguarded after clamping; the off-map centre comes from `mission_generator.gd:129`, where the degenerate fallback returns `origin` raw while every real candidate is clamped at `:121-122`. The same fallback feeds ambient-patrol spawns (`:566`) and patrol anchors (`:170`).

**6. The rivers are dry because the channel tracer never writes a water surface.**
`terrain/water/hydrology_map.gd:506` writes `_type_h[i]` and never `_surface_h[i]`; the only surface writes are lake (`:354`), swamp (`:362`) and sea level (`:413`) after `fill(0.0)` at `:341`, and export copies `_surface_h` (`:537,547`). Both runs logged "Extracted 6 river paths" with water at 3.4 % / 5.1 % of the map. Smallest fix, largest visible effect, and a Rule-#1 "feel like Vietnam" item.

**7. Any grenade crater near a village permanently deletes the jungle cover the AI can see, while the player still sees bushes.**
`gameplay_grid.gd:479-497` boosts `vegetation_density` to 0.55 around villages, but the boost is written into cells and never stored; every terrain edit re-seats those cells to bare biome (`:121,142` via `:429-440`, `:453`), fired at runtime by `game_world.gd:405-429`. `rebuild_rect` already re-grows the riparian belt for exactly this reason (`:442-450`) and simply never re-applies the veg boosts. After one explosion the AI's spotting range silently widens (`enemy_base.gd:687-694`) while the player is standing in visibly dense brush that no longer conceals him.

**8. The FPS attribution probe has never once run — it names a class that does not exist.**
`tests/perf_probe.gd:88` types a variable as `BillboardVegetation`; `class_name BillboardVegetation` has zero hits repo-wide, and `--check-only` reports `Could not find type "BillboardVegetation"`. This is the instrument that splits frame cost across billboards / patches / grass (`:5-8,34`) — the exact attribution needed with FPS sitting at 24–38 against a 30 gate. The top systemic risk on the board has no working measuring tool.

**9. The head agent's own charter still enforces retired damage dice as binding law.**
`.claude/agents/recon-overseer.md:58` lists "one damage grammar — RECON dice, no flat modifiers (ADR-003)" under "laws you enforce on every call". ADR-003 itself says otherwise (`production/adr/ADR-003-one-damage-grammar.md:2`: PARTIALLY SUPERSEDED, damage is flat base × zone), and the code agrees (`data/weapons/m16a1.tres:14 base_damage = 27`, guarded by `tests/test_flat_damage.tscn`). The file was edited today at 22:16 and this line survived — it is the same drift generator CLAUDE.md:185-187 already names, sitting in the file with more reach than CLAUDE.md.

**10. A leftover `_TMP` test cannot parse, so every full suite run burns seven minutes and ends red.**
`tests/test_xp_spend_TMP.gd:40` calls `SkillCatalog.buy_attribute()`, which exists nowhere; the script never loads, so `_ready()` never fires and `get_tree().quit()` is never reached. `run_all_tests.ps1:22` globs `test_*.tscn` and boxes each at 420 s with an empty KnownRed list (`:32-36`). I ran it headless: no output, still alive at 180 s.

---

## 2. BY DEFECT CLASS

### INERT — ships, parses, never runs (7)

| Finding | Pointer |
|---|---|
| **VC sappers are ordinary riflemen.** `vc_sapper.tres` spawns live (`mission_generator.gd:36`, `lazy_group.gd:25`, `ai_stress_arena.gd:86`, `gore_lab.gd:13-14`) but the 36-line behaviour node is never attached to anything — no DETONATE_RANGE check, no MEDIUM_EXPLOSION, and the "SAPPER IN THE WIRE!" toast has never fired. | `scripts/enemies/sapper_charge.gd:3,6,28,32,34` |
| **The 368-line scripted-sequence system runs only inside its own test.** Only construction sites repo-wide are `tests/test_scripted_events.gd:186,231,286`; its `sequence_bark` signal has zero `connect()` calls anywhere. Test-only liveness looks identical to real liveness from outside — this is the sharpest example of the blindspot. | `scripts/missions/scripted_sequence.gd:30,272` |
| **The FPS attribution probe cannot parse** (short list #8). | `tests/perf_probe.gd:88` |
| **The `_TMP` test hangs the suite** (short list #10). | `tests/test_xp_spend_TMP.gd:40` |
| **Formation spacing is unreachable by construction.** Each man rolls a personal ring slot 2.5–4.5 m out (`:199`), but the arrival tolerance that decides whether he moves at all is 5.0 m (`:96`, `:605-609`) — larger than the whole ring. At a halt every man is already "arrived" anywhere inside a 5 m bubble. The rolled offsets never influence one final position; the comment at `:586-588` promises arcs and spacing, the render is a blob. | `scripts/allies/ally_base.gd:96,199,605-609` |
| **A complete graphics-quality settings file nothing references.** `class_name QualitySettings`, zero references, not autoloaded; defines vegetation_density / load_distance / shadow_distance / fog_density with different semantics and values from the live `world_config.gd`, plus GPU auto-detect (`:135` Intel → POTATO). With FPS below gate, the first person to build a settings menu reaches for the file literally named QualitySettings. | `terrain/core/quality_settings.gd:2,135` |
| **NVA-regular fallback — closed out, not ranked here.** It calls `push_warning` before swapping, so it announces itself and is not a silent lie at code level. Adjacent dead weight: the substituted unit is never passed to `SpriteStateMap.clip_for`, and the `unit` argument is unused anyway (`scripts/visuals/sprite_state_map.gd:199-206`). | `enemy_base.gd:329-333` |

### COMPETING — two authorities for one answer (9)

| Finding | Pointer |
|---|---|
| **Two weather systems stamp the same fog and disagree on day two.** WeatherDirector (`mission_generator.gd:221-225`, `weather_director.gd:22-26,36-38,50-67`) and MissionWeather (`game_flow.gd:311-313`, `mission_weather.gd:53,60-65,88-94`) both write `env.fog_density`/`fog_light_color`. MissionWeather runs last at mission start, so tuning WeatherDirector does nothing visible. On day rollover WeatherDirector re-rolls from its own private 4-entry table and re-fogs the world while `sight_mult` (`enemy_base.gd:688`), `rain_active` (`weapon_holder.gd:345`) and NoiseBus stay frozen at day-one weather. The fog says FOG, the sim says CLEAR. Today's SimClock wiring sharpened this rather than fixing it. |
| **Squad speed deficit** (short list #1). | `ally_base.gd:9` vs `player.gd:5-6` |
| **Formation flip at crouch speed** (short list #2). | `ally_base.gd:596` vs `player.gd:7,63` |
| **A second line-of-sight model with a regression test guarding it.** `terrain/core/gameplay_grid.gd:376-402 has_line_of_sight()` is a Bresenham march over elevation and terrain type; every gameplay caller instead uses the physics raycast at `scripts/autoload/combat_manager.gd:268-281` (`enemy_base.gd:749,767,857,1037`, `ally_base.gd:490`, `civilian.gd:163`, `mission_trigger.gd:187`, `ai_stress_arena.gd:1461`). The grid version's only callers are `tests/test_los_determinism.gd:26,31,41,44,58`. The test is a lying instrument: it proves a dead path stable. |
| **A 994-line weapon table says the M79 does 80 damage; the live file says 150.** `data/vietnam/vietnam_weapon_data.gd:266` vs `data/weapons/m79.tres:14`. ADR-016 canon is 150. The dead table is bigger, carries a `class_name`, and looks more authoritative. Cannot be retired alone — `game_enums.gd` in the same folder IS autoloaded, so it is a three-file atomic change. |
| **The "is this hit fatal" system is authorable, shown on the bench, and never consulted.** `scripts/combat/hitzone.gd:32,88-90`; authoring wired at `hitzone_builder.gd:523` and `hitzone_editor.gd:384,550`. Live kill logic hardcodes a string instead: `enemy_base.gd:2102-2104 if zone == "HEAD": amount = current_hp + 999`. The day anyone authors the helmeted heavy this was built for (`fatal_override = 0`), the editor will say "not FATAL" and the game will kill him anyway. Second confirmed instance of *bench writes what the game never reads* — worth ruling on as one class with the viewmodel-calibration case, not two tickets. |
| **An orphaned second world-location planner, unmarked.** `scripts/world/location_planner.gd:23`; only caller is `tests/test_world_alive.gd:23,64-75`. Live path is SitePlanner (`mission_generator.gd:420,539`). The orphan is shorter and better commented, carries no test-only disclaimer, and implements a different pipeline order — `apply_lifts()` raises the heightmap and expects hydrology re-run afterward, which the game does not do. |
| **The surface-hardness rule is copy-pasted byte-for-byte.** `scripts/combat/bullet_system.gd:182-190` and `scripts/player/weapon_holder.gd:906-913` — identical bodies, identical rock/metal/bunker/vehicle/truck list, identical group check. Harmless today, guaranteed to diverge: add "concrete" to one and half the game's rounds spark, half puff dirt. |
| **Rice-paddy avoidance defined twice under two names.** `ambush_planner.gd:20 PADDY_AVOID_M = 30.0` (`_near_paddy` `:58-62`) and `patrol_generator.gd:13 PADDY_AVOID_RADIUS = 30.0` (`_near_paddy` `:78-82`). Same value today, so invisible; a retune lands in one file and ambush siting and patrol routing quietly adopt different rules about standing in open water. |

### SILENT LIE — no error, and the world contradicts itself (7)

- **Craters erase AI-visible cover** (short list #7). `gameplay_grid.gd:479-497` vs `:121,142`.
- **Patrol anchors: every named key misses, and the one that hits is your spawn.** `mission_generator.gd:158-160` and `:405-407` read `village_center`/`firebase_center`/`camp_center`; the planner writes `fsb_center` (`:439`), `village_centers` (`:485`), `camp_centers` (`:499`). All three singular reads miss silently behind `p.has()`. In `_patrol_anchors` the miss is masked because `p.sites` supplies village and camp centres anyway (`:157-160`) — so nothing looks wrong. The harmful key is the one that DOES hit: `insertion_lz` = `gm.spawn_pos` (`:443`). In `_enemy_anchors` all three miss with no fallback, so NavBaker (`:596`) is seeded from `enemy_groups` positions only.
- **Squad perception ignores weather, night and jungle** (short list #3). Worth noting the fairness machinery it undercuts is otherwise excellent: `ai_marksmanship.gd:72-89` puts the exposure ramp and first-shot near-miss on the correct branch, wired at `enemy_base.gd:1941-1943`.
- **Patrols seeded with the player's spawn** (short list #4).
- **NVA regulars arrive dressed as VC.** `data/enemies/nva_regular.tres:24` declares `sprite_unit = "nva_regular"`; no such GLB exists in any folder ModelActor searches (`scripts/visuals/model_actor.gd:14-16,22-30`), so it falls back to `vc_guerilla_ppsh` (`enemy_base.gd:329-333`). This is one of the most-spawned enemies: the escalation hunter (`field_director.gd:100`), two lazy_group slots (`:23-24`), two generator pool slots (`:34-35`). Graceful, but it erases the payoff of Pillar 5's escalation ladder — the thing hunting you after first contact looks identical to what you were already fighting. Runtime found a **second** unlisted case: `nva_rpg` → `vc_guerilla_rpg` via `lazy_group.gd:80`.
- **The orphaned-art probe can never pass, and gates nothing.** `tools/probe_orphaned_art.gd:83` asserts against `scripts/missions/insertion_ride.gd`, deleted in commit `4d4fff2d`; `_read()` returns `""` for a missing file so `_reads()` returns false permanently (`:108-110`). I ran it: `[FAIL] the HUEY AIRCREW are pilots, not olive capsules` — exit 1, unfixable by art. Meanwhile `production/ART_GAPS_2026-07-13.md:82` claims it "now **fails the build**", but `run_all_tests.ps1:22` globs only `tests/test_*.tscn` and the probe lives in `tools/`; no `.ps1` or `.bat` mentions it. The same doc's orphan table names three GLBs not among the 24 on disk.
- **The Bible reports an open P0 determinism bug that does not exist.** `production/bible/03_AI_DETECTION.md:28-30` says `randf()` inside `has_line_of_sight()` poisons the shared RNG stream. The real function is a pure `intersect_ray` with zero `randf` (`combat_manager.gd:268-281`; grep for randf in that file returns nothing), and its only caller path `enemy_base._can_witness` is also randf-free. It sends an agent hunting a phantom and may get a clean raycast "fixed", while falsely blocking determinism-dependent work.

### DOC DRIFT — canon that would misdirect the next agent (12)

- **Overseer charter enforces retired damage dice** (short list #9). `.claude/agents/recon-overseer.md:58`.
- **The Bible's canonical mission loop is the chain ADR-029 deleted.** `production/bible/BIBLE.md:97-101` (BRIEFING → INSERT Huey → PLAY 2–4 objectives → EXFIL → DEBRIEF), plus `:31,36,37,93-95`. Live code has one mission type, "PATROL" (`mission_generator.gd:417,536`); `insertion_ride.gd` and `mission_select.gd` survive only as orphan `.uid` files. The file that says "if code contradicts the Bible, the code is wrong" (`BIBLE.md:3-5`) carries no date banner and no supersession note.
- **The Bible still lists the killed sprite pipeline as owed work.** `09_CHARACTERS_ART.md:55-59` names a sprite epic bead as outstanding, against ADR-001 (3D for everything) and `GAME_GUIDE.md:271,283` ("KILLED"). No live code references it. The Bible ranks 4th in the Overseer's constitution (`.claude/agents/recon-overseer.md:46`), above DESIGN.md.
- **Every "DESIGN.md §4.x" pointer in canon resolves to nothing.** DESIGN.md has no numbered sections at all (`DESIGN.md:3-206`) and no M0–M8. Dangling citers: `BIBLE.md:44,50,57,93,97`; `03_AI_DETECTION.md:17`; `05_CAMPAIGN_ROSTER.md:3,36,54`; `09_CHARACTERS_ART.md:3,55`; `ADR-001:2,24,44,64`; `ADR-006:2`; `ADR-008:2,19`; `ADR-009:46`. Worse: `BIBLE.md:50` sources the five Pillars from "DESIGN.md §1" then lists five pillars that are **not** the five in `DESIGN.md:69-95`. The highest law in the project has two competing texts and a broken pointer between them.
- **Bible 09 sends the art pipeline to three folders that do not exist.** `09_CHARACTERS_ART.md:13,15,18` name `assets/models/characters/`, `assets/models/viewmodels/`, `art_source/characters/fp_arms/`. `assets/models/` is absent entirely and `art_source/` was deleted. Real viewmodels are `scenes/weapons/*_arms_viewmodel.tscn`; real arms live in `assets/player/arms/`. This is the "Pipeline of record" section.
- **Bible 05 tells campaign work to reuse a function whose file was deleted.** `05_CAMPAIGN_ROSTER.md:37` — "Uses existing `mission_select.roll_offers()`". Only the `.uid` remains; `roll_offers` has zero hits in `scripts/`, and the offer chain is forbidden by ADR-029. ("Uses existing" is the most dangerous phrase in a spec — it tells the reader not to check.) The same file's CampaignState claim IS true (`project.godot:35`).
- **An Accepted ADR's VERIFIED evidence block cites deleted files and moved lines.** `ADR-012-input-doctrine.md:82-86`: `project.godot:230-233` (actual `:245`), `:106-109` (actual `:121`), `hub_controller.gd:47,53` (deleted), and the E-as-interact carve-out at `:39-43` is preserved for `insertion_ride.gd:104-107` — also deleted. The one substantive surviving rule is true: squad orders are still dual-bound.
- **A live-voice plan doc says every LZ in the game is a lie, after the fix shipped.** `DESTRUCTIBLE_JUNGLE_PLAN.md:88-100` claims `update_region()` "runs its body never". Today it is three lines delegating straight to `rebuild_rect` — the `get_density_at` guard it blames is gone. It also names `SitePlanner.stamp_firebase()`/`stamp_outpost()`; neither exists (`site_planner.gd` has `stamp_village:208`, `stamp_vc_camp:582`, `stamp_lz:598`). Undated, present tense, opens "Two windows are working in parallel". Highest-cost doc shape in the audit: alarming enough to jump the queue, aimed at a fix already shipped. **One residue is genuinely true and worth keeping: `mark_cleared()` (`gameplay_grid.gd:458`) has zero callers repo-wide.**
- **The player manual documents a key with no binding and a bird that no longer exists.** `PLAYER_MANUAL.md:23` documents hold-G ABORT; `project.godot`'s input block has no abort action among its 38. `:5-7,63,72` describe the offer/Huey/exfil loop deleted by ADR-029. Internal contradiction too: `:5` "six-man recon team" vs `:27` "Five men". The rest of the keybind table checks out. ADR-012:30 already ordered this fixed and it never was.
- **A pre-everything snapshot is on the mandatory pre-design reading list.** `CLAUDE.md:10` lists STATE_OF_PROJECT.md under "Read these before designing anything". That file is dated 2026-07-07 and its MISSING table (`:164-177`) says "build new" for the mission generator, AI alert states, stealth, saves, audio and VFX — all shipped (`mission_generator.gd`; `enemy_base.gd:64 enum AlertTier`; `save_manager.gd`). It also says Godot 4.5 (`:14`) against 4.7, "All NPCs are colored capsules" (`:46`), and that the sprite pipeline must be built (`:46,167`). Legal under the POINTER LAW because it is dated — invisible to `probe_doc_pointers.py`. Cheap fix is a banner on the CLAUDE.md line, not on the file.
- **A comment names a function that never existed, and the error reached this audit's own brief.** `terrain/water/water_system.gd:429` cites `hydrology_map._trace_river`; the real function is `_trace_channel` (`hydrology_map.gd:484`). The phantom name was copied out of the comment into the standing open-item list handed to me, sending anyone who greps it to zero results and making a real, confirmed bug look unfindable. Small alone, load-bearing as evidence: an unverified pointer in a comment became an unverified pointer in a doc.
- **Four entries in the competing-systems sheet are already fixed and must not be re-litigated.** `COMPETING_SYSTEMS_2026-07-19.md` is stale on: height_scale (all readers now on `TerrainConfig.WORLD_HEIGHT_MAX`/`heightmap.height_scale = 350` — `terrain_manager.gd:55,102,110`, `terrain_chunk.gd:15,44`, `game_world.gd:128,398`, `terrain.gdshader:25`; legacy `@export` gone); night authority (`mission_weather.gd:53,93`); TerrainEngine height (`terrain_engine.gd` no longer declares `get_height_at`/`get_normal_at`; last function is `modify_region:662`; `TerrainEngine.` has zero external references); and its **headline meta-finding** on fossil-probe mutual alibi (`tests/test_fossils.gd:272-274` now subtracts all N declarations). Needs a dated correction banner, not a rewrite.

### LOOSE FILES — disk lies (3)

- **29 committed `.uid` tombstones for scripts deleted in the mission-layer burial.** All 29 tracked by git. Examples: `scripts/missions/insertion_ride.gd.uid`, `mission_director.gd.uid`, `mission_offers.gd.uid`, `scripts/ui/screens/briefing.gd.uid`, `scripts/main/hub_controller.gd.uid`, `assets/shaders/foliage_wind.gdshader.uid`, 17 under `tests/` (`test_exfil_sim`, `test_hub_loop`, `test_generator`, `test_sprite_manifest`, …), and `tmp_prop_check.gd.uid` in the repo root beside CLAUDE.md. `git log -- scripts/missions/insertion_ride.gd` names commit `4d4fff2d` "Overnight W3: the burial". Direct FOSSIL LAW violation, and it **contradicts the clean-list entry "MissionDirector → FieldDirector rename is complete"** — the code hits are gone, the disk artefacts are not. These are the identity records Godot resolves `uid://` through, so any scene still holding a stale uid resolves through a stub instead of failing loudly. Three of them advertise the sprite renderer ADR-001 retired.
- **A whole texture directory that is 21 import stubs with no sources.** `terrain/textures/billboards/` contains 21 `.png.import` files and zero `.png` — e.g. `tree1_billboard.png.import:13` declares a `source_file` that does not exist. `git ls-files` on the directory returns nothing: it is **untracked entirely**, so it exists only on this machine and vanishes on a fresh clone. No code loads any path under it. Residue of the retired procedural-billboard path (`terrain/vegetation/tree_cover_layer.gd:10`), plus matching stale `.ctex` blobs in `.godot/imported/`.
- (The two `.uid` findings above were reported separately by two passes and are the same 29 files; counted once.)

### RUNTIME ONLY — only a boot could show these (4)

Method: `main.tscn` boots to a **menu** (`game_flow.gd:23-25`) with no autostart flag, so a bare headless run reaches no world and printed nothing in 60 s. I ran `tests/test_patrol_world.tscn`, which instantiates GameFlow and calls `_begin_operation → enter_hub()` — the genuine chain. Caveat: it hardcodes seed **31337**, not `DEFAULT_OPERATION_SEED = 47225` (`game_flow.gd:188`). Control run: `tests/test_playtest_bundle.tscn`.

1. **NEW: negative-Rect2 crater** (short list #5). Arithmetic confirms it: gate at `224,1057`, `gate_out (0.892,0,0.451)`, first-sign fan ±67.5° at 170–280 m (`mission_generator.gd:508-511`); the +94° sector reaches z ≈ 1336 on a 1280 m map → cell 334 vs size 320.
2. **Chunk rebuild storm — quantified, and it is not the terrain.** Bundle run (no patrol build): 25 mesh builds / 25 chunks = 1.00×. Patrol run: **53 builds = 2.12×**. All 28 redundant rebuilds fall inside `build_patrol_world`. Per chunk: `(1,4)` ×9, `(0,4)` ×8, `(1,3)` ×6, `(0,3)` ×5, `(2,4)` ×4, `(2,3)` ×2; the other 19 build once. The hot chunks are the firebase's own (gate `224,1057` ÷ 256 = chunk `(0,4)`), and the briefing's seed-47225 figures are the same phenomenon relocated by seed — **FSB-neighbourhood-specific, not chunk-specific**, scaling with deforms stamped near the wire. Mechanism: `terrain_manager.gd:288-309` rebuilds synchronously per deform with no coalescing. The irony: the deferred-flush batching pattern already exists two frames away (`game_world.gd:405-413` merges dirty rects and defers) — it was only ever wired to the shader/vegetation consumer, never to the mesh rebuild.
3. **Terrain relief measured.** Normalized `min 0.38 max 0.63` (seed 31337) and `0.43–0.60` (bundle). Against `WORLD_HEIGHT_MAX = 350.0` (`terrain/core/terrain_config.gd:17`) that is **87.5 m of relief over 1280 m**, and only 59.5 m on the bundle seed — 17–25 % of the height range. Multiplier confirmed live, not assumed: `[SPAWN-TRUTH] physics_y=201.70 array_y=201.70 delta=0.00`, and 0.576 × 350 = 201.6.
4. **Water coverage 3.4 % / 5.1 %** while six river paths extracted — the runtime half of the dry-creek finding (short list #6).

**Checked and found NOT to be a defect.** The load report shows civilians and `us_grunt_rto/rifleman/mg/grenadier` logging `+100 clips` while `vc_guerilla*` and `us_grunt_v3` log `+27`. I nearly filed "enemies have a quarter of the animation vocabulary". `model_actor.gd:258-288` is a **merge, not a replace**: `+27` means the model brought 73 of its own, `+100` means it brought none. Every actor lands on the same 100 clips. Worth keeping: the shared library is exactly 100 clips, and the four mesh-only US exports get a synthesized AnimationPlayer (`:266-273`) and depend on it totally. All 17 characters resolve cleanly (heights 1.50–1.71 m, gib_scale 0.42–0.53), two fallbacks only.

**Warnings triaged.** `agent_height is ceiled to cell_height` ×4 is engine-internal precision notice at `cell=0.250`; all four NavBaker bakes succeeded. Everything after `PASS` (RID leaks, ObjectDB counts) is `get_tree().quit()` with no scene teardown. The twelve `BUG: Unreferenced static string` lines in the main.tscn log are SIGTERM artifacts from my own timeout, not boot errors. The integer-division warnings flagged as verified-benign did not appear at all.

**No FPS number.** Headless instantiates `RendererDummy` (proven by the exit leaks `RendererDummy::MaterialStorage::DummyMaterial` / `DummyMesh`, `world.log:215-217`); there is zero GPU work, so any figure would be fiction. The 24–38 FPS item stands **unverified by me** — it needs `windowed_patrol_perf.tscn`, which I am forbidden to launch.

**What I could not answer.** No runtime evidence on "logs startup but never activity". Both harnesses quit a second or two after the world comes up, so I captured the boot phase only. Absence of SimClock / fire-support / AI-think activity in my logs is fully explained by there being no gameplay time — it is **not** evidence of inertness and I decline to report it as such. `test_world_alive.tscn` soaks 60 s but deliberately builds no mission, director or spawner (`tests/test_world_alive.gd:1-9`), so it cannot see those systems either. The gap is a soak harness; I did not create one, being report-only.

Logs: `…\scratchpad\world.log`, `\bundle.log`, `\main_boot.log`.

---

## 3. PILLAR HEALTH

**Pillar 1 — Believable firefights.**
*Strongest support:* the marksmanship fairness machinery. `scripts/enemies/ai_marksmanship.gd:72-89` puts the exposure ramp and the first-shot near-miss on the correct branch, and `enemy_base.gd:1941-1943` wires them. This is the best-built system I read.
*Strongest threat:* the perception asymmetry (§1.3). Fair aiming on top of unfair *seeing* still produces unfair fights, and the player never learns why he was spotted.

**Pillar 2 — Atmosphere / the jungle as antagonist.**
*Strongest support:* `_sight_cap()` (`enemy_base.gd:686-694`) genuinely folds weather × vegetation × flare into enemy acquisition — the mechanic that makes weather matter exists and is correct.
*Strongest threat:* three things dismantle it. Weather has two authorities that desync after one sim-day (§2 competing); a single crater deletes AI-visible cover for good (§1.7); and the rivers are dry (§1.6). Vietnam without water and with cosmetic weather is a green field.

**Pillar 3 — Freedom / stealth economy.**
*Strongest support:* the open patrol world builds and the passability + FSB keep-out checks do gate group spawns (`mission_generator.gd:93,566-568`).
*Strongest threat:* patrols routing onto the player's spawn seat (§1.4) — unwinnable-by-surprise, the opposite of fail-forward — and the crouch-speed formation flip (§1.2), which makes the one posture stealth requires the one posture the squad cannot hold.

**Pillar 4 — Squad is the RPG.**
*Strongest support:* per-man offsets, combat speed scaling and order bindings all exist and are dual-bound in `project.godot`.
*Strongest threat:* the squad cannot keep up at a walk (§1.1) and its formation slots are unreachable by construction (§2 inert). Attachment needs men who look composed; these look permanently panicked. This is the single mechanical root of the Summoner's playtest verdict, and it is two numbers.

**Pillar 5 — Consequences / escalation.**
*Strongest support:* FieldDirector escalation is live and spawns the hunter (`field_director.gd:100`).
*Strongest threat:* the hunter arrives wearing the VC model (§2 silent-lie). Getting caught escalates in numbers only; the visual payoff — a *different, worse* enemy — never renders. Sappers, the other escalation flavour, are riflemen (§2 inert).

---

## 4. WHAT PROBE WOULD HAVE CAUGHT THIS

The standard: a report finds a problem once, a probe finds it forever. This project already ratchets `test_fossils`, `probe_autoload_reach`, the tool-path baseline, `probe_doc_pointers`, the weapon/projectile contract and the gib contract — **every one of them caught something real today.** Below, per class: is it probeable, what would it assert, and is it cheap.

### 4.1 INERT — highly probeable, and the existing probe has a hole

The fossil probe counts references, so a symbol referenced only by its own test looks alive. Sapper, ScriptedSequence, LocationPlanner, QualitySettings and the grid LOS all hid behind exactly this.

**BUILD: production-reachability probe (`probe_test_only_liveness`).** Assert: for every `class_name` under `scripts/` and `terrain/`, if the set of referencing files minus `tests/` is empty, FAIL with the class name. Ratcheted baseline like `test_fossils` (register today's known-blocked entries and ratchet down). **Cheap** — it is the fossil probe's own scanner with one directory excluded from the reference set. Highest value-per-line in this report: it catches five findings at once and permanently closes the "test keeps the symbol alive" alibi.

**BUILD: behaviour-attachment contract (`probe_behaviour_attached`).** Assert: every `scripts/enemies/*_charge.gd`-style behaviour node class is `add_child`-ed somewhere in production, or is listed in a declared-inert allowlist with a bead. **Cheap.** Catches the sapper class of bug — a defining behaviour that ships but is never attached — which reachability alone would miss if someone merely `preload`s it.

**BUILD: every test scene must parse and exit (`probe_test_health`).** Assert: run `--check-only` over every `tests/*.gd` and `tools/probe_*.gd`; any parse error fails immediately instead of burning a 420 s timeout. Additionally assert every `tests/test_*.tscn` has a matching `.gd` that reaches `get_tree().quit()`. **Very cheap** — one loop, one flag. Would have caught both `perf_probe.gd` (never runnable) and `test_xp_spend_TMP.gd` (7 wasted minutes per suite run, permanent red) the day each landed. Extend it to fail any test whose name ends `_TMP`.

**BUILD: probes must be invoked.** Assert: every `tools/probe_*.gd` appears in at least one runner script. **Trivial.** `probe_orphaned_art` gates nothing while a doc claims it fails the build.

### 4.2 COMPETING — probeable in part; the valuable half is cheap

**BUILD: single-writer contract for shared environment state (`probe_env_writers`).** Assert: for a declared list of hot properties (`fog_density`, `fog_light_color`, `vegetation_density`, `move_speed`, `directional_light energy`), exactly one production file writes each, or the extra writers are allowlisted with a bead. **Cheap and high value** — it is a grep with an allowlist, and it catches the two-weather-systems bug, which is the highest-cost competing item on the board.

**BUILD: duplicate-body detector (`probe_copy_paste`).** Assert: no two functions in `scripts/` share a normalized body hash (whitespace and comments stripped) above ~6 lines. **Cheap.** Catches `_surface_is_hard` exactly, and will catch the next one. The paddy-avoidance pair is *near*-duplicate and would need a constant-value probe instead: assert no two `const` names in `scripts/enemies/` share a value with different names — noisy, **not worth building**; call that one by eye.

**BUILD: one function name, one implementation (`probe_ambiguous_api`).** Assert: no gameplay-critical function name (`has_line_of_sight`, `get_height_at`, `plan_*`, `stamp_*`) is defined in more than one `class_name`, unless allowlisted. **Cheap.** Catches the grid-vs-physics LOS pair and would have caught the TerrainEngine height duplication before it was fixed.

**Un-probeable half:** *which* of two competing implementations is correct is a judgement call. The probe can only prove that two answers exist and force a ruling. That is the right division — the machine surfaces the fork, the Summoner picks the branch.

**PARTIALLY probeable: bench-writes-what-the-game-never-reads.** This is now confirmed twice (hitzone `fatal_override`, viewmodel calibration). Assert: every `@export` field in `scripts/combat/` and `data/`-backed resources that is *written* by a `tools/` or `*_editor.gd` file has at least one reader outside `tools/` and `tests/`. **Moderate cost**, needs a field-level scan rather than a symbol-level one — but this is a *recurring* class, not a one-off, and it deserves the investment.

### 4.3 SILENT LIE — the hardest class, and partly probeable

**BUILD: dictionary key contract (`probe_plan_keys`).** Assert: every string literal passed to `.has(` or `[` on the mission-plan dictionary is a member of a declared key set that the planner writes. **Cheap-ish, very high value** — the plan dictionary is a small, known schema, and this single probe kills the entire `village_center` / `fsb_center` family of silent misses, which is the #4 item on the short list and has been open for a day. Generalize: any `p.has("literal")` where the literal is never written anywhere in the file's module → FAIL.

**BUILD: keep-out assertion for spawn geometry (`probe_spawn_keepout`).** Assert: after `build_patrol_world` at N seeds, no enemy patrol waypoint lies within R metres of `gm.spawn_pos`. **Cheap and it runs headless** — the harness already exists (`test_patrol_world.tscn`). This is a *property* test rather than a reference scan, and it is the correct shape for gameplay silent lies: state a rule about the built world and assert it over seeds.

**BUILD: grid-boost durability (`probe_veg_boost_survives_crater`).** Assert: apply veg boosts, stamp a crater in a boosted cell, re-read `vegetation_density` at that cell, assert still boosted. **Cheap**, four lines in an existing harness. Would have caught §1.7 the day it landed and will guard it forever.

**BUILD: asset-existence contract (`probe_model_exists`).** Assert: every `sprite_unit` declared in `data/enemies/*.tres` resolves to a GLB in a ModelActor search path; fallbacks are permitted **only** for units on an allowlist with a bead. **Cheap** — this is the gib contract's exact shape, already proven across 24 characters. Catches both `nva_regular` and the unlisted `nva_rpg`.

**Un-probeable:** the *perception asymmetry* (§1.3) and the *formation flip* (§1.2) are silent lies only against design intent. A machine cannot know that allies should pay the weather tax or that eight men should not oscillate. What it CAN assert once the Summoner rules is a numeric invariant — `ally.move_speed > player.WALK_SPEED`, `formation_threshold > CROUCH_SPEED + margin`, `ally sight cap reads MissionWeather.sight_mult`. **Recommendation: after the ruling, write those three as a `probe_squad_invariants`.** They are one-line asserts each and they lock the ruling in permanently. This is the pattern worth generalizing: taste is un-probeable, but a *ruled* taste becomes an invariant.

### 4.4 DOC DRIFT — mostly probeable, and `probe_doc_pointers` needs two extensions

Twelve findings, and `probe_doc_pointers.py` (built today) already has the right shape. Two gaps let all twelve through:

**EXTEND: cover the agent-charter and Bible trees.** Assert `.claude/agents/*.md` and `production/bible/**` under the same pointer rules as ADRs. **Trivial** — a path glob. The single highest-reach drift in the report (`recon-overseer.md:58`, the system prompt for the agent that heads every session) sits in a directory the probe does not scan.

**EXTEND: section anchors, not just file paths.** Assert that any `DESIGN.md §N` or `§4.x` citation resolves to a heading that exists. **Cheap.** Fifteen-plus canon pointers, including ones inside Accepted ADRs, currently resolve to nothing — and the Pillars themselves are cited through a broken anchor to a list that disagrees with the real one.

**EXTEND: symbols named in docs must exist.** Assert every backticked `identifier()` or `path/file.gd` in `production/**` and `PLAYER_MANUAL.md` resolves to a real symbol or file. **Cheap**, some false-positive tuning. This alone catches `roll_offers()`, `stamp_firebase()`, `insertion_ride.gd`, `assets/models/characters/`, and `_trace_river` — five findings, one rule. Note that `_trace_river` also proves the rule must cover **code comments**, not just docs: the phantom name started in `water_system.gd:429` and propagated into this audit's own brief.

**BUILD: keybind contract (`probe_manual_bindings`).** Assert every key documented in `PLAYER_MANUAL.md`'s bind table maps to an action in `project.godot`. **Trivial** — the table is machine-readable. Catches the ABORT key that cannot be pressed.

**BUILD: superseded-ADR citation guard.** Assert no doc states a rule from an ADR whose header says SUPERSEDED without also naming the superseding ADR. **Moderate** — needs the rule text linked to the ADR, so realistically it degrades to: any file citing `ADR-003` must also cite `ADR-016`. Crude but it would have caught the charter line. **Worth building in the crude form.**

**Honestly un-probeable:** whether a doc is *stale in spirit* — `DESTRUCTIBLE_JUNGLE_PLAN.md` has correct-looking prose, a present-tense voice, and one still-true residue. Every pointer in it could resolve and it would still misdirect. The cheap mitigation is procedural rather than a probe: **assert every file in `production/` has a date banner in its first five lines**, so a reader can weigh it. Trivial, and it would have flagged the plan doc, STATE_OF_PROJECT's reading-list entry, and BIBLE.md's undated mission loop.

### 4.5 LOOSE FILES — completely probeable, cheapest probe in the report

**BUILD: orphan-artefact sweep (`probe_orphan_files`).** Assert: (a) no `*.uid` without a matching source; (b) no `*.import` without its source asset; (c) no untracked directory under `terrain/` or `assets/` containing more than N files; (d) no file matching `tmp_*` or `*_TMP.*` anywhere in the tree. **Trivial — a directory walk, under thirty lines.** It catches all 29 tombstones, all 21 billboard stubs, and the root-level `tmp_prop_check.gd.uid`. Given the FOSSIL LAW is already ratified and already has a ratchet, this is the missing half: `test_fossils` guards *symbols*, nothing guards *files*. **Build this one first** — it is the best cost-to-coverage ratio on the page, and it closes a direct law violation left by a burial commit.

### 4.6 RUNTIME ONLY — probeable, and it is the biggest genuine gap

Everything in §2 runtime needed a boot, and there is currently **no scene that soaks the real GameFlow world**. `test_world_alive.tscn` runs 60 s but deliberately builds no mission, director or spawner (`tests/test_world_alive.gd:1-9`), so it structurally cannot observe the systems most likely to be inert.

**BUILD: `test_soak.tscn` — the missing harness.** Boot the genuine `GameFlow` chain at `DEFAULT_OPERATION_SEED`, run N simulated minutes headless, and assert liveness: SimClock advanced, at least one AI think tick per registered enemy, FieldDirector evaluated, fire support reachable, no `ERROR:` lines in the log. **Moderate cost, highest strategic value** — it converts the entire "logs at startup, never runs" question from unanswerable to automatic, and it is the one question I had to return unanswered. It also gives every property test above a place to live.

**BUILD: zero-errors gate.** Assert the headless world build emits no `ERROR:` line. **Trivial** given a harness. Catches the new negative-Rect2 crater instantly, and would have caught it the day it landed.

**BUILD: world-invariant probe over seeds.** Assert across ~20 seeds: every deform centre lies inside map bounds; water coverage exceeds a floor; relief exceeds a floor; chunk mesh rebuilds ≤ 1.2× chunk count. **Cheap once the harness exists**, and this is the shape that catches things reference-scanning never will. The rebuild-count assert is a genuine perf ratchet — 2.12× today, and it is FSB-neighbourhood-specific, so it will regress again the next time someone stamps more near the wire.

**Un-probeable headless: FPS.** `RendererDummy` does zero GPU work, so no headless number means anything. Frame rate needs `windowed_patrol_perf.tscn` on the Summoner's machine, and — separately — `perf_probe.gd` must be made to parse before any attribution is possible at all. **The 24–38 FPS item is unverified in this audit.**

### 4.7 The honest boundary

A probe can prove that code is unreachable, that two authorities exist, that a pointer resolves, that a file has no source, that a built world violates a stated rule. That covers, by my count, **roughly 33 of the 41 findings** here.

It cannot judge that the squad feels fidgety, that the monsoon should frighten the player rather than help him, that a firebase should sit close enough to walk to, or that the world is fun to walk and feels like Vietnam. Those are Rule #1 and they are the Summoner's eyes, permanently.

The productive relationship between the two: **the Summoner's eyes find the feeling, the ruling turns it into a number, and the number becomes a one-line assert that never regresses.** The squad-speed finding is the model case — a playtest verdict ("they never look composed"), one root cause (`ally_base.gd:9` vs `player.gd:5-6`), and a permanent invariant (`ally.move_speed > player.WALK_SPEED`) the machine can hold forever afterward.

### 4.8 Recommended build order

| # | Probe | Cost | Findings closed |
|---|---|---|---|
| 1 | `probe_orphan_files` — uid/import/tmp/untracked sweep | trivial | 3 |
| 2 | `probe_test_health` — every test parses and exits; probes are invoked | very cheap | 4 |
| 3 | `probe_test_only_liveness` — production reachability, ratcheted | cheap | 5 |
| 4 | `probe_doc_pointers` extensions — agents/, bible/, §anchors, symbols, date banners | cheap | 8+ |
| 5 | `probe_plan_keys` — mission-plan dictionary schema | cheap | 2 (incl. short-list #4) |
| 6 | `test_soak.tscn` + zero-errors gate | moderate | the whole runtime class |
| 7 | `probe_env_writers` — single writer per shared property | cheap | 2 (incl. the weather desync) |
| 8 | `probe_model_exists` — declared unit resolves to a GLB | cheap | 2 |
| 9 | `probe_squad_invariants` — **only after the Summoner rules** on §1.1–1.3 | trivial | locks 3 rulings |

---

*Report ends. No fixes applied, no beads written, nothing deleted. All 41 items await the Summoner.*
