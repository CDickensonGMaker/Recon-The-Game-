# RECONgame — complete 40-minute demo plan, targeted fixes and engineering handoff

Prepared September 13, 2026. Complete standalone plan for Claude Code.
(Saved into the repo 2026-09-13 evening from the Summoner's paste; the NPC first-batch council of
2026-09-13 was convened on §0B "A concrete first implementation batch" items 3–5 from this document.)

## 0. The release goal — this takes priority over the longer roadmap

The approved goal is a roughly 40-minute open-world FPS/RPG demo: 25 minutes of quests, patrols and relationship-building, followed by 15 minutes of firebase assault. The demo must be stable, coherent and polished enough for the owner to record and show while development of the full game continues.

Use this document in two layers:

- **Demo-critical:** N0–N4 for reported NPC failures, the field behavior needed on the demo route, reliable world lifecycle, safe tests, measured performance, and the art/animation contracts visible during normal play. Fix save-completion honesty if that path ships in the demo. Make only the architecture changes required to make these fixes durable.
- **Foundation/post-demo:** full world save-anywhere, richer relationships, broad quest infrastructure, province simulation, migration of every actor type, and extraction of every large script. Inspect their interfaces now; do not let their full implementation delay the demo unless a proven dependency requires it.

The demo uses the real GameFlow/world-build path. `scripts/levels/demo_game.gd` selects the 512 m demo world and owns the arc clock. Preserve that shared runtime while implementing the approved 25-minute introduction and 15-minute defense. Update dependent clocks, air-support beats, enemy reinforcement pacing, backstop behavior and timing tests together. End through a coherent assault resolution rather than cutting off active combat.

The demo also sets `EXCLUDE_SAVES = true` and documents sandboxed campaign writes. Verify the actual demo save controls/profile behavior, but **do not turn full open-world save-anywhere into a release prerequisite for a self-contained session**. The persistence findings remain important for the full game and for any saving the demo genuinely exposes.

### Immediate work order

1. Capture the exact rendered demo performance and NPC failures at a fixed revision.
2. Fix wrong-place activities, schedule boundaries, animation interruptions and invalid placement.
3. Fix occupancy and body-control handoffs where they cause stacking, roofs or frozen people.
4. Remove the largest measured frame-time spikes and fit the visible demo workload to the laptop.
5. Finish the player-visible art/animation defects along the playable area; validate their collision and navigation too.
6. Verify the complete normal-length demo and a final exported build while recording. Broaden the future-game work only after this gate is credible.

Section 9 defines the demo release/recording gate and section 10 gives the implementation test matrix. All longer work below is subordinate to this priority.

### 0A. Approved direction: 25 minutes of RPG introduction, 15 minutes of defense

**Confirmed direction:** the firebase assault is the main set piece and should last about 15 of the demo's roughly 40 minutes. The preceding 25 minutes contain quests, patrols and a taste of the FPS/RPG. In the larger game, the player starts relatively alone, earns individual squadmates' respect, and gains companions over time. Hearts and Minds is intended to influence enemy presence in the surrounding area.

**Ideas under consideration, not locked requirements:** witnessing a jet or Huey being shot down and receiving a resulting call; a small chain of quests whose final completion triggers the firebase assault. Implementing every crash type, a full recruitment system and a large quest framework is not implied. The design below is a recommendation for combining the goals into one achievable demo.

#### Recommended demo structure

| Approximate elapsed time | Experience | Purpose |
|---|---|---|
| 0–4 minutes | Arrive as a newcomer, meet a recognizable soldier, learn the immediate situation | Establish identity, controls and the possibility of earning trust |
| 4–11 minutes | First local patrol/help task, with an opportunity to earn cooperation | Introduce exploration, squad autonomy and local consequences |
| 11–21 minutes | Main outing and contact/rescue incident; a witnessed aircraft crash is one candidate | Demonstrate atmosphere, combat and a meaningful choice |
| 21–25 minutes | Resolve the outing, return, see a relationship response and prepare the firebase | Make the player's actions matter and position them for defense |
| 25–40 minutes | A sustained, phased firebase assault with quieter tactical intervals | Deliver the main combat set piece and earlier choices' payoff |
| Ending | Resolve the attack and show one concrete relationship/world consequence | Promise the larger RPG without pretending the whole progression is implemented |

Times are pacing targets, not invisible walls or exact deadlines. They include travel, combat, conversation and resupply rather than adding those costs afterward. Use two connected quest chunks and a return/preparation beat; prototype the shared route before increasing quest count. Do not fill the additional time with repeated fetch tasks or compulsory waiting.

Show a **small real sample of the full game's progression**. For example, one soldier begins as a reluctant temporary patrol partner; after seeing the player's actions, he chooses to accompany/help them. Another firebase soldier acknowledges the player during the defense. Distinguish a temporary ally, a garrison defender and a recruited companion in data and behavior. Do not equate everybody fighting beside the player with everybody joining their squad.

The demo should not begin with the full future squad already loyal if that hides the actual RPG premise. Equally, do not ask the player to earn a complete squad within this short introduction. One earned companion and another visible relationship response are a sufficient initial target.

#### Quest-triggered assault: use a world-state transition

Recommended flow:

```text
INTRO / AVAILABLE OUTING
 -> PATROL / EVENT
 -> OUTING RESOLVED (success, partial success or coherent failure)
 -> RETURN / DEBRIEF / PREPARATION
 -> ASSAULT ARMED
 -> WARNING / STAND-TO
 -> ATTACK PHASES
 -> RESOLUTION / AFTERMATH
```

The last quest can arm the assault. Begin it after the player returns or reaches a clearly communicated defense transition, giving time to reload and understand the situation. Do not spawn attackers on the quest reward click or require a dialog interaction while the player is already under fire.

A player can ignore a task, lose a rescued pilot, retreat or reach a site by another route. Define those branches so the demo cannot softlock. Recommended policy: an unsuccessful outing can still lead to return and defense, with different trust/intel/support outcomes. Whether the world eventually attacks while the player refuses to return is a product choice to prototype; a timeout must not teleport them home. Do not label the quest-triggered alternative fully decided until the owner chooses it.

The quest outcome is not necessarily the in-world cause of the enemy attack. It can be the pacing condition that reveals an already developing threat. Give the assault warning through observable world events or radio traffic so it feels like something happening to the firebase rather than a reward-screen trigger.

Use one assault start/finish authority and a unique occurrence ID. Quest completion, the old clock trigger and background night checks must not launch three attacks. Demo pacing may request a named scenario from the real siege system; it should not fork a second combat implementation.

#### Build fifteen minutes of fighting through phases, not extra hit points

Implement fifteen minutes of combat by revising phase progression, finite reserves, arrival cadence and support timing together. Inspect `demo_game.gd:59`, `:376` and `siege_director.gd:66–68` before changing them. Extending a timer alone does not create a sustained, enjoyable assault.

Proposed assault pacing, measured from attack start:

| Phase | Approximate duration | Tactical change |
|---|---|---|
| Probe and locate pressure | 2–3 minutes | Threat direction becomes readable; guards engage; player chooses a position |
| Main push | 4–5 minutes | Sustained pressure with staggered arrivals, distinct firing lanes and supporting roles |
| Local crisis and recovery | 3–4 minutes | A threatened section, casualty, ammunition problem or breach creates a reason to move; short lulls allow recovery |
| Final commitment and resolution | 3–4 minutes | Finite remaining reserves commit; enemy breaks/withdraws or defense reaches its failure outcome |

These ranges are tuning proposals. Preserve lethal weapons and responsive soldiers. Do not stretch the fight by making enemies spongy, holding one inaccessible enemy alive, or making a won battle wait for a timer. A strong defense can finish somewhat early; a weak defense can lose. The target is a reliably paced encounter, not a forced minimum duration at any cost.

Separate **total committed enemy reserve**, **materialized population**, **nearby expensive thinkers**, **simultaneous firing pressure** and **arrival cadence**. These are different budgets. A longer battle can reuse a bounded active population as finite reinforcements physically arrive. Do not assume tripling duration requires tripling actors on screen.

Record reserve remaining, entering/in-contact/withdrawing counts, spawn backlog and legitimate win/loss conditions. A distant path-stuck actor must not prevent resolution indefinitely. Keep spawn/reinforcement entrances outside immediate observation where possible and on valid routes; do not pop enemies into visible cover.

Re-time support events around assault phases and actual pressure. Preserve readability and dangerous-close rules; do not turn the finale into an uninterrupted effects benchmark. Recompute day/night acceleration so the attack remains at the intended light level and does not cross midnight unexpectedly, reset support, reroll a second siege or raise the sun mid-fight. Update the normal and stress-mode timing tests intentionally.

#### A witnessed crash can introduce several systems at once

Keep this optional until the basic demo is stable. If selected, build one aircraft/event variant well:

1. A real visible aircraft event occurs within an observable, plausible part of the world.
2. Its downing creates one persistent incident ID with a crash location, survivor state and response state.
3. A believable source reports it; the call references that actual incident rather than a disconnected marker.
4. The player can investigate, help, disengage or arrive too late. The chosen outcome has a small visible consequence.
5. The same survivor persists through rescue/return; no separate duplicate person appears for the quest completion.

Technical scope includes a traversable crash-site choice, safe survivor placement, aircraft-to-wreck handoff, fire/collision boundaries, radio deduplication and task cancellation. Prototype with the already supported aircraft/wreck assets. Do not require both a jet and Huey or a complete systemic aircraft-damage simulation to demonstrate this beat.

#### Keep personal trust, Hearts and Minds, and enemy pressure distinct

The player's relationship with one soldier is not the same variable as local civilian support or enemy military capacity. Proposed responsibilities:

- **Individual trust:** what that person experienced or credibly learned about the player's conduct; affects willingness to accompany, help and share information.
- **Hearts and Minds / local support:** place-level relations, cooperation, warnings, access and local intelligence. It can influence enemy recruitment/support and encounter conditions over time.
- **Enemy pressure/resources:** operational manpower, supply, alerts and current commitments. These determine what forces can plausibly arrive.

Avoid a single global score that instantly spawns enemies when it falls or despawns them when it rises. Apply bounded, legible changes to future encounter budgets, reinforcement delays, warning quality or routes. Existing enemies remain coherent people. A friendly village can still be near hostile forces; civilian support and military presence need not be exact opposites.

For the demo, allow the first outing to affect one or two understandable assault conditions, such as earlier warning, a recovered ally, a prepared position or modest reinforcement pressure. Keep the centerpiece viable across outcomes. The demo can start with an authored enemy attack already committed, while local support influences its conditions. In the full world, the same system can have broader effects on whether attacks develop at all.

**Current source check:** `CampaignState` has persistent `threat_level`, temporary threat modifiers, hidden player reputation and `effective_threat()` (`campaign_state.gd:207–251`). `SiegeDirector` uses `threat_label()` when deciding background night-attack chances (`siege_director.gd:256`, `:283`); FieldDirector also reads that label. The inspected `scripts` search did not identify a dedicated Hearts-and-Minds/allegiance implementation beyond a registry comment, or establish that this existing threat value directly controls area enemy population. Do not claim the desired system is fully wired from its name. Audit the remaining data/call sites, then identify the intended owner and connect specific consumers with tests.

Trust and local support should consume factual event outcomes with stable IDs. The same rescue cannot pay trust or change pressure twice after a reload. Participation/observation matters; do not give every squadmate identical instant respect for an event they could not know about. A small curated rule set is sufficient for the demo; leave a deep social simulator for the full game.

#### Additional acceptance checks for the revised demo

- Approximately 25 minutes of introductory quest/patrol play and 15 minutes of defense, measured across ordinary playthroughs rather than only an accelerated harness.
- Start with the intended small/temporary ally presence; demonstrate at least one earned change in a named person's behavior.
- Completing, failing or abandoning the outing does not dead-end the demo; each defined branch reaches a coherent continuation.
- The assault starts and resolves once; old clock/night/quest triggers cannot overlap.
- The fifteen-minute attack stays within the measured population and frame-time budget, including recording.
- Mid-assault lulls have tactical use; no forced waiting for unreachable enemies or a finish timer.
- A Hearts and Minds outcome changes its intended consumer without duplicating rewards, instantly deleting enemies or accidentally cancelling the demo's central set piece.
- If the crash event ships, aircraft, wreck, survivor, call and outcome all refer to one incident.

### 0B. Complete production plan for the approved demo

Read this section as the implementation roadmap. Sections 4–8 supply the technical findings and architecture; sections 9–10 define release evidence. The forty-minute structure is approved. Quest names, exact characters, crash choice, numbers and relationship outcomes below are recommended design, not additional owner decisions.

#### Demo scope and playable promise

Build one coherent, open playable area around the firebase using the existing world-generation path. The player arrives with limited standing, forms an initial bond through useful actions, experiences a consequential outing and defends the base alongside people who now know them.

Minimum content target:

- One firebase with a small believable population, functional exits and several clearly used activity stations.
- Two connected quest chunks, including one substantial outing/contact. Both use existing places and systems where possible.
- One potential earned companion, one other relationship contact, and distinguishable ambient defenders. Avoid requiring a large dialogue cast.
- One small Hearts and Minds consequence and one individual-trust consequence that the player can perceive.
- A phased fifteen-minute assault, a coherent failure branch and a resolved aftermath.
- A tested quality profile on the working laptop, with a complete captured run of the exported build.

Exclude from this milestone unless required by the chosen slice: full province simulation, a large faction/recruitment tree, every weapon and aircraft, all buildings populated at maximum density, and complete save-anywhere simulation. Retain extension points through stable IDs and explicit results. Do not build unused framework machinery before its first consumer.

#### Quest chunk 1 — become useful, approximately seven minutes after the introduction

**Recommended premise:** a short local patrol/help assignment introduces one named soldier and a nearby place. Choose a task supported by current content, such as checking a reported route, helping recover an interrupted supply delivery or investigating a local report. Do not implement all examples.

Gameplay sequence: receive the request -> choose an approach -> reach the actual site -> investigate or resolve a small problem -> report or communicate the result. Teach movement, interaction, observation and teammate intent during play. This task need not contain a major firefight.

Relationship purpose: the named soldier initially assists because of duty or a temporary assignment. A successful or responsible resolution gives a specific reason to trust the player. Trust is tied to what happened, not a generic quest-complete pop-up.

Hearts and Minds purpose: introduce a local contact or piece of information whose usefulness can later be recognized. If a civilian interaction is not ready, keep this consequence modest and clearly label the broader system as incomplete. Do not fabricate a full regional simulation behind a single scripted result.

Failure/choice handling: the player can take another route, arrive late, withdraw or deliver partial information. Keep the world moving and let the main outing become available through a coherent alternative. Avoid an essential item disappearing permanently under geometry and blocking the entire demo.

**Acceptance:** a fresh player can understand what they can do without a developer explanation; the temporary ally remains identifiable; one factual outcome is recorded once; the route is playable in both directions with correct NPC spacing and navigation.

#### Quest chunk 2 — the main outing, approximately ten minutes

**Preferred candidate:** witness a downing, receive the call and investigate the actual crash incident. Keep the aircraft choice provisional. Evaluate existing jet/Huey flight, wreck, survivor and animation assets, then select the lowest-risk complete variant.

The chain must hold together: an aircraft is visibly in trouble -> it goes down at a valid reachable site -> a call refers to that location -> the player encounters the same wreck and survivor -> a resolution changes the return to base. A trail of smoke, an imperfect report or an existing map affordance can provide direction without inventing a separate quest-marker system.

Create choices from situation and route: approach quickly through exposed ground, take a safer route, help the survivor under pressure, secure the immediate threat, or withdraw. The same event can support more than one outcome without requiring a large branching conversation system.

Keep combat readable and budgeted. The point is to demonstrate gunplay and squad cooperation, not to exhaust the player before the main assault. Use a small finite opposition, a reachable survivor and short enough travel that the whole outing fits the target. Rescue should not require unbuilt carrying/escort mechanics if an existing tested extraction interaction can serve.

**Fallback if aircraft integration is too costly:** discover an existing downed-aircraft incident through a credible report, or use a pinned friendly patrol. A witnessed crash is a candidate feature; it must not delay the demo while roof spawning and basic combat remain broken. Preserve the same incident/outcome contract so the richer presentation can replace the simpler entry later.

**Acceptance:** incident fires once; no duplicate wreck/survivor/call; the site is reachable; abandoning or losing the survivor has a defined outcome; success gives a concrete personal or defense benefit without automatically recruiting the rescued pilot as an infantry squadmate.

#### Return/preparation — approximately four minutes

The player returns through the same world and sees a consequence. A soldier recognizes what happened, an available companion explicitly offers to accompany them, a casualty reaches the infirmary, or useful intelligence changes the defense warning. Choose outcomes that the slice actually simulates.

Provide enough time and readable access to ammunition, treatment and a defensive position. Warning escalates through the existing radio/world channels. The player should understand the threat direction and their available options without being forced to one turret or exact sandbag.

The recommended final task arms the assault once the outing has resolved. A return/preparation transition starts the warning and attack. This preserves the proposed quest linkage while keeping one siege authority. If the owner ultimately prefers a world-clock attack, keep that as one configuration of the same transition, not a second competing trigger.

**Acceptance:** good and poor outing outcomes both reach a coherent defense opportunity; no forced teleport; no reward conversation blocks player control during combat; trust, incident and pressure effects are idempotent.

#### The assault and its payoff

Use the phase design in section 0A. The player should make meaningful local decisions: hold a useful firing position, cover another soldier, respond to a threatened section, get ammunition during a lull, or help stabilize a local crisis. Start with two or three reliable choices rather than many fragile scripted objectives.

Payoffs should be visible and bounded:

| Earlier action | Possible defense payoff | Implementation boundary |
|---|---|---|
| Earned a soldier's trust | They willingly accompany/support the player | Companion status and existing squad intent, not teleporting assistance |
| Obtained credible local information | Earlier warning or a more useful initial threat report | Knowledge/event data; no perfect enemy tracking |
| Recovered personnel | A living named person appears in the appropriate safe/base role | Same person record; wounded people do not instantly become healthy fighters |
| Completed a supply/help task | A prepared supply point or limited additional resource is available | One unique task consequence; no duplicate inventory payout |
| Failed or abandoned the outing | Fewer advantages or a different personal response | The assault remains playable; avoid a cascading unavoidable defeat |

The ending references a small number of true outcomes: who survived, who helped, and what the player changed. Avoid claiming a persistent full-game campaign if the demo remains self-contained. It can demonstrate persistent relationships within the session while preparing the schema for the full game.

#### Hearts and Minds: a demo-sized implementation

First trace existing threat/reputation producers and consumers; do not create a duplicate global system. Define a small typed event result with an occurrence ID, location ID, involved person IDs, relevant witnesses and consequence entries. Apply each consequence once through its responsible subsystem.

For this demo, choose at most two local-support effects and one personal-trust transition. For example, a local contact improves warning quality, and responsible completion earns a soldier's willingness to accompany the player. If enemy pressure also changes, tune a modest bounded reserve/cadence adjustment while leaving the core assault budget predictable.

For the full game, extend the same separation toward place-level support, enemy logistics/manpower and individual relationships. Changes affect future decisions and allocations; avoid popping existing soldiers out of existence. Clamp feedback loops so success does not erase all encounters and one bad result does not produce endless maximum-strength attacks.

**Acceptance:** event deduplication, locality, eligibility and outcome-consumer tests pass; neutral/good/poor outcomes stay within the demo's performance and difficulty envelope; the player can perceive a consequence without exposing a mandatory numeric reputation meter.

#### Ordered work packages

| Package | Deliverable | Targeted work | Gate before moving on |
|---|---|---|---|
| D0 — Baseline | Reproducible demo run and ranked blockers | G0, N0; renderer/profile, safe tests, actor traces | Know which current source causes each observed defect and where frame time is spent |
| D1 — Stable people | Correct floors, places, animation and occupancy | F01–F09; N1–N3 | A real firebase walk shows no repeated roof/stack/work-location failures |
| D2 — Reliable handoffs | Stable person identity and one body owner | F10–F11; N4; lifecycle parts of G1/G6 | Alarm, stand-down, boarding and wake cannot duplicate/reset/freeze people |
| D3 — Playable outing | One complete temporary-ally/quest route with one factual outcome | G4/G7; N5; small person/trust contract | Fresh player completes or fails it coherently; combat and interactions remain reliable |
| D4 — Consequence and second chunk | Main incident, return and preparation | Incident transaction, limited local support and relationship payoff | All selected outcomes lead coherently into defense; no softlocks or double rewards |
| D5 — Fifteen-minute assault | Phases, finite reserves, support timing and resolution | Existing SiegeDirector/SimClock/DemoGame; G5/G6 | Full-length attack resolves and stays inside active-population/pressure budgets |
| D6 — Whole-route optimization | Measured frame pacing in normal and recorded runs | G8; optimize top bottlenecks discovered since D0 | Selected target profile survives quests, transitions and finale |
| D7 — Presentation finish | Demo-visible art, transitions, audio and UI polish | G9 and section 9.4; existing art pipeline | Ordinary close inspection has no blocker-level placeholder/integration errors |
| D8 — Release candidate | Exported approximately forty-minute playable demo | Sections 9–10, full regression and capture | Owner-verified ordinary run, alternate route and recording check |

Performance instrumentation stays active throughout; D6 is the final integrated optimization pass, not permission to ignore catastrophic stutters until then. Art can progress on validated assets while code work proceeds, but changing shared markers/collision requires coordination and revalidation. Do not promise dates before D0 exposes the workload and D3 measures real quest/travel duration.

#### A concrete first implementation batch

Start Claude with a bounded batch rather than "finish the game":

1. Re-establish current source/profile baseline and safe test launching.
2. Add actor provenance/ownership inspection sufficient to capture one roof, overlap and wrong-activity case.
3. Fix cooking's target mapping, fractional schedule updates and stale animation callback/cache behavior.
4. Validate placement for the captured failing path and add a failing-before/passing-after integration check.
5. Replace generic jitter with exclusive placement for the first representative furniture/work station.
6. Walk and capture the same firebase route; compare behavior and frame times; record remaining failures.

Then continue D1/D2 before building quest actors that depend on those contracts. This batch produces visible progress and tests the proposed architecture against real defects.

#### Timing, failure and release rules

Approximately forty minutes is a normal-player target, not a hard gate. A skilled player may finish sooner; a curious player may take longer. Measure actual intro, travel, interaction, quest combat, preparation and assault durations separately. Adjust route/content density before adding timer locks. Include the aftermath in the intended overall experience without stretching the last firefight arbitrarily.

Test success, partial failure, death/retry and ignored-task paths. Demo checkpoints, if needed, should restore the deliberately supported snapshot and use the same incident/person/outcome identities. Do not quietly promise general save-anywhere. If the current self-contained demo restarts instead, make that behavior clear and judge whether a forty-minute session needs a limited safe checkpoint before defense.

The forty-minute session requires endurance testing for accumulated actors/effects, schedule transitions, state changes and player loss. Validate the backstop and time-of-day calculations. Record a full normal-length exported run; a shortened stress test cannot validate this accumulation.

#### What remains deliberately provisional

Exact quest fiction, aircraft choice and whether the final task or the world clock is the final assault trigger remain design choices. Prototype the recommended task-to-return-to-warning flow using simple content first. Stable IDs, outcomes, cancellation, performance and navigation contracts do not depend on those fiction choices and can proceed now.

## 1. Start here, Claude

The owner reports the same problems across playthroughs: soldiers appear on building roofs and remain there; friendly groups perform the same irrelevant animation in inappropriate places; people stand inside one another. Fix these as connected world-simulation problems. Then strengthen the rest of the game without destabilizing working systems.

Work in `C:\Users\caleb\recongame`. This is the Vietnam FPS/RPG project, not BP RTS Dark Shadows, RECON's old source projects, or a request to make an RTS. Preserve the player's role as a soldier inside an autonomous squad. Build believable people with places, responsibilities, reactions and persistent consequences.

This handoff authorizes an implementation sequence, not an instruction to rewrite the entire game at once. Re-read current source before each task; another session is actively working in this repository. Preserve its changes. Start with the smallest complete vertical slice that fixes the reported NPC failures. Expand only after that slice passes its regression gates.

### Audit baseline and limits

- Reviewed checkout: `daf621cd12c18afa0bb85eb0be36237cf1f4d2ff`, with uncommitted art, production-document and gore-tool work. More art files appeared while this review ran. This was a live checkout, not a frozen release.
- Source review was deepest in friendly actors, civilians, schedules, placement, navigation, garrison transitions and animation selection. The broader review sampled saving/loading, lifecycle, missions, player/UI entry points, combat/pooling, vehicle seating, performance architecture and tests. It was not an exhaustive line-by-line audit of every script or asset.
- No game source was edited. No rendered playthrough was performed in this review. The owner's reported symptoms are the playthrough evidence; exact offending actors and spawn paths still need runtime traces.
- Godot available locally: `C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe`. Project rules specify Godot 4.7. Use the matching console executable for the existing suite if available.
- Current desktop rendering setting is **Mobile**, `project.godot:331`. Do not repeat the older recommendation to switch from Forward+. The September 11 tracking entry reports a historical 29.4 to 40.9 FPS comparison; that was not reproduced here and does not establish current steady performance.
- The hardware target is the laptop's Intel UHD, i7-10850H and approximately 16 GB RAM. The owner has ruled out further broken NVIDIA-driver repair. Optimize for the working hardware.
- The earlier conversation asked for solid 60 FPS; a later local tracking entry records a 45–59 FPS usability target. Report both 16.67 ms and 22.22 ms frame-budget results. Do not silently resolve that product-target difference by declaring a lower number a 60 FPS success.

### Evidence vocabulary

**Observed by owner:** recurring in playthroughs. **Source-confirmed:** the current function does the described thing. **Inferred consequence:** a plausible or logically implied failure that still needs an integrated reproduction. **Proposed:** a design or engineering improvement. **Historical:** a dated repository measurement that was not repeated here.

Line numbers below refer to the reviewed checkout. Paths within this document are relative to the project root unless explicitly absolute. Locate functions by name if lines move.

### Read the project rules, but resolve their contradictions

Read `AGENTS.md`, `CLAUDE.md`, `production/GAME_GUIDE.md`, relevant `production/adr/` decisions, and `production/bible/`. They contain conflicting descriptions of task tracking, older mission loops, and newer demo/open-patrol scope. `AGENTS.md` requires beads; `CLAUDE.md` explicitly retires beads; the guide contains both historical beads language and later retirement language. Do not let this documentation conflict divert the NPC repair into tool migration. Establish which current owner decisions apply and correct stale descriptions when touching their subject.

Authored quest moments may occur within an open world the player can leave or approach another way, consistent with `production/GAME_GUIDE.md`. The demo should communicate the FPS/RPG direction through a small genuine relationship change and visible consequences.

Scope implementation against the approved demo, then carry proven architecture to the larger patrol world. Code tests support the release decision; they do not substitute for the owner's playthrough verification.

## 2. The main diagnosis

The game already has behavior trees, military schedules, navigation, animation variants and recovery logic. Its central weakness is that these systems do not consistently agree on **who the person is, which place they own, whether they reached it, and who currently controls their body**.

A schedule can request cooking but resolve a home-adjacent destination. A general-purpose jitter can shift someone away from a precise work socket. A navigation helper can return the input unchanged without saying whether it was valid or unsupported. A crew driver can capture someone using horizontal distance alone and snap them to a marker. An animation chooser can cache a broad posture while its meaningful action has changed. Two distance systems can disable or reposition the same actor.

Adding more clips to those pathways would make the same mistakes more varied. The first improvement should be a reliable chain:

```text
Persistent person
  -> activity intent
  -> compatible, reserved place
  -> reachable approach
  -> physical arrival and alignment
  -> activity performance
  -> interruption / completion / release
```

Every transition needs an explicit result. "No valid place" must mean wait, choose another compatible task, or report failure. It must not mean perform the requested work wherever the actor happens to stand.

## 3. Preserve the improvements already present

Preserve these existing implementations while addressing their remaining gaps:

| Existing system | Current evidence | What it still needs |
|---|---|---|
| Interior-aware floor query | `scripts/levels/game_world.gd:448`, `floor_y` | Surface identity, failure reporting and safe fallback policy |
| Roof filtering during nav bake | `scripts/world/nav_baker.gd:619`, `:826`, `:908` | Coverage of new assets and semantic distinction between roofs and usable decks |
| Shared navigation helper | `scripts/ai/nav_router.gd:63`, `:85` | Typed status, revision invalidation and destination precision |
| Twelve civilian actions dispatched through a BT | `scripts/world/civilian.gd:1137`, `:1205` | Correct destinations, timing and execution state |
| Work actions now walk before settling | `scripts/world/civilian.gd:1439` | Actual interaction slots instead of universal jitter |
| Per-person animation variation and loop desynchronization | `scripts/world/civilian.gd:617`; `scripts/visuals/model_actor.gd:1246` | Semantic animation keys, consistent application and safe asynchronous transitions |
| Work points dealt without replacement in villages | `scripts/missions/mission_generator.gd:1316` | Occupation compatibility and lifecycle-wide reservations |
| Garrison combat promotion and stand-down | `scripts/allies/garrison_defender.gd:26`, `:118` | Preserve person state and exclusively transfer body ownership |
| Shared combat cover claims and ally spacing | `scripts/allies/ally_base.gd:2007`, `:2407` | Broader idle/civilian spacing and exact-overlap handling |
| Helicopter seat/socket system | `scripts/vehicles/seat_system.gd` | Integration with a single actor-control and placement contract |
| Mission cleanup entry point | `scripts/main/mission_scope.gd:30`; `scripts/main/game_flow.gd:407` | Coverage for new reservations, callbacks and asynchronous work |
| Save schema, backup loading, future-version refusal | `scripts/data/save_data.gd`; `scripts/autoload/save_manager.gd:225` | Full promised world-state scope and reliable save completion |
| AI tiers, paced assaults, idle-body movement throttling | `scripts/ai/ai_lod.gd`; `scripts/world/civilian.gd:478`; `scripts/allies/ally_base.gd:877` | Coordinated ownership and measured tail latency |
| Mobile renderer and reused squad HUD labels | `project.godot:331`; `scripts/ui/mission_hud.gd:261` | Current integrated performance and visual verification |

## 4. Findings to turn into implementation work

### F01 — Roof prevention is still a height guess with an unsafe fallback

**Source-confirmed:** `game_world.gd:448–457` casts downward from `at.y + 0.4`. It returns the first world collision and otherwise falls back to `surface_y`. Neither branch proves that the hit is the intended floor rather than a roof, canopy, prop or different storey. A supplied Y already above a roof can still hit that roof. Making the ray longer does not solve semantic ambiguity.

`TerrainWatchdog` calls this function both when waking a body and when testing a fall-through (`scripts/missions/terrain_watchdog.gd:69–88`). A body already standing on a roof has support under its feet and is not necessarily below the reported ground, so this watchdog does not establish a recovery route from an erroneous rooftop placement.

`Civilian.place_for_current_hour` assigns the resolved destination directly (`civilian.gd:1341`). `Civilian.spawn` and `AllyBase.spawn_ally` also trust supplied positions (`civilian.gd:398`; `ally_base.gd:2579`). `FriendlyPatrolGroup._spawn_men` samples an XZ spread while keeping the group's Y (`friendly_patrol_group.gd:35`). This is another caller to validate, not a proven instance of the owner's exact roof failure.

**Needed:** explicit placement intent, floor/support identity, capsule clearance, bounded correction, navigation readiness and success/failure. Validate every spawn, wake, role swap, seat exit and recovery through the same policy. Keep legitimate tower decks, helipads, stairs, bunkers and interior floors usable. A global "NPCs must be at terrain height" rule would break the firebase.

### F02 — Cooking and other activities are sent to the wrong type of place

**Source-confirmed:** `civilian.gd:1355–1366` only uses `working_point_pos` for `walk_paddy`, `work` and `fish`. `cook`, `sit`, `sleep`, `rest` and `talk` fall back to `home` plus unseeded random XZ offsets. `_bt_walk_fire` and `_bt_walk_market` invent fixed offsets from home (`:1399`, `:1408`) rather than resolving actual fire/market locations.

For a `mess_cook`, the schedule genuinely selects `cook`, but the target resolver does not select the stove work point. `_bt_settle` can correctly arrive at the wrong location and `_play_garrison` can then play a cooking clip there. This is a strong source-level explanation for the owner's "wrong spot or area" symptom.

**Needed:** resolve typed locations from the action and the person's role. A cook needs a compatible cooking slot; a sleeper needs a bed or explicitly permitted ground-rest location; a diner needs a serving/seat sequence; a fisherman needs an appropriate waterside station. Missing location must not retain the work label with an unrelated destination.

### F03 — Fractional schedules are evaluated only when the integer hour changes

**Source-confirmed:** `_bt_tick` checks `int(hour) != int(last_hour)` (`civilian.gd:1223`). `CivilianSchedules.action_for` contains fractional windows, including meal sittings starting at 19.5, 19.9 and 20.3 for 0.4 hours. A regularly ticking actor can miss a whole sitting or keep an action beyond its window. This affects schedules with 04:30, 05:30, 12:45 and other boundaries too.

The current BT test samples different hours; it does not traverse all fractional boundaries within one hour. Calling `action_for` directly can pass while the live caller still caches the wrong result.

**Needed:** use next-boundary scheduling or a modest staggered cadence that evaluates actual simulation time. Define clock jumps, pause, midnight and compressed time. Use one resolved activity revision so navigation and animation change together.

### F04 — Random offsets are being used in place of occupancy

**Source-confirmed:** `_bt_settle` adds a 1.5 m radius name-hashed offset to every nonzero destination, then projects it toward the mesh (`civilian.gd:1426–1456`). This is applied to activities that need exact prop alignment as well as open-ground activities. A 1.5 m displacement can move a person off a chair, away from a stove or beyond a shelter; nav projection can collapse different offsets back to the same point.

The spawn planners also distribute people around raw post positions (`mission_generator.gd:1114–1128` and `_build_firebase_garrison`). The assignment and final settling offsets are different stages. They do not reserve the final positions atomically.

**Needed:** one person per exclusive slot; shared activities get several authored or validated participant slots. Only flexible areas may generate spread positions, and those positions must be collision-checked and reserved. Do not apply generic jitter to furniture sockets, weapon stations or beds.

### F05 — Bodies do not generally keep other ambient bodies out

**Source-confirmed:** both civilian and ally factories use world-only collision masks and disable navigation avoidance (`civilian.gd:361`, `:390`; `ally_base.gd:2573–2577`). The civilian movement function has no neighborhood-separation pass. Ally combat separation scans allies and the player (`ally_base.gd:2407`) rather than every ambient person. Exact coincident ally positions produce no ally-to-ally push because the branch requires `d > 0.01`.

Friendly patrol men are all given the same route target (`friendly_patrol_group.gd:56`, `:92`). Existing follow spacing and combat cover claims are useful but do not establish general camp circulation or a queue.

**Needed:** exclusive destination capacity plus local movement spacing, door/queue rules and a deterministic tie-break for exact coincidence. Do not simply turn on mutual rigid collision for every actor; that can replace overlap with doorway jams and increase physics cost. Benchmark bounded local avoidance, preserve collision/hitzone semantics, and integrate only one final movement result.

### F06 — Animation selection loses the action's meaning

**Source-confirmed:** `_animate` converts multiple actions into broad labels such as `seated` and `stooped`, then returns when that label equals `_last_clip` (`civilian.gd:591–616`). A stationary change from work to cook, or rest to talk, can keep the previous animation because the coarse label did not change.

`_play_garrison` often selects work by occupation and coarse pose: a medic who is not walking/running can request `medic_treat_give` without a current patient check (`:720–727`). A quartermaster's walking branch requests `cargo_carry` (`:849`) without establishing a carrying task in that branch. A chosen fallback can preserve an inappropriate prop-dependent gesture.

In the village branch, action-specific early returns (`:635–646`) bypass the later `desync_loop` call (`:666`). The existing desynchronization therefore does not cover every action path. Position-derived integer seeds can also be identical for nearby spawn points (`:365`), so deterministic does not automatically mean distinct.

**Needed:** cache by activity instance/revision, execution phase, movement/posture, equipment and interruption state. Select clips from the executed activity, not merely occupation. Require contextual props/partners. Apply phase variation at the performance entry point. Preserve deliberate synchronized weapon crews; do not randomly desynchronize a loader from the firing cycle.

### F07 — A delayed animation can overwrite a later behavior

**Source-confirmed:** the chow sit-down timer only checks actor validity before playing its captured table animation (`civilian.gd:839–845`). It does not verify that the person still owns that seat, is still eating, or has the same action generation. A living actor can have begun walking or entered a threat response before the callback fires.

**Needed:** cancellable activity transitions or generation-token guards. A callback may act only when its person, world generation, activity and phase still match. On alarm, movement, injury, death, boarding or unload, invalidate pending ambient transitions and release associated props/slots.

### F08 — Navigation returns a vector where callers need a result

**Source-confirmed:** `NavRouter.nearest_mesh_point` returns the supplied point unchanged for no agent, disabled nav, uncovered region, unsynchronized map or excessive correction (`nav_router.gd:63`). It can also return an unchanged point because the point is valid. These outcomes are indistinguishable to callers.

Target/self/snap caches are invalidated by position changes, not a recorded navigation-map revision. Small target changes below the cache threshold can reuse another nearby point. `step` only restakes the agent target when the squared distance exceeds 9.0 (`:117`), a 3 m threshold that deserves particular testing against submeter work-slot arrival. Its final failure behavior is direct steering, and the off-mesh test deliberately discards Y (`:142`). That may be acceptable in open terrain but cannot prove a same-storey interaction or recover every vertically misplaced actor.

**Needed:** distinguish waiting-for-map, valid route, arrived, partial path, blocked, uncovered region and invalid destination. Keep the current open-terrain behavior only under an explicit traversable-ground policy. Do not turn every navigation failure into a straight line through buildings. Invalidate caches on region generation and target identity changes. Use precise target handling for the final approach without requesting a new global path every frame.

### F09 — Two distance systems compete over the same civilians

**Source-confirmed:** civilians have 80/300 m tiers with wake placement (`civilian.gd:1299`). `TerrainWatchdog` independently disables their physics and hides them past 240 m, resuming below 210 m (`terrain_watchdog.gd:9–10`, `:51–74`). In normal outward travel, the external suspension can prevent the civilian from ever reaching its own 300 m FAR transition. A test that directly forces FAR does not test this integrated path.

The watchdog does not consult the civilian's `puppet`/crew-driver ownership before its distance wake and floor adjustment. Crew, seat and litter systems have their own process/position rules. That is a conflict risk, not proof that every seated actor is currently broken.

**Needed:** one simulation-activation policy, explicit suspension reasons and a single wake transaction. Seat ownership is not distance suspension. A wounded patient is not an idle actor. Reconcile a distant schedule before showing a body, validate its slot and footing, and avoid visible teleports, including through binoculars or across an open sightline.

### F10 — Garrison role swaps do not preserve a whole person

**Source-confirmed:** `GarrisonDefender.promote` carries occupation, model, role and digging permission, then generates a fresh `SquadRoster` member from position. `stand_down` creates a fresh Civilian with a post and role. Neither function transfers a full persistent identity, original home, schedule reservation, health/injury state and appearance seed (`garrison_defender.gd:26`, `:118`).

Promotion unregisters and disables physics before `queue_free`, but it does not explicitly disable all old collision/hitzone receivers in this path. The comment's claim of synchronous teardown is stronger than what deferred deletion guarantees. Verify the overlap window with an actual damage/registry probe before reporting a reproduced double-hit.

**Needed:** first patch the existing 1:1 swap with a complete typed snapshot and explicit transfer. Longer term, keep a persistent person record and preferably switch control mode on one body. A rename or job change must not heal, duplicate, replace or reroll a person. Keep existing AllyBase combat behavior rather than inventing a third combat brain.

### F11 — Gun-crew capture checks horizontal proximity, then teleports

**Source-confirmed:** `_eligible` uses XZ distance to the work point; `_capture` sets `puppet`, clears velocity and writes the raw work point (`gun_crew_performance.gd:187–204`). It does not itself establish same floor, vertical proximity, clear capsule volume, correct facing or a reached approach path.

**Needed:** use the same slot acquisition and arrival contract as other interactions. Capture only after a valid physical approach. A crewman directly above a station must not be considered ready. Release must restore the right locomotion/animation state and invalidate the prior performance token.

### F12 — Current probes do not prove the player's reported experience

The roof probe is a useful starting point, not a comprehensive acceptance gate. It samples once after 40 seconds, uses geometric/name heuristics, ignores actors without a floor hit, and does not follow shift changes, wakeups, role swaps or returning aircraft (`tools/probe_roof_spawn.gd:10`, `:41`, `:71`). It does not test overlap or purposeful activities.

The schedule-placement probe instantiates minimal civilians without the real firebase, physics geometry, work props or external watchdog. It accepts a broad distance band near home. The BT probe proves dispatch and an hourly sweep, not valid activity locations.

**Needed:** preserve these unit checks, then add scenario-driven integration checks with negative controls and rendered inspection. A test must observe the failure it claims to prevent.

### F13 — Save success does not include successful final replacement

**Source-confirmed:** `SaveManager.save_game` writes a temporary file, schedules the swap, optionally waits, and returns true. `_swap_into_place` logs a final rename failure but does not return a result to that caller; earlier remove/rename return values are also unchecked (`save_manager.gd:117–173`). A synchronous manual save can therefore report success even when the replacement did not succeed.

Backup loading and future-version rejection already exist. Preserve them. This finding is about completion/error propagation, not a claim that all saves are corrupt.

**Needed:** a save transaction with a result for each stage, a completion event for async writes, truthful UI and a recoverable previous save. Handle disk-full, denied writes, rename failures, quickload during autosave, process exit and consecutive saves. Test using disposable directories and injected failures.

### F14 — The slot schema does not yet capture a complete live world

**Source-confirmed:** `SaveData.mission` is an empty reserved dictionary (`scripts/data/save_data.gd:16`). `SaveManager.collect` fills campaign, hub, metadata and player but not live mission state (`save_manager.gd:175`). `apply` restores those sections, and player position restoration is conditioned on `context == "hub"` (`:253`, `:270`).

This is not sufficient evidence for faithful save-anywhere restoration of NPC identities, positions, wounds, active activities, dead people, queued encounters, vehicles, simulation time and terrain changes. Some durable consequences already live in CampaignState; audit those before adding duplicate fields. Trace what the active demo calls its save context before claiming exactly how a specific player's quicksave behaves.

**Needed:** a documented persistence contract and a real save/load vertical slice. Rebuild the deterministic base world, apply durable world/person state, reconcile activity reservations, then materialize safe actors. Do not serialize live Node references or ephemeral path state.

### F15 — Large scripts mix unrelated responsibilities

**Measured source sizes in this snapshot:** `enemy_base.gd` 3,786 lines, `site_planner.gd` 3,244, `ally_base.gd` 2,582, `player.gd` 2,229, `field_director.gd` 2,206, `civilian.gd` 1,491, `mission_generator.gd` 1,472 and `model_actor.gd` 1,384. Size alone is not a bug.

The actionable issue is responsibility coupling: Civilian includes identity selection, BT dispatch, schedule placement, navigation, threat reaction, props, animation and LOD; FieldDirector includes enemy lifecycle, escalation, support requests, targeting UI, patrol tasking and garrison transitions. Changes have a wide blast radius because their contracts live inside the same mutable object.

**Needed:** extract stable responsibilities around the repairs below, preserve existing call surfaces during each small migration, move their callers in the same change and remove replaced paths once no caller needs them. Do not spend a sprint splitting files without observable behavioral improvement.

## 5. Proposed architecture: practical boundaries, not a new engine

These names describe responsibilities. Reuse a suitable existing class when possible. Do not create a global manager for every noun. Prefer typed Resources/RefCounted values for data, a few world-owned services, and per-actor executors.

### 5.1 A persistent person separate from their current body

Create a small `NpcRecord` contract, or extend the existing roster representation with an equivalent contract:

```text
person_id                 stable across save/load and role changes
site_id / household_id / squad_id
faction, occupation, duty_assignment
appearance_seed, behavior_seed, model_id
home_slot_id, preferred_work_slot_ids
alive, health, injury state, equipment/ammunition
current_activity_id, activity_phase, relevant simulation timestamps
small factual memory / relationship references where gameplay uses them
```

Start by covering the fields lost in the current garrison swap. Avoid a deep personality simulator before identity and health persist correctly. Generate IDs from a stable site/population identity or a persisted allocator. Node names, instance IDs and rounded positions are not durable identities. Two people sharing an initial coordinate must remain two distinguishable people.

`AgentRegistry` should remain the live-node registry. A durable person registry is a different responsibility: it may hold records for people who are dead, away or not materialized. Do not replace the live arrays with persistent entries without auditing every combat consumer.

### 5.2 Placement validation owns the meaning of a location

Add an explicit `PlacementRequest` / `PlacementResult` boundary behind the current placement helpers:

```text
Request:
  person/body dimensions, placement purpose
  desired point, permitted support/surface classes
  expected site / room / storey / slot
  maximum lateral and vertical correction
  navigation-required flag, world/nav generation
  exclusions and reserved footprint

Result:
  VALID | WAITING_FOR_WORLD | WAITING_FOR_NAV | NO_SUPPORT
  | WRONG_SURFACE | BLOCKED | UNREACHABLE | OCCUPIED
  transform, support ID, slot ID, reason and correction distances
```

Validation sequence:

1. Resolve the authored marker through its actual parent transform. Distinguish a person-root marker from a furniture contact marker.
2. Confirm the relevant geometry is present and synchronized. Do not accept a missing collider as open space during load.
3. Find support compatible with the placement purpose and expected floor. Prefer semantic metadata on the asset/marker. Keep a measured compatibility layer for existing assets until migrated.
4. Check slope, headroom and the full body volume. Ignore the actor's own shapes but include occupied people through the occupancy service.
5. Where movement is required, verify an approach from an accessible point and an appropriate connected navigation component. Nearest polygon alone is insufficient.
6. Reserve the intended footprint, then commit the actor. A bounded failed search yields an explicit failure or retry, never an unchecked point.

Elevated tower guards are allowed when assigned a valid deck and an accessible route or explicit spawn-only station. Ordinary camp workers are not allowed on a roof merely because it is flat. Ground-rest tasks can use terrain; eating at a table requires that table's slot.

Use the same validator for placement at initial build, late reinforcements, restored saves, wakeup, seat exits, garrison transitions and unstick recovery. Each caller supplies a different purpose; they do not all use the same top-down ray.

### 5.3 The world offers usable activity slots

An `ActivitySlot` or equivalent resource should contain:

| Field | Purpose |
|---|---|
| Stable slot ID and owner object/site | Survive streaming and identify destroyed props |
| Activity tags and compatible roles | Cook at a stove; treat at a patient; watch from a post |
| Approach point and interaction transform | Reach the place before aligning to its prop |
| Floor/support identity | Prevent upstairs/downstairs false arrival |
| Body clearance / allowed posture | Fit a person rather than just a point |
| Capacity or participant slots | One chair occupant; several distinct conversation positions |
| Required props / partner roles | Carrying needs cargo; treatment needs a patient |
| Entry, loop, exit clips or performance definition | Keep geometry and animation aligned |
| Interruption policy and disabled/destroyed state | Safe response to alarm, movement or world changes |

Use a world-owned reservation broker with claim, renew/confirm, release and invalidation. Claims include person ID and world generation. A timeout handles abandoned approaches, but healthy seated actors must not lose their seats simply because their update rate is low. Release on death, cancelled activity, prop removal, transfer, unload and world reset.

Existing cover claims, mortar claims and SeatSystem contain domain rules worth retaining. Introduce a shared ownership interface or adapter; do not immediately rewrite every specialized system into a universal interaction framework. Migrate only where the contract fixes a demonstrated gap.

### 5.4 Activity execution is a small explicit state machine

```text
REQUEST -> RESERVE -> APPROACH -> ALIGN -> ENTER -> PERFORM -> EXIT -> RELEASE
                         \          any interrupt -> CANCEL / SUSPEND
                          -> BLOCKED -> retry / alternate / safe idle
```

`scheduled_action` is intention. `executed_activity` is what the actor is physically doing. Keep both for diagnostics. The animation layer reads execution.

Arrival requires horizontal distance, vertical agreement, adequate facing and ownership of the slot. Tolerances are defined per activity and validated against the actual model. Cooking and gun stations need tighter alignment than standing in a social circle. Never compare a 0.7 m final arrival target against a navigation helper that ignores all target changes smaller than 3 m without a separate local approach phase.

For paired tasks, assign the complementary role: a medic treats a particular patient; a server hands a tray to a particular customer; two litter bearers support the same casualty. Synchronization belongs to that activity instance. Independent bystanders retain their own timing.

### 5.5 One owner writes body motion at a time

Introduce an explicit body-control mode/lease rather than adding more booleans:

```text
LOCOMOTION / INTERACTION / VEHICLE_SEAT / SCRIPTED_PERFORMANCE
DOWNED_OR_DEAD / UNMATERIALIZED
```

Track suspension separately by reasons such as distance, menu, world loading or cinematic handoff. Releasing one reason must not clear the others. A distance wake must not turn physics on for a seated passenger or move a stretcher patient to ground height.

Death/downed handling preempts ordinary activity. Threat responses may interrupt compatible ambient work. Seat/transport must first detach safely before locomotion resumes. Quest staging acquires an explicit lease and must release it on interruption or walk-away. The precise gameplay priority remains the project's existing rule; the technical requirement is a single resolved writer.

Every delayed callback carries a world-generation and activity-generation token. It checks them before touching nodes, inventory, damage, transforms or animation. A surviving Node is not enough evidence that an old action is still valid.

### 5.6 Keep navigation, movement and animation distinct

`NavRouter` chooses a route/next step and reports status. Locomotion combines desired route velocity with bounded local spacing, terrain constraints and posture. Physics commits movement. Presentation uses actual displacement and the active performance contract.

Godot's navigation documentation separates path following from avoidance: the agent does not move its parent automatically, and avoidance does not alter the navigation path or replace collision. If experimenting with RVO, connect and consume its safe-velocity result; setting `avoidance_enabled` alone is not a complete implementation. Preserve the documented path-update and map-synchronization rules, verifying them against the installed 4.7 build. [Godot: Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html).

For camp spacing, start with exclusive targets and a spatial neighborhood index. Define pass-side preference, an exact-overlap tie-break and short-lived yielding at narrow doors. Seated actors occupy their footprint but do not walk away every time someone passes. Medics and transport lanes may have priority, bounded so other actors cannot starve indefinitely.

Avoid global all-pairs scans on every frame. Reuse an existing suitable spatial index if one exists. Update neighborhoods on a staggered cadence; execute smooth movement at the physics cadence. Measure before committing to either RVO or custom steering.

### 5.7 One activation policy for the living world

Unify the **decision** to suspend/wake people, not every species' behavior implementation. Preserve AILod's existing combat-specific rules and player-squad exemptions.

Suggested policy:

- Fully relevant: visible/nearby people, actors interacting with player or squad, local combat participants, transport/quest dependencies.
- Reduced detail: fewer perception and planning updates, simpler animation work, stable existing activity/route; preserve damage and important events.
- Unmaterialized or dormant: durable activity/route progress and state only, if the existing world-simulation design permits it. Do not introduce outcome-changing offscreen combat abstraction as a hidden optimization.

Wake transaction: resolve time-dependent state -> select a valid free slot or safe arrival point -> validate geometry/nav -> restore body/control mode -> restore presentation -> make visible. No simultaneous independent watchdog correction afterward.

Far simulation should use timestamps and stable records. Do not fast-forward hundreds of missed behavior ticks in one frame. If a visible actor cannot be placed honestly, delay materialization or use a permitted nearby entry point; do not teleport them across a sightline.

## 6. NPC implementation sequence with acceptance criteria

### N0 — Capture reproducible failure evidence

**Deliver:** a developer-only inspect overlay and compact event trace, building on `SpawnLedger` and `StallLedger` rather than replacing them.

Select a person and show: stable/debug ID, spawn caller, initial/requested/committed positions, support identity, current controller, occupation, scheduled and executed activity, claimed slot, target/path status, distance and vertical error, current clip, visibility/tier, last recovery reason and world/nav generation.

Trace only state changes and bounded per-actor history. Do not print every actor every frame. Record screenshots/video from the actual player camera separately from diagnostic overlays.

**Accept:** a roof worker, stacked pair and misplaced cooking/treatment animation can each be traced to the last transform/activity writer. An invalid state remains visible as a failure, even if recovery later hides it. A baseline run records seed, exact revision, dirty source hashes, scene and simulation time.

### N1 — Repair semantic targets and timing before a large refactor

**Files:** `civilian.gd`, `civilian_schedules.gd`, existing site/work-point resolver and relevant generator wiring.

1. Resolve cooking to a compatible cooking point, not home wander.
2. Make sleep/rest/social destinations explicit; where content lacks a place, select a safe, honest idle and report missing content.
3. Remove universal work jitter from exact furniture and weapon stations. Retain spread only for flexible areas with distinct validated positions.
4. Refresh schedules across their actual fractional boundaries. Use seeded per-person variation outside mandatory duty windows; never randomize a sentry off a required post.
5. Add action/phase/context to animation invalidation. Guard delayed sit-down completion against cancellation.

**Accept:** a continuous simulation crossing 19.4 through 20.8 observes the correct meal windows; the cook moves to the stove before cooking; treatment requires a patient; walking/alarm cancels a pending seated clip. Midnight and time jumps are tested. No new RNG consumption changes the world layout seed stream.

### N2 — Establish safe placement and validate the actual firebase

**Files:** `game_world.gd`, `nav_baker.gd`, `site_planner.gd`, `mission_generator.gd`, `nav_router.gd`; migrate friendly factories and lifecycle callers.

Build the typed placement boundary and convert the pathways named in F01. Inventory main firebase, kit firebase, village and vehicle-exit markers. Export a content-error report naming the offending marker, owning asset, intended role, support and correction, so fixes can happen in the source asset rather than by piling offsets into GDScript.

**Accept:** zero unauthorized roof placements for the tested seed/event matrix; valid tower and helipad occupants still work; insufficient clearance or unsynchronized nav causes a bounded retry/refusal; no person is accepted at the origin as a magic fallback. Rebuild nav after a breach and verify existing valid destinations survive while invalid ones are withdrawn.

### N3 — Add occupancy, activity phases and camp circulation

Start with **one stove, two diners, one table and one narrow doorway**. A small real-world slice reveals most contract problems. Then migrate the infirmary, bunks, supply jobs and sentry posts.

Introduce reservations and APPROACH/ALIGN/PERFORM. Two claimants cannot acquire one seat. A full hall forms a finite queue or chooses another activity. A person going home does not retain a stove claim. A route failure cannot enter PERFORM. Use terrain-projected local movement, not per-frame root snapping to the marker.

**Accept:** no sustained body overlap after settling; no permanently blocked doors; a destroyed/missing prop releases the activity; loss of a partner cancels or changes a paired task; queues do not exceed authored capacity. Measure seated/cot alignment from the rendered model, not only capsule centers.

### N4 — Consolidate ownership and lifecycle transitions

Patch the current promotion/stand-down snapshot first. Preserve identity, health, home, equipment and appearance; unregister/deactivate old receivers before exposing a replacement. Then migrate transform/animation ownership to explicit modes. Retain one combat implementation.

Unify distance suspension and wakeup. Adapt SeatSystem, GunCrewPerformance and LitterTeam through clear acquire/release boundaries. Do not route crew synchronization through independent ambient clip randomization.

**Accept:** ten alarm/stand-down cycles preserve the same surviving people, health and homes. A death never respawns through stand-down. One person has one active body and damage receiver set. A passenger, patient and gun crew survive distance suspend/resume correctly. There are no stale claims or callbacks after unloading the world.

### N5 — Improve friendly soldier behavior in the field

Keep existing doctrine, cover broker, suppression, ammunition rules and squad autonomy. Improve their coordination at the edges:

- Give ambient patrol members distinct moving slots around a route anchor, with spacing adapted to paths and cover. Do not send every person to the same waypoint coordinate.
- On a narrow trail, compress to a plausible file; after clearing it, reopen spacing. Keep the pointman forward without constant slot swapping.
- On halting, pick distinct useful positions and observation arcs. Do not form a decorative ring through walls.
- In contact, retain valid cover unless there is a reason to move. Separate local cover selection, exposure permission and firing-lane checks. Avoid aim jitter from noisy perception updates.
- Let buddies cover a medic's approach. A rescue requires a reachable patient, a safe enough attempt under the current doctrine, a treatment phase and a cancellable result.
- When an order cannot be honored, communicate a short reason such as blocked route, no ammunition, casualty or pinned. Avoid repeating the same bark every think tick.
- Preserve contact provenance: seeing/hearing a threat and receiving a report are different evidence sources. Do not grant friendlies omniscience for convenience.

**Accept:** player squad and ambient patrol remain distinct; an ambient unit never silently becomes a follower; medics do not revive at a distance; exact coincident positions recover deterministically; friendlies do not repeatedly step into the player's firing lane to satisfy a formation target. Run the existing squad/fairness tests appropriate to each change.

### N6 — Add purposeful everyday life and controlled variation

Only after reliable places and ownership, expand activities. Prefer short sequences with a purpose and end condition:

| Person | Purposeful sequence | Interruption / visible consequence |
|---|---|---|
| Cook/server | Prepare -> serve a diner -> clean station | Alarm pauses service; unserved diner leaves queue appropriately |
| Diner | Queue -> receive tray -> reach free seat -> eat -> return tray | Cannot eat before receiving food or occupy an unavailable chair |
| Quartermaster/detail | Pick up real load -> carry to destination -> set down -> return | Cargo state follows the person; cancellation cannot duplicate it |
| Medic | Inspect patient -> prepare -> treat -> finish/restock | Reacts to patient death, threat and lack of supplies |
| Sentry | Take over post -> watch an assigned arc -> acknowledge handover | Post coverage remains coherent while shifts change |
| Off-duty soldier | Join available social group -> listen/speak/rest -> leave | Turns toward a real partner; no conversation pantomime facing a wall |
| Villager | Household/occupation task -> rest/social interval -> return home | Responds to local danger and changed access without becoming a soldier |
| Gun crew | Reach assigned station -> coordinated service cycle -> rest | Actual piece state and assigned role drive the performance |

Variation should affect timing, chosen compatible micro-action, glance direction and companions. Use cooldowns, minimum dwell time and an action history to reduce immediate repetition. Calm idling is legitimate. A believable firebase does not require every person to gesture constantly.

Do not turn cosmetic crate carrying into a hidden economy unless a real consumer exists. A simple finite task with a real pickup/drop prop can be enough. Do not make every villager an informer, every soldier equally brave or every noise a base-wide panic; preserve current design rules and differentiate reactions through role, evidence and situation.

**Accept:** a five-minute camera observation can explain what each nearby person is doing, where they are going and why. Independent idle actions do not start in lockstep. Cooperative gun/medical/litter actions do synchronize where appropriate. No activity loop runs indefinitely with an absent prop or partner.

## 7. Whole-game engineering work, ordered by risk and dependencies

The following covers the broader game. Confirm local defects before altering behavior; items labeled inspection are not claims that the system is presently broken. The goal is to reduce change risk while improving what the player experiences. No honest plan can guarantee zero regressions, so changes must be small, observable, tested and reversible.

### G0 — Establish a trustworthy baseline and change boundary

**Existing foundation:** `run_all_tests.ps1` captures engine errors, distinguishes known failures and unexpected passes, and uses `-- --test-save`. `tools/overnight_suite_chunk.ps1` provides resumable chunks. The repository contains 191 `.gd` files under `tests` in the reviewed snapshot; that count is not a claim that 191 tests passed or that the default runner includes every probe.

**Work:**

1. Record HEAD, dirty files, source hashes, Godot version, active scene and renderer before making changes. Coordinate with existing work; do not stash, reset or commit someone else's changes.
2. Establish a focused test baseline for the modified systems and a shipping-demo smoke test. Run the broader suite once the branch stabilizes, not after every trivial edit.
3. Record each known failure with its current evidence. Do not assume September 9 known-red comments remain true. Do not change the failure allowlist just to obtain green output.
4. Ensure all test entry points isolate saves **before autoload `_ready`**. Default tests to disposable campaign/slot directories; production-profile access must require an explicit non-test launch. A scene-path naming convention alone is too easy to bypass.
5. Record real wall-frame time and actor counts along with correctness. Use rendered checks for presentation, navigation-in-world and FPS.

**Accept:** a developer can reproduce a failure using one documented command/scene/seed. A test cannot write the owner's real campaign. Baseline errors are distinguished from new regressions, and failed/timeout runs never appear as passes.

### G1 — Make lifetime and cancellation a shared contract

**Existing sources:** `scripts/main/game_flow.gd::_teardown_world`, `scripts/main/mission_scope.gd::reset`, `scripts/autoload/agent_registry.gd`, and delayed callbacks in `field_director.gd` and civilian presentation.

**Proposed boundary:** GameFlow owns changing the world. A world-session object owns world-scoped services and a monotonically changing generation token. Each actor/activity also has a generation for callbacks that can become obsolete while the same world survives.

**Work:**

- Enumerate state by lifetime: per-frame, activity, actor, world, operation, campaign, application setting. Put each value under one appropriate owner.
- Cancel pending spawn jobs, support callbacks, reservations and staged performances before freeing their world. A completed background job may publish only if its generation is still current.
- Clear transient registries and claims through one teardown path. Preserve campaign consequences and user settings intentionally.
- Make register/unregister and release operations idempotent. A death followed by tree exit must not score twice or throw because cleanup already ran.
- Preserve the existing `MissionScope.reset` coverage while migrating it into clearer ownership. Avoid a second reset list that diverges from the first.
- Add diagnostics for orphaned live actors, invalid claim owners and timers that try to affect a replaced world.

**Accept:** new game -> play -> menu -> new game, load over an active world, death during an interaction, and quit during a support request all leave no stale actors, input locks, reservations or callbacks. Repeat world creation/destruction ten times in one process and compare live object/registry counts after settling.

### G2 — Make persistence complete and truthful

**Confirmed priorities:** F13 and F14. Preserve existing magazine schema migration, backup fallback, future-version refusal and campaign consequence logic.

**Work in two separate increments:**

**First: reliable file transaction.** Collect an immutable snapshot on the correct thread. Write, validate and replace with checked results. Return committed success to synchronous callers; publish completion/failure to asynchronous callers. Only show SAVED after success. Maintain a last known good recovery path if rotation fails. Join or safely cancel pending work on shutdown without losing the last completed save. Do not move live scene access onto worker threads.

**Second: persistence scope.** Define exactly what a field save promises. Inventory every durable piece of gameplay state and its owner. Extend the schema incrementally with versioned person/world sections rather than dumping Node properties. Include stable NPC IDs and survival state before adding relationships or quest dependencies.

For a true in-world resume, account for the active world seed/site configuration, simulation day/time, player and squad state, relevant civilian/garrison state, irreversible site changes, completed/active tasks, encounter occurrence IDs and transport state. Decide whether transient bullets/effects are restored, resolved or safely discarded; never accidentally replay an explosion or grant its reward twice.

Rebuild base geometry from deterministic data, apply persistent changes, wait for necessary readiness, restore people to valid locations, reconstruct exclusive reservations deterministically and only then expose the loaded world. On an old save with no slot data, resolve compatible safe locations rather than trusting obsolete raw coordinates.

Reconcile CampaignState's CFG and JSON slot ownership. They need not be merged immediately, but one explicit load/save transaction must determine which snapshot is authoritative. Loading a slot must not partially overwrite campaign state and then fail halfway through the world restore without a reported outcome.

**Accept:** save/load preserves an injured named friendly, a dead NPC, a depleted magazine, the clock and an irreversible world consequence. It does not heal/repopulate by rebuilding. Old supported saves migrate; future saves are refused; corrupt primary can recover from backup; a denied write never displays success. Run tests in disposable profiles only.

### G3 — Separate generation data from runtime construction

**Existing sources:** `mission_generator.gd`, `site_planner.gd`, `game_world.gd`, `nav_baker.gd`, terrain managers and `WorldSim`.

`WorldSim` is currently a small flat registry (`scripts/autoload/world_sim.gd`), not evidence of a complete strategic/offscreen simulation. Build on actual capability rather than treating its name as a finished feature.

**Work:**

- Extract a typed world/site plan containing stable IDs, seed streams, structures, spawn requests and activity-slot definitions. Keep existing seeded layout outcomes stable during the first extraction.
- Separate plan validation, geometry construction, collision readiness, navigation readiness and population activation. Each phase has a completion/result contract; "node exists" is not "ready to spawn people".
- Use separate deterministic streams for world layout, population identity, cosmetic variation and activity choices. A new idle animation must not move a village or change the enemy population.
- Cache immutable static navigation source geometry where appropriate; rebuild affected regions rather than the entire world after local changes. Invalidate dependent routes/slots using a generation.
- Validate authored metadata during content import/build: exact-marker transforms, surface classes, collision agreement, model sockets and reachable activity approaches.
- Make repeated loads/builds deterministic at the data level. Do not confuse nondeterministic thread completion order with a deliberate variation in gameplay.

**Accept:** same seed/configuration produces the same plan and persistent identities; adding cosmetic variation leaves layout unchanged; changing a structure invalidates only affected access/activities; a cold build and warm-cache build both place actors safely.

### G4 — Reduce player and UI coupling through one interaction contract

**Existing sources:** `scripts/player/player.gd`, `scripts/player/weapon_holder.gd`, `scripts/ui/mission_hud.gd`, `scripts/ui/action_progress.gd`, GameManager action/menu state, and FieldDirector's fire-menu/placement methods.

**Inspection and incremental extraction:**

- Create or reuse a unified interaction query/result: target identity, verb, availability reason, required input, duration and cancellation conditions. The prompt and executing action must consume the same result.
- Prioritize competing interactions deterministically. A nearby chair must not steal a casualty treatment prompt; a weapon action must not also activate a menu item.
- Resolve input context centrally: gameplay, conversation, map, support targeting, vehicle, pause, downed. Keep raw input capture, gameplay command and UI feedback separate.
- Extract action channels from Player as needed: treatment, resupply, weapon cleaning, eating and boarding. Each has begin/tick/cancel/complete; effects occur once, not once per UI refresh.
- Preserve weapon-holder ownership of ammunition and reload transactions. The HUD reads state and displays changed values; it must not own inventory or simulate reload completion.
- Present concise reasons for rejected actions. Do not expose technical state-machine or nav status text in the normal player's interface.

**Accept:** holding an interaction while pausing, dying, looking away, entering a seat or opening the map cannot complete twice or leave controls locked. Key prompts match remapped inputs. Closing a screen restores the correct previous context. Squad-status label reuse remains intact.

### G5 — Keep combat rules stable while reducing implementation coupling

**Existing sources:** `Hitzone`, `HitzoneBuilder`, `BulletSystem`, `ProjectilePool`, `CombatManager`, `AI_Marksmanship` implementation in `scripts/combat/ai_marksmanship.gd`, NoiseBus, cover claims and squad coordination. Use actual class names when coding; this list identifies systems, not an instruction to invent aliases.

**Inspection first:** map one rifle shot, one grenade, one support shell and one melee action from input/AI decision through impact, damage, death, registry removal and campaign credit. Establish where direct damage and blast damage are deliberately different. Do not consolidate merely because there are several functions named damage.

**Work:**

- Introduce a typed hit/damage context only where it removes ambiguous argument or ownership paths: source identity, weapon/projectile identity, impact, zone, team, damage type and attribution.
- Guarantee one consequence application per hit/death/event. Repeated callbacks and pooled reuse must not score twice.
- Preserve flat weapon damage rules, hitzones, first-contact fairness, suppression and witnessed-information behavior. Refactoring is not a balance pass.
- Keep belief/last-known-position separate from exact target transform. Test what a friendly actually knows before it aims through vegetation or walls.
- Audit pooled object reset: previous target, collision exclusions, timers, signals, trail state, owner attribution and damage latches must not survive reuse.
- Review saturation behavior. `ProjectilePool._evict_one` prefers non-warheads but eventually evicts a live warhead if no other class is available. Determine the measured saturation case before changing limits. A better policy may reserve important projectile capacity or represent essential impact events independently of cosmetic objects; do not silently delete promised impacts.
- Extract perception, combat intent and presentation from large actor scripts only when their contracts are characterized. Keep shared ballistics/marksmanship rather than copying enemy logic into friendlies again.

**Accept:** before/after deterministic shots and damage scenarios preserve intended results; friend/foe damage attribution remains correct; a silent unwitnessed event does not broadcast omniscient knowledge; pooled reuse cannot hit a prior target; saturation is observable and follows a documented policy.

### G6 — Harden vehicles and support as transactions

**Existing sources:** `seat_system.gd`, `heli_lift.gd`, `landing_zone.gd`, `air_traffic.gd`, FieldDirector fire-support methods and vehicle scripts.

**Work:**

- Treat boarding as reserve seat -> approach -> validate -> attach; unboarding as reserve valid exit -> detach -> restore ownership -> move clear. A failed step must release previous reservations.
- Keep seat-local orientation and character orientation contracts explicit. Preserve authored sockets and per-airframe fallbacks during changes.
- Validate exits against rotorcraft shape, ground, occupied people, pad keep-out and current world generation. Never unseat everyone to one point.
- Handle interruption: aircraft leaves, seat occupant dies, passenger disappears, player cancels, landing zone becomes blocked, world unloads.
- Treat fire-support requests as an idempotent request/result with reserved or spent resources according to the existing rule. Cancellation or failure must not spend twice or yield free duplicate strikes.
- Keep UI previews, actual support destination, timing and damaging effect on the same request data. Preserve danger-close confirmation and allied exposure rules.
- Tie crew animations to genuine flight/weapon state. Avoid inventing a separate harmless-looking firing loop when the weapon is not firing.

**Accept:** full and partial boarding, failed landing, casualty during flight, repeated resupply and menu/load transitions leave no duplicates or frozen passengers. An accepted support request resolves once; a rejected request explains why and handles its resources correctly.

### G7 — Make missions and RPG content consumers of the world

**Release scope:** add only the small amount of content needed to make the demo's exploration meaningful. A full quest/relationship framework is foundation work after the release slice unless the owner deliberately expands the demo scope.

**Existing sources:** `MissionState`, `DynamicMissionFactory`, FieldDirector patrol/crisis methods, CampaignState, squad roster and the dated `production/DEMO_TWO_QUESTS_PLAN_2026-09-06.md` proposal. That proposal is design history, not proof a dialogue system is implemented.

**Work:**

- Define stable world facts and occurrence IDs for events that quests consume: a particular patrol became pinned, a particular patient recovered, supplies reached a particular post, a named soldier died.
- Keep quest state separate from NPC movement. A quest requests an activity/interaction lease; it does not directly overwrite the actor's transform, AI state and animation from several scripts.
- Give quest participants explicit eligibility: alive, available, not boarded, not already in a conflicting activity. If a participant is unavailable, postpone, substitute where the story permits, or branch to a coherent failure outcome.
- Save quest state and already-applied consequences. Loading cannot pay twice or resurrect a quest giver just because a scene rebuild creates their default actor.
- Retain the existing world/task selection authority. Do not add a parallel objective selector that fights FieldDirector's patrol route.
- Review crisis deduplication: `DynamicMissionFactory.emit_location` records `_seen[entity_id]` before validating the translated event and uses entity ID alone. For repeatable events or multiple kinds per entity, define an occurrence key and validate before recording it. Current semantics may intentionally be once per entity; expand only with explicit task needs.
- Keep authored quest beats interruptible and geographically open, consistent with the owner's newer RPG direction. Avoid turning an optional task into an invisible wall around the player.

**Accept:** complete, ignore, interrupt, fail and reload a small task; each produces the intended unique consequence. A dead participant remains dead. A quest does not erase ordinary NPC life when inactive.

### G8 — Budget work across systems rather than patching isolated spikes

**Existing foundation:** `StallLedger`, SpawnLedger, AI tiers, spawn/prewarm pacing, nav collection slicing, idle-body throttling, Mobile renderer and HUD reuse. Preserve these until a controlled measurement justifies a change.

**Work:**

- Capture rendered frame intervals over representative 60–120 second segments: populated firebase, changing shifts, squad patrol, first contact, resupply/boarding and assault with support effects. Include longer gameplay for accumulated leaks/stalls.
- Record actual GPU, renderer, viewport/render scale, power conditions, seed, camera route, visible/active/dormant counts and exact revision. Separate loading from steady-state gameplay.
- Report mean, p95, p99, worst frame and fractions above 16.67/22.22/33.33 ms. Record both CPU and GPU bottlenecks; their work overlaps, so do not add independent timing maxima as if they were one frame.
- Name perception, path requests, locomotion/collision, animation, UI, saves, population activation, nav construction, terrain and effects separately. A physics spike is not automatically an AI-think spike.
- Establish one measured discretionary-work budget for expensive background tasks. Prioritize player-visible readiness and correctness; defer optional preparation. A timer around one indivisible expensive call is not a hard budget.
- Stagger schedule evaluation, spatial refresh and optional visual updates. Batch immutable background computation only where engine/thread rules permit it; commit scene and physics changes through the appropriate main-thread stage.
- Keep relevant NPCs responsive. Do not claim a performance fix by making nearby soldiers stop thinking, delaying all wounds or removing consequences.
- Tune visible vegetation, actor animation detail and effects only with matched visual checks. Preserve the owner's established 3D art direction.

**Accept:** the same scenario improves measured frame-time distribution without new overlap, missed activities, altered casualties or visible wakeups. Headless throughput is reported separately and never labeled player FPS. A 60 FPS average with frequent 50 ms stalls is not a solid 60 FPS result.

### G9 — Turn content assumptions into cheap validators

**Existing sources:** `site_planner.gd`, collision tables/kit registry, `model_actor.gd`, Blender/export tools and asset/animation probes.

**Work:**

- Validate person-slot markers for world/local transform, floor identity, approach access, clearance, facing and supported animation.
- Validate props needed by an activity: stool, tray, crate, radio, shovel, patient or weapon. Missing required content selects honest fallback behavior and appears in a content report.
- Validate per-model animation availability and transitions. Existing `play_first` fallback chains remain useful but cannot silently substitute a clip with incompatible requirements.
- Verify collision geometry, navigation walkability and rendered geometry agree at doors, stairs, bunker openings, floors and pads.
- Associate generated assets with source files and a reproducible export/validation command. Avoid hand-patching generated geometry while the next Blender export restores the bug.
- Keep resource paths, Godot UIDs and scene references intact during refactors. Rename public classes/resources only with all serialized consumers located and migrated.

**Accept:** an intentionally wrong marker, removed chair, missing clip and oversized collider each cause a named validator failure. A good representative asset passes. Do not expand a suppression baseline to bury new failures.

### G10 — Make development evidence easy to trust

Maintain one current status view with: problem, current implementation, evidence, known limitation and next action. Dated histories are useful, but they must not masquerade as the active specification.

Each completed change records its exact revision, relevant test commands/results and rendered evidence when behavior is visual. Avoid claiming "realistic AI completed" because a schedule returned a string. Avoid a count of wired animations as a proxy for believable people.

Use a small diagnostics scene with real representative props and runtime actor classes, plus the actual shipping world. Do not let a sterile test arena become the only proof. Keep development overlays and error codes out of normal gameplay.

## 8. Safe refactor method for Claude

### The repeatable change unit

1. Pick one observable defect or one unstable boundary, not a whole feature category.
2. Trace the live caller chain and serialized consumers. Read the implementation rather than trusting old comments.
3. Record a reproducer/characterization before changing behavior. If fixing a bug, capture the failing case; if extracting code, capture behavior to preserve.
4. Introduce the smallest explicit boundary needed. Reuse proven components.
5. Move the affected callers. During migration, exactly one path may apply state changes. A read-only comparison path may exist briefly for verification but cannot issue moves, damage, saves or rewards.
6. Run focused tests and the relevant integrated scenario. Compare both intended changes and invariants that must stay stable.
7. Remove the replaced implementation and update stale pointers in the same completed change. Do not leave old and new authorities enabled behind unrelated flags.
8. Produce a small reviewable commit according to the project's workflow. Broaden regression checks after the coherent set of related changes, then perform the real demo/patrol checks.

### Dependency order

```text
G0 baseline + safe tests
  -> N0 tracing
  -> N1 target/timing/animation corrections
  -> N2 placement contract
  -> N3 occupancy + activity execution
  -> N4 identity / body ownership / wake integration
  -> N5 field behavior and N6 everyday life

G1 lifecycle supports N2–N4 and all later work
G2 save transaction can be fixed early; world persistence depends on stable IDs
G3 generation contracts support N2 and persistence
G4 interaction contracts precede richer G7 quests
G5 combat and G6 vehicles migrate through proven ownership boundaries
G8 measurement and G9 validation accompany every phase
G10 keeps the current implementation record accurate
```

Do not hold the simple cooking/timing fix until a full world architecture is finished. Do not build rich NPC quests on top of disposable identities. These dependencies are intended to deliver improvements throughout the work.

### Public contracts to protect

| Contract | Protected behavior |
|---|---|
| Damage / ammunition | Same intended hit outcomes, no duplicated rounds, no free reloads |
| Person identity | Role changes, LOD and saves preserve the same surviving person |
| World generation | Same seed/config gives the same geography and population identity |
| Lifecycle | One live body, one owner, idempotent cleanup and no stale callbacks |
| Input | One action per input context; prompts match actual bindings |
| Support / rewards | Accepted operation resolves once; rejection has truthful consequences |
| Saves | No production-save access in tests; committed success means data was committed |
| Performance | Correctness survives cheaper scheduling; player-visible response remains coherent |

### Avoid these high-risk shortcuts

- A blanket rewrite into ECS/GOAP or one universal mega-manager before the current failures are characterized.
- Larger floor rays or larger snap distances without validating the intended surface.
- Lowering every NPC to terrain height, thereby breaking real elevated floors and decks.
- Applying random offsets to every chair, patient, gun station or interaction target.
- Enabling all body collisions or RVO without integrating movement and measuring door behavior.
- Adding animation randomization while destinations, context or callback ownership remain wrong.
- Renaming giant files without separating authority or improving observable behavior.
- Moving live scene-tree access into workers to remove a profiler spike.
- Changing balance, RNG layout streams, save formats and control architecture in one commit.
- Updating snapshots/known-failure lists to hide regressions.
- Running tests against the player's save or treating exit code zero as sufficient evidence.
- Optimizing by removing the people and activity the game is meant to simulate.

## 9. The demo that is worth recording

### 9.1 What the forty minutes must prove

The demo should answer five questions through play:

1. **Do I want to be in this world?** The first room, firebase circulation, distant atmosphere and nearby people make a coherent first impression.
2. **Can I explore under my own initiative?** The player can leave, choose a plausible route and discover a reason to care without being forced down a corridor.
3. **Can I trust my squad and the controls?** Teammates move, respond and fight intelligibly. Prompts do what they say. Failures have understandable causes.
4. **Does combat feel good under load?** Aiming, firing, hit feedback, sound, cover, suppression and enemy reaction remain readable during the actual fight, not only in an empty range.
5. **Does the experience finish coherently?** The night battle resolves; surviving/dead people and world changes make sense; the ending does not mask a stalled simulation.

Do not require forty minutes of constant action. Quiet is valuable when the player has things to notice and choices to make. Empty waiting for an assault timer is different. Track where a first-time player spends time and whether they know what they can do next.

### 9.2 Build one continuous showcase route, then test alternatives

Use a repeatable QA route through the real world, not a special video-only scene:

- Spawn in the intended bunk/room and inspect the nearest friendly at conversation distance.
- Walk through quarters, mess, infirmary or supply area and a perimeter post. Exercise at least one real interaction.
- Leave through the gate with the squad, cross representative vegetation/terrain and visit the demo's intended nearby location(s).
- Experience a representative contact, reload, use cover and observe a squad response.
- Return and observe a changed schedule/lighting period or reinforcement activity.
- Participate in the normal assault with real effects, then reach its intended resolution and end presentation.

This is a testing route, not a rail for the player. Also try the opposite gate approach, loitering in camp, reaching a location early, not taking an optional task, retreating and looking at the action through binoculars. The world must remain coherent when the camera is not where the developer hoped.

Record a short 60–90 second segment after each repaired blocker. That provides visible progress before the full demo is ready. The final acceptance recording must be an ordinary uninterrupted run, without teleporting past defects or changing population/performance settings for the video.

### 9.3 Performance must be tested while recording too

First capture without recording to identify game cost. Then repeat the same route with the actual intended recorder/settings, because recording consumes resources. Report both results and the recording resolution/frame rate. A good unrecorded benchmark is not proof the promotional capture will be smooth.

Use the working Intel GPU and current Mobile renderer. Establish a repeatable lower-cost demo profile before spending time on visual detail the hardware cannot support. Keep the profile honest: state actual viewport, rendering scale, resolution, effects and active population. Do not claim full-resolution 1080p from a scaled internal buffer.

**Proposed measurement gates, to be ratified from the baseline:**

| Objective | Evidence required |
|---|---|
| Steady 60 FPS ambition | Frame-time distribution concentrated within 16.67 ms, with headroom and no recurring stalls; aim for p99 at or below the target budget in representative steady segments |
| 45–59 FPS usability fallback, if explicitly selected | Explicitly labeled fallback, with results against 22.22 ms and 16.67 ms; never marketed internally as a proven 60 FPS result |
| Recording readiness | Same gameplay population/quality remains usable while recording; report the extra frame cost and drops |
| Stutter control | Name and resolve recurring >33.33 ms and >50 ms events; a single isolated long event is investigated and classified rather than hidden in an average |
| Full-arc stability | End-of-run performance and memory do not degrade materially from accumulation compared with matched earlier scenes |

Thresholds are engineering targets, not measured achievements. If 60 FPS is unattainable on the current laptop at the selected look/scale, show the measured trade-offs. The owner can then choose the demo profile knowingly. Do not spend another cycle on the broken NVIDIA device or silently remove the living-world behavior to produce a benchmark.

Attack the top frame-cost causes in measured order. Typical candidate comparisons are vegetation/material cost, view distance, active animation rigs, body collision work, effects, population activation and nav rebuilds. Those are experiments, not findings until timed on the current revision. Preserve the already shipped HUD, idle-body, renderer and pacing improvements.

### 9.4 Art completion follows player exposure and gameplay relevance

Create a small **demo-visible asset list**, separate from the entire future game's art backlog. Walk the actual route and record each defect with a screenshot, asset/source path, distance at which it matters and the exact acceptance change.

Prioritize:

1. Player hands, weapon scale/aim, reloads and hit feedback: visible throughout play.
2. Close friendly faces, gear and a small reliable set of locomotion/idle/combat transitions: these sell the squad.
3. The spawn room, exits, doors, stairs, floors and perimeter: bad placement/collision here ruins the opening.
4. The few work stations used by demo NPCs: their props, sockets and animations must agree.
5. Combat-critical enemies, wounds/deaths and readable silhouettes at actual fighting distances.
6. Night lighting, muzzle flashes, flares and support effects visible during the finale.
7. Distant polish and optional props after the above hold up.

`production/ART_Track_Log.md` contains useful entries but mixes old missing-asset claims with newer completed work. The current top section records journal art as completed and kit collision as completed, while identifying tower/platform and TOC details to revisit. These are dated tracking claims; verify current rendered assets before assigning new art tasks. Another session is editing art now.

For each visible problem, distinguish **missing art**, **wrong integration**, **wrong transform**, **wrong behavior** and **performance compromise**. A medic treating empty air may need a valid patient/slot rather than a new animation. A soldier sliding through a table may need collision/motion repair rather than foot IK.

Do not add every available animation to the demo. A smaller, context-correct set of idle, walk, stop, turn, crouch, aim, shoot, reload, hit and death transitions is more convincing than a large collection triggered incorrectly.

### 9.5 The release gate

Before calling the demo ready to show:

- No unauthorized rooftop actors, persistent body stacks, work clips in unrelated places or visibly frozen squads during the tested ordinary run.
- The first minute works from a fresh profile and cold launch, without console intervention.
- The player can complete the open-world route and fight using the shipped controls and prompts.
- The normal assault resolves correctly; the backstop is not the routine way to finish.
- Performance meets the selected, explicitly named target profile; recurring frame spikes have been removed or the remaining limitation is clearly understood.
- Main weapons and close actors have no missing models, obvious placeholder fallbacks, broken attachments or unacceptable transitions along the route.
- The exported build matches the tested scene/renderer/settings and does not depend on editor caches, developer saves or loose files outside the export.
- A full-length capture can be recorded without changing gameplay to conceal problems.
- The owner plays and judges the result. A test report can support that judgment but cannot substitute for it.

Run at least three representative complete demo playthroughs for the candidate build: the intended route, a less cooperative exploration route, and a repeat/cold launch with recording. This is a proposed small release gate, not proof of universal correctness. Add seeds and stress cases according to failures found.

If the slice is still not showable, keep a short ranked blocker list: worst stutter, worst recurring NPC fault, worst combat/control fault and most exposed art defect. Fix those before expanding content.

## 10. Regression and acceptance matrix

Use real runtime classes and representative real geometry. Unit tests should target rules; integration tests should exercise the chain; rendered review should judge the presentation. Do not replace one kind of evidence with another.

| ID | Scenario | Required outcome |
|---|---|---|
| P01 | Interior marker below a roof, then an intentionally mis-heighted marker | Valid floor accepted; wrong roof rejected/corrected with named reason |
| P02 | Legitimate tower deck, helipad, bunker and sloped ground | Valid elevated/support surfaces remain usable |
| P03 | Missing collision or nav during world construction | No actor committed into invalid space; bounded waiting/refusal |
| P04 | Narrow headroom, occupied capsule, blocked approach | Explicit rejection or compatible alternative, no unsafe snap |
| P05 | Initial spawn, late reinforcement, seat exit, stand-down and wake | All go through the same placement policy with their correct purposes |
| P06 | Nav/terrain rebuilt beneath or near an active slot | Cache revision updates; affected task revalidates safely |
| A01 | Cook scheduled away from stove | Actor approaches compatible stove before PERFORM |
| A02 | Work -> cook while both would map to stooped | Action/animation updates despite unchanged coarse posture |
| A03 | Rest -> talk / sleep transition at same location | Correct activity, partner/bed requirement and animation revision |
| A04 | Clock crosses 19.5, 19.9, 20.3 and respective ends | No meal window silently missed by integer-hour caching |
| A05 | Pause, clock jump and midnight | Consistent boundary handling; no duplicate entry effects |
| A06 | Interrupted sit-down timer | Old completion cannot overwrite walk, alarm, injury or boarding |
| A07 | Missing chair, tray, patient or carried cargo | Honest fallback/cancellation; no pantomime of unavailable activity |
| A08 | Multiple independent idlers and a coordinated crew | Independent timing varies; cooperative roles remain synchronized |
| O01 | Two actors request one seat simultaneously | Exactly one owner; other waits/chooses alternative |
| O02 | Several actors project toward one narrow nav edge | Distinct valid final slots or explicit capacity refusal |
| O03 | Exact coincident body positions | Deterministic separation/recovery without NaNs or permanent overlap |
| O04 | Opposite traffic in a doorway and a stationary bystander | Progress without indefinite jam, wall penetration or repeated teleport |
| O05 | Death/cancel/unload while approaching or performing | Claim and props released once; no ghost occupancy |
| L01 | Civilian travels through 80, 210, 240 and 300 m bands | One activation policy; correct schedule and safe visibility on return |
| L02 | Seated/puppeted actor crosses activation distance | Ownership retained; no gravity/ground snap overriding the seat |
| L03 | Ten promotion/stand-down cycles | Same person, home, health, appearance and valid registry membership |
| L04 | Damage during a role handoff | One active receiver set and one consequence |
| L05 | Ten world load/unload cycles | No accumulating actors, timers, claims, input locks or support effects |
| C01 | Patrol route halt with several friendly men | Distinct suitable positions and observation, no shared endpoint pile |
| C02 | Contact then cover/reload/retreat | Existing damage/fairness preserved; coherent decisions and animation |
| C03 | Medic interrupted or patient dies | Treatment cancels; no remote/duplicate revive or prop residue |
| C04 | Blocked firing lane / target lost behind cover | Correct firing/knowledge policy; no omniscient position tracking |
| S01 | Failed temp write / backup rotation / final rename | Failure reported truthfully; last good save recoverable |
| S02 | Save during autosave and quickload/quit | Ordered transaction; no premature SAVED or stale apply |
| S03 | Old, future and malformed schemas | Supported migration; explicit future refusal; safe recovery behavior |
| S04 | Named wounded NPC and dead NPC across load | Persistent identity/wounds/death preserved when this save scope ships |
| V01 | Full/partial boarding and blocked unload points | Exclusive seats and valid distinct exits, no frozen passengers |
| V02 | World unload while support/flight callbacks wait | No callbacks mutate the next world or duplicate effects |
| Q01 | Optional task completed, ignored, interrupted, reloaded | Coherent branch, unique consequence, ordinary NPC life restored |
| U01 | Interaction + map/pause/menu/death in different orders | One input owner, correct prompts, no stuck controls |
| R01 | Normal full demo with recording | Coherent open-world play, combat, resolution and measured frame pacing |

### Quantify failures instead of relying on impressions alone

Suggested instrumentation fields:

- Unauthorized surface-placement count, rejected-placement count by reason, recovery count and maximum correction distance.
- Overlap duration for pairs on the same floor with overlapping body envelopes; record intentional paired performances separately. A chair/cot actor is judged using the appropriate footprint.
- Route time without progress, blocked-door dwell, claim wait time and reservation leaks.
- Time in PERFORM without valid slot/prop/partner, stale callback rejection count, unexpected animation restarts.
- Duplicate person/body count, unauthorized transform-writer count, health/identity differences across role changes.
- Actor counts by relevance tier, per-subsystem cost and rendered frame-time percentiles.

For an initial overlap watchdog, flag a pair whose penetrated body envelopes persist for more than a short settling grace period, such as two seconds. That threshold is a proposed diagnostic setting, not a universal physical rule. Use tighter checks for accepting a new spawn/slot, where overlap should be prevented before commitment.

### Reuse existing tests before inventing a parallel suite

Verified existing paths include:

- `tests/test_bt_civilian.tscn`, `tests/test_schedule_placement.tscn`, `tests/test_firebase_garrison.tscn`, `tests/test_schedule_reset.tscn`.
- `tests/test_friendly_patrols.tscn`, `tests/test_squad_identity.tscn`, `tests/probe_friendly_lane.tscn`.
- `tools/probe_roof_spawn.gd`, `tools/probe_chowhall_nav.tscn`, `tools/probe_interior_nav.tscn`, `tools/probe_compound_nav.tscn`.
- `tests/probe_ground_seat.tscn`, `tests/probe_off_duty_seating.tscn`, `tests/probe_aid_station.tscn`.
- `tests/test_flat_damage.tscn`, `tests/test_hitzones.tscn`, `tests/test_hitzone_rebuild.tscn`, `tests/test_ai_fairness.tscn`, `tests/test_witness_rule.tscn`.
- `tests/test_magazine_ammo.tscn`, `tests/test_save_roundtrip.tscn`, `tests/test_campaign_state.tscn`, `tests/test_mission_state.tscn`.
- `tests/test_seat_system.tscn`, `tests/test_fire_mission.tscn`, `tests/test_field_item_hud.tscn`, `tests/test_rto_point_hud.tscn`.

These are available starting points, not a claim that they are all currently green or adequate. The normal runner selects `test_*.tscn`; `probe_*` and tool-attached probes need explicit execution and their own bounded result capture. Do not omit them accidentally.

### Safe example commands

From the project root, use the existing runner for focused tests:

```powershell
powershell -File .\run_all_tests.ps1 -Filter test_bt_civilian -TimeoutSec 60
powershell -File .\run_all_tests.ps1 -Filter test_schedule_placement -TimeoutSec 60
```

For a direct test invocation, the isolation flag is mandatory:

```powershell
& 'C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64_console.exe' `
  --headless --path 'C:\Users\caleb\recongame' `
  'res://tests/test_bt_civilian.tscn' -- --test-save
```

Before using the direct form, make its test profile disposable and writable, capture stdout and stderr and impose a bounded process timeout. Do not run parallel tests against the same test-save filename: `CampaignState` uses `campaign_test.cfg` and resets it on startup. Either run serially or give each process a verified separate profile.

For roof regression, the existing probe attaches to the live demo through `--roof-probe`; combine it with a disposable test profile and an explicit seed. Its current one-time result must be supplemented with lifecycle sampling. A `--stress=assault` launch is useful for rapid firefight iteration, but the full quest/patrol lead-in creates different accumulated world state. It cannot replace the full demo test.

### Fresh tests performed during this review

Two direct headless checks ran on September 13 against the reviewed checkout:

| Check | Assertion output | Process result | Limit |
|---|---|---|---|
| `test_bt_civilian` | 9 schedule cases, occupation sampling, 12-action dispatch, unknown-action fallback and seven distinct day-sweep actions passed | Exit 0 | Minimal BT/schedule test, not live-world spatial behavior |
| `test_schedule_placement` | Farmer at work, near home, FAR wake relocation and missing-post fallback passed | Exit 0 | Minimal actors; no actual building/prop/occupancy/watchdog integration |

**These were not clean isolated suite passes.** The direct launches omitted `--test-save`; autoload startup attempted the normal campaign load and emitted access-denied/copy/backup diagnostics plus a certificate-store error. The commands did not call reset_campaign, but the startup behavior itself demonstrates why test isolation must precede autoload initialization. Filesystem restrictions rejected the reported campaign access; do not infer successful save migration or clean persistence from these runs. Further direct runs were not used as a substitute for fixing the harness/profile setup.

This review did not run the full suite, the roof probe against a complete demo, or a fresh rendered performance benchmark. It did not reproduce the owner's exact roof actors on screen. The source findings and proposed tests are intended to make those failures reproducible and repairable.

## 11. Product insights beyond the code tasks

### A smaller believable population is more valuable than a busier-looking one

A few people with clear jobs, correct places and convincing transitions can sell the firebase better than a larger number endlessly gesturing. This does not mean removing the garrison as a performance shortcut. Staff the important stations and circulation routes deliberately, use quiet rest legitimately, and increase density only when movement and performance can support it.

### Transitions are where the player notices the simulation

Walking to a seat, stopping, turning, sitting, reacting to a gunshot and getting up are more revealing than a perfect idle loop. Prioritize approach, alignment and interruption quality. The player forgives low-poly art more easily than a person levitating onto a roof or eating through a wall.

### The squad should earn trust through consistency

The FPS/RPG identity can come from a squadmate staying himself: recognizable face and voice, dependable role, remembered injury, understandable fear and consequences. Start with a stable identity and a small factual history before adding many dialogue branches or personality scores.

### Make world consequences small but visible

A vacant bunk after a death, a medic busy with the casualty brought home, a supply task visibly completed, or a sentry acknowledging a relief shift can make the world feel persistent. These are proposed content uses of the same activity/identity system, not separate scripted populations. Do not implement all of them before the demo; choose one that strengthens the existing loop.

### Let fantasy and scope stay distinct

The demo's promise is the feeling of being a soldier in this war-world: atmosphere, freedom, squad presence and combat. It does not need the entire province, every role, dozens of weapons or a complete quest system to prove that. It does need the systems it shows to behave reliably.

### The real roadmap should follow what spoils a normal recording

Keep doing short ordinary captures during development. If the same stutter, pose, spawn or control issue ruins every capture, it belongs ahead of another optional content addition. Use the recording to reveal defects, not just to prepare marketing after all work is supposedly complete.

## 12. What Claude must hand back

After each completed increment, provide:

1. **Player-visible change:** what now behaves better, with a concrete before/after example.
2. **Implementation:** affected modules, new owner/contract and removed superseded path.
3. **Evidence:** exact revision, scene/seed/profile, focused test results, relevant full-world result and rendered clip/screenshots when visual.
4. **Regression comparison:** protected behaviors checked, known failures unchanged and any newly exposed issue.
5. **Performance:** same-scenario measurements when movement, animation, population, rendering or background scheduling changed.
6. **Remaining limitation:** what is not yet tested or repaired; no broad "done" claim beyond the evidence.
7. **Next demo blocker:** the single next highest-impact problem on the route to a showable forty-minute build.

For the final demo candidate, provide a concise release report, an ordinary full-length captured run, a reproducible exported build configuration and a ranked remaining-issues list. Keep future-game architecture tasks separate from release blockers.

## 13. Copyable instruction to begin the implementation

> Read this handoff and re-check the current RECONgame checkout. The priority is a roughly forty-minute open-world demo: about twenty-five minutes of quests and relationship-building followed by fifteen minutes of firebase defense that the owner is comfortable recording and showing. Preserve active work from other sessions. Start with safe test isolation and a rendered baseline, then reproduce and repair friendly/NPC roof placement, incorrect activity locations, repetitive or stale animation, overlapping bodies and control handoff problems. Use the smallest explicit placement, activity-slot and ownership boundaries needed to make the fixes reliable. Preserve working combat, squad autonomy, the shared demo/world path, current Mobile renderer and prior performance improvements. Remove the largest measured stutters and finish the demo-visible integration defects. Run focused regression tests and actual normal-length demo checks; headless success is not proof of visual quality or FPS. Treat the broader architecture and full-RPG work as a staged follow-on, not a reason to postpone a showable demo. Report concrete evidence after each increment and do not declare the demo ready until an ordinary recorded playthrough supports that claim.
