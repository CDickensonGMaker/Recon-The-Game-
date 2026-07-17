# BRIEFING — ACTIVITY-TIERED AI (ADR-026 Part B, bead ps28) + SQUAD SURVIVAL (4utx)

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Why a council:** touches Pillar 1 (fairness),
the witness rule (ADR-005), and the squad-is-the-RPG pillar. Summoner-decreed; build now.

## THE DECREE (Caleb, via ADR-026 Part B — the values are law, not proposals)

The frame is **CPU-bound on AI** (measured 2026-07-17: `ai/agents` 25–192ms ≫ GPU ~32ms; the jungle is
NOT the wall). The fix is **budgeted compute, not a headcount cap** — firefight scale (target 30v30) is a
pillar.

- **Rolling HOT-SET.** Only ~**12 full-combat-AI** fighters (ceiling **16**) run the expensive cognition:
  target acquisition, LOS raycasts, precise aiming, cover-seeking, grenade logic. The rest run **cheap
  behaviors**: move / hold / take-cover / suppressed / reposition / fire-in-general-direction.
- **Promote-on-death / disengage.** As a hot fighter dies or disengages, a peripheral unit promotes in.
  Rolling reassignment keeps the fight alive and the cost flat.
- **Owner: `EnemySquad`** — the single coordinator/targeting authority. Do not ship two targeting authorities.

## THE GUARD-RAILS (pillar law — a design that violates any of these is rejected)

1. **FAIRNESS EXEMPTION (ADR-026 A.1, ADR-005).** The muzzle-flash SPRITE, the tracer, and the report are
   **exempt from every tier/LOD/flash cap.** Any tier that FIRES emits the full telegraph and obeys
   first-shot-is-a-near-miss / the exposure ramp. A cheap-tier unit that shoots the player still
   telegraphs legibly. Cap the *cognition*, never the *telegraph*.
2. **WITNESS HEARTBEAT NEVER DISABLED (ADR-005, binding).** Perception + NoiseBus + persistent state tick
   on **every unit at every tier at every distance**. **`set_physics_process(false)` is NEVER used to shed
   AI cost** — a blind cold unit voids the 150m loud-kill witness beacon and inverts the stealth economy.
   Tiering governs render + EXPENSIVE cognition ONLY.
3. **SCALE STAYS UNCAPPED.** Solve CPU by tiering, never by cutting bodies. 30v30 must still spawn, exist,
   be visible and animated.

## 4utx (sibling, land if coupled)

A squad at ~**45% strength** flips its COLLECTIVE goal fight→**SURVIVE**: organized withdrawal / break
contact / fall back covering each other — NOT fight-to-the-last-man. Squad-level cohesion owned by
`EnemySquad`, layered on the existing individual courage/rout ladder. Baseline 45%, modulated by
courage/type (elite/NVA lower, green/Local Force earlier). **Both sides.** A withdrawing squad's men
naturally shift to move/cover — dovetails with the hot-set.

## OPEN QUESTIONS FOR THE COUNCIL
- **Fossil hazard (ADR-023/ADR-025):** the existing `_update_think_lod` (distance think-rate LOD) and the
  ADR-025 `set_tier` design are overlapping LOD notions. Does the hot-set SUBSUME `_update_think_lod`, or
  layer above it? We must not ship a 4th LOD authority. (ADR-025 is DRAFT; ADR-026 B is the build order.)
- **Hot-set selection metric:** distance-to-player? engaged/has-target? recency-of-fire? A blend? It must
  keep the units the PLAYER can see/fight in the hot-set (fairness: the man shooting you is full-AI).
- **Cheap-behavior fidelity:** enough that the outlining men read as participating (Pillar 2) without the
  per-frame cost — and a cheap unit that acquires the player must be able to PROMOTE before it fires
  unfairly.
- **Determinism (ADR-010):** hot-set selection must be deterministic per seed (no global RNG).

## LENSES
- **systems-designer** — the hot-set budget, selection metric, promote-on-death, EnemySquad ownership.
- **devil's-advocate** — the fairness/witness failure modes: can a cheap unit shoot you without a
  telegraph? can a cold unit fail to witness a silent kill? the promote-on-death race.
- **lead-programmer** — the code seam (recon in progress): where enemy_base branches hot vs cheap, the
  witness tick that must stay, the fossil reconciliation with `_update_think_lod`.
