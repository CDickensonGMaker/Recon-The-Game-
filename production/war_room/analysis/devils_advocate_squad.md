# Devil's Advocate — Squad Follow/Sight Proposal (2026-07-19)

Read in full: `scripts/allies/ally_base.gd` (1066 lines), `scripts/player/player.gd:1-30`.
Cross-checked: `scripts/enemies/enemy_base.gd` (SIGHT_CAP consts, move_speed usage),
`scripts/squad/squad_system.gd` (SQUAD_SIZE=8), `production/adr/ADR-005-detection-beacon-witness-rule.md`,
`production/GAME_GUIDE.md:42` (fairness/telegraph law), `data/weapons/m16a1.tres:20` (max_range 460).

## Ranked holes

### 1. 140m flat ally acquisition can trigger the mission alarm without player input — violates ADR-005
`ally_base.gd:457-478` (`_find_target`), `:641-699` (fires once `has_line_of_sight` true), `:933` (`NoiseBus.emit_noise(GUNSHOT...)`).
Allies have **no alert tier** (comment at `:41-42` says so explicitly) and default `weapons_free = true`
(`:119`). Raising acquisition from flat 60m to up to 140m open means an ally can spot, aim-settle
(0.45-0.9s, `:477`), and open fire on an enemy the player never saw, at a range where the player's own
LOS/FOV may not reach. That gunshot is a **witnessed hit** on the enemy side (`ADR-005:36-38`) which
stamps `EnemyBase.last_combat_contact_ms` — "**THE alarm: mission-level escalation keys exclusively off
this beacon**" (`ADR-005:40`). An ally's private 140m spot can therefore yank the whole AO into COMBAT
escalation (QRF pool, etc.) while the player was playing quiet. That is not a fudge-factor nitpick, it
directly undermines Pillar 3 (freedom, stealth optional) and the ADR-005 witness contract, which was
written specifically so *unwitnessed* player action doesn't auto-alarm. The proposal note "NO fudge
factor" makes this worse, not better — a fudge factor is exactly what would let allies see far without
unilaterally deciding to shoot. Needs a cap or a hold-fire-until-player-in-contact gate, not just LOS.

### 2. Formation hysteresis gates SPEED, not DIRECTION — 180° turn teleports every slot
`ally_base.gd:592-604`. `dir` is recomputed raw from `player.velocity.normalized()` every frame with zero
smoothing. The proposed enter/exit hysteresis (3.2 / 1.5 m/s) only debounces the FOLLOW-vs-HUDDLE
transition; it does nothing to `dir` itself. A player standing still then snapping 180° (or just
strafing hard enough to flip forward-velocity sign) instantly flips `dir`, and every slot recomputes at
`global_position - dir*(3.5*file_slot) + side*lateral` — for `file_slot` up to 8 (`SQUAD_SIZE=8`,
`squad_system.gd:12`) that's a **28m instant relocation of the target slot** for the last man in file,
on every direction reversal, hysteresis or not. The 1.5s slot-position lerp (game designer's proposal)
would help IF it's applied to `slot`, but nothing in the brief says the hysteresis band covers direction
— confirm the lerp target explicitly is `slot`, not just entry/exit state, or this ships unfixed.

### 3. move_speed is one shared field used in 5 non-follow codepaths — a blanket 4.5→5.8 bump reaches all of them
`move_speed` (`:9`) drives: unstick sidestep `:57-58`, combat strafe `:682-683` (×0.6), cover
duck-and-dodge `:749-750` (**full speed, no ×0.6**), `_move_toward` `:866-867` — which is *also* called
by combat's lost-sight chase (`:702`) and the cover-rush sprint (`:727`), not just the FOLLOW branch
(`:607`). If the base var is edited in place (the easy implementation), the coward's cover-dodge speed,
the sprint-to-cover rush, and the stuck-watchdog sidestep all silently jump ~29%, none of which the
game designer's numbers were tuned against (enemy `move_speed` stays 4.0, `enemy_base.gd:13`). The
catch-up multiplier must be a **separate scalar applied only inside the FOLLOW/IDLE branch**, not a
rewrite of the shared field — and even then, 5.8×1.35 = 7.83 already exceeds the stated 7.8 cap, so the
"1.35" and "7.8 cap" as stated are inconsistent; one of the two numbers is wrong.

### 4. New deadzone stacks on top of `follow_distance=5.0`, which the proposal never touches
`follow_distance: float = 5.0` (`:96`) is the ONLY threshold gating `_move_toward` vs `_settle` today
(`:606-609`). The proposed ring/file deadzone (2.5m / 3.0m) is a *second*, smaller, unlinked threshold
that would need to fully replace it or the two disagree about when a man has "arrived." Leaving
`follow_distance` in place while a new deadzone constant governs the same decision is exactly the
FOSSIL LAW's target pattern (CLAUDE.md "NO MORE DRIFT" / ADR-023) — this project has a probe
(`tests/test_fossils.tscn`) that will flag the loser as dead weight, but only if it's actually
unreferenced; if both stay wired (one checked first) it's worse — a live footgun, not a fossil.

### 5. Micro-patrol has no stated per-frame distance re-check → drift compounds under sprint
The proposal describes a *committed* 2-4s micro-patrol (walk 1.2m, idle-scan 1.5-3s) triggered once
inside the deadzone. `_execute_idle` recomputes `dist` every physics tick today (`:591-609`), so if the
micro-patrol behavior does NOT re-check `dist > deadzone` every frame and instead runs its full 2-4s
script uninterrupted, a player who breaks into SPRINT (8.0 m/s, `player.gd:6`) mid micro-patrol can open
up to 32m before the next re-evaluation. The proposal *does* call out "does not collapse on sprint
(widens to 4.0m)" as the intended override, but that's a **widen**, not a bypass — it still doesn't
force an every-frame distance re-check, so the timing has to be verified, not assumed, or the "does not
collapse on sprint" rule is decorative.

### 6. Squad size 5 vs 8 — file spacing math already produces a 28m column at 8 men, untested against 140m sight
`slot = player_pos - dir*(3.5*file_slot) + side*lateral` (`:600-604`): at `file_slot=8` the last man
sits 28m behind the player. Combined with finding #1, the tail-end-Charlie of an 8-man file is now
individually eligible to acquire targets up to 140m past the player's position — call it 168m worst-case
separation between "what triggered contact" and "where the player is standing." At squad size 5 the
column is 17.5m deep — the same class of bug, smaller blast radius. Neither number appears tested
against the arena's actual jungle sightline geometry; both are pure formula extrapolation.

## What a "squad feel" probe would be lying about
A headless probe can verify: slot math (no NaN, correct file offsets), deadzone entry/exit thresholds
fire at the right speeds, catch-up multiplier respects the 7.8 cap, sight-cap delegation returns the
right numbers for weather/veg/flare inputs. **It cannot verify** whether the resulting motion *reads*
as a disciplined fireteam vs. a herd of NPCs doing local random walks that happen to stay in a box — that
is a felt, visual judgment (per CLAUDE.md's own "judge LOOK by Caleb's EYES not engine counts" rule
already established for world-build). Any probe that reports "squad feel: PASS" is lying about having
tested the thing it's named after; it can only certify the numeric contract, not the feel.
