# UX DESIGNER — THE PROGRESSION SPINE
## War Room 2026-09-09 · lens: legibility, feedback, the r4bk law, the period-HUD cap

**Method:** read `briefing.md`, `measurements.md`, `evidence_pack.md`, then the code they point at
(`combat_posture.gd`, `vo_manager.gd`, `field_mark_verb.gd`, `squad_system.gd`, `mission_hud.gd`,
`player.gd`). Static reading only. Nothing here was playtested.

**My verdict in one line:** *the command grammar is not the problem, and the cursor was never the
problem. The problem is that this game's best system is invisible, and every rung of the proposed
ladder is a promise to make something visible that the game currently cannot show.*

---

## 1 · THE CENTRAL UX PROBLEM: SUPPRESSION HAS NO OUTPUT

`combat_posture.gd` is the deepest system in this codebase — `SUPPRESS_PIN 0.7`, `CROUCH_SUPPRESS 0.6`,
cone spread to ×3.2 at the ceiling, a 4 s pin-mercy grace, prone commit and dwell timers — and the player
has **no channel to observe any of it.** `vo_manager.gd` has zero suppression lines. `mission_hud.gd`
has zero suppression readout. That is the r4bk law failing at full scale: *the deep half of Brothers in
Arms is built and none of the legible half is.*

Everything below is downstream of this. Ordering men to attack an enemy whose state you cannot read is
not tactics, it is dice.

### Candidate A — THE VOICE FALLS APART *(rank 1)*
Enemy VO is already per-speaker stable across three Vietnamese voice sets and carries ten recorded lines
(`assets/audio/vo/vi_*/`). Bind the *pattern* of that chatter to `suppression_level`, in three bands:

- **≤0.35 — working.** Coordinated, multi-speaker: `spotted_us` → `advance` → `flanking`, from two or
  three different men. This is what an unpressed position sounds like today.
- **0.35–0.7 — pressed.** `taunt` and `advance` stop firing. `reload` starts — **and `enemy_reload.wav`
  is recorded in all three voice folders with ZERO callers anywhere in `scripts/`** (grep: `play_enemy(`
  never passes `"reload"`). It is a finished asset waiting for exactly this. Lines now come from ONE
  speaker, not three.
- **≥0.7 — pinned.** One short urgent line, then **silence**, for the dwell.

The tell the player learns is **loss of coordination, then silence.** No indicator, no meter, no HUD.
It is the red-ring-to-grey rendered entirely in audio, and it works at any range you can hear.
**Sacrificed:** the soundscape goes *quiet* at the climax of a fight, which pushes against Pillar 2 at
the exact moment atmosphere is doing the most work; and a player in heavy rain, or with the mix low,
gets nothing.

### Candidate B — THE TRACERS ANSWER *(rank 2)*
Suppression already widens the return-fire cone to ×3.2. Make that widening *visible*: mandate tracer on
enemy return fire, so a fresh position puts rounds cracking past your ear and a pinned one puts them
into the canopy. Pair it with one animation — **blind fire**, rifle held over the log, not shouldered.
A man shooting with his weapon above his head is unambiguous at 45 m through jungle in a way no colour
or icon is. **Sacrificed:** this is the expensive one — an animation clip per enemy archetype plus a
tracer pass, and tracer density is a period-honesty argument waiting to happen.

### Candidate C — YOUR OWN MEN NARRATE IT *(rank 3)*
New `play_squad` lines keyed to the aggregate suppression of the target group: *"they're down"* /
*"he's up again."* This is the most legible of the three and the least suitable, because **it dies at the
bottom of the ladder** — the solo player, who needs it most, has nobody to say it. It is also fighting
`MAX_CONCURRENT_FIELD 2` and `SPEAKER_COOLDOWN_S 3.0` for airtime.

**Ranking: A, then B, then C.** Ship A and B as one feature; C only as a top-rung bonus.
**Named sacrifice for the whole approach:** suppression legibility becomes *range-limited*. Beyond
~60 m in canopy you can neither hear him nor see his posture, so fire-and-maneuver only teaches itself
at close range. That is honest, and it is a real loss against BiA's ring, which taught at any distance.

---

## 2 · THE WEAPON IS THE INTERFACE — AND THE TRIFECTA IS MISSING TWO LEGS

`_aim_ground_point()` (`squad_system.gd:328-344`) is already the answer to the cursor question: one 250 m
camera ray, layer 1 only, *"so his own men are never the destination."* That is correct and must be kept.

Against the trifecta, as built:

| | Today | Verdict |
|---|---|---|
| **(a) WHAT did I order** | one toast, `"SQUAD: MOVE THERE"` | passes |
| **(b) WHO heard it** | one man speaks for eight (`play_squad`) | **fails** |
| **(c) WHERE did it land** | nothing; a missed ray is silently dropped (`squad_system.gd:286-288`) | **fails** |

**The confirmation trifecta, using only 1967:**

- **(a) READBACK.** The man who takes the order *says the order back.* Voice procedure in 1967 was
  readback-based; this is the most period-honest confirmation available and it costs recordings, not
  screen. Keep the toast as the subtitle — VO is additive here by house rule (`vo_manager.gd` header).
- **(b) THE LOOK.** Every man who receives the order **turns his head to the player for ~0.4 s before he
  moves.** The ack is a body, not an icon. Reinforce it inside the roster strip, which **already carries
  per-man sub-lines** — the RTO's `ON THE NET` row and the pointman's `scanning 34m` row
  (`mission_hud.gd:285-291`). A 1.5 s ack flash on a name row therefore adds **zero new persistent
  elements** and stays inside ADR-030's four (compass, roster, ammo, reticle).
- **(c) THE MAN IS THE MARKER.** Never draw the destination — a marker is one clause from an objective
  pin (patrol contract R2). Instead, **the first man to arrive kneels and faces outward.** The point is
  legible because somebody is standing in it. Before arrival, the confirmation is simply that men are
  visibly moving.
- **THE MISS.** An order ray returning `Vector3.ZERO` must never be silent again. Answer it with a
  refusal bark — *"say again"* — plus the toast `SAY AGAIN - COULDN'T SEE IT`. A refusal is information;
  silence is a bug report.

**Sacrificed:** ~8 new VO lines minimum across two squad voices (this project's slowest pipeline), and a
head-turn state that will fight the COMBAT aim state for the neck. The look-ack must lose to combat
aiming, which means the ack is weakest exactly when orders matter most.

---

## 3 · THE ORDER/FIRE COLLISION — RULING

**An order may never share the trigger in a mode the player can enter, or remain in, by accident.**
Toggled order modes are forbidden outright.

It *may* share the trigger under a **held key**, because a held key is self-evidencing — you cannot
forget you are holding it. Concretely:

1. **Enter:** hold `X` (the existing order key) for ≥120 ms. A fumbled tap is still a plain MOVE_TO.
2. **The state is shown by the weapon, not the HUD.** On arming, the viewmodel **lowers off the shoulder
   and the off hand comes up in a signal.** The reticle does not change; nothing is added to the screen.
   ADR-034 already gives every weapon its own viewmodel and lens, so the mode indicator is the gun —
   this is literally "the weapon is the interface," and it costs no HUD budget.
3. **While held, the weapon CANNOT FIRE.** No frame is ever ambiguous. Pulling the trigger while `X` is
   down issues the aggressive attack at whatever is under the reticle; it can never discharge a round.
4. **Exit:** release `X`. The weapon comes back up. One clean edge in, one clean edge out.

This closes both failure directions: you cannot shoot while ordering (the weapon is down), and you cannot
order while shooting (the modifier is not held). **Sacrificed:** a viewmodel gesture clip per weapon; and
the aggressive attack becomes a two-handed input under fire, which is when the player is worst at inputs.
Expect the first playtest to call it clunky. I judge that friction correct under Pillar 1, but it is a
real cost and it will be reported.

---

## 4 · THE KEYSPACE — NO FIFTH KEY. RULED.

There is a shipped precedent for exactly this problem: `FieldMarkVerb.infer()` — **one verb, four nouns,
the noun taken from the highest-priority thing under the reticle** (`field_mark_verb.gd:20-52`). The
report verb never needed a menu and neither does the order verb.

**Decree: `X` is the only order key, and its meaning is inferred from what is under the reticle.**

| Under the reticle | Order |
|---|---|
| ground / terrain | **MOVE THERE** → hold and defend on arrival *(as today)* |
| a living enemy | **ATTACK THAT** *(aggressive variant = §3's held-modifier + trigger)* |
| nothing, or a squad member | **REGROUP** |

`C` / `H` / `N` keep their current meanings; ADR-012's permanence is untouched; the 2026-09-07 council's
*"no fifth key"* stands. REGROUP is not new — it is `C`, and its toast should simply read `REGROUP`
rather than `ON ME`. ATTACK is not a new key — it is `X` pointed at a man.

**One code consequence:** `_aim_ground_point()` masks **layer 1 only**, so enemies (layer 3) are
invisible to it today. Inference needs a second ray on `1 | 4`, the same shape `_report_field_mark()`
already uses (`player.gd:268`). Cheap.

**Sacrificed:** `X` becomes ambiguous. A player pointing at dirt with an enemy near the reticle gets
ATTACK. The field-mark verb carries the identical hazard and survives it on a strict priority ladder, but
here the consequence is men dying rather than a wrong map pin. **Therefore §2's readback is a HARD
DEPENDENCY of this ruling, not an enhancement** — an inferred verb you cannot hear confirmed is worse
than a fifth key.

---

## 5 · THE LADDER, FELT WITHOUT A SCREEN

**The rule I would decree: a rung is announced by a thing changing hands or a man changing behaviour —
never by a message. The reward is delivered at the bunk, before the patrol.** That reuses
`sleep_station.gd` / ADR-039 and adds nothing to any screen.

1. **Solo → supplied RTO.** You wake and **there is a second man on the next bunk with a PRC-25 on the
   floor.** Nobody explains him; he walks out the wire with you. The felt tell is that the shipped radio
   sub-line `ON THE NET - [T]` (`mission_hud.gd:311-317`) appears for the first time in your life.
2. **Supplied → borrow anyone.** No announcement at all. The change is that a stranger's nameplate
   (`squad_nameplate.gd`, ≤5 m) now resolves his **role** where before it showed only a name. *Role
   appearing is permission granted.* Wordless, and it runs on shipped machinery.
3. **Borrow → companion.** He is **standing at the wire when you walk out**, and says one line: his name.
   The felt change is that you no longer have to go find one.
4. **Companion → own handset.** The handheld is **on your bunk when you wake**. `project.godot:250-254`
   already declares an unreferenced `radio` action on `G` — an ADR-023 fossil that is also the obvious
   bind. The felt change: `OFF THE NET - RADIO 34m` never appears again.
5. **Handset → men.** They are **already outside, already kitted, waiting on you.** The roster strip goes
   from one row to eight. The title lands as **one bark from one man, once, unprompted** — never a banner.

**Sacrificed:** a player who never sleeps or never returns never sees his promotion, which quietly makes
the firebase load-bearing in a game whose Pillar 3 forbids rails. Mitigated only because every rung is a
*gain* and never a gate (ADR-018's ladder law). Second sacrifice: "wake up and find a change" is a device
that gets thin by its fifth use — rungs 3 and 5 should break the pattern deliberately.

---

## 6 · THE BORROWED RADIO — WORDLESS, AND NO DIALOGUE SYSTEM

**Ruling: build no dialogue system.** Three reasons. There is nothing to "connect to" — the grep returned
zero, so this would be a new subsystem on the critical path of a post-demo feature. A dialogue box is a
screen, and anything re-readable is forbidden by the briefing-screen line. And wordlessness is simply
truer: you do not negotiate for a radio, you put your hand out.

**The handset offer.** Approach an NPC RTO inside ~3 m and look at him. He is already *doing* something —
map, coffee, handset to his ear.

- **AVAILABLE:** he **stops and turns his head to you.** Nameplate resolves. `[F]` appears — the shipped
  prop-grab (`player.gd:438-451`, `:1055-1058`).
- **COSTLY:** he holds the handset out **but does not let go of the set.** The 10 m leash becomes a thing
  you can see: a short cord tying you to a man who is not yours and who will not move for you. ADR-011's
  designed hardship, stated by the world instead of by a number.
- **REFUSED:** **he does not turn.** He keeps working. No `[F]`, no error, no `REFUSED` toast. *A man who
  does not look at you has not agreed* — that is the whole refusal grammar, and it needs no words.
  Refusal triggers: he is in contact; he is mid-transmission (`play_radio` already enforces *"one net,
  one voice"*); his faction dislikes you; your tier is below the rung.

This inherits the exact affordance discipline `radio_state()` already documents in code — *"the player
must see he is off the net BEFORE he presses T, not as a refusal after."*

**Sacrificed:** with no dialogue, the borrowed RTO can never become a character, so the companion rung
above it must carry all the characterisation on barks alone. And refusal-by-not-looking has a genuine
failure mode: **a player reads a non-responsive NPC as a broken NPC.** The refusing man must be visibly,
legibly busy — animation playing, handset to ear — never idle.

---

## 7 · SOLO LEGIBILITY — THE STRONGEST ARGUMENT AGAINST THE PIVOT

Taken seriously: **the squad is currently an information system, and going solo deletes it.**

What is lost, concretely:
1. **Early contact detection.** The pointman is a spotting system with a rendered radius
   (`mission_hud.gd:289-291`). Solo, your first knowledge of an enemy is being hit by him — and under the
   fear/lethality doctrine that is death, not tension.
2. **Direction.** `show_damage_direction()` exists, but it fires *after* you are shot. The squad bark
   fires before.
3. **A check on your own error.** A man saying *"watch it"* is a second pair of eyes on a bad decision.
4. **The soundscape itself.** Pillar 2. Silence is not atmosphere; silence is absence.

What can replace it:
- **The world's voice replaces the squad's.** Ten enemy lines are already recorded and per-speaker stable.
  Solo, `enemy_spotted_us` *becomes* the contact call — you are told you have been seen, in Vietnamese,
  from a direction. That is better information than a squadmate's, and the asset cost is zero.
- **Sharpened hearing.** Field VO runs at `max_distance = 45.0`. Solo, the squad's own noise floor is
  gone, so raise that reach for the lone player. He hears further because nobody is talking over him.
- **Ecology as the pointman.** Birds leaving a treeline is the period-honest early-warning system, and the
  ambient ecology already exists to carry it.

**But I will not pretend this is answered.** Two of the four losses are replaced by systems that *do not
exist yet*, while the loss itself lands on day one of the pivot. So:

> **My binding recommendation: the solo rung must not ship until the world has a voice.** Sequence the
> suppression legibility work (§1) and enemy-VO-as-contact-call BEFORE `SquadRoster.ensure_roster()`
> stops self-healing to eight (`squad_roster.gd:178-179`). Reverse that order and the first solo playtest
> reports *"it's empty and I die to things I never heard"* — and that verdict will be correct.

**One door to keep open, from this lens:** the roster strip is the only per-man information surface in
the game, and it is hard-built around a fixed squad. Anything that assumes eight rows — layout, anchor,
the `-310` y-offset (`mission_hud.gd:259`) — should be made size-driven now, while it is free.
