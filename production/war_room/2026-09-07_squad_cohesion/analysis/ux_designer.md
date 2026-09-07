# UX DESIGNER — Squad cohesion as a combat mechanic
**War Room 2026-09-07 · PHASE 2 INDIVIDUAL SIGHT · no cross-talk**
Lens: the r4bk Law. Evidence read: code first, docs second.

---

## 0 · THE FINDING THAT REFRAMES THE QUESTION

**Cohesion is already simulated in this codebase, under another name, and it is already announced —
badly.** Nothing in the briefing says so. Pointers, all re-read today:

- `scripts/squad/squad_system.gd:549` — `var squad_broken: bool` on the PLAYER'S squad.
- `scripts/squad/squad_system.gd:554-580` — `_update_break()` ticks every `STRENGTH_TTL_MS`, computes
  break through **the same authority the NVA break on** (`EnemySquad.break_state`,
  `scripts/enemies/enemy_squad.gd:118-124`), writes the flag onto every living man, and **toasts on the
  edge**: `"SQUAD COMBAT INEFFECTIVE - BREAKING CONTACT"` / `"SQUAD BACK IN THE FIGHT"`.
- `scripts/allies/ally_base.gd:122-137` — **nerve MOVES during a contact**: `_nerve_drift`, floor -0.30,
  -0.12 per mate down inside 25m, +0.02/s recovery in a lull.
- `scripts/allies/ally_base.gd:153-156` — `on_squadmate_down()`, which also spikes `incoming_pressure`.
- `scripts/allies/ally_base.gd:160-179` — `effective_courage()` plus **`RALLY_BONUS` 0.10 inside
  `RALLY_RADIUS` 6.0m, and ONLY when `_player_is_forward()`** — the player must be BETWEEN his man and
  the threat. That comment is explicit that proximity alone was a bug.
- `scripts/allies/ally_base.gd:186-189` + `scripts/ai/squad_coordinator.gd:105` — `has_covering_fire`,
  a per-squad census of whether anyone is actually laying down fire for this man.
- `scripts/ai/combat_goals.gd:145-164` — all three feed goal selection. Broken men take cover, stop
  closing, widen stand-off (`ally_base.gd:220,227,906,1538`).

So the honest statement of the problem is not *"should we build cohesion."* It is:

> **We built cohesion, we never named it, and the only thing the player can read off it is a
> casualty count he could already read off the squad panel.**

`break_state` is `live / peak` shifted by average courage. It is **a survivor tally**. An ambush that
kills nobody cannot shatter it. A squad that is scattered, out of contact, has lost its RTO, and is
firing at nothing is, by this function, at full cohesion. **That is the re-skin risk sitting in the
repo right now, and it is pointed the wrong way: the SIMULATION is the re-skin, and the presentation
is the part that doesn't exist.**

Second finding, a live canon violation: `GAME_GUIDE.md §5` binds — *"Where realtime needs diverge from
the tabletop (suppression, morale — RECON has neither), the divergence is named in an ADR, never
silent."* **Ally morale/break is in shipping code and no ADR names it.** Not a design gap. A
documentation gap over a shipped system, and by the POINTER LAW that is the finding, not a footnote.

---

## 1 · IS COHESION A REAL MECHANIC, OR A RE-SKIN OF SUPPRESSION/MORALE?

**Real — but only if it stops being a casualty ratio.** As shipped it is 90% re-skin.

Three things are genuinely distinct and only two of them are modelled:

| | Modelled today | Where |
|---|---|---|
| **Nerve** (this man's willingness) | YES | `_nerve_drift`, `effective_courage()` |
| **Strength** (how many are left) | YES | `break_state` — and this is what "cohesion" currently means |
| **COHERENCE** (are they one unit or five men) | **NO** | nothing |

Coherence is the missing axis: are they in their slots, in mutual support, hearing each other, on the
net, oriented at the same threat. `has_covering_fire` is the only shipped ingredient of it. Spacing
exists as follow slots (rolled 2.5–4.5m, `file_slot`, `squad_system.gd:728-733` catch-up gap) but
nothing reads it as a state.

**Ruling: cohesion is real ONLY as COHERENCE.** If the council defines it as nerve or strength, it is a
re-skin and I refuse it on fossil-law grounds — we would be building a second system that an agent
cannot tell from `break_state`.

---

## 2 · THE PLAYER-VISIBLE VERB

### **NO NEW KEY. The verb already exists, uncommanded and unlit: you rally by putting yourself between your men and the thing shooting at them.**

`effective_courage()` already pays +0.10 for exactly that, gated on `_player_is_forward`. It is the
single most Vietnam-correct verb available, it is Pillar 4 exactly (*you are IN the squad, not above
it*), it costs zero keys against ADR-012's already-spent F1-F4 + C/H/X/N, and **it is 100% built and
100% invisible.** A player has never once been told this rule exists. That is a shipped feature with
no affordance — a live r4bk breach, today, before this council proposes anything.

Everything else the player does about cohesion is the four orders he already has. There is no fifth
order verb and I will not spend a fifth prime key on one.

### THE AFFORDANCE: **THE ACK IS THE INSTRUMENT.** This is an AUDIO feature, not a UI feature.

A grunt in contact does not read his squad's cohesion. He **hears** it — or he hears nothing, which is
worse. That is the correct channel and it is the one channel with no sight-distance problem, which
matters because of the next ruling.

**RULED: cohesion CANNOT be read off the men at PSX fidelity and jungle range.** Refuse the visual
answer. At 45–90m through vegetation you cannot resolve 2.5–4.5m spacing drift, you cannot read
posture against foliage, and the only per-man identification surface in the game is a **5m, 12° look
cone** (`scripts/ui/squad_nameplate.gd:11-13`). The point man's fist is beautiful and it is legible at
8m, once, in a lull — it is a moment, not a readout. Spacing and posture are FLAVOUR. They are not the
instrument.

**The audio bank is already built.** `assets/audio/vo/john/` alone holds 25 squad lines — `contact`,
`contact_front`, `enemy_left`, `enemy_right`, `treeline`, `movement_ahead`, `taking_fire`, `man_down`,
`fall_back`, `on_me`, `moving`, `clear`, `weapons_free`, `weapons_tight` — mirrored across the voice
cast, and `SquadSystem._order_all()` already fires an ack VO on every order
(`squad_system.gd:280-291` passes `"on_me"` / `"moving"`). GAME_GUIDE §4.11 counts 162 wired lines and
notes toast text doubles as subtitles.

**So the affordance costs no new audio and no art days. It is a GATING change on lines that ship:**

1. **THE ACK CONTRACT (the whole design, in one line).** *An order that takes ALWAYS acks. Therefore no
   ack means the order did not take.* Make the ack unconditional and unskippable when coherence is
   intact, and the SILENCE at the ack slot becomes a hard, learnable signal. This is the only way
   absence can carry meaning: absence is legible only against perfect presence.
2. **CALLOUT QUALITY IS THE AMBIENT READOUT.** Gate the existing bank on coherence, not on volume.
   Coherent squad: the *directional* half fires — `enemy_left`, `treeline`, `contact_front`,
   `movement_ahead`. Degraded: the directional lines stop and only the reflex lines survive —
   `taking_fire`, `man_down`. **The player hears his squad stop telling him where the enemy is.** That
   is precisely ADR-018 §2's veteran/green table (*"callouts are late and vague"* → *"early,
   directional, and right"*) applied to a state that changes inside one firefight instead of across a
   campaign. It reuses ADR-018's own authored vocabulary at zero extra cost.
3. **ONE WORD IN A PANEL THAT ALREADY EXISTS.** `mission_hud.gd:270-271` prints
   `"SQUAD // WEAPONS FREE"`. That header is where cohesion goes: `SQUAD // TIGHT`,
   `SQUAD // SHAKY`, `SQUAD // COMING APART`. A **state word, not a bar, not a number, not a
   percentage** — the game's hatred of meters is a hatred of quantities, not of words. It is a text
   change to a shipped label, so it does not argue with ADR-030 (which defers the HUD LOOK to final
   polish) and it adds no widget.
4. **DO NOT add a per-man nerve column.** The row already carries OK/HIT/CRIT/KIA
   (`mission_hud.gd:265-269`). A second per-man column turns the panel into the stat sheet ADR-018 §1
   killed. If any per-man tell is wanted, it is the dim role line going quiet — not a value.
5. **Relocate the existing break toast into this vocabulary.** `"SQUAD COMBAT INEFFECTIVE - BREAKING
   CONTACT"` is a good line in the wrong grammar — it is an edge event, it fires once, and it fires on
   a casualty ratio the player already sees. It becomes the top rung of the same word ladder.

---

## 3 · THE r4bk VERDICT — may cohesion claim the ADR-018 §2 exemption?

### **NO. Refused, and the reason is the exact incident r4bk is named after.**

ADR-018 §2 earned its exemption on a property cohesion does not have. **Silent squad XP is UNCOMMANDED.
The player never presses a key at it.** Nothing he does with his hands can appear to break, because
nothing he does with his hands touches it. Its affordance can honestly be "the man himself," because
there is no input for the missing widget to make look dead. ADR-018 also names its own kill switch: *"if
that isn't legible enough to feel, the system has failed and must be cut rather than papered over with
a UI."*

**Cohesion is COMMANDED.** The moment it touches an order — and the Summoner's point 6 proposes exactly
that, *"gating which orders function"* — an input that worked five seconds ago stops working. That is
bead r4bk verbatim: F1–F4 were bound, the system was in the tree, and *"with zero HUD affordance the
player could not tell a dead feature from an undiscovered one"* (ADR-012, Context, third force).
A cohesion gate would not merely repeat r4bk. **It would build r4bk into the design as a feature, in
the loudest moment of the game, where the player is least able to reason about it.**

**THE BINDING RULE I put to the Arbiter:**

> **An order that does not take must be AUDIBLY refused, at the moment of refusal, by a named man.
> Ambient state is not sufficient — the tell must be attached to the press.**

And the stronger form, which I recommend over gating entirely:

> **COHESION DEGRADES EXECUTION. IT NEVER REFUSES AN ORDER.** They go — slow, late, ragged, and they
> stop at the first cover. Refusal is a wall; degradation is a ladder. This is ADR-018's own LADDER LAW
> (*"rank gates how big, never whether"*) applied one level down, and it keeps Pillar 3 and Pillar 5
> intact in the one moment they are most exposed.

Degradation is also **self-affording**: the ack comes back late and thin, the men move and you watch
them move badly. Nothing is silently swallowed, so there is no dead-feature reading available to the
player. A gate needs a new affordance; a ladder is its own affordance.

---

## 4 · WHAT IT COSTS. NAMED.

1. **The ack becomes load-bearing, so it can never be culled.** No random variety-skipping, no
   distance/priority ducking, no "he's busy" suppression on a squad-order ack. The player will hear the
   same four ack lines several hundred times in a session and they will grate. **We are spending
   audio variety to buy a silence that means something.** That is the price and it is a real one; the
   only mitigation is more takes of the SAME line, which is voice-cast cost, not design cost.
2. **We spend the game's quietest channel.** Once absence-of-callout means cohesion, we can never again
   go quiet for atmosphere during a firefight without saying something. ADR-020's Ambience Law wanted
   that silence.
3. **The FLAVOUR channel is explicitly bought and not used.** Spacing, posture, the point man's fist —
   I am ruling these are not the instrument. If the council wants them anyway, cost them honestly at
   art velocity: ~1 animation sequence per working day, for the LEAST legible channel in the game.
   **For EA I refuse them.** Against the gate, that is the difference between zero art days and a week.
4. **One HUD word joins the permanent furniture.** ADR-030 lists four persistent elements; the squad
   panel header gains a second job. Small, but it is a claim on final-polish real estate.
5. **A degradation ladder is harder to author than a gate and much harder to test.** A gate is a
   boolean a probe asserts. "They go, but badly" has no crisp pass/fail, and the verification law binds.
   That is a genuine cost of my own recommendation and I name it.

---

## 5 · ADR COLLISIONS

- **ADR-012 (input doctrine).** Only if a fifth order verb is proposed. **I refuse it** — F1–F4 and
  C/H/X/N are spent and ADR-012 names that spend as an accepted cost. Any proposal here that needs a
  key must first say which of the four it takes. Also binding: *"any order surface MUST have a visible
  HUD affordance."* Cohesion touching orders drags the whole thing under that clause.
- **ADR-018 §2.** Exemption refused, argued above. **§1 also binds:** cohesion may never touch the
  PLAYER's accuracy, recoil, sway, handling, health or stamina. It lives entirely on the AI men.
- **ADR-030 (HUD buffer).** DEFERRED to final polish, non-blocking. Text into the EXISTING squad panel
  is safe; a new widget or a bar would be building furniture the deferred ADR has to inherit.
- **ADR-040 + the Fairness Law.** The Summoner's point 6 makes the near-miss the cohesion-recovery
  window. ADR-040 names the hole: the first-shot near-miss triggers on **the shooter entering combat**,
  not on the player being unaware. In an ambush the second, third and fourth shooters are already in
  combat and spend no warning shot. **Building recovery on that instrument means it fires reliably in
  exactly the situations that do not need it, and not in the ambush that does.**
- **ADR-020 (Ambience Law).** See cost 2 — we spend combat silence.
- **ADR-029.** No collision. Everything proposed is diegetic (voice, a panel word). No markers.
- **GAME_GUIDE §5.** Live violation, pre-existing: ally morale/break ships un-ADR'd.

---

## 6 · THE GATE (ADR-015 / GAME_GUIDE §8.0) — honest placement

**Cohesion as a NEW mechanic is a feature epic and is BLOCKED.** The demo playthrough is undischarged.
Three pieces are exempt and I recommend exactly those three, in this order:

1. **EVIDENCE PROBE (exempt, do first, cheap).** *Does `squad_broken` ever fire in a demo
   playthrough?* A 5-man squad at `BREAK_RATIO` ~0.45 needs roughly three men down. **Nothing in this
   repo claims it has ever fired in the demo, and by the verification law I claim nothing either.** If
   it never fires, the entire shipped cohesion system is invisible because it is DORMANT, not because
   it lacks a widget — and that changes the whole council's answer.
2. **PRESENTATION FOR A SHIPPED SYSTEM (exempt).** The rally rule (`RALLY_BONUS` + `_player_is_forward`)
   ships and is unlit. Giving it its affordance is presentation, not a feature.
3. **PRESENTATION FOR A SHIPPED SYSTEM (exempt).** Gating existing VO on existing `effective_courage`.
   Both halves ship. No new mechanic, no new key, no new asset.

The coherence axis — spacing, mutual support, on-the-net — is **new simulation** and sits on the far
side of the gate. Post-playtest.

---

## 7 · THE SUMMONER'S SIX POINTS, BY NUMBER

**1 · REFUTED on the fact, CONFIRMED on the instinct.** *"Pillar 1 already mandates the BiA/HLL feel —
the Brothers in Arms inheritance is canon."* **Brothers in Arms appears nowhere in canon.** Not in
`GAME_GUIDE.md`, not in `BIBLE.md`, not in `DESIGN.md`. Hell Let Loose appears exactly once
(`GAME_GUIDE.md:20`) and **only for LETHALITY**. Pillar 1 as merged reads *"Believable firefights — AI
that fights like soldiers AND weapons that kill like weapons, neither subordinate."* That is compatible
with the BiA feel; it does not mandate it. **He is inheriting an ancestor this project never adopted.**
This matters practically: if BiA is to be canon, it needs a decision, not an assumption — and the thing
that made BiA work (suppress-with-one-team, flank-with-the-other, on a fixed enemy) is a **two-element
order verb we do not have and cannot afford a key for.**

**2 · CONFIRMED in substance, REFUTED in attribution, and it is STRONGER than he thinks.** Pillar 2 is
one word, "Atmosphere". The doctrine he is describing is **ADR-020 §3** — *"Willard does not fly the
Ride of the Valkyries. He watches it from a boat"*, *"the player is a WITNESS, never a puppet"*, and
the first-patrol beat *"a firefight you HEAR and never reach — the war is bigger than you."* It is
already ratified and already exactly his answer.

**3 · CONFIRMED as a gap, REFUTED as an absence — and it is worse than he thinks.** He is right that
Pillar 4 is attachment and cohesion is winning fights, and right that no ADR covers cohesion. But the
MECHANIC is in shipping code (§0 above), unnamed, in violation of GAME_GUIDE §5. **This is not a hole
to fill. It is an unnamed shipped system to name, correct and light** — cheaper than he fears and more
urgent than he thinks.

**4 · CONFIRMED, and this is the best of his six.** *"Vietnam cohesion is SOP-driven — react-to-contact
fires in three seconds without orders. What the player commands is the RECOVERY, not the reaction."*
**This is already true in the code and nobody has written it down.** `_contact_barks()` fires on its
own tick; `combat_goals` re-plans on contact with no player input; the orders are what the player adds
AFTERWARD. His sentence is the design principle the existing implementation has been obeying silently.
From my lens it is also the whole UX answer: **you do not need an affordance for the reaction, because
the player did not ask for it. You need an affordance for the recovery, because he did.**

**5 · CONFIRMED, and it reinforces 4.** *"In Vietnam you BEGIN already fixed."* ADR-020's whole
first-patrol table is the enemy choosing ground and time. The Fairness Law's near-miss is the game
conceding this and buying the player one second. If the fight begins at Fix, then Find and Fix are not
player verbs here, and BiA's four-verb order vocabulary genuinely does not port — which independently
kills the case for a fifth order key.

**6 · SHAPE CONFIRMED, MECHANISM REFUTED, three ways.**
   - **(a)** *"the ambush SHATTERS it"* — the shipped break function is `live / peak`, a **casualty
     tally**. An ambush that kills nobody cannot shatter it. Shattering-by-ambush requires a NEW input
     (shock, surprise, loss of mutual support) that does not exist in this codebase.
   - **(b)** *"drills RESTORE it"* — drills are a campaign/training-layer idea and **the demo is one
     day, 30 minutes**. Nothing in the shipped model recovers except `_nerve_drift` at +0.02/s in a lull
     and the medic revive channel raising `live`. **The restore path he wants is not built and does not
     fit the EA scope.**
   - **(c)** *"the Fairness Law's near-miss is the recovery window"* — collides with **ADR-040's named
     hole** (§5 above). It is a beautiful idea resting on an instrument that does not fire for the
     second and third shooters in an ambush, which is the case it exists to serve.
   - **And *"gating which orders function"* is the r4bk failure mode in its purest form** (§3).
     **Degrade execution; never gate.** The SHAPE — cohesion as a thing lost in a moment and won back
     through what the player does with his own body — is right, and the rally rule already in the code
     is the honest, shipped, unlit version of it.

---

## 8 · WHAT I WOULD BUILD, SHORTEST HONEST LIST

1. Probe whether `squad_broken` ever fires in a demo playthrough. **Claim nothing until it answers.**
2. Make the order ack unconditional and unskippable. *No ack = the order did not take.*
3. Gate the existing directional VO on existing `effective_courage`. Reflex lines always survive.
4. One state word in the squad panel header that already exists. No bar. No number.
5. Light the rally rule so the player learns that standing forward of his men steadies them.
6. Write the ADR that names ally morale/break, which GAME_GUIDE §5 has required all along.

Items 1–3 and 5–6 spend **zero art days and zero new keys**. Item 4 is a string.
---
---

## PHASE 3 — RESPONSE TO THE REFRAME

**His words:** *"for the demo im not worried about the rotation effect of the squad AI. i just want
realistic feeling and looking combat coming from both the allied npcs and the enemy npcs. right now
its like 60 percent there, but not as smooth looking as a call of duty 1 or brothers in arms"*

I take the vindication and the overrule in the same breath, and I lead with the overrule.

---

### 0 · WHERE I WAS WRONG. TWO POSITIONS CHANGED.

**CHANGED #1 — "audio has no sight-distance problem." FALSE. Audio has a HARDER distance problem than
sight, and I asserted the opposite without measuring it.**

`scripts/autoload/vo_manager.gd:104` — every field bark is an `AudioStreamPlayer3D` with
`max_distance = 45.0`. That is a **cliff, not a falloff**. Compare the sight caps:
`scripts/enemies/enemy_base.gd:108-109` — `SIGHT_CAP_OPEN 140.0`, `SIGHT_CAP_JUNGLE 45.0`.

> **In open ground the player can SEE a man at 140m and cannot HEAR him at 46m.** Voice dies at exactly
> one third of the range vision reaches. In jungle the two happen to coincide at 45m, which is why this
> has never been caught.

My Phase 2 ruling built the entire cohesion affordance on a channel that switches off before most of
the demo's open-ground engagements begin. **That was the wrong reason to close the visual channel.**
The audio design still stands on its merits — but it is a CLOSE-RANGE instrument, and it must be
argued as one.

**CHANGED #2 — "cohesion cannot be read off the men." QUALIFIED, and in his favour where it matters
most: the trailer shot.**

I ruled against the body at 45–90m. I did not check where the demo's fights actually happen. They
happen much closer:

- `scripts/missions/siege_director.gd:394` — `BREACH_INSIDE_M 12.0`. The assault comes THROUGH the wire.
- `:74` — `INSIDE_MARGIN_M 6.0`. Men are judged inside/outside at a six-metre band.
- `:599` + `:86` — `ILLUM_STANDOFF_M 140.0`: the wire is **lit by flares**, so this is not a
  dark-silhouette fight, it is a high-contrast one.
- `:337` — `SUPPORT_STANDOFF_M 90.0` is the *support-by-fire* element, not the assault element.

**RULING, resolved honestly and not in my favour:** the readable range and the engagement range are two
different numbers, and we are both right about different distances.

| Distance | What the body can carry | Verdict |
|---|---|---|
| **0–25m** (the siege at the wire, the ambush that matters) | posture, facing, flinch, weapon up/down, who is moving and who is not, the fist | **FULLY readable. He is right. Build here.** |
| **25–45m** | gross posture and facing only — prone vs up, moving vs static. Not spacing drift, not who is firing at what | Partial |
| **45–90m** (jungle patrol contact) | almost nothing at PSX fidelity through vegetation — **and no voice either, past 45m** | **My Phase 2 ruling stands here** |

**So the visual channel is not closed. It is the PRIMARY channel at the distance the demo's climax and
its trailer footage actually occur, and the audio channel is its partner at the same distance.** They
are the same 25m bubble, not competing bubbles. The place where NEITHER works — 45–90m jungle contact
— is a real hole nobody has named, and it is not solvable by presentation; it is where the game
genuinely goes quiet and blind, and that is arguably correct for Vietnam.

**RULINGS I ACCEPT WITHOUT ARGUMENT:** rotation/DEROS parked. No meter, no number — the readout is the
soldiers. The words are LOOKING and SMOOTH. The gating design from his point 6 is dead and he never
asked for it, so my §3 refusal is now moot rather than contested; I withdraw it as a live position and
keep only the general rule: **an input that stops working must say so at the press.**

---

### 1 · BARK TIMING AND SYNC — THE AUDIT. THIS IS THE CHEAPEST WIN IN THE COUNCIL.

I audited `scripts/autoload/vo_manager.gd` end to end and every `play_squad` / `play_enemy` /
`play_radio` call site in `scripts/`.

#### 1a · The cooldowns DROP. They never delay. That is good news and I will say so plainly.

`_play_field` (`vo_manager.gd:88-100`) returns on every refusal — `MAX_CONCURRENT_FIELD`,
`_speaker_busy`, `_on_cooldown`. **Nothing is queued, nothing is deferred, nothing arrives late.** A
bark either lands on its frame or it never existed. So the "bark two seconds off the beat" failure the
brief suspected **is not present in the VO router**, and the ordering there is deliberate and correct:
the comment at `:90` states a line refused for chorus must not burn its own cooldown, and the code does
exactly that.

**Do not "fix" this into a queue.** A queued bark is precisely the desync we are trying to avoid.

#### 1b · But the sync failure is real, and it is one layer up: THE CONTACT MOMENT HAS NO VOICE AT ALL.

`scripts/squad/squad_system.gd:764-786`, `_contact_barks()`. On the rising edge — the moment the squad
enters contact, the single loudest beat in any firefight — it does this:

```
_toast("%s: CONTACT!" % SquadRoster.call_name(caller.member))
```

**A toast. Text on the screen. No `VOManager.play_squad` call.** Meanwhile `squad_contact.wav` and
`squad_contact_front.wav` are recorded and sitting on disk in every squad voice.

> **The single most important bark in the game is a subtitle with no voice under it.**

And the gate is at the TOP of the function (`:765-766`): while `_bark_cooldown` is running (8.0s, set
at `:772`), the whole function returns — so `_last_combat_count` is not updated and the **falling** edge
that fires `"clear"` can be consumed silently inside that window. The edge detector is disabled by its
own cooldown.

#### 1c · TWENTY RECORDED LINES NEVER PLAY. Measured, not estimated.

Every `.wav` basename cross-referenced against every call site (`ack_line` and the weapons-free ternary
resolved by hand, so `on_me` / `moving` / `weapons_tight` are counted as LIVE):

**SQUAD — 12 of 25 dead** (`assets/audio/vo/john/`, mirrored in `ryan/`):
`contact` · `contact_front` · `enemy_left` · `enemy_right` · `treeline` · `sniper` · `ammo_low` ·
`reloading` · `reloading_cov` · `push_up` · `fire_in_hole` · `frag_out`

**RADIO — 7 of 15 dead** (`joe the radio man voice/`):
`roger_out` · `shot_splash` · `say_again` · `fire_mission` · `dustoff` · `winchester` · `no_commo`

**ENEMY — 1 of 10 dead:** `reload`

**Read what is in that list.** The dead squad set is *exactly* the directional callout vocabulary I
proposed in Phase 2 as the cohesion instrument — `contact_front`, `enemy_left`, `enemy_right`,
`treeline`. I proposed gating lines that have never once played. **The instrument I designed does not
need designing. It needs CONNECTING.** Also dead: `reloading` and `reloading_cov` — the two lines that
make a squad sound like it is covering itself, which is the exact texture he is asking for.

And `roger_out` + `shot_splash` are the fire-mission acknowledgement and the splash call. **Fire
support has no voice acknowledgement.** That is my Phase 2 ack contract, already recorded, already
un-wired, on the radio channel.

#### 1d · THE ELEMENT SWAP HAS NO BARK — confirmed, and it is worse than "no bark".

I found no `play_squad` at any bounding/overwatch element swap. The nearest thing that exists is
`has_covering_fire` (`scripts/ai/squad_coordinator.gd:105`), a per-squad census that already knows,
every think, whether someone is laying down fire for this man. **The truth is computed and never
spoken.** `push_up` and `reloading_cov` are the recorded lines for it.

#### 1e · THE CHEAP WINS, RANKED BY VALUE PER HOUR. ALL CODE. ZERO ART DAYS. ZERO NEW AUDIO.

1. **Put a voice under the contact toast.** One `play_squad("contact"/"contact_front", …, urgent=true)`
   at `squad_system.gd:775`. The loudest beat in the game, currently mute.
2. **Move the `_bark_cooldown` gate below the edge detection** so the "clear" edge and
   `_last_combat_count` cannot be eaten by the cooldown.
3. **Wire the four directional lines** off the contact bearing the squad already has
   (`last_known_target_pos` is on every man) — `enemy_left` / `enemy_right` / `contact_front` /
   `treeline`. This alone changes what a firefight sounds like more than anything else on this list.
4. **Wire `reloading` / `reloading_cov` to the reload the code already runs**, and `ammo_low` to the
   low-ammo state it already tracks. Mutual-support texture, free.
5. **Wire `roger_out` and `shot_splash`** into the fire-mission path at `field_director.gd:831`.
6. **Wire `frag_out` / `fire_in_hole`** to the grenade throw that already fires `grenade`.
7. **Wire `push_up`** to the covering-fire census as the element-swap voice.
8. **Wire `enemy_reload`** — the enemy going quiet to reload is a *tactical* cue the player can act on.

Eight items. Every one is a call site, not a design.

---

### 2 · AUDIO AS THE SMOOTHNESS CHANNEL — THE HOLES

The build is stronger here than I expected and has two holes that both read as cheapness.

**What is already good, and should be defended:** supersonic crack past the player's head, round-robin
over `crack_1..3.wav`, one per round, enemy only (`bullet_system.gd:105-156`,
`audio_manager.gd:396-420`) — this is the Fairness Law telegraph and it is the single best combat-audio
asset in the game. Distance-layered gunfire with a real distant report per weapon
(`fire_<id>_dist.wav`, `DISTANT_BAND_M 85.0`, `FAR_SHOOTER_DIST_M 60.0`), mechanical layers
(`mech_*.wav`), a tail/echo layer, and a distant-war ambient bed. That is CoD1's grammar and it is
present.

**HOLE 1 — THE IMPACT LAYER IS TWO SOUNDS, AND SHOOTING A MAN SOUNDS LIKE SHOOTING DIRT.**

The entire impact vocabulary is `impact_dirt.wav` and `impact_hard.wav`
(`scripts/combat/gun_fx.gd:9-10`), selected by a boolean (`bullet_system.gd:226`,
`_surface_is_hard`). No ricochet. No foliage. No metal. No sandbag. No water. No wood.

And the flesh hit is a **named placeholder in shipping code**:

```
gun_fx.gd:1002:   a.stream = IMPACT_DIRT   # placeholder wet tick until a flesh sample exists
```

with the line above it (`:911`) stating the intent: *"Flesh hit - the cue that shooting a body feels
different from shooting a wall."* **It doesn't.** This is his "I shoot people and they don't die"
lens pointed at audio: the felt problem will be read as damage or as animation, and the actual
mechanism is that the confirmation sound for hitting a man is the sound of hitting soil. **This is the
highest-value single audio asset missing from the game** — one wet impact set, and it fixes the moment
the player cares about most.

**HOLE 2 — THE MIX IS CAPPED AT TWO VOICES. In a forty-five-man assault.**

`vo_manager.gd:26` — `MAX_CONCURRENT_FIELD: int = 2`. Plus `SPEAKER_COOLDOWN_S 3.0` per man and
`LINE_COOLDOWN_S 4.0` per line. In the siege (`SIEGE_STRENGTH` 45) the wire will sound like four men.
**Overlapping voices are most of why CoD1 reads as a wall of combat rather than a diorama** — and this
constant is the one number standing between us and that. It was written to stop a five-man squad
answering one trigger in chorus, which is correct at squad scale and wrong at siege scale.

Two more thin spots, both cheap: only **2 squad voices** (`SQUAD_DIRS ["john","ryan"]`) split across
five men, so two or three grunts share a throat; and **3 enemy voices** across 45 attackers. Two
folders exist and are unused — `bryce/` and `hfc_male/`. If either holds usable squad lines, the cast
doubles for the cost of a constant.

---

### 3 · WHAT "60 PERCENT" LOOKS LIKE FROM THE PLAYER'S SEAT — RANKED

Ranked by what he notices FIRST, not by what is most broken. Within my lane only — pose, blend and
transition are the technical artist's ground and I stay off it.

1. **SILENCE ON AN ACTION HE WATCHED HAPPEN.** The strongest cheapness signal there is. The brain reads
   an unvoiced event as *not simulated*. We currently have: contact with no voice, a hit body that
   sounds like dirt, an element swap nobody calls, a fire mission nobody rogers. **This is #1 and it is
   the one that is fully fixable this week.**
2. **THINNESS — too few things sounding at once.** A firefight that sounds like four men is read as
   cheap before any individual sound is judged. `MAX_CONCURRENT_FIELD 2`.
3. **REPETITION AND UNIFORMITY.** Same voice out of two different faces; the same three enemy voices
   across forty-five men; the same two impact sounds for every surface in Vietnam.
4. **DESYNC.** A sound that lands off its action. **Confirmed NOT a defect in the VO router** — the
   router drops rather than delays. I rank it here because it is what everyone assumes is wrong, and
   the finding is that it isn't; do not spend a day here.
5. **NO SPATIAL GRAMMAR AT DISTANCE.** The 45m voice cliff against a 140m sight cap: men visibly
   fighting in total silence in open ground. Fourth-order, but it is exactly the "not smooth" feeling
   in the open approaches to the wire.

---

### 4 · r4bk RUNNING BACKWARDS — WHAT THE LAW MEANS HERE

The law was written for a feature that was simulated and had no widget. **This is the mirror: the
simulation is honest and the BODY is the thing that does not report it.** `has_covering_fire` knows.
`effective_courage` knows. `_nerve_drift` knows. `squad_broken` knows. Twenty recorded lines are
sitting on disk waiting to say so.

> **Applied here, the r4bk Law does not ask for a HUD. It asks: for every state the simulation
> computes, what does the player SEE OR HEAR that carries it? And the answer must be a man, a sound,
> or a body — never a widget, because he has now ruled out the widget himself.**

That is a stricter law than the original, not a looser one. The original could be satisfied by a label.
This one can only be satisfied by the fight looking and sounding like what the code already believes.

**And the gate placement improves under his reframe.** Every item in §1e and §2 is *presentation for a
shipped system* — the simulation ships, the audio assets ship, the call sites are missing. That is
explicitly exempt under ADR-015. The flesh-impact sample is one audio asset, not an art day. The only
thing on the far side of the gate is new coherence simulation, and he has just said he does not want it
for the demo.

---

### 5 · WHAT I NOW RECOMMEND, REPLACING MY PHASE 2 LIST

1. Voice under the contact toast. **(one line of code, the biggest single win)**
2. The other eleven dead squad lines and seven dead radio lines, wired to states that already exist.
3. Move the `_bark_cooldown` gate below the edge detection.
4. Raise `MAX_CONCURRENT_FIELD` for siege scale — a scale-aware value, not a flat one.
5. One flesh-impact sample. **The only new asset I ask for anywhere in this document.**
6. Broaden the impact set beyond hard/soft — ricochet, foliage, metal.
7. Check `bryce/` and `hfc_male/` for usable squad lines; if they hold, double the cast for a constant.
8. Reconcile the 45m voice cliff against the 140m open sight cap.
9. Still write the ADR naming ally morale/break. GAME_GUIDE §5 has required it all along and his
   reframe does not excuse it.

Items 1–4 and 7–9 are code and constants. Item 5 is one sample. Item 6 is a small sound pack.
**Zero animation days requested.**
