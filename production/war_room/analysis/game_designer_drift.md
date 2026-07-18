# GAME-DESIGNER LENS — ART DRIFT ON THE CANONICAL PATH (2026-07-17)

Path walked in code: boot (game_flow.gd) -> hub (enter_hub :405 -> MissionGenerator.build_hub :898
-> SitePlanner.stamp_firebase site_planner.gd:430) -> TOC briefing (hub_controller.gd:46) -> board
(hub_controller.gd:51, insertion_ride.gd) -> game_world (mission_generator.gd:365-604) -> exfil
(objectives/exfil_zone.gd:11, same huey.tscn).

## VERDICT IN ONE LINE
The HUB is the drift epicenter: every structure the player walks past at home base is the same
RTS-copy-in generation as the TOC the Summoner already rejected (7nxd). In-mission, characters and
villages are new-era; the leaks are the beige huts, the cultist temple, sphere-chickens, BoxMesh
props, and RTS clutter textures.

## KILL — old-era, fossil law ADR-023 (asset + every ref)
| Asset | Refs to delete |
|---|---|
| us_grunt_v2.glb (Summoner: "not in the game at all"; nothing spawns it) | tests/test_head_burst.gd:26, test_gore_rig.gd:26, test_hitzones.gd:49,71,162,183,193, test_anim_library.gd:37,54, test_seat_system.gd:67; scripts/tools/hitzone_editor.gd:40; scripts/visuals/grunt_randomizer.gd:14; tools/probe_* (worn_gear:10, zone_shapes:11, rig_compare:9, render_height:11, hitbox_coverage:24, anim_audit:12); tools/build_ragdoll_scene.gd:32, dump_spine*.gd. Re-point every test at the six new grunts FIRST (lpib) |
| us_grunt_m14 / m60 / m79.glb (orphans — no spawn path; ART_GAPS §5) | grunt_randomizer.gd:15; probe_anim_audit.gd:12-13; probe_render_height.gd:11 |
| us_rto.glb (superseded by us_grunt_rto), us_medic.glb (never spawned) | model_actor.gd:59 (UNIT_HEIGHT_M), :280 (CARRIES_RADIO) |
| vc_guerilla_m16.glb (orphan per MODEL_SESSION_HANDOFF.md:40) | tools/probe_anim_audit.gd:14 |
| WW2/RTS vehicle fossils: us_m4_sherman, us_halftrack, us_m24_tank, us_jeep, us_jeep_s3o, us_bulldozer, uh1_huey (superseded by huey.glb 7/11) — zero spawn paths | collision_table.gd:37-42,124-128 rows; tests/test_asset_probe.gd:16; tools/probe_penetration.gd:73,79 |
| terrain/textures/billboards/ — ALL 21 PNGs (tree1-6, bamboo1-3, bush1-9, rice1-3): zero code refs | none — pure art fossils, plus .import twins |
| Dead single-tree loader: vegetation_manager.gd:234-243 (palm_tree.blend), :245 (grass_patch.fbx — dir terrain/vegetation/models/ does not exist), _create_procedural_tree :804 | superseded by JunglePatchLayer/TreeCoverLayer; the else-branch :585-586 only fires on manifest failure |
| WW2 string fossils | audio_manager.gd:147 + gun_fx.gd:68 ("thompson"/"mp40"); sprite_state_map.gd:226-227 ("thompson","kar98k","mat49"); weapon_data.gd:92 Thompson comment |
| Sprite renderer stubs (ADR-001; assets/NPCs/ root is GONE from disk — SpriteActor can never load art) | sprite_actor.gd / sprite_manifest.gd (ROOT :15) / SpriteStateMap; fallback wiring enemy_base.gd:345, ally_base.gd:219 — council call: capsule-only fallback is enough |

## REPLACE — function stays, model is Caleb's art call
| Surface | Where |
|---|---|
| HUB SET, whole generation: observation_tower, hootch x2, sandbag_bunker x2 (site_layouts.gd:35-41); 9 extras pool incl. toc/mess_hall/quonset (:50-60); mg_nest :43, sandbag_light :44, triple_concertina :45, psp_helipad :46; parked mutt+m113 (:67-70); static ch47_chinook (site_planner.gd:487); huey.glb (huey.tscn:4) | All RTS copy-ins (May-era, bulk-re-exported 7/9). Same generation as the rejected TOC — when Caleb's eyes killed toc.glb they indicted this whole set. NOTE: toc.glb + commo_bunker.glb were touched TODAY 15:22 (7nxd may be mid-swap — verify by eye) |
| TOC tent itself (7nxd open) | mission_generator.gd:906-908 |
| Armorer's bench = BoxMesh top + BoxMesh legs | armorers_bench.gd:26,39 (ji0v closed but the placeholder still ships) |
| Village huts render flat BEIGE (3asc open, Jul-9 export dropped thatch texture) | site_layouts.gd:6-13 hut pool; thatched_hut/three_room_house confirmed regressed (war_room 2026-07-16 TD analysis) |
| Buddhist temple ruin = CatacombsOfGore CULTIST temple + European "monastary walls" texture, 50% of missions | site_planner.gd:536,542; caller mission_generator.gd:583 |
| Chicken = white SphereMesh — while chicken.glb SITS UNUSED in assets/world/animals/ | mission_generator.gd:844; also absent from VILLAGE_ANIMALS site_layouts.gd:108 — wire the model, kill the sphere |
| Supply crate = untextured BoxMesh | mission_director.gd:430 |
| Tunnel-rat room: 6 BoxMesh walls + BoxMesh cache + BoxMesh ladder | tunnel_room.gd:48,63,73 |
| POW camp built from US Army hootch.glb (a VC camp wearing American buildings) | mission_generator.gd:373-374 |
| NVA have no models — nva_regular/nva_rpg render as VC guerillas via fallback | nva_regular.tres:24-25, nva_rpg.tres:25-26; enemy_base.gd:327-332 |
| Ground clutter textures = TerrainEngine-era temperate set (mushroom, blue_flower, generic grassland) | ground_clutter.gd:26-33 — LIVE near-ground on the whole AO |
| VegetationManager grass = untextured procedural green triangles, renders EVERY chunk regardless of canopy mode | vegetation_manager.gd:897 (_create_procedural_grass), always called :587 — second grass system beside GroundClutter (divergent-systems risk): pick ONE |

## KEEP — already new-era
- Squad/allies: six 7/15 grunts + us_grunt_v3 pools (squad_system.gd:84-93); pilots us_pilot_* (insertion_ride.gd:54); capsule only on missing file
- Enemies: all five .tres resolve to vc_guerilla family, 7/12 gib-parity exports (vc_rifleman.tres:24 etc.)
- Civilians: civ_* roster + capsule fallback (civilian.gd:59-61,88)
- Village life: Caleb market props (site_layouts.gd:86-104, exported TONIGHT 21:06-21:41) + rigged animals :107-112 (add chicken)
- Canopy: JunglePatchLayer merged patches + jungle_palette (jungle_patch_layer.gd:6-15) — shipped default (vegetation_manager.gd:43)
- Impostor cards + TreeCoverLayer (tree_cover_layer.gd:14) — gated OFF pending broadleaf .blend fix + look-check; broadleaf_a/b/c "dark pyramids" do NOT reach eyes in game_world today (arena + gated path only: ai_stress_arena.gd:442,798)
- Weapons: data/weapons/*.tres all Vietnam-era; player M16+M1911 (weapon_holder.gd:123-124); no WW2 .tres, no WW2 viewmodels; shotgun/ithaca bench-only
- VC props: pow_cage, spider_hole, punji, tunnel_entrance, weapons_cache; paddies rice_a/b (paddy_stamper.gd:26-27); UI mockup art menu_bg/screen_bg

## COUNCIL NOTES
1. Rule #1 test: the hub is the FIRST thing the player walks every session and it is 100% old-generation + one BoxMesh bench. Nothing of tonight's market/life wave dresses it.
2. Fossil-law hazard: tests are green on us_grunt_v2 while the game ships different art — the death register is lying (lpib). Re-point, then delete.
3. chicken.glb unwired while a sphere ships is exactly the divergent-systems blindspot; same for the double grass layer.
