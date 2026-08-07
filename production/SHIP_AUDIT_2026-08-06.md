# SHIP AUDIT — Steam Early Access, target 2026-09-06

**Role: scope control.** The goal of this document is to make the remaining workload SMALLER.
Every claim is tied to a file, a doc line, or your own words in the tracking docs.

---

## ✅ §0 RESOLVED — HIS RULING, 2026-08-06

> **EARLY ACCESS = THE DEMO'S SHAPE.** One firebase, one day, 30 real minutes:
> dawn → the day out → dusk → night stand-to → probe → assault → gunships.
> `scenes/levels/demo_game.tscn`, 512m, `plan_demo_world`.

**The deciding fact was not art — it was verification.** The demo's shape is the only part of
this game ever playtested to a verdict (8/4, 8/5). **PLAYTEST R4 — the open-patrol loop, the
thing ADR-029 declared *the game* — is named as the standing gate in 30 documents and discharged
in none of them.** `DEMO_SHIP_BACKLOG.md:889` records a phantom patrol that banked 7 kills
without leaving the wire. Shipping an unverified core loop to paying customers was the risk.

**Sacrifice, named (the law binds the Arbiter too):** the ADR-029 open-patrol identity becomes
ROADMAP, not product. The Steam page must say so plainly.

### CUT BY THIS RULING — do not spend an hour on any of it

villages (geometry, fleshed-out buildings, CQB interiors, animation loops) · enemy camps ·
civilian schedules in villages · convoys · the 1280m AO · `plan_patrol_world` as the shipped path ·
**M20 roads — a 512m firebase map has none; CUT, do not even diagnose.**

### BUDGET

**13–19 art-days of ~26 available. ~1 week buffer.** Priced at his stated velocity: **~1 large
animation sequence OR 1–2 models per working day.** Code is Claude's and costs him **zero
art-days** — that split now drives every estimate in this document.

### TWO CONSEQUENCES THAT NEED HIS ATTENTION

1. **The session entry gate is now wrong in two canon docs.** `CLAUDE.md` and
   `OVERSEER_CHARTER.md` both make **PLAYTEST R4 (the open-patrol loop)** the standing gate that
   parks all feature work. Under this ruling the gate must become **the DEMO playthrough**. Fix
   both, or every future session opens on a gate for a product that is not shipping.
2. **Replay value is unruled.** The demo is a **fixed-seed** 30-minute arc with one end card and
   a RESTART button (`demo_game.gd:15, 56, 478`). Paying EA customers generally expect more than
   one 30-minute run. Two cheap levers already exist and need no new systems: **vary `DEMO_SEED`**,
   and the arena's **chained survival waves** (`ai_stress_arena.gd` `SIEGE_STRENGTH 30`,
   `_on_siege_ended` relaunch). **Raised, not built — his call.**

---

## ⚠ REVISION 1 — 2026-08-06 23:10, after he updated `ART_Track_Log.md`

**The first pass priced §0 off `ART_Track_Log.md` §1–8, whose section headers were frozen at
2026-07-11 while the file's mtime read 2026-08-05** (1,300 lines of current wave-log appended
below them). He corrected the doc. Every number below supersedes the first pass.

### What got CHEAPER

| First pass said | Truth as of 2026-08-06 | Effect |
|---|---|---|
| Characters ~55% gap | RTO/PRC-25 **done**, US headgear **done**, grunt spawner **done** (8/4), gore stumps **done**. Open: NVA/VC headgear (in progress today), ZPU gunner. Torso/arm variety **he deferred himself**: *"Later date, update down the line problem."* | **Large cut** |
| **SKS shows a Kar98k** | **There is no SKS in the game.** No `sks.tres` in `data/weapons/`. `vc_rifleman.tres` carries `mosin.tres` — *"Local Force guerrilla with a Mosin-Nagant."* **Zero Kar98k assets on disk.** The line was fully stale. | **Threat deleted** |
| **CAR-15 shows a Thompson** | `car15.tres` exists but is **unreachable** — its only reference outside itself is `ambient_war.gd:40 US_VOICES`, an *audio* list. Not in `armorers_bench.gd` ARMORY, not in `gun_range.gd`, not in `squad_system` MOS map. **The player cannot get one.** His "post-launch" call is already true in code. | **Cut confirmed** |
| Radio handset FP (M13) | *"All of radio is done and works with the player."* | **M13 CLOSED** |
| Audio ~10% | *"Do a full audit of the audio because lots has changed in the good way."* | **Unpriced — needs the audit, but it is not 10%** |
| Firebase interiors | *"about half done"* (was read as part of the 0% CQB epic — it is not; that epic is village/world interiors) | **Cheaper** |
| Tunnels, CAR-15, torso/arm variety | **He explicitly deferred all three post-launch** | **Confirmed cut** |

**M12 RESOLVES TO ONE WEAPON.** Reachability check run: only **M79** is both a stand-in problem
and in the player's hands (`armorers_bench.gd:27` ARMORY + grenadier MOS). He puts it at **60%
done**. The feared ~4 days + 32 animation clips collapses to finishing one gun he is most of the
way through. `m70`, `shotgun`, `m72_law` are also reachable via the bench but are not stand-ins.

### What got MORE EXPENSIVE — three new MUST SHIP items from his own notes

| # | Task | Evidence | Sev | Effort |
|---|---|---|---|---|
| **M19** | **The mounted MG fires nothing.** His words: *"it doesn't produce any bullets or fire from the tip so i cant tell if im shooting anything."* `mg_emplacement.gd` has **no firing code at all** (135 lines: occupancy, arc limits, mount/dismount). `player.gd:1347 man_mg()` snaps the body and clamps the view but **never re-poses the weapon** — and `m60.tres` carries `hip_position = Vector3(11.37, 9.20, -32.92)`, a **32.9 m Z offset** that the FP viewmodel lens cancels. **Strong hypothesis: mounted rounds spawn ~33 m downrange**, which is exactly "no bullets, no fire from the tip." Same failure the 7/28 audit measured on the FP M60 before it was fixed. | Bunkers and the firebase MG are core to the defence fantasy — the whole EA product. | **High** | Medium |
| **M20** | **Roads are invisible.** His words: *"I haven't seen any real roads in the game as of 8/6."* `RoadNetwork` is built (`mission_generator.gd:562`), carves vegetation (`:680`), and is guarded by `tests/test_roads.gd`. **A green test and an invisible feature is the silent-no-op class** — the road net probably exists as data with no surface material. | Lower for the demo's shape (a 512m firebase map may legitimately have no road). **Check whether roads are even in the EA scope before spending a minute on this.** | Medium | Small to diagnose |
| **M21** | **Texture optimisation, and he wants it headless overnight.** *"This all still needs to happen... I need to optimize all the models in the game."* Still gated on M5: measure first. His two open questions are real and I have not answered either: **will downscaling change how textures read on units**, and **why do legs show through trousers during movement** (a skinning/clipping bug, not a texture one — different fix). | Perf is a Critical item; this may or may not be its cause. | Medium | Medium–Large |

### M22 — THE ARTILLERY CREW IS BUILT AND STRANDED (found 23:45, highest leverage on this page)

`fb_emplacement_m101.glb` carries a **complete four-man gun-crew performance, ~497 animation
channels**: `PSXRig_gunner` (123) · `PSXRig_agunner` (124) · `PSXRig_loader` (125) · `PSXRig_ammo`
(125) · `M101Rig` (18, the piece itself) · `MC_shell_load`/`MC_shell_carry` · `MC_casing_1..5` +
`MC_spent_22` (ejecting brass). Plus `station_loader_M101`, `station_loadwait_M101`,
`contact_load_M101`, six `socket_back_*`/`socket_eyes_*` crew positions, and **20 `work_gun` + 4
`work_mortar` markers** in `fsb_main_v3.glb` across 6 `fb_gun_pit_i` instances (~3 stations/gun).

**Readers in `scripts/` `tools/` `tests/`: ZERO.** Only `work_mortar` appears anywhere, and only
in `gen_firebase.py` — the generator, not the game.

**It is off because of one guard.** `site_planner.gd:822-823` refuses to map `gun`/`mortar` to an
occupation: *"20 of them is not a firebase, it is a joke."* That comment is reacting to the 20
`work_gun` markers on the assumption each spawns a mannable M60. It disabled the feature instead
of capping it per pit.

- **He confirmed the clips are good** (authored ~2026-07-30). No QC gate.
- **HIS RULING: the gun is ATMOSPHERE, not linked to player RTO calls.** No fire-mission plumbing, no ammo economy, no danger-close, no `FieldDirector` coupling. An ambient staged performance on the garrison schedule — the chow-hall pattern.

| Sev | Effort | Art-days it costs him | Dependencies |
|---|---|---|---|
| **High** | Small–Medium, **code only** | **ZERO** — 3–5 art-days already banked | none |

**Sweep it raises:** the chow hall and litter team came off the same pipeline. A "staged
performance GLBs vs their readers" pass is cheap and headless and may surface more banked days.
**Folded into the animation audit.**

### Corrections to HIS doc (the pointer law cuts both ways)

- **`ART_Track_Log.md:40` — "a4_skyhawk unwired (modeled, no scene)" is itself stale.** The scene exists (`scenes/vehicles/a4_skyhawk.tscn`), `air_traffic.gd:19` maps it, `FORMATION_SIZES` covers it, and **`demo_game.gd:149` already flies it in the demo's air rotation.** It is wired.
- **`ART_Track_Log.md:66` — "kar98 stand-in texture set (~40MB) dies when the real SKS lands."** There is no Kar98k anywhere in `assets/`. That 40MB is already gone or was never there.
- **Dead weight found:** `assets/weapons/world/thompson.glb` + 6 Thompson audio files + a grip-state JSON, for a weapon the player cannot reach. ~630 KB and a maintenance lie. Cut with the CAR-15.
- **`ART_Track_Log.md:1` still reads "as of audit #3 (2026-07-11)"** over freshly-edited content. **Re-date it**, or the next reader repeats my mistake.

### Re-priced verdict on §0

**The recommendation is unchanged, but the gap narrowed.** Ship the demo's shape. Characters and
weapons are much closer to done than the stale log implied, and he has personally deferred
tunnels, CAR-15 and torso/arm variety. What still does **not** fit a month is **villages and
enemy camps finished + animated** — that scope is untouched by this revision, and it remains the
single decision that sets the date.

**Still unpriced and still blocking a real estimate:**
1. **The animation audit he asked for** — *"weve made 300+ animations in our library at this point. I want a new audit of whats there and not there."* `NPC_ANIM_GAPS.md` is dated 2026-07-31 against **163 clips**; the library has apparently near-doubled since. **That audit is a good headless overnight job.**
2. **The audio audit** — *"lots has changed in the good way."*
3. **UI** — the only §1–8 section he did not revise. Still total placeholder, still asking for a research week. **Still my §6 "do not do that week" call.**

---

## 0 · THE FINDING THAT MATTERS MORE THAN THE LIST

**The MUST SHIP list as you defined it is not a one-month list. It is a four-to-six-month list.**
Your three headline items — *finished firebase, finished villages, finished enemy camps, all with
animations* — are, by your own notes:

- Firebase: *"I need to spend like a full day making a more detailed firebase"* (`ART_Track_Log.md` §5)
- Villages: *"I should do that too with the villages and make more finished buildings so they can be fleshed out"* (same line)
- UI: *"its all total placeholder right now and worth... a deep dive of a week"* (§6)
- Audio: **~10% complete** (§7) — launchers and shotgun still synth, no VO barks, one ambience bed
- FP weapons: **SKS shows a Kar98k, M79 shows an MP40, CAR-15 shows a Thompson** (§2)
- Building interiors: **0%, "every building is a shell"** (§5)

That is not a criticism of the project — the *code* really is strong, and this audit confirms it.
It is arithmetic. A month does not contain it.

**So the highest-leverage scope decision available to you is not which polish to cut. It is which
GAME to ship.** And you already built the answer.

### THE RECOMMENDATION: ship the DEMO's shape as Early Access

`scenes/levels/demo_game.tscn` is a **30-minute, one-day, one-firebase arc** on a 512m map:
dawn → the day out → dusk return → night stand-to → probe → assault → gunships
(`demo_game.gd:26-69`). It boots the real flow, not a fork (`demo_game.gd:98-101`, ADR-028). It
has a beginning, a climax and an end card. **It is a product.**

The open-patrol 1280m AO — villages, enemy camps, civilian schedules, roads, convoys, the living
world — is **the full game**, and it is the thing that is 45% done.

| | EA = the demo's shape | EA = the open-patrol world |
|---|---|---|
| Firebase | one, the one you're finishing | one, plus villages + camps |
| Villages | **CUT to post-launch** | must be finished + animated |
| Enemy camps | **CUT to post-launch** | must be finished + animated |
| Civilians/schedules | **CUT** (no villages to hold them) | must be finished |
| Content to author | ~0 new | large |
| Realistic ship | **~1 month** | 4–6 months |

**What you would actually be selling:** a hardcore Vietnam firebase-defence sim — one base, one
day, one night assault, permadeath squad, real ballistics, destructible wire. That is a coherent
Early Access pitch, and "more of the province is coming" is *literally what Early Access is for.*

**What is sacrificed** (no free lunches): the open-patrol identity is the thing you've been
building toward since ADR-029, and shipping the demo's shape means EA players do not see it. Your
store page must be honest that the province is the roadmap, not the product. If that trade is
unacceptable, **the honest move is to move the date, not to compress the work** — and the rest of
this document still applies, just over a longer calendar.

Everything below is scoped to **the demo's shape**. Where an item only matters for the wider
world, it is marked **[WORLD]** and lives in POST-LAUNCH.

---

## 1 · MUST SHIP

Ordered by the production queue at §4. Effort is rough: **Small** ≤ ½ day, **Medium** 1–3 days,
**Large** ≥ 4 days.

### Tier 1 — game-breaking / data-loss

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| **M1** | **Atomic saves.** `save_game()` writes straight into the live slot with no temp/rename/`.bak` (`save_manager.gd:99-107`), and autosave rewrites slot 8 **every 30 s** (`:20-22`). A crash or power loss mid-write destroys the save. | EA players *will* crash, and lost saves are the single most review-damaging bug a game can ship. Same bug class that already bit you in Viper. | **Critical** | Small | none |
| **M2** | **Reject future-version saves.** `load_game` migrates old saves but applies newer ones as-is; `is_valid()` has no upper version bound (`save_manager.gd:177`, `save_data.gd:43`). | Patch 1.1 → player rolls back → silent partial state. Cheap now, unfixable later. | High | Small | none |
| **M3** | **Demo/real save-dir leak on abnormal exit.** `demo_game.gd:82-96` repoints the campaign path; `_exit_tree:119-124` restores it. Its own comment says a session **already once wrote into the real slots**. Confirm the taskbar-kill path. | Corrupts the player's campaign from a menu action. | High | Small | M1 |
| **M4** | **Establish the test baseline.** Newest suite artefact is `test_results/overnight_suite.log`, **2026-07-17**. Last recorded figure is 101 pass / **18 fail / 14 error** (2026-07-27) and is unverified. | You cannot ship on an unknown. Every other item's "still green" claim is meaningless without it. | **Critical** | Small (to run) / unknown (to fix) | none — **do first** |
| **M5** | **Perf: get a number, then a floor.** No jungle sightline has ever been measured (`PERF_LEDGER.md:968-975`); your own run: *"its def laggy with everything going on."* One crater = a 256m chunk rebuild, ~24,576 `SurfaceTool` calls, synchronous. | A game that stutters during its own climax gets refunded. Intel UHD is your floor. | **Critical** | Medium | M4 |

### Tier 2 — spawning & visual bugs (your #1 stated problem)

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| **M6** | **Spawn-under-world.** Still open on your own list (`CALEB_TODO` §000, "hardened 2026-07-30, still needs your eyes"). Three stacked patches live in code: `surface_y`, `floor_y`, the bunk-marker path (`game_world.gd:404-445`, `game_flow.gd:137-205`). | Spawning inside terrain is the most visible bug a game can open on. It is *the first thing the player sees.* | **Critical** | Medium | M4 |
| **M7** | **Enemies are clones — `EnemyBase` has no dresser call at all.** Allies dress (`ally_base.gd:398`), civilians dress (`civilian.gd:262`), zombies dress (`zombie_wave_director.gd:158`). Enemies do not. All 14 VC/NVA GLBs + face atlases are **already on disk**. | 45 identical men assault your wire in the climax. Highly visible, and the art is already paid for. | **High** | Small | `vc_nva_dresser.gd` exists; needs manifest + randomizer |
| **M8** | **Cover-seek reads broken.** Your observation: *"taking cover a good 10m before they were actually to the building and then they slowly made their way to the wall"* (`ART_Track_Log.md` §3). | The AI is Pillar 1 and this makes it look stupid in the exact moment it should look smart. | High | Medium | M4 |
| **M9** | **Legs clip through trousers during movement** (`ART_Track_Log.md` §8, your note). | Visible on every man, every frame of movement. | Medium | Small–Medium | diagnose first |
| **M10** | **Firebase destructible/ballistic contract verified on the FINAL export.** Naming is the contract; a missed prefix ships silently invulnerable AND bulletproof. Skill: `recon-destructible-export`. | The night assault *is* the game. If the wire cannot be breached the climax does not happen. | **Critical** | Small (verify) | your final firebase export |

### Tier 3 — required assets & integration

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| **M11** | **Final firebase export + regenerate `firebase_v3_destructibles.json`.** 80 exact-name segments; a re-export without re-running `tools/gen_firebase_v3.py` breaks all 80 **and blinds SiegeDirector**, which measures the wire off the same group. | Same as M10 — this is the one asset the whole EA product stands on. | **Critical** | Medium (your Blender day) | none |
| **M12** | **FP weapon stand-ins: SKS→Kar98k, M79→MP40, CAR-15→Thompson.** | **A WW2 German rifle in a Vietnam game is a screenshot that ends you on release day.** Non-negotiable if those weapons are reachable in the demo's shape. **If they are NOT reachable, CUT them from EA instead of building them** — see §7. | **Critical** *(if reachable)* | Medium | check reachability first |
| **M13** | **Radio handset FP** — placeholder phone model; you're mid-wiring the support loop (`player.gd:101-106`, ART §2). | Fire support is RTO-gated; the handset is the verb. | High | Medium | in progress |
| **M14** | **Firebase animations** — chow hall (19 clips, shared library), medical, sleep loop, garrison stations. Mostly BUILT per memory; needs your eye + wiring closed. | The "living firebase" is the whole day half of the arc. | High | Medium | your Blender passes |

### Tier 4 — player-facing polish that is not optional

| # | Task | Why it blocks release | Sev | Effort | Depends on |
|---|---|---|---|---|---|
| **M15** | **UI/UX pass — SCOPED TO ONE DAY, NOT A WEEK.** Your note says all placeholder and asks for a week of research. **For EA you need legibility, not a design system:** readable HUD, working pause/save feedback, a settings screen that states the save tier, an end card. | Placeholder UI reads as "abandoned" on a store page. | High | Medium | — |
| **M16** | **Audio: the two silent gaps.** Launchers (m79/law/rpg2/rpg7) and shotgun are still synth (ART §7). Guns are 8/9 real. | Explosive weapons sounding fake undercuts the lethality the whole game is built on. | Medium | Small | source hunt |
| **M17** | **Balance pass on the demo arc only** — the 30-min arc, the probe at 1395s, the 45-man assault, gunship ending. | It is the entire product; it has to land. | High | Medium | M4, M5 |
| **M18** | **Steam build hygiene** — `export_presets.cfg` exists → `build/RECONgame.exe`. Verify a clean export boots with **no `res://tests` dependency** (`game_flow.gd:718` already degrades correctly), no debug keys ([J]/[H]/[G] are `OS.is_debug_build()`-gated — confirm). | A dev key in a shipped build is a speedrun exploit and a support burden. | High | Small | all |

---

## 2 · NICE TO HAVE

Real improvements. **None of them ship the game.** Do not touch until MUST SHIP is empty.

- Torso/arm variety for US grunts (helmets DONE 2026-08-04 — the clone read is already broken)
- Officer rank flair + medic satchel (queued polish, ART §9)
- The four 90° pivot clips (`turn_90_*`) — needs a one-shot mechanism, *real work, not wiring*
- `cover_reposition`, `crouched_sneaking_left/right`
- Bunker firing slits (researched, not started — recipe in `FIREBASE_BLENDER_HANDOFF.md` §2)
- More ambience beds (night/rain/river); your new radio-broadcast edits
- VO barks (Vietnamese + US) — pipeline ready, content not recorded
- Gore stump painting on `gore_tex`
- Extra headgear variants (half done)
- Texture optimisation / the 85MB faction sheets — **only if M5 proves it is a perf cause**
- The ~64 modeled-but-unplaced structures — **placement work, and mostly Spring1944 rips you already called holders**
- C-47 Spooky side guns
- Ordnance actually mounting on the F-4

---

## 3 · POST-LAUNCH

Everything here is a feature, a redesign, or content at scale. **All of it is already frozen or
parked by your own decrees — this section mostly just confirms that.**

- **[WORLD] Villages: finished buildings, interiors, CQB geometry, animations** — your own "full day each" ask, times N villages
- **[WORLD] Enemy camps: finished + animated**
- **[WORLD] The open-patrol 1280m AO** as the shipping product
- **Tunnel interiors** — GAME_GUIDE §6.0 FROZEN, *"a second game... it eats a year"*
- **POW / capture epic** — FROZEN
- **Driveable / flyable vehicles, helicopter gunship rides** — FROZEN
- **Building interiors / CQB kit** — 0%, gated epic
- **Zombie mode** — 14 files, ~3k lines, reachable from one test scene. **PARKED, correctly**
- **Hearts & Minds / village allegiance (ADR-019)** — **zero code exists.** Confirmed twice
- **Enemy defensive zones** — deferred by your own 8/5 ruling
- **`ai_stress_arena` rebuilt on the shared world path** — architecture hygiene, invisible to players
- **Segmented trees** — council said wait
- **New weapons, new enemy archetypes, major UI redesign, the UI/UX research week**
- **Weapon family animation sets** (mg / launcher / bolt / pistol, 8 clips each) — **unless** M12's reachability check says a launcher is in the player's hands in EA

---

## 4 · THE PRODUCTION QUEUE

**Phase 0 — know where you stand (1 day).** Nothing else is trustworthy until this is done.
> M4 suite baseline → M5 perf numbers (THE WALK · ONE DIG · THE BARRAGE)
> **GATE: if the suite is redder than 101/18/14, fix it before anything else.**

**Phase 1 — stop the bleeding (2–3 days).** All small, all critical.
> M1 atomic saves → M2 version rejection → M3 demo save leak → M18 build hygiene

**Phase 2 — the bugs players see first (4–6 days).**
> M6 spawn-under-world → M7 enemy dressing → M8 cover-seek → M9 trouser clipping

**Phase 3 — the one asset everything stands on (4–6 days, your Blender time).**
> M11 final firebase export → M10 verify the contract on it → M14 firebase animations closed

**Phase 4 — the weapons decision (0–4 days, depending on §7).**
> M12 reachability check → **cut or build** → M13 handset

**Phase 5 — make it feel finished (4–6 days).**
> M15 UI (one day, scoped) → M16 launcher audio → M17 balance the arc

**Phase 6 — ship (2–3 days).**
> Full playthrough × 3 on the Intel UHD floor → store page → build → EA.

**Total: roughly 18–25 working days**, which fits a month **only if Phase 0 comes back clean and
the weapons decision goes to CUT.** Any slip in the suite or the perf floor eats the buffer.

---

## 5 · TOP 10 NEXT TASKS

1. **Run the suite. Get the number.** (M4) — everything downstream is guesswork without it.
2. **Atomic saves + `.bak` self-heal.** (M1) — small, critical, and you've been burned by this exact bug before.
3. **Measure perf: THE WALK, ONE DIG, THE BARRAGE.** (M5) — three probes, never run, and one of them likely explains "def laggy."
4. **Decide the EA scope question in §0.** Demo's shape, or move the date. Every estimate here hangs off it.
5. **Spawn-under-world, closed with your eyes on it.** (M6)
6. **Enemy dressing — manifest + randomizer + the EnemyBase call.** (M7) — small, and the art is already on disk.
7. **Final firebase export + regenerate the destructibles manifest.** (M11)
8. **Verify the ballistic/destructible contract on that export** — three `[FSB]` boot lines. (M10)
9. **FP weapon reachability check.** (M12) — 30 minutes of grepping decides whether you owe 4 days of Blender or zero.
10. **Future-version save rejection.** (M2) — small, and it stops a bug you cannot fix after launch.

---

## 6 · DO NOT WORK ON YET

Tempting, defensible, and all of it costs you the date:

- **The UI/UX research week.** You want it and it will make the game better. It is a week. EA needs *legible*, not *designed*. (M15 is one day.)
- **Texture optimisation / the 85MB sheets.** Do not touch until M5 *proves* textures are the bottleneck. You already flagged the risk yourself: *"won't this change the way textures appear on units?"* — yes, it can, and re-fixing UVs is not a month-of-runway activity.
- **The ~64 unplaced structures.** Mostly Spring1944 holders by your own note. Placing them is content for a world you are not shipping.
- **Weapon family animation sets** (mg/launcher/bolt/pistol — 32 clips). Gated on M12.
- **The `ai_stress_arena` rebuild.** Architecture hygiene. Zero players will ever see it.
- **Bunker firing slits.** Researched, not started, and the slit alone gets you geometry — an occupiable AI-aware bunker is a *separate code task nothing wires today.* That is a trap: it looks like art and it is a feature.
- **Villages, camps, civilians, roads, convoys.** [WORLD] — post-launch under the §0 recommendation.
- **`ai_stress_arena` survival waves, zombie mode, ADR-019.** Parked, correctly.
- **Segmented trees.** Council said wait for logs-as-cover; logs-as-cover is post-launch.

---

## 7 · CUT CANDIDATES

Ranked by days saved per unit of pain.

| Cut | Saves | Cost of cutting |
|---|---|---|
| **The open-patrol world as the EA product** (§0) | **months** | The ADR-029 identity is roadmap, not product. Biggest lever on this page. |
| **SKS / M79 / CAR-15 FP models** — *if* those weapons are not reachable in the demo's shape | ~4 days + 32 anim clips | None, **if** unreachable. **Check first (M12).** If a player can pick up an SKS off a dead VC and see a Kar98k, this cut is impossible. |
| **Zombie mode** — disable the scene from the EA build | 0 days now, avoids "why is this here" | None. It is already unreachable from the game path. Just don't ship the scene. |
| **`mission_trigger.gd` + `scripted_sequence.gd`** — 517 lines, zero production callers | maintenance | None. ADR-029 deleted the loop they served. |
| **VO barks** | days of recording | Ambience suffers; the game is already carried by diegetic gunfire and radio. |
| **Gore stump painting** | ~1 day | Only visible on gibs, which you note are rare at current damage tuning. |
| **The 4 pivot clips + cover_reposition + sneaking** | ~2 days | Real motion polish; nobody refunds over it. |
| **Ordnance mounting on the F-4 / C-47 side guns** | ~2 days | Aircraft are set dressing at range. |
| **Hearts & Minds (ADR-019)** — formally cut, don't just leave it phantom | — | **Amend `GAME_GUIDE.md:279` so THE SLICE stops naming a system with zero code.** Cutting it costs nothing; leaving it phantom costs the next reader a day. |

---

## 8 · SCOPE CREEP WARNINGS

Things in the project **right now** that are growing past what ships:

1. **🚩 The MUST SHIP list you wrote is the scope creep.** "Finished villages + finished enemy camps + all animations" is the full game wearing a release label. This is the one to catch.
2. **🚩 Zombie mode.** 14 files, ~3k lines, a lot process, a wave director, an economy, a mystery box, wall-buys, power-ups — built *during* a ship push, for a mode that is parked. It is the clearest scope creep in the repo. **It is also fine, because it's quarantined** — just do not finish it, and do not ship the scene.
3. **🚩 "I need to spend a full day making a more detailed firebase... and the villages too."** The firebase day is MUST SHIP. The villages day is the same sentence and it is post-launch. Watch that they don't travel together.
4. **🚩 The UI/UX "deep dive of a week."** A week of research one month out is not a plan, it is a deferral. One scoped day.
5. **🚩 Texture optimisation framed as perf work with no measurement.** Classic: a big, satisfying, risky job standing in for the measurement that would tell you whether to do it.
6. **🚩 Bunker firing slits.** Reads as a small Blender pass; the useful version needs an occupiable AI-aware bunker position that **nothing wires today**. Art task hiding a feature.
7. **🚩 The 8/5 migration decree's seven rulings + P0–P7 phase plan.** It is good work and it is a *systems* roadmap (fell registry, shooter-anchored bullet promotion, destructible world, consequence hooks, defensive zones, segmented trees). Almost none of it ships the EA product. **Park P2–P7 explicitly** or it will absorb the month.
8. **🚩 Weapon family animation sets (32 clips).** Queued as art priority #1–#4 in `ART_Track_Log.md` §3. Gated entirely on M12's reachability check — do not start them before it.

---

## 9 · WHAT I DID NOT ASSESS

- **No playtest.** Feel, fun and difficulty are yours; I read code and docs.
- **No art quality judgement.** I did not open a single mesh or texture.
- **The suite was not run** — M4 exists precisely because that number is unknown.
- **No Steam-side work assessed** (store page, capsule art, trailer, age rating, wishlist runway). **That is real work and it is not on this list.** A month to EA includes marketing days you have not budgeted.
