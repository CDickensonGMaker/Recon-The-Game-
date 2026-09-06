# ANALYSIS — GAME DESIGNER + WRITER (one file, two lenses)
**Council:** 2026-09-06 RPG pivot · **Architects:** game-designer, writer · **Status:** analysis, nothing built.
**Binding order:** 5 Pillars → ADRs → GAME_GUIDE → bible → DESIGN.md. Plus the r4bk law and ADR-019 §4's
narrow exception to it (allegiance has NO meter; the affordance is the world).

**What I read:** `GAME_GUIDE.md` §1/§6/§8 · ADR-006 · ADR-019 · ADR-020 · ADR-022 (+ Amendment A) ·
ADR-029 (+ Amendments B and C) · ADR-032 · `PLAYTEST_FINDINGS_2026-08-28.md` §Q2/Q2b · and the code
named below. Every code claim carries a pointer (POINTER LAW).

---

## 0 · THE MEASURED GROUND (read this before any section)

Nothing in this analysis re-derives a number. These are measured, and two of them change the answer.

**The clock** (`scripts/levels/demo_game.gd:45,50,60,61,75`):
`START_HOUR` 6.5 · `DAY_RATIO` 38 · night at ~1184 s (**19.7 real min of daylight**) ·
`PROBE_AT_S` 1395 (**23.25 min**) · `SIEGE_AT_S` 1440 (**24 min**) · `END_BACKSTOP_S` 2700 is a
backstop only.

**The geography** (`scripts/missions/mission_generator.gd:693+`). `out_v` is the gate's outward normal.
Everything is bearing-locked off it:

| Feature | Bearing from `out_v` | Range from centre | Line |
|---|---|---|---|
| Village (3–4 live defenders) | **+2.35 rad (+135°)** | **185 m** (fallback 165) | `:735-743`, `:812` |
| Temple / shrine (**no enemies**) | **−2.35 rad (−135°)** | **170 m** | `:744-748` |
| VC camp (3 mortar + 2 ZPU crew) | **−2.35 rad, same flank** | **300 m** (fallback 265) | `:823-841` |
| 3 jungle ruins | 1.15 / −0.55 / 3.05 rad | 175 / 140 / 160 m | `:764-790` |
| Treeline watchers (3–5) | fixed | ~190 m | `:814-819` |
| First-sign craters (2–3) | outbound arc | 150–300 m | `:798-808` |

**Derived, and it matters:** the village flank and the temple/camp flank are **90.5° apart**, not 270°.
So the village→temple chord is **~252 m** and the village→camp chord is **~353 m**. The two-site loop
gate→village→camp→gate is **~800 m of ground**, not the ~1,000 m a naive reading of "opposite flanks"
suggests.

**THE FACT THAT DECIDES THE WHOLE DESIGN** (`scripts/missions/field_director.gd:1325-1326`):

```gdscript
if kind in ["village", "vc_camp"]:
    patrol_locations.append({"pos": sd.center as Vector3, "kind": kind})
```

**`patrol_locations` accepts exactly TWO kinds.** Temples and ruins are *not* sweep locations — they are
pure discovery with `[F] SEARCH THE SHRINE` (`scripts/player/player.gd:626-630`). In the shipped demo
world that means the existing selector already offers **exactly two places, in a fixed order**: the
village (185 m, nearest to the gate — `_pick_patrol_objectives` sorts by distance from the gate,
`field_director.gd:1409-1419`) and then the camp (300 m). Six already offers the second one himself,
by bearing and distance, with **"OR BRING THEM IN. YOUR CALL."** (`field_director.gd:1666-1668`).

**The completion rules** (`field_director.gd:1613-1642`): a sweep finishes on (a) a kill inside the
90 m ring plus zero live hostiles in it, (b) a tunnel mouth that was there on arrival and is now gone,
or (c) a stash cleared. `SWEEP_ARRIVE_M` 120 m gates all three — he must walk there himself.
**Consequence: a temple can never finish a sweep, because it has no enemies, no tunnel and no stash.**

**Walk speed** `WALK_SPEED` 5.0 / `SPRINT_SPEED` 8.0 / winded 7.0 (`scripts/player/player.gd:12-13,81`).

**There is no talk verb.** `field_interact_prompt()` (`player.gd:604-655`) has fourteen branches and
none of them is a person you can speak to. A quest-giver is **a new verb**, and that is the honest
centre of the cost.

**There is no conversational VO.** The banks are 25 combat line ids across five voices plus a
15-line radio voice (`assets/audio/vo/{bryce,hfc_male,john,norman,ryan}`, `joe the radio man voice`).
Every line written in sections D and E below is **text on the existing toast/subtitle channel**, or it
costs recording days he has not budgeted.

---

## A · THE TWO DEMO QUESTS

### A.0 The governing ruling

> **THE TWO QUESTS ARE NOT A NEW TASKING SYSTEM. They are two men putting a REASON on the two places
> the sweep selector already offers, in the order it already offers them.**

Build a second picker and you have rebuilt the offer board ADR-029 killed, you have breached §4
clause 4, and you have doubled the bug surface on the one loop that must not break in the shipping
demo. The village is already first. The camp is already second. Six already hands off between them.
**All that is missing is a human motive and a human payoff** — which is precisely the RPG the decree
asks for.

### A.1 QUEST ONE — THE VILLAGE. Given by the BLACK-MARKET GANG.

- **Who:** the gang's man in the hooch nearest the supply depot. He is not a quartermaster and he is
  not on your roster. He is a Spec-4 with a footlocker.
- **Where the ask happens:** face to face, inside the wire, before you cross it. Never on the net.
- **The verb:** `[F]` on him. One ask, spoken, no accept button, no menu, gone when you walk away.
- **The ask, in his words:** *"There's a ville out west. When your patrol goes through it, I want
  what's in the headman's hut. Not the rice. The rest of it."*
- **What ends it:** the existing sweep. He arrives, there are 3–4 defenders in the 90 m ring
  (`mission_generator.gd:812`), a kill inside the ring plus zero live hostiles fires
  `_finish_sweep("THE AREA'S CLEAR")` (`field_director.gd:1629-1630`) — the point man calls it, the
  map takes a dated `SWEPT` mark (`:1650`), Six offers the camp.
- **The second, quieter end:** the thing itself. A `FieldCache` (`scripts/props/field_cache.gd`,
  already the `[F] TAKE FROM …` verb at `player.gd:645-646`) stamped in the village. Taking it is
  the quest. **He can also just not take it, and nobody says anything.** Pillar 3.
- **Return at dusk:** the gang's man is where he was. He says one line and hands over something that
  exists today — a satchel, a belt for the pigman, a gun off the rack. Not points, not a currency.

### A.2 QUEST TWO — THE CAMP. Given by the TRUE BELIEVERS.

- **Who:** the lifer NCO who eats alone, or the man in the hooch with the tidy bunk. He is not HQ. He
  wants the mortar tube that has been dropping on the wire.
- **The ask:** *"There's a tube out there. It's been walking rounds onto us for a week and battalion
  says wait. I'm asking you not to wait."*
- **What ends it:** the camp is the second thing `_pick_patrol_location` offers; the mortar crew and
  the ZPU crew are in the ring (`mission_generator.gd:834-841`), so the same rule (a) fires. If a
  tunnel mouth is stamped in the camp (`site_planner.stamp_vc_camp`, `:2244+`), rule (b) is the
  quieter completion — satchel the hole and walk away without a firefight. **Both roads legal.**
- **Return at dusk:** the lifer's payoff is not an object. It is that he speaks to you now, and the
  draftees notice he does.

### A.3 DO TWO FIT IN 19.7 MINUTES? — the honest answer is **ONE AND A HALF, AND THAT IS THE POINT**

Priced at his measured geography, walking, with a squad, in jungle:

| Beat | Ground | Real time |
|---|---|---|
| Wake, cross the compound, take the ask, clear the gate | ~120 m + browsing | **2.0–3.5 min** |
| Gate → village (185 m, cautious, sight cap 45 m) | 185 m | **1.5–2.5 min** |
| The village: contact, clear the ring, take the cache | — | **3.0–5.0 min** |
| Village → camp (353 m chord, across an unwalked flank) | 353 m | **3.0–4.5 min** |
| The camp: 5 men, hunters live after first contact (`field_director.gd:1458`, pool ≥6) | — | **4.0–6.5 min** |
| Camp → wire (300 m, heavier, possibly dragging a man) | 300 m | **2.5–4.0 min** |
| **TOTAL** | **~800 m** | **16.0–26.0 min** |

Straight-line at `WALK_SPEED` the 800 m is 160 s. **The walk is not the cost. The two fights are.**

**RULING.** The median run lands at **~21 min** — past the 19.7 min night seam and *arriving at the
wire around the 23.25 min probe*. That is not a failure; **that is the demo he described.** Quest one
is a full quest. Quest two is the one he finishes in the dark, and the wire is hot when he gets back.

But it only works if three things hold, and one of them is a change:

1. **Do not add a third quest, and do not put a quest on a temple.** A temple cannot finish a sweep
   (§0). A quest whose completion condition the engine cannot fire is the exact defect his 8/28
   playtest opened as **Q2 — "he believes he did what was asked; it never registered as finished."**
2. **Quest two must be refusable in the field.** If the fast player takes the camp first, or skips the
   village, or turns for home at 300 m out, nothing is lost and nothing is said. Six's existing
   **"OR BRING THEM IN. YOUR CALL."** is already the correct sentence and must not be replaced by a
   quest-flavoured one.
3. **The dusk return needs the two men to still be there.** They are `Civilian` nodes on garrison
   posts (`site_planner.gd:938-955`, `FSB_GARRISON_POSTS`); their schedule moves them
   (`FSB_GARRISON_QUARTERS`, `:959-962`). If the payoff man is off at a work marker when the player
   walks back in at dusk, the loop dead-ends silently. **Pin the two givers to a hooch billet for the
   arc, or the demo's best beat fails at random.**

**The slow player.** A browser who spends six minutes inside the wire first will reach the camp after
dark and be caught outside during the probe. That is a *great* outcome and must not be prevented —
but `_grant_fire_support` is once per sim day (`field_director.gd:1494-1497`) and the illum allotment
is 2–3. Walking home in the dark with no light is the demo's most likely bad-feeling failure. Name it;
do not fix it with a rail.

---

## B · THE FOUR §4 CLAUSES, AND THE BRIEFING SCREEN

ADR-029 Amendment C §4, probed by `tests/test_patrol_contract`. Taking each in turn against the design
above.

### Clause 1 — waypoints never check off
**PASS as designed. Breaches on contact with three things:**
- ✗ A map pin for the quest location. Forbidden — the village already gets a `SWEPT` circle *after*
  the fact (`field_director.gd:1650`) and that is a dated record, not a tick.
- ✗ A second completion toast. `_finish_sweep` already emits `SWEEP COMPLETE — THE AREA'S CLEAR`.
  A `QUEST COMPLETE` toast on top of it is exactly the "completion toast beyond the diegetic feedback
  the act itself produces" that **Amendment B forbids by name**.
- ✗ Any strikethrough, checkmark, or greyed-out state anywhere.
- **Redesign:** the confirmation is the man at dusk. Nothing on screen ever confirms a quest.

### Clause 2 — ground-covered never reaches the in-field HUD
**PASS, trivially — nothing here reads ground-covered.** The breach to watch for is the *adjacent*
one: a quest counter. `2/3 CRATES` or `MORTAR CREW 3/5` is the same disease with a different noun.
**Redesign:** the quest has no quantity. One place, one thing, one man.

### Clause 3 — command names features/ordinals, never objective pins
**PASS, and it forces a good craft rule.** A faction giver is **not command**. The clean, legible,
zero-ambiguity split, and I would make it law:

> **THE NET IS SIX. THE WIRE IS EVERYONE ELSE.**
> Battalion speaks over the radio, in bearings and distances, and offers. Faction men speak face to
> face, inside the wire, in place names and grievances, and ask. Neither ever uses the other's channel.

That is also the single best atmosphere dividend in this whole decree — it is *Platoon*'s actual
sound design — and it costs nothing because it is a restriction, not a system.
**Breach:** the black-market man calling you on the net. Forbidden. He does not have a radio, and the
fact that he does not is characterisation.

### Clause 4 — the route feeds only the one selector, never the scorer/tasking-authority
**THIS IS THE ONE THAT WILL BREAK.** The obvious implementation of "quest" is a flag that sets
`patrol_location`. `_set_patrol_location` (`field_director.gd:1563`) is documented as *"THE ONE PLACE
the sweep's location changes… four separate assignment pairs used to drift."* A quest system that
writes it becomes a second tasking authority and the drift returns.

**Redesign, and it is the whole architectural answer:**
- The faction ask **sets nothing.** It does not move the sweep, it does not reorder
  `patrol_locations`, it does not touch `patrol_objectives`.
- It works *because the selector already picks the village first.* The quest is a **reason applied to
  a tasking that would have happened anyway.**
- If a future faction ask must genuinely move the sweep, the only legal door is the existing
  `raise_crisis` (`field_director.gd:1673-1690`), which push-fronts to `patrol_locations` and
  retargets **through** `_set_patrol_location`, and which already respects the net check. Never a new
  path.
- The quest **must not touch the scorer.** `_bank_patrol` is the one AAR at the wire and it is
  untouched by the sweep work (Q2 finding, `PLAYTEST_FINDINGS_2026-08-28.md:69`). A quest that adds a
  score term re-opens ADR-006, which item 6 of the decree is retiring. Keep them apart.

### The thing ADR-029 killed in July — where a quest-giver re-grows the briefing screen

ADR-029 §1/§4/§7 deleted BriefingScreen, the offer dict, mission-select and the objective counter.
**The regrowth is not gradual — it happens at four identifiable moments, and the line is between the
third and the fourth:**

| | | Verdict |
|---|---|---|
| 1 | One man, one ask, spoken once, face to face, no UI, forgotten if you walk away | **LEGAL.** This is a bark with a motive. |
| 2 | Two men in two hooches, one ask each, found by walking | **LEGAL.** Plurality of *people*, not of *options*. |
| 3 | The ask is re-readable — a journal, a note in the inventory, a line on the map screen | **THE LINE. This is where it becomes a quest log.** Forbidden. |
| 4 | A place you go to collect tasks · a list of available asks · an ACCEPT/DECLINE prompt · an ask that waits for you | **THE BOARD, rebuilt.** Forbidden outright. |

**The precise test, and I would put it in the ADR:**

> **If the player can find out what he was asked to do without walking back to the man who asked him,
> you have built a briefing screen.**

Corollary, and it is uncomfortable: **the player is allowed to forget the quest.** He will. Some
players will walk out having missed both asks entirely, sweep the village on Six's word, and have a
perfectly good demo. That is the correct outcome and it must not be softened with a reminder.

---

## C · DEMO FACTION DRESSING — cheap vs. the trap, priced honestly

### C.1 GENUINELY CHEAP — the substrate already exists

The firebase seats its garrison at **authored GLB markers** with an occupation each
(`site_planner.gd:938-955`), sleeps them round-robin in **four named hooch billets**
(`FSB_GARRISON_QUARTERS`, `:959-962`), and the eleven hooch radio sets **already have voices**
— `_stamp_hooch_radios` (`site_planner.gd:2201-2240`) gives one radio per hooch, suppresses the model
because the GLB already draws it, and seeds each playlist from the radio's own position so no two
play in unison.

| Dressing | Mechanism that already exists | Honest price |
|---|---|---|
| **Who lives where** | Assign `FOOTPRINT_002 / _004 / _007` a faction tag; the round-robin already sends men home to a billet | **Code only, hours.** Zero art. |
| **What plays in which hooch** | `RadioProp.music_dir` is an `@export_dir` (`radio_prop.gd:16`); `site_planner.gd:2237` already does `radio.set("model_path","")` before `_ready` — a per-hooch `music_dir` is the same one-line move | **Code: one line. ASSETS: see the wall below.** |
| **Who acknowledges you** | The existing toast/subtitle channel; proximity, not interaction | **Writing only.** ~20 lines. |
| **Who does *not* look up** | An idle variant that does not play the look-at | **One clip, or free if the look-at is simply suppressed.** |
| **Two men doing the dap** | `crew-choreography` skill; a two-man spliced clip from the existing library | **~1 art-day** at his measured velocity. The single most expensive line in this table, and the one worth paying. |

### C.1a THE ASSET WALL ON THE RADIO — name it now

`assets/audio/Radio Vietnam/music` holds **14 tracks, all Vietnamese traditional** (khene, gongs, ho
work songs, funeral songs). There is **no American popular music in this project and there cannot be** —
the 1960s masters that would carry the *Platoon* two-hooch signal are exactly the recordings nobody
licenses cheaply.

**So the radio cannot carry the racial/social split by genre, and any plan that assumes it will is
built on an asset that does not exist and will not.** The substitutes that *do* exist, in order of
cost:

1. **Broadcast vs. music.** One hooch runs AFVN talk (`Radio_Vietnam_GOOD_MORNING_long_run.ogg`,
   `…Nixion_Inaguration…`, `…Night_Beat…`); another runs music. **Free — the files are on disk.**
2. **Volume and liveliness.** One hooch is loud with men in it. One is quiet with two men in it.
   `volume_db` and `hear_distance` are exports. **Free.**
3. **A man, not a machine.** A harmonica, a man singing, a transistor held to an ear. **~1 art-day of
   audio, and it is more period-true than a licensed needle-drop anyway.**

### C.2 THE TRAP — named-NPC-with-quest-logic

The moment a faction man is a **named, persistent, stateful individual** you have signed up for:
- a **talk verb** in `field_interact_prompt()` (`player.gd:604-655`) — a new branch in a 14-branch
  chain that already has priority ordering comments explaining why the order is load-bearing;
- **a state machine per man** (has he asked · did you accept · is it done · did you collect) — which
  is a quest log whether or not it is drawn;
- **pinning him against his own schedule** (§A.3 item 3), i.e. a garrison-schedule exception;
- **a face and a voice.** A named man the player is told to remember, rendered as the same clone
  everyone else is, is worse than an anonymous one. Enemy dressing is *already* an open P2 defect
  (`GAME_GUIDE` §8.1 item 3 — "`EnemyBase` has no dresser call at all");
- **save/restore**, if the demo ever needs it.

**Honest price:** the dressing in C.1 is roughly **one art-day plus a day of code**. Two named
quest-givers with state, a talk verb, schedule pinning and dressed faces is **three to five days**,
in a budget of 13–19 art-days of ~26 (`GAME_GUIDE` §8.1) with items 5, 6 and 7 unfinished.

**RULING.** Ship C.1 dressing for **all four factions**. Give **exactly two men** the named treatment,
and give them the *thinnest* state that works: **asked / not asked** — nothing else. No accept, no
"in progress", no completion flag on the man. At dusk he reads the world (was the sweep swept? is the
cache gone?) and speaks accordingly. **Read the world, do not store a quest.** That collapses the
state machine to a single bit and it is the difference between one day and four.

---

## D · WRITER LENS — THE RACIAL ELEMENT AS SOCIAL GEOGRAPHY

### D.1 The craft rules

**GOES IN THE WORLD (all of it environmental, none of it addressed to the player):**

1. **Hooch assignment is the whole statement.** Two of the four billets sort themselves. It is never
   remarked on, never explained, and the game never draws attention to it. The player either notices
   or does not, and both are fine.
2. **What is playing, and how loud.** Per §C.1a: talk radio in one, music in another, a man with a
   harmonica in a third. **Never a licensed song doing the work a scene should do.**
3. **The dap between two specific men.** Not "black soldiers do the dap" — *these two men*, always
   each other, always unhurried, and **they finish it before either acknowledges the player.** That
   last beat is the entire craft of it: the ritual outranks you, briefly, and nobody comments.
4. **Who does not look up.** You step into a hooch that is not yours; the conversation continues at
   lower volume; the radio does not change; one man nods and the others do not. **Nobody says a word
   about it.** This is the single cheapest and most eloquent thing in the whole list.
5. **Where a man sits at chow.** The chow hall already has a servery post, a queue and seats
   (`site_planner.gd:993-1000`, the `chow_server` marker family). Seating is dressing, not code.
6. **Small refusals.** A man who does not hand you the thing you reached for, and hands it to the man
   next to you instead. One animation, no line.

**FORBIDDEN, without exception:**

- **Slurs as ambient texture.** Not for grit, not for accuracy, not once. The period is carried by
  everything else in §D.1; a slur adds nothing the hooch assignment has not already said, and it turns
  a background man into a statement.
- **Any individual standing for a group.** No man explains his people, his neighbourhood, or his
  experience to the player. Every ambient man is one guy with one grievance.
- **The player as arbiter.** No "fix the racism" ask, no Tolerant/Bigot dialogue branch, no reputation
  for how he treated it, no scene that resolves because he walked in. He has **no verb** here and that
  absence is the design.
- **Speaking it AT the player.** Nothing in §D.1 is said to the player's face. It is all overheard,
  seen, or not offered.
- **A payoff.** Nothing in this layer may reward, unlock, gate, or score anything. The moment it pays,
  it is a system and it is being optimised.

### D.2 THE DRAFT IS THE LOAD-BEARER

The draft carries the class-and-race truth without a single line about race, because **the draft is a
question of paperwork and money, and men in a hooch talk about paperwork and money constantly and
without embarrassment.** Who got a deferment, whose father knew someone, who was in school and who
was not, whose number came up. It is period-true, it is *what men actually complained about*, and it
puts the whole structure in front of the player as gossip.

**EXAMPLE LINES — the register (in-world, overheard, never addressed to the player):**

1. *"Wilson had two years of college. Two years, and they took him anyway. Somebody in that office
   just doesn't like him."*
2. *"You know who's not here? Anybody I ever met whose dad had a lawyer."*
3. (a man reading a letter aloud to nobody in particular) *"My brother made the list. Doctor wrote
   about his knee. I've seen that man play ball on that knee all summer."*
4. (of a replacement, flat, not hostile) *"Nineteen. Cleveland. Same as the last one."*
5. (to another man, as the player passes and is not included) *"You go home in March. You said March.
   Say it again."*

**EXAMPLE LINES — the failure mode, so the line is legible:**

1. ✗ *"You ever notice it's always the same guys pulling point around here?"* — **a man explaining the
   theme to the player.** It converts a structure into a message and makes the speaker a
   representative. This is the failure that will get written by accident, because it *sounds* like
   good, brave writing.
2. ✗ `[DIALOGUE]  > "That's not right."   > "Stay out of it."` — **the player as arbiter.** Two
   options and a moral scoreboard behind them; the exact PS2 thing ADR-019 was written to forbid.
3. ✗ *"Get out of our hooch, [slur]."* — **a slur doing plot work.** It makes the moment about an
   incident with a villain and a victim, which is a storyline; the hooch assignment already said
   everything true, quietly, and permanently.

> **THE TEST, one sentence:** *if the player could describe what he saw but could not describe what the
> game wanted him to think about it, it is right.*

---

## E · WRITER LENS — THE FACTION READOUT (item 5, the load-bearing sample)

**The mechanism, stated plainly:** Hearts & Minds is a hidden province value with no meter, by law
(ADR-019 §4). The men at the firebase are how the player **hears** it. One action, four readings, and
none of them is the truth — HQ's reading is an *opinion*, the believers' is a *creed*, the burnouts'
is *fatigue*, the gang's is a *price list*. **The world's reading is not spoken at all: it is the
paddy that is empty at midday and the trail that is wired now.** Zero new UI; it rides the toast /
subtitle channel that already carries 162 lines.

### ACTION 1 — He put fire on the ville. (Burned it, or called steel onto it.)

| Reading | Line |
|---|---|
| **WORLD** *(not spoken — this is the affordance)* | The paddies south are empty at midday. The trail he used last week has a wire across it now. The old man at the well is not at the well. |
| **HQ** | *"Battalion likes the number. They want to know if you can do it again this week."* |
| **TRUE BELIEVERS** | *"Whole place was VC and everybody in this camp knew it. Took an outsider to say so."* |
| **DRAFTEES / BURNOUTS** | *"…"* (the hooch does not stop talking, it just gets quieter, and one man gets up and goes outside) |
| **BLACK MARKET** | *"Nothing came out of there? You burn a whole ville and you come back with your hands empty. That's just waste, man."* |

### ACTION 2 — He let a VC patrol walk past. (Contact avoided.)

| Reading | Line |
|---|---|
| **WORLD** | The trail stays cold. Next week the same men use it, at the same hour, and he knows the hour. |
| **HQ** | *"Zero contact. Zero results. What am I supposed to send up the hill?"* |
| **TRUE BELIEVERS** | *"You had them. You had them and you let them walk home."* |
| **DRAFTEES** | *"Nobody got hurt. That's the whole thing. That's a good day."* |
| **BLACK MARKET** | *"So you got nothing off them either. Man, everybody out here's got something on him."* |

### ACTION 3 — He broke up a VC tax collection and left the ville standing.

| Reading | Line |
|---|---|
| **WORLD** | A kid runs alongside the column instead of inside the hut. The headman looks at him instead of past him. |
| **HQ** | *"Battalion hasn't got a box on the form for that one."* |
| **TRUE BELIEVERS** | *"You're playing policeman for people who'll feed the same men tonight."* |
| **DRAFTEES** | *"Heard you went all the way down there and didn't shoot anybody. Nice change of pace."* |
| **BLACK MARKET** | *"They like you down there now? That's not nothing. That's a supply line, is what that is."* |

### THE ONE HE ASKED FOR — the villes not talking, heard four ways

- **HQ:** *"S2 says the whole southern district has gone quiet on us. Nobody's reporting. Fix it."*
- **TRUE BELIEVERS:** *"They stopped talking because they finally figured out which side we're on.
  Good."*
- **DRAFTEES:** *"Villes down south won't talk to anybody since you came through. Not to us, not to
  the ARVN. Nobody."*
- **BLACK MARKET:** *"My guy in the south stopped coming up the road. You did that. Now I'm paying
  Saigon prices."*

### The craft rules under these lines (this is what makes it work, not the lines themselves)

1. **Nobody says the name of the system.** No "allegiance", no "the villagers' opinion of you", no
   "hearts and minds". Four men, four grievances, one hidden number none of them can see either.
2. **HQ's reading is the least true one.** That is the decree's item 6 doing its work: body count
   becomes an *opinion held by a specific office*, not a law of the universe.
3. **The draftee is the honest channel and the black-market man is the most useful one.** The
   burnout tells the player what happened; the dealer tells him what it *cost*. That is why the
   dealer, not HQ, is the natural quest-giver for the demo's first quest.
4. **The world's reading is never a line.** The instant somebody narrates the empty paddy, the meter
   is back. ADR-019 §4's exception to r4bk survives only if the world channel stays wordless.
5. **Each line is under twenty words and none of them explains itself.** They are complaints, not
   readouts.

---

## F · WRITER LENS — VIGNETTE PLACES (item 13, ROADMAP ONLY, BUILD NOTHING)

The Do Lung model, stated as a rule: **a place, further out, less commanded, that says everything by
existing.** No cutscene, no cinematic, no mad colonel, no river. The binding test is ADR-020 §3's:
*can he turn around and leave right now?* Every one of these must answer yes.

**1 · THE FIREBASE THAT IS EMPTY.**
The same `fsb_main.glb` he has already built — the one asset everything stands on (`GAME_GUIDE` §8.1
item 5) — dressed dead. Wire down in one place, guns spiked, the chow hall standing with trays on the
tables, one radio still playing to nobody (`RadioProp` already runs a timeline whether the player is
present or not, `radio_prop.gd:2-4`). Three ARVN squatting in the TOC who will not explain and cannot
be recruited. **Cost: near zero new art — it is his own firebase, re-dressed.** This is the strongest
candidate on the list by a wide margin and it says the entire thesis in ninety seconds of walking.

**2 · THE BRIDGE NOBODY COMMANDS.**
The road net already stamps (`plan_demo_world` roads), the plank walkways exist, illum flares exist
(`field_director.gd:974-982`), ambient AA tracers exist (`mission_generator.gd:849+`). A bridge held
by men who have been there so long the chain of command has fallen off. Somebody is firing into the
treeline at nothing, on a schedule. Ask who is in charge and you get a shrug and a question back.
**No river journey; the player walks up to it, and walks away from it.**

**3 · THE OUTPOST THAT WILL NOT LET YOU IN.**
An ARVN or CIDG post on the temple/village kit with a closed gate and a man who is polite, immovable,
and will not open it. The player can see the inside through the wire. There is no verb that opens it,
no quest that opens it, and no reason given. **Authority dissolving with distance, rendered as one
closed gate.** Cost: an existing kit, a gate, one idle, ~4 lines of text.

**4 · THE RUIN WHERE AMERICANS LIVE.**
The `prasat_ruin_01..10` pool is already in the generator (`mission_generator.gd:755-758`) and every
temple already carries `[F] SEARCH THE SHRINE`. Put half a dozen men in one, out of uniform, in
country long enough that nobody is coming for them. They are not hostile. They are not friendly. They
do not ask him for anything and they do not answer the net. **He walks in, he walks out, and nothing
is resolved.**

**What all four have in common, and it is the rule:** the player arrives, understands the place
instantly, is offered nothing, and leaves. **No place on this list has a quest in it.** The moment one
does, it is a mission, and the descent becomes a chapter list.

---

## G · TRADEOFFS — everything this costs (no free lunches)

**Sacrificed by the two-quest design (§A):**
1. **The demo's day is now aimed.** ADR-020 §5's front-loaded density is being spent on two authored
   asks, and a player who follows both walks a route we chose. It is not a rail — he can refuse
   either, and Six offers the same two places regardless — but **it is the closest this project has
   come to one**, and the Arbiter will have to say no to the third quest, then the fourth.
2. **The quiet demo dies.** A player who takes no ask now gets a *lesser* version of the same 30
   minutes, because the two best beats are attached to two men he never met. That is a real cost of
   putting content on people.
3. **The camp becomes near-mandatory content.** Today it is the second thing Six offers and many
   players never reach it. Attaching a quest makes it the expected destination, and if it is
   underbuilt it will now be underbuilt *in front of everyone*.
4. **Two more failure surfaces in the shipping arc**: the giver being off-post at dusk (§A.3.3), and
   the sweep failing to fire (his 8/28 Q2 wound). Both land in the demo playthrough, which is the
   session entry gate.

**Sacrificed by the faction dressing (§C):**
5. **Named men in a clone cast.** Two men the player is asked to remember, wearing the same face as
   forty others, while enemy dressing is still an open P2. Naming a man raises the bar on his face.
6. **Three to five days if it is done as full NPCs**, out of 13–19 in a budget with items 5–7 open.
   The asked/not-asked single bit is the only version I would ship, and it is a *worse* RPG than the
   one the decree imagines. That is the correct trade for a 2026-09-06 EA date.

**Sacrificed by the social-geography rules (§D):**
7. **Most players will not notice any of it.** That is the design working and it will read to some as
   the topic being ducked. There is no defence available, because every available defence — a line, a
   scene, a choice — is the failure mode.
8. **No American music, ever.** §C.1a. The most legible signal *Platoon* uses is unpurchasable, and
   every plan that reaches for it must be stopped.
9. **The layer can never pay off.** Nothing here unlocks, scores or resolves. Someone will propose a
   reward for engaging with it. The answer is no, permanently.

**Sacrificed by the readout (§E):**
10. **It is voiceless.** 25 combat line ids exist, none conversational. Every line in §E ships as text
    on the toast channel or costs recording days nobody has budgeted, and text-only faction voices in
    a game with voiced squad barks will read as unfinished to some players.
11. **Four readings of one act is four times the writing, forever.** Every future action worth
    reacting to costs four lines, not one. That is the price of the key synthesis, and it is a
    permanent tax on content.
12. **Ambiguity by design.** Four contradictory readings and no meter means some players conclude the
    system does nothing. ADR-019 already accepted this cost; the faction readout makes it *louder*
    without making it *clearer*, and that is deliberate.

**Sacrificed by the vignettes (§F):**
13. **All roadmap, all post-launch.** Writing them down creates a pull to build one "since it's
    cheap." The empty firebase in particular is cheap enough to be dangerous before EA ships.
14. **A place with nothing in it will be called empty content** by a fraction of players, and the
    answer to that complaint is never "put a quest in it."

**The one I would flag hardest, above all of these:** the decree's §5 synthesis — factions as the
readout for Hearts & Minds — is **magnificent and unbuildable this month.** ADR-019's ledger does not
exist in code (`scripts/world/civilian.gd:718-722` says so in as many words; ADR-019's own status note
confirms it). **In the demo there is no province value for the factions to read.** Anything shipped
now is four men with canned opinions, not a readout. That is fine — record it as canon, ship the
dressing and two asks, and do not let anyone claim the readout is live until there is a number behind
it to be read.
