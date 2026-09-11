# Systems designer — smaller waves (2026-09-11)

**The mechanism already exists and is tuned as a flood.** `_enforce_live_cap` holds a marching cell
(physics off) when materialized men reach the cap; `_thaw_held_cells` releases held cells as the
dead buy room, one cell at a time and only while its strength fits. A wave schedule is the cap made
a function of time: `wave_cap()` ramping from `WAVE_CAP_START` to `LIVE_CAP` over `WAVE_RAMP_S`,
read in the two places the constant was read. `_light_check` (an illum round materializing lit
cells) reads the same cap or an illum round becomes a button that fields the whole assault.

**Two contracts kept.** ADR-035 §2's pop ring is untouched (cells still materialize at 120 m on the
slice); §4's ledger is untouched (`live_strength()` counts held cells at paper strength, so the
ratio still measures the roll).

**The trap the first cut walked into, and it is worth recording as a class.** Cap END 26 with a
force of 45: the cap counts EVERY materialized man — the base of fire at its 90 m standoff and the
sappers who already went through — so at 27 present against 26 the last cells could never fit
(`c.strength > room`) and were held forever. A cap that is not the full force is a cap that can
deadlock the moment the men it lets through refuse to die. The ramp must top out at the ceiling.

**The cost side.** What the laptop pays for is men near, animated and shooting at once. Paced
arrival keeps the near tier at 13-20 instead of 37-39; mean fps 109-112 vs 79-84 headless, floor
64-76 vs 35-39. That is the pre-warm and the AI LOD doing the job they were built for.
