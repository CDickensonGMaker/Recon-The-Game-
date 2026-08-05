# GAME DESIGNER — Individual Sight

I am here to ask what the player sees, because this council is at risk of optimising a
measurement instrument instead of a game.

## What the player sees in Lane A

The viewmodel is on screen more than any other asset in the game. But the player is not
inspecting joint accuracy — they are reading **weight, punctuation, and whether the gun feels
alive between actions.** Rule #1 is *FUN*, and the standing acceptance test on the combat side
is his own sentence: *"I don't feel in danger."* The viewmodel equivalent is *"this gun doesn't
feel like a prop."*

That feeling is produced by:
- the gun never sitting perfectly still (the M16 froze for 35 of 72 frames — that was the tell);
- tangents that don't micro-stop at every extreme (`AUTO_CLAMPED` → `AUTO` was the single
  biggest win ever measured on this rig);
- offset keys instead of full-sync frames;
- and **runtime sway/bob/lag**, which the research keeps naming as the top lever.

**None of that comes from a camera.** Zero of the four measured causes of "robotic" were mocap
problems. This strongly supports spending the effort on the procedural layer and the curve
discipline rather than on capture fidelity.

## What the player sees in Lane B

The opposite. NPC bodies are read at distance, in peripheral vision, in groups. What sells them
is **plausible weight, correct ground contact, and variety** — not per-joint precision. This is
exactly what monocular depth error destroys (float, slide, no weight) and exactly what a second
camera restores.

So the two lanes want *opposite* things from the pipeline, which is the strongest argument in
this whole session for **splitting them and naming them.** One instrument, two jobs, and we have
been tuning it for the average of the two — which serves neither.

## Where I push back on my own council

The engineers want gates, tests, hashes and verdict blocks. All correct. But **Demo Day is a
30-minute one-day arc and his playtest is the ship gate.** The bottleneck on this project has
repeatedly been measured as *his eyes*, not our throughput. A week of pipeline hardening that
delays the demo is a bad trade.

My ranking by player-visible value per hour:

1. **Procedural life layer** — improves *every clip already shipped*, retroactively. Nothing else
   in this document has that property.
2. **`beats.json` timing extraction** — makes the hand-keyed weapon workflow (which is the
   correct workflow) substantially cheaper.
3. **Take triage gate** — stops wasted capture sessions, cheap to build.
4. **Two-camera rig** — the right long-term answer for NPC bodies, but it is a *new shooting
   discipline* and its payoff lands on future clips, not the demo's.
5. **Solver replacement** — dead on licence, and would not have been top of my list anyway.

## One design note the pipeline should encode

Weapon clips are read at one distance and one framing, forever. NPC clips are read at many. That
means weapon clips justify hand-authored per-frame care and NPC clips do not — NPC clips should
be **spliced from a library and contact-solved**, which is already the ruled approach. The
pipeline should stop offering the same fidelity dial to both.
