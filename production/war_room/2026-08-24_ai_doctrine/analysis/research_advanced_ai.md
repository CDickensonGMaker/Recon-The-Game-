# RESEARCH ARCHITECT — Advanced Combat AI in Shipped Shooters (2026-08-24)

Brief: how shipped shooters made men HOLD cover, deliver mutual suppressing fire, move as a
unit, and preserve their own lives — mechanisms only, costed against our constraints
(~50 men hot cap, think at 6-7 Hz separate from execute, frame already CPU-bound in the AI,
no per-man pathfinding storms, no O(n²) teammate scans).

Our architecture, verified in code before writing (POINTER LAW):
goal-FSM per man (`current_goal: Enums.AIGoal`, `current_state: Enums.AIState`,
`scripts/enemies/enemy_base.gd:24-25`), personalities
(`Enums.AIPersonality` AGGRESSIVE/DEFENSIVE/BALANCED, `scripts/autoload/enums.gd:55-59`),
`suppression_level` 0-1 (CLAUDE.md §Suppression System), think LOD
(`_think_interval_current`, `enemy_base.gd:33`), local grid cover search
(`COVER_SEARCH_OFFSETS`, `enemy_base.gd:126`), debounced contact (`contact_conf`,
`enemy_base.gd:169`), intent stability filter (`_last_intent`/`_cand_intent`,
`enemy_base.gd:170-172`). **There is no squad-level coordinator object for enemies** —
`scripts/**/*squad*.gd` has zero hits; the siege director drives objectives, not roles.
That absence is the single biggest gap this research points at.

Sources reviewed in full text (papers pulled and read, not just abstracts): Orkin's F.E.A.R.
GDC 2006 paper, McIntosh's TLOU Game AI Pro 2 chapter. Others from talk summaries/slides as
cited inline.

---

## 1. F.E.A.R. — GOAP individuals + a thin ad-hoc squad layer (Orkin, GDC 2006)

**(a) Mechanism.** Individual soldiers plan with A* over actions (GOAP), but the celebrated
squad play comes from a SEPARATE, deliberately informal layer: a global coordinator
periodically re-clusters AI into squads **by proximity**, and each squad runs at most ONE
"simple squad behavior" at a time. The four shipped behaviors: **Get-to-Cover** (everyone
without valid cover moves to valid cover *while one member lays suppression fire*),
**Advance-Cover** (squad bounds to cover nearer the threat, again one suppressor),
**Orderly-Advance** (single file, each man covers the man ahead, last man covers rear),
**Search** (pairs covering each other). The behavior fills *slots* (1 suppressor + N movers),
sends **orders**, and orders arrive as goals the individual weighs against his own — fleeing a
grenade can trump the order, and the squad behavior just *fails* and re-forms. Critically,
the squad layer never analyzes the map: each man's own sensors already keep a list of valid
cover nearby; the squad behavior only picks from what members already know and **ensures no
two men are ordered to the same node**. Orkin is explicit that F.E.A.R. shipped ZERO complex
squad behaviors — flanking and pincers are emergent from "move to the only valid cover you
know" routed around walls. Barks are chosen AFTER the decision to sell it as intentional
("I've got nowhere to go!" explains a man who can't reposition).

**(b) Cost.** Squad layer is O(squads) at a slow tick (~1 Hz is enough), each behavior touches
only its ~4-6 members. Zero extra per-man think cost: the men were already sensing cover.
Slot bookkeeping is an array. The one hazard — orders triggering pathfinds — is bounded
because a behavior moves at most a squad's worth of men and only on activation, not per tick.

**(c) Mapping.** Orders = one new high-priority entry in our situation-priority stack
(`ORDER_SUPPRESS`, `ORDER_MOVE_TO`), refusable exactly as F.E.A.R.'s are (our stack already
prioritizes; an order is just a scored goal whose score comes from outside). Cover dedup =
a claim table keyed by our `COVER_CELL` grid cell. The suppressor slot writes the *target's*
`suppression_level` — the receiving side already exists.

**(d) Answers.** Mutual suppressing fire (the suppressor slot IS it) · moving as a unit
(Advance-Cover/Orderly-Advance are bounding overwatch and file movement verbatim) · partly
cover holds (a man ordered to suppress from cover stays put by definition).

Sources: [gamedevs.org paper PDF](https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf) ·
[GDC Vault talk](https://gdcvault.com/play/1013282/Three-States-and-a-Plan) ·
[Game Developer summary](https://www.gamedeveloper.com/design/building-the-ai-of-f-e-a-r-with-goal-oriented-action-planning)

---

## 2. The Last of Us — Combat Coordinator roles + exactly-one-shooter (McIntosh, Game AI Pro 2 ch.34)

**(a) Mechanism.** A single global **Combat Coordinator** owns named roles: *Flanker,
Approacher, Investigator, StayUpAndAimer, OpportunisticShooter*. NPCs call `RequestRole()`;
grant locks the role until released. Two grant policies: first-come-first-served
(OpportunisticShooter — "it was only necessary for ONE NPC to be shooting the player at any
given time; all other NPCs could spend their time taking cover, flanking") and
ideal-candidate (Flanker — every candidate's flank route is rated by cost and only the best
requester is granted). This is the purest statement of CoD-style life preservation in print:
**at any instant one man is the threat and everyone else is preserving himself**, and the
one man granted the shooter role drops *everything*, mid-animation, to fire — so the player
is never safe, yet nobody mobs. Cover selection: precomputed cover "posts", closest ~20
gathered per NPC, rated by **post selectors** — a list of criteria each returning 0..1,
**multiplied** together (any zero vetoes), e.g. `path-valid`, `available` (not claimed),
`static-pathfind-not-near-player` (reject cover whose path runs toward the player — their
fix for men sprinting past the player's muzzle), distance curves. All criteria are evaluated
continuously from data gathered on *previous* frames, so state switches have zero latency.
Flank routing uses a **combat-vector cost shape** (avg NPC position weighted by recent shots)
painted into pathfind cost — stable, unlike exposure-map flanks which "could vary wildly
from one frame to the next" (their words: frame-to-frame score instability IS the bouncing
disease, and they cured it by scoring against a slow-moving aggregate instead of raw LOS).

**(b) Cost.** Role table: O(roles) memory, O(1) request/release. Their luxury numbers
(20-40 pathfinds/frame on SPUs, 160 rays/frame for cover checks, round-robin path refresh
every ~0.5 s) are NOT affordable for us — but the load-shaping ideas are: fixed per-frame
ray/path budgets, round-robin refresh, and consumers reading last-known scores instead of
demanding fresh ones. Ideal-Flanker's "pathfind per candidate per frame" must degrade to
one candidate probe per squad tick for us.

**(c) Mapping.** Roles are goals granted by a coordinator instead of self-selected: our
goal scorer already picks `ENGAGE_TARGET` vs `SEEK_COVER`; the coordinator just caps how
many men may *hold* the aggressive goal at once. `available` = the same cover-claim table as
#1. The multiplicative-criteria scorer is structurally our situation-priority stack — we can
adopt the *not-toward-player path* veto and *distance curve* criteria as data.

**(d) Answers.** COD-style life preservation (this is the canonical implementation) ·
cover holds (a man without the shooter role has no reason to leave cover) · mutual
suppression (StayUpAndAimer ≈ suppressor role).

Sources: [Game AI Pro 2 ch.34 PDF](https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf) ·
[GDC Vault: The Last of Us Human Enemy AI](https://www.gdcvault.com/play/1020338/The-Last-of-Us-Human) ·
[Game Developer: Endure and Survive](https://www.gamedeveloper.com/design/endure-and-survive-the-ai-of-the-last-of-us)

---

## 3. Killzone — annotated waypoints, precomputed visibility, position evaluation (Straatman & Beij, GDCE 2005)

**(a) Mechanism.** The world is a waypoint graph annotated offline; **waypoint-to-waypoint
visibility is a precomputed lookup table** (standing + crouched stances — 2,000 waypoints in
32 KB). Position picking evaluates candidate waypoints near the agent with a weighted
function over: cover from EACH known threat (a table lookup, not a raycast), line of fire to
the target, distance/path cost, danger zones, and area-of-operations assignment (a
commander-imposed region that keeps a man's search local and his behavior on-mission).
**Suppression fire** falls out of the same data: when the target is lost, fire at the last
known position and the waypoints adjacent to it — the LUT says which points the muzzle can
service. Tactical pathfinding reuses the LUT as path cost so approach routes avoid enemy
lines of fire without per-node raycasts.

**(b) Cost.** This is the cheapest position scoring in the canon: per candidate per threat =
one bit lookup. The offline bake is the price. For us the equivalent is baking a coarse
cell-to-cell visibility/cover field per generated AO (the firebase is 512 m; a 4 m cell grid
is 128×128 = 16 K cells — pairwise full LUT is too big, but per-cell "cover direction
bitmask + height class" like our `cover_is_low` is bakeable at stamp time, and threat-aware
scoring becomes integer ops). Per man per think: O(candidates × threats) integer work, zero
raycasts.

**(c) Mapping.** Our `COVER_SEARCH_OFFSETS` grid probe is the runtime-raycast version of
this; the Killzone lesson is to move the expensive predicate offline/into the world stamp
so the 6-7 Hz think only does table math. Area-of-operations = our siege director's
`assault_objective` generalized: a region assignment that stops men wandering off-doctrine.

**(d) Answers.** Cover holds (a position scored against ALL known threats stays valid
longer, so there's less churn) · mutual suppression (last-known-position suppression is
exactly the "shoot at the treeline" Vietnam texture we want) · perf headroom that pays for
everything else.

Sources: [Guerrilla paper PDF](https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf) ·
[mirror](http://cse.unl.edu/~choueiry/Documents/straatman_remco_killzone_ai.pdf) ·
[Killzone 3 hierarchical bots, Game AI Pro ch.29](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf)

---

## 4. Halo 2/3 — behavior hysteresis, styles as personality masks, task-tree allocation (Isla, GDC 2005/2008)

**(a) Mechanism.** Two pieces matter to us. First, Halo 2's decision hygiene: behaviors carry
**memory and hysteresis** — a running behavior gets a bonus to keep running, impulses/events
(not per-tick re-scoring of everything) trigger interrupts, and **styles/behavior masks**
switch whole subtrees on/off per character archetype — Grunt vs Elite is the SAME tree with
different masks and parameters. That is the shipped answer to "one synced core, asymmetric
doctrine." Second, Halo 3's **objectives system**: designers author a tree of prioritized
tasks with *capacities* ("plinko machine" — squads poured in at the top filter down to the
most important unfilled tasks), so 40+ men in an encounter get jobs from a declarative task
list instead of each reasoning globally.

**(b) Cost.** Hysteresis and masks are FREE — constants and branch conditions inside the
scorer you already run. The task tree is O(tasks + squads) at encounter cadence (well below
1 Hz), and replaces per-man global reasoning, i.e. it *reduces* cost at 45 men.

**(c) Mapping.** Hysteresis: our `_cand_intent`/`_cand_since` stability filter
(`enemy_base.gd:170-172`) already does this for ANIMATION intent — the research finding is
that the SAME pattern must sit on `current_goal`: challenger goal must out-score the
incumbent by a margin, sustained across N thinks, before a switch. Styles: our
`AIPersonality` enum becomes a **doctrine resource** (a .tres of weights, dwell times,
token counts, press thresholds) — US vs NVA vs VC are three data files over one scorer.
Halo 3's task tree is our siege director grown one notch: tasks with capacities
("suppress bunker 2, cap 2", "breach wire east, cap 6") instead of a single
`assault_objective` vector.

**(d) Answers.** Bouncing (hysteresis on goals is the direct cure) · one-core-many-doctrines
(styles/masks are the shipped pattern) · moving as a unit at siege scale (task capacities).

Sources: [Handling Complexity in the Halo 2 AI, GDC 2005](https://www.gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai) ·
[Building a Better Battle slides PDF](https://web.cs.wpi.edu/~rich/courses/imgd4000-b12/lectures/halo3.pdf) ·
[GDC Vault](https://gdcvault.com/play/497/Building-a-Better-Battle-HALO) ·
[GDC08 notes](https://aarmstrong.org/journal/2008/03/02/gdc08-notes-building-a-better-battle-halo-3-ai-objectives)

---

## 5. Attack/fire tokens — DOOM 2016, Marvel's Spider-Man

**(a) Mechanism.** A shared pool of N attack tokens per encounter; only token holders may
attack (or in cover-shooter terms: may EXPOSE themselves to fire). Everyone else postures —
holds cover, repositions, yells. Token count is the difficulty/doctrine dial: more tokens =
more simultaneous aggression. Spider-Man passes the attacker token round-robin to pace the
fight. This is the degenerate, dirt-cheap form of TLOU's coordinator, and it's the exact
mechanism behind the modern-CoD feel the Summoner names: men in cover are WAITING for a
token, which reads as discipline and self-preservation.

**(b) Cost.** An int counter and an owner list per side per encounter. O(1) per request.
The cheapest technique in this document.

**(c) Mapping.** Gate `ENGAGE_TARGET`'s *exposed* variants (leave cover, advance, stand-and-
fire) behind a token from the squad/side coordinator; `HOLD_POSITION`+fire-from-cover stays
ungated. Token count lives in the doctrine resource: US squad 2-3, VC cell 1-2, siege
assault_press effectively uncapped — which preserves the 7/30 siege ruling (45 men pressing
the wire must not be strangled by a token cap; the doctrine file for `assault_press` sets
tokens = 999, and the press keeps its existing path).

**(d) Answers.** COD-style life preservation · cover holds (no token = stay put) · bouncing
(a man who can't act on a new target has no reason to reposition toward it).

Sources: [DOOM token system writeup + GDC origin](https://github.com/Lim-Young/UnrealAITokenSystem)
(id Software, "Embracing Push Forward Combat in DOOM", GDC 2018) ·
[Spider-Man AI, Game Developer](https://www.gamedeveloper.com/programming/designing-ai-to-do-anything-a-spider-man-i-) ·
[Ask a Game Dev on attack tokens](https://askagamedev.tumblr.com/post/620010728353595392/when-designing-non-boss-enemy-ai-ie-ai-for)

---

## 6. Company of Heroes — suppression as a first-class state with a pinned threshold

**(a) Mechanism.** Incoming automatic fire accumulates suppression on infantry; suppressed
units lose move speed and accuracy; continued fire crosses a second threshold to **pinned**
(near-immobile, near-useless, hugging the ground). The design intent (Relic): suppression is
an alternative to killing — it *removes a unit from the fight without removing its men*, and
it creates the base-of-fire + maneuver grammar because a pinned defender can be flanked at
leisure. The AI side is symmetric: MG teams are TASKED to suppress an area, not to kill.

**(b) Cost.** We already pay it — `suppression_level` exists. The upgrade is two thresholds
(suppressed/pinned) with hysteresis on exit, and posture consequences (`_prone` pin path
already exists at `enemy_base.gd:175-177`). Data-only.

**(c) Mapping.** Make `suppression_level` a driver of the goal scorer, not just a
cover-seeking nudge: suppressed multiplies all reposition goals down (men under fire HOLD),
pinned locks goal churn entirely for a dwell. And on the OUTPUT side, the squad suppressor
slot (#1) targets a CELL, not a man — area suppression writes suppression onto everyone in
the cell, which is what makes MG fire feel like doctrine instead of aimbot.

**(d) Answers.** Mutual suppression (gives the suppressor's fire a mechanical product) ·
cover holds (being suppressed pins you IN cover) · moving as a unit (suppress-then-move
becomes causally real: the move is safe *because* the target is pinned).

Sources: [CoH suppression, Fandom wiki](https://companyofheroes.fandom.com/wiki/Suppression) ·
[Inspired Designs in Relic's RTS Games, Game Developer](https://www.gamedeveloper.com/design/inspired-designs-in-relic-s-rts-games) ·
[GDC Vault: AI From the Trenches of Company of Heroes](https://www.gdcvault.com/play/765/Dealing-with-Destruction-AI-From)

---

## 7. Arma/OFP + van der Sterren — bounding overwatch and the two squad-AI shapes

**(a) Mechanism.** OFP/Arma's "Danger" mode: the squad automatically drops into bounding
overwatch — one element stationary and covering while the other moves, roles alternating —
driven by formation slots and a squad leader FSM, not per-man cleverness. William van der
Sterren's AI Game Programming Wisdom (2002) chapters ("Squad Tactics: Team AI and Emergent
Maneuvers" / "Planned Maneuvers") formalized the two viable shapes: **decentralized**
(each man reacts to squadmates' broadcast intents — cheap, emergent, F.E.A.R.-like) vs
**centralized** (a squad brain plans a maneuver and issues orders — Arma-like, needed for
deliberate fire-and-movement). The canon consensus: centralize the MANEUVER decision,
decentralize the survival decisions — which is exactly F.E.A.R.'s refusable orders.

**(b) Cost.** A squad-leader tick at ~1 Hz choosing between {hold / bound-left-element /
bound-right-element}; members just receive move orders. O(squad members) per squad tick.
The trap (visible in Arma itself) is pathfinding every member every bound — stagger the
element's move orders across thinks.

**(c) Mapping.** Split each squad into two fixed elements at spawn (data: element A/B
membership). The squad behavior alternates which element holds `ORDER_SUPPRESS` (fire from
cover at known/suspected cells) and which gets `ORDER_MOVE_TO` the next cover line. Our ally
`patrol_file_slot`/`FILE_SPACING` machinery (`enemy_base.gd:141-143`) shows formation slots
already exist in the codebase — combat bounding reuses the slot idea with cover cells as
slots.

**(d) Answers.** Moving as a unit (this IS the ask, by name) · mutual suppression
(the stationary element's job) · faction asymmetry (US bounds by fireteams with an MG base;
VC doctrine file swaps bounding for infiltrate-then-volley-then-fade).

Sources: [Bohemia forums on Arma bounding overwatch AI](https://forums.bohemia.net/forums/topic/88457-when-should-ai-subordinates-use-the-bounding-overwatch-movement/) ·
[Bounding overwatch, Wikipedia](https://en.wikipedia.org/wiki/Bounding_overwatch) ·
van der Sterren, *AI Game Programming Wisdom* (2002), squad tactics chapters (CGF-AI)

---

## Cross-cutting finding: why our men still bounce after the 8/04 FEAR decree

Three shipped-game diagnoses converge on the same defect class:
1. **Score instability, not bad scores** (TLOU flank routes "varying wildly frame to frame"
   → fixed by scoring against slow aggregates like the combat vector). If our cover/goal
   scores are built from raw per-think LOS and raw target position, they oscillate and the
   man follows them. `contact_conf` debounces sight; nothing debounces the SCORE.
2. **No incumbency bonus on goals** (Halo 2 hysteresis). We built the stability filter for
   animation intent but the goal layer switches on any better score.
3. **No reason to stay** (TLOU/DOOM): a man with nothing gating his aggression always has
   somewhere "better" to be. Tokens/roles give not-moving a purpose, which is what "longer
   cover holds" actually is — not a bigger dwell constant, but a job whose execution is
   staying put. F.E.A.R. even papered over the residue with a bark ("I've got nowhere to
   go!") — cheap and worth copying for squad radio chatter.

---

## RANKED SHORTLIST — best feel-per-CPU under our constraints

| # | Technique | Type | Per-man/think cost | Complaints answered |
|---|-----------|------|--------------------|---------------------|
| 1 | **Squad coordinator with roles + fire tokens** (TLOU roles ×ced down to F.E.A.R. slots: per squad 1 suppressor slot, N exposure tokens, cover-claim table) | NEW SYSTEM (small: one autoload/side object, ~1-2 Hz squad tick) | O(1) per man (request/release); O(squad) per squad tick | life preservation · mutual suppression · cover holds |
| 2 | **Goal hysteresis + score stabilization** (incumbent margin + sustained-challenger delay on `current_goal`; score against debounced aggregates, mirror of the existing `_cand_intent` filter) | TUNING + ~20 lines in the scorer | zero new work — same scorer, extra constants | bouncing (the direct cure) · cover holds |
| 3 | **Doctrine resources over one core** (Halo styles: US/NVA/VC .tres of weights, dwell, token counts, press thresholds; `AIPersonality` folds into it; `assault_press` doctrine keeps the siege uncapped) | DATA-ONLY (once #1/#2 expose the dials) | zero | one synced core, asymmetric factions |
| 4 | **Suppression as goal-scorer driver both ways** (CoH pinned threshold w/ exit hysteresis; suppressor slot fires at CELLS and writes area suppression) | TUNING + small code on existing `suppression_level` | zero new scans (reuses existing state) | mutual suppression · cover holds · suppress-then-move causality |
| 5 | **Two-element bounding overwatch** (F.E.A.R. Advance-Cover / Arma danger-mode: elements alternate suppress/move via #1's orders, moves staggered across thinks) | NEW SYSTEM (medium, but only squad-tick logic on top of #1) | O(element) move orders per bound, staggered | moving as a unit · mutual suppression |

Deliberately NOT shortlisted: TLOU-scale continuous post evaluation (raycast/pathfind
budgets we cannot pay), full GOAP (our goal-FSM + stack already covers the individual layer;
F.E.A.R.'s own lesson is that the squad layer, not the planner, made the feel), Killzone
full visibility LUT (right idea, but bake-at-stamp cover fields are a later perf play, not a
feel play — flag for the terrain/worldgen council).

Dependency order: #2 alone is shippable today and attacks the named complaint ("they bounce
around too much"); #1 unlocks #3/#4/#5.
