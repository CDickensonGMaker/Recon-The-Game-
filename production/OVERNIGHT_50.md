# OVERNIGHT 50 — improvement task queue (2026-07-08)

Generated from the Bible + ROADMAP + a grounded codebase audit. Each task tagged:
`[RESEARCH]` web study · `[CODE]` GDScript, no Blender · `[DESIGN]` doc/spec · `[ASSET]` needs Blender · `[DOC]` Bible fill.
**AUTO** = safely runnable overnight without you or Blender. **GATE** = needs your input or Blender/MCP.

Grounded facts this list is built on (audit): blood = red CPU particles only, player-shots-only (`gun_fx.gd:174`);
ragdoll MISSING (canned death clip); CAS dive-bomb + napalm strip + fire-support menu FULLY WIRED
(`cas_airplane.gd`, `mission_director.gd`) but no F-4 horizontal flyby, napalm craters only center;
terrain cratering + tree clear WIRED (`damage_system.gd`), no rubble; claymore WIRED (box mesh);
punji MODEL-ONLY no damage; skills 6/7 wired, `detect_ambush`+player `al` dead; coop = zero networking.

---

## A. Research & study — internet (all AUTO)

1. `[RESEARCH]` Squad-command mechanics across FPS (SWAT4, R6, Brothers in Arms, Ghost Recon, Full Spectrum Warrior, ARMA) → distill order/formation/cover/suppression command patterns → report `production/research/squad_mechanics.md`. Compare to our `squad_system.gd` (follow/hold/move/fire-toggle only).
2. `[RESEARCH]` Open-source FPS study (Xonotic, Cube2/Sauerbraten, Red Eclipse, AssaultCube, Godot FPS demos, Trenchbroom/Quake AI) → what's portable (AI, weapon feel, netcode) → `production/research/oss_fps.md`.
3. `[RESEARCH]` Godot 4 coop architecture (high-level multiplayer, MultiplayerSynchronizer, server-authority, host migration, determinism) → feasibility + cost/risk for RECONgame → `production/research/coop_feasibility.md`.
4. `[RESEARCH]` Vietnam air support authenticity (napalm runs, Arc Light B-52, Spooky/Puff, CBU cluster) → numbers/behaviors to tune CAS → `production/research/air_support.md`.
5. `[RESEARCH]` Blood/gore FX techniques (PSX-era + modern: decals, spray particles, mesh gibs, pooling, screen-space) → pick an approach fitting our low-poly look → `production/research/gore_fx.md`.
6. `[RESEARCH]` Godot 4 ragdoll approaches (PhysicalBone3D from Mixamo skeleton, anim→ragdoll blend, active ragdoll, perf) → implementation plan → `production/research/ragdoll.md`.
7. `[RESEARCH]` Booby-trap/mine mechanics in tactical FPS (tripwire, pressure plate, command-det, punji) → design for RECON → `production/research/traps.md`.
8. `[RESEARCH]` Procedural settlement/village clustering (hamlets, road-connected, paddy layouts) → algorithm for village clusters → `production/research/village_clusters.md`.
9. `[RESEARCH]` Combat bark/vocalizer systems (L4D AI Director + vocalizer, F.E.A.R. barks, radio chatter) → bark system + audio pipeline design → `production/research/barks.md`.
10. `[RESEARCH]` Vietnam terrain destruction / defoliation reference (craters, scorch, fallen trees, rubble) for visual targets → `production/research/terrain_destruction_ref.md`.

## B. World-gen & immersion

11. `[DESIGN]` Village CLUSTER system: group 2–4 `stamp_village` rings into a hamlet with short connecting paths + shared paddy; extend `site_planner`/`mission_generator` ambient pass (`:463-518`). AUTO (spec) → GATE (implement).
12. `[CODE]` Firebase interior variety — fix `hi9c`: make `stamp_firebase()` actually consume its `rng` (vary interior offsets, MG angles, hootch count). AUTO.
13. `[DESIGN]` Random US Army installation TYPES that appear on the map: patrol base, MACV compound, medevac pad, arty battery — spec layouts like the firebase (`site_layouts.gd`). AUTO.
14. `[CODE]` US installation random spawn pass: scatter 1–2 minor US installs per AO in the ambient build (`mission_generator.gd build()`), min-separation like `find_site`. AUTO.
15. `[CODE]` Roads pass firebase→villages (RTS `road_network.gd` borrow — existing ROADS bead). Muddy laterite strip + tire-track decals via `ground_clutter` pattern. GATE (textures).
16. `[CODE]` Roaming civilians in villages: wander/flee AI on a civilian actor (reuse `ally_base`/`enemy_base` movement, non-combatant), informs on a timer (DESIGN §4.2). AUTO (AI) / GATE (civ model).
17. `[CODE]` More ambient world scatter along the insertion corridor: destroyed vehicles, refugee markers, extra B-52 craters (extend `mission_generator.gd:497-505`). AUTO.
18. `[CODE]` Vegetation density + bush variety pass (bead `360a`) — vary sizes/clusters in `ground_clutter`/vegetation manager. AUTO.
19. `[DESIGN]` "Ville attitude" data (friendly/neutral/VC-sympathizer) driving civilian behavior + informant risk. AUTO.

## C. Combat feel, gore & ragdoll

20. `[CODE]` Blood DECALS on surfaces behind flesh hits — reuse the `gun_fx.bullet_hole()` Decal path (`:211`) with a red blood texture; FIFO-capped. AUTO (code) / GATE (texture).
21. `[CODE]` Enemy-shooter blood: call `GunFX.blood()` on flesh hits in `enemy_base.gd` (currently player-only, `:1337`) and `ally_base.gd`. AUTO.
22. `[CODE]` Blood spray + pooling: textured spray particles + a short-lived ground pool decal on kills. AUTO (code) / GATE (texture).
23. `[CODE]` Flesh-hit audio: replace `gun_fx.gd:197` placeholder with a wet-impact sample (source CC0 or synth). GATE (audio).
24. `[CODE]` **Ragdoll**: PhysicalBone3D ragdoll off the Mixamo skeleton on death, blend from death clip → physics (`enemy_base._die` `:1519`, `ally_base` `:551`). Per ragdoll research (#6). GATE (verify per rig).
25. `[CODE]` Explosion visual FX (grenade `:88` TODO): shared fireball/flash/smoke/dust for grenade/claymore/sapper/arty. AUTO (code) / GATE (polish).
26. `[CODE]` Wire real fire VFX: connect the unused `terrain/systems/terrain_vfx.gd NAPALM_FIRE` into `FireHazard` (`fire_hazard.gd:26` placeholder cylinder). AUTO.
27. `[CODE]` Pain stagger/flinch: wire the uncalled `apply_stagger()` (`enemy_base.gd:1513`), add hit-recoil + pain-bark-on-hit. AUTO.
28. `[CODE]` Smoke visual upgrade: replace the "goofy grape" sphere (`smoke_cloud.gd:9`) with particle smoke, correct color. AUTO (code) / GATE (polish).
29. `[CODE]` Rubble/debris: destroyed structures leave a rubble mesh + scorch instead of `queue_free` vanish (`mission_generator.gd:627`). AUTO (code) / GATE (rubble models).
30. `[DESIGN]` Gib/dismemberment option for heavy hits (.50 cal, explosions, danger-close) — spec low-poly gib pieces + trigger thresholds. AUTO (spec).

## D. Traps & explosives

31. `[CODE]` **Punji trap gameplay**: give `punji_trap.glb` a trigger Area3D + foot/leg wound damage (model exists, zero collision `collision_table.gd:35`). AUTO.
32. `[CODE]` Tripwire trap system: tripwire → grenade/explosive detonation; VC places along trails. AUTO.
33. `[CODE]` Pressure mine / toe-popper trap type (reuse claymore/grenade explosion trio). AUTO.
34. `[CODE]` VC trap placement in world-gen: scatter punji/tripwire near villages + trail corridors (enemy side); Point-man/Demolitions spot them (`plant_charge` pattern). AUTO.
35. `[ASSET]` Claymore model — replace placeholder box (`claymore.gd:19`) with real claymore `.glb` + "clack" detonation audio. GATE (Blender).

## E. Air support & planes

36. `[CODE]` **F-4 Phantom fast horizontal flyby** (your exact idea): spawn ~200m out, fly fast + low with loud doppler, drop napalm/CBU along a straight run, then **climb and despawn into the clouds once 100m+ past** the player (fade into the cloud layer, free). New `Phase` path distinct from the self-directed dive-bomb (`cas_airplane.gd`). AUTO (code) / GATE (F-4 model — Skyraider scene exists as stand-in).
37. `[CODE]` Napalm strip terrain destruction: lift the single-center-crater cap (`cas_airplane.gd:3-4,95-104`) to scorch/deform the whole strip + knock down more trees, perf-budgeted. AUTO.
38. `[CODE]` Cluster bomb (CBU) ordnance type: many small craters + submunition pops over an area; add to fire-support menu. AUTO.
39. `[CODE]` Air-strike cinematics: shockwave ring, screen shake, dust wall, doppler on approach for napalm/bomb. AUTO (code) / GATE (polish).
40. `[CODE]` Fire-support authenticity tune from research #4 (delays, danger-close, budgets per mission type). AUTO.

## F. Dialogue & audio

41. `[CODE]` **Troop dialogue AUDIO layer**: play bark audio via the `audio_manager` voice pool — enemy Vietnamese callouts + squad radio chatter. Trigger logic already exists as text (`enemy_base` shouts, `squad_system` toasts). GATE (voice samples).
42. `[CODE]` Expand bark trigger set: taking-fire, flanking, reloading, man-down, trap-spotted, grenade-out, enemy taunts, fallback. AUTO (triggers) / GATE (audio).
43. `[CODE]` RTO radio-procedure VO for fire-support calls (text→placeholder audio). GATE (audio).
44. `[CODE]` **100 roster bios** data file `data/roster/bios.gd` with name/nickname/quirk/voice-temperament tag feeding barks + roster (Bible 05, `squad_roster.gd` currently procedural). AUTO — batchable via subagents.
45. `[RESEARCH]/[ASSET]` Weapon/ambience audio sourcing list (CC0) + procedural synth plan (beads `ew4u/9qp6`). AUTO (list).

## G. Skills, RPG & wiring

46. `[CODE]` Wire the dead `detect_ambush` skill + player `al` attribute → a "being-noticed" directional pip (DESIGN §4.10; `al` only read on squad now). AUTO.
47. `[CODE]` Make squad members' OWN skills/attributes drive their combat (`small_arms`/`sniping`/`st`/`ag` on allies, currently player-only — `ally_base.gd`). AUTO.
48. `[CODE]` Barracks UI: show each skill's real effect + costs (`barracks.gd`), and flag unused ones. AUTO.

## H. Coop (investigation only — greenfield)

49. `[CODE]` Coop feasibility SPIKE: prototype Godot high-level multiplayer on the player controller (2-peer movement + shot sync) in a throwaway scene; measure effort. GATE (report back before committing).

## I. Docs / Bible / wiring status

50. `[DOC]` Fill the unwritten Bible chapters from `DESIGN.md §4` + this audit: `00_PILLARS`, `01_GAME_LOOP`, `02_GUNPLAY`, `03_AI_DETECTION`, `04_SQUAD`, `06_MISSION_GEN`, `07_INSERT_EXFIL`, `08_WORLD_TERRAIN`, `10_UI_AUDIO`, `11_SUPPORT_FIRE`, **plus** a `WIRING_STATUS.md` matrix (wired/stubbed/missing) answering "how much is left before we scale." AUTO — batchable via subagents.

---

## Overnight execution notes
- **AUTO-runnable now (no you, no Blender):** all of A (1–10), plus 12, 13, 14, 17, 18, 19, 21, 25, 26, 27, 30, 31, 32, 33, 34, 37, 38, 40, 42(triggers), 44, 46, 47, 48, 50. That's ~30 tasks a workflow could grind through tonight.
- **GATE (needs Blender/MCP or your call):** 35 (models), 15/20/22/23/41/43 (textures/audio), 24 (ragdoll verify per rig), 36 (F-4 model), 49 (coop go/no-go).
- Bead hygiene: this doc IS the queue. Beads get created only for follow-up work as tasks complete — not 50 up front.
</content>
