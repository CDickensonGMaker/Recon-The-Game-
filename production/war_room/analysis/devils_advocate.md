# DEVIL'S ADVOCATE — the replacement economy
**Matter:** "On patrol everyone but 2 other guys died. How does the player get more units back?"
**Date:** 2026-08-28. Every claim below carries a `file:line` or names the probe. Where I have none, I say so.

---

## 0. THE FINDING THAT SHOULD END THE SESSION

**Nobody has checked whether the mechanic under debate is reachable in the product that ships.**

Two pointers, and they are fatal to the framing:

1. `SquadRoster.ensure_roster()` is called from exactly **two** places repo-wide:
   `scripts/squad/squad_system.gd:70` (once, inside `setup()`, at squad spawn) and
   `scripts/ui/screens/barracks.gd:50` (a menu refresh). **It does not run during a mission.**
   When Caleb's men died on patrol, nothing regenerated anybody. He finished that day with two men
   because the squad is built once at `setup()` and never rebuilt. The "free instant reset" the
   council was convened to replace **did not fire in the run that prompted the question.**

2. The shipping EA product is `demo_game.tscn`, and it opens with
   `CampaignState.reset_campaign()` behind `EXCLUDE_SAVES := true` (`scripts/levels/demo_game.gd:25,
   100-108`). Every demo run starts with a **virgin campaign** — roster `[]`, `missions_played` 0,
   `kia_total` 0 — written to `user://campaign_demo.cfg` and wiped on the next boot (`:108`,
   `_wipe_demo_sandbox`). The arc is **one day**, ending on the gunships (`:70-78`, `END_BACKSTOP_S`).

**Therefore: in the thing shipping 2026-09-06 there is no "between excursions".** There is one
excursion. A replacement economy — cost, wait, trickle, battalion pipeline, all of it — would be
built with **zero live consumers in the shipping build**. That is not a feature. Under ADR-023 that
is a **fossil authored on purpose**: code that reads as load-bearing, that no shipping path executes,
that the next agent will find and assume is live. This project has a written law against exactly
this, and the law was written because five such systems were found in one session.

If the council wants to proceed anyway, it must first answer, out loud: *which build, on which date,
runs `ensure_roster` a second time with a corpse in the array?* Today the answer is "the campaign
loop, which is deferred post-launch with PLAYTEST R4" (`production/GAME_GUIDE.md:376-379`).

---

## 1. THE CASE **FOR** THE FREE RESET

I am supposed to attack the premise, so here it is: **the free reset is currently correct, and it is
correct for reasons that have nothing to do with generosity.**

**a) It is a save-file integrity device, not an economy.** Read what it actually does. Lines 170-173
drop the dead. Lines 178-185 refill the MOS slots. Lines 187-200 back-fill `skill_uses`, `xp`,
`skills`, `face`, `helmet` onto records written by older builds. `ensure_roster` is the **migration
shim** that guarantees `squad_system.setup()` gets eight well-formed dicts with a POINTMAN, an RTO
and a MEDIC in them. Replace the "free rookies" line with an economy and you have also replaced the
thing that stops a 3-man save from spawning a squad with no radio and no medic. Whatever ships must
keep that guarantee, or `member_by_mos("RTO")` starts returning null in paths that do not all
null-check.

**b) The punishment for losing men ALREADY EXISTS, and it is severe.** Nobody in this council has
priced what the current game already charges:
- Lose the **RTO** → `_grant_fire_support` reads `member_by_mos("RTO")` for the `fo_fac` level
  (`scripts/missions/field_director.gd:1448-1450`) and ADR-011 gates every fire-support verb on him.
  The mitigation is the radio handoff (`squad_system.gd:774-786`) — which costs you *another man's
  MOS*: the man who takes it stops being a rifleman/grenadier and becomes the RTO. You do not lose
  the radio; you lose a gun to keep it.
- Lose the **MEDIC** → no revive chain, no `MedicalCrate.drop` resupply (`squad_system.gd:741-748`).
- Lose the **POINTMAN** → the trap/ambush warning verb goes with him (`GAME_GUIDE.md:172-173`).
- And the men are lost **for the remainder of the day**, because of §0.1.

A day where five men die is already a day with no air, no medic, no point warnings and three guns.
**Adding a replacement cost taxes the same loss twice.** The council is about to design a punishment
for an event that is already the harshest thing in the game, and to do it without measuring the
existing penalty first.

**c) The AI cannot yet be blamed for the deaths.** `production/PLAYTEST_FINDINGS_2026-08-28.md`,
his own run of 8/27, open items: NPCs fall through the ground (#4), NPC squads spawn on the hooch
**roof** (#6), the squad **does not crouch when you crouch and stands on top of you** (#28),
squadmate muzzle flashes are detached from the muzzle (#29), the squad **opened fire inside the wire
with no enemy** (#8), there is **no friendly-fire warning** (#33), and the squad cannot path into the
hooches (#22). Item #28 is the one that matters here: a squadmate who stands on the player during a
firefight is a squadmate standing in the player's line of fire, in a game with 27-damage rifles and a
**×2.5 torso multiplier and a bypass-fatal head zone** (CLAUDE.md, ADR-016 Amendment D).

**A replacement cost is a bill for deaths the player did not cause.** Until #28, #8 and #33 are
closed, the honest description of the proposed feature is: *charge the player for the AI's bugs.*

**d) The demo is a 30-minute first impression with no second day.** A punitive economy has literally
nowhere to be felt inside 30 minutes; all it can do is make the last 10 minutes of a bad run worse
right before the siege, which is the beat the whole demo exists to sell. `SIEGE_STRENGTH` 45 men
against a firebase — arriving at that with 3 grunts because the economy would not give you men back
is not "consequence", it is the demo failing to show the thing it was built to show.

---

## 2. THE DEATH SPIRAL — where the line is, in numbers

State the mechanic honestly and it collapses on its own arithmetic.

Let **L** = expected men lost per excursion, **R** = replacements delivered per excursion,
**N** = 8 (`SquadRoster.SQUAD_SIZE:67`, locked in step with `SquadSystem.SQUAD_SIZE:23`).

Roster level is a queue: `N(t+1) = min(8, N(t) − L + R)`.

- **R ≥ L ⇒ no economy exists.** The roster returns to 8; the trickle is theatre. This is the free
  reset with extra steps and a fresh save-migration risk. It is also the only setting that is safe
  today.
- **R < L ⇒ the spiral is not a risk, it is the definition.** Every excursion strictly reduces the
  roster until L falls to meet R — and L does not fall as the squad shrinks, it **rises**, because
  fewer guns means longer engagements, and because the first three specialists lost (RTO/MEDIC/POINT)
  each remove a survival verb. The feedback loop has **positive gain**. There is no equilibrium
  above zero except the floor you hand-code.

Put his own run in it. He came home with **2 of 8**: L = 6.
- R = 1/day → **6 days** at reduced strength; at ~30 real minutes/day that is **3 hours of play
  before the squad is whole**, the first ~2 hours of it below the 5-man MOS set.
- R = 2/day → 3 days, ~90 minutes.
- R = "full refill" → today's behaviour.

**The line, stated so it can be ruled on:** any R below L is a spiral, and the only thing that stops
a spiral is a **floor**, not a rate. So the real question is not "how fast do FNGs arrive" — it is
**"what is the smallest squad the game will ever hand you?"** Answer that and the rate becomes a
cosmetic detail. If the floor is 5 (the MOS set), the economy can never actually hurt, and you have
just built a trickle animation. If the floor is below 5, you have a 30-minute-day product that can
put a player into the 45-man siege without a medic or a radio, permanently, with no way back.

**Pillar 5 says fail forward, never reload-and-memorize.** `iron_man` is a *flag*, defaulting false
(`scripts/autoload/campaign_state.gd:33`, `:352-353`) — the ordinary player **can** reload. A
replacement cost is precisely the pressure that teaches him to. And note the shape of the lesson: he
will not reload because he was outplayed, he will reload because a squadmate stood on top of him
(#28) or opened fire at nothing (#8). **We would be teaching save-scumming as the correct response to
our own defect list.** That is a Pillar 5 violation with a witness.

---

## 3. "MAKE IT HURT" — what does the player DO while he waits?

Name the downtime activities the firebase offers, then check each against his 8/27 run:

| Downtime activity | State on 2026-08-27 |
|---|---|
| Enter a bunker | **Cannot enter ANY bunker** (#3) |
| Visit the aid station and see your wounded | **See-through tent, everyone T-posed, no wounded present** (#26) |
| Mess hall | **No mess hall animations play** (#27) |
| Watch the garrison work | Work points drop silently on a bare `continue` (Q1/24, `working_point_resolver.gd:20-28`); men sit where there is nothing to sit on |
| Man the guns | **Nobody ever manned the artillery gun**; floating shells (#16) |
| Look around the hooches | **Every hooch has the identical interior**; chairs face away from tables; radio lies wrong (#19-21) |
| HQ | **Unbuilt** (#11) |

**There is nothing to do.** So the honest name for the proposal is: *stand in a broken firebase and
watch a number go down.* A wait timer is not a design; a wait timer pointed at content that does not
work yet is a **guided tour of the bug list**. We would be using the replacement economy to force the
player to look at items #3, #11, #16, #19, #20, #21, #26 and #27 for as long as the timer lasts.

If a cost ships, it must be **paid in something the player does**, not in something he waits through
— and every candidate ("run a supply mission", "escort the FNG convoy") is #35, the convoy Caleb
himself flagged as *"big; not launch scope unless you say so."*

---

## 4. THE RPG ANGLE — you are solving the wrong variable

Pillar 4: **the squad is the RPG.** Now measure how much RPG a man can actually accumulate before he
dies, using the shipping build's own numbers:

- A nickname requires **3 missions** (`squad_roster.gd:75` `NICK_MISSIONS`).
- Rank requires 1 / 2 / 4 / 8 / 12 / 16 missions (`squad_roster.gd:210-225`).
- Skill levels come from `credit_use` against `SkillCatalog.uses_for_level` (`:143-161`).
- The demo runs **one day**, and wipes the campaign at boot (`demo_game.gd:100-108`).

**In the shipping product, `missions` is 0 for every man, forever.** No nickname is ever earned. No
man is ever above PVT. The entire veterancy ladder — the thing that is supposed to make you care who
died — is **unreachable in EA**. The GAME_GUIDE already says it: "a free rookie must be visibly,
audibly worse" is listed as **the debt ADR-018 exists to pay**, not as built (`GAME_GUIDE.md:181-183,
191-195`).

So: if men die often and are replaced by strangers, the player never bonds — **but he does not bond
today either**, and no replacement economy fixes that. Bonding is bought with *time survived*, and
the two levers on time survived are (a) how lethal the world is to allies and (b) whether the squad
AI keeps itself alive. **Neither is a replacement-rate problem.**

The proposal has misdiagnosed the variable. The player lost six men in one day. The interesting
question is not "how does he get them back", it is **"why did six men die?"** — and the candidate
answers in his own findings are: they stood on him (#28), they fired at nothing (#8), they could not
crouch (#28), they could not path into cover indoors (#22), and he had no friendly-fire warning (#33).
**Ally lethality is the disease. Replacement rate is the symptom he happened to notice.**

There is a second, uglier RPG risk nobody has named: a scarcity economy makes losing a *veteran*
catastrophic, which makes the correct play **leaving your veterans at home** — or, in a game with no
bench, playing so conservatively that Pillar 3 (freedom) dies. Scarcity does not produce attachment.
It produces hoarding.

---

## 5. PRECONDITIONS — what MUST be true before any replacement COST ships

Non-negotiable, in order. Each is a pointer, not an opinion.

1. **A second excursion must exist in the shipping build.** Today it does not (`demo_game.gd:25,
   100-108`; campaign loop deferred, `GAME_GUIDE.md:376-379`). Until then the economy is unreachable
   code and ADR-023 forbids it.
2. **The squad must not kill itself or the player.** Close #8 (fires at nothing), #28 (stands on the
   player, will not crouch), #33 (no FF warning). A death economy is only legitimate when deaths are
   attributable to the player.
3. **Men must stop dying to geometry.** #4 (falls through ground), #6 (spawns on roofs), #22 (cannot
   path into hooches). A man who falls through the world is not a casualty, he is a crash report.
4. **Loss must already be legible before it is priced.** The KIA toast exists (`squad_system.gd:
   758-760`); **arrival is silent** and the dead are **deleted** from view by the living-only filter
   (`squad_roster.gd:170-173`), so the barracks cannot show a memorial. Price nothing the player
   cannot yet read.
5. **A hard floor must be ruled by the Summoner**, in men, with the MOS set named. Per §2 the floor
   *is* the economy; the rate is decoration.
6. **`ensure_roster`'s migration duties must survive.** Whatever replaces it still back-fills
   `skill_uses` / `xp` / `skills` / `face` / `helmet` (`:187-200`) and still guarantees the MOS set,
   or old saves spawn squads with no radio.
7. **The body-swap pool must be reconciled.** `demo_game.gd` installs a body swap on player death
   (`_install_body_swap`, `:186`); the roster is therefore also the player's supply of lives. Any
   scarcity rule silently shortens the demo run. Nobody has priced this interaction.

**If precondition 1 is not met, nothing else on the list matters.**

---

## 6. THE CHEAPEST CORRECT FIX — if exactly one thing ships

**Ship the LEDGER, not the ECONOMY.** Zero cost, zero wait, zero rate. Keep the refill exactly as it
is, and make the game *say what happened*:

- At the wire / on the roster screen, name the dead — rank, name, earned nick, kills — and name the
  men who arrived to replace them, by name and MOS.
- Nothing changes numerically. Nobody waits. Nothing spirals.

Why this is the right single move:
- It answers **Caleb's literal question**. He asked "how does the player get more units back" — that
  is a man reporting that **the game never told him**. It is the same defect class as his Q2 ("a
  sweep only banks when you re-enter the wire; the game never said you did the mission",
  `field_director.gd:1821`). He is not asking for a tax. He is asking for **information**.
- It is the precondition for every economy anyone might later want (precondition 4), so it is not
  throwaway work under any future ruling.
- It costs **zero art-days** — the binding budget (`GAME_GUIDE.md:384-386`).
- It cannot make the 30-minute demo unwinnable, cannot teach save-scumming, and cannot interact with
  the body-swap pool.

**The sacrifice, named — and I will not pretend there isn't one:** shipping only the ledger means
**loss stays costless at the campaign layer**, and the GAME_GUIDE's own indictment ("Loss is still
costless (instant free rookies) — the debt ADR-018's silent veterancy exists to pay",
`GAME_GUIDE.md:194-195`) stands unpaid for another release. A player who watches six men die, reads
six names, and walks out next dawn with six new ones has been *informed* of a consequence he did not
*suffer*. That is a real hole in Pillar 4, and I am recommending we leave it open on purpose, because
the alternative is paying that debt with a currency (attrition pressure) the current AI is not
competent to charge fairly.

**Second sacrifice:** a named-arrival ledger makes the strangers *more* visible. Reading "PVT MERCER
— REPLACING SGT KOWALSKI" every dawn will make the treadmill legible rather than hiding it. That is
the correct trade — a visible problem gets fixed, an invisible one does not — but it is a trade, and
the council should not be told it is free.

---

## 7. WHAT I WOULD ACTUALLY PUT TO THE SUMMONER

Two questions, glossed, no file needed to answer:

1. **"When your squad gets wiped down to two men, what is the smallest squad the game is ever allowed
   to hand you the next morning?"** (This is the floor. It is the whole design; everything else is
   pacing.)
2. **"Do you want to be charged for men the AI got killed — or do you want to know their names
   first?"** (Ledger now, economy after the AI is trustworthy — versus economy now.)

And one statement he needs to hear before he answers either: **in the demo that ships on 9/6 there is
no next morning.** Whatever is decided here is a decision about the post-launch campaign loop, not
about the run he played on 8/27.
