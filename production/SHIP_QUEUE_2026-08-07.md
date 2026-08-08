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
- [ ] Crashed A-1 Skyraider: judge the prototype renders, then bless or redirect (feeds S28)
- [ ] Tighten the demo village (models exist — TIGHTEN ONLY: no interiors, no new buildings)
- [ ] Tighten the demo enemy camp (same bar) — **incl. the VC/NVA crewed mortar pit, which lives
      IN this camp per his 8/7 ruling; never a standalone site, never exported as `mortar_pit.glb`**
- [ ] Pilot gib donors (`us_pilot_white/_black`, via psx-npc-pipeline skill)
- [ ] Aid station: surgeon double-body fix, surgeon mask + medic brassard palette

## CODE TRACK (zero art-days, runs in parallel)

- [ ] 1. One uninterrupted full suite run — the number everything else stands on
- [ ] 2. Atomic saves (temp + rename + .bak; autosave hits slot 8 every 30s today)
- [ ] 3. Perf: THE WALK · ONE DIG · THE BARRAGE, recorded
- [ ] 4. Reject future-version saves · demo save-dir leak on kill
- [ ] 5. Spawn-under-world, closed with Caleb's eyes on it
- [ ] 6. Mounted MG fires nothing (test the 33m-downrange hypothesis first)
- [ ] 7. Artillery crew wiring — 497 channels banked, one guard line, NOT blocked on anything
- [ ] 8. Cover-seek stops 10m short · trouser clipping
- [ ] 9. After his exports land: chow-hall diner side (12 clips) · Huey variant switch ·
      camp station consumption so the VC mortar crew can live in the camp
      (`mission_generator.gd:296` village-only gate + `stamp_vc_camp` work_stations + `.001` strip)
- [ ] 10. **S27 mortar harassment loop** (random timing, camp-sourced, silenceable, night link) —
      after the camp-station fix, BEFORE balance
- [ ] 11. **S28 downed pilot recovery** (AA silent kill → smoke bearing → wreck → walk him home) —
      after S27 and the pilot bind/gib fixes
- [ ] 11b. **S29 destructible jungle** — wire the 60 segment GLBs (batch 8/5, ZERO readers).
      His rulings: no standing colliders; projectile rays ahead, hit tree promotes to 3-part
      form and breaks at hit height; crown falls as cover, stump stays. Never RigidBody.
- [ ] 12. UI legibility (ONE day) · launcher/shotgun audio · balance the demo arc · build hygiene

## DECISIONS ONLY CALEB CAN MAKE

- [x] ~~Villages/camps~~ **RULED 8/7: the ONE demo village + ONE demo camp ship, tightened from
      existing models** (they're already stamped by `plan_demo_world`). Villages/camps AT SCALE
      stay post-launch per 8/6.
- [ ] LAW and RPG-7: pull from the EA rack (free) or export viewmodels (~1 art-day each)?
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
