# Devil's Advocate — THE PATROL CONTRACT

**Charge:** find where the decree breaks a Pillar, an ADR, or itself. Name every hidden cost.
No free lunches. Read against the code, not the pitch.

---

## 1. THE RESURRECTION RISK — the sharpest case that this VIOLATES ADR-029 §4

ADR-029 §4 (`ADR-029-open-patrol-simulator.md:26-31`) is not soft. It bans, verbatim:
**"No player-facing mission tracking, ever. … Floating objective markers are forbidden."** The decree
that produced it was the Summoner condemning **"the whole briefing part of the game"** and the
**"operations layer"** in favor of one north star: **"i just wanna leave the camp and go find
problems"** (`:15-16`). ADR-023 then *deleted* the briefing/offer/select/exfil chain and migrated the
save schema (`:37-38, :49-50`). This is not a parked feature. It is a **buried corpse with a headstone.**

Now read what THE PATROL CONTRACT proposes as "the genuinely-new layer" (`briefing.md:58-61`):

1. **A pre-wire screen the player opens to author intent before leaving.** — This is a
   *planning screen you sit at before the wire.* The condemned briefing was *a planning screen you sit
   at before the wire.* The period font (grease pencil vs offer dict) is cosmetic. **The interaction
   shape is identical: stop, plan on a board, then go execute the plan.** ADR-029's north star is the
   literal negation of a pre-departure planning step.
2. **"Taskings anchored to waypoints."** — A tasking bound to a point the player drew, that the player
   is then measured against, is an **objective**. Renaming it "tasking" and delivering it by radio bark
   does not change that the game is now tracking player progress against authored points.
3. **"Ground covered" score.** — A patrol-quality metric derived from whether the player reached the
   points he drew is **mission tracking.** The instant it is legible to the player mid-patrol, §4 is
   broken outright. Even debrief-only, it means the game is *scoring the plan* — the exact loop
   ("did you do the thing you were briefed to do?") that was condemned.

The honest reading: **three of the five new sub-features are the deleted briefing/objective loop
re-derived from first principles, wearing ADR-022's clothes.** The grease pencil was canonized
(ADR-022) as a tool for the player to record *what he thinks* and *be wrong* (`ADR-022:42-49`). The
Contract repurposes it as a tool for the player to *declare a route the game will grade.* That is a
different object with the same texture, and the texture is what will fool the next reader.

### The exact conditions under which it does NOT violate §4 — and whether they hold

For this to survive ADR-029, ALL of the following must be true and *stay* true:

- **(a) Waypoints never acquire completion state.** No checkmark, no color change, no "reached" flag,
  no removal-on-arrival. They are inert grease marks, indistinguishable from an ADR-022 ambush note.
- **(b) Ground-covered is never on-screen during the patrol.** No progress bar, no "3/5 swept," no
  counter. It surfaces only in the wire AAR (`_bank_patrol`, `field_director.gd:1074`), as prose.
- **(c) No waypoint is ever the target of a tasking bark that references it *as a waypoint*.** Command
  may say "check the village NORTH" — it may **not** say "proceed to your waypoint Bravo." The moment
  the radio names the player's own mark, the mark is an objective pin with a diegetic voice.
- **(d) The route never drives location selection.** (See §2 — this is where it actually breaks.)

**Is the Arbiter's proposed guard sufficient?** The guard offered in the briefing (`:68-69`) covers
(a) and (b) only — "waypoints never check off; ground-covered is debrief-only, never an on-screen
progress bar." **It does not name (c) or (d), and those are where the line actually fails.** A guard
that forbids the *visual* checkmark but permits a radio bark that says "you missed your second marker"
has moved the objective tracker from the eyes to the ears and called §4 satisfied. **The line is too
fine to hold as stated.** §4 says "*ever*" — a word the Summoner chose. A drawn-route-plus-score system
lives one careless bark, one debug HUD line, one "small QoL" progress toast away from being the thing
he deleted. And this repo's own memory is that features drift back: the "buried briefing" was buried
*once already* and the standing law is **never "restore" a buried system**
(memory: recongame-overnight-patrol-sim). This decree is, structurally, a proposal to un-bury it under
a new name. That must be stated plainly, not glossed.

**Verdict on §1:** VIOLATION-PRONE. Survivable ONLY with a four-clause guard (a–d), machine-enforced,
not a sentence of intent. Absent (c) and (d) in writing, the Arbiter is approving a resurrection.

---

## 2. ROUTE POINTLESSNESS — what do 5 drawn points ADD that walking there doesn't?

This is the decree's load-bearing weakness, and the code proves it.

The world is **already persistent** — villages and camps are placed at world-build and stored in
`patrol_locations` (`field_director.gd:787-798`). The player **already chooses direction by walking**:
`_pick_patrol_location` reads `world.player.global_position - patrol_gate_pos` as the push vector and
selects the nearest living site within a ±45° cone (`:1042`, `dot >= 0.707` at `:1053`). **The player's
feet are already the route.** Walk north out the wire → command points you at the northern village.
That is the entire loop, shipped, working, and it requires zero UI.

So what does drawing 5 points add?

- **If the route only expresses direction:** it adds nothing the push-vector doesn't already read from
  the player's first 120m of walking. It is **ceremony** — a menu that reproduces information the game
  already infers from behavior. Pillar 3 (`BIBLE.md:87`) is "*any route, any order … nothing on rails*"
  — walking *is* the route expression the pillar wants. A planning screen is a weaker, more abstract
  version of the freedom the player already has in his legs.
- **If the route drives tasking (§4-(d)):** now it is worse than pointless — it is **actively
  harmful**, because it creates a **second location-selection authority** competing with the live
  push-direction picker at `:1042`. This project's single most expensive recurring bug is exactly this:
  **"~14 parallel LIVE world-build systems"** producing divergent behavior the fossil law can't catch
  (memory: recongame-divergent-systems-blindspot). A route-proximity picker layered beside
  `_pick_patrol_location` is a fifteenth. When the drawn route says "Bravo" and the push-vector says
  "the village you're actually walking toward," which wins? Every answer is a bug: route wins → the
  world ignores where you walk (guts Pillar 3 and design-call #3, "route = suggestion"); walk wins →
  the route you drew is decorative and the player feels lied to.

**Does it make the loop WORSE?** Yes, at the front door. The north star is
**"i just wanna leave the camp and go find problems"** (`ADR-029:16`). A route-planning screen inserts
a **planning friction gate between the player and the wire** — the precise step the Summoner removed.
The fantasy is *walk out and let the AO happen to you.* The Contract asks the player to *do homework
first.* For a player who wants to leave camp and find trouble, five grease dots on a board is a
speed bump, not a feature.

**The one thing a route legitimately adds** that walking does not: **an intent the player can be WRONG
about** — ADR-022's actual purpose. "I'll sweep the ridge, then cut to the stream" is a plan the world
can violate (the ridge is empty, the trouble was at the stream). But note: **ADR-022 already grants
this** via free grease-pencil marks and the AMBUSH note (`ADR-022:35-53`), and it grants it *without a
dedicated planning screen and without any scoring.* The Contract's route UI is ADR-022's pencil with a
scoreboard bolted on — and the scoreboard is the part that breaks §4.

---

## 3. OP-HOLD — the boredom/rail dilemma, and what SimClock does to it

The overnight-OP setpiece is a trap, and SimClock makes the trap sharper, not softer.

**The dilemma is real and unescaped:**
- **10 mikes of nothing** = dead air. The player crouches in the dark and waits. Pillar 2 (atmosphere)
  can carry *some* dread, but 10 minutes of guaranteed-nothing is how you teach a player to alt-tab.
- **A guaranteed wave** = a scripted setpiece. Pillar 3 (`BIBLE.md:87`): "*the seeded world generates
  the tactical problems … not from authored setpieces.*" A hold that *always* pays off in a contact at
  minute 8 is an authored setpiece with a countdown. **That is a Pillar 3 violation**, full stop, and
  dressing it as "tension" doesn't change that the outcome was authored, not seeded.
- **A *chance* of a wave** (the only Pillar-3-legal option) means the tension is honest but the median
  session is the dead-air one. You cannot have guaranteed payoff AND emergent freedom. **No free lunch.**

**SimClock makes it worse, both ways.** `sim_clock.gd:16` sets `real_to_sim_ratio = 60.0` and `:33-37`
free-runs every frame. So "hold 10 mikes" resolves three ways, all bad:
1. **Run at 60:1 (the world's normal rate):** 10 sim-minutes = **10 real seconds.** The "overnight OP"
   is over before the player's knees bend. No tension, no setpiece — a blink.
2. **Drop to 1:1 for the hold:** now it's **10 real minutes of crouching.** Dead air, and you've also
   desynced the setpiece from the ambient war, `civilian_schedules.gd`, `ambient_war.gd`, and
   `mission_weather.gd`, all of which read sim-time. Time-compression is what makes the living world
   affordable; pausing it for a setpiece **freezes the living world the setpiece is supposed to live
   inside.**
3. **Pause SimClock entirely:** same desync as (2), plus night/dawn (`period_at`, `:60-67`) stops
   advancing — the "overnight" never becomes morning.

**The crouch/hold tension the briefing leans on is a real-time, second-to-second phenomenon**
(suppression, posture, the sound of movement in the trees). **SimClock time is not real-time.** The
setpiece wants a slice of *un-compressed* time bolted into a *compressed* world, and the two clocks
fight. There is no built substrate for "10 mikes" that isn't either 10 seconds or a living-world
freeze. **This feature has no clean home in the current time model, and the briefing does not
acknowledge it.**

---

## 4. THE RAGE — is Level-2 command a net negative until the AI is reliable?

The briefing's own fear (`:35-36`): "*deep command + unreliable AI = rage.*" It is right to be afraid,
and its mitigation is **half a fix.**

Read what already exists: `squad_system.gd:147-161` already ships **exactly the forgiving area/direction
orders the briefing asks for** — FOLLOW (`squad_follow`), HOLD (`squad_hold`), MOVE_TO an aimed ground
point (`squad_move`), and weapons-free toggle. `_order_all` (`:173-178`) already emits a toast
("SQUAD: HOLD POSITION"). **So Level-2 orders are ~80% built.** The *new* ask is narrower than it
sounds: an EYES-ON/SUPPRESS-a-direction verb, plus **confirmation feedback** (bark + compass line +
roster change).

Here is the trap the briefing walks into: **confirmation feedback makes unreliable AI feel WORSE, not
better.** The briefing's theory is "half the 'AI ignored me' feeling is missing feedback" (`:35`). The
other half — the half that matters — is **the AI actually not doing the thing.** When the point man
pathfinds into a tree, holds the wrong knoll, or the MOVE_TO ground-ray fails (`_aim_ground_point`,
`:181-192`, caps at 40 steps × 5m = 200m and returns ZERO past that — an order the player gave that
silently does nothing), a confirmation bark **converts a silent failure into a broken promise.** "MOVING
UP" *(and then doesn't)* is more enraging than saying nothing, because now the squad has **lied on the
radio.** The Summoner's own 2026-07-19 verdict was already "*it felt like I was driving him*"
(`BIBLE.md:76`) — the squad AI is on *provisional* pillar footing precisely because its obedience feel
is unproven (`BIBLE.md:88-94`).

**Is Level-2 a net negative until the AI is more reliable?** For the *confirmation* half — **yes, it can
be**, and the risk is asymmetric: a confirmed-then-disobeyed order is worse than the current silent
state. The forgiving-order half (area/direction biasing intent the AI already had) is lower-risk and
mostly already exists. **Recommendation: ship the direction verb, DEFER the confirmation bark until a
playtest proves the AI visibly obeys area/direction orders ≥~90% of the time.** Bolting "it SAID it
obeyed" onto an AI that visibly doesn't is how you manufacture the exact rage the briefing named.

---

## 5. SCOPE — one decree or five?

It is **five features**, and the briefing lists them as five (`:58-61`): route-planner UI ·
ground-covered accumulator · route-anchored tasking · overnight-OP setpiece · Level-2 orders + confirm.
They share a theme, not an implementation. Bundling them means the **weakest one (route-anchored
tasking, §2/§4) gates the strongest one, and the riskiest one (OP-hold, §3) has no clean substrate.**

The standing law is that PLAYTEST R4 is **unresolved** — it is the session entry gate, discharged only
by a verified Summoner playtest (`CLAUDE.md`, THE SESSION ENTRY GATE). **The current open-patrol loop
has never been verified by the Summoner.** Building five interlocking systems *on top of an unverified
loop* is the trap: if R4 reveals the base loop is wrong (as the 2026-07-19 "driving him" verdict
revealed the squad was), all five new systems were built on sand and must be reworked. This project has
paid that bill before.

**The MVP that proves the loop** — and nothing more:
1. **NOTHING new before R4 is discharged.** The base loop (wire → push-direction site → contact → AAR)
   must be Summoner-verified first. That is the law, not my opinion.
2. **Then, the single cheapest test of the Contract's core hypothesis:** does command tasking the player
   dynamically over the net make the patrol feel *authored-by-the-world* rather than *wandering?* This
   is testable with **zero new UI** — `raise_crisis` (`field_director.gd:886`) already retargets the
   sweep over the net to features actually near the player. Tune *that* (more varied barks, tie to
   nearby persistent features) and playtest it. If dynamic radio tasking against the persistent world
   isn't fun **without** a route screen, no route screen will save it.
3. **Ground-covered as a silent debrief line only** (AAR prose, `_bank_patrol:1074`) — one number, never
   on-screen. Cheap, §4-safe, tests whether the player even *wants* a patrol grade.

**Deferred until the above earns them:** the route-planner UI (§2 says it may be pure ceremony), the
OP-hold setpiece (§3 says it has no clean time-model home), the confirmation bark (§4 says it may be
net-negative). **Build the loop's nervous system before its costume.**

---

## 6. LANDMINES — determinism, persistent-world edge, abort/failure

- **Determinism (ADR-010, one seed per operation).** The world is seeded once; `_bank_patrol` sets
  `state.seed_value = patrol_count` per excursion (`field_director.gd:1090`) with the op seed owning the
  world. A **ground-covered score computed from a player-drawn, free-form route is inherently
  non-deterministic and non-reproducible** — two players, same seed, different squiggles, different
  scores. That's fine for a *grade* but fatal if ground-covered ever feeds anything the seed is supposed
  to own (spawns, rank gates, campaign state). Keep it strictly cosmetic/AAR or it punches a hole in
  ADR-010's "the op seed owns the world."

- **Persistent-world edge: a waypoint with no living feature nearby.** The briefing names this
  (`:66`) but the code shows the teeth. `_pick_patrol_location` (`:1030-1069`) selects from
  `patrol_locations` — villages/camps only (`:797`). If the player draws a waypoint in an **empty
  quadrant** (ADR-029 guarantees only ≥1 village ≤450m and ≥1 camp ≤500m, `ADR-029:27-28` — the rest of
  the AO can be barren), route-anchored tasking has **nothing to anchor to.** Command either goes silent
  (player drew a plan, got no response — feels broken) or invents a target near the empty point
  (spawns-on-the-line — **explicitly forbidden by design-call #1, guts world-foundation-locked**). There
  is no third option. The persistent world does not owe the player's grease pencil a target.

- **Abort/failure semantics.** RTB is always legal (open-sim) and the code honors it — cross back inside
  95m and `_bank_patrol` fires (`:822-824`). But layering a *route* onto this creates a new failure
  feeling with no failure state: a player who drew 5 points and walked 1 before RTB has "abandoned" 4
  waypoints. If those waypoints visibly persist un-checked (they must, per §4-(a)), the map now shows
  the player his own **unfulfilled plan** every time he opens it — a nagging quest log the player wrote
  *for himself.* ADR-022's law is that the player's marks may be wrong and **the game never corrects
  them** (`ADR-022:42-49`) — but here the *player's own eyes* correct him against his own route. That's
  a subtle new bad-feeling the ambush-note system never had, because an ambush note isn't a *commitment.*

- **Fossil/drift hazard.** `field_director.gd:1` still headers itself as owning "objective completion" —
  a drift artifact from the deleted objective system that ADR-029 §7 says should be dead. Adding
  ground-covered + a second location-picker without deleting the push-direction picker (`:1042`) is a
  textbook ADR-023 violation: **two systems that pick the patrol location, neither deleted.** Whatever
  ships, the fossil law demands the loser of the route-vs-push contest be *removed*, not left standing as
  a lie in the map.

---

## What is sacrificed (no free lunches)

- Approve the route UI + ground-covered as specified and you **spend §4's "ever"** — you re-open the
  briefing/objective door the Summoner welded shut, and you trust a two-clause guard to hold a
  four-clause line.
- Approve the OP-hold setpiece and you **buy a Pillar-3 fight** (authored payoff vs seeded emergence)
  **and a time-model fight** (real-time tension vs 60:1 compression) that the code has no home for.
- Approve the confirmation bark now and you **risk manufacturing the exact rage the briefing feared** by
  giving an unproven AI a voice to promise with.
- Build all five before R4 and you **stack five systems on an unverified loop** — the trap this project
  has already sprung twice.

**The route is ceremony until proven otherwise; the score is a §4 breach until walled off; the setpiece
has no clock to live in. Prove the loop with dynamic radio tasking and a silent AAR grade FIRST.**
