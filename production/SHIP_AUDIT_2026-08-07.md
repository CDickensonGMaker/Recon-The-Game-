# SHIP AUDIT — 2026-08-07 (re-run of the 8/6 audit, plain language)

**Goal: Steam Early Access, working target 2026-09-06.**
**His ruling, 2026-08-07: the date is HIS OWN pacing target, not a hard deadline — "there isn't a
real deadline and it can move if it has to."** No Steam page exists yet, so nothing external is
promised. The target exists to set realistic expectations and keep the work honest. **Scope
discipline stays either way — it is what makes any date possible — but the date bends before
quality does, and no cut in this document should ever be forced by calendar panic.**
**This document's only job is to make the remaining work SMALLER.**

This replaces nothing — `SHIP_AUDIT_2026-08-06.md` stays as the record of the ruling. This is the
same audit re-run one day later with everything that changed on 8/7 folded in. Where a claim is
about code, it carries a file pointer or names the doc that proves it (pointer law).

**Standing rulings honored here:**
- **EA = THE DEMO'S SHAPE** (your ruling, 8/6). One firebase, one day, 30 real minutes:
  dawn → the day out → dusk → night stand-to → probe → 45-man assault → gunships.
  `scenes/levels/demo_game.tscn`, 512m map.
- **Zombie mode: DO NOT TOUCH, DO NOT DELETE** (your ruling, 8/7). It is post-launch content.
  It stays in the repo, it stays parked, and it does not ship in the EA build.

---

## ✅ THE VILLAGES/CAMPS QUESTION — RESOLVED (his ruling, 2026-08-07)

His words: *"theres one village and one enemy camp IE that proves both those things work. i have
models for these things they just need to be tightened up."*

**And the code agrees with him.** `plan_demo_world` already stamps ONE village and ONE enemy camp
(plus a temple and jungle ruins) on the 512m demo map — the village site at
`mission_generator.gd:716`, the camp with its own second-attempt placement (`:738-741`). **They
were never outside the demo's shape.** The apparent conflict with the 8/6 ruling was two documents
using one word for two different things:

- **IN SCOPE (MUST SHIP):** the one demo village and one demo camp, tightened up from models that
  already exist. See S25/S26 below.
- **STILL POST-LAUNCH (the 8/6 cut, unchanged):** villages *plural* across the 1280m AO,
  fleshed-out building interiors, CQB geometry, civilian schedules, convoys — the open-patrol
  world's content at scale.

**The tripwire to watch:** "tighten up" is the scope. The moment the village work becomes
interiors, new buildings, or a second village, it has crossed back into the post-launch pile.

---

## WHAT CHANGED SINCE LAST NIGHT'S AUDIT (all verified 8/7)

**Closed:**
- **M7 enemy dressing — DONE.** Enemies now dress; no more 45 identical men in the assault
  (`enemy_base.gd:399/423/428`, observed running in a boot).
- **M13 radio handset — CLOSED** (your note: radio is done and works with the player).
- **M12 the WW2-rifle scare — NOT REAL.** There is no SKS in the game, no Kar98k asset on disk,
  and the CAR-15 is unreachable. The screenshot risk that topped last night's list does not exist.
- **A boot-blocker was found and fixed** (missing script-class cache entry for `vc_nva_dresser.gd`).
- **Huey backwards-running: both bugs fixed** same day (commit `a8ef6922`), awaiting your playtest.
- **Destroyed-building swap now ships** — huts no longer vanish when killed; they swap to ruin
  meshes (`destructible.gd`, `RUIN_FOR`).

**New problems found on 8/7 (these are now on the MUST SHIP list below):**
- **RPD and RPG-2 have no fire or reload animations.** Both guns are on the armorer's rack and
  load fine — their GLBs are stale July-11 exports holding only `rifle_idle`, so nothing errors,
  the guns just don't animate. This is the sneakiest kind of defect: silent and player-facing.
- **M72 LAW and RPG-7 viewmodels were never exported at all.** The LAW is reachable from the rack.
- **The v3 Huey has never been exported.** The game still flies the July-11 model. The work is
  done in Blender and stranded there (`huey_v3.blend`, `huey_v3_transport.blend`).
- **The aid station reads broken:** `us_surgeon` draws as TWO overlapping men, his mask is
  untextured white, and the medic's red-cross brassard is white.
- **Suite still has no completed full run** — the last two attempts were killed mid-flight.

---

# 1 · MUST SHIP

Only what the game needs to function, feel coherent, and not embarrass itself on release day.
Effort scale: **Small** ≤ half a day · **Medium** 1–3 days · **Large** 4+ days.
"Code" items cost you **zero art-days** — that split drives the whole plan.

### Tier 1 — game-breaking and data-loss (all code, all cheap)

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| S1 | **One uninterrupted full suite run.** No completed run exists post-fix; the last like-for-like sample improved (31→39 pass over the same 50) but the total is unknown. | Every other "still green" claim is guesswork without it. | **Critical** | Small | nothing — **do first** |
| S2 | **Atomic saves.** `save_game` writes straight into the live slot with no temp file, no rename, no backup, and autosave rewrites slot 8 every 30 seconds (`save_manager.gd:99-109`, `:20-22`). A crash mid-write destroys the save. | Lost saves are the single most review-damaging bug an EA game can ship. This exact bug class already bit Viper. | **Critical** | Small (~30 lines) | none |
| S3 | **Reject saves from a newer game version** (`save_manager.gd`, no upper version bound). | Player updates, rolls back, loads — silent corrupted state you can never fix after launch. | High | Small | none |
| S4 | **Demo save-dir leak on abnormal exit.** The demo repoints the campaign save path and restores it on clean exit; its own comment says one session already wrote into real slots (`demo_game.gd:82-96`, `:119-124`). Verify the taskbar-kill path. | A menu action corrupting the player's campaign. | High | Small | S2 |
| S5 | **Performance: get a number, then set a floor.** THE WALK, ONE DIG, THE BARRAGE have never produced a recorded result (`test_results/` holds no perf artefact). Your words: "its def laggy with everything going on." | A game that stutters during its own climax gets refunded. Also gates the balance pass. | **Critical** | Medium | S1 |

### Tier 2 — spawning and visual bugs (your stated #1 problem)

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| S6 | **Spawn-under-world, closed with your eyes on it.** Three stacked patches live in code (`game_world.gd:404-445`, `game_flow.gd:137-205`); still on your list. | It's the first thing the player sees. | **Critical** | Medium | S1 |
| S7 | **The mounted MG fires nothing.** Your words: "it doesn't produce any bullets or fire from the tip." `mg_emplacement.gd` has no firing code; strong hypothesis is the 32.9m hip offset in `m60.tres` makes mounted rounds spawn ~33m downrange. | Bunker MGs are core to the defence fantasy — the whole EA product. | High | Medium | none |
| S8 | **Cover-seek reads broken** — men take cover 10m short of the wall, then creep to it. | The AI is Pillar 1 and this makes it look stupid at the exact moment it should look smart. | High | Medium | S1 |
| S9 | **Legs clip through trousers during movement.** | Visible on every man, every frame. Diagnose first — it's a skinning fix, not a texture one. | Medium | Small–Medium | none |
| S10 | **Aid station fixes:** surgeon draws as two men (gib-hide fault on `apron_front`), surgeon mask and medic brassard untextured white. | The aid station is the demo's day half, and a medic without a red cross is missing his one marking. | Medium | Small (~half an art-day + minutes of palette) | none |

### Tier 3 — required assets and integration

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| S11 | **THE FIREBASE — your critical path, your words: "a lot of the game hinges on me finishing the firebase."** The checklist is `FIREBASE_EXPORT_NEED_TO_DO.md`: medical anims → artillery placement → mortar anims (in progress) → HQ + anims → 3 hooches incl. the dug bunker → bunker entry/hangout anims → shoot-out-of-slits. | This is the one asset the entire EA product stands on. | **Critical** | Large (your Blender days — the bulk of your remaining art budget) | none |
| S12 | **After the final firebase export: re-run `tools/gen_firebase_v3.py` and verify the destructible contract.** A re-export without the regen breaks all 80 named segments AND blinds SiegeDirector. Verification signal: the boot line `[FSB] N concave shape(s) forced double-sided` should read **0** after the re-export. | If the wire can't be breached, the climax doesn't happen. Silent failure — no error if you skip it. | **Critical** | Small (code/verify) | S11 |
| S13 | **RPD + RPG-2 viewmodel re-exports.** Both reachable, both animation-less. It's a re-export, not modelling: `python tools/export_all_viewmodels.py <gun>` (clips were retargeted 7/28; the GLBs never followed). | A gun on the rack with no fire or reload animation, silently. | High | Small | none |
| S14 | **Decide the LAW and RPG-7: export or pull from the rack.** `m72_law_fp.glb` and `rpg7_fp.glb` were never exported. Pulling the LAW off the EA rack costs zero art-days and nothing errors (`model_path` empty already filters gracefully). | A player who takes the LAW gets no viewmodel. | High | Small (pull) or ~1 art-day each (export) | your call |
| S15 | **Finish the M79** — you put it at 60%; needs bench alignment and the bigger mould to the FP hands. Reachable (bench + grenadier MOS), so it's real EA work. | The grenadier's whole verb. | High | ~1 art-day | none |
| S16 | **Firebase animation wiring — the banked art.** 12 of 19 chow-hall clips unwired (the whole diner side), the M101 artillery crew (~497 channels, 4-man performance) has ZERO readers behind one guard line (`site_planner.gd:822-823`), `stretcher_load_casualty.glb` has zero readers. All code-only. | 3–5 art-days of finished work sitting invisible. The living firebase IS the day half of the arc. | High | Medium, **all code, zero art-days** | chow-hall diner side blocked on your export; artillery is not blocked |
| S17 | **Huey v3: export both variants, then the variant switch.** Order matters: fix the seat sockets/180° flip BEFORE export (the armed landmine — the moment real `seat_*` empties land, every occupant inverts), then export gunship + transport, then code the switch (`huey.tscn` hardcodes one GLB today). | The Huey is the demo's bookends (insert + gunships). | High | ~1 art-day (export) + Small (code) | socket fix first |
| S18 | **Pilot gib contract** — `us_pilot_white`/`_black` missing all gib donors and caps; a hit that would dismember anyone else does nothing. Assembly via the `psx-npc-pipeline` skill, not new modelling. | Inconsistent gore in a game whose lethality is the identity. | Medium | ~half art-day | none |
| S25 | **Tighten the demo village** (his ruling 8/7: models exist, they need tightening — not interiors, not new buildings). The village is stamped ~185m off the gate flank (`mission_generator.gd:710-716`) and the player walks to it in the exploration window. | It's one of the two authored destinations of the demo's day half; rough models there read as rough game. | High | 1–2 art-days (tightening only) | none |
| S26 | **Tighten the demo enemy camp** — same ruling, same bar. It holds a live garrison and a sited ambush, so it is where the day's fair contact happens. **His ruling 8/7 night: the VC/NVA mortar crew lives HERE — the crewed pit set piece may only ship as a resident of an EXISTING enemy camp, never as a new standalone site.** The art has a home now; what's missing is one code fix: camps cannot consume work stations at all today (`mission_generator.gd:296` gates on `kind == "village"`; `stamp_vc_camp()` never sets `work_stations`; the camp path also skips the `.001` suffix strip the firebase path does). Fossil law rides along: never export as `mortar_pit.glb` (a stale collision row keyed by that basename activates silently, `collision_table.gd:134`), and shipping the crewed pit means retiring the old `mortar_pit.tscn` convention — three are live today. | The other authored destination; the player fights here, and a mortar crew working the pit is the camp reading as alive. | High | ~1 art-day (tightening) + Small (code: camp station consumption) | none |

### Tier 4 — polish that is not optional

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| S19 | **UI legibility pass — ONE DAY, NOT A WEEK.** Readable HUD, working pause/save feedback, a settings screen, an end card. Not a design system. | Placeholder UI reads as "abandoned" on a store page. | High | Medium (one scoped day) | none |
| S20 | **Launcher + shotgun audio.** Five weapons still fire byte-identical synth renders (m79 · rpg2 · rpg7 · m72_law · shotgun). Source hunt, not modelling. VO barks and ambience turned out to be DONE (audited 8/7 — 162 files, 8 voices). | Explosive weapons sounding fake undercuts the lethality everything is built on. | Medium | Small | none |
| S21 | **Balance the demo arc only** — the 30-minute day, the probe, the 45-man assault, the gunship ending. | It IS the product; it has to land. | High | Medium | S1, S5 |
| S22 | **Steam build hygiene** — clean export boots with no `res://tests` dependency, no debug keys in release. | A dev key in a shipped build is an exploit and a support burden. | High | Small | everything |
| S23 | **Steam store work — unbudgeted and real.** His words, 8/7: the page hasn't been made AT ALL. Store page, capsule art, trailer, age rating questionnaire — all greenfield. (Upside: nothing is publicly promised, which is why the date is free to move.) | You cannot ship on Steam without it, and it eats days near the end when there is no buffer left. | High | Medium (budget 2–3 days now) | none |
| S24 | **Open code defects awaiting your ruling:** group_walk followers walking backward (recommend: fix the formation), the hunters count nothing reads, arena nav failures (verify whether they reach the demo path). | Each is a visible-or-invisible call only you can make; they're cheap once ruled. | Medium | Small each | your rulings |

---

# 2 · NICE TO HAVE

Real improvements. **None of them ship the game. Do not start any until MUST SHIP is empty.**

- `__mg` weapon-family clips — every M60/RPD carrier holds his MG like an M16, both factions.
  Visible, reads wrong, breaks nothing. First candidate to promote IF the MUST list finishes early.
- `stand_to_cover_2/_3` — every ally takes cover identically (the code already rotates three
  variants; two clips just don't exist in the library).
- M26 grenade arms alignment + the five equipment items with no ADS pose (bandage, flashlight,
  handset, knife, m26 — bench work, values can't be guessed).
- One burned-out version per building (today one generic `burned_hut` stands in for all eight
  houses — zero code work when they land).
- ZPU #2 NVA gunner · officer rank flair · medic satchel · extra headgear variants.
- Gore stump painting · more ambience beds · your radio-broadcast edits.
- Bunker firing slits — **TRAP: looks like art, hides a feature.** The slit alone buys geometry;
  an occupiable AI-aware bunker is a separate code task nothing wires today.
- Texture optimisation — **only if S5's numbers prove textures are the bottleneck.**
- The four 90° pivot clips, `cover_reposition`, sneaking variants.
- C-47 Spooky side guns · ordnance actually mounting on the F-4.

---

# 3 · POST-LAUNCH

Everything here is either your own standing ruling or a feature wearing a task's clothes.
**Do not spend an hour on any of it before 9/6.**

- **Villages AT SCALE: multiple villages, fleshed-out buildings, interiors, CQB geometry,
  animation loops** (8/6 ruling — the ONE demo village is in scope as S25; everything past
  "tightened" is here)
- **Enemy camps at scale** (same — the one demo camp is S26; more camps are post-launch)
- **The 1280m open-patrol AO as the shipped product** · civilian village schedules · convoys · roads
- **Zombie mode** — parked, kept, not shipped, per your 8/7 ruling. The 12 missing `zed_*` GLB
  exports are post-launch work for when the mode resumes. `test_fossils` and `test_import_refs`
  stay red on it honestly; that is the accepted cost.
- **Tunnel exploring** — frozen ("it eats a year") · **POW loop** — frozen · **helicopter gunship
  rides / driveable vehicles** — frozen
- CAR-15 (already unreachable in code) · US torso/arm variety (your own deferral)
- Hearts & Minds / village allegiance (zero code exists) · enemy defensive zones (your 8/5 ruling)
- The migration decree's P2–P7 systems phases · the arena rebuild · segmented trees
- The UI/UX research week · major UI redesign · new weapons · new enemy archetypes
- **Shot-down aircraft + pilot recovery** (his ask, 8/7 night — AA fire downs a plane or Huey,
  player patrols out to recover the pilot). **Ruled post-launch, but near the TOP of the
  post-launch list** — it's the open-patrol world's story engine and a strong first roadmap
  update. Banked already: pilot models (gib/bind fixes are S18 + known list) · aircraft fly in
  the demo rotation · ZPU guns exist (#2 gunner on the art list) · fire/smoke is Godot-side VFX.
  Missing, and all of it systems: crash sequence, sane wreck placement, one crashed airframe
  model, survivor AI, the recovery objective loop, enemies converging on the smoke. Same class
  as the frozen POW loop.
- **The PSX-style render push** (his ask, 8/7 night — he holds the details). **Queued behind
  Phase 0: no global render-treatment change before the perf numbers (S5) exist.** Done in
  order it may BUY frames (lower render target) and give the store page an identity; done
  before measuring it's an unquantifiable change to an unmeasured system. Take his details any
  time; act after S5.

---

# 4 · THE PRODUCTION QUEUE

Ordered: game-breaking → progression → spawning/visual → missing assets → integration → polish → balance.
Code phases and your art run IN PARALLEL — the plan never has code work waiting on Blender or vice versa.

**Phase 0 — know where you stand (1 day, code).**
S1 full suite run → S5 perf numbers (THE WALK · ONE DIG · THE BARRAGE).
*Gate: if the suite or the perf floor is bad, fixing that outranks everything below.*

**Phase 1 — stop the bleeding (2–3 days, code).**
S2 atomic saves → S3 version rejection → S4 demo save leak → S22 build hygiene.

**Phase 2 — the bugs players see first (4–6 days, code + small art).**
S6 spawn-under-world → S7 mounted MG → S8 cover-seek → S9 trousers → S10 aid station → S24 rulings.

**Phase 3 — YOUR ART CRITICAL PATH (runs in parallel with Phases 0–2, your Blender days).**
S11 firebase checklist → S12 regen + contract verify → S25 village tighten → S26 camp tighten →
S15 M79 → S17 Huey sockets-then-export → S13 RPD/RPG-2 re-exports (minutes each) →
S18 pilot gibs → S14 LAW/RPG-7 decision.
*The firebase still comes first — your own words, "a lot of the game hinges on me finishing the
firebase." The village and camp are the next stops after it, not detours during it.*

**Phase 4 — wire the banked art (2–3 days, code, unblocks as exports land).**
S16 artillery crew (not blocked — start any time) → chow-hall diner side → Huey variant switch.

**Phase 5 — make it feel finished (4–6 days).**
S19 UI day → S20 launcher audio → S21 balance the arc.

**Phase 6 — ship (3–5 days).**
S23 store page/capsule/trailer → full playthrough ×3 on the Intel UHD floor → build → EA.

**Total: roughly 20–29 working days against the ~30 the working target allows.** Tight but
honest — and per his 8/7 ruling the date is his own pacing target, not a promise, so a slip here
moves the date rather than gutting the list. It fits the target ONLY if Phase 0 comes back clean,
the village/camp passes stay at "tighten," and nothing new gets invented.

---

# 5 · TOP 10 NEXT TASKS

1. **Run the full suite, uninterrupted, once.** (S1) Everything else is guesswork without the number.
2. **Atomic saves.** (S2) Thirty lines, Critical, and this bug class already burned you once.
3. **Perf: the three probes, recorded.** (S5) Oldest unmeasured Critical item in the project.
4. **Keep driving the firebase checklist.** (S11) Mortar anims are in progress — it's the critical
   path and it's yours alone.
5. **RPD + RPG-2 re-exports.** (S13) Minutes of work each; kills two silent player-facing defects.
6. **Mounted MG fires nothing.** (S7) Test the 33m-downrange hypothesis first — it may be a one-line fix.
7. **Artillery crew wiring.** (S16) 3–5 art-days of finished performance behind one guard line; not blocked on anything.
8. **Spawn-under-world, verified with your eyes.** (S6)
9. **Rule the LAW/RPG-7 rack question.** (S14) Thirty seconds of decision saves one to two art-days.
10. **Aid station: surgeon double-body + medic brassard.** (S10) Small, visible, in the demo's day half.

---

# 6 · DO NOT WORK ON YET

Tempting, defensible, and all of it costs the date:

- **The UI/UX research week.** EA needs legible, not designed. One scoped day (S19).
- **Texture optimisation.** Not until S5 proves textures are the bottleneck. You flagged the risk
  yourself: downscaling can change how units read, and re-fixing UVs is not a 30-day activity.
- **Villages and camps BEYOND the two in the demo map.** The one village and one camp are S25/S26;
  civilians-at-scale, roads, convoys, and everything plural stays post-launch.
- **`__mg` clips and animation variety.** First promotion candidates AFTER the MUST list is empty — not before.
- **Bunker firing slits.** Art task hiding a feature (needs AI-aware occupancy code nothing wires).
- **The ~64 unplaced structures.** Content for a world that isn't shipping in EA.
- **The migration decree P2–P7.** A systems roadmap; ships none of the EA product.
- **Anything zombie.** Parked by your own ruling. Includes the zed_* GLB re-exports.
- **NVA/VC roster perfectionism.** The roster decree says remaining work is EXPORTING, not
  modelling. Face-atlas and headgear iteration past "reads right at game distance" is polish on
  enemies who exist to be shot at 50m.
- **The Huey gunship/transport visual differentiation question** beyond doors — raised on 8/7,
  unruled. Don't build it unasked.

---

# 7 · CUT CANDIDATES

Ranked by days saved per unit of pain. None of these hurt the shipped game noticeably.

| Cut | Saves | Cost of cutting |
|---|---|---|
| **M72 LAW off the EA rack** (instead of exporting its viewmodel) | ~1 art-day | None — it filters gracefully today; nothing errors. Post-launch weapon. |
| **RPG-7 off the EA rack** (same) | ~1 art-day | Same. The RPG-2 covers the VC rocket fantasy. |
| **`us_artillery_m101.glb`** — 14.6 MB duplicate of the emplacement GLB, identical animation list, zero readers | disk + a maintenance lie | None. |
| **`thompson.glb` + 6 Thompson audio files + grip JSON** — weapon the player cannot reach | ~630 KB + a lie | None. Cut with the CAR-15. |
| **`mission_trigger.gd` + `scripted_sequence.gd`** — 517 lines, zero production callers, serving the loop ADR-029 deleted | maintenance | None. |
| **The four `heli_*` staged vignettes** — zero code readers, flagged suspicious by the asset probe (never re-centered before export) | a red test either way | Your call: delete, or ratify the band. They're invisible today either way. |
| **VO bark RECORDING work** | days | Already moot — the 8/7 audio audit found the barks EXIST (162 files). Nothing to cut; just don't add more. |
| **Gore stump painting** | ~1 day | Only visible on gibs, which are rare at current tuning. |
| **Per-building burned versions** | ~2 art-days | Every ruined hut looks identical. Players see ruins mid-firefight; acceptable for EA. |

**NOT cut, by your standing ruling: anything zombie-related.** It costs nothing to keep parked.

---

# 8 · SCOPE CREEP WARNINGS

What is growing past what ships, right now:

1. **🚩 "Tighten up" is one Blender session away from "flesh out."** The village/camp ruling
   (8/7) is scoped to tightening existing models. The known gravity wells: building interiors
   (0%, a gated epic), a second village, CQB geometry, per-building burned variants. Any of those
   appearing in the village pass means the post-launch world is sneaking into the release again.
2. **🚩 NVA/VC roster depth.** 12+12 symmetric roster, 7 helmet variants, face-atlas sex/age
   classification, scrim texture debates. The decree itself says the remaining work is EXPORTING.
   Every additional variant pass is post-launch polish spending EA days.
3. **🚩 The mortar animation retiming loop.** Approved, then re-opened on pacing, then a stutter
   re-bake queued. Third pass on one background loop. It's your call and your eye — but at some
   point "reads right at 50m" has to be the bar, and this loop is at pass three.
4. **🚩 Zombie glue in live code.** 46 lines of player glue (give_weapon/refill_ammo) landed
   during a ship push for a parked mode. Kept per your ruling — but it's the pattern to watch:
   parked-mode work leaking into ship-critical files 30 days out.
5. **🚩 Texture optimisation framed as perf work, still with zero measurements.** Same warning as
   last night; still true.
6. **🚩 The UI/UX week.** Same warning as last night; still true. One day.
7. **🚩 The Huey question expanding.** Doors were the ask; "should gunship and transport differ
   visually beyond doors" is already on the table. Answer: not for EA unless you rule otherwise.
8. **🚩 Steam-side work is still unbudgeted.** Not creep — the opposite: real MUST SHIP work
   nobody has written down. It's S23 now. Budget it before it budgets itself out of the buffer.

---

# 9 · WHAT THIS AUDIT DID NOT DO

- No playtest — feel, fun, and difficulty are yours. **The demo playthrough remains the standing
  session entry gate and has never been discharged** (ADR-015). That is the single most important
  unchecked box in the project.
- No art quality judgement — no mesh or texture was opened.
- The suite total is still unknown (S1 exists precisely because of that).
- Perf has still never been measured (S5).
