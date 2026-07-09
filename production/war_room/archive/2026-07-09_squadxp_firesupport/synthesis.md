# THE DECREE — Living Squad XP + Radio Fire Support (2026-07-09)

The council (game-designer, systems-designer, technical-director, devil's-advocate) convened on the Summoner's
query. Full analyses in `analysis/`. The four converged; the Arbiter weaves and decrees.

## Resolution — the core tension (barracks vs use-based) is dissolved by the PLAYER_SKILLS seam
`skill_catalog.gd` already splits `PLAYER_SKILLS` (small_arms/sniping/silent_movement — the player's own body)
from MOS skills (a squadmate's role). We ride that seam so the two economies **never double-dip**:
- **Squad MOS skills grow by USE (learn-by-doing)** — the emotional spine (Pillar 4). Field-earned only.
- **team_xp (barracks) buys the PLAYER's body skills + ATTRIBUTES** (st/ag/al). Kept as the player's lever.
- **Use-XP NEVER touches attributes.** Skills grow, stats don't → no soldier becomes irreplaceable → no hoarding
  (Devil's R2). Growth stays cheap/shallow (existing `max: 8`, generous starting roll).

## Decree — Living Squad XP
1. **No more blank recruits.** `generate_member` rolls: MOS skill guaranteed at **L1–3** (scaled by governing
   attribute), plus **0–2 random extra skills** weighted by `al`. Every recruit has a face at spawn. A rookie is
   ~70% of a vet (Devil's R2 — replaceable), the gap reads *in combat* (tight bursts vs spray, already skill-wired).
2. **Per-soldier growth, in place.** Add `xp:0` and `skill_uses:{}` to the member dict (which IS the roster object).
   One choke-point `SquadRoster.credit_use(member, skill, n)` + `SkillCatalog.uses_for_level()` curve
   (cumulative 10/25/45/70/105/155/225 → cap L8). ~2–3 missions to L3, ~15+ to L8.
3. **Hooks land on existing attribution sites** (no signal re-plumbing):
   - kill → `small_arms` (or `sniping` if the shot was long/ADS): `EnemyBase.take_damage` where `attacker` is in
     scope (allies pass `self`). Also finally increments `member.kills`.
   - revive → `medic` (`squad_system` revive) · point warning → `detect_ambush` (`_point_scan`) ·
     fire-mission → `fo_fac` (`mission_director` dispatch).
4. **Grind-proof by structure** (Devil's R1): finite enemies per mission, revives capped 2/mission, credit is a
   capped per-event bump — no farm loop. Attributes untouchable by use closes the "bank score → buy stats" exploit.
5. **VISIBILITY is 90% of the value** (Game-designer): a **promotion toast at the moment of the deed**
   (`PIG — SMALL ARMS ★III`, reuse `director.toast`), an earned **rank prefix** by missions survived
   (PVT→PFC→CPL→SGT), and a **KIA memorial line at debrief** (name/nick/rank/kills). Silent growth = no attachment.
6. **Permadeath = ceremony, not sunk-cost** (fail-forward, Pillar 5). Cheap/shallow growth + the memorial make loss
   land as story. (Stretch: RTO recoverable as a radio pickup on death — fail-forward, Devil's R8. Follow-up bead.)

## Decree — Radio Fire Support ("make it real")
7. **Expose the built-but-hidden CBU** as the 6th call (budget key `cbu`, `slot_6` input, HUD row, dispatch via the
   existing `_launch_flyby(target, CASAirplane.Ordnance.CBU)`). Budget **1, raid profile only** — escalation, not
   entitlement (Pillar 3).
8. **`fo_fac` earns its keep** (fuses both proposals — the RTO gets better by doing): it now **tightens scatter**
   (`lerpf(1.0, 0.45, fo/8)`) on top of the existing cooldown cut, +1 mortar round at fo≥5. Losing a maxed "STEEL
   RAIN" radioman becomes the game's most painful death — Pillar 4's thesis.
9. **Danger-close is the beating heart** (Game-designer) AND the crux risk (Devil's R7): a **"DANGER CLOSE —
   CONFIRM" second keypress** when the aim point is near a living squadmate, plus **asymmetric friendly fire** —
   allies take ~0.4× blast (or duck), the player stays fully vulnerable. Strikes threaten but don't delete your veterans.
10. **Per-mission crater ceiling** (Devil's R9 perf): the shipped cap is per-strike; add an aggregate cap so more
    exposed ordnance can't re-create the chunk-rebuild regression.

## Save compat
All new fields read via defaulted `.get()`; `ensure_roster` back-fills `xp`/`skill_uses` on load. Old `user://`
saves load clean (Technical-director: no forced SAVE_VERSION bump; back-fill is enough).

## Tradeoffs named (no free lunch)
- Use-based means **less direct player control** over squad builds — accepted, in exchange for emergent attachment.
- **Two economies persist** (barracks + use) — the PLAYER_SKILLS seam keeps them from double-dipping.
- **Asymmetric danger-close** is a small realism concession — accepted, to protect the veteran the player loves.
- Fire support stays **scarce** (0–3 calls) so it never becomes the win-button that would gut Pillar 1 gunplay.

## Build order (today, on `overnight-claude`, validate+commit each)
A. Squad XP core: (1) start-roll + fields → (2) curve + `credit_use` → (3) 4 hooks → (4) promotion toast + rank + KIA memorial.
B. Fire support: (5) expose CBU → (6) fo_fac scatter/mortar → (7) danger-close confirm + asymmetric FF → (8) crater ceiling.
