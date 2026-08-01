# EVIDENCE — Scout Reports (condensed), 2026-07-31

Four read-only scouts swept the repo. Full detail below is the distillation; architects may spot-check code but should not re-derive this.

## Scout 1 — Demo slice (static code audit)

**WORKING (verified by reading):**
- Demo boot fork is single-path per ADR-028: `game_flow.gd:545` demo_mode static, 512m map, `plan_demo_world` (`mission_generator.gd:665-741`), same build path after.
- All four 7/30-audit P0s FIXED: night clock (110× ratio, dawn ≈06:20), scored assault (`run_peak` fix), demo save dir, campaign repoint+reload.
- Air spectacle wired: all 5 aircraft scenes exist, every ext_resource resolves, all ordnance enums real.
- Huey landings: `HeliLift.attach` real; `fb_helipad` nodes verified inside fsb_main_v3.glb.
- Overrun chain complete: OVERRUN_MEN 3 → "THEY'RE INSIDE THE WIRE" + siren; 4-squad assault real (`siege_director.gd:285`); satchel/dump breach wired.
- Zero TODO/FIXME/HACK in any .gd repo-wide.

**BROKEN/MISSING:**
1. **No shipped demo build.** No demo export preset, no demo.bat; demo reachable only by F6 in editor. (DEMO_PLAN item 7 open.)
2. **World built TWICE per demo boot** — `_ready` runs `start_default_operation()` (seed 47225) before demo reseeds; one thrown-away terrain gen per boot.
3. **3 of 4 exclude-flags inert.** `EXCLUDE_DEBRIEF` does nothing — player death mid-assault tears the world down and freezes the demo arc (`demo_game.gd:244-245` returns forever).
4. **End card is opaque, undismissable, over a running game** — no pause, mouse stays captured, Esc builds PauseMenu UNDER the card.
5. **NEW: SimClock dedup key swallows scheduled air.** `sim_clock.gd:92` keys by hour+kind; all air books under `&"air_traffic"` → only 1 event/hour fires. TRANSITS_PER_HOUR=3 is effectively 1; scheduled Huey lz_cycles suppressed. Undocumented until now.
6. **Ambient scheduled air dies at real t≈213s** (day rollover at 110×; SimClock requires same sim_day). Masked partly by demo's own 42s cadence.
7. `reinforce()` re-emits siege_began → double "STAND TO" + siren at t=60s.
8. `_physics_process` delta uncapped on the arc; AirTraffic re-resolved every frame.
9. End card fires at t≈500s (siege MAX_DURATION 480 counted from probe) — 80s AFTER dawn card at 420s; overlap between "dawn" and live siege.

**UNCERTAIN:** HeliLift never run in-game; BOARD_CLIPS empty (embark teleports); siege ring 190/235m vs 256m half-width — diagonal margins thin; LIVE_CAP 50 vs ADR-035's 18; demo scene never perf-measured.

**Doc drift:** DEMO_PLAYTEST_SCRIPT cites a 720s arc and "not built yet" four-squads — both wrong vs code; DEMO_PERF_PLAN cites wrong lines/numbers; DEMO_PLAN item 5 (release trigger) is superseded by the arc clock — the arc IS the release-safe trigger, but C4's debug-gate concern still holds for the [J] key path only.

## Scout 2 — Full game systems

**Deep and real:** boot→patrol loop→wire gate→AAR banking; pencil marks persisted; siege director full ADR-035 spec; enemy AI 2862-line coordinator w/ hot-set budget, hunt net; casualty/medical complete both player and squad; save/load with slots+migration; audio manager 24-voice pool; VFX decal caps; destruction on blast bus; one world-build path.

**Top gaps (promise vs reality):**
1. **No sleep/time-skip verb** — night siege gated behind ~10 real minutes of waiting or debug [O] key. Biggest hole under the siege.
2. ADR-019 hearts & minds: zero `allegiance` hits. Named slice pillar, absent.
3. Rank gates nothing (ADR-018 "rank gates AUTHORITY" unbuilt).
4. **Two route systems, one dead** — `set_player_route` chain is tests-only; live `route_order` is WIPED by `_bank_patrol` (`field_director.gd:1581`) contradicting its own comment.
5. Siege has no stakes (ADR-036 BLOCKED; loss costs one fire-support dock).
6. Canon index broken: ADR-024/027 don't exist but are indexed; ADR-035 numbered TWICE; two competing pillar lists (GAME_GUIDE §1 vs BIBLE 7/19 merge); ADR-029 is what code does but still DRAFT.
7. SeatSystem "zero callers" claim STALE — HeliLift uses it, but builds an ORPHAN SeatSystem instead of the authored huey.tscn node, on the strength of a false comment.
8. `WorldBuilder` still zero hits (ADR-028 Phase 3 unbuilt); arena separate.
9. Zero-caller classes: WorkingPointResolver, PondDetector; test-only: MissionTrigger, ScriptedSequence.
10. 153 dirty files vs HEAD (but origin/master is level — pushes are current; dirt is working tree).

## Scout 3 — Art/asset (the "art blocks" question)

**Headline: the art tree is far healthier than the tracking docs say.** Missing res:// refs: 2 total (one is a test fixture; one real: claymore_viewmodel.tscn). Animation coverage CLEAN — all 163 clips, zero broken play() requests. gen_weapon_audio.py has a hard guard; "real guns overwritten" fear closed.

**DEMO-blocking, ranked (his hands = Blender):**
- D1 wire ring is ONE merged mesh → assault funnels at the gate. Generator split + re-export + nav re-bake hook (exists). ~1 day. THE centrepiece dependency.
- D2 medical_complex not exported into fsb_main_v3.glb → aid-station patient on bare floor; blocks 4 litter clips. Hours.
- D3 **21 interior props ARE exported but nothing places them** — `place_firebase_main` never calls `_furnish_interior`, and INTERIOR_PROPS maps to village assets. Half-day of CODE. Best payoff-per-hour on the list.
- D4 rpd/ithaca/rpg2 are stale 7/11 exports: 1 clip, no sight markers → bench [V] cannot work. Hours (manifest ready). Mosin is FIXED.
- D5 five guns on placeholder ADS (ak47, m1911, mosin, rpd, rpg2) — matters now that WorldWeapon pickup ships (player can take a VC AK). Minutes each after D4.
- D6 M79 is 15 MINUTES from being a whole weapon (GLB complete, needs .tscn + model_path). LAW/RPG-7 GLBs don't exist (~1 day each).
- D7 __mg/__launcher/__bolt families empty → RPD gunner and RPG man hold weapons like rifles in the siege the player stares at. ~2-3h posing per family; pipeline built.
- D8 bunkers have no firing slits; no occupiable bunker position exists (code too). ~1 day + code.
- D9 claymore FP viewmodel path is null — plant animation shows nothing. 2-3h.
- D10 ArmorersBench is a BoxMesh AND has zero references — the ADR-032 weapon rack is unreachable in-game. Triage call.
- D11 Spooky has no visible guns. 2-4h.
- D12 audio: all 4 launchers + shotgun procedural synth (RPG is the signature siege sound); NPC footsteps placeholder; no VO barks (full-game arguably).

**Full-game only:** interiors/CQB kit 0% (weeks); UI total placeholder by decree; ZPU wired to nothing; ordnance never hangs on aircraft; Huey interior/door-gunner/sockets (his, 1-2 days); NVA flair pass; 233MB duplicate faction sheets (perf-irrelevant — draw-call bound); gore stumps; tunnel kit 0%.

**Docs lying:** ART_Track_Log SKS/M79/CAR-15 placeholder entry is DEAD (weapons retired); "MuzzlePoint zero viewmodels" false (all 17 have one); firebase_interior_wiring "NOT exported" false; "prone unwired/crawl zero clips" both closed; DEMO_SHIP_BACKLOG itself found 7 of its items already shipped.

**Non-art cap:** FSB_GARRISON_MAX_MEN=24, curated posts spend 17 → only SEVEN men animate 198 work markers. Ceiling raise is a frame-cost decision nobody has taken; it decides busy-base vs dead-base in the demo's first minute.

## Scout 4 — Production state

- **Critical path is the 45-min DEMO_PLAYTEST_SCRIPT pass (6 sections/30 rows) — his eyes, ADR-015.** Nearly every backlog item is BUILT AND UNVERIFIED.
- Genuinely open code: C4 release-safe trigger concern (arc clock exists; [J] debug-gated), demo export preset (unconfirmed anywhere), 512m siege-geometry override landmine (bodies off heightmap, mortar 700m out — DEMO_PERF_PLAN §0.4), D1 road remainder, M60 bench (hip_position 0,0,0 → rounds spawn 50m out; MUST bench if M60 in demo loadout).
- Test suite: 137 scenes, KnownRed EMPTY, but **baseline is 101/18/14 from 7/27, unverified across ~40 commits since**. Only stored run log is Jul 17.
- Git: 654 commits, ~20/day burst 7/30-7/31, origin level. 152 uncommitted files, ~85% art (his). Standing law: stage by path, never broad add; weapon .tres are his live edits, do not sweep.
- Awaiting rulings: headshot fatal-zones caller (opened 7/27, still open — `Hitzone.is_fatal_zone()` has zero callers), aid-station populator, salute/signal triggers, FMV direction, temple statues, blood look, squad keybinds, trademark screen.
- FP viewmodel defects on his bench: AK 132f reload under 78f clip, FROZEN HANDS (hand.R 0.00mm/frame across M16/AK/M14 reloads), M16 floaters, PPSh bolt unsplit.
- Doc-pointer debt at ceiling: 95 broken pointers (ceiling 97), 12 unpointered assertions (AT ceiling 12 — next one fails the build).
