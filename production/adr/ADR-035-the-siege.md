# ADR-035 — The Siege: the night assault on the firebase

**Status:** rev.2 2026-07-28 — **BUILT (local, unpushed).** Revised after War Room review (2 SEND BACK,
1 RATIFY-WITH-AMENDMENTS against rev.1), then coded on the Summoner's instruction. Ratification is
still discharged only by a verified playtest (ADR-015) — see **Build state** below.
**Date:** 2026-07-28 · **Pillars:** 1 (believable firefights), 2 (atmosphere), 4 (you are IN the squad), 5 (fail forward).
**Related:** ADR-029 (open patrol simulator), ADR-020 (**the Ambience Law — amended, see §0**),
ADR-011 (fire-support ladder — illum joins it), ADR-026 (**PS2 budget — amended, see §7**),
ADR-023 (fossil law), ADR-001 (Forward+), ADR-010 (determinism), ADR-006 (scoring).
**Superseded scope:** the fall of the firebase, its objective installations, the respawn stake and the
lethality pass are **NOT in this ADR** — see **ADR-036**, which is blocked behind work that does not exist.
**War room:** `production/war_room/2026-07-28_firebase_siege/` (briefing, 4 problem analyses, 3 ADR reviews, synthesis).

---

## §0. What this ADR is, and what it deliberately is not

rev.1 tried to rule the siege AND the loss of the firebase in one document. The council found nine of its
thirteen dependencies did not exist — most fatally that **the firebase is a single baked GLB node**
(`site_planner.gd:925` returns `"nodes": [root]`), so it has no damageable installations to capture, no
TOC, and no commo bunker anywhere in the repo. Welding the two meant neither could ship.

**This ADR rules the siege as a FIGHT.** ADR-036 rules what losing it costs.

**Amendment to ADR-020 (the Ambience Law).** ADR-020 §4 holds that "a firebase attacked every third night
is a Battlefield map." The Summoner's 2026-07-28 cadence ruling supersedes that clause for the firebase
specifically. §1 below carries the rate that keeps it honest — the Ambience Law's *intent* (assault is
rare and earned) survives as a probability, not as a prohibition.

## §1. Cadence, composition, and the probe/siege split

- A night assault may fire **on any night**; a run may last **up to three consecutive nights**; a fourth
  consecutive night cannot fire. The once-per-operation latch is DELETED (§8).
- **Per-night probability by earned threat tier**, replacing the deleted `SAPPER_CHANCE`:
  LOW 0.05 · MODERATE 0.15 · HIGH 0.30 · CRITICAL 0.45. **Named here because the fossil kill-list removes
  the old constant and a rate that is not written down ships as whatever the first coder types.**
- **Strength = d50, rolled ONCE PER RUN, not per night** (council amendment, accepted). Nights 2 and 3
  attack with **the survivors the reap collected** (§5), plus an ADR-019 allegiance trickle. Break them
  hard on night 1 and night 2 may not come. Escalation is authored by the player's defence, not re-rolled.
- **Sappers = 2d6 of that strength.**
- **THE PROBE/SIEGE SPLIT** (council amendment, accepted — it closes the decree's one arithmetic hole,
  where 2d6 can exceed a low d50):
  - **d50 of 1–11 = a PROBE.** A handful of men on the wire; sappers `mini(2d6, count)`. A small night is
    legible as a probe instead of reading as a broken siege.
  - **d50 of 12–50 = a SIEGE.** 2d6 ≤ count by construction. Everything below applies.
- It fires **whether or not the player is inside the wire.** The `patrol_out` gate (`field_director.gd:1027`)
  is removed, with the consequences in §9 handled.
- **The night is 600 real seconds** — `SimClock.real_to_sim_ratio` (`sim_clock.gd:17`) × `period_at`
  (`:56-63`), arithmetic verified. A siege runs at most **480 s** and **must be triggered early enough in
  the NIGHT period that 480 s fits before dawn.** rev.1 asserted "never runs to dawn undecided" while
  constraining nothing; the trigger hour is now the constraint.

## §2. The marching cell

**Measured** (`PERF_LEDGER.md:295-304`, W0 headless, 65+ units): the AI wall is ~38–40 ms/physics-tick;
the ledger attributes **~6% to perception rays + think combined** (think alone 1.2 ms). The other ~94% is
the **BODY**: `move_and_slide` ~9 ms + hitzone sync ~10 ms + anim/execute ~18–19 ms.
**A hivemind that shares thinking banks nothing. A hivemind that shares BODIES banks everything.**

The assault is built of **marching cells: 3–6 men of ONE type**, each a single node carrying its strength
as an integer and **zero bodies** until it materializes. Reuses the shipped `LazyGroup` pattern
(`lazy_group.gd:88`), which routes spawns through `FieldDirector.spawn_tracked_enemy` — **the single spawn
authority is preserved.** A d50 of 43 is ~9–10 cells.

**Contracts (rev.2 — contract 1 corrected, it contradicted §7 as written):**
1. **Dark materialize ring = 80 m.** Night sight is 56 m open / 18 m jungle — derived, not literal:
   `SIGHT_CAP_OPEN = 140.0` / `SIGHT_CAP_JUNGLE = 45.0` (`enemy_base.gd:80-81`) × the NIGHT darkness
   multiplier `0.4` (`sight_cap.gd:12` `DARKNESS_BY_PERIOD`).
2. **Illumination force-materializes any cell inside the LIT CIRCLE, at any range.** A flare raises the
   multiplier floor to 0.9 (`sight_cap.gd:34-35`) → ~126 m of sight, which is **beyond** the 80 m ring.
   rev.1's flat "materialize radius > sight cap" was therefore self-contradictory. Scoping the trigger to
   the lit circle — not to the whole assault — resolves it and bounds the spike a player can self-inflict.
3. **The break counts TOTAL strength including dormant cells** — and therefore **CANNOT use
   `EnemySquad._strength`** (§5).
4. **Dormant cells emit `NoiseBus` noise.** An approaching company is heard before it is seen.

**Honest limit, unchanged and now explicit: the "diegetic ceiling" bounds nothing by itself.** One axis
plus one objective cluster means every cell crosses the ring within roughly a minute. A hard cap on
simultaneous materialized men is REQUIRED, and when it defers a cell that fact is `log()`-ed, never
silently dropped.

## §3. One axis

The assault comes up **one 60° sector**. Sappers may enter on a different vector *inside* that sector.
**Nights 2 and 3 remember the axis** — a sector that worked is attacked again (council amendment).

**Pillar 4:** the player's real decision in a siege is not aiming, it is **where his five men go** —
`squad_follow` / `squad_hold` / `squad_move` / `squad_fire_toggle` all ship (`project.godot:215-233`,
`squad_system.gd:180`). Five men against one 60° sector, plus when to spend light (§7), is the siege's
Pillar-4 verb. rev.1 wrongly implied illum and fire missions were his only inputs.

## §4. The break, the credit, and THE REAP

**Break threshold = 40–50% of the assault killed.** rev.1's mechanism was defective and is replaced.

**WHY rev.1 FAILED (both reviewers converged, verified at source):** `break_state(live, peak, avg_courage)`
(`enemy_squad.gd:109-112`) takes **no threshold parameter** — the only in-signature route to 0.575 is
`avg_courage = 0.1875`, which also drives `char_self_preservation` and the individual rout ladder, making
every besieger personally cowardly. And its only feeder `_strength` (`:115-137`) counts
`get_nodes_in_group("enemies")` and ratchets `peak = maxi(peak, live)` (`:129`) — **dormant cells have no
nodes**, so `live` is *replenished* as cells arrive, the ratio hovers near 1.0, and the assault break is
suppressed for exactly as long as materialization runs. **Every siege would have ended on the 480 s
stopwatch, not on the Summoner's number.**

**RULING:**
- `break_state` gains an **optional threshold parameter**, defaulting to today's behaviour so no shipped
  fight retunes. One function, one formula, one authority — the divergent-systems law is satisfied by the
  DECISION being in one place, not by pretending a squad-scoped cache can serve an assault.
- **The siege owns its own strength ledger:** total strength (materialized + dormant), peak fixed at
  roll time rather than observed, decremented on death. It passes that ledger into `break_state` with the
  siege threshold **0.575** (breaks at 42.5% killed, inside the decreed band).
- Cells keep using the shipped squad-scoped path for their own local break. **Two scopes, two ledgers,
  one formula** — rev.1 claimed two scopes on one ledger, which was false.

**CREDIT: every attacker death inside the siege counts — NOT player-attributed kills.** `_on_enemy_died`
(`field_director.gd:63`) discards the killer and the signal (`enemy_base.gd:5`) never carried one; the
player's mortars (`:726`), arty (`:579`) and claymores (`claymore.gd:58`) pass `attacker = null`, which
`combat_manager.gd:149-150` reads as "indirect fire, 0.4× to your own men." Building attribution would make
his own steel **2.5× more lethal to his own squad** — a live regression shipped to fix a counter. The
player is one rifle on a perimeter (Pillar 4); the garrison holding with him is the fantasy.
**Required exclusion: enemy mortars must not damage their own men,** filtered at the shell.
**The passive-player case is priced by a siege AAR (§6), not by a credit rule.**

**THE REAP — the largest new construction in this ADR.** All four problem-phase architects converged:
**withdrawal does not exist in this codebase.** `_execute_retreating` (`enemy_base.gd:1644-1676`) flees on
a bearing with no destination, stop distance, timeout or map clamp; `EnemyBase` has **no despawn path**
(`_live_enemies` is erased only on death, `field_director.gd:65`); and `:902` holds a routed man at ALERT
forever, pinning `_body_gate_open()` (`:534-536`) open for the rest of the operation. Untouched, a
three-night run leaves **~40 permanent full-cost ghosts.**

On break, the siege owner takes every survivor and:
1. **Frees any `SapperCharge` child FIRST.** `_physics_process` tests `target_pos` (`sapper_charge.gd:42-51`),
   so a withdrawing sapper crossing his old aim point detonates on the way out. **rev.1 got this order
   wrong in effect:** `_detonate` sets `assault_objective = Vector3.ZERO` (`:69`), kills the man
   (`:70`) and fires `on_firebase_breach` (`:66-68`) — a detonation during withdrawal both cancels step 2
   and charges the player for a siege that had already broken.
2. Sets `assault_objective` to a rally ~350 m back down the sector axis. This sits above the FSM
   (`enemy_base.gd:1317-1319`) so goal scoring cannot override it — verified. **Known limit:** `_move_toward`
   only navmeshes when both endpoints share a `NavBaker` box, so a 350 m rally is straight-line steering
   without wall-slide. Rally points are therefore placed on the axis the cells *walked in on*, which is
   known-traversable ground.
3. **Reaps** at the rally, at a hard 600 m radius, or after 90 s — whichever is first.

## §5. Enemy indirect fire — the ranging walk

Mortars open the assault and **walk on**: dispersion 50 m → 12 m over 180 s, 3-round volleys at 20–25 s,
reusing `_fire_shell` / `_mortar_impact` (`field_director.gd:648-730`) with an enemy source. Two mandatory
fixes: `_fire_shell` computes azimuth from `fsb_center` (`:656`), so **an enemy shell currently arrives
from inside the compound** — it must take a `from` bearing; plus the enemy-exclusion of §4.

## §6. The garrison stands to — AND STANDS DOWN — and the night banks

`GarrisonDefender.promote` **destroys the Civilian** (`garrison_defender.gd:42-48`). After one stand-to the
`firebase_garrison` group is **empty**, the scheduled civilians (`site_planner.gd:726`) are gone forever,
and the base is a fort of static HOLD-order soldiers on an 8 m leash (`ally_base.gd:147`).

**STAND-DOWN SHIPS WITH THIS ADR.** At dawn, surviving defenders revert to Civilians at their posts, with a
**stand-down identity contract**: a man keeps his generated `member` identity across promote/revert, or
three round-trips launder the garrison into anonymous men. **Dead men stay dead and are not replaced** —
that is the three-night dramatic engine. Without §6, Pillar 2 is paid out permanently on the first night.

**THE SIEGE AAR.** `_bank_patrol` fires only on crossing the wire inward (`field_director.gd:941-943`,
`:1213`) while `spawn_tracked_enemy` debits the ADR-006 ledger regardless (`:42-44`) — so today **the player
is scored DOWN for being attacked in his sleep.** A siege banks its own AAR at dawn: the butcher's bill,
who held, who died. This is also what prices the passive player.

## §7. Illumination

`IllumFlare` (`illum_flare.gd`) is reused whole; `IllumFlare.is_lit()` (`:14-18`) is the §2 contract-2 hook.
- **MORTAR ILLUM ships with the siege.** `_fire_shell(MORTAR_SHELL, target, callback)` already flies the
  shell; illum is that shell with a callback that pops a flare instead of applying damage. Missing only the
  wiring the WP round also lacks: a `fire_support` entry (`:255`), a grant (`_grant_fire_support:957`,
  called at `:939`), an input key (`:180-195`). At 300–500 m it is the only illumination that reaches, and
  **deciding when to spend light is the siege's strategic verb.**
- **M79 ILLUM DEFERRED behind an ammo system.** `WeaponData` carries one `projectile_data_path`
  (`m79.tres:28`) — **there is no ammo-type concept in this game.** Ammo switching pays off beyond illum
  and must be built for its own sake. M79 range is 100 m (`:24`) — a wire weapon, not an approach weapon.
- **Scale correction:** `LIGHT_RADIUS = 30.0` / `DURATION = 25.0` (`:8-9`) are hand-flare values; the
  mortar round needs its own — higher, wider, longer, slower drift.
- **AMENDMENT TO ADR-026 (recorded, not silent):** the Summoner waived the `OmniLight3D` budget for siege
  illumination on 2026-07-28. rev.1 took this waiver without citing the ADR it amends.

## §8. Fossil law (ADR-023) — what dies

Deleted in the same change: `SAPPER_DATA`, `SAPPER_COUNT`, `SAPPER_RING_MIN`/`MAX`, `SAPPER_CHANCE`,
`ASSAULT_DATA`, `ASSAULT_ELEMENT`, `_sapper_launched`, `_sapper_rolled_night`, `_maybe_launch_sappers`,
`launch_sapper_assault` (`field_director.gd:783-1146`). `tests/test_sapper_assault.gd:198-199` asserts the
exact `patrol_out` gate being removed and is rewritten, not deleted.

## §9. Live defects this ADR must fix on contact (drift law)

- `enemy_base.gd:1042-1045` — `_update_line_of_sight` returns without incrementing `target_last_seen_time`
  when `target == null`, so INVESTIGATE never expires (`:1131`) and the hunt anchor slides to
  `HUNT_ADVANCE_MAX = 130 m` **past** `fsb_center` (`enemy_squad.gd:303-304, 332-341`). **Attackers walk
  through the compound and loiter 130 m out the far side — shipping today.** `target == null` is the normal
  state of a man approaching in the dark who has acquired nobody; it does **not** mean the defenders are
  dead. Fixing this line alone makes the assault stall at 300 m — it must not be fixed without §2/§3.
- Removing the `patrol_out` gate: `raise_crisis` banks a `firebase_attack` patrol location (`:1009`, before
  the guard at `:1010`) that `_pick_patrol_location` takes first (`:1152-1159`) — **the next walk-out would
  task the player to sweep his own firebase.**
- **The wire band is farmable.** `_grant_fire_support` (`:957`) is an unlatched hard assign, the gate
  thresholds are 120 m out / 95 m in (`:772-773`) — a **25 m band** — and `FSB_THREAT_M = 90.0` puts the
  fight inside it. A player can re-arm mid-siege by walking 25 m. The grant needs a per-night latch.
- `SimClock.sim_day` (`sim_clock.gd:16`) is not serialized (`campaign_state.gd:208-229`, `:281`), so F5/F9
  resets a three-night run to night 1. `save_data.gd:15-17` serializes **zero live enemies**.
  **RULING: a siege is not save-scummable mid-fight — saving during a siege is refused, as the AAR-banked
  night is the checkpoint.** rev.1 named this gap and failed to rule on it.
- **Player death tears the world down** (`field_director.gd:141-142` → `game_flow.gd:169-185`), so nights
  2–3 cannot survive a death today. In THIS ADR that is a known boundary; it is ADR-036's to solve.

## §10. The gate (binding, ADR-015)

1. **No siege ships before THE REAP (§4) exists and is probed.** Shipping without a withdrawal and despawn
   path knowingly ships the ghost accumulation the decree's own one-axis rule exists to prevent.
   **Probe:** spawn a full-strength assault, force the break, assert `_live_enemies` returns to its
   pre-siege count within 120 s and that zero enemies remain outside the sector.
2. **Perf predicate, stated as a number so it can be discharged or fail** (rev.1's gate named none, and was
   dischargeable by writing any figure in the ledger): with the highest d50 roll materialized at the cap,
   mortars falling, on the ADR-026 floor — **worst single physics-frame AI cost ≤ the current 38–40 ms W0
   baseline**, measured by the same harness that produced `PERF_LEDGER.md:295-304`. Arena numbers must be
   re-confirmed in the real world build (ADR-028 Phase 3 ruling).
   **ADR-025 is SUPERSEDED (`ADR-025:3-19`) and may not be cited as the mitigation.**
3. Every rig ships with a probe that EXERCISES it — cells, reap, mortar walk, illum, stand-down, AAR.

## Build state — 2026-07-28, local and unpushed

**SHIPPED.** New: `scripts/missions/siege_director.gd` (cadence, the run pool, the sector, the ledger,
the break, the reap, the ranging walk), `scripts/enemies/marching_cell.gd` (3-6 same-type men, dormant
until 80 m / lit / capped). Edited: `EnemySquad.break_state` (optional `base_ratio`, default unchanged),
`EnemyBase._update_line_of_sight` (the blind clock now runs with no target — §9 defect 1),
`EnemyBase.despawn` + `FieldDirector.despawn_tracked_enemy` (the first path in this codebase that
removes a LIVING enemy), `SapperCharge.disarm` (synchronous — `queue_free` is deferred and left the
satchel one more tick to blow), `GarrisonDefender.stand_down` (dawn revert, identity carried on meta),
`FieldDirector` (siege wiring, the `patrol_out` gate removed with the crisis-banking guard, the
per-sim-day allotment latch, illum mission + `_fire_shell(source)`), `IllumFlare` (per-instance burn and
radius; 81 mm round is 75 s / 180 m / 140 m up), `project.godot` (`illum_strike`, key 7).

**FOSSIL LAW DISCHARGED:** the entire `SAPPER_*` / `ASSAULT_*` / `_sapper_launched` /
`_sapper_rolled_night` / `_maybe_launch_sappers` / `launch_sapper_assault` block is deleted;
`ai_stress_arena` repointed to `SiegeDirector.SAPPER_DATA`. The fossil probe ratcheted **4 → 3**
(`tests/fossil_baseline.json`).

**PROBES:** `tests/test_siege.gd` (+`.tscn`) — 7 checks, each aimed at a mechanism the council proved
broken or absent: the dormant-aware ledger (with the shipped squad ledger as negative control), the
40-50% band plus a control that the default did NOT move, cell size/homogeneity/no-lost-men, the reap
returning the roster to its pre-siege count and scoring zero kills, satchels disarmed on withdrawal,
the blind clock, and the run pool carrying with a wipe ending the run. **Verified green**, as are the
two rewritten probes `test_sapper_assault` and `test_firebase_defense`. Full suite NOT run — the
Summoner runs it.

**NOT BUILT, still open against this ADR:** the siege AAR (§6) is a toast, not a banked debrief;
`SimClock.sim_day` is still unserialized and the save-refusal ruling (§9) is unimplemented; the §10
perf predicate is unmeasured. **`LIVE_CAP = 18` is SUPERSEDED — it is 50 in code
(`siege_director.gd:36`) by the Summoner's ruling of 2026-07-28: a capped assault trickles in and
never reads as the mass attack the roll describes. The cap is now the d50 ceiling, so it defers
nothing in practice; the amendment is that the roll ships UNCAPPED on his word rather than behind
a number nobody measured.** Consequence found 2026-07-30: an assault authored AT the cap freezes
its late cells at the ring, which is why the demo's escalation targets 45 and not 50.
The `enemy_squad.gd` hunt-anchor overshoot is now unreachable for besiegers (every man carries an
`assault_objective`) but is **not fixed at its source** for any other caller.

## §11. Consequences (the sacrifice)

1. **Frame budget.** Even celled, this is the most expensive combat event in the game.
2. **A passive player can still survive** a siege the garrison fought; the AAR prices it, the credit rule
   does not punish it.
3. **Scope.** Multi-session: siege state machine, marching cells, enemy indirect fire, the reap, garrison
   stand-down, the siege AAR, illum, save refusal. Other work parks.
4. **The living firebase is at risk** and is protected only by §6 shipping with the rest.
5. **Sieges cannot yet cost the player the base** — that is ADR-036, and until it lands a lost siege costs
   men and materiel but never the war.
