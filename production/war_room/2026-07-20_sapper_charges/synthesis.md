# DECREE — Wiring the sapper charge (2026-07-20)

Arbiter: recon-overseer. Council: game-designer, systems-designer, ux-designer, devil's-advocate.
Full analyses in `analysis/`. This file is the ruling of record.

## The finding the Summoner asked for

`sapper_charge.gd` is **not a behaviour to wire — it is a broken stub.** All four architects,
reading independently, converged:

1. **The movement is a lie.** The header says "sprints for the wire"; the body only writes
   `enemy.last_known_target_pos` (`sapper_charge.gd:24`). That is a *search hint* the combat brain
   reads only when LOS is lost and overwrites every think (`enemy_base.gd:653,1037`). A fresh sapper
   with no target falls to `HOLD_POSITION` and stands still. On a squadded sapper the write *poisons*
   `EnemySquad.begin_hunt` (`enemy_base.gd:1101-1108`), sending the whole squad hunting the firebase.
   **Nothing moves.** Real objective-movement has to be built; it was never written.

2. **Aimed at `fsb_center`, the satchel is a 17-man massacre, not a firework.**
   `CombatManager.apply_explosion_damage` damages five rosters including civilians
   (`combat_manager.gd:159-169`), and the garrison ARE `Civilian` instances, `Kind.CIVILIAN`, HP ~20
   (`civilian.gd:162`). They cannot fight back, cannot flee — `_on_noise` hard-returns on `is_garrison`
   (`civilian.gd:174`) so they do not even flinch — and their deaths are unscored
   (`_record_noncombatant_death` is empty, `civilian.gd:385`) and unreplaced across a persistent
   province. A 180-damage blast among them on a schedule is a sadism simulator. **This is the exact
   Pillar-5 landmine the brief anticipated and told us to surface, not solve by rewriting the garrison.**

3. **The notification layer already exists — do not build a parallel one.**
   `friendly_firebase_under_attack` is wired and guard-tested: `_poll_firebase_threat` raises the crisis
   for any 2 enemies within 90m while `patrol_out` (`field_director.gd:626-641`,
   `test_dynamic_events.gd:205`). A dedicated sapper node that also toasts is a fossil-in-waiting.

4. **"While he is away" is the dud-maker (Devil's Advocate, strongest dissent).** A spectacular event
   400m away through jungle is, from his chair, a toast and a kill count. The witnessable version —
   sappers on the wire **at night while he is inside it** — is the one with teeth. Game-designer and UX
   agree: *both*, with witnessable primary; the net is the failure-mode channel, not the event.

### Two bugs found in passing (pointer law)
- `sapper_charge.gd:28` toasts directly, bypassing `_radio_check()` — a marker from nothing, a
  Fairness-Law violation.
- `sapper_charge.gd:8` defaults `target_pos = Vector3.ZERO` with no guard — a sapper near world origin
  detonates on frame one.
- **Separate, pre-existing:** `_poll_firebase_threat` emits with a *constant* fsb-hash entity id
  (`field_director.gd:640`), so the firebase crisis fires **once per operation, ever** — every later
  attack is silent. Not fixed here (it changes existing crisis behaviour he may want to rule on); the
  sapper crisis uses its own per-night id and is documented for him.

## The ruling — build the fork-independent honest core; surface the two forks

The honest feature is bigger than "wire an orphan," and it contains two design-taste calls that are
the Summoner's, not mine. I build everything that is correct under **both** answers, in its safest
Pillar-5-respecting default, so he can rule from a working, fair, witnessable build in hand.

**BUILT NOW (nothing here is thrown away by either fork ruling):**
- **Reusable objective drive** in `enemy_base.gd`: an `assault_objective` the execute path honours,
  overriding HOLD/patrol and pushing *through* contact (correct sapper doctrine — aggression
  doctrine-exempt, `test_ai_fairness.gd:103`). One clause at the top of `_execute()`; the goal-scoring
  brain is untouched.
- **`sapper_charge.gd` repaired and made LIVE** (un-orphans it): sets the objective in `setup()`,
  ZERO-guarded, detonates on real arrival, **no direct toast**.
- **Witnessable spawn**, night- and threat-tier-gated, capped at the standing crisis budget, sappers
  walk in from 300-500m so he can cut them in the dark. Notification reuses the existing crisis net via
  a **dedicated per-night crisis id** (no parallel toast, no dependence on the buggy fsb-hash path).
- **The satchel aims at the bench POSITION and SPARES the garrison by default** — the objective is the
  armorer's bench point (a fixed landmark inside the wire, away from the perimeter garrison posts).
  `apply_explosion_damage` gains an opt-in `spare_garrison` flag (default false, all existing callers
  unchanged); the satchel passes true. The blast is real (FX, noise, crater, damages enemies/allies/
  props in radius) but does not delete the men who cannot react. **The bench is NOT modified** — it is
  only the aim point; making it a damageable, consequential PROP is Fork B and stays untouched.

**SURFACED FOR HIS RULING (seams left clean):**
- **Fork A — the garrison.** Default spares them. Does he want casualties, or the ability to react
  (a design change to what the garrison *is*)? Not mine to make.
- **Fork B — the persistent cost.** v1's detonation is a real explosion + crater but leaves no lasting
  materiel state; the sappers are a fight, not yet a loss. Whether reaching the wire should wreck the
  bench / cost mortars / foul the rack / raise threat is his ruling. No dead flag is left behind — the
  seam is simply the detonation callback, where a consequence hooks in when he rules.

## Pacing choice (named, per the brief)
**One roll per sim-night, probability by the threat tier the player earned, hard cap ONE sapper crisis
per operation, never before the world has settled.** The friendly-patrol crisis is capped at 2/op; a
firebase assault is louder, so it takes a smaller share of the same budget — **one**. This is the
symmetric other face of `_grant_fire_support` (noise buys napalm; noise also buys sappers). Night-gating
is legibility and flavour, not the rarity lever (a sim day is ~24 real min, night ~42% of playtime).

## What is sacrificed (no free lunch)
Rare content most players see seldom; the quiet player — whom ADR-006 rewards — sees it least; the v1
consequence is thin until Fork B is ruled; and the honest build spends real work on `enemy_base` (a
central shared file) that a naive "36-line wire" would have skipped straight into the massacre.
