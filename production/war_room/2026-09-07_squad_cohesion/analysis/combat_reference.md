# COMBAT REFERENCE ANALYST — squad cohesion as a combat mechanic
**War Room 2026-09-07 · PHASE 2, INDIVIDUAL SIGHT · no cross-talk**
**Method:** research on the named games and on Vietnam infantry doctrine, then measured against this
repo's code. Every claim about RECONgame carries a `file:line`. Every claim about another game carries
a source at the foot.

---

## 0 · THE HEADLINE, BEFORE THE RESEARCH

**Cohesion is not missing from this game. It is BUILT, SIMULATED, AND INVISIBLE.**

The briefing's point 3 says *"No ADR appears to cover this."* The ADRs may not, but the **code does**,
and it is not a sketch:

| Cohesion behaviour | Where it already lives |
|---|---|
| ONE suppressor slot per squad; N exposure tokens gating how many men may be out of cover at once; two-element bounding overwatch expressed through the token grants; per-squad covering-fire census | `scripts/ai/squad_coordinator.gd:1-11` (the file's own docstring), 242 lines, both sides |
| Doctrine as data, per faction (`us`/`nva`/`vc`/`assault_press`) | `squad_coordinator.gd:37-49` + `data/ai/doctrine_*.tres` |
| **Nerve that MOVES during a contact** — falls 0.12 per mate down within 25 m, recovers 0.02/s in a lull, floors at −0.30 | `scripts/allies/ally_base.gd:118-129, 155, 817-819` |
| **The player's body steadies men** — +0.10 nerve inside a 6 m radius *if the player is forward* | `ally_base.gd:130-166` (`RALLY_RADIUS`, `RALLY_BONUS`, `_player_is_forward`) |
| Suppression as pin / fire-ceiling / spread-spoil, with cover-dependent accrual and decay | `ally_base.gd:344-351, 802-813, 2212-2218`; `scripts/ai/combat_posture.gd` |
| Per-man personality: courage, skill, reaction, aggression, self-preservation, burst length, range bias | `ally_base.gd:105-121` |
| Role dependency as data — POINTMAN/RTO/MEDIC/MG/GRENADIER, each consuming its own learned skill, **squadmates only, player owns none** | `scripts/squad/squad_roster.gd:64`, `scripts/squad/skill_catalog.gd:31-40` |
| Silent behavioural squad XP (ADR-018 §2) | `squad_roster.gd:102,150`; `skill_catalog.gd` thresholds |

And the affordance side of the ledger:

- `scripts/ui/hud.gd` — **zero hits for `squad` or `order`.**
- `scripts/ui/mission_hud.gd:271` — one line, `"SQUAD // %s" % fire_mode`. That is the *entire* squad HUD.
- `scripts/ui/squad_nameplate.gd:10-12` — name/rank/role, but only inside a **5 m, 12° look cone**.
- `nerve`, `RALLY_RADIUS` and `RALLY_BONUS` have **no hits anywhere in `scripts/ui/`.**

> **The origin lens the briefing hands us applies to the briefing itself.** *"I shoot people and they
> don't die"* was an ACCURACY problem wearing a DAMAGE costume. **"The squad has no cohesion" is a
> LEGIBILITY problem wearing a MECHANIC costume.** There is a nerve system that falls when your friends
> die and rises when you stand in front of them, and the player cannot see one pixel of it. A squad
> whose coordination you cannot read does not read as coordinated — it reads as five men doing
> whatever.

---

## A · BROTHERS IN ARMS: ROAD TO HILL 30 — what the player actually pressed

### The literal control surface
- Two AI teams under you: a **fire team** (rifles/BAR — better at establishing a base of fire) and an
  **assault team** (SMGs — better at closing and clearing). Later games add a bazooka/MG team.
- The player has essentially **two commands**: point at a place/enemy and issue **fire on that**, or
  point and issue **move/assault there**. Plus a rally/regroup. That is it. Gearbox's stated design
  goal was that the player gives **general intent to a team leader**, never micromanagement of
  individual men — the system "respected the chain of command."
- **Situational Awareness view** — a tactical top-down that slows/pauses the world so you can read the
  geometry. This is the load-bearing UI element and it is the one nobody talks about.
- The AI underneath is written to behave like trained soldiers: find cover, cover each other, take good
  firing positions, following the SOPs and battle drills those men were actually trained with. Gearbox
  insisted it be **dynamic and unscripted**.

### The suppression indicator — and what its LOCATION implies
BiA renders a state marker **over the ENEMY**: grey (unsuppressed) → **red (suppressed / heads down)**.
It is a HUD element on the thing you are trying to change, not on the thing you own.

**This is the craft finding, and it is the one I would put in front of the room.** Compare Company of
Heroes, which puts its suppression/pinned icons on **your own** squads. The two games put the indicator
on opposite sides — and both are right, by the same rule:

> **The suppression indicator goes on whichever side the player must make a decision ABOUT.**

In BiA you decide *"can my assault team move yet?"* — the answer lives on the enemy, so the light is on
the enemy. In CoH you decide *"is this squad still combat-effective?"* — the answer lives on your unit,
so the light is on your unit.

**For RECONgame, the player is a line grunt inside the squad, and Pillar 4 forbids him positioning
individual men.** The decision he actually makes is *"can I move / can they move yet."* That points at
BiA's answer — **the readout belongs on the ENEMY and on the GROUND, not on a squad panel.** A squad
cohesion meter is the one shape both reference games avoided.

### The feedback loop — how much was AI, how much was UI
The loop is: **Find** (contact, you go prone) → **Fix** (order fire team to suppress; watch the marker
go red) → **Flank** (the red marker is your PERMISSION SLIP — you and the assault team can now move
across ground that was lethal ten seconds ago) → **Finish**.

The good feeling is **not** the AI being clever. It is the loop's **causal legibility**: you press a
thing, a light changes colour, and *ground that killed you becomes ground you can walk on*. The AI
supplies the plausibility; **the UI supplies the causality**. Strip the marker and the same AI reads as
noise. The moment-to-moment pleasure of BiA is a **traffic light for terrain.**

**Applicability warning.** BiA's protagonist is a **sergeant with a tactical pause**. RECONgame's
protagonist is explicitly *"a line grunt, not an operator"* (GAME_GUIDE §1) who *"suggests and calls"*
(CLAUDE.md, Pillar 4). **The BiA command view is a Pillar-4 violation on sight.** What ports is the
traffic light. What does not port is the hand on the levers.

---

## B · HELL LET LOOSE vs HELL LET LOOSE: VIETNAM — the falsifiable claim, tested

### What HLL simulates about cohesion
Squads of ~6 under a Squad Leader; a Commander per 50-player team; roles (SL, Officer, Engineer, MG,
AT, Medic, Recon…) with hard caps. The load-bearing structure is **not** a cohesion stat, it is
**spawn geometry**: Garrisons (team-wide, expensive, built near supplies) and Outposts (squad-local,
cheap, placed by the SL as a stepping stone toward the objective). Suppression is a screen effect —
blur, desaturation, shake — that degrades your ability to aim. **There is no cohesion variable in HLL.**
What people call cohesion in HLL is *humans talking on proximity/radio VOIP*.

### What is actually different in the Vietnam iteration
- **Still 50v50.** Same squad sizes, same SL/Commander structure, same Garrison/Outpost economy, same
  suppression model.
- New: **helicopters, patrol boats, rivers, swimming/climbing/fast-crawl**, and the NVA's asymmetric
  **tunnel network** — buildable spawns linkable to a Garrison, 100–400 m apart, US cannot use them.
- Jungle: reviewers consistently report that dense vegetation **liquifies the frontline**; fights come
  from flanks and out of undergrowth instead of across a defined line.

### VERDICT — the Summoner's felt difference is REAL, and his attribution is WRONG

> **HLL:Vietnam ships the SAME cohesion machinery as HLL:WW2 — because it ships NONE in either.
> The difference he feels is produced by SIGHTLINES, SPAWN GEOMETRY and FORCE ASYMMETRY.**

Mechanism, in order of size:

1. **Sightlines.** WW2 hedgerows and towns give long lanes and readable frontlines, so the fight
   resolves as two masses trading across ground → *grand war spectacle*. Jungle caps engagement
   distance to tens of metres, so every fight is decided by **who saw whom first at close range**, i.e.
   **however many men happen to be standing near you** → *squad vs squad*.
2. **Spawn geometry.** Tunnels put NVA spawns *inside* your flank. A frontline you cannot draw is a
   frontline that cannot produce a spectacle.
3. **Asymmetry.** US firepower/air vs NVA ambush/manoeuvre means the two sides are not playing the same
   game, which removes the symmetrical mass-vs-mass shape entirely.

**Why this matters for RECONgame, concretely.** If the room believes "Vietnam feel = a cohesion
mechanic," the work goes into a squad system. If the room believes the evidence, the work goes into
**jungle occlusion, contact ranges, and where the enemy comes from** — and Pillar 2 (Atmosphere),
ADR-029 (open patrol) and the vegetation/sightline systems are already the correct owners. **The
strongest lever on "make it feel like Vietnam instead of WW2" is the density of the green and the
bearing the first round comes from, not a coordination stat.**

---

## C · REAL VIETNAM INFANTRY DOCTRINE — and the strongest fact in this briefing

### Immediate action drills: the response is UNORDERED, and it BRANCHES
The doctrine (FM 7-8 Battle Drill 4, React to Ambush; period MACV IA-drill outlines) splits on one
variable — **is the ambush inside grenade/assault range or not** — and the two answers are opposites:

- **NEAR AMBUSH** (in the kill zone, close): return fire, **throw frag/concussion/smoke**, and on
  detonation **assault THROUGH the ambush position** using fire and movement. Doctrine is explicit that
  men in the kill zone assault **"without order or signal."** Rationale: you move out of the beaten
  zone, and standing on top of the ambushers means the rest of their line cannot shoot without hitting
  their own.
- **FAR AMBUSH** (beyond assault range): the opposite — men in the kill zone **do not assault**. They
  return fire, take cover, and keep firing; elements OUTSIDE the kill zone manoeuvre to enable them to
  break out.

**Getting this wrong is fatal in both directions**: assault a far ambush and you cross open ground into
a machine gun; go to ground in a near ambush and you die in a pre-registered kill zone.

**This is the single most gameable fact in the whole briefing.** It is a real, binary, three-second,
life-or-death read that a *line grunt* makes with his own eyes — no rank, no command authority, no
tactical pause. It is a **PLAYER SKILL**, not a squad statistic.

### The rest of the doctrine that maps to verbs already in this game
- **Point man / slack man.** Point reads the trail — sign, wire, punji, the too-quiet clearing. Slack
  covers point and is the first gun into a contact. `MOS_SKILL["POINTMAN"] = "detect_ambush"`
  (`skill_catalog.gd:33`) is already this man, and ADR-021 §4's follow-phase tutorial is already him
  teaching you.
- **Fire discipline.** Patrols moved with weapons on safe and fire was withheld to avoid compromise —
  `squad_fire_toggle` / WEAPONS TIGHT (`scripts/squad/squad_system.gd:289-300`) is exactly this verb,
  already bound and already spoken aloud by the VO.
- **The mad minute.** A firebase perimeter dumps everything into the treeline at stand-to, to break up
  forming assaults and to spot movement. A base-defence ritual — relevant to the demo's siege arc, not
  to a patrol cohesion mechanic.
- **Break contact / bounding overwatch (the "peel").** Already expressed in
  `squad_coordinator.gd:1-11`'s two-element token grants.

### THE HISTORICAL FINDING THE ROOM WILL NOT EXPECT

The documented American cohesion problem in Vietnam **was not within-firefight coordination. It was a
personnel-system problem.**

- WW2 US Army: soldiers were cohorted — trained together, deployed together, stayed for the duration.
- Vietnam: the **individual rotation policy** — a 12-month tour (13 for Marines), each man arriving and
  leaving **alone**, into a unit of strangers. Military psychiatrists of the period warned it was
  having catastrophic consequences for unit cohesion; commanders interviewed in *Revolving Door War*
  describe a unit in permanent flux, veterans rotating out at peak proficiency, continuity destroyed.
  **FNG syndrome** — the new guy nobody will befriend because he is likely to get someone killed, and
  the short-timer who stops taking risks — is the direct cultural product.

> **The Summoner's instinct is RIGHT and his LAYER is WRONG. "Cohesion" in Vietnam is a CAMPAIGN
> phenomenon, not a combat one. It is about WHO IS IN THE SQUAD THIS WEEK.**

And RECONgame already holds two of the three pieces:
1. **Permanent attrition** — men die for real (Pillar 4, ADR-019).
2. **Silent behavioural veterancy** — ADR-018 §2, built as data (`squad_roster.gd:102,150`;
   `skill_catalog.gd:31-40`), so a rookie *is* measurably worse.
3. **MISSING: the rotation clock.** GAME_GUIDE §1 Pillar 4 names it in its own text — teammates who
   *"improve, get wounded, **rotate home**, and die for real"* — and I found **no `DEROS`, no tour
   clock, no days-in-country, no short-timer state anywhere in `scripts/`.** Replacements arrive
   (`scripts/ai/air_traffic.gd:784` `request_replacement_lift`); **nobody ever goes home.**

**A man who survives long enough to become good, and then LEAVES, taking his competence with him, is
the Vietnam cohesion experience.** It costs no HUD, no keybind and no combat code. It is a clock and a
Huey that already flies.

---

## D · OTHER GAMES THAT SHIPPED SOMETHING COHESION-ADJACENT

Sorted by the only question that matters here: **is the protagonist a LINE GRUNT or a COMMANDER?**

### Not applicable — commander protagonists (their solutions do not port)
| Game | The mechanic | Why it does not port |
|---|---|---|
| **Full Spectrum Warrior** | Pure squad command; the player never fires a weapon. Suppression is the entire combat verb. | The player IS the command layer. Pillar 4 forbids it outright. |
| **Ghost Recon (2001)** | Body-swap between team members + a command map. | Positioning individual men — the exact thing CLAUDE.md Pillar 4 names as a violation. |
| **Close Combat** | The best morale model ever shipped: units panic, rout, cower, and **refuse orders**. | RTS/commander — but see the lesson below; it is the most valuable entry in this table. |
| **Company of Heroes** | Suppression → pinned, icons on YOUR squads; the pin is what makes flanking exist at all. | Commander. Ports as the *indicator-placement rule* only (§A). |
| **ARMA command layer** | 1–9 nested menus, full unit control. | The canonical warning: a commander verb-set bolted onto a first-person soldier. Near-unusable, and precisely what ADR-012's four-order budget exists to prevent becoming. |

**Close Combat's real lesson, stated plainly:** orders that can be **refused** are a proven, good design
— and Close Combat only got away with it because every refusing unit had a **name and a visible state
word** on it. RECONgame already refuses orders by construction (`squad_coordinator.gd:11-12`:
*"Orders are REFUSABLE by construction… survival verbs are never routed through it"*) and shows the
player **nothing**. That is refusal without a face on it, which reads as a bug rather than as design.

### Applicable — line-grunt protagonists
| Game | What it did | Verdict |
|---|---|---|
| **Vietcong (2003)** | **The most applicable game in this list.** You are the point of a 6-man team where each man is a role you cannot substitute: Nhut the Kit Carson scout finds the trail and the traps, Defoe the medic is your only healing, Bronson the pigman is the base of fire, Crocker the engineer opens what is locked. Commands are few and largely positional. | Its squad feeling comes from **role dependency**, not coordination. You could not do the job alone because you physically lacked the man's job, not because a stat was low. **This is the mechanism RECONgame should copy, and `MOS_SKILL` (`skill_catalog.gd:31-40`) already is it.** |
| **SWAT 4** | Element leader who also shoots. Orders are issued **contextually by what you are looking at** — the command menu changes because you are aimed at a door, not because you pressed a door key. | **The verb-budget answer.** ADR-012 says four prime keys are spent and neither binding may be removed. SWAT 4 proves you get more orders **without more keys** by making the existing keys context-sensitive — which is ADR-012's own key-6 doctrine ("one physical key, the open context owns it"). |
| **Six Days in Fallujah** | Fireteam AI in procedural houses; deliberately minimal squad commands; the AI's competence carries it. | Supports the "AI supplies plausibility" half, and confirms that few verbs is not poverty. |
| **Men of Valor** | You are a grunt; the squad follows and is largely set dressing on a linear path. | The failure case. Squadmates present, cohesion absent — and it is remembered as the lesser Vietnam shooter for exactly that reason. |
| **Squad / Post Scriptum / HLL** | Cohesion is produced by **human beings on VOIP**. | **Cannot be ported to single-player at all.** Any claim that RECONgame should "feel like HLL's teamwork" is a claim about a thing HLL does not code. |

---

## THE FIVE MANDATORY ANSWERS

### 1 · Is cohesion a real mechanic here, or a re-skin of suppression/morale we already have?

**A cohesion RESOURCE is a re-skin. Three-quarters of it already exists under a different name, and
adding a second scalar next to it is a FOSSIL LAW violation waiting to happen** — two variables an agent
will later mistake for the same thing (CLAUDE.md, the Summoner's own words: *"so we don't have multiple
things that could accidentally be interpreted by you as the same thing"*).

`_nerve_drift` (`ally_base.gd:118-129`) already IS squad cohesion: it falls when a mate goes down inside
25 m, recovers in a lull, and is raised by the player standing forward within 6 m. Name a second thing
"cohesion" and you have two morale numbers and no way to tell which one is live.

**One thing IS real and un-built, and it is not a resource — it is a BRANCH:**

> **THE IMMEDIATE ACTION DRILL. On contact, the squad reads NEAR vs FAR and executes the doctrinally
> opposite response, in about three seconds, without an order.** Today each ally independently picks a
> goal from suppression, cover and nerve (`ally_base.gd:1079-1213`). There is no squad-level
> *react-to-contact* branch at all. **That is the missing mechanic, and it is a BEHAVIOUR, not a
> number.**

### 2 · If real: what is the player-visible verb? (r4bk binds)

**Not a fifth order. ADR-012 spent the last four prime keys (F1–F4 + C/H/X/N) and forbids removing
either binding.** Three surfaces, in priority order:

1. **THE ENEMY-SIDE TRAFFIC LIGHT (BiA's actual invention).** A readout that the position pinning you
   has gone **heads-down** — the light that turns lethal ground into crossable ground. Kept diegetic per
   ADR-029: their volume of fire drops, muzzle flashes stop, and your own squad's voice calls it
   (*"he's down — MOVE"*). The traffic light without the HUD panel.
2. **THE RALLY RADIUS, MADE VISIBLE.** `RALLY_BONUS` already fires when you are within 6 m **and
   forward** (`ally_base.gd:159-166`). The verb is **where the player stands** — the most Pillar-4 verb
   available, because it works *from inside the squad* and needs no authority. Its affordance is the men
   themselves: at rally distance they fire more and hug cover less; outside it they go quiet and sink.
   Already simulated; only the presentation is missing.
3. **CONTEXTUAL RE-USE OF `ON ME` (SWAT 4's answer, ADR-012's own key-6 doctrine).** Under fire with
   nerve low, `squad_follow` means **RALLY/CONSOLIDATE** — get up, get to me, break the pin — instead of
   a march order. Same key, same binding, the context owns it. No new key, no removed binding.

### 3 · What does it cost? Name the sacrifice.

1. **A cohesion METER costs Pillar 4 outright.** Show a number and the player starts *managing* it — and
   a man managing his squad's stat is standing **above** the squad, which Pillar 4 forbids by name.
   **The number you display is the number the player will optimise. There is no such thing as a
   read-only meter.**
2. **The r4bk exemption is a real risk, not a free pass.** ADR-018 §2's exemption came with its own kill
   switch: *"if that isn't legible enough to feel, the system has failed and must be cut rather than
   papered over with a UI."* Nerve has been shipped and invisible and nobody has reported feeling it.
   **By ADR-018 §2's own terms that is closer to a cut condition than to a precedent to lean on.**
3. **A scripted assault-through is a rail on contact.** The most cinematic thing in this analysis is also
   the closest thing to a cutscene in a game whose Pillar 3 says *nothing is on rails, ever*. ADR-020's
   binding test applies: **can he leave, right now, unpunished?** If the drill moves the player, the
   answer is no and it may not ship.
4. **Legibility costs mystery.** The dread of not knowing whether your squad is holding is *itself* part
   of the Vietnam feeling. Every light you add spends some of it.
5. **The rotation clock costs attachment on purpose.** Men leaving alive is the correct history and will
   read as the game taking something for no reason unless the fiction sells it hard.

### 4 · Where does it collide with an existing ADR?

| ADR | Collision | Severity |
|---|---|---|
| **ADR-012** | Four prime keys spent; neither binding removable. **The briefing's point 6 — cohesion "gating which orders function" — makes a bound key silently do nothing.** That is the precise defect ADR-012 was written to kill (*"a prompt that lies is worse than no prompt"*). | **BLOCKING** |
| **ADR-018** | Rank gates AUTHORITY, never ABILITY. A cohesion value that gates which orders *work* re-invents ability-gating with a new noun. §2's silent-XP r4bk exemption exists but carries its own cut condition. | **HIGH** |
| **ADR-016 / ADR-040** | One damage grammar, no parallel path. **The moment cohesion multiplies ally accuracy or damage it is hit-point math and Pillar 1 is gone.** Cohesion may move POSTURE, MOVEMENT, TARGET SELECTION and VOICE. It may never move a bullet. | **HIGH — draw this line first** |
| **ADR-040 §4** | The near-miss fires on the **shooter entering COMBAT**, per man. An ambush opening therefore already grants one near-miss *per ambusher* — the recovery window in point 6 **already exists and is generous**. The named hole (a shooter already in COMBAT swinging onto you) is the *second* volley, not the opener. | Reframes point 6 |
| **ADR-021** | The follow phase *"may never be enforced."* A cohesion system that punishes straying from the squad enforces it by the back door. | **HIGH** |
| **ADR-029 / ADR-030** | Diegetic pointers only; HUD buffer doctrine. A squad-status panel is the wrong shape for this game regardless of its merit. | MEDIUM |
| **THE GATE (ADR-015)** | **Split verdict, and this is the useful part.** *Presenting* the already-shipped nerve/rally/coordinator behaviour is **"presentation for shipped systems" — EXEMPT.** A cohesion resource, an IA-drill branch, or a rotation clock are **feature epics — GATED** behind the demo playthrough. | **Both sides** |

### 5 · The Summoner's six points — CONFIRM / REFUTE, by number

**1. "Pillar 1 already mandates the BiA/HLL feel — the BiA inheritance is canon."**
**REFUTED.** Pillar 1 (GAME_GUIDE §1) cites **HLL for LETHALITY ONLY** — *"HLL lethality; death comes
from situation… never bullet sponges."* **Brothers in Arms is not named in the pillars, in the tonal
north star, or in the flavour list.** The north star is **Platoon / Hamburger Hill / Apocalypse Now**
(films); the game flavour list is **SOCOM / Vietcong / Men of Valor** (CLAUDE.md). Importing BiA is a
**new import requiring a ruling**, not an inheritance — and it matters, because BiA's protagonist is a
sergeant with a tactical pause and RECONgame's is *"a line grunt, not an operator."*

**2. "Pillar 2 already solves the WW2-spectacle problem — grand war at the AMBIENT layer, the fight
stays squad-sized."**
**CONFIRMED, textually.** Pillar 2: *"The AO feels like a war is happening around you."* That is
literally war-as-ambience. **Amendment from §B:** ambience is not the only mechanism and not the biggest
one. HLL:Vietnam gets the same result from **jungle sightlines and spawn geometry**, which RECONgame
gets for free from ADR-029's jungle. Pillar 2 covers it; the vegetation covers more of it.

**3. "THE GAP: cohesion is about WINNING FIGHTS, not attachment, and no ADR covers it."**
**REFUTED — the strongest refutation in this analysis.** The distinction between attachment and tactical
coherence is sound and worth keeping. The claim that nothing covers it is wrong: `SquadCoordinator`
(suppressor slot, exposure tokens, bounding overwatch, per-faction doctrine files), `_nerve_drift`
(casualty shock, lull recovery, rally bonus), five-trait per-man personality, and MOS role-skills are all
shipped code. **The gap is not the SIMULATION. It is the AFFORDANCE — `scripts/ui/hud.gd` contains zero
occurrences of `squad`, and `nerve`/`RALLY_RADIUS` appear nowhere in `scripts/ui/` at all.** This is the
same shape as the modding finding that opened the briefing: felt problem, different system.

**4. "BiA cohesion is ORDER-driven; Vietnam cohesion is SOP-driven — the player commands the RECOVERY,
not the reaction."**
**CONFIRMED, and it is his best point.** Doctrine backs it literally: in a **near ambush** the men in the
kill zone assault **"without order or signal."** The code already agrees — `squad_coordinator.gd:11-12`:
*"Orders are REFUSABLE by construction; survival verbs (SEEK_COVER / RETREAT) are never routed through
it."* **The reaction is already un-commandable by design.** One correction: the SOP is a **binary branch
(near vs far), not a single reflex**, and getting the branch wrong is fatal — which makes it the richest
un-built thing in the briefing.

**5. "BiA's loop starts at Find/Fix. In Vietnam you BEGIN already fixed."**
**HALF-CONFIRMED, and the missing half is already canon.** True for enemy-initiated contact, and it is
why a straight BiA port fails. **But ADR-021 §3 gives the player the other half by decree** — *"PATROL TO
LEARN THE GROUND. USE THE GROUND TO KILL THEM… the ghost run and the gun run are the same run, a week
apart."* **When the player sets the ambush he IS running Find/Fix/Flank/Finish**, and ADR-021 §2 even
prices it (a successful ambush burns the route). So the game has both halves on a weekly cycle — a
**better** structure than BiA's, and already ratified.

**6. "Cohesion as a resource the ambush SHATTERS and drills RESTORE, gating which orders function; the
Fairness Law's near-miss becomes the recovery window."**
**SPLIT — refute the gating, confirm the window, and the window is already open.**
- **REFUTE the resource:** `_nerve_drift` is that resource and it already shatters on casualties and
  restores in a lull. A second one is a fossil.
- **REFUTE the gating, hard:** a bound key that silently does nothing is the exact ADR-012 defect, and it
  punishes the player at his moment of maximum panic, which fights Pillar 5 (fail forward) and Pillar 3.
  **Cohesion should change WHAT THE MEN DO, never WHETHER YOUR KEY WORKS.** The order should always fire;
  the *response* to it should degrade — Close Combat's model, which needs the men's names and states on
  screen to read as design rather than as breakage.
- **CONFIRM the window, with a correction:** the near-miss is per-man and fires on a shooter *entering*
  COMBAT (ADR-040 §4), so a six-man ambush opens with **six independent warning shots**. The recovery
  window the point asks for **already exists and is more generous than he thinks.** ADR-040's named hole
  is the *second* volley, not the opening one.

---

## THE CLAIM — what actually produces the Vietnam squad-fight feeling

**Not a cohesion meter. Three things, none of which is a stat the player watches:**

1. **ROLE DEPENDENCY (Vietcong's mechanism, already built as data here).** The feeling of needing your
   squad comes from **physically lacking a job** when a man is gone: no pointman → you walk onto the
   wire; no RTO → ADR-011 fire support is off the net entirely; no Doc → ADR-040's down state has no
   answer at all; no pigman → nobody can move because nothing suppresses. `MOS_SKILL`
   (`skill_catalog.gd:31-40`) and `MOS_ORDER` (`squad_roster.gd:64`) are already exactly this list.
   **Cohesion is not a resource — it is a READOUT of role coverage, and every role is a man with a
   name.**
2. **A TRAFFIC LIGHT FOR TERRAIN (BiA's real invention), rendered DIEGETICALLY on the enemy.** The
   pleasure loop is *ground that was lethal becomes ground I can cross, because of something my squad
   did.* Volume of fire drops, flashes stop, a squadmate shouts it. This is what makes coordinated AI
   *read* as coordinated instead of as noise.
3. **THE REVOLVING DOOR — cohesion as a PERSONNEL system, not a combat system.** The documented Vietnam
   cohesion failure is the **individual rotation policy**: men arriving and leaving alone, a unit of
   permanent strangers, FNG syndrome, veterans rotating out at peak proficiency. RECONgame has permanent
   death and silent veterancy; **it has no rotation clock, and Pillar 4's own text promises one**
   (*"rotate home"*). A man who becomes good and then goes home — that is the whole feeling, and it costs
   a clock and a Huey that already flies.

**Is he naming the right system?** He is naming the right FEELING and the wrong LAYER. What he is
reaching for is not a combat variable — it is **legibility** inside the fight (see the squad work; see
the enemy break), **dependency** across the fight (roles you cannot cover yourself), and **churn** across
the campaign (the squad is never the same squad twice). The one genuinely new *combat* mechanic in the
neighbourhood is the **near/far immediate-action branch**, and it is a behaviour, not a number.

**And on the gate:** presenting nerve, rally and the coordinator is presentation for shipped systems and
is **GATE-EXEMPT**. Everything else here — the IA drill, the rotation clock, any cohesion resource — is a
feature epic and is **GATED behind the demo playthrough.** Named honestly, as the briefing requires.

---

## SOURCES

- [Brothers in Arms: Road to Hill 30 — Wikipedia](https://en.wikipedia.org/wiki/Brothers_in_Arms:_Road_to_Hill_30)
- [Brothers in Arms: Road to Hill 30 Q&A — Final Thoughts, GameSpot](https://www.gamespot.com/articles/brothers-in-arms-road-to-hill-30-qanda-final-thoughts/1100-6119621/)
- [Basic Gameplay — Brothers in Arms Wiki](https://brothersinarms.fandom.com/wiki/Basic_Gameplay)
- [Hell Let Loose: Vietnam vs Hell Let Loose — What's Actually Different? (GamingBolt)](https://gamingbolt.com/hell-let-loose-vietnam-vs-hell-let-loose-whats-actually-different)
- [Hell Let Loose: Vietnam vs. Hell Let Loose — G2A News](https://www.g2a.com/news/features/hell-let-loose-vietnam-vs-hell-let-loose/)
- [Hell Let Loose Vietnam Spawn, Garrison & Outpost Guide](https://www.whisperofthehouse.com/hell-let-loose-vietnam/spawn-garrison-outpost-guide)
- [Hell Let Loose: Vietnam Review in Progress — TheSixthAxis](https://www.thesixthaxis.com/2026/08/12/hell-let-loose-vietnam-review-in-progress/)
- [Battle Drill #4: React to Ambush (platoon/squad)](https://www.armystudyguide.com/content/EIB/EIB_Related_Battle_Drills/battle-drill-4-react-to-a.shtml)
- [FM 7-8 Chapter 4 — Battle Drills](https://550cord.com/infantry-rifle-platoon-squad-fm-7-8/fm-7-8-chapter-4-battle-drills/)
- [Immediate Action Drills (ROTC handout, PDF)](https://www.atu.edu/rotc/docs/20_Imediate_action_drills.pdf)
- [Chapter 21 — Immediate Action Drills for Foot Patrols](http://www.hardscrabblefarm.com/vn/immediate-action-drills.html)
- [Vietnam War: The Individual Rotation Policy — HistoryNet](https://historynet.com/vietnam-war-the-individual-rotation-policy/)
- [Revolving Door War: Former Commanders Reflect on the Impact of the Twelve-Month Tour](https://repository.lib.ncsu.edu/items/126c41e6-a190-4c70-aca1-54de8150048a)
- [FNG syndrome — Wikipedia](https://en.wikipedia.org/wiki/FNG_syndrome)
- [Unit replacement vs individual rotation — Foreign Policy](https://foreignpolicy.com/2016/01/26/whats-better-to-use-in-combat-unit-replacement-or-individual-troop-rotation/)

---
---

# PHASE 3 — RESPONSE TO THE REFRAME

**The Summoner:** *"for the demo im not worried about the rotation effect of the squad AI. i just want
realistic feeling and looking combat coming from both the allied npcs and the enemy npcs. right now its
like 60 percent there, but not as smooth looking as a call of duty 1 or brothers in arms"*

He has moved the question from *what mechanic* to *what does the eye see*. Everything below is measured
against that.

---

## 1 · THE POSITIONS I CHANGE (stated first, because a change is worth more than consistency)

**CHANGED — the readout.** In Phase 2 I argued from BiA and Company of Heroes that the suppression
readout belongs **on the enemy**, and I called a squad cohesion meter "the one shape both reference
games avoided." **He went one step further than I did and he is right: no light at all — read it off the
bodies.** And the research below shows *why* I stopped a step short: **BiA's marker was a crutch for a
game whose enemies barely moved.** A stationary grey-or-red silhouette cannot express state with its
body, so Gearbox had to put a lamp over its head. **This project's men DO move and DO decide. They can
carry the signal themselves — but only if the eye can follow them, and that is a movement-concurrency
and clip-coverage problem, not a HUD problem.** My §A conclusion is superseded by his.

**DOWNGRADED — the near/far immediate-action drill.** In Phase 2 I called it the richest un-built combat
mechanic here. **For the demo I withdraw it.** His complaint is that too much is already happening
illegibly; an IA branch adds a *second* simultaneous thing. **Legibility must land before behaviour
grows.** It stays a good post-demo idea and nothing more.

**PARKED, per his ruling — the rotation clock / DEROS.** Recorded above in §C, not planned. I note only
that it costs no combat code, so nothing is lost by waiting.

**UNCHANGED.** §0 stands and is now the load-bearing finding: the decisions are already there
(`squad_coordinator.gd`, `_nerve_drift`), and the player cannot see them. He has independently arrived
at the same diagnosis from the other end — *"60 percent there."* **That is a man watching correct
decisions rendered badly.**

---

## 2 · WHAT COD1 AND BIA WERE ACTUALLY DOING — mechanism, not vibes

### The finding that reframes the whole question

From a contemporaneous BiA review, describing the enemy AI:

> *"they shifted fire in reaction to various flanking manoeuvres... but **rarely retreated and never
> advanced** (except for scripted movements when they initially ran into position). **They stayed in one
> position and the player manoeuvred around them.**"*

**Read that as an engineering statement rather than as a criticism, because that is what it is.**

> **BiA's enemies do not foot-slide, stutter, re-path, or turn badly — because THEY ARE ALMOST NEVER
> MOVING.** Their movement is front-loaded into one scripted run into position at spawn, and after that
> they are a firing pose behind cover. Gearbox spent its entire movement-quality budget on the **two
> friendly teams**, which move **only when you order them**, **one team at a time**, **to a place you
> chose**. At any instant, roughly one group is in motion and the player already knows its destination
> because he issued it.

CoD1 runs the same trick with different framing: infantry play a short scripted move into a position and
then hold it; the fights are staged in corridors and courtyards where few actors are visible at once and
each occupies a known lane. Infinity Ward's contribution on top of id Tech 3 was an in-house skeletal
system ("Ares") plus enhanced animation/scripting — but the **readability** came from staging, not from
clip count.

**So: both reference games look smooth in large part because they asked far less of movement.** They did
not solve locomotion quality. **They avoided the problem.**

### The second mechanism: audio arrives before the body

CoD1's real readability engine is that **every actor announces itself before you can see it.** Constant
shouted German and American callouts locate a man in space, in the moment he becomes relevant. Your eye
is *pre-aimed* at the thing that is about to move. That costs one sound and zero frames.

### The third: the flinch is the confirmation

CoD1 hit reactions are the era's most-copied trick, and their function is not decoration — they are the
**receipt**. You fire, the body yields, you know the round landed. Combat that never confirms reads as
mush no matter how good the clips are.

### Honest limit, per the verification law
I found **no primary developer source** for CoD1's blend times or animation-tree structure. The
engine-level facts (id Tech 3 base, in-house "Ares" skeletal animation, enhanced animation/scripting)
are sourced; the staging claims are inferred from the shipped games and from contemporaneous reviews,
and I mark them as inference rather than as measured fact.

---

## 3 · THE RULING: IS "SMOOTH" ANIMATION OR LEGIBILITY?

> **LEGIBILITY, roughly 70/30 — and this build's 30% is already in better shape than either reference
> game's was.**

I went looking for the animation defects first, expecting to find them, and **mostly did not**:

| Suspected defect | Reality in this repo |
|---|---|
| Hard clip cuts / pops | **Solved.** 0.18 s crossfade, `scripts/visuals/model_actor.gd:1034`, with same-beat resume at `:1028` |
| Body-yaw whip / snap turns | **Solved.** ONE yaw owner with a frame-rate-independent damped turn, `model_actor.gd:966-980` (`1.0 - exp(-12.0 * dt)`), explicitly written to absorb a discontinuous facing source |
| No hit reaction | **Solved, and elegantly.** `scripts/visuals/flinch_modifier.gd` — an additive directional spine punch, 22°, 0.28 s decay, that never steals the clip. This is *better* than CoD1's approach, not worse |
| Skating / foot slide | **Structurally guarded.** Bible 04's Law 1, "MOVEMENT OWNS THE LEGS," plus `CROUCH_SPEED_CAP 1.9` so the crouch clip cannot read as a skate |

**An animation layer with a damped single yaw owner, crossfades, an additive flinch and a documented
intent funnel is not a 60%-looking animation layer.** The missing 40% is therefore very unlikely to be
clips — which is exactly the hypothesis the reframe asked me to test hard, and it survives the test.

**And the perf evidence points the same way.** The programmer's finding — thinking is 1.2 ms of a
37.5 ms AI wall, and **the body (`move_and_slide`, hitzone sync, animation) is ~94%** — means **the men
moving are the expensive thing.** Fewer men in motion at once is *simultaneously* the legibility fix and
the perf fix. **Those two arguments converge on one dial, which is the strongest signal this council has
produced today.**

---

## 4 · WHAT IS CHEAP, AND WHAT THIS BUILD IS NOT DOING

Ordered by (effect on the eye) ÷ (cost). Every one is measured against a pointer.

### 4.1 · TOO MANY MEN MOVE AT ONCE — and it is a two-line DATA edit
`data/ai/doctrine_us.tres` ships **`exposure_tokens = 3`** and **`grant_stagger_ms = 600`**. In a five-
or six-man squad that is **half the squad out of cover simultaneously, starting six-tenths of a second
apart** — which the eye reads as *all at once*.

**BiA and CoD1 both effectively ran ONE mover.** The machinery to do the same is already built and
already wired (`squad_coordinator.gd:139-168`; ally side registers at `ally_base.gd:1071, 1197`).

> **`exposure_tokens: 3 → 1 or 2` and `grant_stagger_ms: 600 → ~1200`. No code. No art. No new system.
> One man breaks cover, you watch him arrive, then the next one goes.** That single change converts a
> correct-but-unreadable simultaneous rush into the thing he is describing — and, per the programmer's
> numbers, it also cuts the expensive bucket.
>
> **Named cost, honestly:** a squad that manoeuvres one man at a time is a **slower** squad. It will
> feel more deliberate and less desperate. That may be exactly right for a patrol and exactly wrong for
> the siege — which is why `assault_press` is a separate doctrine file and should keep its own numbers.
> **This is a dial to be tuned by his eye, not a value I should assert.**

### 4.2 · YOU CANNOT TELL AN ADVANCING MAN FROM A WALKING MAN
Bible 04's own gap list: **"No aimed-walk clip — `aim_walk` reuses `walk_forward`."** So a man closing on
you under fire plays the same legs and the same rifle carry as a man strolling a trail. **This is the one
place where a genuine clip gap and a legibility failure are the same defect**, and it is the single
highest-value animation ask on the board — one clip, rifle up, forward walk.

### 4.3 · NOBODY SAYS "MOVING" BEFORE HE MOVES
CoD1's readability is **audio-led**: the shout locates the actor before the eye finds him. `VOManager`
and `play_squad` already exist and already fire on orders (`squad_system.gd:289-306`). **Nothing speaks
when a man takes an exposure token.** A single callout fired at token grant — *"MOVING!"* — pre-aims the
player's eye at the one thing about to move. One line, one sound, and it is precisely the mechanism CoD1
built its whole feel on.

### 4.4 · ONE BLEND TIME FOR EVERY TRANSITION
`model_actor.gd:1034` — `_anim.play(clip, 0.18)`, a single global crossfade. 0.18 s is too *slow* for
run→fire (the shot reads late and mushy) and too *fast* for a settle into cover (the arrival pops).
**A small per-transition table is the classic difference between "blended" and "smooth," and it is a
handful of lines at the one place that already owns every clip change.**

### 4.5 · MEN STOP AT FIVE DIFFERENT RATES
`ally_base.gd` decelerates with `lerpf(..., delta * 5.0)` at `:1486`, `delta * 3.0` at `:1506`,
`delta * 8.0` at `:1607/1634`, `delta * 10.0` at `:1708` — and sets `velocity.x` **instantly** at `:1785`
and `:67`. **Six code paths, six different stopping behaviours, one of which is a teleport of velocity.**
Stop-start stutter is exactly what inconsistent deceleration looks like. One shared decel constant, and
the instant-set paths brought onto it.

### 4.6 · WHAT I AM NOT PROPOSING
No new mechanic, no new key, no HUD element, no cohesion resource, no IA drill. **Every item above is a
data value, a single clip, one VO line, or a constant that already exists in six inconsistent copies.**
That is deliberate: his complaint was about rendering, and none of this is a feature.

---

## 5 · GATE STANDING (named honestly, as required)

- **4.1 doctrine numbers, 4.4 blend table, 4.5 decel unification** — tuning and presentation of shipped
  systems. **GATE-EXEMPT.** 4.5 is arguably a bug fix outright: six deceleration rates for one behaviour
  is not a design.
- **4.3 the movement callout** — presentation of an already-shipped system (the token grant). **EXEMPT,
  narrowly.** It must not grow into a callout system.
- **4.2 the aimed-walk clip** — new art against a gap the bible already names. **Art, not a feature
  epic**, but it is his call whether it fits before the playthrough.
- **The IA drill, the rotation clock, any cohesion resource** — **GATED.** Unchanged from Phase 2.

## 6 · THE SENTENCE I WOULD PUT IN THE DECREE

> **Both reference games look smooth because they moved less, moved one thing at a time, and shouted
> before they moved. This project's animation layer is already better than either of theirs. It is being
> asked to render three men breaking cover simultaneously, in silence, and it cannot — and neither could
> theirs.**

### PHASE 3 SOURCES (additional)

- [Review: Brothers in Arms — Road to Hill 30 (contemporaneous, enemy AI behaviour)](https://forums.tomshardware.com/threads/review-brothers-in-arms-road-to-hill-30-long.148429/)
- [id Tech 3 — Call of Duty Wiki](https://callofduty.fandom.com/wiki/Id_Tech_3)
- [Call of Duty (video game) — Wikipedia](https://en.wikipedia.org/wiki/Call_of_Duty_(video_game))
- [IW (game engine) — Wikipedia](https://en.wikipedia.org/wiki/IW_(game_engine))
- [Infinity Ward — Grokipedia (in-house "Ares" skeletal animation system)](https://grokipedia.com/page/Infinity_Ward)
