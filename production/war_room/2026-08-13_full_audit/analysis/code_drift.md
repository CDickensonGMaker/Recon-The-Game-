# CODE-DRIFT AUDIT — 2026-08-13 full-project audit

**Auditor:** code-drift architect · **AUDIT ONLY, nothing changed** · Working tree at `a5d077a7` (nav-truth wave), plus 8 uncommitted files.

**Method:** diff-scoped symbol scan of every `const`/`signal`/`func`/`@export` ADDED to `scripts/` since the 08-04 audit boundary (`de360564`) — 767 new symbols, each reference-counted across scripts/scenes/tests/tools/data/addons (comment-aware); pointer verification of every `file:line` claim in `scripts/levels/demo_game.gd`, CLAUDE.md and the two commits landed today (`f6b323a6` napalm scale, `a5d077a7` nav-truth); ADR-016 vs every `data/weapons/*.tres`; `.gitignore` reconciled against `git ls-files -i -c` and the untracked set. Zombie paths (`scripts/zombies/`, `zed_*`, `zombie_*`, `vc_zombies.gd`) excluded per the Summoner's standing ruling; the 27 grandfathered baseline entries not re-reported.

**Verdict: 0 SHIP-BLOCKER · 3 DEFECT · 5 DRIFT · 6 NOTE.** The two commits landed today are the cleanest audited this cycle — every numeric claim in both messages verified against code (see the clean register at the bottom).

---

## DEFECTS

### D1 — ~518 MB of tracked `*_PRE_*.blend` working backups, under a rule that says "never tracked"
`.gitignore:104-106` reads *"Working backups - never tracked (no-blend-backups rule, storage-bloat law)"* / `*_PRE_*.blend`. The rule landed 2026-08-05 in a commit whose message says *".gitignore now stops the class"* — but an ignore rule does not untrack, and that pass `git rm --cached`-ed only ONE PRE blend (PRE_M60FIX) and four `.bak`. **Ten PRE blends remain tracked today** (`git ls-files -i -c --exclude-standard`):
- `assets/us/characters/us_base_v3_PRE_HELMET.blend` (87 MB), `_PRE_RAISE` (75), `_PRE_MEDICFIX` (66), `_PRE_PILOTRIG` (66), `_PRE_MATFIX` (66)
- `assets/us/characters/us_v3_soldier_lineup_PRE_RIGFIX.blend` (48), `_PRE_RAISE` (48), `_PRE_HELMET` (48)
- `assets/us/characters/helmet_variants_PRE_HELMET.blend` (13), `assets/player/arms/fp_arms_rifle_PRE_IDLEPASS.blend` (10)

Riders in the same class: `production/cinematics/cutscene_01_operation_briefing/_assembly_proof.blend` tracked despite the owner's cinematics-off-GitHub decree (`.gitignore:88`), and `test_results/overnight_suite.log` tracked inside ignored `test_results/` (`.gitignore:107`). This is the 1.66 GB precedent inverted: last time an ignore rule silently swallowed what should be tracked; this time a rule asserts untracked-ness the tree contradicts, and every clone/push carries half a gigabyte the storage-bloat law says must not exist. *Fix shape (not applied): `git rm --cached` the twelve, one commit; files stay on disk.*

### D2 — tracked GLB with an untracked texture: `fb_office_chair`
`assets/us/props/interior/fb_office_chair.glb` was committed 2026-08-12 ("Eleven new hooches…"), and it references its canvas texture internally (`fb_canvas` string present in the binary) — but `assets/us/props/interior/fb_office_chair_fb_canvas.png` is **untracked on disk**. Since 08-12 a fresh clone imports the chair textureless. This is the `export-ate-the-medical-complex` / single-disk-risk class: the texture exists only on this machine. Seven other uncommitted files ride with it (working tree `??` set): `door_screen_creak/slap.wav.import`, `cigarette.png.import`, `fb_office_chair.glb.import`, the canvas png + its `.import`, and `tools/probe_mound_in_walk.gd/.tscn` — an uncommitted probe from the nav sessions (its sibling `probe_bunker_entry` shipped in `a5d077a7`; this one is stranded). Likely today's live session mid-flight — flag, commit before session end per the completion law.

### D3 — the fossil probe is blind to `static func`, and the ADR-023 machine therefore has a hole
`tests/test_fossils.gd:245` — `re_func.compile("^\\s*func\\s+…")` — cannot match a line beginning `static func`. Every static function in the repo is invisible to the probe, so "A NEW fossil FAILS THE BUILD" (CLAUDE.md, FOSSIL LAW) is not true for an entire declaration class. Proof it bites: finding DR3 below passed today's "Fossil probe PASS" (`f6b323a6` commit message). The probe's other two learned rules (comments stripped, baseline not tallied) are intact; this is a third rule it has not learned.

---

## DRIFT

### DR1 — CLAUDE.md:422 sends the session gate to a constant that no longer exists: `END_AT_S`
The standing SESSION ENTRY GATE checklist reads *"gunships on station at `END_AT_S`"*. `END_AT_S` has zero hits in `scripts/` — it was renamed AND re-purposed: the raid's end (`SiegeDirector.siege_ended` → `_on_raid_ended`, `scripts/levels/demo_game.gd:507`) ends the demo per his 2026-08-07 ruling, and the clock is now only `END_BACKSTOP_S = 2700.0` (`demo_game.gd:73`), a failed-resolve backstop, explicitly *"a BACKSTOP, not the pacing"* (`demo_game.gd:69`). CLAUDE.md is injected into every session — its own text calls a stale line here "a DRIFT GENERATOR". The checklist's cited span `demo_game.gd:26-69` has also slid (arc constants now run to `:87`).

### DR2 — GAME_GUIDE.md:418 tunes the arc around `END_AT_S 1800` — stale in name, number and mechanism
*"stretch the arc 30 → 45 min (every beat is tuned around `END_AT_S` 1800)"*. The const is gone (DR1), the value is not 1800 anywhere (backstop 2700), and the beats no longer tune around any end clock — they tune around `SIEGE_AT_S` and resolve on `siege_ended`. GAME_GUIDE.md is the top of the canon hierarchy (ADR-014); anyone pricing the 45-minute stretch from this line prices the wrong system.

### DR3 — new fossil since the 08-04 audit: `CursorSet.use_large` — zero callers repo-wide
`scripts/ui/cursor_set.gd:55` (landed `11c78c6d`, 2026-08-12). The high-DPI cursor rung: declared, self-documented ("Call once at boot if the desktop wants the big rung"), and called by **nothing** — no script, scene, tool, or settings screen (1 reference total = its declaration; string-call forms also checked). Triage: **UNFINISHED** (built ahead of its wiring — there is no settings toggle to hang it on), not superseded. Wire or cut per ADR-023. The rest of `CursorSet` is live (`set_context`/`reset`/`hook_buttons` wired across five UI screens). Sole true fossil out of 767 new symbols — the diff-window fossil rate is otherwise clean.

### DR4 — "THE ONE HP TABLE… decided here and nowhere else" is false for the 80 parapet segments
`scripts/world/destructible.gd:62-64` claims every structure's HP comes from `HP_FOR` — *"only the number is shared, so tuning a kind is one edit and cannot drift."* But the parapet wiring reads per-segment HP from the baked kit JSON: `scripts/world/site_planner.gd:1685` `_wire_parapet_segment(mi, …, int(seg.get("hp", 140)))` and `:1728` (twin pass) — source `firebase_v3_destructibles.json` (`hp: 140` baked by `tools/gen_firebase_v3.py`), fallback a hardcoded 140, **never `HP_FOR`**. Structures do use the table (`site_planner.gd:1856` `Destructible.hp_for`). Today the values agree at 140 by coincidence; edit `HP_FOR["sandbag_wall"]` and the shipped perimeter silently ignores it — a disconnected lever wearing a "one edit" label. Either route parapet HP through `hp_for()` or correct the comment to name the JSON as the parapet's source.

### DR5 — demo_game.gd:52-53 cites `field_director.gd:1240-1245` for the `_granted_day` exploit; truth is ~200 lines away
The NIGHT_RATIO rationale ("re-arms a second siege roll… unlatches the fire-support allotment through `_granted_day`") points at `field_director.gd:1240-1245`, which today holds `_nearest_location_to`. The latch actually lives at `field_director.gd:1159` (declaration) and `:1446-1453` (the one-allotment-per-day gate and its 25-metre-band comment). The claim itself is still TRUE — only the pointer rotted. demo_game.gd was touched 08-12 (`452ed393`) and the pointer rode through uncorrected.

---

## NOTES

- **N1** — CLAUDE.md:320: fossil baseline described as *"`ceiling` 3, `count` 3, as of 2026-07-31… the ratchet has done its job since."* Register is now **27/27** (`tests/fossil_baseline.json:3-4`) after the 2026-08-12 zombie-mode grandfathering. The date banner keeps it lawful under the Pointer Law, but "done its job since" now reads as a live claim and misleads; worth a one-line refresh on next touch.
- **N2** — CLAUDE.md:429: `_bank_patrol` cited at `field_director.gd:1797`; now `:1818` (call site `:1432`). Pointer rot, function intact.
- **N3** — `scripts/missions/siege_director.gd:71`: "…96.1 m (firebase_v3_destructibles.json, **80 segments**)". The JSON does hold 80 and the radii verify (95.6 m centre + half-box = 96.1), but this same commit's headline adopted the stray `fb_sbg_seg_046_001` as the **81st** segment on the blast bus (`a5d077a7`) — the comment's count is now the manifest's, not the runtime's.
- **N4** — `FellableTree` (class deleted 08-07) still named as if known in `scripts/world/tree_break_system.gd:322` ("FellableTree's scripted hinge") and `tests/test_support_fire_bench.gd:70`. Tombstone references to a dead class — the exact camouflage pattern the comment-discipline law names. `probe_fire_parity.gd` itself is clean of it after today's refit.
- **N5** — `scripts/world/site_planner.gd:1638-1640`: *"`firebase_v3_destructibles.json` has been sitting next to the GLB READ BY NOTHING"* — past-state narration sitting three lines above `FSB_DESTRUCTIBLES_JSON`, which reads it. The paragraph as a whole narrates before→after (PR narration, belongs in the commit/ADR); skimmed mid-paragraph it asserts the opposite of the code below it.
- **N6** — `data/weapons/` carries `m60.tres.bak`, `m70.tres.bak`, `shotgun.tres.bak` on disk (untracked, correctly caught by `.gitignore:105`). Disk clutter only; delete at leisure.

---

## CLEAN REGISTER — claims verified true this audit (do not re-derive)

- **ADR-016 vs `data/weapons/*.tres` — MATCHES on every value.** M26 190 · M79 150 · LAW 250 · RPG-2 250 · RPG-7 290 (ADR-016:184-185, Amendment H :214-236) · MG 42 (m60, rpd) · sniper 87 (m70) · shotgun 35/pellet · rifles/SMG/pistol 27 explicit (car15, m1911) or by default-27 absence (ak47, m14, m16a1, mosin, ppsh41 — default at `scripts/weapons/weapon_data.gd:22`). `aircraft_20mm.tres` 87 sits outside the table's classes (CAS gun, ADR-011 territory), not a contradiction.
- **demo_game.gd switchboard — honest end to end.** All four EXCLUDE consts consumed (`:100,:183` saves · `:424` debrief · `:146-159` air/ambient via `_apply_ambient_exclusions`, with `push_warning` when the named node is absent); `mission_generator.gd:263-268` builds `AirTraffic`/`AmbientWar` under exactly the names `find_child` looks for; boot print `:136-138` prints the real constants it claims.
- **Arc constants internally consistent and cross-verified:** night-seam math (06:30 @38x → NIGHT ~1184 s) ✓ · M-6 print math (60 s → ~07:08) ✓ · `LIVE_CAP` 50 (`siege_director.gd:35`) vs SIEGE_STRENGTH-45 rationale ✓ · parapet 96.1 m reach derived from the kit JSON ✓ · `mission_weather.gd:40` `{5.5,10.0,17.5,21.0}` and `:51` plan-seeded hour — both pointers EXACT (file lives at `scripts/world/`) · `AirTraffic` API real (`launch` `scripts/ai/air_traffic.gd:218`, `orbit_on_station` `:404`, `flights_in_air` `:414`, huey formation 6-9 `:39`) · `CASAirplane.Ordnance` holds every member the beat tables use (`cas_airplane.gd:16`) · `GameFlow.DEMO_MAP_SIZE` 512 (`game_flow.gd:565`).
- **Today's napalm commit (`f6b323a6`) — every checked claim true:** `_KIND_SCALE` napalm 13 / heavy 10 / mortar 6 (`gun_fx.gd:124-135`) with the width header CORRECTLY recomputed (2.2×1.05×kind×2.0: napalm ~60 m ✓) · `MAX_LINGER` 9 (`:315`) · tallest tree 13.378 in `data/veg_break_bands.json` ✓ · FirePlan lane 8×22+2×30 = 236 m (`fire_plan.gd:31-34,:87`) matches gun_fx's "~240 m chain" comment · hut deaths on the napalm kind (`destructible.gd:43-44`) · `_scorch` exists (`gun_fx.gd:567`).
- **Today's nav-truth commit (`a5d077a7`) — every checked claim true:** `agent_max_slope` 45 (`nav_baker.gd:330`) · `NAV_ROOF_HEIGHT_M` 1.9 (`:577`) · per-bake `ms=` instrument (`:385`) · `NAV_GROUND_PREFIXES` (`:544`) and `combat_manager.gd:294` `BLAST_PROOF_PREFIXES` are twin lists, each cross-annotated to the other (hand-synced — watch, but not silent) · casualty figures tagged + boot-printed (`site_planner.gd:1504,:1529,:1536`) · tandem-keyed seat fallback (`heli_lift.gd:96`, `seat_system.gd:48`, `helicopter.gd:25`).
- **CLAUDE.md pointers verified good:** BIBLE.md pillars `:67/:85-101` ✓ · `model_actor.gd:9-21` ✓ · overseer dice-retired `:63-64` ✓ · `weapon_data.gd:22` ✓.
- **`.gitignore` regenerability claims all real:** `tools/voice_studio.py` exists · `radio_prop.gd` warns as described (`scripts/props/radio_prop.gd:36,:148`) · `radio_manifest.json` exists. Big ignored trees are all deliberate (build/ 1.4 GB, tools/tts 762 MB, cinematics blends, `.blend1`). No new swallow found.
- **False positives dismissed by hand** (for the next auditor): `screen_door.gd` `leaf_a/b_path` exports ARE set (via `door.set()` in `wire_all`, `:145-147`) · `enemy_data.gd` `sprite_unit_variants` IS set (`data/enemies/vc_sapper.tres:29`) · `radio_cord.gd` `cord_length` is a live knob at default.
