# RECON — Overseer Agent Charter

> **Working title:** *Recon* (RECONGAME) — a hardcore Vietnam War tactical FPS.
> **Engine / look:** Godot 4.7 stable · GDScript (strict typing) · PSX-era low-poly 3D · modern tactical UI.
> **Document role:** The **operating charter & live coordination ledger** for the head-honcho agent role.
> It holds **no canon of its own** — it enforces the canon (see §0) and tracks state.
> **Status:** v0.3.1 — reconciled against `production/GAME_GUIDE.md` + the ADR set (Full Game Audit #2, ratified 2026-07-10). `production/adr/` now holds **ADR-001 … ADR-029** (31 ADR files + README, including the fossil law, the Forward+ decree and the open-patrol pivot); read the directory, never a fixed count. State reflects that canon; **live task truth is `production/CALEB_TODO_7_22_updated.md`, `production/ART_Track_Log.md` and `production/DEMO_SHIP_BACKLOG.md` — not this doc.**

---

## 0. Where this document sits (canon hierarchy — ADR-014)

| Class | Documents | Rule |
|---|---|---|
| **CANON** | `production/GAME_GUIDE.md` (doc of record) · `production/adr/` (ADR-001 … ADR-029 — read the directory, it grows) · `production/bible/` · `DESIGN.md` (founding vision) · `PLAYER_MANUAL.md` (must track the input map) | Amended by explicit decision only (War Room / Summoner). Code contradicting canon = a tracked entry, never a shrug. |
| **LOG** | dated reports (PROGRESS / WAVE / NIGHTSHIFT / CODE_AUDIT / CALEB_TODO …) | Disposable snapshots. Never cited as authority. |
| **DEAD** | `war_room/archive/` · superseded roadmaps | History. Nobody obeys it. |

**Task truth lives in the tracking docs above and in Claude memory. Beads (`bd`) are RETIRED — `CLAUDE.md:401-408` forbids resurrecting `.beads/` or running `bd`, and any surviving bead ID in this file or an ADR is dated provenance, never a live pointer.** This charter is process-memory, not canon — where it and `GAME_GUIDE` ever disagree, the guide wins and this doc gets corrected — but **both are pre-pivot documents**: a newer ratified ADR outranks either (ADR-014), and the code outranks all three when the question is what the game actually does.

---

## 1. Identity & mandate — and the honest overlap

**Read this first.** `GAME_GUIDE.md §10` already seeds a head-honcho agent — the **"RECONgame Director"** — with a priority-ordered constitution (**5 Pillars → ADRs → GAME_GUIDE → bible → DESIGN**) and a list of laws to enforce. **This charter does not create a second authority.** It is the *full operating manual and live ledger* for that same role: the §10 seed is the compressed system-prompt; this is the charter it points to. Same constitution, same priority order.

- **The Summoner (Caleb) holds final authority.**
- **The Director holds the pillars; the Arbiter guards them** (GAME_GUIDE §1).
- **The Overseer/Director owns:** alignment (guard the pillars + the binding laws below), routing, cross-domain dependency tracking, refereeing *within* canon, and the state ledger (§9).
- **Never, without the Summoner (and a War Room where pillars/loop-structure are touched):** alter a pillar, a binding law, or the launch-vs-DLC scope line; override an ADR or `GAME_GUIDE`; close anything without a probe, measurement, or verified playtest.

> **Resolved (v0.3.1, default adopted — Summoner may override):** this charter IS the §10 Director's
> expanded manual. The installed agent definition (`.claude/agents/recon-overseer.md`) is the compressed
> seed; it loads this charter + `GAME_GUIDE.md` at session start. One role, one authority, two layers.

---

## 2. North Star & the binding laws

**Pitch.** Hardcore Vietnam tactical FPS: randomized insertion → 2–4 generated objectives in an open 1–1.5km AO → exfil → a persistent campaign that remembers. Arma/OFP bones, SOCOM/Vietcong/Men of Valor flavor, RECON RPG (1982) as the numbers backbone, HLL lethality, an AI fireteam you order, maintain, and lose. **You are a line grunt, not an operator** — *Platoon / Hamburger Hill / Apocalypse Now*.

**The five pillars — test every decision:**
1. **Outstanding gunplay** — HLL lethality; death from *situation*, never bullet sponges / hit-point math.
2. **Atmosphere** — jungle, weather, night, load-bearing audio; the war happens with or without you.
3. **Freedom** — open AO, any route/order, loud or quiet; stealth is an economy, never a gate; no rails, ever.
4. **The squad is the RPG** — named persistent men who improve, wound, rotate home, and die for real.
5. **Fail forward** — detection escalates, failure mutates, a dead mission seeds the next; never reload-and-memorize.

**Binding laws the Overseer enforces on every call:**
- **Fairness Law** (DESIGN §4.2): alert ≠ accuracy; AI accuracy ramps with player *exposure*; first shot at an unaware player is a near-miss; muzzle flash / tracers / vocalizations always telegraph.
- **The r4bk Law:** a feature without a visible HUD affordance **does not exist**. Simulation without presentation is unfinished, not shipped.
- **Witness rule · one damage grammar · 1.7132m scale contract · ≤2km no-streaming · perf-first (a gating FPS number) · verification law · truth law** — see the domains (§5) and process law (§8).
- **Never** add rails, gate stealth, or make loud play the optimal XP strategy.

---

## 3. Scope law (GAME_GUIDE §6)

**Launch = ONE faction: the US Army grunt** — the full mission-generation loop, squad RPG, campaign layer.

| Ruling | Items |
|---|---|
| **KILLED** | 8-directional sprite render matrix (ADR-001) · multi-faction front door at launch |
| **PARKED** | hunger (ADR-009) · **SF (MACV-SOG) & Marines → DLC forks** |
| **FROZEN (post-core)** | co-op · tunnel/interior mode · driveable vehicles · capture/POW · battle director · RPG shop · ride-or-walk |
| **SHRUNK** | 100 bios → 20 great ones · HQ interactions stay walk-up-simple |

A frozen epic thaws only by explicit decree — an entry appearing in a tracking doc is **not** a thaw. *(Marines/SF real-world research is retained as DLC-horizon reference only; do not work it.)*

---

## 4. The loop (ADR-008)

`MAIN MENU (NEW CAMPAIGN / CONTINUE) → pick operation → LIVE FIREBASE (walkable hub) → TOC 7-element briefing → board the Huey → MISSION (open AO, 2–4 objectives, detection ladder, squad orders, fire support) → heat-scaled EXFIL → wheels-down (HARD checkpoint) → DEBRIEF (RECON scoring, XP, roster consequences, war-state) → repeat`

Mission grammar: quiet approach → recon ring → objective spike → lull → escalation → heat-scaled exfil → boarding catharsis. *⚠ This is the ADR-008 loop as decreed. The shipped code no longer runs it: the briefing screen and offer board are deleted and `mission_generator.gd:540` emits only `"PATROL"` under the 2026-07-17 open-patrol pivot (ADR-029 + its 008/006 amendments, both **DRAFT**). The decreed loop stays on the page until the pivot is ratified — see §5 Insertion and §8 item 5.*

---

## 5. Domain agents & as-built status (audit-#2 canon state)

Concise pointers, not re-transcribed canon. ⚠ = the audit's verified deviation. Re-sync from the tracking docs for live truth.

| Domain | As-built | Deviations / open work |
|---|---|---|
| **Gunplay & Damage** (ADR-016/003/004) | **Flat base × zone grammar (ADR-016, Summoner-decreed 2026-07-10)** — deterministic per hit, values = retired dice averages; per-weapon ADS FOV ratified; locational model live (`scripts/combat/hitzone.gd:16-21` — HEAD 4.0 / TORSO 2.5 / GUT 2.25+bleed / LIMB 1.0, ADR-016 Amendment D; player 100, enemy 65–85) | ✅ Build item 4 DONE with ADR-016: WW2 .tres out (MP40/Kar98k/Thompson deleted — `data/weapons/` is the 15 shipping resources), vc_rifleman→SKS, descriptions honest, CLAUDE.md rewritten. Post-Amendment-H flattening: every rifle/SMG/pistol base 27 incl. Mosin (`data/weapons/mosin.tres:14`), MG 42, sniper 87. Guarded by `test_flat_damage` |
| **Stealth & Detection** (ADR-005/006) | 4-tier accumulator, NoiseBus, believed-position, sentry boredom | ✅ **Witness rule SHIPPED** — `enemy_base.gd:736 _can_witness` / `:756 _witness_check`, called from `_die()` at `:2351`; an unwitnessed kill leaves an unreported corpse instead of raising the AO. Probe `tests/test_witness_rule.tscn`; o18o closed. ✅ ±25 contact scoring live (`scripts/ui/screens/debrief.gd:25-26` CONTACT_AVOIDED 25 / CONTACT_DETECTED −25). ⚠ detection pip unshipped |
| **Enemy AI** | Hybrid goal-FSM + situation-priority stack; personalities; suppression; grenade telegraphs | Open keystones: squad coordinator (gpvb), smart patrol/teamwork (0623), detection ambience (r6qe); ⚠ `MAX_THINK_TIME` declared-unused (perf day) |
| **Squad RPG** (ADR-012) | 5-man MOS fireteam; orders F1–F4 + C/H/X/N; learn-by-doing XP; permadeath | ⚠ **Loss is costless** (instant free rookies) — campaign-debt gap; squad keys never verified on Caleb's keyboard (R3 checklist) |
| **Fire Support** (ADR-011) | RTO-gated, budgets, danger-close double-press — verified genuinely fixed | ✅ Danger-close checks the **player's** distance too (`scripts/missions/field_director.gd:357-359`, ahead of the squad loop) |
| **Insertion & Exfil** (ADR-008) | Walkable firebase hub ratified | The 7-element briefing is **deleted, not skipped** — `scripts/ui/screens/briefing.gd` is gone (only an orphan `.uid` remains) and `mission_generator.gd:540` hardcodes `mission_type = "PATROL"`. The briefing, offer board and insertion ride are voided under the open-patrol pivot (`ADR-029-amendments-008-006`, **still DRAFT — ADR-029 itself is unratified**). What survives: firebase as home + persistence anchor, armorer's bench, autosave on entering the world. See §8 item 5 |
| **Campaign & Saves** (ADR-007/010) | Persistent hub; one-seed determinism; all-or-nothing exfil commit; 3 save tiers | ⚠ Offer labels ("ENEMY: HEAVY") never read by generator → campaign is flat; ✅ pause menu shipped (`scripts/ui/screens/pause_menu.gd`); corrupt-slot load is refused, not crashed (`save_manager.gd:170-179`); ⚠ still open: atomic writes (`save_manager.gd:101-105` writes the slot in place, no temp+rename) and future-version reject (`:174` only migrates *older*; a newer schema falls straight through to `from_dict`) |
| **World & Presentation** (ADR-001/002/013) | 3D PSX renderer of record; 1280m AO; streaming OFF ≤2km | ✅ **Speck-soldier AABB bug FIXED 2026-07-10** (instance-space measurement; 9/9 characters at 1.7132m; probe `test_model_scale` added to suite) — Caleb visual confirm pending (n2ij); ⚠ jungle feel fails ground truth (item 6); invisible HUD systems (item 3); streaming-off open. **Renderer A/B is CLOSED** — ADR-026 Amendment A (RATIFIED 2026-07-17): `forward_plus` is canon; do not evaluate, propose, or draft a renderer switch again. **CORRECTION 2026-07-19:** the old `project.godot:300` pointer is dead — Godot **strips `renderer/rendering_method` on save** when it equals the desktop default, so Forward+ CANNOT be locked in config and holds only by being the default. Verify at runtime, not by grepping `project.godot` |
| **Tech / Engine** (ADR-010) | Godot 4.7 stable, GDScript strict typing; per-mission determinism + MissionScope registry | ⚠ **No gating FPS number** — still unset, still the top systemic risk. `rendering_method` is Forward+ by desktop default, ratified by ADR-026 Amendment A — but **not lockable in `project.godot`** (Godot strips the key on save when it matches the default; corrected 2026-07-19). Last sourced bench (ADR-026:111, 18v18 stress arena): **14.0 → 23.1 fps** after the cheap graphics cuts, now CPU-bound — the frame is in the AI, so activity-tiered AI (Part B) is the lever, not jungle draw cuts. Load GodotPrompter skills + `godot_4.7_features.md` before Godot-facing design |
| **QA / Verification** (ADR-015) | The feature gate + verification/truth laws; headless-boot validation | **PLAYTEST R4 is the session entry gate** — the ADR-029 open-patrol checklist, discharged only by a verified playtest by the Summoner; test suite still needs rendered-scale probe + gating FPS number |

---

## 6. DLC-horizon reference — Marines & SF (NOT launch canon)

Forward-looking only; frozen. Marines → I-Corps urban (Hue) + DMZ siege (Khe Sanh) + CAP village-embed. SF/MACV-SOG → deniable cross-border recon teams on the Ho Chi Minh Trail (Laos/Cambodia). Do not work without a decree.

---

## 7. Working agreements (the guardrails)

Perf first (a gating FPS number beats any feature) · no HUD affordance = doesn't exist · one seed per operation · never block systems on art · canon over memory · nothing "done" without a probe/measurement/verified playtest · new feature must serve a pillar **and** be launch scope, or it's cut-list / DLC-horizon.

---

## 8. Process law & the mechanical gate (ADR-015)

- **THE FEATURE GATE:** gated feature work stays parked while **PLAYTEST R4** is open. R4 is discharged only by a verified playtest by the Summoner (ADR-015) — never by a probe and never by an agent's reading. The open list lives in the tracking docs. **Exempt (may proceed while gated):** bug fixes, presentation for already-shipped systems, standing-decree items, and evidence-gathering probes/measurements.
- **Verification law:** "mitigated" / "likely fixed" never closes anything; name the proof.
- **Truth law:** no comment or doc may claim behavior a probe hasn't verified.
- **War Room:** loop-structure and pillar-touching decisions convene a council **before** build.

### The standing decree — build order (GAME_GUIDE §8)
**MAIN PRIORITY (Summoner decree 2026-07-25): the Blender→Godot FP gun/arms PIPELINE.** Animate in
Blender → export lands in Godot working, every time, as automated as possible. Scope: the export
tooling (`tools/export_viewmodel_clips.py` batch driver), pre-flight rig-contract probe, post-flight
GLB validator (see memory `recon-m16-rig-break-2026-07-25` for the measured failure it must prevent),
research input `production/research/blender_godot_fp_pipeline_2026-07-25.md`. Same decree, verbatim
intent: "push the hud to the background and later work" — the ADR-030 deferral is RE-CONFIRMED; no
HUD item outranks pipeline work.
**STATUS 2026-07-26: v1 SHIPPED and proven end-to-end** — fix blessed+executed (M16 rig restored,
m16/ak/m14 re-exported, his 5h of clips landed), pipeline v1 live (`tools/viewmodel_manifest.json` +
`export_all_viewmodels.py` driver + `--strict` pre-flight/wreckage-catcher in
`export_viewmodel_clips.py` + `validate_viewmodel_glb.py` with the break as selftest regression +
`tests/test_viewmodel_contract.tscn` in the suite). Remaining (next session): Summoner suite run +
V-align eyes check · re-export ak/m14 through the driver for uniformity · M14 fittings reparent
(manifest `_debt`) · extend manifest per new gun (ppsh next) · research §F multi-slot experiment.

0. **PLAYTEST R4 (`RECONgame-qrg6`)** — session entry gate; nothing new ships until the Summoner verifies the ADR-029 open-patrol checklist (boot seated at `fsb_main` → wire gate → find a site unguided → fair contact → squad behaves → AAR banks at the gate, `field_director.gd:602-614`). Discharged only by a verified playtest (ADR-015), never by a probe.
1. ~~**Stealth restoration bundle**~~ ✅ **DONE** — witness guard live (`enemy_base.gd:736/756/2351`, probe `test_witness_rule`) and ±25 contact scoring live (`debrief.gd:25-26`); o18o closed.
2. **Trust-restoration day (measured)** — ✅ `rendering_method` set (`forward_plus`, ADR-026 Amdt A) · ✅ ModelActor AABB fix · remaining: streaming off ≤2km, `MAX_THINK_TIME`, and the gating FPS number (mhfv; closes 8pbo, n2ij 1-2).
3. **Player-State HUD layer (fmc8 m0)** — condition/consumables/stamina/breath + detection pip + save/load feedback + pause menu + prompt-key truth (fy45).
4. ~~**Damage data finish**~~ ✅ **DONE 2026-07-10** — executed with ADR-016 in one migration (xkn1 closed; probe `test_flat_damage` PASS).
5. **Hub conditions** — RECON 7-element briefing in the TOC + Huey ride restored (4q4i). **⚠ FOR THE SUMMONER:** the code has moved the other way — the briefing screen is deleted and the generator only emits `"PATROL"`. The open-patrol pivot (ADR-029 + its 008/006 amendments) voids this item, but **both are still DRAFT**, so this decree line stands until ratified. Do not build it and do not silently drop it — ratify or re-decree.
6. **Jungle feel pass** — priced by #2's numbers (ge6g).
7. **Law & ledger cleanup** — dead code purge, roadmaps consolidated, PLAYER_MANUAL corrected (e99w).

---

## 9. State of the game (living ledger — audit-#2 canon, re-sync from the tracking docs)

- **Posture:** past Full Game Audit #2 remediation (2026-07-10) and into the 2026-07-17 open-patrol pivot. ADR-001 … ADR-029 on disk (several late ones still DRAFT — check each header before citing); a standing decree governs execution.
- **Engine:** Godot 4.7 stable (upgraded from 4.6.2, 2026-07-10), GDScript strict typing.
- **Performance:** `rendering_method = forward_plus` (ADR-026 Amendment A, closed to re-litigation). Last sourced bench: **14.0 → 23.1 fps** on the 18v18 stress arena, now CPU-bound in the AI. **No gating FPS number is set — perf remains the top systemic risk.**
- **Feature gate:** ACTIVE, held by PLAYTEST R4. See the tracking docs for current truth.
- **Where the build lags the vision (vision wins):** detection pip, jungle feel (item 6), save hardening (atomic write + future-version reject), the gating FPS number.
- **Biggest single wound:** perf without a gate number — the frame is CPU-bound in the AI and nothing mechanically fails a regression. *(The stealth economy is no longer the wound: the witness rule and ±25 scoring both shipped.)*
- ~~Live design decision in flight~~ **DECIDED 2026-07-10: ADR-016 ratified by direct Summoner decree**
  ("pure flat base × zone; drops the dice entirely") and shipped same-day with its probe. ADR-003's
  dice core is superseded; its locational model and one-grammar law survive.

---

## 10. Open questions — the few that remain

1. ~~**Overseer ↔ §10 Director seed.**~~ **RESOLVED (v0.3.1, default):** one role, two layers — the installed agent definition is the compressed seed; this charter is its operating manual. Summoner may override.
2. ~~**Damage grammar (ADR-016).**~~ **RESOLVED 2026-07-10 by direct Summoner decree** — flat base ×
   zone, dice dropped. The planned profiler became the regression probe (`test_flat_damage`); the
   migration ran once, with build item 4 folded in. Bead btnm closed as superseded.
3. ~~**Overseer ↔ `bd`.**~~ **SUPERSEDED 2026-08-05:** beads are retired (`CLAUDE.md:401-408`). The Overseer records work in the tracking docs and Claude memory, and runs no `bd` command.

---

## 11. Changelog

- **v0.3.2 (2026-07-10)** — ADR-016 decided and shipped.
  - The Summoner decreed the damage grammar directly: pure flat base × zone, dice dropped entirely.
    Migration executed same-day (schema, 16 resources, 6 call sites, rosters, CLAUDE.md law) with
    build item 4 folded in; verified by headless boot + `tests/test_flat_damage.tscn` (PASS).
  - §5 Gunplay row, §8 item 4, §9 ledger, and §10.2 updated to DONE/RESOLVED. Beads: xkn1 closed
    (proof: probe), btnm closed (superseded by decree; probe role shipped as the regression test).
  - Test harness moved to the Godot 4.7 console exe (was still invoking 4.6.2).
- **v0.3.1 (2026-07-10)** — Installed by the War Room session that ratified audit #2.
  - Agent definition created at `.claude/agents/recon-overseer.md` (the compressed §10-seed layer); `GAME_GUIDE §10` now points here; global war-council config routes RECONgame work to this role.
  - **ADR-016 status corrected to PROPOSED** (no such ADR exists yet; the 15 stand; ADR-003 remains law). The damage-profiling probe is now a real bead (exempt evidence-gathering); build item 4 sequenced behind that decision.
  - Open questions 1 and 3 resolved to their stated defaults. NOTE: `bd` forbids task-type blockers on
    epics, so a task that governs the GATE by law may not be mechanically linked to it — check §8 for the
    governing list, not the dependency graph alone.
  - Loop line corrected: MAIN MENU includes NEW CAMPAIGN / CONTINUE; decree items annotated with their bead IDs.
- **v0.3 (2026-07-10)** — Reconciled against `GAME_GUIDE.md` + the 15 ADRs.
  - Filled §5 domain status with as-built truth, ⚠ deviations, and build-order items; filled §9 state ledger (engine, perf, gate, lag-vs-vision).
  - Added the binding laws (Fairness, r4bk), the scope-law table, the process gate + the standing decree.
  - **Named the honest overlap:** positioned this charter as the operating manual for the §10 "RECONgame Director," not a competing authority — flagged as the #1 open decision.
  - Logged the in-flight ADR-016 damage-grammar decision.
- **v0.2** — Reconciled against `VISION_READOUT.md` (scope corrected to one launch faction; pillars/PSX/governance).
- **v0.1** — Initial scaffold (pre-canon; superseded).
