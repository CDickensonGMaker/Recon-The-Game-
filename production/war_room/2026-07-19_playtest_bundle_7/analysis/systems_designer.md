# SYSTEMS DESIGNER — playtest bundle 7 (2026-07-19)

Assignments A (item 1, fire support), B (item 3, camp life), C (item 5, punji traps),
D (item 6, informer). Recon facts taken as given; code read to ground every number below.

---

## A) ITEM 1 — THE FIRE SUPPORT ECONOMY

### The injection point ADR-011 lost, and where it goes instead

ADR-011 says budgets are "rolled at briefing, per mission type," injected via
`mission_generator`'s `fire_support` dict. ADR-029 deleted the briefing, the offer chain and the
mission-type fleet. So the ADR-011 clause has no host. `mission_generator.gd:437`'s
`{"mortar": 1}` is dead data (recon confirmed zero readers), and the live budget is forever
`field_director.gd:194`.

**RULING: the budget is PER PATROL, granted at the OUTWARD wire crossing.**

The event already exists and is already the canonical patrol boundary. `_poll_wire_gate()`
(`field_director.gd:474-497`) fires `patrol_out = true`, bumps `patrol_count`, calls
`CampaignState.begin_mission()` and picks the location; the inward crossing calls `_bank_patrol()`
(`:544-560`) which **already replaces `state` with a fresh `MissionState`**. The per-patrol ledger
boundary is built. The budget belongs on the same edge — one `_grant_fire_support()` at the
outward crossing.

Rejected alternatives, with reasons:

- **Per-day / sim-clock refill.** REJECTED. The player has no legible read on the day boundary at
  the moment he steps out, so the resource would appear and vanish for reasons he cannot see. A
  budget he cannot predict is not an economy, it is weather.
- **Resupply purchase at the firebase.** REJECTED, and it is the dangerous one. A shop is a
  mission/operations layer with a screen, and ADR-029 §4/§7 condemned exactly that ("no
  player-facing mission tracking, ever"). The firebase is a place you walk out of, not a
  storefront.
- **Persistent campaign stockpile.** REJECTED for this slice — it makes hoarding optimal, and a
  hoarded arty mission is a patrol the player refuses to fight honestly.

### The numbers

Base grant per patrol, RTO at `fo_fac` 0:

| verb | grant | why this number |
|---|---|---|
| **mortar** | **3** | The firebase's own tube — the only asset that is diegetically *yours*, from the base you just walked out of. Cheap, short-reach, scatters wide at fo 0. Three = one call to break contact, one to soften, one for the bad moment. The current 2 means one mistake empties the net. |
| **arty** | **1** | A battery mission is 6 rounds × 200 dmg / 14m (`_arty_impact`, `:331-340`). That is a village-killer. Exactly one per patrol. It is the "we are being overrun" button, not an opener. |
| **bombs** | **1** | Fixed-wing is on-station by luck. One snake-eye run is the answer to a treeline. |
| **napalm** | **1** | Same scarcity as bombs, and Pillar 2 earns it a guaranteed slot — napalm over the canopy once a patrol is atmosphere the player will remember. |
| **cbu** | **0** | Not a patrol-scale asset, and its key is still double-bound with `place_claymore` (physical 54, `project.godot:146-149` vs `:191-194`). Shipping it live before the keybind fix is shipping a known bug. |
| **spooky** | **0** base | A 30-second gunship orbit is a firebase-defense weapon. Earned, not granted (below). |

Total steel per patrol: 3 mortar + 3 heavy calls. That cannot clear a 4-7 man village AND a 4-6
man camp AND survive a hunter wave. It can save one of them.

### The earn hooks — scarcity must be legible, or it is just a locked door

Five "NONE AVAILABLE" answers is what the owner hit. Fixing that is not only about grants; the
player must understand that the empty slots are *earnable*, not broken.

1. **`fo_fac` scales QUALITY, never QUANTITY — with one exception.** ADR-011 already gives the
   RTO's skill three effects: scatter 1.0→0.45, cooldown 25−2×fo (floor 10), and the veteran 4th
   mortar round. Adding count-scaling would make one skill quadruple-dip and would let a levelled
   RTO turn the sky into the default answer to every problem. The single exception:
   **`fo_fac` ≥ 6 → +1 mortar (3→4).** That is a Pillar-4 payoff you can feel without changing
   which verb is optimal.
2. **ESCALATION GRANTS ARTY. `+1 arty` the first time `_escalation_active` flips** in a patrol.
   This is the ruling I care most about. When the AO wakes (ADR-005 witness rule, honestly
   stamped), battalion notices there is a fight and releases steel. Consequences:
   - It is Pillar 5 in its purest mechanical form — getting made *buys* you something.
   - It sets the two routes in honest opposition: **the ghost is paid in score (ADR-006 +25/contact
     avoided); the loud player is paid in ordnance.** Neither is a gate (Pillar 3), and neither
     dominates.
   - It structurally prevents fire support from being the optimal opener, because you cannot have
     the second arty mission until you have already been detected.
3. **`spooky` 1 on NIGHT patrols only.** Spooky flew nights. The SimClock is live. This costs zero
   UI, is diegetically true, and gives a real reason to walk out after dark (Pillar 2).

### Is `fo_fac` the right scaling knob? — YES, but not for count

Ruled above. Count is a *battalion* decision (what the war gives you); quality is a *man* decision
(what your radioman can do with it). Conflating them makes the RTO a resource generator instead of
a person, which inverts Pillar 4. Keep the knobs separate.

### TRADEOFFS, NAMED

1. **The wire farm.** Per-patrol refill means out-in-out cycling regenerates ordnance. The gate
   only re-arms on inward crossing at ~120m walking distance, so a farm costs ~240m of walking per
   mortar round — slow and boring, but real. Ship the simple version, probe the farm, and if it
   needs a brake add: grant only if `_visited_locations` grew last patrol (you actually went
   somewhere). Do NOT pre-emptively add the brake — it is a rule the player cannot see.

2. **REQUIRED ADR-006 AMENDMENT — indirect fire marks a group DETECTED.** This is a live exploit
   and it blocks growing the budget past the table above. Under current definitions a group killed
   by arty from 350m may never reach COMBAT, and would therefore score as **avoided (+25)**.
   Long-range shelling would be the highest-scoring play in the game — the exact inversion ADR-006
   exists to prevent, and it would make fire support the optimal strategy in a single stroke.
   **RULE: any enemy group taking friendly indirect fire is marked detected at impact
   (`state.report_detected(group_id)`), regardless of its awareness.** You spent the AO's
   attention; you pay the −25. This is an ADR-006 amendment, and it ships WITH the budget or the
   budget does not ship.

3. **Carry-forward: the ADR-011 player-distance amendment is now urgent.**
   `_danger_close_to_squad()` (`field_director.gd:320-328`) still iterates squadmates only. With
   arty at 6 × 200 dmg inside `DANGER_CLOSE_M` 45.0, a player who has been handed a real budget now
   has a confirm-free suicide hole he did not have when only 2 mortars existed. Ship it in the same
   change.

4. **What is sacrificed:** the power fantasy. Six verbs on the net and only three usable calls
   means the radio is mostly a *promise*. That is deliberate — the rifle stays primary (Pillar 1)
   — but a player who reads "SPOOKY" on the panel and can never press it will read the game as
   broken unless the earn condition is spoken. The toast on a zero-budget verb must change from
   `"%s: NONE AVAILABLE"` to something that names the condition
   (e.g. `"SPOOKY: NOT ON STATION — NIGHT MISSIONS ONLY"`). Truth law (ADR-015): the panel may not
   advertise a verb whose unlock is invisible.

---

## B) ITEM 3 — VISIBLE CAMP LIFE

### First, correct the record

The briefing's headcount premise is wrong. The generator builds **4 villages (one per quadrant,
`mission_generator.gd:462`) + 3 camps (`:497`)**, not 8-10 villages. Live totals:
4 × (4-7) + 3 × (4-6) = **~20-28 garrison**, plus 2-3 ambient patrols × (2-4) = **~6-12**, so
**26-40 potential bodies** in the AO. The nearest village is **not lazy** (`:538`) and is live from
world build.

### The cost of a body — the number that decides everything

`PERF_LEDGER.md:265-284`: 65-67 live units cost ~37-40ms of AI, of which BODY (move_and_slide +
hitzone sync + anim) is 95-97%. That is **~0.57ms per live unit**. One garrison activated
= 5 men = **~2.9ms**. A tenth of a 30fps frame for one village.

### RULING: fix behaviour first. Do NOT raise `activation_range` this session.

**FIX 1 — garrisons get work (FREE, ship it).** `LazyGroup.force_spawn` (`lazy_group.gd:59-90`)
hands `patrol_route`/`patrol_file_slot` only when `group_tag.begins_with("ambient_patrol")`;
everything else falls to the outward-facing sentry branch (`:78-89`). Change: give non-patrol
groups a **local beat** — split **60% ambient/work, 40% posted sentry**. The working 60% get a
`work_pos` on a small ring (8-14m) around the group centre, re-rolled every 20-40s;
`_execute_idle` (`enemy_base.gd:1350-1359`) already walks men to `work_pos`, so this is data, not
new behaviour. The posted 40% keep `_home_facing` and get a slow scan sweep (±35° on a 6-10s
cycle) so even the statues are not mannequins.

**Cost: effectively zero.** These men are ALREADY spawned inside 120m and already paying full body
cost. `PERCEIVE_RANGE` is 150 > activation 120, so the body gate is already open for every one of
them — a moving man and a standing man inside the bubble cost the same. **We are paying for bodies
we are not using.**

Keep sentries. A camp with nobody posted is not a camp, and the 40% who stand still are what makes
the 60% who move read as *life* rather than as milling.

**FIX 2 — CampDirector's dead roles (FREE, ship it).** `camp_director.gd:100-101` writes
`work_pos = Vector3.ZERO` whenever `_stations_for_role` returns empty, and `:108-119` returns empty
for `patrol`, `sleep` and `guard`. So the day schedule *actively freezes* men on three of its
roles. Give `"patrol"` a perimeter-ring station list. Same zero cost, and it makes the hour clock
visible.

**FIX 3 — `activation_range` 120 → 160, garrisons only (PAID, BLOCKED).**
If 1+2 are not enough by eye, this is the correct next lever and **160 is the correct number**: it
sits just above `PERCEIVE_RANGE = 150.0`, so a garrison materializes *before* entering the bubble
where the body gate keeps it animated anyway — no pop-in where the player can see it. Ambient
stays 140. Cost: typically one extra site held vs 120m = **+5 men ≈ +2.9ms**.
Do NOT go past 160. At ~250m you routinely hold three extra sites = +15 men ≈ **+8.6ms** — the
entire fake-lights win from ADR-026 spent on men the player reads as specks.

### THE GATE NUMBER

**`activation_range` does not move until the windowed bench holds ≥30fps (≤33.3ms frame) at the
firebase with the current 120m setting.**

ADR-026's own status section is unambiguous: the cheap GPU wave took the bench 14.0 → 23.1fps
(71ms → 43ms) and the frame is now **CPU-bound at the ~41ms wall**. We are ~10ms over the 30fps
target *before* adding anyone. Raising activation_range today buys visible life by spending a
budget we have not yet earned. **I rule against paying it this session.** Fixes 1 and 2 are free
and are almost certainly what the owner actually saw — the men he walked past were inside 120m and
standing still.

**What unlocks Fix 3:** extend ADR-026 hot-set tiering to non-combat units. The comment at
`enemy_base.gd:584` says outright "Non-combat units are never tiered," and that is where the
headroom is: a patrolling man beyond ~90m does not need 60Hz `move_and_slide` and per-frame
hitzone sync — 10Hz with interpolated visuals is indistinguishable at that range and is a ~5×
saving on the 95% that is body cost. That is the Part B wave (ADR-025/026), and it is **out of
scope for one session.**

### TRADEOFF, NAMED

Fixes 1+2 make the near world alive and the far world exactly as dead as it is today. A player who
glasses a camp from 200m still sees an empty clearing, then walks 80m and it populates. We are
choosing to fix the camps he *stands in* and to leave the camps he *observes* broken, because the
second fix costs a frame budget we are already over. That is the honest trade and it should be
said out loud rather than sold as a full fix.

### PROBE HONESTY

Structurally probeable: garrison men have nonzero `work_pos`; N of M garrison men displaced >2m
over 10 simulated seconds; sentry fraction ≈ 40%. **"The camp feels alive" is NOT probeable** — it
is an eyes verdict (Rule #1) and must be reported as unverified until Caleb looks.

---

## C) ITEM 5 — DESTRUCTIBLE PUNJI TRAPS

### RULING: single body + health. NO hitzones.

Hitzones exist to give a *locational* model to a **man** — ADR-003's second half and ADR-016
Amendment D: HEAD fatal, TORSO ×2.5, GUT ×2.25 + bleed, LIMB ×1.0. A spike pit has no anatomy.
Authoring zone semantics for props would be inventing a second locational grammar through the back
door, and it would put junk entries in the `HitzoneTuning` bench. One body, one HP pool, no
multipliers.

### How it joins the grammar without a second router

Recon suggests reusing the civilian hitzone path (layer 512). **REJECTED** — that route registers a
trap in `AgentRegistry.civilians`, and every civilian-iterating system (ROE ledger, morale,
hearts-and-minds ADR-019) would then see a spike pit as a person. That is a lie in the map, and the
fossil law exists precisely to prevent two things being interpreted as the same thing.

**RULING: add a fifth roster — `AgentRegistry.props`** (destructible world objects) — and one
additional loop in `apply_explosion_damage` that mirrors the civilian loop exactly:
distance → `_can_damage_multipoint` → `_explosion_damage_at` → `take_damage`.

**This is not a second router.** ADR-003's one-grammar law governs damage *computation*, not roster
count. `CombatManager.apply_explosion_damage` remains the single explosion authority; the trap
implements `take_damage(amount, DamageType, attacker)` and nothing else. Adding a roster to an
existing router is the same move the civilians loop already is.

For bullets: give the trap a `StaticBody3D` child on the world layer exposing `take_damage`, so the
existing bullet hit resolution reaches it with no new code.
**FLAG — UNVERIFIED:** I did not read `weapon_holder.gd`'s hit-resolution walk. If it does not
already climb from collider to a `take_damage`-bearing node, this needs a one-line addition there,
not a new path. Verify before committing.

### HP: 30. What destroys it: bullets AND blast AND a silent manual clear.

Justified against the flat grammar (ADR-016 Amendment H, base rifle 27, no zone multiplier on a
prop):

- **One rifle round (27) does NOT clear it. Two do.** That is the whole design in one number.
- **Buckshot (9 × 35) obliterates it** — the CQB gun becomes the trap gun, which is welcome
  weapon identity now that Amendment H deleted damage-side identity entirely.
- **M79 (150) / M26 (190) / arty centre (200)** vaporize it; arty *rim* (~25) does not, two rounds
  do. Correct: ordnance clears lanes, near-misses do not.
- 30 means a trap is never a bullet sponge and never free.

**The load-bearing consequence:** firing to clear a trap emits a **150m GUNSHOT** (ADR-005). So
shooting traps is *how the stealth player gets found*. The trap is not an obstacle — it is a
question: is this worth the noise? That is Pillar 3 as a mechanic rather than a rule.

**The silent answer (required, or the trap becomes a stealth gate):** hold-to-act manual clear on
the trap — ~2.5s, adjacent, no noise, using the self-contained `armorers_bench.gd:18,56-64,75-83`
pattern with a world `Label3D` prompt. **No skill gate, no `demolitions` requirement** —
`demolitions` backs zero code today (`skill_catalog.gd:10`) and wiring it here creates a second
unfinished system inside a fix. The POINTMAN's existing `detect_ambush` scan on the
`punji_traps` group stays the free spotting answer.

### Does destroying a trap pay under ADR-006?

**NO SCORE.** ADR-006 pays avoided/detected contacts and objectives; kills already pay zero. Paying
for world objects invents a farm (traps are generator-placed and could be swept for XP), and it
would be the second inversion of the scoring economy in one bundle.

It should pay something *diegetic*: credit the POINTMAN via `SquadRoster.credit_use` on a
**spotted** (not destroyed) trap — same learn-by-doing shape as `fo_fac` at
`field_director.gd:266-269`. Pillar 4 payoff, zero score inflation, and it rewards the behaviour
we actually want (looking) rather than the one we don't (shooting scenery).

**FLAG:** a destroyed trap must set `_sprung = true` so it cannot spring, and should leave a
wrecked model in place — a cleared trap you can still see is map memory (ADR-022), and deleting the
node erases the player's own record of the ground he has covered.

---

## D) ITEM 6 — THE INFORMER

Two defects, and the handler is meaningless until the first is fixed.

### 1. Perception — the informer must obey the witness rule

`civilian.gd:159-165` starts the inform clock on **distance alone (<15m), no LOS**. This is the one
perception system in the game that never learned ADR-005, and it means a villager reports a patrol
he could not possibly have seen — through a hootch wall, at night, from behind.

**RULING: the clock starts only on `CombatManager.has_line_of_sight(civ_eye, player_eye, self)`
AND distance < 15m.** Use the canonical helper (`combat_manager.gd:288-300`) that
`enemy_base._can_witness`, `_witness_check`, `ally_base.gd:491` and `mission_trigger.gd:187`
already use — never a camera-look fake. A civilian is a witness; the witness rule is the game's law
about who may raise an alarm. The counterplay becomes legible: break LOS, or don't walk the square.

### 2. The handler — what the director actually does

Delete the `state.flags["informer_transformed"]` / `["informer_last_pos"]` writes
(`civilian.gd:326-330`) outright. `state.flags` is write-only debrief data copied out by
`build_result` (`mission_state.gd:18`, `:93-97`) — it is not a message bus, and the comment
claiming a director handler reads it is a truth-law violation (ADR-015) and a fossil.
**Replace with a signal:** `Civilian.informed(pos)` → `FieldDirector._on_informer_reported(pos)`,
one-shot guarded, in the `_check_detection()` shape (`field_director.gd:70-77`).

**What spawns:**

- **4 men.** `vc_rifleman` / `nva_regular` mix, `group_tag = "informer_response"`, via the existing
  `spawn_tracked_enemy` (`:30-44`) so the ADR-006 contact ledger registers them.
  Not 8 (a punishment wave), not 2 (a non-event). Four is one VC cell — a real fight a competent
  squad wins. **Fail forward (Pillar 5): the informer escaping makes the patrol harder, never
  failed.**
- **90-140m from the reported position, on the side AWAY from the player** — they come *from* the
  countryside, not out of the ground next to you.
- Seeded exactly like the hunter wave (`:102-105`): `last_known_target_pos = reported_pos`,
  `target_last_seen_time = 0.0`.

### 3. They spawn ALERT, not COMBAT — and the fake gunshot dies

**This is the witness-rule ruling.** The informer told them *where a patrol was seen*, not that
anyone has eyes on you. They arrive **searching**. If they find you, the normal perception path
stamps `last_combat_contact_ms` legitimately and `_check_detection()` fires on its own.

**The informer must NOT stamp the beacon directly.** Today `civilian.gd:172` emits a fake
`NoiseType.GUNSHOT` at 120m radius to force the alarm. There was no gunshot. That is a lie in the
map, and it launders detection past ADR-005 — the exact class of bug the witness rule was written
to kill. **Delete that line.** The alarm is the men arriving, not a phantom shot. The existing
toast ("THAT VILLAGER TALKED — THEY KNOW YOU'RE HERE") is the honest player-facing signal and stays.

### 4. The clock should be beatable

The current flat 25s timer is right in shape but wrong in kind: **a timer you cannot beat is not a
system, it is a punishment.** The informer has to physically reach someone.

**RULING: the clock runs only while the civilian is FLEEing, and "arrival" fires on ~60m
displacement from where he saw you** (or the village edge, whichever first). Kill him or cut him
off before that and nothing spawns. **You can chase him down** — that is the counterplay, and it is
a genuinely great Vietnam beat.

**FLAG:** this depends on the civilian's FLEE navigation actually working over 60m. If it is shaky,
ship the flat 25s clock for this session and bead the displacement version — do not ship a
displacement gate that never completes because the villager walks into a tree.

### 5. Out of scope, flagged not solved

Killing the informer *before* he transforms is a noncombatant death; killing him *after* is a clean
kill. `_record_noncombatant_death` (`civilian.gd:300-303`) is a deliberate stub carrying an
explicit "do not add scoring here without a decree." **Respect it.** But note the hole for the
record: the game currently rewards shooting a fleeing villager on suspicion, and prices it at zero.
That is an ADR-019 (hearts and minds) question, not a bundle-7 question. Bead it.

---

## SCOPE — what I would ship in one session

**SHIP:**
- A: `_grant_fire_support()` on the outward wire crossing + the table + the two earn hooks
  + **the ADR-006 indirect-fire=detected amendment** (non-optional, ships with it)
  + the ADR-011 player-distance danger-close amendment (now urgent at arty scale)
  + honest zero-budget toasts.
- B: Fixes 1 and 2 ONLY (both free).
- C: entire item — roster + HP 30 + hold-to-clear + pointman skill credit.
- D: LOS gate + signal handler + 4-man ALERT response + delete the fake gunshot.

**DEFER (named, with the thing that unblocks each):**
- B Fix 3 (`activation_range` 120→160) — blocked on the bench holding ≥30fps / ≤33.3ms at 120m.
- Non-combat activity tiering (`enemy_base.gd:584`) — the Part B wave; it is what unlocks Fix 3.
- CBU as a live verb — blocked on the physical-54 keybind collision.
- Informer displacement clock — blocked on FLEE nav confidence.
- Any noncombatant-death scoring — blocked on an ADR-019 decree.

**PROBE HONESTY:** A, C and D are honestly headless-probeable (budget granted on gate crossing;
trap survives 27, dies to 54 and to blast, `_sprung` after death; informer clock refuses to start
without LOS, spawns exactly 4 at ALERT, beacon unchanged at spawn time). **B is not** — structure
is probeable, "alive" is an eyes verdict.
