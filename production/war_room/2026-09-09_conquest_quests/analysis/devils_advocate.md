# DEVIL'S ADVOCATE — the five Conquest quest candidates

**Written 2026-09-09.** Every code claim below carries a `file:line`. I read the substrate before I read
the candidates, and the substrate refutes more of this brief than the brief expects.

**One-line verdict:** one of these five is already shipped (**D**), two of them are the same quest (**A** and
**E**), one of them fights a ceremony this game already performs and will read as a spawn bug (**C**), and
only one is unambiguously play (**B**) — and B's four verbs do not exist, on an if-ladder whose ordering is
documented as load-bearing.

---

## 0 · THE THREE FACTS THAT KILL MORE OF THIS THAN ANY OPINION I HAVE

These were found in the code, not in the docs, and every candidate has to survive them.

### 0.1 · THE COMMAND CHANNEL IS RADIO-GATED, AND THE POST-DEMO PLAYER HAS NO RADIO

`_radio_check()` (`scripts/missions/field_director.gd:814-821`) returns a failure string unless
`nearest_radioman()` finds a living RTO **within `RTO_RADIO_RANGE`**. Every command-side beat in the file
is behind it — `_advance_route_tasking` (`:1296`), `_finish_sweep` (`:1656`), `raise_crisis` (`:1687`).

The briefing's constraint 7 says the post-demo player is **SOLO**, then a radio, then an RTO. **A solo player
therefore has no command toast at all.** Any candidate whose payoff arrives as a `toast.emit()` is, for the
first tier of the post-demo game, *literally silent*. That is not restraint. That is a feature that does not
run.

**This alone disqualifies "the toast will carry it" as an answer for B, C and E.** Say it out loud in the
council: **the one-line channel you are all planning to use is off for the player you are all designing for.**

### 0.2 · THE GAME ALREADY READS THE DEAD BY NAME, AT THE WIRE

`_read_the_dead()` (`scripts/missions/field_director.gd:2116-2130`) speaks a **named roll** —
`KILLED IN ACTION - N MAN`, then each name on its own toast — driven from the wire bank (`:2082`) and from
dawn after a siege (`:1900`). It is the Summoner's own 2026-08-28 ruling, quoted in the comment at `:2103`:
*"game will read the dead roster at the end of the play."*

Candidate C ("a death in the gutter, no body, no scene, no name") is **in direct conflict with a shipped
ceremony that names every man.** More on this in §C.

### 0.3 · THE ROSTER HAS TWO STATES, NOT THREE, AND IT DELETES THE DEAD

`SquadRoster.ensure_roster()` (`scripts/squad/squad_roster.gd:169-197`) filters on one boolean:

```
	# Drop the dead (they stay in memory only via the log).
	for m in roster:
		if bool(m.get("alive", true)):
			living.append(m)
```

There is **no MISSING**. A man is `alive` or he is erased. `CampaignState.bank_result`
(`scripts/autoload/campaign_state.gd:260-266`) keeps only a **count** (`kia_total`, `bags_unlifted`) and a
list of **name strings** in `state.flags["squad_kia"]` (`scripts/squad/squad_system.gd:809`). His `face`
index, his `helmet` string (`squad_roster.gd:190-194`) — the entire physical identity of the man — is
**destroyed at bank time**.

This is the fact that kills candidate E's best clause and candidate C's whole premise. Neither author of
those candidates checked.

---

## A · THE RIFLE THAT DOES NOT FIRE

### Verdict: PAGEANTRY, with one grain of play in it — and the grain is currently free.

**The event half is not an event.** "The sniper acquires the player and declines" is, from inside the
player's head, *identical to an AI that did not acquire him*. There is no perceptual difference between a
withheld shot and no shooter. You are proposing to spend engineering on a state the player is guaranteed
never to enter, and then reveal it hours later at a location. **That is not a withheld event. That is no
event plus a diorama.**

**The discovery half is a room you walk into.** Flattened grass, a spent case, a sightline. The player does
nothing, chooses nothing, fails nothing. He looks. This is the *exact* failure mode the briefing's §"THE
FAILURE MODE THIS COUNCIL EXISTS TO CATCH" names: *walk to where the theme happens and watch it.*

**And the choice you offer to redeem it is a fake choice, because its stated price does not exist.** The
candidate says routing around the crossing costs *"time, and time is contact."* **Time is not contact in this
build.** I looked. `CampaignState.threat_level` (`scripts/autoload/campaign_state.gd:22, 207-215`) is the
**AA/insertion** threat, moved by AA sites killed and birds lost (`:246-248`) — it has nothing to do with
elapsed patrol time. `DynamicMissionFactory` (`scripts/missions/dynamic_mission_factory.gd`) fires crises
off **events** (`_on_convoy_ambushed`, `report_village_distress`, `report_camp_discovered`), not off a clock.
There is no ambient escalation timer in `field_director.gd`.

So: **route around, and you pay nothing.** A choice with no cost is not a choice; it is a preference. **Build
the cost or cut the choice.** Do not ship a fork whose price is a sentence in a design doc.

### What is sacrificed if you build it anyway
A marksman entity that acquires and declines needs a suppression-of-fire path in `EnemyBase` that no other
enemy has, and every future bug where an NVA shooter fails to engage will now be indistinguishable from this
feature working. **You are building a mechanic whose success state is a bug report.**

### Edge cases nobody named
- **The player crosses that stream once and never returns.** The AO is 512m in the shipping shape and the
  seeded world rotates sites; there is no guarantee `patrol_locations` (`field_director.gd:1187, 1320-1328`)
  ever pushes him back through the same crossing. The hide is then a place that exists and is never found.
- **The player kills the sniper on the crossing by accident**, because he happened to be glassing that brush
  with binoculars (18.0 FOV zoom, hardcoded, `scripts/player/player.gd`). The whole three-tier escalation
  the Bible praises (§7 "the sniper: recurring antagonist") collapses to a lucky shot in tier one.
- **The hide is findable by walking, not by deduction.** Nothing gates it. So a player who wanders finds the
  payoff before he has the question, which inverts the Bible's structure (§7: *"rumour before picture"*).

### Minimum affordance (r4bk), legal under ADR-029 §4
**The spent case is a takeable object.** Put it in the existing `[F]` proximity ladder as a `FieldCache`-shaped
verb (`scripts/player/player.gd:606-660`; the ladder already carries `[F] TAKE FROM %s` at `:643`), and on
pickup stamp an **OBSERVED** mark via `state.add_field_mark("HIDE", pos, r, patrol_no)`
(`scripts/missions/mission_state.gd:59-64`).

That satisfies all four §4 clauses: it never checks off, it never reaches the in-field HUD, command never
names it, and it does not touch `_pick_patrol_location`. It is legal under ADR-022 §1 because **he personally
witnessed it**. And it is not a pin: it is a dated circle on his own sheet that the game will never
reconcile.

**Nothing else. No toast** — see §0.1, the solo player would not hear it.

---

## B · THE BAG

### Verdict: the only unambiguous PLAY in the set. And the only one with zero verbs built.

Four verbs, four player acts, four different men the player becomes. Open / leave / bury / turn in is the
only candidate here where **the theme arrives because of something the player does**. ADR-038's four camps
read the same act four ways and the world's reading is wordless. This is the right shape. I am not going to
pretend otherwise.

Now the brutal part.

### The verbs do not exist and the ladder resists them
`FieldCache` is a **take-only container** — *"A box a squad specialist puts on the ground for everyone else
to draw from"* (`scripts/props/field_cache.gd:1-16`), no collider, proximity `[F]`. There is **no leave verb,
no bury verb, no hand-in verb anywhere in the repo.** The interact ladder is a hardcoded if-chain whose own
header comment states the constraint: *"The ranges MUST match `_try_field_interact`'s or the prompt promises
a verb that will not fire"* (`player.gd:604-606`), and the plan doc already flags it —
`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:165-167`: *"There is no dialogue system... the interact verb is a
hardcoded if-ladder (`player.gd:606-660`) with load-bearing priority ordering."*

You are adding **three new branches with three new proximity ranges** to a chain where ordering is
load-bearing and a mismatch silently promises a verb that will not fire. **Price that at real days, not at
"it's just an if."**

The one pattern that already works is on the same ladder at `:634`:
`"[F] GO DOWN THE HOLE    [HOLD F] SATCHEL THE MOUTH"`. **Copy it. One line, two verbs, a hold modifier.**
Four verbs on one prompt is a menu, and a menu at a bag is the ACCEPT/DECLINE prompt the demo plan forbids
outright (`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:131`).

### Where B brushes the forbidden line
`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:130-133` — **"an ask that waits for you"** is forbidden, and
**"if the player can find out what he was asked to do without walking back to the man who asked him, you
have built a briefing screen."** A bag that sits in the firebase indefinitely, re-visitable, re-readable, is
uncomfortably close to a persistent objective object. It survives only because **nobody asks him to do
anything with it.** That distinction is one design meeting away from being lost. **Write it into the ADR now
or it will erode.**

### Where B could accidentally build the decay layer
**If the bag ever changes.** If it smells worse on day three, if flies gather, if the contents rot, if the
squad's line about it escalates — **that is world state decaying, and it has no owner.** The Bible's rule
(§5): *"Every horror image in the Reboot belongs to somebody, and it measures that person, not the world."*
A bag that gets worse on its own measures the calendar.

**Ruling: THE BAG IS INERT.** It is the same bag on day one and day thirty. Everything that changes is what
the player does and what men say — and those have owners.

### Edge cases nobody named
- **Turn it in to whom?** ADR-038 gives four camps and the demo plan (`:147-151`) rules exactly **two men**
  get named-giver treatment with **one bit of state** (`asked` / `not asked`). A hand-in needs a receiver
  with a schedule, and `Civilian` garrison posts wander (`site_planner.gd:938-962`, flagged as breakage
  risk #1 at `DEMO_TWO_QUESTS_PLAN_2026-09-06.md:155-158`). **The bag's best verb dead-ends at random.**
- **Bury it where?** Terrain deformation is capped (`MAX_DEFORMS_PER_CELL`, `WorldConfig.TERRAIN_DEFORMS_PER_FRAME`,
  see `field_director.gd:_arty_impact` `:880-895`). A buried object needs persistence in `ProvinceState` that
  a hole in the ground does not currently have. **"Bury" is the most expensive of the four verbs by an order
  of magnitude and it is listed as if it were free.**
- **The player never finds it.** Correct and must not be softened (`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:135-137`).
  Say so in the ADR before someone adds a reminder.

### Minimum affordance
The `[F]` prompt line, and nothing else. `field_interact_prompt()` (`player.gd:606`) is where the player
looks, and the file already says why: *"a takedown he cannot see is a mechanic he will never find"* (`:654-655`).
**No toast, no mark, no journal entry.** The bag is the affordance.

---

## C · THE MAN WHO IS NOT AT STAND-TO

### Verdict: THIS IS THE ONE THAT READS AS A BUG. Cut it or invert it.

**Answering the council's question directly: candidate C is by a wide margin the most likely to read as a bug
rather than as a theme.** Three independent reasons, all in code.

**1. The game already names its dead, out loud.** §0.2. `_read_the_dead()` speaks a roll at the wire and at
dawn (`field_director.gd:2116-2130`). A man who is absent and *not* on that roll produces a player who
notices the roll ran and did not mention Hayes — **which is the correct feeling, and it only works because
the ceremony exists.** But it works *once*. The second time, the player concludes the roll is unreliable, and
then the roll is broken for every real death for the rest of the campaign. **You would be spending a shipped
system's credibility to buy one beat.**

**2. He comes back to breakfast.** §0.3. `ensure_roster` keeps every member with `alive: true`
(`squad_roster.gd:174-177`) and `SquadSystem.setup` stands up the first `SQUAD_SIZE` of them at dawn
(`squad_system.gd:69-75, 103`). A man who is "simply absent" without being marked dead **is stood back up the
next morning by the spawner.** Missing on Tuesday, at the fire on Wednesday. That is not restraint, that is
`_stand_up_member` doing its job, and **every player will file it, correctly, as a respawn bug.**

To avoid it you must add a third roster state, teach `ensure_roster` about it, teach `bank_result` about it,
and teach the debrief about it (`scripts/ui/screens/debrief.gd:108`). **That is a save-format change for a
beat that lasts eight seconds.**

**3. "May find nothing at all" is a design brief for a wasted evening.** ADR-021's quiet-patrol economy exists
precisely because an empty walk has to pay in *something* — ADR-022's whole "Bought" clause is that the map is
what makes a contactless mission worth the evening. **Candidate C proposes an errand whose designed outcome is
nothing, alone, at cost.** That is a direct hit on the quest quality law (briefing constraint 2: every quest
carries a THREAT and a STORY). C has a story and no threat: **nothing worsens if you ignore it.** He is
already gone.

### And it requires a squad the player will not have
**Answering the council's question directly: C is the candidate that requires a squad the post-demo player
does not have.** Stand-to is a formation of men. `SQUAD_SIZE` is 8 (`squad_system.gd:23`,
`squad_roster.gd:66`), reached only at the *last* tier of the post-demo ladder. At the solo tier there is
nobody to be absent; at the radio tier there is nobody to be absent; at the RTO tier there is exactly one man
and if *he* is absent the entire command channel dies with him (§0.1) — which the player will read as the
radio being broken, not as a theme.

**C is unplayable for three of the four tiers of the game it is being written for.**

### Minimum affordance — and it is the cheapest legal one in the whole set
**Do not add anything. Subtract.** The affordance is the **existing roll of the dead**: a name that is not
read. Withholding is only legible when there is a known ritual to withhold from, and this game already
performs that ritual on every walk home. **That is the line between restraint and invisibility, and C is the
only candidate that sits on the right side of it for free** — which makes it doubly galling that everything
*around* it (roster states, solo tiers, respawn) is broken.

### If you keep it, keep it this way
Fold C into the roll, not into the field. **The man is on `squad_kia` (so the roster deletes him and he never
respawns) but the toast prints his name with no cause.** Zero new state, zero new verbs, no errand, no
"go look and find nothing." The gutter death happens in the ledger, which is exactly where Sgt. Maddox dies
in Issue 2 p4 — *in a subordinate clause*, not in a search.

**The version in the candidate — go look, alone, find nothing — should be cut.**

---

## D · THE SHORT ROUND

### Verdict: NOT A QUEST. IT IS ALREADY SHIPPED. Cut it from this list entirely.

This is not a close call and I am not being rhetorical. Every element of candidate D exists in the build
right now:

| D's claim | Where it already lives |
|---|---|
| Fire support lands with scatter | `_run_mortar_mission`, `field_director.gd:906-927` — `FirePlan.MORTAR_SHEAF_M` scatter on every round |
| **It can land where he was not told it would** | Same function, `:919-922`, and the comment says it deliberately: *"The spot round is a RANGING shot: it strays further than the sheaf on purpose, **which is why it lands outside the ring the player was shown**"* |
| It can kill the player | `CombatManager.apply_explosion_damage`, `scripts/autoload/combat_manager.gd:127-143` — full damage, multi-point visibility, knockback |
| It can kill his own men | Same, `:145-168` |
| **It can kill the people he came to protect** | Same, `:170+` — *"Noncombatants take blast like anyone else"* |
| Fail forward, no reload-and-memorise | `_danger_close_to_squad`, `field_director.gd:853-874` + the two-press confirm at `:541-549`; `DANGER_CLOSE_M = 45.0` at `:363` |
| The telegraph (tube thump, then whistle) | `_battery_telegraph`, `field_director.gd:899-903` |

**Somebody proposed as a quest a system with a dedicated ADR (ADR-011), a test bench
(`scripts/levels/support_fire_range.gd`), and a Summoner decree behind it.** Whoever wrote candidate D did
not open `field_director.gd`. Say that plainly in the council; it is the single clearest instance of the
failure mode the briefing exists to catch, and it is on our own side of the table.

### What D is actually asking for, once you strip the fiction
It is asking for **the WW1 rhyme** — Issue 2 p16, *"These are our own shells!"* — to be audible when the
shipped system does what it already does. That is **one VO line and zero engine work**, and the treatment
already tells you the grammar: the comic cuts from French shells falling on French troops straight into a
skeleton in the Vietnamese bush (`TREATMENT §3 Continuation C`, and `BIBLE §4 "How the cuts are made"`).

**Demote D to audio and art direction. It is not a quest and it never was.**

### The one real defect underneath it, which nobody has priced
`combat_manager.gd:155-159`:

```
	# Asymmetric danger-close: INDIRECT fire (attacker == null - arty, CAS,
	# napalm, CBU, placed charges) does only ~0.4x to your own men, so a
	# called strike threatens without deleting your squad.
```

**Your own shells do 40% to your own men and 100% to civilians.** That is a deliberate Pillar-5 anti-sadism
dial, and it is defensible. But it means **the comic's beat cannot land at full strength**: the horror of
Issue 2 p16 is that your own artillery *kills your own*, and this build has decided it mostly doesn't.

**Name the tradeoff and make somebody choose:** you can have Pillar 5's softening or you can have Issue 2
p16, not both. Nobody in this council has noticed they are in tension. **My position: keep the 0.4x.** The
comic's beat is available at full strength on the *civilians*, who take 100%, and that is both truer to the
war and worse to live with.

---

## E · THE DUGOUT

### Verdict: PAGEANTRY — and legitimately so. But one of its clauses is a lie the data cannot tell, and
another one builds the decay layer the author banned.

**E is a room you walk into and look at.** It is the honest version of A. And I am not going to call that a
defect, because the source is explicit: *"The book ends on arrival, not on battle... He is sitting down,
cleaning a rifle. The film's ending is a room, and so is his"* (`TREATMENT §1`, point 2). The Bible grades it
**"MISSION or place"** and the "four I would build first" entry says it outright: *"A place, not a boss"*
(`BIBLE §7 #12` and §7 "The four I would build first" #4).

A place that answers a question the player has carried for hours, with no dialogue, is a legitimate payoff
and RECONgame already has the machinery for authored places (ADR-041). **Keep E.**

Now the two things wrong with it.

### E.1 · "THE HELMETS MAY BE RECOGNISABLE" IS NOT SUPPORTABLE BY THE DATA. Cut the clause or build the field.

Three separate failures, any one of which is fatal:

1. **The record is deleted before the wall is found.** §0.3 — `ensure_roster` drops the dead
   (`squad_roster.gd:173-177`) and `bank_result` keeps only a **name string** and a **count**
   (`campaign_state.gd:260-266`, `squad_system.gd:809`). The dead man's `helmet` field
   (`squad_roster.gd:192-194`) **no longer exists** by the time the player stands in the dugout.
   Recognition needs a per-man persistent record that survives death, and there isn't one.
2. **Fifteen helmets, eight men.** `GruntDresser.HELMETS` has 15 entries (`scripts/visuals/grunt_dresser.gd:42-47`).
   Eight men drawn from fifteen variants collide roughly nine times out of ten. **"That's Hayes's helmet" is
   a claim the pool cannot support.** Two living men in the current squad are probably wearing it.
3. **The player has never looked at a squadmate's helmet closely enough to remember it.** There is no
   inspect verb for an ally in the `[F]` ladder (`player.gd:606-660`). He knows his men by **name and by MOS
   nickname** (`squad_roster.gd:70-76` — DOC, PIG, SPARKS, EYES), not by headgear decal.

**If you ship the clause without the data, every player recognises nothing, and the wall becomes generic
props — the exact PANEL-ONLY failure the Bible's own adaptation map warns about (§7, category definition).**

**If you want it, the honest build is:** a persistent `lost_men` list on `CampaignState` carrying
`{name, helmet, face, patrol_no}`, populated at bank time before `ensure_roster` erases the body, and the
wall instantiates *those* helmet variants. **That is a save-format change and it should be priced as one, not
smuggled in as a prop.**

### E.2 · A WALL THAT GROWS IS THE WORLD-STATE DECAY LAYER, WEARING A PROP'S CLOTHES

**Answering the council's question directly: E is where the banned decay layer gets built by accident.**

The moment the helmet wall **accumulates** — one more helmet per man you lose — it stops being an image and
becomes a **readout of the campaign's accumulated failure state**. It is a KIA counter rendered as a
diegetic prop. It has no mind attached to it. The author's rule, verbatim in the Bible (§5):
*"any horror gore scene in the comic is supposed to be representative of the psychological state of the
person expericing the vision"* — and the Bible's own attribution audit (§5, closing) says it found **no**
horror image in 88 pages that cannot be pinned on a mind present in the scene.

**Whose mind does a growing wall measure?** The sniper's — and the sniper *never gets a vision* (Bible §5,
"THE SNIPER"): *"He does not get visions. He is one — for everyone else."* So a wall that tracks your losses
measures **nothing but the save file**. That is world state.

Worse: it also breaks the Bible's own reading of what the wall means. On the page the wall is **the sniper's
kill counter, and it rhymes with Gus's ear necklace** (Bible §5, "the single largest finding in Issue 4";
Treatment §4 beat 2: *"The trophy rhyme, uncommented"*). Those are **his** kills. **A wall stocked from your
campaign's casualty list is a different object with a different author.**

**Ruling: the wall is AUTHORED AND FIXED at world-gen.** Same number of helmets on your first visit and your
tenth. It was full before you got there. That is more frightening than a counter and it costs nothing.

### E.3 · The rest of E is fine and the empty-when-found clause is its best idea
*"It may be empty when found"* is the Treatment's own Continuation A ending (`TREATMENT §3 A`) and it is the
one beat in this entire brief that is both cheap and correct. **Do not let anyone add a fight to it.**

### Edge cases nobody named
- **How is it found?** `patrol_locations` only carries `"village"` and `"vc_camp"`
  (`field_director.gd:1187, 1326-1328`). A third kind means touching the sweep selector
  (`_pick_patrol_location`, `:1416-1425`), and **routing the player to it via command tasking would violate
  ADR-029 §4 clause 3** (command names features, never objective pins) *and* clause 4 (the route feeds only
  the one selector). **The dugout must be findable by walking and by nothing else.** That means most players
  never see it. Accept that or do not build it.
- **A dugout that is a `patrol_location` gets a sweep circle drawn on the sheet** (`_set_patrol_location` →
  the map's sweep ring). **That is a pin.** Keep it off the list.
- **The porters.** `BIBLE §5` and `§9 #9`: he is *supplied by the local VC*. Porter columns are named as
  existing behaviour (`BIBLE §8`). If the player intercepts the supply column he has invented a resource-denial
  quest nobody designed. **Either the porters are decoration or the wall goes cold — decide it, don't discover it.**

### Minimum affordance
**One take verb on one helmet**, in the existing `[F]` ladder, so he walks out holding a thing. No mark until
he has stood in the doorway; then the OBSERVED stamp (`mission_state.gd:59`), same as A. No toast (§0.1).

---

## THE ANSWERS, STATED FLATLY

### Which reads as a BUG rather than a theme?
**C, by a wide margin.** Three code-level reasons in §C: it contradicts a shipped named roll of the dead
(`field_director.gd:2116`), the roster has no MISSING state so the absent man is **stood back up at dawn**
(`squad_roster.gd:173-177` + `squad_system.gd:103`), and its designed outcome is "find nothing, alone." The
runner-up is **A**, whose success state — an enemy that acquires and does not fire — is perceptually
identical to an AI failing to engage, i.e. **the feature working and the feature broken look the same.**

### Where does restraint cross into invisibility?
**The line is not "has a HUD element." The line is: can the player tell this from an absence?**
Restraint puts the affordance **in the world** (a case he can pick up, a hide he can stand in, a bag with an
`[F]` line, a name that is missing from a roll he has heard ten times). Invisibility leaves the affordance
**in the designer's head**.

Minimum affordances, none of which violate ADR-029 §4 (no waypoints, no pins, no in-field tracking):

| | Minimum affordance | Why it is legal |
|---|---|---|
| **A** | The **spent case** as an `[F]` take verb (`player.gd:606-660`), and on pickup an OBSERVED mark via `state.add_field_mark` (`mission_state.gd:59`) | ADR-022 §1 — he personally witnessed it. Never ticks, never reaches the in-field HUD, never touches the selector |
| **B** | The `[F]` prompt line on the bag, **two verbs max**, using the `[F] … [HOLD F] …` pattern already at `player.gd:634` | It is a world object with a proximity verb. Not a menu, not an accept/decline |
| **C** | **Subtract, don't add** — the affordance is his **name missing from the existing roll** (`field_director.gd:2116`) | Zero new UI. Withholding is only legible against a known ritual, and the ritual ships |
| **D** | **Already has one** — `FIRE MISSION - SPOT ROUND OUT` toast + the danger-close second press (`field_director.gd:541-549, 908`) | Nothing to add. Nothing to build |
| **E** | The **place itself**, plus **one take verb on one helmet** | A place is not a pin. It must be found by walking, never by tasking |

**In every case: no toast for the payoff.** §0.1 — the solo player cannot hear it.

### Which is secretly the same quest?
**A and E are the same quest, and A should be cut down to fold into E.**

Both are *"the sniper as a place you find after the fact, with nobody in it."* A's hide is a small E:
flattened grass, a spent case, a sightline, an empty position. E's dugout is a large A: skulls, helmets, a
cold fire, an empty position. **Same beat, same shape, same emptiness, same antagonist, and both pay off in
looking.** Building both means the player has the identical realisation twice and the second one is weaker.

**Keep the withheld shot from A** — the moment, which costs an AI branch — and **delete A's discovery half.**
Fold the discovery into E, which does it better, once, at the end. One place, not two.

(Secondary duplication worth naming: **A and C share a failure mode** — both stage the theme as a withheld
event whose absence the player cannot distinguish from an absence of content. Two candidates built on the
same unverifiable premise is a pattern, not a coincidence.)

### Where does a candidate accidentally build the banned world-state decay layer?
**E, primarily** — §E.2. Any helmet wall that **grows with the player's losses** is a campaign KIA counter
rendered as a prop, attached to the one character in the source who explicitly *never has visions*
(Bible §5, "THE SNIPER"). Fix: **authored and fixed at world-gen.** It was full before you arrived.

**B, secondarily** — §B. Any bag that **changes over time** (smell, flies, rot, escalating squad lines)
is decay with no owner. Fix: **the bag is inert.**

**And a warning for A:** the "route around forever" fork will tempt someone to make the AO *get worse* while
you avoid the crossing. That is the same disease. **Do not.**

### Where does a candidate require a squad the player will not have?
**C outright** — stand-to is a formation, and `SQUAD_SIZE = 8` (`squad_system.gd:23`) is the last tier of the
post-demo ladder. Solo, radio and RTO tiers have nobody to be absent; at the RTO tier the absent man **is the
command channel** (`_radio_check`, `field_director.gd:814-821`) and his absence reads as a broken radio.

**A partially** — "hunt the hide" alone, at the solo tier, is an unsupported errand; and the branch that
makes it interesting (the squad walks on past a man who chose not to shoot — Bible §7, the panel itself) has
**no squad to walk on**.

**B is the only candidate that works at every tier**, because a bag does not need men. That is a real
argument for building B first, and it is stronger than any thematic argument in the brief.

---

## WHAT I WOULD KILL, IN ORDER

1. **CUT D entirely.** It is shipped. Demote to one VO line for the Issue 2 p16 rhyme.
2. **CUT the discovery half of A** and fold it into E. Keep only the withheld shot, and **only if you first
   build the cost** that makes routing around a real choice — because right now it is free.
3. **CUT the field half of C** ("go look, alone, find nothing"). Keep the ledger half: a name that the roll
   does not read. It costs nothing and it is the only truly free beat in this brief.
4. **CUT "the helmets may be recognisable"** from E unless somebody funds the persistent `lost_men` record,
   because `ensure_roster` deletes the man before the wall exists.
5. **KEEP B, and build it first**, with two verbs on one prompt line, an inert bag, and a named receiver
   pinned to a billet — or accept that its best verb dead-ends at random
   (`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:155-158`).

**What that leaves: one quest (B), one place (E), one moment (A's withheld shot), one absence (C's unread
name), and one VO line (D).** That is a smaller list than the one you came in with, and every item on it
survives contact with the code.

---

## THE THING NOBODY IN THIS COUNCIL HAS SAID

Four of the five candidates are built on **withholding an event**, and the fifth is built on **an event that
already happens**. That is not a coincidence and it is not five people arriving at the same good idea. It is
five people reading a comic whose defining move is restraint (`BIBLE §6`: *"Deaths happen in the gutter...
That restraint is the whole tone"*) and mistaking **the author's restraint** for **a design method**.

A comic can withhold, because the reader is still holding a page and knows he is being told a story. **A
first-person game that withholds gives the player nothing to hold.** The comic's gutters are surrounded by
panels; a game's gutters are surrounded by an empty jungle and a player wondering whether the build is
broken.

**The tone is achievable. But it is bought with things the player touches — a case, a bag, a helmet, a name
in a roll — not with things the game declines to show him.** Every candidate above that survives, survives
because it has an object in it. Every one I killed, I killed because it did not.
