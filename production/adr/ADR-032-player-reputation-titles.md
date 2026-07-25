# ADR-032: Player progression — hidden reputation, earned rank, armory tiers
**Date:** 2026-07-25 · **Status:** PROPOSED (Summoner decree, awaiting playtest) · **Amends:** ADR-006 (where the score banks), ADR-018 §2 sacrifice note · **Kills:** `SkillCatalog.buy_skill` and every on-screen XP number

## The decree (Summoner, 2026-07-25, verbatim)

> *"i should never see anything about XP but feel the rewards of them"*

> *"only allies learn by doing. the player is earned rewards from their missions by different titles
> they are refered to and than when they go into their armory they will have more options."*

Refined the same day, in order:
1. Slang titles (CHERRY/GRUNT/…) **rejected** — real Vietnam-era US Army enlisted ranks instead.
2. *"the gates as you level up give you less rewards in the armory but they get better when you do
   hit those milestones."* — fewer items per gate, each one bigger.
3. *"we should limit it to like 30 or 40 levels max."* — a capped internal level skeleton.

## Decision — three lanes, one economy

The banked mission score (formerly `CampaignState.team_xp`) is now the player's **hidden
reputation** (`scripts/autoload/campaign_state.gd:26`). It is **never rendered as a number,
anywhere** — and neither is the level derived from it. It surfaces exactly two ways: the rank the
player is addressed by, and what hangs on the armory rack.

| Lane | Who | Mechanism |
|---|---|---|
| Learn-by-doing | **Allies only** | `SquadRoster.credit_use` (`scripts/squad/squad_roster.gd:134`) — untouched by this ADR |
| Rank | Player | reputation → level → title (`campaign_state.gd:62-95`) |
| Armory | Player | `WeaponData.armory_tier` (`scripts/weapons/weapon_data.gd:9`) vs `title_tier()` at the bench (`scripts/levels/armorers_bench.gd:46-53,152`) |

### The skeleton: reputation → level (capped 40) → rank tier

- Faucet unchanged: both AAR bank points route through the ONE helper
  `CampaignState.bank_reputation` (`campaign_state.gd:100-103`), called at
  `scripts/missions/field_director.gd:1202` (patrol banked at the wire) and
  `scripts/main/game_flow.gd:165` (mission-end debrief). Negative scores floor at 0, as before.
- `level()` (`campaign_state.gd:78-82`): quadratic curve `rep_for_level(n) = 75(n-1) + 6(n-1)²`
  (`campaign_state.gd:73-75`), `MAX_LEVEL = 40` (`campaign_state.gd:67`).
- **Score-magnitude evidence** (`scripts/ui/screens/debrief.gd:28-42` — `compute_score`): +25 per
  contact avoided / −25 per detected (a walk registers each spawned group,
  `scripts/missions/mission_state.gd:70-75`), +50 fast success, +75 weapons-discipline (ghost)
  bonus, −damage taken, −100 lost POW. A decent patrol banks **~150**. On the curve that is ~1
  level per patrol early (level 2 costs 81, level 3 costs 174) and ~1 level per 3–4 patrols near
  the cap (level 40 costs 543 over level 39) — exactly the decreed pacing.
- The level is the **pacing skeleton only**. It follows the same law as the reputation number:
  never shown on any screen or toast. The levels BETWEEN rank milestones are RESERVED for a future
  smaller-unlock pass (ammo loadouts, grenade counts, kit variety) — deliberately not built now;
  the skeleton exists so those slots have somewhere to live.

### The rank ladder (tier = index into `TITLES`, `campaign_state.gd:62,68`)

Vocabulary matches `SquadRoster.rank_for` (`scripts/squad/squad_roster.gd:200-215`) — one rank
language in the game, short forms.

| Tier | Rank | At level | Armory unlock (fewer, better) |
|---|---|---|---|
| 0 | PVT | 1 | base kit: M16A1, M1911 (+ captured-weapon rack, untouched) |
| 1 | PFC | 3 | Ithaca 37, M14 — the workhorses |
| 2 | SP4 | 8 | M79, M60 — heavy firepower |
| 3 | SGT | 18 | M70 — the sniper |
| 4 | SSG | 30 | M72 LAW — the crown |

Tier values live in the .tres data: `data/weapons/shotgun.tres:9`, `m14.tres:9`, `m79.tres:9`,
`m60.tres:9`, `m70.tres:9`, `m72_law.tres:9`. M16A1/M1911 and every captured VC weapon
(AK/PPSh/Mosin/RPD/RPG-2) carry the default tier 0 — gating battlefield pickups is NOT this
decree.

### The tell

Promotion is the only visible event: `FIELD PROMOTION: <RANK>` on the field-director toast channel
(`field_director.gd:1203`, `game_flow.gd:166`). The rank word also appears where prose already
addressed the player: barracks status line (`scripts/ui/screens/barracks.gd:44-45`), service
record (`service_record.gd:31-33`), AAR sub-header (`debrief.gd:66`).

### The armory gate

The bench serves `rack_for_tier(CampaignState.title_tier())` (`armorers_bench.gd:46-53`): a
candidate hangs only if its .tres is **complete** (`tres_complete`, `armorers_bench.gd:37-43` —
arms viewmodel on disk, projectile resource on disk when named) AND its tier is earned. A locked
or incomplete weapon is **simply absent** — no greyed-out teases, no numbers. The gun range
(`scripts/levels/gun_range.gd:7-10`) is a dev bench and stays ungated.

**Known art gaps (excluded by completeness, not by name):** `m79.tres:38` and `m72_law.tres:38`
have `model_path = ""` — no first-person arms viewmodels exist
(`scenes/weapons/` holds none for either). Their projectile data is wired
(`data/projectiles/m79_he.tres`, `law_rocket.tres`). The moment the arms models land, they appear
at their tiers with zero code changes.

## Supersedes / corrects

- **ADR-018:80-81** — *"The St/Ag/Al pool survives for the squad only"* is retired: the pool is
  now the PLAYER's hidden reputation; squadmates no longer draw on any shared pool at all. Their
  ONLY growth is learn-by-doing (`credit_use`). ADR-018 §2's "never shown as a number" law
  (ADR-018:35-37) now covers the player's pool and level too.
- **ADR-006:34** — the score still banks 1:1, floored at 0, but into `reputation`, not `team_xp`.
  The scoring terms themselves are untouched.
- **Deleted:** `SkillCatalog.buy_skill` + the SKILLS `cost` fields (fossil law — nothing calls
  either; the ghost audit already flagged it, `production/GHOST_CODE_AUDIT_2026-07-25.md:101`).
  `tests/test_only_liveness_baseline.json:14` still lists it; the next `--write-baseline` run
  drops it (the baseline only shrinks).
- The ally skill-up bark no longer prints a level star (`scripts/allies/ally_base.gd:170` — nick +
  skill name only), closing the last on-screen progression numeral.

## Save migration

Old campaigns keep their pool: load reads `reputation` with fallback to the pre-ADR-032 `team_xp`
key, in both the cfg (`campaign_state.gd:250`) and the SaveData dict (`campaign_state.gd:297`).
No version bump — the shape is a superset read.

## Tradeoffs (no free lunches)

- **The barracks loses its only verb.** With buy_skill dead it is a pure roster/status screen;
  if it stays verb-less it should eventually earn a reason to exist or be folded away.
- **SSG is far** (level 30 ≈ 7,221 reputation ≈ ~48 decent patrols). That is the point of a crown,
  but the number is data, not law — retune `rep_for_level`'s two constants, never add a UI meter.
- **A hidden economy is hard to debug by eye.** The probe carries that weight.

## Probe

`tests/test_reputation.tscn` — ladder order/cap/monotonicity, promotion tell fires exactly at the
gates, save round-trip incl. `team_xp` fallback, per-tier rack contents, incomplete-weapon
exclusion, and a never-a-number sweep of barracks/service record/AAR. Rack completeness contract:
`tests/test_bench_rack.gd`. Learn-by-doing thresholds: `tests/test_skills.gd`.
