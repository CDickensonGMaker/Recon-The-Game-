# DEVIL'S ADVOCATE — FULL GAME AUDIT #2: THE DRIFT AUDIT (2026-07-10)

Mandate: attack assumptions, name the sacrifices, audit compliance with the 2026-07-09 decree.
Every claim below is grounded in file:line, bead ID, or commit hash. No vibes.

---

## (a) DRIFT CATALOG — headline: THE COMPLIANCE AUDIT

The council wrote a decree at commit `0822a1c` (07-09 16:37). **27 commits landed between the decree
and HEAD `8444795` (07-10 00:56) — 8.3 hours.** Here is what the decree ordered versus what those
27 commits did. Verdict first: **build-order compliance 3 of 7; scope-decree compliance ~1 of 4.
The council's own law was violated within hours of ratification.** A council whose decrees decay in
one working session is not a governance body; it is a mood.

### A1. THE GATE LAW — VIOLATED, REPEATEDLY, THE SAME NIGHT

Decree (synthesis.md, wound #6): *"Council law adopted: no new system ships while a P1 playtest
bug is open."* Build order item 2: *"Playtest gate: fix a2qb + r4bk + e6qc, then a real human
playtest session."*

State of the gate bugs right now (`bd ready`, 2026-07-10): **a2qb OPEN P1, r4bk OPEN P1, e6qc OPEN
P1, zet2 OPEN P1, n2ij OPEN P1** — plus ida9 (Playtest R3) filed as yet another entry-point bead.
a2qb's own notes say "LIKELY FIXED ALREADY — needs tonight's playtest to confirm." r4bk's notes say
"MITIGATED... Caleb: verify either keyset works in tonight's playtest, then close." Neither was
verified. Neither closed. **"Mitigated" and "investigated" were treated as synonyms for "fixed."
They are not.**

New systems shipped while those P1s sat open (timeline from `git log`):

| When | Commit | What shipped | Gate state |
|---|---|---|---|
| 17:00 | `15ec916`/`15e3ec7` | GORE_WORKFLOW.md 5-phase plan | 3 P1 playtest bugs open |
| 18:36 | `84f0449` | **BLOOD v2 + persistent wounds** (new system) | 3 open |
| 23:14 | `8e39c3e` | Playtest R2 files **new** P1s (n2ij: tiny units, terrain pop, dead jungle) | now 4+ open |
| 23:56 | `6e2fc3d` | **FPS arms viewmodel system** (new system) | 4+ open |
| 00:00 | `97260df` | **PHASE A: SaveManager + SaveData schema** (new system) | 4+ open |
| 00:05 | `4573616` | **PHASE B: walkable firebase-hub loop** (new system) | 4+ open |
| 00:07 | `0330bba` | **PHASES C+D: survival v1 + HARD checkpoints** (two new systems) | 4+ open |
| 00:48 | `627421e` | PSX character art pipeline, emplacements, ruins | 4+ open |

That is at minimum **five new systems shipped under an active gate**, and the most damning ordering
of all: playtest R2 at 23:14 found the game's characters render as *specks* and the terrain *pops*
— and the response, starting 42 minutes later, was to build a save system, a hub, and a hunger
meter on top of the game that couldn't render a soldier at the correct size.

*What was sacrificed:* the entire point of the gate — that verification debt stops compounding.
The debt compounded. There are now MORE open P1 playtest bugs (6) than when the law was adopted (3).

### A2. DECREE BUILD ORDER — ITEM-BY-ITEM SCORECARD

| # | Decree order | Status | Evidence |
|---|---|---|---|
| 1 | Fire-support bug cluster, same day | **DONE** ✅ | `e4baf23` 16:40 |
| 2 | Playtest gate: fix a2qb+r4bk+e6qc, then human playtest | **NOT DONE** ❌ | all three OPEN; R2 playtest run anyway, found new P1s (n2ij) |
| 3 | VO wiring (THE ONE BUILD) | **DONE** ✅ (out of order — shipped 16:52, *before* the gate it was sequenced behind) | `08b3987`; `scripts/autoload/vo_manager.gd` is real, 115 lines, well-scoped |
| 4 | Perf-spike day → close 8pbo with measurements | **NOT DONE** ❌ | 8pbo OPEN; `project.godot:277-280` — `[rendering]` still has **no `rendering_method`** (the decree's own #1 suspect); no perf commit post-decree |
| 5 | Stealth witnessed-contact fix + detection pip | **SHIPPED-BUT-BROKEN** ❌ | see A3; pip: zero grep hits for any noticed-pip in `scripts/` — never built |
| 6 | Damage unification (RECON dice, M16 default) | **DONE** ✅ | `591a5a5`, `96114f5`; `weapon_holder.gd:133-135` M16A1 default |
| 7 | Cheap campaign-scaling partials, then M6 depth | **NOT DONE — SUBSTITUTED** ❌ | see A4; instead the unratified campaign loop overhaul shipped |

### A3. THE STEALTH "FIX" IS A FALSE POSITIVE — THE BUG IS LIVE AND THE CODE NOW LIES ABOUT IT

This is the sharpest single finding of my audit.

- `scripts/enemies/enemy_base.gd:189-191` — a comment proudly declares: *"The mission director
  polls this to raise the AO alarm on DETECTION, so a silent, unwitnessed kill **no longer summons
  the QRF**."*
- `scripts/enemies/enemy_base.gd:1497` — `take_damage()` still calls `_set_tier(AlertTier.COMBAT)`
  **unconditionally**, before the death check at :1526.
- `scripts/enemies/enemy_base.gd:626-627` — `_set_tier(COMBAT)` stamps the static
  `last_combat_contact_ms` beacon.
- `scripts/missions/mission_director.gd:68-71` — `_check_detection()` reads that beacon and fires
  **"YOU'VE BEEN MADE - THEY'RE MOVING TO CONTACT"**.

Trace it: one suppressed round into an unwitnessed sentry → victim stamps COMBAT as he dies → beacon
set → director escalates. **Exactly the bug the decree ordered killed (wound #4), still alive.**
Bead o18o is honestly still OPEN — but the code comment claims the fix, and the briefing narrative
("stealth witnessed-contact fix") half-believed it. A comment asserting a fix the code six lines
below disproves is *worse than no fix*: the next reader (human or model) reads the comment and moves
on. The ghost economy — silent kills, threat cooling, the entire loud/quiet pillar-3 economy — is
still voided by one line.

*Which is RIGHT:* the bead. Fix: gate the stamp on an actual witness (living enemy with
LOS/proximity/noise), exactly as o18o's description specifies.

### A4. THE CAMPAIGN LOOP OVERHAUL — UNRATIFIED, AND IT INVERTED TWO DECREE ITEMS

The decree's scope section said **SHRINK: "HQ tent → menu-first version."** Eight hours later,
PHASE B (`4573616`) shipped the opposite: a *walkable* firebase hub — full `game_world.tscn`
instantiation with terrain gen for a menu-equivalent (`game_flow.gd` `enter_hub()`, which builds
world + director + squad + weather + `HubController` just to let you walk 30 m to a tent), prompt
polling (`hub_controller.gd:38-63`), briefing panel, save integration (`hub_controller.gd:82`),
state restore. The decree's cheap partial that WAS ordered — *"read the label"* — was skipped:
`mission_offers.gd:34` still rolls `"strength": LIGHT/MODERATE/HEAVY` and **`mission_generator.gd`
contains zero reads of it** (grep: no hits). `missions_played` still scales nothing
(`campaign_state.gd:33,97` — bookkeeping and the offer-board seed only). **"ENEMY: HEAVY" on the
briefing board is still a lie to the player.**

*Which is RIGHT:* honestly, the hub is probably better for pillar 2 than a menu — but that is a
council decision that was never made. Ratify it retroactively with an ADR, or revert. It cannot
remain a fait accompli, because it carries a permanent maintenance tax: every future system
(inventory zet2, roster ooel, saves, weather, squad spawning) now needs a "does this work in hub
context?" branch. `SaveManager.context: "menu"|"hub"|"mission"` (`save_manager.gd:21`) is a
three-state machine every save-touching feature must now respect, forever.

### A5. KILL/FREEZE/SHRINK — MOSTLY IGNORED

| Decree | Status | Evidence |
|---|---|---|
| **KILL** sprite matrix (9xd/j8o) after an A/B far-LOD test | **NOT EXECUTED** | 9xd OPEN **P1** epic, j8o OPEN **P1**, kkr/e0a open. No A/B commit. The corpse is still marked "urgent." |
| **FREEZE** coop, interiors, vehicles, RPG shop, capture, battle director | **PARTIAL / LEAKING** | gfgr retitled "(post-core)" ✅; rw28 + 2kcp OPEN P2 with no freeze marker; and bead **8ue4 "Batch 9: Building interiors — enterable shells"** (created 07-09) queues frozen-scope interiors work through the art-track back door |
| **SHRINK** 100 bios → 20 | **NOT EXECUTED** | ooel unchanged: still "Write 100 distinct soldier bios," still **P1** |
| **SHRINK** HQ tent → menu-first | **INVERTED** | see A4 |

A KILLed epic that stays open at P1 isn't killed; it's a zombie that will eat a future session.
`bd ready` today shows ~22 open P1s — priority inflation so severe that P1 no longer means anything.
When everything is P1, the gate law has no teeth *by construction*.

### A6. CODE ≠ DOCS — THE LAW BOOK NOW TEACHES THE DEAD GRAMMAR

These are the drifts that will actively corrupt future sessions, because CLAUDE.md is injected into
every conversation:

1. **CLAUDE.md:3** sells the game as *"8-directional billboard sprite characters (CULTIC-style)"*
   and **DESIGN.md:84 (§4.9)** canonizes the sprite pipeline — while the actual renderer is
   `ModelActor` 3D-first with capsule fallback (`enemy_base.gd:286,305`; `ally_base.gd:126`) and the
   decree KILLed the matrix. Three documents, three different renderers. Meanwhile e6qc item 4
   records the Summoner *himself* asking for sprite far-LOD — which is the decree's A/B position.
   Nobody has written the one paragraph that reconciles all four sources.
2. **CLAUDE.md "Damage System"** still teaches `[1,6,45] = 1d6+45` and "Player HP: 100, Enemy HP:
   60-80" — the HoD legacy grammar the decree executed (wound #5). A fresh session reading its own
   law file will re-learn the dead system. `equipment_manager.gd:9` still comments "Slot 0 = Primary
   weapon (Thompson)" against the M16 default at `weapon_holder.gd:135`.
3. **CLAUDE.md "FOV locked at 75.0 everywhere (no ADS zoom)"** vs `weapon_holder.gd:215-220` —
   *"W40: ADS FOV zoom re-enabled (per-weapon ads_fov)"* — vs `player.gd:115` (binoculars zoom to
   FOV 18) vs bead **2spa**: *"Decide: keep FOV-75-no-zoom rule vs small 75→68 ADS zoom (needs
   CLAUDE.md amendment)."* The same decision currently exists in **three contradictory states**:
   forbidden (law), shipped (code), and undecided (bead). This is the purest specimen of drift in
   the project.
4. **DESIGN.md:18 / §1** — *"Never reload-and-memorize"* (pillar 5's own text) and **M8: "Iron Man
   unlockable"** vs `save_manager.gd:6-9`: REGULAR tier = **quicksave/quickload anywhere (F5/F9),
   and REGULAR is the default**. The fail-forward pillar was quietly inverted for the default
   player. Maybe that's the right accessibility call — but it is a *pillar-level* change made by
   nobody, ratified never.
5. **Survival v1 exists in no design document.** DESIGN.md contains no hunger, no rations, no
   weapon-condition. It arrived in `0330bba` labeled "PHASES C+D" of a plan no council saw.
6. **WAVE3_REPORT.md** claims 35.6 avg FPS; bead 8pbo measured steady-state **19-25** and its own
   text orders: "Reconcile the number or the claim." Still unreconciled.
7. **PLAYER_MANUAL.md** (48h old) is already stale: squad C/H/X/N secondary keys (r4bk mitigation)
   absent; hub interact is `[E]` (`hub_controller.gd:47`) while the manual teaches `F` interact
   with `E` as "lean doubles as context interact"; F5/F9 save keys, rations `[0]` kit, and the
   entire hub/survival loop unmentioned.
8. **ROADMAP.md:4**: "Canon detail lives in `production/bible/`" — the bible is 218 lines across
   3 stubs. Canon lives nowhere.
9. **GAME_SCALE_STANDARD.md** decrees 1.7132 m canonical height and says the engine auto-normalizes
   — published at 00:28 (`b37827f`), *the same night* playtest R2 reported characters rendering as
   specks and n2ij noted "GLBs measure ~1.9m." A standard was written while the code demonstrably
   violated it, and **no test enforces it** (see (c)-3).

### A7. DRIFTS THAT ARE IMPROVEMENTS (credit where due — then ratify them)

- M16 default + locational damage (`enemy_base.gd:1466-1467`: headshot = `current_hp + 999`) is
  better than doc-faithful RECON dice-only. Note it *bypasses the dice entirely* on headshots —
  RECON fidelity was already traded for feel. Correct trade; undocumented. ADR it.
- VOManager's diegetic radio sourcing (3D at the RTO's pack unless on the net —
  `vo_manager.gd:42-57`) is better than anything the docs specified.
- The save architecture (Catacombs deferred-apply pattern, `save_manager.gd:24-27`) is genuinely
  solid engineering — my objection is *sequencing and ratification*, not quality.
- `mission_offers.gd:1-3` single-sources offer rolling "so the two can never drift apart" — someone
  in that window understands drift. The instinct exists; the process doesn't harness it.

---

## THE ATTACK VECTORS (b/c feed off these)

### "NOTHING FELT BAD IN MY TESTS" — what brief solo tests are structurally blind to

1. **Hunger is inert for the first ~22 minutes.** `player.gd:316`: drain = 100/(45·60) per second;
   `player.gd:323-326`: zero effect above hunger 50. Warning toast at 25 ≈ minute 34. A 30-minute
   mission ends before the system does anything but toast once. A 10-minute test sees *nothing*.
2. **The campaign difficulty curve cannot be felt because it does not exist.** Nothing reads
   `missions_played` for scaling; offer strength labels are decorative (A4). Ten missions in, the
   war is identical. Only a multi-hour campaign playthrough — which nobody has done — would notice.
3. **Save-scum degeneracy.** REGULAR-tier F5/F9 anywhere + deterministic seeded worlds
   (`game_flow.gd:296-297` — "deterministic seed = same world") = quickload-and-memorize is not
   just possible, it is *optimal play*. Brief tests don't reveal degenerate strategies; hours do.
4. **Hub-cycle state rot.** Offers reroll seeded from `operation_seed*31 + missions_played`
   (`hub_controller.gd:73`); hunger and weapon condition silently reset to 100 at the hub
   (`game_flow.gd:355-358` — "the firebase takes care of you"). Whether ten hub↔mission↔death↔resume
   cycles keep `hub_snapshot`, checkpoint_offer, and CampaignState coherent has never been exercised
   by a human. test_hub_loop runs the loop *once*, headless.
5. **Perf after 30 minutes on a full AO** — probe_perf_decay measured 56 *seconds*. Craters, decals,
   blood v2 accumulation, VO node spawning (`vo_manager.gd:81-96` allocates a new
   AudioStreamPlayer3D per bark) across a full mission: unmeasured.
6. **Squad attachment economics.** Free instant rookies (decree wound #7) mean permadeath — the
   emotional core of pillar 4 — costs nothing. You can't feel that in one sortie; you feel it the
   third time you shrug at a KIA.

### SURVIVAL v1 — a system that taxes without paying

Which pillar asked for hunger? None of the five. Run the numbers: invisible until minute ~22
(`player.gd:316,323-326`), warning at ~34, ration restores 45 points (`player.gd:336`), hub resets
it free (`game_flow.gd:356`). In the median mission it is **one toast and a stamina haircut in the
final third**, plus an inventory slot and a keybind the player must learn. Weapon condition is
better-integrated (fouling → jam chance up to ~6.5x, `weapon_holder.gd:299-308`) and at least
touches pillar 1 — but both arrived as "PHASES C+D" of an unratified plan. This is Catacombs DNA
(the save port brought its survival instincts with it) grafted onto a game whose missions are too
short to starve in. **Either give it teeth (multi-day ops, E&E mutations where rations become the
mission) or cut it before players learn a ritual that means nothing.** The current version is the
worst of both: too weak to create decisions, present enough to demand bookkeeping.

### THE HUB — atmosphere purchased with permanent surface area

Named tax, itemized: a full world-gen pass per hub visit (`enter_hub()` instantiates
`game_world.tscn` and awaits `is_world_ready`); a third SaveManager context; prompt/interact
plumbing duplicated from insertion_ride (`hub_controller.gd:3-4` admits the copy); every future
UI/inventory/roster feature now needs hub-mode testing; and the R3 verification burden (ida9) grew
by an entire loop. All added *under an active playtest gate*. The hub may well be worth it — the
TOC-briefing-to-bird ritual is genuinely pillar-2 — but nobody priced it before buying.

### TEST THEATER — 38 green scenes, and the playtest still found specks

The harness itself is honest — `run_all_tests.ps1` was hardened post-audit (output-scanning, the
known-red XPASS discipline, `--test-save` isolation; its header even documents how R16 shipped as a
no-op under the old green suite). Respect. But every one of the 38 scenes asserts *logic*, and the
playtest found *presentation*: tiny units, terrain pop, dead jungle (n2ij) — precisely the class of
defect a headless suite cannot see. **test_hub_loop PASSES while the game renders soldiers as
specks.** The suite systematically cannot see: rendered scale, LOD/chunk swap continuity, frame
rate as a gate, audio actually audible, foliage density/motion. Minimum viable fix: a screenshot
probe that spawns a character 10 m from the camera and asserts its rendered pixel height (the
GAME_SCALE_STANDARD contract, *enforced*), and promote probe_perf_decay to a gating test with a
number. Otherwise "23/23" (now 38) is a comfort blanket, not evidence.

### SACRED COWS — two I'd put on the docket

1. **FOV-75-no-ADS-zoom is already dead; someone should bury it.** The law's origin is a *tooling*
   constraint (viewmodel-editor/camera sync, CLAUDE.md "CRITICAL" block), not a design conviction.
   W40 re-enabled per-weapon zoom, binocs zoom to 18, iron sights are modeled, and 2spa begs for a
   ruling. Keep hip-FOV 75 fixed; permit modest per-weapon `ads_fov`. Amend CLAUDE.md. Sacrifice
   named: some PSX-era flat-FOV purity, and the editor-sync guarantee needs one careful pass.
2. **8-directional sprites: finish the execution or grant a pardon — in writing.** The decree
   killed it, the beads keep it at P1, the docs still canonize it, and the Summoner wants it back
   as far-LOD (e6qc#4). The A/B far-LOD test the decree ordered is ~an evening and settles it with
   data. What's sacrificed by deciding: either ~600 frames of sunk render work (kill) or a second
   permanent render path with its own bugs (far-LOD hybrid). What's sacrificed by NOT deciding:
   every doc reader and every future session plans against a renderer that may not exist.

### DOC ROT AS PROCESS FAILURE — the structural fix

Four roadmaps (ROADMAP, ROADMAP_NEXT, ROADMAP_WAVE2, WAVE3_REPORT) with two competing numbering
schemes (R-, W-), three overnight/nightshift reports, a stale manual, a 218-line "bible," decrees
in an archive folder, and a CLAUDE.md that teaches dead systems. The game guide the Summoner wants
will rot identically within a week unless the *categories* change, because the failure mode is
structural: **session-end writes new documents instead of updating canonical ones.** Proposal:

- **CANON (update-in-place, small, versioned):** ONE game guide + `production/adr/` (immutable
  decisions) + CLAUDE.md (technical law only — and purge its stale Damage/sprite/FOV sections
  *now*). Every canon file gets a `STATUS: CANON` header and a "last verified" date.
- **LOG (append-only, timestamped, never load-bearing):** all wave/overnight/progress reports move
  to `production/logs/`. A LOG is forbidden from containing the only copy of a decision.
- **DEAD:** ROADMAP_NEXT, ROADMAP_WAVE2, WAVE3_REPORT, OVERNIGHT_*, NIGHTSHIFT_REPORT — archive
  them. ROADMAP.md:4 already concedes "task truth lives in beads"; believe it. Beads for tasks,
  ADRs for decisions, one guide for design. Anything not updated at session close gets deleted, not
  accumulated.
- **Enforcement, not intention:** add the doc-update to the session-close MANDATORY WORKFLOW in
  CLAUDE.md (it already mandates git push; docs are the same class of hygiene).

---

## (b) TOP 5 STRENGTHS (grudging, evidenced)

1. **VOManager shipped and shipped well** — the decree's ONE BUILD, done same day (`08b3987`),
   115 lines, diegetic sourcing, cooldowns, silent no-op on missing wavs (`vo_manager.gd`). The
   council's highest-leverage order was executed faithfully.
2. **The test harness is honest about its own history** — `run_all_tests.ps1` output-scanning +
   known-red XPASS discipline + campaign-save isolation is better test hygiene than most shipped
   games. (Its blindness to presentation is a scope gap, not dishonesty.)
3. **Damage unification is real** — M16A1 RECON-dice default (`weapon_holder.gd:133-135`),
   locational anti-sponge outcomes (`enemy_base.gd:1465-1494`: headshot fatal, gut = crawl +
   bleed-out, W46 crippled crawlers). Pillar 1 got genuinely stronger this cycle.
4. **The save backbone is proven architecture, competently ported** — deferred-apply pattern,
   tiered saves, exit-autosave that can't block quit (`save_manager.gd:39-44`). My quarrel is that
   it shipped under a gate, unratified — not with its quality.
5. **Drift-awareness exists in the code culture** — `mission_offers.gd:1-3` single-sources offers
   explicitly "so the two can never drift apart"; MissionScope teardown; seeded determinism
   throughout. The instincts are right. The governance isn't.

## (c) TOP 5 WEAKNESSES / RISKS, RANKED

1. **Governance failure: the decree decayed in one session.** Gate law violated within ~2-8 hours
   (A1); build order 3/7; KILL/SHRINK unexecuted (A5); the campaign spine replaced unratified (A4).
   Risk: the War Room becomes theater — every future decree inherits this precedent. This audit's
   deliverables are worthless if decree #2 rots like decree #1.
2. **The stealth fix is a false positive with lying documentation** (A3). `enemy_base.gd:189-191`
   claims fixed; `:1497` disproves it; the loud/quiet economy — pillar 3's heart — is still dead,
   while everyone *believes* it works. False green is the most expensive bug state there is.
3. **Verification debt is compounding faster than it's paid.** 6 open P1 playtest bugs (a2qb, r4bk,
   e6qc, zet2, n2ij, +ida9 pending), two playtests without closing one, while surface area grew by
   saves+hub+survival+arms. r4bk means **pillar 4's entire input surface is unverified since 07-08.**
   Tests can't see the failure class (specks, pop, feel) that playtests keep finding.
4. **P1 inflation has disarmed prioritization.** ~22 open P1s including a KILLed epic (9xd) and a
   fantasy task (ooel, 100 bios). When the gate law's trigger condition ("a P1 playtest bug is
   open") is permanently true and universally ignored, both the law and the priority system are
   dead letters.
5. **Canonical docs actively teach the wrong game** (A6). CLAUDE.md — injected into every session —
   still teaches HoD damage, sprite renderer, and the no-ADS law. For a project driven by
   long-running model sessions, stale law files aren't cosmetic: they are *drift generators*.

## (d) PILLAR SCORECARD (devil's-advocate lens)

| Pillar | Score | One line |
|---|---|---|
| 1. Outstanding gunplay | **3.0** | Unification + locational damage genuinely help; but the decreed perf day was skipped (`rendering_method` still unset, 8pbo open at 19-25 FPS) and 20 FPS gunplay cannot be outstanding. |
| 2. Atmosphere | **3.0** | VO + jungle bed are real wins; the Summoner's own verdict — "jungle a white kid in america made," speck soldiers, popping terrain — is ground truth that outranks any green test. |
| 3. Freedom | **2.5** | Open AO stands, but the pillar's economy is broken in both directions: silent kills still trigger YOU'VE BEEN MADE (A3) and default quicksave-anywhere makes reload-and-memorize the dominant strategy (A6.4). |
| 4. Squad is the RPG | **2.5** | The squad's *controls* have been unverified-broken for two days across two playtests (r4bk); loss is still costless; 100-bios fantasy still P1. The RPG's verbs may not even be reachable from the keyboard. |
| 5. Fail forward | **3.0** | HARD checkpoints + hub loop are honest fail-forward architecture; the default REGULAR tier quietly repeals the pillar for most players, unratified. |
| **Process compliance** | **1.5** | Not a pillar, but it gates all five: the council's first decree survived roughly two hours. |

## (e) THE ONE THING TO BUILD/FIX NEXT

**Execute decree item 2, which is now three days stale: a verification playtest (ida9) whose ONLY
allowed outputs are closed beads — a2qb, r4bk, e6qc triage, n2ij scale/pop — plus the o18o
witnessed-contact fix beforehand so the playtest can validate stealth too.** Not the game guide,
not UI modernization, not one more system. Every hour of new construction on six open P1s is an
hour of compounding un-verification; and r4bk alone means pillar 4 might be unplayable and nobody
would know. The cheapest, highest-information action in the entire project is one disciplined hour
of closing loops that are already 90% closed ("likely fixed, needs confirm" — a2qb notes).

## (f) ADR CANDIDATES (decisions living only in code/commits/beads)

1. **ADR: 3D models are the character renderer; sprites demoted to far-LOD-if-proven.** Decision in
   code (`enemy_base.gd:286` ModelActor-first) and decree (KILL 9xd) but contradicted by
   CLAUDE.md:3 + DESIGN.md §4.9 + open P1 beads. Must state the A/B far-LOD test as the sole
   revival path. *Matters:* every art-pipeline hour and every doc reader depends on it.
2. **ADR: ADS FOV policy.** Hip FOV locked 75; per-weapon `ads_fov` zoom permitted (already live,
   `weapon_holder.gd:215-220`; bead 2spa demands the ruling; CLAUDE.md forbids it). *Matters:*
   three-way contradiction in the project's most sacred technical law.
3. **ADR: Save tiers vs Fail Forward.** REGULAR = quicksave anywhere (default), HARD = wheels-down
   checkpoint, IRONMAN = hub-only (`save_manager.gd:6-9`) vs DESIGN.md "never reload-and-memorize"
   + "Iron Man unlockable." Decide the default and amend the pillar text honestly. *Matters:*
   pillar-level inversion currently undocumented.
4. **ADR: Survival v1 scope and numbers** — hunger (45-min drain, effect <50 only, hub reset),
   weapon condition (fouling→jam ~6.5x), rations/kits (`player.gd:63-68,312-337`,
   `weapon_holder.gd:297-308`, `game_flow.gd:355-358`). State which pillar it serves and the
   teeth-or-cut criterion. *Matters:* it's in the save schema now; cutting later costs migrations.
5. **ADR: The walkable firebase hub supersedes menu-first HQ** (contra the 07-09 decree SHRINK);
   MissionSelect demoted to seed-replay dev tool (`mission_offers.gd:2-3`); hub's permanent
   maintenance tax named. *Matters:* it's the campaign spine and it is currently un-decreed.
6. **ADR: Damage grammar** — RECON dice everywhere, with locational *overrides* that bypass dice
   (headshot = `hp+999`, gut bleed-out, `enemy_base.gd:1466-1491`); CLAUDE.md Damage section
   rewritten (currently teaches 1d6+45 / HP 60-80). *Matters:* CLAUDE.md is teaching new sessions
   the dead grammar.
7. **ADR: Detection beacon architecture + witnessed-contact rule** — static
   `last_combat_contact_ms` polled by the director (`enemy_base.gd:192`,
   `mission_director.gd:64-71`), and the witness-gating rule o18o specifies *once it is actually
   implemented*. *Matters:* pillar 3's core economy; currently documented only in a wrong comment.
8. **ADR: Character scale contract** — 1.7132 m TARGET_HEIGHT auto-normalization
   (GAME_SCALE_STANDARD.md, model_actor.gd:16) + an *enforcing* screenshot/AABB probe, because the
   standard shipped the same night the game violated it (n2ij). *Matters:* the export contract is
   only as real as its test.
9. **ADR: Canonical doc hierarchy** — CANON / LOG / DEAD statuses; one guide + ADRs + beads; four
   roadmaps archived (per (a) structural fix). *Matters:* this audit's own deliverable dies without it.
10. **ADR: Decree enforcement mechanism** — decree laws become *blocking beads* at ratification
    (e.g., a GATE bead that `bd link --blocks` every feature epic while playtest P1s are open), so
    `bd ready` physically hides gated work. *Matters:* see (c)-1; a law that lives only in an
    archived markdown file has now been empirically proven to last two hours.

---
*Tradeoffs named, per the law: enforcing the gate slows the window's spectacular velocity — 27
commits in 8 hours built real things. That velocity is also how three contradictory FOV states,
a lying stealth comment, and an unratified campaign spine happened in one night. Pick.*
