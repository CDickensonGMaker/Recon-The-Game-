# GAME DESIGNER — Independent Analysis (FULL GAME AUDIT #2: THE DRIFT AUDIT, 2026-07-10)

**Lens:** vision and play. Is the game being built still the game that was approved?
All claims grounded in file:line or doc citation. Prior scores (my lens, 2026-07-09): 3 / 3 / 4 / 3 / 3.

**One-line verdict:** the last decree was substantially executed (VO wired, damage unified, fire-support
bugs fixed) and the unratified campaign overhaul points in the RIGHT direction — but it quietly
**amputated the front half of the approved core loop** (briefing + insertion), and the stealth economy —
the mechanical heart of Pillar 3 — is now broken in **three independent places** at once. The docs of
record promise a perception game; the code, measured end to end, pays body count.

---

## (a) DRIFT CATALOG

Legend: **CODE✓** = drift is an improvement, update the doc. **DOC✓** = doc is right, fix the code.
**DECIDE** = neither is obviously right; needs a decree/ADR.

### A1. The hub loop bypasses the RECON 7-element briefing — DOC✓ (restore, inside the TOC)
- **Doc/decree:** DESIGN.md §2 mission loop opens with `BRIEFING — 7 elements (RECON)`; Bible 01
  (BIBLE.md:88-92) repeats it; RECON_ADAPTATION.md item 3 (§ later editions) calls the 7-element order
  "the briefing screen spec, verbatim."
- **Code:** the campaign path is `launch_accepted() → start_mission(offer)` (game_flow.gd:305-312) —
  `BriefingScreen` is never constructed. It survives only on the legacy `show_select` path, now
  explicitly labeled a "seed-replay dev tool" (game_flow.gd:51, mission_offers.gd:2-3). The TOC board
  card is 3 lines: codename/type, terrain/weather/time, strength, complications (hub_briefing.gd:38-45).
  No insertion element, no fire-support element, no enemy estimate, no extraction plan, no special rules.
- **Judgment:** the ritual front door of the whole fantasy was deleted from the shipping path and kept
  on the dev path. The TOC tent is the *perfect diegetic home* for the full 7-element order — this is a
  wiring gap, not a design disagreement. **Fix:** `HubBriefing._accept()` should open the 7-element order
  (with intel fuzz) before arming the bird.

### A2. The hub loop deletes the live Huey insertion — DOC✓
- **Doc:** DESIGN.md §2 `INSERT — Huey ride on the chosen route (live AA layer…)`; §4.8; the hub loop's
  own header comment claims "board the bird → mission (**the ride disguises the world load**)"
  (game_flow.gd:242-245).
- **Code:** `if bool(offer.get("from_hub", false)): plan.erase("start_pad")` (game_flow.gd:166-167) —
  from the hub there is NO `InsertionRide`; you get an "INSERTING..." loading screen (game_flow.gd:120)
  and spawn standing at the LZ (game_flow.gd:170-173). The full live ride with AA-threat rolls and
  shoot-down→E&E exists and works (insertion_ride.gd:1-42, aa_hit_chance_scale vs
  `CampaignState.effective_threat()`), but only on the legacy path.
- **Knock-on:** this **orphans the campaign AA-threat economy.** ANTI-AA ops grant −0.25 threat for 3
  missions (campaign_state.gd:111-115) whose primary consumer was insertion AA rolls; exfil shoot-down
  is a flat 0.35 unrelated to threat (exfil_zone.gd:22, :67). On the campaign path, destroying AA now
  buys almost nothing. A whole strategic loop pays into a system that no longer runs.
- **Judgment:** code contradicts the docs AND its own comments. Board the bird at the firebase → ride to
  the LZ (the ride *is* the load disguise) → wheels-down. Restore it.

### A3. Debrief scoring inverts the RECON stealth economy — DOC✓ (this is load-bearing)
- **Doc:** RECON_ADAPTATION.md:15 — "**+25 per contact successfully avoided, −25 per contact detected**,
  minus every point of St the team lost… We adopt it nearly unchanged as the mission debrief score."
  DESIGN.md §2 DEBRIEF — "RECON scoring (+avoided/−detected contacts, −St lost…)".
- **Code:** `compute_score()` = objectives×100 **+ kills×10** − damage − 50 emergency + 50 speed + 75
  ghost bonus (debrief.gd:21-31). There is no contact tracking at all: `MissionState` counts kills and
  damage only (mission_state.gd:13-16); grep for "avoided" across scripts/ returns nothing. The ghost
  bonus is a shots-fired proxy (≤15 rounds/objective, debrief.gd:16-18) — a quiet knife-heavy clear of
  20 men can out-score an actual ghost run, and every kill *always* pays +10.
- **Judgment:** the tabletop rule the project is literally named for was replaced by a body-count bonus,
  silently. Since debrief score banks 1:1 as team XP (game_flow.gd:219), **the XP economy itself now
  teaches loud play.** Docs right, code wrong.

### A4. The o18o "silent kill leaves the AO cold" fix is NOT actually fixed for killing blows — DOC✓
- **Decree:** last synthesis item 4 — one-line class of fix; briefing orders "verify actually fixed."
- **Code claims:** enemy_base.gd:189-191 and mission_director.gd:51-54 both state a silent, unwitnessed
  kill no longer summons the QRF.
- **Code does:** `take_damage()` unconditionally calls `_set_tier(AlertTier.COMBAT)` at
  enemy_base.gd:1497, **before** the death check at :1526; `_set_tier()` stamps the global beacon
  `EnemyBase.last_combat_contact_ms` on every COMBAT transition, before the same-tier early-out
  (enemy_base.gd:625-627). The director polls that beacon and fires "YOU'VE BEEN MADE" + hunter
  escalation (mission_director.gd:64-71). So a one-shot kill of an unaware man — the canonical ghost
  move — still raises the AO alarm. The dead man "entered COMBAT" for one instruction.
- **Judgment:** the escalation-on-detection *architecture* is right; the stamp must be gated on the
  victim surviving (or on a witness). As shipped, ghost play is voided exactly as it was last audit —
  the fix moved the comment, not the behavior.

### A5. VILLAGE_RAID still carries a mandatory 80% body-count — DOC✓ (carried over, decreed, unfixed)
- **Doc:** Pillar 3 — "loud or quiet… stealth is an economy, never a gate." Prior audit weakness #5.
- **Code:** required objective `"CLEAR THE VILLAGE" … "fraction": 0.8` (mission_generator.gd:233).
  You cannot ghost a raid; the design orders you loud after stealth got you there.
- **Judgment:** make the garrison-clear optional (bonus) or replace with "destroy materiel + exfil
  undetected pays double." One line of generator data; a whole pillar of message.

### A6. Offer "strength" label is still cosmetic — decree item 7 not executed — DOC✓
- **Decree:** "cheap campaign-scaling partials (read the label, scale populations)".
- **Code:** offers roll `"strength": LIGHT/MODERATE/HEAVY` (mission_offers.gd:33); grep "strength" in
  mission_generator.gd: **no matches**. Enemy counts are fixed per type (e.g. village 6-10,
  mission_generator.gd:226). Partial credit: complications now have real mechanical bite
  (mission_generator.gd:268-280) and hunters accelerate with field time (mission_director.gd:81-86).
- **Judgment:** still a lie on the mission card. Cheapest honest fix in the project: multiply group
  counts by the label.

### A7. Briefing text is blank/wrong for ANTI_AA and RESCUE — prior weakness #4, still unfixed — DOC✓
- **Code:** `match int(offer.type)` covers only PATROL / VILLAGE_RAID / FIREBASE_DEFENSE
  (briefing.gd:21-33); ANTI_AA and RESCUE fall through to empty objectives and "FIRE SUPPORT: NONE"
  despite carrying napalm+mortar / mortar (mission_generator.gd:132, :153). Severity shifted: on the hub
  path this screen never shows (A1), so the bug is now mostly *dead code* — which is worse, not better.
  Fix it as part of restoring the briefing (A1).

### A8. Survival v1 is unratified scope — split verdict — DECIDE
- **Doc:** hunger appears nowhere in DESIGN.md, RECON_ADAPTATION.md, or MISSION_DESIGN_RESEARCH.md.
  DESIGN §4.3 promised "**per-magazine stoppage roll (weapon-weighted)**" as the reliability system.
- **Code:** hunger 100→0 over 45 field minutes, sub-50 scales stamina down to 0.55, rations restore
  (player.gd:63-68, :313-338, :432); weapon condition fouls 0.15/round (+0.10 in rain) and multiplies a
  per-round jam chance up to ~6.5× (weapon_holder.gd:49-53, :296-311); both reset free at the firebase
  (game_flow.gd:355-361); HARD checkpoints carry them (save_manager.gd:128, :141).
- **Pillar test:** *which pillar does hunger serve?* None of the five. Missions run ~15-30 min; hunger
  does nothing until minute ~22 and never touches health — it is a stamina tax most players will never
  meet, plus two inventory keys ahead of the still-open inventory design bead (zet2). Weapon condition
  is different: a fouling M16 that jams when dirty IS the Vietnam gunplay fantasy (Pillars 1+2) — but
  it's weapon-agnostic (an AK fouls exactly like an M16, weapon_holder.gd:298), missing the one
  authentic hook (and the doc's "weapon-weighted" promise) that would justify it.
- **Judgment:** KEEP condition, move reliability weighting into WeaponData (AK forgiving, M16 filthy).
  CUT hunger or park it until ops are multi-day; today it is pure drift. Ratify whichever way by ADR.

### A9. Save tiers vs the docs of record — DECIDE (partly implements Pillar 5, partly fights it)
- **Doc:** MISSION_DESIGN_RESEARCH.md §10.1 — "**No quicksave.** Checkpoints at mission-graph nodes
  only"; §10.5 — "**Never regenerate the same mission for retry**… failure produces novelty, not
  memorization." Pillar 5: "Never reload-and-memorize."
- **Code:** REGULAR (the default: `hardcore` defaults false, game_settings.gd:13,70) allows F5/F9
  quicksave/quickload **anywhere** (save_manager.gd:59-69, :80-87) plus a 30s in-mission autosave
  (save_manager.gd:47-56). HARD's wheels-down checkpoint re-runs the SAME seed = same world, same
  enemies (game_flow.gd:296-301, :95-107) — so quit-and-resume on the *hardcore-adjacent* tier is a
  legal memorize-and-retry door.
- **What's right:** death spends the checkpoint (game_flow.gd:221) and commits the mission
  all-or-nothing (campaign_state.gd:20-26, :92-96) — that part genuinely implements fail-forward, and
  the tier ladder itself is a good idea. **What drifts:** the DEFAULT tier ships the exact anti-pattern
  Pillar 5 forbids, and HARD's resume replays a known world. Options worth decreeing: default = no
  in-mission quickload (mission-graph-node checkpoints per §10.1), and re-roll the *population* stream
  (keep terrain) on a HARD resume. Also note: save tier is derived from `GameSettings.hardcore`, a flag
  whose own docstring says "no compass, no markers, faster bleed" (game_settings.gd:13) — a HUD setting
  silently owns your save rules.

### A10. HARD checkpoints per se — CODE✓ (they implement Pillar 5, with the A9 caveat)
The wheels-down checkpoint is quit-*resume*, not death-*retry*: KIA → mission resolved → checkpoint
cleared → debrief → campaign continues (game_flow.gd:209-226). "MISSION FAILED — BODY RECOVERED"
(debrief.gd:37) with the campaign rolling on is fail-forward as approved. Docs should record this.

### A11. Squad of 5, fixed MOS order — CODE✓ (update DESIGN)
DESIGN §4.5 says "2-4 AI teammates"; code spawns 5 (POINT/RTO/MEDIC/PIGMAN/GRENADIER,
squad_system.gd:30-46, squad_roster.gd:7). The 5-man version carries all the MOS verbs and works.
Amend the doc.

### A12. Loss economy: free instant rookies — DOC✓ (known M8 gap, unchanged since last audit)
DESIGN §2: wounded heal 2 St/day, veterans rotate stateside, replacements *arrive*. Code:
`ensure_roster()` back-fills 5 living members instantly and free (squad_roster.gd:88-118). Partial
mitigation now exists — a dead veteran's learn-by-doing skills die with him and the rookie starts L1-3
(squad_roster.gd:40-58) — so loss finally costs *something*, but there is still no wound state, no
calendar, no delay. Also: **the barracks (XP spend, roster) is unreachable from the hub** — it hangs
off the main menu only (game_flow.gd:54-63); DESIGN §2 puts squad management at the firebase. The
firebase gives you chow and an armorer (game_flow.gd:354-361) but not your own men.

### A13. Exfil archetypes — partial, shipped version is good — DECIDE (document as v1)
DESIGN §4.8 / research §11 promise heat-weighted archetypes (hold-LZ / gauntlet / quiet walk-on) +
30-60s prep phase. Code ships ONE archetype with a compromise roll: LZ hot while bird inbound → 35%
shoot-down / wave-off → fallback LZ is final (exfil_zone.gd:61-71, :160-193). It's the best moment in
the game (prior audit agreed), but the roll is flat — not weighted by heat/noise economy, so clean play
does not buy a quieter exit (compounds A3). Record as v1; wire `shoot_down_chance` to escalation state.

### A14. Intel economy (W80) orphaned by the hub loop — DOC✓/wiring
`intel_points` sharpen the briefing estimate fuzz (briefing.gd:37) — a screen the campaign path never
shows (A1); and they're zeroed at mission start (game_flow.gd:203). Looting documents currently buys
nothing a hub player can see. Restoring the TOC briefing (A1) revives this for free.

### A15. Doc ≠ doc: the drift machine itself
- **FOUR roadmaps:** ROADMAP.md (living order), ROADMAP_NEXT.md, ROADMAP_WAVE2.md, WAVE3_REPORT.md —
  the latter three are stale session reports posing as roadmaps (all 2026-07-08).
- ROADMAP.md:66 still schedules the sprite render matrix (`9xd`) that the 2026-07-09 decree KILLED.
- BIBLE.md is 2/12 sections written; its own law says "if code contradicts the Bible, the code is wrong
  (or the Bible gets an amended decision — **never a silent drift**)" (BIBLE.md:3-5) — and Bible 01
  explicitly requires a **War Room gate before any loop-structure change** (BIBLE.md:60-63). PHASE B
  (the firebase-hub loop) is precisely such a change, built ungated. The process law exists and was
  violated by the process that wrote it.
- CLAUDE.md still describes the game as "8-directional billboard sprite characters (CULTIC-style)"
  (CLAUDE.md header) after the decree made 3D models the renderer.
- Loading tip still teaches "F1 ON ME. F2 HOLD..." (game_flow.gd:135) while playtest r4bk mitigation
  added C/H/X/N secondaries — verify before it teaches the broken binding.

### A16. Decree items verified EXECUTED (compliance credit)
- **VO wiring (the ONE build):** VOManager autoload exists and is threaded through squad barks
  (squad_system.gd:95, :134-135, :213, :252, :281), radio procedure (mission_director.gd:337-342), and
  enemy shouts (enemy_base.gd:1410). Prior #1 weakness closed.
- **Damage unification:** M16A1 default primary, "Thompson holdover… retired" (weapon_holder.gd:133-135);
  RECON dice in data (ak47 4d10, m16/car15/m60 5d10 — data/weapons/*.tres). Residue: kar98k.tres
  (1d10+70), mp40.tres, thompson.tres still in data/ — "kill dead .tres" incomplete.
- **Fire-support bug cluster:** danger-close confirm reachable with expiring pend
  (mission_director.gd:220-255), shortcuts can't bypass the RTO leash (:229, :393), point-scan throttled
  (squad_system.gd:182-187).
- **All-or-nothing mission commit:** mid-mission writes deferred to debrief (campaign_state.gd:20-37,
  :129-141) — kills the Alt-F4 roster scum. Genuinely good, undocumented (ADR).

---

## (b) Top 5 strengths (this build)

1. **The firebase hub is the right *shape* for the campaign layer.** Operation = a place; TOC → accept
   → walk to the bird → fly out → come home to the same base (game_flow.gd:242-364,
   mission_generator.gd:642-663). This is DESIGN §2's "firebase hub" made diegetic ahead of schedule —
   the skeleton to ratify, even though it currently amputates two loop stages (A1/A2).
2. **The war finally has a voice.** VO routed through every existing bark/radio/enemy hook (A16); the
   radio ritual (on the horn → danger close → shot out) now *sounds* like procedure. Last audit's
   silence — the #1 felt absence — is closed.
3. **Mission commit is all-or-nothing** (campaign_state.gd:20-37): a mission is now a dramatic unit
   that either happened or didn't. Quiet design win for fail-forward and Iron Man integrity.
4. **One damage grammar.** RECON dice everywhere that matters, M16 default (A16) — the two-grammar
   incoherence from last audit is resolved, and locational damage + pain-stagger (enemy_base.gd:1465-1523)
   keep lethality situational.
5. **Complications with teeth + field-time pressure.** NO AIR SUPPORT actually zeroes sorties, REINFORCED
   GARRISON feeds the hunter pool, fog really rolls in (mission_generator.gd:268-280); hunters lean
   harder the longer you stay (mission_director.gd:81-86). The mission card is starting to be an honest
   contract — finish the job via A6.

## (c) Top 5 weaknesses/risks — ranked by damage to the approved vision

1. **The stealth economy is broken in three stacked places** (A3 scoring pays kills, A4 beacon fires on
   silent one-shot kills, A5 mandatory village body-count). Pillar 3's "loud or quiet" is currently
   false end-to-end: the ghost route is punished at the alarm layer, unpaid at the debrief layer, and
   forbidden at the objective layer. Two consecutive decrees have aimed at this; it is still down.
2. **The campaign path skips briefing and insertion** (A1/A2): the approved loop is
   brief→insert→play→exfil→debrief; the shipping loop is card→loading-screen→play→exfil→debrief. The
   two most fantasy-defining ritual beats live on a dev-tool path, and the AA-threat strategic economy
   pays into nothing (A2).
3. **The jungle fails the fantasy — ground truth.** "Jungle a white kid in america made," units render
   as specks, terrain pops at cell boundaries (briefing playtest items 1-3, bead n2ij). No wind/sway
   exists anywhere in terrain grass (grep terrain/: only false positives, terrain_chunk.gd:79).
   Atmosphere was the lowest pillar (2.8) *before* 30 commits that added zero jungle density work.
4. **Loss still costs (almost) nothing, and your men live in the main menu.** Free instant rookies
   (A12), no wounds/calendar, barracks unreachable from the hub — Pillar 4's attachment loop still
   doesn't close, and the new hub makes it *stranger* (you sleep at a firebase your squad isn't at).
5. **The doc corpus is now actively misleading** (A15): four roadmaps, a decree-killed sprite plan still
   scheduled, a 2/12-written bible whose gate law was violated by the biggest change of the week, and a
   CLAUDE.md describing a renderer that no longer exists. Until the GAME GUIDE consolidates this, every
   long session will re-drift — this audit exists because the docs couldn't hold the line.

## (d) Pillar scorecard (1-5, vision-and-play lens)

| # | Pillar | Score | Justification |
|---|--------|:-:|----------------|
| 1 | Outstanding gunplay | **3** | One RECON grammar at last, condition/jam texture and pain-stagger are right; but hitscan remains, the feel keystone (wbtd) is open, and TINY-UNITS/terrain-pop (n2ij) mean firefights happen against specks on popping ground. |
| 2 | Atmosphere | **2.5** | VO is a real gain — the war is audible; the war is still not *visible*: static dead grass, no undergrowth, speck-scale men, popping terrain (playtest ground truth). The pillar that defines the fantasy went down, not up. |
| 3 | Freedom | **3** | Open AO, any-order objectives, abort-anywhere all hold; docked hard because the stealth *economy* half of the pillar is triple-broken (A3/A4/A5) and the hub removed the one route choice the loop had (LZ/route pick never built, ride deleted). |
| 4 | The squad is the RPG | **3.5** | Voices + learn-by-doing + RTO leash + memorial beats = the attachment tech is compounding; loss remains ~free (A12) and squad management is exiled to the main menu, so the RPG still can't hurt you properly. |
| 5 | Fail forward | **3.5** | All-or-nothing commit, death-spends-checkpoint, LZ-compromise mutation, Iron Man wipe = genuine progress; default-tier quickload-anywhere and HARD same-seed resume are reload-and-memorize doors (A9), and failure still generates no next story. |

## (e) The ONE thing to build next: **close the stealth economy loop (one small, three-part build)**

1. **Beacon fix (the real o18o):** in `take_damage()`, don't stamp the COMBAT beacon when the hit kills
   an unwitnessed victim — gate `_set_tier(COMBAT)`/the stamp on survival or a live witness
   (enemy_base.gd:1497 vs :1526, :625-627).
2. **RECON scoring:** track contacts in MissionState (an enemy group reaching COMBAT with the player =
   detected; group left alive+cold behind you = avoided) and score **+25/−25** per
   RECON_ADAPTATION.md:15 at the debrief, replacing kills×10 (debrief.gd:21-31). Kills stay on the AAR
   as flavor, not pay.
3. **Un-gate the raid:** make VILLAGE_RAID's garrison clear optional/bonus (mission_generator.gd:233).

**Why this over everything else:** it is the smallest build that makes a *pillar* true. Pillar 3 is the
project's identity claim ("stealth is an economy, never a gate") and the RECON license's actual rule
set; right now all three layers of the game contradict it, and the XP economy teaches players to ignore
it. It needs no art, no perf work, and no new systems — it's a fix to systems two decrees already
ratified. (The jungle-feel and n2ij P1 bugs matter more to Atmosphere, but they are engineering/art
builds that other lenses will own; per the playtest-gate law they run first regardless.)

## (f) ADR CANDIDATES (decisions living only in code/commits that need formal ADRs)

1. **ADR: The firebase-hub campaign loop replaces menu-driven mission select.** Operation = seed-stable
   firebase + AO; TOC board is the sole offer source; legacy select = dev tool
   (game_flow.gd:242-364, mission_offers.gd:1-3). *Matters:* it's the loop-structure change Bible 01
   said required a gate — ratify it WITH the A1/A2 conditions (briefing in the TOC, ride on launch).
2. **ADR: Save-tier ladder (REGULAR/HARD/IRONMAN) derived from existing settings** — incl. quicksave
   anywhere on the default tier and `GameSettings.hardcore` doubling as the save law
   (save_manager.gd:5-9, :72-87). *Matters:* directly contradicts MISSION_DESIGN_RESEARCH §10.1;
   defaults define the game most players play.
3. **ADR: HARD wheels-down checkpoint = same-seed deterministic re-run carrying consumed state**
   (game_flow.gd:110-114, :296-301). *Matters:* collides with §10.5 "never regenerate the same mission";
   needs the population-reroll (or ratified as-is) on record.
4. **ADR: Survival v1 scope** — hunger→stamina only, weapon condition→jam-chance only, free firebase
   reset (player.gd:313-338, weapon_holder.gd:296-311, game_flow.gd:354-361). *Matters:* unratified new
   pillar-adjacent system; decide keep/cut/bind-to-weapon-data explicitly.
5. **ADR: Detection architecture — a single global COMBAT beacon is THE alarm** (`last_combat_contact_ms`,
   enemy_base.gd:189-192 + mission_director.gd:64-71), with finite hunter pool 12 and field-time
   acceleration. *Matters:* it's the stealth economy's spine and currently mis-stamps (A4); its rules
   must be written to be testable.
6. **ADR: Debrief score = team XP, and what the score rewards** (game_flow.gd:219, debrief.gd:21-31).
   *Matters:* whoever sets this formula sets the player's values; today it silently overrides the
   RECON rule the adaptation doc adopted "nearly unchanged."
7. **ADR: Mission grammar v1 = five concrete types** (PATROL/VILLAGE_RAID/FIREBASE_DEFENSE/ANTI_AA/
   RESCUE, mission_generator.gd:6) standing in for DESIGN §3's RAID/SECURITY/TRANSPORTATION taxonomy
   until M6. *Matters:* names the interim honestly and preserves the M6 upgrade path.
8. **ADR: Mission state is all-or-nothing** — mid-mission campaign writes deferred to debrief commit
   (campaign_state.gd:20-37). *Matters:* quietly load-bearing for Iron Man, permadeath, and save
   integrity; must survive future refactors.
9. **ADR: Global RNG is seeded per mission for determinism; systems needing isolation use dedicated
   streams** (game_flow.gd:95-107, mission_generator.gd:443-447 AA stream, mission_offers.gd:13).
   *Matters:* the entire checkpoint/replay/test edifice rests on it.
10. **ADR: Squad = 5 fixed MOS; replacements instant + free until the M8 loss economy** (squad_roster.gd:7,
    :88-118; supersedes DESIGN §4.5's 2-4). *Matters:* the interim rule everyone balances against.

### What the canonical GAME GUIDE must contain (from this lens)
The as-built loop diagram (hub AND legacy paths, stage by stage); the 5 pillars with their pass/fail
tests; the stealth/detection economy in one table (tiers, noise, beacon rule, hunter pool, scoring);
the debrief scoring formula of record; the mission-type grammar + objective sensor catalog; save-tier
law; squad MOS verbs, XP/learn-by-doing rates, and the loss economy; fire-support catalog with budgets
and the RTO leash; campaign dials (threat, intel, iron man) and what actually consumes them. Fold
ROADMAP_NEXT/WAVE2/WAVE3 into `production/archive/`; ONE living roadmap; bible sections become the
guide's chapters instead of a 12-file aspiration.
