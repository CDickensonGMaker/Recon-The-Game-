# SYSTEMS DESIGNER — Full-Game Audit (2026-07-09)
Lens: mechanics, balance, economy. Branch `overnight-claude`. All claims file:line grounded.

---

## (a) Top 5 Strengths

1. **The firing model is genuinely rigorous.** Framerate-independent RPM via a negative-remainder
   accumulator with hitch capping (`scripts/player/weapon_holder.gd:129-141, 245-249, 265-270`),
   favor-the-shooter delayed hit resolution scaled by real `projectile_speed`
   (`weapon_holder.gd:359-370`), first-shot kick / sustained climb / per-weapon recovery
   (`weapon_data.gd:43-49`, `weapon_holder.gd:374-386`). This is a Pillar-1 backbone most
   prototypes never get right.

2. **Detection is designed as an economy, not a switch.** Four alert tiers with one-way COMBAT
   memory (`scripts/enemies/enemy_base.gd:71, 596-606`), vegetation sight caps 140m→45m
   (`enemy_base.gd:79-80, 494-502`), stance/motion awareness modifiers (prone 0.35x, moving 1.5x,
   `enemy_base.gd:578-584`), point-blank sense bubble (`enemy_base.gd:569, 586`), noise
   investigation that goes to the sound not the source (`enemy_base.gd:631-644`), and a **finite
   hunter pool of 12** so a blown op can be bled dry (`scripts/missions/mission_director.gd:62,
   74-96`). Weather scales all noise radii through one multiplier (`scripts/autoload/noise_bus.gd:22`).

3. **The squad XP economy has the right shape.** Learn-by-doing with a steepening cumulative curve
   (`scripts/squad/skill_catalog.gd:22`), role-gated credit hooks — medic +3/revive
   (`scripts/squad/squad_system.gd:161`), point +2/warning (`squad_system.gd:198`), RTO +2/call
   (`mission_director.gd:277`), ally small-arms +1/kill (`enemy_base.gd:1541`) — plus no-blank-recruits
   starting rolls weighted by the RECON `al` attribute (`scripts/squad/squad_roster.gd:40-58`).
   Skills live on the man, so KIA = lost investment: the death penalty IS the RPG (Pillar 4).

4. **Fire support is laddered and friction-priced, not a win button.** Budgets scale by mission
   type: patrol `{mortar:1}` (`scripts/missions/mission_generator.gd:103`) → village
   `{bombs:1,napalm:1,mortar:2}` (`:236`) → firebase 10 calls (`:248`). Every call requires a
   *living* RTO within 10m (`mission_director.gd:170-175, 215`), the rifle physically drops while
   on the handset (`weapon_holder.gd:173-179, 590-593`), one shared 10-25s cooldown
   (`mission_director.gd:250`), and danger-close needs a second deliberate press
   (`mission_director.gd:239-241`). FO/FAC skill tightening the sheaf (lerp 1.0→0.45,
   `mission_director.gd:262, 329`) makes the radioman's growth *visible in the dirt*.

5. **Campaign loops actually close.** Threat responds to playstyle (12+ kills +0.05, clean ≤3
   kills −0.03, `scripts/autoload/campaign_state.gd:106-110`), ANTI-AA pays −0.25 for 3 missions
   (`:112-115`), high threat spawns opportunistic AA on its own RNG stream so seeds stay stable
   (`mission_generator.gd:446-461`), complications have mechanical bite not flavor
   (`mission_generator.gd:268-280`), and the all-or-nothing mission commit kills Alt-F4 scumming
   (`campaign_state.gd:24-27, 131-141`).

---

## (b) Top 5 Weaknesses (ranked)

### 1. The stealth economy is voided by one line: every hit stamps COMBAT contact.
`enemy_base.gd` `take_damage()` unconditionally calls `_set_tier(AlertTier.COMBAT)` on the victim
("Getting shot = instant COMBAT tier, whatever we were doing", ~`enemy_base.gd:1481`), and
`_set_tier` writes the static `EnemyBase.last_combat_contact_ms` **before** the same-tier early
return (`enemy_base.gd:611-613`). `MissionDirector._check_detection()` treats any contact newer
than the mission baseline as "YOU'VE BEEN MADE" and starts hunter escalation
(`mission_director.gd:65-71`). Net effect: a clean, unwitnessed one-shot kill of a lone sentry —
the exact case the code comment promises "leaves the AO cold" (`mission_director.gd:52-55`) —
triggers mission-wide escalation on your **first bullet**. Everything priced against stealth
(ghost bonus, threat cooling, silent_movement, captured-weapon noise trick R57) is undermined.
Compounding it: AI ears hear gunshots at only 55m (`noise_bus.gd:14`) while players hear them at
350m (`weapon_data.gd:59`), so *legitimate* acoustic detection of long shots never happens — the
bug is doing the detection work the noise system should be doing.

### 2. Two incompatible damage grammars coexist, and the WRONG one is the player's default.
Vietnam guns use RECON dice (AK 4d10 avg 22, M16/CAR-15/M60 5d10 avg 27.5 —
`data/weapons/ak47.tres:10`, `m16a1.tres:10`) per DESIGN 4.3. The HoD holdovers still use
flat-legacy (Thompson 1d6+45 avg 48.5, MP40 1d6+38, Mosin 1d10+68, **RPD 1d8+42 avg 46.5** —
`data/weapons/thompson.tres`, `rpd.tres:10`). Consequences:
- The **default player primary is the Thompson** (`weapon_holder.gd:113`), out-damaging the M16
  per round by ~76% with near-zero variance. There is no loadout screen; M16/CAR-15 are
  unreachable except in the combat lab (`scripts/levels/combat_lab.gd:282`).
- The enemy RPD sapper deals ~46.5/round vs the M60's ~27.5 — the enemy belt-fed hits ~1.7x
  harder per bullet than ours.
- Allies declare `sprite_weapon = "m16a1"` but load `thompson.tres` ballistics
  (`scripts/allies/ally_base.gd:89` vs `:97`) — the exact sprite/ballistics drift
  `enemy_data.gd`'s own comment warns "nobody notices for six months."
- Vs the 100 HP player (`scripts/player/health_system.gd:19`), Mosin torso = avg 110 (1-shot
  down) while AK torso = avg 33 (3-4 shots): lethality asymmetry exists, but by *accident of
  data lineage*, not design.

### 3. The three-situation asymmetry (DESIGN 4.3) does not exist.
Zero hits for any initiator/ambush effectiveness system in `scripts/` (grep: `asymmetry`,
`initiator`, `ambush_penalty`). What exists is fragments: enemy first-shot forced near-miss
(`enemy_base.gd:~1285`), close-range startle delay (`enemy_base.gd:620-626`), player suppression
spread bloom (`weapon_holder.gd:300-304`). There is no "undetected initiator gets full
effectiveness / ambushed side suffers heavy penalty until in cover" — which DESIGN.md:66 names as
**where HLL lethality comes from**. Also from 4.3, still missing: ~10 hitzones with wound effects
beyond arm/leg, diegetic ammo, and per-magazine weapon-weighted stoppages (current jam is a flat
1.5%/shot for all 17 weapons, `weapon_holder.gd:275` — the M16's early-Vietnam reputation and the
AK's reliability are the same number).

### 4. XP economy: the two acquisition paths are priced against each other, and one skill is dead.
Buying is flat 100-150/level (`skill_catalog.gd:6-16`) while use-thresholds steepen to 320
(`skill_catalog.gd:22`). At the top, L7→L8 costs 100 team XP **or** 95 use-points ≈ **32 medic
revives / 95 ally kills** — buying dominates lategame, so learn-by-doing quietly stops mattering
exactly when players are attached to their veterans. The curve's own comment ("~2-3 missions to
L3") doesn't survive the credit rates: L3 = 45 points = 45 ally kills or 15 revives (revives are
capped at 2/mission, `squad_system.gd:16`) — realistically 5-8+ missions. And **demolitions has
no `credit_use` call anywhere** (only readers: `mission_generator.gd:362`,
`objectives/plant_charge.gd:28`) — the GRENADIER can never learn his own MOS skill by doing; the
player plants the charge and no one gets credit. Team XP inflow (~200-400/mission via
`scripts/ui/screens/debrief.gd:21-31`, awarded `scripts/main/game_flow.gd:207`) buys 2-3 levels a
mission across a 6-man roster with 7 skills + 3 attributes each — the sink is fine, the faucet is
fine, the *relative pricing* is not.

### 5. Dead numbers and unpriced consequences (the tuning debt list).
- **Civilian kills cost nothing**: `civ_casualties` is flagged and the toast says "THAT FOLLOWS
  YOU HOME" (`scripts/world/civilian.gd:124-125`) but `compute_score()` never reads it and
  neither does the threat model (`debrief.gd:21-31`, `campaign_state.gd:92-126`). Napalm on the
  ville is score-optimal.
- **Score mildly pays loud over quiet**: kills ×10 uncapped vs ghost bonus +75 flat
  (`debrief.gd:16-31`); 10 kills already out-earns the ghost route, threat −0.03 is the only
  counterweight.
- **`m26_grenade.tres` dice (10d10) are dead data** — grenades resolve through hardcoded
  `apply_explosion_damage` tuples; explosion power lives as 12 scattered literals
  (arty 200/60/14 `mission_director.gd:319`, mortar 140/40/10 `:407`, bomb 220/60/16
  `cas_airplane.gd:140`, CBU 55/15/5 `:174`, grenade `grenade.gd:72`...) with no shared table.
- **Danger-close checks squadmates only, never the player** (`mission_director.gd:303-311`) —
  you can confirm-free drop arty on your own head.
- **Rifle falloff is mostly unreachable**: AK/M16 `effective_range` 250-300m vs the 45m jungle
  sight cap (`enemy_base.gd:80`) — `min_damage_mult` almost never engages in actual play.
- **No healing calendar**: squadmates are binary alive/dead (`squad_roster.gd:94-96`); wounds
  don't persist between missions and replacements are free and instant — losing a rookie costs
  literally nothing.

---

## (c) The ONE next build/fix

**Fix the detection stamp (Weakness #1): make a kill that leaves no living, aware witness stay
silent.** Concretely — in `take_damage()`, only stamp `last_combat_contact_ms` if the victim
*survives* the hit, and separately let living enemies stamp it when they perceive the death
(they already have the machinery: noise investigation `enemy_base.gd:631-644`, squad intel
sharing `enemy_base.gd:507-522`); raise `NoiseBus` GUNSHOT toward its audible truth (55m → ~150m+,
weapon-scaled, suppressed stays 3m) so *sound* becomes the real stealth price instead of the bug.

Why this one: it is the cheapest fix on this list and it re-activates the largest amount of
already-shipped design — the ghost bonus, threat cooling, silent_movement, captured-weapon audio
deception, the finite hunter pool, and the entire "escalation not fail-states" pillar all assume
a stealth economy that currently cannot exist past the first trigger pull. (Runner-up, and the
biggest *build*: unify all 17 weapons onto RECON dice + add the loadout/armory screen — that is
the Pillar 1 debt, but it's a week, not an afternoon.)

---

## (d) Pillar Scorecard (systems lens, 1-5)

| # | Pillar | Score | One-liner |
|---|--------|-------|-----------|
| 1 | Outstanding gunplay | **3** | World-class feel plumbing (RPM accumulator, recoil model, travel time) carrying a split damage grammar, a WW2 default loadout, and no DESIGN-4.3 asymmetry. |
| 2 | Atmosphere | **4** | Systems sell it — chickens as noise traps, weather-scaled ears, campfire beacons, crater water — atmosphere is *mechanized*, not just painted. |
| 3 | Freedom / escalation not fail-states | **3** | The architecture (finite hunters, abort-anytime exfil, one-way alert memory) is exactly right, but the COMBAT-stamp bug forces escalation on first blood — stealth is currently a fiction. |
| 4 | The squad is the RPG | **4** | Learn-by-doing on the man, role-gated credits, skills-die-with-him — genuinely the game's best economy; docked for curve/credit-rate mismatch and the dead demolitions path. |
| 5 | Fail forward | **4** | Bleed-out/revive chain, emergency exfil at −50, all-or-nothing commit, opt-in Iron Man — failure is priced, not fatal; free instant replacements slightly cheapen the fall. |
