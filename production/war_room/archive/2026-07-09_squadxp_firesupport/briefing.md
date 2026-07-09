# WAR ROOM BRIEFING — Living Squad XP + Radio Fire Support (2026-07-09)

## The Summoner's query
Make two things real **today**:
1. **Living squad XP** — every new recruit arrives with *random starting skills* (not blank). Each soldier has
   their OWN XP/progression, separate from the player. They improve by DOING — the more a soldier does a thing,
   the better they get at it (Elder-Scrolls "learn by doing").
2. **Radio-called fire support** — artillery, bombing runs (CAS / F-4 napalm / CBU), mortar strikes — as a real,
   reachable, satisfying RTO-gated system.

## Binding constraints (Pillars — no decree may violate these)
1. Outstanding gunplay · 2. Atmosphere · 3. Freedom (escalation not fail-states) · **4. The squad is the RPG**
(named soldiers who improve, get wounded, and die for real — minimal stats, maximal attachment) · 5. Fail forward.

## Ground truth (from the codebase audit — what already exists)
- **Roster/skills**: `squad_roster.generate_member` creates members with `skills: {}` (EMPTY). `skill_catalog.gd`
  has `buy_skill(member, skill)` writing `member.skills[id]=level+1`, `skill_level(member, skill)`, and a
  `MOS_SKILL` map (POINT→detect_ambush, MEDIC→medic, PIGMAN/RIFLEMAN→small_arms, RTO→fo_fac, SNIPER→sniping).
  Growth today = player spends a SHARED `CampaignState.team_xp` pool in the barracks. Persistence via ConfigFile
  to `user://` (`campaign_state.gd`), roster is `CampaignState.roster` (Array of member dicts).
- **Skill effects already wired**: small_arms (spread/jam), sniping (ADS accuracy), medic (revive), fo_fac
  (fire-support cooldown), detect_ambush (point warning radius), silent_movement (footstep noise). ~6 skills live.
- **Attributes**: st/ag/al rolled RECON 2d100 at generation. Player st/ag used; member al used by point scan.
- **Fire support = ALREADY WIRED** (`mission_director.gd`): RTO-gated `[T]` menu, keys 1-5 →
  bombs / napalm / arty(6-round barrage) / mortar(spot+3) / Spooky gunship. Per-mission budgets set by the
  generator; cooldown reduced by the RTO's `fo_fac`. CAS = `cas_airplane.gd` (Skyraider dive-bomb + **new F-4
  horizontal flyby** + **CBU cluster ordnance, built but NOT exposed to any menu**).
- **Action attribution exists**: ally kills pass `self` as attacker in `take_damage`; revives in `squad_system`;
  point warnings in `_point_scan`; fire-support dispatch in `mission_director`. These are the natural XP hooks.
- Related beads: `ooel` (100 bios + roster system), `r4bk` (squad command controls bug).

## What the council must decree
- Squad-XP model: starting-skill roll, per-soldier XP + use-based growth curves, and **the fate of the barracks
  shared-XP model** (keep as accelerator / replace with pure learn-by-doing / hybrid).
- Fire support: what "make it real" means beyond wired — expose CBU, tie RTO's fo_fac growth to use, radio feel,
  balance (don't trivialize combat), and the escalation/Freedom-pillar fit.
- A concrete, buildable-today implementation plan naming files + reuse points. Conservative, no-mess, no dup systems.
