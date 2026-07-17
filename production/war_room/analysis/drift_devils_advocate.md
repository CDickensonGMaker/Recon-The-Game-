# DEVIL'S ADVOCATE — THE DRIFT COUNCIL

**Seat:** mandatory (CLAUDE.md, War Room law). **Date:** 2026-07-13.
**Method:** the git history and `bd`, never the plan. Every claim below is a citation.

---

## 0. THE ONE-LINE FINDING

> **The drift is not in the file tree. It is in the calendar.**
> In the last sixteen hours this project has shipped **sixteen commits, and not one of them
> advanced the standing decree.** The council is about to spend itself on a 15-minute `git rm`,
> a stale path string, and a model that was already declared LIVE — while **decree item 0
> (`ida9`, the session entry gate, "nothing new ships until it verifies") has sat untouched
> since 2026-07-10 and ~95 commits have shipped straight over the top of it.**

---

## 1. THE ARBITER IS WRONG ABOUT THE P0

### The Arbiter's claim
> **"P0 — THE REPO CANNOT BE PUSHED."** 4 files >100MB, `.git` = 4.8 GB.

### What the repo actually says

```
$ git status -sb
## audit-fixes...origin/audit-fixes [ahead 2]

$ git reflog show origin/audit-fixes
6b79525 refs/remotes/origin/audit-fixes@{0}: update by push   <- 07-13 13:29, TWO HOURS AGO
cf437da refs/remotes/origin/audit-fixes@{1}: update by push
bcda3cc refs/remotes/origin/audit-fixes@{2}: update by push
```

**The repo has been pushed, cleanly, all day.** It was pushed two hours ago. The break is
**two commits old** (`53c903d`, `615ddd0`) and **nothing is on the remote that has to be
rewritten.**

That changes the size of the problem by an order of magnitude:

| The Arbiter's framing | The measured truth |
|---|---|
| "The repo cannot be pushed" (chronic) | The repo was pushed at 13:29 today; a 2-commit-old regression broke it |
| Implies BFG / filter-repo / history surgery on 4.8 GB | 2 unpushed commits → `git rm --cached` + repath 4 ignore lines + `git reset --soft` and recommit. **Nothing shared is rewritten. No force-push. ~15 minutes.** |
| Headline of a drift council | A chore |

### Steelman: the git issue IS a distraction

- The Summoner is a **solo dev on one machine.** He is not pushing *for* anybody. There is no
  reviewer, no CI, no teammate blocked by a red push.
- Even the disaster case is small: the exposure window if the disk dies right now is
  **2 commits plus a working tree** — not the project.
- And here is the cut that hurts: **the 236 MB git swallowed is DERIVED art.** The `.gitignore`
  comment the Arbiter quotes says so in its own words — *"us_base_v3.blend is a pure function of
  us_grunt_v2.blend + tools/make_base_v3.py."* Git tracking it or not tracking it **changes
  nothing about what can be recovered.** The truth source is already tracked. The Arbiter has
  labelled "we are accidentally backing up regenerable files" a **P0**.
- Meanwhile the thing that is **genuinely unrecoverable** — the in-flight, uncommitted Blender
  surgery (`us_base_v3.blend` M, `gear_armory.blend` M, `us_v3_soldier_lineup.blend` untracked) —
  is unrecoverable **whether or not `git push` works**, because it is not committed. The P0 does
  not protect the one thing at risk.

### Steelman: the git issue is real

- `git push` **will** hard-fail on the next attempt. The Summoner's own CLAUDE.md
  ("Session Completion") says **"Work is NOT complete until `git push` succeeds."** A permanently
  red push train teaches the operator to stop pushing, and *that* is how a solo dev loses a month.
- The mechanism that failed is not trivial and it is the **same mechanism that will fail again**:
  `.gitignore` is a rule bound to a **path string**, and a rename walked it out from under.
  (See §4 — this is the project's signature failure.)

### STRAIGHT VERDICT

**It is real, and it is cheap, and it is NOT a P0.** It is a 15-minute chore that the Arbiter
promoted to the headline of a drift council. Fix it in the first 15 minutes and **do not let it
be the decree.** A P0 that costs 15 minutes to fix and 0 game-value to leave broken over lunch is
not a P0 — it is a **chore wearing a P0's uniform,** and it is doing exactly what a distraction
does: it has given four architects an interesting, tractable, technically satisfying puzzle to
solve on the day the project needed to be told to stop making art.

**And one more thing the Arbiter should hear:** the briefing says the ignore rule "did not fail,
it was walked out from under." Correct. Now apply the same sentence to the GATE. See §4.

---

## 2. THE DRIFT NOBODY IS LOOKING AT

This is the section the council is not writing.

### The standing decree (CHARTER §8) vs. what actually shipped

| # | Decree item | Bead | Status TODAY |
|---|---|---|---|
| **0** | **PLAYTEST R3 — "session entry gate; nothing new ships until it verifies"** | `ida9` | **OPEN. Created 2026-07-10. `Updated: 2026-07-10`. NEVER RUN.** |
| 1 | Stealth restoration bundle | `pwu5` | ✅ CLOSED 07-12, probe 11/11 |
| 2 | Trust-restoration day (**measured perf**) | `mhfv` | **OPEN, P0.** Still no `rendering_method`, no streaming-off, **no gating FPS number** |
| 3 | Player-State HUD layer | `fy45` | OPEN |
| 4 | Damage finish | — | ✅ DONE 07-10 |
| 5 | Hub conditions (briefing + Huey ride) | `4q4i` | OPEN |
| 6 | Jungle feel | `ge6g` | OPEN |
| 7 | Law & ledger cleanup | `e99w` | OPEN |

**Two of eight decree items are done. Item 0 — the gate on all the others — has never been
executed, and ~95 commits have shipped since it was written.**

### What DID ship, in the last sixteen hours

Every commit from `cfb1288` (07-12 23:50) to `615ddd0` (07-13 15:22):

```
cfb1288  PROCESS: the War Room is the default, and CLAUDE.md was a drift generator   [process doc]
9f0d9a5  YOUR ART IS IN THE GAME NOW. You were never art-starved.                    [art wiring]
141481a  GUN ANIMATION WORKFLOW - and why you must not author a reload yet           [art doc]
f5105a6  WORKFLOW: the Arbiter overturns his own council. TWO BONES...               [art doc]
650b2c8  WORKFLOW: TWO RIGS. They share nothing. (Summoner's correction)             [art doc]
11b23ad  ART GAP LIST - measured, not guessed                                        [art doc]
b078f8a  BRIEFING: THE GRUNT, NOT THE GHOST (pillar-level correction)                [art council]
3f11b58  ART-AHEAD WIRING: build the socket BEFORE the art                           [code, FOR art]
750a677  DECREE: THE GRUNT, NOT THE GHOST                                            [art council]
2f2aab9  us_grunt_v3 IS LIVE. The helmet and the ruck leave the hurtbox.             [art]
8af9deb  STOP: us_base_v3 fails its own bone_attach gate. 15 props displaced.        [art false alarm]
bcda3cc  CORRECTION: my P0 was a FALSE ALARM. us_grunt_v3 is fine and stays live.    [art false alarm, retracted]
cf437da  THE MEDIC IS IN THE GAME. us_medic.glb + tools/make_medic.py                [art]
6b79525  THE AID BAG, built with the fabric tool (make_satchel.py)                   [art]
53c903d  cleanup: remove dead sprite_frames + stale US lineage blends                [asset plumbing]
615ddd0  restructure: one asset tree, one folder per faction                         [asset plumbing]
```

**16 of 16 are art, art-workflow documentation, art councils, or asset-tree plumbing.**
The only two that touch `scripts/` (`9f0d9a5`, `3f11b58`) touch it **in order to mount art.**

Widen the window: **95 commits since 2026-07-12 00:00. 61 of them touch `tools/`, `assets/`, or
`art_source/`.** Sixty-four percent of a two-day sprint went into the art pipeline.

### Say it plainly

**The project has spent three days making a soldier, a medic, an aid bag, a gear armory, a
satchel, a jungle patch tool, an armory rack, and a folder tree — and zero days playing its own
game.** Item 0 of the decree is a **playtest.** It is the cheapest item on the entire board. It
costs one evening at a keyboard. It has been open for **three days** while the man who owns it
sat in Blender.

And the decree is not a suggestion — the Charter calls `ida9` **"the session entry gate; nothing
new ships until it verifies a2qb/r4bk."** Ninety-five things shipped.

### The perf knife

This is the part that turns art-drift from a scheduling annoyance into an **active liability.**

- The game **last measured 19–25 FPS** (40–41 on 4.7, per `mhfv` notes). There is **still no
  gating FPS number** (`mhfv`, P0, open — it has been the "top systemic risk" in CHARTER §9 since
  audit #2).
- In that same window the project **added geometry to every man on screen**: base 1736 tris →
  RIFLEMAN 2008 → RTO 2196 (`cn68`), plus a medic, plus an aid bag, plus 3 civilian colour
  variants each hauling 5–6 textures.
- **And because of `x1bs`, every grunt is currently rendering his gear TWICE.** Two helmets, two
  rucks, two bandoliers, three bando mags — *shipping, right now.*

So the honest sentence is: **the project is pouring triangles into a renderer it has never
measured, while a live bug doubles the gear geometry on every soldier in the AO.** Art is not
free. Under `mhfv` it is the single most expensive thing you can add.

**This is a far more expensive drift than a 217 MB blend file, and no other seat at this council
is looking at it.**

---

## 3. IS THE GRUNT REMAKE JUSTIFIED?

### The receipts

- `cn68` — **"US soldier base model + RTO variant: DONE"** — and it is still **OPEN**, with a
  description pointing at `art_source/` paths that no longer exist. A bead titled DONE that is
  open, describing files that are gone.
- `2f2aab9` (07-13 00:26) — **"us_grunt_v3 IS LIVE."**
- `8af9deb` (07-13 00:34, **eight minutes later**) — **"STOP: us_base_v3 fails its own bone_attach
  gate. 15 props displaced up to 1.8m."**
- `bcda3cc` (07-13 08:09) — **"CORRECTION: my P0 was a FALSE ALARM. us_grunt_v3 is fine and stays
  live."**
- **And now the models are being remade again.**

The model was declared done (`cn68`), declared LIVE (`2f2aab9`), declared broken (`8af9deb`),
declared fine (`bcda3cc`) — **and is now being rebuilt.** That is not iteration. That is a loop.

### Ask the only question that matters: what PLAYER-VISIBLE defect does the remake fix?

I went looking for one. The only real, shipping, in-engine defect on the grunt is **`x1bs`**:

> *"Gear gib-donors RENDER on top of the live gear — every grunt wears 2 helmets, 2 rucks, 2
> bandoliers."*

That is the whole list. Everything else on the grunt is **taste**.

### THE CHEAPEST FIX THAT ACHIEVES THE SAME PLAYER-VISIBLE RESULT

`x1bs` is **a naming bug in a string comparison.** Not a modelling bug.

`scripts/visuals/model_actor.gd:329-334` hides gib donors by prefix:

```gdscript
if (nm.begins_with("grunt_") or nm.begins_with("head_frag_") or nm.begins_with("cap_")) \
        and not nm.ends_with("_joined"):
    mi.visible = false
```

The **body** donors match. The **gear** donors — `helmet_camo_shell`, `helmet_bugjuice`,
`bandolier`, `bando_mag0..2`, `ruck_bag`, `ruck_crossbar`, `ruck_rail_l/r` — do not, because
nobody gave them a prefix. The live gear is already named `*_worn` (`tools/make_base_v3.py:46`:
`("bandolier_worn", ["BandolierCloth"])`). **The convention already half-exists. One side of it
was never written down.**

**Fix A — 4 lines, ships in ten minutes:**
```gdscript
const GEAR_DONORS: PackedStringArray = ["helmet_camo_shell","helmet_bugjuice","bandolier",
    "bando_mag0","bando_mag1","bando_mag2","ruck_bag","ruck_crossbar","ruck_rail_l","ruck_rail_r"]
# ...add `or nm in GEAR_DONORS` to the existing hide condition.
```
Every grunt in the game stops wearing two helmets **today.** Costs nothing. Brittle to the *next*
gear piece.

**Fix B — the right-sized fix, hours not days:** enforce **one naming law** at the *export tool*.
Rename every gib donor to a `gib_*` prefix in `tools/make_base_v3.py` / the gear-armory export.
`ModelActor` then hides by **one prefix**, forever, and **every future gear piece is covered by
construction.** No remodelling. No re-authoring. No new topology. It is a rename plus a re-export.
Add `tests/probe_gib_contract` (there is already a `3aw2` coverage-gate bead asking for exactly
this class of probe) and the bug can never return.

**Note carefully:** *even a perfect remake does not fix `x1bs` unless the remake also renames the
donors.* The rename **is** the fix. Everything else in the remake is orthogonal to the bug.

### VERDICT ON THE REMAKE

**The remake is not fixing a defect. The remake IS the drift.**

Two things are true and the council must not blur them:

1. **The project does not need this remake.** There is no pillar it serves that `us_grunt_v3` does
   not already serve. Pillar 1 is gunplay. Pillar 2 is atmosphere — and a grunt at 30m in a PSX
   renderer, in a game the player has **never once been sat down to play** (`ida9`), does not read
   his webbing. Pillar 4 is the *squad as RPG* — that is **names, wounds, rotation, permadeath**,
   not silhouette. The Charter's own working agreement, §7: **"never block systems on art."**
   Right now the project has **inverted it: it is blocking systems FOR art.**

2. **Caleb enjoys the art, and that is a completely legitimate reason for a hobbyist to spend a
   Sunday.** The Summoner holds final authority (Law 3) and he is allowed to spend his own time on
   what gives him joy. **Nobody gets to take that from him.**

**But the council must NOT dress reason 2 up as reason 1.** The last sixteen hours contain a
*briefing*, a *decree*, an emergency *P0*, and a *retraction* — a full War Room apparatus —
convened over a soldier's helmet. **That is the project's governance machinery being spent to
justify a hobby.** The correct honest ruling is:

> **The remake is a HOBBY ITEM, not a DECREE ITEM. Caleb may absolutely keep doing it. It gets
> ZERO council overhead, ZERO P0s, ZERO beads above P2, and it does not get to be the reason the
> playtest slips a fourth day. `x1bs` gets Fix B and ships without him.**

---

## 4. THE PHONE IS A SCAPEGOAT

### The premise
> *"we have hit major drift within the project from using the remote control app on my phone"*

Every other architect has accepted this. **It is false — or, more precisely, it is a half-truth
that lets the real cause walk.**

**A phone cannot write a bad commit. It removes friction and supervision.** It is an accelerant.
So what did it accelerate? Something that was **already burning.**

### The guardrails that exist ON PAPER and have NEVER ONCE been mechanically enforced

**(a) THE GATE (`97u3`) — walked around, in exactly the same way `.gitignore` was.**

The gate bead's own description:
> *"every new feature epic must `bd dep add <epic> <this>`. While this is blocked, `bd ready` hides
> feature work."*

And, in its own text, its own epitaph:
> *"Born from audit #2: **the markdown-only gate law of 07-09 was violated within ~2 hours.**"*

So they replaced a markdown gate with a bd gate. Now look at what `bd ready` prints **today**:

```
○ RECONgame-p3f4  ● P0  LW-5 HEARTS AND MINDS: allegiance drives VC manpower
○ RECONgame-6mba  ● P0  LW-2 ProvinceState ledger + the save migration it forces
○ RECONgame-clm4  ● P0  LW-3 The firebase moves INSIDE the AO
○ RECONgame-5i8a  ● P0  LW-1 GATE: determinism probe
○ RECONgame-k77e  ● P0  [epic] EPIC: THE LIVING WAR
```

**`k77e` — "THE LIVING WAR", a P0 feature epic with twelve children, created 2026-07-13 — is NOT
in `97u3`'s blocks list.** Nobody ran `bd dep add k77e 97u3`. So the largest feature epic in the
project's history **sits at the top of `bd ready`, unblocked, while the gate is "ACTIVE."**

The gate does not gate. It gates **the four epics that happened to exist on the day it was
written** (`36pk`, `4i60`, `9qp6`, `ooel`). Every epic created since has walked straight past it,
because the gate is enforced by **an agent remembering to type a command.**

**This is the identical failure to `.gitignore`.** The Arbiter's own sentence, applied to his own
gate: *"The rule did not fail. The rule was walked out from under."*

**(b) `ida9` — "the session entry gate; nothing new ships until it verifies."**
Created 2026-07-10. **Ninety-five commits have shipped since.** It has blocked **zero.** There is
no hook, no pre-commit check, no CI, nothing that reads it. It is a sentence in a markdown file.

**(c) The gate's exemption list is a hole you can drive three days of art through.**
Exempt: *"bug fixes, presentation for already-shipped systems, standing-decree items, and
evidence-gathering probes."* **Every art asset in existence is "presentation."** The one
mechanical guardrail this project owns is **structurally incapable of catching the drift that
actually happened.** It would have waved through the medic, the aid bag, the satchel, the armory,
and the remake — on the desktop, with no phone in the room.

**(d) The truth law and the verification law are enforced by an agent's diligence — and the agent
failed them, at a desktop.** `8af9deb` raised a **P0** against the model on the strength of a
gate script and **never looked at it.** Eight hours later `bcda3cc` retracted it as a false alarm.
The Summoner's own standing memory says: *"HARD RULE: measure the scene, act, then verify by
measuring AND looking."* An agent broke that rule **while enforcing the rules.**

**(e) `CLAUDE.md` — a document injected into EVERY session — was itself a proven drift generator.**
`cfb1288` says so in its subject line. A stale explosives table made **two War Room architects
independently "verify" a canon violation that did not exist.** No phone involved.

**(f) `project.godot` cannot hold a comment.** The Arbiter's own P2: Godot deleted the 9-line
explanation within one editor session. A guardrail written where the machine erases it.

**(g) Jolt was silently reverted TWICE** (`c93a477`, `d7ec889`) by a killed benchmark. Nothing
caught it but a human noticing.

### VERDICT ON THE PHONE

**The phone is not the cause. The phone is the load test — and the process failed it.**

The cause is this, and it is one sentence:

> **Every guardrail in RECONgame is a DOCUMENT that a diligent reader must choose to obey. Not one
> of them is a MACHINE that says NO.**
> `.gitignore` obeys a path string. The GATE obeys an agent's memory. `ida9` obeys nobody.
> The truth law obeys diligence. `CLAUDE.md` is a *source* of drift, not a check on it.

Blaming the phone lets the process off the hook — and if this council decrees "stop using the
phone," it will have **treated the accelerant and left the fire.** The same drift will happen at
the desk, more slowly, and the project will not see it coming, because it will have already
declared the problem solved.

---

## 5. THE BILL — WHAT EVERY PROPOSED FIX COSTS

No free lunches. The law binds me too, and it binds the Arbiter.

| Fix | The bill |
|---|---|
| **Repair the push (repath ignores, `git rm --cached`, recommit the 2 local commits)** | **~15 min.** Sacrifice: the 236 MB of derived blends stay unbacked-up. *Accept it* — they are a pure function of tracked inputs. Cost of accepting: if `make_base_v3.py` and its input ever disagree, that output is gone. **Pay it.** |
| **`git gc` / history surgery on the 4.8 GB `.git`** | **Hours + real risk of losing history.** Sacrifice: a day. **Buys the solo dev NOTHING.** *Do not do this. This is the trap.* |
| **`x1bs` Fix A (4-line name list)** | **10 min.** Sacrifice: brittle — the next gear piece re-opens the bug. Buys: every grunt loses his second helmet **today**, and the renderer loses ~30–40% of the gear triangles on every soldier in the AO. |
| **`x1bs` Fix B (rename donors `gib_*` in the export tools + one prefix in `ModelActor` + a probe)** | **Hours.** Sacrifice: one re-export of every existing character; a day of Blender-time Caleb was going to spend anyway. Buys: the bug **cannot return**, and the gib contract finally has ONE law. **This is the right-sized fix. This is the whole justified part of the remake.** |
| **The full grunt remake** | **Days.** Sacrifice: **item 0 (`ida9`) slips a fourth day; `mhfv` (P0, perf, the top systemic risk) slips again; the game the pillars describe stays unplayed.** Buys: **nothing the player can see that `us_grunt_v3` + Fix B does not already buy.** |
| **Repath `make_jungle_patches.py` (P1 landmine)** | **~5 min.** Real. Cheap. Do it in the same 15 minutes as the push fix. Sacrifice: none. |
| **Fix the truth-law violations in `enemy_base.gd:366`, `insertion_ride.gd:57`, `civilian.gd:23`, `test_sprite_enemy.gd`** | **~20 min.** Do it. Sacrifice: none. |
| **`bd dep add k77e 97u3` (close the gate leak)** | **10 seconds.** Sacrifice: **THE LIVING WAR — the project's most exciting work, the thing Caleb most wants to build — disappears from `bd ready` until the playtest runs.** *That is the point.* **That is the whole point.* If the council will not pay this ten seconds, then the GATE is a lie and it should be deleted from the Charter rather than left there to launder work it never blocked. |
| **A mechanical gate (a pre-commit hook / a test in `run_all_tests` that FAILS while `ida9` is open)** | **An hour, plus permanent friction on every commit.** Sacrifice: **friction — the exact thing the phone was bought to remove.** Buys: the first guardrail in this project's history that can say NO without a human in the loop. |
| **"Stop using the phone"** | **Sacrifice: the Summoner's ability to work when he is not at the desk — which is when he actually has time.** Buys: **NOTHING, if the guardrails stay advisory.** The drift is a process defect; the phone only made it fast. **This decree is a placebo. Refuse it.** |
| **Standing down the art (my own recommendation)** | **Sacrifice: the thing Caleb is enjoying most, on the day he is enjoying it.** This is a REAL cost and I will not pretend otherwise. A solo hobbyist who is not having fun ships nothing at all. **The honest mitigation: do not ban the art — DEMOTE it.** It keeps happening; it stops being P0; it stops convening councils; it stops being the reason the playtest slips. |

---

## 6. WHAT I WOULD DECREE (and I expect to be overruled)

1. **15 minutes:** repath the two `.gitignore` lines, `git rm --cached` the 4 fat files,
   `reset --soft` + recommit the 2 unpushed commits, push. Repath `make_jungle_patches.py`.
   Fix the 4 lying comments. **Then close the laptop on infrastructure.**
2. **10 seconds:** `bd dep add k77e 97u3`. Prove the gate is a gate or admit it never was.
3. **Ship `x1bs` Fix B.** Rename the donors in the export tools; one prefix in `ModelActor`; add
   the probe. This is the **only** part of the grunt remake the game actually needs, and it lands
   without a single new vertex.
4. **`ida9`. Tonight.** The session entry gate. Item 0. The cheapest item on the entire board.
   **Three days late.** Play the game.
5. **`mhfv`.** Set a gating FPS number before another triangle enters this project.
6. **The remake is reclassified P2 / hobby.** Caleb builds his grunt because he wants to.
   **The council does not convene for it again.**

---

## 7. THE SENTENCE THE ARBITER WILL NOT WANT TO WRITE

> The Arbiter measured the file tree because the file tree can be measured. He did not measure the
> **schedule**, because measuring the schedule means telling the Summoner that the thing he is
> enjoying is the thing that is costing him his game — and no seat at this table wants that job.
>
> **That is what my seat is for.**
