# Animation Contract Audit — 2026-07-12
**Question (Summoner):** *"audit all the models, what animations they're capable of, what the code
calls for, and where the gap is."* · **Instrument:** `tools/probe_anim_audit.gd` — plays every
demanded clip on every rig through the real `ModelActor.play()` path and records what resolves.

## Verdict: the contract is CLEAN on all 10 rigs
Every unit (4 US + 6 VC) carries the full **100-clip shared library** (anim_library.glb merge
works on every rig — the PSXRig contract holds roster-wide). Every intent the code demands
resolves on every unit. `laying_breathless` exists everywhere. **No unit is missing any clip the
code asks for.** The only ALIAS hits are the deliberate v1→v2 name mappings
(`rifle_aiming_idle → idle_aiming`, `death_forward → death_from_the_front`) — working as designed.

### Corrected diagnosis: the standing dead were NEVER a missing-clip problem
The audit disproves yesterday's missing-clip hypothesis for the current roster. The confirmed
causes were (1) **ragdoll pool starvation** — the 8-slot cap counted settled corpses for 45s, so
man #9+ in a wave had no physics fallback (fixed: slots free on settle), and (2) silent
`play()` failures had **no fallback at all** if they ever did fail (fixed: clip → any-death →
ragdoll ladder). The ladders stay — they're insurance for future/imported rigs — but no current
rig needs them. If a standing corpse appears again, suspect the ragdoll/animation *runtime*, not
the clip inventory.

## The real gap #1: weapon-family holds are 1/4 delivered
The funnel asks for `<clip>__<family>` per the carried weapon (Caleb: "the way I'd hold the PPSh
is different than the Mosin"). Inventory answer:
- `__smg` — **EXISTS** (11 clips, present on every rig via the shared library)
- `__bolt`, `__mg`, `__launcher`, `__pistol` — **DO NOT EXIST.** Mosin/M60/RPD/M79/RPG/Colt men
  silently fall back to the rifle hold.
This is Batch 7 (bead ou5q) content work in Blender. The engine side is done — clips light up on
landing, zero code.

## The real gap #2: the AI uses ~13 clips of 100
Fifty-nine authored clips per rig are never asked for. This is the hidden answer to *"they don't
seem to be thinking, just reacting"* — thinking is expressed through movement VARIETY, and the
variety is already authored, just unwired. Categorized, with where each set belongs:

| Set | Clips | Wire into (T3 layer) |
|---|---|---|
| Sprint family | sprint_forward/back/left/right + diagonals (8) | ADVANCE at range, the numbers-press charge, retreat-at-full-break |
| Movement texture | run_to_stop, stop_walking, start_walking, run diagonals, run_backward×3 | arrival at cover (kills the skate-stop), backpedaling fire |
| Stealth/cover | cover_sneak_l/r, crouched_sneaking_l/r, cover_to_stand×3, stand_to_cover×3 | SEEKING_COVER approach, SUSPICIOUS investigation, cover exits |
| Reaction | hard_landing, falling_to_roll | grenade-dodge dive (exists as clips, not as behavior), knockdown |
| Idle life | idle_unarmed×5, sitting, action_idle_to_standing_idle | RELAXED sentries/camps — pre-contact atmosphere (Pillar 2) |
| Set pieces | cockpit×3, pilot_flips_switches, swimming, brutal_assassination, jumping_jacks, jump×4 | vehicles/rivers/stealth kills — future systems, already costed |

## Genuinely missing from the library (Blender wishlist, priority order)
1. **flinch** — no clip exists; a bullet hit reads as nothing (T2's top gap; code falls back to
   idle). Until authored, a code-side stagger (brief speed/aim hitch + upper-body jerk via
   existing pose) is the stopgap.
2. **aim_walk** — noted in code as art wishlist; walk_forward stands in.
3. **surrender** — kneeling_pointing stands in (visible but ambiguous).
4. **The four weapon-family hold sets** (gap #1 above).

## Recommended order
1. Code (cheap, big feel): wire **sprint** into ADVANCE/charge + **run_to_stop** on cover arrival
   + **sneak set** for cover approach — three intent mappings in SpriteStateMap + speed gates.
2. Code: bullet **flinch stagger** stopgap (T2).
3. Blender: flinch clip, then the `__bolt`/`__mg`/`__launcher` hold sets (Batch 7).
4. The set-piece clips wait for their systems; do not wire speculatively.
