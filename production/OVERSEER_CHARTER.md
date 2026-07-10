# RECON — Overseer Agent Charter

> **Working title:** *Recon* (RECONGAME) — a hardcore Vietnam War tactical FPS.
> **Engine / look:** Godot 4.7 stable · GDScript (strict typing) · PSX-era low-poly 3D · modern tactical UI.
> **Document role:** The **operating charter & live coordination ledger** for the head-honcho agent role.
> It holds **no canon of its own** — it enforces the canon (see §0) and tracks state.
> **Status:** v0.3.1 — reconciled against `production/GAME_GUIDE.md` + the 15 ADRs (Full Game Audit #2, ratified 2026-07-10). State reflects that canon; **live task truth is `bd`, not this doc.**

---

## 0. Where this document sits (canon hierarchy — ADR-014)

| Class | Documents | Rule |
|---|---|---|
| **CANON** | `production/GAME_GUIDE.md` (doc of record) · `production/adr/` (the 15 decisions) · `production/bible/` · `DESIGN.md` (founding vision) · `PLAYER_MANUAL.md` (must track the input map) | Amended by explicit decision only (War Room / Summoner). Code contradicting canon = a bead, never a shrug. |
| **LOG** | dated reports (PROGRESS / WAVE / NIGHTSHIFT / CODE_AUDIT / CALEB_TODO …) | Disposable snapshots. Never cited as authority. |
| **DEAD** | `war_room/archive/` · superseded roadmaps | History. Nobody obeys it. |

**Task truth lives in beads (`bd ready`), never markdown.** This charter is process-memory, not canon — where it and `GAME_GUIDE` ever disagree, the guide wins and this doc gets corrected.

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

A frozen epic thaws only by explicit decree — a bead in `bd ready` is **not** a thaw. *(Marines/SF real-world research is retained as DLC-horizon reference only; do not work it.)*

---

## 4. The loop (ADR-008)

`MAIN MENU (NEW CAMPAIGN / CONTINUE) → pick operation → LIVE FIREBASE (walkable hub) → TOC 7-element briefing → board the Huey → MISSION (open AO, 2–4 objectives, detection ladder, squad orders, fire support) → heat-scaled EXFIL → wheels-down (HARD checkpoint) → DEBRIEF (RECON scoring, XP, roster consequences, war-state) → repeat`

Mission grammar: quiet approach → recon ring → objective spike → lull → escalation → heat-scaled exfil → boarding catharsis. *Hub ratified with binding conditions not yet met — see §5 Insertion.*

---

## 5. Domain agents & as-built status (audit-#2 canon state)

Concise pointers, not re-transcribed canon. ⚠ = the audit's verified deviation (beaded). Re-sync from `bd` for live truth.

| Domain | As-built | Deviations / open work |
|---|---|---|
| **Gunplay & Damage** (ADR-016/003/004) | **Flat base × zone grammar (ADR-016, Summoner-decreed 2026-07-10)** — deterministic per hit, values = retired dice averages; per-weapon ADS FOV ratified; locational model live (HEAD fatal / TORSO 2.0 / GUT 1.75+bleed / LIMB 0.75; player 100, enemy 65–85) | ✅ Build item 4 DONE with ADR-016: WW2 .tres out (MP40/Kar98k deleted; Mosin 32 / Thompson 17 retuned), vc_rifleman→SKS, descriptions honest, CLAUDE.md rewritten. Guarded by `test_flat_damage` |
| **Stealth & Detection** (ADR-005/006) | 4-tier accumulator, NoiseBus, believed-position, sentry boredom | ⚠ **Witness rule NOT implemented** — silent kill still trips "YOU'VE BEEN MADE" (o18o, **build item 1, the headline wound**); ±25 scoring not implemented; detection pip unshipped |
| **Enemy AI** | Hybrid goal-FSM + situation-priority stack; personalities; suppression; grenade telegraphs | Open keystones: squad coordinator (gpvb), smart patrol/teamwork (0623), detection ambience (r6qe); ⚠ `MAX_THINK_TIME` declared-unused (perf day) |
| **Squad RPG** (ADR-012) | 5-man MOS fireteam; orders F1–F4 + C/H/X/N; learn-by-doing XP; permadeath | ⚠ **Loss is costless** (instant free rookies) — campaign-debt gap; squad keys never verified on Caleb's keyboard (R3 checklist) |
| **Fire Support** (ADR-011) | RTO-gated, budgets, danger-close double-press — verified genuinely fixed | ⚠ Danger-close must also check the **player's** distance (squad-only today) |
| **Insertion & Exfil** (ADR-008) | Walkable firebase hub ratified | ⚠ **Hub conditions unmet**: 7-element briefing skipped; live Huey ride deleted from campaign path (kills the AA economy) — **build item 5** |
| **Campaign & Saves** (ADR-007/010) | Persistent hub; one-seed determinism; all-or-nothing exfil commit; 3 save tiers | ⚠ Offer labels ("ENEMY: HEAVY") never read by generator → campaign is flat; saves need atomic writes, future-version reject, visible feedback, pause menu (item 3) |
| **World & Presentation** (ADR-001/002/013) | 3D PSX renderer of record; 1280m AO; streaming OFF ≤2km | ✅ **Speck-soldier AABB bug FIXED 2026-07-10** (instance-space measurement; 9/9 characters at 1.7132m; probe `test_model_scale` added to suite) — Caleb visual confirm pending (n2ij); ⚠ jungle feel fails ground truth (item 6); invisible HUD systems (item 3); streaming-off + renderer A/B still open (item 2 remainder) |
| **Tech / Engine** (ADR-010) | Godot 4.7 stable, GDScript strict typing; per-mission determinism + MissionScope registry | ⚠ **No gating FPS number; last measured 19–25 FPS**, `rendering_method` unset — Trust-Restoration Day (item 2). Load GodotPrompter skills + `godot_4.7_features.md` before Godot-facing design |
| **QA / Verification** (ADR-015) | GATE bead + verification/truth laws; headless-boot validation | PLAYTEST **R3 (ida9) is the session entry gate**; test suite still needs rendered-scale probe + gating FPS number |

---

## 6. DLC-horizon reference — Marines & SF (NOT launch canon)

Forward-looking only; frozen. Marines → I-Corps urban (Hue) + DMZ siege (Khe Sanh) + CAP village-embed. SF/MACV-SOG → deniable cross-border recon teams on the Ho Chi Minh Trail (Laos/Cambodia). Do not work without a decree.

---

## 7. Working agreements (the guardrails)

Perf first (a gating FPS number beats any feature) · no HUD affordance = doesn't exist · one seed per operation · never block systems on art · canon over memory · nothing "done" without a probe/measurement/verified playtest · new feature must serve a pillar **and** be launch scope, or it's cut-list / DLC-horizon.

---

## 8. Process law & the mechanical gate (ADR-015)

- **GATE bead (RECONgame-97u3):** feature epics are `bd dep`-blocked while playtest P1s are open — `bd ready` hides gated work. **Open P1s:** o18o, a2qb, r4bk, e6qc, n2ij, zet2, ida9. **Exempt (may proceed while gated):** bug fixes, presentation for already-shipped systems, standing-decree items, and evidence-gathering probes/measurements.
- **Verification law:** "mitigated" / "likely fixed" never closes a bead; name the proof.
- **Truth law:** no comment or doc may claim behavior a probe hasn't verified.
- **War Room:** loop-structure and pillar-touching decisions convene a council **before** build.

### The standing decree — build order (GAME_GUIDE §8)
0. **PLAYTEST R3 (ida9)** — session entry gate; nothing new ships until it verifies a2qb/r4bk.
1. **Stealth restoration bundle** — real witness guard + delete lying comments + GUNSHOT 55→150m + ±25 scoring + optional village clear (o18o, pwu5).
2. **Trust-restoration day (measured)** — set `rendering_method`; ModelActor AABB fix (k≈0.9); streaming off ≤2km; wire `MAX_THINK_TIME` (mhfv; closes 8pbo, n2ij 1-2).
3. **Player-State HUD layer (fmc8 m0)** — condition/consumables/stamina/breath + detection pip + save/load feedback + pause menu + prompt-key truth (fy45).
4. ~~**Damage data finish**~~ ✅ **DONE 2026-07-10** — executed with ADR-016 in one migration (xkn1 closed; probe `test_flat_damage` PASS).
5. **Hub conditions** — RECON 7-element briefing in the TOC + Huey ride restored (4q4i).
6. **Jungle feel pass** — priced by #2's numbers (ge6g).
7. **Law & ledger cleanup** — dead code purge, roadmaps consolidated, PLAYER_MANUAL corrected (e99w).

---

## 9. State of the game (living ledger — audit-#2 canon, re-sync from `bd`)

- **Posture:** mid-remediation from Full Game Audit #2 (2026-07-10). 15 ADRs ratified; a standing decree governs execution.
- **Engine:** Godot 4.7 stable (upgraded from 4.6.2, 2026-07-10), GDScript strict typing.
- **Performance:** last measured **19–25 FPS**; no gating FPS number set; `rendering_method` unset → item 2 sets the baseline. **Perf is the top systemic risk.**
- **Feature gate:** ACTIVE. Feature epics blocked while the 7 P1s are open.
- **Where the build lags the vision (vision wins, all beaded):** witness rule (o18o), scoring economy (ADR-006), hub 7-element briefing + Huey ride (item 5), detection pip, damage-finish (item 4), speck-soldier scale (item 2), jungle feel (item 6).
- **Biggest single wound:** the stealth economy — the witness rule is law but unimplemented; a silent kill still raises the alarm, which voids Pillar 3's whole economy. Build item 1.
- ~~Live design decision in flight~~ **DECIDED 2026-07-10: ADR-016 ratified by direct Summoner decree**
  ("pure flat base × zone; drops the dice entirely") and shipped same-day with its probe. ADR-003's
  dice core is superseded; its locational model and one-grammar law survive.

---

## 10. Open questions — the few that remain

1. ~~**Overseer ↔ §10 Director seed.**~~ **RESOLVED (v0.3.1, default):** one role, two layers — the installed agent definition is the compressed seed; this charter is its operating manual. Summoner may override.
2. ~~**Damage grammar (ADR-016).**~~ **RESOLVED 2026-07-10 by direct Summoner decree** — flat base ×
   zone, dice dropped. The planned profiler became the regression probe (`test_flat_damage`); the
   migration ran once, with build item 4 folded in. Bead btnm closed as superseded.
3. ~~**Overseer ↔ `bd`.**~~ **RESOLVED (v0.3.1, default):** the Overseer drives `bd` directly — `bd init` + `bd prime` at session start, creates/closes/links beads itself. (Repo CLAUDE.md already mandates this for any agent in the repo.) Summoner may override.

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
  - Open questions 1 and 3 resolved to their stated defaults. NOTE: o18o could NOT be mechanically
    linked to the GATE (bd forbids task-type blockers on epics); the gate is mechanically held by the six
    playtest beads (a2qb/r4bk/e6qc/n2ij/zet2/ida9), and o18o is covered by law as decree item 1 — treat
    §8's seven-P1 list as the governing list regardless.
  - Loop line corrected: MAIN MENU includes NEW CAMPAIGN / CONTINUE; decree items annotated with their bead IDs.
- **v0.3 (2026-07-10)** — Reconciled against `GAME_GUIDE.md` + the 15 ADRs.
  - Filled §5 domain status with as-built truth, ⚠ deviations, and build-order items; filled §9 state ledger (engine, perf, gate, lag-vs-vision).
  - Added the binding laws (Fairness, r4bk), the scope-law table, the process gate + the standing decree.
  - **Named the honest overlap:** positioned this charter as the operating manual for the §10 "RECONgame Director," not a competing authority — flagged as the #1 open decision.
  - Logged the in-flight ADR-016 damage-grammar decision.
- **v0.2** — Reconciled against `VISION_READOUT.md` (scope corrected to one launch faction; pillars/PSX/governance).
- **v0.1** — Initial scaffold (pre-canon; superseded).
