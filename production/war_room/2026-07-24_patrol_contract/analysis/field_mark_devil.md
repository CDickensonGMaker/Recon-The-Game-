# Devil's Advocate — THE PLAYER FIELD-MARKING LAYER

**As of 2026-07-24.** Read against code, not the plan. Verdicts cite `file:line`/ADR. No free lunches.

---

## 1. §4 RESURRECTION — the proposed probe guards the WRONG DOOR

The briefing's probe ({kind, map_pos, placed_at}, no `completed` field, command never reads marks,
no counter) is **NOT sufficient**. It firewalls the in-field/command path and leaves two open doors:

**Leak A — the DEBRIEF path.** Synthesis R2.2 (`synthesis.md:46`) makes ground-covered accrue silently
on MissionState and **surface at `_bank_patrol` (`field_director.gd:1066`)**. The moment the AAR reads the
marks array — "features checked," "2 tunnels sighted, 1 camp glassed" — the marks become a **scored,
per-kind tally presented to the player**. That IS the progress tracker §4 bans (ADR-029:30), only
deferred to the wire. No `completed` field is needed: `marks.filter(k==CAMP).size()` reconstructs
"3 camps found" from raw data. The probe as specced never asserts `compute_score`/`_bank_patrol`/the
AAR-string builder don't touch marks. **That is the actual §4 boundary and it is unguarded.**

**Leak B — CONTACT folds the net-report verb into marks (briefing:15-18).** A CONTACT mark that command
"calls over the net" and then *retasks toward* is `raise_crisis` retarget (`synthesis.md:12`) reading a
**player mark as selection input** — route-as-authority creep, the very thing R1 spent its budget
forbidding. Clause 3 (`synthesis.md:48`) says command references features/ordinals, "never a player
waypoint"; a CONTACT mark command reacts to is a player waypoint by another name.

**Required probe additions (else §4 is cosmetic):** (a) no scorer/AAR/`_bank_patrol` code path reads the
marks array; (b) the AAR string emits no per-kind mark count; (c) `_pick_patrol_location` /
`raise_crisis` take no mark as input. Without these three, marking is a backdoor objective list.

## 2. IMPRECISION FRUSTRATION — a tuned error model is gold-plating on an unproven verb

A stably-wrong CAMP mark 50m into empty jungle is **not** fog-of-war depth; it is the player learning his
own tool lies and *abandoning it*. That is strictly worse than no mark — it also poisons the map, which
ADR-022 sells as "your memory." A memory aid you can't trust is a liar, not depth. Building a
range-scaled deterministic offset model (ADR-010-clean per op seed) is a whole subsystem authored
**before one playtest has answered "does dropping a mark feel good."** The first playtest rewards the
*act* (aim, press, symbol lands, satisfying), not a calibrated error curve. **Defer the imprecision
model entirely; MVP places where you look.** Imprecision is a Phase-3+ texture pass, gated on marking
being fun at all.

## 3. THE THIRD AIM PATH — there are already TWO, and the input is out of keys

Systems ruled "reuse the ray-march, no THIRD aim path" (briefing:51). **But two divergent ground-aim
implementations already exist:**
- `field_director._cas_ground_target:688` — ray-march, RTO/net-gated, for fire.
- `squad_system._aim_ground_point:181` — a *separate* ground-aim for `squad_move` (X key).

They already diverge (ADR-023 smell). A mark verb is the **third caller** and there is no shared seam to
reuse — "reuse the ray-march" means routing squad + mark through `_cas_ground_target`, a refactor nobody
scoped.

**The input is worse.** Marking must land a world point with the **rifle in hand** (LOS-gated; binos for
ranged — briefing:24). In the world `fire`=LMB and `aim`=RMB are the trigger and ADS; they only remap to
send/withdraw *while on the net* (`field_director.gd:187-194`). So mark cannot be LMB/RMB in the world
without stealing the trigger. The key wall is full: C/H/X/N = squad (`project.godot:210-233`), T =
radio/CAS (`:234`), G/F/R/5/6 = kit. **There is no free press near the thumb.**

**And "one verb, whole vocabulary" is a fiction:** CONTACT is net-gated, TRAIL/TUNNEL are LOS-free notes,
CAMP is binocular-ranged-and-still. Three different gates wearing one icon. That is three verbs, not one
overloaded verb — and overloading one keypress across three gate-states is how the fire-menu's
mode-mirror bugs (`field_director.gd:220-245`) get re-created on a new surface.

## 4. PERSISTENCE TRAP — smuggles ADR-017 province scope into a marking feature

Banking marks to a firebase AO map (briefing:37-39) = **save-schema growth + accumulation (dedup/cap) +
stale-decay (camp moved → mark lies)**. That is exactly ADR-017 persistent-province, and the briefing
admits the tie. ADR-029 **just deleted** the `offers`/`accepted_offer`/`hub_snapshot` save chain
(`ADR-029:48-49`); re-growing the save schema for a marking MVP re-opens the wound the pivot just closed.
**MVP: marks are patrol-local, die at the AAR** — the CO's sweep circle already does exactly this
("the next patrol's circle replaces it," `topo_map.gd:136-137`). Marks inherit that lifecycle: drawn on
`_overlay`, gone at the wire. Zero schema bump, zero decay logic. Multi-patrol AO knowledge is a separate,
later ADR-017 decision — not a rider on a pencil.

## 5. SCOPE/SEQUENCING — marking is P2 at the earliest, and premature before the SPINE playtest

Phase 1 is defined as **"NO new UI"** + route-as-input + silent ground-covered + the four §4 probes
(`synthesis.md:82-85`). Marking violates **every** P1 criterion: new UI (icons on `_overlay`), new input
(a verb + keybind), a new world-aim path, AND a new §4 surface (typed intel one field from a tracker).
It cannot be P1.

Worse, it is downstream of an **unproven** question. The P2 pencil gate is "does the drawn route change
tasking meaningfully" (`synthesis.md:87`). Until a playtest proves the mark-free SPINE — leave camp, wire
gate, find a site, fair contact, AAR (the standing **PLAYTEST R4** entry gate, CLAUDE.md) — is *fun*,
marking is polish bolted to a loop we haven't confirmed works. That is the exact premature gold-plating
the devil exists to kill.

**Sequence:** SPINE playtest (R4) → route pencil (P2, its own gate) → **marking rides the same pencil
pass as P2's tail**, and only the LOS-free note marks (TRAIL/TUNNEL/CACHE, place-where-you-look).
CONTACT (net-coupled → §4 risk) and CAMP (binocular/imprecision → a subsystem) defer further.

**ADR-023 note:** marks live on MissionState beside ground-covered, rendered by `topo_map._overlay`.
A `MarkManager`/`IntelLayer` node is the fossil — the same trap systems flagged for RouteManager
(`synthesis.md:12`).

---

## Two most dangerous problems
1. **The §4 probe guards the in-field door and leaves the DEBRIEF door open** — the AAR/`_bank_patrol`
   reading marks by kind is a deferred "3 camps found" tracker; CONTACT marks feeding `raise_crisis` is
   route-as-authority. Probe must forbid scorer/AAR/selector from reading marks (§1).
2. **No clean third aim path and no free input** — two divergent ground-aim funcs already exist
   (`_cas_ground_target:688`, `_aim_ground_point:181`); LMB/RMB are the trigger in-hand; the keyboard is
   full; "one verb" is really three differently-gated verbs (§3).

## MVP / sequencing call
Marking is **P2's tail, not P1**. Ship the SPINE and get R4 verified FIRST. Then MVP marking =
**patrol-local (dies at the AAR like the sweep circle, no persistence/decay/schema), LOS-free note marks
only (TRAIL/TUNNEL/CACHE) placed where you look (no imprecision model), on MissionState + `_overlay` (no
node), with the three debrief/selector probe clauses added to §4.** CONTACT-net coupling, binocular CAMP
ranging, imprecision, and multi-patrol AO persistence are each separately gated and deferred.
