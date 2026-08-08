# THE SHIP QUEUE — one page, updated 2026-08-07

**EA working target 2026-09-06 — HIS pacing target, not a hard deadline; it can move (ruled 8/7, no Steam page exists yet) · the product is THE DEMO'S SHAPE (ruled 8/6) · zombies parked, kept, not shipped (ruled 8/7).**
Full reasoning: `SHIP_AUDIT_2026-08-07.md`. Check items off here; re-date this file when you do.

## YOUR ART TRACK (the critical path — nothing below replaces it)

- [ ] Firebase checklist, in order (`FIREBASE_EXPORT_NEED_TO_DO.md`): medical anims → artillery
      placement → **mortar anims (in progress)** → HQ + anims → 3 hooches incl. dug bunker →
      bunker entry/hangout anims → shoot-out-of-slits
- [ ] Final firebase export → re-run `tools/gen_firebase_v3.py` → boot must print
      `[FSB] 0 concave shape(s) forced double-sided`
- [ ] M79 to 100% (bench alignment + hand mould)
- [ ] Huey v3: fix seat sockets / 180° flip FIRST, then export gunship + transport
- [ ] RPD + RPG-2 re-exports (`python tools/export_all_viewmodels.py <gun>` — minutes each)
- [ ] M70 sniper re-mount + re-export — he flagged it unconfirmed 8/8; measured 8/5: barrel
      +19.13° / sights 7.92° off barrel in the GLB (model mis-mounted, pipeline itself passes).
      Blender re-mount, then same export path as RPD/RPG-2
- [ ] Crashed A-1 Skyraider: judge the prototype renders, then bless or redirect (feeds S28)
- [ ] Tighten the demo village (models exist — TIGHTEN ONLY: no interiors, no new buildings)
- [ ] Tighten the demo enemy camp (same bar) — **incl. the VC/NVA crewed mortar pit, which lives
      IN this camp per his 8/7 ruling; never a standalone site, never exported as `mortar_pit.glb`**
- [ ] Pilot gib donors (`us_pilot_white/_black`, via psx-npc-pipeline skill)
- [ ] Aid station: surgeon double-body fix, surgeon mask + medic brassard palette

## CODE TRACK (zero art-days, runs in parallel)

- [ ] 1. One uninterrupted full suite run — the number everything else stands on
- [x] 2. ~~Atomic saves~~ **DONE 8/7** — tmp+rename+`.bak`, load falls back to `.bak`
      (`save_manager.gd:99-130`, `:181-205`; guarded by `tests/test_save_roundtrip.gd`)
- [ ] 3. Perf: THE WALK · ONE DIG · THE BARRAGE, recorded
- [x] 4. ~~Reject future-version saves · demo save-dir leak on kill~~ **DONE 8/7** —
      future-version refused (`save_manager.gd:192-198`); the "leak" was the demo sandbox,
      not the real slots: a killed demo session's `saves_demo`/`campaign_demo.cfg` leaked
      into the NEXT demo boot, and a virgin machine's demo inherited the real tour from
      memory. Demo now wipes the sandbox and starts virgin (`demo_game.gd:96-106`, `:136-142`)
- [ ] 5. Spawn-under-world, closed with Caleb's eyes on it
- [ ] 6. Mounted MG fires nothing (test the 33m-downrange hypothesis first)
- [x] 7. ~~Artillery crew wiring~~ **CODE DONE 8/7 night, unverified by playtest.** M22's
      occupation shipped the morning of 8/7 (commit `0b023a4e`); the night pass made it a CREW:
      per-pit seeding (`site_planner.gd` `_arty_pits()` + crew block in `fsb_garrison_plan`,
      1 howitzer crew of 3 + 1 mortar crew of 3, other pits stay unserved by budget),
      phase-locked staged loop `scripts/world/gun_crew_performance.gd` (litter-team driver
      shape; 27.3s/26.633s clocks), combat release through `garrison_defender.gd promote()`
      (`crew_driver.release_man`) so the crew fights at stand-to and reforms at dawn
      (`role` now survives the promote/stand-down round-trip). **The piece stays a statue
      until his artillery-placement export** — contract in `ART_GAPS_2026-08-07.md` "NOT ART";
      the recoil consumer is already coded (`_bind_piece`)
- [ ] 8. ~~Cover-seek stops 10m short~~ **CODE DONE 8/7 night, unverified**: false cover from
      distant walls' LOS shadows; blocker must now sit ≤2.5m (`COVER_BLOCKER_MAX_M`,
      `enemy_base.gd` cover+bound tests, `ally_base.gd`) · trouser clipping still open (art)
- [ ] 9. After his exports land: chow-hall diner side (12 clips) · Huey variant switch ·
      ~~camp station consumption~~ **CODE HALF DONE 8/7**: `_stations_near` takes camps
      (`mission_generator.gd:296`), `stamp_vc_camp` publishes `work_stations`
      (`site_planner.gd:1714-1721`), `.001`/`_001` strip at the read site
      (`site_planner.gd:567-570` — was real: `_collect_stations` never stripped, the fsb
      reader at `:936-939` always did)
- [x] 10. **S27 mortar harassment loop** — CODE DONE 8/7, unverified by playtest.
      `scripts/world/camp_mortar.gd` (random timing, 10-min hold, crew-dead/tube-dead
      silence latch) · shells reuse `SiegeDirector.fire_mortar_volley` with the camp pit
      as source (`siege_director.gd:658`) · night link gates the ranging walk
      (`siege_director.gd:641,653`) · crew = lazy group `camp_mortar_crew` on camp
      stations (`mission_generator.gd:810-812,1086-1108`)
- [x] 11. **S28 downed pilot recovery** — CODE DONE 8/7 (late), unverified by playtest and
      still riding the pilot bind/gib art fixes. The chain: ZPU stands at the demo camp
      (`scripts/world/zpu_gun.gd`, stamped at `mission_generator.gd:851-860`, crew group
      `zpu_crew` at `:816-820`) → fires real tracered bursts at overflights, rolls the kill
      ONLY vs a transiting Skyraider (`zpu_gun.gd:163-176`) → plane dives on a smoke trail
      and explodes (`cas_airplane.gd` `shoot_down`/`_fly_crash`/`crashed`) → wreck
      (`a1_skyraider_crashed.glb` via `place_structure`), burning FireHazard + tall smoke
      column = the only waypoint, pilot on HOLD beside it, lazy VC picket 25-60m off
      (`scripts/world/pilot_recovery.gd`) → player within 12m wakes FOLLOW → inside 30m of
      the wire he walks to the aid-station post and banks (`flags["pilot_recovered"]`,
      end card line `demo_game.gd:_show_end_card`, campaign counter + lost-pilot bag
      `campaign_state.gd:on_mission_end`). Silencing mirrors CampMortar: `zpu_crew` dead
      OR gun Destructible killed; a killed gun banks `aa_killed` (reader was stranded at
      `campaign_state.gd:249`). No event in the first 600s, ONE event per day.
      Ambient tracer AA decree (8/7 late) LANDED: 3 atmosphere-only points, `ZpuGun.attach_ambient`
      (`zpu_gun.gd`), planned/stamped at `mission_generator.gd` `plan_demo_world` ambient-AA block +
      `build_patrol_world` — no crew, no kill roll, world-masked, unverified by playtest.
- [x] 11a. **Ambient walking-dice encounters** — CODE DONE 8/7 (late), unverified by playtest.
      His decree: "vc harrasing villagers, or other friendly squads either on patrol or stuck in
      their own firefights... a dice roll that happens as the player walks around so its not just
      all happening at once." `scripts/world/ambient_encounters.gd` (roll every 65m walked outside
      the wire, 35% chance, ONE live at a time, 240s cooldown, day caps 1/2/1, 600s hold, no rolls
      at night or under siege) · stamped `mission_generator.gd` `plan_demo_world` (after the
      ambient-AA block) + attached last in `build_patrol_world` (appended seed draws) · exclusivity
      gate is two-way with the pilot chain (`pilot_recovery.gd` `encounter_active` both sides) ·
      harass = LazyGroup at the ville + forced COWER, kill-them-all banks
      `flags["villagers_freed"]` · patrol/firefight reuse `FriendlyPatrolGroup` + real VC via
      `spawn_tracked_enemy`, RTB-to-gate then despawn beyond 220m.
- [x] 11b. **S29 destructible jungle** — CODE DONE 8/7 (pre-freeze), unverified by playtest.
      `scripts/world/tree_break_system.gd` autoload (register/query_ahead/apply_blast/promote),
      wired from projectile_base/combat_manager/damage_system/tree_cover_layer; `FellableTree`
      deleted per fossil law; 60 GLBs renamed `_stump`/`_stem`/`_crown`. Still owed: live-fire
      at the support-fire range. ~~M-4 ballistic tags~~ DONE 8/8 night: snag/log/bench/pooled
      trunks `hard_surface`, tunnel `hard_surface`, resupply crate `soft_cover`
      (`tree_break_system.gd`, `tree_cover_layer.gd _acquire_body`, `tunnel_room.gd:32`,
      `field_director.gd:1061`).
- [ ] 12. UI legibility (ONE day) · launcher/shotgun audio · balance the demo arc · build hygiene
- [x] 12a. **PSX look toggle** — LANDED 8/7 per his ruling: "PSX LOOK" in settings, **default OFF —
      perf numbers (item 3) still govern default-on** (`scripts/autoload/psx_look.gd`; material-shader
      half filed in `ART_GAPS_2026-08-07.md` "PSX LOOK")

## DECISIONS ONLY CALEB CAN MAKE

- [x] ~~Villages/camps~~ **RULED 8/7: the ONE demo village + ONE demo camp ship, tightened from
      existing models** (they're already stamped by `plan_demo_world`). Villages/camps AT SCALE
      stay post-launch per 8/6.
- [ ] LAW and RPG-7: pull from the EA rack (free) or export viewmodels (~1 art-day each)?
- [ ] **arms_rig.glb** (8/8 sweep find): a complete FP unarmed/melee set — 18 clips / 2,808
      channels (jabs, grabs, knife draw/hits, guard, finger-gun) with ZERO readers and no doc
      anywhere claiming it. Build unarmed/melee combat (a feature, days) or park it? No system
      expresses melee states today.
- [ ] **Huey vignette set** (4 GLBs, ~7,656 channels: approach/land, casualty load, liftoff,
      troops disembark — 14 rigs each, zero readers): wiring is blocked on a re-centered
      re-export (two authored groups never shared an origin; `test_asset_probe` flags all four
      at 67.3m). Re-export first (art), then wire on the gun_crew_performance driver pattern?
- [ ] **`us_artillery_m101.glb`**: 14.6 MB byte-duplicate of the kit emplacement, zero readers —
      delete it? (Deletion is your call, never incidental.)
- [ ] **seat_pax_7**: `seat_system.gd:24` declares it; the shipped `huey.glb` carries pax 1–6
      only (the 7th exists in a .blend, never exported). Export it with Huey v3, or drop the
      declaration?
- [ ] group_walk backwards marchers: fix formation (recommended) or restage the probe?
- [ ] hunters count: enforce, drop, or record as scenery?
- [ ] Roads: cut from EA (a 512m firebase map may legitimately have none)?
- [ ] Huey gunship vs transport: any visual difference beyond doors? (Recommend: no, for EA)
- [x] ~~Mortars + pilot rescue in EA?~~ **RULED IN, 8/7 night: "i think the pilot rescue and
      mortars should be in the game."** Now S27/S28 on the code track below. Mortar timing is
      RANDOM (*"you can never predict what charlies thinking"*). Defaults standing unless he
      overrules: rare-but-real garrison wounds · crew dead OR tube destroyed silences, no
      re-crewing that day · no fire in the first ~10 min · silenced camp = no siege mortar walk.

## NOT BEFORE 9/6 — the tripwires

A SECOND village or camp · building interiors/CQB · civilians at scale · convoys · roads ·
tunnels · POW · gunship rides · zombie anything ·
UI research week · texture optimisation without perf numbers · `__mg` clips and animation variety ·
bunker firing slits (feature in art's clothing) · NVA/VC variant passes beyond export ·
migration decree P2–P7 · new weapons · new archetypes

## STILL UNBUDGETED, STILL REAL

Steam store page · capsule art · trailer · age rating — budget 2–3 days NOW, not in the last week.
And the standing gate: **the demo playthrough, verified by Caleb, has never been discharged.**
