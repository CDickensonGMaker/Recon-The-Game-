# Systems-Designer Analysis — W5: ROE/Stealth Ledger (Pillar 5, Fail-Forward)

**Method:** read the code, not the plan. Every claim below carries a `file:line` pointer (Pointer Law).

---

## 1. LIVE vs DEAD — what the code actually does

### The stealth/ROE contact ledger is LIVE end-to-end. The plan's premise is false.

The plan claims "the ROE/stealth scoring inputs feed a dead ledger." Traced against code, the **entire
contact loop is wired and banking real XP**:

- **Input, spawn side:** `field_director.gd:43` calls `state.register_group(...)` the moment an enemy
  spawns → `MissionState.register_group()` (`mission_state.gd:37`) adds it to `_known_groups`.
- **Input, detection side:** an enemy reaching COMBAT *witnessed* calls out at `enemy_base.gd:913-914`
  → `field_director.report_contact()` (`field_director.gd:48`) → `state.report_detected()`
  (`mission_state.gd:27`), which increments `contacts_detected` once per group (one-way, per-group).
- **Compute:** `MissionState.build_result()` emits `contacts_detected` and `contacts_avoided()`
  (`mission_state.gd:66-67`; avoided = `_known_groups − _detected_groups`, `:42`).
- **Score:** `DebriefScreen.compute_score()` (`debrief.gd:32-42`) pays `+25/−25` per avoided/detected,
  `−damage`, `+50` speed, `+75` ghost bonus (`_ghost_bonus`, `:19-21`), `−100` POW.
- **Bank:** `field_director._bank_patrol()` (`field_director.gd:1070`)
  `CampaignState.team_xp += maxi(0, DebriefScreen.compute_score(result))`, at the wire, as a toast.

So **ghost bonus is LIVE** (reads `result["shots"]`, set at `_bank_patrol:1068` from
`WeaponHolder.session_shots`). **Contact avoidance/detection is LIVE and priced into team XP.** The
"dead ledger" framing describes a world that predates the ADR-006 implementation.

### What is genuinely DEAD

**`_record_noncombatant_death()` (`civilian.gd:385-386`) is the one real dead hook.** It is empty,
called on every noncombatant death (`civilian.gd:378`), and its comment explicitly forbids scoring
without a decree. Nothing else in the repo records a civilian death: grep for `noncombatant` across
`scripts/` finds only the civilian file, the CombatManager satchel-spare guard (`combat_manager.gd:164`),
and doc/comment references. **Civilian killing has zero data spine, zero witness context, zero
consequence** — exactly as `civilian.gd:4-7` states. This is the actual "dead ledger."

### Ambiguous / out-of-scope: the DebriefScreen fossil

`game_flow.gd:167,181` still instantiate the full `DebriefScreen` on `_on_mission_ended`. ADR-029
deleted the debrief *screen* for the open-patrol loop, where the AAR is a toast (`_bank_patrol`). This
screen path is a likely fossil on the open-patrol mission type, but it is **out of scope for W5** and is
a separate fossil-law question — flag it, don't touch it here.

---

## 2. Is ADR-006:67 drift? — YES.

ADR-006 Consequences/Buys line 67: *"Re-activates the payoff side of already-shipped stealth systems
(ghost bonus, silent movement, threat cooling) that currently feed a dead ledger."*

Measured against code today:

- **"ghost bonus"** — LIVE in `compute_score` (`debrief.gd:38`). Not dead.
- **"silent movement"** — is a **squad SKILL** (`skill_catalog.gd:12`, a spendable upgrade "Quieter
  footsteps"), **not a score input at all**. It never fed any ledger; it's a purchase. Mislabeled.
- **"threat cooling"** — **zero hits repo-wide as a score term.** It exists only as AI behavior
  (awareness decay), never as a debrief input. Naming it a ledger input is a phantom.

**Verdict:** ADR-006:67 is a **stale projection**. It was written 2026-07-10 in the *future tense of the
decree* ("re-activates… that currently feed a dead ledger") describing the pre-implementation state,
where `compute_score` paid `kills×10` and no contact tracking existed. Post-implementation, the contact
ledger is alive; and two of its three named items were never score inputs. Per the standing "no more
drift — correct on contact" law, **this line should get a dated pointer correction**: the ledger is
LIVE (cite `field_director.gd:43/48/1070`), ghost bonus is LIVE, and "silent movement"/"threat cooling"
are an upgrade and an AI behavior respectively — not ledger inputs. This is a documentation fix, not new
work; note it in the ADR, do not read past it.

---

## 3. The minimal in-scope build — fill `_record_noncombatant_death` as TRACKING ONLY

**Scope discipline:** the hook's own comment (`civilian.gd:383-384`) and Pillar 5 (fail-forward, "not a
sadism simulator") forbid a scoring or fail-state term without a decree. So the minimal build is a
**data spine with witness/ROE context and NO score, NO XP, NO fail-state.** It makes the hook honest
(kills the dead-hook lie) and gives a future Summoner-blessed consumer something real to read.

**Build (small, self-contained):**

1. **Capture witness context at death**, reusing the ADR-005 witness machinery rather than re-deriving
   it. A civilian killed with a surviving observer is materially different from one killed cold — that
   is the exact semantic ADR-005 already encodes (`enemy_base._can_witness`, `_witness_check`;
   `field_director.gd:58` "a silent, unwitnessed kill leaves the AO cold"). Record a `witnessed: bool`
   — true if any live enemy OR any other live civilian has LOS to the death position at kill time.
2. **Accumulate on `MissionState.flags`** (the generic extras channel already merged into `build_result`,
   `mission_state.gd:11,51-52`): `noncombatant_deaths` (int) and `noncombatant_deaths_witnessed` (int).
   No new score keys. These ride into `result` for free and surface nowhere until a consumer is blessed.
3. **`_record_noncombatant_death(_killer)`** resolves the active `MissionState` (via the field
   director / world), increments the two counters, and records witnessed-ness. That is the whole change:
   the empty `pass` becomes a two-counter tracking write. `compute_score` is **not touched** — no −X per
   civilian, no fail-state.
4. **Guard it with a headless probe** (Verification Law): spawn a civilian, kill it witnessed and
   unwitnessed, assert the two counters move correctly and that `compute_score` is **unchanged** by the
   death. A tracked-but-unsurfaced counter is itself a latent fossil/pointer risk unless a probe pins it
   live — the probe is what keeps this from becoming the next dead hook.

**Why this and not more:** it fills the acknowledged attach point, inherits witness semantics from
ADR-005 so a future ROE consumer doesn't reinvent them, and stays strictly inside "tracking" — the one
thing the hook's decree-comment permits.

---

## 4. Reserved for the Summoner — and the tradeoff, named both ways

**Reserved (do NOT build without his decree):**

- **Any SCORING term** for noncombatant deaths (−X to score / team_xp). The ADR-006 economy and any
  re-host of it is **explicitly Summoner-reserved** (ADR-006 pointer correction `:12-14`: "Whether and
  how this economy re-hosts in the open-patrol AAR is an open question for the Summoner, not settled
  here"). A war-crime price is an economy change.
- **Any XP-bias / fail-forward escalation** — AO heat, faction reaction, morale, informer cascades
  driven by civilian deaths. That is a *fail-state-adjacent* mechanic and lands squarely on Pillar 5
  ("escalation not fail-states… not a sadism simulator"). Design call, not an implementation detail.
- **Surfacing at the AAR** — the AAR is now a toast (`_bank_patrol:1075`), not a screen (ADR-029). Adding
  an ROE line to the player-facing report is an AAR re-host decision, the same reserved question as the
  economy re-host.

**Tradeoff — no free lunch, both directions:**

- **If we build tracking-only (recommended):** we get an honest hook and a real data spine, and we stay
  inside the decree. *Sacrificed:* the number is invisible — no player feedback, no behavioral pressure,
  ROE discipline still unpriced. A civilian massacre still costs the player nothing *in the moment*, and
  an unsurfaced counter risks reading as "done" while the actual feature (consequence) isn't. We must
  file the reserved decision plainly for the Summoner so the counter isn't orphaned.
- **If we surfaced/scored now (rejected):** we'd give ROE immediate teeth and close the loop in one pass.
  *Sacrificed:* we'd override a Summoner-reserved economy re-host without his ruling, and we'd risk a
  fail-state term against Pillar 5 and flatten the ADR-005 nuance (witnessed vs cold kills mean different
  things) into a blunt penalty. That is over-scoping a moral mechanic on guesswork — the exact failure
  mode the War Room exists to stop.

**Bottom line:** the stealth/ROE contact ledger is alive; ADR-006:67 is drift and needs a pointer
correction. The only dead thing is the noncombatant hook — fill it as witness-aware TRACKING behind a
probe, and put the scoring/surfacing/escalation decisions to the Summoner.
