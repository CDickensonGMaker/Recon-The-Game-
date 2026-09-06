# THE DECREE — War Room 2026-09-06 · THE RPG PIVOT

**Arbiter:** the Overseer/Director · **Council:** game designer + writer · systems designer · technical
director · devil's advocate (four analyses in `analysis/`) · **Briefing:** `briefing.md`

---

## 0 · THE SENTENCE THIS SYNTHESIS MUST OPEN WITH

**Today, 2026-09-06, was the Early Access target date. It passed with the §8.0 session entry gate
undischarged** — the Summoner has still not verified the demo arc end to end. That is not a failure of
the target (his own ruling of 2026-08-06: the date is a target, not a deadline). It is the fact that
must sit at the top of any record made today, because the decree below is exactly the kind of document
that can become a date's alibi.

**The decree is recorded. Zero items from the playtest list were closed today.** Both halves of that
sentence are the honest report.

---

## 1 · THE DECREE — what is now canon

The Summoner's reframe is **ACCEPTED and RECORDED**. It is not a new direction so much as a name for the
one the code already faces: ADR-017 built a persistent province, ADR-019 built a world that reacts,
ADR-029 made the firebase home and killed the mission menu. **"RPG / STALKER-in-Vietnam" is what those
three ADRs already add up to.** That is why recording it costs nothing.

| # | Item | Canon | Standing |
|---|---|---|---|
| 1-3 | The firebase is home · four camps inside the wire · the racial element as **social geography, never plot** | **ADR-038** | Accepted. **Launch ships PLACEMENT ONLY; every authored line about race is CUT from launch** (§4 below) |
| 4-5 | Hearts & Minds is senior · **the factions are its READOUT** | **ADR-038 §2 + the new §2a imprecision law** | Accepted as the law the code will be brought to. **Unbuildable today** (§3) |
| 6 | The mission score is retired | **ADR-006 Amendment B** | **RE-HOSTED, not repealed.** HQ is the faucet |
| 7 | Contraband as currency | ADR-038 / 006-B | Accepted with three guards |
| 8 | 2km map | **ADR-039 §6** | **PARKED behind a hard, fundable gate** |
| 9 | Zones, not streaming · board don't select | **ADR-039** | **PARKED.** Six enforceable clauses recorded |
| 10 | Save anywhere | **ADR-007 Amendment A** | **PARKED — the largest item in the decree** |
| 11 | Tunnels as dungeons | ADR-039 §8 | Frozen; the thaw is *named*, not granted |
| 12 | Player durability → **extend the DOWN state, not the health pool** | **ADR-040** | **PARKED.** Pillar 1 held |
| 13 | *Apocalypse Now* structure, not its story | ADR-020 governs | Roadmap only |

Recorded in `production/GAME_GUIDE.md` §6.1 so a future session cannot mistake any of it for launch scope.

---

## 2 · THE FOUR RULINGS THAT CHANGE WHAT SOMEBODY WOULD HAVE BUILT

### 2.1 · The two-quest premise is INVERTED. There is no timing problem; there is 14 minutes of dead air.

The council measured what nobody had put side by side. The compound's own half-extents are
**149.3 × 111.2 m** (`site_planner.gd:809`); the village is 185 m and the temple 170 m from centre, on
bearings **90.7° apart, not 180°**. **The quest sites sit 36-74 m outside the wire.** The full circuit is
**~850-1000 m — 170 s at walk speed, ~340-500 s cautious with two firefights — against 1184 s to dusk.**

> **"Timed so the player returns at dusk" is not a design. It is a description of the fact that there is
> nothing else to do.** He returns when he finishes, and then he waits — for **11 to 18 minutes.**

The code already knows: `field_director.gd:1454-1456` raises the hunter pool with a comment naming this
exact failure. **The map is 512 m, so the quests cannot be made FAR. They must be made SLOW.**
**That is the one design question worth the Summoner's time today, and it is put to him, not answered
for him** (§6).

### 2.2 · ONE walk-out, not two — rule it or it will be built wrong.

Two walk-outs make `_bank_patrol` fire **twice in a one-day demo whose fiction is a single patrol**:
`patrol_count` reads 2, the ledger is destroyed and recreated, the dead are read twice, replacements are
called twice. **RULING: one walk-out, both quests, one bank.** The machinery already supports it
(`_advance_route_tasking`; the comment at `field_director.gd:1222` says so outright). **The first person
to build this will build the wrong one, because two walk-outs is what "two quests" sounds like.**

### 2.3 · Retiring ADR-006 without naming the faucet would have broken FOUR things — one of them invisible.

`compute_score()` is the only faucet in the progression economy. Killing it stops rank, empties the
armory rack of six weapons, kills the `FIELD PROMOTION` toast (ADR-032's *only* visible progression
event — an r4bk violation), **and freezes campaign fire support at the PVT floor**
(`field_director.gd:1512-1518`) — a consumer the decree had not counted. **That last one is invisible in
the demo**, which hard-overrides fire support, so it would have shipped silently into the campaign.

**Ruling: HQ is the faucet**, paying ADR-029's already-ratified *"rank clock = completed patrols"*.
**And the line that stops the old disease returning: body count may move HQ's WORDS; it may never move
HQ's GRANT.**

### 2.4 · "Zero new UI" is the decree's highest-risk sentence, and ADR-019's defence had to be rewritten.

Four voices are **a meter with causal annotation**, which is a *strictly better* optimisation signal than
a number. ADR-019 §4's defence — *"a number would be optimised"* — does not survive as written.
**What protects the system is imprecision, not silence.** Hence ADR-038 §2a:

> **A faction line may name the SUBJECT. It may never name the QUANTITY, the RATE, or the DIRECTION OF
> CHANGE.**

---

## 3 · THE HONEST LIMIT — the readout cannot be built, and must not be claimed

**ADR-019's ledger does not exist in code.** `civilian.gd:718-722` records the deferral in so many
words. **There is no province value for the factions to read.** Anything shipped in the demo is four men
with canned opinions, and under the truth law **no doc, comment or store page may call it a readout.**

This is the difference between a decree and a description, and it is stated inside ADR-038 itself so the
next agent cannot miss it.

---

## 4 · THE RACIAL ELEMENT — the ruling, and why it is the smallest one available

He said he does not think he is the writer for this and does not want it done badly. **Law 3 says the
Summoner holds final authority — including over his own stated limits.** So the council took him at his
word rather than working around him:

- **SHIPS: social geography as PLACEMENT ONLY** — seating, work details, hooch groupings, who walks with
  whom, who does not look up. Level-design work. No writer, no writing days.
- **CUT FROM LAUNCH: every authored line of racial content, including the good ones.**
- **The guardrail nobody had named: the same care extends to the Vietnamese**, and the first place it
  bites is the civilian — already ADR-019's open art and behaviour gap.
- **The one test that is not a matter of taste, five minutes before ship:** list every named character
  with a speaking line and every character who is visually non-white. **If the intersection is exactly
  the set who speak about race, the representative failure has occurred.**

---

## 5 · SEQUENCING — the council's unanimous verdict

> ## **The playtest list is the real work, and it is not close.**

Read his sentence structure: *"right now to get that more real, we need to make sure the last long list
… has been fixed."* **"To get that more real" is the goal clause; the defect list is the means clause.**
He was not asking which to do. He was saying the list is how the pivot becomes real.

**It is a prerequisite of the pivot, not a competitor to it:** you cannot demonstrate that the firebase
is home while the player cannot walk into a single one of its bunkers (item 3, open).

**Order:** the P1 blockers (3, 4, 6, 8, and the new 36) → **his siege playtest, the §8.0 gate** → then
the two-quest plan.

---

## 6 · WHAT ONLY HE CAN DECIDE — put plainly, four questions

1. **The demo has 11-18 minutes of dead air after the quests are done, and the map is too small to fix
   it with distance. Which slow thing do you want?** A hold, a timed search, an escort, a dig, or waiting
   for something to happen.
2. **The gating FPS number.** The proposal has been ready since 2026-08-14: *`assault_on_wire` ≥ 20 fps
   average, ≥ 10 fps minimum, at the shipped 0.75 scale on the floor box.* **The demo passes the average
   (22.6) and misses the minimum (5), GPU-led.** Until a number is law, no performance argument in this
   decree is resolvable — including 2km.
3. **Save anywhere is six workstreams and the biggest item in the decree. Do you want the cheap version
   instead** — "save when you get back to base", which costs almost nothing and buys most of the feel?
4. **Extending the down state means LOOK + VOICE, not crawling** — crawl reverses your own 2026-08-24
   "drop down and lay in place" ruling. **Is watching and calling for Doc enough?**

---

## 7 · WHAT WAS SACRIFICED (the law binds the Arbiter too)

- **The world can never be COMPOSED.** ADR-039 clause 1 forbids hand-built outdoor geography forever —
  the price of never re-fracturing the world build. It collides with the vignette-place ambition of the
  same decree, and the reconciliation (dress procedural ground; author only interiors) is thinner than
  the ambition.
- **Four voices are designed to contradict**, so a player who wants to know how he is doing will be told
  four different things and may conclude the game is broken rather than that the war is.
- **He asked to be tougher and the answer is "no, but here are four other things."** ADR-040 is a
  promise; failing to build LOOK + VOICE turns it into a refusal.
- **2km is further away than "one constant" made it sound** — it is gated behind terrain LOD, a feature
  nobody has started.
- **The racial element ships as its smallest possible version**, which will read to some as absence.
- **A fourth reframe on the target date is a real risk**, and the mitigation is only this: it was
  recorded, not built, and §0 states the date's cost plainly.

---

## 8 · THE RECORD

**Canon written:** `ADR-038` (the firebase factions) · `ADR-039` (zones, not streaming) ·
`ADR-040` (the down state) · `ADR-006 Amendment B` (the score re-hosted) ·
`ADR-007 Amendment A` (save anywhere, priced) · `GAME_GUIDE` §6.1.

**Plans:** `production/DEMO_TWO_QUESTS_PLAN_2026-09-06.md` — priced, **not built.**

**Defect audit:** `production/PLAYTEST_FINDINGS_2026-08-28.md` — a verified status table with file:line
evidence for all 35 items, plus **new defect 36** (the lives economy is dead in daylight).

**Drift corrected on contact (NO MORE DRIFT):** the **two ADRs numbered 035**, open since 2026-07-28 and
audited twice — the route/hunters ADR is now **ADR-037**, citations repointed · ADR-017 §4's load-mask
claim marked as aspiration with a dead pointer · both save defects on the ship list confirmed **CLOSED**
and struck · the field-marking vocabulary is **four nouns, not six** · ADR-028 Amendment A's
`KNOWN_EXCEPTIONS` pointer is stale (`EXCLUDED_BENCHES`) · `terrain_manager.gd:369-370`'s hydrology
comment is false for every map from 1280m to 2700m.

**Enforcement added:** every post-demo ADR now carries a **FROZEN FILES** section naming paths, and the
`SLEEP_POST_LAUNCH`-style *parked-but-built* constant is **forbidden by name** as the leak mechanism it
has already proven to be.
