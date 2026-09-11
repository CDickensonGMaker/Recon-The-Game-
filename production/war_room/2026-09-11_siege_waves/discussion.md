# Discussion — smaller waves (2026-09-11)

## Agreed without argument
- The ramp lives on the MATERIALIZED cap, not the roll. A 45-man night still fields 45 men; they
  arrive as a tide. Held cells thaw as the dead buy room — the mechanism already existed
  (`_thaw_held_cells`), the wave is a moving ceiling on it.
- `--siege-waves-off` is the A/B. One flag, same seed, same map, same garrison.
- The cost side IS the design side: what the laptop pays for is men who are near, animated and
  firing at once. A wave shape that keeps that number small is the pre-warm and the AI LOD doing
  what they were built for.

## Game designer vs systems designer — the end of the ramp
Game designer wanted `WAVE_CAP_END` at 26: "the last wave should still be a wave, not the old
wall." Systems designer measured it: with 27 men already materialized the cap was never
re-entered, no held cell was ever released, kills went flat and the night ran to dawn every time.
**Resolved for the systems designer:** `WAVE_CAP_END = LIVE_CAP` (50). The ramp decides how FAST
the wall arrives, not whether it does. The wall is the sacrifice the devil's advocate named; it
still comes, three minutes in.

## Devil's advocate vs everyone — what the numbers are
DA: every A/B row is a garrison-only night. No one disputed it. The numbers say what the ramp does
to the machine and to the garrison; they cannot say what it does to HIM at the wire with an M60.
The feel numbers (`WAVE_CAP_START 8`, `WAVE_RAMP_S 180`, `SAPPER_HOLD_S 40`) go to the Summoner as
open rulings, not as findings.

## The find nobody summoned the council for — the stall
Pacing the assault took away the flood, and the flood had been hiding a night that could not end.
Three defects, none of them in the wave code, all measured by the per-man dawn dump:
1. **Spent sappers stood 26 m out until dawn.** `SapperCharge._withdraw` left `assault_driven`
   up forever; he reached the withdraw point and stood on it, driven, at full health. Six of them
   on every paced night. Fixed: the charge releases his legs at the withdraw point
   (`_tick_withdraw`), and `_reaim_stalled` sends a spent sapper back at the wire like any other
   man with no objective (still silent — he carries no gun in this design, see open ruling 4).
2. **The stuck watchdog was blind to a wall.** `_update_unstick` read "wants to move" off
   `velocity`, which is lerped from last frame's POST-slide value — a man pushing square into
   the parapet has it eaten to ~0 every frame and never read as wanting to move. Fixed: legs
   record the speed they were ASKED for (`_move_intent`), the watchdog reads that.
3. **A pinned far man promoted, then demoted 2 s later into the same wall.** Fixed: `_pin_promoted`
   holds the near brain until his objective is reached or dropped.
Plus the two from the earlier pass: the bearing-only breach re-aim (`BREACH_REAIM_M`) and the
arrive-and-wait re-aim (`_reaim_stalled`).

DA's point stands: these predate the council and ship with the flat cap too. The waves get no
credit for finding them beyond having removed the thing that hid them.
