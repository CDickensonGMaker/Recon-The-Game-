# FPS Core Combat Priorities — what to dial before scaling up
**Date:** 2026-07-12 · **For:** the Summoner's question: *"what's the core elements I need to dial
in for the combat before I move to larger scales?"* · **Sources:** the id/Valve/Infinity Ward
lineage of gunfeel writing, HLL/Insurgency/Arma TTK design, RTCW/MoHAA AI doctrine (already our
mission-design reference), and this project's own bench data.

## The one rule
**Combat quality is a stack. Each layer amplifies the ones below it — and amplifies their flaws.**
Scale (bigger AOs, more men, objectives) is the TOP of the stack. Ship it last. A firefight that
feels wrong with 7 men in a 44m box feels *more* wrong with 40 men in a valley, and you will not be
able to tell which layer is lying to you anymore. The gore lab IS the instrument — every layer
below T4 must be provable in it.

## The stack, bottom to top

### T0 — Gunfeel (the 100-millisecond loop)
The trigger-pull → screen-response loop. If this is off, nothing above it can be evaluated.
- Crosshair/sight truth: the round goes where the reticle says. **DONE** — ADS fires down the
  camera ray; hip converges muzzle→aim point; viewmodel offsets are cosmetic.
- Recoil that is learnable: first-shot kick, climb, recovery — per weapon, deterministic. **DONE**
  (W-feel fields in WeaponData). Judge by: can you keep an M16 burst on a chest at 30m by hand?
- Response FX at zero latency: muzzle flash, sound, punch on the FRAME of the shot (not arrival).
  **DONE.**
- ADS visual alignment: sights stack on center. **IN PROGRESS** (Caleb's per-gun pass; aim is
  already true, so this is polish-order work, not blocking).

### T1 — TTK consistency (the layer we are on NOW)
The Summoner named it exactly: *"sometimes fast kills… other times Half-Life with 1/10th of the
life."* The kill-time TARGET matters less than its VARIANCE. HLL feels deadly not because TTK is
0.2s but because the same shot always does the same thing — death reads as *situation*, never as
RNG. Rules of the layer:
- **Same aim = same result.** Every source of hidden variance is a bug: body capsules shadowing
  zones (fixed), limbs shadowing the chest (fixed 2026-07-12 — rounds over-penetrate one limb at
  75% energy and carry into the torso; head/torso/gut stop the round), explosion loops skipping
  victims (fixed), mid-tune hand-authored hitboxes (retired — zones auto-fit the mesh).
- **Median target:** centered rifle fire kills in 1–2 rounds (M16 chest 70 vs 65–85hp ✓). Player
  dies in 2 chest hits / 1 head — mutual, by decree.
- **Variance budget:** what remains SHOULD vary — range falloff, cover clipping the pattern, limb
  hits that wound instead of kill. That is legible variance; the player can read WHY.
- **Verify with probes, not vibes:** `probe_bullet_damage` (headshot = kill), `probe_grenade`
  (cluster wipe). Add a chest-TTK probe if doubt returns: 20 shots at a chest from 15m must all
  land 63–70.

### T2 — Death and damage legibility (did I get him?)
Every hit needs an answer within one frame of arrival: blood + hitmarker on hit, and on a kill the
body must ANSWER — this is why the ragdoll doctrine matters (clean kill = weight drops; a man who
keeps standing for even 500ms reads as "the game ate my shot," identical to a TTK bug even when
damage was correct). Status: doctrine shipped on all models; the walking-dead class of bugs
(ragdoll pool starvation, missing clips, standing downed men) has been hunted three times — treat
any future standing corpse as a T2 regression, priority zero.
- Still open in this layer: **pain reactions on non-lethal bullet hits** (a flinch/stagger frame),
  which is the single strongest "your shots matter" signal after death itself. Enemies stagger on
  explosions only today.

### T3 — Enemy legibility (thinking, not reacting)
The Summoner's read — *"they don't really seem to be thinking, just reacting"* — is a LEGIBILITY
problem as much as an AI problem. Players cannot see goals; they see MOVEMENT. An enemy is
"thinking" when his movement has visible narrative: he ducks when suppressed, he moves cover→cover
in bounds, a flank develops on your side over seconds, he shouts before he pushes.
- **Pathfinding is the floor of this layer and currently its weakest plank.** A man face-planting
  a crate reads as brainless no matter how smart the goal scoring is. Lab navmesh shipped (241
  polys, agents route). Remaining, in order: RVO avoidance (men not stacking/shoving in lanes),
  cover-to-cover BOUNDS as the default combat move (short nav hops between claims, not straight
  lines to targets), navmesh in dummy/combat labs (bead kw1w).
- Think/execute split, goal scoring, suppression, morale-by-numbers, first-shot fairness: all
  exist. They become VISIBLE once movement stops lying.
- Barks tied to intent (VOManager exists): "flanking!", "grenade!", "he's down!" — cheapest
  legibility multiplier in the codebase.

### T4 — Encounter grammar (the arena as a sentence)
Only after T0–T3: engagement ranges, cover density/heights (the lab's 0.5/1.0/1.5/2.5 field is
already deliberate), enemy mix per fight (rifles vs MG vs RPG), wave pacing, flanking geometry.
This is where "pace" is actually tuned — TTK sets the cost of a mistake; encounter grammar sets
how often mistakes are invited. Yesterday-vs-today pace differences live HERE as much as in
damage numbers: 7 pressing men with working grenades is a different sentence than 7 timid ones
with broken grenades, at identical TTK.

### T5 — Scale (the reward for finishing T0–T4)
AO streaming, objectives, squads, missions. Every element scales cleanly only if it was proven in
the box: 40 men on navmesh behave like 7 men on navmesh; TTK at 150m is the falloff curve you
already trust. If something feels wrong at scale, the layer discipline tells you where to look —
and it is almost never at T5.

## Scorecard (2026-07-12)
| Layer | State |
|---|---|
| T0 Gunfeel | ✅ mechanics · 🔧 ADS visual pass (Caleb, per-gun) |
| T1 TTK consistency | ✅ after limb penetration — verify by feel this session |
| T2 Legibility | ✅ death doctrine · ❌ bullet pain-flinch (next code item in this layer) |
| T3 Enemy | 🔧 weakest layer: RVO avoidance, cover-to-cover bounds, barks (kw1w) |
| T4 Encounter | 🕐 tune after T3 movement stops lying |
| T5 Scale | 🕐 blocked on T3/T4 by design, not by tech |

## Recommended order from here
1. Caleb: ADS visual pass (T0 polish, independent track).
2. Code: pain-flinch on bullet hits (T2 — small, huge feel payoff).
3. Code: RVO avoidance + cover-to-cover bounds (T3 — the "thinking" fix).
4. Bench: TTK feel session in the lab; only then touch damage numbers again.
5. T4 encounter tuning in the lab. Then, and only then, the first large AO test.
