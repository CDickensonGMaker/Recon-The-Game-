# SYSTEMS DESIGNER — Living Squad XP + Radio Fire Support

*Lens: mechanics / economy / balance. All numbers concrete and tuned to ship today.
Ground truth verified against `skill_catalog.gd`, `squad_roster.gd`, `campaign_state.gd`,
`mission_director.gd`, `mission_generator.gd`, `cas_airplane.gd`, `RECON_ADAPTATION.md`.*

---

## 1. LIVING SQUAD XP

### 1.1 Starting-skill roll (in `SquadRoster.generate_member`, after attrs are rolled)

Governing attribute per skill (the stat that "carries" the skill):

| Skill | Gov attr | Rationale |
|---|---|---|
| small_arms, sniping, silent_movement | **ag** | hands / feet / steadiness |
| detect_ambush, medic, fo_fac, demolitions | **al** | wits / alertness / training |

**Rule A — guaranteed MOS skill.** Every recruit arrives already competent at his job:
```
gov  = gov_attr(MOS_SKILL[mos])
L_mos = 1 + int(gov >= 120) + int(gov >= 155)      # → 1..3
skills[MOS_SKILL[mos]] = L_mos
```
So a sharp point man (al 150) starts DETECT_AMBUSH 3; a green one (al 95) starts at 1.

**Rule B — bonus skills, count keyed on `al` (the "savvy" stat).** Roll `r = randi(1,100)`:

| al bracket | 0 extras | 1 extra | 2 extras | 3 extras |
|---|---|---|---|---|
| al < 100 (rookie) | 65% | 35% | – | – |
| al 100–139 | 25% | 55% | 20% | – |
| al ≥ 140 (veteran) | – | 45% | 45% | 10% |

Each extra: pick a skill **not already owned** from a weighted pool (universal soldier skills
weighted highest so everyone can shoot/sneak):
`small_arms ×3, silent_movement ×3, detect_ambush ×2, medic ×1, fo_fac ×1, demolitions ×1, sniping ×1`.
Each extra starts at **level 1**.

Result: nobody arrives blank (fixes the `skills:{}` empty-roster problem), specialists feel like
specialists, and high-`al` men read as grizzled without touching their attributes. Cap total starting
levels so no rookie is a god: MOS skill ≤3, extras ≤1 each.

### 1.2 Per-soldier XP + learn-by-doing curves

**Data:** each member gets `skill_uses: {skill_id: float}` (use-points accumulator). A skill auto-levels
when its accumulator crosses the threshold for its **current** level. Level cap **8** (matches
`SKILLS[*].max`). Diminishing returns baked into a rising cumulative table:

| Reach level | Cumulative use-pts | Δ from prev |
|---|---|---|
| L2 | 10 | 10 |
| L3 | 25 | 15 |
| L4 | 45 | 20 |
| L5 | 70 | 25 |
| L6 | 105 | 35 |
| L7 | 155 | 50 |
| L8 (cap) | 225 | 70 |

Formula if you prefer code over a const table: `Δ(L→L+1) = 10 + 5·(L−1)` for L≤4, then `×1.4` steps.

**Use-credit per event** (how many use-points an action grants the acting soldier):

| Skill (MOS) | Event that credits it | Use-pts | Anti-grind gate |
|---|---|---|---|
| **small_arms** (PIGMAN/RIFLEMAN) | enemy KILL by that soldier w/ small arms | **+1** | only genuine hostile deaths (engine already gates via `take_damage` death); no credit on already-downed |
| **sniping** (SNIPER) | KILL at range **≥120 m while ADS** | **+1** | close kills route to small_arms instead → natural specialization, no double-count |
| **detect_ambush** (POINT) | a `_point_scan` warning that resolves to a **real** enemy inside the warned radius | **+1** | rising-edge only, deduped per enemy group — NOT per scan tick |
| **fo_fac** (RTO) | fire mission that lands **≥1 effect** (kill/suppression) on a hostile | **+2** | wasted calls into empty jungle credit **0** — ties growth to *effective* use |
| **medic** (MEDIC) | successful revive of an **enemy-downed** teammate | **+3** | `REVIVES_PER_MISSION = 2` hard cap; no friendly-down mechanic exists → can't farm |
| **demolitions** (GRENADIER) | charge planted/detonated on an objective | **+2** | objective-gated (1–3/mission) |
| **silent_movement** | per contact **AVOIDED** (stealth economy) | **+1** to POINT + player | capped 3/mission |

**Per-mission yield is roughly flat (2–6 use-pts/skill), thresholds rise.** Consequence:
L1→L3 in ~2–3 missions (fast, satisfying early), L7→L8 takes ~15+ missions (elite is earned).
This is exactly RECON's "shallow by design" (RECON_ADAPTATION L176: 35 pts → +5%).

**Kill-farming is structurally impossible** because generated missions spawn **finite** enemies
(`mission_generator`: 2–10 per group, fixed). You cannot respawn-farm. Escalation reinforcements
exist but each raises `threat_level` (campaign heat, `on_mission_end`) — grinding *costs* you.
**Revive-farming** is blocked by the 2/mission cap + enemy-inflicted-only requirement + no way to
wound your own men.

Auto-level on credit:
```
skill_uses[id] += pts
while skills.get(id,0) < 8 and skill_uses[id] >= THRESHOLD[skills.get(id,0)+1]:
    skills[id] += 1
    toast: "%s — %s ▲ %d" % [nick, SKILLS[id].name, skills[id]]   # diegetic feedback, Pillar 2
```

### 1.3 Fate of the barracks shared `team_xp` — **HYBRID (repurpose, don't delete)**

Skills and XP must never touch the same number (no double-dip). Clean split:

- **SKILLS → earned in the field only** (learn-by-doing above). This *is* Pillar 4 — the squad
  improves by DOING. `buy_skill` **stops spending `team_xp` on squadmate MOS skills**.
- **`team_xp` → a requisition / training currency** with its own sinks that never overlap skills:
  - **Attributes** (RECON-faithful): `buy_attribute` stays — 100 pts → +5 st/ag/al, cap 200. Keep.
  - **Extra fire-support charge** before a mission (e.g. +1 mortar = 80 pts) — feeds §2.
  - **Medevac** a bleeding-out veteran at debrief so he isn't KIA (saves attachment; Pillar 5).
- **Minimal shippable line for TODAY:** keep `buy_skill` working **only for the player's own three
  `PLAYER_SKILLS`** (his body — small_arms/sniping/silent_movement), make **squadmate** skills
  learn-by-doing only. `buy_attribute` unchanged. Zero double-dip, least code.
  *(Better next step: give the player the same learn-by-doing loop — `player_data` already has
  `skills:{}` — and demote `team_xp` to pure requisition. Not required day one.)*

The team-pool debrief math (RECON_ADAPTATION L134–142) stays as the **`team_xp` faucet**; it no
longer buys skills, it funds requisition/attributes. Optionally deposit each member's *share* into
`member.xp` for the **retirement mechanic** (L143: near-cap veterans rotate stateside — permadeath-lite).

### 1.4 Data model + save compatibility

Add to `generate_member` dict **and** `player_data`:
```
"xp": 0,                 # lifetime, for retirement/service-record flavor
"skill_uses": {},        # skill_id -> float use-points  (drives auto level-up)
```
`skills:{}` **shape is unchanged** → save-compatible.

**Persistence:** bump `CampaignState.SAVE_VERSION 1 → 2` and add a `_migrate` branch that backfills
`xp:0, skill_uses:{}` on every roster member + `player_data` (the code's own comments demand a real
migration branch rather than silent half-load). Loader reads are additive/defaulted
(`m.get("skill_uses", {})`), so old v1 saves load clean.

### 1.5 Attributes: growth too? — **No. Skills only.**

- Skills grow by doing; **attributes stay purchase-only** (`team_xp`, 100/pt, +5, cap 200).
- Rationale: st/ag/al are *who the man is*, rolled at birth. Letting them grind erodes the
  "a 130-St pigman is a tank, a 91-St rookie is fragile" identity (RECON_ADAPTATION L32) and would
  strip the one meaningful `team_xp` sink. Keep attributes rare, bought, precious.
- Optional flavor (NOT today): a soldier who survives N missions earns a one-time +Al "combat wisdom."

---

## 2. RADIO FIRE SUPPORT

### 2.1 Are the current budgets right? — **Mostly yes; leave the shape, tune fo_fac.**

Current per-mission budgets (`mission_generator`):

| Mission (RECON category) | Budget | Verdict |
|---|---|---|
| PATROL / RECON (SECURITY) | `{mortar:1}` (default) | **Correct** — you're not meant to level the jungle |
| ANTI_AA (stealth RAID) | `{mortar:1}` | **Correct** — a satchel job, air would blow the sneak |
| RESCUE (TRANSPORT) | `{napalm:1, mortar:1}` | **Correct** — one panic button |
| VILLAGE_RAID (RAID) | `{bombs:1, napalm:1, mortar:2}` | **Correct** — a real strike package |
| FIREBASE_DEFENSE (HOLD) | `{bombs:2, napalm:1, arty:2, mortar:3, spooky:1}` | **Correct** — set-piece arsenal |

The scaling (SECURITY starved, RAID/HOLD armed) already honors Pillar 3 (escalation, not a win-button)
and the RECON taxonomy (RECON_ADAPTATION L168). **Do not inflate these.**

### 2.2 fo_fac (RTO's learned skill) should do more than cut cooldown

Today: `_cas_cooldown = maxf(10.0, 25.0 - 2.0·fo)` (fo0→25s, fo8→10s). Keep that, **add**:

1. **Scatter → accuracy (the headline RTO payoff).** Multiply every impact-offset range by
   `scatter_mult = lerpf(1.0, 0.45, fo/8.0)`:
   - Arty `±18 → ±8` at fo8; mortar cluster `±8 → ±3.6`, spot `±15 → ±6.75`.
   - A veteran RTO calls **tight** fire — this is what "the radioman got good" *feels* like, and it's
     the enabler for danger-close (§2.4).
2. **One extra charge at fo ≥ 5** — `+1 mortar` at mission start only (the RTO "knows the battery").
   One type, small — not a budget explosion.
3. **(Optional) shorter turnaround** — spot-round delay `3.0s → 2.0s` at high fo. Minor polish.

Because fo_fac is now learn-by-doing (**+2 per effective fire mission**, §1.2) and budgets are ~1–3
calls/mission, an RTO climbs fo over a campaign — the *same radioman* visibly sharpens. Pillar 4.

### 2.3 Expose CBU — **its own budget key + menu line, reuse `_launch_flyby`**

CBU is already built (`cas_airplane.gd`: 16 bomblets, 22 m spread, 55 dmg/15 falloff/5 m each, no
fire, one crater) but bound to no menu. It is the **"troops in the open" anti-personnel** answer,
distinct from SNAKE-EYE bombs (hard target) and napalm (area denial + fire).

Recommendation — cleanest buildable-today:
- Add key `"cbu"` to the `fire_support` dict; generator grants it on RAID/defense only:
  VILLAGE_RAID `+cbu:1`, FIREBASE_DEFENSE `+cbu:1`. Nothing to SECURITY missions.
- Expose it as a **6th line in the T-menu**, dispatched via existing
  `_launch_flyby(target, CASAirplane.Ordnance.CBU)` (the F-4 flyby path already handles CBU).
  Bind to `slot_6` if it exists; otherwise a menu-cycle on the bombs family (Snake-Eye ↔ CBU).
  Toast: `"FAST MOVER — CLUSTER RUN — GET DOWN (%d left)"`.

### 2.4 Danger-close rules (keeps CBU/arty from being a win-button — Pillar 3)

- Define per-ordnance danger radius: **CBU 40 m, arty 30 m, bombs 25 m, napalm 35 m, mortar 20 m**.
- If `_cas_ground_target()` is **within** that radius of the player, the first press arms a
  **"DANGER CLOSE — CONFIRM [T]"** prompt; the strike only launches on a **second** press.
- Friendly fire is **LIVE**: bomblets/HE call `apply_explosion_damage(..., null)` (no attacker
  filter) → they hurt the player and squad. This is the self-limiter — you *can* wipe a position on
  top of yourself, and it'll cost you.
- **No laze / no reach-around:** `_cas_ground_target()` raycasts from the camera, so you can only
  strike ground you can **see**. You cannot erase an objective from behind a hill. Keeps it tactical.
- CBU has **no fire and one crater** → it clears infantry but does **not** destroy hard objectives;
  you still plant charges. A support tool, never an "I win." Fits Pillar 3.

### 2.5 Escalation fit (already wired, note the loop)

Every strike emits `NoiseBus.EXPLOSION` → draws enemies (escalation). `on_mission_end` bumps
`threat_level +0.05` when `kills ≥ 12` → louder AO = harder next mission. The **campaign economy
already taxes over-reliance** on fire support; no per-call nerf needed. Recommend the "loud" nudge
also counts fire-support kills so a bomb-heavy op raises heat like a firefight does.

---

## Buildable-today checklist (systems)
1. `generate_member`: add starting-skill roll (§1.1) + `xp:0, skill_uses:{}` fields.
2. New `SquadRoster.credit_use(member, skill, pts)` helper: accumulate + auto-level + toast.
3. Wire credit calls at the existing hooks (kill attribution, `_point_scan`, revive, fire dispatch, avoided-contact).
4. `buy_skill`: restrict `team_xp` spend to player's `PLAYER_SKILLS` only.
5. `CampaignState`: SAVE_VERSION 1→2 + `_migrate` backfill.
6. `mission_director`: fo_fac scatter mult, +charge at fo5, danger-close confirm, CBU line.
7. `mission_generator`: add `cbu:1` to village/firebase budgets.
