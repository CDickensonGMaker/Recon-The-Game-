# DECREE — smaller waves for the assault (2026-09-11)

## The judgment
The assault arrives as a TIDE, not a wall. The roll is unchanged — a 45-man night still fields 45
men — but the cap on MATERIALIZED men opens at `WAVE_CAP_START` (8) the moment the probe becomes
the assault and climbs linearly to the full `LIVE_CAP` (50) over `WAVE_RAMP_S` (180 s). Held cells
thaw as the dead buy room. Sappers are held for `SAPPER_HOLD_S` (40 s) so wave one is riflemen at
the wire and the demolition party comes in behind them with the pressure already on. Probes are
exempt — eleven men holding off in the dark is already the small wave. `--siege-waves-off` is the
one-flag A/B.

**Shipped in `scripts/missions/siege_director.gd`** (`wave_cap`, `waves_enabled`, `wave_status`,
`survivors_status`, cap-aware `_enforce_live_cap` / `_light_check` / `_thaw_held_cells`) and read
by the printer's `[WAVE]` row (`scripts/dev/fps_printer.gd`).

## The measurement — paired, back to back, same seed, garrison only
| | paced (waves ON) | flood (`--siege-waves-off`) |
|---|---|---|
| the night ends | **broken at t+139 s, 22 of 45 down** | broken at t+71 s, 23 of 45 down (+ OVERRUN) |
| near-tier peak | **19** | 38 |
| fps during the assault (per 5 s window) | **25 – 101, most windows 50–90** | 13.6 – 30.6 |
| worst frame | 41 – 97 ms | 76 – 98 ms |
| 1% low | 10 – 29 fps | 10 – 13 fps |
(second pair, `wp_on2` / `wp_off2`; the first pair read the same shape: near peak 15–18 vs 38–39.)

The ramp does what it was asked to on the machine: the expensive tier — men near, animated, firing
— stays at a dozen instead of forty, and the assault runs at 2–3× the frame rate. And the night
still ends, an hour later than the flood's, with the same body count.

## What the council actually found
Pacing the assault took away the flood, and the flood had been hiding **a siege that could not
end**: every paced night ran to dawn with 14–31 men alive and the kill count flat for four minutes.
Five defects, none in the wave code, each read off the per-man dawn dump and fixed:
1. **Spent sappers stood 26 m out at full health until dawn** — `SapperCharge._withdraw` never gave
   his legs back. Now he clears his own fuse, then joins the attack **with the PPSh he already
   carried** (his ruling, see below). `sapper_charge.gd:_tick_withdraw`.
2. **The stuck watchdog was blind to a wall** — it read "wants to move" off a velocity the slide had
   already eaten. Now reads the commanded speed (`_move_intent`). `enemy_base.gd:_update_unstick`.
3. **A pinned far man promoted, then was demoted 2 s later into the same wall** — `_pin_promoted`
   holds the near brain until his objective is reached or dropped. `enemy_base.gd:_lod_decide`.
4. **Bearing-only breach re-aim** sent squads through a hole on the far side of the compound —
   `BREACH_REAIM_M` (70 m): a hole is a way in for the men in front of it.
5. **Arrive-and-wait** — a man who reached his objective with no target stood ALERT in the dark;
   `_reaim_stalled` sends him back at the compound every 6 s.
Plus `AILod.mean_near` deleted (born dead 9/09, the fossil gate is green again).

## His rulings taken this session
- **"he needs a gun and just joins the attack after placing a bomb."** Done: `silent_infiltrator`
  is lifted at the withdraw point, he is re-aimed at the compound undriven, and `_reaim_stalled`
  treats him as any rifleman. The sapper `.tres` descriptions say so now.

## Open for him — feel numbers, none measured with him on the M60
1. `WAVE_CAP_START = 8` — the first thing he sees. Hell Let Loose's "five guys at once" was the
   brief; 8 is a squad and a half.
2. `WAVE_RAMP_S = 180` — three minutes from the first wave to the full wall. Too slow reads as a
   small night; too fast is the flood again.
3. `SAPPER_HOLD_S = 40` — how long the riflemen have the wire before the satchels come.
All three are one-line constants in `siege_director.gd`. His siege playtest is still the only gate.

## Sacrificed, named
The wall — 45 men standing up together at the wire — is gone from the first three minutes. It
still comes at the top of the ramp. And the paced night is longer (139 s to the break vs 71 s);
that is the design, but it is more time under fire for the garrison, and the flat-cap break was
the only reason five old AI stalls never showed.

## Gates (all green, headless, this tree)
`probe_ai_lod` 13/13 · `test_sapper_assault` · `test_siege` · `test_fossils` (28 = baseline) ·
`test_firebase_defense` · `test_demo_arc`.
