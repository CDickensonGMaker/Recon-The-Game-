# RECONgame — Next 45 (post-Nightshift backlog)

Council-sorted. P1 = next sessions, P2 = soon, P3 = later. Tracked in Beads (prefix R-).

## GUNPLAY (pillar 1 — game-designer + systems)
1. **P1** Vietnam weapon swap: M16, CAR-15, AK-47, M60, M79 + SKS/Mosin enemies from `data/vietnam/vietnam_weapon_data.gd`; retire WW2 set (Beads 6rz)
2. **P1** Projectile ballistics via the dormant projectile pool (travel time, drop at range, visible tracers)
3. **P1** NPC fire from gun muzzle tip (define muzzle offsets per NPC/sprite state; tracers originate there) — user directive
4. **P1** RECON damage dice + expanded hitzones: arm hits degrade aim, leg hits kill sprint, head fatal
5. **P2** Three-situation asymmetry: undetected first volley = full effect; ambushed side −heavy until in cover (RECON's secret sauce)
6. **P2** Muzzle flash, impact dirt/foliage puffs, better tracers
7. **P2** Hit feedback: flinch frames, hit sound tick, kill confirm
8. **P2** Real fire modes: bolt-cycle delay, true burst
9. **P2** Weapon stoppages (per-mag jam roll, clear action) + diegetic ammo (mag check, no exact counter)
10. **P3** Player claymores + tripflares (exfil prep phase); VC punji/tripwire traps spotted by point man
11. **P3** Suppression on player: muffled audio, vignette, sway

## ENEMY AI (M3 — systems + technical-director)
12. **P1** Alert tiers RELAXED→SUSPICIOUS→ALERT→COMBAT + visibility accumulator (stance/foliage/motion modifiers)
13. **P1** NoiseBus: typed sound events w/ radii (gunshot 50m, footstep 13m, suppressed ~2m), investigation behavior
14. **P1** Believed-position aiming + last-known search + breadcrumbs (no psychic AI)
15. **P2** Cover claims: AI actually uses SitePlanner cover points/sandbags
16. **P2** Navmesh bake near AI (call exists, commented) or improved obstacle steering — stop wall-bumping
17. **P2** Enemy archetypes: VC militia / Main Force / NVA regular (accuracy, kit density: grenades 1-in-3, RPG 1-in-20) from `vietnam_unit_data.gd`
18. **P2** Patrol routes along generated trails; sentry boredom oscillation
19. **P2** Escalation ladder: alarm runner NPC (radio/flare — killable), QRF from finite manpower pool, mortars walk onto last-known position (audible warning)
20. **P3** Light morale: militia breaks and flees when mauled, NVA doesn't

## SQUAD (M4 — the RPG pillar)
21. **P1** Sprite squadmates: wire the US grunt sheets (8-dir, idle/run/aim/fire/death) onto AllyBase; 5-man team follows + fights (Beads 86a)
22. **P1** Squad orders: FOLLOW / HOLD / MOVE-TO(point) / ENGAGE / HOLD-FIRE (4 keys + point-command)
23. **P1** Medic revive chain: downed state → squadmate drags → medic channel-heals (limited charges) — the lives system
24. **P2** Point man: walks slightly ahead, hand-signal warnings for ambushes/traps (Al-based detection)
25. **P2** RTO gating: no radioman alive = no CAS/exfil call (protect-the-RTO gameplay)
26. **P2** Squad text barks: contact direction, "moving!", ammo, post-fight chatter
27. **P2** Buddy rules: never block player/muzzle line, never break player stealth (perception-exempt while undetected)
28. **P3** VC/NVA enemy sprites (user's 6 unit variants) replacing capsules

## WORLD & ATMOSPHERE (pillar 2)
29. **P1** Dynamic weather port from BPRTS (WeatherPreset resources + rain/fog particle core; add monsoon preset); briefing weather roll drives fog distance + sight caps (Beads n6q)
30. **P1** TimeOfDay: dawn/dusk/night missions (sun angle+energy lerp, night = short sight caps, flares later)
31. **P1** First audio pass: weapon reports w/ distance filtering, jungle ambience bed, wildlife-goes-quiet near enemies (tension tell)
32. **P2** Near-field 3D tree/bush variety using your models (strict budget: 3D near, billboards far) + undergrowth layer
33. **P2** Trail network: worn-path rendering connecting sites (GameplayGrid roads), patrols walk them
34. **P2** More POI types: NVA bunker complex, tunnel entrance cluster (spider holes), crashed aircraft site, abandoned camp
35. **P2** Ambient contact deck: supply parties, medics w/ wounded, tax collector w/ escort, unit bathing — enemies doing jobs (RECON tables)
36. **P2** Civilians in villages + attitude states (friendly/indifferent/hostile); civilians who see you inform local VC on a timer
37. **P3** Water gameplay: wading slows (depth), rivers as tactical obstacles, sampans as props
38. **P3** Night: muzzle flashes reveal position, illumination flares (player + AI), starlight scope item

## MISSIONS & CAMPAIGN
39. **P1** Topo map screen (M): 1960s contour map from heightmap, green player arrow, objective marks, grid squares (Beads b4o)
40. **P2** RESCUE mission type: free the POW/downed pilot, he joins the squad on ally AI, escort to exfil
41. **P2** ASSASSINATE mission type: named officer with patrol routine + bodyguards, intel identifies him
42. **P2** Convoy ambush mission type: moving trucks on a trail, kill-box setup, claymore synergy
43. **P2** Crash-site E&E: mid-mission shootdown (insertion or exfil) mutates objectives to survivor rally + alternate extraction
44. **P2** Live Huey insertion: ride in on the chosen route, door-gun usable, AA sites in world (M7)
45. **P3** Campaign layer: province map, war state, persistent named roster w/ RECON XP spend, wounds calendar, rotate-stateside, Iron Man unlock (M8)

## HOUSEKEEPING (technical-director)
46. **P2** Pause menu + settings (sensitivity, volume, quality preset dropdown wired to world_config)
47. **P2** Perf: fix billboard-gen frame spikes (min 19 FPS) — stagger generate_for_chunk over frames
48. **P3** Retire test_arena + WW2MapGenerator to reference/ folder once M5 lands
