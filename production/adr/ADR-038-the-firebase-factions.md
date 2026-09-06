# ADR-038: The Firebase Factions — four camps inside the wire, and the readout for Hearts & Minds

**Date:** 2026-09-06 · **Status:** ACCEPTED (Summoner decree, THE RPG PIVOT) ·
**Amends:** ADR-019 (§4 "allegiance is FELT, not read" — this ADR names the organ it is felt *through*) ·
**Depends on:** ADR-017 (the province must persist), ADR-019 (the ledger being read), ADR-020 (the
authored threshold — a faction is a place, not a cutscene) ·
**War Room:** `production/war_room/2026-09-06_rpg_pivot/`

---

## Context

The Summoner reframed the project on 2026-09-06, his own EA target date, after seeing an AI "Skyrim in
Vietnam" video:

> RECONgame is an **RPG / STALKER-in-Vietnam**, not a firebase sim. NPCs give you problems. You live in
> a whole Vietnam world rather than being a soldier on one patrol at a time. **No fantasy elements.**

He answered the structural question directly: **the firebase IS home.** And he named what lives in it —
*Platoon*'s camp, split into camps.

This ADR exists because that reframe, on inspection, is not a new system. It is **the missing organ of a
system already ratified and still unbuilt.** ADR-019 decreed Hearts & Minds — village allegiance driving
VC manpower — and in the same breath took the only affordance away from it:

> "**There is no hearts-and-minds meter in the HUD.** … A live numeric meter is forbidden, because the
> moment allegiance is a number, the player optimizes it and the moral weight evaporates."

ADR-019 named that as a deliberate, narrow violation of the r4bk law and accepted it on one condition,
verbatim: *"If the player cannot feel it through the world within one playtest, the presentation has
failed — and the fix is **more world**, never a meter."*

**The factions are the more world.** That is the whole decision below.

## Decision

### 1 · FOUR CAMPS INSIDE THE WIRE

The firebase holds four bodies of opinion. They are **social geography, not organisations**: nobody
joins one, nobody has a reputation bar with one, and no screen lists them.

| Camp | What it wants | Its register |
|---|---|---|
| **HQ** | numbers it can send up the hill; to be kept happy | an office. Its reading is an *opinion*, never a truth |
| **THE TRUE BELIEVERS** | the war won; the straight-laced, anti-communist lifers | a *creed* |
| **THE DRAFTEES / BURNOUTS** | to go home; they don't want to be here | *fatigue* — the honest channel |
| **THE BLACK MARKET** | a cut of everything; it pushes the draftees, and you, toward itself | a *price list* — the most useful channel |

### 2 · THE FACTIONS ARE THE READOUT FOR HEARTS & MINDS

> ## **The world holds the value. The men at the wire are how the player HEARS it.**

One player action gets **four different readings, none of which is the truth**, plus a fifth that is
never spoken:

- **The WORLD's reading is not a line.** It is the paddy empty at midday, the trail that has a wire
  across it now, the old man not at the well. **The instant somebody narrates the empty paddy, the meter
  is back.** ADR-019 §4's exception to r4bk survives only while the world channel stays wordless. This is
  binding.
- **The four spoken readings** ride the toast/subtitle channel that already carries the game's radio
  traffic. **Zero new UI.** No screen, no menu, no meter, no faction standing.

Worked sample — *the villes to the south have gone quiet since he came through*:

| Voice | Line |
|---|---|
| **HQ** | *"S2 says the whole southern district has gone quiet on us. Nobody's reporting. Fix it."* |
| **TRUE BELIEVERS** | *"They stopped talking because they finally figured out which side we're on. Good."* |
| **DRAFTEES** | *"Villes down south won't talk to anybody since you came through. Not to us, not to the ARVN. Nobody."* |
| **BLACK MARKET** | *"My guy in the south stopped coming up the road. You did that. Now I'm paying Saigon prices."* |

**The five craft rules that make this work** (they are the decision, not decoration):

1. **Nobody says the name of the system.** No "allegiance", no "hearts and minds", no "the villagers'
   opinion of you". Four men, four grievances, one hidden number none of *them* can see either.
2. **HQ's reading is the least true one.** This is how §4 below does its work.
3. **The draftee tells him what happened; the dealer tells him what it cost.**
4. **The world's reading is never a line.**
5. **Every line is under twenty words and none of them explains itself.** They are complaints, not
   readouts.

### 2a · THE IMPRECISION LAW (binding — this is what actually protects §2)

The council's sharpest attack on this decree, and it lands: **four voices are a meter *with causal
annotation*, which is a strictly BETTER optimisation signal than a number.** "The villes down south
won't talk to anyone since you came through" tells the player the subject, the direction and the cause
in one sentence. ADR-019 §4's defence — *a number would be optimised* — **does not survive as written**,
because prose can be more optimisable than a number.

**What protects the system is not silence. It is imprecision.** Therefore:

> ## **A faction line may name the SUBJECT. It may never name the QUANTITY, the RATE, or the DIRECTION OF CHANGE.**

- **Legal:** *"the villes down south won't talk to anybody since you came through"* — a subject and a
  grievance.
- **Illegal:** *"the district's turned about halfway against us"* (quantity) · *"they hate us more every
  time you go out there"* (rate) · *"that helped — they're coming back around"* (direction of change).

Grep-enforceable, and it must be enforced: no numerals, no comparatives of degree, no "more/less than
before" in any faction line. **A line that lets the player score his last patrol has rebuilt the meter.**

**Corollary, and it is a build requirement, not a nicety:** at least one faction voice must be
**unprompted** — spoken because you walked past, not because you asked. A readout the player must query
is a menu with a face on it.

### 3 · THE RACIAL ELEMENT — PRESENCE WITHOUT PLOT

The Summoner asked for the 1960s racial reality to be present because it is historically true, and said
plainly that he does not think he is the writer to handle it as a **plot** and does not want it done
badly. **That instinct is upheld as law, not worked around.**

**It lives as social geography and never as storyline** — *Platoon*'s two-hooch structure. It is in who
sits where, what is on the radio in which hooch, whose hooch you are welcome in, the dap between two
specific men, who does not look up when you walk in, and small refusals.

**Binding constraints:**

- **No slurs as ambient flavour.** Not for texture, not for period accuracy, not once.
- **Individuals are never representatives.** No man stands for a group.
- **The player is NEVER the arbiter.** No "fix the racism" quest. No Tolerant/Bigot dialogue options. No
  resolution, no reconciliation scene, no reward for either. There is no lever here and the player must
  never be handed one.
- **The DRAFT carries the class and race truth** — who got sent and who got a deferment. This is the
  channel, because it is a *fact about the war* rather than a claim about a person, and it is said
  between men about themselves, never at the player.
- **Nothing is said AT the player about race.** Ever.

**If any of this cannot be done to this standard, it is cut.** Presence without plot is the whole
permission; a plot is an immediate breach.

#### 3a · THE LAUNCH RULING: PLACEMENT SHIPS, THE VERBAL LAYER IS CUT

The council took his own words seriously — *he told us he is not the writer for this* — and Law 3 says
the Summoner holds final authority, including over his own limits. So:

- **SHIPS AT LAUNCH: social geography as PLACEMENT ONLY.** Chow-hall seating, work details, hooch
  groupings, who walks with whom, who does not look up. **Zero authored lines about race.** This is
  level-design work. It needs no writer, costs no writing days, and **it is exactly the version his own
  stated approach describes.**
- **CUT FROM LAUNCH: every authored line of racial content — including the good ones.** Not because
  they would be bad, but because he said he is not the writer for them. A writer can be brought in
  post-launch, and the placement layer will be waiting.
- **THE GUARDRAIL NOBODY NAMED: the same care extends to the Vietnamese**, and the first place it bites
  is the civilian — a bigger open item than the American layer, and already on the board as ADR-019's
  named art and behaviour gap.

**THE ONE TEST THAT IS NOT A MATTER OF TASTE — run it before ship, it takes five minutes:**

> List every named character with a speaking line, and every character who is visually non-white. **If
> the intersection is exactly the set who speak about race, the representative failure has occurred.**

### 4 · THE MISSION SCORE'S MORAL RELOCATES (ADR-006 retirement — see ADR-006 Amendment B)

Body count stops being a law of the universe and becomes **HQ's opinion**, held by one office among
four. Fire discipline near a ville stops being a scoring term and **becomes allegiance itself**. The
+25/−25 rule's moral survives; the arithmetic does not.

### 5 · WHAT SHIPS IN THE DEMO — AND THE HONEST LIMIT

**This is a scope wall, not a build order.**

**BUILDABLE AND IN DEMO SCOPE — dressing only:**
who lives in which hooch · what plays on which hooch radio · who acknowledges you and who does not look
up · two men doing the dap. The substrate exists: the garrison is seated at authored GLB markers with an
occupation each and slept round-robin in four named hooch billets (`site_planner.gd:938-962`), and the
eleven hooch radio sets **already each have exactly one voice** (`_stamp_hooch_radios`,
`site_planner.gd:2201-2240`; `RadioProp.music_dir` is an exported dir).

**NOT BUILDABLE TODAY, AND MUST NOT BE CLAIMED — the readout itself.**
ADR-019's ledger **does not exist in code**; `scripts/world/civilian.gd:718-722` records the deferral in
so many words. **There is no province value for the factions to read.** Anything shipped in the demo is
therefore *four men with canned opinions*, and **no doc, comment or store page may call it a readout**
(truth law, ADR-015). §2 is the law the code will be brought to, not a description of the code.

**THE ASSET WALL, named now so nobody plans against it:** the project's radio library is 14 Vietnamese
traditional tracks. There is no American popular music in this project **and there cannot be** — the
1960s masters that would carry the *Platoon* two-hooch signal by genre are exactly the recordings nobody
licenses cheaply. Any plan that reaches for a needle-drop is dead on arrival. The substitutes that exist:
**AFVN talk versus music** (free, already on disk), **volume and liveliness** (one hooch loud and full,
one quiet with two men in it — free), and **a man rather than a machine** — a harmonica, a man singing,
a transistor held to an ear, which is more period-true than a licensed needle-drop anyway.

## Consequences

**Bought.** ADR-019's named failure condition gets its answer: allegiance becomes *felt* through people
instead of silently bookkept, with **zero new UI and no meter**. The firebase stops being scenery and
becomes the reason to come back — the RPG the Summoner asked for, built out of men rather than menus. The
mission score's moral survives its own retirement. And *Platoon*'s camp exists in the game that has
wanted it since the first pillar was written.

**Sacrificed — no free lunches.**

- **Four voices may read as noise, or as nagging, or as contradiction.** They are *designed* to
  contradict, which is the point and also the risk: a player who wants to know how he is doing will be
  told four different things and may conclude the game is broken rather than that the war is.
- **This is arguably a meter with extra steps, and worse, an unambiguous one.** "The villes down south
  won't talk to anyone since you came through" is *clearer* feedback than a number and therefore
  potentially *more* optimisable. The only guard is craft rule 1 and the wordless world channel. If a
  playtest shows players optimising the lines, the fix is **fewer, later, vaguer lines — never a meter.**
- **A player who never talks to anyone gets no readout at all.** Accepted: the world channel is still
  firing, and Pillar 3 says he may ignore the camp.
- **The racial element is the highest-reputational-risk content in the project.** It is kept only on the
  terms in §3, and §3's last sentence is real: it is cut before it is done badly.
- **It doubles down on civilians and on the province ledger**, neither of which exists yet.
- **Named individuals cost far more than dressing** (see the demo plan): the moment a faction man is
  named, persistent and stateful he needs a talk verb, a state machine, a schedule exception, and a face
   — and enemy/NPC dressing is *already* an open defect.

## Evidence

- Summoner decree, 2026-09-06 (conversation of record); briefing at
  `production/war_room/2026-09-06_rpg_pivot/briefing.md`; council analyses in `analysis/`.
- `production/adr/ADR-019-hearts-and-minds.md` §4 (no meter; "the fix is more world, never a meter") and
  its 2026-08-07 STATUS NOTE (not implemented).
- `scripts/world/civilian.gd:718-722` — the ADR-019 deferral, in the code's own words (verified).
- `scripts/world/site_planner.gd:938-962` — `FSB_GARRISON_POSTS` / `FSB_GARRISON_QUARTERS`, four named
  hooch billets, round-robin (verified).
- `scripts/world/site_planner.gd:2201-2240` — `_stamp_hooch_radios`: one voice per hooch across eleven
  hooch sets, model suppressed, playlist seeded from position (verified).
- `assets/audio/Radio Vietnam/music` — 14 tracks, all Vietnamese traditional (verified).

## Related

- **ADR-019** — the system this ADR gives an organ to. Amended: §4's "felt, not read" now names *how*.
- **ADR-006 + Amendment B** — the retired score whose moral relocates here.
- **ADR-020** — the authored threshold: a faction is a *place and a person*, never a cutscene.
- **ADR-029 + Amendment C** — the loop the demo's two quests must not re-grow a briefing screen inside.
- **Pillars served:** 2 (Atmosphere — the camp is the war's weather), 4 (the squad is the RPG — extended
  outward to the men around the squad), 5 (Fail forward — what you did comes back as what men say).
