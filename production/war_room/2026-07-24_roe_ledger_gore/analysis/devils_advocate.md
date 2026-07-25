# Devil's Advocate — ROE / Noncombatant-Death Ledger

**Date:** 2026-07-24 · Charter: challenge assumptions, find edge cases, name the sacrifice, catch canon/law violations. Read the code, never the plan.

## What I verified (pointers)

- `scripts/world/civilian.gd:358-386` — `_die()` sets `state = GONE` on its first line (:359), then calls `_record_noncombatant_death(attacker)` at :378. The hook (:385-386) is `pass`, with a guard comment (:382-384): *"do not add scoring here without a decree; that system is explicitly out of scope."*
- `civilian.gd:27` `var director: FieldDirector`, set at spawn (:114). **The hook CAN reach the live MissionState** via `director.state` — no new plumbing needed.
- `scripts/missions/mission_state.gd` — RefCounted. Has `kills`, `damage_taken`, `contacts_detected`, the group ledgers, and a `flags` Dictionary. `build_result()` (:49-53) emits `_base_result()` (:56-68) **then merges every `flags` key on top**. No civilian counter exists anywhere (grep across `scripts/` returns zero `war_crime`/`atrocity`/noncombatant *counter* — only descriptive comments).
- `scripts/ui/screens/debrief.gd` — **`compute_score()` IS LIVE**, called at `field_director.gd:1070`: `CampaignState.team_xp += maxi(0, DebriefScreen.compute_score(result))`. It reads a FIXED key set: `contacts_avoided`, `contacts_detected`, `damage_taken`, `time_sec`, `success`, `shots`, `pow_lost`. It does **not** read any civilian key and ignores unknown keys.
- `field_director.gd:1066-1083` `_bank_patrol()` — builds `result` at :1067 (captures the finished patrol), banks XP/commits, emits the toast at :1075 (prints only `patrol_count` and `kills`), **then** `state = MissionState.new()` at :1080. Ordering is correct: capture-then-reset.
- ADR-006:13-15 — *"Whether and how this economy re-hosts in the open-patrol AAR is an open question for the Summoner, not settled here."* ADR-029 deleted the debrief screen.
- **ADR-005 is `ADR-005-detection-beacon-witness-rule.md`** — it governs the ENEMY detection beacon (`last_combat_contact_ms`), i.e. whether the AO knows you're there. **It says nothing about civilians, ROE, or a war-crime ledger.** Its "witness" machinery lives in `enemy_base.take_damage()` / NoiseBus, and it explicitly warns (`:68-69`) against "new raycast storms."

## Attacks

### (1) Can a mere COUNT still leak into a fail-state / moralize? (Pillar 5)
As-is, **no** — *provided `compute_score()` is not touched.* A `civilian_deaths` int on MissionState is invisible to scoring because `compute_score` reads named keys only. Two live leak vectors remain, and both are one careless edit away:

- **compute_score drift.** The instant the ledger lands in `build_result`, a future agent "completing" the feature can add `score -= civilian_deaths * X`. Then `maxi(0, …)` (:1070) floors XP at 0 — a heavy civilian toll doesn't just zero the penalty, it can **silently erase an entire clean patrol's XP**, which is a soft fail-state wearing an info costume. This is exactly the Pillar-5 "sadism simulator" line: escalation, not fail-states.
- **CampaignState.on_mission_end(result).** `_bank_patrol` passes `result` to `CampaignState.on_mission_end` and `commit_mission`. If the counter is in `build_result`, whatever that autoload does with the dict (persist? log? react?) becomes an unaudited surfacing/consequence the Summoner never approved. I did not read CampaignState; **that is the finding** — putting the counter in `build_result` hands it to a consumer we have not vetted.

The guard comment at :382-384 is the only thing holding the line today. Any counter I add must carry the **same** guard, or it becomes bait.

### (2) Hidden double-tracking / MissionState reset bug?
- **Reset:** correct. `state = MissionState.new()` (:1080) gives a fresh `civilian_deaths = 0` per patrol — **only if the counter lives on MissionState.** The trap: if anyone parks it on `CampaignState` or a `static`/autoload "so it survives," it accumulates across patrols and never resets. Name and forbid that.
- **Double-count from multiple hits:** safe. `take_damage` returns early on `GONE` (:348) and `_die` sets `GONE` first (:359), so `_die`/the hook fire exactly once per civilian.
- **REAL MIS-COUNT — the revealed informer.** `_transform_to_vc()` (:399-410) removes the civilian from the `"civilians"` group and unregisters it from AgentRegistry, but **does NOT set `state = GONE` and does not tear down the Civilian script.** Its `take_damage`/`_die` remain fully live. So shooting a revealed-VC informer — now functionally an enemy — routes through the Civilian hook and **counts a legitimate combatant kill as a noncombatant death.** Blast (`combat_manager.gd:161` iterates `AgentRegistry.civilians`) won't hit it (unregistered), but direct fire will. Any ledger MUST guard: `if is_informer and not is_in_group("civilians"): return`.

### (3) Is even the AAR-toast line overstepping?
**Yes.** ADR-006:13-15 reserves *whether and how* the economy re-hosts in the open-patrol AAR for the Summoner. A civilian-death line in `_bank_patrol`'s toast (:1075) is a surfacing decision — it decides *how* it surfaces, the exact thing reserved. It also risks reading as a moral verdict at the wire ("2 CIVILIANS KILLED"), which pre-judges the Pillar-5 tone question the Summoner owns. The toast line is the clearest overreach in the Arbiter's inclination.

### (4) Bonus catch — the ADR-005 "witness/ROE context" claim is a mis-citation.
The Arbiter proposes recording "witness/ROE context per ADR-005." **ADR-005 does not authorize a civilian ledger** — it is the enemy detection-beacon rule. Worse, at the moment the hook fires the Civilian has **no cheap access** to "was this death witnessed": that state lives in enemy perception / NoiseBus, and ADR-005:68-69 explicitly forbids new raycast storms. So "record witness/ROE context" is neither authorized by the cited ADR nor cheaply computable — it is scope the plan smuggled in under a pointer that doesn't cover it. Count only.

## The single safest cut (and the sacrifice)

**Increment a `civilian_deaths: int` on the live `MissionState` ONLY, from the hook, guarded — and touch NOTHING else.**

- `mission_state.gd`: add `var civilian_deaths: int = 0` with the same "no scoring without a decree" guard comment. **Do NOT add it to `_base_result`/`build_result`.**
- `civilian.gd` hook: 
  ```
  func _record_noncombatant_death(_killer: Node) -> void:
      if is_informer and not is_in_group("civilians"):
          return  # revealed VC informer is a combatant, not a noncombatant
      if director != null and is_instance_valid(director) and director.state != null:
          director.state.civilian_deaths += 1
  ```
- **No `compute_score` term. No `build_result` key. No AAR toast line. No witness/ROE context.**
- Verify with a headless probe (Verification Law) that reads `director.state.civilian_deaths`: kill N villagers → counter == N; new patrol → counter == 0; kill a revealed informer → counter unchanged.

This records the ledger the ADR-006/ADR-029 re-host will eventually consume, resets correctly per patrol, cannot touch XP, cannot moralize, and leaves every reserved surfacing decision on the Summoner's desk.

**THE SACRIFICE (no free lunch):** the counter is **invisible** — no AAR, no log, no XP, no HUD. Nothing in the shipping game reads it. By the FOSSIL LAW that makes it an **UNFINISHED system — built ahead of its wiring** — the precise shape that reads as live-but-dead and gets mis-triaged later. It is only defensible if it is (a) explicitly logged in the tracking docs as *reserved-pending-Summoner* with the ADR-006:13-15 pointer, and (b) covered by the probe so it can't silently rot. We also forgo the richer "was it a war crime?" context entirely — a bare tally can't distinguish a massacre from one stray round through a hut wall. That nuance is deferred, on purpose, to the Summoner's surfacing decree. If the council isn't willing to log it as UNFINISHED and probe it, the honest move is the **null cut: leave the hook `pass`** — an empty hook with a guard comment is a smaller, more honest placeholder than a counter nobody reads.
