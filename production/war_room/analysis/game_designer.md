# GAME DESIGNER — independent analysis
**Query (Summoner, 2026-08-28):** *"On patrol everyone but 2 other guys died. How does the player get more units back?"*
**Written:** 2026-08-28 · no cross-talk · code read, not the plan.

---

## 1 · What the question actually exposes

He did not ask "how do I get men back." He asked because **the game already gave them back and he
did not notice.** `SquadRoster.ensure_roster()` (`scripts/squad/squad_roster.gd:165-201`) drops every
dead man, back-fills every empty MOS slot with a freshly rolled member, tops the list to
`SQUAD_SIZE = 8`, saves, and returns — instantly, silently, free. It is called on squad spawn
(`scripts/squad/squad_system.gd:70`) and again every time the barracks screen refreshes
(`scripts/ui/screens/barracks.gd:50`). The player walks back through the wire with two men and walks
out again with eight, and **nothing anywhere tells him six men died.**

That is the whole defect, and it is a *design* defect before it is a systems one. Three things are
wrong at once, and they are separable:

| # | Defect | Pillar violated |
|---|---|---|
| 1 | **No notification.** Six deaths produce no name, no line, no board entry. | 4 · The r4bk Law (a feature with no affordance does not exist) |
| 2 | **No cost.** The replacement is instant, free, and full-strength-shaped. | 4 · ADR-018 §2 ("*a free rookie must be visibly, audibly, painfully worse*") |
| 3 | **No difference.** The rookie rolls the SAME `_roll_starting_skills` (`:127-146`) a veteran rolled — MOS skill L1–3, 0–2 extras. He is not green. He is a stranger with the dead man's job and the dead man's competence. | 4 · ADR-018 §2 |

Defect 1 is the one he felt. Defects 2 and 3 are why fixing 1 alone would make it *worse* — a
toast that says "SIX MEN KIA" followed by a full squad next morning is the game telling the player
his loss was administrative.

**The standing law is already written in this repo and points the other way.** Doc's bag of 6
bandages and the gunner's 8 belts do not self-refill because "*running it dry is meant to be one of
the reasons you go home*" (Summoner 2026-07-30, `squad_system.gd:7-13`). **Bandages are scarce and
men are free.** That inversion is indefensible under Pillar 4 and it is the thing to correct.

**The dead are already banked.** `CampaignState.on_mission_end` (`campaign_state.gd:260-279`) reads
`result.squad_kia` into `kia_total`, `bags_unlifted` and derives `ward_wounded`. The ledger knows.
Nothing shows the player what the ledger knows, and `ensure_roster` erases the hole before he can
see it. **The data is there; the presentation and the price are missing.**

**And the delivery machine is already built.** `HeliLift` (`scripts/vehicles/heli_lift.gd`) already
lands 3–6 men (`PAX_MIN`/`PAX_MAX`, `:26-27`) at the firebase when the garrison is under
`ESTABLISHMENT = 28`, with per-man disembark clips, deterministic bunks, work-point claims and a
stand-to hand-off (`_deliver()`, `:277-345`). Its own header states the intent verbatim: *"men die,
the base drops below strength, and the next ship brings their replacements."* **The replacement bird
exists and flies today. It just does not feed the player's squad.** Any option that ignores this is
building a second system next to a working one (ADR-023).

---

## 2 · The real thing (grounding, per the brief)

A rifle company got replacements as **individual FNGs trickling in from battalion over days**, by
whatever bird or truck was going that way — never as a squad reset. Requisitions went up through
the first sergeant; what came back was whatever battalion had, when it had it. A short squad **went
out short**, and going out short was normal and hated. The FNG was a liability: green, no bush
skills, loud, the man nobody wanted walking near them, and the man most likely to be killed in his
first three weeks. Veterans did not learn his name for a while — that is where "FNG" comes from, and
it is the exact emotional beat Pillar 4 wants.

Three design truths fall out, and all three are mechanics:
1. **Replacement is a trickle, not a refill.** Ones and twos, on a clock the player does not own.
2. **Short is legal.** The patrol goes out at 5 of 8 and that is the punishment — not a lockout.
3. **The FNG is worse, and the squad says so.** Both must be true or neither lands.

---

## 3 · Common floor — binding on every option below

The brief's minimum ("*every option must TELL the player who died and who arrived*") is not a
feature of one option. It is the floor, and it costs almost nothing because every surface exists.

**F1 · THE BUTCHER'S BILL AT THE WIRE (AAR).** `_bank_patrol()`
(`field_director.gd:1821-1852`) already toasts `"BACK INSIDE THE WIRE - PATROL %d LOGGED, %d KILLS"`.
It gets the line that matters first, one man per line, **rank + name + role**, from
`result.squad_kia`:

```
KIA THIS PATROL - 6
  SGT  LUTHER HAYES     POINT MAN         9 patrols
  SP4  ROCCO SANTORO    MACHINE GUNNER    4 patrols
  PFC  EAMON DOYLE      RIFLEMAN          first patrol
  ...
SQUAD STRENGTH 2 OF 8
```

Patrols survived is the epitaph. `rank_for()` and `mos_display()` already exist (`:205-224`).
**Kills stay information, never income (ADR-006) — so do deaths. This line prices nothing; it
reports.**

**F2 · THE ROSTER BOARD REMEMBERS (barracks).** `barracks.gd:_refresh` gets a header block above
the living: **STRENGTH 2/8 · KIA THIS TOUR n · IN THE WARD n · BAGS ON THE PAD n** — all four
already live in `CampaignState` (`:56-62`) and none is displayed anywhere today. Under the living
rows, a short **RECENT DEAD** list, struck through, that ages off after ~5 patrols. The board is
the memorial; the game has no other one.

**F3 · ARRIVALS ARE ANNOUNCED, BY NAME, ON THE NET.** A man joining the squad produces a radio
line and a board row flagged **NEW**. Never a silent list-length change.

**F4 · `ensure_roster()` STOPS TOPPING UP.** It keeps its migration job (`:184-198` — the
`skill_uses`/`face`/`helmet` back-fill is load-bearing for old saves) and **loses the fill loops**
(`:177-183`). Strength becomes a *state the player can see and be short in*. Without F4 every
option below is cosmetic, because the roster refills the instant the barracks screen is opened.
**This is the one line of the floor that is a real ruling and not a UI job.**

---

## 4 · OPTION A — THE REPLACEMENT BIRD (recommended)

**The mechanic.** Battalion sends men on the resupply ship, not to your squad. When squad strength
drops below 8, the vacancy is posted; the **next Huey that lands at the pad carries 1–3 FNGs** on
top of its garrison delivery, and they walk off it into the firebase as bodies you can see standing
around the pad. They are **not in your squad**. To fill a slot you walk to the **roster board in the
barracks** and take a man — a named FNG, his MOS stamped from what battalion had, his seasoning
reading **GREEN**. Take him or leave him; an untaken FNG stays in the firebase as garrison. The bird
comes on the existing logistics cadence (garrison-need driven, `heli_lift.gd:151 _choose_mission`),
so **a fully rebuilt squad is 3–4 birds away, not one**. Concretely: lose 6, get ~2 back before the
next walk-out, full strength ~3 in-game days later.

**What it costs the player.** Time and strength. He patrols at 3, then 5, then 6 of 8 — and the
slots that stay empty are the ones battalion had nobody for. **Losing the wrong man costs more than
losing a man**: no MEDIC on the roster means no revive chain and no bandage bag; no RTO means no
fire support and no net at all (ADR-011), which is the single most expensive loss in the game. He
can go out anyway. He will not want to.

**How it is surfaced.** All three period channels, no markers: **radio** — "*Six-Actual, Bravo,
your replacements are on the log bird, ETA next lift*" and, on touchdown, "*Two new men on the pad,
report to the board*". **Roster board** — the F2 header, the empty slots drawn as empty
(`RTO — VACANT`), and the FNG pool sitting under **AVAILABLE — BATTALION REPLACEMENTS**. **AAR** —
the butcher's bill at the wire, and the strength line that tells him what he is walking out with.

**Pillar 4.** This is the option that makes the squad an RPG instead of a party. The man arrives
as a **body in the world you saw get off a helicopter** — that is what turns a roster row into a
person, and `_deliver()` already animates it. The squad is now something you *maintain*, and the
first sergeant's arithmetic (bandages, belts, bodies) becomes one economy instead of two.

**Pillar 5.** Perfect fit. Losing six men is never a fail-state and never a reload: the campaign
continues short, the next patrol is genuinely harder because you are three men, and **the recovery
is the story**. Nothing reverts, nothing is retried, and reloading to save a veteran is a HARD-save
decision (`save_manager.gd:87-94`), not a habit.

**THE TRADEOFF, NAMED.** *You can be stuck.* A player who loses his Medic and his RTO on the same
patrol has a stretch of game — possibly two or three patrols — that is measurably worse, through no
new choice of his own. That is the price of Pillar 4 having teeth, and it is the thing that will
generate the first "this game is unfair" review. It must be **bounded**: a floor of **4 men** (the
bird always fills to 4 before it fills to 8, and a squad at 3 gets the next bird guaranteed), and
**never a rank/mission gate** — he is never told he may not walk out the wire (Pillar 3, ADR-018's
soft-rail line). Second sacrifice: it is the most build. It needs the pool, the board interaction,
the vacancy posting and the FNG differentiation. Third: **it does not fit the demo**, which is one
day and one firebase — see §7.

---

## 5 · OPTION B — THE TRICKLE (the cheap honest one)

**The mechanic.** No pool, no walking, no board interaction. Replacements arrive **on a clock, one
at a time**: after each patrol, if the squad is short, roll one FNG in with probability scaled by
how short you are — **≤3 men: guaranteed 1 · 4–6 men: ~50% · 7 men: ~25%** — capped at **one man
per patrol, ever**. Lose six and it takes six patrols to be whole. The men arrive between
excursions with a radio line and a board row, and they arrive **GREEN**: MOS skill **L0–1 with no
aptitude bonus and zero extra skills** (bypass `_roll_starting_skills`, `:127-146`), which already
prints as **"GREEN"** on the barracks board (`barracks.gd:_seasoning`, `:88-99`) with no new UI at
all.

**What it costs the player.** Patrols. The refill is measured in excursions, not seconds, and every
one of those excursions is walked short. Cheaper emotionally than A because he never *chooses*, but
the arithmetic is the same shape: six dead is six patrols of being under strength.

**How it is surfaced.** **AAR** — the butcher's bill, then at the next walk-out `"REPLACEMENT:
PVT DECLAN ODELL, RIFLEMAN - GREEN"`. **Radio** — one line from the net when he crosses out the
wire with a new man behind him, and a point-man bark that names him as new. **Board** — F2 header,
NEW flag, GREEN seasoning.

**Pillar 4.** Serves it, at a discount. The loss is legible, the recovery is slow, and the green
man is worse. What it does not buy is the *body on the pad* — the FNG is a name that appears in a
list, which is exactly the register the current system fails in, only slower and labelled.

**Pillar 5.** Same as A, and slightly safer: the trickle is automatic, so there is no state in
which the player is short because he forgot to do something. Nothing to miss, nothing to reload for.

**THE TRADEOFF, NAMED.** *No agency.* The player never makes a decision about his own squad — men
appear because a timer said so. It fixes the cost and the notification and leaves the **squad
economy hollow**: nothing to trade, nothing to weigh, no first-sergeant fantasy. It is a good floor
and a poor ceiling, and the risk is that it ships and the better version never does. Second
sacrifice: an FNG who arrives as a list entry is easier to *not care about*, which cuts both ways —
he is meant to be resented, not ignored.

---

## 6 · OPTION C — CANNIBALIZE THE WIRE (the choice with teeth)

**The mechanic.** Layered on A or B, never alone. The firebase has a **garrison of 28**
(`heli_lift.gd:ESTABLISHMENT`) standing on the wire tonight. When your squad is short, you may
**pull a garrison man into it** at the roster board — immediately, no waiting. He is a real soldier,
not an FNG: he has been in-country, he reads **STEADY** rather than GREEN, and he is available right
now. **The wire is one man thinner for the night, and it stays thinner** — the garrison only refills
from the same bird your replacements ride. Take 4 men off the wire before a probe and the night
assault has 4 fewer rifles on it. Existing law already reads this: garrison men are soldiers
(memory: `recon-garrison-soldiers-decree`), and `_deliver()` already fills the garrison toward
establishment and never past it, so the accounting is one number in one place.

**What it costs the player.** A direct, immediate, legible trade: **strength on patrol vs. strength
on the wire.** It is also the only option where the player can hurt himself in a way he will
remember, which is what makes it worth building. Doubling the price: garrison men are **the wrong
MOS**. Pulling a rifleman off the wire never gives you a Medic or an RTO — those still only come
from battalion. So cannibalizing fills the *bodies*, never the *verbs*.

**How it is surfaced.** **Board** — `TAKE FROM GARRISON (28 ON THE WIRE)`, and the number visibly
drops when he does it. **Radio** — the topkick pushing back on the net: "*Six, you're taking men
off my perimeter. Noted.*" **AAR** — the wire strength printed next to squad strength, so the two
numbers always sit side by side and he learns they are one pool.

**Pillar 4.** Strong. The squad stops being a party you refill and becomes **an allocation you make
out of a finite firebase**. That is the RPG, in period, with no stat screen.

**Pillar 5.** The strongest of the three. A bad patrol propagates into a bad night — the loss
*mutates* into the next situation instead of resetting. That is fail-forward stated exactly.

**THE TRADEOFF, NAMED.** *It can be gamed into a free refill, and it can quietly break the siege.*
If the garrison is deep and the wire's thinness is not felt, "take from garrison" is just a button
that undoes death — worse than today, because it looks like a system. It only works if the wire
being thin is **visibly and mechanically real**, which means the siege must read garrison strength
(`SIEGE_STRENGTH` 45 attackers against a defence that now varies), and that is a balance surface
nobody has measured. Second sacrifice: it is a **decision with a right answer** in the demo (there
is exactly one night and it is the climax), which makes it a trap rather than a choice unless the
player is told the assault is coming — and telling him is a rail. **My judgement: C is the right
campaign system and the wrong demo system.**

---

## 7 · Scope split (the honest recommendation)

**Early Access ships the demo's shape** — one firebase, one day, ~30 minutes
(`GAME_GUIDE.md` §8). There are no "days" to trickle across and one bird cycle to spend. So:

- **DEMO / EA (build now, hours not days):** the **common floor, F1–F4**. The butcher's bill at the
  wire, the strength line, the roster board header, the KIA list, **and `ensure_roster` stops
  topping up**. Plus **one** replacement channel scoped to the day: the log bird brings **1–2
  green men once** if the squad is under strength before dusk. That is enough to make the day's
  losses real, and it is honest about what the demo is. **Six dead in the demo means you stand-to
  that night with three men and the FNG, and the siege is the harder for it — which is the best
  version of the demo's ending anyone has proposed.**
- **CAMPAIGN / post-launch:** **Option A** as the spine, **Option C** layered on it once the siege
  reads garrison strength. **Option B is A's fallback** if the pool-and-board interaction is judged
  too much build — it delivers the same law with none of the fantasy.

**What I would not do, under any option:** cap the squad's *rebuild* behind rank, gate a walk-out
on minimum strength, or fail the campaign on a squad wipe. All three are rails (Pillar 3) and the
last one is a reload prompt (Pillar 5).

---

## 8 · Verdict (short, for the Arbiter)

The bug is not that replacements are missing — it is that **they are free, instant, silent, and
just as good as the men who died**, in a game whose own code refuses to refill a bandage bag. Fix
the floor first (name the dead at the wire and on the board, and **make `ensure_roster` stop
back-filling**), then make the FNG green and make him arrive on the bird that is already flying.
**Recommend the common floor + Option A, with Option C as the campaign layer and Option B as A's
cheap fallback.** The named sacrifice is that the player can be genuinely short of the men his
squad needs for two or three patrols, with no way to buy his way out — and that is Pillar 4 finally
costing something.
