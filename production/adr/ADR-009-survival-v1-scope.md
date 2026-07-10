# ADR-009: Survival v1 scope: hunger parked, weapon condition kept
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends the Survival v1 ship (commit 0330bba, "PHASES C+D: survival v1"); scopes an unratified system that appears in no design doc (hunger is absent from DESIGN.md, RECON_ADAPTATION.md, and MISSION_DESIGN_RESEARCH.md)

## Context

Survival v1 shipped in commit 0330bba as a two-meter system — hunger and weapon condition — plus
two consumables (rations `[9]`, cleaning kits `[0]`). It was never ratified: hunger appears in no
design document, and neither meter has any HUD affordance (audit #2, "invisible systems" wound).
Audit #2's systems-designer analysis (DRIFT-8) ran the arithmetic and found hunger **incapable of
firing**. The drain is `100.0 / (45.0 * 60.0)` per second — 45 minutes of field time to empty
(`scripts/player/player.gd:316`). The only penalty, a stamina-max multiplier scaling 1.0 → 0.55,
begins **below 50 hunger** (`player.gd:323-326`), i.e. after **22.5 minutes** of continuous field
time. Missions are tuned sub-15-minutes — the debrief's speed bonus pays out under 900 s
(`scripts/ui/screens/debrief.gd:25`). And every hub entry resets hunger AND weapon condition to
100, free ("The firebase takes care of you" — `scripts/main/game_flow.gd:354-361`), so hunger
cannot accumulate across missions either. On a par mission the player exfils around 67 hunger:
the meter, the 2 rations (+45 each, cap 4 — `player.gd:66,255,336`), and the `[9]` key are dead
weight. The 25-hunger warning toast (`player.gd:317-319`) fires ~34 minutes in — effectively never.

Weapon condition, by contrast, **works and is felt**. Every round fouls the action −0.15 (−0.25
in monsoon rain) (`scripts/player/weapon_holder.gd:298-299`); jam chance multiplies by
`1 + (100 − condition) × 0.055` (`weapon_holder.gd:308`). At condition 60 (~267 rounds fired) an
unskilled shooter jams ~4.8% per shot — one stoppage per magazine and a half, felt and fair. It
couples weather to misery (Pillar 2) and makes maintenance a real tactical choice (Pillar 1).
One truth-law note: the comment at `weapon_holder.gd:297` claims jams rise "up to ~5x"; the
formula's maximum is 6.5x at condition 0. Comment must be corrected, not the formula.

Both game-designer and systems-designer analyses converged independently: no pillar is served by
hunger at current mission lengths; condition serves two. The council's choice was park-or-retune,
and retuning a meter for mission lengths the game does not have fails the pillar test.

## Decision

- **Hunger is PARKED.**
  - Remove the drain: delete/disable `_tick_hunger()` and its `_physics_process` call
    (`player.gd:313-319,563`). `hunger_stamina_mult()` must return 1.0 (or the field pinned at 100).
  - **Fields remain in SaveData for compatibility** (`scripts/data/save_data.gd:80,95,117`) —
    no save-format change, no migration.
  - **No HUD claim**: the player-state HUD layer (decree build-order item 3) must NOT show a
    hunger meter. A meter for a dead system violates the r4bk presentation law in reverse.
  - Delete or repoint the hunger warning toast; the `[9]` key is repurposed below.
  - **Re-entry condition:** hunger returns only if mission or operation field time ever exceeds
    ~40 minutes (multi-mission ops without hub return). Re-entry requires a new ADR.
- **Weapon condition is KEPT** as shipped: −0.15/shot (−0.25 in rain), jam multiplier
  `1 + (100 − cond) × 0.055`, free reset at the firebase armorer (`game_flow.gd:357-361`).
  - It **must become weapon-weighted** per DESIGN.md §4.3 ("per-magazine stoppage roll
    (weapon-weighted)"): reliability factor moves into WeaponData — AK forgiving, M16 filthy.
  - Correct the `weapon_holder.gd:297` "~5x" comment to the true 6.5x maximum (truth law).
- **Rations `[9]` remain** as a consumable, redefined as the condition/stamina pick-me-up
  (restore stamina, no longer a hunger antidote). **Cleaning kits `[0]` stay** unchanged.

## Consequences

**Buys:** one fewer invisible simulation to display, tune, and explain; the player-state HUD layer
ships smaller (condition/stamina/breath/consumables — no hunger row); the pillar-serving half of
Survival v1 gets deepened (weapon-weighted reliability) instead of the whole system limping.

**Sacrificed (council law — no free lunches):** "hardcore sim" surface area. A Vietnam game that
does not make you eat sheds a flavor claim some players expect; the C-rations fiction thins to a
stamina consumable. The 0330bba hunger code becomes dead-adjacent weight kept only for save
compatibility, and a future re-entry pays a re-integration cost.

**Work created:** (1) drain removal + toast cleanup in `player.gd`; (2) ration effect redefinition;
(3) weapon-weighted reliability field in WeaponData + `weapon_holder.gd` hookup; (4) comment fix at
`weapon_holder.gd:297`; (5) HUD layer (decree item 3, fmc8 milestone 0 lineage) explicitly excludes
hunger. Items land inside the existing decree build order; the inventory design bead (zet2) should
note `[9]`'s new meaning.

## Evidence

All verified against working tree, 2026-07-10:
- `scripts/player/player.gd:63-68` — hunger/ration fields; `:313-319` — `_tick_hunger()` drain
  100/(45·60)/s + 25-hunger toast; `:323-326` — stamina mult 1.0→0.55 below 50; `:330-338` —
  `_eat_ration()` +45 cap 100; `:255` — resupply cap 4; `:432` — stamina_max × hunger mult; `:563` — tick call.
- `scripts/main/game_flow.gd:354-361` — hub entry resets hunger and weapon_condition to 100, free.
- `scripts/player/weapon_holder.gd:298-299` — fouling −0.15/shot, −0.25 in rain; `:307-308` — jam
  chance × `1+(100−cond)×0.055` (4.8%/shot at cond 60, small_arms 0); `:297` — drifted "~5x" comment.
- `scripts/ui/screens/debrief.gd:25` — <900 s speed bonus (missions tuned sub-15-min); `:23` — kills×10.
- `scripts/data/save_data.gd:80,95,117` — hunger field serialize/deserialize (stays).
- Commit `0330bba` — "PHASES C+D: survival v1 (hunger/condition/rations/kits) + HARD checkpoints".
- War Room audit #2: `production/war_room/synthesis.md` (scope rulings: PARK hunger);
  `analysis/systems_designer.md` DRIFT-8; `analysis/game_designer.md` §hunger pillar test.

## Related

- **Pillars served:** 1 (Outstanding gunplay — jam economy as tactical texture) and
  2 (Atmosphere — rain fouls your rifle). Hunger served none; that is why it parks.
- **ADRs:** ADR-008 (walkable firebase hub — the free reset lives in the hub flow);
  DESIGN.md §4.3 stoppage philosophy (weapon-weighted per-magazine rolls) is the target state.
- **Beads:** zet2 (inventory/backpack design — `[9]`/`[0]` key meanings); fmc8 lineage /
  decree build-order item 3 (player-state HUD layer — condition yes, hunger no).
