# ADR-003: One damage grammar: RECON dice + locational overrides
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends `CLAUDE.md` "Damage System" section (rewrite ordered); completes the damage-unification decree closed prematurely in commit `96114f5`; part of the ADR-002/003 locational-damage family ratified retroactively in the audit #2 decree.

## Context

RECONgame inherited two damage grammars. The Hell of Duty WW2 core shipped flat-modifier
weapons (`[1, 6, 45]` = 1d6+45: high floor, tiny variance), while the RECON RPG adaptation
mandates pure dice pools (`[N, 10, 0]` = Nd10: wide variance, zero modifier). The unification
decree from audit #1 converted the Vietnam arsenal — `m16a1.tres` 5d10, `ak47.tres` 4d10,
`sks.tres` 4d10, `ppsh41.tres` 3d10 — and the bead was closed (`96114f5 "beads: damage
unification closed"`). It was ~80% done. Four flat-grammar WW2 resources survive live in
`data/weapons/`: `thompson.tres:14` [1,6,45] (avg 48.5), `mp40.tres:14` [1,6,38],
`kar98k.tres:14` [1,10,70], `mosin.tres:14` [1,10,68] (avg 73.5), all still player-reachable
via `scripts/levels/combat_lab.gd:283` and `scripts/weapons/viewmodel_editor.gd:73-84`.

The holdover is not cosmetic — it is live on the most common enemy. `data/enemies/vc_rifleman.tres:14`
sets `weapon_path = "res://data/weapons/mosin.tres"` while its own description (line 9) reads
"Local Force guerrilla with an SKS." With `mosin.tres` avg 73.5, `min_damage_mult = 0.85`
(mosin.tres:24), and the TORSO ×2.0 multiplier (`scripts/combat/hitzone.gd:18`), a chest hit
deals ≥125 to the 100-HP player (`scripts/player/health_system.gd:19`): the *basic* patrol
rifleman one-shots the player at ALL ranges, all the time. Meanwhile the elite
`nva_regular.tres` (85 HP, description "with an AK-47", line 9) actually fires `ppsh41.tres`
3d10, avg 16.5 per round (line 14). Lethality is currently determined by data lineage, not design.

The law itself rotted worse than the data. `CLAUDE.md`'s Damage System section — injected into
every session — is false on every line: it teaches HEAD 4x / TORSO 1.5x / LIMB 0.6x, a
`[1, 6, 45]` example, and enemy HP 60-80. Code truth: HEAD is fatal outright
(`enemy_base.gd:1466-1467` sets `amount = current_hp + 999`, bypassing dice entirely), TORSO
is ×2.0, GUT ×1.75 + bleed, LIMB ×0.75 (`hitzone.gd:16-21`), and enemy HP spans 65-85
(`vc_farmer` 65 → `nva_regular` 85). Every session, the injected law taught a dead game.

## Decision

**RECON dice are the SOLE damage grammar. The locational model of record is the code truth
ratified below. All data and documentation conform to it.**

- **Grammar:** every weapon's `base_damage` is a pure dice pool `[N, 10, 0]` (Nd10, modifier 0).
  No flat-modifier damage arrays may exist in `data/weapons/`.
- **Locational model of record** (ratified as-is from `hitzone.gd` / `enemy_base.gd`):
  - **HEAD** — fatal on enemies: `take_damage` bypasses dice with `current_hp + 999`. A headshot is a headshot.
  - **TORSO** — ×2.0.
  - **GUT** — ×1.75 + bleed.
  - **LIMB** — ×0.75.
- **HP of record:** enemy HP 65-85; player HP 100.
- **The four legacy WW2 .tres** (`thompson`, `mp40`, `kar98k`, `mosin`) are deleted, or
  converted to dice grammar if kept as legitimate Vietnam hand-me-downs. No third option;
  no flat grammar survives either way. Purge their references from `combat_lab.gd:283` and
  `viewmodel_editor.gd:73-84` if deleted.
- **`vc_rifleman.tres` loads `sks.tres`** (4d10, RECON dice) — matching its own description.
  The Mosin one-shot dies with this line.
- **Enemy descriptions must match actual loadouts** for every file in `data/enemies/`
  (`nva_regular` "AK-47" vs actual PPSh included: fix the weapon or fix the words, per design intent).
- **`CLAUDE.md` Damage System section is rewritten** to the model of record above (HEAD fatal /
  TORSO 2.0 / GUT 1.75 + bleed / LIMB 0.75, Nd10 example, enemy 65-85, player 100). Per the
  Truth Law (ADR-015), no doc may restate multipliers that a probe hasn't verified against code.
- **Testable acceptance:** grep of `data/weapons/*.tres` shows no `base_damage` with a nonzero
  third element; a headless probe confirms no enemy weapon one-shots the 100-HP player on a
  TORSO hit at any range.

## Consequences

**Buys:** one legible lethality model — designers reason in Nd10 and four zone rules, nothing
else; the basic-rifleman-one-shots-player accident becomes structurally impossible, not just
patched; CLAUDE.md stops teaching a dead game every session; enemy flavor text becomes trustworthy
data again; Pillar 1 (outstanding gunplay) gets a tunable foundation instead of two colliding grammars.

**Costs (named — no free lunches):** the flat grammar's tight damage bands are sacrificed —
Nd10 pools have wide variance, so a 4d10 SKS can roll a limp 4 or a savage 40, and lethality
tuning must now happen through dice count and zone multipliers only. If the WW2 four are
deleted, four working viewmodels/audio hookups are abandoned; if converted, someone owes
conversion + balance passes on weapons no Vietnam mission currently issues. The VC rifleman
gets meaningfully *less* scary at range (73.5 avg sniper → 22 avg SKS), which is the design
intent but is still a felt difficulty drop that playtest R3 must re-read.

**Work created:** decree build-order item 4 ("DAMAGE DATA FINISH") — delete/convert the WW2
four, repoint `vc_rifleman` → `sks.tres`, reconcile all five enemy descriptions with loadouts,
rewrite the CLAUDE.md damage section, and close with a headless probe per the Verification Law
(no bead existed for this at ratification; one must be created and gated per ADR-015).

## Evidence

- `scripts/combat/hitzone.gd:16-21` — MULTIPLIERS: TORSO 2.0, GUT 1.75, LIMB 0.75 (HEAD 4.0 entry is dead — see next); `:78-79` `is_fatal_zone()` = HEAD. **Verified.**
- `scripts/enemies/enemy_base.gd:1466-1467` — `if zone == "HEAD": amount = current_hp + 999` (fatal bypass). **Verified.**
- `scripts/player/health_system.gd:19` — `@export var max_hp: int = 100`. **Verified.**
- `data/enemies/*.tres:10` — max_hp 65 (vc_farmer), 70 (vc_rifleman), 75 (nva_rpg), 80 (vc_sapper), 85 (nva_regular). **Verified.**
- `data/enemies/vc_rifleman.tres:14` — `weapon_path = mosin.tres`; line 9 description claims SKS. **Verified.**
- `data/enemies/nva_regular.tres:14` — loads `ppsh41.tres` (3d10, avg 16.5); line 9 claims AK-47. **Verified.**
- `data/weapons/{thompson,mp40,kar98k,mosin}.tres:14` — [1,6,45] / [1,6,38] / [1,10,70] / [1,10,68]. **Verified.**
- `data/weapons/mosin.tres:24` — `min_damage_mult = 0.85` (one-shot holds at max range). **Verified.**
- `scripts/levels/combat_lab.gd:283`, `scripts/weapons/viewmodel_editor.gd:73-84` — WW2 four still player-reachable. **Verified.**
- Commit `96114f5` "beads: damage unification closed" — closed the unification bead at ~80% done. **Verified** (bead-only commit; conversion commit was `591a5a5` per lead_programmer.md:52).
- `CLAUDE.md` Damage System section — HEAD 4x / TORSO 1.5x / LIMB 0.6x / [1,6,45] / enemy 60-80: false on every line vs the code above. **Verified.**
- `production/war_room/synthesis.md` (wound #5, build-order item 4); `analysis/systems_designer.md` DRIFT-2; `analysis/lead_programmer.md:52-63`.

## Related

- **ADR-002** — locational damage grammar (this ADR's family; audit #2 ratified the pair retroactively).
- **ADR-015** — process laws: Verification Law (probe before close — the law `96114f5` violated) and Truth Law (docs amended by explicit decision only).
- **Beads:** decree item 4 bead to be created and linked under the standing GATE bead; the prematurely-closed unification bead (`96114f5`) is the cautionary record.
- **Pillars served:** Pillar 1 (outstanding gunplay — lethality by design, not lineage); Pillar 5 (fail forward — the player may not be deleted by a data accident at any range).
