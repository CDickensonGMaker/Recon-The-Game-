# WAVE 3 — MORNING REPORT (W01–W90)

**Run:** 2026-07-08. Plan: `~/.claude/plans/drum-up-a-15-refactored-avalanche.md`. ~25 commits, every block regression-tested. Regression table at the bottom.

> **DEAD as a planner; a dated LOG otherwise.** ADR-014 (`production/adr/ADR-014-doc-hierarchy.md`:44-46)
> names this file DEAD alongside ROADMAP_NEXT.md and ROADMAP_WAVE2.md; the consolidation into
> `ROADMAP.md` was never executed, so the file still sits at repo root. Read it as a snapshot of what
> was true on 2026-07-08 — never as a description of the game today, and never as authority. Systems
> below have since been superseded by ADR-016 (flat damage) and ADR-029 (open patrol simulator).

## SHIPPED — 84 of 90 (6 documented defers)

### A. Campaign meta (W01–04)
Persistent `CampaignState` (user://campaign.cfg): **AA threat level** with decaying modifiers, team XP, roster, intel points, mission log. Loud missions heat the AO; clean work cools it. **ANTI-AA SWEEP** is a full 5th mission type (satchel 2–3 gun sites → −threat for 3 missions); at HIGH threat, live AA positions spawn near your LZs and killing them opportunistically pays too. Threat shows on mission select + the menu intel panel.

### B. The Huey ride (W05–12)
Missions open at a staging pad: walk up, **E to board**, sit the left door with capsule crew, rotor loop thumping, terrain-following flight to the LZ. **AA rolls en route** — tracer streams reach up at you; get hit and it's a crash landing, survivors continue (E&E). Dismount prompt, bird departs. Exfil boards you the same way — the climb-out is the closing shot. Hot exfil LZs wave the bird off or **shoot it down**; the fallback LZ is final.

### C. The squad (W13–24)
Five persistent men in EVERY mission, generated RECON-style (2d100 St/Ag/Al, 4-F reroll), one per MOS with real teeth: **Point** warns of ambushes, **RTO** gates CAS/mortars/resupply, **Doc** runs the downed-revive chain (2/mission), **Pig** sustains fire, **Thumper** auto-lobs M79 at clusters. Orders on **F1–F4** incl. weapons-tight (squad stealth works — buddies are perception-exempt while you're undetected). Name tags, HUD strip, contact barks. KIA are permanent; rookies replace them; the debrief names the dead.

### D. RPG meta (W25–32)
Debrief score → team XP → **BARRACKS**: buy skills/attributes for you and each man. Every purchase does something real (Small Arms=spread, Silent Movement=footstep radius, Demolitions=plant speed+trap immunity, FO/FAC=CAS turnaround, Medic=revive speed/amount, AG=reloads, ST=HP+stamina). Iron Man toggle = campaign permadeath.

### E. Gunplay & body (W33–40)
Stamina w/ winded state, **prone** (Z: 0.35× detection, 0.6× spread), limb wounds (arm=shake, leg=no sprint, medkit clears), hitmarkers w/ kill tone, real bolt-cycle + 3-round burst, **ADS FOV zoom re-enabled**, **Vietnam weapons**: M16A1 primary, NVA AK-47s, VC SKS riflemen — correct sound-signature lore. *(The "5d10 / RECON dice" grammar this block shipped was retired by ADR-016: damage is flat and deterministic, `m16a1.tres`:14 `base_damage = 27`, `WeaponData.get_damage()` returning `maxi(1, base_damage)` at `scripts/weapons/weapon_data.gd`:112-113. The 5d10 survives only as flavour text in the weapon's `description` string.)* **Smoke grenades [5]** genuinely block AI sight lines. **Claymores [6]** with frontal-wedge triggers.

### F. World & missions (W41–48)
**1960s topo map [M]** — real contour bands from the heightmap, 100m grid, water, green player arrow, objective triangles. **Weather system** (clear/cloudy/rain/fog/monsoon w/ rain particles) + **time-of-day** (dawn/dusk/night) rolled per op, shown as chips on offer cards — they scale AI sight caps AND mask hearing (monsoon = move loud). **POW RESCUE** = 5th... 6th mission type (camp, cage, pilot joins your squad, get him out alive). **Photo-recon** bonus objectives (+intel). Villages live: **civilians** (informer mechanic — 25s to stop him), **campfires** at night, **chickens as noise traps**.

### G. Encounter verbs (W51–66)
**Tunnel crawl** (drop into dark cache chambers, +2 intel), **booby-trapped objectives** (Point/Demolitions spot the wire; sprung = 40 dmg + alert), **mortar fire missions [Y]** (spot round → walking volley), **pop flares [7]** (strip night concealment), **binoculars [B]** (zoom + mark targets), **sappers** with satchels in final firebase waves ("SAPPER IN THE WIRE"), firebase **prep-phase**, **resupply drop [8]** on your smoke, **corpse looting** (mags/frags/documents), **Chieu Hoi surrender + prisoner capture**, damage-direction pips.

### H. Atmosphere (W67–78)
Jungle ambience bed + distant-war rumble layer, menu soundscape (idle rotor + radio crackle), combat-contact drum sting, surface-matched footsteps (dirt/grass/water), leeches on long wades, weapon lowers when sprinting, marksmanship stats on debrief.

### I. Systems & ship (W79–90)
**GameSettings** (sensitivity/volume/difficulty/HARDCORE persisted) + Settings screen, **Service Record** (medals wall, mission log), 14 field-manual loading tips, billboard-gen spike fix + NPC think-LOD, repo hygiene, `run_all_tests.ps1`, Windows export preset, **PLAYER_MANUAL.md** (the field manual — read it, it documents every key), this report.

### BONUS (mid-run directives)
- **Main menu rebuilt to your mockups**: your key art full-bleed, stencil title column, olive highlight-bar buttons, INTEL BRIEFING panel, version tag. (`assets/ui/menu_bg.png` + `screen_bg.png` cropped from your PNGs.)
- Detection/gunfeel work from earlier in the session (alert tiers, NoiseBus, muzzle FX) is all live under this.

## DEFERRED — 6 items, with reasons
| Item | Why | Unblock |
|---|---|---|
| W36 projectile ballistics | Dormant pool needs an API audit; hitscan is tuned and safe | 1 focused session |
| W65 AI garrison slots | Enemies lack an anchor/order system (they steer freely) | With M3 cover work |
| W73 heat haze/DOF | Perf-first rule on Intel UHD | After next perf pass |
| W74 sampan/bicycle arrivals | Wants the QRF system (R19) first | With escalation ladder |
| W79 mid-mission checkpoint | Full world serialization — heavyweight, fail-forward covers it | Dedicated design |
| W85 MultiMesh rings | Node counts acceptable after W49/W86; refactor risk > win tonight | Perf pass |

---

# THE ART SHOPPING LIST (what the code is waiting for)

## 1. BLENDER SCENES (highest impact)
| Asset | Expected integration | Placeholder today |
|---|---|---|
| **Huey cockpit/cabin interior** | Sockets named exactly: `SeatPilot`, `SeatCopilot`, `SeatDoorLeft`, `SeatDoorRight`, `DoorGunMount` — `insertion_ride.gd` finds them by name and uses fallback Marker3Ds otherwise. Export GLB → replace/augment `scenes/vehicles/huey.tscn` | Capsule crew at hardcoded offsets |
| **AA gun (ZPU-4 / DShK on mount)** | Any GLB → drop into `assets/building models/structures/vc_nva/`, then point `SitePlanner.stamp_aa_site()` at it + add a `CollisionTable` entry | mg_nest.glb standing in |
| **Weapons cache prop variants** (crates+rifles pile) | Same pipeline as weapons_cache.glb | single cache model |
| **Tunnel interior kit** (optional) | `tunnel_room.gd._build()` replaces box panels with your kit | brown boxes + candle light |
| **POW cage** (bamboo) | `rescue_objective.gd.setup_camp()` | translucent brown box |

## 2. SPRITE SHEETS (the big one — swaps capsules everywhere)
Consumed states per character, 8 yaw angles each (your existing pipeline):
`idle, walk, run, crouch_idle, crouch_walk, aim, fire (2-3 frames), reload, flinch, death_a, death_b, prone/crawl` — plus for VC: `surrender (hands up)` (W63 shows CHIEU HOI) and `crawl` doubles for the wounded-cripple state (W46) and sappers (W57).
- **US grunt set** (5 squadmates + variants): wires into `AllyBase._setup_visual` — code expects nothing yet, so any sheet layout works; keep your `assemble_sheets.py` manifest and we'll write the `Sprite3D` frame-select shader against it.
- **VC set** (your 6 blend variants: farmer/mainforce/sapper/female/nva/heavy): wires into `EnemyBase._setup_visual`, mapping to `vc_rifleman`/`nva_regular` data (+ future archetypes).
- **Rescued pilot** (flight suit) for W48.
- **Civilian** male/female villager (wander/flee/cower poses) for W47.

## 3. WEAPON VIEWMODELS (first-person)
Data files exist and are live — models are WW2 stand-ins:
| Weapon | Data file | Current viewmodel |
|---|---|---|
| M16A1 | `data/weapons/m16a1.tres` | thompson_viewmodel.tscn |
| AK-47 | `data/weapons/ak47.tres` | mp40_viewmodel.tscn |
| SKS | `data/weapons/sks.tres` | kar98k_viewmodel.tscn |
| M60, M79, CAR-15, M1911(keep) | not yet written — say the word | — |
Pipeline: GLB + `MuzzlePoint` marker → `scenes/weapons/X_viewmodel.tscn` → set `model_path` in the .tres → tune in the viewmodel editor. (Your `weapons_v1.blend` / wpn renders are the source.)

## 4. AUDIO (every placeholder is procedural synth — same filename swaps in)
All in `assets/audio/sfx/`:
| File | Should be |
|---|---|
| shot_rifle / shot_smg / shot_pistol.wav | real M16 / AK / 1911 reports (dry, close) |
| shot_distant.wav | far-off rifle crack w/ echo |
| impact_dirt / impact_hard.wav | bullet dirt smack / rock-wood hit |
| explosion.wav | frag/mortar blast w/ debris tail |
| rotor_loop.wav / wind_loop.wav | real UH-1 blade slap loop / door wind |
| jungle_loop.wav | dense insect+bird jungle bed (day) — night variant welcome |
| distant_war_loop.wav | far artillery rumble, irregular |
| radio_crackle.wav | period radio net static + squelch |
| combat_sting.wav | tense percussion hit |
| step_dirt / step_grass / step_water.wav | boot foley sets (2-3 variants each ideal) |
| dry_click.wav | firing-pin click |
| NEW wants: reload foley, bolt cycle, M79 thunk, claymore clack, flare pop, LUU DAN + Vietnamese barks, US squad VO barks, wounded cries |

## 5. TEXTURES / UI
- **Topo map paper texture** (aged 1:25,000 sheet) — `topo_map.gd` renders on flat color today; a paper underlay + grease-pencil font would finish it.
- **Medal/ribbon icons** for the Service Record wall.
- **MACV-SOG patch** (you have it in the mockups) as a transparent PNG for menu/barracks.
- **Offer-card thumbnails** per mission type (optional; text chips today).
- Menu art: DONE — using your mockup PNGs (`assets/ui/menu_bg.png`). More variants rotate easily.

## Regression table — **23/23 PASS** (closeout run)
```
test_anti_aa_sim    PASS 29.4s   test_huey_ride     PASS 31.1s
test_asset_probe    PASS  1.9s   test_huey_sim      PASS 24.2s
test_campaign_state PASS  0.5s   test_mission_state PASS  2.4s
test_cas_sim        PASS 28.9s   test_patrol_sim    PASS 25.6s
test_crater         PASS  9.2s   test_rescue_sim    PASS 26.2s
test_detection      PASS  5.9s   test_sensors       PASS  4.5s
test_exfil_sim      PASS 25.2s   test_site_stamp    PASS 30.1s
test_firebase_sim   PASS 28.4s   test_squad         PASS 30.9s
test_full_loop      PASS 139.6s  test_vehicle_kill  PASS 12.1s
test_generator      PASS 11.7s   test_village_sim   PASS 29.6s
test_grid_queries   PASS  8.6s   test_world_boot    PASS 10.1s
                                 test_xp_spend      PASS  0.5s
```
