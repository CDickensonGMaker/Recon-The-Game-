# AUDIT #3 — STATE OF THE GAME (2026-07-11)

**Type:** full-state audit (Summoner-requested: "where is the game right now — core gunplay loop close to finished, art >50%, narrowing in on animations for guns and units").
**Method:** 4 parallel verification lanes (gunplay code, animation coverage, art inventory, beads-vs-reality) + headless boot. Every claim carries file:line evidence in the lane reports (agent transcripts); this file is the synthesis. Dated report = LOG, not authority (ADR-014).

---

## VERDICT IN ONE PARAGRAPH

The **mechanical gunplay loop is real and good**: input → hitscan with travel-time-delayed damage → zone multipliers → layered blood/decals/hitmarkers → death theater → loot. Boot is clean on Godot 4.7. The two tuning benches (viewmodel alignment, hitzone + damage) are live. What stands between today and "core loop finished" is NOT the shooting — it's (1) the **stealth trio** (witness guard, 150m gunshot, ±25 scoring — all canon, all confirmed absent; pwu5 stays THE P0), (2) **animation families** (smg baked; mg/launcher/bolt/pistol at zero — two enemy types visibly rifle-hold their MG/RPG), and (3) a short list of **truth bugs** (grenade damage ignores ADR-016, captured RPG-2 fires as a hitscan rifle, muzzle points are guesses). Art is realistically **~55–60%**, inflated by a big unplaced structure library; the genuinely-missing buckets are civilians/RTO, building interiors, real audio, UI art.

---

## 1. BOOT / HARNESS — GREEN

- Headless boot on **Godot 4.7 console exe** (`Downloads/Godot_v4.7-stable_win64.exe/…_console.exe`): **PASS**, zero SCRIPT/Parse errors; only the two known-benign exit warnings (AUDIT-12 list).
- Probes green today: `test_hitzones` (incl. new damage-override roundtrip), `test_flat_damage` (16 weapons), `test_model_scale`, `test_anim_library`.

## 2. GUNPLAY LOOP — pipeline solid, canon gaps enumerated

**Working end-to-end (verified):** fire modes incl. jam/fouling; spread w/ skills/prone/breath/suppression; travel-time-delayed hitscan (favor-the-shooter); Hitzone → zone mult → `take_damage`; blood mist/droplets/exit splat/wound decals/kill pool; hitmarkers (kill/head/hit); bullet holes FIFO; directional player hurt UI; morale rout/surrender; downed roll; head-burst gib on fatal headshots; lootable corpses; RPG-2 as real pooled projectile w/ drop + AoE (enemy side).

**Confirmed absent / wrong (the gap list, sized):**
1. **[S] Witness guard (pwu5/o18o)** — victim stamps his own COMBAT beacon in `take_damage` (enemy_base.gd:1821, pre-dedup stamp :683-685); silent unwitnessed kills still trigger "YOU'VE BEEN MADE". Lying comments at :228-230 + mission_director.gd:51-54.
2. **[S] GUNSHOT radius still 55m** (noise_bus.gd:14); canon wants ~150m + alert-ladder retune.
3. **[S] Scoring still kills×10** (debrief.gd:23), the exact anti-Pillar-3 incentive ADR-006 abolished; no ±25 contact terms exist. (Ghost bonus +75 exists, unrelated.)
4. **[S] Tracers hardcoded** — enemy every-round green (enemy_base.gd:1658), ally yellow, player const; no WeaponData fields (nx9n).
5. **[S] Grenade damage violates ADR-016** — grenade.gd:12-13 hardcodes 130/25 vs M26=55 record; m26_grenade.tres dead data; ally M79 verb hardcodes 90/25 vs m79.tres 44 (squad_system.gd:256). NEW bead this audit.
6. **[S] Captured RPG-2 fires as 62-dmg hitscan rifle** — weapon_holder never reads `projectile_data_path`. NEW bead.
7. **[M] MuzzlePoint sockets missing everywhere** — zero current arms viewmodels have one (player tracer spawns from −0.5m guess); NPC muzzle = body-offset formula w/ TODO (model_actor.gd:516). Owner directive says muzzle-tip. NEW bead.
8. **[M] Dead damage pipeline stands (8x59)** — `apply_bullet_damage()` still zero callers; falloff/zone logic duplicated in two resolvers.
9. **[M] Flinch invisible (xphx)** — hit = 0.25s fire stall + material flash; no FlinchModifier.
10. **[M] Live dismemberment never fires** — GibSystem complete, rig contract ships in all 10 GLBs, but `dismember()` has no live caller; head-burst 25% roll has no one-piece fallback.
11. **[M] Armory reachability** — Mosin/M60/Ithaca(outside gore_lab)/CAR-15/M79/LAW/RPG-7 unreachable in-game; SKS shows a Kar98k, CAR-15 a Thompson, M79 an MP40; M70/M14 GLBs have no weapon data.
12. **[L] Bullet ballistics via pool (7ks)** — everything except RPG is hitscan; tracer visual speed decoupled from muzzle velocity.

## 3. ANIMATIONS — the "narrowing in" picture (Summoner's current focus)

**Library:** 99 clips in shared `anim_library.glb` (91 base + 8 `__smg`), wired to every PSXRig character via `_merge_shared_library` (00qp engine half DONE; roster mesh-only re-export pending your windowed confirm).

**Family coverage:** smg **8/8 baked** — but **3 of 8 unreachable**: the funnel strips the family suffix BEFORE alias resolution, so `idle_aiming__smg`, `idle_crouching__smg`, `sprint_forward__smg` never play (fix = few lines in ModelActor.play: try `alias__family` before stripping). **bolt / mg / launcher / pistol = 0 clips each** (8-clip set each via the proven bake_family_clip.py delta pipeline).

**Unit truth table (who needs what):**
- vc_sapper carries RPD → needs **mg** (0 clips — rifle-holds an LMG)
- nva_rpg → needs **launcher** (0 clips — rifle-holds the tube, worst visual offender) **and is pointed at the wrong GLB** (vc_guerilla_rpd; vc_guerilla_rpg exists unused)
- PIGMAN (M60) is on **us_grunt_black, a v1 rig that can never receive library/family clips** — should be us_grunt_m60 (exported, unused)
- nva_regular (PPSh) → smg, live today (5/8 until the alias fix)
- vc_rifleman fires SKS but the model holds a Mosin — decide sks→bolt mapping (one line)

**FP viewmodels:** 9/11 fully wired (m16, ak, mosin, colt45, ppsh, m60, rpd, rpg2, ithaca) — the "7 unwired viewmodels" status was stale, that work shipped. Remaining: m70 (scene exists, **no .tres**), m14 (orphaned), SKS/M79/CAR-15 still WW2 stand-ins, per-gun FP idle/fidget sets not started (every fp glb = only `rifle_idle`).

**Priority order for your posing sessions:** 1) mg family (unblocks vc_sapper + Pig), 2) launcher (nva_rpg), 3) bolt, 4) pistol, 5) family `reloading` where it differs most (mg belt / bolt cycle / launcher muzzle-load), 6) missing base clips (grenade_throw, surrender, wounded_crawl, death_from_the_left, stumble_hit).

## 4. ART — real number: ~55–60%

| Category | % | Note |
|---|---|---|
| Characters | ~55% | 6 combatants + gib rig + library wired; 5 variant GLBs orphaned (m14/m60/m79/m16/rpg); civilians/RTO/VC-female = 0 (sources exist) |
| Viewmodels | ~80% | 9/11 wired; stand-ins for SKS/M79/CAR-15 |
| Structures | ~65% | ~104 modeled+measured; only ~30 placed, ~64 table-ready unplaced; interiors 0; roads 0 |
| Vehicles/air | ~65% | Huey/Chinook/APC/A-1/F-4 wired; C-47 still a box; ordnance not mounted |
| Props/emplacements | ~45% | **ZPU modeled but unwired** (mg_nest stands in, site_planner.gd:254); all 6 Batch-2 emplacement mounts orphaned |
| UI | ~30% | menus only |
| Audio | ~10% | 1 real ambience bed; all SFX procedural placeholders |

**Cleanup lever:** ~145MB redundant in characters/emplacements (loose 8.6MB source sheets ×10 duplicating embedded copies + orphaned GLBs). Bead ar5c quantified.

## 5. SHIPPED TODAY (this session)

- **Hitzone bench damage editing** (bead 5if4 CLOSED): per-zone damage multiplier (`,`/`.`, Shift fine) + fatal toggle (`F`) in hitzone_editor, saved per-unit to `data/hitzones/<unit>.tres`, applied via existing seams. **ADR-016 Amendment B** recorded (defaults remain law; bench refuses to persist law-equal values). Probes green.
- Both benches launched for the Summoner: viewmodel alignment (bore laser, B auto-align, Ctrl+S) + hitzone (shapes + damage).

## 6. THE RECORD — bead actions from this audit

Applied: close hyyn (done, absorbed by shipped weapon_holder code) · close o18o as superseded-by-pwu5 (NOT fixed) · close ew4u as dup of 9qp6 · narrow 60v5 (only m70.tres remains) · narrow of80 (FP radio handset only) · trim n2ij (tiny-units fixed+probed; terrain pop + jungle remain) · refresh pwu5 line numbers (1497→1821 etc.) · new beads: grenade/M79 ADR-016 compliance, RPG-2 capture hitscan bug, MuzzlePoint sockets, family-alias gap + unit GLB re-point (PIGMAN→us_grunt_m60, nva_rpg→vc_guerilla_rpg).

**GATE 97u3 status:** held closed by SIX P1s — ida9, n2ij, e6qc, a2qb, r4bk, **zet2** (zet2 was missing from the working list). Build order unchanged: **pwu5 → mhfv → decree items 3-7.** mhfv is honestly PARTIAL (AABB fix + probe done; streamer guard, decal cap, MAX_THINK_TIME uses, FPS gate remain).

*Lane evidence: agent transcripts of 2026-07-11 (gunplay/anim/art/beads). Next audit should re-verify items marked NEW.*
