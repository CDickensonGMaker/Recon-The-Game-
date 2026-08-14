# THE SIEGE REPLAY — one run, one page (DEMO_TIGHT_40 step 1)

Boot the demo (`demo_game.tscn`), play the day into the night attack, live to the end
card. Everything below changed since your last validated siege and lands in this one
run. Tick what reads right; anything that reads wrong, just note WHAT you saw — the
probes carry the numbers.

## On the walk out (daytime)
- [ ] **Berms and bunkers**: walk INTO a berm-side bunker (posts 0/6/14/35 were the
      four capsule-tight ones; one interior is honestly off-mesh now). Can you enter
      where the garrison stands?
- [ ] **Garrison men walk the real ground** — nobody swimming through berms or walking
      impossible lines (the navmesh rides the actual mound now).
- [ ] **The early napalm beat (~35s)**: a rolling CHAIN of ~60m fire bursts on the
      treeline, not one sky-filling dome. `[`/`]` on the fire range later if the size
      reads wrong — no code needed.
- [ ] **Chinook at ~95s**: the stick files OUT THE BACK RAMP, fans behind the ship,
      and the men walk off to camp jobs (not seated statues on the pad).

## The night attack
- [ ] **The assault spawns outside the wire** — no bodies popping inside the compound
      (the ring was straying 47m; it is center-true now, and `[SIEGE] aim offset`
      prints the number in the log).
- [ ] **Squads use satchel holes**: when sappers blow the parapet, the squads nearer
      the hole press THROUGH it into the compound instead of queueing at the gate.
- [ ] **Hooches that die BURST at mortar size, catch fire, and swap to the burned
      shell** — no more map-wide fireballs per hut.
- [ ] **Cover feel**: men still stop ~4-5m short of walls — that fix is PARKED for a
      session you watch (it retunes your own squad too). Expected, not a regression.
- [ ] **Frame feel during the assault**: worst hitches should be shorter than before
      (the spawn-burst fix); if it still stutters hard at wave arrivals, say when.

## The end
- [ ] Gunships arrive when the assault RESOLVES (not on a timer), no mortars landing
      on the end card, player lives, end card holds.
- [ ] Esc during play: the button reads **RESTART DAY** and reboots clean.

## While you're in the mood (5 min each, optional)
- [ ] Fire range: heavy (~46m) and mortar (~28m) sizes with the knob — bank your
      numbers.
- [ ] The three perf poses (THE WALK · ONE DIG · THE BARRAGE) if I haven't taken them
      by then — but I will try to have these done for you.

**What your run discharges**: the demo gate re-opens closed (ADR-015), Blocks 1-2 of
DEMO_TIGHT_40 unlock, and the honest-mesh, breach, hooch, Chinook, napalm, and
spawn-ring changes all move from "probe-verified" to "his-eye-verified."
