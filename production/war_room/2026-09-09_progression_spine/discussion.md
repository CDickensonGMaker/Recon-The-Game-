# THE DEBATE — THE PROGRESSION SPINE
## War Room 2026-09-09 · six lenses, no cross-talk, then this

Analyses: `analysis/game_designer.md` · `analysis/systems_designer.md` · `analysis/ux_designer.md` ·
`analysis/narrative_director.md` · `analysis/technical_director.md` · `analysis/devils_advocate.md`
Evidence: `analysis/measurements.md` (code truth, Arbiter-verified) · `analysis/evidence_pack.md` (canon + research)

---

## 1 · WHAT EVERY ARCHITECT AGREED ON, ARRIVING FROM DIFFERENT DOORS

**This is the strongest signal the process produces (repo CLAUDE.md), and it produced five of them.**

### AGREEMENT 1 — Nothing is thrown away. The pivot deletes no squad code.
Independently reached by the systems designer (§8: *"This pivot deletes no squad code. It moves the
squad from hour 0 to hour N. Anyone reading it as 'we don't need the squad systems' has misread it"*)
and by the Arbiter's own audit (`measurements.md` §1). Every squad consumer null-checks; the only
blocker is `SquadRoster.ensure_roster()` self-healing to eight (`squad_roster.gd:178-179`).
**The Summoner's first pressure point is answered: verified, nothing real is lost.**

### AGREEMENT 2 — The period-HUD collision does not exist. There is no cursor to import.
Game designer (§6: *"the period-HUD problem is already solved in code: the weapon IS the cursor"*),
UX (§2: *"`_aim_ground_point()` is already the answer to the cursor question"*) and the Arbiter's
audit all landed on the same line. `squad_system.gd:328-344` designates by one 250 m camera ray,
layer 1 only. **Brothers in Arms' command ring is not something this project would be removing; it is
something it never built.**

### AGREEMENT 3 — The real defect is THE ARRIVED-AND-IDLE MAN, and it is fatal to the verb set as specified.
Named independently by the systems designer (*"THE ARRIVED-AND-IDLE MAN"*), the UX designer, the
Devil's Advocate (Charge 9, *"fires into a null"*) and verified by the Arbiter reading the file:
`order_mode` appears at only five lines in `ally_base.gd` — `:295` (declaration), `:329` (setter),
`:1376` (RESCUE), and `:1418`/`:1420`, **both inside `_execute_idle`.** `MOVE_TO` on arrival falls to
`_settle(delta)`, byte-identical to `HOLD`.

> **A man in COMBAT, SUPPRESSED, SEEKING_COVER, ADVANCING or FLANKING silently ignores every order.
> An aggressive attack order is by definition given when men are in contact — the exact state that
> cannot hear it.** *(Devil's Advocate, Charge 9.)*

### AGREEMENT 4 — Suppression is the deepest system in the game and it has ZERO output.
UX (§1: *"this game's best system is invisible"*) and Devil's Advocate (Charge 1) converge, from
opposite intentions, on the same conclusion: **`vo_manager.gd` has no suppression line and
`mission_hud.gd` has no suppression readout.** Brothers in Arms' actual genius was the red ring
fading to grey. This project has built the simulation and none of the legibility.

### AGREEMENT 5 — Build no dialogue system. The borrowed radio is wordless.
UX (§6, ruled), systems designer (§3, *"there are none… it hangs off the interact verb plus per-element
state"*), narrative director (the carrier rule needs no conversation). **The session brief's premise —
"connect to the existing conversation systems" — was refuted on contact: the grep returns zero files.**

---

## 2 · WHERE THEY DISAGREED, AND THE TRADEOFF IN EACH

### DISPUTE A — The handheld radio (rung 4)
| Voice | Position |
|---|---|
| **Game designer** | *"the one I would fight."* Salvage it by making it a **posture, not a possession** — kneel, antenna up, rifle slung, 8-12 s. `_radio_check()` gains a second satisfier, not a bypass. |
| **Systems designer** | Agrees on the mechanism, and supplies the constitutional sentence: **"a bypass is a call path that does not call `_radio_check()`. Adding a new SOURCE that `_radio_check()` accepts is not a bypass."** Then prices it: tubes + *unadjusted* arty only, never fast movers, `fo_fac` fixed at 0, flat 25 s cooldown, rifle stowed, ruck slot, signature. |
| **Devil's Advocate** | Charge 6: the ladder's endgame is *"the removal of the game's most deliberately designed piece of friction."* ADR-011 names its own cost as a feature. |
| **Resolution** | The two designers converge on an amendment that survives the Devil's objection **only if the handheld is strictly worse in five axes and better in exactly one (leash).** The Devil's charge stands as the guard: if the handheld is ever tuned toward convenience, it eats rungs 2 and 3 and the ladder collapses. |

### DISPUTE B — Is Pillar 4 deferred, re-hosted, or switched off?
| Voice | Position |
|---|---|
| **Game designer** | **Re-hosted, conditionally.** Pillar 4's real content is attachment to other men and losing them; solo delivers that from hour one. *But* — *"if that framing is not built, Pillar 4 IS deferred by twenty hours, and I vote against the pivot."* |
| **Narrative director** | Re-hosted, and supplies the missing piece: **the ladder must have a DOWN.** Gus is the first companion and the wrong one. |
| **Devil's Advocate** | Charge 4: **switched off.** *"That is not a pivot. It is a demotion of a pillar to a late-game feature, and it should be argued as such openly."* |
| **Resolution** | The Devil is right that it must be argued openly, and the game designer supplied the condition that makes it survivable: **the opening squad must be GIVEN AND TAKEN AWAY.** Both designers independently reached the same device from different doors — the game designer from pacing (*"you spend twenty hours earning back a thing you had on your first afternoon"*), the narrative director from the source material (Maddox dies in a subordinate clause). **That convergence is the resolution.** |

### DISPUTE C — ADR-021, THE PROMOTION IS THE TUTORIAL
| Voice | Position |
|---|---|
| **Devil's Advocate** | Charge 4: ADR-021 §4 is *"the only onboarding design this project has ever ratified"* and the pivot deletes it — in a game the 9/07 audit measured as having **no onboarding at all.** Under ADR-023 it must be named for deletion, and nobody proposed that. |
| **Game designer** | **It has TWO rows and only one dies.** Row 1 (new in country → YOU FOLLOW) survives *intact* as the tutorial. Row 2 (trusted → YOU LEAD, the squad follows you) is superseded. |
| **Narrative director** | Independently: *"ADR-021's tutorial is the comic's first act… the solo stretch is act two, not act one. Nothing needs deleting."* |
| **Resolution** | **The Devil's procedural objection is upheld and his substantive one is answered.** ADR-021 is not deleted; its second row is superseded and must be named for deletion in the decree, along with its line *"if he dies before you are ready, you take over anyway"* — which has no squad left to take over. |

### DISPUTE D — Sequencing: what must ship before solo?
Three different architects named three different hard dependencies, and **none of them cancels the others**:
- **Game designer:** solo does not ship before **save-anywhere** (ADR-007 Amendment A), or Pillar 5
  becomes reload-and-memorise. And **break-contact must actually release** (45 s LOS / 90 s / 120 m) or
  one contact per patrol is a death spiral — *"the highest-risk item in the whole proposal."*
- **UX designer:** *"the solo rung must not ship until the world has a voice."* Suppression legibility
  and enemy-VO-as-contact-call before `ensure_roster()` stops self-healing.
- **Devil's Advocate:** Charge 1 — solo makes the player **deaf**, not lonely, because the squad is the
  game's only legibility layer.
**Resolution:** the UX designer and the Devil reached the same finding as ally and prosecutor. That is
the strongest signal in the session, and it sets the build order.

### DISPUTE E — WW1: narration, zone, or separate title?
| Voice | Position |
|---|---|
| **Narrative director** | **(c) separate title is dead on arrival** — the causal chain is the spine; ship the cause in a different box and the cause never ships. **(a) narration ships first regardless. (b) playable only as a by-product of the trench kit.** *"The story does not get to order the tool."* |
| **Devil's Advocate** | Charge 8: there is **no radio ladder in WW1** — runners, field telephones, flares. Abstract the RTO into "a way to call support" and *"you get 'call support' in three wars and a soul in none."* |
| **Resolution** | Not in conflict. The narrative ruling concerns *content*; the Devil's concerns *frames*. Both point the same way: **do not abstract ADR-011.** WW1 rides a tool built for Vietnam's own reasons, or it does not ride. |

### DISPUTE F — Is this session the disease?
The Devil's Charge 5 is the one the Arbiter is obliged to answer rather than absorb: EA date passed,
gate undischarged, **`build/RECON_Demo.exe` dated 2026-07-31 (verified on disk today, 1.47 GB, five
and a half weeks stale)**, the siege forming up off a 512 m map, 25 open playtest items, 17 of 145
tests failing. *"We pay the constraint cost now and collect the benefit never. That is the disease."*
**No other architect contested this.** It is answered in the synthesis, not here.

---

## 3 · THE THREE FINDINGS THAT CHANGED THE QUESTION

Not opinions. Code, verified by the Arbiter directly.

1. **HE ALREADY DECREED THE BORROWED RADIO — 2026-08-05, and it SHIPPED.**
   `field_director.gd:789-794`: *"**ANY RADIOMAN IS THE NET** (his ruling 2026-08-05: 'make it so all
   radiomen are valid call options and the menu is universal' — 'that does feul that feeling of a larger
   war too')… Nearest living man in "radioman" wins, **wherever he came from.**"*
   Found independently by the systems designer and the Arbiter.
2. **AND THE GROUP HAS EXACTLY ONE MEMBER.** The only non-bench `add_to_group("radioman")` in the
   project is `squad_system.gd:236` — the player's own RTO. `FriendlyPatrolGroup`'s MOS pool is
   `["POINTMAN","RIFLEMAN","RIFLEMAN","MG"]` (`:36`) and `garrison_defender.gd:14` says outright
   *"the firebase radioman is background — never the player's RTO."*
   **The capability is real; the population is empty.**
3. **THE LIVING WORLD IS ALSO ALREADY HIS DECREE — 2026-08-07.** `ambient_encounters.gd:1-6`:
   *"The walking dice (his decree 2026-08-07): distance travelled outside the wire is the pacing engine…
   Three kinds: VC leaning on the ville, **a friendly element passing through**, **a friendly element
   stuck in a real firefight.**"* Two four-man US elements already walk seeded routes
   (`mission_generator.gd:1005-1029`).

> **Together these reframe the session. The proposal is not a new direction — it is the capstone of
> three decrees he already made, and it converts ADR-020's saddest promise (*"a firefight you HEAR and
> never reach — the war is bigger than you, and you cannot fix it"*, `ADR-020:56`) into a verb.**

---

## 4 · THE TWO CANON COLLISIONS, AS DEBATED

### Pillar 4's anti-puppeteer clause (`bible/BIBLE.md:88-94`)
*"You are a member of the squad, not its puppeteer… A design that has you positioning individual men
violates this pillar."* — **PROVISIONAL** since 2026-07-19, his words: *"pillar 4 is open to changing as
i play test more."* His playtest verdict on the squad as it exists: ***"it felt like I was driving him."***
Latest touch (2026-09-07): *"FORMALLY OPEN, PARKED… It remains his ruling to make from play."*

- **Devil's Advocate, Charge 2:** the ladder's twenty-hour payoff **is the state he criticised.**
- **Game designer:** the clause survives untouched, because **all orders address the ELEMENT, never a
  man.** *"Refused: 'you — go there.'"* Named sacrifice: no *"pigman, set up on that treeline"* — the
  loss squad-tactics veterans will feel most.
- **Unresolved by design.** Only he can close it, and the council does not have standing.

### The period HUD (ADR-030, PROPOSED-DEFERRED, non-blocking)
Resolved by Agreement 2 and by the UX designer's ruling: **no fifth key.** `X` infers its verb from what
is under the reticle, exactly as the shipped `FieldMarkVerb.infer()` already does
(`field_mark_verb.gd:20-52`). Ground → MOVE. Enemy → ATTACK. Nothing → REGROUP. ADR-012's permanence is
untouched, and the 2026-09-07 council's *"no fifth key"* stands.
**Its hard dependency, named by UX:** *"an inferred verb you cannot hear confirmed is worse than a fifth
key"* — the readback is not an enhancement, it is a precondition.

---

## 5 · WHAT NOBODY DEFENDED

- **A mission counter.** All voices rejected counting to "mission 4 or 5"; there is nothing to count
  (`mission_generator.gd:881`, one type). The game designer's replacement: trigger on a **deed** —
  ≥3 committed excursions **and** one demonstrated failure the radio answers.
- **A dialogue system.** Unanimous.
- **A command cursor, ring, wheel or order marker.** Unanimous. UX: *"the man is the marker"* — the first
  man to arrive kneels and faces outward.
- **Abstracting ADR-011 into a period-agnostic "communications ladder."** Devil's Charge 8, unopposed.
- **Michael's nightmares / a sanity mechanic.** Narrative: *"PANEL-ONLY means CUT, not deferred."*
