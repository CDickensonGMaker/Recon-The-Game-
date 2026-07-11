# DEVIL'S ADVOCATE — CoD-2000 "Living Fight" Transplant (2026-07-11)

**Lens:** attack the premise. **Canon read:** GAME_GUIDE.md (pillars, §4.1/4.3 deviations, §6 scope law,
§8 build order), war_room/synthesis_ai_goals.md (the AI doctrine decree), MISSION_DESIGN_RESEARCH.md
(the RTCW/MoHAA derivation — already covers most of what this query asks), enemy_base.gd /
ally_base.gd / sprite_state_map.gd (spot-checks for perf claims).

**Thesis up front:** the Summoner is asking for CoD's *feel* minus CoD's *machine*. Fine — but be
honest about what the machine bought. CoD's aliveness was not an AI achievement; it was an
**audience-management achievement**: guaranteed density, guaranteed fronts, guaranteed sightlines,
guaranteed timing. We are a 5-man patrol in jungle with a 45–90m sight cap (GAME_GUIDE §4.9). Most of
CoD's theater physically cannot be *seen* in our AO. What transplants is the **audible war and the
honest telegraphs** — not the visible one.

---

## 1 · What CoD-2000 actually did (claims sourced or marked)

**Documented (developer-stated, official features, or extensively documented in modding/retrospectives):**

1. **Lineage is real.** Infinity Ward formed from 2015 Inc. (MoHAA: Allied Assault devs); CoD1 (2003)
   runs on modified id Tech 3; Gray Matter (United Offensive, 2004) were the RTCW devs. Our
   MISSION_DESIGN_RESEARCH already mined the underlying architecture from iortcw/OpenMoHAA source —
   CoD1's scripting model is the same family (trigger volumes, spawner scripts, script_brushmodels,
   dormant groups woken in sequence). *Nothing in CoD1's toolbox is architecturally new relative to
   what we already derived. This council should be additive on FEEL techniques only, or it's
   re-derivation.*
2. **Respawn faucets gated by advance triggers.** Enemies respawn from out-of-sight spawners until the
   player crosses an invisible line; widely documented in CoD/CoD2 modding docs and design
   retrospectives, and the single most-criticized structure in the series. The Summoner rejects this;
   so does existing canon (MISSION_DESIGN_RESEARCH §8: RTCW *removed* spawn-from-thin-air — "a
   shipped-game verdict"; finite manpower pool is already law).
3. **Battle Chatter System (CoD2, official marketed feature).** Context-sensitive squad callouts —
   direction, landmark, target type — drawn from a large recorded line pool (thousands of lines per
   faction). This, more than AI, is what reviewers called "smart." Consistent with the FEAR lesson
   already in canon (perceived AI ≈ vocalization, MISSION_DESIGN_RESEARCH §7.7).
4. **Ally density + ally respawn.** CoD kept 8–20 friendlies on screen; generic squadmates were
   replenished between beats so the "front" never thinned. The fight felt alive because *your side*
   was numerous and noisy, not because enemies were clever.
5. **Forgiving damage model as the enabler.** CoD1 medkits, CoD2 regen. That forgiveness is what let
   designers pour constant incoming fire at the player — the bullet-storm feel *depends* on the player
   surviving the storm. **At HLL lethality this is flatly unavailable to us** (Pillar 1: death from
   situation). Named now because half of CoD's "living fight" is volume-of-fire *at the player*, and
   we cannot import it without either killing the player constantly or making enemies liars.
6. **Smoke blocks AI sight (CoD2, documented).** The MG-field-crossing-under-smoke beat. Our decree
   already defers ally smoke doctrine + finite smoke inventory (synthesis_ai_goals, Deferred).
7. **Heavy tracer rendering + fixed MG lanes** as legibility tools: you read the fight by its light.
   (Exact tracer-per-round ratios: **speculation** — visibly far above the real ~1:4/1:5, likely
   most rounds traced for readability. Do not cite ratios as fact.)
8. **Ambient war bed + scripted vignettes:** looping distant artillery/planes, one-shot staged
   vignettes (wounded dragged past, executions, collapsing buildings) placed where the camera must
   look. Trigger-timed, camera-aware, single-use.

**Speculation (mark it, don't build on it):** internal claims about CoD1 AI "goal systems" beyond the
MoHAA-family actor model; any claim that CoD AI reacted systemically to flanking/suppression rather
than being leash-and-script theater. Treat CoD-era enemy AI as *staged*, period.

---

## 2 · Attack 1 — the mushy middle: what scripting bought that systemic AI cannot

Name the purchases honestly (Law 2), because each one is a thing we **sacrifice**:

| CoD's scripting bought | Why systemic can't replicate it | What we sacrifice |
|---|---|---|
| **Guaranteed timing** — the mortar lands when you're looking | Systemic events fire whether or not the player is watching; in jungle they're usually *unseen* | Spectacle-on-cue. Accept: our spectacle is mostly **audio** |
| **Guaranteed density** — every window manned, always a target | Finite honest enemies means the median contact is 2–4 men; a cleared AO is *empty* | The constant-stimulation floor. Accept: **dud stretches exist** |
| **A front line** — allies advance, there is always a "forward" | Open AO, any route, 5-man patrol: no front exists, by Pillar 3 design | The "army around you" feeling entirely. Reframe, don't fake |
| **Authored pacing** — R-curve enforced by triggers | Generator validates layout (§9) but can't control mid-mission player behavior; a player who clears everything early gets 20 quiet minutes | Pacing *guarantees*. Accept variance as fail-forward texture |
| **Cheap "smartness"** — enemies look competent because the set protects them | Our AI is honestly perceivable (Fairness Law) and honestly finite | The illusion of enemy competence beyond what the doctrine actually delivers |

**The mushy-middle failure mode is real and specific:** systemic finite enemies + no authored
corridors + no ally mass = long stretches where the game is *neither* CoD (dense, staged) *nor* Arma
(huge, simulated) — just a small quiet walk with occasional 3-man contacts. The defense is not "add
more aliveness systems." The defense is the one already ratified: **mission grammar + contact deck +
escalation ladder** (GAME_GUIDE §3, §4.2, MISSION_DESIGN_RESEARCH §9) make *contacts* the punctuation
and *quiet* the sentence. This council should sharpen those, not bolt a CoD ambience engine on top.

**The reframe that resolves it:** CoD staged *the fight around you*. Our fiction (Platoon, line-grunt
recon patrol) demands *the WAR around you, at a distance* — and *your* fights small, sudden,
personal. Distant arty rumble, another company's contact on the radio net, flares over a far
treeline: cheap, audio-first, fiction-true, and it makes YOUR silence feel like a held breath rather
than an empty server. Chasing proximity-spectacle is chasing the wrong game.

---

## 3 · Attack 2 — the eerie quiet: atmosphere vs. just boring

When quiet works: **uncertainty**. The player doesn't know whether the AO is cleared. When quiet
fails: **certainty**. The player knows it's over, and now it's a walking simulator to exfil.

1. **Earned vs. unearned quiet.** Post-clear quiet after a real fight reads as *aftermath* — if it's
   dressed as aftermath (your smoke drifting, brass, bodies, squad post-fight muttering — barks the
   162-line VO pool partially covers). Unearned quiet (generator rolled a sparse corner, player took
   the empty route) reads as *unfinished game*. Same silence, opposite valence. The fix is dressing
   and information control, not enemies.
2. **Never sell certainty.** No remaining-enemy counters, no "area clear" toast mid-mission, intel
   stays rolled-accuracy vague (7-element briefing already does this). The moment UI confirms the AO
   is empty, the atmosphere pillar dies. (Tension: debrief tracks contacts avoided per ADR-006 —
   fine, *debrief* is after.)
3. **Ambience must not lie.** The tempting hack — random wildlife-silence, phantom rustles, fake
   distant AK fire *in* the AO — trains players that tells are noise, and then the honest tells
   (canon: muzzle flash, tracers, vocalizations always telegraph) die with them. **Extend the
   Fairness Law to ambience: in-AO threat tells fire only from real state** (bead r6qe,
   detection-driven ambience, is already pointed here). *Out-of-AO* war flavor (distant arty, radio
   traffic about other units) is exempt — it promises nothing about your AO.
4. **Quiet has a half-life.** Speculation to playtest, not decree: contact-free tension survives
   roughly 2–3 minutes on stimulus (a bark, a trace, radio traffic, a boobytrap tell), then decays to
   boredom. Instrument it (time-since-last-stimulus) before funding any content to fill it. Do not
   pre-build valley content for a boredom we haven't measured.
5. **The minimum honest texture already exists in canon** — MISSION_DESIGN_RESEARCH §9 valleys:
   distant mortars, wildlife silence, corpses, abandoned camps, squad chatter. The gap is that most of
   it is unbuilt and *invisible* (r4bk law). Build the canon list before inventing a new one.

---

## 4 · Attack 3 — scope: the content treadmill traps (one artist + AI pair)

Ranked by danger:

1. **Battle-chatter clone = the #1 trap.** CoD2's BCS was thousands of recorded lines per faction.
   We have 162 wired VO lines total. A context-callout system (direction + landmark + target) is a
   combinatorial line-count explosion, and audio content is the one thing the AI pair cannot fully
   automate to quality. If pursued at all: text-first radio/subtitle grammar (r4bk-compliant),
   small recorded pool, no landmark-specific lines (directions only — "contact left!" scales,
   "MG in the granary, second floor!" does not).
2. **Scripted vignettes are single-use money.** Every CoD vignette = staging + bespoke animation +
   one viewing. Each new theatrical anim clip costs Caleb Blender time through the sprite_state_map
   funnel. Law of the treadmill: **no proposal that requires a new animation clip per event type.**
   Reusable prefab event-blocks stamped by the generator (canon §2.3 name-indirection) using
   *existing* clips only.
3. **"Ambient combat director" is a FROZEN epic.** GAME_GUIDE §6: *battle director* is explicitly
   FROZEN post-core, and "a bead in `bd ready` is not a thaw." Any proposal shaped like "a runtime
   system that stages distant battles / paces ambient events dynamically" is a stealth thaw and must
   be named as such before the Arbiter. The cheap substitute is a **seeded schedule rolled at
   briefing** (static data, no runtime brain): N distant-war audio events + radio traffic beats,
   placed on the mission timeline by the generator it already has.
4. **Set-piece insertion/exfil:** the Huey ride already exists and is a ratified binding condition
   (§3). Reuse it as the spectacle bookend. Build zero new set-piece machinery.

---

## 5 · Attack 4 — perf: what breaks

1. **The baseline is already failing.** GAME_GUIDE §4.1: last measured **19–25 FPS** with
   `rendering_method` unset, and no gating FPS number exists. Every aliveness proposal is decoration
   on a machine that can't afford decoration *today*. Build-order item 2 (trust-restoration perf day)
   must land first — this is not negotiable sequencing, it's the standing decree (§8).
2. **The think budget is a lie in code.** `MAX_THINK_TIME` is declared (enemy_base.gd:211) and never
   used — verified by grep this session; the guide flags it (§4.3 ⚠). enemy_base.gd is 1759 lines
   with live `intersect_ray` calls in cover selection (lines ~1502, ~1525). "Dozens of AI in an open
   AO" on top of unbudgeted thinks + raycast cover searches is how 19 FPS becomes 12. The doctrine's
   dispersion costing is zero-raycast by design (synthesis §4) — keep that discipline for anything new.
3. **Canon already caps the fight.** MISSION_DESIGN_RESEARCH §8: active brains 8–12 per fight pocket,
   brain-LOD freeze >60m unseen, staggered perception, leashes. Any "living fight" proposal that
   implies more *simultaneous awake brains* than that is rejected by existing law, not by me.
4. **Ambient layers have budgets too:** distant-war audio = a scheduler + AudioStreamPlayer3D pool
   (cheap, fine); tracer streams are cheap; **dynamic lights are not** — flares/muzzle lighting in a
   PSX forward pipeline need a hard cap (1 flare light, N muzzle flashes as unlit sprites). And the
   witness-rule bug (o18o, build-order #1) sits under ALL detection-driven ambience: silence tied to
   enemy state is worthless while enemy state itself lies.

---

## 6 · What transplants systemically (the short honest list)

- **Audio-first war-at-a-distance** (out-of-AO bed + radio net traffic) — CoD's cheapest trick, and
  the only one that fits a recon-patrol fiction.
- **Chatter as perceived intelligence** — already canon (§7.7); scale by *systemic bark triggers on
  existing lines*, not line-count.
- **Tracer legibility** — per-weapon tracer ratios from real shooters only; RPD/MG lanes readable,
  bolt rifles dark. Serves the Fairness Law directly.
- **Smoke-blocks-sight** — already deferred in the decree; the CoD2 evidence says it's worth its
  slot when the smoke plumbing comes.
- **Interruptible scripted micro-beats on spawned NPCs** (prefab event-blocks) — already derived in
  MISSION_DESIGN_RESEARCH §2.3; CoD adds nothing architectural here.

## 7 · What to reject

- **Respawn faucets / advance-trigger spawning** — rejected by Summoner and by canon (finite pool).
- **Volume-of-fire at the player** — incompatible with HLL lethality; the storm must be aimed at
  lanes/cover/allies, sparingly, or it reads fake.
- **Ally-mass theater / front lines** — no front exists in an open AO; 5 men are not a company.
- **Camera-aware staged spectacle** — unaffordable and unwatchable at jungle sight caps.
- **Landmark-specific chatter** — line-count explosion.
- **Any runtime ambient-battle director** — frozen epic (§6); seeded briefing-time schedule instead.
- **Dishonest tension fakery in-AO** (phantom noises, random wildlife silence) — kills the tell economy.

---

## 8 · Concrete proposals (numbered · effort S/M/L · pillar served)

1. **War-at-a-distance audio schedule (not a director).** Generator rolls, at briefing time, a seeded
   timeline of out-of-AO war events (distant arty, far firefight swells, a flare over a far treeline)
   + matching RTO radio traffic about *other units*. Static data consumed by a dumb player — no
   runtime brain, no frozen-epic thaw. **M · Pillar 2.**
2. **Honest-silence rule, decreed as a Fairness-Law extension.** In-AO ambient tells (wildlife
   silence, rustle) fire ONLY from real enemy state (implements bead r6qe); out-of-AO flavor is
   exempt. Plus aftermath dressing on cleared sites: lingering smoke, squad post-fight barks from the
   existing VO pool. **S–M · Pillars 2, 3.**
3. **Tracer discipline pass.** Per-weapon tracer ratio field; every tracer from a real fired shot;
   MG/RPD lanes highly visible, SKS/Mosin dark; muzzle flash always renders (Fairness Law). Cheap
   param work on the existing tracer path. **S · Pillars 1, 2.**
4. **Quiet-boredom instrumentation before quiet-boredom content.** Log time-since-last-stimulus
   (contact, bark, radio beat, trace discovery, trap tell) in playtests; fund valley content only
   against measured dead air >~2–3 min median. **S · process, protects Pillars 2/5 from treadmill.**
5. **Bark-trigger expansion on the EXISTING 162-line pool** (contact direction, post-kill,
   post-silence "too quiet" beats, point-man trap tells) — systemic triggers, zero new anims,
   text-subtitle fallback for uncovered contexts (r4bk). Explicitly NOT a BCS clone. **M · Pillars 4, 2.**
6. **Punctuation lives in the contact deck, not a new system.** Ambush/boobytrap/patrol cadence =
   generator deck weights (canon §4.6) + the escalation ladder; sharpen weights, add an "ambush"
   prefab event-block from existing clips. **M · Pillars 3, 5.**
7. **Sequencing law:** none of the above lands before build-order #1 (witness rule o18o) and #2
   (perf day: rendering_method A/B, MAX_THINK_TIME actually wired, gating FPS number). Aliveness on
   a lying detection core at 19 FPS is drift. **S (process) · guards all five pillars.**

---

## The sacrifice ledger (Law 2, stated plainly)

We give up: spectacle-on-cue, the constant-stimulation floor, the army-around-you, and pacing
*guarantees*. We accept: dud stretches, small contacts, variance between missions. We buy: honesty,
replayable generation, an atmosphere no CoD game ever had — silence that means something. If the
council isn't willing to say "some missions will be quiet and that's the game," it should not
pretend to reject the respawn faucet, because every mushy-middle "fix" is the faucet wearing a mask.
