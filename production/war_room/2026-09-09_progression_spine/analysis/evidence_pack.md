# EVIDENCE PACK — canon, code and competitor research
## War Room 2026-09-09, THE PROGRESSION SPINE · companion to `measurements.md`

Read `measurements.md` first (squad/RTO/command code truth). This file carries the rest: the canon
collisions, the suppression finding, the comic, and the competitor research.

---

## 1 · PILLAR 4's ANTI-PUPPETEER CLAUSE — the full text, and its real status

**Source of record: `production/bible/BIBLE.md:88-94`.**

> 4. **The squad is the RPG — and you are IN it, not above it.** Named persistent teammates with MOS
> roles who improve, get wounded, rotate home, and die for real; minimal stats, maximal attachment.
> **You are a member of the squad, not its puppeteer** — you suggest movement, call targets, request
> support, and the squad holds its own AI intent. **A design that has you positioning individual men
> violates this pillar.**
>
> > **PROVISIONAL — under playtest review (Summoner, 2026-07-19).** *"pillar 4 is open to changing as i
> > play test more. if it makes more sense to try to be more tactical with the troopers i will take it
> > that way."* … **Do not treat the anti-puppeteer clause as settled law until he rules from play. The
> > other four pillars are not provisional.**

**His own 2026-07-19 playtest verdict on the squad, verbatim: *"it felt like I was driving him."***

**Latest touch, `2026-09-07_squad_cohesion/synthesis.md` §9:** *"Pillar 4's provisional anti-puppeteer
clause: FORMALLY OPEN, PARKED. Nobody is proposing a command layer; it has no urgency and was not
forced. It remains his ruling to make from play."*

**Two days later, he proposed a command layer.** The clause is now forced. It is genuinely undecided —
not accepted, not rejected — and **only he can close it, from play.**

Historical note that matters: the clause was **dropped once before**, and its absence produced the exact
defect it existed to prevent (the "driving him" verdict), which is why it was restored and flagged
provisional rather than deleted (`BIBLE.md:74`).

---

## 2 · THE SUPPRESSION FINDING — the single most important thing in this pack

Brothers in Arms' real lesson was **suppression made legible**, not the cursor. So: does this game model
suppression, and can the player SEE it?

**It models it deeply, symmetrically, and well.**
- `scripts/ai/combat_posture.gd` — one shared source of truth. `SUPPRESS_PIN = 0.7`,
  `CROUCH_SUPPRESS = 0.6`, `SUPPRESS_FIRE_CEILING = 0.85`, prone enter/exit 0.85/0.6 with a 1.2 s commit
  and 8 s max dwell, cover-modulated accrual/recovery (`:23-26`), a 4 s "pin mercy" grace that widens the
  shooter's cone at a freshly pinned man (`:31-32`, `:64-69`), cone spread up to ×3.2 at the ceiling
  (`:58-59`).
- `scripts/autoload/combat_manager.gd:402-468` — `suppress_along_shot()` (near-miss along the lane) and
  `apply_suppression_in_area()` (blast / sustained fire), **faction-blind**.
- **The player's own fire suppresses enemies.** `scripts/player/weapon_holder.gd:716-728` routes every
  player shot through the same two functions enemy fire uses. Symmetric by construction.
- Player-side feedback when *he* is suppressed is good: camera shake, a screen shader
  (`terrain/shaders/suppression.gdshader`), audio lowpass toward 650 Hz (`player.gd:143-173`,
  `:2107-2198`).

### And the player cannot see it working on the enemy. At all.

- **No suppression bark exists.** `scripts/autoload/vo_manager.gd` has zero hits for "pinned" or
  "suppress".
- **No HUD affordance.** `scripts/ui/mission_hud.gd:249-291` shows HP pips (OK/HIT/CRIT/KIA),
  weapons-free/tight, RTO net state, point-man scan radius — **nothing about suppression, either side.**
- The only tell is indirect: the man crouches or hunkers. A player may read that as "taking cover",
  not as "my fire is working."

> **THE FINDING: this project has built the deep half of Brothers in Arms and none of the legible half.**
> BiA's genius was the **red ring that fades to grey** as you suppress a position — a single readout that
> taught fire-and-maneuver by showing it. (It was removed on the hardest difficulty, which is the
> period-honest option this project would want.)
>
> **A command grammar built on top of invisible suppression reduces to "men go there and die."** This is
> the r4bk law with teeth: the simulation exists, the presentation does not, so *for the player the
> feature does not exist.*

### The defect that would break the command scheme outright

`scripts/allies/ally_base.gd:1417-1491` — **`order_mode` is read ONLY inside `_execute_idle`.**

```
OrderMode.HOLD:     _settle(delta)
OrderMode.MOVE_TO:  if order_pos != ZERO and dist > 2.0: _move_toward(order_pos, delta)
                    else: _settle(delta)          # arrival == HOLD. Nothing else.
```

Three consequences, all fatal to the proposed grammar as-is:
1. **A man in COMBAT, SUPPRESSED, SEEKING_COVER, ADVANCING or FLANKING silently ignores every order**
   until he returns to IDLE. *You lose command of your squad at the exact moment you need it,* with no
   indication.
2. **"Move here" has no arrival behaviour.** On arrival he calls `_settle()` — the same function HOLD
   uses — then micro-idles (`:1519-1534`). **He does not take cover, does not go prone, does not face
   outward, does not defend.** "Hold and defend" is not a rename of an existing state; it does not exist.
3. **A missed order ray is dropped silently** (`squad_system.gd:286-288`) — no toast, no VO. The player
   presses the key and nothing happens.

**Acknowledgement as built** (`squad_system.gd:303-311`): one toast + **one** man speaks for the whole
squad (`VOManager.play_squad`, e.g. `"on_me"`, `"moving"`). No per-man accept, no refusal, no visual ack.

> Canon already anticipated this. **ADR-029 Amendment C §5** names *"Level-2 forgiving squad orders
> (area/direction, aim-and-press, confirm via bark + order-line + roster)"* as **spec-ready but GATED —
> "enabled only once the AI provably obeys in a playtest."** That playtest has never been run. The gate
> was written for exactly this proposal, before it was made.

---

## 3 · THE INPUT DOCTRINE CONSTRAINT

**ADR-012 (Accepted):** squad orders are FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE, **dual-bound F1–F4 +
C/H/X/N, and both bindings are permanent — "neither may be removed."** The ADR itself names the cost:
*"Dual-bound squad keys spend C/H/X/N, four prime keys now unavailable for future features."*

The 2026-09-07 squad-cohesion council's game-designer lens: *"Four is enough. I want no fifth key and I
will argue against one."* — and, on the cursor specifically: *"Hold the anti-puppeteer clause. Do not
import the command cursor"*, for three named reasons: the *Platoon* no-control fantasy dies; you would be
commanding blind under the 45 m jungle sight cap; and it removes the "cannot fix it fast enough" ambush
tension, *"the game's best emotion."*

**But note what `measurements.md` §2 found: there is no cursor to import.** MOVE_TO already designates by
aiming at the ground (`squad_system.gd:328-344`, one 250 m camera ray). His scheme is closer to as-built
than to Brothers in Arms.

---

## 4 · THE OTHER BINDING CANON

| Source | The clause that bites |
|---|---|
| **ADR-011** | *"ALL support verbs … require a LIVING RTO within `RTO_RADIO_RANGE` (10.0 m) … **No bypass paths.**"* Cost already named in the ADR: *"the 10 m leash punishes aggressive solo play … that friction is deliberate."* **Canon already treats "no RTO nearby" as a designed hardship — which is the early game he is describing.** |
| **ADR-020** | *"A RAIL TAKES THE CONTROLS AWAY. A GUARANTEE DOES NOT."* Binding test: *"Can the player turn around and LEAVE, right now, without the game stopping him or punishing him?"* And the Ambience Law: *"Every ambient event must be safe to ignore. The moment ignoring something COSTS the player, it is not ambience — it is a MISSION."* |
| **ADR-021** | *"New in country: **YOU FOLLOW.** An NPC sergeant sets the waypoints… **THE TUTORIAL — diegetic, unscripted.**"* → *"Trusted: **YOU LEAD.**"* **Assumes a squad from the start. There is no solo-start precedent anywhere in canon.** |
| **ADR-029 §4** | *"No player-facing mission tracking, ever."* Amendment B draws the line *"at bookkeeping, not at agency"* — world verbs legal, **objective counters forbidden.** |
| **ADR-039 §4** | *"You BOARD the bird, you never select it… no destination list, no map-select, no ACCEPT/DECLINE, and no screen at any point."* |
| **ADR-041** | *"THE SCENE IS A PLAN, NOT A PREFAB."* A hand-placed RTO NPC at a fixed post is illegal; he must be seeded/planned. |
| **DEMO_TWO_QUESTS_PLAN §5** | **THE BRIEFING-SCREEN LINE:** *"if the player can find out what he was asked to do without walking back to the man who asked him, you have built a briefing screen."* Anything re-readable is forbidden. **This governs "request an RTO companion" directly.** |
| **ADR-040 §1** | *"No player-specific damage multiplier… A future request to make the player tougher is answered with this ADR, not with a number."* **Solo survivability may not be bought with health.** |
| **GAME_GUIDE §4.4** | *"5-man persistent fireteam"* — the only squad-size number in canon **contradicts the code's 8** (`squad_system.gd:23`). A standing drift, found in passing. |
| **GAME_GUIDE:304** | *"Where realtime needs diverge from the tabletop (**suppression, morale** — RECON has neither), the divergence is named in an ADR, never silent."* **No such ADR exists.** Suppression, nerve and two-sided squad-break are live, wired and probe-covered code. **The game guide is in breach of its own rule.** |

---

## 5 · THE COMIC — CONQUEST OF WORMS

Three untracked drafts in `production/`, written 2026-09-09 03:32, confirmed by him as *"from the comic
intergration work we did this morning."* They are **adaptation research on his own existing underground
comic** (Rotten Sewer Productions, Issues 1–4, 2021–2025), not original game lore.

- **Premise:** Michael Lee Crawford, 17, drafted from Minden, Louisiana, arrives as a replacement in the
  101st Airborne, A Shau valley, **November 1967**. He carries his dead grandfather Louie's **WW1
  journal** and reads it in-country; **the comic cuts between the two wars.**
- A second replacement, "Gus"/Eugene, decays into trophy-taking, cannibalism, and shoots an officer.
- A disfigured **Russian WW2-veteran sniper** — skull-faced — stalks the squad, revealed at the end in a
  Kurtz-like dugout ringed with skulls and captured American helmets.
- **Causal chain:** WW1 Louie spares a young German → that German becomes an SS officer → tortures a
  Russian → that Russian is the sniper hunting Louie's grandson. *(Mostly undrawn; from his own synopsis.)*
- **The story has no ending.** Bible §10: *"The story stops. The author: 'thats about as far of a story i
  had written overall.'"* Issue 4 is drawn but never scripted.
- **His binding rule on the horror, verbatim:** *"any horror gore scene in the comic is supposed to be
  representative of the psychological state of the person expericing the vision"* — horror is never a
  monster in the world, always a readout of one man's mind.
- **His own scope ruling, verbatim:** *"so we could still add a horror level and it comes from like stress
  and shit but thats not a main focus right now but that is the vibe of the comic"* — **the VIBE, not a
  feature. No sanity mechanic is authorised.**
- Ancestors he named himself: **The 'NAM** (documentary procedure) and **Weird War Tales** (the horror
  sting) — **both short-form.**

**The strongest game-native idea in it, called out repeatedly:** the sniper as a **recurring, non-boss,
ambient hunter** — first a rumour, then an unnoticed silhouette in the brush (Issue 3 p13, *"the most
useful panel in the comic for a game designer"*), then a fragment, before he is ever seen whole.

**And the transition device:** Michael physically opening the journal at his bunk to cut to WW1 — proposed
as a **diegetic, walk-away-able** zone transition on the existing `sleep_station.gd` / ADR-039 machinery,
and checked against ADR-020's leave-test.

> **THIS IS WHERE WW1 COMES FROM.** His *"and we go to ww1 etc"* is not an abstract franchise ambition —
> **WW1 is already inside the comic, reached through the grandfather's journal.**

### The storytelling-canon problem

- **ADR-024 does not exist as a file.** It is a row in `GAME_GUIDE.md:535` ("Cinematic direction …
  *(DRAFT)*") and nothing else. **A standing gap in the ADR folder**, found in passing.
- Standing law is **against cutscenes**: ADR-020 (*"The player is a WITNESS, never a puppet"*) and
  ADR-041 / the Do Lung Bridge model — *"a PLACE that says everything, not a cutscene."*
- **Nothing in canon establishes a rule for a comic-panel interstitial.** That idea exists only inside the
  Conquest of Worms documents' own "PANEL-ONLY" category, which warns those beats *"will be worse in any
  other medium."* Unreconciled with ADR-020/041. This is an open question, not a settled one.

---

## 6 · THE FRANCHISE — ALREADY DECREED, 2026-07-30

His *"and we go to ww1 etc"* **confirms standing canon rather than opening a new question.**

- External franchise brand: **"Tour of Hell"**, era-tagged per title — ***Tour of Hell: Vietnam* first,
  with Korea and WWI as named future titles.** Internal project name stays **RECON**.
- The decree's own reasoning: the umbrella structure *"matches how TerrainEngine is already built
  (swappable real-world elevation data + presets per region)"*.
- "Hell of Duty" was rejected unanimously (tonal mismatch with the pillars + trademark exposure
  compounding across every era-tagged title).

---

## 7 · COMPETITOR RESEARCH

### EASY RED 2 — the named competitor
8-person Italian studio (Corvostudio), ~$8.99, **91% positive of 6,686 Steam reviews**, peak ~12k
concurrent. 100+ missions, 6 campaigns, full map/mission editor and modding SDK.

- **Loop:** phase-based capture points; Operations (attacker ticket pool) or Push the Frontline.
- **The world genuinely runs without the player:** each AI squad understands and pushes objectives on its
  own logic; the player can **freely switch which AI squadmate he is playing** mid-battle. There is no
  force-wide commander.
- **No story, no protagonist, no narrative framing** — reviewers state this plainly: *"the game doesn't
  have a story, nor any specific protagonist or introduction to any of its missions."* "Campaigns" are
  historically ordered unlock chains, not arcs.
- **Progression is near-zero:** mission unlock order plus collectible dog tags (cosmetic loadouts).
- **Complaints:** *"only one game mode, played on repetitive maps that feel too similar"*; thin
  multiplayer population; pacing called "sluggish" by some.
- **The player is NEVER solo** — always dropped into a fully-manned institutional army of interchangeable,
  fungible bodies. **Soldiers have no identity, so the game structurally cannot deliver relationship
  stakes.**

> **Caution, honestly reported:** the research could **not** verify the specific complaint "it feels
> empty." The attested complaints are repetitive maps/modes and a thin MP population. **Do not cite
> "players say Easy Red 2 feels empty" — it is unproven.**

### BROTHERS IN ARMS — what he actually named
- **Command interface:** PC is a **context-sensitive single mouse click** — cursor on an enemy position =
  suppress it; cursor on ground = maneuver there. **The same verb changes meaning by what is under it.**
  Console held a trigger to raise a command ring (and in *Hell's Highway* pulled the camera back).
- Baker plus **two fire teams**, ordered independently; verbs reduced deliberately so tactics stay legible
  under fire.
- **Four Fs — Find, Fix, Flank, Finish.** The suppression readout: a **red ring** over a spotted enemy
  squad that **fades to transparent grey as you suppress them.** Grey = safe to flank. **Removed entirely
  on the hardest difficulty**, forcing the player to read behaviour instead.
- **Reception, and this is the warning:** critics called the command layer *"one of the most accessible
  and successful implementations"* of squad tactics — and called the **shooting itself "somewhat weak"**,
  undermined by dumb AI and stale tactics once the Four Fs novelty wore off.
  > **BiA's command layer was the innovation and its gunplay was the weakness. RECONgame's Pillar 1 IS
  > the gunplay. Importing BiA's structure into a game whose whole draw is the shooting is importing the
  > half BiA was praised for onto the half BiA was criticised for — which may be exactly right, or may
  > drown the thing that is already good.**
- **Casualties were checkpoint-reversible**; only scripted story deaths were permanent. **Narrative weight
  without mechanical permadeath.** RECONgame has real permadeath — so an "attack" order that spends men
  costs vastly more here than it did there.
- **Situational Awareness View:** a pause-and-zoom overhead showing only contacts already made — diegetically
  justified (a paratrooper's own map study), fog-of-war respected, and **not** reported as immersion-breaking.

### EARNING COMPANIONS — the pattern library
- **MGSV** is the cleanest model: a specific unlock moment, then a **Bond** that unlocks real new abilities
  per buddy, each with a distinct tactical identity (mark/recon vs direct action vs mobility).
- **Bannerlord** is the failure mode: browse a filtered list, pay 1,400–3,000 denars. *Procedural finding,
  transactional bond.*
- **Far Cry 2** buddies felt alive (they show up to save you from bleedout) but **added friction without
  capability** — the fiction and the mechanics fought.
- **STALKER: a full companion-hiring system was BUILT AND CUT.** The iconic "alone in the Zone" feeling may
  be as much cut content as deliberate design. **A cautionary data point for anyone citing STALKER as
  proof that solo is the better game.**

**What makes earning a companion feel good:** (1) a specific unlock moment tied to player action, not a
list; (2) visible mechanical growth from investment; (3) a distinct role identity worth earning; (4)
reactive behaviour that sells the relationship. **Failure modes:** designed-then-cut; transactional
recruitment; a companion who adds friction without capability.
