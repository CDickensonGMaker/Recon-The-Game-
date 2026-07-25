# SYSTEMS DESIGNER — DRIFT AUDIT #2 (2026-07-10)

> **BANNER (corrected 2026-07-25, ghost-code audit):** References to `RECON_ADAPTATION.md` below are
> historical; that doc was deleted on purpose 2026-07-23. Do not seek or restore it. Canon is
> `production/GAME_GUIDE.md` + `production/adr/`.
Lens: numbers and economies. Auditing compliance with the 2026-07-09 decree + doc↔code drift.
All claims file:line grounded. No code modified.

---

## (a) DRIFT CATALOG

### DRIFT-1 — THE HEADLINE: the o18o stealth fix DID NOT LAND. The comments landed; the code didn't.
- **Decree says** (build order #5, wound #4): fix `take_damage()` stamping COMBAT contact so an
  unwitnessed silent kill no longer triggers "YOU'VE BEEN MADE". Briefing lists it among
  "decree items executed."
- **Code actually does**: `scripts/enemies/enemy_base.gd:1496-1497` — `take_damage()` still calls
  `_set_tier(AlertTier.COMBAT)` unconditionally ("Getting shot = instant COMBAT tier (R12), whatever
  we were doing"), BEFORE the death check at `:1526`. `_set_tier()` stamps the static beacon
  `EnemyBase.last_combat_contact_ms` at `:626-627` — **before** the same-tier early return at `:628`.
  `MissionDirector._check_detection()` (`scripts/missions/mission_director.gd:65-71`) polls that beacon
  and fires "YOU'VE BEEN MADE - THEY'RE MOVING TO CONTACT" + hunter escalation. A one-shot suppressed
  headshot on a lone sentry still raises the AO on the first bullet.
- **The insidious part**: the *comments* now describe the fixed behavior as if it shipped —
  `enemy_base.gd:189-191` ("a silent, unwitnessed kill no longer summons the QRF") and
  `mission_director.gd:51-54` ("A silent, unwitnessed kill leaves the AO cold"). Those comments are
  about kill-triggered escalation removal (true) but read as the full witnessed-contact rule (false).
  Bead **o18o is still OPEN, P1** (verified via `bd show o18o`).
- **Which is right**: the decree. This voids the entire stealth economy for the second audit running:
  ghost bonus, threat cooling (−0.03 clean, `campaign_state.gd:109-110`), `silent_movement` skill
  (100 XP/level, `skill_catalog.gd:12`), suppressed-noise design (3m radius, `noise_bus.gd:15`) are
  all priced against a stealth that cannot exist past the first trigger pull.
- **Update**: fix the code (don't stamp the beacon on a killing blow; let living witnesses stamp via
  the noise/LOS machinery they already have at `enemy_base.gd:645-658`), then close o18o.

### DRIFT-2 — Damage unification: closed at ~80% done. The Mosin one-shots the player by data lineage.
- **Decree says** (item 6): "RECON dice everywhere, M16 default, kill dead .tres." Commit `96114f5`
  ("beads: damage unification closed") marks it done.
- **Code actually does**:
  - DONE: default primary is M16A1 for player (`scripts/player/weapon_holder.gd:133-135`) and allies
    (`scripts/allies/ally_base.gd:97`, sprite/ballistics now match). Actively-used conversions landed:
    ppsh41 `[3,10,0]`, rpd `[4,10,0]`, m1911 `[2,10,0]`, sks `[4,10,0]` (data/weapons/*.tres:14).
  - NOT DONE: four flat-grammar legacies survive — `thompson.tres [1,6,45]` (avg 48.5),
    `mp40.tres [1,6,38]`, `kar98k.tres [1,10,70]`, `mosin.tres [1,10,68]` (avg 73.5) — and the
    **Mosin is LIVE on the most common enemy**: `data/enemies/vc_rifleman.tres:14`
    `weapon_path = mosin.tres`. Chest hit on the player: 73.5 avg × 2.0 TORSO (`hitzone.gd:18`)
    = **~147 vs 100 HP = one-shot kill, no bleed-out window** (`health_system.gd:206-208` — hp≤0
    goes straight to `_die()`); with `min_damage_mult = 0.85` (`mosin.tres`) it one-shots at ALL
    ranges. Compare: AK chest = 22 × 2.0 = 44 (2-3 hits), allied M16 = 27.5 × 2.0 = 55.
  - Enemy data contradicts itself: `vc_rifleman.tres:8` description says "with an SKS" but loads the
    Mosin; `nva_regular.tres` says "with an AK-47" but loads `ppsh41.tres` (avg 16.5/round — the elite
    NVA hits **weakest-in-game** per round while the militia rifleman one-shots). The exact
    "sprite/ballistics drift nobody notices for six months" the code warns about.
  - WW2 guns still player-reachable: combat lab list (`scripts/levels/combat_lab.gd:282-283`) and
    corpse looting (`player.gd:295`) — the legacy grammar can enter the player's hands.
- **Which is right**: the decree. Point vc_rifleman at `sks.tres` (4d10, matching its own description),
  nva_regular at `ak47.tres`, and decide the fate of the four WW2 .tres (convert or delete).

### DRIFT-3 — CLAUDE.md's "Damage System" section is technical law that is now false on every line.
- **Doc says** (`CLAUDE.md` Damage System): example `[1,6,45] = 1d6+45`; "Body multipliers: HEAD (4x),
  TORSO (1.5x), LIMB (0.6x)"; "Player HP: 100, Enemy HP: 60-80".
- **Code actually does**: `scripts/combat/hitzone.gd:16-21` — HEAD 4.0 **and fatal outright on
  enemies** (`hitzone.gd:78-79`, `enemy_base.gd:1466-1467` `amount = current_hp + 999`), TORSO **2.0**,
  **GUT 1.75** (a zone CLAUDE.md doesn't know exists — with 4.0 dps bleed-out + forced crawl,
  `enemy_base.gd:1489-1491`), LIMB **0.75** + wound effects. Player HP = `50 + st*0.5`
  (`player.gd:429-430`) = 100 at baseline st 100 but up to 150 via +5-st purchases
  (`skill_catalog.gd:16-17`). Enemy HP is **65-85** (`vc_farmer 65`, `vc_rifleman 70`, `nva_rpg 75`,
  `vc_sapper 80`, `nva_regular 85` — data/enemies/*.tres:10), not 60-80. The dice example showcases
  the grammar the decree ordered killed.
- **Which is right**: the code (the locational rework `591a5a5` is a genuine improvement — see
  strength #2). **Update CLAUDE.md** — it is the doc every fresh session reads first.

### DRIFT-4 — Detection sight caps: code is 3.6x below DESIGN.md in the open.
- **Doc says**: `DESIGN.md:60` "open ~500m, forest ~90m, jungle ~45m"; RECON_ADAPTATION §5 open 600yd.
- **Code actually does**: `enemy_base.gd:79-80` `SIGHT_CAP_OPEN: 140.0`, `SIGHT_CAP_JUNGLE: 45.0`,
  lerped by vegetation density and scaled by weather (`:508-516`). There is no forest middle tier.
  The book's 20:1 open/jungle ratio became ~3:1.
- **Which is right**: probably the code (1km AO, weapon `max_range` 460m on the M16, perf) — but
  600m paddies being "genuinely dangerous" is a named design goal ("HLL treeline terror, by the
  book"). At 140m open cap, open ground is far safer than the docs intend. **Needs ratification**,
  then update DESIGN.md.

### DRIFT-5 — The RECON XP debrief formula (§12) was never implemented; the score pays the opposite behavior.
- **Doc says** (`RECON_ADAPTATION.md` §1, §12): "adopt nearly unchanged as the mission debrief score":
  +25 per contact avoided, **−25 per contact detected**, danger pay per enemy tier placed, −every St
  of team damage (KIA ×2), ÷ team size.
- **Code actually does** (`scripts/ui/screens/debrief.gd:21-31`): `objectives×100 + kills×10 −
  damage_taken + 50 (sub-15-min) − 50 (emergency exfil) + 75 (ghost)`. Kills PAY, uncapped; the ghost
  bonus is shots-based (≤15/objective, `:16-18`) not detection-based; `mission_state.gd:13-19` tracks
  **no contact-avoided/detected counters at all**. Detection costs nothing at debrief. 8 kills out-earn
  the entire ghost bonus.
- **Which is right**: the doc's *shape* is the one aligned with Pillars 3/5 (stealth as economy) —
  and it's cheap now that DRIFT-1's fix would make detection a real event to count. At minimum,
  ratify the deviation; RECON_ADAPTATION currently promises a scoring system that doesn't exist.

### DRIFT-6 — Debrief lies: the −100 POW line is displayed but never scored; civilian kills still free.
- `debrief.gd:68-69` prints "THE PILOT DIDN'T MAKE IT: -100" but `compute_score()` (`:21-31`) never
  reads `pow_lost` — the −100 is UI fiction. Same class as the prior audit's civilian finding, which
  is **unchanged**: `civilian.gd` flags casualties and toasts "THAT FOLLOWS YOU HOME," but neither
  `compute_score()` nor the threat model (`campaign_state.gd:92-126`) reads it. Napalm on the ville
  remains score-optimal.
- **Which is right**: neither — display and score must agree. Score the −100; price civilians.

### DRIFT-7 — Campaign scaling (decree item 7): not started; the HEAVY label is still a lie.
- **Decree says**: "cheap campaign-scaling partials (read the label, scale populations, wound-not-dead
  rookies)."
- **Code actually does**: `missions_played` feeds only the offer-board reseed
  (`hub_controller.gd:73`), roster top-up count (`barracks.gd:48`) and UI strings. The offer
  `strength` ("LIGHT/MODERATE/HEAVY", `mission_offers.gd:33`) is displayed in the TOC briefing
  (`hub_briefing.gd:41`) and **read by nothing** — grep for `strength` in `mission_generator.gd`: zero
  hits. Squad KIA replacements remain free/instant. Threat still moves only ±0.03-0.05/mission +
  AA modifiers (`campaign_state.gd:106-115`).
- **Compliance note**: item 7 was LAST in the build order, so this is schedule-consistent — but item 5
  (stealth) was skipped while items 6 (partially) and later work (unratified campaign loop) shipped.
  The build order was not followed in order.

### DRIFT-8 — Survival v1 (unratified system): hunger is arithmetically incapable of mattering.
- **No decree ordered this system** (briefing: "CAMPAIGN LOOP OVERHAUL (unratified by any council)").
  Auditing its numbers as-built (commit `0330bba`):
  - Hunger drains `100/(45*60)` per second (`player.gd:316`) — **45 minutes to empty**. Penalty begins
    below 50 (`player.gd:323-326`: stamina-max mult lerp 1.0→0.55) — i.e. **22.5 minutes of field time
    before ANY effect**, warning toast at 25 hunger (~34 min).
  - The mission economy targets **sub-15-minute missions** (speed bonus at <900s, `debrief.gd:25`), and
    QRF pressure ramps to push you out (waves accelerate ×0.6 past 15 min, `mission_director.gd:82-86`).
  - The hub **resets hunger AND weapon condition to 100, free, on every entry**
    (`game_flow.gd:354-361` "The firebase takes care of you") — and every mission starts and ends at
    the hub. So hunger can never accumulate across missions either.
  - Net: on a par mission you exfil at ~67 hunger; the meter, the 2 rations (+45 each, cap 4,
    `player.gd:255,336`), and the `use_ration` key are dead weight. **Tuned to be ignorable.**
  - **Weapon condition, by contrast, works**: −0.15/shot, −0.25 in rain (`weapon_holder.gd:298`), jam
    chance ×`1+(100−cond)×0.055` (`:308`) — at condition 60 (~267 rounds) jams hit ~4.8%/shot, one
    stoppage per ~21 rounds. Felt in exactly the right situation (long, loud, wet). Minor comment
    drift: ":297 says 'up to ~5x more'; formula max is 6.5x at condition 0."
- **Which is right**: neither doc nor decree exists to compare — that's the problem. Either ratify
  hunger as a multi-mission field-ops mechanic (no hub reset; ops with 2-3 missions before return)
  or cut it and keep condition. Write the ADR.

### DRIFT-9 — Fire-support bug cluster (decree item 1): VERIFIED FIXED — with one survivor from the prior analysis.
- All four decree'd bugs confirmed dead in code: danger-close confirm reachable (net stays open
  through soft failures, closes only on dispatch, `mission_director.gd:226-257`), pend is kind-bound
  + expires at 5s (`:220-222, 248-249`), `_radio_check()` gates every request including Y-mortar/O-drop
  shortcuts (`:229, 324-331, 393`), key-6 claymore guarded by `any_fire_menu_open` (`:212`), point scan
  throttled (commit `e4baf23`).
- **Survivor**: `_danger_close_to_squad()` (`:352-360`) still checks **squadmates only, never the
  player** — you can drop a snake-eye on your own head confirm-free at DANGER_CLOSE_M 45
  (`:218`). Named in the prior systems analysis; never made the decree; still true.
- Budgets remain well-laddered: patrol `{mortar:1}` (`mission_generator.gd:103`), rescue
  `{napalm:1,mortar:1}` (`:132`), anti-AA `{mortar:1}` (`:153`), village `{bombs:1,napalm:1,mortar:2}`
  (`:236`), firebase defense 10 calls (`:248`). FO/FAC skill visible: scatter lerp 1.0→0.45, cooldown
  `25−2×fo`s, 4th mortar round at fo≥5 (`mission_director.gd:264, 279, 379-380`).

### DRIFT-10 — "Heat-weighted exfil" exists in the decree and RECON_ADAPTATION, not in the game.
- **Decree strength #2** credits "tiers, noise, finite QRF pools, heat-weighted exfil" as built design.
  RECON_ADAPTATION §9 specifies withdrawal tapering ("fewer contacts on withdrawal") + the Phase-2
  heat system.
- **Code actually does**: grep `heat` → one schema comment (`save_data.gd:16`). Exfil spawning has no
  weighting; the only time-coupling is the QRF `field_mult` (`mission_director.gd:82-86`) which makes
  pressure **increase** with field time — the *opposite* of RECON's withdrawal taper. That's a
  defensible real-time choice (push toward exfil), but it contradicts the doc and was never decided
  anywhere findable.

### DRIFT-11 — Save/checkpoint economy (unratified Phases A+D): sound tiers, one scum door.
- As built (`save_manager.gd:6-9, 72-87`): REGULAR = F5/F9 anywhere + 30s autosave; HARD = hub saves +
  wheels-down checkpoint (written to slot 5 at launch, `game_flow.gd:110-114`; **spent** on any
  resolution, `:221`); IRONMAN = hub only, KIA archives the campaign (`:222-225`). Field-save denial is
  honored with a diegetic toast (`save_manager.gd:65`). Good economy, cleanly derived from existing
  settings.
- **The scum door**: there is no MissionSection (`save_data.gd:15-17`, Phase E reserved), but a
  mid-mission REGULAR quicksave serializes the **live campaign dict** (`save_manager.gd:105-113`)
  *during* `_defer_saves` — bypassing the all-or-nothing `commit_mission()` design
  (`campaign_state.gd:129-141`) the prior audit praised. Loading returns you to the hub
  (`game_flow.gd:287-302` — no checkpoint on REGULAR → `enter_hub()`), mission abandoned: any
  squad KIA / XP spend since the save is reverted at the price of the mission. On REGULAR that is
  arguably fine-by-design — but nobody decided it; it inverts a ratified property.

### DRIFT-12 — Noise numbers: the asymmetry the prior audit flagged is untouched.
- AI ears: GUNSHOT 55m (`noise_bus.gd:14`); player ears: `audio_max_distance = 350.0` on every rifle
  (`m16a1.tres`). Enemies remain 6x deafer than the player. Suppressed 3m vs RECON_ADAPTATION §5's
  ~10m recommendation (code is *more* generous than the doc — playable, but undocumented). Sound alone
  can never reach COMBAT (hearing bumps SUSPICIOUS→ALERT only, `enemy_base.gd:645-658`, +0.35
  awareness) — which is exactly why DRIFT-1's damage-stamp is currently doing the detection work the
  noise system should be doing. Same conclusion as last audit; nothing moved.

### DRIFT-13 — Squad XP: verified UNCHANGED since "mis-priced, not mis-designed."
- `skill_catalog.gd:6-22` is byte-identical in effect: buy 100-150 flat/level vs use-thresholds
  steepening to 320; L7→L8 still cheaper to buy (100 XP) than to earn (95 use-points ≈ 32 revives).
  **Demolitions still has zero `credit_use` call** — grep confirms only small_arms
  (`enemy_base.gd:1557`), fo_fac (`mission_director.gd:296`), medic (`squad_system.gd:166`),
  detect_ambush (`squad_system.gd:209,222`). The grenadier still cannot learn his own MOS skill.
  No decree item ordered this yet, but it has now survived two audits.

---

## (b) Top 5 strengths (systems lens)

1. **The locational damage rework is real and coherent** (`591a5a5`): root cause found
   (`collide_with_areas` never set — every shot in the game's history was 1.0x center mass), GUT
   zone with 4dps bleed + forced crawl (`enemy_base.gd:1488-1491`), HEAD fatal-no-dice (`:1466-1467`),
   limb wounds that change the man (arm ×1.35 sway `weapon_holder.gd:328-329`, leg no-sprint), and the
   player made symmetrically mortal. "Nobody eats 10 rounds" is now numerically true for RECON-dice guns.
2. **Fire support is the best-audited economy in the game**: decree bugs verified dead, budgets typed
   per mission, the RTO leash airtight through every entry point, and the radioman's skill visible in
   the dirt (sheaf 1.0→0.45). This system now matches its documentation better than any other.
3. **EnemySquad** (`enemy_squad.gd`): 90 lines that turn individuals into a fireteam — shared
   designation, 30m alert propagation, 12s knowledge TTL, breadcrumb pursuit. Cheap, clean, and it
   makes detection tiers legible to the player.
4. **The save architecture** is Catacombs-grade: typed schema with defaults everywhere
   (`save_data.gd:1-4`), migration slot pre-reserved, tiers derived from existing knobs (no new
   settings), deferred apply, exit-autosave that can never block quit (`save_manager.gd:39-44`).
5. **Weapon condition** is the survival number that works: coupled to the jam economy the game already
   has, weather-sensitive, skill-dampened, warned diegetically at 60/30. It creates the M16-in-the-rain
   fantasy with three constants.

## (c) Top 5 weaknesses/risks (ranked)

1. **Stealth is still voided and everyone believes it's fixed** (DRIFT-1). Twice audited, decree'd,
   bead open, comments claim it works. Every downstream economy is priced against a lie.
2. **The Mosin one-shot** (DRIFT-2): the most common patrol enemy kills the 100-HP player in one
   torso hit at any range through a WW2 data holdover, while the elite NVA regular does 16.5/round
   through a PPSh. Lethality asymmetry by accident of file lineage, not design.
3. **Docs are now actively misleading builders** (DRIFT-3/4/5/10): CLAUDE.md's damage law, DESIGN's
   sight caps, RECON_ADAPTATION's XP formula, and the decree's own "heat-weighted exfil" all describe
   a different game. The next long Claude session will re-drift from these.
4. **Survival hunger is dead tuning shipped unratified** (DRIFT-8): 22.5 min to first effect vs
   sub-15-min missions and a free hub reset. Cost: input key, HUD meter, save fields, player attention
   — for a mechanic that cannot fire.
5. **The scoring economy contradicts the pillars and itself** (DRIFT-5/6): kills pay uncapped,
   avoidance is untracked, the POW −100 is display-only, civilians are free. The debrief teaches
   players to play loud in a stealth-economy game.

## (d) Pillar scorecard (systems lens, 1-5)

| # | Pillar | Score | One-liner |
|---|--------|-------|-----------|
| 1 | Outstanding gunplay | **4** | Locational damage + M16 default + the RPM/recoil model finally align; docked for the Mosin one-shot accident and the still-flat jam table (all weapons 1.5% base). |
| 2 | Atmosphere | **4** | Systems still sell it and the war now speaks (VO wired); condition/rain/jam coupling adds mechanized weather-misery. |
| 3 | Freedom / escalation not fail-states | **2.5** | The architecture is right and the one line that voids it was decree'd, believed fixed, and isn't — stealth remains a fiction, and QRF pressure only ever ramps up. |
| 4 | The squad is the RPG | **4** | Learn-by-doing ships and credits real acts; docked for the demolitions dead path and free instant rookies, both surviving a second audit. |
| 5 | Fail forward | **4** | Save tiers price failure correctly (HARD checkpoint spent-on-resolution is elegant); docked for the REGULAR mid-mission scum door and death still = mission restart. |

## (e) The ONE thing to build/fix next

**Land o18o for real.** In `take_damage()`: do not stamp `last_combat_contact_ms` when the hit kills
(move the `_set_tier(COMBAT)` behind the death check, or stamp only if `current_hp > 0` after
subtraction); let living enemies stamp contact through the perception/noise paths they already own
(`enemy_base.gd:645-658` hearing, `_update_perception` sight, `EnemySquad` propagation). Pair it with
the one-constant change that makes sound the honest detection currency: GUNSHOT 55m → ~150m+
weapon-scaled (`noise_bus.gd:14`), suppressed stays 3m.

Why this over everything else: it is an afternoon; it is the same fix this council ordered yesterday;
it re-activates five already-shipped economies (ghost scoring, threat cooling, silent_movement,
suppressed loadouts, the finite hunter pool); and Pillar 3 is my lowest score *specifically because
of it*. Second time on the decree — it should not survive to audit #3.

## (f) ADR CANDIDATES (decisions living only in code/commits/beads)

1. **ADR: Locational damage model** — HEAD fatal-on-enemies/4x-on-player, TORSO 2.0, GUT 1.75+bleed,
   LIMB 0.75+wounds; player symmetric mortality. Lives in commit `591a5a5` + `hitzone.gd`. Supersedes
   CLAUDE.md's written law.
2. **ADR: One damage grammar** — RECON dice everywhere; fate of the four WW2 flat-grammar .tres
   (convert/delete/museum) and the rule that enemy `weapon_path` must match archetype description.
3. **ADR: Detection beacon + witnessed-contact rule** — the intended o18o semantics (who may stamp
   `last_combat_contact_ms`, and that a corpse can't) exist only in a bead description.
4. **ADR: Save tiers & checkpoint economy** — REGULAR/HARD/IRONMAN semantics, checkpoint-spent-on-
   resolution, what a mid-mission save means without MissionSection, and whether the REGULAR
   revert-by-abandon door is intended. Lives in commits `97260df`/`0330bba`.
5. **ADR: Survival v1 scope** — hunger→stamina-only ("sloppy, not dead"), free firebase reset,
   condition→jam coupling, and whether hunger is a per-mission or per-operation meter. Entire system
   unratified.
6. **ADR: Mission scoring economy** — kills-pay vs RECON §12 avoidance-pays; the fate of the
   documented +25/−25 formula; the rule that every displayed debrief line must be scored.
7. **ADR: Sight-cap values** — 140/45 two-tier code vs DESIGN's 500/90/45 three-tier; the compressed
   open-ground ratio is a real gameplay decision about how dangerous paddies are.
8. **ADR: QRF field-pressure ramp** — waves accelerating past 15 minutes (anti-camping, pro-exfil)
   deliberately inverts RECON's withdrawal taper; decided in a commit, contradicts RECON_ADAPTATION §9.
9. **ADR: Fire-support ladder** — per-mission-type budgets, the 10m living-RTO leash, kind-bound 5s
   danger-close confirm, FO/FAC skill effects. The system is excellent and entirely commit-documented.
